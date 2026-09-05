class_name CWWorldEdits
extends RefCounted

## Edition du terrain et persistance des modifications (jalon 1.8).
##
## -- Ce qui est porte, et ce qui ne l'est pas ---------------------------------
## L'original tient le monde en **colonnes persistantes** : une grille de chunks
## de 256 x 256 colonnes, chaque colonne etant un enregistrement de 32 octets qui
## pointe une suite contigue de blocs de 4 octets a partir d'une altitude de base
## (`Chunk_getColumnAt` @00406100, `Column_getBlockChecked` @00405f20). Editer,
## c'est ecrire dans cette suite, et la faire grandir si l'on sort par le haut ou
## par le bas (`VoxelColumn_setBlock` @0041fe60). Analyse : `docs/systems/03`.
##
## Voxel Tools tient deja exactement ce role, mieux et en natif : blocs de
## donnees, pagination, fils, et un `VoxelStream` pour le disque. On ne reecrit
## donc pas la structure — ce serait porter une implementation, pas un
## algorithme. Ce qui se porte ici, ce sont les **regles** que la structure
## d'origine impose et qu'aucun moteur ne devine :
##
##   1. **l'eau n'est pas de la matiere, c'est le vide sous le niveau de la
##      mer.** `World_getBlockAt` ne lit jamais un bloc d'eau : au-dessus de la
##      colonne il rend un temoin d'eau si `z <= 0`, un temoin d'air sinon. Creuser
##      sous le niveau de la mer rend donc de l'eau, pas un trou — c'est
##      `erase_value`, et c'est la seule regle d'edition que la source donne
##      explicitement ;
##   2. **le monde est borne** a `[0, 0x1000000)` sur X et Z, soit exactement
##      `CWWorldParams.WORLD_SIZE`. Une edition hors bornes n'est pas une erreur,
##      elle est sans effet — l'original rend un pointeur nul et poursuit.
##
## -- Ce que l'original a et que la palette ne peut pas porter ------------------
## Un bloc d'origine fait 4 octets : trois de couleur **RVB** et un d'attributs
## (type sur 5 bits, drapeau 0x40, protection 0x80). Le projet stocke un *index*
## de palette sur un octet. Deux consequences :
##
##   * la **protection** (0x80), qui empeche la generation d'effacer un bloc pose
##     par une structure, n'a pas ou se ranger. Elle n'a pas encore de producteur
##     non plus — maisons et donjons sont au jalon 4 — donc reserver un second
##     canal maintenant couterait de la memoire pour rien. Le jour ou 4.2 arrive,
##     c'est `VoxelBuffer.CHANNEL_DATA2` qui l'accueille ;
##   * la couleur par bloc explique peut-etre la **dalle d'eau du LOD 1**
##     (`docs/ROADMAP.md`) : une couleur RVB survit a une moyenne, un index de
##     palette non. C'est une piste, pas une demonstration.
##
## -- Le sol du monde -----------------------------------------------------------
## `floor_y` n'est pas porte : l'original borne X et Z mais son axe vertical est
## celui de la colonne, qui grandit vers le bas a la demande. Ici le terrain a des
## bornes fixes, et laisser creuser la derniere couche ferait tomber hors du
## monde. C'est une decision de ce projet, signalee comme telle.

## Rayon maximal, en blocs, d'un coup de pioche ou de pose.
const REACH: float = 8.0

## Rendu par `edited_top` pour une colonne que personne n'a touchee.
const NOT_EDITED: int = 0x7FFFFFFF

## Profondeur maximale du balayage qui cherche le nouveau sol apres un coup de
## pioche. Borne : creuser le fond d'un puits ne doit pas couter un parcours de
## toute la colonne. Au-dela, la colonne est declaree sans sol et sa flore tombe.
const TOP_SCAN_MAX: int = 96


var _tool: VoxelTool = null
var _generator: CWVoxelGenerator = null
var _params: CWWorldParams = null
## Altitude sous laquelle rien ne se creuse. Voir la note d'en-tete.
var _floor_y: int = -2147483648
## Nombre d'editions appliquees depuis le demarrage. Pour l'ATH et les tests.
var edit_count: int = 0

