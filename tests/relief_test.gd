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


## Le biome nomme a la fraction `t` du segment qui joint un site a son voisin.
## Trois lignes, mais elles sont ecrites deux fois dans la mesure d'ecotone —
## une passe grossiere puis une fine — et les garder ensemble est ce qui evite
## que les deux se mettent a mesurer deux choses differentes.
func _biome_le_long(f: CWTerrainField, site: CWRegionSite, axe: Vector2,
		t: float, sea: int) -> int:
	var q: Vector2 = Vector2(float(site.x), float(site.z)) + axe * t
	var x: int = int(q.x)
	var z: int = int(q.y)
	return CWBiome.of_site(f.nearest_site(x, z), f.sample_column(x, z).x, sea)


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
			if CWPalette.surface_of(CWBiome.GREENLANDS, 60.0,
					x + 1000, z + 2000, 0.0) == CWPalette.STONE:
				plate += 1
			if CWPalette.surface_of(CWBiome.GREENLANDS, 60.0,
					x + 1000, z + 2000, 0.9) == CWPalette.STONE:
				raide += 1
	_ok("une pente nulle ne porte jamais de roche", plate == 0, "%d" % plate)

	# -- L'ecotone : la frontiere entre deux biomes (refait le 2026-09-12) ---
	#
	# Le biome se decide au **site de region** depuis ce jour-la, et la frange
	# n'est plus un brouillage de climat mais un **deplacement du point** :
	# la matiere du sol prend le biome du site le plus proche d'un point
	# deplace d'au plus `FRINGE_BLOCKS`. Ce qui se verifie ici est donc une
	# geometrie, et non plus une amplitude — c'est ce qui rend ces mesures
	# beaucoup plus directes que celles qu'elles remplacent.
	var f := _champ()

	# 1. Le deplacement est borne, et il n'est pas nul. Les deux ensemble : une
	#    frange figee passerait la premiere verification sans rien dire.
	var pire_ecart: float = 0.0
	var bouge: bool = false
	for i in 400:
		var x: int = 4_000_000 + i * 37
		var z: int = 4_000_000 + i * 91
		var d: Vector2 = f.fringe_point(x, z) - f.warped_point(x, z)
		pire_ecart = maxf(pire_ecart, maxf(absf(d.x), absf(d.y)))
		if d.length() > 4.0:
			bouge = true
	_ok("le deplacement de frange reste sous FRINGE_BLOCKS",
			pire_ecart <= CWTerrainField.FRINGE_BLOCKS + 0.001,
			"%.1f blocs pour %.0f" % [pire_ecart, CWTerrainField.FRINGE_BLOCKS])
	_ok("le deplacement de frange n'est pas fige", bouge,
			"ecart maximal %.1f blocs" % pire_ecart)

	# 2. **Au coeur d'une region, la frange ne change rien.** C'est la propriete
	#    que l'ancien mecanisme n'avait pas : sur un climat plat, brouiller le
	#    climat tirait a pile ou face sur chaque colonne d'un pays entier. Un
	#    deplacement de trente blocs, lui, ne change pas de site tant qu'on est
	#    loin d'une arete — et « loin » se compte en blocs, sans pente a diviser.
	var site: CWRegionSite = f.sites().get_site(60, 60)
	var dedans: int = 0
	for ix in 24:
		for iz in 24:
			var x: int = site.x + (ix - 12) * 24
			var z: int = site.z + (iz - 12) * 24
			var h: float = f.sample_column(x, z).x
			if f.fringe_biome(x, z, h) != CWBiome.of_site(
					f.nearest_site(x, z), h, f.params().sea_level):
				dedans += 1
	_ok("au coeur d'une region, la frange ne deplace rien", dedans == 0,
			"%d colonnes sur 576" % dedans)

	# 3. **Sur une frontiere, les deux biomes s'interpenetrent, et pas plus
	#    profond que le contrat.** Le transect va d'un site a son voisin : il
	#    traverse donc l'arete de Voronoi qui les separe, et une seule. On le
	#    parcourt une premiere fois grossierement pour trouver l'arete, puis a
	#    la maille du bloc autour d'elle — une frange de trente blocs sur vingt
	#    mille ne se voit pas autrement, et c'est bien le signe qu'elle est
	#    etroite.
	var voisin: CWRegionSite = f.sites().get_site(61, 60)
	var sea: int = f.params().sea_level
	var axe := Vector2(float(voisin.x - site.x), float(voisin.z - site.z))
	var longueur: float = axe.length()
	var pas_gros: int = 128
	var bord_t: float = -1.0
	var prev: int = -1
	var sauts: int = 0
	for k in pas_gros + 1:
		var t: float = float(k) / float(pas_gros)
		var here: int = _biome_le_long(f, site, axe, t, sea)
		if prev >= 0 and here != prev:
			sauts += 1
			bord_t = t
		prev = here
	_ok("un transect d'un site a son voisin ne traverse qu'une frontiere",
			sauts <= 1, "%d frontieres sur %.0f blocs" % [sauts, longueur])
	print("     un site a son voisin : %.0f blocs, %d changement(s) de biome"
			% [longueur, sauts])

	if sauts == 1:
		# La maille fine : 512 blocs de part et d'autre de l'arete, un point
		# par bloc.
		var n_f: int = 1024
		var nomme := PackedInt32Array()
		var trame := PackedInt32Array()
		nomme.resize(n_f)
		trame.resize(n_f)
		var centre: Vector2 = Vector2(float(site.x), float(site.z)) + axe * bord_t
		var u: Vector2 = axe / longueur
		for k in n_f:
			var q: Vector2 = centre + u * float(k - n_f / 2)
			var x: int = int(q.x)
			var z: int = int(q.y)
			var h: float = f.sample_column(x, z).x
			nomme[k] = CWBiome.of_site(f.nearest_site(x, z), h, sea)
			trame[k] = f.fringe_biome(x, z, h)
		var bords := PackedInt32Array()
		for k in range(1, n_f):
			if nomme[k] != nomme[k - 1]:
				bords.append(k)
		var desaccords: int = 0
		var pire_incursion: int = 0
		for k in n_f:
			if trame[k] == nomme[k]:
				continue
			desaccords += 1
			var d: int = n_f
			for bord in bords:
				d = mini(d, absi(k - bord))
			pire_incursion = maxi(pire_incursion, d)
		_ok("la frontiere de Voronoi porte une frange", desaccords > 0,
				"%d colonnes sur %d" % [desaccords, n_f])
		# La borne est prise large : le pas d'un bloc suit la droite du
		# transect, qui coupe l'arete de biais. Ce qu'elle attrape est le retour
		# du vrai defaut — une frange qui traverse un pays.
		_ok("la frange ne s'enfonce pas plus loin que son contrat",
				pire_incursion <= int(CWTerrainField.FRINGE_BLOCKS * 2.0),
				"%d blocs pour un contrat de %.0f"
						% [pire_incursion, CWTerrainField.FRINGE_BLOCKS])
		print("     ecotone : %d colonnes de frange sur %d, incursion maximale %d blocs"
				% [desaccords, n_f, pire_incursion])

	_ok("une pente franche est entierement rocheuse",
			raide == 120 * 120, "%d sur %d" % [raide, 120 * 120])
