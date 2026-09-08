class_name CWOreTest
extends RefCounted

## Verifications de la couche des filons (jalon 2.6, l'apparition) : le lot
## d'assets, la table espece <-> modele, la dispersion et l'ecriture dans le
## terrain.
##
## Pilote par tests/worldgen_test.gd, qui tient le compte :
##   CWOreTest.new().run(self)
##
## **Emprise choisie pour ce qu'elle contient**, comme `CWLodTest.ORIGIN`
## (invariant n° 58) : `tools/find_ore.gd` montre qu'un filon affleure des le
## premier anneau de cellules autour du point de depart de la demo (graine
## 2024), sur le flanc qui porte aussi ses trois premiers arbres. `ORIGIN` vise
## ce flanc, pas un coin choisi au hasard qui n'a pas de falaise.
const ORIGIN: Vector2i = Vector2i(8396843, 8396629)

## Enveloppe d'un filon, en blocs. `generer_filons.FILON` dessine un
## affleurement de six blocs de haut et quatre de rayon ; la marge couvre
## l'irregularite du grignotage de bord (`_blocs_de_gangue`, `plein=0,78`).
const ENVELOPPE_HAUTEUR: int = 8
const ENVELOPPE_RAYON: int = 6

var _runner: Object


func run(runner: Object) -> void:
	_runner = runner
	_test_modeles()
	_test_especes()
	_test_dispersion()
	_test_matiere()


func _ok(label: String, condition: bool, detail: String = "") -> void:
	_runner._ok(label, condition, detail)


func _skip(label: String, why: String) -> void:
	print("  [saute] %s  (%s)" % [label, why])


# -- 1. Le lot d'assets -------------------------------------------------------

func _test_modeles() -> void:
	print("[modeles de filons]")
	var lib := CWModelLibrary.shared_ores()
	if not lib.has_any():
		_skip("enveloppe du lot de filons", "aucun modele charge")
		return

	var mauvaise_grille: Array = []
	var oversize: Array = []
	for ore in CWOreScatter.MODEL_OF:
		var path: String = CWOreScatter.MODEL_OF[ore]
		var m: CWVoxelModel = lib.model(path)
		if m == null:
			continue
		if not is_equal_approx(m.voxels_per_block, CWVoxelModel.VOXELS_PER_BLOCK_TERRAIN):
			mauvaise_grille.append(path)
		if m.height_blocks > ENVELOPPE_HAUTEUR or m.radius_blocks > ENVELOPPE_RAYON:
			oversize.append("%s %dx%d blocs" % [path, m.height_blocks, m.radius_blocks])
	_ok("le lot de filons est a un voxel par bloc", mauvaise_grille.is_empty(),
			str(mauvaise_grille))
	_ok("aucun filon ne depasse son enveloppe (%d h, %d r)"
			% [ENVELOPPE_HAUTEUR, ENVELOPPE_RAYON], oversize.is_empty(), str(oversize))

	# Chaque filon garde sa propre gangue de roche (index 1) en plus de sa veine :
	# c'est ce qui lui permet de se fondre dans la falaise au lieu de dessiner un
	# caillou pose dessus (voir `generer_filons.py`, en-tete).
	var sans_gangue: Array = []
	for ore in CWOreScatter.MODEL_OF:
		var path: String = CWOreScatter.MODEL_OF[ore]
		var m: CWVoxelModel = lib.model(path)
		if m == null:
			continue
		var v: PackedByteArray = m.values(0)
		var a_roche: bool = false
		var a_veine: bool = false
		for i in v.size():
			if v[i] == CWPalette.STONE:
				a_roche = true
			elif v[i] == ore:
				a_veine = true
		if not a_roche or not a_veine:
			sans_gangue.append("%s : roche=%s veine=%s" % [path, a_roche, a_veine])
	_ok("chaque filon porte sa gangue de roche et sa veine", sans_gangue.is_empty(),
			str(sans_gangue))


# -- 2. La table des especes ---------------------------------------------------

