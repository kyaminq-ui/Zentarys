class_name CWPalette
extends RefCounted

## Palette de blocs et regles de surface.
##
## IMPORTANT - perimetre juridique : la palette de couleurs de Cube World fait
## partie de son expression artistique, pas de ses algorithmes. Aucune couleur
## n'est extraite du jeu d'origine. Les teintes ci-dessous sont choisies ici,
## librement, pour lire correctement en cubes colores. Seule la *regle* de
## selection (surface pilotee par temperature et humidite melangees depuis les
## sites de region) provient de l'analyse du systeme.
##
## -- Deux canaux, comme dans l'original ---------------------------------------
## Depuis le 2026-09-05, un voxel porte **deux** valeurs, et c'est la disposition
## du binaire d'origine : un bloc y fait quatre octets, trois de couleur et un
## d'attributs dont cinq bits de type (`docs/systems/03`, §3).
##
##   * `CHANNEL_TYPE`  (8 bits)  : l'**index de palette**, 0 = air. C'est la
##     valeur *semantique* — ce que le jeu sait du bloc. Tout le code qui
##     raisonne en blocs (surfaces, flore, edition, collisions) lit celle-la ;
##   * `CHANNEL_COLOR` (32 bits) : la **couleur rendue**, RGBA8888. C'est ce que
##     `VoxelMesherCubes` lit en mode `COLOR_RAW`, et rien d'autre ne s'en sert.
##
## Pourquoi ce dedoublement, alors qu'un index suffisait jusqu'ici : le mailleur
## n'a pas de canal de lumiere, et en mode palette il cuit la couleur du
## nuancier dans les sommets. Une luminosite par voxel n'a donc nulle part ou
## aller tant que la couleur est un index partage. C'est le verrou identifie en
## `docs/systems/04`, §6, et l'original le contourne de la meme facon : il stocke
## la couleur par bloc.
##
## **La palette ne disparait pas** : elle reste la source des couleurs et le
## contrat d'authoring des modeles `.vox`. Ce qui change est l'encodage du canal
## de rendu, pas le nuancier — aucun asset n'est a repeindre.

const AIR: int = 0
const STONE: int = 1
const DIRT: int = 2
const GRASS: int = 3
## Le bois d'un tronc ecrit dans le terrain. Voir la note ci-dessous.
const WOOD: int = 4
const GRASS_JUNGLE: int = 5
const SAND: int = 6
const SNOW: int = 7
const ICE: int = 8
## Retire le 2026-09-06 : `surface_of` ne le rend plus. Voir la note ci-dessous.
const TUNDRA: int = 9
const SWAMP: int = 10
const GRAVEL: int = 11
const WATER: int = 12
const WATER_DEEP: int = 13
const COUNT: int = 14

# -- Une entree recyclee : 4, d'herbe seche a bois (jalon 1.11) ---------------
#
# Le tronc d'un feuillu et le stipe d'un palmier sont **ecrits dans le terrain**
# depuis le 2026-09-06 : on doit pouvoir les creuser, et ils porteront la
# collision. Chacun de leurs voxels est donc un *type de bloc*, ce qui demande
# une entree dans la plage que le generateur ecrit — 0-13.
#
# L'entree prise est le **4**, laisse libre le matin meme par le retrait de
# `GRASS_DRY` : son index restait alloue pour ne pas decaler la reserve peinte
# dans les .vox, et aucun modele ne l'employait. Il change donc de statut sans
# qu'une frontiere bouge et sans qu'un fichier soit a repeindre — exactement le
# geste de MAGMA et SCORIA sur 30 et 31, et exactement ce qui evite de repayer
# l'operation de l'invariant n° 31.
#
# **Sa couleur est celle de l'ecorce**, et elle ne sert qu'a `place()` : un tronc
# estampe ecrit son type ici et sa **teinte de modele** dans `CHANNEL_COLOR`,
# donc les quatre nuances d'ecorce du lot survivent au passage dans le terrain.
# C'est le partage pose au jalon 1.9, et c'est lui qui rend l'operation gratuite.
#
# -- Une entree retiree, et pourquoi elle garde sa place ----------------------
#
# `TUNDRA` (9) etait l'autre frange seche heritee du
# systeme d'avant le jalon 1.12 : une prairie sous 0,46 d'humidite virait au
# kaki, une Snowlands sous 0,50 au gris-olive. Depuis que `CWBiome` classe le
# climat, une seconde matiere de plaine par biome ne dit rien de plus que le
# biome — et en jeu elle disait le contraire de lui. `surface_of` ne les rend
# plus (2026-09-06).
#
# **Son index reste alloue, et ce n'est pas de la negligence.** Les entrees 1 a
# 13 sont contigues et la reserve de matiere des modeles commence a 14 : liberer
# le 9 decalerait tout ce qui suit, donc les plages 14-19 (roche nue),
# 20-24 (gres), 25-27 (basalte) — qui sont **peintes dans les 66 fichiers .vox
# du depot**. Le geste coute un repassage complet par `tools/repaint_models.gd`
# pour economiser deux entrees sur 256. C'est exactement l'arbitrage de
# l'invariant n° 31, et il se tranche dans le meme sens. Aucun modele n'employait
# ces deux index — verifie avant de les retirer, pas apres. Le 4 a servi le
# soir meme, ce qui est l'argument le plus court en faveur de cette prudence.

