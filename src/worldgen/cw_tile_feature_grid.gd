class_name CWTileFeatureGrid
extends RefCounted

## Grille paresseuse d'elements de tuile : 8 x 8 elements par zone de 16384
## unites monde, generes d'un bloc et memoises, avec garde de reentrance.
##
## -- Resume du systeme -------------------------------------------------------
## Chaque zone porte une grille de 64 elements, un par tuile de 2048 unites.
## Un seul d'entre eux est pose d'office : le bourg (type 1), sur la tuile qui
## contient le site de region. Les autres tuiles ne recoivent un element que si
## leur centre appartient bien a ce site, puis un tirage ordonne par distance
## au bourg leur attribue un type. Cinq types deforment le terrain (bourg,
## cratere, deux caldeiras, piton) ; les autres sont des ancres de contenu.
##
## -- Analyse du pseudo-code --------------------------------------------------
## World_generateRegionFeatures (@0050e080) :
##   * garde d'unicite : la zone n'est generee que si son enregistrement est nul ;
##   * force d'abord les sites de region du voisinage 5 x 5 ;
##   * srand(graine + zz * 1024 + zx) puis une sequence de tirages dont l'ordre
##     est porteur (voir les commentaires en place) ;
##   * passe 1, balayage tx puis tz : le bourg sur la tuile du site, sinon un
##     element candidat place au hasard dans sa tuile avec une marge de
##     rayon + 256, et retenu seulement si sa tuile *et* sa position relevent
##     bien de ce site ;
##   * les candidats sont tries par « distance au bourg + bruit uniforme +-2 » ;
##   * passe 2, 64 iterations : les indices impairs sont sautes, les indices
##     valant 2 mod 4 recoivent le type 14 (agglomeration), ceux valant 0 mod 4
##     un type tire parmi huit ;
##   * passe 3 : jusqu'a cinq candidats restants deviennent des donjons.
##
## -- Recursion, et comment l'original la casse -------------------------------
## L'altitude de chaque element est echantillonnee par World_baseHeightField,
## qui relit lui-meme la grille d'elements. L'original n'ecrit le pointeur de
## zone qu'a la *fin* de la fonction : pendant sa construction, la zone se voit
## vide, donc l'altitude retenue pour un element est celle du terrain *sans*
## couche d'elements. Comme toutes les positions tirees restent dans leur propre
## tuile, aucune zone n'en interroge une autre : la recursion s'arrete la.
##
## On reproduit exactement ce comportement, mais sur plusieurs fils : la zone en
## cours de construction n'est publiee qu'une fois terminee, le fil qui la
## construit la voit vide (garde de reentrance par identifiant de fil), et les
## autres fils attendent. Sans cette attente, une colonne generee pendant la
## fenetre de construction serait figee sans deformation, et le meme monde ne se
## regenererait pas a l'identique.

const ZONE_SIZE: int = CWWorldParams.ZONE_SIZE
const TILE_SIZE: int = CWWorldParams.TILE_SIZE
const ZONE_GRID: int = CWWorldParams.ZONE_GRID
const TILES_PER_ZONE: int = 8
const TILE_GRID: int = ZONE_GRID * TILES_PER_ZONE
const TILES_PER_ZONE_SQ: int = TILES_PER_ZONE * TILES_PER_ZONE

## Marge laissee entre un element et le bord de sa tuile, en plus de son rayon.
const PLACEMENT_MARGIN: int = 256

## Pas de la grille sur laquelle les types 11, 12 et 14 sont recales.
const SNAP_STEP: int = 256

var _params: CWWorldParams
var _zones: Dictionary = {}
var _building: Dictionary = {}
var _mutex: Mutex = Mutex.new()
var _build_mutex: Mutex = Mutex.new()

## Zone rendue au fil qui construit deja cette zone, et hors du monde. De
## taille nulle, ce qui distingue « pas d'elements ici » de « 64 elements dont
## certains sont vides » : get_feature s'appuie sur is_empty().
var _empty: Array = []


