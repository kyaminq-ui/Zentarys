class_name CWMesa
extends RefCounted

## Un **massif** : une masse de roche deformee, posee au-dessus du champ
## d'altitude, qui donne au paysage un relief que le champ ne sait pas produire.
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
## -- La forme : abstraite, exageree, et **pas escaladable** ------------------
##
## Trois formes se sont succede, et la troisieme est un renversement assume.
##
## 1. **Un chapeau plat sur un socle etroit** (2026-09-07) : une mesa au sens
##    propre, avec sa paroi verticale et son porte-a-faux. Retiree le lendemain
##    sur une objection qui ne se discutait pas — *le joueur doit pouvoir y
##    monter* ;
## 2. **un champ de bosses escaladable** (2026-09-08) : `1 - u²` deforme par deux
##    bruits, eleve au carre pour rejoindre le sol tangentiellement, et
##    l'amplitude des bruits **rabattue** des que la marche depassait deux blocs.
##    Le contrat etait tenu, mesure, et verifie ;
## 3. **la forme actuelle** (2026-09-09), demandee apres la session de jeu qui a
##    juge la precedente : *ils ressemblent trop a des domes, il faut que ce soit
##    plus abstrait et exagere dans leur deformation, ne plus tenir compte de
##    l'escalade du personnage*.
##
## > **Le contrat d'escalade est retire, et c'est la seule facon de tenir la
## > demande.** Il ne bornait pas un detail : il bornait *tout*. La hauteur
## > relative, l'amplitude des bruits, l'exposant du profil — chacun des trois
## > leviers qui font qu'une masse n'est pas un dome sortait de la borne de
## > marche, et `CWMesaGrid` rabattait la rugosite tiree plutot que de poser une
## > masse trop raide. Un relief escaladable partout **est** un dome ; on ne
## > pouvait pas garder l'un en demandant l'autre.
##
## Ce qui remplace le dome, dans l'ordre ou ca se voit :
##
## * **une deformation du domaine.** On ne deforme plus le contour, on **deplace
##   le point** avant de le mesurer : `q = p + bruit(p) x amp_warp x rayon`. Un
##   bruit additif fait onduler un cercle ; un bruit de domaine le **plie**, lui
##   fait des golfes, des caps et des pincements. C'est la difference entre une
##   silhouette bruitee et une silhouette *dessinee*, et c'est le levier qui
##   compte le plus. Il remplace aussi le bruit lent d'avant, qui faisait moins
##   bien la meme chose pour le meme prix ;
## * **une ellipse tournee.** Le terme radial n'est plus `1 - u²` sur un cercle
##   mais sur une ellipse d'allongement et d'orientation tires par massif : des
##   cretes et des buttes la ou il n'y avait que des ronds ;
## * **des lobes angulaires**, `cos(k x theta)` avec `k` de deux a six : des
##   doigts de roche qui partent du coeur. Le terme est amorti pres du centre,
##   ou l'angle n'a pas de sens ;
## * **un exposant de profil par massif.** `f^p` et non plus `f²`. C'est la
##   reponse directe au mot « dome » : a `p = 2` la masse rejoint le sol
##   tangentiellement, ce qui **est** un dome ; a `p = 0,4` elle a un dessus
##   presque plat et des flancs qui tombent — la mesa qu'on avait retiree, mais
##   sans son porte-a-faux ;
## * **des strates.** Un massif sur deux quantifie sa hauteur par paliers de
##   trois a neuf blocs. C'est ce qui donne l'abstraction demandee : la masse
##   monte par gradins, comme un dessin de roche plutot que comme un tas.
##
## Le seul endroit ou la matiere surplombe encore du vide reste le **porche**
## d'une grotte : autour de chaque entree, le dessous de la masse se souleve, ce
## qui creuse un abri au-dessus du trou et le rend visible de loin.
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

# -- Le caractere d'un massif : sept nombres, tires un par un ------------------
#
# Chacun a une plage, et **la plage est l'eventail du paysage**. Les bornes
# ci-dessous ne sont pas des garde-fous : ce sont les deux extremes qu'on
# accepte de voir cote a cote dans un meme pays.
#
# Tout se tire par massif depuis le 2026-09-09, et plus rien n'est rabattu :
# il n'y a plus de contrat d'escalade a tenir, donc plus de raison de refuser le
# haut d'une plage.

## Longueur d'onde de la deformation du domaine, en lobes par rayon. Basse :
## un warp a courte longueur d'onde fait de la dentelle, pas des caps.
const WARP_WAVES: float = 0.55

## Longueur d'onde du bruit de peau, en lobes par rayon. **Relative au rayon**,
## et non absolue : un bruit a frequence fixe donnerait dix lobes a une grosse
## masse et un demi-lobe a une petite, donc deux formes qui n'ont rien a voir.
const SKIN_WAVES: float = 2.6

