class_name CWLight
extends RefCounted

## Eclairage voxel (jalon 1.9). Portage de `VoxelChunk_propagateSunlight`
## (@0059a0e0). Analyse complete : `docs/systems/04`.
##
## -- L'algorithme, en deux passes ---------------------------------------------
##   A. **descente du soleil**, une fois, colonne par colonne : au-dessus du
##      premier bloc opaque on est a 255, en dessous a 0. Pas d'attenuation
##      verticale, la transition est franche ;
##   B. **diffusion**, seize iterations, **purement horizontale** et en double
##      tampon. Chaque voxel transparent prend le maximum de ses quatre voisins
##      de meme altitude, attenue de `x 0,85`.
##
## Trois details qui distinguent cet eclairage de celui, familier, de Minecraft,
## et qu'il ne faut pas « corriger » :
##
##   * l'attenuation est **multiplicative**, pas un moins-un par bloc. La lumiere
##     decroit donc en exponentielle et non en rampe : `0,85^16 ~ 7 %` ;
##   * un voisin transparent contribue **au moins 5**, meme s'il est noir. C'est
##     l'ambiante, et elle est dans l'algorithme, pas dans le rendu : aucun
##     recoin ne tombe au noir absolu ;
##   * la diffusion **ne monte ni ne descend**. Le vertical est entierement
##     traite par la passe A ; une ouverture au plafond eclaire sa colonne
##     jusqu'au sol, et c'est de la que la lumiere s'etale, etage par etage.
##
## -- Ce qui est transparent ---------------------------------------------------
## L'original teste `type == 0 || type == 2` : l'air, et un second type qui
## laisse passer la lumiere sans etre de l'air — l'eau, selon toute
## vraisemblance (`docs/systems/03`, §4). Ici c'est l'air et les deux eaux.
##
## L'original connait aussi un **type 13, source de lumiere** a 255. Le projet
## n'a pas encore de bloc lumineux — ce sera un asset de donjon, jalon 4 — donc
## `SOURCE` est reserve mais aucun index ne le porte. La branche est ecrite : le
## jour ou une torche existe, il y aura une ligne a changer, pas une passe a
## reecrire.
##
## -- Pourquoi le terrain genere ne passe pas par ici --------------------------
## Le monde porte est un **champ de hauteurs pur** : pas de grotte, pas de
## surplomb. La passe A y repond donc « 255 partout au-dessus de la surface, 0
## en dessous », et ce qui est en dessous n'est jamais visible. Faire tourner la
## diffusion sur du terrain intact reviendrait a payer seize iterations pour
## reobtenir 255. `CWVoxelGenerator` ne l'appelle pas, et un test verrouille le
## raisonnement : sur une colonne de champ de hauteurs, la passe A rend bien 255
## sur tout ce qui est au-dessus du sol.
##
## L'eclairage sert donc **la ou le joueur a creuse**, et nulle part ailleurs.

## Pleine lumiere.
const FULL: int = 255

## Contribution minimale d'un voisin transparent, meme noir. L'ambiante.
const FLOOR: int = 5

## Attenuation par bloc, en centiemes : `lumiere * 85 / 100`.
const ATTENUATION_NUM: int = 85
const ATTENUATION_DEN: int = 100

## Nombre d'iterations de diffusion. Fixe aussi la portee de la lumiere, donc la
## marge a prevoir autour d'une zone qu'on veut publier juste.
const ITERATIONS: int = 16

## Rendu par `opaque_level` pour un bloc sans aucune face visible.
const BURIED: int = -1

## Type de bloc qui emet. Aucun index de `CWPalette` ne le porte encore : le
## bloc lumineux est un asset de donjon (jalon 4). Voir l'en-tete.
const SOURCE: int = -1


## Vrai si la lumiere traverse ce type de bloc.
##
## L'air et les deux eaux. C'est le `type == 0 || type == 2` de l'original, dont
## le second type est presque surement l'eau.
static func is_transparent(block_type: int) -> bool:
	return block_type == CWPalette.AIR or block_type == CWPalette.WATER \
			or block_type == CWPalette.WATER_DEEP


