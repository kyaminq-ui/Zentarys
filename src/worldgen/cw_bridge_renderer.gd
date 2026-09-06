class_name CWBridgeRenderer
extends Node3D

## Les **travees de pont**, instanciees a six voxels par bloc.
##
## -- Le partage, et pourquoi il est le meme que celui des arbres -------------
##
## Depuis le jalon 1.11, un arbre existe en deux moities : son tronc est de la
## **matiere** ecrite dans les donnees du monde — il se creuse, il portera la
## collision —, et son houppier est un **modele instancie**, treize fois plus
## fin que le bloc, qui ne porte ni l'un ni l'autre.
##
## Un pont suit exactement ce partage. Son tablier est de la matiere, pose par
## `CWVoxelGenerator.road_shape` : c'est le sol sur lequel on marchera. Ce noeud
## pose par-dessus l'**ouvrage** — platelage, longerons, garde-corps, poteaux —
## a la grille fine du projet, celle des petits props de la flore. Demande du
## 2026-09-08 : *redessine les ponts a six voxels par bloc pour plus de details*.
##
## -- Ce qui distingue ce rendu de celui de la flore --------------------------
##
## `CWFloraRenderer` disperse des dizaines de milliers d'objets sur une grille
## de cellules, et tout son appareil — file, cellules en cache, attente du sol,
## reprise apres edition — existe pour ca. Un monde contient quelques ponts par
## zone. Ici, tout tient en une passe : on demande a la zone ses
## franchissements, on pose une travee tous les `PAS` blocs le long de chacun,
## et on garde le tout en cache par zone.
##
## **Une difference porte tout le reste : le lacet est libre.** La flore et les
## arbres se posent au quart de tour, parce que leurs voxels doivent rester
## alignes sur la grille du monde. Un pont suit une courbe, et une travee
## alignee au quart de tour la plus proche serait de travers une fois sur deux.
## L'instance porte donc l'angle exact du trace — la grille du modele n'est plus
## alignee sur celle du monde, et c'est le seul endroit du projet ou on
## l'accepte : a six voxels par bloc, un platelage de biais se lit comme un
## platelage de biais, pas comme une erreur.

## Distance entre deux travees, en blocs. La travee fait deux blocs de long :
## elles se recouvrent donc d'un demi-bloc, ce qui les soude quel que soit
## l'angle et evite un trou dans les diagonales.
const PAS: float = 1.5

## Chemin du modele de travee.
const TRAVEE: String = "res://assets/models/structures/pont_travee.vox"

## Distance de vue, en blocs. Un pont est un objet rare et gros : on le garde
## plus loin que la flore.
@export var view_distance: float = 512.0

var _field: CWTerrainField
var _origin: Vector2i
var _camera: Node3D
var _model: CWVoxelModel
var _mesh: ArrayMesh
var _nodes: Dictionary = {}
var _enabled: bool = true


func setup(field: CWTerrainField, world_origin: Vector2i,
		camera: Node3D) -> void:
	_field = field
	_origin = world_origin
	_camera = camera


## Bascule d'isolation, comme `--sans-arbres` et `--sans-flore`.
func set_enabled(on: bool) -> void:
	_enabled = on
	if not on:
		clear()


func clear() -> void:
	for n in _nodes.values():
		n.queue_free()
	_nodes.clear()


## `(ponts poses, travees instanciees)`, pour l'ATH.
func stats() -> Vector2i:
	var travees: int = 0
	for n in _nodes.values():
		travees += n.multimesh.instance_count
	return Vector2i(_nodes.size(), travees)


func _process(_delta: float) -> void:
	if not _enabled or _field == null or _camera == null:
		return
	if _field.params().road_network == false:
		return
	if _model == null and not _charge():
		return

	var here := Vector2i(
			_origin.x + roundi(_camera.global_position.x),
			_origin.y + roundi(_camera.global_position.z))
	# Les ponts d'une zone ne sortent pas de leur zone (invariant n. 43), mais
	# la camera peut en voir dans la voisine : on regarde le voisinage 3 x 3 de
	# la zone courante. C'est neuf consultations de dictionnaire par image.
	var zx0: int = CWWorldParams.zone_of(here.x)
	var zz0: int = CWWorldParams.zone_of(here.y)
	for dz in 3:
		for dx in 3:
			_pose_zone(zx0 + dx - 1, zz0 + dz - 1, here)