# -- Lava Lands : deux types de bloc de plus, sans deplacer une frontiere -----
#
# Le biome volcanique (jalon 1.12) a besoin de matiere que le generateur
# **ecrit** — donc de types de bloc, pas de simples couleurs de modele : on doit
# pouvoir creuser une croute de scorie et reconnaitre une coulee de magma dans
# `CHANNEL_TYPE`.
#
# Les deux entrees prises sont 30 et 31, deja peintes en lave dans la reserve
# terrain 14-31, et **les deux seules de cette reserve qu'aucun modele du depot
# n'employait** (`inspect_model.gd` ne rendait que 14-29). Elles changent donc
# de statut — matiere de modele -> type de bloc — sans qu'une seule couleur
# bouge et sans toucher a `RANGE_TERRAIN_END`.
#
# C'est ce qui evite de repayer l'operation de l'invariant n° 26 : la frontiere
# terrain/creatures reste a 40/41, et le jour ou un modele de creature existera,
# rien ne sera a repeindre.
const MAGMA: int = 30
const SCORIA: int = 31

# -- Filons : neuf types de bloc, 32-40 (jalon 1.11) --------------------------
#
# Un filon n'est pas un decor pose : il **s'estampe dans le terrain**, puisqu'on
# doit pouvoir le miner. Chacun de ses voxels est donc un *type de bloc*, pas
# seulement une couleur, et il lui faut une entree a lui dans la plage terrain.
#
# L'ordre est celui de la source, et il n'est pas arbitraire : les neuf filons y
# occupent les codes d'entite **131 a 139 consecutifs** (`docs/systems/02`,
# §5.2), dans l'ordre exact de la table de rarete de §5.4. On garde ce bloc
# consecutif ici, ce qui donne la correspondance `index = 32 + (code - 131)` —
# verrouillee par un test, parce qu'elle sera le chemin le plus court le jour ou
# la voie des entites sera portee.
const ORE_GOLD: int = 32
const ORE_IRON: int = 33
const ORE_SILVER: int = 34
const ORE_SANDSTONE: int = 35
const ORE_EMERALD: int = 36
const ORE_SAPPHIRE: int = 37
const ORE_RUBY: int = 38
const ORE_DIAMOND: int = 39
const ORE_ICE_CRYSTAL: int = 40

## Premier et dernier filon, et code d'entite du premier. Voir `ore_of_code`.
const ORE_BEGIN: int = ORE_GOLD
const ORE_END: int = ORE_ICE_CRYSTAL
const ORE_CODE_BEGIN: int = 131

# -- Plages reservees de la palette de projet ---------------------------------
#
# VoxelMesherCubes en mode COLOR_MESHER_PALETTE lit un index par voxel, et une
# seule palette sert a tout : terrain et modeles. Les assets doivent donc etre
# peints dans CETTE palette, d'ou le decoupage en plages. Voir
# `assets/palette/PALETTE.md` et le PNG exporte pour MagicaVoxel.
#
# L'index 0 est l'air et ne peut pas servir : le mailleur le traite comme vide.

## Terrain. 0-13 sont ecrits par le generateur ; 14-31 sont de la matiere de
## terrain destinee aux modeles — roche nue, gres, argile, basalte, lave —, et
## 32-40 sont les neuf filons. C'est la seule plage ou un modele trouve du gris :
## la vegetation n'en a aucun.
##
## -- Pourquoi la frontiere a bouge le 2026-09-05 ------------------------------
##
## La reserve 14-31 etait pleine, et les neuf filons avaient besoin de neuf types
## de bloc — ils s'estampent, donc chacun de leurs voxels porte une semantique,
## pas seulement une couleur. `docs/prompt_generation_arbres.md` posait trois
## issues ; aucune n'a ete prise telle quelle, et la raison est mesurable.
##
##   1. **les mettre dans la plage equipement (96-127)** aurait fait porter a un
##      bloc minable un index que la palette declare « armes et equipement ». Le
##      decoupage existe precisement pour qu'un modele peint aujourd'hui reste
##      juste quand les teintes evoluent : ajuster la rampe des gemmes aurait
##      repeint les filons. C'est la panne que le decoupage evite, on ne va pas
##      l'organiser ;
##   2. **deplacer toutes les frontieres** aurait invalide les modeles peints —
##      mais seulement si on les deplace *toutes*. Ce n'etait pas necessaire ;
##   3. **reutiliser des entrees existantes** est impossible depuis 1.9, ou
##      `CHANNEL_TYPE` porte la semantique du bloc.
##
## La sortie prise est la seconde, faite au plus juste : `RANGE_TERRAIN_END`
## passe de 31 a 40 et `RANGE_CREATURES_BEGIN` de 32 a 41. **Aucune autre
## frontiere ne bouge, et aucun modele n'est a repeindre** — verifie plutot que
## suppose : `inspect_model.gd` sur les 53 modeles du depot ne rend que des index
## dans 14-29 et 128-175. La plage creatures perd neuf entrees sur 64 et n'en a
## aucune de peinte, l'apparence des creatures etant hors perimetre
## (`docs/ROADMAP.md`, jalon 2). Elle en garde 55.
const RANGE_TERRAIN_BEGIN: int = 1
const RANGE_TERRAIN_END: int = 40