## Sommet plein de chaque colonne editee. Vide au demarrage : une colonne absente
## d'ici est intacte, et la flore s'y pose sur le relief genere comme avant.
##
## -- Attention : cette table est en coordonnees **monde** ---------------------
## Tout le reste de cette classe est en coordonnees de scene, comme `VoxelTool`.
## La table, elle, est lue par `CWScatter`, qui travaille en coordonnees monde —
## `Placement.x` est un point du monde d'origine, pas de la scene. La conversion
## se fait donc a l'ecriture, dans `_set_top`, et nulle part ailleurs.
##
## Ce n'est pas une precaution theorique : la premiere version gardait la table
## en coordonnees de scene, la recherche ne tombait jamais juste, et la flore
## continuait de flotter au-dessus des crateres sans qu'aucun test ne bronche —
## les deux cotes du test employaient le meme repere, donc il passait au vert.
##
## -- Pourquoi une table, et pas une requete ------------------------------------
## La flore est construite sur des fils du pool (`CWFloraRenderer`), et un
## `VoxelTool` ne se lit pas depuis un autre fil pendant que le fil principal
## edite. Le sommet est donc calcule **au moment de l'edition**, sur le fil
## principal, et range ici ; la dispersion n'a plus qu'a consulter un
## dictionnaire, ce qui ne coute rien et ne touche pas au terrain.
var _tops: Dictionary = {}
var _tops_mutex: Mutex = Mutex.new()

## Cellules de dispersion dont la flore est a refaire. Vidangees par le rendu.
var _dirty_cells: Dictionary = {}

## Pave englobant les blocs edites depuis le dernier reeclairage, en coordonnees
## de scene. Vide quand il n'y a rien a refaire.
var _relight_box: AABB = AABB()
var _relight_pending: bool = false
## Duree du dernier reeclairage, en microsecondes. Pour l'ATH et les tests.
var last_relight_usec: int = 0


func setup(terrain: Node, generator: CWVoxelGenerator, floor_y: int) -> void:
	_generator = generator
	_params = generator.field().params()
	_floor_y = floor_y
	if terrain != null and terrain.has_method("get_voxel_tool"):
		_tool = terrain.get_voxel_tool()
		# L'outil travaille sur le canal **semantique** : c'est lui qui dit ce
		# qu'est un bloc. La couleur suit, ecrite par `_write`.
		_tool.channel = CWPalette.CHANNEL_TYPE
		_tool.mode = VoxelTool.MODE_SET


func has_tool() -> bool:
	return _tool != null


## Valeur laissee en place par un effacement a l'altitude `y`.
##
## **La regle portee.** `World_getBlockAt` @00405fd0 : au-dessus de la matiere
## d'une colonne, le bloc rendu est un temoin d'eau quand `z < 1` et un temoin
## d'air sinon — le niveau de la mer de l'original etant `z = 0`, ce qui est aussi
## la valeur de `CWWorldParams.sea_level`. La meme fonction rabat sur le temoin
## d'eau un bloc *stocke* dont le type est nul sous la meme altitude. Autrement
## dit : sous le niveau de la mer, il n'y a pas de vide, il y a de l'eau.
##
## Creuser une tranchee depuis la plage la remplit donc, et c'est le comportement
## d'origine, pas une facilite ajoutee ici.
static func erase_value(y: int, sea: int) -> int:
	if y > sea:
		return CWPalette.AIR
	return CWPalette.water_index(float(sea - y))


## Vrai si `index` est de la matiere qu'on peut traverser et remplacer.
static func is_open(index: int) -> bool:
	return index == CWPalette.AIR or index == CWPalette.WATER \
			or index == CWPalette.WATER_DEEP


## Bloc present a ce point, editions comprises, en coordonnees de scene.
##
## C'est la primitive de requete du jalon — celle dont les collisions du jalon 2
## auront besoin. Elle rend l'etat *courant* du monde : le bloc charge s'il l'est,
## sinon ce que le generateur y mettrait.
##
## Portage de `World_getBlockAt` @00405fd0, y compris son parti pris : hors du
## monde charge, on ne se plaint pas, on repond ce que le champ decrit.
func voxel_at(x: int, y: int, z: int) -> int:
	if not in_world(x, z):
		return CWPalette.AIR
	if _tool != null:
		var at := Vector3i(x, y, z)
		if _tool.is_area_editable(AABB(Vector3(at), Vector3.ONE)):
			return _tool.get_voxel(at)
	return _generator.generated_voxel(x, y, z)


