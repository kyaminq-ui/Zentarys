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
	#
	# **Et la borne est celle de ce massif-la** (2026-09-09). Depuis que chaque
	# masse tire son propre caractere — des domes lisses, des masses decoupees en
	# lobes —, la marche maximale n'est plus une constante partagee : elle se
	# calcule des nombres du massif (`CWMesa.max_step`, derivee dans son en-tete).
	# C'est contre elle que la mesure se fait. Le contrat global n'a pas disparu
	# pour autant : `CWMesaGrid` rabat la rugosite d'une masse qui depasserait
	# `CLIMB_MAX_STEP`, et la verification suivante le tient.
	_ok("la masse s'escalade : jamais plus que sa propre borne",
			pire_marche <= m.max_step(),
			"%d blocs en %s, borne %d" % [pire_marche, ou, m.max_step()])
	_ok("et sa borne tient le contrat d'escalade",
			m.max_step() <= CWMesa.CLIMB_MAX_STEP,
			"borne %d" % m.max_step())
	print("     massif : rayon %.0f, hauteur %.0f, rugosite %.3f/%.3f, marche %d (borne %d)"
			% [m.radius, m.height, m.amp_slow, m.amp_fine, pire_marche,
			m.max_step()])

	_caracteres(f)

	# Le generateur et la requete ponctuelle doivent decrire le meme surplomb.
	# C'est l'invariant n. 18, exerce **la ou il y a quelque chose au-dessus du
	# sol** — le balayage du jalon 1.8 tombe sur un champ de hauteurs nu.
	_ok("bloc genere et requete ponctuelle s'accordent sur un massif",
			_accord(f, int(m.x), int(m.z)))


