class_name CWMesa
extends RefCounted

## Un **massif** : une masse de roche arrondie et irreguliere, posee au-dessus
## du champ d'altitude, qui donne au paysage un relief que le champ ne sait pas
## produire.
##
## -- Pourquoi cette couche existe --------------------------------------------
##
## Le champ d'altitude du jalon 1.4 est un champ de hauteurs : une colonne, une
## altitude, et rien au-dessus. C'est ce qui le rend bon marche a echantillonner,
## et c'est aussi ce qui lui interdit une paroi — un bruit de valeur a
## interpolation cosinus est lisse par construction, et le jalon 1.13 a mesure
## que son plus grand denivele d'un bloc au suivant vaut **0,65 bloc**. D'ou la
## conclusion qui a fait retirer la falaise ce jour-la : *une falaise ne se peint
## pas, elle se taille*.
##
## Cette couche est ce relief. Elle ne touche pas au champ — `_height_from` reste
## mot pour mot ce qu'il etait, et le monde garde son ossature — elle **ajoute**
## une seconde nappe de matiere par-dessus, decrite elle aussi par colonne.
##
## -- La forme : arrondie, irreguliere, et **escaladable** --------------------
##
## La premiere version (2026-09-07) etait un **chapeau plat sur un socle
## etroit** : une mesa au sens propre, avec sa paroi verticale et son
## porte-a-faux. Elle a ete refaite le lendemain, sur une objection qui ne se
## discute pas — *le joueur doit pouvoir y monter*. Un chapeau qui deborde de son
## socle n'est pas escaladable : il est fait pour ne pas l'etre.
##
## La forme est donc devenue un **champ de bosses** :
##
##     f(x, z) = (1 - u²) + bruit lent + bruit fin
##     dessus  = sol + hauteur × max(0, f)
##
## — un dome radial, deforme par deux bruits, qui **retombe a zero sur son
## contour**. Il n'y a donc plus ni bord franc ni dessous : la masse sort du sol
## et y retourne, et on la gravit par n'importe quel cote.
##
## > **La pente est le contrat, et elle se mesure.** Une masse escaladable est
## > une masse dont le dessus ne monte jamais de plus d'un bloc par bloc — sinon
## > elle porte une marche qu'on ne franchit pas. Les trois amplitudes ci-dessous
## > sont choisies pour ca, et `tests/relief_test.gd` **mesure la pente reelle**
## > sur des masses tirees au hasard plutot que de faire confiance au calcul :
## > la deformation du contour et les deux bruits s'additionnent, et leur somme
## > n'a pas de borne evidente.
##
## Le seul endroit ou la matiere surplombe encore du vide est le **porche** d'une
## grotte : autour de chaque entree, le dessous de la masse se souleve, ce qui
## creuse un abri au-dessus du trou et le rend visible de loin. C'est un
## surplomb local, choisi, et il ne barre aucun chemin.
##
## -- Ce qui n'est pas de la source -------------------------------------------
##
## **Tout, et c'est dit en clair.** Le binaire de l'alpha n'a pas de couche de
## massifs : son terrain est un champ de hauteurs, comme celui-ci. Cette couche
## est une **creation de ce projet**, ecrite pour rapprocher le paysage de ce que
## montrent les captures du jeu.
##
## -- La recursion n'existe pas ici -------------------------------------------
##
## `CWTileFeatureGrid` doit se garder contre elle : ses elements deforment le
## champ, et leur altitude se lit *dans* le champ. Rien de tel ici, parce que la
## couche est posee **au-dessus** du champ et jamais dedans.