## Table `type -> 1 si transparent`, sur les 256 index possibles.
##
## Les passes visitent chaque voxel du pave — trente-six mille pour un simple
## coup de pioche — et un appel statique par visite se mesurait en millisecondes.
## La regle reste ecrite une seule fois, dans `is_transparent` ; ceci n'en est
## que la forme tabulee.
static func clear_table() -> PackedByteArray:
	if _clear.is_empty():
		_clear_mutex.lock()
		if _clear.is_empty():
			var t := PackedByteArray()
			t.resize(256)
			for i in 256:
				t[i] = 1 if is_transparent(i) else 0
			_clear = t
		_clear_mutex.unlock()
	return _clear


static var _clear: PackedByteArray = PackedByteArray()
static var _clear_mutex: Mutex = Mutex.new()


## Ce qu'un voisin apporte a la case courante, avant attenuation.
static func contribution(block_type: int, level: int) -> int:
	if block_type == SOURCE:
		return FULL
	if is_transparent(block_type):
		return maxi(level, FLOOR)
	return 0


## Attenuation d'un pas. Entiere et multiplicative, comme dans l'original :
## ecrire `level - 1` donnerait la rampe de Minecraft, pas cette decroissance.
static func attenuate(level: int) -> int:
	@warning_ignore("integer_division")
	var out: int = (level * ATTENUATION_NUM) / ATTENUATION_DEN
	return out


## Eclaire un pave dense de types de blocs, et rend un pave de niveaux.
##
## `types` est indexe **dans l'ordre natif de `VoxelBuffer`**, soit
## `y + size.y * (x + size.x * z)` : le Y d'abord, donc une colonne est
## contigue. Le resultat a la meme forme.
##
## Cet ordre n'est pas un gout : c'est celui que rend
## `VoxelBuffer.get_channel_as_byte_array`, verifie a la main sur un pave aux
## trois cotes distincts. S'y aligner, c'est passer le canal de types tel quel a
## la passe A au lieu de le recopier voxel par voxel — trente-six mille appels
## de moins pour un simple coup de pioche. La passe A y gagne deux fois, puisque
## la descente du soleil parcourt justement des colonnes.
##
## **La marge est a la charge de l'appelant.** La diffusion porte a
## `ITERATIONS` blocs : un pave publie sans marge est faux sur ses seize
## dernieres colonnes, parce que les voisins hors pave comptent pour zero. C'est
## exactement ce que fait l'original, qui calcule large et ne publie que
## l'interieur.
static func compute(types: PackedByteArray, size: Vector3i) -> PackedByteArray:
	var level := PackedByteArray()
	level.resize(types.size())
	var sx: int = size.x
	var sy: int = size.y
	var sz: int = size.z
	# Les trois pas, dans l'ordre natif du tampon : Y est contigu, X saute une
	# colonne, Z saute une tranche.
	var step_x: int = sy
	var step_z: int = sy * sx
	# La table plutot que `is_transparent` : l'appel statique par voxel se voyait
	# a la milliseconde sur un pave de trente-six mille cases.
	var clear: PackedByteArray = clear_table()

	# -- Passe A : la descente du soleil --------------------------------------
	for z in sz:
		for x in sx:
			var base: int = (x + sx * z) * sy
			var exposed: bool = true
			for k in sy:
				var i: int = base + sy - 1 - k
				if clear[types[i]] == 1:
					level[i] = FULL if exposed else 0
				else:
					exposed = false
					level[i] = 0

	# -- Passe B : la diffusion -----------------------------------------------
	# On ne parcourt que les cases transparentes qui ne sont pas deja pleines :
	# c'est l'optimisation de l'original (`byte2 != 0xff`), et elle est ce qui
	# rend la passe abordable — dans un monde a ciel ouvert, la quasi-totalite
	# de l'air est deja a 255 des la passe A et ne bouge plus.
	var work := PackedInt32Array()
	for z in sz:
		for x in sx:
			var base: int = (x + sx * z) * sy
			# Quels voisins horizontaux existent. Hors du pave, un voisin compte
			# pour zero — c'est ce qui rend les seize dernieres colonnes fausses et
			# ce qui oblige l'appelant a prevoir la marge. On retient le masque ici,
			# ou x et z sont connus, plutot que de les redecouper a chaque iteration.
			var mask: int = 0
			if x > 0:
				mask |= 1
			if x < sx - 1:
				mask |= 2
			if z > 0:
				mask |= 4
			if z < sz - 1:
				mask |= 8
			for y in sy:
				var i: int = base + y
				if clear[types[i]] == 1 and level[i] < FULL:
					work.append(i)
					work.append(mask)
	if work.is_empty():
		return level

	var count: int = work.size()
	for _pass in ITERATIONS:
		# Double tampon : sans lui, la lumiere avancerait de plusieurs blocs par
		# iteration dans le sens du parcours et d'un seul dans l'autre, et
		# l'eclairage dependrait de l'ordre de balayage.
		var next: PackedByteArray = level.duplicate()
		var k: int = 0
		while k < count:
			var i: int = work[k]
			var mask: int = work[k + 1]
			k += 2
			# Quatre voisins, jamais six : la diffusion est horizontale. Le vertical
			# est entierement traite par la passe A — ajouter ici un `i - 1` ou un
			# `i + 1` changerait l'eclairage du jeu entier.
			var m: int = 0
			if (mask & 1) != 0:
				m = contribution(types[i - step_x], level[i - step_x])
			if (mask & 2) != 0:
				m = maxi(m, contribution(types[i + step_x], level[i + step_x]))
			if (mask & 4) != 0:
				m = maxi(m, contribution(types[i - step_z], level[i - step_z]))
			if (mask & 8) != 0:
				m = maxi(m, contribution(types[i + step_z], level[i + step_z]))
			next[i] = attenuate(m)
		level = next
	return level


