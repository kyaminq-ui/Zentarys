extends SceneTree

## Validation du systeme de generation de terrain, sans moteur de rendu.
##
##   godot --headless --path . -s tests/worldgen_test.gd
##
## Deux roles :
##   1. verrouiller les invariants numeriques portes depuis le binaire (le
##      hachage du bruit et le LCG sont des references : s'ils bougent, tous les
##      mondes deja generes changent) ;
##   2. sortir des apercus PNG (altitude, climat, chenaux) dans user:// pour la
##      validation visuelle de la phase 4.

const PREVIEW_RES: int = 256
const PREVIEW_STEP: int = 256  # unites monde par pixel -> 65536 u de cote

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	print("=== Zentarys : validation worldgen ===")
	_test_value_noise()
	_test_rand()
	_test_region_sites()
	_test_terrain_field()
	_test_tile_features()
	_test_generator()
	_test_decor()
	_test_flora()
	_test_trees()
	_test_edits()
	_test_light()
	_test_map()
	_test_palette()
	_bench()
	_write_previews()
	print("--- %d verifications, %d echec(s) ---" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _ok(label: String, condition: bool, detail: String = "") -> void:
	_checks += 1
	if condition:
		print("  [ok]   ", label)
	else:
		_failures += 1
		printerr("  [FAIL] ", label, "  ", detail)


func _close(label: String, got: float, want: float, tol: float = 1e-9) -> void:
	_ok(label, absf(got - want) <= tol, "obtenu %.17f, attendu %.17f" % [got, want])


# -- 1. Bruit de valeur -------------------------------------------------------

func _test_value_noise() -> void:
	print("[bruit de valeur]")
	# References calculees independamment sur l'arithmetique 32 bits du binaire.
	_close("lattice(0)", CWValueNoise.lattice(0), -0.27954507153481245, 1e-12)
	_close("lattice(1)", CWValueNoise.lattice(1), -0.6342021068558097, 1e-12)
	_close("lattice(57)", CWValueNoise.lattice(57), -0.5821403255686164, 1e-12)
	_close("lattice(12345)", CWValueNoise.lattice(12345), 0.5573478946462274, 1e-12)
	_close("lattice(-1)", CWValueNoise.lattice(-1), 0.2781454110518098, 1e-12)
	_close("sample(0.5, 0.5)", CWValueNoise.sample(0.5, 0.5), -0.5825526122935116, 1e-12)
	_close("sample(12.25, 7.75)", CWValueNoise.sample(12.25, 7.75), 0.4637036633340571, 1e-12)
	_close("sample(1000.125, 2000.875)", CWValueNoise.sample(1000.125, 2000.875),
			0.7093009498071512, 1e-12)

	var lo: float = INF
	var hi: float = -INF
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 20000:
		var v: float = CWValueNoise.sample(rng.randf_range(-5000.0, 5000.0),
				rng.randf_range(-5000.0, 5000.0))
		lo = minf(lo, v)
		hi = maxf(hi, v)
	_ok("domaine dans [-1, 1]", lo >= -1.0 and hi <= 1.0, "[%f, %f]" % [lo, hi])
	_ok("domaine effectivement large", hi - lo > 1.0, "amplitude %f" % (hi - lo))

	# Continuite : deux echantillons voisins ne peuvent pas sauter.
	var worst: float = 0.0
	for i in 2000:
		var x: float = rng.randf_range(-500.0, 500.0)
		var z: float = rng.randf_range(-500.0, 500.0)
		worst = maxf(worst, absf(CWValueNoise.sample(x, z)
				- CWValueNoise.sample(x + 0.001, z)))
	_ok("continu (pas de saut sur 0.001)", worst < 0.02, "ecart max %f" % worst)

	# Les noeuds entiers doivent redonner exactement la valeur du reseau.
	_close("interpolation exacte aux noeuds",
			CWValueNoise.sample(3.0, 4.0), CWValueNoise.lattice(3 + 4 * 57), 1e-12)


# -- 2. LCG de la CRT MSVC ----------------------------------------------------

func _test_rand() -> void:
	print("[rand MSVC]")
	var expected: Array[int] = [41, 18467, 6334, 26500, 19169,
			15724, 11478, 29358, 26962, 24464]
	var rng := CWRand.new(1)
	var got: Array[int] = []
	for i in expected.size():
		got.append(rng.next())
	_ok("sequence de reference pour srand(1)", got == expected, str(got))

	var a := CWRand.new(12345)
	var b := CWRand.new(12345)
	var same: bool = true
	for i in 100:
		if a.next() != b.next():
			same = false
	_ok("deterministe", same)

	var r := CWRand.new(99)
	var out_of_range: bool = false
	for i in 5000:
		var u: float = r.unit()
		if u < 0.0 or u > 1.0:
			out_of_range = true
	_ok("unit() dans [0, 1]", not out_of_range)


# -- 3. Sites de region -------------------------------------------------------

func _test_region_sites() -> void:
	print("[sites de region]")
	var p := CWWorldParams.new()
	p.world_seed = 2024
	var grid := CWRegionSiteGrid.new(p)

	_ok("hors grille -> null", grid.get_site(-1, 0) == null and grid.get_site(1024, 5) == null)

	var s1: CWRegionSite = grid.get_site(300, 400)
	var s2: CWRegionSite = CWRegionSiteGrid.new(p).get_site(300, 400)
	_ok("deterministe entre deux grilles",
			s1.x == s2.x and s1.z == s2.z and s1.base_height == s2.base_height
			and is_equal_approx(s1.temperature, s2.temperature))
	_ok("memoise (meme instance)", grid.get_site(300, 400) == s1)

	var bad_pos: int = 0
	var bad_clim: int = 0
	var bad_snap: int = 0
	var land: int = 0
	var wet: int = 0
	var total: int = 0
	var h_lo: int = 1 << 30
	var h_hi: int = -(1 << 30)
	for rx in range(200, 240):
		for rz in range(200, 240):
			var s: CWRegionSite = grid.get_site(rx, rz)
			total += 1
			var zx: int = CWWorldParams.zone_of(s.x)
			var zz: int = CWWorldParams.zone_of(s.z)
			if zx != rx or zz != rz:
				bad_pos += 1
			if s.temperature < 0.0 or s.temperature > 1.0 \
					or s.humidity < 0.0 or s.humidity > 1.0:
				bad_clim += 1
			if s.x % CWWorldParams.TILE_SIZE != CWWorldParams.TILE_SIZE / 2 \
					or s.z % CWWorldParams.TILE_SIZE != CWWorldParams.TILE_SIZE / 2:
				bad_snap += 1
			if s.base_height > 0:
				land += 1
			if s.wet:
				wet += 1
			h_lo = mini(h_lo, s.base_height)
			h_hi = maxi(h_hi, s.base_height)

	_ok("site contenu dans sa propre zone", bad_pos == 0, "%d ecarts" % bad_pos)
	_ok("climat dans [0, 1]", bad_clim == 0, "%d ecarts" % bad_clim)
	_ok("position calee au centre de tuile", bad_snap == 0, "%d ecarts" % bad_snap)
	_ok("plancher oceanique a -100", h_lo >= -100, "min %d" % h_lo)
	_ok("terre et ocean coexistent", land > 0 and land < total,
			"%d/%d terrestres, %d marais, altitudes [%d, %d]" % [land, total, wet, h_lo, h_hi])
	print("     terre %d/%d, marais %d, altitude de base [%d, %d]"
			% [land, total, wet, h_lo, h_hi])

	# La zone de depart est forcee tempéree et emergee.
	var start := p.start_point
	var ss: CWRegionSite = grid.get_site(CWWorldParams.zone_of(start.x),
			CWWorldParams.zone_of(start.y))
	_ok("site de depart pose sur le point de depart",
			ss.x == CWRegionSiteGrid._snap_to_tile_centre(start.x)
			and ss.z == CWRegionSiteGrid._snap_to_tile_centre(start.y))
	_ok("site de depart emerge", ss.base_height > 0, "altitude %d" % ss.base_height)
	_ok("site de depart tempere", ss.temperature >= 0.3 and ss.temperature <= 0.7,
			"T %f" % ss.temperature)


# -- 4. Champ de terrain ------------------------------------------------------

func _test_terrain_field() -> void:
	print("[champ de terrain]")
	var p := CWWorldParams.new()
	p.world_seed = 2024
	var f := CWTerrainField.new(p)
	var o := p.world_origin

	var bad: int = 0
	var h_lo: float = INF
	var h_hi: float = -INF
	var t_bad: int = 0
	var under: int = 0
	var total: int = 0
	for i in 64:
		for j in 64:
			var c: Vector3 = f.sample_column(o.x + i * 512, o.y + j * 512)
			total += 1
			if not is_finite(c.x):
				bad += 1
			if c.y < 0.0 or c.y > 1.0 or c.z < 0.0 or c.z > 1.0:
				t_bad += 1
			if c.x < float(p.sea_level):
				under += 1
			h_lo = minf(h_lo, c.x)
			h_hi = maxf(h_hi, c.x)
	_ok("altitude finie partout", bad == 0, "%d NaN/inf" % bad)
	_ok("climat dans [0, 1]", t_bad == 0, "%d ecarts" % t_bad)
	_ok("relief avec du denivele", h_hi - h_lo > 50.0, "[%f, %f]" % [h_lo, h_hi])
	_ok("mers et terres coexistent", under > 0 and under < total,
			"%d/%d colonnes sous le niveau de la mer" % [under, total])
	print("     altitude [%.1f, %.1f], %d/%d colonnes immergees"
			% [h_lo, h_hi, under, total])

	# Continuite : pas de falaise absurde entre deux blocs adjacents.
	var worst: float = 0.0
	for i in 400:
		var x: int = o.x + i * 37
		var z: int = o.y + i * 53
		var a: float = f.sample_column(x, z).x
		var b: float = f.sample_column(x + 1, z).x
		worst = maxf(worst, absf(a - b))
	_ok("continu d'un bloc au suivant", worst < 8.0, "denivele max %.3f" % worst)

	# Coutures : un balayage clairseme rate les artefacts d'une seule colonne de
	# large. Celui-ci est dense, et c'est le seul moyen de voir revenir la
	# tranchee que creusaient les termes lies aux aretes du graphe de sites
	# (bande de moins d'un bloc, donc invisible a tout autre pas).
	var seam_worst: float = 0.0
	var seam_at: int = 0
	var seam_count: int = 0
	var zs: int = o.y + 400
	var prev: float = f.sample_column(o.x - 1500, zs).x
	for i in range(-1499, 1500):
		var h: float = f.sample_column(o.x + i, zs).x
		var d: float = absf(h - prev)
		prev = h
		if d > seam_worst:
			seam_worst = d
			seam_at = o.x + i
		if d > 1.5:
			seam_count += 1
	_ok("aucune couture d'une colonne de large", seam_count == 0,
			"%d colonnes sautent de plus de 1.5 bloc (pire %.2f en x=%d)"
			% [seam_count, seam_worst, seam_at])
	print("     balayage dense : saut max %.2f bloc en x=%d" % [seam_worst, seam_at])

	# Determinisme entre deux instances.
	var f2 := CWTerrainField.new(p)
	var identical: bool = true
	for i in 50:
		var x: int = o.x + i * 911
		var z: int = o.y + i * 733
		if not is_equal_approx(f.sample_column(x, z).x, f2.sample_column(x, z).x):
			identical = false
	_ok("deterministe entre deux instances", identical)

	# Graines differentes -> mondes differents.
	var p3 := CWWorldParams.new()
	p3.world_seed = 777
	var f3 := CWTerrainField.new(p3)
	var diff: int = 0
	for i in 50:
		var x: int = o.x + i * 911
		var z: int = o.y + i * 733
		if absf(f.sample_column(x, z).x - f3.sample_column(x, z).x) > 0.5:
			diff += 1
	_ok("la graine change le monde", diff > 40, "%d/50 colonnes differentes" % diff)

	# Le champ de chenaux doit descendre pres de zero quelque part.
	var c_lo: float = INF
	var c_hi: float = -INF
	for i in 200:
		var v: float = f.channel_field(o.x + i * 97, o.y + i * 131)
		c_lo = minf(c_lo, v)
		c_hi = maxf(c_hi, v)
	_ok("champ de chenaux positif", c_lo >= 0.0, "min %f" % c_lo)
	_ok("champ de chenaux module", c_hi > 0.25, "[%f, %f]" % [c_lo, c_hi])


# -- 4b. Elements de tuile ----------------------------------------------------

const CWTileFeaturesTest := preload("res://tests/tile_features_test.gd")


func _test_tile_features() -> void:
	CWTileFeaturesTest.new().run(self)


func _test_decor() -> void:
	CWDecorTest.new().run(self)


func _test_flora() -> void:
	CWFloraTest.new().run(self)


func _test_trees() -> void:
	CWTreeTest.new().run(self)


func _test_edits() -> void:
	CWEditTest.new().run(self)


func _test_light() -> void:
	CWLightTest.new().run(self)


func _test_map() -> void:
	CWMapTest.new().run(self)


# -- 5. Generateur voxel : cache de colonnes et arret -------------------------

func _test_generator() -> void:
	print("[generateur voxel]")
	var p := CWWorldParams.new()
	p.world_seed = 2024
	var g := CWVoxelGenerator.new()
	g.params = p

	var buf := VoxelBuffer.new()
	buf.create(16, 16, 16)
	var ground: int = roundi(g.field().sample_column(p.world_origin.x, p.world_origin.y).x)
	var oy: int = (ground / 16) * 16

	# Premier bloc d'une colonne : plein tarif.
	var t0: int = Time.get_ticks_usec()
	g._generate_block(buf, Vector3i(0, oy, 0), 0)
	var cold: int = Time.get_ticks_usec() - t0

	var counts := _count_values(buf)
	_ok("le bloc de surface contient du solide et de l'air",
			counts.get(0, 0) > 0 and counts.size() > 1, str(counts))

	# Les blocs suivants de la meme colonne (x, z) doivent reutiliser la carte
	# de hauteurs. C'est ce qui rend un monde de mille blocs de haut praticable.
	var t1: int = Time.get_ticks_usec()
	for k in 8:
		g._generate_block(buf, Vector3i(0, oy - 16 * (k + 1), 0), 0)
	var warm: int = (Time.get_ticks_usec() - t1) / 8
	_ok("cache de colonnes efficace", warm * 5 < cold,
			"a froid %d us, a chaud %d us" % [cold, warm])
	print("     bloc a froid %d us, bloc mis en cache %d us (x%.1f)"
			% [cold, warm, float(cold) / maxf(float(warm), 1.0)])

	# Une origine (x, z) differente doit bien repasser au plein tarif : sinon
	# le cache renverrait la carte du voisin.
	var t2: int = Time.get_ticks_usec()
	g._generate_block(buf, Vector3i(4096, oy, 4096), 0)
	var other: int = Time.get_ticks_usec() - t2
	_ok("le cache est bien indexe par (x, z)", other * 3 > cold,
			"autre colonne %d us vs %d us a froid" % [other, cold])

	# Arret : les taches encore en file doivent devenir gratuites.
	g.request_shutdown()
	_ok("etat d'arret expose", g.is_shutting_down())
	var t3: int = Time.get_ticks_usec()
	for k in 16:
		g._generate_block(buf, Vector3i(128 * k, oy, 128 * k), 0)
	var stopping: int = (Time.get_ticks_usec() - t3) / 16
	_ok("un bloc genere apres l'arret est quasi gratuit", stopping * 20 < cold,
			"%d us contre %d us" % [stopping, cold])
	var after := _count_values(buf)
	_ok("un bloc genere apres l'arret est vide",
			after.size() == 1 and after.has(CWPalette.AIR), str(after))
	print("     bloc apres demande d'arret %d us (contre %d us)" % [stopping, cold])


func _count_values(buf: VoxelBuffer) -> Dictionary:
	var counts := {}
	var s := buf.get_size()
	for y in s.y:
		for z in s.z:
			for x in s.x:
				var v: int = buf.get_voxel(x, y, z, CWPalette.CHANNEL_TYPE)
				counts[v] = counts.get(v, 0) + 1
	return counts


# -- 6. Palette de projet -----------------------------------------------------

func _test_palette() -> void:
	print("[palette]")
	var c: PackedColorArray = CWPalette.colors()
	_ok("256 entrees", c.size() == 256, "%d" % c.size())
	_ok("index 0 transparent (le mailleur le traite comme du vide)",
			c[CWPalette.AIR].a == 0.0)

	# Le decoupage en plages est un contrat avec les assets deja peints : une
	# plage qui bouge ou qui en chevauche une autre rend faux tout un lot de
	# modeles, en silence.
	var ranges: Array = [
		[CWPalette.RANGE_TERRAIN_BEGIN, CWPalette.RANGE_TERRAIN_END],
		[CWPalette.RANGE_CREATURES_BEGIN, CWPalette.RANGE_CREATURES_END],
		[CWPalette.RANGE_GEAR_BEGIN, CWPalette.RANGE_GEAR_END],
		[CWPalette.RANGE_FLORA_BEGIN, CWPalette.RANGE_FLORA_END],
		[CWPalette.RANGE_BUILD_BEGIN, CWPalette.RANGE_BUILD_END],
		[CWPalette.RANGE_FX_BEGIN, CWPalette.RANGE_FX_END],
	]
	var contiguous: bool = ranges[0][0] == 1
	for i in range(1, ranges.size()):
		if ranges[i][0] != ranges[i - 1][1] + 1:
			contiguous = false
	_ok("plages contigues, sans trou ni chevauchement, de 1 a 255",
			contiguous and ranges[-1][1] == 255, str(ranges))

	# Les blocs de terrain sont ecrits par le generateur : une entree effacee
	# rendrait des voxels invisibles.
	var undefined: Array[int] = []
	for i in CWPalette.COUNT:
		if i != CWPalette.AIR and c[i].a <= 0.0:
			undefined.append(i)
	_ok("tous les blocs de terrain ont une couleur", undefined.is_empty(),
			"index sans couleur : %s" % str(undefined))

	# Reserve de terrain 14-31. Elle n'est ecrite par aucun generateur, et elle
	# n'est pas decorative pour autant : c'est le seul endroit de la palette ou un
	# modele trouve du gris ou de l'ocre. Vide, tous les cailloux du lot de flore
	# se rabattent sur la meme entree.
	var terrain_holes: Array[int] = []
	for i in range(CWPalette.COUNT, CWPalette.RANGE_TERRAIN_END + 1):
		if c[i].a <= 0.0:
			terrain_holes.append(i)
	_ok("reserve de terrain renseignee (matiere des modeles mineraux)",
			terrain_holes.is_empty(), "index sans couleur : %s" % str(terrain_holes))

	var asset_holes: int = 0
	for i in range(CWPalette.RANGE_CREATURES_BEGIN, 256):
		if c[i].a <= 0.0 and not (i >= 228 and i <= 233):
			asset_holes += 1
	_ok("plages d'assets renseignees", asset_holes == 0, "%d trous" % asset_holes)

	# -- Les neuf filons (jalon 1.11) -----------------------------------------
	#
	# Ils ont fait bouger `RANGE_TERRAIN_END` de 31 a 40 le 2026-09-05. Ce qui
	# est verrouille ici, c'est ce dont depend la suite : qu'ils soient bien
	# **dans la plage terrain** (un filon est de la matiere, il s'estampe et il
	# se mine), qu'ils soient **consecutifs et alignes sur les codes d'entite
	# 131-139** de la source, et que leurs teintes se distinguent — neuf filons
	# de la meme couleur dans une paroi grise ne servent a rien.
	_ok("les neuf filons sont dans la plage terrain",
			CWPalette.ORE_BEGIN >= CWPalette.RANGE_TERRAIN_BEGIN
			and CWPalette.ORE_END <= CWPalette.RANGE_TERRAIN_END,
			"%d-%d dans %d-%d" % [CWPalette.ORE_BEGIN, CWPalette.ORE_END,
			CWPalette.RANGE_TERRAIN_BEGIN, CWPalette.RANGE_TERRAIN_END])
	_ok("neuf filons, exactement",
			CWPalette.ORE_END - CWPalette.ORE_BEGIN + 1 == 9)

	# `index = 32 + (code - 131)`. Ce sera le chemin le plus court le jour ou la
	# voie des entites sera portee : la table de rarete rend un rang, ce rang est
	# un code, ce code est un index.
	var mapping_ok: bool = true
	for code in range(CWPalette.ORE_CODE_BEGIN, CWPalette.ORE_CODE_BEGIN + 9):
		var idx: int = CWPalette.ore_of_code(code)
		if not CWPalette.is_ore(idx) or CWPalette.code_of_ore(idx) != code:
			mapping_ok = false
	_ok("code d'entite 131-139 <-> index de filon, aller-retour", mapping_ok)
	_ok("un code hors de la plage ne rend pas de filon",
			CWPalette.ore_of_code(CWPalette.ORE_CODE_BEGIN - 1) == CWPalette.AIR
			and CWPalette.ore_of_code(CWPalette.ORE_CODE_BEGIN + 9) == CWPalette.AIR
			and CWPalette.code_of_ore(CWPalette.STONE) == -1)

	var teintes: Dictionary = {}
	for i in range(CWPalette.ORE_BEGIN, CWPalette.ORE_END + 1):
		teintes[c[i]] = true
	_ok("les neuf filons ont neuf teintes distinctes", teintes.size() == 9,
			"%d teintes" % teintes.size())

	# La table de rarete de `docs/systems/02`, §5.4, portee verbatim. On la
	# deroule sur les 1 000 combinaisons possibles plutot que par tirage : le
	# resultat est exact, et il tombe sur les pourcentages annonces par l'analyse.
	var counts: Dictionary = {}
	for a in 10:
		for b in 100:
			var ore: int = CWPalette.roll_ore(a, b)
			counts[ore] = int(counts.get(ore, 0)) + 1
	var pct := func(ore: int) -> float:
		return 100.0 * float(counts.get(ore, 0)) / 1000.0
	print("     filons : fer %.1f %%, or %.1f %%, argent %.1f %%, emeraude %.1f %%, saphir %.1f %%, rubis %.1f %%, diamant %.1f %%"
			% [pct.call(CWPalette.ORE_IRON), pct.call(CWPalette.ORE_GOLD),
			pct.call(CWPalette.ORE_SILVER), pct.call(CWPalette.ORE_EMERALD),
			pct.call(CWPalette.ORE_SAPPHIRE), pct.call(CWPalette.ORE_RUBY),
			pct.call(CWPalette.ORE_DIAMOND)])
	_ok("rarete des filons conforme a la table de la source",
			is_equal_approx(pct.call(CWPalette.ORE_IRON), 70.0)
			and is_equal_approx(pct.call(CWPalette.ORE_GOLD), 10.0)
			and is_equal_approx(pct.call(CWPalette.ORE_SILVER), 10.0)
			and is_equal_approx(pct.call(CWPalette.ORE_EMERALD), 9.1)
			and is_equal_approx(pct.call(CWPalette.ORE_SAPPHIRE), 0.5)
			and is_equal_approx(pct.call(CWPalette.ORE_RUBY), 0.3)
			and is_equal_approx(pct.call(CWPalette.ORE_DIAMOND), 0.1), str(counts))

	# Les neuf modeles sur le disque, et rien que de la matiere de terrain
	# dedans : un filon peint en feuillage sortirait vert.
	var ore_dir: String = "res://assets/models/filons/"
	var ore_missing: Array = []
	for nom in ["or", "fer", "argent", "gres", "emeraude", "saphir", "rubis",
			"diamant", "cristal_de_glace"]:
		if not FileAccess.file_exists(ore_dir + nom + ".vox"):
			ore_missing.append(nom)
	_ok("les neuf modeles de filon sont sur le disque", ore_missing.is_empty(),
			str(ore_missing))

	var pal: Resource = CWPalette.build_voxel_palette()
	_ok("ressource VoxelColorPalette construite",
			pal != null and pal.colors.size() == 256)


# -- 7. Cout -----------------------------------------------------------------

func _bench() -> void:
	print("[cout]")
	var p := CWWorldParams.new()
	var f := CWTerrainField.new(p)
	var o := p.world_origin
	# Prechauffage du cache de sites.
	f.sample_column(o.x, o.y)
	var t0: int = Time.get_ticks_usec()
	var n: int = 16 * 16 * 8  # equivalent de huit blocs 16^3
	for i in n:
		f.sample_column(o.x + (i % 128), o.y + (i / 128))
	var dt: int = Time.get_ticks_usec() - t0
	print("     %d colonnes en %.1f ms  (%.1f us/colonne, ~%.1f ms/bloc 16^3)"
			% [n, dt / 1000.0, float(dt) / float(n), float(dt) / float(n) * 256.0 / 1000.0])
	_ok("cout par colonne raisonnable", float(dt) / float(n) < 400.0,
			"%.1f us/colonne" % (float(dt) / float(n)))


# -- 8. Apercus PNG ----------------------------------------------------------

func _write_previews() -> void:
	print("[apercus]")
	var p := CWWorldParams.new()
	p.world_seed = 2024
	var f := CWTerrainField.new(p)
	var o := p.world_origin
	var half: int = PREVIEW_RES * PREVIEW_STEP / 2

	var img_h := Image.create(PREVIEW_RES, PREVIEW_RES, false, Image.FORMAT_RGB8)
	var img_c := Image.create(PREVIEW_RES, PREVIEW_RES, false, Image.FORMAT_RGB8)
	var img_r := Image.create(PREVIEW_RES, PREVIEW_RES, false, Image.FORMAT_RGB8)

	var h_lo: float = INF
	var h_hi: float = -INF
	var cache := PackedFloat32Array()
	cache.resize(PREVIEW_RES * PREVIEW_RES)
	var k: int = 0
	for py in PREVIEW_RES:
		for px in PREVIEW_RES:
			var wx: int = o.x - half + px * PREVIEW_STEP
			var wz: int = o.y - half + py * PREVIEW_STEP
			var c: Vector3 = f.sample_column(wx, wz)
			cache[k] = c.x
			k += 1
			h_lo = minf(h_lo, c.x)
			h_hi = maxf(h_hi, c.x)
			img_c.set_pixel(px, py, Color(c.y, c.z, 0.25))
			var ch: float = clampf(f.channel_field(wx, wz) * 2.0, 0.0, 1.0)
			img_r.set_pixel(px, py, Color(ch, ch, ch))

	var span: float = maxf(h_hi - h_lo, 1.0)
	k = 0
	for py in PREVIEW_RES:
		for px in PREVIEW_RES:
			var h: float = cache[k]
			k += 1
			if h < float(p.sea_level):
				var d: float = clampf((float(p.sea_level) - h) / 120.0, 0.0, 1.0)
				img_h.set_pixel(px, py, Color(0.05, 0.25 - d * 0.15, 0.65 - d * 0.35))
			else:
				var t: float = (h - h_lo) / span
				img_h.set_pixel(px, py, Color(t, t * 0.92 + 0.05, t * 0.75))
	var dir: String = "user://worldgen_preview"
	DirAccess.make_dir_recursive_absolute(dir)
	img_h.save_png(dir + "/height.png")
	img_c.save_png(dir + "/climate.png")
	img_r.save_png(dir + "/channels.png")
	print("     altitude sur l'apercu : [%.1f, %.1f]" % [h_lo, h_hi])
	print("     ecrit dans ", ProjectSettings.globalize_path(dir))
	_ok("apercus ecrits", FileAccess.file_exists(dir + "/height.png"))
