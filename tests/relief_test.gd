class_name CWReliefTest
extends RefCounted

## Verifications de la couche posee **au-dessus** du champ d'altitude : le
## reseau de chemins et ses levees (jalon 1.16), et le tramage des matieres de
## surface qui l'accompagne (le degrade adouci).
##
## Pilote par tests/worldgen_test.gd, qui tient le compte des verifications.
##
## **Ce que cette suite peut voir, et ce qu'elle ne peut pas.** Elle verifie des
## proprietes *geometriques* — un chemin ne tranche pas plus de quatre blocs,
## une levee passe au-dessus de l'eau, deux matieres se partagent une frontiere.
## Elle ne peut rien dire de ce a quoi tout cela ressemble : ce depot a deja
## retire **quatre** systemes qui passaient tous leurs tests et ne valaient rien
## a l'oeil — la falaise, les ponts, le lot d'ouvrages, et les surplombs avec
## leurs grottes. La capture reste le juge.

var _runner: Object


func run(runner: Object) -> void:
	_runner = runner
	_test_chemins()
	_test_tramage()


func _ok(label: String, condition: bool, detail: String = "") -> void:
	_runner._ok(label, condition, detail)


## Un champ neuf sur la graine de la demo, ou tous les reperes de ce depot sont
## pris (invariant n. 37).
func _champ() -> CWTerrainField:
	var p := CWWorldParams.new()
	p.world_seed = 2024
	return CWTerrainField.new(p)


## Compare `_generate_block` et `generated_voxel` sur la colonne de blocs qui
## traverse un point donne. Rend vrai si les deux disent la meme chose partout.
func _accord(f: CWTerrainField, wx: int, wz: int) -> bool:
	var p: CWWorldParams = f.params()
	var g := CWVoxelGenerator.new()
	g.params = p
	var lx: int = wx - p.world_origin.x
	var lz: int = wz - p.world_origin.y
	@warning_ignore("integer_division")
	var bx: int = (lx >> 4) << 4
	@warning_ignore("integer_division")
	var bz: int = (lz >> 4) << 4
	var buf := VoxelBuffer.new()
	buf.create(16, 16, 16)
	var sol: int = floori(g.field().sample_column(wx, wz).x)
	for k in range(-2, 9):
		var by: int = ((sol >> 4) + k) << 4
		g._generate_block(buf, Vector3i(bx, by, bz), 0)
		for ix in range(0, 16, 3):
			for iz in range(0, 16, 3):
				for iy in range(0, 16, 3):
					var a: int = buf.get_voxel(ix, iy, iz,
							CWPalette.CHANNEL_TYPE)
					var b: int = g.generated_voxel(bx + ix, by + iy, bz + iz)
					if a != b:
						printerr("     desaccord en (%d, %d, %d) : %d vs %d"
								% [bx + ix, by + iy, bz + iz, a, b])
						return false
	return true



# -- 3. Les chemins -----------------------------------------------------------

