extends Node3D

## Scene de demonstration : streaming du terrain porte depuis l'alpha, rendu en
## cubes colores, camera libre.
##
## Tout l'arbre voxel est construit ici plutot que serialise dans le .tscn :
## le generateur est une ressource scriptee dont les parametres (graine, origine
## de monde) doivent rester lisibles et modifiables au meme endroit que le reste
## du reglage de la demo.
##
## Repere : les coordonnees Godot sont relatives a `params.world_origin`, de
## sorte qu'on joue au centre de la carte d'origine (zone 512, 512) tout en
## gardant des coordonnees proches de zero.

const WORLD_Y_MIN: int = -160
const WORLD_Y_MAX: int = 900

## Bornes du reglage de distance de vue au clavier (Page haut / Page bas).
const VIEW_MIN: int = 128
const VIEW_MAX: int = 3072
const VIEW_STEP: int = 128

## Fils de generation, ou -1 pour le calcul automatique. Voir `_pick_threads`.
@export var generation_threads: int = -1

## Recherche de biome : rayon en zones de 16384 blocs, et pas de sondage a
## l'interieur d'une zone (un point par tuile).
const SEARCH_ZONE_RINGS: int = 10

## Dossier des captures prises depuis le jeu (touche F12).
const SHOT_DIR: String = "user://shots"

## Sauvegardes du monde modifie. Un fichier par graine : deux mondes ne
## partagent pas leurs editions.
const SAVE_DIR: String = "user://saves"

## Nombre de zones affichees par la carte du monde, et ses bornes. Une vue de
## cinq zones fait 320 cases de cote, soit 81 920 unites monde.
const MAP_ZONES_MIN: int = 3
const MAP_ZONES_MAX: int = 9

## Attente maximale, en millisecondes, de la fin de la sauvegarde a la
## fermeture. Borne : mieux vaut perdre les dernieres editions que la fenetre.
const SAVE_WAIT_MAX_MS: int = 3000
## Delai, en secondes, avant la capture automatique du gabarit d'echelle : le
## temps que le terrain autour du gabarit soit maille.
const BOARD_SHOT_DELAY: float = 8.0

## Cibles de teleportation, par touche. Six biomes, six touches : depuis le
## jalon 1.12 ce sont des biomes et non des matieres de surface, et les touches
## 7 a 9 n'ont plus d'emploi.
const BIOME_KEYS: Dictionary = {
	KEY_1: CWBiome.GREENLANDS,
	KEY_2: CWBiome.SNOWLANDS,
	KEY_3: CWBiome.DESERTS,
	KEY_4: CWBiome.JUNGLES,
	KEY_5: CWBiome.LAVALANDS,
	KEY_6: CWBiome.OCEANS,
}

@export var world_seed: int = 2024
## Decalage, en blocs, applique au point d'apparition par rapport au point de
## depart du monde. Sert a inspecter un endroit precis sans changer l'origine.
@export var spawn_offset: Vector2i = Vector2i.ZERO
@export var move_speed: float = 28.0
@export var boost_multiplier: float = 6.0
@export var mouse_sensitivity: float = 0.0022
## Distance de vue initiale, en blocs. Reglable en jeu par Page haut / Page bas.
##
## **La flore suit ce reglage**, toujours et sans knob separe : une couche de
## vegetation qui s'arrete a mi-chemin du terrain trace un cercle net autour du
## joueur, et ce cercle se voit bien plus qu'une touffe lointaine ne coute.
@export var view_distance: int = 384

## Conserve les modifications du terrain d'une session a l'autre.
##
## Seuls les blocs *edites* partent sur le disque : `save_generator_output` reste
## a faux, donc le monde intact reste procedural et ne coute rien. C'est le
## modele de l'original, qui ne serialise que les colonnes touchees.
@export var save_edits: bool = true

## Bloc pose au clic droit. Index de palette.
@export var build_block: int = CWPalette.STONE

## Pose le gabarit d'echelle (mires de hauteur connue, silhouette, modeles
## charges) devant le point d'apparition. Sert a regler la taille des assets
## voxels : voir nextsteps.md, §8.1.
@export var scale_board: bool = false

## Capture automatique apres ce delai, en secondes. Negatif = aucune.
##
## Sert a regarder une couche de rendu sans piloter la fenetre : lancer avec
## `--quit-after`, recuperer le PNG dans `user://shots`. Le gabarit d'echelle a
## deja son propre enchainement de captures, celui-ci est pour le reste.
@export var auto_shot_delay: float = -1.0

## Ouvre la carte du monde des le demarrage.
##
## Meme role que `scale_board` : valider en jeu ce qu'un test ne montre pas,
## sans piloter la fenetre. Avec `auto_shot_delay`, la capture sort avec la
## carte ouverte.
@export var auto_open_map: bool = false

## Bascule VoxelTerrain (detail unique) <-> VoxelLodTerrain (pyramide de LOD).
##
## RESULTAT MESURE (2026-09-03) : inutilisable en l'etat avec un rendu en cubes.
## La geometrie lointaine se construit bien, mais de larges dalles d'eau
## apparaissent en pleine plaine des le LOD 1, a des altitudes ou le terrain est
## de l'herbe. Le meme point de vue en VoxelTerrain n'en montre aucune. Cause
## exacte non etablie (le canal porte un index de palette, valeur qui ne survit
## a aucune reduction numerique, mais l'endroit de la reduction reste a
## confirmer). Conserve pour reverifier apres un changement de mesher ou de
## version. Voir docs/ROADMAP.md, section « Vue lointaine ».
@export var use_lod: bool = false
@export_range(1, 8, 1) var lod_count: int = 6
## Distance de vue en mode LOD. Sans commune mesure avec `view_distance` :
## c'est tout l'interet de la pyramide.
@export var lod_view_distance: int = 2048

