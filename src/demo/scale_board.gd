@tool
class_name CWScaleBoard
extends Node3D

## Gabarit d'echelle : les modeles charges, poses a cote de mires de hauteur
## connue et d'une silhouette de reference.
##
## Raison d'etre. L'echelle d'un modele voxel n'est deductible d'aucune
## decompilation : le binaire ne dit nulle part combien de blocs de terrain fait
## un personnage. Le seul moyen de trancher est de regarder, et pour regarder il
## faut une regle. Ce noeud est cette regle — a poser sur le terrain genere, a
## cote de la plante, et a photographier.
##
## Ce n'est pas du contenu de jeu : rien ici n'est ecrit dans le terrain, c'est
## un maillage isole qu'on ajoute et qu'on retire sans rien changer au monde.

## Hauteurs des mires, en blocs.
const TICKS: Array[int] = [1, 2, 3, 4, 6, 8, 12, 16, 24, 32]
## Espacement entre deux objets du gabarit, en blocs.
const SPACING: int = 6
## Marge d'air autour du contenu : le mailleur en cubes a besoin de voir du vide
## sur le pourtour, sinon il ferme les faces de bord.
const PAD: int = 2

## Silhouette de reference, en blocs, vue de face. Volontairement grossiere :
## elle ne sert qu'a donner une taille humaine a l'oeil, ce n'est pas un modele.
const FIGURE_HEIGHT: int = 8

## Decalage en X, depuis le centre du gabarit, du milieu de la zone des modeles,
## et largeur de cette zone. Sert a cadrer un gros plan sur les modeles seuls :
## de loin, un modele de trois blocs ne se lit plus.
var models_center: float = 0.0
var models_span: float = 0.0


## Largeur du gabarit, en blocs, pour la liste de modeles donnee.
static func width_of(models: Array) -> int:
	return (TICKS.size() + 1 + models.size()) * SPACING + PAD * 2


static func build(models: Array) -> CWScaleBoard:
	var board := CWScaleBoard.new()
	board.name = "ScaleBoard"

	# Largeur : les mires, la silhouette, puis un modele par emplacement.
	var slots: int = TICKS.size() + 1 + models.size()
	var depth: int = 1
	var height: int = 1
	for m in models:
		depth = maxi(depth, m.extent.z)
		height = maxi(height, m.height)
	height = maxi(height, TICKS[TICKS.size() - 1])
	height = maxi(height, FIGURE_HEIGHT)

	var size := Vector3i(slots * SPACING + PAD * 2, height + PAD * 2, depth + 4 + PAD * 2)
	var buf := VoxelBuffer.new()
	buf.create(size.x, size.y, size.z)
	buf.fill(CWPalette.AIR, VoxelBuffer.CHANNEL_COLOR)

	var cz: int = size.z / 2
	var slot: int = 0
	# Mires : une colonne de pierre par hauteur de reference, avec un bloc de
	# repere criard tous les quatre blocs pour pouvoir compter sur la photo.
	for t in TICKS:
		var cx: int = PAD + slot * SPACING + SPACING / 2
		for y in t:
			var value: int = CWPalette.STONE if (y % 4) != 0 else 250
			buf.set_voxel(value, cx, PAD + y, cz, VoxelBuffer.CHANNEL_COLOR)
		slot += 1

	_draw_figure(buf, PAD + slot * SPACING + SPACING / 2, PAD, cz)
	slot += 1

	var first_model_slot: int = slot
	for m in models:
		_draw_model(buf, m, PAD + slot * SPACING + SPACING / 2, PAD, cz)
		slot += 1
	# La silhouette reste dans le cadre du gros plan : c'est elle qui donne son
	# sens a la taille des modeles.
	board.models_span = float((models.size() + 1) * SPACING)
	board.models_center = float(PAD + (first_model_slot - 1) * SPACING) \
			+ board.models_span * 0.5 - float(size.x) * 0.5

	var mesher := VoxelMesherCubes.new()
	mesher.color_mode = VoxelMesherCubes.COLOR_MESHER_PALETTE
	mesher.palette = CWPalette.build_voxel_palette()
	mesher.greedy_meshing_enabled = true
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mesher.opaque_material = mat

	var mesh: Mesh = mesher.build_mesh(buf, [mat, mat], {})
	var mi := MeshInstance3D.new()
	mi.name = "Board"
	mi.mesh = mesh
	# Le maillage sort en coordonnees locales du tampon : on recentre sur la
	# base du gabarit pour pouvoir poser le noeud a meme le sol.
	mi.position = Vector3(-float(size.x) * 0.5, -float(PAD), -float(cz))
	board.add_child(mi)
	return board


## Silhouette humanoide de FIGURE_HEIGHT blocs : tete, tronc, deux jambes.
static func _draw_figure(buf: VoxelBuffer, cx: int, base: int, cz: int) -> void:
	var ch: int = VoxelBuffer.CHANNEL_COLOR
	var skin: int = 32
	var cloth: int = 220
	for y in 3:
		buf.set_voxel(cloth, cx - 1, base + y, cz, ch)
		buf.set_voxel(cloth, cx + 1, base + y, cz, ch)
	for y in range(3, 6):
		for dx in range(-1, 2):
			buf.set_voxel(cloth, cx + dx, base + y, cz, ch)
	for y in range(6, FIGURE_HEIGHT):
		for dx in range(-1, 2):
			buf.set_voxel(skin, cx + dx, base + y, cz, ch)


static func _draw_model(buf: VoxelBuffer, m: CWVoxelModel, cx: int, base: int,
		cz: int) -> void:
	var ch: int = VoxelBuffer.CHANNEL_COLOR
	var dx: PackedInt32Array = m.offsets_x(0)
	var dy: PackedInt32Array = m.offsets_y(0)
	var dz: PackedInt32Array = m.offsets_z(0)
	var values: PackedByteArray = m.values(0)
	var size: Vector3i = buf.get_size()
	for i in values.size():
		var x: int = cx + dx[i]
		var y: int = base + dy[i]
		var z: int = cz + dz[i]
		if x < 0 or y < 0 or z < 0 or x >= size.x or y >= size.y or z >= size.z:
			continue
		buf.set_voxel(values[i], x, y, z, ch)
