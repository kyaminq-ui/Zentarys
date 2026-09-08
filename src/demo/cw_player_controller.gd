class_name CWPlayerController
extends CharacterBody3D

## Le joueur physique : gravite, marche, saut, collision contre le terrain.
##
## -- Pourquoi c'est invente, et pas porte -------------------------------------
##
## Le jalon 3.1 vise `control/GameController.cpp` de la source, mais la
## fonction qui y fait autorité pour le mouvement est `vfunc_10` — la plus
## grosse fonction du binaire entier (77 Ko de pseudo-code Ghidra), et elle
## mélange indissociablement le deplacement, les menus, l'inventaire et
## l'artisanat en une seule mise a jour par image. Il n'y a pas de sous-bloc
## « physique du joueur » a en extraire : c'est un agregat, pas une fonction.
##
## Comme le reseau de chemins au jalon 1.16, c'est donc une decision de ce
## projet et non une extraction : *une chose absente d'une source exploitable
## n'est pas hors perimetre, elle est a decider.* Les constantes de vitesse, de
## gravite et de hauteur de saut ci-dessous n'ont donc pas de source a citer —
## ce sont des choix de sensation de jeu, a revoir au clavier plutot qu'au banc.
##
## -- Ce que ça remplace, et ce que ça n'efface pas ----------------------------
##
## La camera libre (`TerrainDemo._build_flycam`) reste le comportement par
## defaut : tous les outils de capture (`--ici`, `--vers`, `--regard`, la
## teleportation de biome) la pilotent a la main, sans physique. Ce controleur
## est un second mode, choisi par `--joueur`, qui remplace la camera libre par
## un `CharacterBody3D` — la seule difference vue du reste de la demo est que
## `TerrainDemo.camera` pointe vers l'enfant `camera` de ce noeud au lieu d'une
## camera libre.
##
## -- Le corps et la camera a la troisieme personne ----------------------------
##
## `CWPlayerBody` porte le personnage de reference — six pieces animees
## proceduralement, voir ce fichier. Le voir suppose une camera qui recule :
## elle est un enfant de `_pitch_pivot`, decalee de `CAMERA_DISTANCE` sur son
## propre axe +Z. Ce dernier pointe dans la direction opposee au regard du
## personnage (Godot avance vers -Z), donc un decalage positif la place bien
## **derriere** lui plutot que devant.
##
## Le lacet tourne le corps entier (`rotate_y`, sur `self`) ; le tangage ne
## tourne que `_pitch_pivot`, qui porte la camera — c'est lui, et non la
## camera, que `look` et `set_look_angles` inclinent.
##
## ⚠️ **Pas encore d'evitement de mur.** Un `SpringArm3D` raccourcirait la
## distance contre un obstacle ; ce premier morceau ne le fait pas, et la
## camera peut donc passer a travers le relief pres d'une paroi. C'est un
## defaut connu, pas un oubli — voir `nextsteps.md`.
##
## -- Franchir une marche, et lisser ce que ça secoue --------------------------
##
## `CharacterBody3D` ne franchit rien de lui-meme : sans aide, le bord d'un
## seul cube de terrain (un chemin, une bordure) arrete la capsule comme un
## mur. `_step_up`, appele juste avant `move_and_slide`, souleve le corps de
## `STEP_HEIGHT` **seulement** quand c'est ce qui manque pour avancer — voir sa
## derivation, elle explique pourquoi il faut trois essais et non un.
##
## Une marche franchie deplace le corps d'un bloc entier en une image, et la
## camera qui lui est rigidement attachee hériterait du meme a-coup.
## `_smooth_camera_height` fait donc suivre `_pitch_pivot` en hauteur avec un
## leger retard exponentiel plutot que rigidement, sauf ecart enorme (une
## teleportation de biome), qu'il cale au lieu de rattraper sur plusieurs
## secondes — voir `CAMERA_Y_SMOOTH_SPEED` et `CAMERA_Y_SNAP_THRESHOLD`.

## Hauteur de reference du personnage, en blocs : 32 voxels a la grille fine de
## 40/3 (`docs/ASSETS.md`), donc 32 * 3/40 = 2,4 blocs.
const HEIGHT: float = 2.4
const RADIUS: float = 0.35

## Assiette de la camera, en radians. Bornee comme celle de la camera libre :
## une tete qui regarde plus haut que 1,5 radian (86°) part en arriere.
const PITCH_LIMIT: float = 1.5

## Recul de la camera, en blocs, et hauteur du pivot de tangage — a hauteur
## d'epaule plutot que d'oeil, pour cadrer le personnage entier et non son
## seul crane.
const CAMERA_DISTANCE: float = 4.5
const CAMERA_PIVOT_HEIGHT_RATIO: float = 0.78

