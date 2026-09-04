extends SceneTree

## Inventaire d'un modele .vox : dimensions, index de palette employes, densite.
##
##   godot --headless --path . -s tools/inspect_model.gd
##   godot --headless --path . -s tools/inspect_model.gd -- res://assets/models/flore/herbe_01.vox
##
## Sans argument, passe en revue tout `assets/models/`. Sert a deux choses :
## verifier qu'un modele reste dans sa plage de palette (un index hors plage
## sort avec la couleur d'un autre lot, sans le moindre message d'erreur), et
## connaitre sa taille reelle avant de le poser en jeu — en voxels, l'unite dans
## laquelle on dessine, et en blocs de terrain, l'unite dans laquelle on juge.

const MODELS_DIR: String = "res://assets/models"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var paths: PackedStringArray = args if args.size() > 0 else _all_models(MODELS_DIR)
	if paths.is_empty():
		print("aucun modele dans ", MODELS_DIR)
		quit(1)
		return
	for path in paths:
		_inspect(path)
	quit(0)


func _all_models(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for sub in d.get_directories():
		out.append_array(_all_models(dir + "/" + sub))
	for f in d.get_files():
		if f.get_extension().to_lower() == "vox":
			out.append(dir + "/" + f)
	return out


func _inspect(path: String) -> void:
	var buffer := VoxelBuffer.new()
	var err: int = VoxelVoxLoader.load_from_file(path, buffer,
			CWPalette.build_voxel_palette(), VoxelBuffer.CHANNEL_COLOR)
	if err != OK:
		print("%s : ECHEC de chargement (%d)" % [path, err])
		return

	var size: Vector3i = buffer.get_size()
	var used: Dictionary = {}
	var filled: int = 0
	# Boite englobante reelle : le .vox est souvent plus large que sa matiere.
	var lo := Vector3i(size)
	var hi := Vector3i(-1, -1, -1)
	for y in size.y:
		for z in size.z:
			for x in size.x:
				var v: int = buffer.get_voxel(x, y, z, VoxelBuffer.CHANNEL_COLOR)
				if v == CWPalette.AIR:
					continue
				filled += 1
				used[v] = int(used.get(v, 0)) + 1
				lo = lo.min(Vector3i(x, y, z))
				hi = hi.max(Vector3i(x, y, z))

	print("\n%s" % path)
	if filled == 0:
		print("  vide")
		return
	var extent: Vector3i = hi - lo + Vector3i.ONE
	print("  tampon %d x %d x %d (godot x,y,z)   matiere %d x %d x %d, coin bas %s"
			% [size.x, size.y, size.z, extent.x, extent.y, extent.z, lo])
	# La taille en blocs est la seule qui dise quelque chose : un modele se juge
	# contre le personnage de reference, qui fait 2 blocs. Voir MODELS.md, §1.
	var per: float = float(CWVoxelModel.VOXELS_PER_BLOCK)
	print("  soit %.2f x %.2f x %.2f blocs   (%.2f fois la hauteur du personnage)"
			% [float(extent.x) / per, float(extent.y) / per, float(extent.z) / per,
			float(extent.y) / (per * 2.0)])
	print("  %d voxels pleins, %.1f %% du tampon"
			% [filled, 100.0 * float(filled) / float(size.x * size.y * size.z)])

	var indices: Array = used.keys()
	indices.sort()
	var parts := PackedStringArray()
	for i in indices:
		parts.append("%d x%d" % [i, used[i]])
	print("  index : ", ", ".join(parts))

	# Le decoupage en plages est un contrat : un modele qui en sort se peint
	# avec les couleurs d'un autre lot le jour ou la palette bouge.
	var strays := PackedStringArray()
	for i in indices:
		if not _in_flora_range(i):
			strays.append(str(i))
	if strays.is_empty():
		print("  plage : tout dans Vegetation %d-%d ou Terrain %d-%d"
				% [CWPalette.RANGE_FLORA_BEGIN, CWPalette.RANGE_FLORA_END,
				CWPalette.RANGE_TERRAIN_BEGIN, CWPalette.RANGE_TERRAIN_END])
	else:
		print("  ATTENTION index hors plage flore/terrain : ", ", ".join(strays))


func _in_flora_range(i: int) -> bool:
	if i >= CWPalette.RANGE_FLORA_BEGIN and i <= CWPalette.RANGE_FLORA_END:
		return true
	return i >= CWPalette.RANGE_TERRAIN_BEGIN and i <= CWPalette.RANGE_TERRAIN_END
