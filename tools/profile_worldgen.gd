extends SceneTree

## Profil du chargement, **poste par poste**. C'est l'etape 1 de la demande
## d'optimisation, et le fichier de reprise dit pourquoi elle vient avant tout
## le reste : *mesurer avant d'ecrire*.
##
## -- Pourquoi cet outil existe -------------------------------------------------
##
## La suite de validation porte un banc, mais il ne mesure qu'une chose : le cout
## d'une colonne du champ. Or « le chargement » est une somme, et on ne savait
## pas laquelle. Le 2026-09-10, le fichier de reprise annoncait 28,5 s pour
## stabiliser une vue de 384 blocs ; le chiffre reel etait **107,7 s**, et
## personne ne l'avait vu parce que rien ne le remesurait. D'ou l'invariant
## n. 51, et d'ou ceci.
##
## -- Ce qu'il mesure, et ce qu'il ne mesure pas --------------------------------
##
## Il mesure le **debit** : combien coute chaque poste, par colonne ou par
## cellule, sur le chemin que le streaming emprunte reellement. Il ne mesure pas
## la **latence** — la saccade a l'arrivee d'un pave —, qui est une affaire
## d'ordonnancement et se regarde en jeu, pas ici. Les deux problemes n'ont pas
## le meme remede, et les melanger coute une journee.
##
## Il ne mesure pas non plus le **maillage** : il appartient a Voxel Tools, il
## tourne sur son propre pool, et rien d'ici ne peut l'isoler. Ce qu'on en sait
## se lit a l'ATH de la demo, sur la file « maillage ».
##
## > ⚠️ **Une mesure de cout se prend sur une session qui ne fait que ca.** Le
## > banc de `worldgen_test` a sorti 125 us/colonne une fois, contre 73 a 80 les
## > fois suivantes, simplement parce qu'une autre instance de Godot tournait en
## > fond. Fermer l'editeur avant de lancer ceci.
##
## Usage : -s tools/profile_worldgen.gd -- [colonnes] [graine]
##         (par defaut 4096 colonnes sur la graine 2024, celle de la demo)

## Cote du pave sonde, en colonnes. Un bloc de terrain fait 16x16 ; on mesure
## donc sur un multiple, pour que `_get_patch` voie ce qu'il voit en vrai.
const PATCH: int = 16


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var n: int = int(args[0]) if args.size() > 0 else 4096
	var seed_v: int = int(args[1]) if args.size() > 1 else 2024

	print("profil du chargement — %d colonnes, graine %d" % [n, seed_v])
	print("(fermer l'editeur avant de lire ces chiffres : une autre instance de")
	print(" Godot en fond les fausse d'un facteur un et demi)")
	print("")

	_poste_champ(n, seed_v)
	_poste_dispersion(seed_v)
	_poste_pave(seed_v)
	quit()


## Un champ neuf. Chaque mesure repart de zero : les caches de sites et
## d'elements sont ce qui fait la difference entre froid et chaud, et les
## melanger dans une meme session rendrait la seconde mesure gratuite.
func _champ(seed_v: int, features: bool = true, cliff: bool = true,
		roads: bool = true) -> CWTerrainField:
	var p := CWWorldParams.new()
	p.world_seed = seed_v
	p.tile_features = features
	p.cliff_slope = cliff
	p.road_network = roads
	return CWTerrainField.new(p)


## Un point a `i` colonnes du depart, sur une diagonale. Une diagonale plutot
## qu'un carre : elle traverse des zones et des tuiles au lieu de rester dans
## la meme, donc elle paie les caches comme le streaming les paie.
func _point(f: CWTerrainField, i: int) -> Vector2i:
	var o: Vector2i = f.params().world_origin
	return Vector2i(o.x + i * 7, o.y + i * 11)


## Chronometre `n` appels, en microsecondes par appel.
func _mesure(n: int, f: Callable) -> float:
	var t0: int = Time.get_ticks_usec()
	for i in n:
		f.call(i)
	return float(Time.get_ticks_usec() - t0) / float(n)


func _ligne(quoi: String, us: float, base: float = 0.0) -> void:
	var part: String = ""
	if base > 0.0:
		part = "   %5.1f %% du champ" % (us / base * 100.0)
	print("  %-42s %8.2f us%s" % [quoi, us, part])


# -- 1. Le champ d'altitude, terme par terme ----------------------------------