func _charge() -> bool:
	var palette: Resource = CWPalette.build_voxel_palette()
	_model = CWVoxelModel.load_from(TRAVEE, palette, "pont_travee",
			CWVoxelModel.VOXELS_PER_BLOCK_FLORE_FINE)
	if _model == null:
		push_warning("[pont] modele introuvable : %s" % TRAVEE)
		return false
	_mesh = _model.mesh()
	return _mesh != null


func _pose_zone(zx: int, zz: int, here: Vector2i) -> void:
	# La zone n'est demandee que si son reseau est **deja construit** : ce noeud
	# ne doit pas declencher les 350 ms d'un trace sur le fil principal. Le
	# terrain s'en charge depuis son pool, et le pont apparait au tour suivant.
	var zone: CWPathNetwork.Zone = _field.paths().built_zone(zx, zz)
	if zone == null or zone.bridges.is_empty():
		return
	for i in zone.bridges.size():
		var key := Vector3i(zx, zz, i)
		if _nodes.has(key):
			continue
		var pont: PackedFloat32Array = zone.bridges[i]
		if Vector2(pont[0] - float(here.x), pont[1] - float(here.y)).length() \
				> view_distance:
			continue
		_nodes[key] = _bati(pont)


## Un noeud par franchissement : une seule instance multiple, une travee tous
## les `PAS` blocs, chacune tournee dans l'axe du trace.
func _bati(pont: PackedFloat32Array) -> MultiMeshInstance3D:
	var poses: Array[Transform3D] = []
	var n: int = pont.size() / 3 - 1
	var reste: float = 0.0
	var aabb := AABB()
	var premier: bool = true
	for i in n:
		var a := Vector3(pont[i * 3], pont[i * 3 + 2], pont[i * 3 + 1])
		var b := Vector3(pont[(i + 1) * 3], pont[(i + 1) * 3 + 2],
				pont[(i + 1) * 3 + 1])
		var d: float = Vector2(b.x - a.x, b.z - a.z).length()
		if d <= 0.001:
			continue
		# **La longueur de la travee est son axe X**, et c'est ce qui decide du
		# lacet : `Basis(UP, yaw)` envoie X local sur `(cos, 0, -sin)`, donc
		# l'angle qui l'aligne sur la direction du trace est `atan2(-dz, dx)` et
		# non `atan2(dx, dz)`. Une travee posee avec le second est en travers du
		# pont, ce qui se voit tout de suite et n'a rien d'un defaut subtil.
		var yaw: float = atan2(-(b.z - a.z), b.x - a.x)
		# Deux facteurs, comme pour la flore : le rapport des grilles — six
		# voxels par bloc — et rien d'autre, une travee n'ayant pas de gigue.
		# `mesh_offset` passe par la base, donc il subit la rotation et
		# l'echelle : sans cela la travee glisse d'un demi-gabarit des qu'elle
		# tourne.
		var e: float = 1.0 / _model.voxels_per_block
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3(e, e, e))
		var t: float = reste
		while t < d:
			var p: Vector3 = a.lerp(b, t / d)
			# Le modele est ancre au centre de son empreinte et a sa base ; sa
			# base se pose **sur** le tablier de matiere, donc un bloc plus haut
			# que l'altitude du tablier.
			var xf := Transform3D(basis,
					Vector3(p.x - float(_origin.x), p.y + 1.0,
							p.z - float(_origin.y)) + basis * _model.mesh_offset())
			poses.append(xf)
			if premier:
				aabb = AABB(xf.origin, Vector3.ONE)
				premier = false
			else:
				aabb = aabb.expand(xf.origin)
			t += PAS
		reste = t - d

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _mesh
	mm.instance_count = poses.size()
	for i in poses.size():
		mm.set_instance_transform(i, poses[i])

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	# Le materiau du terrain, comme pour la flore : sans lui, le maillage sort
	# avec le materiau par defaut de Godot — blanc, lisse, et sans rapport avec
	# le reste du monde. C'est ce qui rend les couleurs du modele visibles, car
	# elles vivent dans les sommets.
	mmi.material_override = CWPalette.build_opaque_material()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# Sans boite explicite, la visibilite d'un MultiMesh se calcule sur la seule
	# boite de son maillage : un pont entier disparaitrait des que son premier
	# bloc sort du champ. Meme piege qu'au jalon 1.7 pour la flore.
	mmi.custom_aabb = AABB(aabb.position - Vector3(8, 8, 8),
			aabb.size + Vector3(16, 16, 16))
	add_child(mmi)
	return mmi
