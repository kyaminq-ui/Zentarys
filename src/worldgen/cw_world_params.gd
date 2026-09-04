@tool
class_name CWWorldParams
extends Resource

## Paramètres d'un monde : graine, constantes d'échelle, décalages de bruit.
##
## Traçabilité : dans l'original, ces valeurs vivent dans le gros bloc de
## données de `cube::World` (graine du monde à +0x800188, vingt-huit décalages
## de bruit entiers de +0x800168 à +0x800218). Leur séquence d'initialisation
## n'est pas récupérable depuis la décompilation ; on les dérive ici du même
## LCG que le reste du monde, ce qui garde le déterminisme sans prétendre à une
## équivalence bit à bit avec l'original.

# --- Découpage spatial du monde d'origine -----------------------------------
# Le monde fait 0x1000000 unités (= colonnes de blocs) sur chaque axe :
#   monde  16 777 216 u
#     └ zone       16384 u   (grille 1024 x 1024, indexée par x >> 14)
#         └ tuile   2048 u   (8 x 8 par zone, indexée par x >> 11)
#             └ région 256 u (8 x 8 par tuile, grille de colonnes 256 x 256)
# Reconstruit à partir des décalages et bornes de `World_getTileAtCoords`,
# `Chunk_getColumnAt` et des fenêtres 3x3 des mélanges climatiques.
const ZONE_SIZE: int = 16384
const ZONE_SHIFT: int = 14
const TILE_SIZE: int = 2048
const TILE_SHIFT: int = 11
const ZONE_GRID: int = 1024
const WORLD_SIZE: int = ZONE_GRID * ZONE_SIZE
## Centre de la carte, en unites monde : centre de la zone (512, 512). C'est la
## reference de `World_featureTier` (@004d7870), qui gradue la difficulte a
## partir de ce point.
@warning_ignore("integer_division")
const WORLD_CENTRE: int = (ZONE_GRID >> 1) * ZONE_SIZE + ZONE_SIZE / 2

# --- Indices dans `noise_offsets` -------------------------------------------
const O_CHAN_BASE: int = 0      ## réseau de chenaux, octave de base  (f 0.001)
const O_CHAN_DETAIL: int = 2    ## réseau de chenaux, détail          (f 0.01)
const O_AMP_LOW_A: int = 4      ## masque d'amplitude continental A   (f 0.0001)
const O_AMP_LOW_B: int = 6      ## masque d'amplitude continental B   (f 0.0001)
const O_AMP_MID_A: int = 8      ## masque d'amplitude médian A        (f 0.001)
const O_AMP_MID_B: int = 10     ## masque d'amplitude médian B        (f 0.001)
const O_AMP_HIGH: int = 12      ## masque d'amplitude de détail       (f 0.002)
const O_CONT_A: int = 14        ## octave continental A               (f 0.0002)
const O_CONT_B: int = 16        ## octave continental B               (f 0.0002)
const O_MID_A: int = 18         ## octave médian A                    (f 0.002)
const O_MID_B: int = 20         ## octave médian B                    (f 0.002)
const O_HIGH: int = 22          ## octave de détail                   (f 0.01)
const O_WARP_X_BASE: int = 24   ## déformation du domaine, X          (f 0.0005)
const O_WARP_X_DETAIL: int = 26 ## déformation du domaine, X          (f 0.01)
const O_WARP_Z_BASE: int = 28   ## déformation du domaine, Z          (f 0.0005)
const O_WARP_Z_DETAIL: int = 30 ## déformation du domaine, Z          (f 0.01)
const OFFSET_COUNT: int = 32

@export var world_seed: int = 1337:
	set(v):
		world_seed = v
		_rebuild()

## Décalage appliqué aux coordonnées Godot pour obtenir les coordonnées monde.
## Permet de jouer au centre de la carte d'origine (zone 512, 512) tout en
## gardant les coordonnées Godot proches de zéro.
@export var world_origin: Vector2i = Vector2i(WORLD_CENTRE, WORLD_CENTRE)