## Le caractere varie d'un massif a l'autre, et chacun tient sa propre borne.
##
## Un seul massif ne peut pas montrer ca : il faut un echantillon. On balaie
## donc les cellules autour du depart, on releve les rugosites tirees, et on
## verifie les deux moities du contrat de 2026-09-09 — **il y a bien un
## eventail** (sans quoi le tirage par massif ne sert a rien), et **aucune masse
## ne sort du contrat d'escalade** (sans quoi le rabattement de `CWMesaGrid` ne
## marche pas).
func _caracteres(f: CWTerrainField) -> void:
	var o: Vector2i = f.params().world_origin
	var vus: Array[CWMesa] = []
	for i in range(0, 26):
		for j in range(0, 26):
			var cx: int = CWMesaGrid.cell_of(o.x) + i - 13
			var cz: int = CWMesaGrid.cell_of(o.y) + j - 13
			for m in f.mesas().get_cell(cx, cz, f):
				vus.append(m)
	_ok("de quoi juger l'eventail des caracteres", vus.size() >= 12,
			"%d massifs" % vus.size())
	if vus.size() < 12:
		return

	var lisse: float = INF
	var rude: float = 0.0
	var hors: int = 0
	var au_dela: int = 0
	for m in vus:
		lisse = minf(lisse, m.amp_slow)
		rude = maxf(rude, m.amp_slow)
		if m.max_step() > CWMesa.CLIMB_MAX_STEP:
			hors += 1
		if m.slope_bound() > float(CWMesa.CLIMB_MAX_STEP):
			au_dela += 1
	print("     caracteres : %d massifs, rugosite lente de %.3f a %.3f"
			% [vus.size(), lisse, rude])
	# Un eventail reel, et pas deux tirages qui se ressemblent : le plus rude
	# doit porter au moins moitie plus d'amplitude que le plus lisse.
	_ok("les massifs n'ont pas tous le meme caractere", rude > lisse * 1.5,
			"de %.3f a %.3f" % [lisse, rude])
	# Et le rabattement tient sur tout l'echantillon : c'est la moitie du
	# contrat que le tirage par massif aurait pu casser.
	_ok("aucun massif ne sort du contrat d'escalade", hors == 0,
			"%d sur %d" % [hors, vus.size()])


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
	var bouches: int = 0
	var percees: int = 0
	var pincees: int = 0
	var marches: int = 0
	var profondeurs: PackedFloat32Array = PackedFloat32Array()
	for c in m.caves:
		var n: int = c.points()

		# 1. Le tube ne sort jamais par le dessus de la masse : une grotte qui
		#    deboucherait au sommet serait un trou dans le sol. On le verifie
		#    **le long de l'axe** et non aux bouches — une bouche est au seuil
		#    de la masse, la ou celle-ci n'a par definition aucune epaisseur.
		for k in range(1, n - 1):
			var q: Vector2 = c.point_at(k)
			var sommet: int = floori(f.sample_column(int(q.x), int(q.y)).x) \
					+ m.thickness(int(q.x), int(q.y))
			if c.floor_at(k) + c.clearance_at(k) - 1.0 > float(sommet):
				percees += 1
				break

		# 2. **Praticable d'un bout a l'autre** (2026-09-09). C'est le prix de la
		#    section variable : elle peut se pincer jusqu'a boucher la galerie,
		#    et une grotte bouchee au milieu est pire qu'une grotte droite — on y
		#    entre, on marche, et on se cogne. On exige donc a **chaque** point
		#    de l'axe une section et une hauteur libre au-dessus des planchers,
		#    et un plancher qui ne fait pas de marche : une galerie qui monte de
		#    six blocs d'un point au suivant ne se parcourt pas plus qu'un mur.
		for k in range(0, n):
			if c.radius_at(k) < CWMesaGrid.CAVE_SECTION_FLOOR - 0.001 \
					or c.clearance_at(k) < CWMesaGrid.CAVE_CLEARANCE_FLOOR - 0.001:
				pincees += 1
				break
		for k in range(1, n):
			var d: float = absf(c.floor_at(k) - c.floor_at(k - 1))
			var pas: float = c.point_at(k).distance_to(c.point_at(k - 1))
			# Une pente d'un bloc par bloc se monte ; au-dela, c'est une marche.
			if d > maxf(2.0, pas):
				marches += 1
				break

		# 3. **Elle est accessible sans creuser, et par ses deux bouts.** Le bloc
		#    qui se trouve a une bouche a la hauteur du plancher doit deja etre
		#    de l'air, et le rester en s'eloignant. Verifie dehors, sur le monde
		#    genere, pas sur la regle qui l'a posee.
		#
		#    Un embranchement en est dispense : il s'arrete **dans** la masse par
		#    construction, et on y accede par la galerie qui le porte.
		if c.branch:
			continue
		for cote in 2:
			bouches += 1
			var bouche: Vector2 = c.mouth() if cote == 0 else c.mouth_out()
			var sol: float = c.floor_at(0) if cote == 0 else c.floor_at(n - 1)
			var dir: Vector2 = (bouche - Vector2(m.x, m.z)).normalized()
			var libre: bool = true
			for step in range(0, 26, 5):
				var px: int = int(bouche.x + dir.x * float(step))
				var pz: int = int(bouche.y + dir.y * float(step))
				if g.generated_voxel(px - g.params.world_origin.x, int(sol),
						pz - g.params.world_origin.y) != CWPalette.AIR:
					libre = false
					break
			if libre:
				ouvertes += 1

		# 4. Sa longueur : la somme de ses segments, en blocs.
		var l: float = 0.0
		for i in n - 1:
			l += c.point_at(i + 1).distance_to(c.point_at(i))
		profondeurs.append(l)

	_ok("aucune grotte ne perce le dessus du massif", percees == 0,
			"%d sur %d" % [percees, m.caves.size()])
	_ok("aucune galerie ne se pince sous ses planchers", pincees == 0,
			"%d sur %d" % [pincees, m.caves.size()])
	_ok("le plancher d'une galerie ne fait pas de marche", marches == 0,
			"%d sur %d" % [marches, m.caves.size()])
	# **Les deux bouts**, depuis que la galerie traverse : une grotte ouverte
	# d'un seul cote est un cul-de-sac, ce qui etait justement le reproche.
	_ok("chaque galerie debouche a l'air libre par ses deux bouts, sans creuser",
			ouvertes == bouches, "%d bouches sur %d" % [ouvertes, bouches])
	_ok("une galerie a bien deux bouches", bouches >= 2, "%d" % bouches)
	var l_min: float = profondeurs[0]
	for l in profondeurs:
		l_min = minf(l_min, l)
	_ok("une galerie s'enfonce d'au moins vingt blocs", l_min >= 20.0,
			"la plus courte fait %.0f blocs" % l_min)
	_ok("son axe est brise, pas droit", m.caves[0].points() >= 3,
			"%d points" % m.caves[0].points())

	# La section respire : le rayon n'est pas constant le long de l'axe, sans
	# quoi la galerie reste le tuyau que le reproche visait.
	var c0: CWMesa.Cave = m.caves[0]
	var r_min: float = INF
	var r_max: float = 0.0
	for k in c0.points():
		r_min = minf(r_min, c0.radius_at(k))
		r_max = maxf(r_max, c0.radius_at(k))
	_ok("la section varie le long de la galerie", r_max > r_min * 1.15,
			"de %.1f a %.1f" % [r_min, r_max])
	var branches: int = 0
	for c in m.caves:
		if c.branch:
			branches += 1
	print("     grottes : %d galeries dont %d embranchements, la plus courte %.0f blocs, section %.1f a %.1f"
			% [m.caves.size(), branches, l_min, r_min, r_max])

	# Le tube est bien creux : au milieu, la colonne porte de l'air a la hauteur
	# du plancher, alors que le terrain, lui, est plus haut.
	@warning_ignore("integer_division")
	var mid: int = c0.points() / 2
	var q0: Vector2 = c0.point_at(mid)
	var creux: bool = g.generated_voxel(
			int(q0.x) - g.params.world_origin.x, int(c0.floor_at(mid)) + 1,
			int(q0.y) - g.params.world_origin.y) == CWPalette.AIR
	_ok("le tube est creux en son milieu", creux)


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
	# L'amplitude est desormais un argument, borne en blocs par
	# `CWBiome.fringe_amplitude` : ces deux mesures-ci veulent la frange la
	# plus large possible, donc le plafond.
	var plein := Vector2(CWBiome.DITHER_T, CWBiome.DITHER_H)
	var loin: int = 0
	for x in range(0, 60):
		for z in range(0, 60):
			if CWBiome.at_dithered(50.0, 0.45, 0.50, 0, x + 700, z + 800,
					plein) \
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
					x + 4000, z + 5000, plein) == CWBiome.DESERTS:
				deserts += 1
	var part_d: float = float(deserts) / float(total)
	_ok("sur le seuil, les deux biomes s'interpenetrent",
			part_d > 0.2 and part_d < 0.8, "%.3f de desert" % part_d)
	print("     ecotone : %.1f %% de desert exactement sur son seuil d'humidite"
			% (part_d * 100.0))

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
			if CWBiome.at_dithered(50.0, 0.80, CWBiome.DESERT_H, 0,
					x + 4000, z + 5000, Vector2.ZERO) \
					!= CWBiome.at(50.0, 0.80, CWBiome.DESERT_H, 0):
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
