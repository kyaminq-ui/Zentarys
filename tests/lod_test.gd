class_name CWLodTest
extends RefCounted

## Verifications de la **pyramide de LOD** : ce que `_generate_block` rend quand
## `VoxelLodTerrain` le demande a un pas superieur a un.
##
## Pilote par tests/worldgen_test.gd, qui tient le compte des verifications.
##
## -- Pourquoi cette suite existe ---------------------------------------------
##
## Le mode LOD a ete declare inutilisable le 2026-09-03 et l'est reste dix
## jours, sur un diagnostic faux : on croyait a une moyenne d'index de palette,
## alors que **le generateur est appele une fois par niveau** et que rien n'est
## jamais moyenne. Les deux vrais defauts etaient dans la discretisation de la
## colonne, et **aucun ne pouvait se voir au pas de un** — c'est-a-dire dans les
## 407 verifications qui existaient alors :
##
##   * un bloc ne couvrait que `(taille - 1) x pas` unites de monde au lieu de
##     `taille x pas`, donc la bande haute perdait son bloc de surface ;
##   * l'eau demarrait a `sol + 1`, donc **dans la cellule du sol** des que la
##     cellule vaut plus d'une unite.
##
## D'ou les deux regles que cette suite verrouille :
##
##   1. **la composition de la surface ne depend pas du niveau** — un monde qui
##      rend de la roche au loin la ou il est de l'herbe de pres est faux, et il
##      l'est en silence ;
##   2. **le sol ne se noie pas** — la cellule qui porte le dessus du terrain
##      existe encore a tous les niveaux. C'est la seule des deux qui attrape la
##      dalle d'eau, parce que celle-ci ne change pas la matiere du sommet de la
##      colonne : elle change **laquelle des deux couches occupe la cellule**.
##
## -- Deux choix de mesure, et ils ont coute leur temps a trouver -------------
##
## ⚠️ **L'emprise porte de l'eau, et ce n'est pas un detail.** Les 512 blocs
## autour du point de depart n'ont ni mer ni mare : une suite posee la passait au
## vert avec le defaut remis en place. `ORIGIN` vise donc un endroit choisi pour
## ce qu'il contient — 41 % de mer, 17 % de mares, le reste en terre.
##
## ⚠️ **Les couches d'arbres et de filons sont coupees.** Elles s'arretent
## respectivement a `TREE_MAX_LOD` et `ORE_MAX_LOD` par decision, donc sans cela
## chaque mesure dirait « le sol a disparu » la ou seul un houppier — ou un
## affleurement de filon, depuis le jalon 2.6 — manque. Et les filtrer par la
## matiere ne marche pas : un `rocher_geant` est de la roche, comme le sous-sol,
## et il monte de vingt blocs au-dessus du terrain ; un filon de meme.
##
## ⚠️ Comme partout dans ce depot, ceci verifie de la geometrie, jamais du
## rendu. La capture reste le juge : c'est elle qui a montre les dalles.

## Coin de l'emprise balayee, en blocs, depuis l'origine de scene.
const ORIGIN: Vector2i = Vector2i(20480, 0)

## Cote de l'emprise, en blocs de monde. Il en faut assez pour porter plusieurs
## blocs de LOD 5 — un seul en couvre 512 — sans quoi le niveau le plus grossier
## n'est represente que par une poignee de colonnes.
const SPAN: int = 512

## Etendue verticale balayee. Le relief du monde tient dedans avec de la marge
## des deux cotes : `_write_previews` mesure [-100, 377] sur l'apercu.
const Y_LO: int = -320
const Y_HI: int = 704

const BS: int = 16

## Marqueur de colonne sans matiere, dans le releve des sols.
const AUCUN: int = Y_LO - 1

var _runner: Object


func run(runner: Object) -> void:
	_runner = runner
	print("[lod]")
	_test_cellule_au_dessus()
	_test_lit_de_mare()
	_test_pyramide()


func _ok(label: String, condition: bool, detail: String = "") -> void:
	_runner._ok(label, condition, detail)