## Point de départ du joueur en coordonnées monde. La région qui le contient est
## forcée en climat tempéré et en altitude positive par le générateur de sites.
@export var start_point: Vector2i = Vector2i(WORLD_CENTRE, WORLD_CENTRE)

## Niveau de la mer. Les altitudes de base océaniques sont négatives dans
## l'original, donc y = 0 est bien la surface de l'eau.
@export var sea_level: int = 0

## Facteur appliqué à l'altitude finale. 1.0 = fidèle. Sert uniquement à réduire
## la hauteur du monde pour des tests de streaming.
@export_range(0.05, 2.0, 0.01) var height_scale: float = 1.0

## Active la couche d'éléments de tuile (jalon 1.6) : bourgs, cratères,
## caldeiras, pitons et relèvement des îlots océaniques.
##
## Bascule conservée pour comparer un même monde avec et sans, et pour isoler
## une régression du champ de base. La désactiver ne change rien au reste du
## champ : les éléments ne s'appliquent qu'en fin de chaîne.
@export var tile_features: bool = true

## Contribution du mélange « marais » au champ de chenaux.
## L'accumulateur de `World_waterProximityInfluence` est perdu dans la
## décompilation (valeur de retour en xmm0) : on connaît sa structure, pas le
## champ sommé. Désactivé par défaut plutôt que deviné.
@export_range(0.0, 2.0, 0.01) var swamp_channel_weight: float = 0.0

## Rayon d'influence, en blocs, des arêtes du graphe de sites de région.
## `0` désactive les deux termes qui en dépendent (crête du champ de chenaux,
## porte d'atténuation du détail).
##
## Les deux termes comparent cette distance à des seuils de l'ordre de l'unité
## (`1 - d * 0.75`, `min(1, max(d, 0.02) * 2)`), alors que le binaire y injecte
## un *carré de distance en unités monde*. Les seuils ne sont donc franchis que
## sur une bande de moins d'un bloc de large, ce qui creuse une tranchée d'une
## seule colonne le long de chaque arête : des lignes fines et parfaitement
## droites qui tranchent le paysage, y compris à travers les frontières de
## biome. Reproduire ce comportement à la lettre n'apporte rien — c'est un
## artefact d'unités, pas un relief.
##
## Défaut `0` : pas de tranchée. Une valeur positive normalise la distance par
## `rayon²`, ce qui donne l'effet vraisemblablement voulu à l'origine, une
## dépression large le long des lignes reliant les régions. À évaluer quand la
## couche d'éléments de tuile arrivera : les routes y sont un type d'élément,
## et ces arêtes sont peut-être leur tracé.
@export_range(0.0, 4096.0, 1.0) var site_edge_radius: float = 0.0

var noise_offsets: PackedFloat64Array = PackedFloat64Array()


func _init() -> void:
	if noise_offsets.size() != OFFSET_COUNT:
		_rebuild()


func _rebuild() -> void:
	var rng := CWRand.new(world_seed * 2654435761)
	noise_offsets = PackedFloat64Array()
	noise_offsets.resize(OFFSET_COUNT)
	for i in OFFSET_COUNT:
		# Décalages entiers larges, comme dans l'original : ils décorrèlent les
		# octaves sans changer la phase fractionnaire du réseau.
		noise_offsets[i] = float(rng.next() * 32768 + rng.next())


func offset_x(slot: int) -> float:
	return noise_offsets[slot]


func offset_z(slot: int) -> float:
	return noise_offsets[slot + 1]


## Index de zone (grille 1024 x 1024) contenant une coordonnée monde.
##
## Décalage arithmétique plutôt que division flottante : les deux tailles sont
## des puissances de deux, `>>` est donc exactement la division entière par
## défaut que faisait `floori`, négatifs compris — et ces deux fonctions sont
## appelées plusieurs fois par colonne.
static func zone_of(v: int) -> int:
	return v >> ZONE_SHIFT


## Index de tuile (grille 8192 x 8192) contenant une coordonnée monde.
static func tile_of(v: int) -> int:
	return v >> TILE_SHIFT