func _poste_champ(n: int, seed_v: int) -> void:
	print("[le champ d'altitude — %d colonnes]" % n)

	# La reference : ce que paie une colonne complete, tout allume. C'est le
	# nombre que la suite de validation imprime, et le plafond de tout.
	var f: CWTerrainField = _champ(seed_v)
	# Chauffe : la premiere colonne construit une fenetre de sites et une zone
	# d'elements, soit des centaines de millisecondes qui n'appartiennent a
	# aucune colonne en particulier.
	f.sample_column_full(_point(f, 0).x, _point(f, 0).y)
	var plein: float = _mesure(n, func(i):
		var q: Vector2i = _point(f, i)
		f.sample_column_full(q.x, q.y))
	_ligne("colonne complete (sample_column_full)", plein)

	# Sans les elements de tuile : ce que coutent les crateres, les collines et
	# les bourgs qui deforment le champ.
	var f2: CWTerrainField = _champ(seed_v, false)
	f2.sample_column_full(_point(f2, 0).x, _point(f2, 0).y)
	var sans_elem: float = _mesure(n, func(i):
		var q: Vector2i = _point(f2, i)
		f2.sample_column_full(q.x, q.y))
	_ligne("  dont elements de tuile", plein - sans_elem, plein)
	_ligne("  colonne sans elements", sans_elem, plein)

	# Le climat seul — et c'est `climate_blend`, pas `climate_at`. La seconde
	# passe par `sample_column` et paie donc la colonne entiere pour deux
	# nombres qui n'en dependent pas ; son en-tete le dit, et la premiere
	# version de cet outil s'y est laissee prendre : elle a mesure 72 us la ou
	# le climat en coute deux.
	var clim: float = _mesure(n, func(i):
		var q: Vector2i = _point(f, i)
		f.climate_blend(q.x, q.y))
	_ligne("climat seul (climate_blend)", clim, plein)

	# La pente : une colonne de plus sur chaque axe, le prix de la falaise.
	var pente: float = _mesure(n, func(i):
		var q: Vector2i = _point(f, i)
		f.slope_at(q.x, q.y))
	_ligne("pente (slope_at, appel isole)", pente, plein)

	# Le chenal, qui decide l'eau.
	var chenal: float = _mesure(n, func(i):
		var q: Vector2i = _point(f, i)
		f.channel_field(q.x, q.y))
	_ligne("chenal (channel_field, appel isole)", chenal, plein)

	# -- Le bruit lui-meme, et c'est lui qui decide la question du C++ ---------
	#
	# `CWValueNoise.sample` est la feuille de tout l'arbre : le champ d'altitude
	# en fait une quinzaine par colonne, et chacune emule de l'arithmetique 32
	# bits que GDScript n'a pas. Si le champ est le poste dominant et que le
	# bruit est l'essentiel du champ, alors une GDExtension a une cible, une
	# seule, et on peut chiffrer ce qu'elle rapporterait. Sinon le C++ est une
	# reecriture sans adresse.
	var bruit: float = _mesure(n, func(i):
		CWValueNoise.sample(float(i) * 0.37, float(i) * 0.71))
	_ligne("un echantillon de bruit (CWValueNoise.sample)", bruit)
	_ligne("  x 15, l'ordre de ce que fait une colonne", bruit * 15.0, plein)
	print("")


# -- 2. Les deux dispersions --------------------------------------------------

