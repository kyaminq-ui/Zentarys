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
## C'etait **la constante qui decidait si le massif etait escaladable**, et elle
## plafonnait a 0,54 pour cette raison. Le contrat d'escalade ayant ete retire le
## 2026-09-09, elle ne repond plus qu'a une question de paysage : *a partir de
## quand une masse cesse d'etre une bosse ?* La fourchette est donc montee a
## 0,40-0,80, ce qui donne des masses de 18 a 91 blocs de haut selon leur rayon.
const HEIGHT_PER_RADIUS_MIN: float = 0.40
const HEIGHT_PER_RADIUS_SPAN: float = 0.40
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

# -- La section respire, et deux planchers l'empechent de se pincer -----------
#
# *« Un creusement plus aleatoire, un peu comme Minecraft »* : le rayon et la
# hauteur libre varient d'un point de l'axe au suivant, donc la galerie se
# resserre et s'ouvre au lieu d'etre un tuyau.
#
# **C'est la contrainte qui coute.** Une section variable peut se pincer jusqu'a
# boucher la galerie, et une grotte bouchee au milieu est pire qu'une grotte
# droite : on y entre, on marche, et on se cogne. D'ou deux planchers absolus,
# sous lesquels aucun point de l'axe ne descend — et une verification qui
# parcourt l'axe entier, parce que ces planchers bornent la geometrie posee et
# non ce que le generateur ecrit, qui est l'intersection du tube et de la masse.

## Amplitude de la respiration, en fraction du rayon (resp. de la hauteur)
## nominal. A 0,45, une galerie de rayon 7 va de 4 a 10.
const CAVE_SECTION_SWING: float = 0.45
const CAVE_CLEARANCE_SWING: float = 0.35

## Les deux planchers. En dessous, on ne passe plus : trois blocs de large et
## quatre de haut sont le minimum pour qu'un couloir se parcoure.
const CAVE_SECTION_FLOOR: float = 3.0
const CAVE_CLEARANCE_FLOOR: float = 4.0

## Nombre de directions essayees pour percer une bouche.
##
## **Douze depuis le 2026-09-09**, contre huit. Deux choses en demandaient plus :
## la silhouette porte maintenant des bras et des golfes, donc un cote sur trois
## ne mene nulle part ; et la condition de debouche est devenue exacte, donc plus
## severe. A huit directions, le monde perdait un cinquieme de ses galeries.
const ESSAIS: int = 12

## Chance, sur cent, qu'une galerie porte un embranchement court, et longueur de
## celui-ci en fraction de la galerie. Un embranchement ne debouche pas : il
## s'arrete dans la masse, et on y accede par la galerie.
const CAVE_BRANCH_CHANCE: int = 55
const CAVE_BRANCH_LEN: float = 0.35

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
## de sa cellule. Le rayon maximum d'un surplomb, allongement et deformation du
## domaine compris, vaut **270 unites** depuis le 2026-09-09 — contre 176 avant
## la refonte de la forme, et toujours bien moins qu'une cellule de 512 —, donc
## trois cellules suffisent.
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
	# La constante est prise sur la hauteur **nominale** : le profil `f^p` la
	# ramene au coeur des que `p` depasse un, et le massif reel monte alors
	# moins haut que ce nombre-la.
	m.height = maxf(float(HEIGHT_MIN), m.radius * (HEIGHT_PER_RADIUS_MIN
			+ rng.unit() * HEIGHT_PER_RADIUS_SPAN))
	m.warp_ox = float(rng.next() * 32768 + rng.next())
	m.warp_oz = float(rng.next() * 32768 + rng.next())
	_tire_caractere(m, rng)

	_add_caves(m, rng, field)
	out.append(m)
	return out


## Le pas d'un sondage radial : combien de points entre `reach()` et le centre.
##
## **En distance absolue, et non en multiples du rayon.** Les sondages partaient
## de `1,15 x rayon` : c'etait juste tant que le contour etait un cercle a peine
## bosselle, et c'est faux depuis que la forme porte un allongement et une
## deformation du domaine — le contour sort alors jusqu'a `2,3 x rayon`, un
## sondage qui commence a 1,15 commence **dans la masse**, ne voit jamais le
## dehors, et aucune galerie n'est plus posee. C'est le genre de regression qui
## ne casse aucune verification de forme et vide le monde de ses grottes.
const SONDE_PAS: int = 80


