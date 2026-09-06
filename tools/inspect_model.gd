extends SceneTree

## Inventaire d'un modele .vox : dimensions, index de palette employes, densite.
##
##   godot --headless --path . -s tools/inspect_model.gd
##   godot --headless --path . -s tools/inspect_model.gd -- res://assets/models/flore/herbe/herbe_01.vox
##
## Sans argument, passe en revue tout `assets/models/`. Sert a trois choses :
## verifier qu'un modele reste dans sa plage de palette (un index hors plage
## sort avec la couleur d'un autre lot, sans le moindre message d'erreur),
## connaitre sa taille reelle avant de le poser en jeu — en voxels, l'unite dans
## laquelle on dessine, et en blocs de terrain, l'unite dans laquelle on juge —,
## et dire **s'il tient d'un seul tenant**.
##
## -- Le morcellement, ajoute le 2026-09-06 -----------------------------------
##
## La planche de validation (`scenes/model_portraits.tscn`) a montre une dizaine
## de modeles faits de cubes qui ne se touchent pas : vus de pres, ils flottent.
## C'est le seul des defauts releves qui se mesure, donc le seul qu'un outil
## puisse attraper — d'ou le compte de morceaux ci-dessous, en **26-voisinage**,
## celui qui laisse passer le grain voulu (deux voxels en diagonale se touchent
## par un coin, et se lisent comme attaches) et refuse l'ilot detache.

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
	# contre le personnage de reference, qui fait 2,4 blocs. Voir MODELS.md, §1.
	#
	# **La grille depend du lot** : la flore est a 4 voxels par bloc — 6 pour ses
	# petits props —, les arbres et les filons a 1. Se tromper de grille ici
	# n'est pas anodin — l'outil annoncait le pin a 1,65 bloc de haut la ou il
	# en fait 22, et c'est justement l'outil qu'on consulte pour verifier une
	# echelle. Le chemin suffit a trancher, et `CWModelLibrary` fait le meme
	# choix par dossier de lot.
	var per: float = _grille_de(path)
	print("  soit %.2f x %.2f x %.2f blocs   (%.2f fois la hauteur du personnage)"
			% [float(extent.x) / per, float(extent.y) / per, float(extent.z) / per,
			float(extent.y) / (per * 2.4)])
	print("  %d voxels pleins, %.1f %% du tampon"
			% [filled, 100.0 * float(filled) / float(size.x * size.y * size.z)])

	_morceaux(buffer, size, filled)

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


## Compte les morceaux d'un modele, en 26-voisinage.
##
## Un modele d'un seul tenant en a **un**. Au-dela, les cubes du second morceau
## ne touchent rien : en jeu ils flottent, et de loin ils lisent comme du bruit.
## Le compte sort avec la taille du plus gros morceau, parce que c'est le rapport
## qui dit si on regarde une plante grenee ou un tas de confettis.
func _morceaux(buffer: VoxelBuffer, size: Vector3i, filled: int) -> void:
	var vus: Dictionary = {}
	var morceaux: Array[int] = []
	var isoles: int = 0
	for y in size.y:
		for z in size.z:
			for x in size.x:
				var p := Vector3i(x, y, z)
				if vus.has(p):
					continue
				if buffer.get_voxel(x, y, z, VoxelBuffer.CHANNEL_COLOR) == CWPalette.AIR:
					continue
				# Parcours en largeur, pile explicite : la recursion sur un
				# modele de six cents voxels est inutilement fragile.
				var pile: Array[Vector3i] = [p]
				vus[p] = true
				var n: int = 0
				while not pile.is_empty():
					var c: Vector3i = pile.pop_back()
					n += 1
					for dy in [-1, 0, 1]:
						for dz in [-1, 0, 1]:
							for dx in [-1, 0, 1]:
								var q := c + Vector3i(dx, dy, dz)
								if q.x < 0 or q.y < 0 or q.z < 0:
									continue
								if q.x >= size.x or q.y >= size.y or q.z >= size.z:
									continue
								if vus.has(q):
									continue
								if buffer.get_voxel(q.x, q.y, q.z,
										VoxelBuffer.CHANNEL_COLOR) == CWPalette.AIR:
									continue
								vus[q] = true
								pile.append(q)
				morceaux.append(n)
				if n == 1:
					isoles += 1
	morceaux.sort()
	morceaux.reverse()
	var plus_gros: int = morceaux[0] if not morceaux.is_empty() else 0
	var verdict: String = "d'un seul tenant" if morceaux.size() == 1 else "MORCELE"
	print("  %d morceau(x), le plus gros %d voxels (%.0f %%), %d isole(s) : %s"
			% [morceaux.size(), plus_gros,
			100.0 * float(plus_gros) / float(maxi(filled, 1)), isoles, verdict])


## Voxels par bloc du lot auquel appartient ce fichier.
##
## **Trois grilles depuis le 2026-09-06**, et l'outil en annoncait une seule :
## il rendait la flore treize fois plus fine qu'elle n'est dessinee, c'est-a-dire
## qu'il mentait exactement sur ce qu'on vient le lire.
func _grille_de(path: String) -> float:
	if path.contains("/arbres/") or path.contains("/filons/"):
		return CWVoxelModel.VOXELS_PER_BLOCK_TERRAIN
	if path.contains("/flore/"):
		var cle: String = path.get_base_dir().get_file() + "/" + path.get_file().get_basename()
		if CWModelLibrary.GRILLE_FINE.has(cle):
			return CWVoxelModel.VOXELS_PER_BLOCK_FLORE_FINE
		return CWVoxelModel.VOXELS_PER_BLOCK_FLORE
	return CWVoxelModel.VOXELS_PER_BLOCK


func _in_flora_range(i: int) -> bool:
	if i >= CWPalette.RANGE_FLORA_BEGIN and i <= CWPalette.RANGE_FLORA_END:
		return true
	return i >= CWPalette.RANGE_TERRAIN_BEGIN and i <= CWPalette.RANGE_TERRAIN_END