## Amplitude du bruit de peau, en fraction du rayon. Reference de lecture : les
## massifs tirent la leur.
const SKIN_AMP: float = 0.06

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
## Rayon nominal : le demi-axe moyen de l'ellipse de contour.
var radius: float = 70.0
## Sol de reference, releve au centre au placement.
var base_y: int = 0
## Hauteur de la masse au-dessus de son sol de reference, en blocs.
var height: float = 24.0
var warp_ox: float = 0.0
var warp_oz: float = 0.0

# -- Le caractere. Voir l'en-tete pour ce que chacun fait a la silhouette. -----

## Amplitude de la deformation du domaine, en fraction du rayon.
var amp_warp: float = 0.25
## Amplitude du bruit de peau, en fraction du rayon.
var amp_fine: float = SKIN_AMP
## Allongement de l'ellipse : demi-grand axe `rayon x stretch`, demi-petit axe
## `rayon / stretch`. Un vaut un cercle.
var stretch: float = 1.0
## Orientation du grand axe, et son cosinus/sinus tenus a jour par `set_axes`.
var angle: float = 0.0
var _ca: float = 1.0
var _sa: float = 0.0
## Lobes angulaires : leur nombre, leur phase, leur amplitude.
var lobes: int = 3
var lobe_phase: float = 0.0
var amp_lobe: float = 0.0
## Exposant du profil. Deux rejoint le sol tangentiellement — c'est le dome ;
## sous un, le dessus s'aplatit et les flancs tombent.
var profile_pow: float = 2.0
## Epaisseur d'un gradin, en blocs, et part de la quantification appliquee.
## Zero veut dire pas de strates.
var strata: float = 0.0
var strata_mix: float = 0.0

var caves: Array[Cave] = []


## Pose l'ellipse. Le cosinus et le sinus sont gardes parce que `shape` les
## emploie a chaque colonne du voisinage du massif.
func set_axes(s: float, a: float) -> void:
	stretch = maxf(1.0, s)
	angle = a
	_ca = cos(a)
	_sa = sin(a)


## Rayon normalise maximal du contour : ce que valent au plus les lobes et la
## peau ajoutes au terme radial.
func silhouette() -> float:
	return sqrt(maxf(1.0, 1.0 + amp_lobe + amp_fine))


## Rayon **circulaire** au-dela duquel la colonne ne peut plus etre concernee,
## allongement et deformation du domaine compris.
##
## Il sert a deux choses qui ne demandent pas la meme finesse : dimensionner la
## fenetre de cellules, et **partir de l'exterieur** quand on cherche le contour
## de la masse le long d'une direction (les grottes). Le rejet rapide par
## colonne, lui, passe par `near`, qui teste l'ellipse.
func reach() -> float:
	return radius * (stretch * silhouette() + amp_warp) + 2.0


## Rejet rapide, **sur l'ellipse** et non sur son cercle circonscrit. La
## difference n'est pas cosmetique : `shape` echantillonne trois bruits, et
## l'aire d'un disque de rayon `radius x stretch` vaut `stretch²` fois celle de
## l'ellipse. A `stretch = 1,45`, c'est deux fois trop de colonnes payees.
##
## La marge du warp est prise sur le **petit** axe, ou elle pese le plus en
## unites normalisees : conservateur des deux cotes.
func near(cx: int, cz: int) -> bool:
	var dx: float = float(cx) - x
	var dz: float = float(cz) - z
	var rx: float = (dx * _ca + dz * _sa) / (radius * stretch)
	var rz: float = (dz * _ca - dx * _sa) * stretch / radius
	var b: float = silhouette() + amp_warp * stretch
	return rx * rx + rz * rz <= b * b


