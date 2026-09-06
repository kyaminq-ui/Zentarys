extends SceneTree

## Repere un surplomb, pour viser une capture dessus. Rend des coordonnees
## pretes a passer a `--ici`, **sur la graine 2024** — celle de la demo,
## invariant n. 37. Le point rendu est pose *devant* le surplomb, a une
## distance qui met sa paroi et son ombre dans le champ.
##
## Usage : -s tools/find_mesa.gd -- [nombre] [graine]

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var want: int = int(args[0]) if args.size() > 0 else 6
	var seed_v: int = int(args[1]) if args.size() > 1 else 2024

	var p := CWWorldParams.new()
	p.world_seed = seed_v
	var f := CWTerrainField.new(p)
	var o: Vector2i = p.world_origin
	var found: int = 0
	var seen: Dictionary = {}

	for r in range(0, 96):
		for a in range(0, 12):
			var ang: float = float(a) * TAU / 12.0
			var x: int = o.x + int(cos(ang) * float(r) * 260.0)
			var z: int = o.y + int(sin(ang) * float(r) * 260.0)
			for m in f.mesas().mesas_at(x, z, f):
				if seen.has(m):
					continue
				seen[m] = true
				if m.caves.is_empty():
					continue
				# Devant l'entree de la premiere grotte, en reculant du rayon.
				var c = m.caves[0]
				var dir := Vector2(c.ax - m.x, c.az - m.z).normalized()
				# Second point de vue : face a l'entree de la grotte, de pres.
				print("--ici %d %d --vers %d %d --altitude 4   # grotte" % [
						int(c.ax + dir.x * 55.0), int(c.az + dir.y * 55.0),
						int(c.ax), int(c.az)])
				var d: float = m.radius + 260.0
				var px: int = int(m.x + dir.x * d)
				var pz: int = int(m.z + dir.y * d)
				print("--ici %d %d --vers %d %d   # %s  sol %.0f, entree y=%d" % [
						px, pz, int(m.x), int(m.z), str(m),
						f.sample_column(px, pz).x, c.floor_y])
				found += 1
				if found >= want:
					quit()
					return
	print("rien trouve")
	quit()
