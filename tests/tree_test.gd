class_name CWTreeTest
extends RefCounted

## Verifications de la couche des arbres (jalon 1.11) : le lot d'assets, la
## bibliotheque tenue a part, la dispersion a cellule large, l'espacement
## minimum et le montage en plusieurs pieces.
##
## Pilote par tests/worldgen_test.gd, qui tient le compte :
##   CWTreeTest.new().run(self)
##
## Ce fichier remplace le garde-fou provisoire qui vivait dans le generateur
## Python (`tools/blender/generer_arbres.py`, table `LOT`) : les enveloppes du
## lot sont desormais verifiees ici, sur les modeles charges, comme celles de la
## flore le sont dans `flora_test.gd`.

## Enveloppes par classe de modele, en voxels : (hauteur max, rayon max).
## Proposition de `docs/prompt_generation_arbres.md`, §1.1, verrouillee ici.
const ENV_ARBRE := Vector2i(160, 45)
const ENV_HOUPPIER := Vector2i(80, 45)
const ENV_PALME := Vector2i(60, 45)

## Les modeles qui ne sont pas des arbres entiers, et leur classe. Tout ce qui
## n'est pas cite est un arbre entier.
const CLASSES: Dictionary = {
	"herbe/houppier_01": ENV_HOUPPIER,
	"herbe/houppier_02": ENV_HOUPPIER,
	"herbe_seche/houppier_sec": ENV_HOUPPIER,
	"jungle/houppier_jungle": ENV_HOUPPIER,
	"jungle/palme": ENV_PALME,
	"jungle/palme_diagonale": ENV_PALME,
}

var _runner: Object


func run(runner: Object) -> void:
	_runner = runner
	_test_models()
	_test_rules()
	_test_scatter()


func _ok(label: String, condition: bool, detail: String = "") -> void:
	_runner._ok(label, condition, detail)


func _skip(label: String, why: String) -> void:
	print("  [saute] %s  (%s)" % [label, why])


# -- 1. Le lot d'assets -------------------------------------------------------

func _test_models() -> void:
	print("[modeles d'arbres]")
	var paths: Array = CWTreeRules.all_paths()
	var missing: Array = []
	for path in paths:
		if not FileAccess.file_exists(CWTreeRules.TREE_DIR + path + ".vox"):
			missing.append(path)
	_ok("tous les modeles de la table sont sur le disque (%d entrees)" % paths.size(),
			missing.is_empty(), str(missing))

	var lib := CWModelLibrary.shared_trees()
	if not lib.has_any():
		_skip("enveloppe du lot d'arbres", "aucun modele charge")
		return

	# Enveloppe par classe. Un houppier de 160 voxels ou une palme de 100 ne
	# casserait rien a l'execution — elle serait simplement rognee aux bordures
	# de cellule, ce qui se voit sans qu'on sache pourquoi.
	var oversize: Array = []
	for path in paths:
		var m: CWVoxelModel = lib.model(path)
		if m == null:
			continue
		var env: Vector2i = CLASSES.get(path, ENV_ARBRE)
		if m.height > env.x or m.radius > env.y:
			oversize.append("%s %dx%d > %dx%d" % [path, m.height, m.radius, env.x, env.y])
	_ok("aucun modele d'arbre hors de son enveloppe de classe",
			oversize.is_empty(), str(oversize))

	# Un houppier n'a pas de pied : sa base est une couronne, et elle sera posee
	# au sommet d'un tronc. Un houppier plus haut que large serait un arbre.
	var trop_haut: Array = []
	for path in CLASSES:
		if CLASSES[path] != ENV_HOUPPIER:
			continue
		var m: CWVoxelModel = lib.model(path)
		if m != null and m.height > 3 * m.radius:
			trop_haut.append(path)
	_ok("les houppiers sont des couronnes, pas des futs", trop_haut.is_empty(),
			str(trop_haut))

	# **L'invariant n° 17, cote arbres.** C'est la raison d'etre des deux
	# bibliotheques : un houppier range avec la flore ferait exploser la marge de
	# `placements_in` pour toute la flore. Les deux maxima doivent rester
	# separes, et l'ecart doit se voir.
	var flore := CWModelLibrary.shared()
	print("     rayon max : flore %d blocs, arbres %d blocs"
			% [flore.max_radius_blocks, lib.max_radius_blocks])
	_ok("la bibliotheque de la flore ignore les arbres",
			flore.max_radius_blocks <= 2,
			"rayon max de la flore : %d blocs" % flore.max_radius_blocks)
	_ok("la bibliotheque des arbres a son propre maximum",
			lib.max_radius_blocks > flore.max_radius_blocks
			and lib.max_radius_blocks <= 4,
			"rayon max des arbres : %d blocs" % lib.max_radius_blocks)


# -- 2. La table des especes --------------------------------------------------

