class_name CWMesaGrid
extends RefCounted

## Grille paresseuse de **surplombs** : une cellule de 512 unites monde, au plus
## un surplomb par cellule, construits d'un bloc et memoises.
##
## -- Combien, et ou ----------------------------------------------------------
##
## Un tirage uniforme donnerait des mesas partout a la meme frequence, ce qui
## est exactement ce que les captures du jeu d'origine ne montrent pas : on y
## voit soit une **butte isolee** au milieu d'une prairie, soit un **canyon**
## entier ou elles se touchent presque. La chance de la cellule est donc
## modulee par un bruit tres basse frequence — c'est la meme idee que la crete
## de placement du decor, a une echelle mille fois plus grande : le monde a des
## *pays de canyons*, et entre eux des plaines ou l'on croise une butte de temps
## en temps.
##
## -- Pas de recursion, et c'est ce qui rend la couche bon marche -------------
##
## Le constructeur d'une cellule echantillonne le terrain (`sample_column_raw`)
## pour savoir a quelle altitude poser le chapeau et le plancher des grottes.
## Il peut le faire librement : le champ d'altitude ne consulte **jamais** cette
## grille — les surplombs sont poses par-dessus lui, pas dedans. C'est la
## difference avec `CWTileFeatureGrid`, qui deforme le champ et doit donc se
## garder contre sa propre relecture par trois verrous et une garde de
## reentrance. Voir l'en-tete de `CWMesa`.
##
## -- Creation de ce projet ---------------------------------------------------
##
## Toute cette couche l'est, et la charte demande de le dire : le binaire de
## l'alpha n'a pas de generateur de surplombs. Voir `CWMesa`.

## Cote d'une cellule, en unites monde. Choisi en regard de la distance de vue :
## a 512, un champ de vision de 384 blocs traverse une cellule ou deux, donc un
## pays de canyons se lit sans qu'une plaine soit saturee.
const CELL: int = 512
const CELL_SHIFT: int = 9
const CELL_GRID: int = CWWorldParams.WORLD_SIZE >> CELL_SHIFT

## Frequence du champ de densite regionale. A 6e-5, la longueur d'onde est de
## ~16 000 blocs, soit la taille d'une zone : un pays de canyons fait la taille
## d'une region, ce qui est l'echelle a laquelle on nomme un paysage.
const REGION_FREQ: float = 0.00006
const REGION_OFFSET_X: float = 774311.0
const REGION_OFFSET_Z: float = 316007.0
## Chance d'une cellule dans une plaine, puis dans un pays de canyons.
const CHANCE_MIN: float = 0.18
const CHANCE_MAX: float = 1.0
## Exposant applique au champ de densite. Plus il est grand, plus les pays de
## canyons sont rares et tranches.
const REGION_EXPONENT: float = 2.0

## Rayon nominal d'un massif, en blocs. **Reduit le 2026-09-08** : la premiere
## generation montait a 143, ce qui faisait des objets qu'on regarde plutot que
## des reliefs qu'on parcourt.
const RADIUS_MIN: int = 34
const RADIUS_SPAN: int = 80

## Hauteur de la masse, en fraction de son rayon.
##
## **C'est la constante qui decide si le massif est escaladable.** Le dessus
## suit `1 - u²` : sa pente radiale vaut `2 x hauteur / rayon` au bord, donc a
## 0,34 elle plafonne a 0,68 bloc par bloc avant les deux bruits de forme.
## Au-dela de 0,45, la masse porte des marches qu'on ne franchit pas, et une
## verification mesure la pente reelle plutot que de faire confiance a ce
## calcul — les bruits s'y ajoutent.
const HEIGHT_PER_RADIUS_MIN: float = 0.34
const HEIGHT_PER_RADIUS_SPAN: float = 0.20
## Plancher de hauteur, en blocs : un massif de rayon 26 ne doit pas etre une
## bosse de sept blocs qu'on ne remarque pas.
const HEIGHT_MIN: int = 18

## Altitude minimale du sol, au-dessus de la mer, pour qu'un massif soit pose.
const GROUND_MIN_ABOVE_SEA: float = 6.0

