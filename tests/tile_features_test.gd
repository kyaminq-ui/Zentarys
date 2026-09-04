extends RefCounted

## Verifications de la couche « elements de tuile » (jalon 1.6).
##
## Pilote par tests/worldgen_test.gd, qui tient le compte des verifications :
##   CWTileFeaturesTest.new().run(self)
## Separe uniquement pour garder la suite lisible — la couche a autant
## d'invariants a elle seule que le champ de base.

var _runner: Object


func run(runner: Object) -> void:
	_runner = runner
	_test_tile_features()


func _ok(label: String, condition: bool, detail: String = "") -> void:
	_runner._ok(label, condition, detail)


func _close(label: String, got: float, want: float, tol: float = 1e-9) -> void:
	_runner._close(label, got, want, tol)


func _test_tile_features() -> void:
	print("[elements de tuile]")
	var p := CWWorldParams.new()
	p.world_seed = 2024
	var f := CWTerrainField.new(p)
	var grid: CWTileFeatureGrid = f.features()
	@warning_ignore("integer_division")
	var zc: int = CWWorldParams.ZONE_GRID / 2

	# -- Structure de la grille ------------------------------------------------
	var zone: Array = grid.get_zone(zc, zc, f)
	_ok("une zone porte 64 elements", zone.size() == 64, "%d" % zone.size())
	_ok("grille memoisee (meme instance)", grid.get_zone(zc, zc, f) == zone)
	_ok("hors monde -> zone vide", grid.get_zone(-1, zc, f).is_empty())
	_ok("hors monde -> element nul", grid.get_feature(-1, 0, f) == null)

	# -- Le bourg : un seul par zone, sur la tuile du site ---------------------
	var site: CWRegionSite = f.sites().get_site(zc, zc)
	var towns: Array[CWTileFeature] = []
	for feat: CWTileFeature in zone:
		if feat.type == CWTileFeature.TYPE_TOWN:
			towns.append(feat)
	_ok("un bourg et un seul par zone", towns.size() == 1, "%d" % towns.size())
	if towns.size() == 1:
		var town: CWTileFeature = towns[0]
		_ok("le bourg est sur la tuile du site",
				CWWorldParams.tile_of(int(town.x)) == CWWorldParams.tile_of(site.x)
				and CWWorldParams.tile_of(int(town.z)) == CWWorldParams.tile_of(site.z))
		_ok("rayon du bourg dans [512, 711]",
				town.radius >= 512.0 and town.radius <= 711.0, "%f" % town.radius)
		_ok("le bourg emerge", town.height >= 0.0, "%f" % town.height)

	# -- Chaque element tient dans sa tuile, avec sa marge --------------------
	var escaped: int = 0
	var typed: int = 0
	var zone_x: int = zc * CWWorldParams.ZONE_SIZE
	var zone_z: int = zc * CWWorldParams.ZONE_SIZE
	for tx in 8:
		for tz in 8:
			var feat: CWTileFeature = zone[tz + tx * 8]
			if feat.type == 0:
				continue
			typed += 1
			var x0: float = float(zone_x + tx * CWTileFeatureGrid.TILE_SIZE)
			var z0: float = float(zone_z + tz * CWTileFeatureGrid.TILE_SIZE)
			var span: float = float(CWTileFeatureGrid.TILE_SIZE)
			if feat.x < x0 or feat.x > x0 + span or feat.z < z0 or feat.z > z0 + span:
				escaped += 1
	_ok("chaque element reste dans sa tuile", escaped == 0, "%d debordent" % escaped)
	_ok("la zone centrale est peuplee", typed > 8, "%d elements types" % typed)

	# -- Adressage : l'element rendu pour un point est bien celui de sa tuile --
	var addressing_ok: bool = true
	for tx in 8:
		for tz in 8:
			var x: int = zone_x + tx * CWTileFeatureGrid.TILE_SIZE + 17
			var z: int = zone_z + tz * CWTileFeatureGrid.TILE_SIZE + 3
			if f.feature_at(x, z) != zone[tz + tx * 8]:
				addressing_ok = false
	_ok("adressage tuile -> element", addressing_ok)

	# -- Poids d'influence ----------------------------------------------------
	# Au centre exact d'un element non deforme (types 11, 12, 14), le poids
	# vaut 0 ; a une distance d'un rayon, il vaut 1.
	var flat: CWTileFeature = null
	for feat: CWTileFeature in zone:
		if feat.type in CWTileFeature.UNWARPED_TYPES:
			flat = feat
			break
	if flat != null:
		_close("poids nul au centre", f.falloff_weight(flat, int(flat.x), int(flat.z)),
				0.0, 1e-6)
		_close("poids unite au bord",
				f.falloff_weight(flat, int(flat.x + flat.radius), int(flat.z)), 1.0, 1e-3)
	else:
		_ok("un element non deforme dans la zone centrale", false,
				"aucun type 11, 12 ou 14")

	# -- Champ de routes ------------------------------------------------------
	if towns.size() == 1:
		var town: CWTileFeature = towns[0]
		# Le type 1 passe par la deformation du domaine : le maximum du champ
		# n'est pas au centre geometrique du bourg mais a une centaine d'unites
		# de la, la ou le point deforme retombe sur le centre. On verifie donc
		# qu'il est proche de 1 au centre, et qu'il atteint 1 quelque part.
		var at_centre: float = f.road_field(int(town.x), int(town.z))
		_ok("champ de routes eleve au centre du bourg", at_centre > 0.8,
				"%f" % at_centre)
		var peak: float = 0.0
		for i in range(-6, 7):
			for j in range(-6, 7):
				peak = maxf(peak, f.road_field(int(town.x) + i * 24,
						int(town.z) + j * 24))
		_close("champ de routes sature dans le bourg", peak, 1.0, 1e-3)
		var outside_x: int = int(town.x) + CWTileFeatureGrid.TILE_SIZE * 2
		_ok("champ de routes nul hors de la tuile du bourg",
				f.road_field(outside_x, int(town.z)) == 0.0)

	# -- Reliefs locaux -------------------------------------------------------
	var pb := CWWorldParams.new()
	pb.world_seed = p.world_seed
	pb.tile_features = false
	var fb := CWTerrainField.new(pb)

	var crater: CWTileFeature = _find_type(grid, f, zc, CWTileFeature.TYPE_CRATER)
	if crater != null:
		# Le poids d'influence est deforme : le fond n'est pas au centre
		# geometrique. On balaie le disque interieur, ou la formule du cratere
		# remplace le terrain de bout en bout, et on verifie ses deux bornes :
		# hauteur - 50 au point le plus creux, hauteur - 25 au bord du disque.
		var lo: float = INF
		var hi: float = -INF
		for i in range(-10, 11):
			for j in range(-10, 11):
				var h: float = f.height_at(int(crater.x) + i * 15,
						int(crater.z) + j * 15)
				lo = minf(lo, h)
				hi = maxf(hi, h)
		_close("cratere : fond a hauteur - 50", lo, crater.height - 50.0, 1.0)
		_ok("cratere : jamais sous hauteur - 50", lo >= crater.height - 50.5,
				"%.2f contre %.2f" % [lo, crater.height - 50.0])
		_ok("cratere : bord au plus haut a hauteur - 25",
				hi <= crater.height - 24.5, "%.2f contre %.2f"
				% [hi, crater.height - 25.0])
		var raw: float = fb.height_at(int(crater.x), int(crater.z))
		var centre: float = f.height_at(int(crater.x), int(crater.z))
		_ok("cratere : le fond descend sous le terrain d'origine", centre < raw,
				"%.1f contre %.1f" % [centre, raw])
	else:
		print("     (aucun cratere dans la zone centrale, verification sautee)")

	var caldera: CWTileFeature = _find_type(grid, f, zc, CWTileFeature.TYPE_CALDERA_A)
	if caldera == null:
		caldera = _find_type(grid, f, zc, CWTileFeature.TYPE_CALDERA_B)
	if caldera != null:
		# La caldeira creuse, mais l'original la borne a l'altitude de base du
		# site : elle ne perce jamais sous le socle regional.
		var floor_h: float = f.height_at(int(caldera.x), int(caldera.z))
		_ok("caldeira : plancher borne par le socle du site",
				floor_h >= float(site.base_height) - 0.5,
				"%.1f contre socle %d" % [floor_h, site.base_height])
	else:
		print("     (aucune caldeira dans la zone centrale, verification sautee)")

	# -- La bascule rend exactement le champ de base ---------------------------
	var drift: int = 0
	var far: int = zone_x - CWWorldParams.ZONE_SIZE * 3
	for i in 200:
		var x: int = far + i * 71
		var z: int = far + i * 97
		if f.feature_at(x, z) != null and f.feature_at(x, z).affects_height():
			continue
		if absf(f.height_at(x, z) - fb.height_at(x, z)) > 1e-9:
			drift += 1
	_ok("hors influence, le champ est inchange", drift == 0,
			"%d colonnes derivent" % drift)

	# -- Pas de couture : balayage dense a travers un element ------------------
	# Meme raison que pour le champ de base : les bords des masques d'influence
	# sont exactement le genre d'endroit ou une discontinuite d'une colonne de
	# large peut apparaitre sans qu'aucun test clairseme la voie.
	var probe: CWTileFeature = crater if crater != null else towns[0]
	var seam_worst: float = 0.0
	var seam_count: int = 0
	var seam_at: int = 0
	var zline: int = int(probe.z)
	var x_from: int = int(probe.x - probe.radius) - 200
	var prev: float = f.height_at(x_from - 1, zline)
	for i in range(0, int(probe.radius) * 2 + 400):
		var x: int = x_from + i
		var h: float = f.height_at(x, zline)
		var d: float = absf(h - prev)
		prev = h
		if d > seam_worst:
			seam_worst = d
			seam_at = x
		if d > 1.5:
			seam_count += 1
	_ok("aucune couture au bord d'un element", seam_count == 0,
			"%d colonnes sautent de plus de 1.5 bloc (pire %.2f en x=%d)"
			% [seam_count, seam_worst, seam_at])
	print("     balayage dense sur un element de type %d : saut max %.2f bloc"
			% [probe.type, seam_worst])

	# -- Determinisme, y compris depuis plusieurs fils -------------------------
	# La grille se construit paresseusement pendant que les fils de generation
	# echantillonnent : si un fil voyait une zone a moitie construite, il figerait
	# des colonnes sans deformation dans le cache de hauteurs. Le garde de
	# reentrance et l'attente des autres fils sont ce que verifie ce test.
	var refs := PackedFloat64Array()
	var xs := PackedInt64Array()
	var zs := PackedInt64Array()
	for i in 300:
		var x: int = zone_x + 512 + i * 53
		var z: int = zone_z + 512 + i * 37
		xs.append(x)
		zs.append(z)
		refs.append(f.height_at(x, z))
	var fresh := CWTerrainField.new(p)
	var mismatches: Array[int] = [0]
	var threads: Array[Thread] = []
	for t in 8:
		var th := Thread.new()
		th.start(func() -> void:
			var local: int = 0
			for i in refs.size():
				if absf(fresh.height_at(xs[i], zs[i]) - refs[i]) > 1e-9:
					local += 1
			mismatches[0] += local)
		threads.append(th)
	for th in threads:
		th.wait_to_finish()
	_ok("meme monde depuis huit fils concurrents", mismatches[0] == 0,
			"%d ecarts" % mismatches[0])

	# -- Fonctions auxiliaires portees ----------------------------------------
	_ok("palier 1 au centre de la carte", CWTileFeatureGrid.feature_tier(zc, zc) == 1)
	_ok("palier croissant avec la distance",
			CWTileFeatureGrid.feature_tier(zc + 40, zc)
			> CWTileFeatureGrid.feature_tier(zc + 4, zc))

	var s := CWRegionSite.new()
	s.temperature = 0.5
	s.humidity = 0.5
	_ok("nombre d'elements : climat tempere",
			CWTileFeatureGrid.feature_count_range(s) == Vector2i(1, 10))
	s.humidity = 0.1
	_ok("nombre d'elements : desert",
			CWTileFeatureGrid.feature_count_range(s) == Vector2i(10, 20))
	s.humidity = 0.9
	s.temperature = 0.1
	_ok("nombre d'elements : froid et humide",
			CWTileFeatureGrid.feature_count_range(s) == Vector2i(15, 25))
	s.wet = true
	_ok("nombre d'elements : marais",
			CWTileFeatureGrid.feature_count_range(s) == Vector2i(20, 30))


func _find_type(grid: CWTileFeatureGrid, f: CWTerrainField, zc: int,
		type: int) -> CWTileFeature:
	# Elargit la recherche aux zones voisines : un type donne n'est pas garanti
	# present dans une zone en particulier.
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for feat: CWTileFeature in grid.get_zone(zc + dx, zc + dz, f):
				if feat.type == type:
					return feat
	return null
