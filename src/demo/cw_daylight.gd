class_name CWDaylight
extends Node3D

## Le ciel, le soleil et le brouillard — et le cycle jour/nuit qui les fait
## varier ensemble.
##
## -- Un seul point d'entree, et c'est la seule chose a retenir -----------------
##
## Tout se deduit d'un **scalaire d'heure** dans `[0, 1)` par la seule fonction
## `applique`. Rien d'autre dans le projet ne touche au soleil, au ciel ou au
## brouillard.
##
## C'est une contrainte, pas une commodite. Si l'angle du soleil se reglait ici
## et la couleur du brouillard ailleurs, **l'aube aurait un ciel rose et un
## brouillard bleu** — et le defaut ne se verrait qu'a l'aube, c'est-a-dire
## rarement et tard. Toute grandeur qui depend de l'heure se calcule donc dans
## cette fonction, ou nulle part.
##
## > **Et c'est pourquoi les nuages n'apparaissent plus ici.** On y trouvait
## > `cloud_lit`, `cloud_shade` et `cloud_cover`, du temps ou les nuages etaient
## > un bruit fractal dans le ciel : une couleur simulee a la main devait bien
## > se regler quelque part, et cet endroit-ci etait le bon. Depuis qu'ils sont
## > des **modeles voxels instancies** (`CWClouds`), leur teinte est celle du
## > soleil que cette fonction regle deja — donc la regle tient toujours, sans
## > une ligne pour la porter. Ajouter ici un second reglage de teinte des
## > nuages rouvrirait exactement le defaut que la regle interdit.
##
## Le repere : `0.0` minuit, `0.25` lever, `0.5` midi, `0.75` coucher.
##
## -- Ce que le voxel cuit devient ----------------------------------------------
##
## `CWLight` est un eclairage **cuit** : la passe A descend la lumiere colonne
## par colonne, la passe B diffuse seize fois a l'horizontale, et le resultat est
## ecrit dans le canal de couleur du voxel a la generation. Il ne suit pas le
## `DirectionalLight3D`, et un recuit est hors de question — 7 ms pour un pave de
## 33³, sur chaque pave visible, a chaque minute de jeu.
##
## La lecture qui marche, et c'est celle qu'on adopte : **le voxel cuit est un
## terme d'occlusion, pas une heure.** Il dit *ce recoin est abrite*, ce qui
## reste vrai la nuit ; c'est la lumiere de la scene qui porte le cycle. Cela
## tient parce que le terrain **genere** ne passe jamais par `CWLight` — un champ
## de hauteurs est eclaire partout ou on le voit —, donc ses voxels portent leur
## couleur pleine et s'assombrissent avec le soleil et l'ambiante comme n'importe
## quelle surface. Seul ce que le joueur a creuse porte de l'ombre cuite, et une
## ombre reste une ombre a toute heure.
##
## -- Le brouillard, et pourquoi il est ici --------------------------------------
##
## Sa densite cache le bord de la vue chargee. Elle se regle donc **contre la
## distance de vue**, et elle varie avec l'heure — une nuit est plus opaque
## qu'un midi. Les deux raisons la mettent dans `applique` et non dans une
## constante d'environnement.
##
## > ⚠️ **Elle est reglee pour une vue de 384 blocs.** Augmenter la distance sans
## > reprendre `FOG_DENSITY_*` rend le lointain laiteux bien avant son bord.

const SKY_SHADER: String = "res://src/demo/cw_sky.gdshader"

## Duree d'un jour complet, en secondes de jeu.
##
## **Quarante minutes depuis le 2026-09-11, contre douze auparavant.** Douze
## minutes etaient le reglage d'un cycle qu'on venait d'ecrire et qu'on voulait
## voir tourner ; a l'usage, le soleil traversait le ciel le temps d'aller
## regarder un biome, et une capture prise trois minutes apres une autre n'etait
## plus a la meme heure. Vingt minutes de jour et vingt de nuit laissent une
## traversee de vallee se faire a heure a peu pres constante.
##
## Ce que le ralentissement aurait coute sans les bascules : rien ne se regle a
## l'oeil sur un cycle lent — attendre une aube prendrait dix minutes. C'est
## exactement pourquoi `--heure h` et les touches F2/F3/F4 existaient avant lui.
const DAY_LENGTH: float = 2400.0

## Pas d'un coup de touche sur l'heure : une heure de jeu sur vingt-quatre.
##
## **Regarder une aube en temps reel n'est pas une methode de reglage** : sans
## cette touche, verifier une teinte de crepuscule coute neuf minutes d'attente.
const HOUR_STEP: float = 1.0 / 24.0

# -- Le soleil ----------------------------------------------------------------