## `_cell_above` est le point unique qui dit « juste au-dessus du sol » aux trois
## couches qui se posent dessus. Au pas de un il doit rendre `w + 1` **exactement
## et pour tout w**, negatifs compris : c'est ce qui garantit que le LOD 0 —
## c'est-a-dire tout le jeu, l'edition, les collisions et les deux dispersions —
## ne bouge pas d'un voxel.
func _test_cellule_au_dessus() -> void:
	var exact: bool = true
	for w in range(-600, 601):
		if CWVoxelGenerator._cell_above(w, 1) != w + 1:
			exact = false
			break
	_ok("au pas de un, la cellule au-dessus est l'unite suivante", exact)

	# La division doit s'arrondir **vers le bas**. La troncature de GDScript
	# rabat vers zero, donc elle rendrait une cellule trop haut sous le niveau
	# zero — et le niveau de la mer est a -60.
	_ok("l'arrondi descend sous zero",
			CWVoxelGenerator._cell_above(-1, 16) == 0
			and CWVoxelGenerator._cell_above(-16, 16) == 0
			and CWVoxelGenerator._cell_above(-17, 16) == -16
			and CWVoxelGenerator._cell_above(15, 16) == 16
			and CWVoxelGenerator._cell_above(16, 16) == 32,
			"%d %d %d %d %d" % [
				CWVoxelGenerator._cell_above(-1, 16),
				CWVoxelGenerator._cell_above(-16, 16),
				CWVoxelGenerator._cell_above(-17, 16),
				CWVoxelGenerator._cell_above(15, 16),
				CWVoxelGenerator._cell_above(16, 16)])

	# Elle ne doit pas dependre du plancher du bloc : c'est ce qui permet a la
	# passe de colonnes et au remplissage de tomber sur le meme nombre, comme
	# l'invariant n. 44 le demande pour le pochoir de la pente.
	var stable: bool = true
	for stride in [2, 4, 8, 16, 32]:
		for w in [-97, -60, -1, 0, 17, 178]:
			var attendu: int = CWVoxelGenerator._cell_above(w, stride)
			for m in [-4, -1, 0, 1, 3]:
				var y_min: int = m * BS * stride
				@warning_ignore("integer_division")
				var k: int = (w - y_min) / stride
				if w - y_min < 0 and k * stride != w - y_min:
					k -= 1
				if y_min + (k + 1) * stride != attendu:
					stable = false
	_ok("elle ne depend pas du plancher du bloc", stable)


## Le lit d'une mare ne se decouvre que sous l'eau qui sera reellement dessinee.
## Au pas de un, le test doit etre **mot pour mot** celui d'avant le 2026-09-13
## — `prof.y <= prof.z` —, sans quoi le fond des mares change dans tout le jeu.
func _test_lit_de_mare() -> void:
	var terre: int = CWPalette.subsurface_index(CWPalette.GRASS)
	var identique: bool = true
	for x in range(-40, 41):
		for d in range(0, 6):
			# `column_profile` rend toujours `prof.y == prof.x + 1`.
			var prof := Vector3i(x, x + 1, x + d)
			var attendu: int = terre if prof.y <= prof.z else CWPalette.GRASS
			if CWVoxelGenerator.pond_surface(CWPalette.GRASS, prof, true) != attendu:
				identique = false
	_ok("au pas de un, le lit de mare est celui d'avant le LOD", identique)

	# Au pas de seize, une mare de quatre blocs de fond est plus mince qu'une
	# cellule : elle n'est pas dessinee, donc son lit ne doit pas se decouvrir.
	# Sans cette regle, chaque mare laisse une tache de terre en pleine prairie.
	_ok("au pas de seize, une mare de quatre blocs ne decouvre pas son lit",
			CWVoxelGenerator.pond_surface(CWPalette.GRASS,
					Vector3i(100, 101, 104), true, 16) == CWPalette.GRASS)
	_ok("une mare plus epaisse qu'une cellule le decouvre encore",
			CWVoxelGenerator.pond_surface(CWPalette.GRASS,
					Vector3i(100, 101, 130), true, 16) == terre)