## Couleur rendue stockee en un point. Pour l'inspection et les tests : c'est la
## valeur que le mailleur lira, lumiere comprise.
func raw_color_at(x: int, y: int, z: int) -> int:
	if _tool == null:
		return 0
	var at := Vector3i(x, y, z)
	if not _tool.is_area_editable(AABB(Vector3(at), Vector3.ONE)):
		return 0
	_tool.channel = CWPalette.CHANNEL_COLOR
	var v: int = _tool.get_voxel(at)
	_tool.channel = CWPalette.CHANNEL_TYPE
	return v


## Vrai si la colonne est dans le monde. Bornes de `Chunk_getColumnAt` : les
## coordonnees monde tiennent dans `[0, 0x1000000)`, soit `WORLD_SIZE`.
func in_world(x: int, z: int) -> bool:
	var wx: int = _params.world_origin.x + x
	var wz: int = _params.world_origin.y + z
	return wx >= 0 and wz >= 0 \
			and wx < CWWorldParams.WORLD_SIZE and wz < CWWorldParams.WORLD_SIZE


## Creuse un bloc. Rend la valeur laissee en place, ou -1 si rien n'a ete fait.
func dig(at: Vector3i) -> int:
	if _tool == null or not in_world(at.x, at.z):
		return -1
	if at.y <= _floor_y:
		return -1
	if not _tool.is_area_editable(AABB(Vector3(at), Vector3.ONE)):
		return -1
	if is_open(_tool.get_voxel(at)):
		return -1
	var left: int = erase_value(at.y, _params.sea_level)
	_write(at, left)
	edit_count += 1
	# Le sol de la colonne a pu descendre : si c'est lui qu'on vient d'oter, on
	# cherche le suivant sous lui. Sinon on a creuse une galerie sous un toit
	# intact, et le sommet ne bouge pas.
	if at.y >= _top_of(at.x, at.z):
		_set_top(at.x, at.z, _scan_top_below(at.x, at.y - 1, at.z))
	_touch_light(at)
	return left


## Pose un bloc. Rend vrai si quelque chose a change.
##
## Poser ne remplace que du vide ou de l'eau : sans cette garde, un clic sur une
## face deja pleine remplacerait la matiere visee au lieu de se poser devant, ce
## qui est desorientant et n'est pas ce que fait l'original.
func place(at: Vector3i, index: int) -> bool:
	if _tool == null or not in_world(at.x, at.z):
		return false
	if not _tool.is_area_editable(AABB(Vector3(at), Vector3.ONE)):
		return false
	if not is_open(_tool.get_voxel(at)):
		return false
	_write(at, index)
	edit_count += 1
	if not is_open(index) and at.y > _top_of(at.x, at.z):
		_set_top(at.x, at.z, at.y)
	_touch_light(at)
	return true


## Ecrit un bloc : l'index dans le canal semantique, sa couleur dans le canal de
## rendu. Les deux, toujours, et au meme endroit — un terrain dont la couleur ne
## suit plus le type est un monde qui ment a l'oeil sans qu'aucun test de logique
## ne s'en apercoive.
func _write(at: Vector3i, index: int) -> void:
	_tool.channel = CWPalette.CHANNEL_TYPE
	_tool.value = index
	_tool.do_point(at)
	_tool.channel = CWPalette.CHANNEL_COLOR
	_tool.value = CWPalette.raw_of(index)
	_tool.do_point(at)
	_tool.channel = CWPalette.CHANNEL_TYPE


## Premier bloc plein sur un rayon, ou null. `previous_position` donne la case
## vide devant lui, celle ou se pose un bloc.
func raycast(origin: Vector3, direction: Vector3,
		reach: float = REACH) -> VoxelRaycastResult:
	if _tool == null:
		return null
	return _tool.raycast(origin, direction, reach)


# -- Le sol des colonnes editees ----------------------------------------------
#
# Creuser sous une touffe d'herbe la laisse en l'air : la flore est instanciee a
# partir du relief *genere*, que l'edition ne change pas. C'est la consequence
# connue de la sortie de la flore des donnees voxels (2026-09-04), et elle se
# voit des qu'on creuse. Ce qui suit est ce qu'il faut pour que la dispersion
# s'en apercoive sans rien payer sur son chemin chaud.


