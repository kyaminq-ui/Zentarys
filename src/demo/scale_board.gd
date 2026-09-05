@tool
class_name CWScaleBoard
extends Node3D

## Gabarit d'echelle : des mires de hauteur connue en blocs, la silhouette du
## personnage de reference, et les modeles charges — tous a leur taille reelle,
## cote a cote.
##
## Raison d'etre. L'echelle d'un modele voxel n'est deductible d'aucune
## decompilation : le binaire ne dit nulle part combien de blocs de terrain fait
## un personnage. Le seul moyen de trancher est de regarder, et pour regarder il
## faut une regle. Ce noeud est cette regle — a poser sur le terrain genere, a
## cote de la plante, et a photographier.
##
## Il montre du meme coup les **deux grilles** : les mires sont a l'echelle du
## terrain (un cube = un bloc), la silhouette et les modeles a l'echelle fine
## (1 / CWVoxelModel.VOXELS_PER_BLOCK). C'est exactement ce rapport qu'on vient
## verifier.
##
## Ce n'est pas du contenu de jeu : rien ici n'est ecrit dans le terrain, ce sont
## des maillages isoles qu'on ajoute et qu'on retire sans rien changer au monde.

## Hauteurs des mires, en blocs. Le personnage en fait 2 : au-dela de 16, une
## mire ne sert plus qu'a situer le relief.
const TICKS: Array[int] = [1, 2, 3, 4, 6, 8, 12, 16]
## Espacement entre deux objets du gabarit, en blocs.
const SPACING: int = 3
## Marge d'air autour du contenu : le mailleur en cubes a besoin de voir du vide
## sur le pourtour, sinon il ferme les faces de bord.
const PAD: int = 2

## Silhouette de reference, en **voxels de modele**. 32 voxels = 2 blocs, le
## contrat de MODELS.md §1. Volontairement sommaire : elle ne sert qu'a donner
## une taille a l'oeil, ce n'est pas un modele de personnage.
const FIGURE_HEIGHT: int = 32

# Index de palette de la silhouette. Plages creatures et equipement : elle n'est
# pas de la vegetation, et une silhouette peinte en herbe se lit mal.
const FIGURE_SKIN: int = 32
const FIGURE_HAIR: int = 40
const FIGURE_EYE: int = 64
const FIGURE_CLOTH: int = 100

## Nombre de modeles par rangee. Au-dela, le gabarit continue en profondeur.
## Une rangee unique de trente-neuf modeles fait plus de cent blocs de large ; le
## gros plan qui rend lisible une plante d'un demi-bloc n'en cadre alors que
## trois, et la photo ne sert plus a rien.
const MODELS_PER_ROW: int = 10

## Cadre de la zone des modeles, en blocs, dans le repere local du gabarit :
## milieu et etendue sur X, milieu et etendue sur Z. Sert a poser la camera d'un
## gros plan sur les modeles seuls — de loin, une plante d'un demi-bloc ne se lit
## plus.
var models_center: float = 0.0
var models_span: float = 0.0
var models_z: float = 0.0
var models_depth: float = 0.0


## Largeur du gabarit, en blocs, pour la liste de modeles donnee.
static func width_of(models: Array) -> int:
	var slots: int = maxi(TICKS.size() + 1, mini(models.size(), MODELS_PER_ROW))
	return slots * SPACING + PAD * 2


static func build(models: Array) -> CWScaleBoard:
	var board := CWScaleBoard.new()
	board.name = "ScaleBoard"

	var per_row: int = mini(maxi(models.size(), 1), MODELS_PER_ROW)
	var width: int = width_of(models)
	@warning_ignore("integer_division")
	var slot_mid: int = SPACING / 2
	# Abscisse locale du milieu d'un emplacement, gabarit centre sur l'origine.
	var slot_x := func(slot: int) -> float:
		return float(PAD + slot * SPACING + slot_mid) - float(width) * 0.5

	board.add_child(_build_ticks(width))
	board.add_child(_build_figure(Vector3(slot_x.call(TICKS.size()), 0.0, 0.0)))

	# Les modeles occupent leurs propres rangees, **devant** les mires : rien ne
	# les masque, et les mires continuent de donner l'echelle au-dessus d'eux.
	var rows: int = 0
	for i in models.size():
		@warning_ignore("integer_division")
		var row: int = i / per_row
		rows = maxi(rows, row + 1)
		var mi: MeshInstance3D = _build_model(models[i], Vector3(
				slot_x.call(i % per_row), 0.0, float((row + 1) * SPACING)))
		if mi != null:
			board.add_child(mi)

	if models.is_empty():
		return board
	board.models_span = float(per_row * SPACING)
	board.models_center = (slot_x.call(0) + slot_x.call(per_row - 1)) * 0.5
	board.models_depth = float(rows * SPACING)
	board.models_z = float(SPACING) + board.models_depth * 0.5
	return board