var params: CWWorldParams
var generator: CWVoxelGenerator
var terrain: VoxelNode
var edits: CWWorldEdits
var stream: VoxelStream
var flora: CWFloraRenderer
var trees: CWFloraRenderer
var world_map: CWWorldMap
var map_overlay: CWMapOverlay
var camera: Camera3D
var hud: Label

var _yaw: float = 0.0
var _pitch: float = -0.25
var _captured: bool = false
var _hud_detailed: bool = false
var _hud_timer: float = 0.0
var _shutting_down: bool = false
var _edits_flushed: bool = false

var _voxel_engine: Object = null
var _viewer: VoxelViewer = null
var _pending: int = 0
var _load_started_ms: int = 0
var _load_peak: int = 0
var _pending_gen: int = 0
var _pending_mesh: int = 0
var _pending_main: int = 0
## File du flux de sauvegarde. Elle a sa place a l'ATH au meme titre que les
## deux autres : c'est elle qui bornait le chargement sans que rien ne le
## montre, un flux SQLite sans index de cles faisant attendre chaque bloc au
## disque avant sa mise en file de generation. Voir docs/ROADMAP.md.
var _pending_stream: int = 0

# Recherche de biome, executee sur un fil du pool general.
var _search_task: int = -1
var _search_target: int = -1
var _search_found: bool = false
var _search_result: Vector2i = Vector2i.ZERO
var _search_abort: bool = false
var _search_status: String = ""
## Point de depart de la recherche, releve sur le fil principal.
##
## `Node3D.get_position()` n'est pas lisible depuis un fil du pool : Godot le
## refuse et rend Vector3.ZERO, ce qui faisait partir toutes les recherches de
## l'origine du monde au lieu de la camera.
var _search_from: Vector2i = Vector2i.ZERO

# -- Carte du monde (jalon 1.10) ----------------------------------------------
var _map_open: bool = false
## Rendu de la carte : une vue de 4 096 cases par zone a ~43 ms la dalle, donc
## hors du fil principal comme la recherche de biome.
var _map_task: int = -1
var _map_zones: int = 5
var _map_origin: Vector2i = Vector2i.ZERO
var _map_image: Image = null
var _map_markers: Array = []
var _map_last_chunk: Vector2i = Vector2i(-1, -1)
var _map_flushed: bool = false


## Compte a rebours de la capture automatique. Negatif = pas de capture prevue.
var _shot_countdown: float = -1.0
## Quitter juste apres la capture demandee en ligne de commande. Sans cela il
## faut deviner un nombre de trames pour `--quit-after`, qui depend de la vitesse
## de la machine et coupe la session avant la capture une fois sur deux.
var _shot_then_quit: bool = false
## Capture du gabarit : 0 = vue d'ensemble, 1 = gros plan sur les modeles.
var _shot_stage: int = 0
var _board: CWScaleBoard = null


func _ready() -> void:
	params = CWWorldParams.new()
	params.world_seed = world_seed

	generator = CWVoxelGenerator.new()
	generator.params = params

	# Sans cela, la fenetre se ferme avant que _shutdown() ait pu decharger la
	# file de generation.
	get_tree().auto_accept_quit = false

	if Engine.has_singleton("VoxelEngine"):
		_voxel_engine = Engine.get_singleton("VoxelEngine")
		_voxel_engine.set_thread_count(_pick_threads())

	_build_environment()
	_build_terrain()
	_build_camera()
	_build_flora()
	_build_map()
	_build_hud()
	if auto_open_map:
		toggle_map()
	if scale_board:
		_build_scale_board()
		_shot_countdown = BOARD_SHOT_DELAY
	elif auto_shot_delay > 0.0:
		_shot_countdown = auto_shot_delay
	_read_cmdline()


## Reglages passes en ligne de commande, apres `--`.
##
##   <godot> --path . scenes/terrain_demo.tscn -- --biome 6 --shot 20 --graine 7
##
## Sert a valider en jeu sans piloter la fenetre : se poser dans un biome
## donne, laisser charger, prendre une capture, quitter. C'est le seul moyen
## d'obtenir une image d'une couche de rendu — un test headless n'a pas de
## rasteriseur —, et c'est ainsi que la couche des arbres a ete verifiee.
##
## `--biome` prend un index de `CWBiome` : 0 Greenlands, 1 Snowlands,
## 2 Deserts, 3 Jungles, 4 Lava Lands, 5 Oceans. Ce sont les memes que les
## touches 1 a 6, decalees d'un. `--ici x z` se pose a un point nomme, en
## coordonnees monde — celles que l'ATH affiche en haut a gauche.
func _read_cmdline() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < args.size():
		match args[i]:
			"--biome":
				if i + 1 < args.size():
					i += 1
					# La recherche part sur un fil et repose la camera quand elle
					# trouve. Le compte a rebours de la capture, lui, tourne des
					# maintenant : il faut de toute facon laisser le terrain
					# charger apres le saut.
					start_biome_search(int(args[i]))
			"--shot":
				if i + 1 < args.size():
					i += 1
					_shot_countdown = float(args[i])
					_shot_then_quit = true
			"--vue":
				if i + 1 < args.size():
					i += 1
					set_view_distance(int(args[i]))
			# Se poser a un endroit **nomme**, la ou `--biome` se pose au
			# premier endroit qui convient. Ajoute au jalon 1.13 : une falaise
			# est un objet local, et jusque-la rien ne permettait de viser une
			# capture — on relancait la recherche de biome jusqu'a tomber
			# dessus. Les coordonnees sont celles de l'ATH, donc celles qu'on
			# lit sur une capture precedente ou dans un apercu.
			"--ici":
				if i + 2 < args.size():
					place_at(Vector2i(int(args[i + 1]), int(args[i + 2])))
					i += 2
			"--sans-arbres":
				if trees != null:
					trees.enabled = false
			"--sans-flore":
				if flora != null:
					flora.enabled = false
		i += 1


