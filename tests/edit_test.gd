class_name CWEditTest
extends RefCounted

## Verifications de la couche d'edition et de la persistance (jalon 1.8).
##
## Pilote par tests/worldgen_test.gd, qui tient le compte des verifications :
##   CWEditTest.new().run(self)
##
## La couche d'edition a deux moities qui se testent tres differemment :
##
##   * la **regle** — quel bloc reste apres un coup de pioche, quelle colonne
##     est dans le monde, ce que le generateur met a une altitude donnee. Ce sont
##     des fonctions pures, on les mesure directement, sans terrain ;
##   * la **plomberie** — `VoxelTool`, `VoxelStreamSQLite`. Elle demande un
##     terrain vivant dans un arbre de scene, ce qu'une suite headless peut faire
##     mais qui n'a plus rien d'un test unitaire. On la couvre par un aller-retour
##     sur le flux seul, qui est la seule partie ou une regression serait
##     silencieuse : une edition perdue ne leve rien, elle disparait.

var _runner: Object


func run(runner: Object) -> void:
	_runner = runner
	_test_erase_rule()
	_test_generated_voxel()
	_test_bounds()
	_test_persistence()
	_test_flora_follows_edits()
	_test_two_channels()


func _ok(label: String, condition: bool, detail: String = "") -> void:
	_runner._ok(label, condition, detail)


# -- 1. La regle d'effacement -------------------------------------------------

func _test_erase_rule() -> void:
	print("[edition : la regle d'effacement]")

	# Le portage tient en une phrase : sous le niveau de la mer il n'y a pas de
	# vide, il y a de l'eau. `World_getBlockAt` @00405fd0 rend un temoin d'eau
	# pour tout ce qui est au-dessus de la matiere et sous `z = 1`.
	var sea: int = 0
	_ok("au-dessus de la mer, creuser laisse de l'air",
			CWWorldEdits.erase_value(sea + 1, sea) == CWPalette.AIR,
			CWPalette.name_of(CWWorldEdits.erase_value(sea + 1, sea)))
	# La borne elle-meme est du cote de l'eau : l'original teste `z < 1`, donc
	# z = 0 — le niveau de la mer — est mouille. Une erreur d'un cran ici laisse
	# une rangee de trous secs sur toute la ligne de rivage, ce qui ne se voit
	# qu'en marchant dessus.
	var at_sea: int = CWWorldEdits.erase_value(sea, sea)
	_ok("au niveau de la mer exactement, creuser laisse de l'eau",
			not CWWorldEdits.is_open(at_sea) or at_sea != CWPalette.AIR,
			CWPalette.name_of(at_sea))
	_ok("sous la mer, creuser laisse de l'eau",
			CWWorldEdits.erase_value(sea - 20, sea) != CWPalette.AIR,
			CWPalette.name_of(CWWorldEdits.erase_value(sea - 20, sea)))
	# La teinte suit la profondeur, comme pour l'eau generee : une tranchee
	# creusee dans un haut-fond ne doit pas ressortir en bleu d'abysse.
	_ok("la teinte de l'eau laissee suit la profondeur",
			CWWorldEdits.erase_value(sea - 1, sea)
					== CWPalette.water_index(1.0)
			and CWWorldEdits.erase_value(sea - 40, sea)
					== CWPalette.water_index(40.0))

	# `is_open` decide ce qu'on peut traverser et remplacer. L'eau en fait
	# partie : sans cela on ne pourrait pas batir une digue depuis la rive.
	_ok("l'air et les deux eaux sont traversables",
			CWWorldEdits.is_open(CWPalette.AIR)
			and CWWorldEdits.is_open(CWPalette.WATER)
			and CWWorldEdits.is_open(CWPalette.WATER_DEEP))
	var solid: Array = [CWPalette.STONE, CWPalette.DIRT, CWPalette.GRASS,
			CWPalette.SAND, CWPalette.ICE, CWPalette.SNOW]
	var leaky: Array = []
	for i in solid:
		if CWWorldEdits.is_open(i):
			leaky.append(CWPalette.name_of(i))
	_ok("aucune matiere n'est traversable", leaky.is_empty(), str(leaky))