## Les deux regles de la pyramide, mesurees en une seule descente par niveau.
func _test_pyramide() -> void:
	var p := CWWorldParams.new()
	p.trees = false
	# Meme raison que les arbres (voir l'en-tete) : un filon affleure jusqu'a
	# quatre blocs au-dessus du sol (jalon 2.6), et il ne survit pas au LOD
	# (`CWVoxelGenerator.ORE_MAX_LOD`, zero) — sans cette coupure, un
	# affleurement qui disparait ferait dire « le sol a disparu » exactement
	# comme un houppier coupe.
	p.ores = false
	var gen := CWVoxelGenerator.new()
	gen.params = p

	var ref: Dictionary = _releve(gen, 0)
	var parts_ref: Dictionary = _parts(ref["top"])
	var sol_ref: PackedInt32Array = ref["sol"]

	for lod in [1, 2, 3, 4, 5]:
		var stride: int = 1 << lod
		var got: Dictionary = _releve(gen, lod)
		var parts: Dictionary = _parts(got["top"])

		# -- 1. La composition ------------------------------------------------
		# La roche nue est le temoin du defaut de couverture : elle bondissait a
		# 72 % au LOD 4 quand la bande haute d'un bloc perdait sa surface.
		var roche: float = float(parts.get(CWPalette.STONE, 0.0))
		var roche_ref: float = float(parts_ref.get(CWPalette.STONE, 0.0))
		_ok("LOD %d : la roche nue ne prolifere pas (%.1f %% contre %.1f %%)"
				% [lod, roche * 100.0, roche_ref * 100.0],
				roche <= roche_ref + 0.02)

		# La terre est la seule matiere du monde qui ne soit celle d'aucun biome
		# depuis le 2026-09-12 : elle ne nomme plus que le **lit d'une mare**,
		# donc elle ne peut pas etre en surface la ou l'eau ne l'est pas.
		var terre: float = float(parts.get(CWPalette.DIRT, 0.0))
		var terre_ref: float = float(parts_ref.get(CWPalette.DIRT, 0.0))
		_ok("LOD %d : la terre du lit ne remonte pas en surface (%.1f %% contre %.1f %%)"
				% [lod, terre * 100.0, terre_ref * 100.0],
				terre <= terre_ref + 0.005)

		# La mer est un plan, et un plan reste un plan : sa part ne peut pas
		# fondre avec la distance. Elle a le droit de reculer d'une demi-cellule
		# sur le rivage — la cellule qui porte un fond de mer deborde vers le
		# haut, et la ou elle passe au-dessus de la surface, l'eau cede.
		#
		# ⚠️ **Ce garde-fou est un ordre de grandeur, pas une mesure.** Au LOD 5
		# l'emprise ne porte plus que 256 colonnes contre 262 144 au LOD 0 :
		# l'erreur d'echantillonnage seule vaut une dizaine de points. Il est ici
		# parce qu'il a **deja servi** — c'est lui qui a montre qu'interdire a la
		# mer la cellule du sol, comme a l'etang, faisait reculer le rivage
		# partout (54,6 % d'eau au LOD 0 contre 35,2 % au LOD 5). Une regle
		# uniforme aurait paru propre et aurait vide la mer.
		var eau: float = float(parts.get(CWPalette.WATER, 0.0)) \
				+ float(parts.get(CWPalette.WATER_DEEP, 0.0))
		var eau_ref: float = float(parts_ref.get(CWPalette.WATER, 0.0)) \
				+ float(parts_ref.get(CWPalette.WATER_DEEP, 0.0))
		_ok("LOD %d : la mer ne s'evapore pas (%.1f %% contre %.1f %%)"
				% [lod, eau * 100.0, eau_ref * 100.0],
				eau >= eau_ref - 0.15)

		# -- 2. Le sol ne se noie pas -----------------------------------------
		# C'est la regle qui attrape la dalle. `sol` est le plancher de la
		# cellule de terrain la plus haute ; elle couvre `stride` unites, donc
		# elle porte encore le sol de reference des que son sommet l'atteint.
		#
		# **Seules les colonnes emergees sont jugees.** Ce qui est deja sous la
		# mer n'a pas de silhouette a preserver : la cellule d'un fond marin
		# peut descendre d'un cran sans que rien ne se voie, et la mer a le droit
		# de l'occuper — c'est meme elle qui cache le debordement de la cellule
		# du sol au-dessus de la surface. L'enonce exact est donc : *ce qui
		# emerge doit rester emerge*.
		var noyees: int = 0
		var vues: int = 0
		var sol: PackedInt32Array = got["sol"]
		var z: int = 0
		while z < SPAN:
			var x: int = 0
			while x < SPAN:
				var k: int = z * SPAN + x
				if sol_ref[k] != AUCUN and sol_ref[k] > p.sea_level:
					vues += 1
					if sol[k] + stride - 1 < sol_ref[k]:
						noyees += 1
				x += stride
			z += stride
		_ok("LOD %d : aucune colonne ne perd son sol sous l'eau (%d sur %d)"
				% [lod, noyees, vues], noyees == 0)

	gen.request_shutdown()