## Nombre de fils de generation.
##
## **Ce n'est pas le nombre de coeurs logiques**, et c'est contre-intuitif :
## au-dela du nombre de coeurs *physiques*, l'echantillonnage du champ ne ralentit
## pas, il s'effondre. Mesure du 2026-09-05, empreinte de 48 x 16 cartes de
## hauteurs sur une machine a 16 fils logiques et 8 coeurs physiques :
##
##   | fils |  1   |  4  |  6  |  8  | 10  | 12   | 14   |
##   |------|------|-----|-----|-----|-----|------|------|
##   | mur  |12,4 s|5,7 s|4,4 s|3,2 s|7,9 s|10,9 s|13,5 s|
##
## A quatorze fils, le travail est **plus lent qu'en mono-fil**. La falaise tombe
## exactement entre 8 et 10, c'est-a-dire au passage du nombre de coeurs
## physiques : deux fils GDScript par coeur se disputent un cache et un
## allocateur, et le surcout depasse le gain. Voir docs/ROADMAP.md.
##
## On suppose donc le SMT et on prend la moitie des fils logiques. Sur une
## machine sans SMT ce choix est prudent plutot que faux ; `generation_threads`
## est la pour le remettre en cause sur une autre machine.
func _pick_threads() -> int:
	if generation_threads > 0:
		return generation_threads
	@warning_ignore("integer_division")
	var physical: int = OS.get_processor_count() / 2
	return maxi(1, physical)


func _build_terrain() -> void:
	# Le mailleur et les materiaux viennent de `CWPalette` : le terrain, les
	# modeles instancies et le gabarit d'echelle doivent partager exactement les
	# memes, sans quoi les deux grilles cessent de lire comme un seul monde.
	var mesher: VoxelMesherCubes = CWPalette.build_cubes_mesher()

	var box := AABB(
			Vector3(-1_000_000, WORLD_Y_MIN, -1_000_000),
			Vector3(2_000_000, WORLD_Y_MAX - WORLD_Y_MIN, 2_000_000))

	# Flux de sauvegarde. Monte avant que le terrain ne commence a charger :
	# poser un flux sur un terrain deja en cours de streaming laisse les blocs
	# deja charges hors de son perimetre, donc des editions perdues sans erreur.
	#
	# `save_generator_output = false` est le coeur du dispositif : le monde intact
	# se regenere, seul le diff va sur le disque. C'est le modele de l'original,
	# qui ne serialise que les colonnes qu'on a touchees.
	if save_edits:
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
		var sqlite := VoxelStreamSQLite.new()
		# Index des cles en memoire, pose **avant** la base : sans lui, chaque bloc
		# charge attend une requete disque avant d'etre seulement mis en file de
		# generation, et le chargement se retrouve borne par le flux au lieu de
		# l'etre par le generateur. Mesure a 384 blocs, a nombre de fils egal :
		# 39 s avec la requete, 32 s avec l'index, 29 s sans flux du tout.
		#
		# Le cache ne peut pas se tromper ici : `save_generator_output = false`, donc
		# la base ne contient que des blocs edites, et l'index sait lesquels.
		sqlite.set_key_cache_enabled(true)
		sqlite.database_path = "%s/graine_%d.sqlite" % [SAVE_DIR, params.world_seed]
		sqlite.save_generator_output = false
		stream = sqlite

	if use_lod:
		var lod := VoxelLodTerrain.new()
		lod.name = "VoxelLodTerrain"
		lod.generator = generator
		lod.mesher = mesher
		lod.lod_count = lod_count
		lod.view_distance = lod_view_distance
		lod.generate_collisions = false
		lod.voxel_bounds = box
		lod.format = CWPalette.build_voxel_format()
		lod.stream = stream
		terrain = lod
	else:
		var flat := VoxelTerrain.new()
		flat.name = "VoxelTerrain"
		flat.generator = generator
		flat.mesher = mesher
		flat.max_view_distance = view_distance
		# Blocs de maillage de 32 au lieu de 16 : huit fois moins de maillages et
		# d'appels de rendu pour la meme quantite de voxels. Les blocs de donnees
		# restent a 16, donc le cout de generation ne bouge pas.
		flat.mesh_block_size = 32
		flat.generate_collisions = false
		flat.bounds = box
		# Le format se pose avant tout chargement : un tampon deja cree garde la
		# profondeur qu'il avait, et la couleur sortirait tronquee a un octet.
		flat.format = CWPalette.build_voxel_format()
		flat.stream = stream
		terrain = flat
	add_child(terrain)

	# La couche d'edition prend son `VoxelTool` du terrain : elle doit donc
	# etre montee apres lui, et refaite si le terrain est reconstruit.
	edits = CWWorldEdits.new()
	edits.setup(terrain, generator, WORLD_Y_MIN)
	# La dispersion doit savoir quelles colonnes ont ete creusees, sans quoi la
	# flore reste en l'air au-dessus d'un cratere.
	generator.scatter_grid().set_edits(edits)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "FlyCamera"
	camera.far = 2048.0
	camera.fov = 72.0
	add_child(camera)

	var viewer := VoxelViewer.new()
	viewer.name = "VoxelViewer"
	_viewer = viewer
	viewer.view_distance = lod_view_distance if use_lod else view_distance
	# Le poste dominant n'est pas le cout d'un bloc mais leur nombre, et il croit
	# avec le produit des trois axes. A l'horizontale la portee sert a voir loin ;
	# a la verticale elle ne sert qu'a couvrir l'epaisseur du relief autour du
	# joueur, ce qui demande beaucoup moins.
	viewer.view_distance_vertical_ratio = 0.22
	camera.add_child(viewer)

	# On se pose au-dessus du terrain, au point de depart du monde d'origine.
	var start_h: float = generator.field().sample_column(
			params.world_origin.x + spawn_offset.x,
			params.world_origin.y + spawn_offset.y).x
	camera.position = Vector3(float(spawn_offset.x),
			maxf(start_h, float(params.sea_level)) + 26.0,
			float(spawn_offset.y))
	camera.rotation = Vector3(_pitch, _yaw, 0.0)