## Creatures : peaux, fourrures, ecailles, chitine, yeux.
const RANGE_CREATURES_BEGIN: int = 41
const RANGE_CREATURES_END: int = 95

## Armes et equipement : metaux, manches, cuir, gemmes.
const RANGE_GEAR_BEGIN: int = 96
const RANGE_GEAR_END: int = 127

## Vegetation : feuillages, ecorces, fleurs, champignons.
const RANGE_FLORA_BEGIN: int = 128
const RANGE_FLORA_END: int = 175

## Structures : bois de construction, pierre, toitures, tissus, verre.
const RANGE_BUILD_BEGIN: int = 176
const RANGE_BUILD_END: int = 239

## Effets et reperes d'edition.
const RANGE_FX_BEGIN: int = 240
const RANGE_FX_END: int = 255

## Altitude au-dessus du niveau de la mer a partir de laquelle une colonne est
## consideree comme un sommet. Depend du climat : il neige plus bas au froid.
##
## **Ces trois constantes ne servent plus qu'a Lava Lands depuis le 2026-09-06.**
## Elles decidaient les deux bandes d'altitude — roche nue, puis neige de sommet
## — qui traversaient tous les biomes ; ces bandes sont retirees, parce qu'elles
## ne portaient aucun decor et rendaient un plateau nu au sommet de chaque relief
## (voir la note de `surface_of`). Lava Lands s'en sert encore pour separer sa
## croute de scorie de la roche de ses hauteurs, ce qui est une regle de volcan
## et non une regle d'altitude — d'ou le nom local `lava_rock`.
##
## **La falaise a ete portee le 2026-09-06 et retiree le lendemain**, et il faut
## savoir pourquoi avant de la reecrire : la regle de la source est juste, la
## pente etait mesuree et non devinee, les tests passaient — et le rendu en jeu
## ne valait pas la peine. Une paroi grise sur un flanc vert lit comme une
## tache, pas comme une falaise, parce que ce monde n'a pas de parois : son plus
## grand denivele d'un bloc au suivant est de 0,65 bloc, et de la roche posee
## sur un flanc a vingt-sept degres ne ressemble pas a de la roche. Le detail de
## la mesure est en `nextsteps.md`, Sec. 7ter.4 ; ce qu'elle dit est qu'une
## falaise de ce monde devra d'abord etre **taillee dans le relief** avant
## d'etre peinte, et que la peindre seule ne suffit pas.
const SNOW_LINE_BASE: float = 40.0
const SNOW_LINE_SPAN: float = 360.0
## Epaisseur de roche nue juste sous la ligne de neige.
const ROCK_BAND: float = 55.0
## Altitude sous laquelle il n'y a jamais de roche nue, quelle que soit la
## ligne de neige. Sans ce plancher, un biome froid — ou la ligne de neige
## tombe a 80 blocs — se couvrait de roche des la vingtieme marche : une
## Snowlands y etait un anneau de caillou gris entre la plage et la neige.
## Mesure a l'appui : la roche occupait 14,7 % du monde avant ce plancher, et
## la toundra 3 colonnes sur 49 152.
const ROCK_MIN: float = 90.0
## Hauteur de la plage au-dessus du niveau de la mer.
const BEACH_BAND: float = 3.0


static func colors() -> PackedColorArray:
	var c := PackedColorArray()
	c.resize(256)
	c.fill(Color(0, 0, 0, 0))
	c[AIR] = Color(0, 0, 0, 0)
	c[STONE] = Color8(94, 98, 106)
	c[DIRT] = Color8(192, 111, 75)
	c[GRASS] = Color8(44, 143, 77)
	# L'ecorce du lot d'arbres, teinte mediane de la rampe 148-155. Elle ne sert
	# qu'a poser un bloc de bois a la main : un tronc estampe porte la teinte de
	# son propre modele dans `CHANNEL_COLOR`.
	c[WOOD] = Color8(118, 86, 58)
	c[GRASS_JUNGLE] = Color8(58, 132, 60)
	c[SAND] = Color8(253, 185, 82)
	c[SNOW] = Color8(125, 181, 199)
	c[ICE] = Color8(168, 208, 224)
	c[TUNDRA] = Color8(140, 148, 118)
	c[SWAMP] = Color8(84, 110, 74)
	c[GRAVEL] = Color8(150, 144, 132)
	c[WATER] = Color(0.165, 0.784, 0.988, 0.62)
	c[WATER_DEEP] = Color(0.165, 0.784, 0.988, 0.62)
	_fill_asset_ranges(c)
	return c


## Degrade lineaire ecrit dans [start, start + count).
static func _ramp(c: PackedColorArray, start: int, count: int,
		from_color: Color, to_color: Color) -> void:
	for i in count:
		var t: float = 0.0 if count <= 1 else float(i) / float(count - 1)
		c[start + i] = from_color.lerp(to_color, t)


