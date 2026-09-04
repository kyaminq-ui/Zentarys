@tool
class_name CWVoxelGenerator
extends VoxelGeneratorScript

## Discretisation du champ de terrain en blocs voxels, pour Voxel Tools 1.7.
##
## -- Plan d'implementation ---------------------------------------------------
## Incompatibilite structurelle assumee : l'original est un generateur
## mono-thread qui remplit des colonnes persistantes de 32 octets dans une
## grille de regions 256x256 (Chunk_getColumnAt @00406100) et met en cache
## l'altitude par colonne. Voxel Tools appelle _generate_block depuis un pool de
## fils, sur des blocs cubiques, sans etat partage. On s'y conforme :
##   * le champ de terrain est purement fonctionnel, donc reentrant ;
##   * l'etat partage se limite a des caches proteges par mutex (sites de
##     region, cartes de hauteurs par colonne de blocs, cellules de flore) ;
##   * les colonnes sont remplies par intervalles (fill_area) plutot que voxel
##     par voxel.
##
## Le cache de cartes de hauteurs joue le role du cache de colonnes de
## l'original, et il est indispensable : le monde porte est haut (relief
## jusqu'a ~600 blocs), donc une meme colonne (x, z) est traversee par une
## quinzaine de blocs verticaux qui, sans lui, referaient tous le meme
## echantillonnage.
##
## Le rendu vise VoxelMesherCubes en mode palette : un index par voxel dans
## CHANNEL_COLOR, ce qui reproduit l'aspect « cubes colores » de l'original sans
## bibliotheque de modeles de blocs.

## Nombre de colonnes de blocs gardees en cache. Au-dela, la generation
## precedente est jetee d'un bloc : un LRU a deux generations, sans ordre a
## maintenir et au cout d'eviction amorti.
##
## Ce plafond doit couvrir toute l'empreinte horizontale chargee, sinon le cache
## s'auto-evince en boucle et chaque bloc repaie l'echantillonnage complet. Une
## distance de vue de D blocs demande (2D/16)^2 entrees : 2 304 pour D = 384,
## 9 216 pour D = 768. A ~1,3 Ko l'entree, 16 384 entrees tiennent dans ~21 Mo,
## ce qui couvre D = 1024 et reste negligeable a cote des blocs voxels eux-memes.
const HEIGHTMAP_CACHE_CAP: int = 16384

## Attente maximale, en millisecondes, avant de renoncer a attendre le fil qui
## calcule deja la meme carte de hauteurs et de la calculer soi-meme. Filet de
## securite : sans lui, un fil interrompu bloquerait les autres.
const PATCH_WAIT_MAX_MS: int = 500


## Carte de hauteurs et de blocs de surface pour l'empreinte (x, z) d'un bloc.
class ColumnPatch extends RefCounted:
	var heights: PackedFloat32Array
	var surfaces: PackedByteArray
	var lowest: float = INF
	var highest: float = -INF


@export var params: CWWorldParams:
	set(value):
		params = value
		_field = null
		_scatter = null
		clear_caches()

## Epaisseur de la couche meuble sous la surface.
@export_range(0, 8, 1) var subsurface_depth: int = 3

## Couche de flore (jalon 1.7) : modeles voxels estampes sur le terrain.
## Bascule conservee pour comparer un meme monde avec et sans, et pour isoler
## une regression du champ d'altitude.
@export var scatter: bool = true:
	set(value):
		scatter = value
		if _scatter != null:
			_scatter.clear_cache()

var _field: CWTerrainField
var _scatter: CWScatter
var _field_mutex: Mutex = Mutex.new()
var _patches: Dictionary = {}
var _patches_prev: Dictionary = {}
var _in_progress: Dictionary = {}
var _patch_mutex: Mutex = Mutex.new()
var _shutting_down: bool = false


## Rend instantanee toute generation encore en file.
##
## A la fermeture, Voxel Tools attend que son pool de fils ait vide sa file
## avant de rendre la main. Une file de plusieurs milliers de blocs a ~20 ms
## piece fait attendre l'utilisateur pour un travail dont le resultat sera jete
## immediatement. On ne peut pas annuler les taches deja soumises, mais on peut
## les rendre gratuites : a partir d'ici, chaque bloc est rempli d'air et rendu.
##
## Lu depuis les fils de generation, ecrit depuis le fil principal. Un booleen
## suffit : sa valeur ne fait que passer de faux a vrai, et lire l'ancienne
## valeur une fois de plus ne coute qu'un bloc genere pour rien.
func request_shutdown() -> void:
	_shutting_down = true
	clear_caches()


func is_shutting_down() -> bool:
	return _shutting_down


func field() -> CWTerrainField:
	if _field != null:
		return _field
	_field_mutex.lock()
	if _field == null:
		if params == null:
			params = CWWorldParams.new()
		_field = CWTerrainField.new(params)
		_scatter = CWScatter.new(_field)
	var f: CWTerrainField = _field
	_field_mutex.unlock()
	return f


