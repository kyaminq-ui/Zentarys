extends SceneTree

## Gros plan ombre sur la couche d'elements de tuile, avec et sans.
##
##   godot --headless --path . -s tools/preview_features.gd
##   godot --headless --path . -s tools/preview_features.gd -- 8397738 8401751 6
##
## Arguments optionnels : x, z (coordonnees monde ; defaut = world_origin) et le
## pas en unites par pixel (defaut 6, soit 3072 unites de cote).
##
## Raison d'etre : les apercus de la suite de tests balaient 65536 unites au pas
## de 256, ce qui ne peut pas montrer un element de 550 unites de rayon. Ici le
## pas est de l'ordre de l'element, et les deux rendus se comparent pixel a
## pixel puisque seule la bascule `tile_features` change.
##
## Sortie : user://worldgen_preview/features_avec.png et features_sans.png,
## plus l'inventaire des elements du cadre sur la sortie standard.

const RES: int = 512
const DIR: String = "user://worldgen_preview"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var p := CWWorldParams.new()
	var cx: int = int(args[0]) if args.size() > 0 else p.world_origin.x
	var cz: int = int(args[1]) if args.size() > 1 else p.world_origin.y
	var step: int = int(args[2]) if args.size() > 2 else 6
	@warning_ignore("integer_division")
	var half: int = RES * step / 2
	var x0: int = cx - half
	var z0: int = cz - half

	DirAccess.make_dir_recursive_absolute(DIR)
	print("cadre : (%d, %d) a (%d, %d), %d unites/pixel"
			% [x0, z0, x0 + RES * step, z0 + RES * step, step])

	var f := CWTerrainField.new(p)
	_render(f, x0, z0, step).save_png(DIR + "/features_avec.png")

	var pb := CWWorldParams.new()
	pb.world_seed = p.world_seed
	pb.tile_features = false
	_render(CWTerrainField.new(pb), x0, z0, step).save_png(DIR + "/features_sans.png")

	# Inventaire : sans lui on ne sait pas ce qu'on regarde.
	var seen: Dictionary = {}
	for tz in range(CWWorldParams.tile_of(z0), CWWorldParams.tile_of(z0 + RES * step) + 1):
		for tx in range(CWWorldParams.tile_of(x0), CWWorldParams.tile_of(x0 + RES * step) + 1):
			var feat: CWTileFeature = f.features().get_feature(tx, tz, f)
			if feat == null or feat.type == 0 or seen.has(feat):
				continue
			seen[feat] = true
			print("  %s%s -> pixel (%d, %d), rayon %d px"
					% [feat, "  [altitude]" if feat.affects_height() else "",
					int((feat.x - float(x0)) / float(step)),
					int((feat.z - float(z0)) / float(step)),
					int(feat.radius / float(step))])
	print("ecrit dans ", ProjectSettings.globalize_path(DIR))
	quit(0)


func _render(f: CWTerrainField, x0: int, z0: int, step: int) -> Image:
	var h := PackedFloat32Array()
	h.resize(RES * RES)
	var lo: float = INF
	var hi: float = -INF
	for py in RES:
		# Une ligne par appel : sample_patch sort la consultation des sites et
		# de la grille d'elements de la boucle de colonnes.
		var row: PackedFloat32Array = f.sample_patch(x0, z0 + py * step, RES, 1, step)
		for px in RES:
			var v: float = row[px * 3]
			h[py * RES + px] = v
			lo = minf(lo, v)
			hi = maxf(hi, v)

	var img := Image.create(RES, RES, false, Image.FORMAT_RGB8)
	for py in RES:
		for px in RES:
			var v: float = h[py * RES + px]
			var t: float = (v - lo) / maxf(1.0, hi - lo)
			# Ombrage par la pente vers le nord-ouest : sans lui, un cratere de
			# 50 blocs dans un relief de 150 est un aplat a peine plus sombre.
			var dx: float = (h[py * RES + mini(px + 1, RES - 1)]
					- h[py * RES + maxi(px - 1, 0)])
			var dz: float = (h[mini(py + 1, RES - 1) * RES + px]
					- h[maxi(py - 1, 0) * RES + px])
			var lit: float = clampf(0.62 - (dx + dz) * 0.1, 0.0, 1.0)
			var c := Color(t * 0.55 + 0.25, t * 0.75 + 0.18, t * 0.45 + 0.30)
			if v < 0.0:
				c = Color(0.10, 0.22, 0.45)
			img.set_pixel(px, py, c * lit * 1.7)
	print("  altitude [%.1f, %.1f]" % [lo, hi])
	return img
