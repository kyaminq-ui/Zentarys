class_name CWPathNetwork
extends RefCounted

## Le **reseau de chemins** : les voies qui relient entre eux les jalons d'une
## zone — son bourg, ses donjons, ses agglomerations — et qui se raccordent a
## celles des zones voisines.
##
## -- Creation de ce projet, et le dire vaut mieux que le sous-entendre --------
##
## La source **n'a pas de reseau de routes**, et ce depot l'a etabli deux fois :
## `World_roadField` (@0052bfc0) n'est pas un champ de routes mais
## l'aplanissement du bourg, et le type d'element 1 est le bourg lui-meme, un
## par zone. Les aretes du graphe de sites de region ne sont pas des voies non
## plus — c'est ce que dit l'invariant n. 3, et c'est pourquoi
## `site_edge_radius` vaut zero.
##
## Ce qui suit est donc **entierement de ce projet**. Ce qui le justifie est ce
## qu'on voit sur les captures du jeu d'origine : des sentiers clairs qui
## montent en lacets le long d'un flanc, contournent un massif, et passent d'un
## lieu habite a un autre. On les reproduit par la fonction qu'ils remplissent,
## pas par un algorithme releve.
##
## -- Trois proprietes qui decident de toute l'architecture -------------------
##
## **1. Un chemin se pose en dernier.** Il ne deforme pas le champ d'altitude :
## il *tranche* la colonne a son altitude a lui, efface ce qui le surplombe de
## trop pres — y compris le socle d'un surplomb, d'ou les tunnels — et jette un
## tablier au-dessus de l'eau. C'est la meme place dans la chaine que la couche
## de surplombs, une case plus loin : grotte et chemin creusent, le surplomb
## remplit, l'etang mouille, le terrain porte.
##
## **2. Un chemin ne sort pas de sa zone.** C'est ce qui rend la couche
## abordable : sans cela, une colonne devrait consulter le reseau des neuf zones
## voisines, donc les construire toutes. Les zones se raccordent par des
## **portes** — un point de passage sur chaque frontiere, calcule a partir de
## l'identite de la frontiere elle-meme, donc identique des deux cotes sans
## qu'aucune des deux zones ait besoin de lire l'autre. Deux voisines tracent
## chacune leur moitie, et les deux moities se rejoignent.
##
## **3. Le trace se relaxe, il ne se cherche pas.** Un A* sur une grille de
## hauteurs demanderait des dizaines de milliers d'echantillons de colonne a
## 75 us piece. Ici, chaque arete part d'une ligne droite et ses points
## interieurs glissent perpendiculairement, huit fois, vers ce qui monte le
## moins. C'est une descente locale : elle ne trouve pas l'optimum, elle
## **contourne le relief**, ce qui est tout ce qu'on lui demande.

const ZONE_SIZE: int = CWWorldParams.ZONE_SIZE
const ZONE_GRID: int = CWWorldParams.ZONE_GRID

## Cote d'une cellule d'index, en unites monde. **256 est un choix, pas un
## reglage** : c'est la taille d'un chunk, donc l'empreinte d'un bloc de terrain
## de 16 y tient entiere, et une seule consultation d'index suffit pour les
## 256 colonnes d'un bloc.
const INDEX_CELL: int = 256
const INDEX_SHIFT: int = 8

## Demi-largeur de la chaussee, en blocs, puis largeur de l'accotement ou le
## terrain se raccorde au chemin.
const HALF_WIDTH: float = 4.5
const SHOULDER: float = 5.5
## Largeur, en blocs, sur laquelle la matiere de la chaussee se trame dans celle
## du lieu. Meme mecanisme que la plage et la falaise : un chemin qui s'arrete
## sur un trait a l'air peint, un chemin dont le bord s'effiloche a l'air
## parcouru.
const ROAD_FADE: float = 4.0

## Hauteur libre degagee au-dessus de la chaussee, **a ciel ouvert**. C'est elle
## qui fait qu'un chemin efface les broussailles de matiere qui le surplombent.
const CLEARANCE: int = 6

## Sous un massif, le degagement n'est plus cette constante : il est **une part
## de la masse traversee**, sans quoi un tunnel de six blocs sous quarante
## blocs de roche est un terrier. Il faut cependant lui laisser un toit, sinon
## le chemin coupe le massif en deux et il n'y a plus de tunnel du tout, il y a
## une tranchee.
const TUNNEL_SHARE: float = 0.55
## Epaisseur minimale du toit, en blocs. C'est elle qui empeche la coupe en deux.
const TUNNEL_ROOF_MIN: int = 8

## Profondeur minimale de la chaussee sous le terrain qui la borde, en blocs.
##
## Demande du 2026-09-08 : *un chemin doit toujours etre creuse d'au moins un
## bloc*. C'est ce qui lui donne son ombre portee et sa berge, donc ce qui le
## fait lire comme un chemin plutot que comme une bande de gravier peinte. Le
## bornage a `MAX_CUT` reste au-dessus : un chemin s'enfonce d'un bloc, jamais
## de dix.
const MIN_CUT: int = 1

## Hauteur de la chaussee au-dessus de la surface libre, sur un franchissement.
##
## **Il n'y a plus de pont** (2026-09-09) : la ou le chemin rencontrait l'eau, il
## la **comble**. La demande est directe — *les ponts sont trop compliques a
## integrer, remplacer par remplir le gap par le chemin* — et ce qu'elle retire
## est un systeme entier : un modele a six voxels par bloc, son noeud de rendu,
## un tablier de matiere, un garde-corps, et la condition « y a-t-il un ouvrage
## ici » qu'il fallait porter jusqu'au generateur et jusqu'aux deux dispersions.
##
## Ce qui reste est une **levee** : le remblai de la chaussee, qui montait deja
## a l'approche, ne redescend plus. Deux blocs au-dessus de l'eau, pour qu'on ne
## marche pas dedans.
##
## > **Ce que ca coute, et c'est dit en clair : une levee est un barrage.** Ce
## > monde ne simule pas l'ecoulement, donc rien ne monte derriere elle — mais
## > une riviere coupee reste une riviere coupee, et c'est le prix demande.
const CAUSEWAY_RISE: int = 2