# -- 2. La requete ponctuelle -------------------------------------------------

func _test_generated_voxel() -> void:
	print("[edition : le bloc en un point]")

	# `voxel_of` est la regle ; `_generate_block` la deroule par intervalles pour
	# aller vite. Les deux doivent dire la meme chose, et rien dans le code ne
	# les y oblige : c'est ce test qui tient le contrat. Sans lui, une couche
	# ajoutee au generateur laisserait la requete ponctuelle en arriere, et les
	# collisions du jalon 2 porteraient sur un monde qui n'est plus celui qu'on
	# voit.
	var p := CWWorldParams.new()
	p.world_seed = 2024
	var g := CWVoxelGenerator.new()
	g.params = p

	var sub: int = g.subsurface_depth
	var sea: int = p.sea_level

	# Colonne synthetique : on verifie la regle seule, sans dependre du relief.
	var top: int = 40
	_ok("la surface est au sommet de la colonne",
			CWVoxelGenerator.voxel_of(top, top, CWPalette.GRASS, sub, sea)
					== CWPalette.GRASS)
	_ok("juste sous la surface, la couche meuble",
			CWVoxelGenerator.voxel_of(top - 1, top, CWPalette.GRASS, sub, sea)
					== CWPalette.subsurface_index(CWPalette.GRASS))
	_ok("sous la couche meuble, la roche",
			CWVoxelGenerator.voxel_of(top - sub, top, CWPalette.GRASS, sub, sea)
					== CWPalette.STONE)
	_ok("au-dessus de la colonne et de la mer, de l'air",
			CWVoxelGenerator.voxel_of(top + 1, top, CWPalette.GRASS, sub, sea)
					== CWPalette.AIR)
	# Le cas qui casse quand on teste la roche en premier : sans couche meuble,
	# le remplissage de roche monte jusqu'au sommet et c'est la surface qui doit
	# gagner. Le monde genere montre de l'herbe ; la requete doit aussi.
	_ok("sans couche meuble, la surface l'emporte encore sur la roche",
			CWVoxelGenerator.voxel_of(top, top, CWPalette.GRASS, 0, sea)
					== CWPalette.GRASS)
	# Colonne noyee : de l'eau au-dessus du fond, jusqu'au niveau de la mer.
	_ok("au-dessus d'un fond noye, de l'eau jusqu'a la mer",
			CWVoxelGenerator.voxel_of(sea - 3, sea - 10, CWPalette.GRAVEL, sub, sea)
					!= CWPalette.AIR
			and CWVoxelGenerator.voxel_of(sea + 1, sea - 10, CWPalette.GRAVEL,
					sub, sea) == CWPalette.AIR)

	# Et maintenant l'accord avec le generateur lui-meme, sur du vrai relief :
	# on genere un bloc et on interroge la regle en chaque point.
	var ground: int = roundi(g.field().sample_column(
			p.world_origin.x, p.world_origin.y).x)
	@warning_ignore("integer_division")
	var oy: int = (ground / 16) * 16
	var buf := VoxelBuffer.new()
	buf.create(16, 16, 16)
	g._generate_block(buf, Vector3i(0, oy, 0), 0)
	var mismatched: int = 0
	var probed: int = 0
	var first: String = ""
	for lz in 16:
		for lx in 16:
			for ly in 16:
				var want: int = buf.get_voxel(lx, ly, lz, CWPalette.CHANNEL_TYPE)
				var got: int = g.generated_voxel(lx, oy + ly, lz)
				probed += 1
				if want != got:
					mismatched += 1
					if first == "":
						first = "(%d, %d, %d) : bloc %s, requete %s" % [
								lx, oy + ly, lz,
								CWPalette.name_of(want), CWPalette.name_of(got)]
	_ok("la requete ponctuelle dit la meme chose que le bloc genere (%d points)"
			% probed, mismatched == 0, "%d ecarts, %s" % [mismatched, first])


# -- 3. Les bornes du monde ---------------------------------------------------

