extends SceneTree

## Apercu de la carte du monde (jalon 1.10), hors du jeu.
##
##   godot --headless --path . -s tools/preview_map.gd
##   godot --headless --path . -s tools/preview_map.gd -- 512 512 5 2024
##
## Arguments optionnels : zone x, zone z, nombre de zones (impair de preference),
## graine. Sans argument : les cinq zones autour du point de depart.
##
## Sortie : user://worldgen_preview/map.png (une case de 256 unites par pixel,
## agrandi x4 pour etre lisible) et map_decouverte.png, la meme vue apres avoir
## parcouru une diagonale — c'est le seul moyen de voir les trois clartes
## 200 / 220 / 255 sans jouer.
##
## Raison d'etre : la geometrie du puzzle (une piece = la cellule de Voronoi
## d'un site dans le domaine deforme) ne se verifie pas en lisant des nombres.
## Un test dit que chaque case cite le bon site ; seule une image dit si les
## pieces ressemblent a des regions.

const DIR: String = "user://worldgen_preview"
const ZOOM: int = 4


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var p := CWWorldParams.new()
	if args.size() > 3:
		p.world_seed = int(args[3])
	var zx: int = int(args[0]) if args.size() > 0 else CWWorldParams.zone_of(p.start_point.x)
	var zz: int = int(args[1]) if args.size() > 1 else CWWorldParams.zone_of(p.start_point.y)
	var zones: int = int(args[2]) if args.size() > 2 else 5
	@warning_ignore("integer_division")
	var half: int = zones / 2

	var field := CWTerrainField.new(p)
	var map := CWWorldMap.new(field)
	DirAccess.make_dir_recursive_absolute(DIR)

	var x0: int = zx - half
	var z0: int = zz - half
	print("graine %d, %d x %d zones a partir de (%d, %d)" % [
			p.world_seed, zones, zones, x0, z0])

	var t0: int = Time.get_ticks_usec()
	var img: Image = map.render(x0, z0, zones, zones)
	print("vierge : %d x %d cases en %.2f s" % [
			img.get_width(), img.get_height(),
			float(Time.get_ticks_usec() - t0) / 1e6])
	_save(img, "map.png")

	# Une diagonale parcourue : la case du joueur passe a 255, ce qu'il voit a
	# 220, le reste reste a 200.
	var steps: int = zones * CWWorldMap.CHUNKS_PER_ZONE
	for i in steps:
		var x: int = (x0 * CWWorldMap.CHUNKS_PER_ZONE + i) << CWWorldMap.CHUNK_SHIFT
		var z: int = (z0 * CWWorldMap.CHUNKS_PER_ZONE + i) << CWWorldMap.CHUNK_SHIFT
		map.visit(x, z, 768)
	_save(map.render(x0, z0, zones, zones), "map_decouverte.png")
	print("apres une diagonale : %d case(s) decouverte(s)" % map.discovered_count)

	# L'inventaire de la vue : une region par ligne, son nom, son icone et ses
	# marqueurs. C'est ce qui permet de rapprocher l'image d'un endroit du jeu.
	var icons: Dictionary = {}
	for m: Dictionary in map.render_markers(x0, z0, zones, zones):
		icons[m["icon"]] = int(icons.get(m["icon"], 0)) + 1
		if m.has("name"):
			var zone: Vector2i = m["zone"]
			print("  zone %4d,%4d  %-14s icone %d" % [
					zone.x, zone.y, m["name"], m["icon"]])
	print("marqueurs par icone : ", icons)
	print("ecrit dans ", ProjectSettings.globalize_path(DIR))
	quit(0)


func _save(img: Image, name: String) -> void:
	# Agrandissement au plus proche voisin : une case doit rester un carre net,
	# sinon les frontieres du puzzle se lissent et l'apercu ment.
	img.resize(img.get_width() * ZOOM, img.get_height() * ZOOM,
			Image.INTERPOLATE_NEAREST)
	img.save_png("%s/%s" % [DIR, name])