## Couche de flore : instanciee par-dessus le terrain, pas ecrite dedans. Les
## modeles sont treize fois plus fins que la grille des blocs, voir
## `assets/models/MODELS.md`, §1.
func _build_flora() -> void:
	flora = CWFloraRenderer.new()
	flora.name = "Flora"
	# Meme distance que le terrain, et non plus un reglage a part : voir
	# `view_distance` et `set_view_distance`.
	flora.view_distance = view_distance
	# Le gabarit sert a lire une taille contre des mires : la flore dispersee
	# n'y ferait qu'obstacle, et c'est justement elle qu'on cherche a regler.
	flora.enabled = not scale_board
	flora.setup(generator.scatter_grid(), params.world_origin, camera)
	# Son propre outil, et non celui de `CWWorldEdits` : la couche d'edition
	# change de canal et de mode a chaque coup de pioche, et une lecture qui
	# tomberait au milieu lirait le mauvais canal.
	if terrain != null and terrain.has_method("get_voxel_tool"):
		flora.set_terrain(terrain.get_voxel_tool())
	add_child(flora)

	# La couche des arbres : le meme rendu, une autre dispersion. Elle a sa
	# cellule (64 blocs), sa bibliotheque et sa marge — voir `CWTreeScatter`.
	# L'ombre portee, elle, est allumee ici et nulle part ailleurs : c'est la
	# moitie de ce qui pose un arbre dans le paysage, et il y en a cent fois
	# moins que de touffes d'herbe.
	trees = CWFloraRenderer.new()
	trees.name = "Trees"
	trees.view_distance = view_distance
	trees.enabled = not scale_board
	trees.cast_shadows = true
	trees.setup(generator.tree_scatter_grid(), params.world_origin, camera)
	if terrain != null and terrain.has_method("get_voxel_tool"):
		trees.set_terrain(terrain.get_voxel_tool())
	add_child(trees)


## Pose le gabarit d'echelle au sol, devant la camera, et regarde-le.
func _build_scale_board() -> void:
	# Les modeles distincts, quel que soit le biome qui les emploie : un meme
	# fichier revient dans plusieurs biomes, on ne le pose qu'une fois.
	var lib := CWModelLibrary.shared()
	var seen: Dictionary = {}
	var flat: Array = []
	for biome in CWModelLibrary.flora():
		for m in lib.for_biome(biome):
			if not seen.has(m.name):
				seen[m.name] = true
				flat.append(m)

	var here := _world_position()
	var ahead: Vector2i = here + Vector2i(0, -24)
	var ground: float = generator.field().sample_column(ahead.x, ahead.y).x
	var board := CWScaleBoard.build(flat)
	board.position = Vector3(
			float(ahead.x - params.world_origin.x),
			floorf(ground) + 1.0,
			float(ahead.y - params.world_origin.y))
	add_child(board)

	_board = board
	# Recul calcule pour que toute la largeur du gabarit tienne dans le champ.
	var span: float = float(CWScaleBoard.width_of(flat)) * 0.62
	camera.position = board.position + Vector3(0.0, 16.0, span)
	_pitch = -0.14
	_yaw = 0.0
	camera.rotation = Vector3(_pitch, _yaw, 0.0)


func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	# Sans tonemapping, une surface claire (neige, sable) saturee par le soleil
	# et le ciel deborde a 1.0 et perd toute sa teinte.
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 4.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.80, 0.90)
	env.fog_density = 0.0016
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)


## Carte du monde et suivi de la decouverte.
##
## La carte partage le champ de terrain du generateur : ses dalles se calculent
## a partir des memes sites de region que le relief, donc les frontieres du
## puzzle sont exactement celles du climat.
func _build_map() -> void:
	world_map = CWWorldMap.new(generator.field())
	if save_edits:
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
		world_map.load_discovery(_map_save_path())


func _map_save_path() -> String:
	return "%s/carte_%d.dat" % [SAVE_DIR, params.world_seed]


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(10, 6)
	hud.add_theme_font_size_override("font_size", 12)
	hud.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	hud.add_theme_constant_override("outline_size", 4)
	hud.add_theme_constant_override("line_spacing", 1)
	layer.add_child(hud)

	map_overlay = CWMapOverlay.new()
	map_overlay.name = "MapOverlay"
	map_overlay.visible = false
	layer.add_child(map_overlay)


