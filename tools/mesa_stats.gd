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

	# Le caractere des masses (2026-09-09, refonte du soir) : chaque massif tire
	# sept nombres, et c'est ce qui donne des buttes a paroi, des cretes et des
	# domes dans le meme paysage. Plus rien n'est rabattu — le contrat
	# d'escalade est retire —, donc l'eventail pose **est** la fourchette tiree.
	var warp: Array = []
	var pw: Array = []
	var allonge: Array = []
	var gradins: int = 0
	var etoiles: int = 0
	for m in mesas_seen.keys():
		warp.append(m.amp_warp)
		pw.append(m.profile_pow)
		allonge.append(m.stretch)
		if m.strata >= 1.0:
			gradins += 1
		if m.amp_lobe > 0.15:
			etoiles += 1
	if warp.size() > 0:
		warp.sort()
		pw.sort()
		allonge.sort()
		var n: int = warp.size()
		print("warp de %.3f a %.3f (mediane %.3f)"
				% [warp[0], warp[n - 1], warp[n / 2]])
		print("exposant de profil de %.2f a %.2f (mediane %.2f) — sous 1 : une butte a paroi, a 2 : un dome"
				% [pw[0], pw[n - 1], pw[n / 2]])
		print("allongement de %.2f a %.2f (mediane %.2f)"
				% [allonge[0], allonge[n - 1], allonge[n / 2]])
		print("%d massif(s) a gradins et %d a lobes marques, sur %d"
				% [gradins, etoiles, n])

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
	# -- Ce que les chemins traversent (2026-09-09) --------------------------
	#
	# Depuis que la fonction de cout connait les massifs, le trace glisse vers la
	# ou la masse est mince. On mesure ce qu'il traverse reellement : sur les
	# segments construits de quelques zones, l'epaisseur de massif sous chaque
	# point. C'est le seul moyen de dire si le poids fait quelque chose — un
	# chemin qui contourne bien et un chemin qui n'a rencontre aucun massif se
	# ressemblent beaucoup dans une capture.
	var pts: int = 0
	var sous: int = 0
	var somme: float = 0.0
	var pire: float = 0.0
	for i in 9:
		@warning_ignore("integer_division")
		var zx: int = CWWorldParams.zone_of(p.start_point.x) + (i % 3) - 1
		@warning_ignore("integer_division")
		var zz: int = CWWorldParams.zone_of(p.start_point.y) + (i / 3) - 1
		var zone: CWPathNetwork.Zone = f.paths().get_zone(zx, zz, f)
		var nseg: int = zone.segments.size() / 6
		for k in nseg:
			# Les deux bouts du segment, plus son milieu : trois sondages par
			# segment suffisent a dire si le reseau passe sous la roche.
			for u in 3:
				var t: float = float(u) * 0.5
				var x: int = int(lerpf(zone.segments[k * 6],
						zone.segments[k * 6 + 3], t))
				var z: int = int(lerpf(zone.segments[k * 6 + 1],
						zone.segments[k * 6 + 4], t))
				var e: int = 0
				for m in f.mesas().mesas_at(x, z, f):
					e = maxi(e, m.thickness(x, z))
				pts += 1
				somme += float(e)
				pire = maxf(pire, float(e))
				if e > 0:
					sous += 1
	if pts > 0:
		print("chemins : %d points sondes, %.1f %% sous un massif, epaisseur moyenne %.2f, pire %.0f (poids %.2f)"
				% [pts, 100.0 * float(sous) / float(pts), somme / float(pts),
				pire, CWPathNetwork.MESA_WEIGHT])

	var line: String = "pentes  "
	for b in 12:
		line += " %.1f:%4.1f%%" % [b * 0.1, 100.0 * slopes[b] / maxi(n_land, 1)]
	print(line)
	quit()
