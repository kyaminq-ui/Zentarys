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
## dispersion (CWScatter.CELL_SIZE au carre, soit 256 colonnes). Provisoire,
## meme reserve — la loi de densite de l'original n'est pas encore lue.
##
## Doublees le 2026-09-04, avec le passage a l'echelle fine : une touffe d'herbe
## est passee de trois blocs de haut a un demi, donc a nombre egal le sol
## paraissait nu. Douze par cellule, c'est une plante tous les quatre blocs
## environ — un couvert herbace clairsseme, pas une prairie fournie.
##
## Ce qui manque encore, et qui se voit sur les captures de l'original : la
## flore y vient par **grappes**, trois a six pieds serres puis de larges vides.
## Un tirage uniforme par cellule ne sait pas produire ca. A reprendre avec la
## lecture de `WorldInfo_generateBiomeContent`.
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

## Modeles candidats par biome, dans l'ordre de la table de nextsteps.md, §7.2.
## Chemins relatifs a `FLORA_DIR`, sans l'extension.
const FLORA: Dictionary = {
	CWPalette.GRASS: ["herbe/herbe_01", "herbe/herbe_02", "herbe/herbe_03",
			"herbe/buisson", "herbe/bouquet_01", "herbe/bouquet_02",
			"herbe/fleur_bleuet", "herbe/fleur_tournesol",
			"herbe/caillou_01", "herbe/caillou_02"],
	CWPalette.GRASS_DRY: ["herbe_seche/herbe_seche", "herbe_seche/broussaille",
			"herbe_seche/fleur_echinacea",
			"herbe_seche/caillou_01", "herbe_seche/caillou_02"],
	CWPalette.GRASS_JUNGLE: ["jungle/liane", "jungle/vrille", "jungle/lierre",
			"jungle/feuille", "jungle/fleur_coeur", "jungle/champignon"],
	CWPalette.SWAMP: ["marais/roseau", "marais/champignon", "marais/lierre",
			"marais/fleur_ame"],
	CWPalette.SAND: ["sable_desert/cactus_01", "sable_desert/cactus_02",
			"sable_desert/broussaille", "sable_desert/gres"],
	CWPalette.SNOW: ["neige/caillou_01", "neige/broussaille"],
	CWPalette.TUNDRA: ["toundra/broussaille", "toundra/fleur_ginseng",
			"toundra/caillou_01"],
	CWPalette.STONE: ["roche/caillou_01", "roche/caillou_02"],
	CWPalette.GRAVEL: ["gravier_fond_marin/algue", "gravier_fond_marin/corail",
			"gravier_fond_marin/etoile_de_mer"],
}


static var _shared: CWModelLibrary = null
static var _shared_mutex: Mutex = Mutex.new()

var _models: Dictionary = {}
## Par biome : les modeles reellement disponibles sur le disque.
var _by_surface: Dictionary = {}
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


## Charge un modele, ou rend celui deja en cache. La cle est le chemin : deux
## biomes qui pointent le meme fichier partagent le modele et son maillage.
func _get_or_load(model_name: String, palette: Resource) -> CWVoxelModel:
	if _models.has(model_name):
		return _models[model_name]
	var m: CWVoxelModel = CWVoxelModel.load_from(
			FLORA_DIR + model_name + ".vox", palette, model_name)
	# Meme absent, on retient la reponse : sans cela chaque biome qui reference
	# un modele manquant retente un acces disque a chaque construction.
	_models[model_name] = m
	if m != null:
		max_radius = maxi(max_radius, m.radius)
		max_height = maxi(max_height, m.height)
		max_radius_blocks = maxi(max_radius_blocks, m.radius_blocks)
		max_height_blocks = maxi(max_height_blocks, m.height_blocks)
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