# -- Deformation du contour ---------------------------------------------------
#
# Deux bruits, lent puis fin. **Leurs frequences sont relatives au rayon du
# massif**, et non absolues : un bruit a frequence fixe donne dix lobes a une
# grosse masse et un demi-lobe a une petite, donc deux formes qui n'ont rien a
# voir — et surtout, sur la grosse, une **pente proportionnelle a la hauteur**
# qui finit par depasser le bloc par bloc. En posant la longueur d'onde en
# multiples du rayon, la silhouette et la pente sont les memes a toutes les
# tailles, ce qui est la seule facon de garantir l'escalade sans borner les
# tailles.
const SHAPE_WAVES_SLOW: float = 0.85    ## lobes par rayon
const SHAPE_WAVES_FINE: float = 2.6

## Amplitudes de reference. Elles ne servent plus a dessiner : **chaque massif
## tire les siennes** (`amp_slow`, `amp_fine`, tirees d'un seul caractere de
## rugosite par `CWMesaGrid`), et ces deux-ci ne restent que comme milieu de la
## fourchette et comme reperes de lecture.
##
## -- Pourquoi par massif, et ce que ca change au contrat ---------------------
##
## Avec deux constantes partagees, tous les massifs du monde avaient la meme
## borne de marche — deux blocs — et surtout la **meme silhouette a l'echelle
## pres**. Un paysage n'a pas cette regularite : il porte des masses lisses,
## presque des domes, et des masses decoupees en lobes. Le caractere se tire
## donc par massif.
##
## Le contrat d'escalade devient alors **parametre** : ce n'est plus « jamais
## plus de deux blocs » mesure contre une constante, c'est « jamais plus que la
## borne de *ce* massif », et cette borne se calcule de ses propres nombres
## (`max_step`). C'est elle que `tests/relief_test.gd` mesure.
const SHAPE_AMP_SLOW: float = 0.22
const SHAPE_AMP_FINE: float = 0.055

# -- La borne de marche d'un massif -------------------------------------------
#
# Le dessus d'un massif vaut `plancher(sol) + plancher(hauteur x f²)`. Sa
# derivee le long d'un rayon est `hauteur x 2f x df/dl`, et `f` a trois termes :
#
#   * le terme radial `1 - u²`, de derivee `2u/R`. Le produit `2f x 2u/R` avec
#     `f = 1 - u²` vaut `4u(1-u²)/R`, maximal a `u = 1/sqrt(3)` : **0,77 / R** ;
#   * les deux bruits, de longueur d'onde `R / ondes`. La pente d'un bruit de
#     valeur ne depasse pas ~1,5 par longueur d'onde, d'ou `1,5 x ondes x
#     amplitude / R` chacun, multiplie par `2f`.
#
# D'ou la borne ci-dessous. Elle est **conservatrice par construction** — elle
# suppose les trois termes maximaux au meme point, ce qui n'arrive pas — et
# c'est voulu : une borne qu'on depasse ne vaut rien, et le balayage de
# `relief_test` mesure la marche reelle contre elle.

## Pente maximale du terme radial, en multiples de `hauteur / rayon`.
const SLOPE_RADIAL: float = 0.77

## Pente maximale d'un bruit de valeur, par longueur d'onde.
const NOISE_SLOPE: float = 1.5

## Ce que le terrain lui-meme ajoute a la marche : les deux planchers de la
## formule ont chacun le droit de changer d'une unite d'une colonne a la
## suivante, et le terrain seul en fait deja un.
const STEP_TERRAIN: int = 1

## Marche maximale toleree, tous massifs confondus. **C'est le contrat
## d'escalade du 2026-09-08**, et il ne se negocie pas : `CWMesaGrid` rabat la
## rugosite d'un massif qui le depasserait plutot que de poser une masse qu'on
## ne peut pas gravir. Le caractere varie librement jusqu'a cette limite, et la
## limite gagne.
const CLIMB_MAX_STEP: int = 2

