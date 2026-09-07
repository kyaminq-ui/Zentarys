class_name CWWorldMap
extends RefCounted

## Carte du monde (jalon 1.10). Portage de `cube::WorldMap` et de
## `GameController::loadLandscapeTile` (@006024d0). Analyse complète :
## `docs/systems/05`.
##
## -- Ce que la carte est ------------------------------------------------------
## Un pixel par **chunk de 256 unités** — l'unité que le jalon 1.8 avait
## retrouvée, et que `WorldMap::getTile` (@00602440) confirme en bornant ses
## coordonnées à `[0, 0x10000)`. Soit 64 × 64 cases par zone, 65 536 de côté
## pour le monde entier.
##
## Un « pays » n'est pas une zone : c'est la **cellule de Voronoï du site de
## région dans le domaine déformé**. `loadLandscapeTile` balaie la zone plus une
## zone de marge, déforme chaque point et ne garde que ceux dont le site le plus
## proche est celui de la zone. Frontières ondulées, pièces de puzzle — et ce
## sont exactement les frontières du climat, puisque le mélange de sites du
## jalon 1.3 emploie le même point déformé.
##
## -- Ce que la carte n'est pas ------------------------------------------------
## L'image stockée par l'original **ne porte aucune couleur** : trois clartés et
## rien d'autre (§4 de la note). La teinte vient du dessin. Ce portage garde la
## même séparation : la clarté est une propriété du chunk (découvert ou non), la
## teinte une propriété de la région, et elles ne se rencontrent qu'au rendu.
##
## -- Trois écarts délibérés, détaillés en `docs/systems/05`, §7 ---------------
##   1. dalle de 64 × 64 par zone plutôt que pièce à sa boîte englobante : même
##      géométrie, cache qui se juxtapose sans recouvrement ;
##   2. teinte d'une région échantillonnée à son site ;
##   3. **la carte a sa propre table de couleurs, indexée par biome** — voir
##      `teinte_de`. Elle recopiait celle du terrain jusqu'au 2026-09-12.
##
## -- Fils ---------------------------------------------------------------------
## `slab()` et `render()` échantillonnent le champ de terrain : ~9 µs par case,
## 38 ms par dalle. À appeler depuis un fil du pool, jamais depuis `_process`.
## Les caches sont sous mutex ; la découverte se marque, elle, sur le fil
## principal (c'est un dictionnaire écrit à chaque déplacement du joueur).

# -- L'échelle ----------------------------------------------------------------

## Unités monde par case de carte. `WorldMap::getTile` borne à `0x10000` cases
## pour `0x1000000` unités : une case vaut 256 unités, c'est-à-dire un chunk.
const CHUNK_SHIFT: int = 8
const CHUNK_SIZE: int = 1 << CHUNK_SHIFT
## Cases par zone : `x & 0x3f` puis `* 0x40` dans l'indexation d'origine.
const CHUNKS_PER_ZONE: int = 64
## Côté de la grille de cases du monde entier (`0x10000`).
const CHUNK_GRID: int = CWWorldParams.ZONE_GRID * CHUNKS_PER_ZONE

# -- Les trois clartés, verbatim ----------------------------------------------

## Aucune case connue : le joueur n'est jamais passé assez près.
const SHADE_UNKNOWN: int = 200
## Case connue (chargée), jamais découverte.
const SHADE_KNOWN: int = 220
## Case découverte.
const SHADE_DISCOVERED: int = 255

# -- Icône de région ----------------------------------------------------------
# `WorldMap::ctor_1` charge cinq modèles nommés — plains, village, forest,
# mountains, hills — plus `skull.cub`. Village et crâne se posent sur des
# éléments de tuile (§5) ; les quatre autres décrivent le *terrain* d'une
# région, donc son site. La règle de choix, elle, n'est pas dans les fonctions
# lues : celle ci-dessous est reconstruite sur l'altitude de base et le climat.

const ICON_NONE: int = 0
const ICON_PLAINS: int = 1
const ICON_FOREST: int = 2
const ICON_HILLS: int = 3
const ICON_MOUNTAINS: int = 4
## Marqueurs posés sur un élément de tuile.
const ICON_VILLAGE: int = 5
const ICON_SKULL: int = 6

## Seuils d'altitude de base, en blocs, des deux icônes de relief.
const ICON_MOUNTAIN_HEIGHT: float = 200.0
const ICON_HILL_HEIGHT: float = 90.0

