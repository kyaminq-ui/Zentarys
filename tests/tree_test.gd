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

## Enveloppes par classe de modele, en **blocs** : (hauteur max, rayon max).
##
## En blocs et non en voxels depuis le jalon 1.12, et les deux unites se
## confondent : le lot d'arbres est dessine a un voxel par bloc. C'est ce qui
## rend ces nombres lisibles — un arbre de l'alpha fait six a dix fois la taille
## du personnage, soit 15 a 25 blocs, et c'est ce qu'on lit ici.
##
## Le plafond de l'arbre geant (34) est plus haut que celui des autres arbres :
## il porte une mission, il doit se voir de loin.
## **Portees de 40 % le 2026-09-06**, avec le lot. Elles doublent celles de
## `tools/blender/generer_arbres.py` : le generateur refuse a l'ecriture, le test
## refuse au chargement, et les deux disent le meme nombre.
const ENV_ARBRE := Vector2i(48, 18)
const ENV_HOUPPIER := Vector2i(20, 17)
const ENV_PALME := Vector2i(12, 16)

## Les modeles qui ne sont pas des arbres entiers, et leur classe. Tout ce qui
## n'est pas cite est un arbre entier — troncs compris : un fut nu tient
## largement sous l'enveloppe d'un arbre.
const CLASSES: Dictionary = {
	"greenlands/chene_houppier_01": ENV_HOUPPIER,
	"greenlands/chene_houppier_02": ENV_HOUPPIER,
	"greenlands/bouleau_houppier": ENV_HOUPPIER,
	"greenlands/arbre_geant_houppier": ENV_HOUPPIER,
	"snowlands/bouleau_givre_houppier": ENV_HOUPPIER,
	"jungles/tropical_houppier_01": ENV_HOUPPIER,
	"jungles/tropical_houppier_02": ENV_HOUPPIER,
	"jungles/palme": ENV_PALME,
	"jungles/palme_diagonale": ENV_PALME,
	"deserts/palme": ENV_PALME,
	"deserts/palme_diagonale": ENV_PALME,
}

var _runner: Object


func run(runner: Object) -> void:
	_runner = runner
	_test_models()
	_test_rules()
	_test_scatter()
	_test_matiere()


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
	# La grille du lot : **un voxel par bloc**. C'est le contrat d'authoring du
	# jalon 1.12, et le confondre avec celui de la flore rendrait tout le lot
	# treize fois trop petit sans qu'aucune autre verification ne tombe — les
	# proportions entre pieces resteraient justes.
	var mauvaise_grille: Array = []
	for path in paths:
		var mm: CWVoxelModel = lib.model(path)
		if mm != null and not is_equal_approx(mm.voxels_per_block,
				CWVoxelModel.VOXELS_PER_BLOCK_TERRAIN):
			mauvaise_grille.append(path)
	_ok("le lot d'arbres est a un voxel par bloc", mauvaise_grille.is_empty(),
			str(mauvaise_grille))

	var oversize: Array = []
	for path in paths:
		var m: CWVoxelModel = lib.model(path)
		if m == null:
			continue
		var env: Vector2i = CLASSES.get(path, ENV_ARBRE)
		if m.height_blocks > env.x or m.radius_blocks > env.y:
			oversize.append("%s %dx%d blocs > %dx%d" % [path, m.height_blocks,
					m.radius_blocks, env.x, env.y])
	_ok("aucun modele d'arbre hors de son enveloppe de classe",
			oversize.is_empty(), str(oversize))

	# Le defaut inverse, et c'est celui qui a coute le lot du 2026-09-05 : des
	# arbres **trop petits**. Sur les captures du jeu d'origine un arbre fait six
	# a dix fois le personnage, soit 15 blocs au moins tout compris. On mesure
	# ici la piece portante — un tronc ou un arbre entier —, houppiers exclus,
	# et on demande qu'aucune espece ne descende sous 8 blocs de fut.
	var nains: Array = []
	for biome in CWTreeRules.SPECIES:
		for sp in CWTreeRules.SPECIES[biome]:
			var t: CWVoxelModel = lib.model(sp["tronc"])
			if t != null and t.height_blocks < 8:
				nains.append("%s : %d blocs" % [sp["nom"], t.height_blocks])
	_ok("aucune espece n'a un fut de moins de 8 blocs", nains.is_empty(),
			str(nains))

	# Et la proportion des houppiers : ce sont des domes en parasol, **plus
	# larges que hauts**. Le lot precedent les faisait aussi hauts que larges, ce
	# qui donnait des boules et non une canopee.
	var pas_assez_larges: Array = []
	for path in CLASSES:
		if CLASSES[path] != ENV_HOUPPIER:
			continue
		var m2: CWVoxelModel = lib.model(path)
		if m2 != null and float(m2.radius) * 2.0 < float(m2.height) * 1.4:
			pas_assez_larges.append("%s : %d de large, %d de haut"
					% [path, m2.radius * 2, m2.height])
	_ok("les houppiers sont plus larges que hauts", pas_assez_larges.is_empty(),
			str(pas_assez_larges))

	# Un houppier n'a pas de pied : sa base est une couronne, et elle sera posee
	# au sommet d'un tronc. Un houppier plus haut que large serait un arbre.
	var trop_haut: Array = []
	for path in CLASSES:
		if CLASSES[path] != ENV_HOUPPIER:
			continue
		var m: CWVoxelModel = lib.model(path)
		if m != null and m.height > 2 * m.radius:
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
			flore.max_radius_blocks <= 3,
			"rayon max de la flore : %d blocs" % flore.max_radius_blocks)
	# La borne haute suit le lot : des houppiers de 15 a 21 blocs de large font
	# un rayon de 8 a 11, et une **charpente** un peu plus — ses branches vont
	# chercher le houppier a quatorze blocs de l'axe, et elles sont dans le
	# modele du tronc. C'est elle qui fixe le maximum depuis le 2026-09-06.
	_ok("la bibliotheque des arbres a son propre maximum",
			lib.max_radius_blocks > flore.max_radius_blocks
			and lib.max_radius_blocks <= 16,
			"rayon max des arbres : %d blocs" % lib.max_radius_blocks)


