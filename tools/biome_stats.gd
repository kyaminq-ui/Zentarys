extends SceneTree

## Repartition des six biomes et des matieres de surface, mesuree sur le champ
## reel (jalon 1.12).
##
##   godot --headless --path . -s tools/biome_stats.gd
##   godot --headless --path . -s tools/biome_stats.gd -- 12 256 1337
##
## Arguments optionnels : nombre de zones echantillonnees, pas de sondage en
## unites monde, graine.
##
## Raison d'etre : les seuils de `CWBiome` traduisent des fourchettes en degres
## et en pourcents, mais le champ de climat de ce projet n'a aucune raison de
## les remplir dans les memes proportions que le jeu d'origine. Un seuil qui se
## lit juste peut ne rendre que trois taches sur un continent — ou couvrir la
## moitie du monde. Cet outil donne la part reelle de chacun avant qu'on
## regarde une capture, et il est le garde-fou de tout deplacement de seuil.
##
## Il balaie des zones **eloignees les unes des autres** et non un carre autour
## du point de depart : le climat y est median par construction, et une mesure
## locale surestime les Greenlands. C'est le meme piege que celui de
## `PLACEMENT_PASS_RATE` (invariant n° 16).

const DEFAULT_ZONES: int = 12
const DEFAULT_STEP: int = 256


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var zones: int = int(args[0]) if args.size() > 0 else DEFAULT_ZONES
	var step: int = int(args[1]) if args.size() > 1 else DEFAULT_STEP
	var p := CWWorldParams.new()
	if args.size() > 2:
		p.world_seed = int(args[2])

	var field := CWTerrainField.new(p)
	var per_zone: int = CWWorldParams.ZONE_SIZE / step

	# Zones prises sur une grille large autour du centre du monde : de quoi
	# traverser plusieurs continents et plusieurs regimes climatiques.
	var side: int = int(ceil(sqrt(float(zones))))
	var spread: int = 37  # zones d'ecart : premier, donc pas de battement
	var zc: int = CWWorldParams.zone_of(p.start_point.x)

	var biome_count: Dictionary = {}
	var surface_count: Dictionary = {}
	var land: int = 0
	var total: int = 0
	var t_min: float = 1.0
	var t_max: float = 0.0
	var h_min: float = 1.0
	var h_max: float = 0.0
	# Histogramme du climat des terres, par vingtiemes. C'est lui qui dit ce
	# qu'un seuil coute reellement : le champ de climat de ce projet n'est pas
	# uniforme, et deplacer un seuil de 0,06 peut ne rien changer du tout.
	var t_hist: PackedInt32Array = PackedInt32Array()
	t_hist.resize(20)
	var h_hist: PackedInt32Array = PackedInt32Array()
	h_hist.resize(20)
	# Les deux ensemble : c'est le tableau croise qui a montre que « chaud et
	# moyennement humide » n'existe pas dans ce monde.
	var joint: PackedInt32Array = PackedInt32Array()
	joint.resize(25)
	# Les etangs du jalon 1.14, et c'est le garde-fou du seuil de 0,02 : il dit
	# si la porte rend un monde de mares ou un monde sec, et quelle part de la
	# porte porte reellement de l'eau — la rampe triangulaire n'en garde qu'une
	# fraction, et c'est elle qui fait le chapelet.
	var porte: int = 0
	var eau: int = 0
	var creuse: int = 0
	var prof_hist: PackedInt32Array = PackedInt32Array()
	prof_hist.resize(8)
	var t0: int = Time.get_ticks_usec()
	var done: int = 0
	for i in zones:
		@warning_ignore("integer_division")
		var zx: int = zc + (i % side - side / 2) * spread
		@warning_ignore("integer_division")
		var zz: int = zc + (i / side - side / 2) * spread
		var base_x: int = zx << CWWorldParams.ZONE_SHIFT
		var base_z: int = zz << CWWorldParams.ZONE_SHIFT
		for ix in per_zone:
			for iz in per_zone:
				var x: int = base_x + ix * step
				var z: int = base_z + iz * step
				var c4: Vector4 = field.sample_column_full(x, z)
				var c := Vector3(c4.x, c4.y, c4.z)
				var biome: int = CWBiome.at(c.x, c.y, c.z, p.sea_level)
				var surface: int = CWPalette.surface_of(biome,
						c.x - float(p.sea_level), c.y, c.z, x, z)
				if CWTerrainField.pond_gate(c.x, c4.w, p.sea_level):
					porte += 1
					var prof: Vector3i = CWTerrainField.column_profile(
							c.x, c4.w, p.sea_level)
					creuse += floori(c.x) - prof.x
					if prof.y <= prof.z:
						eau += 1
						prof_hist[clampi(prof.z - prof.y + 1, 0, 7)] += 1
					surface = CWVoxelGenerator.pond_surface(surface, biome, prof,
							true)
				biome_count[biome] = int(biome_count.get(biome, 0)) + 1
				surface_count[surface] = int(surface_count.get(surface, 0)) + 1
				total += 1
				if biome != CWBiome.OCEANS:
					land += 1
					var ti: int = clampi(int(c.y * 20.0), 0, 19)
					var hi: int = clampi(int(c.z * 20.0), 0, 19)
					t_hist[ti] += 1
					h_hist[hi] += 1
					@warning_ignore("integer_division")
					var j: int = (ti / 4) * 5 + hi / 4
					joint[j] += 1
				t_min = minf(t_min, c.y)
				t_max = maxf(t_max, c.y)
				h_min = minf(h_min, c.z)
				h_max = maxf(h_max, c.z)
		done += 1
	var secs: float = float(Time.get_ticks_usec() - t0) / 1e6

	print("=== Repartition des biomes ===")
	print("graine %d, %d zones, un sondage tous les %d u : %d colonnes en %.1f s"
			% [p.world_seed, done, step, total, secs])
	print("climat rencontre : temperature %.3f - %.3f (%.0f - %.0f C), "
			% [t_min, t_max, CWBiome.celsius(t_min), CWBiome.celsius(t_max)]
			+ "humidite %.3f - %.3f (%.0f - %.0f %%)"
			% [h_min, h_max, h_min * 100.0, h_max * 100.0])
	print("")
	print("%-12s %10s %8s %8s" % ["biome", "colonnes", "du monde", "des terres"])
	for biome in CWBiome.all():
		var n: int = int(biome_count.get(biome, 0))
		var share_land: String = "-"
		if biome != CWBiome.OCEANS and land > 0:
			share_land = "%.1f %%" % (100.0 * float(n) / float(land))
		print("%-12s %10d %7.1f %% %8s" % [CWBiome.name_of(biome), n,
				100.0 * float(n) / float(total), share_land])
	print("")
	print("%-14s %10s %8s" % ["matiere", "colonnes", "du monde"])
	var surfaces: Array = surface_count.keys()
	surfaces.sort()
	for s in surfaces:
		var n: int = int(surface_count[s])
		print("%-14s %10d %7.1f %%" % [CWPalette.name_of(s), n,
				100.0 * float(n) / float(total)])
	print("")
	print("Climat des terres, par vingtiemes (part cumulee par le haut)")
	print("%-14s %10s %10s | %-14s %10s %10s"
			% ["temperature", "colonnes", "au-dessus", "humidite", "colonnes", "au-dessus"])
	var t_above: int = 0
	var h_above: int = 0
	for k in 20:
		var i: int = 19 - k
		t_above += t_hist[i]
		h_above += h_hist[i]
		print("%.2f - %.2f %10d %9.2f %% | %.2f - %.2f %10d %9.2f %%" % [
				float(i) * 0.05, float(i + 1) * 0.05, t_hist[i],
				100.0 * float(t_above) / float(land),
				float(i) * 0.05, float(i + 1) * 0.05, h_hist[i],
				100.0 * float(h_above) / float(land)])

	print("")
	print("Les etangs (jalon 1.14), porte du champ de chenaux a %.2f" % CWTerrainField.POND_GATE)
	print("  colonnes dans la porte : %8d   %6.2f %% des terres" % [porte,
			100.0 * float(porte) / maxf(1.0, float(land))])
	print("  dont en eau            : %8d   %6.2f %% des terres, %5.1f %% de la porte"
			% [eau, 100.0 * float(eau) / maxf(1.0, float(land)),
			100.0 * float(eau) / maxf(1.0, float(porte))])
	print("  dont en rive           : %8d   %6.2f %% des terres" % [porte - eau,
			100.0 * float(porte - eau) / maxf(1.0, float(land))])
	print("  creusement moyen       : %8.2f blocs par colonne de la porte"
			% [float(creuse) / maxf(1.0, float(porte))])
	print("  profondeur d'eau, en blocs :")
	for d in range(1, 8):
		if prof_hist[d] > 0:
			print("    %d : %8d   %5.1f %% de l'eau" % [d, prof_hist[d],
					100.0 * float(prof_hist[d]) / maxf(1.0, float(eau))])
	print("")
	print("Terres par (temperature, humidite), en % des terres — lignes chaudes en bas")
	print("%-12s %8s %8s %8s %8s %8s" % ["t / h", "0-20 %", "20-40", "40-60",
			"60-80", "80-100"])
	for ti in 5:
		var row: String = "%.1f - %.1f  " % [float(ti) * 0.2, float(ti + 1) * 0.2]
		for hi in 5:
			row += "%7.2f  " % (100.0 * float(joint[ti * 5 + hi]) / float(land))
		print(row)
	quit()
