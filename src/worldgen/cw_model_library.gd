class_name CWModelLibrary
extends RefCounted

## Bibliotheque des modeles voxels, et table de repartition par surface et par
## role.
##
## Un seul exemplaire partage par tous les fils de generation : les modeles sont
## en lecture seule une fois charges, seule la construction est protegee.
##
## La *liste* des modeles vient des noms charges par l'original ; la *repartition*
## suit desormais ses roles de decor (`CWDecorRules`, `docs/systems/02` §8.6).
## Quel fichier tient quel role sur quelle surface reste une decision de ce
## projet — la source range par role, pas par nom de fichier. Reaffecter un
## modele coute une ligne ici.
##
## Un modele absent du disque est ignore en silence : la production des assets
## est etalee, et un monde a moitie fleuri vaut mieux qu'un monde qui ne se
## genere pas.
##
## -- Chemins, et pourquoi ils portent le biome --------------------------------
##
## Les entrees sont des chemins relatifs a `FLORA_DIR`, dossier de biome compris.
## `nextsteps.md` prevoyait un fichier unique par nom, partage entre biomes ; le
## lot livre le 2026-09-05 en a decide autrement, et mieux : un `caillou_01` de
## prairie, un de neige et un de roche sont trois modeles differents, chacun
## peint dans les teintes de son biome. La table le reflete telle quelle.
##
## Rien n'oblige a en rester la : deux biomes peuvent pointer le meme chemin, et
## le modele n'est alors charge et maille qu'une fois — le cache est indexe par
## chemin, pas par biome.

const FLORA_DIR: String = "res://assets/models/flore/"

## Densite de dispersion par biome : nombre moyen de plantes par cellule de
## dispersion (CWScatter.CELL_SIZE au carre, soit 256 colonnes). Provisoire :
## la source ne porte pas de densite par biome, elle visite chaque colonne.
##
## Doublees le 2026-09-04, avec le passage a l'echelle fine : une touffe d'herbe
## est passee de trois blocs de haut a un demi, donc a nombre egal le sol
## paraissait nu. Douze par cellule, c'est une plante tous les quatre blocs
## environ — un couvert herbace clairsseme, pas une prairie fournie.
##
## Depuis le 2026-09-05, c'est une moyenne et non plus une regularite : la crete
## de placement de `CWScatter` (bruit a 0,05) decoupe le sol en plaques de ~19
## blocs, et c'est de la que viennent les grappes des captures de l'original —
## trois a six pieds serres puis de larges vides. Il n'y avait pas de mecanisme
## de groupement a ecrire, seulement la crete a porter. Le nombre ci-dessous
## reste le nombre attendu par cellule, plaques et vides confondus.
const DENSITY: Dictionary = {
	CWPalette.GRASS: 12.0,
	CWPalette.GRASS_DRY: 6.0,
	CWPalette.GRASS_JUNGLE: 16.0,
	CWPalette.SWAMP: 8.0,
	CWPalette.SAND: 1.2,
	CWPalette.SNOW: 0.5,
	CWPalette.TUNDRA: 3.0,
	CWPalette.STONE: 0.8,
	CWPalette.GRAVEL: 2.5,
}