## Teintes de depart des plages reservees aux assets.
##
## Ce ne sont pas des choix definitifs : ce sont des rampes exploitables tout de
## suite dans MagicaVoxel, a ajuster nuance par nuance. Ce qui compte et ne doit
## pas bouger, c'est le decoupage en plages : il garantit qu'un modele peint
## aujourd'hui reste lisible quand la palette evoluera.
static func _fill_asset_ranges(c: PackedColorArray) -> void:
	# -- Terrain, reserve 14-31 --
	#
	# Les 13 premieres entrees sont ecrites par le generateur ; celles-ci ne le
	# sont par personne. Elles existent pour les modeles : un caillou, un bloc
	# de gres ou une paroi de basalte sont de la *matiere de terrain*, et la
	# plage vegetation n'a aucun gris. Sans elles, tout ce qui est mineral se
	# rabat sur STONE et les six cailloux du lot de flore rendent la meme
	# couleur.
	_ramp(c, 14, 6, Color8(178, 180, 186), Color8(54, 56, 62))    # roche nue
	_ramp(c, 20, 5, Color8(226, 198, 140), Color8(118, 94, 56))   # gres, argile
	_ramp(c, 25, 3, Color8(58, 56, 62), Color8(22, 20, 26))       # basalte, obsidienne
	c[28] = Color8(96, 104, 70)     # roche lichenee, claire
	c[29] = Color8(58, 64, 44)      # roche lichenee, sombre
	# 30 et 31 sont les deux seules entrees de cette reserve que le generateur
	# **ecrit** : ce sont les types de bloc de Lava Lands, pas de la matiere de
	# modele. Voir MAGMA / SCORIA en tete de fichier.
	# Franchement rouge, et pas seulement chaud : a 255,152,48 la coulee lisait
	# comme du sable — le sable du desert est a 253,185,82, et les deux se
	# confondaient sur une capture prise dans la brume (2026-09-06).
	c[MAGMA] = Color8(255, 92, 16)    # coulee incandescente
	# La scorie est **sombre**, et c'est une correction de capture, pas de gout
	# (2026-09-06). A 176,44,20 — la teinte « lave refroidie » d'origine, choisie
	# quand ces deux entrees n'etaient que de la matiere de modele — le sol d'une
	# Lava Lands entiere rendait un rose saumon uniforme : la coulee incandescente
	# ne s'en detachait pas, et le buisson rouge du biome s'y fondait. Une croute
	# refroidie est de la roche, pas de la lave.
	c[SCORIA] = Color8(104, 50, 44)   # croute refroidie

	# Les neuf filons, 32-40, dans l'ordre des codes d'entite 131-139. Ce sont
	# des *types de bloc* : un filon s'estampe et se mine, contrairement a tout
	# ce qui precede en 14-31, qui n'est que de la matiere pour les modeles.
	# Chacun doit se reconnaitre d'un coup d'oeil dans une paroi de roche grise,
	# d'ou des teintes franches plutot que des nuances.
	c[ORE_GOLD] = Color8(255, 206, 80)
	c[ORE_IRON] = Color8(168, 122, 96)
	c[ORE_SILVER] = Color8(222, 234, 246)
	c[ORE_SANDSTONE] = Color8(206, 170, 106)
	c[ORE_EMERALD] = Color8(64, 210, 130)
	c[ORE_SAPPHIRE] = Color8(72, 132, 240)
	c[ORE_RUBY] = Color8(230, 58, 88)
	c[ORE_DIAMOND] = Color8(232, 250, 252)
	c[ORE_ICE_CRYSTAL] = Color8(146, 206, 240)

	# -- Creatures 41-95 --
	# Les sept rampes ont ete recompactees de 56 entrees a 47 le 2026-09-05, pour
	# rendre neuf entrees aux filons. **Les huit teintes ponctuelles gardent leurs
	# index (88-95)** : ce sont elles qu'un modele nommerait en clair, et les
	# deplacer aurait ete le seul vrai cout de l'operation. Aucune n'est peinte a
	# ce jour, l'apparence des creatures etant hors perimetre.
	_ramp(c, 41, 7, Color8(247, 216, 185), Color8(92, 58, 40))    # peaux
	_ramp(c, 48, 7, Color8(198, 138, 78), Color8(74, 44, 24))     # fourrure rousse
	_ramp(c, 55, 7, Color8(238, 238, 236), Color8(58, 58, 66))    # fourrure grise
	_ramp(c, 62, 7, Color8(150, 214, 108), Color8(30, 78, 44))    # ecailles vertes
	_ramp(c, 69, 7, Color8(150, 186, 240), Color8(56, 42, 110))   # ecailles bleues
	_ramp(c, 76, 6, Color8(96, 84, 92), Color8(24, 20, 26))       # chitine
	_ramp(c, 82, 6, Color8(255, 138, 84), Color8(210, 46, 120))   # teintes vives
	c[88] = Color8(250, 250, 250)   # blanc de l'oeil
	c[89] = Color8(20, 18, 22)      # pupille
	c[90] = Color8(214, 48, 48)     # langue, sang
	c[91] = Color8(255, 214, 66)    # iris clair
	c[92] = Color8(126, 226, 226)   # iris froid
	c[93] = Color8(168, 120, 200)   # iris magique
	c[94] = Color8(236, 226, 204)   # os, croc, corne claire
	c[95] = Color8(120, 104, 78)    # corne sombre, sabot

	# -- Armes et equipement 96-127 --
	_ramp(c, 96, 8, Color8(226, 232, 240), Color8(64, 70, 82))    # acier
	_ramp(c, 104, 6, Color8(255, 214, 112), Color8(146, 96, 22))  # or, bronze
	_ramp(c, 110, 6, Color8(186, 140, 92), Color8(74, 50, 32))    # bois de manche
	_ramp(c, 116, 6, Color8(176, 116, 70), Color8(72, 44, 28))    # cuir
	_ramp(c, 122, 6, Color8(126, 244, 220), Color8(150, 54, 214)) # gemmes

	# -- Vegetation 128-175 --
	_ramp(c, 128, 12, Color8(154, 216, 96), Color8(24, 72, 44))   # feuillage
	_ramp(c, 140, 8, Color8(238, 186, 74), Color8(150, 70, 34))   # automne, herbe seche
	_ramp(c, 148, 8, Color8(150, 112, 76), Color8(56, 40, 30))    # troncs, ecorce
	c[156] = Color8(232, 72, 84)    # fleur rouge
	c[157] = Color8(255, 156, 168)
	c[158] = Color8(252, 214, 92)   # fleur jaune
	c[159] = Color8(255, 244, 176)
	c[160] = Color8(96, 150, 236)   # fleur bleue
	c[161] = Color8(168, 206, 255)
	c[162] = Color8(168, 108, 214)  # fleur violette
	c[163] = Color8(216, 178, 248)
	_ramp(c, 164, 6, Color8(214, 118, 92), Color8(70, 96, 62))    # champignons, mousse
	# Algues et coraux. Le fond marin est l'une des neuf surfaces que le
	# generateur produit, et rien d'autre dans la palette n'est froid et sature :
	# sans ces deux entrees, un corail se rabat sur le vert de prairie.
	c[170] = Color8(58, 178, 190)   # eau claire, corail vif
	c[171] = Color8(16, 104, 124)   # profondeur, corail sombre
	_ramp(c, 172, 4, Color8(112, 168, 108), Color8(48, 92, 62))   # cactus

	# -- Structures 176-239 --
	_ramp(c, 176, 12, Color8(206, 164, 112), Color8(84, 56, 36))  # planches
	_ramp(c, 188, 12, Color8(214, 210, 200), Color8(72, 70, 74))  # pierre taillee
	_ramp(c, 200, 10, Color8(196, 84, 70), Color8(78, 34, 34))    # tuiles
	_ramp(c, 210, 10, Color8(244, 238, 224), Color8(158, 146, 124)) # platre, torchis
	_ramp(c, 220, 8, Color8(216, 66, 66), Color8(40, 62, 140))    # tissus, bannieres
	c[228] = Color(0.78, 0.90, 0.96, 0.35)   # verre clair
	c[229] = Color(0.62, 0.80, 0.92, 0.45)
	c[230] = Color(0.90, 0.60, 0.30, 0.45)   # vitraux
	c[231] = Color(0.40, 0.72, 0.50, 0.45)
	c[232] = Color(0.60, 0.40, 0.78, 0.45)
	c[233] = Color(0.94, 0.86, 0.42, 0.45)
	_ramp(c, 234, 6, Color8(148, 152, 160), Color8(52, 54, 60))   # metal de structure

	# -- Effets et reperes 240-255 --
	_ramp(c, 240, 8, Color8(255, 255, 255), Color8(120, 200, 255))  # lumiere, magie
	c[248] = Color8(255, 0, 128)    # repere d'edition, volontairement criard
	c[249] = Color8(0, 255, 128)
	c[250] = Color8(255, 240, 0)
	c[251] = Color8(0, 200, 255)
	c[252] = Color8(255, 96, 0)
	c[253] = Color8(140, 0, 255)
	c[254] = Color8(0, 0, 0)
	c[255] = Color8(255, 255, 255)