## Hauteur de marche franchissable sans sauter, en blocs : un peu plus qu'un
## cube de terrain, l'obstacle le plus courant contre une capsule qui glisse
## au sol (bord de chemin, rebord d'un bloc). `CharacterBody3D` ne sait pas
## franchir de marche seul — `_step_up` le fait a la main, voir sa derivation.
const STEP_HEIGHT: float = 1.05

## Taux de rattrapage de la hauteur de camera, en 1/s (une constante de temps
## de `1 / CAMERA_Y_SMOOTH_SPEED`, ~0,1 s ici). `_smooth_camera_height` fait
## suivre le pivot de tangage a la hauteur de tete **avec retard** plutot que
## rigidement : une marche franchie d'un coup par `_step_up`, ou un bord de
## relief pris en marchant, deplacent le corps d'un bloc entier en une image,
## et une camera rivee dessus donne un a-coup sec. Assez rapide pour rester
## invisible en vol libre (chute, saut), assez lent pour lisser un pas.
const CAMERA_Y_SMOOTH_SPEED: float = 10.0

## Au-dela de cet ecart, en blocs, `_smooth_camera_height` cale au lieu de
## rattraper : une teleportation de biome ou `--ici` deplace le corps de
## plusieurs centaines de blocs d'une image sur l'autre, et un rattrapage a
## `CAMERA_Y_SMOOTH_SPEED` mettrait alors plusieurs secondes a suivre — visible
## comme une camera qui reste plantee au sol pendant que le corps est deja
## arrive. Une marche (`STEP_HEIGHT`) et une pente restent tres en dessous.
const CAMERA_Y_SNAP_THRESHOLD: float = 3.0

@export var walk_speed: float = 6.0
@export var sprint_multiplier: float = 1.8
@export var mouse_sensitivity: float = 0.0022
@export var gravity: float = 28.0
## Hauteur du saut, en blocs. La vitesse de depart s'en deduit a `_ready` :
## `v = sqrt(2 * gravite * hauteur)` est l'equation du tir vertical, pas un
## reglage a part — changer la gravite sans y toucher garde le meme saut.
@export var jump_height: float = 1.2

## Portee de la sonde de sol, en blocs : toute la hauteur jouable du monde
## (`TerrainDemo.WORLD_Y_MIN` a `WORLD_Y_MAX`), pour ne jamais confondre « rien
## en dessous parce que rien n'a encore charge » avec « rien en dessous, vraie
## chute ». Duplique la constante plutot que d'en dependre : ce fichier ne sait
## rien de la demo qui le pose.
const FLOOR_PROBE_DISTANCE: float = 1100.0

var camera: Camera3D
var body: CWPlayerBody

var _pitch_pivot: Node3D

var _pitch: float = 0.0
var _jump_velocity: float = 0.0
## Hauteur monde suivie par `_smooth_camera_height`. Part a 0.0 sans reglage
## special a `_ready` : le premier ecart, contre le vrai point d'apparition,
## depasse `CAMERA_Y_SNAP_THRESHOLD` et se resout donc par un calage immediat,
## pas par un rattrapage visible qui partirait du sol.
var _camera_smoothed_y: float = 0.0


func _init() -> void:
	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var capsule := CapsuleShape3D.new()
	capsule.height = HEIGHT
	capsule.radius = RADIUS
	shape.shape = capsule
	shape.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	add_child(shape)

	body = CWPlayerBody.new()
	body.name = "Body"
	add_child(body)

	_pitch_pivot = Node3D.new()
	_pitch_pivot.name = "PitchPivot"
	_pitch_pivot.position = Vector3(0.0, HEIGHT * CAMERA_PIVOT_HEIGHT_RATIO, 0.0)
	add_child(_pitch_pivot)

	camera = Camera3D.new()
	camera.name = "PlayerCamera"
	camera.fov = 72.0
	camera.position = Vector3(0.0, 0.0, CAMERA_DISTANCE)
	_pitch_pivot.add_child(camera)


func _ready() -> void:
	_jump_velocity = sqrt(2.0 * gravity * jump_height)


## Oriente le regard par une souris relative : lacet sur le corps, tangage sur
## le pivot de la perche — un corps qui tanguerait inclinerait la capsule de
## collision, et une capsule couchee ne glisse plus sur le sol comme un
## personnage debout.
func look(relative: Vector2) -> void:
	rotate_y(-relative.x * mouse_sensitivity)
	_pitch = clampf(_pitch - relative.y * mouse_sensitivity,
			-PITCH_LIMIT, PITCH_LIMIT)
	_pitch_pivot.rotation.x = _pitch


