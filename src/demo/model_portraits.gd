extends Node3D

## Planche de validation des assets : **une capture par modele, seul, de pres**.
##
##   <godot> --path . scenes/model_portraits.tscn -- --lot tout
##   <godot> --path . scenes/model_portraits.tscn -- --lot flore --seul buisson
##
## Raison d'etre. Les huit defauts d'assets trouves depuis le 2026-09-05 l'ont
## tous ete parce qu'ils se **repetaient** — le fut qui depasse, la tache orange,
## le champ de rochers. Un modele qui est simplement laid, et qui n'est ni
## repete ni aberrant, passe indefiniment : a trente blocs une plante de deux
## blocs fait dix pixels, et dix pixels sont toujours plausibles. La question a
## laquelle cette planche repond n'est donc pas « est-ce que le paysage tient ? »
## — les captures de biome y repondent deja — mais **« est-ce qu'on reconnait
## l'objet, ou est-ce une bouillie de voxels ? »**. Elle ne se pose que de pres,
## et un modele a la fois. Voir `nextsteps.md`, §6quater.
##
## -- Pourquoi une scene a part, et pas une option de la demo -----------------
##
## « Sans rien autour » est la moitie du travail : le gabarit d'echelle se pose
## sur le terrain genere, donc sur de l'herbe, avec des plantes autour et un
## relief derriere. Ici il n'y a pas de terrain du tout — un damier neutre d'un
## bloc de maille, un ciel uni, et le modele. C'est aussi ce qui rend la planche
## rapide : rien a streamer, rien a attendre.
##
## -- Ce qu'une session headless ne peut pas faire ----------------------------
##
## Rien de tout ceci n'existe sans rasteriseur : un test headless verifie des
## nombres, pas une silhouette. La scene se lance donc **en fenetre**, prend ses
## captures dans un `SubViewport` de taille fixe — pour que le cadrage ne depende
## pas de la fenetre — et se ferme d'elle-meme.
##
## -- Les quatre lots ---------------------------------------------------------
##
## `flore` et `arbres` sont les modeles un a un, tels qu'ils sortent du
## generateur. `especes` est autre chose et c'est le lot le plus utile : un arbre
## **monte**, tronc et houppiers assembles par `CWTreeScatter`, exactement comme
## en jeu. Les trois derniers defauts corriges (la fleche qui flotte, les palmes
## qui flottent, l'ecorce entre les etages) etaient tous dans l'assemblage et
## dans aucun modele. `filons` ferme la liste.

## Sortie des captures.
const OUT_DIR: String = "user://portraits"

## Cote d'une capture, en pixels. Carre : un modele est aussi souvent haut que
## large, et un cadre carre evite d'avoir a choisir.
const SIZE: int = 640

## Cote d'une vignette de planche, nombre de colonnes, et hauteur de la ligne
## de legende sous chaque vignette.
const CELL: int = 300
const COLS: int = 5
const LEGENDE: int = 20

## Champ vertical de la camera. Etroit volontairement : une perspective large
## deforme un objet cadre serre, et c'est la silhouette qu'on juge.
const FOV: float = 30.0

## Les deux angles. Une bouillie de voxels se lit tres bien de face — c'est meme
## comme ca qu'une masse pleine trompe —, d'ou le trois-quarts au-dessus.
const ANGLES: Array[Dictionary] = [
	{"nom": "face", "lacet": 0.0, "site": 10.0},
	{"nom": "troisquarts", "lacet": 40.0, "site": 30.0},
]

## Damier du sol : deux gris neutres, une case par bloc de terrain. C'est la
## seule regle graduee de la planche, et elle ne coute rien au cadre.
const SOL_A: Color = Color(0.56, 0.56, 0.58)
const SOL_B: Color = Color(0.49, 0.49, 0.52)
const FOND: Color = Color(0.20, 0.21, 0.24)

var _vp: SubViewport
var _cam: Camera3D
var _stage: Node3D
var _titre: Label
var _sol: MeshInstance3D

var _lot: String = "tout"
var _seul: String = ""
var _size: int = SIZE

## Vignettes gardees en memoire pour les planches, par lot puis par angle.
var _vignettes: Dictionary = {}


func _ready() -> void:
	_read_cmdline()
	_build_view()
	_build_preview()
	_run()


func _read_cmdline() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < args.size():
		match args[i]:
			"--lot":
				if i + 1 < args.size():
					i += 1
					_lot = args[i]
			"--seul":
				if i + 1 < args.size():
					i += 1
					_seul = args[i]
			"--taille":
				if i + 1 < args.size():
					i += 1
					_size = maxi(128, int(args[i]))
		i += 1


# -- La scene de pose ---------------------------------------------------------

