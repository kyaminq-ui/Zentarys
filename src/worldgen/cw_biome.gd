class_name CWBiome
extends RefCounted

## Les six biomes du monde, et la regle qui les decide (jalon 1.12).
##
## -- Pourquoi une couche a part, et non les surfaces -------------------------
##
## Jusqu'au 2026-09-06, « biome » voulait dire `CWPalette.surface_index` : neuf
## *matieres de bloc* qui servaient aussi de cle aux tables de flore, d'arbres
## et de densite. Les deux notions y etaient confondues, et ca se voyait des
## qu'on essayait de dire une phrase simple :
##
##   * une crete rocheuse au-dessus d'une prairie n'est pas un « biome roche » :
##     c'est une prairie, vue en altitude ;
##   * une ile au milieu de l'ocean porte la vegetation de la terre ferme, mais
##     l'ancienne table rangeait « gravier » et « sable » comme deux biomes ;
##   * une plage n'est pas un desert, alors qu'elle rendait le meme index.
##
## D'ou la separation : **un biome est une zone climatique**, il y en a six, et
## il decide *ce qui pousse*. La **matiere de surface** — herbe, sable, neige,
## roche, magma — est une consequence du biome et de l'altitude, et elle decide
## *ce qu'on voit et ce qu'on creuse*. `CWPalette.surface_of` fait la seconde
## moitie ; ce fichier fait la premiere.
##
## -- La liste, et d'ou elle vient ---------------------------------------------
##
## Les six sont ceux de l'alpha 2013 : Greenlands, Snowlands, Deserts, Jungles,
## Lava Lands, Oceans. Ce sont des noms du jeu d'origine, gardes tels quels
## parce qu'ils nomment une *classification*, pas un asset : le contenu de
## chacun est une creation de ce projet (`README.md`, perimetre).
##
## -- La conversion climat -> degres ------------------------------------------
##
## Le champ de climat de `CWTerrainField` rend deux flottants dans [0, 1], sans
## unite. Les fourchettes connues des biomes d'origine, elles, sont en degres et
## en pourcents. La conversion retenue est **lineaire, et c'est une convention
## de ce projet** — rien dans le binaire ne donne l'echelle :
##
##     celsius = TEMP_MIN_C + t * (TEMP_MAX_C - TEMP_MIN_C)
##     humidite en % = h * 100
##
## Elle n'existe que pour que les seuils ci-dessous se lisent dans l'unite ou
## ils ont ete releves, et pour l'affichage de l'ATH. Le code de generation ne
## voit que les seuils normalises.
const TEMP_MIN_C: float = -30.0
const TEMP_MAX_C: float = 50.0

const GREENLANDS: int = 0
const SNOWLANDS: int = 1
const DESERTS: int = 2
const JUNGLES: int = 3
const LAVALANDS: int = 4
const OCEANS: int = 5
const COUNT: int = 6

# -- Les seuils ---------------------------------------------------------------
#
# Ils partitionnent le carre (temperature, humidite) en cinq morceaux ; le
# sixieme, l'ocean, se decide sur l'altitude et passe avant tout.
#
# Chaque valeur porte en commentaire la fourchette d'origine qu'elle traduit.
# Les parts de monde qui en sortent sont *mesurees*, pas supposees :
# `tools/biome_stats.gd` balaie le champ de climat sur des zones eloignees et
# rend la repartition. Deplacer un seuil sans relancer cet outil, c'est deplacer
# la composition du monde a l'aveugle.

## -- Six parts egales, et ce que ca a coute aux fourchettes d'origine --------
##
## Les seuils ci-dessous ne traduisent plus des degres. Ils ont ete **resolus**
## le 2026-09-11 par `tools/biome_balance.gd` pour que les six biomes fassent
## chacun **un sixieme du monde**, ocean compris — c'est la demande, et elle a
## un prix qu'il faut dire :
##
## * **Lava Lands cesse d'etre rare.** L'alpha le donne « 30 - 40 °C, rare, loin
##   du spawn », et la regle d'avant en faisait le coeur des regions les plus
##   chaudes : 1,5 % des terres. A parts egales, c'en est 20 %. Ce n'est plus un
##   accident du monde, c'est un pays ;
## * **les degres ne se lisent plus.** `TEMP_MIN_C` / `TEMP_MAX_C` restent la
##   convention d'affichage de l'ATH, mais un desert commence maintenant a 2 °C
##   et une Lava Lands a 20 °C. Ce sont des **quantiles d'un champ**, pas des
##   temperatures : le champ de climat de ce projet n'a aucune raison de remplir
##   les fourchettes d'origine dans leurs proportions, et le fichier le disait
##   deja avant qu'on choisisse l'egalite.
##
## **Ils sont la moyenne de cinq graines** (1337, 2024, 7, 99, 4242), et l'ecart
## entre graines est faible pour le climat — SNOW_T va de 0,198 a 0,312, les
## quatre autres tiennent dans trois centiemes. Le **niveau de la mer**, lui,
## n'est pas stable de cette facon : voir `CWWorldParams.sea_level`.
##
## Les parts qui en sortent sont *mesurees*, pas supposees :
## `tools/biome_stats.gd` balaie le champ de climat sur des zones eloignees et
## rend la repartition, `tools/biome_balance.gd` resout les seuils qui
## l'egalisent. Deplacer un seuil sans relancer l'un des deux, c'est deplacer la
## composition du monde a l'aveugle.

