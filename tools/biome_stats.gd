extends SceneTree

## Ecart, en cases de sondage, auquel on juge le voisinage des biomes.
## Seize cases de 256 unites = 4 096 unites, l'echelle d'une marche.
const VOISIN_PAS: int = 16

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
	# Voisinage des biomes : c'est le garde-fou des **provinces climatiques**
	# (`CWRegionSiteGrid`, 2026-09-06). Un monde ou une Snowlands touche un
	# desert n'est pas credible, et aucune repartition globale ne le dit — les
	# deux peuvent faire 14 % chacun en etant bien separes ou entremeles. Ce
	# qu'on compte ici, ce sont les **paires voisines** de biomes incompatibles.
	var grille: PackedInt32Array = PackedInt32Array()
	grille.resize(per_zone * per_zone)
	var paires: int = 0
	var paires_froid_chaud: int = 0
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
						c.x - float(p.sea_level), x, z)
				if CWTerrainField.pond_gate(c.x, c4.w, p.sea_level, biome):
					porte += 1
					var prof: Vector3i = CWTerrainField.column_profile(
							c.x, c4.w, p.sea_level, biome)
					creuse += floori(c.x) - prof.x
					if prof.y <= prof.z:
						eau += 1
						prof_hist[clampi(prof.z - prof.y + 1, 0, 7)] += 1
					surface = CWVoxelGenerator.pond_surface(surface, prof,
							true)
				grille[ix * per_zone + iz] = biome
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
		# Fin de zone : on compte les paires voisines de sa grille.
		#
		# **L'ecart est de seize cases, pas d'une.** A 256 unites, deux sondages
		# tombent presque toujours dans le meme climat — la mesure y rend zero
		# avant comme apres, et ne dit rien. Ce qu'on veut savoir est si l'on
		# traverse du tempere en allant de la neige au desert, ce qui se juge a
		# l'echelle d'une marche : 4 096 unites, soit un quart de zone.
		for gx in per_zone:
			for gz in per_zone:
				var b0: int = grille[gx * per_zone + gz]
				if b0 == CWBiome.OCEANS:
					continue
				for d in 2:
					var nx: int = gx + (VOISIN_PAS if d == 0 else 0)
					var nz: int = gz + (0 if d == 0 else VOISIN_PAS)
					if nx >= per_zone or nz >= per_zone:
						continue
					var b1: int = grille[nx * per_zone + nz]
					if b1 == CWBiome.OCEANS:
						continue
					paires += 1
					var froid: bool = (b0 == CWBiome.SNOWLANDS
							or b1 == CWBiome.SNOWLANDS)
					var chaud: bool = (b0 == CWBiome.DESERTS
							or b1 == CWBiome.DESERTS
							or b0 == CWBiome.LAVALANDS
							or b1 == CWBiome.LAVALANDS)
					if froid and chaud:
						paires_froid_chaud += 1
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
	print("Voisinage des biomes, sur %d paires de terres a %d unites d'ecart"
			% [paires, step * VOISIN_PAS])
	print("  neige contre desert ou lave : %d   %.3f %% des paires"
			% [paires_froid_chaud,
			100.0 * float(paires_froid_chaud) / maxf(1.0, float(paires))])
	print("")
	print("Les etangs (jalon 1.14), porte du chenal de %.3f en altitude a %.3f au ras de la mer"
			% [CWTerrainField.POND_GATE_HAUT, CWTerrainField.POND_GATE_BAS])
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

	_ecotone(field, p)
	quit()


# -- La largeur de l'ecotone, en blocs ----------------------------------------
#
# Le balayage ci-dessus sonde tous les 256 blocs : une frange large d'une
# trentaine de blocs lui est **invisible**, et c'est pourquoi il n'a rien vu du
# defaut du 2026-09-08 — de l'herbe au milieu du desert, du sable au milieu des
# Lava Lands. La frange se mesure a la maille du bloc, sur des transects qui
# traversent une frontiere.
#
# Ce qu'on compte : pour chaque colonne ou le biome **trame** (la matiere du
# sol) differe du biome **nomme** (`CWBiome.at`), la distance en blocs jusqu'a
# la frontiere la plus proche — c'est-a-dire la **profondeur d'incursion** de la
# matiere dans le biome voisin. C'est exactement le nombre que le reproche
# designait : « de l'herbe se retrouve dans le desert ».
#
# Le contrat est `CWTerrainField.FRINGE_BLOCKS`. Une incursion qui le depasse largement
# est le defaut ; une frange tombee a zero partout est la sur-correction — la
# mesure doit distinguer les deux, donc elle rend aussi la part de colonnes en
# frange et le compte de frontieres traversees.

## Combien de frontieres on veut mesurer, et sur quelle demi-largeur.
##
## `MI_LARGEUR` doit valoir plusieurs fois `CWTerrainField.FRINGE_BLOCKS`, sans quoi la
## mesure ne pourrait pas voir une frange qui deborde son contrat — elle
## rapporterait le maximum de sa propre fenetre.
const FRONTIERES: int = 24
const MI_LARGEUR: int = 128

## Pas et portee de la recherche de frontieres. Le pas est grossier : on cherche
## un endroit ou le biome change, pas encore ou exactement.
const CHERCHE_PAS: int = 64
const CHERCHE_PORTEE: int = 24000