## Sommet plein d'une colonne editee, ou `NOT_EDITED` si personne n'y a touche.
##
## **Coordonnees monde**, pas coordonnees de scene : l'appelant est `CWScatter`.
##
## Sur pour plusieurs fils : c'est `CWScatter._build_cell` qui appelle, depuis un
## fil du pool, pendant que le fil principal edite.
func edited_top(wx: int, wz: int) -> int:
	if _tops.is_empty():
		return NOT_EDITED
	_tops_mutex.lock()
	var v: Variant = _tops.get(Vector2i(wx, wz))
	_tops_mutex.unlock()
	return NOT_EDITED if v == null else int(v)


## Cellules de dispersion touchees depuis le dernier appel. Le rendu les vide et
## reconstruit ce qu'il faut ; passer par un lot evite de refaire une cellule
## entiere a chacun des centaines de blocs d'un meme coup de pioche.
func take_dirty_cells() -> Array:
	if _dirty_cells.is_empty():
		return []
	var out: Array = _dirty_cells.keys()
	_dirty_cells.clear()
	return out


## Sommet courant d'une colonne : la valeur editee si elle existe, sinon celle du
## relief genere. Le resultat est memorise, donc une colonne creusee de haut en
## bas ne repaie pas l'echantillonnage a chaque bloc.
func _top_of(x: int, z: int) -> int:
	var known: int = edited_top(
			_params.world_origin.x + x, _params.world_origin.y + z)
	if known != NOT_EDITED:
		return known
	var f: CWTerrainField = _generator.field()
	var c: Vector3 = f.sample_column(
			_params.world_origin.x + x, _params.world_origin.y + z)
	return floori(c.x)


## `x` et `z` sont en coordonnees de scene ; la table et les cellules sales sont
## en coordonnees monde. C'est ici, et seulement ici, que la conversion a lieu.
func _set_top(x: int, z: int, y: int) -> void:
	var wx: int = _params.world_origin.x + x
	var wz: int = _params.world_origin.y + z
	_tops_mutex.lock()
	_tops[Vector2i(wx, wz)] = y
	_tops_mutex.unlock()
	_dirty_cells[Vector2i(CWScatter.cell_of(wx), CWScatter.cell_of(wz))] = true


## Premier bloc plein a `y_from` ou en dessous. Rend `_floor_y` si le balayage
## n'en trouve pas : une colonne sans sol ne porte plus rien.
func _scan_top_below(x: int, y_from: int, z: int) -> int:
	var y: int = y_from
	var limit: int = maxi(_floor_y, y_from - TOP_SCAN_MAX)
	while y > limit:
		if not is_open(voxel_at(x, y, z)):
			return y
		y -= 1
	return _floor_y


# -- Reeclairage local --------------------------------------------------------
#
# Le terrain genere n'a ni grotte ni surplomb : la descente du soleil y rend
# « 255 partout au-dessus du sol », et le generateur n'appelle donc jamais
# l'eclairage (`CWLight`, en-tete). C'est **l'edition** qui cree de l'ombre, et
# c'est ici qu'on la calcule.
#
# Le pave a refaire est accumule pendant la frame et traite d'un coup : un
# cratere de six cents coups de pioche ne demande qu'un reeclairage, pas six
# cents. Sans cela le cout serait celui du pave entier, multiplie par le nombre
# de blocs touches.


func _touch_light(at: Vector3i) -> void:
	var p := Vector3(at)
	if _relight_pending:
		_relight_box = _relight_box.expand(p)
	else:
		_relight_box = AABB(p, Vector3.ZERO)
		_relight_pending = true


## Vrai s'il reste un pave a reeclairer.
func has_relight_pending() -> bool:
	return _relight_pending