# -- 2. La table des especes --------------------------------------------------

func _test_rules() -> void:
	print("[especes d'arbres]")
	var bad_biome: Array = []
	for biome in CWTreeRules.biomes():
		if not CWTreeScatter.DENSITE.has(biome):
			bad_biome.append(CWBiome.name_of(biome))
	_ok("chaque biome arbore a une densite d'arbres", bad_biome.is_empty(),
			str(bad_biome))

	# Et l'inverse : une densite sans espece est du budget de candidats depense
	# pour rien, cellule apres cellule, sans qu'un seul arbre en sorte.
	var densite_seule: Array = []
	for biome in CWTreeScatter.DENSITE:
		if not CWTreeRules.SPECIES.has(biome):
			densite_seule.append(CWBiome.name_of(biome))
	_ok("chaque densite d'arbres a des especes", densite_seule.is_empty(),
			str(densite_seule))

	# Un montage FEUILLU ou PALMIER sans couronne poserait un tronc nu ; un
	# montage ENTIER avec des couronnes poserait un houppier flottant, puisque
	# rien ne le monte.
	var incoherent: Array = []
	for biome in CWTreeRules.SPECIES:
		for sp in CWTreeRules.SPECIES[biome]:
			var entier: bool = int(sp["montage"]) == CWTreeRules.Montage.ENTIER
			var vide: bool = (sp["couronnes"] as Array).is_empty()
			if entier != vide:
				incoherent.append(sp["nom"])
	_ok("montage et couronnes s'accordent", incoherent.is_empty(),
			str(incoherent))

	# Le tirage pondere doit couvrir tout [0, 1) et ne jamais rendre vide sur une
	# surface arboree : un trou rendrait des clairieres sans raison.
	var trous: Array = []
	for biome in CWTreeRules.biomes():
		for i in 64:
			if CWTreeRules.species_at(biome, float(i) / 64.0).is_empty():
				trous.append("%s @ %.2f" % [CWBiome.name_of(biome), float(i) / 64.0])
				break
	_ok("le tirage d'espece couvre tout l'intervalle", trous.is_empty(),
			str(trous))

	# Un biome sans arbre doit rendre un dictionnaire vide, et non le premier
	# venu : c'est ce qui garde le fond marin nu.
	_ok("un biome sans arbre ne rend rien",
			CWTreeRules.species_at(CWBiome.OCEANS, 0.5).is_empty())


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
		for pl in list:
			# Un arbre = un pied, et un pied = la piece posee sur la colonne du
			# candidat. Compter les colonnes distinctes marchait tant qu'un
			# arbre tenait sur la sienne ; depuis le montage GRAND, ses quatre
			# houppiers sont poses **a cote** et chacun compterait pour un arbre.
			if pl.fy == 0.0:
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
	# Les **pieds**, et non les colonnes occupees : un grand arbre pose ses
	# houppiers au bout de branches, donc sur quatre colonnes voisines de la
	# sienne. Les compter comme des arbres ferait echouer l'espacement sur des
	# pieces qui appartiennent au meme arbre — ce qui est arrive le 2026-09-06,
	# avec 497 faux couples. La piece posee au sol (`fy == 0`) est le pied.
	var pieds: Dictionary = {}
	for c in cells:
		for pl in scatter.cell(c.x, c.y):
			if pl.fy == 0.0:
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
					/ tronc.model.voxels_per_block
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