## Part de chaque matiere parmi les sommets de colonne.
func _parts(top: PackedInt32Array) -> Dictionary:
	var counts := {}
	var total: int = 0
	for v in top:
		if v == CWPalette.AIR:
			continue
		counts[v] = int(counts.get(v, 0)) + 1
		total += 1
	var out := {}
	if total == 0:
		return out
	for k in counts:
		out[k] = float(counts[k]) / float(total)
	return out


## Une descente par niveau, deux mesures a la fois :
##
##   * `top` — la matiere du plus haut voxel plein de chaque colonne, c'est-a-dire
##     ce que le monde **montre** ;
##   * `sol` — le plancher de la cellule de **terrain** (l'eau exclue) la plus
##     haute, c'est-a-dire ce que le monde **porte**.
##
## Les deux sont rangees sur la grille du monde et non sur celle du niveau, ce
## qui permet de les comparer d'un niveau a l'autre sans conversion.
func _releve(gen: CWVoxelGenerator, lod: int) -> Dictionary:
	var stride: int = 1 << lod
	var side: int = BS * stride
	var top := PackedInt32Array()
	top.resize(SPAN * SPAN)
	top.fill(CWPalette.AIR)
	var sol := PackedInt32Array()
	sol.resize(SPAN * SPAN)
	sol.fill(AUCUN)

	var bz: int = 0
	while bz * side < SPAN:
		var bx: int = 0
		while bx * side < SPAN:
			_releve_pile(gen, lod, bx * side, bz * side, top, sol)
			bx += 1
		bz += 1
	return {"top": top, "sol": sol}


## Une pile verticale de blocs, **du ciel vers la roche**.
##
## Le sens compte : on saute les blocs uniformement vides, et on s'arrete des que
## toutes les colonnes du bloc ont trouve leur sol. Sans ces deux economies, le
## balayage lit les 4 096 voxels de chaque bloc de chaque pile et la suite passe
## de vingt-cinq secondes a plusieurs minutes — pour la meme mesure, la
## quasi-totalite d'une colonne du monde etant du vide au-dessus et de la roche
## en dessous.
func _releve_pile(gen: CWVoxelGenerator, lod: int, ox: int, oz: int,
		top: PackedInt32Array, sol: PackedInt32Array) -> void:
	var stride: int = 1 << lod
	var side: int = BS * stride
	var restants: int = 0
	for lz in BS:
		if oz + lz * stride >= SPAN:
			break
		for lx in BS:
			if ox + lx * stride >= SPAN:
				break
			restants += 1
	if restants == 0:
		return

	@warning_ignore("integer_division")
	var haut: int = Y_LO + ((Y_HI - Y_LO - 1) / side) * side
	var y: int = haut
	while y >= Y_LO and restants > 0:
		var buf := VoxelBuffer.new()
		buf.create(BS, BS, BS)
		gen._generate_block(buf, Vector3i(ORIGIN.x + ox, y, ORIGIN.y + oz), lod)
		if buf.is_uniform(CWPalette.CHANNEL_TYPE) \
				and buf.get_voxel(0, 0, 0, CWPalette.CHANNEL_TYPE) == CWPalette.AIR:
			y -= side
			continue
		for lz in BS:
			var wz: int = oz + lz * stride
			if wz >= SPAN:
				break
			for lx in BS:
				var wx: int = ox + lx * stride
				if wx >= SPAN:
					break
				var k: int = wz * SPAN + wx
				if sol[k] != AUCUN:
					continue
				var ly: int = BS - 1
				while ly >= 0:
					var v: int = buf.get_voxel(lx, ly, lz, CWPalette.CHANNEL_TYPE)
					if v != CWPalette.AIR:
						if top[k] == CWPalette.AIR:
							top[k] = v
						if v != CWPalette.WATER and v != CWPalette.WATER_DEEP:
							sol[k] = y + ly * stride
							restants -= 1
							break
					ly -= 1
		y -= side