## Snowlands : le froid, des deux cotes de la frontiere d'humidite. C'est le
## premier test apres l'ocean, donc son seuil ne depend d'aucun autre.
const SNOW_T: float = 0.28

## **La frontiere sec/humide, et il n'y en a qu'une.**
##
## -- Ce qui a change le 2026-09-11, et pourquoi c'etait structurel -----------
##
## Il y en avait deux : `JUNGLE_H` a 0,62 et `DESERT_H` a 0,34. Le desert etait
## donc **plus sec que Lava Lands**, qui prenait toute la moitie seche au-dessus
## de son seuil ; il ne restait au desert que le sec *froid*, que ce champ ne
## produit presque pas. Le solveur l'a montre sans equivoque : `DESERT_T` est
## descendu jusqu'a zero en ne rendant que 3 % du monde. **Ce n'etait pas un
## seuil mal place, c'etait la forme de la regle.**
##
## Le monde se partage maintenant en **sec et humide**, une seule fois, et la
## temperature fait tout le reste : Snowlands au froid, Deserts puis Lava Lands
## se partagent le sec par temperature croissante, Jungles prend le chaud
## humide, Greenlands garde le tempere des deux versants.
##
## C'est aussi ce que la mesure du champ disait depuis le debut, et qui est
## reste ecrit plus bas : *un point chaud est soit tres sec, soit tres humide,
## jamais entre les deux.* Une seule frontiere suffit a un champ bimodal ; deux
## en faisaient une de trop.
##
## La valeur, elle, decide **de quel cote Greenlands est preleve** — pas
## l'egalite, qui tombe juste des que le sec porte deux parts et l'humide une.
## Elle est posee la ou le tempere se partage moitie-moitie entre les deux
## versants.
const HUMID_H: float = 0.65

## Deserts : le sec tempere a chaud. En dessous de Lava Lands, au-dessus de la
## prairie.
const DESERT_T: float = 0.40

## Jungles : le chaud humide. Sa temperature est plus basse que celle du desert
## d'origine, et c'est normal — les deux ne sont plus separes par la meme
## grandeur : le desert et la jungle sont chacun le haut de **leur** versant.
const JUNGLE_T: float = 0.47

## Lava Lands : le haut du versant sec.
##
## -- Deux essais rates avant celui-la, et ce qu'ils ont appris ----------------
## La premiere regle prenait la bande d'humidite laissee libre entre le desert
## et la jungle aux hautes temperatures. Elle rendait **60 colonnes sur
## 147 456**, soit 0,04 % des terres. `tools/biome_stats.gd` en a donne la
## raison, et elle vaut pour tout le reste du fichier : **le champ de climat de
## ce projet est bimodal**, pas uniforme. Son tableau croise, mesure sur
## 144 zones :
##
##       t / h     0-20 %   20-40   40-60   60-80  80-100
##     0,0 - 0,2    10,68    0,05    0,04    0,03   14,00
##     0,2 - 0,4     0,01    0,06    8,03    6,52    1,35
##     0,4 - 0,6     0,00    0,02    8,74   11,87    1,05
##     0,6 - 0,8     0,01    0,05    5,55    8,39    0,08
##     0,8 - 1,0    11,52    0,04    0,04    0,04   11,81
##
## Les quatre coins portent 48 % des terres et le centre le reste ; **un point
## chaud est soit tres sec, soit tres humide**, jamais entre les deux. Baisser
## le seuil de temperature de 0,88 a 0,80 n'a donc rien change du tout : 60
## colonnes sont devenues 64. Une regle peut etre juste et vide.
##
## Ce qui marche est de decouper dans le coin chaud-sec, tout en haut : le
## melange climatique fait qu'une temperature au-dessus de 0,97 n'existe qu'au
## **centre d'une region dont le site est a l'extreme**. Lava Lands est donc un
## coeur de region, entoure de son propre desert — ce qui est exactement la
## forme voulue, et ce qu'un tirage par colonne n'aurait pas donne.
##
## « Loin du spawn » suit sans qu'on ait a le demander : le point de depart du
## monde est au centre de la carte, ou le climat est median. Le jour ou un
## spawn variable existera, c'est ici qu'une distance viendrait s'ajouter — et
## elle demanderait de passer (x, z) a `at`, ce que la regle evite aujourd'hui.
const LAVA_T: float = 0.63