## Le viewport de capture : sa taille est fixe et independante de la fenetre,
## sans quoi deux planches prises sur deux machines ne se comparent pas.
func _build_view() -> void:
	_vp = SubViewport.new()
	_vp.name = "Portrait"
	_vp.size = Vector2i(_size, _size)
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.transparent_bg = false
	add_child(_vp)

	# Meme soleil et meme tonemapping que la demo : la planche doit rendre les
	# couleurs que le jeu rend, sinon elle juge un autre objet. Ce qui change est
	# le fond — uni et neutre au lieu d'un ciel — et l'absence de brouillard.
	var sun := DirectionalLight3D.new()
	sun.name = "Soleil"
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	_vp.add_child(sun)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = FOND
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.74, 0.79, 0.90)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 4.0
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)

	_sol = _build_sol()
	_vp.add_child(_sol)

	_cam = Camera3D.new()
	_cam.name = "Camera"
	_cam.fov = FOV
	_vp.add_child(_cam)

	_stage = Node3D.new()
	_stage.name = "Modele"
	_vp.add_child(_stage)

	# La legende est dessinee **dans** la capture : une planche dont les noms
	# sont ailleurs oblige a compter les cases pour savoir ce qu'on regarde.
	_titre = Label.new()
	_titre.position = Vector2(12, float(_size) - 84.0)
	_titre.add_theme_font_size_override("font_size", maxi(12, int(_size / 34.0)))
	_titre.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_titre.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_titre.add_theme_constant_override("outline_size", 5)
	_vp.add_child(_titre)


## Le sol : un damier dont **une case vaut un bloc de terrain**. C'est la regle
## graduee de la planche — a l'echelle des arbres comme a celle d'une corolle de
## trois voxels, on lit la taille sans mire dans le cadre.
func _build_sol() -> MeshInstance3D:
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.set_pixel(0, 0, SOL_A)
	img.set_pixel(1, 1, SOL_A)
	img.set_pixel(1, 0, SOL_B)
	img.set_pixel(0, 1, SOL_B)

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	var mesh := PlaneMesh.new()
	var mi := MeshInstance3D.new()
	mi.name = "Sol"
	mi.mesh = mesh
	mi.material_override = mat
	return mi


## Adapte le sol a la taille du sujet. La texture fait deux cases de cote, donc
## un facteur d'UV de `cote / 2` met exactement une case par bloc.
func _fit_sol(cote: float) -> void:
	var mesh: PlaneMesh = _sol.mesh
	mesh.size = Vector2(cote, cote)
	var mat: StandardMaterial3D = _sol.material_override
	mat.uv1_scale = Vector3(cote * 0.5, cote * 0.5, 1.0)


## Ce que la fenetre montre pendant que la planche se prend : la derniere
## capture. Sans cela on regarde un ecran noir pendant deux minutes sans savoir
## si la session travaille ou si elle est bloquee.
func _build_preview() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var tr := TextureRect.new()
	tr.texture = _vp.get_texture()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(tr)


# -- Le catalogue -------------------------------------------------------------

## Les sujets a photographier, dans l'ordre des lots.
##
## Une entree porte ses **pieces** deja transformees : un modele seul en a une,
## un arbre monte en a jusqu'a cinq. C'est ce qui permet au meme code de cadrer
## une corolle de trois voxels et un arbre geant.
func _collect() -> Array:
	var out: Array = []
	if _lot == "tout" or _lot == "flore":
		out.append_array(_collect_flore())
	if _lot == "tout" or _lot == "arbres":
		out.append_array(_collect_arbres())
	if _lot == "tout" or _lot == "especes":
		out.append_array(_collect_especes())
	if _lot == "tout" or _lot == "filons":
		out.append_array(_collect_filons())
	if _seul == "":
		return out
	var filtre: Array = []
	for e in out:
		if String(e["cle"]).contains(_seul):
			filtre.append(e)
	return filtre


func _collect_flore() -> Array:
	var lib := CWModelLibrary.shared()
	var out: Array = []
	var vus: Dictionary = {}
	var par_biome: Dictionary = CWModelLibrary.flora()
	for biome in CWBiome.all():
		for path in par_biome.get(biome, []):
			if vus.has(path):
				continue
			vus[path] = true
			var m: CWVoxelModel = lib.model(path)
			if m == null:
				push_warning("modele absent : %s" % path)
				continue
			out.append(_entree_solo("flore", path, m))
	return out


func _collect_arbres() -> Array:
	var lib := CWModelLibrary.shared_trees()
	var out: Array = []
	for path in CWTreeRules.all_paths():
		var m: CWVoxelModel = lib.model(path)
		if m == null:
			push_warning("modele absent : %s" % path)
			continue
		out.append(_entree_solo("arbres", path, m))
	return out


