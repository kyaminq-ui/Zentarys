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

## Nombre de coeurs laisses au fil principal et au rendu. Le reste part au pool
## de generation : par defaut Voxel Tools n'en prend que la moitie, ce qui est
## prudent pour un generateur natif mais bride le notre, qui est en GDScript et
## donc le poste dominant du chargement.
const CORES_RESERVED: int = 2

## Recherche de biome : rayon en zones de 16384 blocs, et pas de sondage a
## l'interieur d'une zone (un point par tuile).
const SEARCH_ZONE_RINGS: int = 10

## Dossier des captures prises depuis le jeu (touche F12).
const SHOT_DIR: String = "user://shots"

## Sauvegardes du monde modifie. Un fichier par graine : deux mondes ne
## partagent pas leurs editions.
const SAVE_DIR: String = "user://saves"

## Attente maximale, en millisecondes, de la fin de la sauvegarde a la
## fermeture. Borne : mieux vaut perdre les dernieres editions que la fenetre.
const SAVE_WAIT_MAX_MS: int = 3000
## Delai, en secondes, avant la capture automatique du gabarit d'echelle : le
## temps que le terrain autour du gabarit soit maille.
const BOARD_SHOT_DELAY: float = 8.0

## Cibles de teleportation, par touche.
const BIOME_KEYS: Dictionary = {
	KEY_1: CWPalette.GRASS,
	KEY_2: CWPalette.GRASS_DRY,
	KEY_3: CWPalette.GRASS_JUNGLE,
	KEY_4: CWPalette.SWAMP,
	KEY_5: CWPalette.SAND,
	KEY_6: CWPalette.SNOW,
	KEY_7: CWPalette.TUNDRA,
	KEY_8: CWPalette.STONE,
	KEY_9: CWPalette.GRAVEL,
}

@export var world_seed: int = 2024
## Decalage, en blocs, applique au point d'apparition par rapport au point de
## depart du monde. Sert a inspecter un endroit precis sans changer l'origine.
@export var spawn_offset: Vector2i = Vector2i.ZERO
@export var move_speed: float = 28.0
@export var boost_multiplier: float = 6.0
@export var mouse_sensitivity: float = 0.0022
## Distance de vue initiale, en blocs. Reglable en jeu par Page haut / Page bas.
@export var view_distance: int = 384
## Distance de vue de la flore, en blocs. Sans rapport avec celle du terrain :
## une touffe d'un demi-bloc ne couvre plus un pixel bien avant l'horizon.
@export var flora_distance: int = 128

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
## voxels : voir nextsteps.md, §7.1.
@export var scale_board: bool = false

## Capture automatique apres ce delai, en secondes. Negatif = aucune.
##
## Sert a regarder une couche de rendu sans piloter la fenetre : lancer avec
## `--quit-after`, recuperer le PNG dans `user://shots`. Le gabarit d'echelle a
## deja son propre enchainement de captures, celui-ci est pour le reste.
@export var auto_shot_delay: float = -1.0

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

## Compte a rebours de la capture automatique. Negatif = pas de capture prevue.
var _shot_countdown: float = -1.0
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
		var wanted: int = maxi(1, OS.get_processor_count() - CORES_RESERVED)
		if wanted > _voxel_engine.get_thread_count():
			_voxel_engine.set_thread_count(wanted)

	_build_environment()
	_build_terrain()
	_build_camera()
	_build_flora()
	_build_hud()
	if scale_board:
		_build_scale_board()
		_shot_countdown = BOARD_SHOT_DELAY
	elif auto_shot_delay > 0.0:
		_shot_countdown = auto_shot_delay


func _build_terrain() -> void:
	var mesher := VoxelMesherCubes.new()
	mesher.color_mode = VoxelMesherCubes.COLOR_MESHER_PALETTE
	mesher.palette = CWPalette.build_voxel_palette()
	mesher.greedy_meshing_enabled = true

	var opaque := StandardMaterial3D.new()
	opaque.vertex_color_use_as_albedo = true
	opaque.vertex_color_is_srgb = true
	opaque.roughness = 0.95
	opaque.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mesher.opaque_material = opaque

	var water := StandardMaterial3D.new()
	water.vertex_color_use_as_albedo = true
	water.vertex_color_is_srgb = true
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.12
	water.metallic = 0.15
	mesher.transparent_material = water

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
	flora.view_distance = flora_distance
	# Le gabarit sert a lire une taille contre des mires : la flore dispersee
	# n'y ferait qu'obstacle, et c'est justement elle qu'on cherche a regler.
	flora.enabled = not scale_board
	flora.setup(generator.scatter_grid(), params.world_origin, camera)
	add_child(flora)