const CAVE_RADIUS_MIN: int = 5
const CAVE_RADIUS_SPAN: int = 4
const CAVE_HEIGHT_MIN: int = 5
const CAVE_HEIGHT_SPAN: int = 4
## Hauteur libre minimale au-dessus du plancher pour qu'un lobe soit garde.
const CAVE_HEADROOM_MIN: int = 6
## Longueur d'une galerie, en fraction du rayon du massif. **Doublee le
## 2026-09-08** : les tubes precedents s'arretaient au tiers du rayon, on voyait
## le fond depuis l'entree, et rien ne meritait qu'on y entre.
const CAVE_LEN_MIN: float = 0.55
const CAVE_LEN_SPAN: float = 0.75
## Nombre de coudes de l'axe. C'est ce qui empeche de voir le fond depuis
## l'entree, et c'est aussi ce qui rend la galerie plus longue que sa profondeur.
const CAVE_BENDS_MIN: int = 2
const CAVE_BENDS_SPAN: int = 3
## Ecart lateral d'un coude, en fraction de la longueur du segment.
const CAVE_BEND_SWING: float = 0.55

var _params: CWWorldParams
var _cells: Dictionary = {}
var _mutex: Mutex = Mutex.new()
var _build_mutex: Mutex = Mutex.new()
var _empty: Array[CWMesa] = []


func _init(params: CWWorldParams) -> void:
	_params = params
	_empty.make_read_only()


func clear_cache() -> void:
	_mutex.lock()
	_cells.clear()
	_mutex.unlock()


static func cell_of(v: int) -> int:
	return v >> CELL_SHIFT


## Les surplombs de la cellule (cx, cz) — zero ou un.
func get_cell(cx: int, cz: int, field: CWTerrainField) -> Array[CWMesa]:
	if cx < 0 or cz < 0 or cx >= CELL_GRID or cz >= CELL_GRID:
		return _empty
	var key: int = cx * 65536 + cz

	_mutex.lock()
	var hit: Variant = _cells.get(key)
	_mutex.unlock()
	if hit != null:
		return hit

	# Deux fils qui tombent sur la meme cellule construiraient le meme resultat,
	# mais chacun paierait ses echantillons de terrain. Le second attend.
	_build_mutex.lock()
	_mutex.lock()
	hit = _cells.get(key)
	_mutex.unlock()
	if hit != null:
		_build_mutex.unlock()
		return hit
	var built: Array[CWMesa] = _build_cell(cx, cz, field)
	_mutex.lock()
	_cells[key] = built
	_mutex.unlock()
	_build_mutex.unlock()
	return built


## Les surplombs dont l'emprise peut atteindre la colonne : le voisinage 3 x 3
## de sa cellule. Le rayon maximum d'un surplomb, deformation comprise, vaut
## 176 unites — bien moins qu'une cellule —, donc trois cellules suffisent.
##
## **A appeler une fois par cellule traversee, pas une fois par colonne.** Les
## 256 colonnes d'un bloc tombent dans une ou deux cellules ; c'est la meme
## economie que celle de `sample_patch` sur la fenetre de sites, et elle compte
## d'autant plus ici que la construction prend un verrou.
func get_window(cx: int, cz: int, field: CWTerrainField) -> Array[CWMesa]:
	var out: Array[CWMesa] = []
	for i in 3:
		for j in 3:
			for m in get_cell(cx - 1 + i, cz - 1 + j, field):
				out.append(m)
	return out


## Les surplombs pouvant atteindre la colonne (x, z), en coordonnees monde.
func mesas_at(x: int, z: int, field: CWTerrainField) -> Array[CWMesa]:
	return get_window(cell_of(x), cell_of(z), field)


## Relief ajoute par les surplombs a une colonne, bornes **incluses** :
## `(dalle_bas, dalle_haut, grotte_bas, grotte_haut)`. Un intervalle vide se dit
## `bas > haut`, et c'est le cas des deux pour la quasi-totalite du monde.
##
## **La dalle vient d'un seul surplomb**, celui dont la colonne est le plus au
## coeur : deux chapeaux qui se recouvrent donneraient sinon deux dessus plats a
## des altitudes differentes dans la meme colonne, et il n'y a qu'une place. Les
## **grottes**, elles, sont prises de tous : un tube qui passe sous un voisin le
## perce aussi, ce qui est la bonne reponse — c'est de l'air, et l'air se
## reunit.
static func relief(window: Array[CWMesa], x: int, z: int,
		ground_top: int) -> Vector4i:
	var slab := Vector2i(1, 0)
	var cave := Vector2i(1, 0)
	var best_f: float = 0.0
	for m in window:
		var f: float = m.shape(x, z)
		if f > best_f:
			best_f = f
			slab = m.slab_from_shape(f, ground_top, x, z)
		if cave.x > cave.y:
			cave = m.cave(x, z)
	return Vector4i(slab.x, slab.y, cave.x, cave.y)