func _test_chemins() -> void:
	print("[chemins]")
	var f: CWTerrainField = _champ()
	var p: CWWorldParams = f.params()
	var zx: int = CWWorldParams.zone_of(p.world_origin.x)
	var zz: int = CWWorldParams.zone_of(p.world_origin.y)
	var zone: CWPathNetwork.Zone = f.paths().get_zone(zx, zz, f)
	_ok("la zone du depart porte un reseau", not zone.is_empty(),
			"%d segments" % (zone.segments.size() / 6))
	if zone.is_empty():
		return
	print("     reseau : %d segments, %d cellules d'index"
			% [zone.segments.size() / 6, zone.index.size()])

	# Les portes sont partagees : les deux voisines calculent le meme point sans
	# se lire. C'est ce qui permet a un chemin de ne pas sortir de sa zone.
	var g1: Vector2i = CWPathNetwork.gate_vertical(p.world_seed, zx + 1, zz)
	var g2: Vector2i = CWPathNetwork.gate_vertical(p.world_seed, zx + 1, zz)
	_ok("une porte est une fonction pure de sa frontiere", g1 == g2)
	_ok("une porte est sur la frontiere", g1.x == (zx + 1) * CWWorldParams.ZONE_SIZE)
	# Et la zone voisine y arrive aussi.
	var voisine: CWPathNetwork.Zone = f.paths().get_zone(zx + 1, zz, f)
	_ok("la zone voisine touche la meme porte",
			_touche(voisine, g1, 40.0) and _touche(zone, g1, 40.0))

	# Tous les segments restent dans leur zone.
	var dehors: int = 0
	var s: PackedFloat32Array = zone.segments
	for i in s.size() / 6:
		for k in [0, 3]:
			var x: float = s[i * 6 + k]
			var z: float = s[i * 6 + k + 1]
			if x < float(zx * CWWorldParams.ZONE_SIZE) - 1.0 \
					or x > float((zx + 1) * CWWorldParams.ZONE_SIZE) + 1.0 \
					or z < float(zz * CWWorldParams.ZONE_SIZE) - 1.0 \
					or z > float((zz + 1) * CWWorldParams.ZONE_SIZE) + 1.0:
				dehors += 1
	_ok("aucun chemin ne sort de sa zone", dehors == 0, "%d bornes" % dehors)

	# Ce qu'un chemin fait a la colonne : la chaussee est plate, la tranchee est
	# bornee, et le degagement est de l'air.
	var sea: int = p.sea_level
	var g := CWVoxelGenerator.new()
	g.params = p
	var vus: int = 0
	var trop: int = 0
	var gravier: int = 0
	var degages: int = 0
	var levees: int = 0
	var pas_creuses: int = 0
	var somme_creux: int = 0
	# La premiere colonne de chaussee rencontree, gardee pour l'accord des deux
	# ecritures de la regle plus bas.
	var milieu := Vector2i(0x7FFFFFFF, 0)
	for i in range(0, s.size() / 6, 7):
		var x: int = int((s[i * 6] + s[i * 6 + 3]) * 0.5)
		var z: int = int((s[i * 6 + 1] + s[i * 6 + 4]) * 0.5)
		var cells: PackedInt32Array = zone.index.get(
				CWPathNetwork.cell_key(x, z), PackedInt32Array())
		var road: Vector2 = CWPathNetwork.nearest(zone, cells,
				float(x), float(z))
		if not CWPathNetwork.on_roadway(road):
			continue
		var c: Vector4 = f.sample_column_full(x, z)
		var biome: int = CWBiome.at(c.x, c.y, c.z, sea)
		var prof: Vector3i = CWTerrainField.column_profile(c.x, c.w, sea, biome)
		var span: float = CWPathNetwork.causeway_at(zone, float(x), float(z))
		var shape: Vector3i = CWVoxelGenerator.road_shape(road, prof.x,
				span, CWTerrainField.free_water(prof, sea))
		vus += 1
		if milieu.x == 0x7FFFFFFF:
			milieu = Vector2i(x, z)
		# -- Le creusement, sur la **chaussee** et non sur son bord -----------
		#
		# C'est le reproche du 2026-09-09 : *les bords sont bien creuses d'un
		# bloc minimum sous le sol, mais l'interieur ne l'est pas*. Il etait
		# juste, et aucune verification ne pouvait le voir — elles mesuraient ce
		# que le chemin **tranche au plus**, jamais ce qu'il tranche **au
		# moins**. Mesure d'alors : 35,3 % des colonnes de chaussee etaient en
		# remblai, et l'ecart moyen au terrain valait -0,26 bloc au milieu du
		# ruban contre -1,00 a son bord.
		#
		# Un franchissement est exclu, et lui seul : la, le chemin comble.
		if not is_nan(span):
			levees += 1
		else:
			if shape.x > prof.x - CWPathNetwork.MIN_CUT:
				pas_creuses += 1
			somme_creux += prof.x - shape.x
			if absi(shape.x - prof.x) > CWPathNetwork.MAX_CUT:
				trop += 1
		var surf: int = g.generated_voxel(x - p.world_origin.x, shape.x,
				z - p.world_origin.y)
		if surf == CWPalette.GRAVEL:
			gravier += 1
		# Le degagement : la tranche au-dessus de la chaussee est vide.
		var vide: bool = true
		for dy in range(1, CWPathNetwork.CLEARANCE + 1):
			if g.generated_voxel(x - p.world_origin.x, shape.x + dy,
					z - p.world_origin.y) != CWPalette.AIR:
				vide = false
		if vide:
			degages += 1

	_ok("des colonnes de chaussee ont ete trouvees", vus > 8, "%d" % vus)
	_ok("un chemin ne tranche jamais plus de quatre blocs", trop == 0,
			"%d colonnes sur %d" % [trop, vus])
	# **Le contrat du creusement, et il porte sur le milieu du ruban.** Hors
	# franchissement, aucune colonne de chaussee ne doit etre a moins de
	# `MIN_CUT` sous le terrain qui la borde.
	_ok("la chaussee est creusee sur toute sa largeur, et pas seulement au bord",
			pas_creuses == 0, "%d colonnes sur %d" % [pas_creuses, vus - levees])
	_ok("la chaussee est en gravier", gravier * 4 >= vus * 3,
			"%d sur %d" % [gravier, vus])
	_ok("la chaussee est degagee, levees comprises", degages == vus,
			"%d sur %d" % [degages, vus])
	print("     chaussee : %d colonnes sondees, dont %d en levee ; creusement moyen %.2f bloc"
			% [vus, levees,
			float(somme_creux) / float(maxi(1, vus - levees))])

	# Et rien n'y pousse : c'est ce qui la rend lisible de loin.
	var sur_chaussee: int = 0
	var scatter := CWScatter.new(f)
	for i in range(0, s.size() / 6, 11):
		var x: int = int(s[i * 6])
		var z: int = int(s[i * 6 + 1])
		for pl in scatter.placements_in(x - 8, z - 8, 16, 16):
			var cells: PackedInt32Array = zone.index.get(
					CWPathNetwork.cell_key(pl.x, pl.z), PackedInt32Array())
			if CWPathNetwork.on_roadway(CWPathNetwork.nearest(zone, cells,
					float(pl.x), float(pl.z))):
				sur_chaussee += 1
	_ok("rien ne pousse sur la chaussee", sur_chaussee == 0,
			"%d plantes" % sur_chaussee)

	# Le generateur et la requete ponctuelle doivent decrire le meme chemin.
	# C'est l'invariant n. 18, exerce **la ou la colonne n'est pas un simple
	# champ de hauteurs** : une chaussee est tranchee sous le terrain et
	# degagee au-dessus, donc les deux ecritures de la regle s'y separent si
	# elles doivent se separer. Le balayage du jalon 1.8 tombe, lui, sur du
	# terrain nu. Cette place etait tenue par un massif jusqu'au 2026-09-10.
	_ok("bloc genere et requete ponctuelle s'accordent sur un chemin",
			milieu.x != 0x7FFFFFFF and _accord(f, milieu.x, milieu.y))
	_test_levees(f, zone, g)


