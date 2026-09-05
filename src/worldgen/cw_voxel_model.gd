class_name CWVoxelModel
extends RefCounted

## Un modele .vox prepare pour etre pose dans le monde.
##
## -- Les deux grilles ---------------------------------------------------------
## Le terrain a un pas d'un bloc ; les modeles ont un pas treize fois plus fin
## (VOXELS_PER_BLOCK). C'est cette difference qui distingue le rendu vise de
## celui de Minecraft : de gros cubes de terrain, mais du detail sur ce qui est
## pose dessus — une touffe d'herbe est faite de lames d'un voxel d'epaisseur,
## un personnage de 2 blocs a des yeux d'un voxel. Mesure et justification dans
## `assets/models/MODELS.md`, §1.
##
## Un modele fin ne peut donc pas etre ecrit dans les donnees voxels du monde :
## il est maille a part (`mesh()`) et instancie a l'echelle 1 / VOXELS_PER_BLOCK.
## Les offsets creux ci-dessous servent a ce maillage, et restent utilisables
## tels quels pour un futur modele a l'echelle du terrain, qui lui s'estampe.
##
## Le chargeur rend un VoxelBuffer dense ; un modele de flore n'en remplit que
## quelques pour cent (80 voxels pleins sur 1960 pour `herbe_01`). On le
## convertit donc en liste creuse, et on precalcule les quatre quarts de tour
## autour de Y.
##
## Repere. Les offsets sont relatifs a l'**ancre** : centre du gabarit au sol
## sur X et Z, base de la matiere sur Y. Poser une plante revient donc a donner
## la colonne (x, z) et l'altitude du premier bloc d'air au-dessus du sol.
##
## Permutation d'axes : `VoxelVoxLoader` rend deja un tampon oriente Godot
## (vox(x, y, z) -> godot(y, z, x), cf. assets/palette/PALETTE.md). Rien a
## compenser ici ; c'est dans MagicaVoxel que le modele doit etre debout.

const ROTATIONS: int = 4

## Voxels de modele dans un bloc de terrain. **Contrat d'authoring** : le
## changer redimensionne tous les modeles deja dessines. Voir MODELS.md, §1.
##
## Valeur de l'original, relevee le 2026-09-05 : les echelles d'instanciation du
## decor y sont 0.075, 0.09 et 0.1, et **0.075 = 3/40 exactement**, soit 40/3
## voxels par bloc. Ecrire 13.333 ferait deriver le rapport ; c'est la fraction
## qui est ecrite ici.
##
## Consequence d'authoring : on ne peut pas dessiner un cube de reference d'un
## bloc, il n'est pas entier. La reference posee dans MagicaVoxel est donc
## **3 blocs = 40 voxels**, et le personnage de reference fait 32 voxels, soit
## 2,4 blocs — ce qui recoupe les 2,3 blocs mesures au pixel sur une capture du
## jeu d'origine (MODELS.md, §1).
##
## A ne pas confondre avec `CWScatter.SUBBLOCK_STEPS`, qui est la finesse de
## *position* d'une plante sous son bloc : une grille entiere, sans rapport avec
## celle du dessin.
const VOXELS_PER_BLOCK: float = 40.0 / 3.0

## Marge d'air autour de la matiere dans le tampon de maillage. Le mailleur en
## cubes a besoin de voir du vide sur le pourtour, sinon il ferme les faces de
## bord et le modele sort creux.
const MESH_MARGIN: int = 2

var name: String = ""
var path: String = ""
## Gabarit de la matiere, en voxels de modele.
var extent: Vector3i = Vector3i.ZERO
## Rayon horizontal, en voxels : de combien la plante deborde de son axe.
var radius: int = 0
var height: int = 0
var voxel_count: int = 0
## Les deux memes mesures, arrondies au bloc superieur. C'est dans cette unite
## que raisonnent la dispersion et le terrain.
var radius_blocks: int = 0
var height_blocks: int = 0