## Epaisseur, en blocs, jusqu'a laquelle le dessus d'un massif garde la matiere
## du pre qu'il traverse, puis largeur de la bande sur laquelle il devient de la
## roche nue.
##
## C'est ce qui fait qu'un massif se **voit**. Une masse arrondie couverte
## d'herbe est une colline ; la meme avec un coeur de roche et une frange
## enherbee est un affleurement, et c'est le second qu'on cherche. La regle de
## falaise ne peut pas rendre ce service : elle mesure la pente du champ
## d'altitude, qui ne sait rien de cette couche.
const SKIN_GRASS: float = 3.0
const SKIN_ROCK: float = 9.0

## Profondeur a laquelle la masse est pleine roche sous le sol de son centre.
## Genereuse : plus bas ne coute rien, l'intervalle recouvrant de la matiere qui
## existe deja.
const ROOT_DEPTH: int = 200

## Hauteur dont le dessous de la masse se souleve au-dessus du sol autour d'une
## entree de grotte, et rayon de ce soulevement en multiples du rayon du tube.
##
## C'est le **porche** : le seul endroit ou cette couche laisse encore de la
## roche surplomber du vide, et il est la pour une raison — une entree de
## galerie percee dans un flanc en pente se confond avec une ombre, alors qu'une
## entree sous une avancee de roche se voit de loin. Il ne barre aucun chemin :
## on en fait le tour en trois pas.
const PORCH_LIFT: int = 7
const PORCH_REACH: float = 2.6


## Une grotte : un **tube brise et traversant** qui perce la masse de part en
## part.
##
## -- Ce qui la definit -------------------------------------------------------
##
##   * **elle traverse** (2026-09-09). Deux bouches, choisies l'une et l'autre
##     par la regle des huit directions qui garantit deja qu'on debouche a l'air
##     libre, et evasees toutes les deux. On entre d'un cote et on ressort de
##     l'autre ; la version precedente s'arretait sur un cul-de-sac ;
##   * **son plancher suit le terrain**. Il ne peut plus etre un seul nombre :
##     les deux bouches sont a des altitudes differentes, et la promesse « de
##     plain-pied a l'entree » vaut aux **deux** entrees. Le plancher est donc
##     porte par l'axe, point par point, et il interpole entre les deux seuils.
##     C'est aussi ce qui donne a la galerie sa pente ;
##   * **son axe est une ligne brisee**, pas un segment : la galerie tourne, et
##     on ne voit pas d'un bout a l'autre depuis une bouche ;
##   * **sa section respire** (2026-09-09) : le rayon et la hauteur libre varient
##     d'un point de l'axe au suivant, donc la galerie se resserre et s'ouvre.
##     Jamais sous les deux planchers de `CWMesaGrid` : une section variable qui
##     se pince jusqu'a boucher la galerie n'est pas une grotte, c'est un mur ;
##   * **elle peut porter un embranchement court** : un tube marque `branch`, qui
##     part d'un point de l'axe principal et s'arrete dans la masse. Il ne
##     debouche pas, et il n'a pas a le faire — on y accede par la galerie.
##
## -- La garantie de praticabilite --------------------------------------------
##
## Les deux planchers ne suffisent pas a eux seuls : ils bornent la geometrie au
## **placement**, pas ce que le generateur finit par ecrire, qui est
## l'intersection du tube et de la masse. C'est `tests/relief_test.gd` qui
## parcourt l'axe d'un bout a l'autre et exige un passage libre a chaque point —
## le pendant de la verification d'acces, qui ne regardait que l'entree.
class Cave extends RefCounted:
	## L'axe, **six flottants par point** : x, z, l'abscisse curviligne
	## normalisee, le plancher en blocs, le rayon, et la hauteur libre.
	##
	## Les quatre dernieres valeurs sont interpolees le long de chaque segment :
	## c'est ce qui fait que la galerie monte, descend, se resserre et s'ouvre
	## sans marche d'un point de l'axe au suivant.
	const STRIDE: int = 6

	var axis: PackedFloat32Array = PackedFloat32Array()
	## Rayon nominal — le rayon des points de l'axe s'en ecarte, et c'est lui qui
	## sert de reference aux mesures et au porche.
	var radius: float = 6.0
	## Elargissement aux bouches, en multiples du rayon.
	var flare: float = 1.9
	## Un embranchement ne debouche pas : il s'arrete dans la masse, et on y
	## accede par la galerie qui le porte.
	var branch: bool = false

	func points() -> int:
		@warning_ignore("integer_division")
		var n: int = axis.size() / STRIDE
		return n

	## Entree du tube, en coordonnees monde.
	func mouth() -> Vector2:
		return Vector2(axis[0], axis[1])

	## **Sortie** du tube. Pour un embranchement, c'est son fond : il n'a qu'une
	## bouche, et l'appelant qui pose un porche doit le savoir.
	func mouth_out() -> Vector2:
		var k: int = (points() - 1) * STRIDE
		return Vector2(axis[k], axis[k + 1])

	func point_at(i: int) -> Vector2:
		return Vector2(axis[i * STRIDE], axis[i * STRIDE + 1])

	func floor_at(i: int) -> float:
		return axis[i * STRIDE + 3]

	func radius_at(i: int) -> float:
		return axis[i * STRIDE + 4]

	func clearance_at(i: int) -> float:
		return axis[i * STRIDE + 5]

	func push(px: float, pz: float, s: float, fl: float, r: float,
			h: float) -> void:
		axis.append(px)
		axis.append(pz)
		axis.append(s)
		axis.append(fl)
		axis.append(r)
		axis.append(h)


