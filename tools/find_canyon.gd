extends SceneTree

## Cherche un **pays de canyons** : le point ou la densite regionale de
## surplombs est la plus forte a portee du depart. Rend un point de vue pret a
## passer a `--ici` / `--vers`.
##
## Usage : -s tools/find_canyon.gd -- [graine]

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var seed_v: int = int(args[0]) if args.size() > 0 else 2024
	var p := CWWorldParams.new()
	p.world_seed = seed_v
	var f := CWTerrainField.new(p)
	var o: Vector2i = p.world_origin

	var best: float = -1.0
	var bx: int = o.x
	var bz: int = o.y
	for iz in range(-40, 41):
		for ix in range(-40, 41):
			var x: int = o.x + ix * 400
			var z: int = o.y + iz * 400
			var c: float = CWMesaGrid.chance_at(x, z)
			if c > best and f.sample_column(x, z).x > float(p.sea_level) + 20.0:
				best = c
				bx = x
				bz = z
	print("centre du pays : %d %d  (chance %.2f par cellule)" % [bx, bz, best])
	# Un point de vue en retrait, et de la hauteur.
	print("--ici %d %d --vers %d %d --altitude 90" % [bx - 420, bz - 420, bx, bz])
	quit()