## Le k-ieme point d'un sondage radial, du dehors vers le dedans.
static func _sonde(m: CWMesa, dir: Vector2, k: int) -> Vector2:
	var d: float = m.reach() * (1.0 - float(k) / float(SONDE_PAS))
	return Vector2(m.x, m.z) + dir * d


## Le **seuil** dans une direction : la ou la masse cesse, en partant du dehors.
##
## C'est de la que part — ou la qu'arrive — une galerie, et c'est ce qui garantit
## qu'elle debouche. Le contour etant deforme, on ne le calcule pas : on le
## rencontre.
static func _seuil(m: CWMesa, dir: Vector2) -> Vector2:
	var out: Vector2 = _sonde(m, dir, 0)
	for k in SONDE_PAS:
		var q: Vector2 = _sonde(m, dir, k)
		if m.thickness(int(q.x), int(q.y)) <= 0:
			out = q
			continue
		break
	return out


## Un embranchement court, greffe sur un point interieur de la galerie.
##
## Il ne debouche pas, et c'est sa definition : il s'arrete dans la masse, on y
## accede par la galerie qui le porte, et ni la verification d'acces ni celle du
## porche ne s'appliquent a lui — d'ou le drapeau `branch`.
##
## Sa hauteur est rabattue sur l'epaisseur de la masse comme celle de la galerie,
## et il n'est pose que s'il tient : un embranchement qui perce le dessus est le
## meme trou dans le sol, en plus discret.
func _ajoute_embranchement(m: CWMesa, parent: CWMesa.Cave,
		pts: Array[Vector2], rng: CWRand, field: CWTerrainField) -> void:
	if rng.mod(100) >= CAVE_BRANCH_CHANCE or pts.size() < 3:
		return
	@warning_ignore("integer_division")
	var mid: int = 1 + rng.mod(pts.size() - 2)
	var base: Vector2 = pts[mid]
	var le_long: Vector2 = (pts[mid + 1] - pts[mid - 1]).normalized()
	var cote: float = 1.0 if rng.mod(2) == 0 else -1.0
	var dir: Vector2 = (le_long.orthogonal() * cote
			+ le_long * (rng.unit() - 0.5)).normalized()
	var longueur: float = (pts[pts.size() - 1] - pts[0]).length() \
			* CAVE_BRANCH_LEN

	var b := CWMesa.Cave.new()
	b.branch = true
	b.radius = maxf(CAVE_SECTION_FLOOR, parent.radius * 0.75)
	b.flare = 1.0
	var fl: float = parent.floor_at(mid)
	var n: int = 3
	for k in n:
		var u: float = float(k) / float(n - 1)
		var q: Vector2 = base + dir * (longueur * u)
		var qx: int = int(q.x)
		var qz: int = int(q.y)
		var sommet: int = floori(field.sample_column(qx, qz).x) \
				+ m.thickness(qx, qz)
		var libre: float = float(sommet) - fl + 1.0
		if libre < CAVE_CLEARANCE_FLOOR:
			return
		var hl: float = minf(libre, maxf(CAVE_CLEARANCE_FLOOR,
				parent.clearance_at(mid) * (0.8 + rng.unit() * 0.3)))
		b.push(q.x, q.y, u, fl, maxf(CAVE_SECTION_FLOOR,
				b.radius * (0.8 + rng.unit() * 0.4)), hl)
	m.caves.append(b)


# -- Le caractere d'une masse : sept nombres ----------------------------------
#
# **Un seul tirage pour la rugosite, et c'est le point.** Le warp et la peau
# pourraient se tirer independamment ; ils ne le sont pas. Une masse dont les
# grands caps sont doux mais la peau rugueuse ne ressemble a rien de naturel —
# les deux echelles d'une erosion vont ensemble. Un seul nombre les pilote donc
# toutes les deux.
#
# **Tout le reste se tire librement, et rien n'est rabattu.** La version du
# 2026-09-08 divisait les amplitudes jusqu'a ce que la marche du massif rentre
# dans le contrat d'escalade ; le contrat est retire, donc le rabattement l'est
# aussi. Ce qui sort du tirage est ce qui se pose.

## Deformation du domaine : c'est elle qui fait la silhouette. Le bas de la
## plage donne un galet, le haut un objet a caps et a golfes.
const WARP_MIN: float = 0.14
const WARP_SPAN: float = 0.40

