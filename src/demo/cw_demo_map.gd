class_name CWDemoMap
extends RefCounted

## La carte du monde de la demo : son etat, son rendu hors du fil principal, sa
## decouverte et sa sauvegarde (jalon 1.10).
##
## -- Pourquoi une classe a elle ------------------------------------------------
##
## Dix fonctions, huit variables d'etat et deux constantes vivaient dans
## `terrain_demo.gd` melangees au terrain, a la camera, a l'ATH et aux captures.
## Elles en sortent le 2026-09-10 : c'est un metier complet — un rendu, une
## tache de fond, un fichier sur le disque — et il ne partage rien avec le reste
## de la demo qu'une **position de joueur**, qui lui est passee a chaque appel.
##
## C'est ce que veut la regle de decoupe : *un fichier, une decision*. La
## decision ici est « ou en est la carte, et faut-il la redessiner ».
##
## -- Ce qu'elle ne fait pas ----------------------------------------------------
##
## Elle ne lit pas la position du joueur, elle la recoit. `Node3D.get_position()`
## n'est de toute facon pas lisible depuis un fil du pool — Godot le refuse et
## rend `Vector3.ZERO` —, et c'est le meme piege que la recherche de biome a
## paye. Tout ce qui vient de la scene entre par un argument.

## Bornes du nombre de zones affichees. Une vue de cinq zones fait 320 cases de
## cote, soit 81 920 unites monde.
const ZONES_MIN: int = 3
const ZONES_MAX: int = 9

var world_map: CWWorldMap
var overlay: CWMapOverlay

var _open: bool = false
## Rendu de la carte : une vue de 4 096 cases par zone a ~43 ms la dalle, donc
## hors du fil principal comme la recherche de biome.
var _task: int = -1
var _zones: int = 5
var _origin: Vector2i = Vector2i.ZERO
var _image: Image = null
var _markers: Array = []
var _last_chunk: Vector2i = Vector2i(-1, -1)
var _flushed: bool = false
var _save_path: String = ""


## La carte partage le champ de terrain du generateur : ses dalles se calculent
## a partir des memes sites de region que le relief, donc les frontieres du
## puzzle sont exactement celles du climat.
func _init(field: CWTerrainField, map_overlay: CWMapOverlay,
		save_path: String = "") -> void:
	world_map = CWWorldMap.new(field)
	overlay = map_overlay
	_save_path = save_path
	if _save_path != "":
		world_map.load_discovery(_save_path)


func is_open() -> bool:
	return _open


func zones() -> int:
	return _zones


func discovered_count() -> int:
	return world_map.discovered_count


func slab_count() -> int:
	return world_map.slab_count()


## Le nom de la region d'un point, en coordonnees monde. L'ATH le montre.
func region_name(wx: int, wz: int) -> String:
	return world_map.names().at(wx, wz)


func toggle(w: Vector2i) -> void:
	_open = not _open
	overlay.visible = _open
	if _open:
		_request(w)


## Change le nombre de zones affichees, et redemande la vue.
func zoom(step: int, w: Vector2i) -> void:
	var want: int = clampi(_zones + step, ZONES_MIN, ZONES_MAX)
	if want == _zones:
		return
	_zones = want
	if _open:
		_request(w)


## Appele une fois par image. Ramasse la vue quand elle est prete, puis marque
## la carte au passage du joueur.
func poll(w: Vector2i, view_distance: int) -> void:
	if _task != -1 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_show(w)
	_mark_visited(w, view_distance)


## Marque la carte au passage du joueur : decouverte sous ses pieds, connue dans
## ce qu'il voit. N'agit que quand la case change, pas a chaque image — et c'est
## aussi la seule chose qui redemande une vue quand la carte est ouverte.
func _mark_visited(w: Vector2i, view_distance: int) -> void:
	var c := Vector2i(CWWorldMap.chunk_of(w.x), CWWorldMap.chunk_of(w.y))
	if c == _last_chunk:
		return
	_last_chunk = c
	world_map.visit(w.x, w.y, view_distance)
	if _open:
		_request(w)


## Met une vue en chantier, centree sur la zone du joueur.
##
## Toujours un rendu complet, jamais une simple repose de l'image : la clarte
## d'une case change avec la decouverte, et elle est cuite dans l'image. Ce
## n'est pas cher — les **dalles** sont memoisees dans `CWWorldMap`, donc un
## rendu qui suit ne paie que la boucle de pixels, et la premiere ouverture est
## la seule a payer les vingt-cinq dalles.
func _request(w: Vector2i) -> void:
	if _task != -1:
		return
	@warning_ignore("integer_division")
	var half: int = _zones / 2
	_origin = Vector2i(
			CWWorldParams.zone_of(w.x) - half,
			CWWorldParams.zone_of(w.y) - half)
	_task = WorkerThreadPool.add_task(_run_build)


func _run_build() -> void:
	_image = world_map.render(_origin.x, _origin.y, _zones, _zones)
	_markers = world_map.render_markers(_origin.x, _origin.y, _zones, _zones)


## Depose la vue calculee et replace le curseur du joueur.
func _show(w: Vector2i) -> void:
	if _image == null or not _open:
		return
	var base: Vector2i = _origin * CWWorldMap.CHUNKS_PER_ZONE
	var player := Vector2(
			float(w.x) / float(CWWorldMap.CHUNK_SIZE) - float(base.x),
			float(w.y) / float(CWWorldMap.CHUNK_SIZE) - float(base.y))
	var zone := Vector2i(CWWorldParams.zone_of(w.x), CWWorldParams.zone_of(w.y))
	var head: String = world_map.names().at(w.x, w.y)
	var sub: String = ("%d x %d zones   zone %d,%d   %d case(s) decouverte(s)"
			+ "   M fermer, +/- agrandir") % [
			_zones, _zones, zone.x, zone.y, world_map.discovered_count]
	overlay.show_view(_image, _markers, player, head, sub)


## Attend la tache de rendu en cours. A la fermeture : un fil du pool qui ecrit
## dans `_image` pendant que la scene se demonte plante.
func wait() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


## Ecrit la decouverte sur le disque, une seule fois par session.
func flush() -> void:
	if _flushed or _save_path == "" or world_map.discovered_count == 0:
		return
	_flushed = true
	world_map.save_discovery(_save_path)
	print("[demo] carte : %d case(s) decouverte(s) sauvegardees"
			% world_map.discovered_count)