var x: float = 0.0
var z: float = 0.0
## Rayon nominal : la distance a laquelle le terme radial du champ s'annule.
var radius: float = 70.0
## Sol de reference, releve au centre au placement.
var base_y: int = 0
## Hauteur de la masse au-dessus de son sol de reference, en blocs.
var height: float = 24.0
var warp_ox: float = 0.0
var warp_oz: float = 0.0
## Le caractere de la masse : amplitudes des deux bruits de contour, tirees par
## massif. Faibles, la masse est un dome ; fortes, elle est decoupee en lobes.
## Voir la note de `SHAPE_AMP_SLOW`.
var amp_slow: float = SHAPE_AMP_SLOW
var amp_fine: float = SHAPE_AMP_FINE
## Vrai si le contrat d'escalade a rabattu la rugosite tiree. Sert aux mesures :
## un monde ou la moitie des masses est rabattue dit que la fourchette de tirage
## est trop large, et l'eventail pose n'est plus celui qu'on croit tirer.
var damped: bool = false
var caves: Array[Cave] = []


## La pente maximale du dessus de cette masse, en blocs par bloc, telle que la
## derivation de l'en-tete la borne. Conservatrice.
func slope_bound() -> float:
	# `2f` avec f au plus `1 + les deux amplitudes` : le facteur du produit
	# derive, pris a son maximum.
	var f_max: float = 1.0 + amp_slow + amp_fine
	return height / radius * (SLOPE_RADIAL + 2.0 * f_max * NOISE_SLOPE
			* (amp_slow * SHAPE_WAVES_SLOW + amp_fine * SHAPE_WAVES_FINE))


## La marche maximale de **ce** massif, en blocs : sa propre pente, plus ce que
## le terrain ajoute. C'est contre ce nombre que la mesure d'escalade de
## `tests/relief_test.gd` se fait — et non contre une constante partagee.
func max_step() -> int:
	return STEP_TERRAIN + ceili(slope_bound())


## Rayon au-dela duquel la colonne ne peut plus etre concernee, deformation
## comprise. Sert au rejet rapide, avant tout echantillon de bruit.
func reach() -> float:
	return radius * sqrt(1.0 + amp_slow + amp_fine) + 2.0


func near(cx: int, cz: int) -> bool:
	var dx: float = float(cx) - x
	var dz: float = float(cz) - z
	var r: float = reach()
	return dx * dx + dz * dz <= r * r