## Types d'éléments de tuile qui posent un village sur la carte : le bourg
## (1, un par zone, posé sur le site) et la parcelle bâtie (3). Identités
## établies en `docs/systems/02`, §4.
##
## Le type 14 en est **exclu** : la feuille de route le dit calé sur la grille de
## 256 et tiré à ~16 par zone, et l'inclure met dix-huit villages par région sur
## la carte — mesuré le 2026-09-05. Un type à seize exemplaires par zone n'est
## pas une agglomération ; son identité reste ouverte (`docs/systems/02`).
const VILLAGE_FEATURES: Array[int] = [1, 3]
## Le donjon (10) porte le crâne.
const SKULL_FEATURES: Array[int] = [10]

## Sentinelle des cases hors du monde.
const NO_OWNER: int = -1

## Dalle de carte : les 64 × 64 cases d'une zone, chacune portant l'indice de la
## zone propriétaire de sa pièce de puzzle.
class Slab extends RefCounted:
	var zx: int = 0
	var zz: int = 0
	## `CHUNKS_PER_ZONE²` entrées, dans l'ordre `cz + cx * 64`, valant
	## `ozx * 1024 + ozz` ou `NO_OWNER`.
	var owners: PackedInt32Array = PackedInt32Array()
	## Zones effectivement présentes dans la dalle, pour n'en teinter que
	## celles-là.
	var zones: PackedInt32Array = PackedInt32Array()

	## Une classe interne ne voit pas les constantes de la classe englobante :
	## on passe par le nom global.
	func owner_at(cx: int, cz: int) -> int:
		return owners[cz + cx * CWWorldMap.CHUNKS_PER_ZONE]


var _field: CWTerrainField
var _names: CWRegionName

var _slabs: Dictionary = {}
var _tints: Dictionary = {}
var _icons: Dictionary = {}
var _mutex: Mutex = Mutex.new()

## Cases découvertes et cases seulement connues. Deux ensembles, comme les deux
## bits de drapeau de `cube::ZoneTile` (+0x30).
var _discovered: Dictionary = {}
var _known: Dictionary = {}

## Le compteur de découverte : le seul état que l'original persiste, en quatre
## octets sous la clé `discovered`.
var discovered_count: int = 0


func _init(field: CWTerrainField) -> void:
	_field = field
	_names = CWRegionName.new(field)


func names() -> CWRegionName:
	return _names


# -- Coordonnées --------------------------------------------------------------

## Case de carte contenant une coordonnée monde. Décalage arithmétique : la
## taille est une puissance de deux, donc c'est la division entière par défaut,
## négatifs compris.
static func chunk_of(v: int) -> int:
	return v >> CHUNK_SHIFT


## Zone contenant une case de carte.
static func zone_of_chunk(c: int) -> int:
	return c >> 6


static func _chunk_key(cx: int, cz: int) -> int:
	return cx * CHUNK_GRID + cz


static func _zone_key(zx: int, zz: int) -> int:
	return zx * CWWorldParams.ZONE_GRID + zz


static func in_world(cx: int, cz: int) -> bool:
	return cx >= 0 and cz >= 0 and cx < CHUNK_GRID and cz < CHUNK_GRID


# -- Découverte ---------------------------------------------------------------

## Marque découverte la case qui contient le point monde (x, z).
## Rend vrai si c'est la première fois — c'est cette condition qui incrémente le
## compteur dans l'original.
func discover(x: int, z: int) -> bool:
	return discover_chunk(chunk_of(x), chunk_of(z))


func discover_chunk(cx: int, cz: int) -> bool:
	if not in_world(cx, cz):
		return false
	var key: int = _chunk_key(cx, cz)
	if _discovered.has(key):
		return false
	_discovered[key] = true
	_known[key] = true
	discovered_count += 1
	return true


## Marque connue — chargée, pas visitée — la case (cx, cz). C'est le second bit
## de drapeau de l'original, celui que pose le chargement des données du chunk.
func mark_known_chunk(cx: int, cz: int) -> bool:
	if not in_world(cx, cz):
		return false
	var key: int = _chunk_key(cx, cz)
	if _known.has(key):
		return false
	_known[key] = true
	return true


## Marque connues les cases d'un carré de `radius` unités monde autour du point,
## et découverte celle qui le contient. C'est le geste du joueur qui avance :
## il découvre là où il est, et connaît ce qu'il voit.
func visit(x: int, z: int, radius: int) -> void:
	discover(x, z)
	var r: int = maxi(radius >> CHUNK_SHIFT, 0)
	var cx: int = chunk_of(x)
	var cz: int = chunk_of(z)
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			mark_known_chunk(cx + dx, cz + dz)