func _init(params: CWWorldParams) -> void:
	_params = params
	_empty.make_read_only()


func clear_cache() -> void:
	_mutex.lock()
	_zones.clear()
	_mutex.unlock()


## Element de la tuile (tx, tz) de la grille 8192 x 8192, ou null.
##
## Rend null hors du monde, et pendant la construction de la zone pour le fil
## qui la construit : c'est ce qui casse la recursion, exactement comme le
## pointeur encore nul de l'original.
func get_feature(tx: int, tz: int, field: CWTerrainField) -> CWTileFeature:
	if tx < 0 or tz < 0 or tx >= TILE_GRID or tz >= TILE_GRID:
		return null
	@warning_ignore("integer_division")
	var zx: int = tx / TILES_PER_ZONE
	@warning_ignore("integer_division")
	var zz: int = tz / TILES_PER_ZONE
	var zone: Array = get_zone(zx, zz, field)
	if zone.is_empty():
		return null
	return zone[(tz % TILES_PER_ZONE) + (tx % TILES_PER_ZONE) * TILES_PER_ZONE]


## Les 64 elements de la zone (zx, zz), dans l'ordre tz + tx * 8.
func get_zone(zx: int, zz: int, field: CWTerrainField) -> Array:
	if zx < 0 or zz < 0 or zx >= ZONE_GRID or zz >= ZONE_GRID:
		return _empty
	var key: int = zx * ZONE_GRID + zz

	# Chemin chaud : une prise de verrou et une consultation. Tout le reste,
	# `OS.get_thread_caller_id()` en tete — un appel de liaison moteur, mesure a
	# une quinzaine de microsecondes par colonne s'il est fait ici — appartient
	# au chemin froid, parcouru une fois par zone.
	_mutex.lock()
	var hit: Variant = _zones.get(key)
	_mutex.unlock()
	if hit != null:
		return hit

	var me: int = OS.get_thread_caller_id()
	_mutex.lock()
	var owner: int = _building.get(key, 0)
	_mutex.unlock()
	if owner == me:
		# Reentrance : c'est nous qui construisons cette zone, elle n'existe
		# pas encore. Voir l'en-tete.
		return _empty

	# Les autres fils attendent le constructeur plutot que de refaire le
	# travail : deux constructions concurrentes donneraient le meme resultat,
	# mais une colonne echantillonnee entre-temps verrait un terrain sans
	# elements et resterait figee ainsi dans le cache de hauteurs.
	_build_mutex.lock()
	_mutex.lock()
	hit = _zones.get(key)
	if hit != null:
		_mutex.unlock()
		_build_mutex.unlock()
		return hit
	_building[key] = me
	_mutex.unlock()

	var built: Array = _build_zone(zx, zz, field)

	_mutex.lock()
	_zones[key] = built
	_building.erase(key)
	_mutex.unlock()
	_build_mutex.unlock()
	return built


# -- Fonctions auxiliaires portees --------------------------------------------

## Palier de difficulte d'une zone, gradue depuis le centre de la carte.
##
## Tracabilite : World_featureTier (@004d7870). La troncature vers zero de
## (int)(d * -0.75) est celle du C ; elle est reproduite telle quelle.
static func feature_tier(zx: int, zz: int) -> int:
	@warning_ignore("integer_division")
	var c: int = ZONE_GRID / 2
	if zx == c and zz == c:
		return 1
	var dx: float = float(c - zx)
	var dz: float = float(c - zz)
	return 2 + int(sqrt(dx * dx + dz * dz) * 0.75)