## Grille de dispersion de la flore. Construite avec le champ de terrain.
func scatter_grid() -> CWScatter:
	field()
	return _scatter


func clear_caches() -> void:
	_patch_mutex.lock()
	_patches.clear()
	_patches_prev.clear()
	_in_progress.clear()
	_patch_mutex.unlock()
	if _scatter != null:
		_scatter.clear_cache()


func _get_used_channels_mask() -> int:
	return 1 << VoxelBuffer.CHANNEL_COLOR


func _generate_block(out_buffer: VoxelBuffer, origin_in_voxels: Vector3i, lod: int) -> void:
	if _shutting_down:
		out_buffer.fill(CWPalette.AIR, VoxelBuffer.CHANNEL_COLOR)
		return

	var f: CWTerrainField = field()
	var p: CWWorldParams = f.params()
	var size: Vector3i = out_buffer.get_size()
	var stride: int = 1 << lod
	var ch: int = VoxelBuffer.CHANNEL_COLOR
	var sea: int = p.sea_level

	out_buffer.fill(CWPalette.AIR, ch)

	var patch: ColumnPatch = _get_patch(f, p, origin_in_voxels, size, stride, lod, sea)

	var y_min: int = origin_in_voxels.y
	var y_max: int = origin_in_voxels.y + (size.y - 1) * stride  # borne incluse

	# Flore. Consultee avant les chemins rapides : une plante posee sur une
	# colonne voisine plus haute peut depasser dans un bloc que la carte de
	# hauteurs de ce bloc-ci croit entierement vide. Le cout est celui de neuf
	# consultations de cellules, deja calculees par les blocs voisins ou par le
	# reste de la pile verticale.
	var plants: Array = []
	var plants_top: float = -INF
	if scatter and lod == 0:
		plants = _scatter.placements_in(
				p.world_origin.x + origin_in_voxels.x,
				p.world_origin.y + origin_in_voxels.z, size.x, size.z)
		for pl in plants:
			plants_top = maxf(plants_top, float(pl.y + pl.model.height - 1))

	# Chemins rapides : bloc entierement vide ou entierement plein. Ce sont eux
	# qui rendent praticable un monde de mille blocs de haut.
	if float(y_min) > patch.highest and float(y_min) > plants_top and y_min > sea:
		return
	if float(y_max) < patch.lowest - float(subsurface_depth):
		# Sous la roche : une plante qui deborderait jusqu'ici serait enterree.
		out_buffer.fill(CWPalette.STONE, ch)
		return

	var i: int = 0
	for lz in size.z:
		for lx in size.x:
			var h: float = patch.heights[i]
			var surface: int = patch.surfaces[i]
			i += 1
			var top: int = floori(h)

			# Roche, du bas du bloc jusqu'a la couche meuble.
			_fill_run(out_buffer, lx, lz, y_min, y_max, stride,
					y_min, top - subsurface_depth, CWPalette.STONE, ch)
			# Couche meuble.
			if subsurface_depth > 0:
				_fill_run(out_buffer, lx, lz, y_min, y_max, stride,
						top - subsurface_depth + 1, top - 1,
						CWPalette.subsurface_index(surface), ch)
			# Bloc de surface.
			_fill_run(out_buffer, lx, lz, y_min, y_max, stride, top, top, surface, ch)
			# Eau, de la surface du terrain jusqu'au niveau de la mer.
			if top < sea:
				_fill_run(out_buffer, lx, lz, y_min, y_max, stride,
						top + 1, sea, CWPalette.water_index(float(sea - top)), ch)

	for pl in plants:
		_stamp(out_buffer, pl, p.world_origin.x + origin_in_voxels.x,
				p.world_origin.y + origin_in_voxels.z, y_min, y_max, size, ch)


## Ecrit un modele dans le bloc, rogne sur ses bornes.
##
## N'ecrase que l'air et l'eau : sur une pente, une partie du gabarit tombe dans
## le flanc de la colline, et y substituer du feuillage creuserait un trou dans
## le terrain. L'eau, elle, se laisse remplacer — c'est ainsi qu'une algue se
## voit depuis la surface.
func _stamp(buf: VoxelBuffer, pl: CWScatter.Placement, ox: int, oz: int,
		y_min: int, y_max: int, size: Vector3i, ch: int) -> void:
	var m: CWVoxelModel = pl.model
	var dx: PackedInt32Array = m.offsets_x(pl.rotation)
	var dy: PackedInt32Array = m.offsets_y(pl.rotation)
	var dz: PackedInt32Array = m.offsets_z(pl.rotation)
	var values: PackedByteArray = m.values(pl.rotation)
	var ax: int = pl.x - ox
	var az: int = pl.z - oz
	for i in values.size():
		var lx: int = ax + dx[i]
		if lx < 0 or lx >= size.x:
			continue
		var lz: int = az + dz[i]
		if lz < 0 or lz >= size.z:
			continue
		var wy: int = pl.y + dy[i]
		if wy < y_min or wy > y_max:
			continue
		var ly: int = wy - y_min
		var here: int = buf.get_voxel(lx, ly, lz, ch)
		if here != CWPalette.AIR and here != CWPalette.WATER \
				and here != CWPalette.WATER_DEEP:
			continue
		buf.set_voxel(values[i], lx, ly, lz, ch)