## Peau : le grain du contour, tire du meme nombre que le warp.
const SKIN_MIN: float = 0.030
const SKIN_SPAN: float = 0.070

## Allongement de l'ellipse. A 1,55, le grand axe fait 2,4 fois le petit.
const STRETCH_SPAN: float = 0.55

## Lobes angulaires : leur nombre, puis leur amplitude. Zero est dans la plage,
## et il le faut — toutes les masses ne sont pas des etoiles.
##
## **L'amplitude ne se lit pas comme un rayon.** Le terme s'ajoute a `1 - u²`,
## donc un lobe d'amplitude A deplace le contour de `sqrt(1 + A)` : a 0,34 —
## la premiere valeur essayee — cela faisait **+16 % de rayon**, invisible a
## cote du warp, et la silhouette restait une patate. A 0,80, le cap est a
## +34 % et le golfe a **-55 %** : la masse devient un objet a bras, ce qui est
## l'abstraction demandee.
const LOBES_MIN: int = 2
const LOBES_SPAN: int = 5
const LOBE_SPAN: float = 0.80

## Exposant du profil. **C'est le levier qui repond au mot « dome ».** A 2, la
## masse rejoint le sol tangentiellement et c'est exactement un dome ; a 0,35,
## elle a un dessus presque plat et des flancs qui tombent.
const POW_MIN: float = 0.35
const POW_SPAN: float = 1.75

## Strates : la chance qu'un massif monte par gradins, l'epaisseur d'un gradin
## en blocs, et la part de quantification appliquee. A 1, les paliers sont
## francs ; a 0,45, ils marquent le flanc sans l'escalier.
const STRATA_CHANCE: int = 48
const STRATA_MIN: int = 3
const STRATA_SPAN: int = 7
const STRATA_MIX_MIN: float = 0.45
const STRATA_MIX_SPAN: float = 0.55


func _tire_caractere(m: CWMesa, rng: CWRand) -> void:
	var r: float = rng.unit()
	m.amp_warp = WARP_MIN + r * WARP_SPAN
	m.amp_fine = SKIN_MIN + r * SKIN_SPAN
	m.set_axes(1.0 + rng.unit() * STRETCH_SPAN, rng.unit() * PI)
	m.lobes = LOBES_MIN + rng.mod(LOBES_SPAN)
	m.lobe_phase = rng.unit() * TAU
	m.amp_lobe = rng.unit() * LOBE_SPAN
	m.profile_pow = POW_MIN + rng.unit() * POW_SPAN
	# Le tirage des strates est fait **dans tous les cas**, y compris quand la
	# masse n'en portera pas : deux nombres consommes ou non deplaceraient tout
	# le flux, et une cellule voisine changerait de massif sans qu'on l'ait
	# demande. Meme regle que partout ailleurs dans ce projet.
	var ep: int = STRATA_MIN + rng.mod(STRATA_SPAN)
	var mix: float = STRATA_MIX_MIN + rng.unit() * STRATA_MIX_SPAN
	if rng.mod(100) < STRATA_CHANCE:
		m.strata = float(ep)
		m.strata_mix = mix


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
	var seuil: Vector2 = _sonde(m, dir, 0)
	var touche: bool = false
	for k in SONDE_PAS:
		var q: Vector2 = _sonde(m, dir, k)
		if m.thickness(int(q.x), int(q.y)) > 0:
			touche = true
			break
		seuil = q
	# Une direction ou la masse n'a aucune epaisseur ne debouche pas : il n'y a
	# rien a percer de ce cote-la.
	if not touche:
		return false
	# -- Le test se fait **en blocs**, et c'est ce qui a manque ---------------
	#
	# Il comparait des altitudes flottantes a `h0 + 0,5`. Or le plancher d'une
	# galerie vaut `plancher(h0) + 1`, et le sol d'une colonne occupe le bloc
	# `plancher(altitude)` : un terrain a `h0 + 0,45` passait le test flottant et
	# **bouchait** la sortie, son bloc de surface tombant exactement sur le
	# plancher du tube. Le decalage etait de quelques dixiemes de bloc, donc il
	# ne se voyait qu'a une bouche sur quatre — et pas du tout tant que le
	# contour etait un cercle, ou les bouches tombaient loin des ressauts.
	#
	# La condition est donc celle que la verification exerce, mot pour mot : le
	# bloc de surface reste **sous** le plancher du tube. Et le pas descend a
	# quatre blocs, la verification marchant de cinq en cinq sur vingt-cinq.
	var plancher: int = floori(field.sample_column(
			int(seuil.x), int(seuil.y)).x) + 1
	for d in [4, 8, 12, 16, 20, 24, 28]:
		var q: Vector2 = seuil + dir * float(d)
		if floori(field.sample_column(int(q.x), int(q.y)).x) >= plancher:
			return false
	return true


