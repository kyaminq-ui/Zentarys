extends SceneTree

## Resout les seuils de `CWBiome` et le niveau de la mer qui rendent **six parts
## egales du monde** (2026-09-11).
##
##   godot --headless --path . -s tools/biome_balance.gd
##   godot --headless --path . -s tools/biome_balance.gd -- 144 512 1337
##
## Arguments optionnels : nombre de zones echantillonnees, pas de sondage en
## unites monde, graine. Memes valeurs et meme grille de zones que
## `tools/biome_stats.gd`, pour que les deux mesures se comparent.
##
## -- Pourquoi un outil, et non six valeurs posees a la main -------------------
##
## Les seuils de `CWBiome` ne sont pas des degres : ce sont des **quantiles d'un
## champ qu'on ne choisit pas**. Le champ de climat de ce projet est bimodal —
## un point chaud y est soit tres sec, soit tres humide, jamais entre les deux —
## et l'annexe de `docs/ROADMAP.md` raconte deux regles qui etaient justes et
## vides pour cette seule raison. Deviner un seuil, le mesurer, le corriger, le
## remesurer coute une demi-journee et se refait a chaque retouche du champ.
##
## Cet outil fait l'inverse : il echantillonne une fois, garde les colonnes en
## memoire, et **lit les seuils comme des quantiles**. Il rend des valeurs
## pretes a recopier dans `CWBiome`, et il se relance en quinze secondes le jour
## ou le champ bougera.
##
## -- Ce qu'il a appris, et qui a change la regle du monde --------------------
##
## La premiere version resolvait les six seuils tels qu'ils etaient. Elle a
## trouve les parts de Snowlands, Jungles, Lava Lands et de l'ocean, et **elle
## n'a pas pu trouver celle des deserts** : `DESERT_T` est descendu jusqu'a zero
## en ne rendant que 3 % du monde. La cause n'etait pas un seuil mal place mais
## la **forme de la regle** — Lava Lands, teste avant le desert, prenait toute
## la moitie seche au-dessus de son seuil, et il ne restait au desert que le sec
## *froid*, que le champ ne produit presque pas.
##
## D'ou la regle telle qu'elle est maintenant : **une seule frontiere
## d'humidite** partage le monde en sec et humide, et la temperature fait le
## reste — Snowlands au froid, puis Deserts et Lava Lands se partagent le sec
## par temperature croissante, Jungles prend le chaud humide, Greenlands garde
## le tempere des deux cotes. C'est aussi ce que la mesure du champ disait
## depuis le debut : *un point chaud est soit tres sec, soit tres humide*.
##
## -- L'ordre de resolution est celui des tests de `CWBiome.at` ---------------
##
## `at` teste dans l'ordre : ocean, Snowlands, Lava Lands, Jungles, Deserts, et
## Greenlands ramasse le reste. Chaque regle ne voit donc que ce que les
## precedentes ont laisse, et les seuils **ne sont pas independants** : elargir
## Lava Lands retire du desert, pas de la prairie.
##
## -- Le degre de liberte, et ce qu'il decide vraiment ------------------------
##
## Cinq seuils de climat pour quatre egalites : il reste une liberte, et c'est
## `HUMID_H`, la frontiere sec/humide. **Elle ne decide pas l'egalite** — le
## compte le dit tout seul : si le sec porte au moins deux quotas (Deserts et
## Lava Lands) et l'humide au moins un (Jungles), alors ce qui reste fait
## exactement un quota, et Greenlands est egal aux autres sans qu'on ait rien a
## regler. Toute frontiere praticable rend donc six parts egales.
##
## Ce qu'elle decide, c'est **de quel cote Greenlands est preleve**. On la pose
## donc la ou le reste se partage a parts egales entre les deux moities : le sec
## porte deux quotas plus la moitie de Greenlands, l'humide un quota plus
## l'autre moitie. Une prairie est alors le tempere des deux versants, et non la
## retombee d'un seul.
##
## > La premiere version cherchait cette frontiere par dichotomie sur la part de
## > Greenlands. Elle ne pouvait pas converger : la part visee est atteinte
## > **partout** dans la fenetre praticable, a l'arrondi des quotas pres, donc
## > le test comparait du bruit et poussait le seuil jusqu'au bord — ou l'humide
## > n'a plus de quoi remplir Jungles, qui s'effondrait a 3,6 %. *Un critere qui
## > vaut vrai partout n'est pas un critere.*

