class_name CWModelLibrary
extends RefCounted

## Bibliotheque des modeles voxels, et table de repartition par biome et par
## role.
##
## Un seul exemplaire partage par tous les fils de generation : les modeles sont
## en lecture seule une fois charges, seule la construction est protegee.
##
## La *liste* des modeles vient des noms charges par l'original ; la *repartition*
## suit desormais ses roles de decor (`CWDecorRules`, `docs/systems/02` §8.6).
## Quel fichier tient quel role dans quel biome reste une decision de ce
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
## dispersion (CWScatter.CELL_SIZE au carre, soit 256 colonnes).
##
## C'est une **moyenne**, pas une regularite : la crete de placement de
## `CWScatter` (bruit a 0,05) decoupe le sol en plaques d'environ 19 blocs, et
## c'est de la que viennent les grappes des captures de l'original — trois a six
## pieds serres, puis de larges vides. Le nombre ci-dessous est le nombre attendu
## par cellule, plaques et vides confondus.
##
## -- Ce qui a change au jalon 1.12 -------------------------------------------
##
## La cle est le **biome**, plus la matiere de surface. Une cellule dont le
## centre tombe sur une crete rocheuse de Greenlands garde donc la densite de
## Greenlands, et ce sont ses candidats, un a un, que `CWDecorRules.decor_allowed`
## ecarte. C'est plus juste que l'ancienne table : une prairie ne devient pas
## sterile parce que son centre de cellule est sur un caillou.
##
## Les valeurs elles-memes sont revues avec le lot d'assets : la flore du
## jalon 1.7 etait dessinee a la moitie de sa taille, et on avait compense en
## doublant les densites (`nextsteps.md`, §6.5). Des plantes deux fois et demie
## plus hautes couvrent six fois plus de sol : Greenlands redescend de 12 a 9,
## Jungles de 16 a 14.
##
## -- Et **tout le lot est multiplie par 0,6 le 2026-09-06** ------------------
##
## Vu en jeu, pas deduit : le sol ne se voyait plus. Le reglage precedent avait
## corrige la taille des plantes — c'etait le bon geste — mais pas assez loin,
## parce qu'on ne compare pas une densite a une autre densite : on la compare a
## la **surface de sol qui reste libre**. Une prairie ou l'on distingue chaque
## touffe se lit comme une prairie ; une prairie ou les touffes se touchent se
## lit comme un tapis, et le relief sous elle disparait.
##
## Le facteur est **uniforme** parce que le rapport entre biomes, lui, n'etait
## pas en cause : une jungle doit rester six fois plus fournie qu'une plaine de
## neige, et c'est le seul repere qu'on ait de l'original. Ce qui a bouge est
## l'echelle commune, et elle a bouge d'un seul coup pour que la comparaison
## d'un biome a l'autre reste lisible.
const DENSITY: Dictionary = {
	CWBiome.GREENLANDS: 5.4,
	CWBiome.SNOWLANDS: 1.5,
	CWBiome.DESERTS: 0.85,
	CWBiome.JUNGLES: 8.4,
	CWBiome.LAVALANDS: 0.7,
	CWBiome.OCEANS: 1.5,
}

