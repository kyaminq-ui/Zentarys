extends SceneTree

## Cherche un filon et rend ses coordonnees pour `terrain_demo --ici x z`.
##
## **Graine 2024**, celle de la demo, et pas le 1337 des outils headless : c'est
## l'invariant n. 37, et un point releve sur la mauvaise graine decrit un autre
## endroit du monde sans que rien ne le signale.
##
## Balaie les cellules de `CWOreScatter` en spirale autour du point de depart de
## la demo — pas une recherche de colonne, un filon se decide par cellule.
func _init() -> void:
	var p := CWWorldParams.new()
	p.world_seed = 2024
	var f := CWTerrainField.new(p)
	var ores := CWOreScatter.new(f)
	if not ores.library().has_any():
		print("aucun modele de filon charge")
		quit(1)
		return
	var o0 := Vector2i(p.world_origin.x >> CWOreScatter.ORE_CELL_SHIFT,
			p.world_origin.y >> CWOreScatter.ORE_CELL_SHIFT)
	var trouve: int = 0
	for r in range(0, 60):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				for pl in ores.cell(o0.x + dx, o0.y + dz):
					print("--ici %d %d   filon %s" % [pl.x, pl.z, pl.model.name])
					trouve += 1
					if trouve >= 12:
						quit()
						return
	print("aucun filon trouve (%d cellules balayees)" % ((2 * 60 + 1) ** 2))
	quit()