## Le champ de forme de la masse en cette colonne : `1` au coeur, `0` sur le
## contour, negatif au-dela. Rend `-1` sans echantillonner si la colonne est
## loin.
##
## Deux echantillons de bruit, payes par les seules colonnes du voisinage d'un
## massif — quelques pourcents des terres.
func shape(cx: int, cz: int) -> float:
	if not near(cx, cz):
		return -1.0
	var fx: float = float(cx)
	var fz: float = float(cz)
	var dx: float = fx - x
	var dz: float = fz - z
	var u2: float = (dx * dx + dz * dz) / (radius * radius)
	var fs: float = SHAPE_WAVES_SLOW / radius
	var ff: float = SHAPE_WAVES_FINE / radius
	var slow: float = CWValueNoise.sample(fx * fs + warp_ox, fz * fs + warp_oz)
	var fine: float = CWValueNoise.sample(fx * ff + warp_oz, fz * ff + warp_ox)
	return 1.0 - u2 + slow * amp_slow + fine * amp_fine


## Intervalle de matiere ajoute par la masse dans cette colonne, bornes
## **incluses**. `bas > haut` veut dire « rien ici », et c'est le cas de la
## quasi-totalite du monde.
func slab(cx: int, cz: int, ground_top: int) -> Vector2i:
	return slab_from_shape(shape(cx, cz), ground_top, cx, cz)


## L'epaisseur de la masse au-dessus du terrain, en blocs.
##
## **Deux choses ici valent le detour, et les deux viennent d'une capture.**
##
## *Le dessus est mesure depuis le sol de la colonne*, pas depuis celui du
## centre du massif. Une masse posee sur un flanc dont le sol descend de douze
## blocs entre son centre et son bord finissait sinon par une **marche de douze
## blocs** sur tout son contour : la masse s'arretait a l'altitude de son
## centre, le terrain etait ailleurs. Mesure avant correction : 12 blocs de
## marche sur un massif de 16 de haut.
##
## *Le profil est au carre*, `f²` et non `f`. C'est ce qui fait que la masse
## rejoint le sol **tangentiellement** : sa pente s'annule sur son contour au
## lieu d'y valoir son maximum. Sans cela, le raccord au terrain est un ressaut
## d'un ou deux blocs tout autour, et c'est exactement ce qu'on ne veut pas
## d'un relief qu'on doit pouvoir gravir.
func slab_from_shape(f: float, ground_top: int, cx: int, cz: int) -> Vector2i:
	if f <= 0.0:
		return Vector2i(1, 0)
	var hi: int = ground_top + floori(height * f * f)
	var lo: int = ground_top - ROOT_DEPTH + porch(cx, cz)
	if lo > hi:
		return Vector2i(1, 0)
	return Vector2i(lo, hi)


## Epaisseur de la masse au-dessus du sol, en blocs, sans la construire.
func thickness(cx: int, cz: int) -> int:
	var f: float = shape(cx, cz)
	if f <= 0.0:
		return 0
	return floori(height * f * f)


## Soulevement du dessous de la masse autour d'une entree de grotte : c'est le
## **porche**, le seul surplomb que cette couche produise encore, et il est la
## pour rendre l'entree visible.
func porch(cx: int, cz: int) -> int:
	if caves.is_empty():
		return 0
	var best: float = 0.0
	for c in caves:
		# **Les deux bouches** depuis que la galerie traverse : une sortie sans
		# porche ne se voit pas de l'exterieur, et c'est par elle qu'on entrera
		# une fois sur deux. Un embranchement n'en a pas — son fond est dans la
		# masse.
		var bouches: Array[Vector2] = [c.mouth()]
		if not c.branch:
			bouches.append(c.mouth_out())
		for m in bouches:
			var r: float = c.radius * PORCH_REACH
			var d: float = Vector2(float(cx) - m.x, float(cz) - m.y).length()
			if d >= r:
				continue
			var t: float = 1.0 - d / r
			best = maxf(best, t * t * (3.0 - 2.0 * t))
	return int(best * float(ROOT_DEPTH + PORCH_LIFT))