const DEFAULT_ZONES: int = 144
const DEFAULT_STEP: int = 512


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var zones: int = int(args[0]) if args.size() > 0 else DEFAULT_ZONES
	var step: int = int(args[1]) if args.size() > 1 else DEFAULT_STEP
	var p := CWWorldParams.new()
	if args.size() > 2:
		p.world_seed = int(args[2])

	print("=== Six parts egales : les seuils qui les rendent ===")
	print("graine %d, %d zones, un sondage tous les %d u" % [p.world_seed, zones, step])

	var t0: int = Time.get_ticks_usec()
	var col: Dictionary = _echantillonne(p, zones, step)
	var hs: PackedFloat32Array = col["h"]
	var ts: PackedFloat32Array = col["t"]
	var us: PackedFloat32Array = col["u"]
	var n: int = hs.size()
	print("%d colonnes en %.1f s" % [n, float(Time.get_ticks_usec() - t0) / 1e6])

	var cible: float = 1.0 / 6.0

	# -- 1. Le niveau de la mer, lu comme un quantile d'altitude -------------
	#
	# Une colonne est de l'ocean quand `altitude - mer < OCEAN_DEPTH`. Le
	# niveau qui rend un sixieme d'ocean est donc **le sixieme quantile des
	# altitudes**, remonte de `OCEAN_DEPTH`. Pas de dichotomie : c'est un tri.
	var tri: PackedFloat32Array = hs.duplicate()
	tri.sort()
	var mer_i: int = roundi(tri[int(cible * float(n))] - CWBiome.OCEAN_DEPTH)
	var plancher: float = float(mer_i) + CWBiome.OCEAN_DEPTH

	print("")
	print("[le niveau de la mer]")
	print("  actuel   %4d   ->  ocean %.1f %% du monde" % [p.sea_level,
			100.0 * _part_sous(tri, float(p.sea_level) + CWBiome.OCEAN_DEPTH)])
	print("  resolu   %4d   ->  ocean %.1f %% du monde  (cible 16,7 %%)"
			% [mer_i, 100.0 * _part_sous(tri, plancher)])

	# -- 2. Les terres, et le froid ------------------------------------------
	var terre_t := PackedFloat32Array()
	var terre_u := PackedFloat32Array()
	for i in n:
		if hs[i] >= plancher:
			terre_t.append(ts[i])
			terre_u.append(us[i])
	var nt: int = terre_t.size()
	# Combien de colonnes chaque biome doit prendre pour faire un sixieme **du
	# monde** — le compte est en colonnes du monde, pas en part des terres,
	# parce que c'est le monde qu'on egalise.
	var quota: int = int(cible * float(n))
	print("")
	print("[les cinq biomes de climat]")
	print("  %d colonnes de terre, soit %.1f %% du monde" % [nt,
			100.0 * float(nt) / float(n)])
	print("  quota : %d colonnes chacun, soit %.1f %% des terres"
			% [quota, 100.0 * float(quota) / float(nt)])

	# Snowlands est le premier test apres l'ocean : il prend le froid des deux
	# moities, humide comme seche, donc son seuil ne depend pas de `HUMID_H`.
	var froid: PackedFloat32Array = terre_t.duplicate()
	froid.sort()
	var snow_t: float = froid[mini(quota, nt - 1)]

	# -- 3. La frontiere sec/humide ------------------------------------------
	#
	# Voir l'en-tete : elle ne decide pas l'egalite, elle decide de quel cote
	# Greenlands est preleve. Les terres tempérées se repartissent en deux parts
	# egales — le sec doit donc porter deux quotas et demi, l'humide un et demi,
	# soit cinq huitiemes des terres chaudes du cote sec.
	var chaud := PackedFloat32Array()
	for i in nt:
		if terre_t[i] >= snow_t:
			chaud.append(terre_u[i])
	chaud.sort()
	var humid_h: float = chaud[mini(int(0.625 * float(chaud.size())),
			chaud.size() - 1)]
	var best: Dictionary = _seuils(terre_t, terre_u, snow_t, humid_h, quota)

	print("")
	print("  seuil            actuel   resolu")
	_ligne("SNOW_T", CWBiome.SNOW_T, snow_t)
	_ligne("HUMID_H", CWBiome.HUMID_H, humid_h)
	_ligne("JUNGLE_T", CWBiome.JUNGLE_T, best["jungle_t"])
	_ligne("LAVA_T", CWBiome.LAVA_T, best["lava_t"])
	_ligne("DESERT_T", CWBiome.DESERT_T, best["desert_t"])

	# -- 4. Ce que ces seuils rendent, verifie en les rejouant ---------------
	#
	# Les quantiles ont resolu chaque part sur ce que les precedentes
	# laissaient ; ce bloc-ci rejoue la regle entiere, dans l'ordre de `at`, et
	# compte. C'est la seule ligne du fichier qui dise ce que le monde
	# contiendra vraiment.
	print("")
	print("[verification : la regle rejouee]")
	var compte: PackedInt32Array = PackedInt32Array()
	compte.resize(CWBiome.COUNT)
	for i in n:
		compte[_at(hs[i], ts[i], us[i], plancher, snow_t, best["lava_t"],
				best["jungle_t"], humid_h, best["desert_t"])] += 1
	var pire: float = 0.0
	for b in CWBiome.COUNT:
		var part: float = float(compte[b]) / float(n)
		pire = maxf(pire, absf(part - cible))
		print("  %-12s %7d   %5.1f %% du monde   (ecart %+.1f pt)"
				% [CWBiome.name_of(b), compte[b], 100.0 * part,
						100.0 * (part - cible)])
	print("  ecart maximal a la sixieme part : %.2f point" % (100.0 * pire))
	quit()