func _test_rules() -> void:
	print("[especes d'arbres]")
	var bad_surface: Array = []
	for surface in CWTreeRules.surfaces():
		if CWModelLibrary.density_of(surface) <= 0.0 \
				and not CWTreeScatter.DENSITE.has(surface):
			bad_surface.append(CWPalette.name_of(surface))
	_ok("chaque surface arboree a une densite", bad_surface.is_empty(),
			str(bad_surface))

	# Un montage FEUILLU ou PALMIER sans couronne poserait un tronc nu ; un
	# montage ENTIER avec des couronnes poserait un houppier flottant, puisque
	# rien ne le monte.
	var incoherent: Array = []
	for surface in CWTreeRules.SPECIES:
		for sp in CWTreeRules.SPECIES[surface]:
			var entier: bool = int(sp["montage"]) == CWTreeRules.Montage.ENTIER
			var vide: bool = (sp["couronnes"] as Array).is_empty()
			if entier != vide:
				incoherent.append(sp["nom"])
	_ok("montage et couronnes s'accordent", incoherent.is_empty(),
			str(incoherent))

	# Le tirage pondere doit couvrir tout [0, 1) et ne jamais rendre vide sur une
	# surface arboree : un trou rendrait des clairieres sans raison.
	var trous: Array = []
	for surface in CWTreeRules.surfaces():
		for i in 64:
			if CWTreeRules.species_at(surface, float(i) / 64.0).is_empty():
				trous.append("%s @ %.2f" % [CWPalette.name_of(surface), float(i) / 64.0])
				break
	_ok("le tirage d'espece couvre tout l'intervalle", trous.is_empty(),
			str(trous))

	# Une surface sans arbre doit rendre un dictionnaire vide, et non le premier
	# venu : c'est ce qui garde la roche et le fond marin nus.
	_ok("une surface sans arbre ne rend rien",
			CWTreeRules.species_at(CWPalette.STONE, 0.5).is_empty()
			and CWTreeRules.species_at(CWPalette.GRAVEL, 0.5).is_empty())


# -- 3. La dispersion ---------------------------------------------------------

