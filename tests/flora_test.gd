class_name CWFloraTest
extends RefCounted

## Verifications de la couche de flore (jalon 1.7) : chargement des modeles,
## dispersion, maillage et pose des instances.
##
## Pilote par tests/worldgen_test.gd, qui tient le compte des verifications :
##   CWFloraTest.new().run(self)
##
## La suite tourne meme si aucun modele n'est encore produit : les
## verifications qui en dependent sont alors annoncees comme sautees plutot que
## reussies. Une suite qui passe au vert parce qu'elle n'a rien teste est pire
## qu'une suite rouge.

## Canal semantique : depuis le passage du rendu en `COLOR_RAW`, c'est
## `CHANNEL_TYPE` qui porte l'index de palette. `CHANNEL_COLOR` porte la
## couleur, et comparer un index avec une couleur passerait inapercu.
const CHANNEL: int = CWPalette.CHANNEL_TYPE

var _runner: Object


func run(runner: Object) -> void:
	_runner = runner
	_test_models()
	_test_scatter()
	_test_rendering()


func _ok(label: String, condition: bool, detail: String = "") -> void:
	_runner._ok(label, condition, detail)


func _skip(label: String, why: String) -> void:
	print("  [saute] %s  (%s)" % [label, why])


# -- 1. Modeles ---------------------------------------------------------------