## Nombre d'elements vise pour une zone, selon le climat de son site.
##
## Tracabilite : World_featureCountRange (@00522290). Les bornes ne sont pas
## lues par le champ d'altitude ; elles cadreront la dispersion du contenu au
## jalon 1.7. Portees ici pour ne pas avoir a rouvrir la fonction.
static func feature_count_range(site: CWRegionSite) -> Vector2i:
	var out := Vector2i(1, 10)
	if site.humidity < 0.2:
		out = Vector2i(10, 20)
	if site.temperature < 0.2 and site.humidity > 0.8:
		out = Vector2i(15, 25)
	if site.temperature > 0.8 and site.humidity > 0.8:
		out = Vector2i(10, 20)
	if site.wet:
		out = Vector2i(20, 30)
	return out


static func _snap(v: float) -> float:
	@warning_ignore("integer_division")
	var half: int = SNAP_STEP / 2
	return float(floori(v / float(SNAP_STEP)) * SNAP_STEP + half)


# -- Construction d'une zone --------------------------------------------------

func _build_zone(zx: int, zz: int, field: CWTerrainField) -> Array:
	var out: Array = []
	out.resize(TILES_PER_ZONE_SQ)
	for i in TILES_PER_ZONE_SQ:
		out[i] = CWTileFeature.new()

	var sites: CWRegionSiteGrid = field.sites()
	# L'original force le voisinage 5 x 5 avant de tirer sa graine. Sans effet
	# sur le flux aleatoire (chaque site a le sien), mais les echantillons
	# d'altitude qui suivent en ont besoin de toute facon.
	for i in range(-2, 3):
		for j in range(-2, 3):
			sites.get_site(zx + i, zz + j)
	var site: CWRegionSite = sites.get_site(zx, zz)
	if site == null:
		return out

	var rng := CWRand.new(_params.world_seed + zz * ZONE_GRID + zx)
	var tier: int = feature_tier(zx, zz)
	# Variante de zone, tiree seulement au-dela du palier 4 : l'ordre compte.
	if tier > 4:
		rng.mod(5)
	var theme: int = rng.mod(4)
	var counter: int = rng.mod(10000)
	if site.humidity > 0.81:
		theme = rng.mod(2) + 4
	var counts: Vector2i = feature_count_range(site)

	@warning_ignore("integer_division")
	var start_tx: int = (site.x / TILE_SIZE) % TILES_PER_ZONE
	@warning_ignore("integer_division")
	var start_tz: int = (site.z / TILE_SIZE) % TILES_PER_ZONE

	var zone_x: int = zx * ZONE_SIZE
	var zone_z: int = zz * ZONE_SIZE
	@warning_ignore("integer_division")
	var tile_half: int = TILE_SIZE / 2
	var candidates: Array = []

	for tx in TILES_PER_ZONE:
		for tz in TILES_PER_ZONE:
			var f: CWTileFeature = out[tz + tx * TILES_PER_ZONE]
			var tile_x0: int = zone_x + tx * TILE_SIZE
			var tile_z0: int = zone_z + tz * TILE_SIZE

			# L'original conditionne aussi le bourg a un drapeau de monde
			# (`this+0xa4`, voisin du handle de base de dialogues en +0xac) :
			# vraisemblablement « ce monde a des bourgs », vrai cote serveur.
			# Toujours vrai ici ; si un monde sans bourgs devient utile, c'est
			# la qu'il faudra brancher la bascule.
			if tx == start_tx and tz == start_tz:
				_place_town(f, rng, site, theme, tile_x0, tile_z0, field)
				continue

			# Le centre de la tuile doit relever de ce site : sinon la tuile
			# revient visuellement a la zone voisine et reste vide.
			if field.nearest_site(tile_x0 + tile_half, tile_z0 + tile_half) != site:
				continue

			f.radius = float(rng.mod(256) + 512)
			var margin: float = f.radius + float(PLACEMENT_MARGIN)
			var span: float = float(TILE_SIZE) - margin * 2.0
			# L'original tire z avant x. L'ordre decale tout le reste.
			f.z = float(tile_z0) + margin + rng.unit() * span
			f.x = float(tile_x0) + margin + rng.unit() * span
			f.height = field.sample_column_raw(int(f.x), int(f.z)).x
			f.tier = counts.x

			if field.nearest_site(int(f.x), int(f.z)) != site:
				continue
			var ddx: int = start_tx - tx
			var ddz: int = start_tz - tz
			var d: float = sqrt(float(ddx * ddx + ddz * ddz))
			candidates.append([rng.unit() * 4.0 + d - 2.0, tx, tz])

	candidates.sort_custom(_by_key)

	# Passe 2. Les indices impairs sont sautes sans rien consommer : sur 64
	# iterations, 32 candidats au plus sont types, dont la moitie en type 14.
	for i in TILES_PER_ZONE_SQ:
		if candidates.is_empty():
			break
		if i % 2 == 1:
			continue
		var c: Array = candidates.pop_front()
		var tx: int = c[1]
		var tz: int = c[2]
		var f: CWTileFeature = out[tz + tx * TILES_PER_ZONE]
		if f.height < 0.0:
			f.height = 0.0
		f.tier = _tier_of(tier, i)

		if (i >> 1) % 2 == 1:
			counter = _place_settlement(f, rng, field, counter)
		else:
			_place_random_type(f, rng, site, zone_x, zone_z, tx, tz)
			f.difficulty = _difficulty_of(f.tier, rng)
			f.id = counter
			counter = counter + 1 + rng.mod(50)

	# Passe 3 : jusqu'a cinq donjons parmi les candidats restants.
	var placed: int = 0
	while placed < 5 and not candidates.is_empty():
		var c: Array = candidates.pop_at(rng.next() % candidates.size())
		var f: CWTileFeature = out[int(c[2]) + int(c[1]) * TILES_PER_ZONE]
		# Le donjon garde la position tiree au placement : contrairement aux
		# types 11, 12 et 14, l'original ne le recale pas sur la grille de 256,
		# il n'en derive qu'un index de cellule pour la carte de zone. Le
		# deplacer changerait le terrain, via le relevement oceanique qui
		# s'appuie sur la position de l'element.
		f.type = CWTileFeature.TYPE_DUNGEON
		f.id = rng.mod(10000000) + 1
		placed += 1

	# Relevement oceanique : fige par element, il ne depend que de sa position.
	for f: CWTileFeature in out:
		if f.type == 0:
			continue
		var near: CWRegionSite = field.nearest_site(int(f.x), int(f.z))
		if near != null and near.base_height < 0:
			f.ocean_lift = float(near.base_height)
	return out