## Les arbres **montes**, par `CWTreeScatter` et non par une recopie du montage :
## une planche qui remonterait l'arbre a sa facon validerait son propre code, pas
## celui du jeu. Le tirage d'instance est fixe au milieu de sa plage — echelle
## moyenne, nombre de pieces maximal — pour que deux planches se comparent.
func _collect_especes() -> Array:
	var lib := CWModelLibrary.shared_trees()
	var scatter := CWTreeScatter.new(CWTerrainField.new(CWWorldParams.new()), lib)
	var out: Array = []
	for biome in CWTreeRules.biomes():
		for sp in CWTreeRules.SPECIES[biome]:
			if not lib.has_paths(([sp["tronc"]] as Array)
					+ (sp["couronnes"] as Array)):
				continue
			var poses: Array = []
			scatter._monte(poses, sp, 0, 0, 0,
					{"jitter": 0.5, "turn": 0, "pieces": 0.99})
			if poses.is_empty():
				continue
			var pieces: Array = []
			for pl in poses:
				pieces.append({
					"model": pl.model,
					"t": CWFloraRenderer.instance_transform(pl, Vector2i.ZERO)
							.translated(Vector3(-0.5, 0.0, -0.5)),
				})
			var cle: String = "%s/%s" % [CWBiome.dir_of(biome),
					String(sp["nom"]).replace(" ", "_")]
			out.append({
				"lot": "especes",
				"cle": cle,
				"pieces": pieces,
				"info": "%d piece(s) · montage %s" % [pieces.size(),
						_nom_montage(int(sp["montage"]))],
			})
	return out


func _collect_filons() -> Array:
	var palette: Resource = CWPalette.build_voxel_palette()
	var out: Array = []
	var dir := DirAccess.open("res://assets/models/filons")
	if dir == null:
		return out
	var noms: PackedStringArray = dir.get_files()
	noms.sort()
	for f in noms:
		if not f.ends_with(".vox"):
			continue
		var nom: String = f.get_basename()
		# Un filon s'estampe dans le terrain : sa grille est celle du bloc.
		var m: CWVoxelModel = CWVoxelModel.load_from(
				"res://assets/models/filons/" + f, palette, nom,
				CWVoxelModel.VOXELS_PER_BLOCK_TERRAIN)
		if m == null:
			continue
		out.append(_entree_solo("filons", nom, m))
	return out


## Un modele seul, pose par son ancre a l'origine — la meme pose que
## `CWScaleBoard._build_model`, et pour la meme raison : le maillage porte le
## decalage de son tampon, qu'il faut compenser a l'echelle du modele.
func _entree_solo(lot: String, cle: String, m: CWVoxelModel) -> Dictionary:
	var s: float = 1.0 / m.voxels_per_block
	var t := Transform3D(Basis().scaled(Vector3(s, s, s)),
			m.mesh_offset() * s)
	return {
		"lot": lot,
		"cle": cle,
		"pieces": [{"model": m, "t": t}],
		"info": "%d vox/bloc · %d×%d×%d vox · %d voxels" % [
				int(m.voxels_per_block), m.extent.x, m.extent.y, m.extent.z,
				m.voxel_count],
	}


func _nom_montage(montage: int) -> String:
	match montage:
		CWTreeRules.Montage.ENTIER: return "entier"
		CWTreeRules.Montage.FEUILLU: return "feuillu"
		CWTreeRules.Montage.PALMIER: return "palmier"
		CWTreeRules.Montage.GRAND: return "grand"
	return "?"


# -- La prise de vue ----------------------------------------------------------

func _run() -> void:
	var sujets: Array = _collect()
	if sujets.is_empty():
		push_error("aucun modele a photographier (lot=%s, seul=%s)"
				% [_lot, _seul])
		get_tree().quit(1)
		return
	print("[planche] %d sujet(s), %d angle(s), %d px"
			% [sujets.size(), ANGLES.size(), _size])
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var t0: int = Time.get_ticks_msec()
	for e in sujets:
		var boite: AABB = _pose(e["pieces"])
		_fit_sol(maxf(24.0, maxf(boite.size.x, boite.size.z) * 8.0))
		for angle in ANGLES:
			_cadre(boite, angle)
			_titre.text = "%s / %s\n%s\n%.1f × %.1f × %.1f blocs" % [
					e["lot"], e["cle"], e["info"],
					boite.size.x, boite.size.y, boite.size.z]
			var img: Image = await _capture()
			var nom: String = "%s_%s_%s.png" % [e["lot"],
					String(e["cle"]).replace("/", "_"), angle["nom"]]
			img.save_png(OUT_DIR + "/" + nom)
			_garde_vignette(e["lot"], angle["nom"], img, e["cle"])
	_clear()

	for lot in _vignettes:
		for angle in _vignettes[lot]:
			await _planche(lot, angle, _vignettes[lot][angle])

	print("[planche] %d sujet(s) en %.1f s -> %s" % [sujets.size(),
			float(Time.get_ticks_msec() - t0) / 1000.0,
			ProjectSettings.globalize_path(OUT_DIR)])
	get_tree().quit()


