extends SceneTree

## Ramene les index de couleur d'un `.vox` dans la palette de projet.
##
##   godot --headless --path . -s tools/repaint_models.gd                 # rapport
##   godot --headless --path . -s tools/repaint_models.gd -- --write      # applique
##   godot --headless --path . -s tools/repaint_models.gd -- --write res://…/x.vox
##
## -- Pourquoi cet outil existe ------------------------------------------------
##
## `VoxelMesherCubes` en mode `COLOR_MESHER_PALETTE` rend un *index*, jamais la
## couleur stockee dans le fichier. Un modele dont les index ne sont pas ceux de
## `CWPalette` sort donc avec des couleurs d'un autre lot, sans le moindre
## message d'erreur — c'est le seul defaut d'asset du projet qui ne se voit ni au
## chargement, ni aux tests, seulement a l'ecran.
##
## Le premier lot de flore (2026-09-05) est arrive dans cet etat. La cause est
## etablie, pas supposee : la palette avait ete chargee dans MagicaVoxel en
## glissant `zentarys_palette_ref.png`, la planche agrandie. MagicaVoxel la
## reechantillonne pour la ramener a 256 cases, et retombe une case sur deux sur
## le lisere que `export_palette.gd` dessine au bord de chaque case. D'ou une
## palette ou chaque couleur du projet apparait deux fois — la vraie, puis la
## meme assombrie de 45 % — et donc decalee d'un facteur deux, dans l'ordre des
## lignes inverse. Les teintes etaient justes a l'oeil ; les emplacements, non.
##
## -- Ce que l'outil fait ------------------------------------------------------
##
## Il relit la couleur que le fichier associe a chacun de ses index, cherche
## l'entree la plus proche de la palette de projet, et **reecrit les index dans
## le fichier**. Il remplace du meme coup le bloc `RGBA` par la palette de
## projet : rouvert dans MagicaVoxel, le modele porte alors la bonne palette aux
## bons emplacements, et le probleme ne peut plus revenir sur ce fichier.
##
## La recherche est bornee aux deux plages qu'un modele a le droit d'employer —
## vegetation 128-175 et terrain 1-31 — sinon la couleur la plus proche part
## regulierement dans les creatures ou les structures, et le contrat de plages
## serait perdu pour un gain nul a l'oeil.
##
## L'ecriture est chirurgicale : seuls les octets d'index des blocs `XYZI` et le
## contenu du bloc `RGBA` changent. Les tailles de bloc sont inchangees, donc
## tout ce que MagicaVoxel a mis dans le fichier par ailleurs — graphe de scene,
## calques, materiaux — traverse l'operation intact.
##
## Idempotent : un modele deja dans la palette de projet se remappe sur lui-meme.

const MODELS_DIR: String = "res://assets/models"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var write: bool = false
	var paths := PackedStringArray()
	for a in args:
		if a == "--write":
			write = true
		else:
			paths.append(a)
	if paths.is_empty():
		paths = _all_models(MODELS_DIR)
	if paths.is_empty():
		print("aucun modele dans ", MODELS_DIR)
		quit(1)
		return

	var colors: PackedColorArray = CWPalette.colors()
	var targets: PackedInt32Array = _target_indices(colors)
	print("palette de projet : %d entrees candidates (vegetation %d-%d, terrain %d-%d)"
			% [targets.size(), CWPalette.RANGE_FLORA_BEGIN, CWPalette.RANGE_FLORA_END,
			CWPalette.RANGE_TERRAIN_BEGIN, CWPalette.RANGE_TERRAIN_END])
	print("mode : ", "ECRITURE" if write else "rapport seul (--write pour appliquer)")

	var touched: int = 0
	for path in paths:
		if _repaint(path, colors, targets, write):
			touched += 1
	print("\n%d fichier(s) sur %d a remapper." % [touched, paths.size()])
	quit(0)


## Les index qu'un modele a le droit de porter, dans l'ordre croissant.
##
## Seules les entrees **opaques** sont candidates. Une entree transparente
## rendrait le voxel invisible ; une entree translucide — l'eau, le verre — part
## dans la seconde surface du mailleur, que `CWVoxelModel.mesh()` habille du
## materiau opaque. Un voxel de plante n'y a rien a faire.
func _target_indices(colors: PackedColorArray) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in range(CWPalette.RANGE_TERRAIN_BEGIN, CWPalette.RANGE_TERRAIN_END + 1):
		if colors[i].a >= 1.0:
			out.append(i)
	for i in range(CWPalette.RANGE_FLORA_BEGIN, CWPalette.RANGE_FLORA_END + 1):
		if colors[i].a >= 1.0:
			out.append(i)
	return out