## Construit la ressource de palette attendue par VoxelMesherCubes.
##
## Ne sert plus au rendu depuis le passage en `COLOR_RAW` : elle reste la table
## que `VoxelVoxLoader` consulte pour convertir un `.vox` en index, et c'est
## toujours par elle que les modeles entrent dans le projet.
static func build_voxel_palette() -> Resource:
	var pal: Resource = ClassDB.instantiate("VoxelColorPalette")
	pal.colors = colors()
	return pal


## Canal semantique : l'index de palette. C'est lui que lit tout le code qui
## raisonne en blocs.
const CHANNEL_TYPE: int = VoxelBuffer.CHANNEL_TYPE

## Canal de rendu : la couleur RGBA8888 que `VoxelMesherCubes` lit en
## `COLOR_RAW`. Personne d'autre ne le lit.
const CHANNEL_COLOR: int = VoxelBuffer.CHANNEL_COLOR

## Profondeur du canal de rendu. **Un seul endroit a changer** si l'empreinte
## memoire devient genante : `DEPTH_16_BIT` encode la meme couleur en RGBA4444,
## soit deux octets par voxel au lieu de quatre. Le prix est de seize niveaux par
## composante, ce qui suffit aux teintes de la palette mais fera des marches
## visibles le jour ou la lumiere par voxel les multipliera — d'ou 32 bits ici.
const COLOR_DEPTH: int = VoxelBuffer.DEPTH_32_BIT