## Applique une distance de vue au terrain, a l'observateur et a la flore.
##
## En mode LOD, le terrain garde la sienne (`lod_view_distance`) : seule la flore
## suit. Voir le corps.
func set_view_distance(blocks: int) -> void:
	view_distance = clampi(blocks, VIEW_MIN, VIEW_MAX)
	# Le terrain en mode LOD porte sa propre distance (`lod_view_distance`) et ne
	# suit pas ce reglage. La flore, elle, le suit dans les deux modes : c'est le
	# seul cadran que le joueur ait pour la regler, et la couper court pendant que
	# le terrain porte a deux mille blocs serait le pire des deux mondes.
	if not use_lod:
		if is_instance_valid(terrain) and terrain is VoxelTerrain:
			terrain.max_view_distance = view_distance
		if is_instance_valid(_viewer):
			_viewer.view_distance = view_distance
	if flora != null:
		flora.view_distance = view_distance
	if trees != null:
		trees.view_distance = view_distance
	_hud_timer = 0.0


# -- Carte du monde -----------------------------------------------------------

## Ouvre ou ferme la carte.
func toggle_map() -> void:
	_map_open = not _map_open
	map_overlay.visible = _map_open
	if _map_open:
		_request_map()
	_hud_timer = 0.0


## Change le nombre de zones affichees, et redemande la vue.
func set_map_zones(zones: int) -> void:
	var want: int = clampi(zones, MAP_ZONES_MIN, MAP_ZONES_MAX)
	if want == _map_zones:
		return
	_map_zones = want
	if _map_open:
		_request_map()


## Met une vue en chantier, centree sur la zone du joueur.
##
## Toujours un rendu complet, jamais une simple repose de l'image : la clarte
## d'une case change avec la decouverte, et elle est cuite dans l'image. Ce
## n'est pas cher — les **dalles** sont memoisees dans `CWWorldMap`, donc un
## rendu qui suit ne paie que la boucle de pixels, et la premiere ouverture est
## la seule a payer les vingt-cinq dalles.
func _request_map() -> void:
	if _map_task != -1:
		return
	var w: Vector2i = _world_position()
	@warning_ignore("integer_division")
	var half: int = _map_zones / 2
	_map_origin = Vector2i(
			CWWorldParams.zone_of(w.x) - half,
			CWWorldParams.zone_of(w.y) - half)
	_map_task = WorkerThreadPool.add_task(_run_map_build)


func _run_map_build() -> void:
	_map_image = world_map.render(_map_origin.x, _map_origin.y,
			_map_zones, _map_zones)
	_map_markers = world_map.render_markers(_map_origin.x, _map_origin.y,
			_map_zones, _map_zones)


func _finish_map_build() -> void:
	WorkerThreadPool.wait_for_task_completion(_map_task)
	_map_task = -1
	_show_map_view()


## Depose la vue calculee et replace le curseur du joueur.
func _show_map_view() -> void:
	if _map_image == null or not _map_open:
		return
	var w: Vector2i = _world_position()
	var base: Vector2i = _map_origin * CWWorldMap.CHUNKS_PER_ZONE
	var player := Vector2(
			float(w.x) / float(CWWorldMap.CHUNK_SIZE) - float(base.x),
			float(w.y) / float(CWWorldMap.CHUNK_SIZE) - float(base.y))
	var zone := Vector2i(CWWorldParams.zone_of(w.x), CWWorldParams.zone_of(w.y))
	var head: String = world_map.names().at(w.x, w.y)
	var sub: String = ("%d x %d zones   zone %d,%d   %d case(s) decouverte(s)"
			+ "   M fermer, +/- agrandir") % [
			_map_zones, _map_zones, zone.x, zone.y, world_map.discovered_count]
	map_overlay.show_view(_map_image, _map_markers, player, head, sub)


## Marque la carte au passage du joueur : decouverte sous ses pieds, connue dans
## ce qu'il voit. Appele quand la case change, pas a chaque image — et c'est
## aussi la seule chose qui redemande une vue quand la carte est ouverte.
func _mark_visited() -> void:
	var w: Vector2i = _world_position()
	var c := Vector2i(CWWorldMap.chunk_of(w.x), CWWorldMap.chunk_of(w.y))
	if c == _map_last_chunk:
		return
	_map_last_chunk = c
	world_map.visit(w.x, w.y, view_distance)
	if _map_open:
		_request_map()


# -- Recherche de biome -------------------------------------------------------

## Lance la recherche du cube de surface le plus proche du type demande.
##
## Le balayage tourne sur un fil du pool general : a ~60 us la colonne, une
## recherche large depasse la seconde et figerait l'affichage. Le champ de
## terrain est purement fonctionnel, donc l'appeler depuis un autre fil est sur.
func start_biome_search(target: int) -> void:
	if _search_task != -1:
		return
	_search_target = target
	_search_found = false
	_search_abort = false
	_search_status = "recherche %s..." % CWBiome.name_of(target)
	_hud_timer = 0.0
	_search_from = _world_position()
	_search_task = WorkerThreadPool.add_task(_run_biome_search)


func _run_biome_search() -> void:
	var f: CWTerrainField = generator.field()
	var cx: int = CWWorldParams.zone_of(_search_from.x)
	var cz: int = CWWorldParams.zone_of(_search_from.y)
	# Anneaux de zones concentriques : on rend le resultat le plus proche.
	for ring in SEARCH_ZONE_RINGS + 1:
		for dz in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				if _search_abort:
					return
				if _probe_zone(f, cx + dx, cz + dz):
					return