func _test_bounds() -> void:
	print("[edition : les bornes du monde]")

	# `Chunk_getColumnAt` @00406100 refuse toute coordonnee hors de
	# [0, 0x1000000). Ce nombre est exactement WORLD_SIZE, et c'est une
	# corroboration independante de la geometrie du monde : elle avait ete
	# deduite de la grille de sites (1024 zones de 16384), le binaire la donne
	# par un tout autre chemin.
	_ok("le monde fait 0x1000000 blocs de cote, comme la borne du binaire",
			CWWorldParams.WORLD_SIZE == 0x1000000,
			"%d contre %d" % [CWWorldParams.WORLD_SIZE, 0x1000000])
	# Le chunk de 256 colonnes s'intercale exactement entre la tuile et le bloc.
	_ok("une tuile fait un nombre entier de chunks de 256 colonnes",
			CWWorldParams.ZONE_SIZE % 256 == 0)

	var p := CWWorldParams.new()
	p.world_seed = 2024
	var g := CWVoxelGenerator.new()
	g.params = p
	var e := CWWorldEdits.new()
	# Sans terrain : la couche doit rester utilisable pour ses regles, et rendre
	# la main proprement sur tout ce qui demande un `VoxelTool`.
	e.setup(null, g, -160)
	_ok("sans terrain, la couche n'a pas d'outil", not e.has_tool())
	_ok("sans outil, creuser ne fait rien", e.dig(Vector3i(0, 0, 0)) == -1)
	_ok("sans outil, poser ne fait rien",
			not e.place(Vector3i(0, 0, 0), CWPalette.STONE))
	_ok("sans outil, le rayon ne rend rien",
			e.raycast(Vector3.ZERO, Vector3.DOWN) == null)

	# La requete, elle, doit repondre meme sans terrain : c'est le repli sur le
	# generateur, et c'est ce dont se serviront les collisions loin du joueur.
	_ok("sans terrain, la requete repond depuis le generateur",
			e.voxel_at(0, -100, 0) == CWPalette.STONE,
			CWPalette.name_of(e.voxel_at(0, -100, 0)))

	# Bornes horizontales. Le point de depart est au centre du monde, donc il
	# faut s'ecarter de la moitie de sa largeur pour en sortir.
	_ok("le point de depart est dans le monde", e.in_world(0, 0))
	var half: int = CWWorldParams.WORLD_SIZE
	_ok("une colonne tres a l'ouest est hors du monde", not e.in_world(-half, 0))
	_ok("une colonne tres a l'est est hors du monde", not e.in_world(half, 0))
	_ok("hors du monde, la requete rend de l'air",
			e.voxel_at(-half, 0, 0) == CWPalette.AIR)


# -- 4. La persistance --------------------------------------------------------