func _test_models() -> void:
	print("[modeles voxels]")
	var lib := CWModelLibrary.shared()
	var names: PackedStringArray = lib.loaded_names()
	print("     %d modele(s) : %s" % [names.size(), ", ".join(names)])

	# La table de repartition ne doit viser que des biomes que le generateur
	# sait produire : une entree pour un index de surface inexistant ne leve
	# rien, elle ne sert simplement jamais.
	var bad_surface: Array = []
	for surface in CWModelLibrary.FLORA:
		if CWPalette.name_of(surface) == "?":
			bad_surface.append(surface)
	_ok("la table de repartition ne vise que des surfaces reelles",
			bad_surface.is_empty(), str(bad_surface))
	var no_density: Array = []
	for surface in CWModelLibrary.FLORA:
		if CWModelLibrary.density_of(surface) <= 0.0:
			no_density.append(CWPalette.name_of(surface))
	_ok("chaque biome garni a une densite", no_density.is_empty(), str(no_density))

	# Le lot des 28 modeles de flore est clos depuis le 2026-09-05. Un modele
	# absent du disque reste ignore en silence a l'execution — c'est voulu, un
	# monde a moitie fleuri vaut mieux qu'un monde qui ne demarre pas — mais ici
	# c'est une faute : une faute de frappe dans un chemin fait disparaitre une
	# plante d'un biome sans que rien ne le dise.
	var missing: Array = []
	var entries: int = 0
	for surface in CWModelLibrary.FLORA:
		for entry in CWModelLibrary.FLORA[surface]:
			entries += 1
			var path: String = CWModelLibrary.FLORA_DIR + entry + ".vox"
			if not FileAccess.file_exists(path) and not missing.has(entry):
				missing.append(entry)
	_ok("tous les modeles de la table sont sur le disque (%d entrees)" % entries,
			missing.is_empty(), str(missing))

	var grass: Array = lib.for_surface(CWPalette.GRASS)
	if grass.is_empty():
		_skip("chargement d'un modele", "aucun modele pour l'herbe")
		return
	var m: CWVoxelModel = grass[0]

	_ok("modele non vide", m.voxel_count > 0, str(m))
	_ok("gabarit coherent avec les offsets",
			m.height == m.extent.y and m.radius > 0, str(m))

	# Echelle. Le rapport est un contrat d'authoring : le changer redimensionne
	# tous les modeles deja dessines, donc il est verrouille ici et pas seulement
	# ecrit dans MODELS.md.
	#
	# 40/3 est la valeur de l'original : ses echelles d'instanciation du decor
	# sont 0.075, 0.09 et 0.1, et 0.075 = 3/40 exactement. La comparaison porte
	# donc sur la fraction, pas sur 13.333 qui derive.
	_ok("un bloc de terrain vaut 40/3 voxels de modele",
			is_equal_approx(CWVoxelModel.VOXELS_PER_BLOCK, 40.0 / 3.0),
			"%f" % CWVoxelModel.VOXELS_PER_BLOCK)
	# Trois blocs valent quarante voxels, exactement : c'est la reference posee
	# dans MagicaVoxel, puisqu'un cube d'un bloc n'est pas entier.
	_ok("trois blocs valent quarante voxels",
			is_equal_approx(3.0 * CWVoxelModel.VOXELS_PER_BLOCK, 40.0),
			"%f" % (3.0 * CWVoxelModel.VOXELS_PER_BLOCK))
	_ok("mesures en blocs coherentes avec les mesures en voxels",
			m.height_blocks == ceili(float(m.height) / (40.0 / 3.0))
			and m.radius_blocks == ceili(float(m.radius) / (40.0 / 3.0)),
			"%d voxels -> %d blocs" % [m.height, m.height_blocks])

	# Enveloppe de la flore : le personnage de reference fait 2 blocs, une
	# plante ne le depasse pas de plus du double. Un modele dessine a l'ancienne
	# regle (1 voxel = 1 bloc) sortirait ici a huit fois sa taille.
	var oversize: Array = []
	for k in _distinct_models(lib):
		if k.height > 4 * CWVoxelModel.VOXELS_PER_BLOCK \
				or k.radius > 2 * CWVoxelModel.VOXELS_PER_BLOCK:
			oversize.append(str(k))
	_ok("aucun modele de flore hors de l'enveloppe (4 blocs de haut, 2 de rayon)",
			oversize.is_empty(), str(oversize))

	# Maillage : c'est par la que le modele arrive a l'ecran, puisqu'il n'est
	# plus ecrit dans les donnees du monde.
	var mesh: ArrayMesh = m.mesh()
	_ok("le modele se maille", mesh != null and mesh.get_surface_count() > 0,
			str(mesh))
	if mesh != null:
		# Le maillage sort en coordonnees de tampon ; ramene sur l'ancre par
		# `mesh_offset`, il doit poser a zero et monter a sa hauteur.
		var box: AABB = mesh.get_aabb()
		box.position += m.mesh_offset()
		_ok("le maillage pose sur l'ancre", absf(box.position.y) < 0.001,
				"base a %.3f voxel" % box.position.y)
		_ok("le maillage a la hauteur de la matiere",
				absf(box.size.y - float(m.height)) < 0.001,
				"%.2f voxels pour %d" % [box.size.y, m.height])

	# Plage de palette : un index hors plage ne leve rien, il ressortira avec la
	# couleur d'un autre lot le jour ou la palette bougera.
	var strays: Array = []
	for i in m.values(0):
		var in_flora: bool = i >= CWPalette.RANGE_FLORA_BEGIN \
				and i <= CWPalette.RANGE_FLORA_END
		var in_terrain: bool = i >= CWPalette.RANGE_TERRAIN_BEGIN \
				and i <= CWPalette.RANGE_TERRAIN_END
		if not (in_flora or in_terrain) and not strays.has(i):
			strays.append(i)
	_ok("indices dans les plages vegetation ou terrain", strays.is_empty(), str(strays))

	# Translucidite : `VoxelMesherCubes` range les voxels d'une entree a alpha < 1
	# dans une seconde surface, que `CWVoxelModel.mesh()` habille du materiau
	# opaque. Un modele qui en porte un sort donc opaque la ou l'auteur voulait du
	# translucide — ou l'inverse le jour ou le materiau changera.
	var colors: PackedColorArray = CWPalette.colors()
	var translucent: Array = []
	for k in _distinct_models(lib):
		for i in k.values(0):
			if colors[i].a < 1.0 and not translucent.has(i):
				translucent.append(i)
	_ok("aucun modele ne porte un index translucide", translucent.is_empty(),
			str(translucent))

	# Ancre : la base du modele est a l'offset 0 en Y, sinon une plante posee sur
	# le sol flotte ou s'enterre.
	var min_y: int = 0x7FFFFFFF
	for v in m.offsets_y(0):
		min_y = mini(min_y, v)
	_ok("ancre a la base du modele", min_y == 0, "premier offset Y %d" % min_y)

	# Quarts de tour : meme matiere, orientations distinctes.
	var same_count: bool = true
	var distinct: bool = false
	for r in range(1, CWVoxelModel.ROTATIONS):
		same_count = same_count and m.values(r).size() == m.voxel_count
		if m.offsets_x(r) != m.offsets_x(0) or m.offsets_z(r) != m.offsets_z(0):
			distinct = true
	_ok("les quatre rotations gardent la meme matiere", same_count)
	_ok("les rotations sont distinctes", distinct)

	# Un tour complet doit ramener le modele sur lui-meme.
	var rx: PackedInt32Array = m.offsets_x(0)
	var rz: PackedInt32Array = m.offsets_z(0)
	var back_x := PackedInt32Array()
	var back_z := PackedInt32Array()
	for i in m.voxel_count:
		var q := Vector2i(rx[i], rz[i])
		for _t in 4:
			q = CWVoxelModel._turn(q.x, q.y, 1)
		back_x.append(q.x)
		back_z.append(q.y)
	_ok("quatre quarts de tour ramenent a l'identite",
			back_x == rx and back_z == rz)

	# Reduction : elle sert a montrer une echelle cible, pas a decorer.
	var half: CWVoxelModel = m.reduced(2)
	_ok("reduction : silhouette plus petite mais non vide",
			half.voxel_count > 0 and half.height <= m.height,
			"%s -> %s" % [m, half])
	var half_min_y: int = 0x7FFFFFFF
	for v in half.offsets_y(0):
		half_min_y = mini(half_min_y, v)
	_ok("reduction : la base reste au sol", half_min_y == 0,
			"premier offset Y %d" % half_min_y)
	_ok("reduction d'un facteur 1 : le modele lui-meme", m.reduced(1) == m)


