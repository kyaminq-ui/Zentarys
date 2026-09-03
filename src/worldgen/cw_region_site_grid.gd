class_name CWRegionSiteGrid
extends RefCounted

## Grille paresseuse 1024 x 1024 de sites de région, avec cache protégé par
## mutex (les blocs voxels sont générés sur plusieurs fils).
##
## ── Résumé du système ───────────────────────────────────────────────────────
## Chaque zone de 16384 unités possède un « site » : un point tiré au hasard,
## calé au centre d'une tuile, porteur d'une température, d'une humidité et
## d'une altitude de base. Tout le climat et l'ossature du relief sont ensuite
## obtenus en mélangeant les sites voisins par distance. C'est ce qui donne au
## monde d'origine ses grandes régions climatiques nettes plutôt qu'un dégradé
## de bruit continu.
##
## ── Analyse du pseudo-code ──────────────────────────────────────────────────
## `World_generateRegionSite` (@0050b870) :
##   * mémoïsation dans un tableau de 1024x1024 pointeurs (+0x4000bc) ;
##   * `srand(rx + 0x108a + rz*0x400 + graine*3)` ;
##   * un premier tirage pair/impair choisit entre un climat « tempéré »
##     (T 0.3-0.7, H 0.4-0.8) et un climat « extrême » où température et
##     humidité sont chacune poussées vers un bord (0-0.1 ou 0.9-1.0) ;
##   * dans la branche tempérée, un tirage sur 10 transforme la région en
##     marais (drapeau +0x08, H 0.8-1.0, T 0-0.5) ;
##   * la zone contenant le point de départ court-circuite ces tirages :
##     elle est tempérée et son site est posé exactement sur le point de départ ;
##   * position tirée dans [zone*16384 + 512, +15872], puis calée au centre de
##     tuile la plus proche (`& ~0x7ff` puis `+ 0x400`) ;
##   * altitude de base = deux échantillons de bruit indexés par la région
##     (fréquences 1.4 et 4.0), combinés en `(n1+1)*100 - 70 + n2*30` ;
##   * si cette altitude tombe sous 1, la région devient océanique : -100
##     supplémentaires (plancher à -100), drapeau marais effacé, climat
##     retiré au sort entre tropical et tempéré. La zone de départ est
##     exemptée : elle reçoit une altitude positive de 20 à 69.
##
## Effets de bord : aucun (pur, mémoïsé). Invariant : deux appels pour la même
## région et la même graine donnent le même site.

const ZONE_SIZE: int = CWWorldParams.ZONE_SIZE
const ZONE_GRID: int = CWWorldParams.ZONE_GRID
const TILE_SIZE: int = CWWorldParams.TILE_SIZE
## Demi-tuile. TILE_SIZE est une puissance de deux, la division est exacte.
@warning_ignore("integer_division")
const TILE_HALF: int = TILE_SIZE / 2

var _params: CWWorldParams
var _cache: Dictionary = {}
var _window_cache: Dictionary = {}
var _mutex: Mutex = Mutex.new()


func _init(params: CWWorldParams) -> void:
	_params = params


## Site de la zone (rx, rz), ou null hors de la grille 1024 x 1024.
func get_site(rx: int, rz: int) -> CWRegionSite:
	if rx < 0 or rz < 0 or rx >= ZONE_GRID or rz >= ZONE_GRID:
		return null
	var key: int = rx * ZONE_GRID + rz
	_mutex.lock()
	var hit: Variant = _cache.get(key)
	_mutex.unlock()
	if hit != null:
		return hit
	var site: CWRegionSite = _build_site(rx, rz)
	_mutex.lock()
	# Une autre tâche a pu gagner la course ; on garde la première entrée pour
	# que l'identité du site reste stable.
	if _cache.has(key):
		site = _cache[key]
	else:
		_cache[key] = site
	_mutex.unlock()
	return site


func clear_cache() -> void:
	_mutex.lock()
	_cache.clear()
	_window_cache.clear()
	_mutex.unlock()


func _build_site(rx: int, rz: int) -> CWRegionSite:
	var seed_world: int = _params.world_seed
	var rng := CWRand.new(rx + 0x108A + rz * ZONE_GRID + seed_world * 3)
	var site := CWRegionSite.new()
	site.site_seed = rz * ZONE_GRID + rx + seed_world

	var start: Vector2i = _params.start_point
	var is_start: bool = (rx == CWWorldParams.zone_of(start.x)
			and rz == CWWorldParams.zone_of(start.y))

	if rng.coin() or is_start:
		site.temperature = rng.unit() * 0.4 + 0.3
		site.humidity = rng.unit() * 0.4 + 0.4
		if is_start:
			site.x = start.x
			site.z = start.y
		elif rng.mod(10) == 0:
			site.wet = true
			site.humidity = rng.unit() * 0.2 + 0.8
			site.temperature = rng.unit() * 0.5
	else:
		site.temperature = (rng.unit() * 0.1) if rng.coin() else (rng.unit() * 0.1 + 0.9)
		site.humidity = (rng.unit() * 0.1) if rng.coin() else (rng.unit() * 0.1 + 0.9)

	if not is_start:
		# L'original tire z avant x ; l'ordre compte, il décale toute la suite.
		var rz_off: int = rng.mod(0x3C00)
		var rx_off: int = rng.mod(0x3C00)
		site.z = rz * ZONE_SIZE + rz_off + 0x200
		site.x = rx * ZONE_SIZE + rx_off + 0x200

	# Calage au centre de la tuile contenante.
	site.x = _snap_to_tile_centre(site.x)
	site.z = _snap_to_tile_centre(site.z)

	var s: float = float(seed_world)
	var n1: float = CWValueNoise.sample(s + float(rx) * 1.4, s + float(rz) * 1.4 + 843.0)
	var n2: float = CWValueNoise.sample(s + float(rx) * 4.0, s + float(rz) * 4.0 + 843.0)
	site.base_height = int((n1 + 1.0) * 100.0 - 70.0 + n2 * 30.0)

	if site.base_height < 1:
		site.wet = false
		if is_start:
			# Le point de départ n'est jamais noyé.
			site.base_height = rng.mod(50) + 20
			return site
		site.base_height = maxi(site.base_height - 100, -100)
		if rng.coin():
			site.temperature = rng.unit() * 0.1 + 0.9
			site.humidity = rng.unit() * 0.1 + 0.9
		else:
			site.temperature = rng.unit() * 0.4 + 0.3
			site.humidity = rng.unit() * 0.4 + 0.4

	return site


static func _snap_to_tile_centre(v: int) -> int:
	return (floori(float(v) / float(TILE_SIZE)) * TILE_SIZE) + TILE_HALF


## Fenêtre 3 x 3 de sites ancrée en (zx0, zz0), mémoïsée.
##
## Tous les mélanges du générateur (climat, altitude de base, marais) travaillent
## sur cette même fenêtre : la mettre en cache d'un bloc évite dix-huit
## consultations verrouillées par colonne. Les entrées hors grille valent null.
func get_window(zx0: int, zz0: int) -> Array:
	var key: int = (zx0 + 1) * (ZONE_GRID + 2) + (zz0 + 1)
	_mutex.lock()
	var hit: Variant = _window_cache.get(key)
	_mutex.unlock()
	if hit != null:
		return hit
	var win: Array = []
	win.resize(9)
	for i in 3:
		for j in 3:
			win[i * 3 + j] = get_site(zx0 + i, zz0 + j)
	_mutex.lock()
	if _window_cache.has(key):
		win = _window_cache[key]
	else:
		_window_cache[key] = win
	_mutex.unlock()
	return win