func _test_persistence() -> void:
	print("[edition : persistance]")

	# On teste le flux seul, sans terrain. C'est la partie ou une regression
	# serait muette : une edition qui ne se relit pas ne leve aucune erreur, elle
	# manque simplement au retour dans le monde.
	var dir: String = "user://tests"
	DirAccess.make_dir_recursive_absolute(dir)
	var path: String = "%s/edits_test.sqlite" % dir
	DirAccess.remove_absolute(path)

	var out := VoxelStreamSQLite.new()
	out.database_path = path
	out.save_generator_output = false
	_ok("le flux ne sauvegarde pas la sortie du generateur",
			not out.save_generator_output)

	var size: Vector3i = Vector3i(out.get_block_size())
	var buf := VoxelBuffer.new()
	buf.create(size.x, size.y, size.z)
	buf.fill(CWPalette.AIR, CWPalette.CHANNEL_TYPE)
	# Trois blocs distincts, dont un au niveau de la mer : c'est la valeur que
	# laisse `erase_value`, et donc celle qu'une session de creusage ecrit
	# vraiment sur le disque.
	buf.set_voxel(CWPalette.STONE, 1, 2, 3, CWPalette.CHANNEL_TYPE)
	buf.set_voxel(CWWorldEdits.erase_value(0, 0), 4, 5, 6, CWPalette.CHANNEL_TYPE)
	buf.set_voxel(CWPalette.SNOW, 7, 8, 9, CWPalette.CHANNEL_TYPE)

	var at := Vector3i(12, -3, 40)
	out.save_voxel_block(buf, at, 0)
	out.flush()

	# Relecture par une *seconde* instance : relire par la meme laisserait passer
	# une sauvegarde restee en memoire et jamais ecrite.
	var back := VoxelStreamSQLite.new()
	back.database_path = path
	var got := VoxelBuffer.new()
	got.create(size.x, size.y, size.z)
	var res: int = back.load_voxel_block(got, at, 0)
	_ok("le bloc sauvegarde se relit",
			res == VoxelStream.RESULT_BLOCK_FOUND, str(res))
	_ok("la roche posee est revenue",
			got.get_voxel(1, 2, 3, CWPalette.CHANNEL_TYPE) == CWPalette.STONE)
	_ok("l'eau laissee par un creusage sous la mer est revenue",
			got.get_voxel(4, 5, 6, CWPalette.CHANNEL_TYPE)
					== CWWorldEdits.erase_value(0, 0))
	_ok("la neige posee est revenue",
			got.get_voxel(7, 8, 9, CWPalette.CHANNEL_TYPE) == CWPalette.SNOW)
	_ok("le reste du bloc est reste vide",
			got.get_voxel(0, 0, 0, CWPalette.CHANNEL_TYPE) == CWPalette.AIR)

	# Un bloc jamais ecrit doit se signaler comme absent, et non rendre du vide :
	# c'est ce qui fait retomber Voxel Tools sur le generateur. Confondre les
	# deux donnerait un monde qui se creuse tout seul aux endroits visites.
	var elsewhere := VoxelBuffer.new()
	elsewhere.create(size.x, size.y, size.z)
	var miss: int = back.load_voxel_block(elsewhere, Vector3i(999, 7, -999), 0)
	_ok("un bloc jamais edite se signale absent, pas vide",
			miss == VoxelStream.RESULT_BLOCK_NOT_FOUND, str(miss))

	back.flush()
	DirAccess.remove_absolute(path)


# -- 5. La flore suit le terrain edite ----------------------------------------