## Le champ de forme de la masse en cette colonne : `1` au coeur, `0` sur le
## contour, negatif au-dela. Rend `-1` sans echantillonner si la colonne est
## loin.
##
## Trois echantillons de bruit — deux pour le warp, un pour la peau —, payes par
## les seules colonnes du voisinage d'un massif. La version d'avant en prenait
## deux ; le troisieme achete la deformation du domaine, qui est ce qui fait la
## silhouette, et le bruit lent qu'il remplace ne faisait pas mieux.
func shape(cx: int, cz: int) -> float:
	if not near(cx, cz):
		return -1.0
	var fx: float = float(cx)
	var fz: float = float(cz)

	# 1. La deformation du domaine. On deplace le point, puis on mesure.
	var wf: float = WARP_WAVES / radius
	var w: float = amp_warp * radius
	var qx: float = fx + CWValueNoise.sample(
			fx * wf + warp_ox, fz * wf + warp_oz) * w
	var qz: float = fz + CWValueNoise.sample(
			fx * wf + warp_oz, fz * wf - warp_ox) * w

	# 2. L'ellipse tournee, en coordonnees normalisees.
	var dx: float = qx - x
	var dz: float = qz - z
	var rx: float = (dx * _ca + dz * _sa) / (radius * stretch)
	var rz: float = (dz * _ca - dx * _sa) * stretch / radius
	var u2: float = rx * rx + rz * rz

	# 3. Les lobes angulaires, amortis pres du centre : l'angle n'y a pas de
	#    sens, et un `cos(k x theta)` non amorti y ferait tourner la matiere
	#    d'un bloc a l'autre. Le nombre de lobes etant entier, le terme reste
	#    continu de part et d'autre de la coupure de `atan2`.
	var lobe: float = 0.0
	if amp_lobe > 0.0:
		lobe = cos(float(lobes) * atan2(rz, rx) + lobe_phase) * amp_lobe \
				* clampf(u2 * 3.0, 0.0, 1.0)

	# 4. La peau.
	var ff: float = SKIN_WAVES / radius
	var fine: float = CWValueNoise.sample(fx * ff + warp_oz, fz * ff + warp_ox)
	return 1.0 - u2 + lobe + fine * amp_fine


## Intervalle de matiere ajoute par la masse dans cette colonne, bornes
## **incluses**. `bas > haut` veut dire « rien ici », et c'est le cas de la
## quasi-totalite du monde.
func slab(cx: int, cz: int, ground_top: int) -> Vector2i:
	return slab_from_shape(shape(cx, cz), ground_top, cx, cz)


## L'elevation de la masse au-dessus du sol, en blocs, pour une valeur de forme.
##
## **C'est le point unique du profil** : `slab_from_shape` et `thickness` en
## sortent tous les deux, et il le faut — le placement des grottes lit
## l'epaisseur, le generateur lit la dalle, et deux formules ecrites cote a cote
## finissent par diverger.
##
## Deux choses le composent.
##
## *L'exposant est tire par massif*, `f^p` et non plus `f²`. A `p = 2` la masse
## rejoint le sol tangentiellement — sa pente s'annule sur son contour —, et
## c'est precisement ce qui fait un dome. Sous un, le dessus s'aplatit et les
## flancs tombent : c'est la butte a paroi qu'on cherchait, et elle n'a pas le
## porte-a-faux de la version du 2026-09-07 parce que le contour reste celui du
## champ, pas un chapeau pose dessus.
##
## *Les strates quantifient la hauteur* par paliers de `strata` blocs, melangees
## a la hauteur lisse dans la proportion `strata_mix`. C'est l'abstraction
## demandee : la masse monte par gradins. Un gradin est une marche verticale de
## trois a neuf blocs, donc infranchissable — c'est voulu, et c'est le contrat
## d'escalade qu'on a retire pour l'obtenir.
func rise(f: float) -> int:
	if f <= 0.0:
		return 0
	var h: float = height * pow(f, profile_pow)
	if strata >= 1.0:
		h = lerpf(h, floorf(h / strata) * strata, strata_mix)
	return floori(h)


## L'intervalle de matiere de la masse dans cette colonne.
##
## **Le dessus est mesure depuis le sol de la colonne**, pas depuis celui du
## centre du massif. Une masse posee sur un flanc dont le sol descend de douze
## blocs entre son centre et son bord finissait sinon par une **marche de douze
## blocs** sur tout son contour : la masse s'arretait a l'altitude de son
## centre, le terrain etait ailleurs. Mesure avant correction : 12 blocs de
## marche sur un massif de 16 de haut. C'est la seule chose que la refonte du
## 2026-09-09 n'a pas touchee, et pour cause : elle ne tenait pas a l'escalade,
## elle tenait a la justesse du raccord.
func slab_from_shape(f: float, ground_top: int, cx: int, cz: int) -> Vector2i:
	if f <= 0.0:
		return Vector2i(1, 0)
	var hi: int = ground_top + rise(f)
	var lo: int = ground_top - ROOT_DEPTH + porch(cx, cz)
	if lo > hi:
		return Vector2i(1, 0)
	return Vector2i(lo, hi)


## Epaisseur de la masse au-dessus du sol, en blocs, sans la construire.
func thickness(cx: int, cz: int) -> int:
	return rise(shape(cx, cz))


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
	return ("CWMesa(pos=(%.0f, %.0f), r=%.0f, sol=%d, haut=%.0f, allonge=%.2f,"
			+ " p=%.2f, lobes=%d x %.2f, warp=%.2f, gradins=%.0f, grottes=%d)") % [
			x, z, radius, base_y, height, stretch, profile_pow, lobes,
			amp_lobe, amp_warp, strata, caves.size()]