## Sonde une zone : un point au centre de chacune de ses 64 tuiles.
func _probe_zone(f: CWTerrainField, zx: int, zz: int) -> bool:
	if zx < 0 or zz < 0 or zx >= CWWorldParams.ZONE_GRID or zz >= CWWorldParams.ZONE_GRID:
		return false
	@warning_ignore("integer_division")
	var half: int = CWWorldParams.TILE_SIZE / 2
	for tz in 8:
		for tx in 8:
			var x: int = zx * CWWorldParams.ZONE_SIZE + tx * CWWorldParams.TILE_SIZE + half
			var z: int = zz * CWWorldParams.ZONE_SIZE + tz * CWWorldParams.TILE_SIZE + half
			var c: Vector3 = f.sample_column(x, z)
			if CWBiome.at(c.x, c.y, c.z, params.sea_level) == _search_target:
				_search_result = Vector2i(x, z)
				_search_found = true
				return true
	return false


func _finish_biome_search() -> void:
	WorkerThreadPool.wait_for_task_completion(_search_task)
	_search_task = -1
	if _search_abort:
		_search_status = ""
		return
	if not _search_found:
		_search_status = "%s introuvable a moins de %d zones" % [
			CWBiome.name_of(_search_target), SEARCH_ZONE_RINGS]
		return
	place_at(_search_result)
	_search_status = ""


## Pose la camera au-dessus d'un point du monde, en coordonnees **monde**.
## C'est la seconde moitie de `_finish_biome_search`, extraite pour que `--ici`
## et la recherche de biome posent la camera de la meme facon — deux hauteurs de
## survol differentes donneraient deux captures qu'on ne peut pas comparer.
func place_at(world_xz: Vector2i) -> void:
	var h: float = generator.field().sample_column(world_xz.x, world_xz.y).x
	camera.position = Vector3(
			float(world_xz.x - params.world_origin.x),
			maxf(h, float(params.sea_level)) + 26.0,
			float(world_xz.y - params.world_origin.y))


func _world_position() -> Vector2i:
	return Vector2i(
			params.world_origin.x + roundi(camera.position.x),
			params.world_origin.y + roundi(camera.position.z))


# -- Camera libre -------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not _captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_captured = true
	elif event is InputEventMouseButton and event.pressed and _captured:
		# Souris capturee : le clic edite. Gauche creuse, droit pose.
		if event.button_index == MOUSE_BUTTON_LEFT:
			_edit_at_crosshair(false)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_edit_at_crosshair(true)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		# Premiere pression : rendre la souris. Seconde : quitter. C'est aussi
		# le seul chemin qui exerce _shutdown() au clavier.
		if _captured:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_captured = false
		else:
			_shutdown()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		capture_screenshot()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		_hud_detailed = not _hud_detailed
		_hud_timer = 0.0
		_update_hud()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_M:
		toggle_map()
	elif event is InputEventKey and event.pressed and _map_open and (
			event.keycode == KEY_EQUAL or event.keycode == KEY_KP_ADD):
		set_map_zones(_map_zones + 2)
	elif event is InputEventKey and event.pressed and _map_open and (
			event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT):
		set_map_zones(_map_zones - 2)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_PAGEUP:
		set_view_distance(view_distance + VIEW_STEP)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_PAGEDOWN:
		set_view_distance(view_distance - VIEW_STEP)
	elif event is InputEventKey and event.pressed and BIOME_KEYS.has(event.keycode):
		start_biome_search(BIOME_KEYS[event.keycode])
	elif event is InputEventMouseMotion and _captured:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity,
				-1.5, 1.5)
		camera.rotation = Vector3(_pitch, _yaw, 0.0)


## Creuse ou pose au centre de l'ecran.
##
## `VoxelTool.raycast` traverse les *donnees*, pas la physique : le terrain n'a
## pas de collisions (`generate_collisions = false`) et n'en a pas besoin pour
## ca. Le rayon rend la case pleine touchee et la case vide qui la precede — la
## premiere se creuse, la seconde se batit.
func _edit_at_crosshair(build: bool) -> void:
	if edits == null or not edits.has_tool():
		return
	var hit: VoxelRaycastResult = edits.raycast(
			camera.global_position, -camera.global_transform.basis.z)
	if hit == null:
		return
	if build:
		edits.place(hit.previous_position, build_block)
	else:
		edits.dig(hit.position)
	_hud_timer = 0.0


func _process(delta: float) -> void:
	if _shutting_down:
		return

	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		dir -= camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_S):
		dir += camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_A):
		dir -= camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_D):
		dir += camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_SPACE):
		dir += Vector3.UP
	if Input.is_key_pressed(KEY_CTRL):
		dir += Vector3.DOWN
	if dir != Vector3.ZERO:
		var speed: float = move_speed
		if Input.is_key_pressed(KEY_SHIFT):
			speed *= boost_multiplier
		camera.position += dir.normalized() * speed * delta

	if _search_task != -1 and WorkerThreadPool.is_task_completed(_search_task):
		_finish_biome_search()

	if _map_task != -1 and WorkerThreadPool.is_task_completed(_map_task):
		_finish_map_build()
	if world_map != null:
		_mark_visited()

	# Reeclairage des editions de la frame, en un seul passage. Le terrain genere
	# n'a pas besoin de lumiere — un champ de hauteurs est eclaire partout ou on
	# le voit — donc ceci ne tourne qu'apres un coup de pioche.
	if edits != null and edits.has_relight_pending():
		edits.relight()

	if _shot_countdown > 0.0:
		_shot_countdown -= delta
		if _shot_countdown <= 0.0:
			capture_screenshot()
			if _shot_then_quit:
				_shutdown()
				return
			if _shot_stage == 0 and _board != null:
				# Second cliche, cadre sur les modeles : a la distance qui montre
				# la mire de 16 blocs, une plante d'un demi-bloc est un pixel.
				_shot_stage = 1
				# Recul cadre sur la *zone des modeles*, pas sur le gabarit
				# entier : les mires vont a 16 blocs, les plantes a un demi.
				# Recul cale sur la largeur d'une rangee, pas sur toute la
				# zone : a 16/9 le champ horizontal couvre un peu plus de deux
				# fois la distance, donc 0.4 fois la largeur cadre la rangee
				# entiere en laissant une marge.
				camera.position = _board.position + Vector3(
						_board.models_center, 3.5,
						_board.models_z + _board.models_span * 0.4)
				_pitch = -0.22
				camera.rotation = Vector3(_pitch, _yaw, 0.0)
				_shot_countdown = 1.5

	# Chaque rafraichissement echantillonne le champ de terrain : a 8 Hz le
	# cout est negligeable, a la frequence d'affichage il ne l'est plus.
	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_hud_timer = 0.125
		_refresh_pending()
		_update_hud()