static func _by_key(a: Array, b: Array) -> bool:
	return a[0] < b[0]


func _place_town(f: CWTileFeature, rng: CWRand, site: CWRegionSite, theme: int,
		tile_x0: int, tile_z0: int, field: CWTerrainField) -> void:
	f.type = CWTileFeature.TYPE_TOWN
	f.variant = theme
	f.id = site.site_seed
	f.radius = float(rng.mod(200) + 512)
	f.x = float(site.x)
	f.z = float(site.z)
	# Le bourg herite de la position du site, qui peut deborder de sa tuile :
	# quatre rabattements le ramenent a l'interieur, avec sa marge.
	var m: float = f.radius + float(PLACEMENT_MARGIN)
	if f.x - m < float(tile_x0):
		f.x = float(tile_x0) + m
	if f.z - m < float(tile_z0):
		f.z = float(tile_z0) + m
	if f.x + m > float(tile_x0 + TILE_SIZE):
		f.x = float(tile_x0 + TILE_SIZE) - m
	if f.z + m > float(tile_z0 + TILE_SIZE):
		f.z = float(tile_z0 + TILE_SIZE) - m
	f.height = maxf(0.0, field.sample_column_raw(int(f.x), int(f.z)).x)


## Type 14 : agglomeration calee sur la grille de 256, dont la variante depend
## du climat de sa cellule. Aucun effet sur l'altitude ; portee pour l'ordre des
## tirages et pour le jalon 1.7.
func _place_settlement(f: CWTileFeature, rng: CWRand, field: CWTerrainField,
		counter: int) -> int:
	f.type = 14
	f.radius = 150.0
	f.z = _snap(f.z)
	f.x = _snap(f.x)
	f.variant = rng.mod(4)
	var climate: Vector2 = field.climate_at(int(f.x), int(f.z))
	if climate.y > 0.8:
		f.variant = 4 + (1 if climate.x <= 0.8 else 0)
	rng.mod(10000000)  # identifiant de quete, exploite au jalon 4
	f.id = counter
	var next_counter: int = counter + 1 + rng.mod(50)
	f.difficulty = _difficulty_of(f.tier, rng)
	return next_counter