func is_discovered(cx: int, cz: int) -> bool:
	return _discovered.has(_chunk_key(cx, cz))


func is_known(cx: int, cz: int) -> bool:
	return _known.has(_chunk_key(cx, cz))


## Clarté d'une case : les trois valeurs de l'original, dans le même ordre.
func shade_at(cx: int, cz: int) -> int:
	var key: int = _chunk_key(cx, cz)
	if _discovered.has(key):
		return SHADE_DISCOVERED
	if _known.has(key):
		return SHADE_KNOWN
	return SHADE_UNKNOWN


# -- Persistance --------------------------------------------------------------
# L'original ne sauve que le compteur ; les bits vivent dans les blobs de région.
# Ici il n'y a pas de blob de région, donc on écrit les deux ensembles — c'est
# quelques dizaines de kilo-octets pour un monde longuement parcouru, et ça évite
# d'inventer un second format de stockage.

const SAVE_MAGIC: int = 0x5A4D4150  # "ZMAP"
const SAVE_VERSION: int = 1


func save_discovery(path: String) -> Error:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_32(SAVE_MAGIC)
	f.store_32(SAVE_VERSION)
	f.store_32(_discovered.size())
	f.store_32(_known.size())
	for key: int in _discovered:
		f.store_64(key)
	for key: int in _known:
		f.store_64(key)
	f.close()
	return OK


