class_name CWReliefTest
extends RefCounted

## Verifications des trois couches posees **au-dessus** du champ d'altitude :
## les surplombs et leurs grottes (jalon 1.15), le reseau de chemins et ses
## ponts (jalon 1.16), et le tramage des matieres de surface qui accompagne les
## deux (le degrade adouci).
##
## Pilote par tests/worldgen_test.gd, qui tient le compte des verifications.
##
## **Ce que cette suite peut voir, et ce qu'elle ne peut pas.** Elle verifie des
## proprietes *geometriques* — un chapeau a un dessus plat, une grotte debouche,
## un chemin ne tranche pas plus de quatre blocs, un pont passe au-dessus de
## l'eau. Elle ne peut rien dire de ce a quoi tout cela ressemble : ce depot a
## deja retire trois systemes qui passaient tous leurs tests et ne valaient rien
## a l'oeil. La capture reste le juge.

var _runner: Object


func run(runner: Object) -> void:
	_runner = runner
	_test_surplombs()
	_test_grottes()
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


## Le premier surplomb rencontre en spirale autour du point de depart.
func _un_surplomb(f: CWTerrainField, avec_grotte: bool = false) -> CWMesa:
	var o: Vector2i = f.params().world_origin
	for r in range(0, 40):
		for a in range(0, 10):
			var ang: float = float(a) * TAU / 10.0
			var x: int = o.x + int(cos(ang) * float(r) * 300.0)
			var z: int = o.y + int(sin(ang) * float(r) * 300.0)
			for m in f.mesas().mesas_at(x, z, f):
				if avec_grotte and m.caves.is_empty():
					continue
				return m
	return null


# -- 1. Les surplombs ---------------------------------------------------------

func _test_surplombs() -> void:
	print("[surplombs]")
	var f: CWTerrainField = _champ()
	var m: CWMesa = _un_surplomb(f)
	_ok("un surplomb existe pres du depart", m != null)
	if m == null:
		return

	# Deterministe : la meme cellule reconstruite doit rendre le meme objet.
	# C'est la propriete la plus chere a perdre — un monde qui change entre deux
	# visites ne se signale par rien d'autre.
	var cx: int = CWMesaGrid.cell_of(int(m.x))
	var cz: int = CWMesaGrid.cell_of(int(m.z))
	f.mesas().clear_cache()
	var again: Array[CWMesa] = f.mesas().get_cell(cx, cz, f)
	_ok("une cellule de massifs se reconstruit a l'identique",
			again.size() == 1 and again[0].x == m.x and again[0].z == m.z
			and again[0].base_y == m.base_y and again[0].height == m.height,
			"%s vs %s" % [str(m), str(again)])
	m = again[0]

	# La masse sort du sol et y retourne : au coeur elle est haute, au-dela de
	# son contour elle n'existe plus.
	var au_centre: Vector2i = m.slab(int(m.x), int(m.z), m.base_y)
	_ok("la masse est haute en son coeur",
			au_centre.y - m.base_y > int(m.height * 0.5),
			"%d au-dessus du sol" % (au_centre.y - m.base_y))
	_ok("elle est pleine sous elle", au_centre.x < m.base_y)
	var loin: Vector2i = m.slab(int(m.x + m.reach() + 8.0), int(m.z), m.base_y)
	_ok("hors de portee, la masse ne pose rien", loin.x > loin.y)

	# -- **Escaladable** : le contrat de la refonte du 2026-09-08 --------------
	#
	# Une masse escaladable est une masse dont le dessus ne monte jamais de plus
	# d'un bloc par bloc. On ne s'en remet pas au calcul — les deux bruits de
	# forme s'ajoutent au terme radial et leur somme n'a pas de borne evidente —
	# on **balaie** la masse en croix et on releve la plus grande marche.
	var pire_marche: int = 0
	var ou: String = ""
	for a in range(0, 24):
		var ang: float = float(a) * TAU / 24.0
		var prev: int = 0
		var dans: bool = false
		for d in range(int(m.reach()) + 2, -1, -1):
			var px: int = int(m.x + cos(ang) * float(d))
			var pz: int = int(m.z + sin(ang) * float(d))
			var sol: int = floori(f.sample_column(px, pz).x)
			var sl: Vector2i = m.slab(px, pz, sol)
			var h: int = maxi(sl.y, sol) if sl.y >= sl.x else sol
			# Le **porche** d'une grotte est un surplomb voulu : il souleve le
			# dessous de la masse, donc il fait sauter la colonne. Il ne barre
			# aucun chemin — on en fait le tour en trois pas — et il n'a rien a
			# faire dans une mesure d'escalade.
			if m.porch(px, pz) > 0:
				dans = false
				continue
			if dans:
				var marche: int = absi(h - prev)
				if marche > pire_marche:
					pire_marche = marche
					ou = "(%d, %d)" % [px, pz]
			prev = h
			dans = true
	# **Deux blocs, et pas un**, parce que deux entiers arrondis se suivent :
	# le dessus d'un massif vaut `plancher(sol) + plancher(hauteur x f²)`, et
	# chacun des deux termes a le droit de changer d'une unite d'une colonne a la
	# suivante. Le terrain seul en fait deja un ; la masse en ajoute au plus un.
	# Une marche de deux blocs se monte ; une marche de douze — ce que rendait la
	# premiere version, qui mesurait sa hauteur depuis le sol de son *centre* —
	# ne se monte pas.
	_ok("la masse s'escalade : jamais plus de deux blocs de marche",
			pire_marche <= 2, "%d blocs en %s" % [pire_marche, ou])
	print("     massif : rayon %.0f, hauteur %.0f, plus grande marche %d bloc(s)"
			% [m.radius, m.height, pire_marche])

	# Le generateur et la requete ponctuelle doivent decrire le meme surplomb.
	# C'est l'invariant n. 18, exerce **la ou il y a quelque chose au-dessus du
	# sol** — le balayage du jalon 1.8 tombe sur un champ de hauteurs nu.
	_ok("bloc genere et requete ponctuelle s'accordent sur un massif",
			_accord(f, int(m.x), int(m.z)))


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


