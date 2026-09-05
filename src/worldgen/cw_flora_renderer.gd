class_name CWFloraRenderer
extends Node3D

## Rendu de la couche de flore (jalon 1.7) : les plantes dispersees par
## `CWScatter`, instanciees autour de l'observateur.
##
## -- Pourquoi pas dans le terrain ---------------------------------------------
## Un modele de flore est sur la grille fine (1 / CWVoxelModel.VOXELS_PER_BLOCK
## de bloc) : l'ecrire dans les donnees voxels du monde reviendrait a le grossir
## treize fois. Il est donc maille a part — meme mailleur, meme palette, meme
## materiau que le terrain, ce qui est la condition pour que les deux grilles
## lisent comme un seul monde — puis instancie a l'echelle.
##
## Ce qu'on perd, et qu'il faut savoir : la flore ne se creuse pas, ne porte pas
## de collision, et ne participera pas a l'eclairage voxel du jalon 1.9. Ce
## qu'on gagne : elle quitte le chemin critique de generation, qui est le poste
## dominant du chargement.
##
## -- La cellule est l'unite ---------------------------------------------------
## Une cellule de dispersion (CWScatter.CELL_SIZE blocs de cote) donne un noeud,
## portant un `MultiMeshInstance3D` par modele qu'elle emploie. On cree et on
## detruit par cellule entiere : c'est la granularite du tirage, donc il n'y a
## rien a decouper ni a recoudre.
##
## -- Ce qui coute -------------------------------------------------------------
## Construire une cellule demande un echantillonnage de colonne par plante
## (~75 us), soit de l'ordre de la milliseconde. Une vue de 128 blocs en demande
## deux cents : c'est trop pour le fil principal. Les cellules manquantes sont
## donc construites par lots sur un fil du pool — `CWScatter.cell` est sur a
## appeler depuis plusieurs fils — et le fil principal ne fait plus que lire le
## resultat et poser les transformations, ce qui est immediat.

## Cellules construites par lot sur le fil de fond. Assez grand pour que le cout
## d'une tache soit negligeable devant son contenu, assez petit pour que la
## flore apparaisse par vagues plutot que d'un bloc apres un long silence.
const BATCH: int = 48

## Marge, en cellules, avant qu'une cellule sortie du champ soit detruite.
## Sans elle, une camera qui oscille sur une frontiere reconstruit sans fin.
const KEEP_MARGIN: int = 1

## Distance de vue de la flore, en blocs. Bien plus courte que celle du terrain :
## un modele fin a plusieurs centaines de blocs ne couvre plus un pixel, et
## l'original fait disparaitre sa flore de la meme facon.
@export var view_distance: int = 128:
	set(value):
		view_distance = maxi(0, value)
		_wanted.clear()

## Coupe le rendu de la flore sans demonter le noeud (gabarit d'echelle,
## comparaison d'un meme monde avec et sans).
@export var enabled: bool = true:
	set(value):
		enabled = value
		if not enabled:
			clear()

var _scatter: CWScatter = null
var _origin: Vector2i = Vector2i.ZERO
var _camera: Node3D = null

## Cellules posees : indice de cellule -> noeud.
var _live: Dictionary = {}
## Cellules a construire, de la plus proche a la plus lointaine.
var _queue: Array[Vector2i] = []
## Cellules demandees par la position courante. Vide = a recalculer.
var _wanted: Dictionary = {}
var _task: int = -1
var _batch: Array[Vector2i] = []
var _last_cell: Vector2i = Vector2i(0x7FFFFFFF, 0x7FFFFFFF)


## Transformation d'une plante : de son ancre en coordonnees monde vers le
## repere du maillage de son modele.
##
## Isolee ici parce que c'est le seul endroit ou les deux grilles se rencontrent,
## et le seul calcul de cette couche qui puisse etre faux sans qu'on le voie —
## une plante enterree d'un demi-bloc ou glissee d'un quart de gabarit a chaque
## quart de tour reste plausible a l'oeil. Verifiee dans `tests/flora_test.gd`.
static func instance_transform(pl: CWScatter.Placement,
		world_origin: Vector2i) -> Transform3D:
	var scale: float = 1.0 / CWVoxelModel.VOXELS_PER_BLOCK
	var basis := Basis(Vector3.UP, float(pl.rotation) * PI * 0.5).scaled(
			Vector3(scale, scale, scale))
	var pos := Vector3(
			float(pl.x - world_origin.x) + pl.fx,
			float(pl.y),
			float(pl.z - world_origin.y) + pl.fz)
	# `mesh_offset` est dans le repere du maillage : il subit la rotation et
	# l'echelle comme le reste, sinon la plante glisse d'un quart de gabarit a
	# chaque quart de tour.
	return Transform3D(basis, pos + basis * pl.model.mesh_offset())


func setup(scatter: CWScatter, world_origin: Vector2i, camera: Node3D) -> void:
	_scatter = scatter
	_origin = world_origin
	_camera = camera