func _test_flora_follows_edits() -> void:
	print("[edition : la flore suit le terrain]")

	# Creuser sous une touffe la laissait en l'air : la flore est instanciee a
	# partir du relief *genere*, que l'edition ne change pas. La dispersion
	# consulte donc maintenant le sommet des colonnes editees.
	#
	# Sans terrain il n'y a pas de `VoxelTool`, donc pas de vrai coup de pioche :
	# on pose directement le sommet, ce qui est exactement ce que verrait la
	# dispersion apres un creusage. C'est la regle qui est testee, pas la
	# plomberie de `VoxelTool` — celle-la se voit en jeu.
	var p := CWWorldParams.new()
	p.world_seed = 2024
	var g := CWVoxelGenerator.new()
	g.params = p
	var sc: CWScatter = g.scatter_grid()
	if not sc.library().has_any():
		print("  [saute] la flore suit le terrain  (aucun modele charge)")
		return

	var cx0: int = CWScatter.cell_of(p.world_origin.x)
	var cz0: int = CWScatter.cell_of(p.world_origin.y)

	# Une cellule garnie, pour avoir de la matiere a retirer.
	var cell := Vector2i(0, 0)
	var before: Array = []
	for dz in 24:
		for dx in 24:
			var got: Array = sc.cell(cx0 + dx, cz0 + dz)
			if got.size() > before.size():
				before = got
				cell = Vector2i(cx0 + dx, cz0 + dz)
	if before.is_empty():
		print("  [saute] la flore suit le terrain  (aucune plante autour du depart)")
		return

	var e := CWWorldEdits.new()
	e.setup(null, g, -160)
	sc.set_edits(e)
	_ok("une colonne intacte n'est pas signalee comme editee",
			e.edited_top(before[0].x, before[0].z) == CWWorldEdits.NOT_EDITED)

	# On abaisse le sol sous la premiere plante de dix blocs, comme le ferait un
	# cratere, et on redemande la cellule.
	#
	# **Le piege de repere, et pourquoi ce test le traverse.** `CWWorldEdits`
	# travaille en coordonnees de scene, comme `VoxelTool` ; `CWScatter` travaille
	# en coordonnees monde. On ecrit donc ici avec des coordonnees de scene — ce
	# que fait `dig` — et on relit avec des coordonnees monde — ce que fait la
	# dispersion. Une premiere version de ce test employait le meme repere des
	# deux cotes : il passait au vert alors que la flore continuait de flotter
	# au-dessus des crateres en jeu.
	var victim: CWScatter.Placement = before[0]
	var scene_x: int = victim.x - p.world_origin.x
	var scene_z: int = victim.z - p.world_origin.y
	e._set_top(scene_x, scene_z, victim.y - 11)
	_ok("la colonne creusee porte son nouveau sommet, lue en coordonnees monde",
			e.edited_top(victim.x, victim.z) == victim.y - 11,
			"scene (%d, %d) -> monde (%d, %d)" % [scene_x, scene_z, victim.x, victim.z])
	_ok("et elle n'est pas rangee sous ses coordonnees de scene",
			e.edited_top(scene_x, scene_z) == CWWorldEdits.NOT_EDITED)

	var dirty: Array = sc.take_dirty_cells()
	_ok("la cellule de la colonne creusee est signalee a refaire",
			dirty.has(Vector2i(CWScatter.cell_of(victim.x),
					CWScatter.cell_of(victim.z))), str(dirty))

	sc.invalidate_cell(cell.x, cell.y)
	var after: Array = sc.cell(cell.x, cell.y)
	var still_there: bool = false
	for pl in after:
		if pl.x == victim.x and pl.z == victim.z and pl.y == victim.y:
			still_there = true
	_ok("la plante dont le sol a disparu n'est plus posee", not still_there,
			"%d plantes avant, %d apres" % [before.size(), after.size()])
	# Et seulement celle-la : creuser une colonne ne doit pas raser la cellule.
	_ok("les plantes des colonnes intactes restent",
			after.size() >= before.size() - 4 and not after.is_empty(),
			"%d -> %d" % [before.size(), after.size()])

	# Une plante qui repose encore sur son sol edite doit rester : batir un
	# muret sous une touffe ne la fait pas disparaitre.
	var keeper: CWScatter.Placement = after[0]
	e._set_top(keeper.x - p.world_origin.x, keeper.z - p.world_origin.y,
			keeper.y - 1)
	sc.invalidate_cell(cell.x, cell.y)
	var kept: bool = false
	for pl in sc.cell(cell.x, cell.y):
		if pl.x == keeper.x and pl.z == keeper.z and pl.y == keeper.y:
			kept = true
	_ok("une plante dont le sol est intact survit a l'edition de sa colonne", kept)

	sc.set_edits(null)
	sc.clear_cache()


# -- 6. Les deux canaux ------------------------------------------------------