func _test_especes() -> void:
	print("[especes de filons]")
	var manquants: Array = []
	for ore in range(CWPalette.ORE_BEGIN, CWPalette.ORE_END + 1):
		if not CWOreScatter.MODEL_OF.has(ore):
			manquants.append(CWPalette.name_of(ore))
	_ok("les neuf filons ont un modele", manquants.is_empty(), str(manquants))

	# Le tirage de rarete (`CWPalette.roll_ore`) ne rend jamais gres ni cristal
	# de glace (docs/systems/02, §5.4) : c'est ce que `ESPECE_PAR_BIOME` referme,
	# et c'est la seule route qui les pose.
	_ok("le desert force le gres", CWOreScatter.ESPECE_PAR_BIOME.get(
			CWBiome.DESERTS, -1) == CWPalette.ORE_SANDSTONE)
	_ok("Snowlands force le cristal de glace", CWOreScatter.ESPECE_PAR_BIOME.get(
			CWBiome.SNOWLANDS, -1) == CWPalette.ORE_ICE_CRYSTAL)
	var jamais_tires := [CWPalette.ORE_SANDSTONE, CWPalette.ORE_ICE_CRYSTAL]
	for ore in jamais_tires:
		_ok("%s n'est pas dans le tirage de rarete, donc force par biome"
				% CWPalette.name_of(ore),
				CWOreScatter.ESPECE_PAR_BIOME.values().has(ore))


# -- 3. La dispersion ----------------------------------------------------------

func _test_dispersion() -> void:
	print("[dispersion des filons]")
	var p := CWWorldParams.new()
	p.world_seed = 2024
	var field := CWTerrainField.new(p)
	var scatter := CWOreScatter.new(field)

	_ok("la cellule de filons fait 64 blocs",
			scatter.cell_size == 64 and (1 << scatter.cell_shift) == 64,
			"%d / %d" % [scatter.cell_size, 1 << scatter.cell_shift])

	if not scatter.library().has_any():
		_skip("dispersion des filons", "aucun modele de filon charge")
		return

	# L'anneau de cellules autour du flanc trouve par `tools/find_ore.gd` :
	# assez large pour croiser plusieurs cellules et donc l'espacement entre
	# elles, pas assez pour que la suite ralentisse (chaque cellule paie
	# jusqu'a `CANDIDATS_PAR_CELLULE` pentes, voir l'en-tete de la couche).
	var origin := Vector2i(ORIGIN.x >> CWOreScatter.ORE_CELL_SHIFT,
			ORIGIN.y >> CWOreScatter.ORE_CELL_SHIFT)
	var cells: Array = []
	for dz in range(-4, 5):
		for dx in range(-4, 5):
			cells.append(Vector2i(origin.x + dx, origin.y + dz))

	var total: int = 0
	var placements: Array = []
	for c in cells:
		var list: Array = scatter.cell(c.x, c.y)
		total += list.size()
		placements.append_array(list)
	print("     %d cellules, %d filon(s)" % [cells.size(), total])
	if placements.is_empty():
		_skip("dispersion des filons", "aucun filon autour de CWOreTest.ORIGIN")
		return
	_ok("la dispersion pose des filons", total > 0, "%d" % total)

	# Deterministe, comme toute cellule de ce depot.
	var again := CWOreScatter.new(field)
	var a: Array = scatter.cell(origin.x, origin.y)
	var b: Array = again.cell(origin.x, origin.y)
	var identique: bool = a.size() == b.size()
	if identique:
		for i in a.size():
			if a[i].x != b[i].x or a[i].z != b[i].z or a[i].model != b[i].model:
				identique = false
				break
	_ok("deux dispersions du meme monde donnent la meme cellule", identique)

	# Chaque filon affleure vraiment : la matiere de son point d'ancrage, prise
	# **avec la pente** comme le fait le generateur, doit etre la roche de
	# falaise (invariant n° 27, la seule matiere hors biome).
	var sea: int = p.sea_level
	var pas_sur_roche: Array = []
	var noyes: int = 0
	for pl in placements:
		var col: Vector4 = field.sample_column_full(pl.x, pl.z)
		if col.x <= float(sea):
			noyes += 1
			continue
		var biome: int = CWBiome.at(col.x, col.y, col.z, sea)
		var slope: float = field.slope_at(pl.x, pl.z)
		var surface: int = CWPalette.surface_of(
				field.fringe_biome(pl.x, pl.z, col.x), col.x - float(sea),
				pl.x, pl.z, slope)
		if surface != CWPalette.STONE:
			pas_sur_roche.append("(%d,%d) : %s" % [pl.x, pl.z, CWPalette.name_of(surface)])
	_ok("aucun filon sous le niveau de la mer", noyes == 0, "%d" % noyes)
	_ok("tout filon affleure sur de la roche de pente", pas_sur_roche.is_empty(),
			str(pas_sur_roche.slice(0, 4)))

	# L'espacement minimum, y compris au travers des frontieres de cellule —
	# meme piege que pour les arbres (voir `CWTreeTest`).
	var d2: int = CWOreScatter.ESPACEMENT * CWOreScatter.ESPACEMENT
	var trop_proches: int = 0
	for i in placements.size():
		for j in range(i + 1, placements.size()):
			var dx: int = placements[i].x - placements[j].x
			var dz: int = placements[i].z - placements[j].z
			if dx * dx + dz * dz < d2:
				trop_proches += 1
	_ok("aucun couple de filons sous l'espacement minimum (%d blocs)"
			% CWOreScatter.ESPACEMENT, trop_proches == 0, "%d couple(s)" % trop_proches)

	# Repartition des especes, pour l'oeil : sans assertion chiffree, la table
	# de rarete est deja verrouillee par `tests/worldgen_test.gd` sur
	# `CWPalette.roll_ore` seul.
	var par_espece: Dictionary = {}
	for pl in placements:
		var nom: String = pl.model.name
		par_espece[nom] = int(par_espece.get(nom, 0)) + 1
	print("     especes : %s" % str(par_espece))