## Les mires, a l'echelle du terrain : une colonne d'un bloc de section par
## hauteur de reference, dont les blocs alternent pour pouvoir les compter.
static func _build_ticks(width: int) -> MeshInstance3D:
	var height: int = TICKS[TICKS.size() - 1]
	var depth: int = 1
	var buf: VoxelBuffer = _new_buffer(
			width, height + PAD * 2, depth + PAD * 2)

	@warning_ignore("integer_division")
	var cz: int = (depth + PAD * 2) / 2
	@warning_ignore("integer_division")
	var slot_mid: int = SPACING / 2
	for slot in TICKS.size():
		var t: int = TICKS[slot]
		var cx: int = PAD + slot * SPACING + slot_mid
		for y in t:
			var value: int = CWPalette.STONE if (y % 2) == 0 else 250
			buf.set_voxel(CWPalette.raw_of(value), cx, PAD + y, cz,
					CWPalette.CHANNEL_COLOR)

	var mi := MeshInstance3D.new()
	mi.name = "Mires"
	mi.mesh = _mesh_of(buf)
	# Le mailleur consomme sa marge : l'origine du maillage tombe sur le premier
	# voxel utile, pas sur le coin du tampon. On recentre sur la base du gabarit
	# pour pouvoir poser le noeud a meme le sol.
	var pad: float = float(CWVoxelModel.mesher_padding())
	mi.position = Vector3(
			pad - float(width) * 0.5, pad - float(PAD), pad - float(cz))
	return mi


## Silhouette humanoide de FIGURE_HEIGHT voxels, a la grille fine.
##
## Elle a des yeux d'un voxel : c'est tout l'interet de la demonstration. A
## 1 voxel = 1 bloc, un personnage de 2 blocs serait deux cubes.
static func _build_figure(at: Vector3) -> MeshInstance3D:
	var ch: int = CWPalette.CHANNEL_COLOR
	var w: int = 14
	var d: int = 10
	var buf: VoxelBuffer = _new_buffer(
			w + PAD * 2, FIGURE_HEIGHT + PAD * 2, d + PAD * 2)

	@warning_ignore("integer_division")
	var cx: int = PAD + w / 2
	@warning_ignore("integer_division")
	var cz: int = PAD + d / 2
	var base: int = PAD

	var box := func(x0: int, x1: int, y0: int, y1: int, z0: int, z1: int,
			value: int) -> void:
		for y in range(y0, y1 + 1):
			for z in range(z0, z1 + 1):
				for x in range(x0, x1 + 1):
					buf.set_voxel(CWPalette.raw_of(value), cx + x, base + y,
							cz + z, ch)

	# Jambes, tronc, bras, tete : les proportions d'un personnage de jeu, tete
	# large et corps court.
	box.call(-4, -2, 0, 11, -2, 1, FIGURE_CLOTH)
	box.call(2, 4, 0, 11, -2, 1, FIGURE_CLOTH)
	box.call(-4, 4, 12, 21, -2, 2, FIGURE_CLOTH)
	box.call(-6, -5, 12, 20, -1, 1, FIGURE_SKIN)
	box.call(5, 6, 12, 20, -1, 1, FIGURE_SKIN)
	box.call(-5, 4, 22, 31, -4, 4, FIGURE_SKIN)
	box.call(-5, 4, 30, 31, -4, 4, FIGURE_HAIR)
	# Les yeux, dans la face de la tete tournee vers l'observateur du gabarit
	# (+Z). Un voxel de pupille : c'est la demonstration que 32 voxels suffisent
	# a un visage, la ou 2 blocs ne feraient que deux cubes.
	box.call(-3, -3, 26, 27, 4, 4, FIGURE_EYE)
	box.call(2, 2, 26, 27, 4, 4, FIGURE_EYE)

	var mi := MeshInstance3D.new()
	mi.name = "Silhouette"
	mi.mesh = _mesh_of(buf)
	var scale: float = 1.0 / CWVoxelModel.VOXELS_PER_BLOCK
	var pad: float = float(CWVoxelModel.mesher_padding())
	mi.scale = Vector3(scale, scale, scale)
	# Meme correction de marge que pour les mires, puis le milieu de la
	# silhouette et sa base sur le point demande.
	mi.position = at + Vector3(
			(pad - float(cx)) * scale,
			(pad - float(base)) * scale,
			(pad - float(cz)) * scale)
	return mi


## Un modele charge, a sa taille reelle : maille par le modele lui-meme, pose
## par son ancre.
static func _build_model(m: CWVoxelModel, at: Vector3) -> MeshInstance3D:
	var mesh: ArrayMesh = m.mesh()
	if mesh == null:
		return null
	var scale: float = 1.0 / CWVoxelModel.VOXELS_PER_BLOCK
	var mi := MeshInstance3D.new()
	mi.name = m.name
	mi.mesh = mesh
	mi.scale = Vector3(scale, scale, scale)
	# L'ancre du modele doit tomber sur `at` : le maillage porte le decalage de
	# son tampon, on le compense a l'echelle.
	mi.position = at + m.mesh_offset() * scale
	return mi


## Tampon de gabarit, prêt à recevoir des couleurs.
##
## Le gabarit dessine en **index de palette** — c'est plus lisible que des
## couleurs, et c'est la meme unite que le reste du projet — mais le canal de
## rendu est en `COLOR_RAW` depuis le 2026-09-05 : la conversion se fait a
## l'ecriture, par `CWPalette.raw_of`.
static func _new_buffer(w: int, h: int, d: int) -> VoxelBuffer:
	var buf := VoxelBuffer.new()
	buf.set_channel_depth(CWPalette.CHANNEL_COLOR, CWPalette.COLOR_DEPTH)
	buf.create(w, h, d)
	buf.fill(CWPalette.raw_of(CWPalette.AIR), CWPalette.CHANNEL_COLOR)
	return buf


static func _mesh_of(buf: VoxelBuffer) -> ArrayMesh:
	var mesher: VoxelMesherCubes = CWPalette.build_cubes_mesher()
	var mat: Material = CWPalette.build_opaque_material()
	return mesher.build_mesh(buf, [mat, mat], {}) as ArrayMesh