## Seuil du champ de chenaux au-dela duquel on ne cherche meme pas d'eau sous le
## trace. Genereux : le champ est lisse, et rater un franchissement coute plus
## cher que sonder quelques segments pour rien.
const CHAN_PROCHE: float = 0.14
## Pas du raffinement, en blocs.
##
## **Un, depuis que la levee remplace le pont** (2026-09-09). Quatre suffisait a
## un tablier : il fallait seulement savoir *qu'il y avait une riviere ici*, et
## une riviere de ce monde fait six blocs de large. Une levee demande plus — son
## altitude doit **rester au-dessus de la surface libre colonne par colonne**,
## faute de quoi on marche dans l'eau — et une mare, elle, peut faire deux blocs
## de large. Mesure a quatre : trois colonnes noyees sur 3 232 ; a un : aucune,
## pour 0,2 s de plus sur la construction d'une zone (1,7 s a 1,9 s).
const CROSSING_STEP: int = 1

## Longueur maximale de la **rampe d'acces** ajoutee a chaque bout d'un
## franchissement, et son pas, en blocs.
##
## -- Pourquoi un franchissement ne s'arrete pas a sa derniere colonne mouillee
##
## Le releve s'arrete au premier point sec de chaque rive, et `causeway_at`
## tient alors son altitude constante sur toute sa portee — dix blocs de plus.
## Le terrain, lui, ne s'arrete pas : il monte ou descend pendant ces dix blocs,
## et la ou l'influence de la levee cesse, la chaussee retombe d'un coup sur
## `sol - MIN_CUT`. Mesure : **5 blocs de marche a la culee, et 60 culees sur
## 135 ressautaient**.
##
## La levee se prolonge donc jusqu'a **rencontrer le sol**, en descendant d'au
## plus un bloc tous les deux : le remblai rejoint la tranchee la ou les deux
## regles rendent le meme nombre, et le raccord n'est plus a accorder, il est
## **exact**. C'est la meme idee que le raccord tangentiel d'un massif — une
## surface qui rejoint une autre doit y arriver a la bonne pente, pas y tomber.
const RAMP_LEN: int = 64
const RAMP_STEP: int = 2

## Longueur visee d'un segment de **trace**, en unites monde, et bornes du
## nombre de segments par arete. C'est la maille a laquelle le chemin cherche
## son itineraire — grossiere par construction, parce que chaque point coute
## des echantillons de colonne a chaque passe.
const SEGMENT_LEN: int = 256
const SEGMENTS_MIN: int = 4
const SEGMENTS_MAX: int = 20

## Longueur d'un segment de **profil**, en unites monde. C'est la maille a
## laquelle le chemin epouse le sol, une fois son itineraire trouve.
##
## > **Les deux mailles etaient confondues, et ca donnait des tranchees de seize
## > blocs.** Avec un seul jalon tous les 192 blocs, l'altitude du chemin entre
## > deux jalons est une **corde** : le terrain bombe au milieu, le chemin passe
## > dessous, et la colonne est tranchee de tout ce qui les separe. Mesure sur
## > une capture : 167 blocs de sol pour un chemin a 151, soit une saignee a
## > paroi verticale qu'aucun accotement de quatre blocs ne pouvait raccorder.
## > *Chercher un itineraire et epouser un sol ne se font pas a la meme echelle*,
## > et il n'y avait aucune raison de payer la premiere a la maille de la
## > seconde.
const PROFILE_LEN: int = 32

## Ce qu'un chemin s'autorise a trancher et a remblayer, en blocs. Au-dela, il
## suit le terrain : mieux vaut un chemin qui ondule qu'un chemin qui creuse un
## canyon pour rester plat.
const MAX_CUT: int = 4
const MAX_FILL: int = 3

## Passes de relaxation, et amplitude du premier deplacement lateral.
const RELAX_PASSES: int = 6
const RELAX_REACH: float = 420.0
## Poids de la penalite de longueur contre celle de denivele. Grand : un chemin
## qui contourne un massif reste un chemin, pas un detour de deux zones.
const LENGTH_WEIGHT: float = 0.55

# -- Le trace connait les massifs (2026-09-09) --------------------------------
#
# Jusqu'ici la fonction de cout ignorait totalement la couche de massifs : un
# chemin allait tout droit, et s'il rencontrait une masse de quarante blocs il
# la percait. Le tunnel qui en sortait etait joli ; *ce n'etait pas une raison
# pour le laisser au hasard.*
#
# La masse entre donc dans le cout, et le poids repond a une question qui a une
# reponse naturelle : **percer un bloc de roche doit couter ce que couterait le
# monter.** Le denivele est deja compte en blocs (`montee`), donc le poids est
# de l'ordre de 1 — a 0,9, contourner est legerement prefere a percer, a
# denivele egal.
#
# **Ce que ca produit n'est pas un contournement construit, et c'est mieux
# ainsi.** La penalite etant proportionnelle a l'**epaisseur** traversee, la
# relaxation ne fuit pas la masse : elle glisse vers la ou elle est mince,
# c'est-a-dire vers son contour. Le trace decrit donc un arc dont le rayon suit
# celui de la masse — un chemin de corniche — et il finit par la percer quand
# meme lorsque le detour couterait plus cher que le tunnel. C'est le mot
# « orbitale » du 2026-09-08, obtenu par le cout plutot que par une regle.
const MESA_WEIGHT: float = 0.9

## Pas de sondage de la masse **le long** d'un segment, en blocs.
##
## -- Pourquoi la masse ne se lit pas au jalon --------------------------------
##
## La premiere version lisait l'epaisseur **au jalon**, comme l'altitude. Elle
## n'a presque rien change : 0,21 bloc d'epaisseur moyenne traversee contre 0,17.
## La raison est une affaire d'echelle, et c'est la meme que celle du piege deja
## note dans `nextsteps` — *chercher un itineraire et epouser un sol ne se font
## pas a la meme echelle*. Les jalons sont espaces de `SEGMENT_LEN`, soit 256
## blocs ; un massif fait 70 a 140 blocs de rayon. **Une masse tient donc tout
## entiere entre deux jalons**, et le cout ne la voyait jamais.
##
## L'altitude, elle, peut se lire au jalon : c'est un champ lisse a grande
## echelle. La masse est un objet local, et un objet local se manque.
##
## On integre donc l'epaisseur le long des deux segments adjacents. Le pas est
## de 48 blocs : le plus petit massif a 34 blocs de rayon, donc aucun ne passe
## entre deux sondages. Un pas de 32 a ete essaye — il rend la meme mesure
## (0,08 bloc d'epaisseur moyenne traversee contre 0,09) pour quatre secondes de
## plus sur la suite de validation.
const MESA_PROBE: int = 48

## Nombre maximum d'agglomerations raccordees au reseau d'une zone, en plus du
## bourg et des donjons. Chaque noeud de plus est une arete de plus a relaxer.
const MAX_HAMEAUX: int = 4

## Marge laissee entre une porte et le coin de la frontiere.
const GATE_MARGIN: int = 2560