## Couleur rendue d'un index, en RGBA8888. L'air est zero : alpha nul, donc le
## mailleur le traite comme du vide, exactement comme l'index 0 auparavant.
static var _raw: PackedInt64Array = PackedInt64Array()
static var _raw_mutex: Mutex = Mutex.new()


static func raw_of(index: int) -> int:
	if _raw.is_empty():
		_build_raw()
	return _raw[index & 0xFF]


## Table index -> couleur, construite une fois. Sous verrou : les generateurs
## tournent sur un pool de fils et se la disputent au premier bloc.
static func _build_raw() -> void:
	_raw_mutex.lock()
	if _raw.is_empty():
		var cols: PackedColorArray = colors()
		var table := PackedInt64Array()
		table.resize(256)
		for i in 256:
			var c: Color = cols[i]
			var r: int = int(roundf(c.r * 255.0))
			var g: int = int(roundf(c.g * 255.0))
			var b: int = int(roundf(c.b * 255.0))
			var a: int = int(roundf(c.a * 255.0))
			table[i] = (r << 24) | (g << 16) | (b << 8) | a
		_raw = table
	_raw_mutex.unlock()


## Format de canaux du terrain : l'index sur un octet, la couleur sur quatre.
## A poser sur `VoxelTerrain.format` **avant** que le terrain ne charge quoi que
## ce soit — un tampon deja cree garde la profondeur qu'il avait.
static func build_voxel_format() -> Resource:
	var fmt: Resource = ClassDB.instantiate("VoxelFormat")
	fmt.set_channel_depth(CHANNEL_TYPE, VoxelBuffer.DEPTH_8_BIT)
	fmt.set_channel_depth(CHANNEL_COLOR, COLOR_DEPTH)
	return fmt


## Mailleur en cubes partage par le terrain, les modeles et le gabarit.
##
## En `COLOR_RAW` le mailleur lit la couleur telle quelle : plus de nuancier a
## lui donner. Le materiau transparent reste indispensable — l'eau a un alpha
## inferieur a 1, et c'est cet alpha qui la range dans la seconde surface.
static func build_cubes_mesher() -> VoxelMesherCubes:
	var mesher := VoxelMesherCubes.new()
	mesher.color_mode = VoxelMesherCubes.COLOR_RAW
	mesher.greedy_meshing_enabled = true
	mesher.opaque_material = build_opaque_material()

	var water := StandardMaterial3D.new()
	water.vertex_color_use_as_albedo = true
	water.vertex_color_is_srgb = true
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.12
	water.metallic = 0.15
	mesher.transparent_material = water
	return mesher


## Materiau opaque du rendu en cubes : couleur portee par les sommets, pas de
## speculaire.
##
## Partage par le terrain, les modeles instancies et le gabarit d'echelle. Ce
## n'est pas de la coquetterie : les modeles sont sur une grille treize fois plus
## fine que le terrain, et le seul lien qui les fait lire comme un meme monde est
## d'avoir exactement la meme palette et le meme materiau. Un reglage qui derive
## d'un cote se voit immediatement.
static func build_opaque_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat


## Humidite au-dessus de laquelle un sol de jungle se lit en sol humide. Le
## marais est une *matiere* de Jungles, pas un biome — et c'est la seule frange
## d'humidite qui reste, parce qu'elle porte quelque chose : le roseau de la
## source pousse sur ce type de bloc et sur aucun autre.
const SWAMP_H: float = 0.92

## Altitude sous laquelle une cuvette de Lava Lands est remplie de magma : un
## lac de lave au fond d'un bassin.
##
## Ce seuil seul ne suffit pas, et la mesure le dit : les coeurs de regions
## chaudes sont des terres hautes, et a 30 blocs il ne restait **15 colonnes de
## magma sur 147 456**. C'est le champ de coulees ci-dessous qui porte le
## « magma omnipresent » de l'alpha ; celui-ci ne fait que les bassins.
const MAGMA_LEVEL: float = 12.0

# -- Les coulees de lave ------------------------------------------------------
#
# Une crete de bruit, exactement comme la crete de placement du decor : ce qui
# est *pres de zero* est une coulee, le reste est de la scorie. Une crete rend
# des veines continues la ou un seuil simple rendrait des taches — et c'est bien
# des veines qu'on veut, le magma d'une Lava Lands coulant en rivieres entre les
# reliefs.
#
# La frequence donne la maille du reseau. Elle est passee de 0,004 a 0,012 apres
# capture (2026-09-06) : a 250 blocs de longueur d'onde, une vue de 224 blocs
# pouvait tomber entierement entre deux coulees, et le biome rendait une plaine
# de scorie nue — « magma omnipresent » disait le releve, on n'en voyait aucun.
# A 83 blocs, deux ou trois veines traversent le champ de vision. Les decalages
# n'ont d'autre role que d'eloigner ce champ des autres ; ils sont pris grands
# et premiers entre eux comme partout ici.
#
# Cout : **un echantillon de bruit par colonne de Lava Lands**, soit sur 1,9 %
# des terres. Sur les 62 us que coute une colonne, l'echantillon en vaut 1 —
# c'est la raison pour laquelle la regle de surface prend (x, z) depuis le
# jalon 1.12, et la seule chose qu'elle en fait.
const LAVA_FLOW_FREQ: float = 0.012
const LAVA_FLOW_OFFSET_X: float = 61247.0
const LAVA_FLOW_OFFSET_Z: float = 18923.0
## Demi-largeur de la crete, en valeur de bruit. Plus elle est grande, plus les
## coulees sont larges. Mesuree par `tools/biome_stats.gd`, pas choisie a l'oeil.
const LAVA_FLOW_RIDGE: float = 0.09