# -- 2. Dispersion ------------------------------------------------------------

func _test_scatter() -> void:
	print("[dispersion de la flore]")
	var p := CWWorldParams.new()
	p.world_seed = 2024
	var f := CWTerrainField.new(p)
	var sc := CWScatter.new(f)
	if not sc.library().has_any():
		_skip("dispersion", "aucun modele charge")
		return

	var cx0: int = CWScatter.cell_of(p.world_origin.x)
	var cz0: int = CWScatter.cell_of(p.world_origin.y)

	# Placement : chaque plante dans sa cellule, posee sur le sol de sa colonne,
	# et dans un biome qui l'accepte.
	var total: int = 0
	var out_of_cell: int = 0
	var off_ground: int = 0
	var wrong_surface: int = 0
	for dz in 24:
		for dx in 24:
			var cx: int = cx0 + dx
			var cz: int = cz0 + dz
			for pl in sc.cell(cx, cz):
				total += 1
				if CWScatter.cell_of(pl.x) != cx or CWScatter.cell_of(pl.z) != cz:
					out_of_cell += 1
				var c: Vector3 = f.sample_column(pl.x, pl.z)
				if pl.y != floori(c.x) + 1:
					off_ground += 1
				var surface: int = CWPalette.surface_index(c.x, c.y, c.z, p.sea_level)
				if not sc.library().for_surface(surface).has(pl.model):
					wrong_surface += 1
	print("     %d plantes sur 576 cellules (%.1f par cellule)"
			% [total, float(total) / 576.0])
	_ok("des plantes sont posees", total > 0)
	_ok("chaque plante est dans sa cellule", out_of_cell == 0, "%d hors" % out_of_cell)
	_ok("chaque plante pose sur le sol de sa colonne", off_ground == 0,
			"%d flottantes" % off_ground)
	_ok("chaque plante appartient a son biome", wrong_surface == 0,
			"%d mal affectees" % wrong_surface)

	# Determinisme : deux instances, meme graine, meme resultat.
	var sc_b := CWScatter.new(CWTerrainField.new(p))
	var identical: bool = true
	for dz in 8:
		for dx in 8:
			var a: Array = sc.cell(cx0 + dx, cz0 + dz)
			var b: Array = sc_b.cell(cx0 + dx, cz0 + dz)
			if a.size() != b.size():
				identical = false
				continue
			for i in a.size():
				if a[i].x != b[i].x or a[i].z != b[i].z or a[i].y != b[i].y \
						or a[i].rotation != b[i].rotation \
						or not is_equal_approx(a[i].scale, b[i].scale) \
						or a[i].model.name != b[i].model.name:
					identical = false
	_ok("deterministe entre deux instances", identical)

	# La graine change la dispersion, sinon toutes les parties se ressemblent.
	var p2 := CWWorldParams.new()
	p2.world_seed = 991
	var sc_c := CWScatter.new(CWTerrainField.new(p2))
	var differs: int = 0
	for dx in 32:
		var a: Array = sc.cell(cx0 + dx, cz0)
		var b: Array = sc_c.cell(cx0 + dx, cz0)
		if a.size() != b.size() or (a.size() > 0 and a[0].x != b[0].x):
			differs += 1
	_ok("la graine change la dispersion", differs > 8, "%d/32 cellules" % differs)

	# `placements_in` doit rendre exactement les plantes qui mordent dans
	# l'empreinte : en oublier une fait apparaitre une demi-plante a la frontiere
	# de deux blocs, ce qu'aucun test epars ne verrait.
	var wx: int = p.world_origin.x
	var wz: int = p.world_origin.y
	var got: Array = sc.placements_in(wx, wz, 16, 16)
	var want: Array = []
	# Rayons en blocs : l'empreinte est une requete de terrain, pas de modele.
	# Le rayon est celui de l'*instance*, gigue comprise : une marge calculee
	# sur le modele nu laisserait passer les grandes touffes de la frontiere.
	var margin: int = ceili(float(sc.library().max_radius_blocks) * CWScatter.SCALE_MAX) \
			+ CWScatter.CELL_SIZE
	for cz in range(CWScatter.cell_of(wz - margin), CWScatter.cell_of(wz + 16 + margin) + 1):
		for cx in range(CWScatter.cell_of(wx - margin), CWScatter.cell_of(wx + 16 + margin) + 1):
			for pl in sc.cell(cx, cz):
				var r: int = pl.radius_blocks()
				if pl.x + r < wx or pl.x - r >= wx + 16:
					continue
				if pl.z + r < wz or pl.z - r >= wz + 16:
					continue
				want.append(pl)
	_ok("placements_in rend toutes les plantes du cadre, et rien d'autre",
			got.size() == want.size(),
			"%d rendues, %d attendues" % [got.size(), want.size()])

	# Reproductibilite depuis plusieurs fils : la grille est consultee sans ordre
	# garanti, et deux fils peuvent construire la meme cellule au meme instant.
	var reference: Array = []
	for dx in 16:
		reference.append(sc.cell(cx0 + 100 + dx, cz0 + 100).size())
	var fresh := CWScatter.new(CWTerrainField.new(p))
	var results: Array = []
	results.resize(8)
	var tasks: Array = []
	for t in 8:
		var slot: int = t
		tasks.append(WorkerThreadPool.add_task(
				func() -> void:
					var counts: Array = []
					for dx in 16:
						counts.append(fresh.cell(cx0 + 100 + dx, cz0 + 100).size())
					results[slot] = counts))
	for t in 8:
		WorkerThreadPool.wait_for_task_completion(tasks[t])
	var concurrent_ok: bool = true
	for t in 8:
		if results[t] != reference:
			concurrent_ok = false
	_ok("meme dispersion depuis huit fils concurrents", concurrent_ok)

	_test_two_frequencies(sc, cx0, cz0)