## Chance qu'une cellule porte un surplomb, a cet endroit du monde.
static func chance_at(x: int, z: int) -> float:
	var n: float = CWValueNoise.sample01(
			float(x) * REGION_FREQ + REGION_OFFSET_X,
			float(z) * REGION_FREQ + REGION_OFFSET_Z)
	return CHANCE_MIN + (CHANCE_MAX - CHANCE_MIN) * pow(n, REGION_EXPONENT)


func _build_cell(cx: int, cz: int, field: CWTerrainField) -> Array[CWMesa]:
	var out: Array[CWMesa] = []
	var x0: int = cx << CELL_SHIFT
	var z0: int = cz << CELL_SHIFT

	# Graine propre a la cellule. Le flux est independant de celui des sites de
	# region et de celui des elements de tuile : cette couche peut donc changer
	# sans deplacer un seul bloc du relief existant, ce qui est la propriete qui
	# permet de la regler en la regardant.
	var rng := CWRand.new((_params.world_seed * 2654435761 + cx * 73856093
			+ cz * 19349663) & 0xFFFFFFFF)
	# Deux tirages a vide : le LCG de la CRT MSVC a un premier tirage tres
	# correle a sa graine, et deux graines voisines rendraient deux cellules
	# voisines trop semblables.
	rng.next()
	rng.next()

	if rng.unit() >= chance_at(x0 + (CELL >> 1), z0 + (CELL >> 1)):
		return out

	var mx: int = x0 + rng.mod(CELL)
	var mz: int = z0 + rng.mod(CELL)
	var ground: float = field.sample_column(mx, mz).x
	if ground - float(_params.sea_level) < GROUND_MIN_ABOVE_SEA:
		return out

	var m := CWMesa.new()
	m.x = float(mx)
	m.z = float(mz)
	m.radius = float(RADIUS_MIN + rng.mod(RADIUS_SPAN))
	m.base_y = floori(ground)
	# `f²` divise la hauteur utile par deux au coeur : la constante est prise
	# sur la hauteur **nominale**, celle qu'atteindrait un dome sans son raccord
	# tangentiel, et le massif reel monte moins haut.
	m.height = maxf(float(HEIGHT_MIN), m.radius * (HEIGHT_PER_RADIUS_MIN
			+ rng.unit() * HEIGHT_PER_RADIUS_SPAN))
	m.warp_ox = float(rng.next() * 32768 + rng.next())
	m.warp_oz = float(rng.next() * 32768 + rng.next())

	_add_caves(m, rng, field)
	out.append(m)
	return out


## Perce la masse d'une a deux galeries.
##
## **L'entree est prise sur le flanc**, la ou la masse rencontre le terrain :
## le plancher du tube y est l'altitude du sol, donc on entre de plain-pied dans
## un trou qui donne dehors. C'est la garantie demandee — *jamais besoin de
## creuser* — et elle est geometrique, pas numerique.
##
## Ce qui a change le 2026-09-08, sur trois reproches faits a la premiere
## version :
##
##   * **plus profondes.** La longueur passe du tiers du rayon a la moitie ou
##     davantage, et l'axe **serpente** : la galerie est plus longue que sa
##     profondeur, et on ne voit pas son fond depuis l'entree ;
##   * **plus aleatoires.** Deux a quatre coudes, tires un par un, avec un
##     ecart lateral qui va jusqu'a la moitie du segment ;
##   * **plus visibles.** La bouche s'evase (`flare`) et le dessous de la masse
##     se souleve autour d'elle (`CWMesa.porch`) : un **porche**, qui fait de
##     l'entree une ombre franche au lieu d'un trou de la taille d'une porte.
## Vrai si, en quittant la masse dans cette direction, le terrain **descend** :
## c'est la condition pour qu'une galerie ouverte de ce cote voie le ciel.
##
## On lit le sol au seuil de la masse puis vingt-quatre blocs plus loin, par
## pas de six : si l'un d'eux est plus haut que le seuil, la galerie donnerait
## sur un talus.
static func _debouche(m: CWMesa, dir: Vector2, field: CWTerrainField) -> bool:
	var centre := Vector2(m.x, m.z)
	var seuil: Vector2 = centre + dir * m.reach()
	for k in range(0, 60):
		var t: float = 1.15 - float(k) * 0.02
		if t <= 0.1:
			return false
		var q: Vector2 = centre + dir * (m.radius * t)
		if m.thickness(int(q.x), int(q.y)) > 0:
			break
		seuil = q
	var h0: float = field.sample_column(int(seuil.x), int(seuil.y)).x
	for d in [6, 12, 18, 24]:
		var q: Vector2 = seuil + dir * float(d)
		if field.sample_column(int(q.x), int(q.y)).x > h0 + 0.5:
			return false
	return true