## Les quatre seuils de temperature, pour une frontiere d'humidite donnee.
##
## Chacun est le **quantile** de ce que les tests precedents ont laisse : c'est
## ce qui remplace la dichotomie, et ce qui rend la boucle exterieure abordable.
## Rend aussi la part que Greenlands ramasse, qui est ce que la boucle cherche a
## amener au quota.
func _seuils(t: PackedFloat32Array, u: PackedFloat32Array, snow_t: float,
		humid_h: float, quota: int) -> Dictionary:
	var sec := PackedFloat32Array()
	var humide := PackedFloat32Array()
	var n: int = t.size()
	for i in n:
		if t[i] < snow_t:
			continue
		if u[i] < humid_h:
			sec.append(t[i])
		else:
			humide.append(t[i])
	sec.sort()
	humide.sort()

	# Lava Lands prend le haut du sec, Deserts la tranche juste en dessous.
	# Prendre les deux dans le meme tableau trie est ce qui garantit qu'ils ne
	# se recouvrent pas, quel que soit ce que le champ contient.
	var lava_t: float = sec[maxi(0, sec.size() - quota)] if sec.size() > 0 else 1.0
	var desert_t: float = sec[maxi(0, sec.size() - 2 * quota)] if sec.size() > 0 else 1.0
	var jungle_t: float = humide[maxi(0, humide.size() - quota)] \
			if humide.size() > 0 else 1.0

	var greenlands: int = 0
	for i in n:
		if t[i] < snow_t:
			continue
		if u[i] < humid_h:
			if t[i] >= desert_t:
				continue
		elif t[i] >= jungle_t:
			continue
		greenlands += 1
	return {"humid_h": humid_h, "lava_t": lava_t, "desert_t": desert_t,
			"jungle_t": jungle_t, "greenlands": greenlands}


## Un balayage, et un seul : altitude, temperature, humidite par colonne.
##
## Meme grille de zones que `tools/biome_stats.gd` — zones **eloignees les unes
## des autres** et non un carre autour du depart, ou le climat est median par
## construction et ou toute mesure surestime les Greenlands.
func _echantillonne(p: CWWorldParams, zones: int, step: int) -> Dictionary:
	var field := CWTerrainField.new(p)
	var per_zone: int = CWWorldParams.ZONE_SIZE / step
	var side: int = int(ceil(sqrt(float(zones))))
	var spread: int = 37
	var zc: int = CWWorldParams.zone_of(p.start_point.x)
	var hs := PackedFloat32Array()
	var ts := PackedFloat32Array()
	var us := PackedFloat32Array()
	for i in zones:
		@warning_ignore("integer_division")
		var zx: int = zc + (i % side - side / 2) * spread
		@warning_ignore("integer_division")
		var zz: int = zc + (i / side - side / 2) * spread
		var base_x: int = zx << CWWorldParams.ZONE_SHIFT
		var base_z: int = zz << CWWorldParams.ZONE_SHIFT
		for ix in per_zone:
			for iz in per_zone:
				var c: Vector3 = field.sample_column(
						base_x + ix * step, base_z + iz * step)
				hs.append(c.x)
				ts.append(c.y)
				us.append(c.z)
	return {"h": hs, "t": ts, "u": us}


## La regle de `CWBiome.at`, rejouee avec des seuils passes en argument.
##
## C'est une **copie**, et c'est un risque assume : elle doit rester l'image de
## `at`, sinon l'outil resout les seuils d'une regle qui n'est pas celle du
## monde. Le jour ou `at` gagne un test, celui-ci doit le gagner aussi.
func _at(h: float, t: float, u: float, plancher: float, snow_t: float,
		lava_t: float, jungle_t: float, humid_h: float,
		desert_t: float) -> int:
	if h < plancher:
		return CWBiome.OCEANS
	if t < snow_t:
		return CWBiome.SNOWLANDS
	if t >= lava_t and u < humid_h:
		return CWBiome.LAVALANDS
	if t >= jungle_t and u >= humid_h:
		return CWBiome.JUNGLES
	if t >= desert_t and u < humid_h:
		return CWBiome.DESERTS
	return CWBiome.GREENLANDS


## Part des colonnes strictement sous un plancher, dans un tableau **trie**.
func _part_sous(tri: PackedFloat32Array, plancher: float) -> float:
	var lo: int = 0
	var hi: int = tri.size()
	while lo < hi:
		@warning_ignore("integer_division")
		var mid: int = (lo + hi) / 2
		if tri[mid] < plancher:
			lo = mid + 1
		else:
			hi = mid
	return float(lo) / float(tri.size())


func _ligne(nom: String, actuel: float, resolu: float) -> void:
	print("  %-14s   %6.3f   %6.3f%s" % [nom, actuel, resolu,
			"" if absf(actuel - resolu) < 1e-6 else "   <- deplace"])