func _test_two_channels() -> void:
	print("[rendu : le canal semantique et le canal de couleur]")

	# Depuis le 2026-09-05 un voxel porte deux valeurs : l'index de palette dans
	# `CHANNEL_TYPE` et la couleur rendue dans `CHANNEL_COLOR`. C'est la
	# disposition de l'original (`docs/systems/03`, §3) et c'est ce qui permettra
	# une lumiere par voxel — mais c'est aussi une redondance, et une redondance
	# derive. Un terrain dont la couleur ne suit plus le type ment a l'oeil sans
	# qu'aucun test de logique ne s'en apercoive : d'ou ce qui suit.

	_ok("le canal de rendu est en 32 bits",
			CWPalette.COLOR_DEPTH == VoxelBuffer.DEPTH_32_BIT)
	# L'air doit rester d'alpha nul, sinon le mailleur cesse de le traiter comme
	# du vide et le monde se remplit de cubes transparents.
	_ok("l'air a une couleur d'alpha nul",
			(CWPalette.raw_of(CWPalette.AIR) & 0xFF) == 0,
			"0x%08X" % CWPalette.raw_of(CWPalette.AIR))
	# Les deux eaux doivent rester translucides : c'est leur alpha, et lui seul,
	# qui les range dans la seconde surface du mailleur.
	_ok("les deux eaux sont translucides",
			(CWPalette.raw_of(CWPalette.WATER) & 0xFF) < 255
			and (CWPalette.raw_of(CWPalette.WATER_DEEP) & 0xFF) < 255)
	# Et la matiere, elle, doit etre opaque.
	var see_through: Array = []
	for i in [CWPalette.STONE, CWPalette.DIRT, CWPalette.GRASS, CWPalette.SAND,
			CWPalette.SNOW, CWPalette.ICE, CWPalette.GRAVEL]:
		if (CWPalette.raw_of(i) & 0xFF) != 255:
			see_through.append(CWPalette.name_of(i))
	_ok("la matiere est opaque", see_through.is_empty(), str(see_through))

	# La table de couleurs doit dire la meme chose que la palette dont elle sort,
	# a la quantification pres : le canal porte huit bits par composante, la
	# palette des flottants. La tolerance est donc exactement un pas de 1/255 —
	# la resserrer ferait echouer sur du bruit d'arrondi, l'elargir laisserait
	# passer une vraie derive de teinte.
	var step: float = 1.0 / 255.0
	var cols: PackedColorArray = CWPalette.colors()
	var drift: Array = []
	var worst: float = 0.0
	for i in 256:
		var raw: int = CWPalette.raw_of(i)
		var back := Color8((raw >> 24) & 0xFF, (raw >> 16) & 0xFF,
				(raw >> 8) & 0xFF, raw & 0xFF)
		var off: float = maxf(maxf(absf(back.r - cols[i].r), absf(back.g - cols[i].g)),
				maxf(absf(back.b - cols[i].b), absf(back.a - cols[i].a)))
		worst = maxf(worst, off)
		if off > step * 0.5001 and drift.size() < 4:
			drift.append("%d : %s contre %s" % [i, str(back), str(cols[i])])
	_ok("chaque index rend la couleur de la palette, a un pas de 1/255 pres",
			drift.is_empty(), "ecart max %.5f pour un pas de %.5f ; %s"
					% [worst, step, str(drift)])

	# Le point qui compte : sur du vrai terrain, les deux canaux racontent la
	# meme chose bloc par bloc.
	var p := CWWorldParams.new()
	p.world_seed = 2024
	var g := CWVoxelGenerator.new()
	g.params = p
	var ground: int = roundi(g.field().sample_column(
			p.world_origin.x, p.world_origin.y).x)
	@warning_ignore("integer_division")
	var oy: int = (ground / 16) * 16
	var buf := VoxelBuffer.new()
	buf.set_channel_depth(CWPalette.CHANNEL_COLOR, CWPalette.COLOR_DEPTH)
	buf.create(16, 16, 16)
	g._generate_block(buf, Vector3i(0, oy, 0), 0)

	var mismatched: int = 0
	var first: String = ""
	var opaque_seen: int = 0
	for lz in 16:
		for lx in 16:
			for ly in 16:
				var t: int = buf.get_voxel(lx, ly, lz, CWPalette.CHANNEL_TYPE)
				var c: int = buf.get_voxel(lx, ly, lz, CWPalette.CHANNEL_COLOR)
				if t != CWPalette.AIR:
					opaque_seen += 1
				if c != CWPalette.raw_of(t):
					mismatched += 1
					if first == "":
						first = "(%d, %d, %d) : type %s, couleur 0x%08X" % [
								lx, ly, lz, CWPalette.name_of(t), c]
	_ok("le bloc genere porte de la matiere", opaque_seen > 0,
			"%d voxels non vides" % opaque_seen)
	_ok("la couleur suit le type sur tout le bloc genere (4096 points)",
			mismatched == 0, "%d ecarts, %s" % [mismatched, first])