## Pose les pieces d'un sujet et rend leur boite englobante, en blocs.
##
## La boite vient du maillage et non du gabarit du modele : c'est la seule
## mesure qui vaille pour un arbre monte, dont les houppiers debordent le tronc.
func _pose(pieces: Array) -> AABB:
	_clear()
	var boite := AABB()
	var premier: bool = true
	for p in pieces:
		var m: CWVoxelModel = p["model"]
		var mesh: ArrayMesh = m.mesh()
		if mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.transform = p["t"]
		_stage.add_child(mi)
		var b: AABB = p["t"] * mesh.get_aabb()
		boite = b if premier else boite.merge(b)
		premier = false
	return boite


func _clear() -> void:
	for c in _stage.get_children():
		_stage.remove_child(c)
		c.queue_free()


## Cadre la camera sur la boite, a l'angle donne.
##
## Distance calculee sur la **sphere englobante** : c'est la seule formule qui
## cadre aussi bien un arbre de 22 blocs qu'une corolle d'un demi-bloc, sans
## reglage par lot.
func _cadre(boite: AABB, angle: Dictionary) -> void:
	var cible: Vector3 = boite.get_center()
	var rayon: float = maxf(boite.size.length() * 0.5, 0.15)
	var dist: float = rayon / sin(deg_to_rad(FOV * 0.5)) * 1.12
	var lacet: float = deg_to_rad(float(angle["lacet"]))
	var site: float = deg_to_rad(float(angle["site"]))
	var dir := Vector3(sin(lacet) * cos(site), sin(site), cos(lacet) * cos(site))
	_cam.position = cible + dir * dist
	_cam.look_at(cible, Vector3.UP)
	_cam.near = maxf(0.01, dist * 0.005)
	_cam.far = dist * 8.0


## Une image du viewport de capture.
##
## Deux frames d'attente : la premiere applique les changements de scene, la
## seconde les rend. Une seule rendrait la pose precedente — le genre de defaut
## qui ne se voit qu'a la vingtieme capture, quand un nom ne correspond plus.
func _capture() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return _vp.get_texture().get_image()


func _garde_vignette(lot: String, angle: String, img: Image, cle: String) -> void:
	var petite := Image.new()
	petite.copy_from(img)
	petite.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
	if not _vignettes.has(lot):
		_vignettes[lot] = {}
	if not _vignettes[lot].has(angle):
		_vignettes[lot][angle] = []
	_vignettes[lot][angle].append({"img": petite, "cle": cle})


## La planche de contact d'un lot : toutes ses vignettes en grille.
##
## Rendue dans un second viewport plutot que composee a la main, uniquement pour
## la legende : sans texte lisible sous chaque case, une planche de trente-huit
## modeles oblige a compter les lignes pour savoir lequel est en faute.
func _planche(lot: String, angle: String, vignettes: Array) -> void:
	if vignettes.is_empty():
		return
	var cols: int = mini(COLS, vignettes.size())
	@warning_ignore("integer_division")
	var rows: int = (vignettes.size() + cols - 1) / cols
	var pas := Vector2i(CELL + 8, CELL + 8 + LEGENDE)

	var vp := SubViewport.new()
	vp.size = Vector2i(cols * pas.x + 8, rows * pas.y + 8)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var fond := ColorRect.new()
	fond.color = FOND
	fond.size = Vector2(vp.size)
	vp.add_child(fond)

	for i in vignettes.size():
		@warning_ignore("integer_division")
		var ligne: int = i / cols
		var coin := Vector2(float(8 + (i % cols) * pas.x),
				float(8 + ligne * pas.y))
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(vignettes[i]["img"])
		tr.position = coin
		tr.size = Vector2(CELL, CELL)
		vp.add_child(tr)
		var lb := Label.new()
		lb.text = vignettes[i]["cle"]
		lb.position = coin + Vector2(2.0, float(CELL) + 1.0)
		lb.size = Vector2(float(CELL), float(LEGENDE))
		lb.add_theme_font_size_override("font_size", 15)
		lb.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
		vp.add_child(lb)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	var path: String = "%s/planche_%s_%s.png" % [OUT_DIR, lot, angle]
	img.save_png(path)
	print("[planche] %s : %d vignettes -> %s" % [lot, vignettes.size(), path])
	remove_child(vp)
	vp.queue_free()