func _add_caves(m: CWMesa, rng: CWRand, field: CWTerrainField) -> void:
	var roll: int = rng.mod(100)
	var n: int = 0 if roll < 18 else (1 if roll < 68 else 2)
	var base: float = rng.unit() * TAU
	for i in n:
		var theta: float = base + (PI + (rng.unit() - 0.5) * 1.4) * float(i)
		# **`ESSAIS` directions essayees, la premiere qui debouche est gardee.**
		# Sortir de la masse ne suffit pas a voir le ciel : un massif pose au
		# pied d'un versant a des cotes ou le terrain *remonte* des qu'on le
		# quitte, et une galerie percee de ce cote-la est murée par la colline
		# d'en face. C'est la verification d'acces qui l'a montre, et la reponse
		# est de choisir le cote plutot que de l'esperer.
		var dir := Vector2(cos(theta), sin(theta))
		var essai: int = 0
		while essai < ESSAIS:
			if _debouche(m, dir, field):
				break
			essai += 1
			theta += TAU / float(ESSAIS)
			dir = Vector2(cos(theta), sin(theta))
		if essai >= ESSAIS:
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
		# Le contour etant deforme, on ne les calcule pas : on les rencontre.
		var besoin: int = CAVE_HEIGHT_MIN + CAVE_HEADROOM_MIN
		var seuil: Vector2 = _sonde(m, dir, 0)
		var face: Vector2 = seuil
		var trouve: bool = false
		var vu_dehors: bool = false
		# -- Le seuil est le **premier** contour rencontre, et pas le dernier --
		#
		# La boucle ne s'arrete pas a la premiere colonne pleine : une colonne
		# trop mince ne peut pas porter de galerie, donc on continue vers le
		# coeur. Elle continuait aussi a **deplacer le seuil** a chaque colonne
		# vide rencontree ensuite — ce qui etait sans effet tant que le contour
		# etait un cercle a peine bosselle, et qui est faux depuis que la masse
		# porte des bras : entre deux bras il y a un golfe, et le seuil finissait
		# **dans le golfe**. La galerie s'y ouvrait alors sur un couloir ferme
		# par le bras d'a cote, pendant que `_debouche` avait valide le contour
		# exterieur, lui, et l'avait trouve degage.
		#
		# Les trois lectures du contour disent donc maintenant la meme chose :
		# `_seuil`, `_debouche` et celle-ci gardent la **premiere** rencontre.
		var touche: bool = false
		for k in SONDE_PAS:
			var q: Vector2 = _sonde(m, dir, k)
			var e: int = m.thickness(int(q.x), int(q.y))
			if e <= 0:
				if not touche:
					seuil = q
					vu_dehors = true
				continue
			touche = true
			if e >= besoin and vu_dehors:
				face = q
				trouve = true
				break
		if not trouve:
			continue

		# -- Les deux seuils, et le plancher qui va de l'un a l'autre --------
		#
		# La galerie **traverse** depuis le 2026-09-09. Sa seconde bouche se
		# cherche exactement comme la premiere — huit directions essayees, la
		# premiere qui debouche est gardee — a ceci pres qu'on part de l'oppose
		# de la premiere, pour que le tube coupe la masse au lieu de la raser.
		var sortie := Vector2(-dir.x, -dir.y)
		var essai2: int = 0
		var theta2: float = theta + PI
		while essai2 < ESSAIS:
			if _debouche(m, sortie, field):
				break
			essai2 += 1
			theta2 += TAU / float(ESSAIS)
			sortie = Vector2(cos(theta2), sin(theta2))
		if essai2 >= ESSAIS:
			continue
		var seuil2: Vector2 = _seuil(m, sortie)

		# Le plancher est pris **aux seuils**, pas aux faces : c'est la que la
		# galerie doit etre de plain-pied avec le terrain, et il y en a deux.
		var sol_a: float = field.sample_column(int(seuil.x), int(seuil.y)).x
		var sol_b: float = field.sample_column(int(seuil2.x), int(seuil2.y)).x
		var floor_a: float = floorf(sol_a) + 1.0
		var floor_b: float = floorf(sol_b) + 1.0
		var head: int = m.thickness(int(face.x), int(face.y)) - 1
		if head < CAVE_HEADROOM_MIN:
			continue

		var c := CWMesa.Cave.new()
		c.radius = float(CAVE_RADIUS_MIN + rng.mod(CAVE_RADIUS_SPAN))
		c.flare = 1.7 + rng.unit() * 0.6
		var h_tire: int = CAVE_HEIGHT_MIN + rng.mod(CAVE_HEIGHT_SPAN)

		# -- L'axe : de seuil a seuil2, en passant par le milieu -------------
		#
		# Les coudes s'ecartent lateralement de la corde qui joint les deux
		# bouches. On ne tire donc plus une longueur : elle est celle de la
		# corde, et c'est ce qui fait que la galerie **ressort**.
		var bends: int = CAVE_BENDS_MIN + rng.mod(CAVE_BENDS_SPAN) + 1
		var lat: Vector2 = (seuil2 - seuil).orthogonal().normalized()
		var pts: Array[Vector2] = [seuil]
		for k in range(1, bends):
			var u: float = float(k) / float(bends)
			# L'ecart s'annule aux deux bouts : une bouche doit rester ou le
			# terrain a dit qu'elle etait.
			var enveloppe: float = sin(u * PI)
			var swing: float = (rng.unit() - 0.5) * 2.0 * CAVE_BEND_SWING
			pts.append(seuil.lerp(seuil2, u)
					+ lat * swing * enveloppe * (seuil2 - seuil).length() * 0.5)
		pts.append(seuil2)

		# Puis la section, point par point, avec ses deux planchers.
		var pire_r: float = INF
		var pire_h: float = INF
		for k in pts.size():
			var u: float = float(k) / float(pts.size() - 1)
			var r: float = maxf(CAVE_SECTION_FLOOR, c.radius
					* (1.0 + (rng.unit() - 0.5) * 2.0 * CAVE_SECTION_SWING))
			var hl: float = maxf(CAVE_CLEARANCE_FLOOR, float(h_tire)
					* (1.0 + (rng.unit() - 0.5) * 2.0 * CAVE_CLEARANCE_SWING))
			pire_r = minf(pire_r, r)
			pire_h = minf(pire_h, hl)
			c.push(pts[k].x, pts[k].y, u, lerpf(floor_a, floor_b, u), r, hl)

		# -- Le plafond doit tenir **sur tout l'axe**, pas seulement a la face --
		#
		# La hauteur libre etait prise a la **face**, une seule colonne. Mais
		# l'axe traverse des colonnes ou la masse est plus mince, et le plafond
		# y sortait par le dessus — un trou dans le sol vu d'en haut. On rabat
		# donc chaque point sur l'epaisseur de **sa** colonne, ce qui est plus
		# juste que rabattre toute la galerie sur la pire : une galerie qui
		# s'ecrase sous un col et se rouvre apres reste une galerie.
		#
		# **Les deux bouches sont exclues**, et c'est la meme raison qui fait que
		# la verification du plafond les exclut deja : une bouche est *au seuil*
		# de la masse, la ou celle-ci n'a par definition aucune epaisseur. Les y
		# soumettre rejetait toutes les galeries du monde.
		var praticable: bool = true
		for k in range(1, pts.size() - 1):
			var qx: int = int(pts[k].x)
			var qz: int = int(pts[k].y)
			var sommet: int = floori(field.sample_column(qx, qz).x) \
					+ m.thickness(qx, qz)
			var libre: float = float(sommet) - c.floor_at(k) + 1.0
			if libre < c.clearance_at(k):
				c.axis[k * CWMesa.Cave.STRIDE + 5] = libre
			if c.clearance_at(k) < CAVE_CLEARANCE_FLOOR:
				praticable = false
				break
		# Une galerie qu'on ne traverse pas debout n'en est pas une : plutot
		# aucune grotte de ce cote-la qu'un boyau ecrase.
		if not praticable:
			continue
		m.caves.append(c)
		_ajoute_embranchement(m, c, pts, rng, field)