## Modeles par **biome** et par role. Les roles viennent de `CWDecorRules`, qui
## les tire de la seconde voie de pose de l'original : le decor y porte un type,
## et ce type dit une fonction dans le paysage — du couvert, une fleur, un
## caillou, du sous-bois — pas un fichier. Chaque biome donne donc sa propre
## reponse a chaque role, et c'est ce qui fait qu'un caillou de Snowlands n'est
## pas un caillou de Greenlands.
##
## Chemins relatifs a `FLORA_DIR`, sans l'extension, dossier de biome compris
## (`CWBiome.dir_of`). Une liste de plusieurs modeles pour un meme role est
## departagee par le tirage d'instance : c'est la seule variete qui reste
## locale, les deux cretes de selection etant, elles, regionales.
##
## -- Deux choses a savoir avant d'y toucher -----------------------------------
##
## 1. **Un role qu'un biome sait choisir mais pas poser ne leve rien** : la
##    plante disparait et la densite moyenne ne bouge pas assez pour se voir.
##    L'inverse — un modele range sous un role que les deux cretes n'atteignent
##    jamais — est plus discret encore : le fichier est charge, maille, et ne
##    sort pas une seule fois. `tests/decor_test.gd` tient les deux sens, et
##    c'est la seule chose qui les tienne (invariant n° 22).
## 2. Deux biomes peuvent pointer le meme fichier ; il n'est alors charge et
##    maille qu'une fois, le cache etant indexe par chemin. **Le lot livre au
##    jalon 1.12 ne s'en sert pas** : chaque biome a ses propres teintes, et le
##    champignon luisant lui-meme est dessine deux fois, une par biome ou le
##    role rare est atteignable. Un test refuse qu'un chemin traverse.
const ROLES: Dictionary = {
	CWBiome.GREENLANDS: {
		CWDecorRules.Role.COUVERT: ["greenlands/herbe_01", "greenlands/herbe_02",
				"greenlands/herbe_03", "greenlands/herbe_seche"],
		CWDecorRules.Role.FLEUR: ["greenlands/fleur_bleuet",
				"greenlands/fleur_tournesol", "greenlands/fleur_coeur",
				"greenlands/ginseng"],
		CWDecorRules.Role.SOUS_BOIS: ["greenlands/buisson", "greenlands/scrub",
				"greenlands/broussaille", "greenlands/fougere"],
	},
	CWBiome.SNOWLANDS: {
		CWDecorRules.Role.COUVERT: ["snowlands/herbe_gelee"],
		CWDecorRules.Role.FLEUR: ["snowlands/fleur_de_glace"],
		CWDecorRules.Role.SOUS_BOIS: ["snowlands/buisson_neige",
				"snowlands/snowberry", "snowlands/cotonnier"],
	},
	CWBiome.DESERTS: {
		CWDecorRules.Role.SOUS_BOIS: ["deserts/cactus_01", "deserts/cactus_02",
				"deserts/broussaille_seche", "deserts/cotonnier"],
		CWDecorRules.Role.RARE: ["deserts/habanero"],
	},
	CWBiome.JUNGLES: {
		CWDecorRules.Role.COUVERT: ["jungles/feuille_large"],
		CWDecorRules.Role.FLEUR: ["jungles/fleur_coeur", "jungles/fleur_ame"],
		CWDecorRules.Role.SOUS_BOIS: ["jungles/liane", "jungles/vrille",
				"jungles/lierre", "jungles/fougere_geante"],
		CWDecorRules.Role.ROSEAU: ["jungles/roseau"],
		CWDecorRules.Role.RARE: ["jungles/champignon"],
	},
	CWBiome.LAVALANDS: {
		CWDecorRules.Role.SOUS_BOIS: ["lavalands/fire_shrub",
				"lavalands/herbe_de_lave"],
		CWDecorRules.Role.FLEUR: ["lavalands/fleur_de_lave"],
		CWDecorRules.Role.RARE: ["lavalands/champignon_luisant"],
	},
	CWBiome.OCEANS: {
		CWDecorRules.Role.ALGUE: ["oceans/algue"],
		CWDecorRules.Role.CORAIL: ["oceans/corail"],
		CWDecorRules.Role.FOND: ["oceans/etoile_de_mer"],
	},
}


## Les **petits props** : herbes et fleurs, dessines a six voxels par bloc au
## lieu de quatre. Tout ce qui n'est pas ici prend `VOXELS_PER_BLOCK_FLORE`.
##
## -- Pourquoi une liste et non une regle -------------------------------------
##
## Le partage passe par le *role* a un cheveu pres, et ce cheveu suffit a le
## disqualifier : `feuille_large` est un `COUVERT` de jungle mais c'est une
## grande feuille, pas de l'herbe, et `herbe_de_lave` est range en `SOUS_BOIS`
## alors que c'en est. Une regle qui se trompe sur deux modeles sur trente-huit
## est plus couteuse qu'une liste, parce qu'on ne sait pas lesquels sans les
## regarder un par un — ce qu'il faut faire de toute facon.
##
## **Cette table et le catalogue de `tools/blender/generer_flore.py` doivent
## dire la meme chose.** Le generateur dessine a la grille qu'il croit ; le
## moteur instancie a la grille qu'il lit ici. S'ils divergent, le modele sort
## a une taille fausse d'un facteur un et demi — assez pour se voir, pas assez
## pour qu'on sache pourquoi. `tests/flora_test.gd` verifie qu'aucune entree de
## cette table ne designe un modele absent, ce qui attrape la faute de frappe ;
## l'accord des tailles, lui, se verifie en regardant.
const GRILLE_FINE: Array[String] = [
	"greenlands/herbe_01", "greenlands/herbe_02", "greenlands/herbe_03",
	"greenlands/herbe_seche", "greenlands/fleur_bleuet",
	"greenlands/fleur_tournesol", "greenlands/fleur_coeur",
	"greenlands/ginseng",
	"snowlands/herbe_gelee", "snowlands/fleur_de_glace",
	"jungles/fleur_coeur", "jungles/fleur_ame", "jungles/roseau",
	"lavalands/herbe_de_lave", "lavalands/fleur_de_lave",
]