func _ecotone(field: CWTerrainField, p: CWWorldParams) -> void:
	var franges: int = 0
	var colonnes: int = 0
	var trouvees: int = 0
	var prof_max: int = 0
	var prof_sum: int = 0
	# Histogramme de la profondeur d'incursion, par tranches de 16 blocs.
	var hist: PackedInt32Array = PackedInt32Array()
	hist.resize(8)
	# Les couples qui debordent le plus, pour nommer le defaut plutot que le
	# compter : cle = nomme * 6 + trame.
	var couples: Dictionary = {}
	var t0: int = Time.get_ticks_usec()

	# Huit rayons partant de points eloignes : on avance a gros pas jusqu'a
	# voir le biome changer, puis on mesure finement de part et d'autre.
	for k in 8:
		if trouvees >= FRONTIERES:
			break
		var bx: int = p.start_point.x + (k % 4) * 61007 - 90000
		var bz: int = p.start_point.y + (k / 4) * 59999 - 30000
		var prev: int = -1
		var i: int = 0
		while i < CHERCHE_PORTEE and trouvees < FRONTIERES:
			var x: int = bx + i
			var z: int = bz + i / 3
			var c: Vector3 = field.sample_column(x, z)
			var b: int = CWBiome.at(c.x, c.y, c.z, p.sea_level)
			# Une frontiere d'ocean se decide sur l'altitude, pas sur le climat :
			# le tramage ne peut rien y changer, et la compter diluerait la
			# mesure jusqu'a la rendre muette. C'est ce qui a fait echouer la
			# premiere version de cet outil.
			if prev != -1 and b != prev and b != CWBiome.OCEANS 					and prev != CWBiome.OCEANS:
				trouvees += 1
				var r: Vector4i = _mesure_frange(field, p, x, z, couples)
				franges += r.x
				colonnes += r.y
				prof_sum += r.z
				prof_max = maxi(prof_max, r.w)
				# Le detail de l'histogramme est repris dans `_mesure_frange`,
				# qui seul connait la profondeur colonne par colonne.
				i += MI_LARGEUR * 4
			prev = b
			i += CHERCHE_PAS
	for c in _hist_frange:
		hist[clampi(c / 16, 0, 7)] += 1
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0

	print("")
	print("L'ecotone, mesure a la maille du bloc sur %d frontieres de climat (%.0f ms)"
			% [trouvees, ms])
	print("  contrat CWTerrainField.FRINGE_BLOCKS : %.0f blocs, fenetre de mesure +-%d"
			% [CWTerrainField.FRINGE_BLOCKS, MI_LARGEUR])
	print("  colonnes en frange     : %8d   %6.2f %% des colonnes mesurees"
			% [franges, 100.0 * float(franges) / maxf(1.0, float(colonnes))])
	if franges == 0:
		print("  aucune frange : la correction a mange l'ecotone au lieu de le borner")
		return
	print("  incursion moyenne      : %8.1f blocs"
			% (float(prof_sum) / float(franges)))
	print("  incursion maximale     : %8d blocs   (contrat : %.0f)"
			% [prof_max, CWTerrainField.FRINGE_BLOCKS])
	print("  profondeur d'incursion, par tranches de 16 blocs :")
	for d in 8:
		if hist[d] == 0:
			continue
		var borne: String = "%3d - %3d" % [d * 16, d * 16 + 15]
		if d == 7:
			borne = "    112 +"
		print("    %s : %8d   %5.1f %% des franges" % [borne, hist[d],
				100.0 * float(hist[d]) / float(franges)])
	print("  les couples qui debordent (biome nomme -> matiere posee) :")
	var cles: Array = couples.keys()
	cles.sort_custom(func(a, b): return couples[a] > couples[b])
	for c in cles.slice(0, 6):
		@warning_ignore("integer_division")
		var a: int = c / CWBiome.COUNT
		print("    %-12s -> %-12s %8d   %5.1f %% des franges"
				% [CWBiome.name_of(a), CWBiome.name_of(c % CWBiome.COUNT),
				couples[c], 100.0 * float(couples[c]) / float(franges)])


## Profondeurs d'incursion relevees, pour l'histogramme. Une seule mesure tourne
## a la fois : la garder ici evite de promener un tableau dans deux signatures.
var _hist_frange: PackedInt32Array = PackedInt32Array()


## Mesure la frange autour d'un point de frontiere : on parcourt la fenetre a la
## maille du bloc, on relocalise la frontiere exacte, puis on compte pour chaque
## desaccord sa distance a celle-ci.
##
## Rend Vector4i(franges, colonnes, somme des profondeurs, profondeur maximale).
func _mesure_frange(field: CWTerrainField, p: CWWorldParams, cx: int, cz: int,
		couples: Dictionary) -> Vector4i:
	var n: int = MI_LARGEUR * 2 + 1
	var nomme: PackedInt32Array = PackedInt32Array()
	var trame: PackedInt32Array = PackedInt32Array()
	nomme.resize(n)
	trame.resize(n)
	for j in n:
		var x: int = cx + j - MI_LARGEUR
		var z: int = cz + (j - MI_LARGEUR) / 3
		var c: Vector3 = field.sample_column(x, z)
		nomme[j] = CWBiome.at(c.x, c.y, c.z, p.sea_level)
		trame[j] = field.fringe_biome(x, z, c.x)

	var bords: PackedInt32Array = PackedInt32Array()
	for j in range(1, n):
		if nomme[j] != nomme[j - 1]:
			bords.append(j)
	if bords.is_empty():
		return Vector4i(0, n, 0, 0)

	var franges: int = 0
	var somme: int = 0
	var pire: int = 0
	for j in n:
		if trame[j] == nomme[j]:
			continue
		var d: int = n
		for b in bords:
			d = mini(d, absi(j - b))
		franges += 1
		somme += d
		pire = maxi(pire, d)
		_hist_frange.append(d)
		var cle: int = nomme[j] * CWBiome.COUNT + trame[j]
		couples[cle] = int(couples.get(cle, 0)) + 1
	return Vector4i(franges, n, somme, pire)