## Les cases dont la couleur rendue depend de la lumiere, et leur niveau.
##
## Rend des **paires plates** `(indice, niveau)` dans un `PackedInt32Array` :
## c'est la liste que le reeclairage a besoin de parcourir, et rien d'autre.
##
## -- Pourquoi une liste, et pas un balayage -----------------------------------
## La version directe demandait `opaque_level` sur **chaque** bloc plein du
## pave, soit dix-huit mille appels pour un coup de pioche, dont l'immense
## majorite sur de la roche enterree qui rend `BURIED` et qu'on jette. Ici on
## part des cases transparentes — dans une galerie, une poignee — et on **pousse**
## leur lumiere sur leurs voisins pleins. Un bloc sans face visible n'est jamais
## atteint, donc il ne coute rien du tout.
##
## Le resultat est le meme que `opaque_level` case par case : un test croise le
## verrouille, parce que deux implementations d'une meme regle finissent
## toujours par diverger si personne ne les compare.
static func shaded_cells(types: PackedByteArray, level: PackedByteArray,
		size: Vector3i) -> PackedInt32Array:
	var sx: int = size.x
	var sy: int = size.y
	var sz: int = size.z
	var step_x: int = sy
	var step_z: int = sy * sx
	var clear: PackedByteArray = clear_table()

	var out := PackedInt32Array()
	# Niveau retenu par bloc plein, `-1` tant que rien ne l'a touche. Un tableau
	# d'entiers plutot qu'un dictionnaire : l'allocation est unique et l'acces ne
	# hache rien. Il tient aussi lieu de marque de visite, ce qui evite un second
	# tableau — d'ou `-1` et non zero, qui est un niveau legitime.
	var want := PackedInt32Array()
	want.resize(types.size())
	want.fill(BURIED)

	for z in sz:
		for x in sx:
			var base: int = (x + sx * z) * sy
			for y in sy:
				var i: int = base + y
				var t: int = types[i]
				if clear[t] == 0:
					continue
				var lv: int = level[i]
				# L'eau est transparente **et** coloree : elle porte son propre
				# niveau. L'air n'a pas de couleur a assombrir.
				if t != CWPalette.AIR:
					out.append(i)
					out.append(lv)
				# Les six voisins, en ligne : la poussee ne peut pas passer par
				# une fonction, un `PackedArray` argument etant une copie que la
				# callee modifierait pour elle seule.
				if y > 0 and clear[types[i - 1]] == 0 and lv > want[i - 1]:
					want[i - 1] = lv
				if y < sy - 1 and clear[types[i + 1]] == 0 and lv > want[i + 1]:
					want[i + 1] = lv
				if x > 0 and clear[types[i - step_x]] == 0 and lv > want[i - step_x]:
					want[i - step_x] = lv
				if x < sx - 1 and clear[types[i + step_x]] == 0 and lv > want[i + step_x]:
					want[i + step_x] = lv
				if z > 0 and clear[types[i - step_z]] == 0 and lv > want[i - step_z]:
					want[i - step_z] = lv
				if z < sz - 1 and clear[types[i + step_z]] == 0 and lv > want[i + step_z]:
					want[i + step_z] = lv

	for i in want.size():
		var lv: int = want[i]
		if lv != BURIED:
			out.append(i)
			out.append(lv)
	return out