func _get_patch(f: CWTerrainField, p: CWWorldParams, origin_in_voxels: Vector3i,
		size: Vector3i, stride: int, lod: int, sea: int) -> ColumnPatch:
	var key := Vector3i(origin_in_voxels.x, origin_in_voxels.z, lod)

	# Les blocs d'une meme colonne (x, z) partent ensemble dans la file et sont
	# pris par des fils differents. Sans marqueur « en cours », ils manquent tous
	# le cache au meme instant et recalculent tous la meme carte de hauteurs :
	# le cache ne sert alors plus a rien pendant la phase de chargement, celle
	# qui compte. Le second arrive attend le premier au lieu de dupliquer.
	var waited: int = 0
	while true:
		_patch_mutex.lock()
		var hit: Variant = _patches.get(key)
		if hit == null:
			hit = _patches_prev.get(key)
			if hit != null:
				# Remonte l'entree dans la generation courante.
				_patches[key] = hit
		if hit != null:
			_patch_mutex.unlock()
			return hit
		if not _in_progress.has(key) or waited >= PATCH_WAIT_MAX_MS:
			# A nous de la calculer, soit parce que personne ne s'en charge, soit
			# parce que l'attente a assez dure pour qu'on cesse de faire
			# confiance a l'autre fil.
			_in_progress[key] = true
			_patch_mutex.unlock()
			break
		_patch_mutex.unlock()
		OS.delay_msec(1)
		waited += 1
		if _shutting_down:
			return _empty_patch(size)

	# Les coordonnees Godot sont relatives a l'origine de monde : c'est ce qui
	# permet de jouer au centre de la carte d'origine (coordonnees monde de
	# l'ordre de 8,4 millions) tout en gardant des coordonnees de scene proches
	# de zero. Le decalage s'applique ici et nulle part ailleurs, sans quoi le
	# terrain rendu et les mesures de l'interface decrivent deux endroits
	# differents du monde.
	var ox: int = p.world_origin.x + origin_in_voxels.x
	var oz: int = p.world_origin.y + origin_in_voxels.z

	var patch := ColumnPatch.new()
	var n: int = size.x * size.z
	patch.heights.resize(n)
	patch.surfaces.resize(n)
	# Une seule descente dans le champ : sample_patch ne consulte le cache de
	# fenetres de sites qu'une fois par zone traversee, au lieu d'une fois par
	# colonne.
	var raw: PackedFloat32Array = f.sample_patch(ox, oz, size.x, size.z, stride)
	var j: int = 0
	for i in n:
		var h: float = raw[j]
		patch.heights[i] = h
		patch.surfaces[i] = CWPalette.surface_index(h, raw[j + 1], raw[j + 2], sea)
		patch.lowest = minf(patch.lowest, h)
		patch.highest = maxf(patch.highest, h)
		j += 3

	_patch_mutex.lock()
	if _patches.size() >= HEIGHTMAP_CACHE_CAP:
		_patches_prev = _patches
		_patches = {}
	_patches[key] = patch
	_in_progress.erase(key)
	_patch_mutex.unlock()
	return patch


## Carte de hauteurs neutre, rendue quand l'arret survient pendant une attente.
func _empty_patch(size: Vector3i) -> ColumnPatch:
	var patch := ColumnPatch.new()
	patch.heights.resize(size.x * size.z)
	patch.surfaces.resize(size.x * size.z)
	patch.lowest = 0.0
	patch.highest = 0.0
	return patch


## Remplit l'intervalle [wy0, wy1] (coordonnees monde, bornes incluses) d'une
## colonne du bloc, en le rognant sur l'etendue verticale du bloc.
func _fill_run(buf: VoxelBuffer, lx: int, lz: int, y_min: int, y_max: int,
		stride: int, wy0: int, wy1: int, value: int, channel: int) -> void:
	if wy1 < wy0:
		return
	var a: int = maxi(wy0, y_min)
	var b: int = mini(wy1, y_max)
	if b < a:
		return
	# Le pas est une puissance de deux et les bornes sont alignees sur le bloc :
	# la division entiere est exactement la conversion voulue.
	@warning_ignore("integer_division")
	var ly0: int = (a - y_min) / stride
	@warning_ignore("integer_division")
	var ly1: int = (b - y_min) / stride
	buf.fill_area(value, Vector3i(lx, ly0, lz), Vector3i(lx + 1, ly1 + 1, lz + 1), channel)