## Modeles par surface **et par role**. Les roles viennent de `CWDecorRules`,
## qui les tire de la seconde voie de pose de l'original : le decor y porte un
## type, et ce type dit une fonction dans le paysage — du couvert, une fleur, un
## caillou, du sous-bois — pas un fichier. Chaque surface donne donc sa propre
## reponse a chaque role, et c'est ce qui fait qu'un caillou de neige n'est pas
## un caillou de prairie.
##
## Chemins relatifs a `FLORA_DIR`, sans l'extension. Une liste de plusieurs
## modeles pour un meme role est departagee par le tirage d'instance : c'est la
## seule variete qui reste locale, les deux cretes de selection etant, elles,
## regionales.
##
## Ce qui a change le 2026-09-05 (seconde version) : la table etait auparavant
## une simple liste par biome, ou la selection prenait un indice sur deux par le
## signe d'une crete de bruit. C'etait une invention de ce projet, faute de
## connaitre la table d'origine. Elle est connue depuis (`docs/systems/02`,
## §8.6) : la source range son decor par role et choisit le role par deux
## cretes. La liste par biome se deduit toujours de celle-ci — `flora()`.
const ROLES: Dictionary = {
	CWPalette.GRASS: {
		CWDecorRules.Role.COUVERT: ["herbe/herbe_01", "herbe/herbe_02", "herbe/herbe_03"],
		CWDecorRules.Role.FLEUR: ["herbe/fleur_bleuet", "herbe/fleur_tournesol",
				"herbe/bouquet_01", "herbe/bouquet_02"],
		CWDecorRules.Role.SOUS_BOIS: ["herbe/buisson"],
		CWDecorRules.Role.CAILLOU: ["herbe/caillou_01", "herbe/caillou_02"],
	},
	CWPalette.GRASS_DRY: {
		CWDecorRules.Role.COUVERT: ["herbe_seche/herbe_seche"],
		CWDecorRules.Role.FLEUR: ["herbe_seche/fleur_echinacea"],
		CWDecorRules.Role.SOUS_BOIS: ["herbe_seche/broussaille"],
		CWDecorRules.Role.CAILLOU: ["herbe_seche/caillou_01", "herbe_seche/caillou_02"],
	},
	CWPalette.GRASS_JUNGLE: {
		CWDecorRules.Role.COUVERT: ["jungle/feuille"],
		CWDecorRules.Role.FLEUR: ["jungle/fleur_coeur"],
		CWDecorRules.Role.SOUS_BOIS: ["jungle/liane", "jungle/vrille", "jungle/lierre"],
		CWDecorRules.Role.RARE: ["jungle/champignon"],
	},
	CWPalette.SWAMP: {
		CWDecorRules.Role.COUVERT: ["marais/lierre"],
		CWDecorRules.Role.FLEUR: ["marais/fleur_ame"],
		CWDecorRules.Role.ROSEAU: ["marais/roseau"],
		CWDecorRules.Role.RARE: ["marais/champignon"],
	},
	CWPalette.SAND: {
		CWDecorRules.Role.SOUS_BOIS: ["sable_desert/broussaille",
				"sable_desert/cactus_01", "sable_desert/cactus_02"],
		CWDecorRules.Role.CAILLOU: ["sable_desert/gres"],
	},
	CWPalette.SNOW: {
		CWDecorRules.Role.CAILLOU: ["neige/caillou_01"],
		CWDecorRules.Role.SOUS_BOIS: ["neige/broussaille"],
	},
	CWPalette.TUNDRA: {
		CWDecorRules.Role.FLEUR: ["toundra/fleur_ginseng"],
		CWDecorRules.Role.SOUS_BOIS: ["toundra/broussaille"],
		CWDecorRules.Role.CAILLOU: ["toundra/caillou_01"],
	},
	CWPalette.STONE: {
		CWDecorRules.Role.CAILLOU: ["roche/caillou_01", "roche/caillou_02"],
	},
	CWPalette.GRAVEL: {
		CWDecorRules.Role.ALGUE: ["gravier_fond_marin/algue"],
		CWDecorRules.Role.CORAIL: ["gravier_fond_marin/corail"],
		CWDecorRules.Role.FOND: ["gravier_fond_marin/etoile_de_mer"],
	},
}


## Tous les chemins d'une surface, roles confondus. Deduit de `ROLES` : la table
## par biome n'est plus une source, elle est une vue. Sert aux outils, aux
## captures d'inventaire et aux tests qui verifient le lot sur le disque.
static func flora() -> Dictionary:
	var out: Dictionary = {}
	for surface in ROLES:
		var paths: Array = []
		for role in ROLES[surface]:
			for path in ROLES[surface][role]:
				if not paths.has(path):
					paths.append(path)
		out[surface] = paths
	return out


static var _shared: CWModelLibrary = null
## Bibliotheque des arbres, tenue **a part** et non ajoutee a celle de la flore.
##
## Ce n'est pas un rangement, c'est l'invariant n° 17 : `CWScatter` calcule la
## marge de `placements_in` sur `max_radius_blocks`, tous modeles confondus.
## Ranger un houppier de 3 blocs de rayon dans la bibliotheque de la flore ferait
## passer cette marge de 2 blocs a 9 pour **toute** la flore — `placements_in`
## balaierait une couronne de cellules cinq fois plus large, et chaque
## `MultiMesh` d'herbe porterait une boite de visibilite demesuree. Deux
## bibliotheques, deux maxima, deux marges.
static var _shared_trees: CWModelLibrary = null
static var _shared_mutex: Mutex = Mutex.new()

## Dossier racine des chemins de cette bibliotheque.
var _dir: String = FLORA_DIR
var _models: Dictionary = {}
## Par biome : les modeles reellement disponibles sur le disque.
var _by_surface: Dictionary = {}
## Par surface : dictionnaire role -> modeles disponibles.
var _by_role: Dictionary = {}
## Plus grand rayon horizontal, tous modeles confondus, en voxels de modele.
var max_radius: int = 0
var max_height: int = 0
## Les memes, en blocs : c'est l'unite dans laquelle raisonnent les empreintes.
## Sert a savoir combien de cellules voisines peuvent deborder dans un cadre.
var max_radius_blocks: int = 0
var max_height_blocks: int = 0


## Bibliotheque partagee, construite au premier appel.
static func shared() -> CWModelLibrary:
	if _shared != null:
		return _shared
	_shared_mutex.lock()
	if _shared == null:
		var lib := CWModelLibrary.new()
		lib._load_all()
		_shared = lib
	var out: CWModelLibrary = _shared
	_shared_mutex.unlock()
	return out


