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
## Le rendu vise VoxelMesherCubes en mode COLOR_MESHER_PALETTE : le canal
## CHANNEL_COLOR contient un index, 0 = air.

const AIR: int = 0
const STONE: int = 1
const DIRT: int = 2
const GRASS: int = 3
const GRASS_DRY: int = 4
const GRASS_JUNGLE: int = 5
const SAND: int = 6
const SNOW: int = 7
const ICE: int = 8
const TUNDRA: int = 9
const SWAMP: int = 10
const GRAVEL: int = 11
const WATER: int = 12
const WATER_DEEP: int = 13
const COUNT: int = 14

# -- Plages reservees de la palette de projet ---------------------------------
#
# VoxelMesherCubes en mode COLOR_MESHER_PALETTE lit un index par voxel, et une
# seule palette sert a tout : terrain et modeles. Les assets doivent donc etre
# peints dans CETTE palette, d'ou le decoupage en plages. Voir
# `assets/palette/PALETTE.md` et le PNG exporte pour MagicaVoxel.
#
# L'index 0 est l'air et ne peut pas servir : le mailleur le traite comme vide.

## Terrain. 0-13 sont ecrits par le generateur ; 14-31 sont de la matiere de
## terrain destinee aux modeles — roche nue, gres, argile, basalte, lave. C'est
## la seule plage ou un modele trouve du gris : la vegetation n'en a aucun.
const RANGE_TERRAIN_BEGIN: int = 1
const RANGE_TERRAIN_END: int = 31

## Creatures : peaux, fourrures, ecailles, chitine, yeux.
const RANGE_CREATURES_BEGIN: int = 32
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
const SNOW_LINE_BASE: float = 40.0
const SNOW_LINE_SPAN: float = 360.0
## Epaisseur de roche nue juste sous la ligne de neige.
const ROCK_BAND: float = 55.0
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
	c[GRASS_DRY] = Color8(163, 165, 88)
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
	c[30] = Color8(255, 152, 48)    # lave, incandescente
	c[31] = Color8(176, 44, 20)     # lave, refroidie

	# -- Creatures 32-95 --
	_ramp(c, 32, 8, Color8(247, 216, 185), Color8(92, 58, 40))    # peaux
	_ramp(c, 40, 8, Color8(198, 138, 78), Color8(74, 44, 24))     # fourrure rousse
	_ramp(c, 48, 8, Color8(238, 238, 236), Color8(58, 58, 66))    # fourrure grise
	_ramp(c, 56, 8, Color8(150, 214, 108), Color8(30, 78, 44))    # ecailles vertes
	_ramp(c, 64, 8, Color8(150, 186, 240), Color8(56, 42, 110))   # ecailles bleues
	_ramp(c, 72, 8, Color8(96, 84, 92), Color8(24, 20, 26))       # chitine
	_ramp(c, 80, 8, Color8(255, 138, 84), Color8(210, 46, 120))   # teintes vives
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
static func build_voxel_palette() -> Resource:
	var pal: Resource = ClassDB.instantiate("VoxelColorPalette")
	pal.colors = colors()
	return pal


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


## Bloc de surface d'une colonne.
## height : altitude de la colonne, en blocs. sea_level : niveau de la mer.
static func surface_index(height: float, temperature: float, humidity: float,
		sea_level: int) -> int:
	var above: float = height - float(sea_level)

	if above < -1.0:
		# Fond marin : sable pres du rivage, gravier en profondeur.
		return SAND if above > -12.0 else GRAVEL
	if above <= BEACH_BAND:
		return SAND

	var snow_line: float = SNOW_LINE_BASE + temperature * SNOW_LINE_SPAN
	if above > snow_line:
		return SNOW
	if above > snow_line - ROCK_BAND:
		return STONE

	if temperature < 0.18:
		return SNOW if humidity > 0.5 else TUNDRA
	if temperature > 0.78 and humidity < 0.32:
		return SAND
	if humidity > 0.74:
		return GRASS_JUNGLE if temperature > 0.55 else SWAMP
	if humidity < 0.36:
		return GRASS_DRY
	return GRASS


## Bloc juste sous la surface (quelques blocs d'epaisseur).
static func subsurface_index(surface: int) -> int:
	match surface:
		SAND, GRAVEL:
			return surface
		SNOW, ICE:
			return STONE
		STONE:
			return STONE
		_:
			return DIRT


## Bloc d'eau selon la profondeur sous la surface libre.
static func water_index(depth_below_sea: float) -> int:
	return WATER_DEEP if depth_below_sea > 8.0 else WATER


## Nom lisible d'un index de palette, pour les outils et l'ATH.
static func name_of(index: int) -> String:
	match index:
		AIR: return "air"
		STONE: return "roche"
		DIRT: return "terre"
		GRASS: return "herbe"
		GRASS_DRY: return "herbe seche"
		GRASS_JUNGLE: return "jungle"
		SAND: return "sable"
		SNOW: return "neige"
		ICE: return "glace"
		TUNDRA: return "toundra"
		SWAMP: return "marais"
		GRAVEL: return "gravier"
		WATER: return "eau"
		WATER_DEEP: return "eau profonde"
		_: return "?"