## Les deux frequences de bruit, portees le 2026-09-05 de `docs/systems/02` §8.4.
##
## Ces verifications sont statistiques par nature : le fait teste n'est pas la
## valeur d'une plante, c'est la *forme de la distribution*. Un test qui
## regarderait plante par plante ne verrait aucune des deux regressions qui
## comptent ici — une crete desactivee rendrait un semis parfaitement legal,
## simplement mort a l'oeil.
func _test_two_frequencies(sc: CWScatter, cx0: int, cz0: int) -> void:
	print("[dispersion : les deux frequences]")

	# -- La part passante de la crete ----------------------------------------
	# `PLACEMENT_PASS_RATE` divise le budget de candidats : elle est ce qui
	# conserve la densite moyenne des biomes. Si `CWValueNoise` ou les
	# constantes de la crete bougent, la densite de tout le monde derive sans
	# que rien ne le signale — d'ou cette mesure directe.
	var passed: int = 0
	var probed: int = 0
	for dz in 200:
		for dx in 200:
			var wx: float = float(cx0 << CWScatter.CELL_SHIFT) + float(dx)
			var wz: float = float(cz0 << CWScatter.CELL_SHIFT) + float(dz)
			probed += 1
			var ridge: float = absf(CWValueNoise.sample(
					wx * CWScatter.PLACEMENT_FREQ + CWScatter.PLACEMENT_OFFSET_X,
					wz * CWScatter.PLACEMENT_FREQ + CWScatter.PLACEMENT_OFFSET_Z))
			if ridge > CWScatter.PLACEMENT_RIDGE:
				passed += 1
	var rate: float = float(passed) / float(probed)
	print("     crete de placement : %.1f %% de la surface passe (constante %.1f %%)"
			% [rate * 100.0, CWScatter.PLACEMENT_PASS_RATE * 100.0])
	_ok("la part passante de la crete vaut la constante qui compense le budget",
			absf(rate - CWScatter.PLACEMENT_PASS_RATE) < 0.02,
			"mesure %.4f, constante %.4f" % [rate, CWScatter.PLACEMENT_PASS_RATE])

	# -- Des plaques, et des vides -------------------------------------------
	# C'est le point de tout l'exercice. Un tirage uniforme par cellule donne un
	# nombre de plantes par cellule proche de Poisson, donc une variance egale a
	# la moyenne. La crete a 0,05 a une longueur d'onde de ~20 blocs, soit plus
	# qu'une cellule de 16 : des cellules entieres sont dans une plaque ou dans
	# un vide, et la variance monte tres au-dessus de la moyenne. On mesure ce
	# rapport plutot que la variance seule, qui depend du biome tire.
	var counts: Array[int] = []
	var empty: int = 0
	for dz in 24:
		for dx in 24:
			var n: int = sc.cell(cx0 + dx, cz0 + dz).size()
			counts.append(n)
			if n == 0:
				empty += 1
	var mean: float = 0.0
	for n in counts:
		mean += float(n)
	mean /= float(counts.size())
	var variance: float = 0.0
	for n in counts:
		variance += (float(n) - mean) * (float(n) - mean)
	variance /= float(counts.size())
	var dispersion: float = variance / maxf(mean, 0.001)
	print("     %d cellules : %.1f plantes en moyenne, variance %.1f (rapport %.1f), %d vides"
			% [counts.size(), mean, variance, dispersion, empty])
	_ok("la flore vient par plaques, pas en saupoudrage regulier",
			dispersion > 2.0,
			"variance/moyenne = %.2f (un tirage uniforme donnerait ~1)" % dispersion)

	# -- La densite moyenne est conservee ------------------------------------
	# La compensation du budget doit rendre `DENSITY` lisible comme avant : la
	# crete change la variance, pas la moyenne. Sans cette verification, diviser
	# par la part passante pourrait etre oublie et la flore se ferait rare de
	# deux tiers sans qu'aucun test ne bouge.
	print("     densite moyenne %.1f plante(s) par cellule" % mean)
	_ok("la crete change la variance, pas la densite moyenne",
			mean > 3.0 and mean < 20.0, "%.1f par cellule" % mean)

	# -- La gigue d'echelle ---------------------------------------------------
	var out_of_range: int = 0
	var seen: int = 0
	var lo: float = 99.0
	var hi: float = 0.0
	for dz in 24:
		for dx in 24:
			for pl in sc.cell(cx0 + dx, cz0 + dz):
				seen += 1
				var under: bool = pl.scale < CWScatter.SCALE_MIN - 0.001
				var over: bool = pl.scale > CWScatter.SCALE_MAX + 0.001
				if under or over:
					out_of_range += 1
				lo = minf(lo, pl.scale)
				hi = maxf(hi, pl.scale)
	if seen == 0:
		_skip("gigue d'echelle", "aucune plante autour du point de depart")
		return
	print("     gigue d'echelle sur %d instances : %.3f a %.3f" % [seen, lo, hi])
	_ok("la gigue d'echelle reste dans [1, 2]", out_of_range == 0,
			"%d hors bornes" % out_of_range)
	# Deux touffes du meme modele a la meme taille, c'est le motif repete que la
	# gigue existe pour casser : on verifie qu'elle couvre reellement sa plage.
	_ok("la gigue couvre sa plage, elle n'est pas figee",
			hi - lo > 0.8, "etendue %.3f" % (hi - lo))

	# -- La frequence de selection --------------------------------------------
	# 0,01 decide *laquelle* : deux regions distantes de plusieurs centaines de
	# blocs ne doivent pas tirer la meme composition. Le test compare la moitie
	# de liste designee par le signe du bruit — un indice sur deux — ce qui est
	# la decision portee ; comparer des noms melangerait la selection et le biome.
	var halves: Dictionary = {}
	for step in 40:
		var wx: int = (cx0 << CWScatter.CELL_SHIFT) + step * 137
		var region: float = CWValueNoise.sample(
				float(wx) * CWScatter.SELECTION_FREQ + CWScatter.SELECTION_OFFSET_X,
				float(cz0 << CWScatter.CELL_SHIFT) * CWScatter.SELECTION_FREQ
						+ CWScatter.SELECTION_OFFSET_Z)
		halves[region < 0.0] = true
	_ok("la frequence de selection designe les deux moities selon la region",
			halves.size() == 2, str(halves.keys()))
	# Et elle doit etre stable *dans* une region : une selection qui rebondirait
	# d'une colonne a l'autre serait un second tirage uniforme, pas une composition.
	var flips: int = 0
	var prev: int = CWScatter._choose(4, cx0 << CWScatter.CELL_SHIFT,
			cz0 << CWScatter.CELL_SHIFT, 0.1) % 2
	for step in range(1, 60):
		var here: int = CWScatter._choose(4,
				(cx0 << CWScatter.CELL_SHIFT) + step, cz0 << CWScatter.CELL_SHIFT, 0.1) % 2
		if here != prev:
			flips += 1
		prev = here
	_ok("la composition est stable sur une region, pas d'une colonne a l'autre",
			flips <= 2, "%d basculements sur 60 blocs" % flips)




