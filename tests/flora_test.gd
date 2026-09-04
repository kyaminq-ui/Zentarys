class_name CWFloraTest
extends RefCounted

## Verifications de la couche de flore (jalon 1.7) : chargement des modeles,
## dispersion, estampage dans les blocs.
##
## Pilote par tests/worldgen_test.gd, qui tient le compte des verifications :
##   CWFloraTest.new().run(self)
##
## La suite tourne meme si aucun modele n'est encore produit : les
## verifications qui en dependent sont alors annoncees comme sautees plutot que
## reussies. Une suite qui passe au vert parce qu'elle n'a rien teste est pire
## qu'une suite rouge.

const CHANNEL: int = VoxelBuffer.CHANNEL_COLOR

var _runner: Object


func run(runner: Object) -> void:
	_runner = runner
	_test_models()
	_test_scatter()
	_test_stamping()


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

	var grass: Array = lib.for_surface(CWPalette.GRASS)
	if grass.is_empty():
		_skip("chargement d'un modele", "aucun modele pour l'herbe")
		return
	var m: CWVoxelModel = grass[0]

	_ok("modele non vide", m.voxel_count > 0, str(m))
	_ok("gabarit coherent avec les offsets",
			m.height == m.extent.y and m.radius > 0, str(m))

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
	var margin: int = sc.library().max_radius + CWScatter.CELL_SIZE
	for cz in range(CWScatter.cell_of(wz - margin), CWScatter.cell_of(wz + 16 + margin) + 1):
		for cx in range(CWScatter.cell_of(wx - margin), CWScatter.cell_of(wx + 16 + margin) + 1):
			for pl in sc.cell(cx, cz):
				var r: int = pl.model.radius
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


# -- 3. Estampage dans les blocs ----------------------------------------------

