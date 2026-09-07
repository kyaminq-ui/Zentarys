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
	if temperature < SNOW_T:
		return SNOWLANDS
	if temperature >= LAVA_T and humidity < HUMID_H:
		return LAVALANDS
	if temperature >= JUNGLE_T and humidity >= HUMID_H:
		return JUNGLES
	if temperature >= DESERT_T and humidity < HUMID_H:
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

## Amplitude **maximale** du brouillage, en unites de climat. Comparees aux
## seuils : a 0,07 sur la temperature, la frange fait environ un dixieme de la
## largeur d'une bande climatique.
##
## C'est un plafond, pas la valeur employee : voir `fringe_amplitude`.
const DITHER_T: float = 0.07
const DITHER_H: float = 0.09

## -- La frange se borne en blocs, pas en unites de climat ---------------------
##
## Une amplitude en unites de climat ne dit rien de la largeur de la frange **en
## blocs** : celle-ci vaut l'amplitude divisee par la pente locale du champ de
## climat, et cette pente n'est pas la meme partout. La ou le climat varie
## lentement, 0,07 unite represente des centaines de blocs, et l'herbe traverse
## tout le desert. La ou il est **plat** — au centre d'une region, ou le melange
## de sites ne retient plus qu'un seul site —, elle represente une distance
## infinie : le brouillage ne deplace plus une frontiere, il tire a pile ou face
## sur chaque colonne d'un pays entier. C'est ce qui mettait du sable au milieu
## des Lava Lands, dont le seuil `LAVA_T` ne se rencontre justement qu'au coeur
## d'une region.
##
## D'ou la regle : **l'amplitude est celle qui rend une frange de `FRINGE_BLOCKS`
## blocs, plafonnee par `DITHER_*`.** La ou le climat est plat, elle tombe a
## zero d'elle-meme — la ou il n'y a pas de frontiere, il n'y a pas de frange.
##
## Le gradient vient de `CWTerrainField.climate_gradient`, memoise par cellule
## de 512 : c'est une grandeur d'echelle regionale, elle ne change pas d'une
## colonne a la suivante.

## Largeur visee de l'ecotone, en blocs. C'est le nombre que la note de
## `at_dithered` annoncait — « une trentaine de blocs » — et qui n'etait vrai
## que la ou la pente du climat valait par hasard ce qu'il fallait.
const FRINGE_BLOCKS: float = 32.0


## L'amplitude de brouillage a employer, connaissant le gradient local du champ
## de climat (`CWTerrainField.climate_gradient`, en unites par bloc).
static func fringe_amplitude(gradient: Vector2) -> Vector2:
	return Vector2(
			minf(DITHER_T, gradient.x * FRINGE_BLOCKS),
			minf(DITHER_H, gradient.y * FRINGE_BLOCKS))

## Les deux frequences du tramage. Plus lentes que celles de `CWPalette` : une
## frange de biome se compte en dizaines de blocs, pas en unites — a la maille
## du bloc, elle se lirait comme du bruit et non comme une frontiere.
const DITHER_FREQ_FINE: float = 0.10
const DITHER_FREQ_LARGE: float = 0.02
const DITHER_WEIGHT_LARGE: float = 0.55
const DITHER_OFFSET_X: float = 30011.0
const DITHER_OFFSET_Z: float = 61403.0


## Le biome qui decide de la **matiere du sol** : meme regle que `at`, seuils
## trames. Voir les deux notes ci-dessus.
##
## `amplitude` est ce que rend `fringe_amplitude` : l'amplitude bornee en blocs,
## et non les constantes `DITHER_*`. Un appelant qui passerait celles-ci
## retrouverait le defaut du 2026-09-08.
static func at_dithered(height: float, temperature: float, humidity: float,
		sea_level: int, x: int, z: int, amplitude: Vector2) -> int:
	if not _near_edge(temperature, humidity, amplitude):
		return at(height, temperature, humidity, sea_level)
	# Deux champs decorreles pour le prix d'un jeu de constantes : le second lit
	# le meme bruit avec les coordonnees echangees et decalees, ce qui suffit a
	# rendre les deux independants sans introduire une seconde graine a tenir.
	var nt: float = _blotch(x, z)
	var nh: float = _blotch(z + 7919, x + 3271)
	return at(height, temperature + nt * amplitude.x,
			humidity + nh * amplitude.y, sea_level)


## Vrai si le climat de la colonne est assez pres d'un seuil pour que le
## brouillage puisse changer sa reponse.
##
## La comparaison se fait contre l'amplitude **effective**, donc la bande se
## resserre exactement comme la frange : sur un climat plat, `amplitude` est
## nulle, aucun seuil n'est « proche », et la fonction sort sans echantillonner
## un seul bruit. La sortie rapide devient ainsi le cas general et non plus
## seulement le cas lointain.
static func _near_edge(t: float, h: float, amplitude: Vector2) -> bool:
	if amplitude.x > 0.0 and (absf(t - SNOW_T) < amplitude.x
			or absf(t - JUNGLE_T) < amplitude.x
			or absf(t - DESERT_T) < amplitude.x
			or absf(t - LAVA_T) < amplitude.x):
		return true
	if amplitude.y <= 0.0:
		return false
	return absf(h - HUMID_H) < amplitude.y


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