## Bibliotheque des arbres, construite au premier appel. Voir `_shared_trees`
## pour la raison d'etre de la separation.
static func shared_trees() -> CWModelLibrary:
	if _shared_trees != null:
		return _shared_trees
	_shared_mutex.lock()
	if _shared_trees == null:
		var lib := CWModelLibrary.new()
		lib._dir = CWTreeRules.TREE_DIR
		lib._load_trees()
		_shared_trees = lib
	var out: CWModelLibrary = _shared_trees
	_shared_mutex.unlock()
	return out


## Oublie les bibliotheques partagees. Pour les tests et le rechargement d'assets.
static func reset_shared() -> void:
	_shared_mutex.lock()
	_shared = null
	_shared_trees = null
	_shared_mutex.unlock()


## Charge le lot d'arbres. Pas de roles ici : c'est `CWTreeRules` qui tient le
## montage, et une espece se designe par les chemins de ses pieces.
##
## Une espece dont une seule piece manque du disque est ecartee **en entier** :
## un tronc sans houppier ou un houppier sans tronc se verrait immediatement,
## alors qu'une plante manquante ne fait qu'une clairiere.
func _load_trees() -> void:
	var palette: Resource = CWPalette.build_voxel_palette()
	for surface in CWTreeRules.surfaces():
		var available: Array[CWVoxelModel] = []
		for sp in CWTreeRules.SPECIES[surface]:
			var pieces: Array = ([sp["tronc"]] as Array) + (sp["couronnes"] as Array)
			var loaded: Array[CWVoxelModel] = []
			var complete: bool = true
			for path in pieces:
				var m: CWVoxelModel = _get_or_load(path, palette)
				if m == null:
					complete = false
					break
				loaded.append(m)
			if not complete:
				continue
			for m in loaded:
				if not available.has(m):
					available.append(m)
		if not available.is_empty():
			_by_surface[surface] = available


## Une espece est-elle entierement sur le disque ? Reponse par chemin, pour que
## la dispersion puisse ecarter une espece incomplete sans relire le disque.
func has_paths(paths: Array) -> bool:
	for path in paths:
		if _models.get(path) == null:
			return false
	return true


## Le modele charge pour ce chemin, ou `null`. Les arbres se designent par
## chemin et non par role : c'est `CWTreeRules` qui tient l'assemblage.
func model(path: String) -> CWVoxelModel:
	return _models.get(path)


func _load_all() -> void:
	var palette: Resource = CWPalette.build_voxel_palette()
	for surface in ROLES:
		var by_role: Dictionary = {}
		var available: Array[CWVoxelModel] = []
		for role in ROLES[surface]:
			var models: Array[CWVoxelModel] = []
			for model_name in ROLES[surface][role]:
				var m: CWVoxelModel = _get_or_load(model_name, palette)
				if m != null:
					models.append(m)
					if not available.has(m):
						available.append(m)
			if not models.is_empty():
				by_role[role] = models
		if not available.is_empty():
			_by_surface[surface] = available
			_by_role[surface] = by_role


## Charge un modele, ou rend celui deja en cache. La cle est le chemin : deux
## biomes qui pointent le meme fichier partagent le modele et son maillage.
func _get_or_load(model_name: String, palette: Resource) -> CWVoxelModel:
	if _models.has(model_name):
		return _models[model_name]
	var m: CWVoxelModel = CWVoxelModel.load_from(
			_dir + model_name + ".vox", palette, model_name)
	# Meme absent, on retient la reponse : sans cela chaque biome qui reference
	# un modele manquant retente un acces disque a chaque construction.
	_models[model_name] = m
	if m != null:
		max_radius = maxi(max_radius, m.radius)
		max_height = maxi(max_height, m.height)
		max_radius_blocks = maxi(max_radius_blocks, m.radius_blocks)
		max_height_blocks = maxi(max_height_blocks, m.height_blocks)
	return m


## Modeles disponibles pour un bloc de surface, roles confondus, ou un tableau
## vide. Vue d'ensemble : la dispersion, elle, passe par `for_role`.
func for_surface(surface: int) -> Array:
	return _by_surface.get(surface, [])


## Modeles disponibles pour un role sur une surface, ou un tableau vide.
##
## Un role sans modele sur cette surface rend un tableau vide, et la dispersion
## laisse alors la place nue plutot que de rabattre sur un autre role : c'est le
## comportement de la source, qui ne pose rien quand sa branche ne donne rien,
## et c'est aussi ce qui permet de livrer un lot d'assets par etapes.
func for_role(surface: int, role: int) -> Array:
	var by_role: Dictionary = _by_role.get(surface, {})
	return by_role.get(role, [])


## Roles reellement disponibles sur une surface.
func roles_of(surface: int) -> Array:
	return _by_role.get(surface, {}).keys()


func has_any() -> bool:
	return not _by_surface.is_empty()


func loaded_names() -> PackedStringArray:
	var out := PackedStringArray()
	for k in _models:
		if _models[k] != null:
			out.append(k)
	out.sort()
	return out


## Nombre moyen de plantes par cellule pour un bloc de surface.
static func density_of(surface: int) -> float:
	return DENSITY.get(surface, 0.0)