# -- 2. Les grottes -----------------------------------------------------------

func _test_grottes() -> void:
	print("[grottes]")
	var f: CWTerrainField = _champ()
	var m: CWMesa = _un_surplomb(f, true)
	_ok("un surplomb a grotte existe pres du depart", m != null)
	if m == null:
		return

	var g := CWVoxelGenerator.new()
	g.params = f.params()

	var ouvertes: int = 0
	var percees: int = 0
	var profondeurs: PackedFloat32Array = PackedFloat32Array()
	for c in m.caves:
		# 1. Le tube ne sort jamais par le dessus de la masse : une grotte qui
		#    deboucherait au sommet serait un trou dans le sol. On le verifie
		#    **le long de l'axe** et non a la bouche — la bouche est au seuil de
		#    la masse, la ou celle-ci n'a par definition aucune epaisseur.
		var plafond: int = c.floor_y + c.height - 1
		for k in range(1, c.axis.size() / 3):
			var px: int = int(c.axis[k * 3])
			var pz: int = int(c.axis[k * 3 + 1])
			var sommet: int = floori(f.sample_column(px, pz).x) \
					+ m.thickness(px, pz)
			if plafond > sommet:
				percees += 1
				break

		# 2. **Elle est accessible sans creuser.** L'entree est sur le flanc, au
		#    ras du sol : le bloc qui s'y trouve a la hauteur du plancher doit
		#    deja etre de l'air, et le rester en s'eloignant. C'est la garantie
		#    demandee, et elle est verifiee dehors, sur le monde genere, pas sur
		#    la regle qui l'a posee.
		var mouth: Vector2 = c.mouth()
		var dir: Vector2 = (mouth - Vector2(m.x, m.z)).normalized()
		var libre: bool = true
		for step in range(0, 26, 5):
			var px: int = int(mouth.x + dir.x * float(step))
			var pz: int = int(mouth.y + dir.y * float(step))
			if g.generated_voxel(px - g.params.world_origin.x, c.floor_y,
					pz - g.params.world_origin.y) != CWPalette.AIR:
				libre = false
				break
		if libre:
			ouvertes += 1

		# 3. Sa longueur : la somme de ses segments, en blocs.
		var l: float = 0.0
		for i in c.axis.size() / 3 - 1:
			l += Vector2(c.axis[(i + 1) * 3] - c.axis[i * 3],
					c.axis[(i + 1) * 3 + 1] - c.axis[i * 3 + 1]).length()
		profondeurs.append(l)

	_ok("aucune grotte ne perce le dessus du massif", percees == 0,
			"%d sur %d" % [percees, m.caves.size()])
	_ok("chaque grotte debouche a l'air libre, sans creuser",
			ouvertes == m.caves.size(),
			"%d sur %d" % [ouvertes, m.caves.size()])
	var l_min: float = profondeurs[0]
	for l in profondeurs:
		l_min = minf(l_min, l)
	_ok("une galerie s'enfonce d'au moins vingt blocs", l_min >= 20.0,
			"la plus courte fait %.0f blocs" % l_min)
	_ok("son axe est brise, pas droit",
			m.caves[0].axis.size() / 3 >= 3,
			"%d points" % (m.caves[0].axis.size() / 3))
	print("     grottes : %d galeries, la plus courte %.0f blocs"
			% [m.caves.size(), l_min])

	# 3. Le tube est bien creux : au fond, la colonne porte de l'air a la hauteur
	#    du plancher, alors que le terrain, lui, est plus haut.
	var c0 = m.caves[0]
	var n0: int = c0.axis.size() / 3
	var fond := Vector2(c0.axis[(n0 - 1) * 3], c0.axis[(n0 - 1) * 3 + 1])
	var creux: bool = g.generated_voxel(
			int(fond.x) - g.params.world_origin.x, c0.floor_y + 1,
			int(fond.y) - g.params.world_origin.y) == CWPalette.AIR
	_ok("le tube est creux jusqu'a son fond", creux)


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
	var ponts: int = 0
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
		var shape: Vector4i = CWVoxelGenerator.road_shape(road, prof.x, prof, sea)
		vus += 1
		if shape.w != CWVoxelGenerator.DECK_NONE:
			ponts += 1
			# Un pont passe **au-dessus** de la surface libre, jamais dedans.
			var libre: int = prof.z if prof.y <= prof.z else sea
			if shape.w >= libre + CWPathNetwork.BRIDGE_CLEAR:
				degages += 1
			continue
		if absi(shape.x - prof.x) > maxi(CWPathNetwork.MAX_CUT,
				CWPathNetwork.MAX_FILL):
			trop += 1
		var surf: int = g.generated_voxel(x - p.world_origin.x, shape.x,
				z - p.world_origin.y)
		if surf == CWPalette.GRAVEL:
			gravier += 1
		# Le degagement : la tranche au-dessus de la chaussee est vide, y compris
		# la ou elle traverse le socle d'un surplomb.
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
	_ok("la chaussee est en gravier", gravier * 4 >= (vus - ponts) * 3,
			"%d sur %d" % [gravier, vus - ponts])
	_ok("la chaussee est degagee, ponts compris", degages == vus,
			"%d sur %d" % [degages, vus])
	print("     chaussee : %d colonnes sondees, dont %d en pont" % [vus, ponts])

	# Et rien n'y pousse : c'est ce qui la rend lisible de loin.
	var sur_chaussee: int = 0
	var scatter := CWScatter.new(f)
	for i in range(0, s.size() / 6, 11):
		var x: int = int(s[i * 6])
		var z: int = int(s[i * 6 + 1])
		for pl in scatter.placements_in(x - 8, z - 8, 16, 16):
			# Une plante posee sur le **chapeau** d'un surplomb n'est pas sur la
			# chaussee : elle est quatre-vingts blocs au-dessus d'elle. Sans
			# cette exclusion, la verification compte des plantes parfaitement
			# posees — quatre sur la zone de depart, toutes sur une mesa que le
			# chemin traverse par-dessous.
			var rel: Vector4i = CWMesaGrid.relief(
					f.mesas().mesas_at(pl.x, pl.z, f), pl.x, pl.z,
					floori(f.sample_column(pl.x, pl.z).x))
			if rel.y >= rel.x:
				continue
			var cells: PackedInt32Array = zone.index.get(
					CWPathNetwork.cell_key(pl.x, pl.z), PackedInt32Array())
			if CWPathNetwork.on_roadway(CWPathNetwork.nearest(zone, cells,
					float(pl.x), float(pl.z))):
				sur_chaussee += 1
	_ok("rien ne pousse sur la chaussee", sur_chaussee == 0,
			"%d plantes" % sur_chaussee)


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
	var loin: int = 0
	for x in range(0, 60):
		for z in range(0, 60):
			if CWBiome.at_dithered(50.0, 0.45, 0.50, 0, x + 700, z + 800) \
					!= CWBiome.GREENLANDS:
				loin += 1
	_ok("loin d'un seuil, le tramage de biome ne change rien", loin == 0,
			"%d colonnes" % loin)

	var deserts: int = 0
	var total: int = 0
	for x in range(0, 120):
		for z in range(0, 120):
			total += 1
			# Pile sur le seuil d'humidite du desert, a temperature chaude.
			if CWBiome.at_dithered(50.0, 0.80, CWBiome.DESERT_H, 0,
					x + 4000, z + 5000) == CWBiome.DESERTS:
				deserts += 1
	var part_d: float = float(deserts) / float(total)
	_ok("sur le seuil, les deux biomes s'interpenetrent",
			part_d > 0.2 and part_d < 0.8, "%.3f de desert" % part_d)
	print("     ecotone : %.1f %% de desert exactement sur son seuil d'humidite"
			% (part_d * 100.0))
	_ok("une pente franche est entierement rocheuse",
			raide == 120 * 120, "%d sur %d" % [raide, 120 * 120])