## La levee comble le gap et rejoint ses deux rives (2026-09-09).
##
## **Il n'y a plus de pont.** La ou le chemin rencontrait l'eau, il la comble :
## le remblai qui montait deja a l'approche ne redescend plus, et la travee de
## bois, son noeud de rendu et son tablier de matiere sont retires.
##
## Ce qui se verifie ici est donc ce qu'on demande a une levee, et c'est la meme
## chose qu'a un pont : **qu'on la traverse a pied sec et sans marche**. On
## parcourt l'axe d'un franchissement d'un bout a l'autre, on releve a chaque pas
## la surface sur laquelle on pose le pied, et on exige trois choses — qu'elle ne
## saute jamais de plus d'un bloc a la culee, qu'elle passe **au-dessus de la
## surface libre**, et qu'elle soit bien un **remblai** au milieu, sans quoi le
## chemin plongerait dans la riviere au lieu de la combler.
##
## > **Une marche ne se voit pas sur une colonne seule** — c'est la lecon du
## > 2026-09-09, et elle vaut toujours. Les verifications qui regardaient chaque
## > colonne isolement ont laisse passer un ouvrage flottant pendant deux jours ;
## > celle-ci compare deux colonnes qui se suivent, donc elle marche.
func _test_levees(f: CWTerrainField, zone: CWPathNetwork.Zone,
		g: CWVoxelGenerator) -> void:
	if zone.crossings.is_empty():
		_ok("une zone porte au moins un franchissement", false, "aucun")
		return
	_ok("une zone porte au moins un franchissement", true,
			"%d" % zone.crossings.size())

	var sea: int = f.params().sea_level
	var pires: int = 0
	var pire: int = 0
	var ou: String = ""
	var pas_vus: int = 0
	var mouilles: int = 0
	var remblais: int = 0
	var sur_eau: int = 0
	## La plus grande marche rencontree **partout**, culee ou non. Elle n'est
	## pas un contrat : elle est la pour qu'on sache ce que le reseau fait
	## ailleurs, et pour qu'une regression du bornage general se voie.
	var pire_tout: int = 0
	for passage in zone.crossings:
		var n: int = passage.size() / 3
		if n < 2:
			continue
		# -- On suit l'axe du franchissement, pas sa corde --------------------
		#
		# Le premier essai marchait en ligne droite du premier point au dernier.
		# Un franchissement est **courbe** : la corde sort du ruban, y rentre, et
		# retraverse l'eau ailleurs. Les marches qu'elle relevait etaient celles
		# de colonnes qui ne se suivent pas.
		#
		# On parcourt donc la ligne brisee elle-meme, bloc par bloc, prolongee
		# de `marge` blocs de chaque cote dans l'axe de ses segments de bout —
		# c'est la que se trouve la culee.
		var marge: float = 48.0
		var voie: Array[Vector2] = []
		var d0: Vector2 = (Vector2(passage[0], passage[1])
				- Vector2(passage[3], passage[4])).normalized()
		for k in range(int(marge), 0, -1):
			voie.append(Vector2(passage[0], passage[1]) + d0 * float(k))
		for k in n - 1:
			var a := Vector2(passage[k * 3], passage[k * 3 + 1])
			var b := Vector2(passage[(k + 1) * 3], passage[(k + 1) * 3 + 1])
			var l: int = maxi(1, int(a.distance_to(b)))
			for j in l:
				voie.append(a.lerp(b, float(j) / float(l)))
		var last := Vector2(passage[(n - 1) * 3], passage[(n - 1) * 3 + 1])
		var d1: Vector2 = (last - Vector2(passage[(n - 2) * 3],
				passage[(n - 2) * 3 + 1])).normalized()
		for k in range(1, int(marge) + 1):
			voie.append(last + d1 * float(k))

		var prev: int = 0x7FFFFFFF
		var sur_levee_prev: bool = false
		for q in voie:
			var x: int = int(q.x)
			var z: int = int(q.y)
			var cells: PackedInt32Array = zone.index.get(
					CWPathNetwork.cell_key(x, z), PackedInt32Array())
			var road: Vector2 = CWPathNetwork.nearest(zone, cells,
					float(x), float(z))
			if not CWPathNetwork.on_roadway(road):
				prev = 0x7FFFFFFF
				continue
			var c: Vector4 = f.sample_column_full(x, z)
			var biome: int = CWBiome.at(c.x, c.y, c.z, sea)
			var prof: Vector3i = CWTerrainField.column_profile(
					c.x, c.w, sea, biome)
			var span: float = CWPathNetwork.causeway_at(zone, float(x),
					float(z))
			var libre: int = CWTerrainField.free_water(prof, sea)
			var shape: Vector3i = CWVoxelGenerator.road_shape(
					road, prof.x, span, libre)
			var sur_levee: bool = not is_nan(span)
			# La surface sur laquelle on pose le pied.
			var sous_pied: int = shape.x

			# -- Au milieu de l'eau, on marche au sec et au-dessus du lit -----
			#
			# `libre` est la surface libre de la colonne : l'etang s'il y en a
			# un, la mer sinon. Les deux exigences sont distinctes — *le pied
			# est au-dessus de l'eau* et *le chemin a bien remblaye* — parce que
			# la seconde peut manquer sans la premiere sur une riviere peu
			# profonde.
			if libre != CWTerrainField.NO_WATER:
				mouilles += 1
				if sous_pied > libre:
					sur_eau += 1
				if sous_pied > prof.x:
					remblais += 1

			if prev != 0x7FFFFFFF:
				var marche: int = absi(sous_pied - prev)
				if marche > pire_tout:
					pire_tout = marche
				# **La culee, et elle seule.** Ailleurs, une marche de
				# `MAX_CUT` est un fait connu du reseau et non un defaut : le
				# profil borne son ecart au sol tous les 32 blocs, et entre deux
				# jalons `shaped_top` reprend le bornage colonne par colonne
				# contre un terrain qui a le droit de bomber. Ce qui se juge ici
				# est le **passage de la levee a la tranchee**, et il n'a pas
				# cette excuse : les deux surfaces sortent du meme profil, et la
				# regle de dessus les fait se rejoindre par construction.
				if sur_levee != sur_levee_prev:
					pas_vus += 1
					if marche > pire:
						pire = marche
						ou = "(%d, %d)" % [x, z]
					if marche > 1:
						pires += 1
			prev = sous_pied
			sur_levee_prev = sur_levee
	_ok("de quoi juger une culee", pas_vus >= 2,
			"%d entrees/sorties de levee" % pas_vus)
	_ok("de quoi juger une levee", mouilles >= 8,
			"%d colonnes mouillees" % mouilles)
	# **Deux blocs au pire, et presque toujours zero.** Le contrat n'est pas
	# « aucune marche », et il ne peut pas l'etre : l'altitude de la levee est
	# plancheree par la surface libre au releve, et une riviere plus creuse que
	# ne le disait le jalon voisin du profil releve le remblai d'un bloc ou deux.
	# C'est le meme seuil que l'escalade d'un massif — on monte sur deux blocs —
	# et le chemin lui-meme fait des marches de trois ailleurs, ce que la ligne
	# imprimee rappelle.
	_ok("on passe de la rive a la levee sans marche infranchissable",
			pire <= 2, "la pire fait %d bloc(s) en %s" % [pire, ou])
	_ok("et la culee est a niveau dans la quasi-totalite des cas",
			pires * 20 <= pas_vus,
			"%d culees ressautent sur %d" % [pires, pas_vus])
	# Les deux moities de « remplir le gap par le chemin » : on ne marche pas
	# dans l'eau, et ce qui nous porte est bien de la matiere ajoutee.
	_ok("on traverse l'eau a pied sec", sur_eau == mouilles,
			"%d colonnes sur %d" % [sur_eau, mouilles])
	_ok("et ce qui porte le pied est un remblai, pas le lit",
			remblais == mouilles, "%d colonnes sur %d" % [remblais, mouilles])
	print("     levees : %d franchissements, %d colonnes au-dessus de l'eau, %d entrees/sorties, plus grande marche %d bloc(s) ; le long du chemin, %d"
			% [zone.crossings.size(), mouilles, pas_vus, pire, pire_tout])


