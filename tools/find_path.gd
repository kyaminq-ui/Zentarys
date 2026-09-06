extends SceneTree

## Repere un chemin, pour viser une capture dessus (jalon 1.16). Rend des
## coordonnees pretes a passer a `--ici` / `--vers`, **sur la graine 2024** —
## celle de la demo, invariant n. 37.
##
## Trois sujets, parce que ce sont trois choses differentes a regarder : un
## bout de chaussee, une **levee** au-dessus de l'eau, et une **tranchee** la ou
## le chemin traverse le socle d'un surplomb.
##
## Usage : -s tools/find_path.gd -- [graine]

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var seed_v: int = int(args[0]) if args.size() > 0 else 2024

	var p := CWWorldParams.new()
	p.world_seed = seed_v
	var f := CWTerrainField.new(p)
	var sea: int = p.sea_level
	var o: Vector2i = p.world_origin

	var t0: int = Time.get_ticks_msec()
	var zone: CWPathNetwork.Zone = f.paths().zone_at(o.x, o.y, f)
	print("reseau de la zone construit en %d ms, %d segments, %d cellules"
			% [Time.get_ticks_msec() - t0, zone.segments.size() / 6,
			zone.index.size()])
	if zone.is_empty():
		print("aucun chemin dans cette zone")
		quit()
		return

	var s: PackedFloat32Array = zone.segments
	var n: int = s.size() / 6
	# Le segment le plus proche du depart, pour une capture de chaussee.
	var best: int = 0
	var best_d: float = INF
	var levee: int = -1
	var tranchee: int = -1
	for i in n:
		var mx: float = (s[i * 6] + s[i * 6 + 3]) * 0.5
		var mz: float = (s[i * 6 + 1] + s[i * 6 + 4]) * 0.5
		var d: float = Vector2(mx - float(o.x), mz - float(o.y)).length()
		if d < best_d:
			best_d = d
			best = i
		if levee < 0:
			var c: Vector4 = f.sample_column_full(int(mx), int(mz))
			var biome: int = CWBiome.at(c.x, c.y, c.z, sea)
			var prof: Vector3i = CWTerrainField.column_profile(c.x, c.w, sea, biome)
			if prof.y <= prof.z or c.x < float(sea):
				levee = i
		if tranchee < 0:
			var rel: Vector4i = CWMesaGrid.relief(
					f.mesas().mesas_at(int(mx), int(mz), f), int(mx), int(mz),
					floori(f.sample_column(int(mx), int(mz)).x))
			if rel.y >= rel.x:
				tranchee = i

	_montre(f, s, best, "chaussee")
	if levee >= 0:
		_montre(f, s, levee, "levee")
	else:
		print("# aucune levee dans cette zone")
	if tranchee >= 0:
		_montre(f, s, tranchee, "tranchee dans un surplomb")
	else:
		print("# aucun chemin sous un surplomb dans cette zone")
	quit()


func _montre(f: CWTerrainField, s: PackedFloat32Array, i: int,
		quoi: String) -> void:
	var ax: float = s[i * 6]
	var az: float = s[i * 6 + 1]
	var bx: float = s[i * 6 + 3]
	var bz: float = s[i * 6 + 4]
	var mx: int = int((ax + bx) * 0.5)
	var mz: int = int((az + bz) * 0.5)
	# De cote, a quarante blocs : c'est la distance a laquelle un ruban de six
	# blocs de large se lit encore comme un chemin.
	var dir: Vector2 = Vector2(bx - ax, bz - az).normalized()
	var px: int = mx + int(-dir.y * 42.0)
	var pz: int = mz + int(dir.x * 42.0)
	print("--ici %d %d --vers %d %d --altitude 12   # %s (y %.0f)" % [
			px, pz, mx, mz, quoi, s[i * 6 + 2]])
