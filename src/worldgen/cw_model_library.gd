class_name CWModelLibrary
extends RefCounted

## Bibliotheque des modeles voxels, et table de repartition par biome.
##
## Un seul exemplaire partage par tous les fils de generation : les modeles sont
## en lecture seule une fois charges, seule la construction est protegee.
##
## RESERVE. La table `FLORA` ci-dessous est une **proposition de bon sens**, pas
## une lecture du binaire : l'affectation reelle vit dans
## `WorldInfo_generateBiomeContent` (@005e4850), pas encore analysee. La *liste*
## des modeles, elle, est sure — elle vient des noms de modeles charges par
## l'original. Reaffecter un modele coute une ligne ici.
##
## Un modele absent du disque est ignore en silence : la production des assets
## est etalee, et un monde a moitie fleuri vaut mieux qu'un monde qui ne se
## genere pas.

const FLORA_DIR: String = "res://assets/models/flore/"

## Densite de dispersion par biome : nombre moyen de plantes par cellule de
## dispersion (CWScatter.CELL_SIZE au carre, soit 256 colonnes). Provisoire,
## meme reserve — la loi de densite de l'original n'est pas encore lue.
##
## Reglees pour des modeles a l'echelle de reference (une touffe d'herbe fait
## trois a quatre blocs, cf. assets/models/MODELS.md) : six touffes par cellule,
## c'est une plante tous les six ou sept blocs, ce qui lit comme un couvert
## herbace sans faire une foret.
const DENSITY: Dictionary = {
	CWPalette.GRASS: 6.0,
	CWPalette.GRASS_DRY: 3.0,
	CWPalette.GRASS_JUNGLE: 8.0,
	CWPalette.SWAMP: 4.0,
	CWPalette.SAND: 0.6,
	CWPalette.SNOW: 0.25,
	CWPalette.TUNDRA: 1.5,
	CWPalette.STONE: 0.4,
	CWPalette.GRAVEL: 1.2,
}

## Modeles candidats par biome, dans l'ordre de la table de nextsteps.md, §7.2.
const FLORA: Dictionary = {
	CWPalette.GRASS: ["herbe_01", "herbe_02", "herbe_03", "buisson",
			"bouquet_01", "bouquet_02", "fleur_bleuet", "fleur_tournesol",
			"caillou_01", "caillou_02"],
	CWPalette.GRASS_DRY: ["herbe_seche", "broussaille", "fleur_echinacea",
			"caillou_01", "caillou_02"],
	CWPalette.GRASS_JUNGLE: ["liane", "vrille", "lierre", "feuille",
			"fleur_coeur", "champignon"],
	CWPalette.SWAMP: ["roseau", "champignon", "lierre", "fleur_ame"],
	CWPalette.SAND: ["cactus_01", "cactus_02", "broussaille", "gres"],
	CWPalette.SNOW: ["caillou_01", "broussaille"],
	CWPalette.TUNDRA: ["broussaille", "fleur_ginseng", "caillou_01"],
	CWPalette.STONE: ["caillou_01", "caillou_02"],
	CWPalette.GRAVEL: ["algue", "corail", "etoile_de_mer"],
}

static var _shared: CWModelLibrary = null
static var _shared_mutex: Mutex = Mutex.new()

var _models: Dictionary = {}
## Par biome : les modeles reellement disponibles sur le disque.
var _by_surface: Dictionary = {}
## Plus grand rayon horizontal, tous modeles confondus. Sert a savoir combien de
## cellules voisines peuvent deborder dans un bloc.
var max_radius: int = 0
var max_height: int = 0


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


## Oublie la bibliotheque partagee. Pour les tests et le rechargement d'assets.
static func reset_shared() -> void:
	_shared_mutex.lock()
	_shared = null
	_shared_mutex.unlock()


func _load_all() -> void:
	var palette: Resource = CWPalette.build_voxel_palette()
	for surface in FLORA:
		var available: Array[CWVoxelModel] = []
		for model_name in FLORA[surface]:
			var m: CWVoxelModel = _get_or_load(model_name, palette)
			if m != null:
				available.append(m)
		if not available.is_empty():
			_by_surface[surface] = available


func _get_or_load(model_name: String, palette: Resource) -> CWVoxelModel:
	if _models.has(model_name):
		return _models[model_name]
	var m: CWVoxelModel = CWVoxelModel.load_from(FLORA_DIR + model_name + ".vox", palette)
	# Meme absent, on retient la reponse : sans cela chaque biome qui reference
	# un modele manquant retente un acces disque a chaque construction.
	_models[model_name] = m
	if m != null:
		max_radius = maxi(max_radius, m.radius)
		max_height = maxi(max_height, m.height)
	return m


## Modeles disponibles pour un bloc de surface, ou un tableau vide.
func for_surface(surface: int) -> Array:
	return _by_surface.get(surface, [])


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
