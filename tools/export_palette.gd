extends SceneTree

## Exporte la palette de projet vers `assets/palette/`.
##
##   godot --headless --path . -s tools/export_palette.gd
##
## Trois fichiers :
##   zentarys_palette.vox    planche 16 x 16 a OUVRIR dans MagicaVoxel
##   zentarys_palette.png    256 x 1, forme lineaire
##   zentarys_palette_ref.png  planche 16 x 16 agrandie, pour l'oeil humain
##
## `CWPalette` est la source unique : ne jamais editer les fichiers a la main,
## les regenerer. Un modele peint dans une palette qui a divergé du code se
## retrouve avec des couleurs fausses sans le moindre message d'erreur.
##
## POURQUOI UN .vox. Le rendu lit un *index*, pas une couleur : il ne suffit pas
## que la teinte soit ressemblante, il faut que l'emplacement soit le bon.
## Ouvrir `zentarys_palette.vox` dans MagicaVoxel est le seul geste qui le
## garantit — le fichier porte la palette dans son bloc RGBA, emplacement par
## emplacement. Glisser une image sur le nuancier ne le garantit pas : le
## premier lot d'assets a été peint sur la planche de référence rééchantillonnée
## par MagicaVoxel, ce qui a décalé chaque couleur d'un emplacement sur deux et
## intercalé sa version assombrie par le liseré. Voir `assets/palette/PALETTE.md`.

const OUT_DIR: String = "res://assets/palette"
const CELL: int = 32  # taille d'une case sur la planche de reference


func _initialize() -> void:
	var colors: PackedColorArray = CWPalette.colors()
	if colors.size() != 256:
		printerr("La palette doit compter 256 entrees, pas ", colors.size())
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	# --- Palette lineaire pour MagicaVoxel -----------------------------------
	var strip := Image.create(256, 1, false, Image.FORMAT_RGBA8)
	for i in 256:
		strip.set_pixel(i, 0, colors[i])
	var strip_path: String = OUT_DIR + "/zentarys_palette.png"
	if strip.save_png(strip_path) != OK:
		printerr("Echec d'ecriture de ", strip_path)
		quit(1)
		return

	# --- Planche de reference ------------------------------------------------
	# Damier sous les entrees translucides, sinon l'eau et le verre sont
	# indiscernables du vide.
	var ref := Image.create(16 * CELL, 16 * CELL, false, Image.FORMAT_RGBA8)
	for i in 256:
		var cx: int = (i % 16) * CELL
		var cy: int = (i / 16) * CELL
		for y in CELL:
			for x in CELL:
				var check: bool = ((x / 8) + (y / 8)) % 2 == 0
				var bg := Color(0.85, 0.85, 0.85) if check else Color(0.65, 0.65, 0.65)
				var c: Color = colors[i]
				var px: Color = bg.lerp(Color(c.r, c.g, c.b), c.a)
				# Liseré sombre : sans lui les plages voisines se confondent.
				if x == 0 or y == 0:
					px = px.darkened(0.45)
				ref.set_pixel(cx + x, cy + y, px)
	ref.save_png(OUT_DIR + "/zentarys_palette_ref.png")

	# --- Planche MagicaVoxel ---------------------------------------------------
	_write_vox(OUT_DIR + "/zentarys_palette.vox", colors)

	print("Palette exportee dans ", ProjectSettings.globalize_path(OUT_DIR))
	_report(colors)
	quit()


func _report(colors: PackedColorArray) -> void:
	var ranges: Array = [
		["terrain", CWPalette.RANGE_TERRAIN_BEGIN, CWPalette.RANGE_TERRAIN_END],
		["creatures", CWPalette.RANGE_CREATURES_BEGIN, CWPalette.RANGE_CREATURES_END],
		["armes", CWPalette.RANGE_GEAR_BEGIN, CWPalette.RANGE_GEAR_END],
		["vegetation", CWPalette.RANGE_FLORA_BEGIN, CWPalette.RANGE_FLORA_END],
		["structures", CWPalette.RANGE_BUILD_BEGIN, CWPalette.RANGE_BUILD_END],
		["effets", CWPalette.RANGE_FX_BEGIN, CWPalette.RANGE_FX_END],
	]
	for r in ranges:
		var defined: int = 0
		for i in range(r[1], r[2] + 1):
			if colors[i].a > 0.0:
				defined += 1
		print("  %-11s %3d-%3d  %2d entrees, %d definies"
				% [r[0], r[1], r[2], r[2] - r[1] + 1, defined])


## Ecrit la palette sous forme de fichier MagicaVoxel : une planche de 16 x 16
## voxels, un par emplacement, avec le bloc RGBA renseigne.
##
## Le format `.vox` decale la palette d'un cran — la couleur de l'emplacement
## `i` est stockee en position `i - 1` — et n'a pas d'emplacement pour l'index 0,
## qui vaut toujours « vide ». C'est exactement la convention que le chargeur de
## Voxel Tools absorbe, donc les index se conservent d'un bout a l'autre.
func _write_vox(path: String, colors: PackedColorArray) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		printerr("Echec d'ecriture de ", path)
		return

	# Planche debout : 16 de large, 1 d'epaisseur, 16 de haut. MagicaVoxel est
	# Z-up, et l'index 0 se lit en haut a gauche comme sur la planche PNG.
	var xyzi := PackedByteArray()
	xyzi.append_array(_i32(255))
	for i in range(1, 256):
		@warning_ignore("integer_division")
		var row: int = i / 16
		xyzi.append(i % 16)
		xyzi.append(0)
		xyzi.append(15 - row)
		xyzi.append(i)

	# Troncature, pas arrondi : c'est ce que fait `Image` en FORMAT_RGBA8, et les
	# trois exports doivent donner exactement les memes octets.
	var rgba := PackedByteArray()
	rgba.resize(256 * 4)
	for i in range(1, 256):
		var c: Color = colors[i]
		rgba[(i - 1) * 4 + 0] = int(c.r * 255.0)
		rgba[(i - 1) * 4 + 1] = int(c.g * 255.0)
		rgba[(i - 1) * 4 + 2] = int(c.b * 255.0)
		rgba[(i - 1) * 4 + 3] = int(c.a * 255.0)

	var body := PackedByteArray()
	body.append_array(_chunk("SIZE", _i32(16) + _i32(1) + _i32(16)))
	body.append_array(_chunk("XYZI", xyzi))
	body.append_array(_chunk("RGBA", rgba))

	var out := PackedByteArray()
	out.append_array("VOX ".to_ascii_buffer())
	out.append_array(_i32(150))
	out.append_array("MAIN".to_ascii_buffer())
	out.append_array(_i32(0))
	out.append_array(_i32(body.size()))
	out.append_array(body)
	f.store_buffer(out)
	f.close()


static func _chunk(id: String, content: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(id.to_ascii_buffer())
	out.append_array(_i32(content.size()))
	out.append_array(_i32(0))
	out.append_array(content)
	return out


static func _i32(v: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(4)
	out.encode_s32(0, v)
	return out