## Altitude sous le niveau de la mer a partir de laquelle une colonne est de
## l'ocean. Le meme -1 que l'ancienne regle de surface : au-dessus, c'est une
## plage ou une ile, et l'ile porte la vegetation de son climat.
const OCEAN_DEPTH: float = -1.0


## Le biome d'une colonne.
##
## `height` est l'altitude en blocs, `temperature` et `humidity` les deux
## champs normalises de `CWTerrainField`, `sea_level` le niveau de la mer.
##
## Fonction pure, appelee une fois par colonne sur le chemin de generation :
## pas d'echantillonnage de bruit ici, seulement des comparaisons. C'est
## delibere — voir `LAVA_T` pour la seule regle qui aurait pu en demander un.
static func at(height: float, temperature: float, humidity: float,
		sea_level: int) -> int:
	if height - float(sea_level) < OCEAN_DEPTH:
		return OCEANS
	return of_climate(temperature, humidity)


## **Les cinq biomes de climat, sans la regle d'ocean.** Point unique de la
## partition du carre (temperature, humidite) : `at` l'appelle apres avoir
## tranche l'ocean sur l'altitude, et la carte l'appelle directement — elle
## decide l'ocean autrement, sur le drapeau du site et non sur une colonne.
##
## Les deux ecritures existaient en une seule jusqu'au 2026-09-12, et la carte
## devait alors passer une altitude bidon pour obtenir la moitie qui
## l'interessait. Une altitude bidon dans un appel est ce qui finit par etre
## lue pour de vrai.
static func of_climate(temperature: float, humidity: float) -> int:
	if temperature < SNOW_T:
		return SNOWLANDS
	if temperature >= LAVA_T and humidity < HUMID_H:
		return LAVALANDS
	if temperature >= JUNGLE_T and humidity >= HUMID_H:
		return JUNGLES
	if temperature >= DESERT_T and humidity < HUMID_H:
		return DESERTS
	return GREENLANDS


## Le biome d'une colonne, connaissant le **site de region** dont elle releve.
##
## -- Pourquoi le site, et non le climat de la colonne ------------------------
##
## `at` est une fonction pure d'un climat, et le climat d'une colonne etait
## jusqu'au 2026-09-12 un **melange** des sites voisins. Ce melange a une forme
## tres particuliere, mesuree et ecrite dans `CWTerrainField` : c'est un
## **plateau parfaitement plat** au coeur de chaque region — le melange n'y
## retient qu'un site —, coupe de transitions **etroites**, larges de deux cents
## blocs a peine.
##
## Un biome faisait donc deja la taille d'une region sur l'immense majorite du
## monde. Ce qui n'allait pas etait le bord : deux cents blocs pour passer d'un
## climat a l'autre, et jusqu'a **quatre seuils traverses** en chemin. Entre une
## region froide et une region chaude, on rencontrait une Snowlands, puis
## quarante blocs de Greenlands, puis quarante de Deserts, puis une Lava Lands —
## quatre pays en deux cents pas. C'est la demande du 2026-09-11 au soir : *un
## biome doit faire une taille minimum, pour eviter des transitions trop
## rapides.*
##
## **La seule route qui garantisse est de classer au site.** Un biome devient
## alors une cellule du diagramme de Voronoi des sites — 16 384 unites de cote
## par construction, et il n'y a plus rien a regler pour que ce soit vrai. Les
## bandes intermediaires ne se resserrent pas : elles n'existent plus.
##
## **Ce que ca ne casse pas, et il fallait le verifier.** Le voisinage reste
## credible parce que ce qui l'assurait n'etait pas le melange mais les
## **provinces climatiques** de `CWRegionSiteGrid`, qui adoucissent un climat
## extreme vers le tempere au bord de sa province : deux coeurs opposes ne
## peuvent pas se toucher, il y a une region tempere entre eux. Cette regle est
## au niveau du site, donc elle survit telle quelle. `tools/biome_stats.gd`
## compte les paires « neige contre desert ou lave » ; c'est le garde-fou.
##
## **Ce que ca coute.** Le climat *melange* ne decide plus rien. Il reste rendu
## par `CWTerrainField.climate_blend`, elargi le meme jour, pour l'ATH et pour
## les outils : c'est une lecture d'instrument, plus une regle.
static func of_site(site: CWRegionSite, height: float, sea_level: int) -> int:
	if site == null:
		# Uniquement au bord du monde, ou la fenetre de sites est vide.
		return OCEANS if height - float(sea_level) < OCEAN_DEPTH else GREENLANDS
	return at(height, site.temperature, site.humidity, sea_level)


