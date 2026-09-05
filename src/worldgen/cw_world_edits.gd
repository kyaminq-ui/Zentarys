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


var _tool: VoxelTool = null
var _generator: CWVoxelGenerator = null
var _params: CWWorldParams = null
## Altitude sous laquelle rien ne se creuse. Voir la note d'en-tete.
var _floor_y: int = -2147483648
## Nombre d'editions appliquees depuis le demarrage. Pour l'ATH et les tests.
var edit_count: int = 0


func setup(terrain: Node, generator: CWVoxelGenerator, floor_y: int) -> void:
	_generator = generator
	_params = generator.field().params()
	_floor_y = floor_y
	if terrain != null and terrain.has_method("get_voxel_tool"):
		_tool = terrain.get_voxel_tool()
		_tool.channel = VoxelBuffer.CHANNEL_COLOR
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
	_tool.value = left
	_tool.do_point(at)
	edit_count += 1
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
	_tool.value = index
	_tool.do_point(at)
	edit_count += 1
	return true


## Premier bloc plein sur un rayon, ou null. `previous_position` donne la case
## vide devant lui, celle ou se pose un bloc.
func raycast(origin: Vector3, direction: Vector3,
		reach: float = REACH) -> VoxelRaycastResult:
	if _tool == null:
		return null
	return _tool.raycast(origin, direction, reach)