## Azimut au lever, en degres, et course sur un jour complet. Le soleil se leve
## a l'est et se couche a l'ouest ; il continue sa course sous l'horizon, ou
## personne ne le regarde mais ou sa direction sert encore au ciel.
const SUN_AZIMUTH_DAWN: float = 90.0
const SUN_ENERGY_DAY: float = 1.05
## La nuit garde une lueur — sans elle, le relief devient une silhouette noire
## et on ne se deplace plus. C'est une lune, et elle est assumee comme telle.
const SUN_ENERGY_NIGHT: float = 0.06
const SUN_COLOR_NOON: Color = Color(1.00, 0.98, 0.94)
const SUN_COLOR_HORIZON: Color = Color(1.00, 0.62, 0.34)
const SUN_COLOR_NIGHT: Color = Color(0.55, 0.66, 0.95)

# -- Le ciel ------------------------------------------------------------------

const ZENITH_DAY: Color = Color(0.24, 0.44, 0.80)
const ZENITH_NIGHT: Color = Color(0.03, 0.04, 0.10)
const HORIZON_DAY: Color = Color(0.72, 0.80, 0.90)
const HORIZON_NIGHT: Color = Color(0.06, 0.08, 0.16)
## La bande chaude de l'aube et du crepuscule, qui ne dure qu'un instant de part
## et d'autre de l'horizon.
const HORIZON_TWILIGHT: Color = Color(0.95, 0.48, 0.26)
const GROUND_DAY: Color = Color(0.30, 0.31, 0.33)
const GROUND_NIGHT: Color = Color(0.04, 0.05, 0.07)

# -- L'ambiante et le brouillard ----------------------------------------------

## Ambiante prise du ciel. A 0,45 de jour, les faces detournees du soleil gardent
## leur teinte au lieu de virer au noir.
const AMBIENT_DAY: float = 0.45
const AMBIENT_NIGHT: float = 0.05

## Sans tonemapping, une surface claire — neige, sable — saturee par le soleil et
## le ciel deborde a 1.0 et perd toute sa teinte.
const TONEMAP_WHITE: float = 4.0

const FOG_DAY: Color = Color(0.72, 0.80, 0.90)
const FOG_NIGHT: Color = Color(0.05, 0.07, 0.13)
const FOG_TWILIGHT: Color = Color(0.85, 0.52, 0.36)
const FOG_DENSITY_DAY: float = 0.0016
## Une nuit mange le lointain plus vite qu'un midi. A peine : au-dela, le
## brouillard cesse d'etre de l'air et devient un mur.
const FOG_DENSITY_NIGHT: float = 0.0026

## Part du **ciel** que le brouillard repeint.
##
## -- Le defaut de Godot est 1.0, et il annulait tout ce fichier ---------------
##
## A un, le brouillard recouvre le ciel entier de sa propre couleur : le degrade,
## les nuages et le disque du soleil disparaissent sous un aplat gris-bleu. La
## premiere capture de midi a rendu exactement cela — un ciel plat, et pas une
## trace des nuages qu'on venait d'ecrire —, alors que la capture de minuit
## montrait le degrade, simplement parce qu'a cette heure-la le brouillard est de
## la meme couleur que le ciel qu'il cachait. **Un defaut qui se voit le jour et
## pas la nuit ressemble a un bug de shader ; c'en etait un de reglage.**
##
## A 0,18, la bande d'horizon se fond encore dans le lointain — c'est tout ce
## qu'on lui demandait — et le haut du ciel garde son degrade.
##
## > C'est aussi la mesure de ce que les nuages voxels devaient echapper : le
## > ciel ne prend que 18 % du brouillard, un objet en prendrait 100 %. D'ou
## > `CWPalette.build_cloud_material`, et son `disable_fog`.
const FOG_SKY_AFFECT: float = 0.18

## Diffusion du soleil dans le brouillard : le halo chaud autour de l'astre
## rasant. Fort au crepuscule, discret a midi, nul la nuit — c'est ce qui fait
## qu'une aube se voit **dans le paysage** et pas seulement dans le ciel.
const FOG_SCATTER_DAY: float = 0.12
const FOG_SCATTER_TWILIGHT: float = 0.55


## L'heure, dans `[0, 1)`. 0 minuit, 0,25 lever, 0,5 midi, 0,75 coucher.
@export_range(0.0, 1.0, 0.001) var hour: float = 0.32:
	set(value):
		hour = fposmod(value, 1.0)
		if is_inside_tree():
			applique()

## Duree d'un jour complet, en secondes. Zero ou moins fige le cycle.
@export var day_length: float = DAY_LENGTH

## Fige le cycle sans perdre la duree du jour. Touche **F2**.
@export var paused: bool = false

var sun: DirectionalLight3D
var environment: Environment
var _sky_material: ShaderMaterial