# Offsets par rotation, en tableaux paralleles. Indexes par le quart de tour.
var _dx: Array[PackedInt32Array] = []
var _dy: Array[PackedInt32Array] = []
var _dz: Array[PackedInt32Array] = []
var _v: Array[PackedByteArray] = []

# Maillage, construit au premier besoin.
var _mesh: ArrayMesh = null
var _mesh_offset: Vector3 = Vector3.ZERO

static var _mesher: VoxelMesherCubes = null


## Charge un `.vox` et le prepare. Rend `null` si le fichier manque ou est vide.
##
## `model_name` nomme le modele dans les traces et les tests. Par defaut le nom
## de fichier, ce qui ne suffit plus depuis que les modeles sont ranges par
## biome : trois dossiers portent un `caillou_01`, et ce sont trois modeles
## differents. `CWModelLibrary` passe donc le chemin relatif, biome compris.
static func load_from(model_path: String, palette: Resource,
		model_name: String = "") -> CWVoxelModel:
	if not ResourceLoader.exists(model_path) and not FileAccess.file_exists(model_path):
		return null
	var buffer := VoxelBuffer.new()
	# `load_from_file` est statique : l'appeler sur une instance marche mais
	# alloue un chargeur pour rien, et Godot le signale.
	if VoxelVoxLoader.load_from_file(model_path, buffer, palette,
			VoxelBuffer.CHANNEL_COLOR) != OK:
		return null

	var m := CWVoxelModel.new()
	m.path = model_path
	m.name = model_name if model_name != "" else model_path.get_file().get_basename()

	var size: Vector3i = buffer.get_size()
	var lo := Vector3i(size)
	var hi := Vector3i(-1, -1, -1)
	for y in size.y:
		for z in size.z:
			for x in size.x:
				if buffer.get_voxel(x, y, z, VoxelBuffer.CHANNEL_COLOR) == CWPalette.AIR:
					continue
				lo = lo.min(Vector3i(x, y, z))
				hi = hi.max(Vector3i(x, y, z))
	if hi.x < lo.x:
		return null

	m.extent = hi - lo + Vector3i.ONE
	m.height = m.extent.y
	# Ancre au centre du gabarit : une plante posee en (x, z) doit deborder
	# autant d'un cote que de l'autre, sinon la dispersion est biaisee.
	@warning_ignore("integer_division")
	var anchor := Vector3i(lo.x + m.extent.x / 2, lo.y, lo.z + m.extent.z / 2)

	var bx := PackedInt32Array()
	var by := PackedInt32Array()
	var bz := PackedInt32Array()
	var bv := PackedByteArray()
	for y in range(lo.y, hi.y + 1):
		for z in range(lo.z, hi.z + 1):
			for x in range(lo.x, hi.x + 1):
				var value: int = buffer.get_voxel(x, y, z, VoxelBuffer.CHANNEL_COLOR)
				if value == CWPalette.AIR:
					continue
				bx.append(x - anchor.x)
				by.append(y - anchor.y)
				bz.append(z - anchor.z)
				bv.append(value)
	m.voxel_count = bv.size()

	m._dx.resize(ROTATIONS)
	m._dy.resize(ROTATIONS)
	m._dz.resize(ROTATIONS)
	m._v.resize(ROTATIONS)
	for r in ROTATIONS:
		var rx := PackedInt32Array()
		var rz := PackedInt32Array()
		rx.resize(m.voxel_count)
		rz.resize(m.voxel_count)
		for i in m.voxel_count:
			var p: Vector2i = _turn(bx[i], bz[i], r)
			rx[i] = p.x
			rz[i] = p.y
			m.radius = maxi(m.radius, maxi(absi(p.x), absi(p.y)))
		m._dx[r] = rx
		m._dy[r] = by
		m._dz[r] = rz
		m._v[r] = bv
	m._derive()
	return m