## Pose le gabarit d'echelle au sol, devant la camera, et regarde-le.
func _build_scale_board() -> void:
	# Les modeles distincts, quel que soit le biome qui les emploie : un meme
	# fichier revient dans plusieurs biomes, on ne le pose qu'une fois.
	var lib := CWModelLibrary.shared()
	var seen: Dictionary = {}
	var flat: Array = []
	for surface in CWModelLibrary.FLORA:
		for m in lib.for_surface(surface):
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


## Applique une distance de vue au terrain et a l'observateur.
##
## Sans effet en mode LOD, ou la distance est portee par `lod_view_distance`.
func set_view_distance(blocks: int) -> void:
	if use_lod:
		return
	view_distance = clampi(blocks, VIEW_MIN, VIEW_MAX)
	if is_instance_valid(terrain) and terrain is VoxelTerrain:
		terrain.max_view_distance = view_distance
	if is_instance_valid(_viewer):
		_viewer.view_distance = view_distance
	_hud_timer = 0.0


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
	_search_status = "recherche %s..." % CWPalette.name_of(target)
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
			if CWPalette.surface_index(c.x, c.y, c.z, params.sea_level) == _search_target:
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
			CWPalette.name_of(_search_target), SEARCH_ZONE_RINGS]
		return
	var h: float = generator.field().sample_column(_search_result.x, _search_result.y).x
	camera.position = Vector3(
			float(_search_result.x - params.world_origin.x),
			maxf(h, float(params.sea_level)) + 26.0,
			float(_search_result.y - params.world_origin.y))
	_search_status = ""


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

	if _shot_countdown > 0.0:
		_shot_countdown -= delta
		if _shot_countdown <= 0.0:
			capture_screenshot()
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
	var now: int = _pending_gen + _pending_mesh + int(tasks.get("streaming", 0))
	if now > 0:
		if _pending == 0:
			_load_started_ms = Time.get_ticks_msec()
			_load_peak = 0
		_load_peak = maxi(_load_peak, now)
	elif _pending > 0:
		# Front descendant : la vue est complete, la mesure devient valide.
		print("[demo] vue %d blocs : stabilisee en %.1f s (pic %d taches, %d fils)" % [
			view_distance,
			float(Time.get_ticks_msec() - _load_started_ms) / 1000.0,
			_load_peak,
			_voxel_engine.get_thread_count()])
	_pending = now


func _update_hud() -> void:
	var p := camera.position
	var wx: int = params.world_origin.x + roundi(p.x)
	var wz: int = params.world_origin.y + roundi(p.z)
	var c: Vector3 = generator.field().sample_column(wx, wz)
	var surface: int = CWPalette.surface_index(c.x, c.y, c.z, params.sea_level)

	var busy: String = ""
	if _search_status != "":
		busy = "   " + _search_status
	elif _pending > 0:
		busy = "   gen %d / maillage %d" % [_pending_gen, _pending_mesh]

	var lines: Array[String] = [
		"%d, %d   y %d  (sol %d)" % [wx, wz, roundi(p.y), roundi(c.x)],
		"%s   T %.2f  H %.2f   %d ips%s" % [
			CWPalette.name_of(surface), c.y, c.z,
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
		if edits != null:
			lines.append("editions : %d%s   pose : %s" % [
				edits.edit_count,
				"" if stream != null else "   (non sauvegardees)",
				CWPalette.name_of(build_block)])
		lines.append("ZQSD/WASD + souris · Maj vite · Espace/Ctrl · Echap souris puis quitter")
		lines.append("Clic gauche : creuser · clic droit : poser")
		lines.append("Page haut/bas : distance de vue")
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

	if generator != null:
		generator.request_shutdown()
	# Une recherche en cours doit etre rejointe, sinon le pool attend sa fin.
	_search_abort = true
	if _search_task != -1:
		WorkerThreadPool.wait_for_task_completion(_search_task)
		_search_task = -1
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