func _poste_dispersion(seed_v: int) -> void:
	print("[les deux dispersions — par cellule, puis ramene a la colonne]")
	var f: CWTerrainField = _champ(seed_v)
	var lib := CWModelLibrary.shared()
	var lib_a := CWModelLibrary.shared_trees()
	if not lib.has_any():
		print("  (aucun modele charge — lot d'assets absent, poste non mesure)")
		print("")
		return

	var flore := CWScatter.new(f, lib)
	var arbres := CWTreeScatter.new(f, lib_a)
	var o: Vector2i = f.params().world_origin

	# > ⚠️ **On mesure dans un carre compact, pas le long d'une diagonale.**
	# > Une cellule de dispersion consulte la zone de chemins et la grille
	# > d'elements de son point ; les deux se construisent paresseusement, a
	# > quelques centaines de millisecondes la zone. Une diagonale qui parcourt
	# > cinquante mille blocs en traverse une demi-douzaine et facture ces
	# > constructions aux cellules, ce qui a fait sortir **43 ms** la ou une
	# > cellule en coute une. Le streaming, lui, garnit un voisinage compact :
	# > c'est ce qu'on imite ici, et on chauffe les caches de zone d'abord.
	var cx0: int = CWScatter.cell_of(o.x)
	var cz0: int = CWScatter.cell_of(o.y)
	f.paths().zone_at(o.x, o.y, f)
	f.sample_column_full(o.x, o.y)
	flore.cell(cx0, cz0)
	arbres.cell(o.x >> CWTreeScatter.TREE_CELL_SHIFT,
			o.y >> CWTreeScatter.TREE_CELL_SHIFT)

	# 256 cellules de flore contigues : 16 x 16 cellules de 16 blocs, soit un
	# carre de 256 blocs, bien a l'interieur d'une zone de 16 384.
	var nf: int = 256
	var cf: float = _mesure(nf, func(i):
		@warning_ignore("integer_division")
		var r: int = i / 16
		flore.cell(cx0 + 1 + (i - r * 16), cz0 + 1 + r))
	_ligne("flore : une cellule de 16 x 16 blocs", cf)
	_ligne("  ramene a la colonne", cf / 256.0)

	# 64 cellules d'arbres contigues : 8 x 8 cellules de 64 blocs, soit 512.
	var acx: int = o.x >> CWTreeScatter.TREE_CELL_SHIFT
	var acz: int = o.y >> CWTreeScatter.TREE_CELL_SHIFT
	var na: int = 64
	var ca: float = _mesure(na, func(i):
		@warning_ignore("integer_division")
		var r: int = i / 8
		arbres.cell(acx + 1 + (i - r * 8), acz + 1 + r))
	_ligne("arbres : une cellule de 64 x 64 blocs", ca)
	_ligne("  ramene a la colonne", ca / 4096.0)
	print("  L'assiette — les quatre coins de l'empreinte, sondes par plante —")
	print("  pese 64 %% de la cellule de flore : 722 us sans elle, 2 025 avec.")
	print("  Ce sont les quatre echantillons de champ qui coutent, et non la")
	print("  comptabilite par colonne : les prendre en un seul `sample_patch`")
	print("  a ete essaye le 2026-09-10 et ne change rien (2 035 us).")
	print("")


# -- 3. Le pave, qui est ce que le streaming paie vraiment --------------------

func _poste_pave(seed_v: int) -> void:
	print("[le pave de 16 x 16 — le chemin chaud, celui du streaming]")
	print("  C'est ici que le chiffre compte : `sample_patch` ne consulte le")
	print("  cache de sites qu'une fois par zone traversee, la ou")
	print("  `sample_column` le fait par colonne. Les deux ne se comparent pas.")

	for etiquette in [
			["tout allume", true, true, true],
			["sans les chemins", true, true, false],
			["sans la falaise", true, false, true],
			["sans les elements de tuile", false, true, true],
			["champ nu (les trois eteints)", false, false, false]]:
		var f: CWTerrainField = _champ(seed_v, etiquette[1], etiquette[2],
				etiquette[3])
		var g := CWVoxelGenerator.new()
		g.params = f.params()
		var o: Vector2i = f.params().world_origin
		var buf := VoxelBuffer.new()
		buf.create(PATCH, PATCH, PATCH)
		var sol: int = floori(f.sample_column(o.x, o.y).x)
		var y: int = (sol >> 4) << 4
		# > ⚠️ **Pas de `clear_caches()` entre deux paves, et c'est important.**
		# > Elle vide aussi les caches des deux dispersions, donc chaque pave
		# > repaierait la cellule d'arbres de 64 x 64 que `_stamp_trunks`
		# > consulte — une facture que le streaming, lui, partage entre seize
		# > paves. Elle n'est de toute facon pas necessaire : deux paves a des
		# > x differents ont deux cles de cache differentes, donc aucun ne
		# > profite du travail de l'autre.
		#
		# Chauffe : la zone de chemins et la grille d'elements du point coutent
		# quelques centaines de millisecondes a construire, et elles
		# n'appartiennent a aucun pave. Trente-deux paves suffisent — apres,
		# les caches de zone sont chauds et seule la generation reste.
		for i in 32:
			g._generate_block(buf, Vector3i(i * PATCH, y, 0), 0)
		var n: int = 256
		var t0: int = Time.get_ticks_usec()
		for i in n:
			g._generate_block(buf, Vector3i((32 + i) * PATCH, y, 0), 0)
		var us: float = float(Time.get_ticks_usec() - t0) / float(n)
		print("  %-32s %8.2f ms/pave   %6.2f us/colonne"
				% [etiquette[0], us / 1000.0, us / float(PATCH * PATCH)])
	print("")
	print("Lecture : l'ecart entre deux lignes est ce que coute la couche qui")
	print("les separe. Les ecarts sous 5 %% sont du bruit — relancer deux fois")
	print("avant de conclure quoi que ce soit d'un ecart de cet ordre.")