## Copie reduite d'un facteur entier, par union : un voxel de sortie est plein
## des qu'un voxel de la cellule source l'est.
##
## Une reduction par moyenne effacerait le modele — la flore est faite de lames
## d'un seul voxel d'epaisseur, qui sont minoritaires dans n'importe quelle
## cellule. L'union garde la silhouette, ce qui est tout ce qu'on lui demande.
##
## Destinee au LOD des modeles instancies : au-dela de quelques dizaines de
## blocs, une plante ne couvre plus assez de pixels pour que ses lames se
## distinguent, et un maillage reduit d'un facteur 2 ou 4 rend la meme image
## pour une fraction des triangles. Le rapport etant une puissance de deux, la
## reduction tombe juste. Pas encore branchee sur le rendu.
func reduced(factor: int) -> CWVoxelModel:
	if factor <= 1:
		return self
	var out := CWVoxelModel.new()
	out.path = path
	out.name = "%s/%d" % [name, factor]

	# On repasse par une grille dense : c'est le seul moyen de dedupliquer les
	# voxels qui tombent dans la meme cellule, et le modele est petit.
	var cells: Dictionary = {}
	var src_x: PackedInt32Array = _dx[0]
	var src_y: PackedInt32Array = _dy[0]
	var src_z: PackedInt32Array = _dz[0]
	var src_v: PackedByteArray = _v[0]
	for i in src_v.size():
		var key := Vector3i(
				floori(float(src_x[i]) / float(factor)),
				floori(float(src_y[i]) / float(factor)),
				floori(float(src_z[i]) / float(factor)))
		if not cells.has(key):
			cells[key] = src_v[i]

	var lo := Vector3i(0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF)
	var hi := Vector3i(-0x7FFFFFFF, -0x7FFFFFFF, -0x7FFFFFFF)
	for key in cells:
		lo = lo.min(key)
		hi = hi.max(key)
	out.extent = hi - lo + Vector3i.ONE
	out.height = out.extent.y

	var bx := PackedInt32Array()
	var by := PackedInt32Array()
	var bz := PackedInt32Array()
	var bv := PackedByteArray()
	for key in cells:
		bx.append(key.x)
		# L'ancre reste au sol : la base du modele reduit doit poser au meme
		# endroit que celle de l'original, pas flotter d'un demi-facteur.
		by.append(key.y - lo.y)
		bz.append(key.z)
		bv.append(cells[key])
	out.voxel_count = bv.size()

	out._dx.resize(ROTATIONS)
	out._dy.resize(ROTATIONS)
	out._dz.resize(ROTATIONS)
	out._v.resize(ROTATIONS)
	for r in ROTATIONS:
		var rx := PackedInt32Array()
		var rz := PackedInt32Array()
		rx.resize(out.voxel_count)
		rz.resize(out.voxel_count)
		for i in out.voxel_count:
			var q: Vector2i = _turn(bx[i], bz[i], r)
			rx[i] = q.x
			rz[i] = q.y
			out.radius = maxi(out.radius, maxi(absi(q.x), absi(q.y)))
		out._dx[r] = rx
		out._dy[r] = by
		out._dz[r] = rz
		out._v[r] = bv
	out._derive()
	return out


## Mesures derivees, une fois les offsets en place.
func _derive() -> void:
	radius_blocks = ceili(float(radius) / VOXELS_PER_BLOCK)
	height_blocks = ceili(float(height) / VOXELS_PER_BLOCK)