## Pose le regard a des angles connus — `--regard`, `--vers`, la teleportation
## de biome. Meme decoupe que `look` : le lacet tourne le corps, le tangage ne
## tourne que le pivot de la perche.
func set_look_angles(pitch: float, yaw: float) -> void:
	rotation.y = yaw
	_pitch = clampf(pitch, -PITCH_LIMIT, PITCH_LIMIT)
	_pitch_pivot.rotation.x = _pitch


## L'inverse de `set_look_angles` : x le tangage, y le lacet. Sert a rendre la
## camera libre a l'endroit ou le joueur regardait quand `TerrainDemo` bascule
## hors de `player_mode` en jeu (touche F5) — sans elle la camera libre
## reapparaitrait droit devant plutot que dans la direction du regard.
func look_angles() -> Vector2:
	return Vector2(_pitch, rotation.y)


## -- Le vide n'est pas toujours une chute --------------------------------------
##
## Au moment ou le joueur apparait, le terrain n'a pas encore charge la
## collision de la colonne sous ses pieds — elle vient avec le maillage, qui
## met un instant a se generer. Sans garde, la gravite tombe alors dans un
## vide qui n'existe que le temps du chargement, l'observateur de vue suit la
## chute, et le terrain se met a charger la colonne *d'arrivee* au lieu de
## celle de depart : la chute s'auto-alimente et ne s'arrete qu'au sol reel,
## loin en dessous. On distingue donc « rien en dessous parce que le monde n'a
## pas encore charge » de « rien en dessous, vraie chute » par une sonde qui
## couvre toute la hauteur jouable : si elle ne trouve rien du tout, ce n'est
## pas une chute, c'est un chargement.
func _floor_within_reach() -> bool:
	var space := get_world_3d().direct_space_state
	var from: Vector3 = global_position
	var query := PhysicsRayQueryParameters3D.create(
			from, from + Vector3(0.0, -FLOOR_PROBE_DISTANCE, 0.0))
	return not space.intersect_ray(query).is_empty()


## Souleve le corps de `STEP_HEIGHT` avant `move_and_slide`, mais seulement si
## c'est ce qui manque pour avancer : bloque au ras du sol, degage une fois
## leve, et le mouvement qui suit passe la-haut. Sans ce dernier essai, une
## vraie paroi — plus haute que `STEP_HEIGHT` — ferait quand meme monter le
## corps en vain a chaque image ou il la touche, avant de retomber dessus.
##
## Pas de sonde vers le bas apres coup : `move_and_slide`, appele juste apres
## avec le corps deja souleve, raccroche de lui-meme au sol qu'il retrouve
## sous les pieds (`floor_snap_length` par defaut) — la marche franchie n'a
## besoin de rien de plus.
func _step_up(motion: Vector3) -> void:
	if motion == Vector3.ZERO or not is_on_floor():
		return
	if not test_move(global_transform, motion):
		return
	var raised: Transform3D = global_transform
	raised.origin.y += STEP_HEIGHT
	if test_move(raised, Vector3.ZERO):
		return
	if test_move(raised, motion):
		return
	global_position.y += STEP_HEIGHT


## Fait suivre `_pitch_pivot` a la hauteur de tete avec un retard exponentiel
## plutot que rigidement : voir `CAMERA_Y_SMOOTH_SPEED` et
## `CAMERA_Y_SNAP_THRESHOLD` pour ce qu'il lisse et ce qu'il laisse cingler.
func _smooth_camera_height(delta: float) -> void:
	var target_y: float = global_position.y + HEIGHT * CAMERA_PIVOT_HEIGHT_RATIO
	if absf(target_y - _camera_smoothed_y) > CAMERA_Y_SNAP_THRESHOLD:
		_camera_smoothed_y = target_y
	else:
		_camera_smoothed_y = lerp(_camera_smoothed_y, target_y,
				1.0 - exp(-CAMERA_Y_SMOOTH_SPEED * delta))
	_pitch_pivot.position.y = _camera_smoothed_y - global_position.y


func _physics_process(delta: float) -> void:
	if not is_on_floor() and not _floor_within_reach():
		velocity = Vector3.ZERO
		return

	if is_on_floor():
		if Input.is_key_pressed(KEY_SPACE):
			velocity.y = _jump_velocity
		else:
			velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		dir -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		dir += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		dir -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		dir += transform.basis.x
	dir.y = 0.0

	var speed: float = walk_speed
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= sprint_multiplier
	var horizontal: Vector3 = dir.normalized() * speed if dir != Vector3.ZERO \
			else Vector3.ZERO
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	_step_up(Vector3(velocity.x, 0.0, velocity.z) * delta)
	move_and_slide()
	_smooth_camera_height(delta)

	body.animate(delta, Vector2(velocity.x, velocity.z).length())
