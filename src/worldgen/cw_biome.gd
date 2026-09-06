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

## Snowlands : « < -20 °C ». -20 °C tombe a 0,125 ; le seuil est monte a 0,22
## pour que la toundra — la frange de Snowlands, et non un biome a elle — ait
## de la place. En dessous, le monde n'avait presque pas de froid.
const SNOW_T: float = 0.16

## Deserts : « 34 - 39 °C, humidite 2 - 7 % ». 34 °C tombe a 0,80. Le seuil
## d'humidite est plus large que les 7 % releves : a 0,07 le desert n'existait
## qu'en quelques taches, le champ d'humidite ne descendant presque jamais si
## bas. C'est la premiere fourchette a resserrer si les deserts prennent trop
## de place.
const DESERT_T: float = 0.70
const DESERT_H: float = 0.34

## Jungles : « ~35 °C, humidite ~90 % ». La temperature est celle du desert a
## un cheveu pres — ce sont bien **deux biomes chauds separes par l'humidite**,
## et c'est ce qui fait que l'humidite decide avant la temperature ici.
const JUNGLE_T: float = 0.56
const JUNGLE_H: float = 0.62

## Lava Lands : « 30 - 40 °C, rare, loin du spawn ». C'est le **coeur des
## regions les plus chaudes**, decoupe du cote sec : au-dessus de ce seuil et
## sous l'humidite de jungle.
##
## -- Deux essais rates avant celui-la, et ce qu'ils ont appris ----------------
##
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
const LAVA_T: float = 0.985

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
	if temperature < SNOW_T:
		return SNOWLANDS
	if temperature >= LAVA_T and humidity < JUNGLE_H:
		return LAVALANDS
	if temperature >= JUNGLE_T and humidity >= JUNGLE_H:
		return JUNGLES
	if temperature >= DESERT_T and humidity < DESERT_H:
		return DESERTS
	return GREENLANDS


# -- La frontiere entre deux biomes, tramee -----------------------------------
#
# `at` compare un climat continu a des seuils : sa frontiere est donc une
# **courbe de niveau du champ de climat**, et le sol y change de couleur sur un
# trait. C'est le meme defaut que le haut de plage et la roche de pente avant le
# 2026-09-07, et c'est celui qui se voit le plus : un desert qui rencontre une
# prairie est la plus grande frontiere de matiere du monde.
#
# On brouille donc le climat d'un bruit **avant** de le comparer aux seuils. La
# frontiere devient une bande d'une trentaine de blocs ou les deux matieres
# s'interpenetrent — un ecotone —, et elle suit les memes plaques que les autres
# transitions du projet.
#
# **Deux precautions.**
#
#   * *le biome tramé ne sert qu'a la matiere du sol.* Le biome **nommé** — celui
#     qui choisit ce qui pousse, ce qui apparait, ce que l'ATH affiche et ce que
#     la carte teinte — reste celui de `at`, sans quoi une prairie ferait pousser
#     un cactus tous les vingt blocs le long de son desert. En frange, une touffe
#     d'herbe se tient donc sur une plaque de sable : c'est exactement ce qu'on
#     voit au bord d'un desert ;
#   * *la sortie rapide n'est pas une optimisation cosmetique.* Loin de toute
#     frontiere — la quasi-totalite du monde — le tramage ne peut rien changer,
#     et la fonction sort avant d'echantillonner quoi que ce soit. Sans elle, ce
#     seraient quatre bruits par colonne sur tout le monde.

## Amplitude du brouillage, en unites de climat. Comparees aux seuils : a 0,05
## sur la temperature, la frange fait environ un dixieme de la largeur d'une
## bande climatique.
const DITHER_T: float = 0.07
const DITHER_H: float = 0.09

## Les deux frequences du tramage. Plus lentes que celles de `CWPalette` : une
## frange de biome se compte en dizaines de blocs, pas en unites — a la maille
## du bloc, elle se lirait comme du bruit et non comme une frontiere.
const DITHER_FREQ_FINE: float = 0.10
const DITHER_FREQ_LARGE: float = 0.02
const DITHER_WEIGHT_LARGE: float = 0.55
const DITHER_OFFSET_X: float = 30011.0
const DITHER_OFFSET_Z: float = 61403.0


## Le biome qui decide de la **matiere du sol** : meme regle que `at`, seuils
## trames. Voir la note ci-dessus.
static func at_dithered(height: float, temperature: float, humidity: float,
		sea_level: int, x: int, z: int) -> int:
	if not _near_edge(temperature, humidity):
		return at(height, temperature, humidity, sea_level)
	# Deux champs decorreles pour le prix d'un jeu de constantes : le second lit
	# le meme bruit avec les coordonnees echangees et decalees, ce qui suffit a
	# rendre les deux independants sans introduire une seconde graine a tenir.
	var nt: float = _blotch(x, z)
	var nh: float = _blotch(z + 7919, x + 3271)
	return at(height, temperature + nt * DITHER_T,
			humidity + nh * DITHER_H, sea_level)


## Vrai si le climat de la colonne est assez pres d'un seuil pour que le
## brouillage puisse changer sa reponse.
static func _near_edge(t: float, h: float) -> bool:
	if absf(t - SNOW_T) < DITHER_T or absf(t - JUNGLE_T) < DITHER_T \
			or absf(t - DESERT_T) < DITHER_T or absf(t - LAVA_T) < DITHER_T:
		return true
	return absf(h - JUNGLE_H) < DITHER_H or absf(h - DESERT_H) < DITHER_H


## Bruit a deux frequences, dans [-1, 1]. Meme construction que
## `CWPalette.blend_threshold` — c'est la seconde frequence qui fait les
## plaques — a une echelle trois fois plus grande.
static func _blotch(x: int, z: int) -> float:
	var fine: float = CWValueNoise.sample(
			float(x) * DITHER_FREQ_FINE + DITHER_OFFSET_X,
			float(z) * DITHER_FREQ_FINE + DITHER_OFFSET_Z)
	var large: float = CWValueNoise.sample(
			float(x) * DITHER_FREQ_LARGE + DITHER_OFFSET_Z,
			float(z) * DITHER_FREQ_LARGE + DITHER_OFFSET_X)
	return clampf(fine * (1.0 - DITHER_WEIGHT_LARGE)
			+ large * DITHER_WEIGHT_LARGE, -1.0, 1.0)


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