## Intervalle d'air creuse par les grottes de la masse, bornes **incluses**.
func cave(cx: int, cz: int) -> Vector2i:
	if caves.is_empty():
		return Vector2i(1, 0)
	var fx: float = float(cx)
	var fz: float = float(cz)
	var lo: int = 1
	var hi: int = 0
	for c in caves:
		# Le tube rend desormais son plancher et sa hauteur au point, tous deux
		# interpoles le long du segment : c'est ce qui fait monter et descendre
		# le plafond sans marche.
		var hit: Vector3 = _tube(c, fx, fz)
		if hit.x < 0.0:
			continue
		var fl: int = floori(hit.y)
		# La galerie s'evase aux bouches, et son plafond monte avec elles : une
		# bouche large et basse ne se lit pas comme une entree.
		var top: int = fl + maxi(1, floori(hit.z)) - 1 \
				+ int(hit.x * 0.5 * hit.z)
		# **On reunit** au lieu de rendre le premier trouve : depuis qu'une
		# galerie porte des embranchements, deux tubes de la meme masse se
		# croisent, et rendre le premier couperait le second au croisement.
		if lo > hi:
			lo = fl
			hi = top
		else:
			lo = mini(lo, fl)
			hi = maxi(hi, top)
	return Vector2i(lo, hi)


## Le tube au point donne. Rend `Vector3(-1, 0, 0)` hors du tube, sinon
## `(part d'evasement, plancher, hauteur libre)` — les deux dernieres interpolees
## le long du segment touche.
##
## L'evasement vaut 1 a une bouche et 0 des le premier tiers de la galerie. Il
## est pris **aux deux bouts** depuis que la galerie traverse : un tube evase
## d'un seul cote a une entree et une fissure.
func _tube(c: Cave, px: float, pz: float) -> Vector3:
	var n: int = c.points() - 1
	for i in n:
		var k: int = i * Cave.STRIDE
		var l: int = k + Cave.STRIDE
		var ax: float = c.axis[k]
		var az: float = c.axis[k + 1]
		var vx: float = c.axis[l] - ax
		var vz: float = c.axis[l + 1] - az
		var len2: float = vx * vx + vz * vz
		var t: float = 0.0
		if len2 > 0.0:
			t = clampf(((px - ax) * vx + (pz - az) * vz) / len2, 0.0, 1.0)
		var dx: float = px - (ax + vx * t)
		var dz: float = pz - (az + vz * t)
		var s: float = c.axis[k + 2] + (c.axis[l + 2] - c.axis[k + 2]) * t
		# Les deux bouches. Un embranchement n'en a qu'une : son fond est dans
		# la masse, et l'evaser y creuserait une bulle sans raison.
		var evase: float = maxf(0.0, 1.0 - s * 3.0)
		if not c.branch:
			evase = maxf(evase, maxf(0.0, 1.0 - (1.0 - s) * 3.0))
		var rl: float = c.axis[k + 4] + (c.axis[l + 4] - c.axis[k + 4]) * t
		var r: float = rl * (1.0 + (c.flare - 1.0) * evase)
		if dx * dx + dz * dz > r * r:
			continue
		var fl: float = c.axis[k + 3] + (c.axis[l + 3] - c.axis[k + 3]) * t
		var hl: float = c.axis[k + 5] + (c.axis[l + 5] - c.axis[k + 5]) * t
		return Vector3(evase, fl, hl)
	return Vector3(-1.0, 0.0, 0.0)


func _to_string() -> String:
	return "CWMesa(pos=(%.0f, %.0f), r=%.0f, sol=%d, haut=%.0f, grottes=%d)" % [
			x, z, radius, base_y, height, caves.size()]