## Le reseau d'une zone : les segments, et l'index qui evite de les parcourir.
class Zone extends RefCounted:
	## Six flottants par segment : ax, az, ay, bx, bz, by.
	var segments: PackedFloat32Array = PackedFloat32Array()
	## Cellule d'index -> indices de segment (et non decalages : l'appelant
	## multiplie par six).
	var index: Dictionary = {}
	## Les **franchissements** : une entree chacun, trois flottants par point —
	## x, z, et l'altitude de la chaussee au-dessus de l'eau.
	##
	## Ils sont releves au trace, la ou l'eau et le profil sont connus ensemble,
	## et c'est la seule chose que le generateur ait besoin de savoir d'eux : ou
	## le chemin **comble** au lieu de creuser. Depuis le 2026-09-09 il n'y a
	## plus de pont, donc plus de travee a instancier ni de tablier a poser — un
	## franchissement n'est plus qu'une portion de chemin dont l'altitude est
	## imposee par l'eau plutot que par le sol. Voir `causeway_at`.
	var crossings: Array[PackedFloat32Array] = []
	## Boite englobante de chaque franchissement, quatre flottants : x0, z0, x1,
	## z1, deja elargie de la **portee** d'un chemin — accotement compris, parce
	## que le remblai d'une levee descend rejoindre le lit par ses flancs. Un
	## franchissement couvre une poignee de colonnes du monde ; sans ce test
	## prealable, chaque colonne de chaussee parcourrait tous les points de tous
	## les franchissements de sa zone.
	var crossing_bounds: PackedFloat32Array = PackedFloat32Array()

	func is_empty() -> bool:
		return segments.is_empty()


var _params: CWWorldParams
var _zones: Dictionary = {}
var _mutex: Mutex = Mutex.new()
var _build_mutex: Mutex = Mutex.new()
var _empty: Zone = Zone.new()


func _init(params: CWWorldParams) -> void:
	_params = params


func clear_cache() -> void:
	_mutex.lock()
	_zones.clear()
	_mutex.unlock()


## Le reseau d'une zone **si et seulement si** il est deja construit, sinon
## `null`.
##
## Le rendu passe par ici et jamais par `get_zone` : construire un reseau coute
## trois cents millisecondes, et les payer sur le fil principal ferait un a-coup
## a chaque zone traversee. Le terrain, lui, les paie depuis son pool ; l'ouvrage
## apparait au tour d'apres.
func built_zone(zx: int, zz: int) -> Zone:
	_mutex.lock()
	var hit: Variant = _zones.get(zx * ZONE_GRID + zz)
	_mutex.unlock()
	return hit


## Le reseau vide, rendu quand la couche est desactivee.
func empty_zone() -> Zone:
	return _empty


## Le reseau de la zone qui contient la colonne (x, z), construit au besoin.
func zone_at(x: int, z: int, field: CWTerrainField) -> Zone:
	return get_zone(CWWorldParams.zone_of(x), CWWorldParams.zone_of(z), field)


func get_zone(zx: int, zz: int, field: CWTerrainField) -> Zone:
	if zx < 0 or zz < 0 or zx >= ZONE_GRID or zz >= ZONE_GRID:
		return _empty
	var key: int = zx * ZONE_GRID + zz

	_mutex.lock()
	var hit: Variant = _zones.get(key)
	_mutex.unlock()
	if hit != null:
		return hit

	# Une zone coute quelques centaines de millisecondes d'echantillonnage : les
	# autres fils attendent celui qui la construit plutot que de refaire le meme
	# travail. C'est le patron de `CWTileFeatureGrid`, sans sa garde de
	# reentrance — le champ d'altitude ne lit jamais les chemins.
	_build_mutex.lock()
	_mutex.lock()
	hit = _zones.get(key)
	_mutex.unlock()
	if hit != null:
		_build_mutex.unlock()
		return hit
	var built: Zone = _build_zone(zx, zz, field)
	_mutex.lock()
	_zones[key] = built
	_mutex.unlock()
	_build_mutex.unlock()
	return built


## Les segments a consulter pour la colonne (x, z). Rend un `PackedInt32Array`
## d'indices, vide la plupart du temps.
##
## **A appeler une fois par bloc de terrain, pas une fois par colonne** : une
## cellule d'index fait 256 unites et un bloc 16, donc les 256 colonnes d'un
## bloc tombent toutes dans la meme cellule.
static func cell_key(x: int, z: int) -> int:
	return (x >> INDEX_SHIFT) * 65536 + (z >> INDEX_SHIFT)


# -- Ce qu'un chemin fait a une colonne ---------------------------------------

## Le chemin le plus proche de la colonne : `Vector2(distance, altitude)`.
## Distance infinie quand aucun segment n'est a portee.
static func nearest(zone: Zone, cells: PackedInt32Array, x: float,
		z: float) -> Vector2:
	var best_d2: float = INF
	var best_y: float = 0.0
	var s: PackedFloat32Array = zone.segments
	for si in cells:
		var o: int = si * 6
		var ax: float = s[o]
		var az: float = s[o + 1]
		var bx: float = s[o + 3]
		var bz: float = s[o + 4]
		var vx: float = bx - ax
		var vz: float = bz - az
		var len2: float = vx * vx + vz * vz
		var t: float = 0.0
		if len2 > 0.0:
			t = clampf(((x - ax) * vx + (z - az) * vz) / len2, 0.0, 1.0)
		var dx: float = x - (ax + vx * t)
		var dz: float = z - (az + vz * t)
		var d2: float = dx * dx + dz * dz
		if d2 < best_d2:
			best_d2 = d2
			best_y = s[o + 2] + (s[o + 5] - s[o + 2]) * t
	if is_inf(best_d2):
		return Vector2(INF, 0.0)
	return Vector2(sqrt(best_d2), best_y)


## Portee au-dela de laquelle un chemin ne touche plus la colonne.
static func reach() -> float:
	return HALF_WIDTH + SHOULDER


## Vrai si la colonne est sur la chaussee elle-meme, et non sur l'accotement.
static func on_roadway(road: Vector2) -> bool:
	return road.x <= HALF_WIDTH