# -- La frontiere entre deux biomes, tramee -----------------------------------
#
# Classer au site donne une frontiere de Voronoi, c'est-a-dire **un trait** : le
# sol change de matiere d'une colonne a la suivante, sur une droite. C'est le
# meme defaut que le haut de plage et la roche de pente avant le 2026-09-07, et
# c'est celui qui se voit le plus — un desert qui rencontre une prairie est la
# plus grande frontiere de matiere du monde.
#
# **On brouille donc le point, et non plus le climat.** La matiere du sol prend
# le biome du site le plus proche d'un point **deplace d'une trentaine de blocs
# par un bruit**, la ou le biome nomme prend celui du point vrai. La frontiere
# devient une bande ou les deux matieres s'interpenetrent — un ecotone —, et
# elle suit les memes plaques que les autres transitions du projet.
#
# -- Pourquoi c'est plus simple que ce que ca remplace ------------------------
#
# Le brouillage precedent portait sur le **climat**, et il avait un defaut de
# fond : une amplitude en unites de climat ne dit rien de la largeur de la
# frange **en blocs**, celle-ci valant l'amplitude divisee par la pente locale
# du champ. Sur un plateau — la moitie du monde — la pente est nulle, et un
# brouillage y tirait a pile ou face sur chaque colonne d'un pays entier. Il a
# fallu mesurer le gradient du champ de climat, le memoiser par cellule de 16,
# en deduire une amplitude bornee, et sortir tot la ou elle tombait a zero :
# trois mecanismes, tous retires le 2026-09-12.
#
# **Un deplacement se compte en blocs par construction.** Il n'a ni pente a
# diviser, ni plateau a redouter : sur un plateau, deplacer le point de trente
# blocs ne change pas de site, donc ne change rien, et c'est vrai sans qu'on ait
# rien a tester. La regle est devenue ce qu'elle aurait du etre depuis le
# debut — *une frontiere dans l'espace se brouille dans l'espace*.
#
# La mise en oeuvre est dans `CWTerrainField.fringe_point` : c'est la que vit la
# deformation du domaine, et l'ecotone en est une seconde, plus fine.

## Nom lisible, pour l'ATH, la carte et les outils.
static func name_of(biome: int) -> String:
	match biome:
		GREENLANDS: return "Greenlands"
		SNOWLANDS: return "Snowlands"
		DESERTS: return "Deserts"
		JUNGLES: return "Jungles"
		LAVALANDS: return "Lava Lands"
		OCEANS: return "Oceans"
		_: return "biome %d" % biome


## Nom de dossier d'assets. C'est la meme chaine que le nom, en minuscules et
## sans espace : `assets/models/flore/greenlands/`, `.../lavalands/`.
static func dir_of(biome: int) -> String:
	match biome:
		GREENLANDS: return "greenlands"
		SNOWLANDS: return "snowlands"
		DESERTS: return "deserts"
		JUNGLES: return "jungles"
		LAVALANDS: return "lavalands"
		OCEANS: return "oceans"
		_: return ""


## Les six, dans l'ordre des index. Pour les boucles d'outils et de tests.
static func all() -> PackedInt32Array:
	return PackedInt32Array([GREENLANDS, SNOWLANDS, DESERTS, JUNGLES,
			LAVALANDS, OCEANS])


## Temperature normalisee en degres Celsius. Affichage seul — voir l'en-tete.
static func celsius(temperature: float) -> float:
	return TEMP_MIN_C + temperature * (TEMP_MAX_C - TEMP_MIN_C)