func _test_stamping() -> void:
	print("[estampage de la flore]")
	var p := CWWorldParams.new()
	p.world_seed = 2024
	var g := CWVoxelGenerator.new()
	g.params = p
	if not g.scatter_grid().library().has_any():
		_skip("estampage", "aucun modele charge")
		return

	var ground: int = roundi(g.field().sample_column(p.world_origin.x, p.world_origin.y).x)
	@warning_ignore("integer_division")
	var oy: int = (ground / 16) * 16

	var sown := VoxelBuffer.new()
	sown.create(16, 16, 16)
	g._generate_block(sown, Vector3i(0, oy, 0), 0)

	g.scatter = false
	g.clear_caches()
	var bare := VoxelBuffer.new()
	bare.create(16, 16, 16)
	g._generate_block(bare, Vector3i(0, oy, 0), 0)
	g.scatter = true
	g.clear_caches()

	# La flore ne creuse pas le terrain : elle n'ecrit que dans l'air et l'eau.
	var carved: int = 0
	var added: int = 0
	for y in 16:
		for z in 16:
			for x in 16:
				var a: int = sown.get_voxel(x, y, z, CHANNEL)
				var b: int = bare.get_voxel(x, y, z, CHANNEL)
				if a == b:
					continue
				if b == CWPalette.AIR or b == CWPalette.WATER \
						or b == CWPalette.WATER_DEEP:
					added += 1
				else:
					carved += 1
	print("     %d voxels de flore ajoutes dans le bloc de surface" % added)
	_ok("la flore ne remplace jamais du terrain solide", carved == 0,
			"%d voxels ecrases" % carved)
	_ok("la flore est bien ecrite", added > 0)

	# Deux generations du meme bloc doivent coincider : sans cela le monde ne se
	# regenere pas a l'identique apres un dechargement.
	var again := VoxelBuffer.new()
	again.create(16, 16, 16)
	g.clear_caches()
	g._generate_block(again, Vector3i(0, oy, 0), 0)
	var mismatch: int = 0
	for y in 16:
		for z in 16:
			for x in 16:
				if again.get_voxel(x, y, z, CHANNEL) != sown.get_voxel(x, y, z, CHANNEL):
					mismatch += 1
	_ok("un bloc regenere est identique", mismatch == 0, "%d ecarts" % mismatch)

	# Continuite verticale : une plante a cheval sur deux blocs doit apparaitre
	# entiere, chaque bloc portant sa part. Le bloc du dessus n'a plus de sol : si
	# le chemin rapide « bloc vide » le rendait sans regarder la flore, la moitie
	# haute des plantes hautes disparaitrait.
	var upper := VoxelBuffer.new()
	upper.create(16, 16, 16)
	g._generate_block(upper, Vector3i(0, oy + 16, 0), 0)

	var plants: Array = g.scatter_grid().placements_in(
			p.world_origin.x, p.world_origin.y, 16, 16)
	var expected: int = 0
	var spans_up: int = 0
	for pl in plants:
		var dx: PackedInt32Array = pl.model.offsets_x(pl.rotation)
		var dy: PackedInt32Array = pl.model.offsets_y(pl.rotation)
		var dz: PackedInt32Array = pl.model.offsets_z(pl.rotation)
		for i in dy.size():
			var lx: int = pl.x - p.world_origin.x + dx[i]
			var lz: int = pl.z - p.world_origin.y + dz[i]
			var wy: int = pl.y + dy[i]
			if lx < 0 or lx >= 16 or lz < 0 or lz >= 16:
				continue
			if wy >= oy and wy < oy + 32:
				expected += 1
			if wy >= oy + 16 and wy < oy + 32:
				spans_up += 1
	var seen: int = _flora_voxels(sown) + _flora_voxels(upper)
	# `<=` et non `==` : une plante posee au pied d'une pente peut avoir une part
	# de son gabarit dans le flanc de la colline, ou elle n'ecrit rien.
	_ok("aucune plante n'est perdue entre deux blocs empiles",
			seen <= expected and seen > 0,
			"%d voxels vus pour %d attendus au plus" % [seen, expected])
	if spans_up > 0:
		_ok("le bloc au-dessus du sol porte sa part de flore",
				_flora_voxels(upper) > 0,
				"%d voxels attendus dans le bloc haut" % spans_up)
	else:
		_skip("le bloc au-dessus du sol porte sa part de flore",
				"aucune plante ne franchit la frontiere ici")

	_bench_scatter(g, oy)


## Surcout de la couche de flore sur le chemin de generation.
##
## Le cout par bloc est le plafond de tout le reste : c'est lui qui decide de la
## distance de vue tenable. Une couche qui le double ne se voit pas a l'oeil, on
## la mesure.
func _bench_scatter(g: CWVoxelGenerator, oy: int) -> void:
	var buf := VoxelBuffer.new()
	buf.create(16, 16, 16)
	var runs: int = 12
	var stride: int = 4096  # colonnes distinctes : chaque bloc paie plein tarif

	g.scatter = false
	g.clear_caches()
	var t0: int = Time.get_ticks_usec()
	for k in runs:
		g._generate_block(buf, Vector3i(k * stride, oy, 0), 0)
	var bare: float = float(Time.get_ticks_usec() - t0) / float(runs)

	g.scatter = true
	g.clear_caches()
	var t1: int = Time.get_ticks_usec()
	for k in runs:
		g._generate_block(buf, Vector3i(k * stride, oy, 0), 0)
	var sown: float = float(Time.get_ticks_usec() - t1) / float(runs)

	var overhead: float = 100.0 * (sown - bare) / maxf(bare, 1.0)
	print("     bloc a froid : %.1f ms sans flore, %.1f ms avec (%+.1f %%)"
			% [bare / 1000.0, sown / 1000.0, overhead])
	# Large exprès : la mesure est bruitee sur douze blocs. Le seuil n'est pas
	# la pour valider un reglage fin, mais pour attraper une regression d'ordre
	# de grandeur — un echantillonnage par candidat rejete, par exemple.
	_ok("la flore ne double pas le cout d'un bloc", sown < bare * 1.6,
			"%.1f ms contre %.1f ms" % [sown / 1000.0, bare / 1000.0])


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
