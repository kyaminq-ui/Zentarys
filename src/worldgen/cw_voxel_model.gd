class_name CWVoxelModel
extends RefCounted

## Un modele .vox prepare pour etre estampe dans un VoxelBuffer.
##
## Le chargeur rend un VoxelBuffer dense ; un modele de flore n'en remplit que
## quelques pour cent (80 voxels pleins sur 1960 pour `herbe_01`). On le
## convertit donc en liste creuse, et on precalcule les quatre quarts de tour
## autour de Y : le chemin d'estampage est appele une fois par plante et par
## bloc traverse, il ne doit contenir qu'une boucle et des additions.
##
## Repere. Les offsets sont relatifs a l'**ancre** : centre du gabarit au sol
## sur X et Z, base de la matiere sur Y. Poser une plante revient donc a donner
## la colonne (x, z) et l'altitude du premier bloc d'air au-dessus du sol.
##
## Permutation d'axes : `VoxelVoxLoader` rend deja un tampon oriente Godot
## (vox(x, y, z) -> godot(y, z, x), cf. assets/palette/PALETTE.md). Rien a
## compenser ici ; c'est dans MagicaVoxel que le modele doit etre debout.

const ROTATIONS: int = 4

var name: String = ""
var path: String = ""
## Gabarit de la matiere, en blocs.
var extent: Vector3i = Vector3i.ZERO
## Rayon horizontal, en blocs : de combien la plante deborde de sa colonne.
var radius: int = 0
var height: int = 0
var voxel_count: int = 0

# Offsets par rotation, en tableaux paralleles. Indexes par le quart de tour.
var _dx: Array[PackedInt32Array] = []
var _dy: Array[PackedInt32Array] = []
var _dz: Array[PackedInt32Array] = []
var _v: Array[PackedByteArray] = []


## Charge un `.vox` et le prepare. Rend `null` si le fichier manque ou est vide.
static func load_from(model_path: String, palette: Resource) -> CWVoxelModel:
	if not ResourceLoader.exists(model_path) and not FileAccess.file_exists(model_path):
		return null
	var buffer := VoxelBuffer.new()
	var loader := VoxelVoxLoader.new()
	if loader.load_from_file(model_path, buffer, palette, VoxelBuffer.CHANNEL_COLOR) != OK:
		return null

	var m := CWVoxelModel.new()
	m.path = model_path
	m.name = model_path.get_file().get_basename()

	var size: Vector3i = buffer.get_size()
	var lo := Vector3i(size)
	var hi := Vector3i(-1, -1, -1)
	for y in size.y:
		for z in size.z:
			for x in size.x:
				if buffer.get_voxel(x, y, z, VoxelBuffer.CHANNEL_COLOR) == CWPalette.AIR:
					continue
				lo = lo.min(Vector3i(x, y, z))
				hi = hi.max(Vector3i(x, y, z))
	if hi.x < lo.x:
		return null

	m.extent = hi - lo + Vector3i.ONE
	m.height = m.extent.y
	# Ancre au centre du gabarit : une plante posee en (x, z) doit deborder
	# autant d'un cote que de l'autre, sinon la dispersion est biaisee.
	@warning_ignore("integer_division")
	var anchor := Vector3i(lo.x + m.extent.x / 2, lo.y, lo.z + m.extent.z / 2)

	var bx := PackedInt32Array()
	var by := PackedInt32Array()
	var bz := PackedInt32Array()
	var bv := PackedByteArray()
	for y in range(lo.y, hi.y + 1):
		for z in range(lo.z, hi.z + 1):
			for x in range(lo.x, hi.x + 1):
				var value: int = buffer.get_voxel(x, y, z, VoxelBuffer.CHANNEL_COLOR)
				if value == CWPalette.AIR:
					continue
				bx.append(x - anchor.x)
				by.append(y - anchor.y)
				bz.append(z - anchor.z)
				bv.append(value)
	m.voxel_count = bv.size()

	m._dx.resize(ROTATIONS)
	m._dy.resize(ROTATIONS)
	m._dz.resize(ROTATIONS)
	m._v.resize(ROTATIONS)
	for r in ROTATIONS:
		var rx := PackedInt32Array()
		var rz := PackedInt32Array()
		rx.resize(m.voxel_count)
		rz.resize(m.voxel_count)
		for i in m.voxel_count:
			var p: Vector2i = _turn(bx[i], bz[i], r)
			rx[i] = p.x
			rz[i] = p.y
			m.radius = maxi(m.radius, maxi(absi(p.x), absi(p.y)))
		m._dx[r] = rx
		m._dy[r] = by
		m._dz[r] = rz
		m._v[r] = bv
	return m