func load_discovery(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return FileAccess.get_open_error()
	if f.get_32() != SAVE_MAGIC or f.get_32() != SAVE_VERSION:
		return ERR_FILE_UNRECOGNIZED
	var n_disc: int = f.get_32()
	var n_known: int = f.get_32()
	_discovered.clear()
	_known.clear()
	for i in n_disc:
		_discovered[f.get_64()] = true
	for i in n_known:
		_known[f.get_64()] = true
	discovered_count = _discovered.size()
	return OK


# -- La géométrie du puzzle ---------------------------------------------------

## Dalle de la zone (zx, zz), construite au besoin puis mémoïsée.
##
## Une case appartient à la zone dont le site est le plus proche du point
## déformé — la recherche même que `CWTerrainField.nearest_site` porte depuis le
## jalon 1.6, et que `loadLandscapeTile` refait ici sur la grille de chunks.
##
## Le point échantillonné est le **coin** de la case (`case << 8`), comme dans
## l'original, et non son centre : le décalage d'un demi-chunk se verrait sur la
## frontière si on le corrigeait d'un côté seulement.
func slab(zx: int, zz: int) -> Slab:
	var key: int = _zone_key(zx, zz)
	_mutex.lock()
	var hit: Variant = _slabs.get(key)
	_mutex.unlock()
	if hit != null:
		return hit

	var s := Slab.new()
	s.zx = zx
	s.zz = zz
	s.owners = PackedInt32Array()
	s.owners.resize(CHUNKS_PER_ZONE * CHUNKS_PER_ZONE)
	var seen: Dictionary = {}
	var base_x: int = zx * CHUNKS_PER_ZONE
	var base_z: int = zz * CHUNKS_PER_ZONE
	var i: int = 0
	for cx in CHUNKS_PER_ZONE:
		for cz in CHUNKS_PER_ZONE:
			var owner: int = _owner_of_chunk(base_x + cx, base_z + cz)
			s.owners[i] = owner
			i += 1
			if owner != NO_OWNER:
				seen[owner] = true
	s.zones = PackedInt32Array(seen.keys())

	_mutex.lock()
	# Une autre tâche a pu gagner la course : on garde la première dalle, comme
	# la grille de sites garde le premier site.
	if _slabs.has(key):
		s = _slabs[key]
	else:
		_slabs[key] = s
	_mutex.unlock()
	return s


## Zone propriétaire d'une case de carte, ou `NO_OWNER`.
func _owner_of_chunk(cx: int, cz: int) -> int:
	if not in_world(cx, cz):
		return NO_OWNER
	var site: CWRegionSite = _field.nearest_site(cx << CHUNK_SHIFT, cz << CHUNK_SHIFT)
	if site == null:
		return NO_OWNER
	return _zone_key(
			CWWorldParams.zone_of(site.x),
			CWWorldParams.zone_of(site.z))


# -- Teinte et icône d'une région ---------------------------------------------

# -- La couleur d'une région : une légende, pas une photographie --------------
#
# La carte peignait une région avec **la couleur de son terrain**
# (`CWPalette.colors()[surface_index]`). C'est ce qui paraît le plus honnête, et
# c'est ce qui a rendu la carte illisible : la neige est `(125, 181, 199)` et
# l'eau `(42, 200, 252)`, deux cyans clairs, et une Snowlands côtière était donc
# de la même couleur que la mer qui la borde. **Une carte qui recopie le sol
# recopie aussi ses confusions.**
#
# Le remède n'était pas de repeindre la palette : `SNOW` est un type de bloc
# écrit dans le monde, et le changer pour régler un problème de carte aurait
# repeint toute la neige du jeu. C'est la carte qui prend sa propre table, et
# elle l'indexe par **biome** et non par matière de surface — invariant n° 27,
# vu du côté de la lecture : `CWBiome.at` dit *où on est*, et c'est cela qu'une
# carte doit dire.
#
# Six teintes franches, choisies pour se distinguer les unes des autres, valent
# mieux que dix teintes justes qui se ressemblent. Le couple qui décidait est
# neige / océan : il va maintenant d'un blanc à peine bleuté à un bleu profond,
# et aucun écran ne les confond. Le second couple à surveiller est prairie /
# jungle, deux verts : ils sont séparés par la clarté autant que par la teinte.
#
# Elle règle aussi le cas où deux biomes partagent une matière — depuis le
# 2026-09-12 la neige d'une Snowlands et sa banquise sont le même bloc — et
# celui de l'océan, qui touche partout de la neige, du sable et de l'herbe.
## Le vert franc de la prairie.
const TEINTE_GREENLANDS: Color = Color8(104, 166, 84)
## Un blanc a peine bleute. C'est le premier des deux couples a se confondre :
## il doit rester loin de `TEINTE_OCEANS`.
const TEINTE_SNOWLANDS: Color = Color8(232, 240, 247)
## L'ocre du sable, plus sourd qu'en jeu : sur une carte, un jaune vif tire
## l'oeil vers le desert et le fait paraitre plus grand qu'il n'est.
const TEINTE_DESERTS: Color = Color8(224, 188, 106)
## Un vert sombre et sature. Deux couples se surveillent ici, et le second n'est
## pas celui qu'on attend : la prairie, evidemment — les deux sont separes par
## la clarte autant que par la teinte —, mais aussi **l'ocean**, parce que deux
## couleurs sombres se rapprochent bien plus vite que deux claires. C'est la
## mesure de `tests/map_test.gd` qui l'a dit, pas l'oeil.
const TEINTE_JUNGLES: Color = Color8(30, 122, 52)
## La brique de la scorie refroidie.
const TEINTE_LAVALANDS: Color = Color8(158, 66, 44)
## Un bleu profond, jamais un cyan.
const TEINTE_OCEANS: Color = Color8(32, 72, 150)


## La teinte de carte d'un biome. Un `match` et non un tableau : une entree
## nommee se relit, et le compilateur refuse un tableau de `Color8` en constante.
static func teinte_de(biome: int) -> Color:
	match biome:
		CWBiome.GREENLANDS: return TEINTE_GREENLANDS
		CWBiome.SNOWLANDS: return TEINTE_SNOWLANDS
		CWBiome.DESERTS: return TEINTE_DESERTS
		CWBiome.JUNGLES: return TEINTE_JUNGLES
		CWBiome.LAVALANDS: return TEINTE_LAVALANDS
		CWBiome.OCEANS: return TEINTE_OCEANS
		_: return Color(0.5, 0.5, 0.5)

## Le biome d'une région, pris **à son site** — le point dont tout son climat
## découle, et celui qui décide son biome depuis le 2026-09-12.
##
## -- L'océan se lit sur la région, pas sur une colonne -----------------------
##
## La carte échantillonnait une colonne au site et la peignait en eau si elle
## tombait sous le niveau de la mer. Mesure du 2026-09-12 : sur les 81 régions
## autour du point de départ, **28 sont océaniques et aucune ne rendait de
## l'eau**. La raison est que le champ d'altitude mélange neuf sites : au point
## même d'un site posé à -100, les voisins et le bruit ramènent la colonne à
## +7, +25, +2 — de la terre, à un niveau de mer de -60. Une colonne au site
## dit ce qu'il y a *sous les pieds du site*, et non ce qu'est la région.
##
## Ce que la région *est*, la source le dit : `base_height < 1` la rend
## océanique, et c'est le drapeau que `is_ocean` porte. La carte le lit donc
## directement — c'est déjà ce que fait `icon_of_zone`, et les deux disent
## maintenant la même chose.
##
## **Une carte n'est pas une photographie**, et c'est ici que ça se voit le
## plus : une région marine porte des îles, et une île n'y sera pas peinte. Ce
## qu'on peint est *un pays de mer*, pas la ligne de rivage — laquelle demande
## une case par chunk, soit 4 096 fois le coût.
func biome_of_zone(zx: int, zz: int) -> int:
	var site: CWRegionSite = _field.sites().get_site(zx, zz)
	if site == null or site.is_ocean():
		return CWBiome.OCEANS
	return CWBiome.of_climate(site.temperature, site.humidity)


## Couleur d'une région : celle de son biome.
##
## Une seule lecture de site par région, mémoïsée. Elle échantillonnait encore
## une colonne jusqu'au 2026-09-12 — 74 µs — et n'en a plus besoin : le biome
## d'une région se lit sur son site. L'image d'origine ne porte de toute façon
## pas de couleur (§4), donc rien n'est perdu en fidélité.
func tint_of_zone(zx: int, zz: int) -> Color:
	var key: int = _zone_key(zx, zz)
	_mutex.lock()
	var hit: Variant = _tints.get(key)
	_mutex.unlock()
	if hit != null:
		return hit

	var c: Color = teinte_de(biome_of_zone(zx, zz))
	c.a = 1.0

	_mutex.lock()
	_tints[key] = c
	_mutex.unlock()
	return c


## Icône de relief d'une région. Voir la remarque des constantes : la règle de
## choix est reconstruite, seuls les six modèles chargés sont attestés.
func icon_of_zone(zx: int, zz: int) -> int:
	var key: int = _zone_key(zx, zz)
	_mutex.lock()
	var hit: Variant = _icons.get(key)
	_mutex.unlock()
	if hit != null:
		return hit

	var icon: int = ICON_NONE
	var site: CWRegionSite = _field.sites().get_site(zx, zz)
	if site != null and not site.is_ocean():
		var h: float = float(site.base_height)
		if h >= ICON_MOUNTAIN_HEIGHT:
			icon = ICON_MOUNTAINS
		elif h >= ICON_HILL_HEIGHT:
			icon = ICON_HILLS
		elif site.humidity > 0.55 and site.temperature > 0.3:
			icon = ICON_FOREST
		else:
			icon = ICON_PLAINS

	_mutex.lock()
	_icons[key] = icon
	_mutex.unlock()
	return icon


# -- Marqueurs ----------------------------------------------------------------

## Marqueurs d'une zone : un dictionnaire par élément de tuile porteur d'un
## symbole, avec sa case de carte.
##
## Traçabilité : `loadLandscapeTile` recopie, après les résumés de chunks, les
## 64 enregistrements de `0x68` octets pris à `+0x14018` de la région — les
## éléments de tuile du jalon 1.6, relevés une troisième fois par ce couple.
func markers_of_zone(zx: int, zz: int) -> Array:
	var out: Array = []
	if zx < 0 or zz < 0 or zx >= CWWorldParams.ZONE_GRID or zz >= CWWorldParams.ZONE_GRID:
		return out
	for f: CWTileFeature in _field.features().get_zone(zx, zz, _field):
		if f == null or f.type == 0:
			continue
		var icon: int = ICON_NONE
		if f.type in VILLAGE_FEATURES:
			icon = ICON_VILLAGE
		elif f.type in SKULL_FEATURES:
			icon = ICON_SKULL
		if icon == ICON_NONE:
			continue
		out.append({
			"icon": icon,
			"chunk": Vector2i(chunk_of(int(f.x)), chunk_of(int(f.z))),
			"type": f.type,
			"difficulty": f.difficulty,
		})
	return out


# -- Rendu --------------------------------------------------------------------

## Image de `nx × nz` zones à partir de la zone (zx0, zz0), à une case par pixel.
##
## Chaque pixel prend la teinte de sa région, assombrie par la clarté de sa case.
## Les frontières du puzzle sont retrouvées ici, là où deux cases voisines
## changent de propriétaire — l'original les tient d'un sprite par pièce, nous
## d'une comparaison.
func render(zx0: int, zz0: int, nx: int, nz: int) -> Image:
	var w: int = nx * CHUNKS_PER_ZONE
	var h: int = nz * CHUNKS_PER_ZONE
	var owners := PackedInt32Array()
	owners.resize(w * h)

	for sx in nx:
		for sz in nz:
			var s: Slab = slab(zx0 + sx, zz0 + sz)
			for cx in CHUNKS_PER_ZONE:
				var px: int = sx * CHUNKS_PER_ZONE + cx
				var row: int = px * h + sz * CHUNKS_PER_ZONE
				for cz in CHUNKS_PER_ZONE:
					owners[row + cz] = s.owners[cz + cx * CHUNKS_PER_ZONE]

	# Une teinte par région présente, prise une fois : le rendu ne doit pas
	# rechercher dans un dictionnaire une fois par pixel.
	var tints: Dictionary = {}
	for o: int in owners:
		if o != NO_OWNER and not tints.has(o):
			@warning_ignore("integer_division")
			tints[o] = tint_of_zone(o / CWWorldParams.ZONE_GRID, o % CWWorldParams.ZONE_GRID)

	var data := PackedByteArray()
	data.resize(w * h * 4)
	var base_cx: int = zx0 * CHUNKS_PER_ZONE
	var base_cz: int = zz0 * CHUNKS_PER_ZONE
	for px in w:
		for pz in h:
			var k: int = (pz * w + px) * 4
			var owner: int = owners[px * h + pz]
			if owner == NO_OWNER:
				data[k + 3] = 0
				continue
			var shade: float = float(shade_at(base_cx + px, base_cz + pz)) / 255.0
			# Un bord se voit au changement de propriétaire, pas au bord de
			# l'image : une dalle interrompue n'en produit pas.
			if _is_edge(owners, w, h, px, pz, owner):
				shade *= 0.45
			var c: Color = tints[owner]
			data[k] = int(clampf(c.r * shade, 0.0, 1.0) * 255.0)
			data[k + 1] = int(clampf(c.g * shade, 0.0, 1.0) * 255.0)
			data[k + 2] = int(clampf(c.b * shade, 0.0, 1.0) * 255.0)
			data[k + 3] = 255
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)


