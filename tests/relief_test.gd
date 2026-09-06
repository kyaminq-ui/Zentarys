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

	# -- **Deformee**, et c'est ce qui se mesure (2026-09-09) -----------------
	#
	# Le contrat d'escalade est retire : la demande est *plus abstrait, plus
	# exagere dans la deformation, ne plus tenir compte de l'escalade du
	# personnage*. Une marche de dix blocs n'est donc plus un defaut, c'est le
	# but, et la verification qui la refusait est retiree avec elle.
	#
	# Ce qui la remplace mesure la chose qu'on a demandee : **la silhouette
	# n'est plus un cercle**. On balaie la masse en croix sur vingt-quatre
	# rayons, on releve la distance a laquelle son contour se trouve dans
	# chacun, et on compare la plus grande a la plus petite. Un dome rendrait un
	# rapport voisin de 1 ; l'allongement, la deformation du domaine et les
	# lobes doivent le porter bien au-dela.
	#
	# La marche, elle, reste **relevee et imprimee** — c'est ce qui dit de quoi
	# la masse a l'air —, et bornee par la seule chose qui reste vraie : une
	# masse ne peut pas faire une marche plus haute qu'elle.
	var pire_marche: int = 0
	var ou: String = ""
	var contours: Array[float] = []
	for a in range(0, 24):
		var ang: float = float(a) * TAU / 24.0
		var prev: int = 0
		var dans: bool = false
		var contour: float = 0.0
		for d in range(int(m.reach()) + 2, -1, -1):
			var px: int = int(m.x + cos(ang) * float(d))
			var pz: int = int(m.z + sin(ang) * float(d))
			var sol: int = floori(f.sample_column(px, pz).x)
			var sl: Vector2i = m.slab(px, pz, sol)
			var h: int = maxi(sl.y, sol) if sl.y >= sl.x else sol
			if sl.y >= sl.x and contour == 0.0:
				# La plus grande distance a laquelle la masse existe encore
				# dans cette direction : c'est son contour.
				contour = float(d)
			# Le **porche** d'une grotte est un surplomb voulu : il souleve le
			# dessous de la masse, donc il fait sauter la colonne. Il ne barre
			# aucun chemin — on en fait le tour en trois pas — et il n'a rien a
			# faire dans une mesure de silhouette.
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
		if contour > 0.0:
			contours.append(contour)
	_ok("le contour est trouve dans la plupart des directions",
			contours.size() >= 16, "%d sur 24" % contours.size())
	var proche: float = INF
	var lointain: float = 0.0
	for c in contours:
		proche = minf(proche, c)
		lointain = maxf(lointain, c)
	# **Un cercle rendrait 1.** On demande la moitie en plus, ce qui n'est pas
	# atteignable par le seul bruit de peau (0,10 du rayon au plus) : il faut
	# que l'allongement, le warp ou les lobes aient travaille.
	_ok("la silhouette n'est pas un cercle",
			contours.size() >= 16 and lointain > proche * 1.5,
			"contour de %.0f a %.0f blocs" % [proche, lointain])
	# La seule borne qui reste : une masse ne fait pas une marche plus haute
	# qu'elle. Elle n'est pas la pour garder une pente, elle est la pour
	# attraper une forme partie en vrille.
	_ok("aucune marche plus haute que la masse elle-meme",
			pire_marche <= ceili(m.height) + 2,
			"%d blocs en %s, hauteur %.0f" % [pire_marche, ou, m.height])
	print("     massif : %s" % str(m))
	print("       contour de %.0f a %.0f blocs (rapport %.2f), plus grande marche %d"
			% [proche, lointain, lointain / maxf(1.0, proche), pire_marche])

	_caracteres(f)

	# Le generateur et la requete ponctuelle doivent decrire le meme surplomb.
	# C'est l'invariant n. 18, exerce **la ou il y a quelque chose au-dessus du
	# sol** — le balayage du jalon 1.8 tombe sur un champ de hauteurs nu.
	_ok("bloc genere et requete ponctuelle s'accordent sur un massif",
			_accord(f, int(m.x), int(m.z)))


