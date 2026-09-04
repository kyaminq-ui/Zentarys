class_name CWScatter
extends RefCounted

## Dispersion de la flore sur le terrain genere (jalon 1.7).
##
## -- Pourquoi une grille de cellules ------------------------------------------
## Le generateur remplit des blocs de 16 sans etat partage, et une plante
## deborde de la colonne qui la porte : un bloc doit donc connaitre non
## seulement ses propres plantes mais celles des cellules voisines dont le
## gabarit mord dedans. On decoupe le monde en cellules de CELL_SIZE, chaque
## cellule tire ses plantes a partir de son seul indice — donc de facon
## reproductible, sans ordre d'evaluation ni voisinage — et un bloc consulte la
## couronne de cellules qui peuvent l'atteindre.
##
## -- Cout ---------------------------------------------------------------------
## Chaque plante coute un echantillonnage de colonne (~75 us) : il faut son
## altitude exacte pour la poser, et la surface exacte pour verifier qu'elle a
## le droit d'y etre. Le *nombre* de plantes, lui, se decide sur un seul
## echantillon au centre de la cellule : un biome s'etend sur des milliers de
## blocs, il ne change pas a l'interieur d'une cellule de seize. Une cellule
## coute donc 1 + n echantillons au lieu d'un par candidat rejete, soit ~7 pour
## 256 colonnes de terrain en prairie — moins de 3 % du cout d'un bloc. Le
## resultat est mis en cache par cellule, comme les cartes de hauteurs : une
## cellule sert aux neuf blocs qui l'entourent et a toute leur pile verticale.
##
## -- Ce qui n'est pas encore porte --------------------------------------------
## L'original disperse depuis `WorldInfo_generateBiomeContent` (@005e4850), non
## analysee : la loi de densite, la table modele-biome et le tirage de position
## sont ici des choix de bon sens, pas une lecture du binaire. La *structure*
## — un tirage par cellule, un modele choisi par le climat du point, un quart de
## tour aleatoire — est en revanche celle qu'impose la contrainte de
## reproductibilite sans etat.

## Cote d'une cellule de dispersion, en blocs. Aligne sur le bloc de donnees de
## Voxel Tools : une cellule par bloc, donc une couronne de 3 x 3 a consulter.
const CELL_SIZE: int = 16
const CELL_SHIFT: int = 4

## Plafond dur du nombre de plantes par cellule. Garde-fou : une densite mal
## reglee ne doit pas pouvoir faire exploser le cout d'un bloc en silence.
const MAX_PER_CELL: int = 16

## Plafond du cache de cellules. Meme raisonnement que HEIGHTMAP_CACHE_CAP :
## il doit couvrir l'empreinte chargee, sinon le cache s'auto-evince en boucle.
## Une cellule est bien plus legere qu'une carte de hauteurs.
const CELL_CACHE_CAP: int = 32768

## Melangeurs de l'indice de cellule vers la graine du LCG. Premiers larges,
## comme dans toute fonction de hachage spatiale ; ils n'ont pas d'equivalent
## dans l'original, qui disperse en parcourant les regions dans l'ordre.
const HASH_X: int = 73856093
const HASH_Z: int = 19349663
const HASH_SEED: int = 83492791
const HASH_MIX: int = 2654435761


## Une plante posee : sa colonne, sa base, son modele et son orientation.
class Placement extends RefCounted:
	var x: int = 0
	var z: int = 0
	## Altitude du premier bloc du modele : le bloc d'air juste au-dessus du sol.
	var y: int = 0
	var model: CWVoxelModel = null
	var rotation: int = 0


var _field: CWTerrainField
var _lib: CWModelLibrary
var _cells: Dictionary = {}
var _cells_prev: Dictionary = {}
var _mutex: Mutex = Mutex.new()


func _init(terrain_field: CWTerrainField, models: CWModelLibrary = null) -> void:
	_field = terrain_field
	_lib = models if models != null else CWModelLibrary.shared()


func library() -> CWModelLibrary:
	return _lib


func clear_cache() -> void:
	_mutex.lock()
	_cells.clear()
	_cells_prev.clear()
	_mutex.unlock()


static func cell_of(v: int) -> int:
	return v >> CELL_SHIFT


