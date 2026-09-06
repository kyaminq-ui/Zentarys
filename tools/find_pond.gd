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
	var trouve: int = 0
	# Balayage en spirale grossiere autour du point de depart de la demo.
	for r in range(1, 220):
		for a in range(0, 360, 7):
			var x: int = o.x + int(cos(deg_to_rad(float(a))) * float(r) * 24.0)
			var z: int = o.y + int(sin(deg_to_rad(float(a))) * float(r) * 24.0)
			var c: Vector4 = f.sample_column_full(x, z)
			if not CWTerrainField.pond_gate(c.x, c.w, sea):
				continue
			var prof: Vector3i = CWTerrainField.column_profile(c.x, c.w, sea)
			if prof.y > prof.z:
				continue
			# Une mare d'au moins trois blocs de fond, pour que la capture
			# montre autre chose qu'une flaque d'un bloc.
			if prof.z - prof.y + 1 < 3:
				continue
			print("--ici %d %d   sol %d  eau [%d, %d]  profondeur %d  chenal %.4f"
					% [x, z, prof.x, prof.y, prof.z, prof.z - prof.y + 1, c.w])
			trouve += 1
			if trouve >= 6:
				quit()
				return
	print("aucune mare trouvee")
	quit()