## Le caractere varie d'un massif a l'autre, et l'eventail est celui du tirage.
##
## Un seul massif ne peut pas montrer ca : il faut un echantillon. On balaie
## donc les cellules autour du depart et on releve ce que chaque masse a tire.
##
## **Ce qui se verifie a change de nature le 2026-09-09.** Il y avait deux
## moities : *un eventail existe* et *aucune masse ne sort du contrat
## d'escalade*. La seconde n'a plus d'objet — le contrat est retire, et le
## rabattement qu'elle gardait avec lui. Reste la premiere, elargie aux trois
## leviers qui font qu'une masse n'est pas un dome : l'**exposant de profil**,
## l'**allongement** et les **gradins**. Sans eventail sur ces trois-la, le
## tirage par massif ne sert a rien et le paysage est regulier.
func _caracteres(f: CWTerrainField) -> void:
	var o: Vector2i = f.params().world_origin
	var vus: Array[CWMesa] = []
	# Douze cellules de cote suffisent : elles rendent une quarantaine de masses,
	# assez pour un eventail, et chaque cellule de plus echantillonne le terrain.
	for i in range(0, 12):
		for j in range(0, 12):
			var cx: int = CWMesaGrid.cell_of(o.x) + i - 6
			var cz: int = CWMesaGrid.cell_of(o.y) + j - 6
			for m in f.mesas().get_cell(cx, cz, f):
				vus.append(m)
	_ok("de quoi juger l'eventail des caracteres", vus.size() >= 12,
			"%d massifs" % vus.size())
	if vus.size() < 12:
		return

	var p_bas: float = INF
	var p_haut: float = 0.0
	var w_bas: float = INF
	var w_haut: float = 0.0
	var a_haut: float = 0.0
	var gradins: int = 0
	var buttes: int = 0
	for m in vus:
		p_bas = minf(p_bas, m.profile_pow)
		p_haut = maxf(p_haut, m.profile_pow)
		w_bas = minf(w_bas, m.amp_warp)
		w_haut = maxf(w_haut, m.amp_warp)
		a_haut = maxf(a_haut, m.stretch)
		if m.strata >= 1.0:
			gradins += 1
		# Un exposant sous 1 aplatit le dessus et redresse les flancs : c'est
		# une butte a paroi, l'oppose exact d'un dome.
		if m.profile_pow < 1.0:
			buttes += 1
	print("     caracteres : %d massifs, warp de %.3f a %.3f, profil de %.2f a %.2f, allongement jusqu'a %.2f"
			% [vus.size(), w_bas, w_haut, p_bas, p_haut, a_haut])
	print("       %d a gradins, %d a paroi (profil < 1)" % [gradins, buttes])
	# Un eventail reel, et pas deux tirages qui se ressemblent.
	_ok("les massifs n'ont pas tous le meme grain", w_haut > w_bas * 1.5,
			"de %.3f a %.3f" % [w_bas, w_haut])
	# **Et la moitie de l'eventail n'est pas un dome.** C'est la demande du
	# 2026-09-09, exprimee sur l'echantillon : s'il n'y a pas de buttes a paroi
	# dans un paysage, l'exposant de profil ne sert a rien.
	_ok("des massifs ont un dessus plat et des flancs qui tombent",
			buttes * 5 >= vus.size(), "%d sur %d" % [buttes, vus.size()])
	_ok("des massifs montent par gradins", gradins * 5 >= vus.size(),
			"%d sur %d" % [gradins, vus.size()])
	_ok("l'allongement sort du cercle", a_haut > 1.2, "%.2f au plus" % a_haut)


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
	var levees: int = 0
	var pas_creuses: int = 0
	var somme_creux: int = 0
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
				-0x7FFFFFFF, span, CWTerrainField.free_water(prof, sea))
		vus += 1
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
					road, prof.x, -0x7FFFFFFF, span, libre)
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
	# -- L'alesage d'un tunnel est un cercle (2026-09-09) --------------------
	#
	# Le degagement rendait une hauteur constante sur toute la largeur du ruban :
	# une fente rectangulaire. Il rend maintenant la fleche d'une voute centree
	# sur l'axe, donc il **decroit** avec la distance a celui-ci et **deborde**
	# la chaussee des que le rayon depasse sa demi-largeur. Les trois
	# verifications qui suivent tiennent ces trois proprietes ; ce sont des
	# fonctions pures, on les exerce directement.
	var sous_terre: int = 60      # dessus de la chaussee
	var sous_masse: int = 60 + 40 # dessus d'une masse de quarante blocs
	var r: int = CWVoxelGenerator.tunnel_bore(sous_terre, sous_masse)
	_ok("sous une masse, l'alesage a un rayon",
			r >= CWPathNetwork.CLEARANCE, "%d blocs" % r)
	# Proportionnel a la masse : deux fois plus de roche, un alesage plus large.
	var r2: int = CWVoxelGenerator.tunnel_bore(sous_terre, 60 + 80)
	_ok("l'alesage est proportionnel a la masse traversee", r2 > r,
			"%d contre %d" % [r2, r])
	# Et il garde son toit : la voute ne coupe pas la masse en deux.
	_ok("l'alesage garde son toit",
			sous_terre + r <= sous_masse - CWPathNetwork.TUNNEL_ROOF_MIN,
			"voute a %d, dessus a %d" % [sous_terre + r, sous_masse])
	# La voute decroit du centre vers le piedroit, et elle deborde la chaussee.
	var axe: int = CWVoxelGenerator.tunnel_arch(sous_terre, sous_terre,
			sous_masse, 0.0)
	var bord: int = CWVoxelGenerator.tunnel_arch(sous_terre, sous_terre,
			sous_masse, CWPathNetwork.HALF_WIDTH)
	var dehors: int = CWVoxelGenerator.tunnel_arch(sous_terre, sous_terre,
			sous_masse, float(r) + 1.0)
	_ok("la voute est plus haute sur l'axe qu'au piedroit", axe > bord,
			"%d contre %d" % [axe, bord])
	_ok("la voute deborde la chaussee", bord > 0 and float(r)
			> CWPathNetwork.HALF_WIDTH, "rayon %d, demi-largeur %.1f"
			% [r, CWPathNetwork.HALF_WIDTH])
	_ok("et elle s'arrete a son rayon", dehors == 0, "%d" % dehors)
	# A ciel ouvert, rien de tout cela : pas de masse, pas d'alesage.
	_ok("a ciel ouvert, il n'y a pas d'alesage",
			CWVoxelGenerator.tunnel_bore(sous_terre, -0x7FFFFFFF) == 0)

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