# -- 4. Le tronc ecrit dans le terrain (jalon 1.11) ---------------------------

func _test_matiere() -> void:
	print("[le tronc en matiere]")
	var p := CWWorldParams.new()
	p.world_seed = 2024
	var g := CWVoxelGenerator.new()
	g.params = p
	var scatter: CWTreeScatter = g.tree_scatter_grid()
	if not scatter.library().has_any():
		_skip("le tronc en matiere", "aucun modele d'arbre charge")
		return

	# -- Les deux constantes de marge, contre le lot reel --------------------
	#
	# `MARGE_TRONC` decide quelles cellules `trunks_in` consulte et
	# `HAUTEUR_TRONC_MAX` de combien recule le chemin rapide du generateur. Un
	# modele qui les depasserait serait tronque au bord d'un bloc, ce qui se
	# verrait a peine et ne leverait rien.
	var lib: CWModelLibrary = scatter.library()
	var trop_large := PackedStringArray()
	var trop_haut := PackedStringArray()
	for biome in CWTreeRules.biomes():
		for sp in CWTreeRules.SPECIES[biome]:
			if int(sp["montage"]) == CWTreeRules.Montage.ENTIER:
				continue
			var m: CWVoxelModel = lib.model(sp["tronc"])
			if m == null:
				continue
			if m.radius_blocks > CWTreeScatter.MARGE_TRONC:
				trop_large.append("%s r=%d" % [m.name, m.radius_blocks])
			if roundi(float(m.height) * CWTreeScatter.ECHELLE_MAX) \
					> CWTreeScatter.HAUTEUR_TRONC_MAX:
				trop_haut.append("%s h=%d" % [m.name, m.height])
	_ok("aucun tronc ne deborde de la marge horizontale",
			trop_large.is_empty(), ", ".join(trop_large))
	_ok("aucun tronc ne depasse la hauteur annoncee",
			trop_haut.is_empty(), ", ".join(trop_haut))

	# -- Les branches d'un grand arbre portent-elles vraiment leur houppier ? -
	#
	# `CWTreeRules.SPECIES[...]["branches"]` et
	# `tools/blender/generer_arbres.BRANCHES_*` sont deux tables qui doivent dire
	# la meme chose : l'une dessine la branche, l'autre y pose la masse. C'est le
	# meme accord que celui de `GRILLE_FINE`, a une difference pres qui rend ce
	# test-ci facile — **le bois est la, ou il n'y est pas**. On charge le modele
	# et on regarde s'il y a de la matiere au bout declare.
	#
	# La tolerance est d'un bloc : le bout est le dernier voxel dessine, et
	# l'arrondi de la ligne peut le poser a un bloc de la valeur nominale.
	var bouts_vides := PackedStringArray()
	var grands: int = 0
	for biome in CWTreeRules.biomes():
		for sp in CWTreeRules.SPECIES[biome]:
			if int(sp["montage"]) != CWTreeRules.Montage.GRAND:
				continue
			grands += 1
			var m: CWVoxelModel = lib.model(sp["tronc"])
			if m == null:
				continue
			var dx: PackedInt32Array = m.offsets_x(0)
			var dy: PackedInt32Array = m.offsets_y(0)
			var dz: PackedInt32Array = m.offsets_z(0)
			for b in sp["branches"]:
				var proche: bool = false
				for i in m.voxel_count:
					if absi(dx[i] - b.x) <= 1 and absi(dz[i] - b.y) <= 1 							and absi(dy[i] - b.z) <= 1:
						proche = true
						break
				if not proche:
					bouts_vides.append("%s %s" % [m.name, b])
	_ok("chaque bout de branche declare porte du bois (%d grands arbres)" % grands,
			bouts_vides.is_empty(), ", ".join(bouts_vides))
	_ok("les dix grands arbres sont dans la table", grands == 10, "%d" % grands)

	# -- Qui est de la matiere, et qui n'en est pas --------------------------
	var origin := Vector2i(p.world_origin.x >> CWTreeScatter.TREE_CELL_SHIFT,
			p.world_origin.y >> CWTreeScatter.TREE_CELL_SHIFT)
	var troncs: Array = []
	var arbres: Dictionary = {}
	for dz in range(-3, 4):
		for dx in range(-3, 4):
			for pl in scatter.cell(origin.x + dx, origin.y + dz):
				var k := Vector2i(pl.x, pl.z)
				if not arbres.has(k):
					arbres[k] = []
				arbres[k].append(pl)
				if pl.matiere:
					troncs.append(pl)
	if troncs.is_empty():
		_skip("le tronc en matiere", "aucun feuillu autour du point de depart")
		return
	print("     %d arbre(s), dont %d a tronc de matiere"
			% [arbres.size(), troncs.size()])

	# Une piece de matiere est **le tronc, et lui seul**. Deux troncs de matiere
	# sur un meme arbre en ecriraient deux au meme endroit ; un houppier de
	# matiere serait du feuillage qu'on ne peut plus traverser.
	var fautes := PackedStringArray()
	for k in arbres:
		var n: int = 0
		for pl in arbres[k]:
			if pl.matiere:
				n += 1
				if pl.hauteur <= 0:
					fautes.append("%s sans hauteur" % pl.model.name)
		if n > 1:
			fautes.append("%d troncs en (%d,%d)" % [n, k.x, k.y])
	_ok("un arbre a au plus un tronc de matiere, et il a une hauteur",
			fautes.is_empty(), ", ".join(fautes))

	# Un arbre entier n'est jamais de la matiere : la source le pose en entite,
	# et son feuillage est dans le meme modele que son fut.
	var entiers: int = 0
	for k in arbres:
		if arbres[k].size() == 1 and arbres[k][0].matiere:
			entiers += 1
	_ok("un modele entier n'est pas estampe", entiers == 0, "%d" % entiers)

	# -- La reechantillonnage vertical ---------------------------------------
	#
	# Un tronc estampe fait exactement `hauteur` blocs, du sol au sommet, sans
	# niveau vide au milieu : un trou dans un fut se voit de loin, et une
	# hauteur qui ne suit pas la gigue rendrait tous les arbres identiques.
	var tronc: CWScatter.Placement = troncs[0]
	var voxels: Array = CWTreeScatter.trunk_voxels(tronc)
	var niveaux: Dictionary = {}
	var hors: int = 0
	for v in voxels:
		niveaux[v.y] = true
		if v.y < tronc.y or v.y >= tronc.y + tronc.hauteur:
			hors += 1
	_ok("le tronc estampe occupe tous ses niveaux, et aucun autre",
			niveaux.size() == tronc.hauteur and hors == 0,
			"%d niveaux pour %d blocs, %d hors" % [niveaux.size(),
					tronc.hauteur, hors])

	var gigue: Dictionary = {}
	for pl in troncs:
		gigue[pl.hauteur] = true
	_ok("la gigue d'echelle donne des troncs de hauteurs differentes",
			gigue.size() > 1, "%d hauteur(s) distincte(s)" % gigue.size())

	# -- Le houppier se pose sur le tronc pose, pas sur un tronc reve ---------
	#
	# C'est le point d'accroche des deux mondes : la hauteur qui sert au montage
	# doit etre celle des blocs reellement ecrits. Si l'un arrondit et l'autre
	# non, le houppier flotte ou avale la cime — le defaut du 2026-09-06.
	var k0 := Vector2i(tronc.x, tronc.z)
	var premier: CWScatter.Placement = null
	for pl in arbres[k0]:
		if pl.matiere:
			continue
		if premier == null or pl.fy < premier.fy:
			premier = pl
	if premier != null:
		var attendu: float = float(tronc.hauteur) * CWTreeScatter.ACCROCHE_HOUPPIER
		_ok("le premier houppier s'accroche a la hauteur estampee",
				absf(premier.fy - attendu) < 0.001,
				"fy=%.3f, attendu %.3f" % [premier.fy, attendu])

	# -- La requete du generateur --------------------------------------------
	#
	# `trunks_in` ne rend que de la matiere, et elle rend le tronc dont la
	# colonne tombe dans le cadre. C'est elle que `_generate_block` appelle a
	# chaque bloc de surface.
	var dans: Array = scatter.trunks_in(tronc.x - 2, tronc.z - 2, 5, 5)
	var trouve: bool = false
	var intrus: int = 0
	for pl in dans:
		if not pl.matiere:
			intrus += 1
		if pl == tronc:
			trouve = true
	_ok("trunks_in rend le tronc de son cadre, et rien d'instancie",
			trouve and intrus == 0, "%d resultat(s), %d intrus" % [dans.size(), intrus])

	# -- Et le bout du chemin : le bloc genere -------------------------------
	#
	# La seule verification qui traverse tout — dispersion, reechantillonnage,
	# repere monde vers repere de scene, ecriture des deux canaux. Le repere est
	# le piege : `CWTreeScatter` compte en coordonnees monde et le bloc en
	# coordonnees de scene, et une table rangee dans le mauvais repere ne tombe
	# jamais juste sans que rien ne bronche (jalon 1.9).
	var sx: int = tronc.x - p.world_origin.x
	var sz: int = tronc.z - p.world_origin.y
	@warning_ignore("integer_division")
	var bx: int = floori(float(sx) / 16.0) * 16
	@warning_ignore("integer_division")
	var bz: int = floori(float(sz) / 16.0) * 16
	@warning_ignore("integer_division")
	var by: int = floori(float(tronc.y) / 16.0) * 16
	var buf := VoxelBuffer.new()
	buf.set_channel_depth(CWPalette.CHANNEL_COLOR, CWPalette.COLOR_DEPTH)
	buf.create(16, 16, 16)
	g._generate_block(buf, Vector3i(bx, by, bz), 0)
	var bois: int = 0
	var teintes: Dictionary = {}
	for y in 16:
		for z in 16:
			for x in 16:
				if buf.get_voxel(x, y, z, CWPalette.CHANNEL_TYPE) == CWPalette.WOOD:
					bois += 1
					teintes[buf.get_voxel(x, y, z, CWPalette.CHANNEL_COLOR)] = true
	_ok("le bloc genere contient du bois", bois > 0, "%d voxel(s)" % bois)
	# Le type est unique, la teinte ne l'est pas : c'est tout le partage du
	# jalon 1.9. Un tronc qui sortirait d'une seule couleur voudrait dire que le
	# canal de rendu recopie le type au lieu du modele.
	_ok("le bois garde les nuances d'ecorce de son modele", teintes.size() > 1,
			"%d teinte(s)" % teintes.size())

	# La colonne du tronc porte du bois **au-dessus du sol** : c'est la
	# difference entre un tronc pose et un tronc enterre.
	var lx: int = sx - bx
	var lz: int = sz - bz
	var ly: int = tronc.y - by
	if ly >= 0 and ly < 16:
		_ok("le pied du tronc est sur sa propre colonne",
				buf.get_voxel(lx, ly, lz, CWPalette.CHANNEL_TYPE) == CWPalette.WOOD,
				"type %d en (%d,%d,%d)" % [buf.get_voxel(lx, ly, lz,
						CWPalette.CHANNEL_TYPE), lx, ly, lz])