func _place_random_type(f: CWTileFeature, rng: CWRand, site: CWRegionSite,
		zone_x: int, zone_z: int, tx: int, tz: int) -> void:
	# Un site oceanique remplace crateres et caldeiras par le type 15.
	var drowned: bool = site.base_height < 0
	match rng.mod(8):
		0:
			f.type = 2
		1:
			f.type = 3
			f.variant = rng.mod(3)
		2:
			f.type = 15 if drowned else CWTileFeature.TYPE_CRATER
		3:
			f.type = 5
			if site.humidity <= 0.8:
				f.variant = 0
			elif site.temperature > 0.8:
				f.variant = 3
			elif site.temperature < 0.2:
				f.variant = 2
			else:
				f.variant = 0
			# Seul type a etre repose : rayon plus petit, nouveau tirage dans la
			# tuile, z avant x comme au premier placement.
			f.radius = float(rng.mod(256) + 256)
			var margin: float = f.radius + float(PLACEMENT_MARGIN)
			var span: float = float(TILE_SIZE) - margin * 2.0
			f.z = float(zone_z + tz * TILE_SIZE) + margin + rng.unit() * span
			f.x = float(zone_x + tx * TILE_SIZE) + margin + rng.unit() * span
		4:
			f.type = 15 if drowned else CWTileFeature.TYPE_CALDERA_A
		5:
			f.type = 15 if drowned else CWTileFeature.TYPE_CALDERA_B
		6:
			f.type = 11
			f.radius = 128.0
			f.z = _snap(f.z)
			f.x = _snap(f.x)
		7:
			f.type = 12
			f.radius = 128.0
			f.z = _snap(f.z)
			f.x = _snap(f.x)


## Palier d'un element.
##
## Lacune assumee. L'original ecrit round(formula_inverse(i / 64)), ou
## formula_inverse est un import non resolu du depot d'analyse. Pris a la lettre
## (fonction identite), le palier vaudrait 0 ou 1, donc toujours sous le premier
## seuil, et les quatre branches de difficulte seraient mortes : la lecture
## litterale est donc fausse. Le palier de zone (World_featureTier) est ecrit
## par le generateur et jamais relu ailleurs, ce qui en fait l'entree la plus
## vraisemblable.
##
## Substitut retenu : palier de zone plus le terme litteral. Deterministe, et il
## rend leur role aux seuils 5 / 10 / 15 / 18. Ne pas y voir une equivalence
## avec l'original : c'est une reconstruction, au meme titre que les decalages
## de bruit du monde.
static func _tier_of(zone_tier: int, index: int) -> int:
	return zone_tier + int(round(float(index) * 0.015625))


## Difficulte tiree selon le palier. Le nombre de tirages consommes depend du
## palier : c'est par la que celui-ci influe sur la suite du flux.
static func _difficulty_of(tier: int, rng: CWRand) -> int:
	if tier < 5:
		return 0
	if tier < 10:
		return rng.mod(2)
	if tier < 15:
		return rng.mod(3)
	if tier <= 18:
		return rng.mod(3) + 1
	return rng.mod(4) + 1
