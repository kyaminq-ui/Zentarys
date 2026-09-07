class_name CWDaylight
extends Node3D

## Le ciel, le soleil et le brouillard de la demo.
##
## -- Pourquoi un noeud a lui ---------------------------------------------------
##
## Ces vingt-cinq lignes vivaient dans `terrain_demo.gd`, qui en fait onze cent
## et sept metiers. Elles en sortent le 2026-09-10 pour deux raisons, et la
## seconde est la vraie : c'est ici que le **cycle jour/nuit** viendra se poser,
## et un cycle ecrit dans une scene de demonstration qui fait deja les arguments
## de ligne de commande, le terrain, la carte, l'ATH, la camera et les captures
## n'aurait nulle part ou tenir.
##
## -- Ce qui viendra ici, et le piege qui l'attend -----------------------------
##
## La forme visee est **un scalaire d'heure dans `[0, 1)` et une seule fonction
## qui en deduit tout** : rotation, energie et couleur du soleil ; couleurs de
## zenith, d'horizon et de sol du ciel ; energie de l'ambiante ; couleur et
## densite du brouillard. Un seul point d'entree, sinon l'aube aura un ciel rose
## et un brouillard bleu.
##
## > ⚠️ **`CWLight` est un eclairage *cuit*, et il ne suivra pas le soleil.** La
## > passe A descend la lumiere colonne par colonne, la passe B diffuse seize
## > fois a l'horizontale, et le resultat est ecrit dans le canal de couleur du
## > voxel a la generation. Tourner le `DirectionalLight3D` ne rallume donc rien,
## > et un recuit est hors de question — 7 ms pour un pave de 33³. La lecture qui
## > marche : **le voxel cuit est un terme d'occlusion**, pas une heure — il dit
## > *ce recoin est abrite*, ce qui reste vrai la nuit —, et c'est la lumiere de
## > la scene qui porte le cycle.
##
## > ⚠️ **Le brouillard se regle apres la distance de vue, pas avant.** La densite
## > ci-dessous cache le bord d'une vue de 384 blocs. Augmenter la distance sans
## > la reprendre rend le lointain laiteux bien avant son bord.

## Angle du soleil, en degres. Fixe pour l'instant : c'est la premiere chose que
## le cycle jour/nuit remplacera.
const SUN_ANGLE: Vector3 = Vector3(-52.0, -38.0, 0.0)
const SUN_ENERGY: float = 1.0

## Ambiante prise du ciel. A 0,45 les faces detournees du soleil gardent leur
## teinte au lieu de virer au noir — le relief lointain parait bleute, et c'est
## la decision ouverte notee dans `nextsteps.md` §6.
const AMBIENT_ENERGY: float = 0.45

## Sans tonemapping, une surface claire — neige, sable — saturee par le soleil
## et le ciel deborde a 1.0 et perd toute sa teinte.
const TONEMAP_WHITE: float = 4.0

const FOG_COLOR: Color = Color(0.72, 0.80, 0.90)
const FOG_DENSITY: float = 0.0016

var sun: DirectionalLight3D
var environment: Environment


func _ready() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = SUN_ANGLE
	sun.light_energy = SUN_ENERGY
	sun.shadow_enabled = true
	add_child(sun)

	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = AMBIENT_ENERGY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = TONEMAP_WHITE
	environment.fog_enabled = true
	environment.fog_light_color = FOG_COLOR
	environment.fog_density = FOG_DENSITY

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = environment
	add_child(we)
