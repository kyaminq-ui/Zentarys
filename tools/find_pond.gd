extends SceneTree

## Cherche une mare et rend ses coordonnees pour `terrain_demo --ici x z`.
##
## **Graine 2024**, celle de la demo, et pas le 1337 des outils headless : c'est
## l'invariant n. 37, et un point releve sur la mauvaise graine decrit un autre
## endroit du monde sans que rien ne le signale.
func _init() -> void:
	var p := CWWorldParams.new()
	p.world_seed = 2024
	var f := CWTerrainField.new(p)
	var sea: int = p.sea_level
	var o: Vector2i = p.world_origin
	# `-- --bas <n>` : ne garder que l'eau a moins de n blocs au-dessus de la
	# mer, la ou la porte est large et ou les rivieres s'etalent en lacs.
	var alt_max: float = 1e9
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--bas" and i + 1 < args.size():
			alt_max = float(args[i + 1])
	var trouve: int = 0
	# Balayage en spirale grossiere autour du point de depart de la demo.
	for r in range(1, 220):
		for a in range(0, 360, 7):
			var x: int = o.x + int(cos(deg_to_rad(float(a))) * float(r) * 24.0)
			var z: int = o.y + int(sin(deg_to_rad(float(a))) * float(r) * 24.0)
			var c: Vector4 = f.sample_column_full(x, z)
			var biome: int = CWBiome.at(c.x, c.y, c.z, sea)
			if not CWTerrainField.pond_gate(c.x, c.w, sea, biome):
				continue
			var prof: Vector3i = CWTerrainField.column_profile(
					c.x, c.w, sea, biome)
			if prof.y > prof.z:
				continue
			# Une mare d'au moins trois blocs de fond, pour que la capture
			# montre autre chose qu'une flaque d'un bloc.
			if prof.z - prof.y + 1 < 3:
				continue
			var above: float = c.x - float(sea)
			if above > alt_max:
				continue
			print("--ici %d %d   sol %d (+%d)  eau [%d, %d]  prof %d  chenal %.4f"
					% [x, z, prof.x, roundi(above), prof.y, prof.z,
					prof.z - prof.y + 1, c.w])
			trouve += 1
			if trouve >= 6:
				quit()
				return
	print("aucune mare trouvee")
	quit()