## Niveau a appliquer a un bloc **opaque** : le maximum de ses six voisins.
##
## -- Une approximation, et il faut la connaitre -------------------------------
## L'original eclaire **chaque face** par la case transparente qui lui fait
## face : le mailleur lit la lumiere du voisin au moment de poser le quad. Ici
## `VoxelMesherCubes` ne pose qu'**une couleur par voxel** — il n'y a pas de
## place pour six valeurs. On prend donc le maximum des six voisins.
##
## Ce que ca donne : la face du dessus, qui est celle qu'on voit sur un terrain,
## est juste ; un mur de galerie eclaire d'un cote l'est sur ses deux faces.
## C'est plus clair que la realite, jamais plus sombre — le defaut va donc dans
## le sens ou il se remarque le moins. Le corriger demanderait un mailleur
## maison, ce qui n'est pas au programme.
##
## **Rend `BURIED` si le bloc n'a aucun voisin transparent.** Ce n'est pas la
## meme chose que « noir » : un bloc enterre n'a aucune face visible, donc sa
## couleur n'a aucune importance et il ne faut surtout pas la reecrire. La
## distinction vaut cher — sans elle, reeclairer une galerie noircissait
## quarante-huit mille blocs de roche que personne ne verra jamais.
static func opaque_level(types: PackedByteArray, level: PackedByteArray,
		size: Vector3i, x: int, y: int, z: int) -> int:
	var step_x: int = size.y
	var step_z: int = size.y * size.x
	var i: int = y + step_x * x + step_z * z
	var m: int = BURIED
	if y > 0 and is_transparent(types[i - 1]):
		m = maxi(m, level[i - 1])
	if y < size.y - 1 and is_transparent(types[i + 1]):
		m = maxi(m, level[i + 1])
	if x > 0 and is_transparent(types[i - step_x]):
		m = maxi(m, level[i - step_x])
	if x < size.x - 1 and is_transparent(types[i + step_x]):
		m = maxi(m, level[i + step_x])
	if z > 0 and is_transparent(types[i - step_z]):
		m = maxi(m, level[i - step_z])
	if z < size.z - 1 and is_transparent(types[i + step_z]):
		m = maxi(m, level[i + step_z])
	return m


## Couleur d'un index, assombrie par un niveau de lumiere.
##
## L'alpha ne bouge pas : c'est lui qui range l'eau dans la surface transparente
## du mailleur, et une eau qui devient opaque en profondeur serait un defaut
## bien plus visible que son assombrissement.
static func shade(index: int, level: int) -> int:
	if level >= FULL:
		return CWPalette.raw_of(index)
	var raw: int = CWPalette.raw_of(index)
	var r: int = (((raw >> 24) & 0xFF) * level) / FULL
	var g: int = (((raw >> 16) & 0xFF) * level) / FULL
	var b: int = (((raw >> 8) & 0xFF) * level) / FULL
	return (r << 24) | (g << 16) | (b << 8) | (raw & 0xFF)