## Recalcule la lumiere autour des editions accumulees et reecrit les couleurs.
##
## La marge de `CWLight.ITERATIONS` n'est pas facultative : la diffusion porte a
## seize blocs, et un pave calcule sans marge est faux sur ses seize dernieres
## colonnes — les voisins hors pave y comptent pour zero. On calcule donc large
## et on ne reecrit que ce qui a change.
func relight() -> int:
	if not _relight_pending or _tool == null:
		return 0
	_relight_pending = false
	var t0: int = Time.get_ticks_usec()

	var m: int = CWLight.ITERATIONS
	var lo := Vector3i(_relight_box.position) - Vector3i(m, m, m)
	var hi := Vector3i(_relight_box.position + _relight_box.size) + Vector3i(m, m, m)
	var size: Vector3i = hi - lo + Vector3i.ONE
	if not _tool.is_area_editable(AABB(Vector3(lo), Vector3(size))):
		return 0

	# Les deux canaux d'un coup : les types pour calculer, les couleurs pour
	# savoir lesquelles ont vraiment bouge.
	#
	# Les profondeurs se posent **avant** `create` : un tampon deja cree garde la
	# sienne, et un canal de types en seize bits sortirait sur deux octets par
	# voxel, ce qui decalerait toute la lecture en bloc qui suit.
	var mask: int = (1 << CWPalette.CHANNEL_TYPE) | (1 << CWPalette.CHANNEL_COLOR)
	var buf := VoxelBuffer.new()
	buf.set_channel_depth(CWPalette.CHANNEL_TYPE, VoxelBuffer.DEPTH_8_BIT)
	buf.set_channel_depth(CWPalette.CHANNEL_COLOR, CWPalette.COLOR_DEPTH)
	buf.create(size.x, size.y, size.z)
	_tool.copy(lo, buf, mask)

	# Les canaux entiers d'un seul appel, au lieu d'un `get_voxel` par voxel :
	# trente-six mille appels pour un simple coup de pioche, et c'etait le poste
	# dominant du reeclairage. La disposition est celle de `VoxelBuffer` — Y
	# d'abord —, et `CWLight` est ecrit dans cet ordre exactement pour que le
	# canal se passe tel quel.
	var count: int = size.x * size.y * size.z
	var types: PackedByteArray = buf.get_channel_as_byte_array(CWPalette.CHANNEL_TYPE)
	var colors: PackedByteArray = buf.get_channel_as_byte_array(CWPalette.CHANNEL_COLOR)
	if types.size() != count or colors.size() != count * 4:
		# Une profondeur de canal a change sous nos pieds. Mieux vaut ne rien
		# reecrire que repeindre le monde de travers.
		push_error("CWWorldEdits.relight : disposition de canal inattendue (%d, %d)"
				% [types.size(), colors.size()])
		return 0

	var level: PackedByteArray = CWLight.compute(types, size)

	# On ne reecrit que ce qui change, et on compare a la couleur **stockee** et
	# non a celle de la palette : une case rouverte sur le ciel doit retrouver sa
	# pleine couleur, ce qu'une comparaison a `raw_of` seule ne verrait jamais.
	#
	# La liste ne contient que les cases dont la couleur depend de la lumiere :
	# ni l'air, ni la roche enterree. C'est ce qui evite de sonder chaque bloc
	# plein du pave — dix-huit mille appels, dont l'immense majorite pour
	# apprendre qu'un bloc n'a aucune face visible.
	var cells: PackedInt32Array = CWLight.shaded_cells(types, level, size)
	var written: int = 0
	var ch: int = CWPalette.CHANNEL_COLOR
	_tool.channel = ch
	var sy: int = size.y
	var sxy: int = size.y * size.x
	var k: int = 0
	var n: int = cells.size()
	while k < n:
		var i: int = cells[k]
		var lvl: int = cells[k + 1]
		k += 2
		var want: int = CWLight.shade(types[i], lvl)
		if colors.decode_u32(i * 4) == want:
			continue
		# Retour de l'indice aux coordonnees, dans l'ordre du tampon : Y est
		# contigu, donc c'est lui le reste, et la colonne le quotient.
		@warning_ignore("integer_division")
		var col: int = i / sy
		@warning_ignore("integer_division")
		var cz: int = i / sxy
		_tool.value = want
		_tool.do_point(Vector3i(lo.x + col % size.x, lo.y + i % sy, lo.z + cz))
		written += 1
	_tool.channel = CWPalette.CHANNEL_TYPE
	last_relight_usec = Time.get_ticks_usec() - t0
	return written
