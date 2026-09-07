class_name CWBiomeSearch
extends RefCounted

## La recherche du biome le plus proche, derriere les touches 1 a 6 et
## l'argument `--biome`.
##
## -- Pourquoi une classe a elle ------------------------------------------------
##
## Quatre fonctions, sept variables d'etat et une tache de fond vivaient dans
## `terrain_demo.gd`. C'est exactement la forme de `CWDemoMap`, sortie le meme
## jour, et pour la meme raison : *un fichier, une decision*. Celle-ci est « ou
## est le biome demande, et la recherche est-elle finie ».
##
## -- Pourquoi un fil du pool ---------------------------------------------------
##
## Le balayage coute ~76 us la colonne et sonde jusqu'a 64 points par zone sur
## onze anneaux : une recherche large depasse la seconde et figerait l'affichage.
## Le champ de terrain est purement fonctionnel, donc l'appeler depuis un autre
## fil est sur — c'est la propriete sur laquelle repose toute la generation.
##
## > ⚠️ **Le point de depart se releve sur le fil principal, jamais dans la
## > tache.** `Node3D.get_position()` n'est pas lisible depuis un fil du pool :
## > Godot le refuse et rend `Vector3.ZERO`, ce qui faisait partir toutes les
## > recherches de l'origine du monde au lieu de la camera. C'est pour cela que
## > `start` prend la position en argument.

## Rayon de la recherche, en zones de 16 384 blocs.
const ZONE_RINGS: int = 10

var _field: CWTerrainField
var _sea: int

var _task: int = -1
var _target: int = -1
var _found: bool = false
var _result: Vector2i = Vector2i.ZERO
var _abort: bool = false
var _status: String = ""
## Point de depart, releve sur le fil principal. Voir l'en-tete.
var _from: Vector2i = Vector2i.ZERO


func _init(field: CWTerrainField, sea_level: int) -> void:
	_field = field
	_sea = sea_level


## Ce que l'ATH affiche pendant et apres la recherche. Chaine vide = rien a dire.
func status() -> String:
	return _status


func running() -> bool:
	return _task != -1


## Lance la recherche du biome `target` autour de `from`, en coordonnees monde.
func start(target: int, from: Vector2i) -> void:
	if _task != -1:
		return
	_target = target
	_found = false
	_abort = false
	_status = "recherche %s..." % CWBiome.name_of(target)
	_from = from
	_task = WorkerThreadPool.add_task(_run)


## Appele une fois par image. Rend le point trouve quand la recherche vient de
## s'achever, et `null` sinon — c'est a l'appelant d'y poser la camera, parce
## que c'est lui qui la possede.
func poll() -> Variant:
	if _task == -1 or not WorkerThreadPool.is_task_completed(_task):
		return null
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	if _abort:
		_status = ""
		return null
	if not _found:
		_status = "%s introuvable a moins de %d zones" % [
			CWBiome.name_of(_target), ZONE_RINGS]
		return null
	_status = ""
	return _result


## Rejoint la tache en cours. A la fermeture : sans cela le pool attend sa fin.
func stop() -> void:
	_abort = true
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func _run() -> void:
	var cx: int = CWWorldParams.zone_of(_from.x)
	var cz: int = CWWorldParams.zone_of(_from.y)
	# Anneaux de zones concentriques : on rend le resultat le plus proche.
	for ring in ZONE_RINGS + 1:
		for dz in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				if _abort:
					return
				if _probe_zone(cx + dx, cz + dz):
					return


## Sonde une zone : un point au centre de chacune de ses 64 tuiles.
func _probe_zone(zx: int, zz: int) -> bool:
	if zx < 0 or zz < 0 \
			or zx >= CWWorldParams.ZONE_GRID or zz >= CWWorldParams.ZONE_GRID:
		return false
	@warning_ignore("integer_division")
	var half: int = CWWorldParams.TILE_SIZE / 2
	for tz in 8:
		for tx in 8:
			var x: int = zx * CWWorldParams.ZONE_SIZE \
					+ tx * CWWorldParams.TILE_SIZE + half
			var z: int = zz * CWWorldParams.ZONE_SIZE \
					+ tz * CWWorldParams.TILE_SIZE + half
			var c: Vector3 = _field.sample_column(x, z)
			if CWBiome.at(c.x, c.y, c.z, _sea) == _target:
				_result = Vector2i(x, z)
				_found = true
				return true
	return false
