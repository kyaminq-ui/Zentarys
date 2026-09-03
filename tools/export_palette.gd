extends SceneTree

## Exporte la palette de projet vers `assets/palette/`.
##
##   godot --headless --path . -s tools/export_palette.gd
##
## Deux fichiers :
##   zentarys_palette.png    256 x 1, a glisser sur la palette de MagicaVoxel
##   zentarys_palette_ref.png  planche 16 x 16 agrandie, pour l'oeil humain
##
## `CWPalette` est la source unique : ne jamais editer les PNG a la main, les
## regenerer. Un modele peint dans une palette qui a divergé du code se
## retrouve avec des couleurs fausses sans le moindre message d'erreur.

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