## Plantes dont le gabarit mord dans l'empreinte [x0, x0 + nx) x [z0, z0 + nz),
## en coordonnees monde.
func placements_in(x0: int, z0: int, nx: int, nz: int) -> Array:
	var out: Array = []
	if not _lib.has_any():
		return out
	var margin: int = _lib.max_radius
	var cx0: int = cell_of(x0 - margin)
	var cx1: int = cell_of(x0 + nx - 1 + margin)
	var cz0: int = cell_of(z0 - margin)
	var cz1: int = cell_of(z0 + nz - 1 + margin)
	var x1: int = x0 + nx
	var z1: int = z0 + nz
	for cz in range(cz0, cz1 + 1):
		for cx in range(cx0, cx1 + 1):
			for p in cell(cx, cz):
				var r: int = p.model.radius
				if p.x + r < x0 or p.x - r >= x1:
					continue
				if p.z + r < z0 or p.z - r >= z1:
					continue
				out.append(p)
	return out


## Plantes d'une cellule. Mise en cache : une cellule sert aux neuf blocs qui
## l'entourent et a toute leur pile verticale.
func cell(cx: int, cz: int) -> Array:
	var key: int = (cz << 24) ^ cx
	_mutex.lock()
	var hit: Variant = _cells.get(key)
	if hit == null:
		hit = _cells_prev.get(key)
		if hit != null:
			_cells[key] = hit
	_mutex.unlock()
	if hit != null:
		return hit

	# Calcul hors verrou : il echantillonne le champ de terrain, ce qui est
	# reentrant et prend ~300 us. Deux fils peuvent calculer la meme cellule au
	# meme instant ; ils obtiennent le meme resultat, et payer deux fois coute
	# moins cher que faire attendre.
	var built: Array = _build_cell(cx, cz)

	_mutex.lock()
	if _cells.size() >= CELL_CACHE_CAP:
		_cells_prev = _cells
		_cells = {}
	_cells[key] = built
	_mutex.unlock()
	return built


func _build_cell(cx: int, cz: int) -> Array:
	var out: Array = []
	var rng := CWRand.new(_seed_of(cx, cz))
	# Les premiers tirages d'un LCG seme par un hachage restent correles d'une
	# cellule a l'autre : les cellules voisines partagent leurs bits hauts.
	rng.next()
	rng.next()

	var sea: int = _field.params().sea_level
	var base_x: int = cx << CELL_SHIFT
	var base_z: int = cz << CELL_SHIFT

	# Combien de plantes : decide sur le centre de la cellule.
	@warning_ignore("integer_division")
	var mid: int = CELL_SIZE / 2
	var centre: Vector3 = _field.sample_column(base_x + mid, base_z + mid)
	var density: float = CWModelLibrary.density_of(
			CWPalette.surface_index(centre.x, centre.y, centre.z, sea))
	if density <= 0.0:
		return out
	var count: int = floori(density)
	if rng.unit() < density - float(count):
		count += 1
	count = mini(count, MAX_PER_CELL)

	for i in count:
		var x: int = base_x + rng.mod(CELL_SIZE)
		var z: int = base_z + rng.mod(CELL_SIZE)
		var turn: int = rng.mod(CWVoxelModel.ROTATIONS)
		var pick: float = rng.unit()

		# La surface exacte du point, elle, est verifiee : une cellule a cheval
		# sur une plage ou une ligne de neige ne doit pas y semer sa prairie.
		var c: Vector3 = _field.sample_column(x, z)
		var surface: int = CWPalette.surface_index(c.x, c.y, c.z, sea)
		var choices: Array = _lib.for_surface(surface)
		if choices.is_empty():
			continue
		# Sous l'eau, seul le fond marin se garnit : le reste de la flore
		# n'aurait pas de sens et se verrait de loin a travers l'eau.
		if c.x < float(sea) and surface != CWPalette.GRAVEL:
			continue

		var p := Placement.new()
		p.x = x
		p.z = z
		p.y = floori(c.x) + 1
		p.model = choices[mini(int(pick * float(choices.size())), choices.size() - 1)]
		p.rotation = turn
		out.append(p)
	return out


func _seed_of(cx: int, cz: int) -> int:
	var s: int = (cx * HASH_X) ^ (cz * HASH_Z) ^ (_field.params().world_seed * HASH_SEED)
	return (s * HASH_MIX) & 0xFFFFFFFF