func _add_caves(m: CWMesa, rng: CWRand, field: CWTerrainField) -> void:
	var roll: int = rng.mod(100)
	var n: int = 0 if roll < 18 else (1 if roll < 68 else 2)
	var base: float = rng.unit() * TAU
	for i in n:
		var theta: float = base + (PI + (rng.unit() - 0.5) * 1.4) * float(i)
		# **Huit directions essayees, la premiere qui debouche est gardee.**
		# Sortir de la masse ne suffit pas a voir le ciel : un massif pose au
		# pied d'un versant a des cotes ou le terrain *remonte* des qu'on le
		# quitte, et une galerie percee de ce cote-la est murée par la colline
		# d'en face. C'est la verification d'acces qui l'a montre, et la reponse
		# est de choisir le cote plutot que de l'esperer.
		var dir := Vector2(cos(theta), sin(theta))
		var essai: int = 0
		while essai < 8:
			if _debouche(m, dir, field):
				break
			essai += 1
			theta += TAU / 8.0
			dir = Vector2(cos(theta), sin(theta))
		if essai >= 8:
			continue
		# L'entree : sur le contour de la masse, la ou son dessus rejoint le sol.
		# On la cherche vers l'exterieur plutot que de la calculer, le contour
		# etant deforme par deux bruits.
		# -- Ou commence une galerie, et pourquoi ce n'est pas dans la roche --
		#
		# On cherche deux rayons le long de `dir`, du dehors vers le dedans :
		#
		#   * le **seuil**, la ou la masse cesse — c'est de la que part l'axe,
		#     et c'est ce qui garantit que la galerie **debouche**. La premiere
		#     version partait de la premiere colonne assez epaisse pour la
		#     contenir : le tube etait alors emmure derriere quelques blocs de
		#     flanc, et la verification d'acces l'a attrape ;
		#   * la **face**, la premiere colonne assez epaisse pour porter une
		#     galerie. C'est elle qui decide de la hauteur libre.
		#
		# Le contour etant deforme par deux bruits, on ne les calcule pas : on
		# les rencontre.
		var besoin: int = CAVE_HEIGHT_MIN + CAVE_HEADROOM_MIN
		var centre := Vector2(m.x, m.z)
		var seuil: Vector2 = centre + dir * m.reach()
		var face: Vector2 = seuil
		var trouve: bool = false
		var vu_dehors: bool = false
		for k in range(0, 60):
			var t: float = 1.15 - float(k) * 0.02
			if t <= 0.1:
				break
			var q: Vector2 = centre + dir * (m.radius * t)
			var e: int = m.thickness(int(q.x), int(q.y))
			if e <= 0:
				seuil = q
				vu_dehors = true
				continue
			if e >= besoin and vu_dehors:
				face = q
				trouve = true
				break
		if not trouve:
			continue

		# Le plancher est pris **au seuil**, pas a la face : c'est la que la
		# galerie doit etre de plain-pied avec le terrain.
		var ground: float = field.sample_column(int(seuil.x), int(seuil.y)).x
		var floor_y: int = floori(ground) + 1
		var head: int = m.thickness(int(face.x), int(face.y)) - 1
		if head < CAVE_HEADROOM_MIN:
			continue
		var a: Vector2 = seuil

		var c := CWMesa.Cave.new()
		c.radius = float(CAVE_RADIUS_MIN + rng.mod(CAVE_RADIUS_SPAN))
		c.flare = 1.7 + rng.unit() * 0.6
		c.floor_y = floor_y
		c.height = mini(CAVE_HEIGHT_MIN + rng.mod(CAVE_HEIGHT_SPAN), head)

		# L'axe brise : on avance vers l'interieur et on derive lateralement a
		# chaque coude. Le troisieme flottant de chaque point est l'abscisse
		# curviligne normalisee, dont l'evasement de la bouche se deduit.
		var bends: int = CAVE_BENDS_MIN + rng.mod(CAVE_BENDS_SPAN)
		var length: float = m.radius * (CAVE_LEN_MIN
				+ rng.unit() * CAVE_LEN_SPAN)
		var step: float = length / float(bends)
		var lat := Vector2(-dir.y, dir.x)
		var p: Vector2 = a
		var d: Vector2 = -dir
		c.axis.append(p.x)
		c.axis.append(p.y)
		c.axis.append(0.0)
		for k in bends:
			var swing: float = (rng.unit() - 0.5) * 2.0 * CAVE_BEND_SWING
			d = (d + lat * swing).normalized()
			lat = Vector2(-d.y, d.x)
			p += d * step
			c.axis.append(p.x)
			c.axis.append(p.y)
			c.axis.append(float(k + 1) / float(bends))
		m.caves.append(c)