static func _is_edge(owners: PackedInt32Array, w: int, h: int,
		px: int, pz: int, owner: int) -> bool:
	if px > 0 and owners[(px - 1) * h + pz] != owner:
		return true
	if px < w - 1 and owners[(px + 1) * h + pz] != owner:
		return true
	if pz > 0 and owners[px * h + pz - 1] != owner:
		return true
	if pz < h - 1 and owners[px * h + pz + 1] != owner:
		return true
	return false


## Marqueurs d'une vue, en pixels de l'image rendue par `render`.
func render_markers(zx0: int, zz0: int, nx: int, nz: int) -> Array:
	var out: Array = []
	var base_cx: int = zx0 * CHUNKS_PER_ZONE
	var base_cz: int = zz0 * CHUNKS_PER_ZONE
	for sx in nx:
		for sz in nz:
			var zx: int = zx0 + sx
			var zz: int = zz0 + sz
			for m: Dictionary in markers_of_zone(zx, zz):
				var c: Vector2i = m["chunk"]
				var e: Dictionary = m.duplicate()
				e["pixel"] = Vector2i(c.x - base_cx, c.y - base_cz)
				out.append(e)
			# L'icône de relief se pose au site, qui est le point dont tout le
			# climat de la région découle.
			#
			# **Le nom ne dépend plus de l'icône**, et c'était la première des
			# deux causes de « la carte ne nomme qu'une région sur deux » : une
			# région d'océan rend `ICON_NONE`, et le `and icon != ICON_NONE` qui
			# gardait cette ligne la laissait donc **sans nom par
			# construction** — un sixième du monde. Un nom appartient à la
			# région, pas à son relief ; l'icône est ce qui peut manquer.
			var site: CWRegionSite = _field.sites().get_site(zx, zz)
			if site == null:
				continue
			out.append({
				"icon": icon_of_zone(zx, zz),
				"chunk": Vector2i(chunk_of(site.x), chunk_of(site.z)),
				"pixel": Vector2i(chunk_of(site.x) - base_cx,
						chunk_of(site.z) - base_cz),
				"zone": Vector2i(zx, zz),
				"name": _names.of_zone(zx, zz),
			})
	return out


## Nombre de dalles en cache, pour l'ATH et les tests.
func slab_count() -> int:
	_mutex.lock()
	var n: int = _slabs.size()
	_mutex.unlock()
	return n


func clear_cache() -> void:
	_mutex.lock()
	_slabs.clear()
	_tints.clear()
	_icons.clear()
	_mutex.unlock()