## Nombre de blocs encore a generer ou a mailler. Sert a savoir quand une
## mesure est valide : tant que ce compteur n'est pas nul, la vue est
## incomplete et le nombre d'images par seconde n'est pas representatif.
func _refresh_pending() -> void:
	if _voxel_engine == null:
		return
	var tasks: Dictionary = _voxel_engine.get_stats().get("tasks", {})
	_pending_gen = int(tasks.get("generation", 0))
	_pending_mesh = int(tasks.get("meshing", 0))
	_pending_main = int(tasks.get("main_thread", 0))
	_pending_stream = int(tasks.get("streaming", 0))
	var now: int = _pending_gen + _pending_mesh + _pending_stream
	if now > 0:
		if _pending == 0:
			_load_started_ms = Time.get_ticks_msec()
			_load_peak = 0
		_load_peak = maxi(_load_peak, now)
	elif _pending > 0:
		# Front descendant : la vue est complete, la mesure devient valide.
		print("[demo] vue %d blocs : stabilisee en %.1f s (pic %d taches, %d fils%s)" % [
			view_distance,
			float(Time.get_ticks_msec() - _load_started_ms) / 1000.0,
			_load_peak,
			_voxel_engine.get_thread_count(),
			"" if stream == null else ", flux actif"])
	_pending = now


func _update_hud() -> void:
	var p := camera.position
	var wx: int = params.world_origin.x + roundi(p.x)
	var wz: int = params.world_origin.y + roundi(p.z)
	var c: Vector3 = generator.field().sample_column(wx, wz)
	var biome: int = CWBiome.at(c.x, c.y, c.z, params.sea_level)
	var surface: int = CWPalette.surface_of(biome, c.x - float(params.sea_level),
			c.y, c.z, wx, wz, generator.field().cliff_factor(wx, wz))

	var busy: String = ""
	if _search_status != "":
		busy = "   " + _search_status
	elif _pending > 0:
		busy = "   flux %d / gen %d / maillage %d" % [
				_pending_stream, _pending_gen, _pending_mesh]

	var region: String = ""
	if world_map != null:
		region = "   " + world_map.names().at(wx, wz)

	var lines: Array[String] = [
		"%d, %d   y %d  (sol %d)%s" % [wx, wz, roundi(p.y), roundi(c.x), region],
		"%s / %s   T %.2f (%.0f C)  H %.0f %%   %d ips%s" % [
			CWBiome.name_of(biome), CWPalette.name_of(surface),
			c.y, CWBiome.celsius(c.y), c.z * 100.0,
			Engine.get_frames_per_second(), busy],
	]
	if _hud_detailed:
		lines.append("")
		lines.append("graine %d   zone %d,%d   tuile %d,%d" % [
			params.world_seed,
			CWWorldParams.zone_of(wx), CWWorldParams.zone_of(wz),
			CWWorldParams.tile_of(wx), CWWorldParams.tile_of(wz)])
		# Element de la tuile courante : sans lui, impossible de savoir en jeu
		# si le creux qu'on regarde est un cratere ou du relief ordinaire.
		var feat: CWTileFeature = generator.field().feature_at(wx, wz)
		if feat == null or feat.type == 0:
			lines.append("element : aucun")
		else:
			var w: float = generator.field().falloff_weight(feat, wx, wz)
			lines.append("element type %d%s   rayon %d   h %d   poids %.2f" % [
				feat.type, "*" if feat.affects_height() else "",
				roundi(feat.radius), roundi(feat.height), w])
		lines.append("chenal %.3f   vue %d blocs%s   %d fils" % [
			generator.field().channel_field(wx, wz),
			lod_view_distance if use_lod else view_distance,
			("   LOD x%d" % lod_count) if use_lod else "",
			_voxel_engine.get_thread_count() if _voxel_engine != null else 0])
		if flora != null:
			var fs: Vector2i = flora.stats()
			lines.append("flore : %d plantes sur %d cellules, vue %d blocs%s" % [
				fs.y, fs.x, flora.view_distance,
				"" if flora.enabled else "   (coupee)"])
		if trees != null:
			var ts: Vector2i = trees.stats()
			lines.append("arbres : %d pieces sur %d cellules de 64%s" % [
				ts.y, ts.x, "" if trees.enabled else "   (coupee)"])
		if edits != null:
			lines.append("editions : %d%s   pose : %s   lumiere %.1f ms" % [
				edits.edit_count,
				"" if stream != null else "   (non sauvegardees)",
				CWPalette.name_of(build_block),
				float(edits.last_relight_usec) / 1000.0])
		if world_map != null:
			lines.append("carte : %d case(s) decouverte(s), %d dalle(s) en cache" % [
				world_map.discovered_count, world_map.slab_count()])
		lines.append("ZQSD/WASD + souris · Maj vite · Espace/Ctrl · Echap souris puis quitter")
		lines.append("Clic gauche : creuser · clic droit : poser")
		lines.append("Page haut/bas : distance de vue · M : carte du monde")
		lines.append("1 herbe · 2 herbe seche · 3 jungle · 4 marais · 5 sable")
		lines.append("6 neige · 7 toundra · 8 roche · 9 fond marin")
	else:
		lines.append("F1 details")
	hud.text = "\n".join(lines)