## Vrai si la colonne est sur une coulee. Coordonnees **monde**, comme partout
## dans la dispersion — un decalage d'origine applique deux fois donnerait des
## coulees ailleurs que la ou elles sont generees.
static func lava_flow(x: int, z: int) -> bool:
	return absf(CWValueNoise.sample(
			float(x) * LAVA_FLOW_FREQ + LAVA_FLOW_OFFSET_X,
			float(z) * LAVA_FLOW_FREQ + LAVA_FLOW_OFFSET_Z)) < LAVA_FLOW_RIDGE


## Matiere de surface d'une colonne, connaissant son biome.
##
## `above` est l'altitude au-dessus du niveau de la mer, en blocs. C'est la
## seconde moitie de la regle : `CWBiome.at` dit *ou on est*, celle-ci dit *de
## quoi c'est fait*. Les deux etaient confondues avant le jalon 1.12, et c'est
## cette confusion qui faisait de la roche d'altitude et du fond marin des
## « biomes » a part entiere.
##
## Il ne reste **qu'une bande d'altitude** avant la matiere de plaine : la
## plage. La roche nue et la neige de sommet sont tombees le 2026-09-06 (voir
## la note plus bas), et Lava Lands refuse la plage — il n'y a pas de rivage
## dans un volcan.
##
static func surface_of(biome: int, above: float, temperature: float,
		humidity: float, x: int, z: int) -> int:
	if biome == CWBiome.OCEANS:
		# Fond marin : sable pres du rivage, gravier en profondeur.
		return SAND if above > -12.0 else GRAVEL

	if biome == CWBiome.LAVALANDS:
		if above < MAGMA_LEVEL or lava_flow(x, z):
			return MAGMA
		var lava_rock: float = SNOW_LINE_BASE + temperature * SNOW_LINE_SPAN
		return STONE if above > maxf(lava_rock - ROCK_BAND, ROCK_MIN) else SCORIA

	if above <= BEACH_BAND:
		# Le rivage d'une Snowlands est gele, pas sableux. C'est la **seule**
		# bande d'altitude qui reste (voir ci-dessous), et elle reste parce
		# qu'un rivage est un lieu et non une nuance : on y aborde, on y pose
		# un village, et le sable y dit quelque chose que le biome ne dit pas.
		return SNOW if biome == CWBiome.SNOWLANDS else SAND

	# -- Un biome, une matiere. C'est tout ----------------------------------
	#
	# Deux retraits, le meme jour, et c'est la meme erreur prise par deux bouts.
	#
	# **Les franges d'humidite** — l'herbe seche de Greenlands, la toundra de
	# Snowlands — etaient un reste du systeme d'avant le jalon 1.12, ou « biome »
	# voulait dire « matiere de bloc » et ou il en fallait neuf pour dire six.
	# Depuis que `CWBiome` classe le climat, une seconde matiere de plaine ne dit
	# rien que le biome ne dise deja ; en jeu elle disait meme le contraire, une
	# prairie annoncee « Greenlands » avec un sol kaki de steppe.
	#
	# **Les bandes d'altitude** — roche nue au-dessus d'un seuil, neige de sommet
	# au-dessus d'un autre — sont tombees ensuite, et pour une raison qui n'est
	# pas la meme : elles ne se contredisaient pas, elles ne **portaient rien**.
	# `CWDecorRules.decor_allowed` refuse le decor sur la roche et sur la neige
	# hors Snowlands, si bien que chaque relief un peu haut d'une Greenlands
	# rendait une calotte nue, sans une plante, sans un arbre — un plateau gris
	# ou l'on marchait sans rien rencontrer. Une matiere qui ne porte rien n'est
	# pas un sous-biome, c'est un trou dans le monde.
	#
	# Ce qui les rendait defendables etait un raisonnement de vraisemblance :
	# une montagne a de la roche et de la neige. Il tenait tant qu'on regardait
	# une carte de hauteurs ; il ne tient plus des qu'on marche dessus.
	#
	# Restent donc : la matiere du biome, la plage, et le cas de Lava Lands qui
	# a sa propre regle plus haut — la sienne decrit un volcan, pas une altitude.
	match biome:
		CWBiome.SNOWLANDS:
			return SNOW
		CWBiome.DESERTS:
			return SAND
		CWBiome.JUNGLES:
			return SWAMP if humidity > SWAMP_H else GRASS_JUNGLE
		_:
			return GRASS