# -- 3. Maillage et pose des instances ----------------------------------------

func _test_rendering() -> void:
	print("[rendu de la flore]")
	var p := CWWorldParams.new()
	p.world_seed = 2024
	var g := CWVoxelGenerator.new()
	g.params = p
	var sc: CWScatter = g.scatter_grid()
	if not sc.library().has_any():
		_skip("rendu", "aucun modele charge")
		return

	# La flore a quitte les donnees du monde : un bloc de surface ne doit plus
	# contenir un seul index de vegetation. Sans cette verification, un reste
	# d'estampage passerait inapercu — il ferait juste doublon avec l'instance.
	var ground: int = roundi(g.field().sample_column(p.world_origin.x, p.world_origin.y).x)
	@warning_ignore("integer_division")
	var oy: int = (ground / 16) * 16
	var buf := VoxelBuffer.new()
	buf.create(16, 16, 16)
	g._generate_block(buf, Vector3i(0, oy, 0), 0)
	_ok("le terrain ne contient plus de flore", _flora_voxels(buf) == 0,
			"%d voxels de vegetation dans le bloc de surface" % _flora_voxels(buf))

	# Une plante a poser, prise sur le terrain reellement genere.
	var sample: CWScatter.Placement = null
	for dz in 8:
		for dx in 8:
			for pl in sc.cell(CWScatter.cell_of(p.world_origin.x) + dx,
					CWScatter.cell_of(p.world_origin.y) + dz):
				if sample == null:
					sample = pl
	if sample == null:
		_skip("pose des instances", "aucune plante autour du point de depart")
		return

	# Position sous le bloc : sans elle, toute la flore s'aligne sur la grille du
	# terrain, ce qui se voit au premier coup d'oeil sur une prairie.
	var sub_used: int = 0
	var sub_bad: int = 0
	var seen: int = 0
	for dz in 8:
		for dx in 8:
			for pl in sc.cell(CWScatter.cell_of(p.world_origin.x) + dx,
					CWScatter.cell_of(p.world_origin.y) + dz):
				seen += 1
				if pl.fx < 0.0 or pl.fx >= 1.0 or pl.fz < 0.0 or pl.fz >= 1.0:
					sub_bad += 1
				if pl.fx != 0.0 or pl.fz != 0.0:
					sub_used += 1
	_ok("position sous le bloc dans [0, 1)", sub_bad == 0, "%d hors" % sub_bad)
	_ok("la flore n'est pas alignee sur la grille du terrain",
			sub_used > seen / 2, "%d sur %d decalees" % [sub_used, seen])

	# La transformation d'instance est le seul endroit ou les deux grilles se
	# rencontrent. Une plante enterree d'un demi-bloc ou glissee d'un quart de
	# gabarit a chaque quart de tour reste plausible a l'oeil : on la mesure.
	var model: CWVoxelModel = sample.model
	var mesh: ArrayMesh = model.mesh()
	var voxel: float = 1.0 / CWVoxelModel.VOXELS_PER_BLOCK
	var base_ok: bool = true
	var tall_ok: bool = true
	var centred_ok: bool = true
	var worst: float = 0.0
	for r in CWVoxelModel.ROTATIONS:
		var pl := CWScatter.Placement.new()
		pl.x = sample.x
		pl.z = sample.z
		pl.y = sample.y
		pl.fx = sample.fx
		pl.fz = sample.fz
		pl.model = model
		pl.rotation = r
		var box: AABB = CWFloraRenderer.instance_transform(pl, p.world_origin) \
				* mesh.get_aabb()
		var want := Vector3(
				float(pl.x - p.world_origin.x) + pl.fx,
				float(pl.y),
				float(pl.z - p.world_origin.y) + pl.fz)
		if absf(box.position.y - want.y) > 0.001:
			base_ok = false
		if absf(box.size.y - float(model.height) * voxel) > 0.001:
			tall_ok = false
		# Ancre au centre de l'empreinte : l'ecart tolere est d'un voxel, ce que
		# laisse la division entiere du centre du gabarit.
		var off: Vector3 = box.position + box.size * 0.5 - want
		worst = maxf(worst, maxf(absf(off.x), absf(off.z)))
		if worst > voxel:
			centred_ok = false
	_ok("la plante pose sur le sol, quelle que soit son orientation", base_ok)
	_ok("la plante garde sa hauteur reelle une fois a l'echelle", tall_ok,
			"%d voxels = %.3f bloc" % [model.height, float(model.height) * voxel])
	_ok("la plante reste centree sur son ancre aux quatre quarts de tour",
			centred_ok, "ecart max %.4f bloc (un voxel = %.4f)" % [worst, voxel])

	_bench_cells(sc, p.world_origin)