static func _touche(zone: CWPathNetwork.Zone, p: Vector2i, tol: float) -> bool:
	var s: PackedFloat32Array = zone.segments
	for i in s.size() / 6:
		for k in [0, 3]:
			if Vector2(s[i * 6 + k] - float(p.x),
					s[i * 6 + k + 1] - float(p.y)).length() <= tol:
				return true
	return false


# -- 4. Le tramage des matieres ----------------------------------------------

func _test_tramage() -> void:
	print("[degrade des surfaces]")
	_ok("t = 0 rend la premiere matiere",
			CWPalette.blended(CWPalette.SAND, CWPalette.GRASS, 0.0, 10, 10)
			== CWPalette.SAND)
	_ok("t = 1 rend la seconde",
			CWPalette.blended(CWPalette.SAND, CWPalette.GRASS, 1.0, 10, 10)
			== CWPalette.GRASS)

	# A mi-chemin, la moitie de chaque : c'est la definition d'un tramage, et
	# c'est ce qui fait qu'une frontiere se lit comme un degrade.
	var b: int = 0
	var n: int = 0
	for x in range(0, 200):
		for z in range(0, 200):
			n += 1
			if CWPalette.blended(CWPalette.SAND, CWPalette.GRASS, 0.5,
					x * 3 + 90000, z * 3 + 70000) == CWPalette.GRASS:
				b += 1
	var part: float = float(b) / float(n)
	_ok("a mi-chemin, les deux matieres se partagent le sol",
			absf(part - 0.5) < 0.07, "%.3f" % part)

	# Le tramage est **en plaques** et non en poivre-et-sel : deux colonnes
	# voisines sont d'accord bien plus souvent que le hasard.
	var accords: int = 0
	var paires: int = 0
	for x in range(0, 200):
		for z in range(0, 200):
			paires += 1
			var a: int = CWPalette.blended(CWPalette.SAND, CWPalette.GRASS,
					0.5, x + 5000, z + 4000)
			var c: int = CWPalette.blended(CWPalette.SAND, CWPalette.GRASS,
					0.5, x + 5001, z + 4000)
			if a == c:
				accords += 1
	var voisinage: float = float(accords) / float(paires)
	_ok("le tramage fait des plaques, pas du poivre et sel",
			voisinage > 0.72, "%.3f d'accord entre voisins" % voisinage)
	print("     tramage : %.1f %% de la seconde matiere a mi-chemin, %.1f %% "
			% [part * 100.0, voisinage * 100.0]
			+ "d'accord entre colonnes voisines")

	# La falaise : une pente nulle ne rend jamais de roche, une pente franche
	# en rend. C'est le seul endroit ou la regle retiree au jalon 1.13 revient,
	# et c'est le tramage qui la rend defendable.
	var plate: int = 0
	var raide: int = 0
	for x in range(0, 120):
		for z in range(0, 120):
			if CWPalette.surface_of(CWBiome.GREENLANDS, 60.0, 0.5, 0.5,
					x + 1000, z + 2000, 0.0) == CWPalette.STONE:
				plate += 1
			if CWPalette.surface_of(CWBiome.GREENLANDS, 60.0, 0.5, 0.5,
					x + 1000, z + 2000, 0.9) == CWPalette.STONE:
				raide += 1
	_ok("une pente nulle ne porte jamais de roche", plate == 0, "%d" % plate)

	# L'ecotone : la frontiere entre deux biomes. Loin d'un seuil, le brouillage
	# du climat ne change rien et la fonction sort sans echantillonner ; **sur**
	# le seuil, les deux biomes s'interpenetrent.
	# L'amplitude est desormais un argument, borne en blocs par
	# `CWBiome.fringe_amplitude` : ces deux mesures-ci veulent la frange la
	# plus large possible, donc le plafond.
	var plein := Vector2(CWBiome.DITHER_T, CWBiome.DITHER_H)
	# **Le point temoin est du cote humide, et ce n'est pas indifferent.** Sur
	# le versant sec, les trois seuils de temperature — Snowlands, Deserts, Lava
	# Lands — se suivent de moins de 0,14, c'est-a-dire de moins de deux
	# amplitudes de tramage : on n'y trouve plus un point qui soit loin de tous.
	# Du cote humide il n'y en a que deux, et 0,36 est a 0,08 de l'un et 0,11 de
	# l'autre. L'humidite, elle, est a 0,20 de sa frontiere, soit deux fois
	# `DITHER_H` : le tramage ne peut pas faire passer la colonne du cote sec,
	# donc les seuils du sec ne la concernent pas.
	var loin: int = 0
	for x in range(0, 60):
		for z in range(0, 60):
			if CWBiome.at_dithered(50.0, 0.36, 0.85, 0, x + 700, z + 800,
					plein) \
					!= CWBiome.GREENLANDS:
				loin += 1
	_ok("loin d'un seuil, le tramage de biome ne change rien", loin == 0,
			"%d colonnes" % loin)

	# **Pile sur la frontiere sec/humide, a temperature chaude** : c'est la plus
	# grande frontiere de matiere du monde depuis le 2026-09-11, puisqu'une
	# seule frontiere d'humidite le partage en deux. D'un cote la jungle, de
	# l'autre les Lava Lands.
	var secs: int = 0
	var total: int = 0
	for x in range(0, 120):
		for z in range(0, 120):
			total += 1
			if CWBiome.at_dithered(50.0, 0.80, CWBiome.HUMID_H, 0,
					x + 4000, z + 5000, plein) != CWBiome.JUNGLES:
				secs += 1
	var part_d: float = float(secs) / float(total)
	_ok("sur la frontiere sec/humide, les deux biomes s'interpenetrent",
			part_d > 0.2 and part_d < 0.8, "%.3f du cote sec" % part_d)
	print("     ecotone : %.1f %% du cote sec exactement sur la frontiere"
			% (part_d * 100.0))

	# Et la meme chose sur une frontiere de **temperature**, celle qui separe la
	# prairie du desert : le tramage doit brouiller les deux grandeurs, pas la
	# seule humidite. Sans cette seconde verification, un tramage qui ne
	# toucherait que `h` passerait la precedente sans rien dire.
	var chauds: int = 0
	total = 0
	for x in range(0, 120):
		for z in range(0, 120):
			total += 1
			if CWBiome.at_dithered(50.0, CWBiome.DESERT_T, 0.30, 0,
					x + 1100, z + 2200, plein) == CWBiome.DESERTS:
				chauds += 1
	var part_t: float = float(chauds) / float(total)
	_ok("sur la frontiere prairie/desert, les deux biomes s'interpenetrent",
			part_t > 0.2 and part_t < 0.8, "%.3f de desert" % part_t)

	# -- La frange se borne en blocs (2026-09-09) -----------------------------
	#
	# Le defaut du 2026-09-08 : une amplitude en unites de climat represente une
	# distance qui depend de la pente du champ, donc une frange de largeur
	# inconnue — et infinie la ou le champ est plat. Ces quatre verifications
	# tiennent la borne, et la premiere est la seule qui compte vraiment : **sur
	# un climat plat, il n'y a pas de frontiere, donc pas de frange.**
	var nul: Vector2 = CWBiome.fringe_amplitude(Vector2.ZERO)
	_ok("climat plat : amplitude nulle", nul == Vector2.ZERO, "%v" % nul)

	var fige: int = 0
	for x in range(0, 60):
		for z in range(0, 60):
			# Pile sur le seuil d'humidite du desert, la ou le tramage a le plus
			# de prise : a amplitude nulle il ne doit pourtant rien changer.
			if CWBiome.at_dithered(50.0, 0.80, CWBiome.HUMID_H, 0,
					x + 4000, z + 5000, Vector2.ZERO) \
					!= CWBiome.at(50.0, 0.80, CWBiome.HUMID_H, 0):
				fige += 1
	_ok("climat plat : le tramage ne deplace plus rien", fige == 0,
			"%d colonnes" % fige)

	# Une pente moyenne : la frange doit mesurer FRINGE_BLOCKS blocs, donc
	# l'amplitude vaut la pente multipliee par cette largeur — et non le
	# plafond.
	var douce: Vector2 = CWBiome.fringe_amplitude(Vector2(0.0005, 0.0005))
	_ok("pente douce : l'amplitude est la largeur voulue, pas le plafond",
			is_equal_approx(douce.x, 0.0005 * CWBiome.FRINGE_BLOCKS)
					and douce.x < CWBiome.DITHER_T, "%v" % douce)

	# Une pente forte : le plafond reprend la main, sans quoi une frontiere
	# climatique abrupte se tramerait sur plus large que sa propre bande.
	var raide_c: Vector2 = CWBiome.fringe_amplitude(Vector2(1.0, 1.0))
	_ok("pente forte : le plafond tient",
			raide_c == Vector2(CWBiome.DITHER_T, CWBiome.DITHER_H),
			"%v" % raide_c)

	_ok("une pente franche est entierement rocheuse",
			raide == 120 * 120, "%d sur %d" % [raide, 120 * 120])