func _test_scatter() -> void:
	print("[dispersion des arbres]")
	var p := CWWorldParams.new()
	p.world_seed = 2024
	var field := CWTerrainField.new(p)
	var scatter := CWTreeScatter.new(field)

	_ok("la cellule d'arbres fait 64 blocs",
			scatter.cell_size == 64 and (1 << scatter.cell_shift) == 64,
			"%d / %d" % [scatter.cell_size, 1 << scatter.cell_shift])
	# La conversion des cellules salies par une edition doit etre exacte : une
	# cellule d'arbres couvre un nombre entier de cellules de flore.
	_ok("une cellule d'arbres couvre un nombre entier de cellules de flore",
			CWTreeScatter.TREE_CELL_SHIFT > CWScatter.CELL_SHIFT
			and CWTreeScatter.TREE_CELL_SIZE % CWScatter.CELL_SIZE == 0)

	if not scatter.library().has_any():
		_skip("dispersion des arbres", "aucun modele d'arbre charge")
		return

	# Un coin de monde assez large pour croiser plusieurs biomes.
	var origin := Vector2i(p.world_origin.x >> CWTreeScatter.TREE_CELL_SHIFT,
			p.world_origin.y >> CWTreeScatter.TREE_CELL_SHIFT)
	var cells: Array = []
	for dz in range(-6, 7):
		for dx in range(-6, 7):
			cells.append(Vector2i(origin.x + dx, origin.y + dz))

	var total: int = 0
	var troncs: int = 0
	var non_vides: int = 0
	for c in cells:
		var list: Array = scatter.cell(c.x, c.y)
		total += list.size()
		if not list.is_empty():
			non_vides += 1
		var vus: Dictionary = {}
		for pl in list:
			var k := Vector2i(pl.x, pl.z)
			if not vus.has(k):
				vus[k] = true
				troncs += 1
	print("     %d cellules, %d non vides, %d pieces, %d arbres"
			% [cells.size(), non_vides, total, troncs])
	_ok("la dispersion pose des arbres", troncs > 0, "%d" % troncs)

	# Deterministe : c'est la propriete dont depend tout le reste, puisque la
	# cellule est recalculee a chaque rechargement et par plusieurs fils.
	var again := CWTreeScatter.new(field)
	var a: Array = scatter.cell(origin.x, origin.y)
	var b: Array = again.cell(origin.x, origin.y)
	var identique: bool = a.size() == b.size()
	if identique:
		for i in a.size():
			if a[i].x != b[i].x or a[i].z != b[i].z \
					or not is_equal_approx(a[i].fy, b[i].fy) \
					or a[i].model != b[i].model:
				identique = false
				break
	_ok("deux dispersions du meme monde donnent la meme cellule", identique)

	# **L'espacement minimum, y compris au travers des frontieres de cellule.**
	# C'est la seule propriete de cette couche qui ne se verifie pas en
	# regardant une cellule seule : la regle du rang absolu n'a d'interet que si
	# elle tient entre voisines.
	var pieds: Dictionary = {}
	for c in cells:
		for pl in scatter.cell(c.x, c.y):
			pieds[Vector2i(pl.x, pl.z)] = true
	var liste: Array = pieds.keys()
	var d2: int = CWTreeScatter.ESPACEMENT * CWTreeScatter.ESPACEMENT
	var trop_proches: int = 0
	var pire: int = 0x7FFFFFFF
	for i in liste.size():
		for j in range(i + 1, liste.size()):
			var dx: int = liste[i].x - liste[j].x
			var dz: int = liste[i].y - liste[j].y
			var q: int = dx * dx + dz * dz
			pire = mini(pire, q)
			if q < d2:
				trop_proches += 1
	print("     plus courte distance entre deux troncs : %.1f blocs (minimum %d)"
			% [sqrt(float(pire)) if pire < 0x7FFFFFFF else 0.0,
			CWTreeScatter.ESPACEMENT])
	_ok("aucun couple de troncs sous l'espacement minimum, frontieres comprises",
			trop_proches == 0, "%d couple(s)" % trop_proches)

	# Le montage : toutes les pieces d'un arbre partagent leur colonne et leur
	# echelle, et seul le tronc pose au sol.
	var mauvais_montage: Array = []
	var avec_couronne: int = 0
	for c in cells:
		var par_pied: Dictionary = {}
		for pl in scatter.cell(c.x, c.y):
			var k := Vector2i(pl.x, pl.z)
			if not par_pied.has(k):
				par_pied[k] = []
			par_pied[k].append(pl)
		for k in par_pied:
			var pieces: Array = par_pied[k]
			if pieces.size() > 1:
				avec_couronne += 1
			var base: CWScatter.Placement = pieces[0]
			for pl in pieces:
				if pl.y != base.y or not is_equal_approx(pl.scale, base.scale):
					mauvais_montage.append("%s : pieces desaccordees" % str(k))
					break
			if pieces.size() > 1 and pieces[1].fy <= 0.0:
				mauvais_montage.append("%s : couronne au sol" % str(k))
	_ok("les pieces d'un arbre partagent colonne, altitude et echelle",
			mauvais_montage.is_empty(), str(mauvais_montage.slice(0, 4)))
	_ok("des arbres assembles sont poses (tronc + couronnes)",
			avec_couronne > 0, "%d" % avec_couronne)

	# La couronne doit se poser **haut** sur son tronc, et pas au-dela de sa
	# cime : c'est le calcul que `fy` existe pour garder juste, et le seul de
	# cette couche qui puisse etre faux sans se voir sur une capture.
	var mal_accrochee: Array = []
	for c in cells:
		var par_pied: Dictionary = {}
		for pl in scatter.cell(c.x, c.y):
			var k := Vector2i(pl.x, pl.z)
			if not par_pied.has(k):
				par_pied[k] = []
			par_pied[k].append(pl)
		for k in par_pied:
			var pieces: Array = par_pied[k]
			if pieces.size() < 2:
				continue
			var tronc: CWScatter.Placement = pieces[0]
			var haut: float = float(tronc.model.height) * tronc.scale \
					/ CWVoxelModel.VOXELS_PER_BLOCK
			for i in range(1, pieces.size()):
				var fy: float = pieces[i].fy
				if fy < haut * 0.4 or fy > haut * 1.35:
					mal_accrochee.append("%s : fy %.1f, tronc %.1f" % [str(k), fy, haut])
					break
	_ok("les couronnes s'accrochent au haut de leur tronc",
			mal_accrochee.is_empty(), str(mal_accrochee.slice(0, 4)))

	# La part passante de la crete de placement des arbres. Le budget de
	# candidats est divise par elle : si elle derive, la densite de tous les
	# biomes arbores derive en silence.
	var passes: int = 0
	var essais: int = 0
	for z in range(0, 400, 2):
		for x in range(0, 400, 2):
			essais += 1
			if absf(CWValueNoise.sample(
					float(p.world_origin.x + x) * CWTreeScatter.PLACEMENT_FREQ_ARBRES
							+ CWScatter.PLACEMENT_OFFSET_X,
					float(p.world_origin.y + z) * CWTreeScatter.PLACEMENT_FREQ_ARBRES
							+ CWScatter.PLACEMENT_OFFSET_Z)) > CWScatter.PLACEMENT_RIDGE:
				passes += 1
	var part: float = float(passes) / float(essais)
	print("     crete des arbres : %.4f de la surface passe (annonce %.4f)"
			% [part, CWTreeScatter.PLACEMENT_PASS_RATE_ARBRES])
	_ok("la part passante annoncee est la bonne a 0,05 pres",
			absf(part - CWTreeScatter.PLACEMENT_PASS_RATE_ARBRES) < 0.05,
			"%.4f" % part)

	# Aucun arbre sous l'eau : la couche n'a pas de modele aquatique, et un
	# sapin au fond d'un lac se verait de tres loin au travers de l'eau.
	var noyes: int = 0
	for c in cells:
		for pl in scatter.cell(c.x, c.y):
			if pl.y <= p.sea_level:
				noyes += 1
	_ok("aucun arbre sous le niveau de la mer", noyes == 0, "%d" % noyes)