## Dessus de la colonne une fois le chemin passe.
##
## -- La chaussee est **toujours** en contrebas, et l'accotement l'y rejoint ---
##
## Sur la chaussee, le dessus est l'altitude du profil, rabattue d'au moins
## `MIN_CUT` sous le terrain de la colonne. Sur l'accotement, le terrain
## redescend vers elle par une courbe en S : sans elle, chaque bord de chemin
## serait une marche verticale de plusieurs blocs.
##
## > **La version precedente creusait ses bords et pas son milieu, et c'est ce
## > qu'on voyait en jeu.** Elle interpolait entre le terrain et *le profil*,
## > puis rabattait le resultat d'un bloc. Or le profil est lisse : il passe
## > au-dessus du terrain une colonne sur trois, et la regle du 2026-09-09 qui
## > autorisait le remblai pour la rampe d'un pont le laissait alors remonter
## > sans rien rabattre du tout. Mesure sur la zone de depart : **35,3 % des
## > colonnes de chaussee etaient en remblai**, et l'ecart moyen au terrain
## > valait **-0,26 bloc au milieu du ruban contre -1,00 a son bord**. Un chemin
## > avec une levre a son contour et rien au centre — exactement le reproche.
## >
## > **La correction est un ordre, pas une borne de plus.** On calcule d'abord
## > l'altitude de la *chaussee dans cette colonne* — profil, borne par ce qu'un
## > chemin s'autorise a trancher, puis rabattu sous le terrain —, et l'
## > accotement interpole *vers elle*. Le rabattement est donc dans la cible et
## > non applique par-dessus : il n'y a plus ni levre ni palier, la tranchee est
## > pleine largeur, et le raccord reste continu d'un bout a l'autre.
##
## -- Sauf sur un franchissement, ou le chemin **comble** ---------------------
##
## `span` est l'altitude relevee du franchissement (`causeway_at`), et `NAN`
## partout ailleurs. La, le chemin ne creuse pas : il remblaie, et le remblai
## descend rejoindre le lit par l'accotement — c'est ce qui donne a une levee
## ses flancs en pente plutot qu'un mur.
##
## Les deux branches se rejoignent **par construction** : la ou le remblai
## retombe sous `creux`, `maxf` rend `creux`, qui est ce que rend l'autre
## branche. Une culee n'a donc pas de marche, et il n'y a rien a accorder.
##
## -- Et un plancher **local** : on ne marche jamais dans l'eau ---------------
##
## `libre` est la surface libre de la colonne (`CWTerrainField.free_water`), et
## la chaussee passe toujours `CAUSEWAY_RISE` au-dessus d'elle. Le releve des
## franchissements ne peut pas s'en charger seul : il suit **l'axe du trace** et
## ne connait ni les colonnes d'accotement, ni les mares que le champ de chenaux
## ne signale pas. Mesure avec le seul releve : sept colonnes de chaussee noyees
## sur la zone de depart, toutes dans une mare d'un bloc de fond que le gabarit
## de raffinement n'avait pas vue.
##
## Le partage est donc net, et chacun fait ce qu'il sait faire : **le releve
## donne la rampe** — la pente douce, qui demande de connaitre l'ouvrage entier
## — et **la colonne donne le plancher**, qui ne demande rien d'autre qu'elle.
##
## **Point unique de la regle** : le generateur et les deux dispersions passent
## par ici, faute de quoi la flore d'accotement flotte ou s'enterre — le meme
## piege que le creusement des etangs au jalon 1.14.
static func shaped_top(ground_top: int, road: Vector2, span: float = NAN,
		libre: int = CWTerrainField.NO_WATER) -> int:
	if road.x >= reach():
		return ground_top
	var t: float = clampf((reach() - road.x) / SHOULDER, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	# Le bornage est repris **ici, colonne par colonne**, et pas seulement au
	# calcul du profil. La raison est une interpolation : le profil borne son
	# ecart au sol tous les 32 blocs, mais entre deux de ses jalons l'altitude
	# du chemin est une corde, et le terrain a le droit d'y bomber. Mesure sur
	# la zone de depart avant ce bornage : 4 colonnes de chaussee sur 340
	# tranchaient plus de quatre blocs. Le chemin prefere onduler.
	var creux: float = float(ground_top - MIN_CUT)
	var chaussee: float = clampf(road.y, float(ground_top - MAX_CUT), creux)
	if not is_nan(span):
		chaussee = maxf(span, creux)
	if libre != CWTerrainField.NO_WATER:
		chaussee = maxf(chaussee, float(libre + CAUSEWAY_RISE))
	return roundi(lerpf(float(ground_top), chaussee, t))


# -- Construction -------------------------------------------------------------

## Porte d'une frontiere **verticale** : celle qui separe la zone `zx - 1` de la
## zone `zx`. Les deux voisines la calculent de la meme facon a partir de la
## seule identite de la frontiere, donc elles tombent sur le meme point sans
## avoir a se lire.
static func gate_vertical(seed_v: int, zx: int, zz: int) -> Vector2i:
	var rng := CWRand.new((seed_v * 2654435761 + zx * 40503 + zz * 24571
			+ 7919) & 0xFFFFFFFF)
	rng.next()
	rng.next()
	return Vector2i(zx * ZONE_SIZE,
			zz * ZONE_SIZE + GATE_MARGIN + rng.mod(ZONE_SIZE - GATE_MARGIN * 2))


## Porte d'une frontiere **horizontale** : celle qui separe `zz - 1` de `zz`.
static func gate_horizontal(seed_v: int, zx: int, zz: int) -> Vector2i:
	var rng := CWRand.new((seed_v * 2654435761 + zx * 24571 + zz * 40503
			+ 104729) & 0xFFFFFFFF)
	rng.next()
	rng.next()
	return Vector2i(
			zx * ZONE_SIZE + GATE_MARGIN + rng.mod(ZONE_SIZE - GATE_MARGIN * 2),
			zz * ZONE_SIZE)


func _build_zone(zx: int, zz: int, field: CWTerrainField) -> Zone:
	var out := Zone.new()
	var features: Array = field.features().get_zone(zx, zz, field)
	if features.is_empty():
		return out

	# -- Les noeuds -----------------------------------------------------------
	# Le bourg d'abord : c'est le centre du reseau, et les portes s'y
	# raccordent. Puis les donjons, puis les agglomerations les plus proches du
	# bourg — chacune est une arete de plus a relaxer, d'ou le plafond.
	var bourg := Vector2i(-1, -1)
	var noeuds: Array[Vector2i] = []
	var hameaux: Array = []
	for f in features:
		if f.type == CWTileFeature.TYPE_TOWN:
			bourg = Vector2i(int(f.x), int(f.z))
		elif f.type == CWTileFeature.TYPE_DUNGEON:
			noeuds.append(Vector2i(int(f.x), int(f.z)))
		elif f.type == 14:
			hameaux.append(f)
	if bourg.x < 0:
		return out
	hameaux.sort_custom(func(a, b):
			var da: float = Vector2(a.x - float(bourg.x), a.z - float(bourg.y)).length_squared()
			var db: float = Vector2(b.x - float(bourg.x), b.z - float(bourg.y)).length_squared()
			return da < db)
	for i in mini(MAX_HAMEAUX, hameaux.size()):
		noeuds.append(Vector2i(int(hameaux[i].x), int(hameaux[i].z)))
	noeuds.push_front(bourg)

	# -- Les aretes -----------------------------------------------------------
	# Un arbre couvrant de poids minimal sur les noeuds de la zone : c'est le
	# plus petit reseau qui relie tout, et c'est ce qu'on veut — un maillage
	# complet ferait une toile d'araignee dans un paysage qui n'a pas dix mille
	# habitants.
	var aretes: Array = _arbre_couvrant(noeuds)
	# Puis les quatre portes, chacune raccordee au bourg.
	var s: int = _params.world_seed
	aretes.append([bourg, gate_vertical(s, zx, zz)])
	aretes.append([bourg, gate_vertical(s, zx + 1, zz)])
	aretes.append([bourg, gate_horizontal(s, zx, zz)])
	aretes.append([bourg, gate_horizontal(s, zx, zz + 1)])

	var x0: int = zx * ZONE_SIZE
	var z0: int = zz * ZONE_SIZE
	for a in aretes:
		var trace: PackedFloat32Array = _relaxe(a[0], a[1], field, x0, z0, out)
		_ajoute(out, trace)
	return out


## Arbre couvrant de poids minimal, par la methode de Prim. Le nombre de noeuds
## se compte sur les doigts : la version quadratique est la bonne.
static func _arbre_couvrant(noeuds: Array[Vector2i]) -> Array:
	var out: Array = []
	var n: int = noeuds.size()
	if n < 2:
		return out
	var dedans := PackedByteArray()
	dedans.resize(n)
	dedans[0] = 1
	for _k in n - 1:
		var best: float = INF
		var bi: int = -1
		var bj: int = -1
		for i in n:
			if dedans[i] == 0:
				continue
			for j in n:
				if dedans[j] == 1:
					continue
				var dx: float = float(noeuds[i].x - noeuds[j].x)
				var dz: float = float(noeuds[i].y - noeuds[j].y)
				var d: float = dx * dx + dz * dz
				if d < best:
					best = d
					bi = i
					bj = j
		if bj < 0:
			break
		dedans[bj] = 1
		out.append([noeuds[bi], noeuds[bj]])
	return out


## Trace une arete, en deux temps qui n'ont ni le meme role ni la meme maille :
##
##   1. **l'itineraire** — une ligne droite dont les points interieurs glissent
##      perpendiculairement, six passes, vers ce qui monte le moins. Maille
##      grossiere : chaque point coute deux echantillons de colonne par passe ;
##   2. **le profil** — l'itineraire reechantillonne tous les 32 blocs, chaque
##      point pose sur le sol, l'altitude lissee puis **bornee** a ce qu'un
##      chemin s'autorise a trancher et a remblayer.
##
## Rend une suite de triplets (x, z, y).
func _relaxe(a: Vector2i, b: Vector2i, field: CWTerrainField,
		x0: int, z0: int, zone: Zone) -> PackedFloat32Array:
	var d: float = Vector2(b - a).length()
	var n: int = clampi(int(d) / SEGMENT_LEN, SEGMENTS_MIN, SEGMENTS_MAX)
	var px := PackedFloat32Array()
	var pz := PackedFloat32Array()
	px.resize(n + 1)
	pz.resize(n + 1)
	for i in n + 1:
		var t: float = float(i) / float(n)
		px[i] = float(a.x) + (float(b.x) - float(a.x)) * t
		pz[i] = float(a.y) + (float(b.y) - float(a.y)) * t

	# La normale du segment, une fois : les points glissent tous dans la meme
	# direction, celle qui est perpendiculaire a la corde. C'est moins general
	# qu'une normale locale, et c'est ce qu'il faut — une normale locale laisse
	# le trace se replier sur lui-meme.
	var dir: Vector2 = Vector2(b - a).normalized()
	var nx: float = -dir.y
	var nz: float = dir.x

	var hs := PackedFloat32Array()
	hs.resize(n + 1)
	for i in n + 1:
		hs[i] = field.sample_column(int(px[i]), int(pz[i])).x

	var reach: float = RELAX_REACH
	for _pass in RELAX_PASSES:
		for i in range(1, n):
			var best_c: float = _cout(hs[i - 1], hs[i], hs[i + 1],
					px[i], pz[i], px[i - 1], pz[i - 1], px[i + 1], pz[i + 1],
					_masse_arc(field, px[i], pz[i], px[i - 1], pz[i - 1],
							px[i + 1], pz[i + 1]))
			var best_x: float = px[i]
			var best_z: float = pz[i]
			var best_h: float = hs[i]
			for sgn in [-1.0, 1.0]:
				var cx: float = px[i] + nx * reach * sgn
				var cz: float = pz[i] + nz * reach * sgn
				# Un chemin reste chez lui : c'est la propriete qui evite de
				# construire les neuf zones voisines pour une colonne.
				cx = clampf(cx, float(x0), float(x0 + ZONE_SIZE))
				cz = clampf(cz, float(z0), float(z0 + ZONE_SIZE))
				var ch: float = field.sample_column(int(cx), int(cz)).x
				var c: float = _cout(hs[i - 1], ch, hs[i + 1], cx, cz,
						px[i - 1], pz[i - 1], px[i + 1], pz[i + 1],
						_masse_arc(field, cx, cz, px[i - 1], pz[i - 1],
								px[i + 1], pz[i + 1]))
				if c < best_c:
					best_c = c
					best_x = cx
					best_z = cz
					best_h = ch
			px[i] = best_x
			pz[i] = best_z
			hs[i] = best_h
		reach *= 0.62

	return _profil(px, pz, field, zone)


## Seconde moitie : l'itineraire est trouve, il faut maintenant le poser sur le
## sol. On le reechantillonne a la maille fine, on lit le terrain sous chaque
## point, on lisse, puis on **borne** l'ecart au sol.
##
## Le bornage est ce qui empeche la tranchee : un chemin qui reste plat coute au
## terrain tout ce qui le separe de lui, et le lissage seul n'a aucune raison de
## s'arreter a quatre blocs. Ici, il s'y arrete.
##
## **Au-dessus de l'eau, la reference n'est pas le fond mais la surface.** Sans
## quoi le profil plongerait dans chaque riviere qu'il croise, et la levee qui
## la comble serait un escalier.
func _profil(px: PackedFloat32Array, pz: PackedFloat32Array,
		field: CWTerrainField, zone: Zone) -> PackedFloat32Array:
	var n: int = px.size() - 1
	# Longueur cumulee de l'itineraire, pour reechantillonner a pas constant.
	var total: float = 0.0
	for i in n:
		total += Vector2(px[i + 1] - px[i], pz[i + 1] - pz[i]).length()
	var m: int = maxi(2, int(total) / PROFILE_LEN)

	var fx := PackedFloat32Array()
	var fz := PackedFloat32Array()
	var fh := PackedFloat32Array()
	var sol := PackedFloat32Array()
	fx.resize(m + 1)
	fz.resize(m + 1)
	fh.resize(m + 1)
	sol.resize(m + 1)

	var sea: int = _params.sea_level
	# Le champ de chenaux, un par point : c'est lui qui dira au releve des
	# franchissements quels segments valent un raffinement. Le relever plus tard
	# couterait une seconde descente dans le champ pour chaque point de chaque
	# chemin.
	var chan := PackedFloat32Array()
	chan.resize(m + 1)
	var seg: int = 0
	var acc: float = 0.0
	for k in m + 1:
		var target: float = total * float(k) / float(m)
		while seg < n - 1:
			var l: float = Vector2(px[seg + 1] - px[seg],
					pz[seg + 1] - pz[seg]).length()
			if acc + l >= target:
				break
			acc += l
			seg += 1
		var l2: float = Vector2(px[seg + 1] - px[seg],
				pz[seg + 1] - pz[seg]).length()
		var t: float = 0.0 if l2 <= 0.0 else clampf((target - acc) / l2, 0.0, 1.0)
		fx[k] = px[seg] + (px[seg + 1] - px[seg]) * t
		fz[k] = pz[seg] + (pz[seg + 1] - pz[seg]) * t

		var c: Vector4 = field.sample_column_full(int(fx[k]), int(fz[k]))
		var biome: int = CWBiome.at(c.x, c.y, c.z, sea)
		var prof: Vector3i = CWTerrainField.column_profile(c.x, c.w, sea, biome)
		chan[k] = c.w
		# **Au-dessus de l'eau, le profil vise la surface libre et non le fond**
		# (2026-09-09). C'est ici que la chose se decide, et nulle part ailleurs
		# : en la mettant dans le profil, elle traverse le lissage et le bornage
		# comme le reste du chemin, et les trois passes de lissage etalent la
		# marche sur une centaine de blocs de part et d'autre. C'est la **rampe
		# d'acces de la levee**, fabriquee toute seule, et `shaped_top` n'a plus
		# qu'a suivre le profil.
		var ref: float = float(prof.x)
		var eau: int = CWTerrainField.free_water(prof, sea)
		if eau != CWTerrainField.NO_WATER:
			ref = float(eau + CAUSEWAY_RISE)
		sol[k] = ref
		fh[k] = ref

	for _k in 3:
		var lisse := PackedFloat32Array(fh)
		for i in range(1, m):
			lisse[i] = (fh[i - 1] + fh[i] * 2.0 + fh[i + 1]) * 0.25
		fh = lisse
	for k in m + 1:
		fh[k] = clampf(fh[k], sol[k] - float(MAX_CUT), sol[k] + float(MAX_FILL))

	_releve_franchissements(zone, field, fx, fz, fh, chan)

	var out := PackedFloat32Array()
	out.resize((m + 1) * 3)
	for k in m + 1:
		out[k * 3] = fx[k]
		out[k * 3 + 1] = fz[k]
		out[k * 3 + 2] = fh[k]
	return out


## Releve les **franchissements** du trace et les range dans la zone.
##
## -- Pourquoi ce n'est pas le profil qui les donne --------------------------
##
## Le profil pose un jalon tous les 32 blocs. Une riviere de ce monde en fait
## six de large : elle passe donc **entre deux jalons** neuf fois sur dix, et le
## premier releve n'a trouve aucun des franchissements qu'on voyait en jeu.
##
## On raffine donc, mais **seulement la ou il peut y avoir de l'eau**. Le champ
## de chenaux est deja lu a chaque jalon (`chan`), et il est lisse : un jalon a
## trente blocs d'une riviere a deja une valeur basse. On ne raffine donc que
## les segments dont un bout passe sous `CHAN_PROCHE`, et on y avance de quatre
## blocs en quatre blocs. Sur la zone de depart, cela represente moins d'un
## segment sur dix.
##
## -- Ce que l'altitude relevee doit contenir, depuis qu'il n'y a plus de pont -
##
## Elle est **plancherisee par l'eau ici meme** : `maxf(y, libre + RISE)`. Le
## profil vise deja la surface libre, mais il est ensuite lisse et borne, et
## une riviere plus creuse que ne le disait le jalon voisin le ferait passer
## sous l'eau. C'est le seul endroit ou le trace et la surface libre sont connus
## **a la maille de quatre blocs**, donc c'est ici que le plancher se pose — et
## non dans `road_shape`, ou il l'etait tant qu'il y avait un tablier. Ainsi
## `causeway_at` rend un nombre deja juste, et le generateur comme les deux
## dispersions le lisent sans avoir a le corriger chacun de son cote.
func _releve_franchissements(zone: Zone, field: CWTerrainField,
		fx: PackedFloat32Array, fz: PackedFloat32Array,
		fh: PackedFloat32Array, chan: PackedFloat32Array) -> void:
	var sea: int = _params.sea_level
	var n: int = fx.size()
	var passage := PackedFloat32Array()
	var sec: int = 0
	for k in n - 1:
		if minf(chan[k], chan[k + 1]) > CHAN_PROCHE:
			# Loin de tout chenal : rien a raffiner, et le franchissement en
			# cours se termine.
			sec += 1
			if sec >= 2:
				_ferme(zone, passage, field)
				passage = PackedFloat32Array()
			continue
		var d: float = Vector2(fx[k + 1] - fx[k], fz[k + 1] - fz[k]).length()
		var pas: int = maxi(1, int(d) / CROSSING_STEP)
		for i in pas:
			var t: float = float(i) / float(pas)
			var px: float = lerpf(fx[k], fx[k + 1], t)
			var pz: float = lerpf(fz[k], fz[k + 1], t)
			var c: Vector4 = field.sample_column_full(int(px), int(pz))
			var biome: int = CWBiome.at(c.x, c.y, c.z, sea)
			var prof: Vector3i = CWTerrainField.column_profile(
					c.x, c.w, sea, biome)
			var libre: int = CWTerrainField.free_water(prof, sea)
			var y: float = lerpf(fh[k], fh[k + 1], t)
			if libre == CWTerrainField.NO_WATER:
				sec += 1
				# Une culee de chaque cote : le premier point sec qui suit
				# l'eau reste dans le franchissement, le suivant le ferme.
				if sec == 1 and not passage.is_empty():
					passage.append(px)
					passage.append(pz)
					passage.append(y)
				elif sec >= 2:
					_ferme(zone, passage, field)
					passage = PackedFloat32Array()
				continue
			if passage.is_empty() and i > 0:
				# La culee amont : le point sec juste avant l'eau.
				var t0: float = float(i - 1) / float(pas)
				passage.append(lerpf(fx[k], fx[k + 1], t0))
				passage.append(lerpf(fz[k], fz[k + 1], t0))
				passage.append(lerpf(fh[k], fh[k + 1], t0))
			sec = 0
			passage.append(px)
			passage.append(pz)
			passage.append(roundf(maxf(y, float(libre + CAUSEWAY_RISE))))
	_ferme(zone, passage, field)


## Un franchissement n'est garde qu'a partir de deux points : un point seul n'a
## pas d'axe, donc rien a interpoler.
##
## C'est ici que la levee recoit ses **deux rampes d'acces** — voir `RAMP_LEN`.
func _ferme(zone: Zone, passage: PackedFloat32Array,
		field: CWTerrainField) -> void:
	if passage.size() < 6:
		return
	var n: int = passage.size() / 3
	var tete := Vector2(passage[0], passage[1])
	var queue := Vector2(passage[(n - 1) * 3], passage[(n - 1) * 3 + 1])
	var amont: PackedFloat32Array = _rampe(field, tete,
			tete - Vector2(passage[3], passage[4]), passage[2])
	var aval: PackedFloat32Array = _rampe(field, queue,
			queue - Vector2(passage[(n - 2) * 3], passage[(n - 2) * 3 + 1]),
			passage[(n - 1) * 3 + 2])

	# La rampe amont est construite du dedans vers le dehors : elle se recolle
	# a l'envers.
	var complet := PackedFloat32Array()
	for i in range(amont.size() / 3 - 1, -1, -1):
		complet.append(amont[i * 3])
		complet.append(amont[i * 3 + 1])
		complet.append(amont[i * 3 + 2])
	complet.append_array(passage)
	complet.append_array(aval)

	zone.crossings.append(complet)
	var x0: float = INF
	var z0: float = INF
	var x1: float = -INF
	var z1: float = -INF
	for i in complet.size() / 3:
		x0 = minf(x0, complet[i * 3])
		x1 = maxf(x1, complet[i * 3])
		z0 = minf(z0, complet[i * 3 + 1])
		z1 = maxf(z1, complet[i * 3 + 1])
	# Elargie de la **portee** du chemin et non de sa demi-largeur : le remblai
	# d'une levee descend rejoindre le lit par l'accotement, donc le
	# franchissement concerne des colonnes que la chaussee ne couvre pas.
	zone.crossing_bounds.append(x0 - reach())
	zone.crossing_bounds.append(z0 - reach())
	zone.crossing_bounds.append(x1 + reach())
	zone.crossing_bounds.append(z1 + reach())


## La rampe d'acces d'un bout de levee : des points qui prolongent l'axe vers
## l'exterieur, en descendant d'au plus un bloc tous les `RAMP_STEP`, jusqu'a
## rencontrer `sol - MIN_CUT`.
##
## Elle s'arrete **des que le remblai passe sous la tranchee**, et pas avant :
## c'est la que `maxf(span, creux)` de `shaped_top` bascule sur `creux`, donc la
## que les deux regles rendent deja le meme nombre. Au-dela, le franchissement
## n'a plus rien a dire.
func _rampe(field: CWTerrainField, tete: Vector2, sortant: Vector2,
		y0: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if sortant.length_squared() <= 0.0:
		return out
	var dir: Vector2 = sortant.normalized()
	var sea: int = _params.sea_level
	var y: float = y0
	var k: int = RAMP_STEP
	while k <= RAMP_LEN:
		var q: Vector2 = tete + dir * float(k)
		var c: Vector4 = field.sample_column_full(int(q.x), int(q.y))
		var biome: int = CWBiome.at(c.x, c.y, c.z, sea)
		var prof: Vector3i = CWTerrainField.column_profile(c.x, c.w, sea, biome)
		# **Une rampe qui retombe dans l'eau n'est pas une rampe.** Le releve
		# ferme un franchissement au second point sec, et une rive peut
		# retrouver de l'eau deux blocs plus loin — un bras mort, une mare de la
		# berge. Tant qu'il y en a, la rampe garde son altitude au-dessus de la
		# surface libre au lieu de descendre.
		var eau: int = CWTerrainField.free_water(prof, sea)
		if eau != CWTerrainField.NO_WATER:
			y = maxf(y, float(eau + CAUSEWAY_RISE))
			out.append(q.x)
			out.append(q.y)
			out.append(y)
			k += RAMP_STEP
			continue
		var creux: float = float(prof.x - MIN_CUT)
		if y <= creux:
			out.append(q.x)
			out.append(q.y)
			out.append(creux)
			break
		y = maxf(creux, y - 1.0)
		out.append(q.x)
		out.append(q.y)
		out.append(y)
		k += RAMP_STEP
	_eteint(out, tete, dir, k + RAMP_STEP)
	return out


## Ferme une rampe par un **point mort** : un point d'axe dont l'altitude est
## si basse que `maxf(span, creux)` de `shaped_top` rend `creux` des qu'on
## l'approche.
##
## Sans lui, `causeway_at` tient l'altitude du dernier point sur toute sa portee
## — dix blocs de plus —, contre un terrain qui, lui, continue de monter et de
## descendre. C'est ce qui restait de la marche a la culee une fois la rampe
## posee. Avec lui, la levee s'eteint **dans** son dernier segment plutot qu'au
## bord d'un disque.
static func _eteint(out: PackedFloat32Array, tete: Vector2, dir: Vector2,
		k: int) -> void:
	if out.is_empty():
		return
	var q: Vector2 = tete + dir * float(k)
	out.append(q.x)
	out.append(q.y)
	out.append(-1.0e9)


## Altitude de la chaussee au-dessus de (x, z) sur un franchissement, ou `NAN`
## si aucun n'y passe. C'est le `span` de `shaped_top`.
##
## -- Pourquoi le remblai vient d'ici et non d'un test par colonne -------------
##
## Il se decidait sur « y a-t-il de l'eau **sous cette colonne** ». C'est une
## condition qui **clignote** : sur un franchissement de la zone de depart, elle
## changeait 140 fois d'avis la ou l'ouvrage a deux culees, et il en sortait des
## trous. Un franchissement n'est pas une propriete de colonne, c'est un **objet
## qui a une etendue** — et cette etendue, le releve la connait depuis le jalon
## 1.16.
##
## **La portee laterale est celle du chemin entier**, accotement compris. Avec
## la seule demi-chaussee, le remblai s'arretait net a `HALF_WIDTH` et la levee
## avait des parois verticales de dix blocs ; avec `reach()`, ses flancs
## descendent rejoindre le lit sur toute la largeur de l'accotement, et le
## raccord est celui de tout le reste du reseau.
static func causeway_at(zone: Zone, x: float, z: float) -> float:
	var portee: float = reach()
	for b in zone.crossings.size():
		var k: int = b * 4
		if x < zone.crossing_bounds[k] or x > zone.crossing_bounds[k + 2] 				or z < zone.crossing_bounds[k + 1] 				or z > zone.crossing_bounds[k + 3]:
			continue
		var passage: PackedFloat32Array = zone.crossings[b]
		var best: float = NAN
		var best_d2: float = portee * portee
		for i in passage.size() / 3 - 1:
			var ax: float = passage[i * 3]
			var az: float = passage[i * 3 + 1]
			var vx: float = passage[(i + 1) * 3] - ax
			var vz: float = passage[(i + 1) * 3 + 1] - az
			var len2: float = vx * vx + vz * vz
			var t: float = 0.0
			if len2 > 0.0:
				t = clampf(((x - ax) * vx + (z - az) * vz) / len2, 0.0, 1.0)
			var dx: float = x - (ax + vx * t)
			var dz: float = z - (az + vz * t)
			var d2: float = dx * dx + dz * dz
			if d2 < best_d2:
				best_d2 = d2
				best = passage[i * 3 + 2] 						+ (passage[(i + 1) * 3 + 2] - passage[i * 3 + 2]) * t
		if not is_nan(best):
			return best
	return NAN


## Cout d'un point : ce qu'il fait monter, plus ce qu'il fait rallonger.
## Epaisseur de massif au-dessus d'une colonne, en blocs, ou zero.
##
## **Pas de recursion a craindre**, et c'est ce qui autorise a l'appeler d'ici :
## la grille de massifs echantillonne le champ d'altitude, et le champ
## d'altitude ne consulte ni les massifs ni les chemins. La chaine va dans un
## seul sens — chemins -> massifs -> champ — et elle ne revient pas.
##
## C'est du chemin **froid** : la relaxation d'une zone, une fois. Six passes sur
## une vingtaine de jalons, deux candidats chacun, soit quelques centaines de
## consultations par arete.
static func _masse(field: CWTerrainField, x: int, z: int) -> float:
	var e: int = 0
	for m in field.mesas().mesas_at(x, z, field):
		e = maxi(e, m.thickness(x, z))
	return float(e)


## Epaisseur de massif **moyenne le long des deux segments adjacents** a un
## jalon. C'est ce que voit la fonction de cout — voir `MESA_PROBE` pour la
## raison, qui est la seule chose interessante de cette fonction.
static func _masse_arc(field: CWTerrainField, x: float, z: float,
		x0: float, z0: float, x1: float, z1: float) -> float:
	var somme: float = 0.0
	var n: int = 0
	# La fenetre de massifs est prise **une fois par cellule traversee**, pas une
	# fois par sondage : deux sondages distants de 32 blocs tombent presque
	# toujours dans la meme cellule de 512, et `mesas_at` alloue un tableau de
	# neuf cellules a chaque appel sous verrou. Meme economie que celle du
	# generateur sur la meme fenetre, et elle vaut cher ici — la relaxation
	# evalue quelques centaines de candidats par arete.
	var last_cx: int = 0x7FFFFFFF
	var last_cz: int = 0x7FFFFFFF
	var win: Array[CWMesa] = []
	for bout in 2:
		var bx: float = x0 if bout == 0 else x1
		var bz: float = z0 if bout == 0 else z1
		var d: float = Vector2(bx - x, bz - z).length()
		@warning_ignore("integer_division")
		var pas: int = maxi(1, int(d) / MESA_PROBE)
		for k in range(1, pas + 1):
			var t: float = float(k) / float(pas)
			var qx: int = int(lerpf(x, bx, t))
			var qz: int = int(lerpf(z, bz, t))
			var ccx: int = CWMesaGrid.cell_of(qx)
			var ccz: int = CWMesaGrid.cell_of(qz)
			if ccx != last_cx or ccz != last_cz:
				win = field.mesas().get_window(ccx, ccz, field)
				last_cx = ccx
				last_cz = ccz
			var e: int = 0
			for m in win:
				e = maxi(e, m.thickness(qx, qz))
			somme += float(e)
			n += 1
	return somme / float(maxi(1, n))


static func _cout(h0: float, h: float, h1: float, x: float, z: float,
		x0: float, z0: float, x1: float, z1: float, mass: float) -> float:
	var montee: float = absf(h - h0) + absf(h1 - h)
	var l: float = Vector2(x - x0, z - z0).length() \
			+ Vector2(x1 - x, z1 - z).length()
	return montee + l * LENGTH_WEIGHT * 0.02 + mass * MESA_WEIGHT


## Range un trace dans la zone : ses segments, et les cellules d'index qu'ils
## touchent — emprise elargie de la portee du chemin, sans quoi une colonne
## d'accotement au bord d'une cellule ne trouverait pas son segment.
static func _ajoute(zone: Zone, trace: PackedFloat32Array) -> void:
	var n: int = trace.size() / 3 - 1
	for i in n:
		var si: int = zone.segments.size() / 6
		var ax: float = trace[i * 3]
		var az: float = trace[i * 3 + 1]
		var bx: float = trace[(i + 1) * 3]
		var bz: float = trace[(i + 1) * 3 + 1]
		zone.segments.append(ax)
		zone.segments.append(az)
		zone.segments.append(trace[i * 3 + 2])
		zone.segments.append(bx)
		zone.segments.append(bz)
		zone.segments.append(trace[(i + 1) * 3 + 2])

		var m: float = reach() + 1.0
		var cx0: int = int(minf(ax, bx) - m) >> INDEX_SHIFT
		var cx1: int = int(maxf(ax, bx) + m) >> INDEX_SHIFT
		var cz0: int = int(minf(az, bz) - m) >> INDEX_SHIFT
		var cz1: int = int(maxf(az, bz) + m) >> INDEX_SHIFT
		for cx in range(cx0, cx1 + 1):
			for cz in range(cz0, cz1 + 1):
				var key: int = cx * 65536 + cz
				var lst: PackedInt32Array = zone.index.get(key,
						PackedInt32Array())
				lst.append(si)
				zone.index[key] = lst
