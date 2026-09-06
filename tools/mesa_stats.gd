extends SceneTree

## Mesure la couche de surplombs (jalon 1.15) et la falaise : combien de
## surplombs, quelle taille, quelle part des terres sous un chapeau, quelle part
## de roche de pente, et l'histogramme des pentes.
##
## Usage : -s tools/mesa_stats.gd -- [zones] [pas] [graine]

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var zones: int = int(args[0]) if args.size() > 0 else 36
	var step: int = int(args[1]) if args.size() > 1 else 8
	var seed_v: int = int(args[2]) if args.size() > 2 else 1337

	var p := CWWorldParams.new()
	p.world_seed = seed_v
	var f := CWTerrainField.new(p)
	var sea: int = p.sea_level

	var side: int = int(sqrt(float(zones)))
	var span: int = 384                      # cote sonde par zone, en blocs
	var n_land: int = 0
	var n_slab: int = 0
	var n_over: int = 0                      # surplomb : de l'air sous le chapeau
	var n_cave: int = 0
	var n_rock: int = 0
	var n_beach_mix: int = 0
	var slopes := PackedInt32Array()
	slopes.resize(12)
	var mesas_seen: Dictionary = {}
	var total: int = 0

	for zi in side:
		for zj in side:
			var zx: int = 480 + zi * 7
			var zz: int = 480 + zj * 7
			var bx: int = zx * CWWorldParams.ZONE_SIZE + 4096
			var bz: int = zz * CWWorldParams.ZONE_SIZE + 4096
			for iz in range(0, span, step):
				for ix in range(0, span, step):
					var x: int = bx + ix
					var z: int = bz + iz
					var c: Vector4 = f.sample_column_full(x, z)
					total += 1
					var biome: int = CWBiome.at(c.x, c.y, c.z, sea)
					if biome == CWBiome.OCEANS:
						continue
					n_land += 1
					var slope: float = f.slope_at(x, z)
					var bucket: int = clampi(int(slope * 10.0), 0, 11)
					slopes[bucket] += 1
					var surf: int = CWPalette.surface_of(biome, c.x - float(sea),
							c.y, c.z, x, z, slope)
					if surf == CWPalette.STONE:
						n_rock += 1
					var rel: Vector4i = CWMesaGrid.relief(
							f.mesas().mesas_at(x, z, f), x, z, floori(c.x))
					if rel.y >= rel.x:
						n_slab += 1
						if float(rel.x) > c.x + 1.0:
							n_over += 1
					if rel.w >= rel.z:
						n_cave += 1
					for m in f.mesas().mesas_at(x, z, f):
						mesas_seen[m] = true

	print("--- massifs (graine %d, %d zones, pas %d) ---" % [seed_v, side * side, step])
	print("colonnes sondees : %d, dont terres %d" % [total, n_land])
	print("sous un massif   : %.2f %% des terres" % (100.0 * n_slab / maxi(n_land, 1)))
	print("dont en surplomb : %.2f %% des terres" % (100.0 * n_over / maxi(n_land, 1)))
	print("dans une grotte  : %.3f %% des terres" % (100.0 * n_cave / maxi(n_land, 1)))
	print("roche de pente   : %.2f %% des terres" % (100.0 * n_rock / maxi(n_land, 1)))
	print("massifs vus      : %d" % mesas_seen.size())
	var rr: Array = []
	var hh: Array = []
	for m in mesas_seen.keys():
		rr.append(m.radius)
		hh.append(int(m.height))
	if rr.size() > 0:
		rr.sort()
		hh.sort()
		print("rayon median %.0f blocs, hauteur mediane %d blocs" % [
				rr[rr.size() / 2], hh[hh.size() / 2]])

	# Le caractere des masses (2026-09-09) : chaque massif tire sa rugosite, et
	# c'est ce qui donne des domes et des masses decoupees dans le meme paysage.
	# On rend l'eventail reellement pose sur le monde — le tirage a une
	# fourchette, mais `CWMesaGrid` rabat celles qui sortiraient du contrat
	# d'escalade, donc l'eventail pose n'est pas la fourchette tiree.
	var aa: Array = []
	var pas: Dictionary = {}
	var rabattus: int = 0
	for m in mesas_seen.keys():
		aa.append(m.amp_slow)
		pas[m.max_step()] = int(pas.get(m.max_step(), 0)) + 1
		if m.damped:
			rabattus += 1
	if aa.size() > 0:
		aa.sort()
		var repartition: String = ""
		var cles: Array = pas.keys()
		cles.sort()
		for k in cles:
			repartition += " %d bloc(s):%d" % [k, pas[k]]
		print("rugosite lente de %.3f a %.3f (mediane %.3f), %d rabattus par le contrat"
				% [aa[0], aa[aa.size() - 1], aa[aa.size() / 2], rabattus])
		print("marche maximale par massif :%s" % repartition)
		# La borne **continue**, avant l'arrondi au bloc. C'est elle qui porte
		# vraiment la variation : la borne en blocs entiers ne peut pas
		# descendre sous 2 — `ceil` de tout ce qui est positif vaut au moins 1,
		# et le terrain en ajoute un — donc le contrat d'escalade la fige. Ce
		# qui varie d'un massif a l'autre est la pente reelle et la silhouette.
		var bb: Array = []
		for m in mesas_seen.keys():
			bb.append(m.slope_bound())
		bb.sort()
		print("pente bornee de %.2f a %.2f bloc/bloc (mediane %.2f)"
				% [bb[0], bb[bb.size() - 1], bb[bb.size() / 2]])

	# Les galeries (2026-09-09) : traversantes, a section variable, avec ou sans
	# embranchement. Ce que la suite de tests mesure sur **une** masse, cet outil
	# le mesure sur toutes celles qu'on a croisees.
	var galeries: int = 0
	var branches: int = 0
	var avec_branche: int = 0
	var longueurs: Array = []
	var sections: Array = []
	for m in mesas_seen.keys():
		var b_ici: int = 0
		for c in m.caves:
			if c.branch:
				branches += 1
				b_ici += 1
				continue
			galeries += 1
			var l: float = 0.0
			var rmin: float = INF
			var rmax: float = 0.0
			for k in c.points():
				rmin = minf(rmin, c.radius_at(k))
				rmax = maxf(rmax, c.radius_at(k))
				if k > 0:
					l += c.point_at(k).distance_to(c.point_at(k - 1))
			longueurs.append(l)
			sections.append(rmax / maxf(0.1, rmin))
		if b_ici > 0:
			avec_branche += 1
	if galeries > 0:
		longueurs.sort()
		sections.sort()
		print("galeries %d, embranchements %d sur %d massifs (%.0f %% des galeries en portent)"
				% [galeries, branches, mesas_seen.size(),
				100.0 * float(branches) / float(galeries)])
		print("longueur mediane %.0f blocs, rapport de section median %.2f"
				% [longueurs[longueurs.size() / 2],
				sections[sections.size() / 2]])
	var line: String = "pentes  "
	for b in 12:
		line += " %.1f:%4.1f%%" % [b * 0.1, 100.0 * slopes[b] / maxi(n_land, 1)]
	print(line)
	quit()