## Bloc de surface d'une colonne, biome compris. Raccourci pour les appelants
## qui n'ont pas deja le biome sous la main — le chemin de generation, lui, le
## calcule une fois et appelle `surface_of` directement.
static func surface_index(height: float, temperature: float, humidity: float,
		sea_level: int, x: int, z: int) -> int:
	var biome: int = CWBiome.at(height, temperature, humidity, sea_level)
	return surface_of(biome, height - float(sea_level), temperature, humidity,
			x, z)


## Bloc juste sous la surface (quelques blocs d'epaisseur).
static func subsurface_index(surface: int) -> int:
	match surface:
		SAND, GRAVEL:
			return surface
		SNOW, ICE:
			return STONE
		STONE:
			return STONE
		MAGMA, SCORIA:
			# Sous une coulee comme sous la croute : de la scorie, puis la roche
			# que `CWVoxelGenerator` pose plus bas. Du magma sur toute
			# l'epaisseur ferait une mer de lave en coupe des le premier trou.
			return SCORIA
		_:
			return DIRT


## Bloc d'eau selon la profondeur sous la surface libre.
static func water_index(depth_below_sea: float) -> int:
	return WATER_DEEP if depth_below_sea > 8.0 else WATER


## Vrai pour les deux nuances d'eau. Les distinguer est une affaire de rendu ;
## tout ce qui demande « est-ce mouille » — la dispersion, la regle de bloc —
## veut les deux, et ecrire le couple a la main est la maniere de n'en garder
## qu'une le jour ou une troisieme apparait.
static func is_water(index: int) -> bool:
	return index == WATER or index == WATER_DEEP


## Nom lisible d'un index de palette, pour les outils et l'ATH.
static func name_of(index: int) -> String:
	match index:
		AIR: return "air"
		STONE: return "roche"
		DIRT: return "terre"
		GRASS: return "herbe"
		WOOD: return "bois"
		GRASS_JUNGLE: return "jungle"
		SAND: return "sable"
		SNOW: return "neige"
		ICE: return "glace"
		TUNDRA: return "toundra"
		SWAMP: return "marais"
		GRAVEL: return "gravier"
		WATER: return "eau"
		WATER_DEEP: return "eau profonde"
		MAGMA: return "magma"
		SCORIA: return "scorie"
		ORE_GOLD: return "filon d'or"
		ORE_IRON: return "filon de fer"
		ORE_SILVER: return "filon d'argent"
		ORE_SANDSTONE: return "filon de gres"
		ORE_EMERALD: return "filon d'emeraude"
		ORE_SAPPHIRE: return "filon de saphir"
		ORE_RUBY: return "filon de rubis"
		ORE_DIAMOND: return "filon de diamant"
		ORE_ICE_CRYSTAL: return "filon de cristal de glace"
		_: return "?"


## Vrai si l'index est un filon. Un filon est de la matiere de terrain : il
## s'ecrit dans les donnees du monde, il se creuse, il porte collision.
static func is_ore(index: int) -> bool:
	return index >= ORE_BEGIN and index <= ORE_END


## Index de palette du filon portant le code d'entite `code` (131-139), ou
## `AIR` si le code n'en est pas un.
##
## Les neuf filons occupent des codes consecutifs dans la source
## (`docs/systems/02`, §5.2) et des index consecutifs ici : la correspondance est
## donc une addition, et elle est verrouillee par un test. C'est le chemin le
## plus court le jour ou la voie des entites sera portee — la table de rarete de
## §5.4 rend un rang, ce rang est un code, et ce code est un index.
static func ore_of_code(code: int) -> int:
	var i: int = ORE_BEGIN + (code - ORE_CODE_BEGIN)
	return i if is_ore(i) else AIR


## Le code d'entite d'un filon. Reciproque de `ore_of_code`.
static func code_of_ore(index: int) -> int:
	return ORE_CODE_BEGIN + (index - ORE_BEGIN) if is_ore(index) else -1


## Tirage du filon a poser, porte verbatim de `docs/systems/02`, §5.4 :
##
##     rand() % 10 :  0 -> or        1 -> argent
##                    3 -> rand() % 100 :  0     -> diamant
##                                         1-3   -> rubis
##                                         4-8   -> saphir
##                                         sinon -> emeraude
##                    sinon -> fer
##
## Soit fer 70 %, or 10 %, argent 10 %, emeraude ~9,1 %, saphir 0,5 %, rubis
## 0,3 %, diamant 0,1 %. Les deux tirages sont pris **dans cet ordre et toujours
## les deux** : un tirage conditionnel desynchroniserait le flux du generateur
## d'un appel a l'autre, et la pose ne serait plus reproductible.
##
## `gres` et `cristal de glace` n'apparaissent pas dans cette table — ils sont
## dans la liste des neuf modeles mais pas dans le tirage lu. C'est la source qui
## est ainsi ; ils sont vraisemblablement poses par une autre branche, liee au
## biome (du gres en desert, du cristal en neige), qui n'a pas ete trouvee.
static func roll_ore(r10: int, r100: int) -> int:
	var a: int = r10 % 10
	var b: int = r100 % 100
	if a == 0:
		return ORE_GOLD
	if a == 1:
		return ORE_SILVER
	if a != 3:
		return ORE_IRON
	if b == 0:
		return ORE_DIAMOND
	if b <= 3:
		return ORE_RUBY
	if b <= 8:
		return ORE_SAPPHIRE
	return ORE_EMERALD