## Copie reduite d'un facteur entier, par union : un voxel de sortie est plein
## des qu'un voxel de la cellule source l'est.
##
## Une reduction par moyenne effacerait le modele — la flore est faite de lames
## d'un seul voxel d'epaisseur, qui sont minoritaires dans n'importe quelle
## cellule. L'union garde la silhouette, ce qui est tout ce qu'on lui demande :
## montrer a quoi ressemblerait le meme modele a une autre echelle.
func reduced(factor: int) -> CWVoxelModel:
	if factor <= 1:
		return self
	var out := CWVoxelModel.new()
	out.path = path
	out.name = "%s/%d" % [name, factor]

	# On repasse par une grille dense : c'est le seul moyen de dedupliquer les
	# voxels qui tombent dans la meme cellule, et le modele est petit.
	var cells: Dictionary = {}
	var src_x: PackedInt32Array = _dx[0]
	var src_y: PackedInt32Array = _dy[0]
	var src_z: PackedInt32Array = _dz[0]
	var src_v: PackedByteArray = _v[0]
	for i in src_v.size():
		var key := Vector3i(
				floori(float(src_x[i]) / float(factor)),
				floori(float(src_y[i]) / float(factor)),
				floori(float(src_z[i]) / float(factor)))
		if not cells.has(key):
			cells[key] = src_v[i]

	var lo := Vector3i(0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF)
	var hi := Vector3i(-0x7FFFFFFF, -0x7FFFFFFF, -0x7FFFFFFF)
	for key in cells:
		lo = lo.min(key)
		hi = hi.max(key)
	out.extent = hi - lo + Vector3i.ONE
	out.height = out.extent.y

	var bx := PackedInt32Array()
	var by := PackedInt32Array()
	var bz := PackedInt32Array()
	var bv := PackedByteArray()
	for key in cells:
		bx.append(key.x)
		# L'ancre reste au sol : la base du modele reduit doit poser au meme
		# endroit que celle de l'original, pas flotter d'un demi-facteur.
		by.append(key.y - lo.y)
		bz.append(key.z)
		bv.append(cells[key])
	out.voxel_count = bv.size()

	out._dx.resize(ROTATIONS)
	out._dy.resize(ROTATIONS)
	out._dz.resize(ROTATIONS)
	out._v.resize(ROTATIONS)
	for r in ROTATIONS:
		var rx := PackedInt32Array()
		var rz := PackedInt32Array()
		rx.resize(out.voxel_count)
		rz.resize(out.voxel_count)
		for i in out.voxel_count:
			var q: Vector2i = _turn(bx[i], bz[i], r)
			rx[i] = q.x
			rz[i] = q.y
			out.radius = maxi(out.radius, maxi(absi(q.x), absi(q.y)))
		out._dx[r] = rx
		out._dy[r] = by
		out._dz[r] = rz
		out._v[r] = bv
	return out


## Quart de tour autour de Y, sens direct.
static func _turn(dx: int, dz: int, quarter: int) -> Vector2i:
	match quarter & 3:
		1: return Vector2i(-dz, dx)
		2: return Vector2i(-dx, -dz)
		3: return Vector2i(dz, -dx)
		_: return Vector2i(dx, dz)


func offsets_x(rotation: int) -> PackedInt32Array:
	return _dx[rotation & 3]


func offsets_y(rotation: int) -> PackedInt32Array:
	return _dy[rotation & 3]


func offsets_z(rotation: int) -> PackedInt32Array:
	return _dz[rotation & 3]


func values(rotation: int) -> PackedByteArray:
	return _v[rotation & 3]


func _to_string() -> String:
	return "%s %dx%dx%d, %d voxels, rayon %d" % [
		name, extent.x, extent.y, extent.z, voxel_count, radius]