func _ready() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	add_child(sun)

	_sky_material = ShaderMaterial.new()
	var sh: Shader = load(SKY_SHADER)
	if sh != null:
		_sky_material.shader = sh
	else:
		push_warning("[ciel] %s introuvable : ciel nu" % SKY_SHADER)

	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = _sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = TONEMAP_WHITE
	environment.fog_enabled = true
	environment.fog_sky_affect = FOG_SKY_AFFECT

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = environment
	add_child(we)

	applique()


func _process(delta: float) -> void:
	if paused or day_length <= 0.0:
		return
	hour = fposmod(hour + delta / day_length, 1.0)


## Avance l'heure d'un pas, dans un sens ou dans l'autre. Touches **F3** et
## **F4** : c'est ce qui rend une aube reglable.
func avance(pas: float) -> void:
	hour = fposmod(hour + pas, 1.0)


## L'heure telle qu'on la lit, `hh:mm`, pour l'ATH.
func horloge() -> String:
	var t: float = hour * 24.0
	var hh: int = int(t)
	return "%02d:%02d" % [hh, int((t - float(hh)) * 60.0)]


## Hauteur du soleil sur l'horizon, dans `[-1, 1]`. Positive de jour.
func elevation() -> float:
	return sin((hour - 0.25) * TAU)


## **Le point unique.** Tout ce qui depend de l'heure se calcule ici.
func applique() -> void:
	if sun == null or environment == null:
		return
	var elev: float = elevation()

	# Trois facteurs, et tout le reste en decoule.
	#
	#   `jour`      1 en plein jour, 0 la nuit, avec une bande douce de part et
	#               d'autre de l'horizon ;
	#   `crepuscule` 1 quand le soleil rase l'horizon, 0 des qu'il s'en eloigne.
	#               C'est lui qui porte l'orange, et il faut qu'il soit **etroit**
	#               ou le ciel est chaud toute la journee ;
	#   `zenith`    1 au plus haut. Sert a blanchir le soleil de midi.
	var jour: float = smoothstep(-0.14, 0.16, elev)
	var crepuscule: float = 1.0 - smoothstep(0.0, 0.28, absf(elev))
	var zenith: float = smoothstep(0.05, 0.55, elev)

	# -- Le soleil -----------------------------------------------------------
	# L'assiette du soleil est son elevation, negative quand il plonge : le
	# `DirectionalLight3D` eclaire le long de son -Z, donc un `rotation.x` de
	# -90 degres le fait tomber a la verticale.
	sun.rotation_degrees = Vector3(
			-rad_to_deg(asin(clampf(elev, -1.0, 1.0))),
			SUN_AZIMUTH_DAWN + (hour - 0.25) * 360.0,
			0.0)
	var teinte: Color = SUN_COLOR_HORIZON.lerp(SUN_COLOR_NOON, zenith)
	sun.light_color = SUN_COLOR_NIGHT.lerp(teinte, jour)
	sun.light_energy = lerpf(SUN_ENERGY_NIGHT, SUN_ENERGY_DAY, jour)
	# Une lune ne porte pas d'ombres nettes, et les siennes clignotent au ras de
	# l'horizon quand le soleil passe dessous.
	sun.shadow_enabled = jour > 0.05

	# -- Le ciel -------------------------------------------------------------
	var horizon: Color = HORIZON_NIGHT.lerp(HORIZON_DAY, jour) \
			.lerp(HORIZON_TWILIGHT, crepuscule * 0.85)
	if _sky_material != null and _sky_material.shader != null:
		_sky_material.set_shader_parameter("zenith_color",
				ZENITH_NIGHT.lerp(ZENITH_DAY, jour))
		_sky_material.set_shader_parameter("horizon_color", horizon)
		_sky_material.set_shader_parameter("ground_color",
				GROUND_NIGHT.lerp(GROUND_DAY, jour))
		# Le halo suit l'energie du soleil, sinon il reste un disque blanc
		# accroche dans un ciel de nuit.
		_sky_material.set_shader_parameter("sun_strength",
				lerpf(0.15, 1.0, jour))

	# -- L'ambiante et le brouillard -----------------------------------------
	environment.ambient_light_energy = lerpf(AMBIENT_NIGHT, AMBIENT_DAY, jour)
	environment.fog_light_color = FOG_NIGHT.lerp(FOG_DAY, jour) \
			.lerp(FOG_TWILIGHT, crepuscule * 0.6)
	environment.fog_density = lerpf(FOG_DENSITY_NIGHT, FOG_DENSITY_DAY, jour)
	environment.fog_sun_scatter = lerpf(0.0,
			lerpf(FOG_SCATTER_DAY, FOG_SCATTER_TWILIGHT, crepuscule), jour)