## Enregistre l'image affichee dans `user://shots`.
##
## Passer par le jeu plutot que par une capture de fenetre : une fenetre en
## arriere-plan ne rend plus, donc toute capture prise depuis l'exterieur rend
## une image perimee ou rien du tout.
func capture_screenshot() -> String:
	var image: Image = get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	var path: String = "%s/%s.png" % [SHOT_DIR,
			Time.get_datetime_string_from_system(false, false).replace(":", "")
					.replace(" ", "_").replace("-", "")]
	image.save_png(path)
	print("[demo] capture -> ", ProjectSettings.globalize_path(path))
	return path


# -- Arret ---------------------------------------------------------------------

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_shutdown()
	elif what == NOTIFICATION_EXIT_TREE:
		# Deuxieme filet, et il sert : fermer la fenetre passe bien par
		# WM_CLOSE_REQUEST, mais `--quit-after` et tout appel direct a
		# `SceneTree.quit()` n'envoient rien du tout. Sans cette branche, une
		# session lancee pour une capture automatique perd ses editions en
		# silence — constate le 2026-09-05, 647 editions appliquees et zero
		# ecrite. `_flush_edits` se garde lui-meme contre le double appel.
		_flush_edits()
		_flush_map()


## Rend la main tout de suite au lieu d'attendre la file de streaming.
##
## Voxel Tools attend, a la fermeture, que son pool de fils ait fini les taches
## deja soumises. Trois gestes suffisent a ramener cette attente a rien :
##   1. le generateur bascule en mode arret, donc les blocs encore en file sont
##      remplis d'air en quelques microsecondes au lieu de ~20 ms ;
##   2. l'observateur est retire, donc plus aucun bloc n'est demande ;
##   3. le terrain arrete son chargement automatique.
## Le monde intact se regenere a la volee, donc il n'y a rien a sauver de ce
## cote. Les **editions**, elles, seraient perdues : elles partent sur le disque
## avant tout le reste, parce que les deux gestes qui suivent — generateur en
## mode arret, chargement automatique coupe — rendent le terrain inutilisable
## pour une sauvegarde.
func _shutdown() -> void:
	if _shutting_down:
		return
	_shutting_down = true

	_flush_edits()
	_flush_map()

	if generator != null:
		generator.request_shutdown()
	# Une recherche en cours doit etre rejointe, sinon le pool attend sa fin.
	_search_abort = true
	if _search_task != -1:
		WorkerThreadPool.wait_for_task_completion(_search_task)
		_search_task = -1
	if _map_task != -1:
		WorkerThreadPool.wait_for_task_completion(_map_task)
		_map_task = -1
	if is_instance_valid(camera):
		var viewer := camera.get_node_or_null("VoxelViewer")
		if viewer != null:
			camera.remove_child(viewer)
			viewer.queue_free()
	# Propre a VoxelTerrain ; VoxelLodTerrain n'expose pas ce reglage.
	if is_instance_valid(terrain) and terrain is VoxelTerrain:
		terrain.automatic_loading_enabled = false

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().quit()


## Ecrit les blocs modifies, puis attend que le flux ait fini.
##
## `save_modified_blocks` est asynchrone : rendre la main tout de suite ferait
## quitter le processus au milieu de l'ecriture. On attend donc son temoin, mais
## avec une borne — une sauvegarde qui ne finit pas ne doit pas empecher de
## fermer la fenetre, et le pire cas est de perdre les dernieres editions, pas
## le fichier.
func _flush_edits() -> void:
	if _edits_flushed:
		return
	if stream == null or not is_instance_valid(terrain):
		return
	if edits == null or edits.edit_count == 0:
		return
	_edits_flushed = true
	var tracker: VoxelSaveCompletionTracker = terrain.save_modified_blocks()
	var waited: int = 0
	var deadline: int = Time.get_ticks_msec() + SAVE_WAIT_MAX_MS
	while tracker != null and not tracker.is_complete() and not tracker.is_aborted():
		if Time.get_ticks_msec() >= deadline:
			break
		OS.delay_msec(4)
		waited += 4
	stream.flush()
	print("[demo] %d edition(s) sauvegardees en %d ms" % [edits.edit_count, waited])


## Ecrit les cases decouvertes. Meme filet que les editions : une fermeture par
## `--quit-after` n'envoie pas WM_CLOSE_REQUEST, donc l'ecriture doit aussi
## partir depuis NOTIFICATION_EXIT_TREE.
func _flush_map() -> void:
	if _map_flushed or world_map == null or not save_edits:
		return
	if world_map.discovered_count == 0:
		return
	_map_flushed = true
	world_map.save_discovery(_map_save_path())
	print("[demo] carte : %d case(s) decouverte(s) sauvegardees" % world_map.discovered_count)