## Tous les chemins d'un biome, roles confondus. Deduit de `ROLES` : la liste
## par biome n'est pas une source, c'est une vue. Sert aux outils, aux captures
## d'inventaire et aux tests qui verifient le lot sur le disque.
static func flora() -> Dictionary:
	var out: Dictionary = {}
	for biome in ROLES:
		var paths: Array = []
		for role in ROLES[biome]:
			for path in ROLES[biome][role]:
				if not paths.has(path):
					paths.append(path)
		out[biome] = paths
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
## Grille de dessin du lot : **4** voxels par bloc pour la flore, **1** pour les
## arbres et les filons. Une bibliotheque, une grille — c'est l'autre raison
## d'etre de la separation des deux, celle que l'invariant n° 24 ne disait pas
## encore.
##
## La valeur par defaut reste la grille fine (40/3), celle du personnage : une
## bibliotheque qui ne dit rien tombe sur la reference du projet, et c'est celle
## que prendront les creatures au jalon 2.
var _voxels_per_block: float = CWVoxelModel.VOXELS_PER_BLOCK
var _models: Dictionary = {}
## Par biome : les modeles reellement disponibles sur le disque.
var _by_biome: Dictionary = {}
## Par biome : dictionnaire role -> modeles disponibles.
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
		lib._voxels_per_block = CWVoxelModel.VOXELS_PER_BLOCK_FLORE
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
		lib._voxels_per_block = CWVoxelModel.VOXELS_PER_BLOCK_TERRAIN
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
	for biome in CWTreeRules.biomes():
		var available: Array[CWVoxelModel] = []
		for sp in CWTreeRules.SPECIES[biome]:
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
			_by_biome[biome] = available


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
	for biome in ROLES:
		var by_role: Dictionary = {}
		var available: Array[CWVoxelModel] = []
		for role in ROLES[biome]:
			var models: Array[CWVoxelModel] = []
			for model_name in ROLES[biome][role]:
				var m: CWVoxelModel = _get_or_load(model_name, palette)
				if m != null:
					models.append(m)
					if not available.has(m):
						available.append(m)
			if not models.is_empty():
				by_role[role] = models
		if not available.is_empty():
			_by_biome[biome] = available
			_by_role[biome] = by_role


## Charge un modele, ou rend celui deja en cache. La cle est le chemin : deux
## biomes qui pointent le meme fichier partagent le modele et son maillage.
func _get_or_load(model_name: String, palette: Resource) -> CWVoxelModel:
	if _models.has(model_name):
		return _models[model_name]
	var m: CWVoxelModel = CWVoxelModel.load_from(
			_dir + model_name + ".vox", palette, model_name,
			_grid_of(model_name))
	# Meme absent, on retient la reponse : sans cela chaque biome qui reference
	# un modele manquant retente un acces disque a chaque construction.
	_models[model_name] = m
	if m != null:
		max_radius = maxi(max_radius, m.radius)
		max_height = maxi(max_height, m.height)
		max_radius_blocks = maxi(max_radius_blocks, m.radius_blocks)
		max_height_blocks = maxi(max_height_blocks, m.height_blocks)
	return m


## La grille de dessin d'un modele. C'est la grille de la bibliotheque, sauf
## pour les petits props de flore, qui ont la leur (`GRILLE_FINE`).
##
## Le lot d'arbres ne passe pas par cette exception : `GRILLE_FINE` ne contient
## que des chemins de flore, et un chemin d'arbre n'y tombe jamais. C'est vrai
## par construction et non par hasard — les deux lots ont des dossiers
## disjoints.
func _grid_of(model_name: String) -> float:
	if GRILLE_FINE.has(model_name):
		return CWVoxelModel.VOXELS_PER_BLOCK_FLORE_FINE
	return _voxels_per_block


## Modeles disponibles dans un biome, roles confondus, ou un tableau vide.
## Vue d'ensemble : la dispersion, elle, passe par `for_role`.
func for_biome(biome: int) -> Array:
	return _by_biome.get(biome, [])


## Modeles disponibles pour un role dans un biome, ou un tableau vide.
##
## Un role sans modele dans ce biome rend un tableau vide, et la dispersion
## laisse alors la place nue plutot que de rabattre sur un autre role : c'est le
## comportement de la source, qui ne pose rien quand sa branche ne donne rien,
## et c'est aussi ce qui permet de livrer un lot d'assets par etapes.
func for_role(biome: int, role: int) -> Array:
	var by_role: Dictionary = _by_role.get(biome, {})
	return by_role.get(role, [])


## Roles reellement disponibles dans un biome.
func roles_of(biome: int) -> Array:
	return _by_role.get(biome, {}).keys()


func has_any() -> bool:
	return not _by_biome.is_empty()


func loaded_names() -> PackedStringArray:
	var out := PackedStringArray()
	for k in _models:
		if _models[k] != null:
			out.append(k)
	out.sort()
	return out


## Nombre moyen de plantes par cellule dans un biome.
static func density_of(biome: int) -> float:
	return DENSITY.get(biome, 0.0)