## Cellules posees et plantes instanciees. Pour l'ATH et les tests.
func stats() -> Vector2i:
	var plants: int = 0
	for c in _live:
		plants += int(_live[c].get_meta("plant_count", 0))
	return Vector2i(_live.size(), plants)


func clear() -> void:
	for c in _live:
		_live[c].queue_free()
	_live.clear()
	_queue.clear()
	_wanted.clear()
	_last_cell = Vector2i(0x7FFFFFFF, 0x7FFFFFFF)


func _process(_delta: float) -> void:
	if not enabled or _scatter == null or _camera == null:
		return
	if not _scatter.library().has_any():
		return
	_refresh_wanted()
	_pump()


## Recalcule l'ensemble des cellules a poser. Tant que l'observateur reste dans
## la meme cellule, il n'y a rien a decider.
func _refresh_wanted() -> void:
	var here := Vector2i(
			CWScatter.cell_of(_origin.x + floori(_camera.global_position.x)),
			CWScatter.cell_of(_origin.y + floori(_camera.global_position.z)))
	if here == _last_cell and not _wanted.is_empty():
		return
	_last_cell = here

	var reach: int = (view_distance + CWScatter.CELL_SIZE - 1) >> CWScatter.CELL_SHIFT
	_wanted.clear()
	var pending: Array[Vector2i] = []
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if dx * dx + dz * dz > reach * reach:
				continue
			var c := Vector2i(here.x + dx, here.y + dz)
			_wanted[c] = true
			if not _live.has(c):
				pending.append(c)

	# Du plus proche au plus loin : ce qu'on a sous les yeux d'abord.
	pending.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - here).length_squared() < (b - here).length_squared())
	_queue = pending

	# Au-dela de la marge, on rend la memoire.
	var drop: int = reach + KEEP_MARGIN
	var stale: Array[Vector2i] = []
	for c in _live:
		if absi(c.x - here.x) > drop or absi(c.y - here.y) > drop:
			stale.append(c)
	for c in stale:
		_live[c].queue_free()
		_live.erase(c)


## Fait avancer la construction : un lot en vol a la fois.
func _pump() -> void:
	if _task != -1:
		if not WorkerThreadPool.is_task_completed(_task):
			return
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		# Les cellules sont desormais dans le cache de CWScatter : les relire est
		# immediat, et c'est le fil principal qui cree les noeuds.
		for c in _batch:
			if _wanted.has(c) and not _live.has(c):
				_build_node(c)
		_batch.clear()

	if _queue.is_empty():
		return
	_batch.assign(_queue.slice(0, BATCH))
	_queue = _queue.slice(BATCH)
	var cells: Array[Vector2i] = _batch.duplicate()
	var scatter: CWScatter = _scatter
	_task = WorkerThreadPool.add_task(func() -> void:
		for c in cells:
			scatter.cell(c.x, c.y))


## Un noeud par cellule, un MultiMesh par modele qu'elle emploie.
func _build_node(c: Vector2i) -> void:
	var plants: Array = _scatter.cell(c.x, c.y)
	if plants.is_empty():
		return

	var by_model: Dictionary = {}
	for pl in plants:
		if not by_model.has(pl.model):
			by_model[pl.model] = []
		by_model[pl.model].append(pl)

	var node := Node3D.new()
	node.name = "Cell%d_%d" % [c.x, c.y]
	node.set_meta("plant_count", plants.size())

	var scale: float = 1.0 / CWVoxelModel.VOXELS_PER_BLOCK
	var instances: Array[MultiMeshInstance3D] = []
	var bounds := AABB()
	var first: bool = true

	for model in by_model:
		var mesh: ArrayMesh = model.mesh()
		if mesh == null:
			continue
		var list: Array = by_model[model]
		var reach: float = float(model.radius) * scale
		var tall: float = float(model.height) * scale

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			var pl: CWScatter.Placement = list[i]
			mm.set_instance_transform(i, instance_transform(pl, _origin))
			var pos: Vector3 = pl.origin() - Vector3(
					float(_origin.x), 0.0, float(_origin.y))
			var box := AABB(pos - Vector3(reach, 0.0, reach),
					Vector3(reach * 2.0, tall, reach * 2.0))
			bounds = box if first else bounds.merge(box)
			first = false

		var mmi := MultiMeshInstance3D.new()
		mmi.name = model.name
		mmi.multimesh = mm
		mmi.material_override = CWPalette.build_opaque_material()
		# Des milliers de touffes d'un demi-bloc dans la carte d'ombres coutent
		# cher pour une ombre qu'on ne distingue pas de celle du sol.
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instances.append(mmi)
		node.add_child(mmi)

	if instances.is_empty():
		node.queue_free()
		return

	# Sans boite explicite, la visibilite d'un MultiMesh se recalcule a partir de
	# ses instances ; on la connait deja, on la donne. Le noeud est a l'origine,
	# donc les coordonnees locales sont celles du monde rendu.
	for mmi in instances:
		mmi.custom_aabb = bounds

	add_child(node)
	_live[c] = node