# -- 4. Le filon en matiere (invariant n° 18) ----------------------------------

func _test_matiere() -> void:
	print("[le filon en matiere]")
	var p := CWWorldParams.new()
	p.world_seed = 2024
	var g := CWVoxelGenerator.new()
	g.params = p
	var scatter: CWOreScatter = g.ore_scatter_grid()
	if not scatter.library().has_any():
		_skip("le filon en matiere", "aucun modele de filon charge")
		return

	var origin := Vector2i(ORIGIN.x >> CWOreScatter.ORE_CELL_SHIFT,
			ORIGIN.y >> CWOreScatter.ORE_CELL_SHIFT)
	var placements: Array = []
	for dz in range(-4, 5):
		for dx in range(-4, 5):
			placements.append_array(scatter.cell(origin.x + dx, origin.y + dz))
	if placements.is_empty():
		_skip("le filon en matiere", "aucun filon autour de CWOreTest.ORIGIN")
		return
	print("     %d filon(s) autour de l'origine" % placements.size())

	# Autour d'un filon choisi, un bloc genere doit dire la meme chose que la
	# requete ponctuelle — l'invariant n° 18, deja tombe deux fois sur les
	# arbres (troncs le 2026-09-10, feuillage le 2026-09-11) faute de test.
	var pl: CWScatter.Placement = placements[0]
	var span: Vector2i = CWOreScatter.piece_span(pl)
	var wx0: int = pl.x - ENVELOPPE_RAYON
	var wz0: int = pl.z - ENVELOPPE_RAYON
	var taille: int = ENVELOPPE_RAYON * 2 + 1
	var y0: int = span.x - 2
	var hauteur: int = (span.y - span.x + 1) + 4

	var buf := VoxelBuffer.new()
	buf.create(taille, hauteur, taille)
	var scx0: int = wx0 - p.world_origin.x
	var scz0: int = wz0 - p.world_origin.y
	g._generate_block(buf, Vector3i(scx0, y0, scz0), 0)

	var desaccords: int = 0
	var essais: int = 0
	var filon_vu: bool = false
	for lz in taille:
		for lx in taille:
			for ly in hauteur:
				var attendu: int = buf.get_voxel(lx, ly, lz, CWPalette.CHANNEL_TYPE)
				var got: int = g.generated_voxel(scx0 + lx, y0 + ly, scz0 + lz)
				essais += 1
				if attendu != got:
					desaccords += 1
				if CWPalette.is_ore(attendu):
					filon_vu = true
	_ok("un filon a ete vu dans l'emprise sondee (%d points)" % essais, filon_vu)
	_ok("la requete ponctuelle dit la meme chose que le bloc genere, autour d'un filon",
			desaccords == 0, "%d/%d points" % [desaccords, essais])