## Maillage du modele, construit une fois et garde.
##
## Meme mailleur, meme palette et meme materiau que le terrain : c'est ce qui
## fait que les deux grilles se ressemblent au lieu de se voir. Rend `null` pour
## un modele vide.
func mesh() -> ArrayMesh:
	if _mesh != null or voxel_count == 0:
		return _mesh

	var dx: PackedInt32Array = _dx[0]
	var dy: PackedInt32Array = _dy[0]
	var dz: PackedInt32Array = _dz[0]
	var values: PackedByteArray = _v[0]

	var lo := Vector3i(0x7FFFFFFF, 0x7FFFFFFF, 0x7FFFFFFF)
	for i in voxel_count:
		lo = lo.min(Vector3i(dx[i], dy[i], dz[i]))

	var m: int = MESH_MARGIN
	# Le modele est range en index de palette ; le mailleur, lui, lit desormais
	# une couleur (`COLOR_RAW`). La conversion se fait ici, au dernier moment :
	# c'est ce qui garde les `.vox` et leurs plages de palette comme unique
	# contrat d'authoring — un modele reste peint dans le nuancier du projet, et
	# personne n'a a connaitre l'encodage du canal de rendu.
	var ch: int = CWPalette.CHANNEL_COLOR
	var buf := VoxelBuffer.new()
	buf.set_channel_depth(ch, CWPalette.COLOR_DEPTH)
	buf.create(extent.x + m * 2, extent.y + m * 2, extent.z + m * 2)
	buf.fill(CWPalette.raw_of(CWPalette.AIR), ch)
	for i in voxel_count:
		buf.set_voxel(CWPalette.raw_of(values[i]), dx[i] - lo.x + m,
				dy[i] - lo.y + m, dz[i] - lo.z + m, ch)

	# Le maillage ne sort pas en coordonnees du tampon : le mailleur consomme sa
	# marge de remplissage et son origine tombe sur le premier voxel utile, donc
	# a `get_minimum_padding()` du bord. Sans ce terme, tout ce qui est instancie
	# est enterre d'un voxel — assez peu pour rester plausible a l'oeil, ce qui
	# est exactement la raison de le mesurer dans les tests.
	var pad: int = _shared_mesher().get_minimum_padding()
	_mesh_offset = Vector3(
			float(lo.x - m + pad), float(lo.y - m + pad), float(lo.z - m + pad))
	var mat: Material = CWPalette.build_opaque_material()
	_mesh = _shared_mesher().build_mesh(buf, [mat, mat], {}) as ArrayMesh
	return _mesh


## Decalage, en voxels de modele, du repere du maillage par rapport a l'ancre.
## Construit le maillage si besoin : le decalage en sort, et le lire avant
## serait un piege d'ordonnancement pour rien.
func mesh_offset() -> Vector3:
	if _mesh == null:
		mesh()
	return _mesh_offset


## Marge que le mailleur consomme sur le pourtour d'un tampon. Un maillage
## construit a la main doit la retrancher de ses coordonnees, sinon il est pose
## un voxel trop bas et trop a gauche.
static func mesher_padding() -> int:
	return _shared_mesher().get_minimum_padding()


## Mailleur partage. Construit une fois, et **le meme que celui du terrain** :
## `CWPalette.build_cubes_mesher`. C'est la condition pour que les deux grilles
## lisent comme un seul monde ; un mailleur regle a part derive tot ou tard.
static func _shared_mesher() -> VoxelMesherCubes:
	if _mesher == null:
		_mesher = CWPalette.build_cubes_mesher()
	return _mesher


## Quart de tour autour de Y, sens direct.
static func _turn(dx: int, dz: int, quarter: int) -> Vector2i:
	match quarter & 3:
		1: return Vector2i(-dz, dx)
		2: return Vector2i(-dx, -dz)
		3: return Vector2i(dz, -dx)
		_: return Vector2i(dx, dz)


func offsets_x(rotation: int) -> PackedInt32Array:
	return _dx[rotation & 3]


func offsets_y(rotation: int) -> PackedInt32Array:
	return _dy[rotation & 3]


func offsets_z(rotation: int) -> PackedInt32Array:
	return _dz[rotation & 3]


func values(rotation: int) -> PackedByteArray:
	return _v[rotation & 3]


func _to_string() -> String:
	return "%s %dx%dx%d voxels (%.2f bloc de haut), %d pleins, rayon %d" % [
		name, extent.x, extent.y, extent.z,
		float(height) / VOXELS_PER_BLOCK, voxel_count, radius]