func _repaint(path: String, colors: PackedColorArray, targets: PackedInt32Array,
		write: bool) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		printerr(path, " : illisible")
		return false
	var data: PackedByteArray = f.get_buffer(f.get_length())
	f.close()

	if data.size() < 8 or data.slice(0, 4).get_string_from_ascii() != "VOX ":
		printerr(path, " : ce n'est pas un .vox")
		return false

	var chunks: Array = []
	_walk(data, 8, data.size(), chunks)

	# Palette du fichier. Le format la decale d'un cran : la couleur de l'index
	# `i` est en position `i - 1`. Un fichier sans bloc RGBA emploie la palette
	# par defaut de MagicaVoxel, qu'on ne connait pas ici — on refuse plutot que
	# de deviner.
	var rgba_at: int = -1
	for c in chunks:
		if c[0] == "RGBA":
			rgba_at = c[1]
	if rgba_at < 0:
		printerr(path, " : pas de bloc RGBA, palette d'origine inconnue — ignore")
		return false

	# Table de remappage, index par index, construite une seule fois.
	var remap := PackedInt32Array()
	remap.resize(256)
	for i in 256:
		remap[i] = i
	var used: Dictionary = {}
	for c in chunks:
		if c[0] != "XYZI":
			continue
		var n: int = data.decode_s32(c[1])
		for k in n:
			var v: int = data[c[1] + 4 + k * 4 + 3]
			used[v] = int(used.get(v, 0)) + 1

	var indices: Array = used.keys()
	indices.sort()
	var changes := PackedStringArray()
	var moved: int = 0
	for i in indices:
		if i <= 0 or i > 255:
			continue
		var src := Color8(
				data[rgba_at + (i - 1) * 4 + 0],
				data[rgba_at + (i - 1) * 4 + 1],
				data[rgba_at + (i - 1) * 4 + 2])
		var best: int = _nearest(src, colors, targets)
		remap[i] = best
		if best != i:
			moved += used[i]
		changes.append("%d->%d %s%s" % [i, best, _hex(src),
				"" if _same(src, colors[best]) else _hex(colors[best])])

	print("\n%s" % path)
	print("  %d index employes : %s" % [indices.size(), ", ".join(changes)])
	if moved == 0:
		print("  deja dans la palette de projet")
		return false
	if not write:
		return true

	# --- Ecriture ------------------------------------------------------------
	for c in chunks:
		if c[0] != "XYZI":
			continue
		var n: int = data.decode_s32(c[1])
		for k in n:
			var at: int = c[1] + 4 + k * 4 + 3
			data[at] = remap[data[at]]
	for i in range(1, 256):
		var col: Color = colors[i]
		data[rgba_at + (i - 1) * 4 + 0] = int(col.r * 255.0)
		data[rgba_at + (i - 1) * 4 + 1] = int(col.g * 255.0)
		data[rgba_at + (i - 1) * 4 + 2] = int(col.b * 255.0)
		data[rgba_at + (i - 1) * 4 + 3] = int(col.a * 255.0)

	var w: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if w == null:
		printerr(path, " : ecriture impossible")
		return true
	w.store_buffer(data)
	w.close()
	print("  reecrit")
	return true


## Entree la plus proche parmi `targets`, au carre de la distance RGB.
func _nearest(c: Color, colors: PackedColorArray, targets: PackedInt32Array) -> int:
	var best: int = targets[0]
	var best_d: float = INF
	for i in targets:
		var p: Color = colors[i]
		var d: float = (c.r - p.r) * (c.r - p.r) + (c.g - p.g) * (c.g - p.g) \
				+ (c.b - p.b) * (c.b - p.b)
		if d < best_d:
			best_d = d
			best = i
	return best


static func _same(a: Color, b: Color) -> bool:
	return a.to_rgba32() >> 8 == b.to_rgba32() >> 8


static func _hex(c: Color) -> String:
	return "#" + c.to_html(false)


## Parcourt l'arbre de blocs et rend [id, offset du contenu, taille] pour chacun.
func _walk(data: PackedByteArray, at: int, end: int, out: Array) -> void:
	while at + 12 <= end:
		var id: String = data.slice(at, at + 4).get_string_from_ascii()
		var content: int = data.decode_s32(at + 4)
		var children: int = data.decode_s32(at + 8)
		var body: int = at + 12
		out.append([id, body, content])
		if children > 0:
			_walk(data, body + content, body + content + children, out)
		at = body + content + children


func _all_models(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return out
	for sub in d.get_directories():
		out.append_array(_all_models(dir + "/" + sub))
	for f in d.get_files():
		if f.get_extension().to_lower() == "vox":
			out.append(dir + "/" + f)
	return out