## Cout de construction d'une cellule de flore.
##
## C'est le poste qui decide de la distance de vue tenable pour la couche : le
## rendu en construit par lots sur un fil du pool, et une cellule trop chere se
## paie en flore qui apparait en retard derriere le terrain.
func _bench_cells(sc: CWScatter, origin: Vector2i) -> void:
	# Un carre de cellules contigues autour du point de depart, cache vide :
	# c'est exactement le lot que construit le rendu quand la vue avance. Les
	# mesurer eloignees les unes des autres donnerait un chiffre trois fois pire
	# et sans rapport avec l'usage — chaque cellule repaierait la fenetre de
	# sites de sa zone.
	var side: int = 12
	var runs: int = side * side
	var cx0: int = CWScatter.cell_of(origin.x)
	var cz0: int = CWScatter.cell_of(origin.y)
	sc.clear_cache()
	var plants: int = 0
	var t0: int = Time.get_ticks_usec()
	for dz in side:
		for dx in side:
			plants += sc.cell(cx0 + dx, cz0 + dz).size()
	var per: float = float(Time.get_ticks_usec() - t0) / float(runs)
	print("     cellule de flore : %.2f ms, %.1f plantes (%d colonnes couvertes)"
			% [per / 1000.0, float(plants) / float(runs),
			CWScatter.CELL_SIZE * CWScatter.CELL_SIZE])
	# Large expres : la mesure est bruitee sur vingt-quatre cellules, et le
	# nombre de plantes depend du biome tire. Le seuil attrape un ordre de
	# grandeur — un echantillonnage par candidat rejete, par exemple.
	_ok("une cellule de flore reste sous 8 ms", per < 8000.0,
			"%.2f ms" % (per / 1000.0))


## Les modeles distincts de la bibliotheque. Les noms portent le dossier de
## biome, donc trois `caillou_01` sont bien trois modeles ; deux biomes qui
## pointeraient le meme chemin n'en donneraient qu'un.
func _distinct_models(lib: CWModelLibrary) -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for surface in CWModelLibrary.FLORA:
		for m in lib.for_surface(surface):
			if not seen.has(m.name):
				seen[m.name] = true
				out.append(m)
	return out


func _flora_voxels(buf: VoxelBuffer) -> int:
	var n: int = 0
	var s: Vector3i = buf.get_size()
	for y in s.y:
		for z in s.z:
			for x in s.x:
				var v: int = buf.get_voxel(x, y, z, CHANNEL)
				if v >= CWPalette.RANGE_FLORA_BEGIN and v <= CWPalette.RANGE_FLORA_END:
					n += 1
	return n
