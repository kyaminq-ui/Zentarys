class_name CWPlayerBody
extends Node3D

## Le personnage de reference, assemble a partir de six pieces separees et
## anime proceduralement — la marche n'a que deux etats (l'amble et l'arret),
## et une fonction de la vitesse et de la phase en dit assez pour ne pas avoir
## besoin d'un `AnimationPlayer`.
##
## -- Les six pieces, et pourquoi ce n'est plus quatre ------------------------
##
## Le premier personnage (jalon 3.1, deuxieme tranche) etait quatre `.vox` bruts
## repeints dans la palette du projet, un bras et une jambe mirroirs pour
## l'autre cote. Celui-ci vient d'un export MagicaVoxel en `.obj` — bras, jambe,
## tete, torse, **et chaque cote existe sur le disque** (`arm_l`/`arm_r`,
## `leg_l`/`leg_r`) : plus de reflet de noeud a calculer.
##
## L'export MagicaVoxel garde les six pieces dans **un seul repere partage** —
## on le voit aux sommets: une jambe va de `y=0` (le sol) a `y=0.3`, le torse
## juste au-dessus, la tete au-dessus du torse, les bras a hauteur d'epaule,
## chevauchant le haut du torse. Consequence : il n'y a **aucun offset a
## calculer entre les pieces**, seulement un point de pivot par articulation
## (haut de jambe, haut de bras, base du torse), pris directement dans la boite
## englobante de chacune (`Mesh.get_aabb()`).
##
## **Deux pieces font exception au repere partage.** Verifie a la capture (une
## camera posee devant plutot que derriere, `tools/_inspect_body_tmp.tscn`,
## jete apres usage) : la tete et le torse sortent de l'export tournes de 180
## degres sur le lacet par rapport aux quatre membres — un visage qui regarde
## vers +Z alors que `CWPlayerController` avance vers -Z. Les bras et les
## jambes n'ont pas ce defaut. Rien dans les sommets ne le signale a la
## lecture, seulement a l'image : deux objets d'une meme scene MagicaVoxel
## peuvent avoir chacun leur propre rotation au moment de l'export, sans que
## rien dans le fichier `.obj` ne le distingue d'une difference de modelisation
## voulue. `_attache(..., flip = true)` les corrige, chacun autour de son
## propre pivot plutot que de son centre — voir sa derivation.
##
## -- L'unite de l'export ------------------------------------------------------
##
## Les sommets sont des multiples exacts de 0,1 (`v 6.8 1 0.5`, jamais
## `6.83`) : c'est la convention de l'exportateur `.obj` de MagicaVoxel, un
## dixieme d'unite par voxel. `SCALE_BLOCS_PAR_UNITE_OBJ` la traduit en blocs de
## terrain via `CWVoxelModel.VOXELS_PER_BLOCK` (40/3), la meme grille fine que
## le reste du lot personnage/creatures. Applique une seule fois, en `scale` sur
## la racine — toutes les pieces partagent le meme repere, la mise a l'echelle
## n'a donc besoin d'etre ecrite qu'un seul endroit.
##
## -- La texture est un damier de palette, pas une photo -----------------------
##
## Chaque `.png` est une bande de 256x1 : un texel par index de la palette
## MagicaVoxel de la piece, et les UV du `.obj` tombent exactement au centre de
## chaque texel (`(i+0,5)/256`). Sans ça le filtrage lineaire lirait juste, mais
## les mipmaps generes a l'import moyennent des texels voisins des la premiere
## reduction — deux couleurs de la palette qui se meraient des qu'on s'eloigne
## un peu. `TEXTURE_FILTER_NEAREST` ignore les mipmaps a la lecture : c'est ce
## qui garde le personnage net a distance, pas seulement au premier plan.
##
## -- L'amble --------------------------------------------------------------
##
## La phase avance avec la **distance parcourue**, pas le temps
## (`horizontal_speed * delta`) : un pas revient toujours a la meme ouverture
## de jambe au meme endroit sous le pied, quelle que soit la vitesse — un
## simple `sin(temps)` ferait patiner les appuis des qu'on accelere. Bras et
## jambe opposes montent ensemble, comme une vraie marche.

const DOSSIER: String = "res://assets/models/personnage/human/"

## Un dixieme d'unite `.obj` par voxel — mesure sur les sommets, voir plus haut.
const OBJ_UNITS_PAR_VOXEL: float = 0.1
## Blocs par unite `.obj` : `1 / (OBJ_UNITS_PAR_VOXEL * VOXELS_PER_BLOCK)`, soit
## 0,75 avec la grille fine du personnage (40/3). Applique une seule fois, sur
## `self.scale`.
const SCALE_BLOCS_PAR_UNITE_OBJ: float = \
		1.0 / (OBJ_UNITS_PAR_VOXEL * CWVoxelModel.VOXELS_PER_BLOCK)

## Amplitude de l'amble a vitesse de reference, en radians.
const STRIDE_AMPLITUDE: float = 0.55
## Radians de phase par bloc parcouru — la « frequence » du pas.
const STRIDE_RATE: float = 2.4
## Vitesse, en blocs/s, au-dela de laquelle l'amplitude ne monte plus : sans
## plafond, un sprint ferait des moulinets.
const STRIDE_SPEED_REF: float = 6.0
## En dessous de cette vitesse, on est a l'arret : sans seuil, le bruit de la
## physique (un `velocity` qui ne tombe jamais exactement a zero) ferait
## trembler les membres au repos.
const STRIDE_MIN_SPEED: float = 0.05

## Vitesse du fondu marche <-> repos, en unites de melange par seconde (donc
## un aller-retour complet en 1/BLEND_SPEED secondes). Sans lui, s'arreter au
## milieu d'une enjambee ramenait les membres a zero d'une image sur l'autre —
## visible des qu'on relachait ZQSD en cours de foulee.
const BLEND_SPEED: float = 4.0

## Amplitude et frequence du balancement au repos — une respiration, pas une
## marche.
const IDLE_AMPLITUDE: float = 0.03
const IDLE_HZ: float = 0.35

## Rebond vertical du torse, en blocs : le poids du corps qui retombe a chaque
## appui, pas seulement les membres qui pendent. Deux fois par foulee (un par
## pied), d'ou `absf(sin(phase))` plutot que `sin(phase)` dans `animate` — un
## signe qui ne changerait pas selon le pied porteur ferait bondir le torse
## d'un seul cote de sa foulee sur deux.
const BOB_AMPLITUDE: float = 0.05

var _left_hip: Node3D
var _right_hip: Node3D
var _left_shoulder: Node3D
var _right_shoulder: Node3D
var _torso_pivot: Node3D
## Hauteur de repos du pivot de torse : `animate` y ajoute le rebond plutot que
## de l'y remplacer, sans quoi chaque image effacerait la position de depart.
var _torso_base_y: float = 0.0

var _phase: float = 0.0
var _idle_t: float = 0.0
## 0 a l'arret, 1 en marche : fondu plutot que bascule, voir `BLEND_SPEED`.
var _walk_blend: float = 0.0


func _init() -> void:
	var mesh_head: Mesh = _load_piece("character_human-2-head.obj")
	var mesh_chest: Mesh = _load_piece("character_human-3-chest.obj")
	var mesh_arm_l: Mesh = _load_piece("character_human-0-arm_l.obj")
	var mesh_arm_r: Mesh = _load_piece("character_human-4-arm_r.obj")
	var mesh_leg_l: Mesh = _load_piece("character_human-5-leg_l.obj")
	var mesh_leg_r: Mesh = _load_piece("character_human-1-leg_r.obj")
	if mesh_head == null or mesh_chest == null or mesh_arm_l == null \
			or mesh_arm_r == null or mesh_leg_l == null or mesh_leg_r == null:
		push_error("CWPlayerBody: piece manquante dans " + DOSSIER)
		return

	scale = Vector3.ONE * SCALE_BLOCS_PAR_UNITE_OBJ

	# Centre horizontal partage par les six pieces, calcule sur leurs boites
	# englobantes : c'est ce qui fait tomber l'axe de lacet du personnage au
	# milieu du corps plutot qu'au coin du repere de l'export.
	var aabbs: Array[AABB] = [mesh_head.get_aabb(), mesh_chest.get_aabb(),
			mesh_arm_l.get_aabb(), mesh_arm_r.get_aabb(),
			mesh_leg_l.get_aabb(), mesh_leg_r.get_aabb()]
	var center: Vector3 = _horizontal_center(aabbs)

	# Points de pivot, releves dans le repere brut de l'export (voir l'en-tete
	# du fichier) : le haut d'une jambe ou d'un bras est son articulation, la
	# base du torse celle du balancement au repos.
	var torso_raw: Vector3 = _bottom_center(mesh_chest.get_aabb())
	var left_hip_raw: Vector3 = _top_center(mesh_leg_l.get_aabb())
	var right_hip_raw: Vector3 = _top_center(mesh_leg_r.get_aabb())
	var left_shoulder_raw: Vector3 = _top_center(mesh_arm_l.get_aabb())
	var right_shoulder_raw: Vector3 = _top_center(mesh_arm_r.get_aabb())

	var hips := Node3D.new()
	hips.name = "Hips"
	add_child(hips)

	_torso_pivot = _pivot(hips, "TorsoPivot", torso_raw - center)
	_torso_base_y = _torso_pivot.position.y
	# `true` : tete et torse sortent de l'export tournes de 180 degres sur le
	# lacet, seuls parmi les six pieces — un visage qui regarde vers +Z quand
	# `CWPlayerController` avance vers -Z. Voir l'en-tete du fichier.
	_attache(_torso_pivot, mesh_chest, torso_raw, true)
	_attache(_torso_pivot, mesh_head, torso_raw, true)

	_left_shoulder = _pivot(_torso_pivot, "LeftShoulder",
			left_shoulder_raw - torso_raw)
	_attache(_left_shoulder, mesh_arm_l, left_shoulder_raw)
	_right_shoulder = _pivot(_torso_pivot, "RightShoulder",
			right_shoulder_raw - torso_raw)
	_attache(_right_shoulder, mesh_arm_r, right_shoulder_raw)

	_left_hip = _pivot(hips, "LeftHip", left_hip_raw - center)
	_attache(_left_hip, mesh_leg_l, left_hip_raw)
	_right_hip = _pivot(hips, "RightHip", right_hip_raw - center)
	_attache(_right_hip, mesh_leg_r, right_hip_raw)


static func _load_piece(file_name: String) -> Mesh:
	var mesh: Mesh = load(DOSSIER + file_name)
	if mesh == null:
		return null
	# Le filtrage nearest evite que les mipmaps de la bande de palette (256x1)
	# ne moyennent deux couleurs voisines a distance — voir l'en-tete.
	for i in mesh.get_surface_count():
		var mat: Material = mesh.surface_get_material(i)
		if mat is BaseMaterial3D:
			(mat as BaseMaterial3D).texture_filter = \
					BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mesh


static func _horizontal_center(aabbs: Array[AABB]) -> Vector3:
	var min_x: float = aabbs[0].position.x
	var max_x: float = aabbs[0].end.x
	var min_z: float = aabbs[0].position.z
	var max_z: float = aabbs[0].end.z
	for a in aabbs:
		min_x = minf(min_x, a.position.x)
		max_x = maxf(max_x, a.end.x)
		min_z = minf(min_z, a.position.z)
		max_z = maxf(max_z, a.end.z)
	return Vector3((min_x + max_x) * 0.5, 0.0, (min_z + max_z) * 0.5)


static func _top_center(a: AABB) -> Vector3:
	return Vector3(a.position.x + a.size.x * 0.5, a.end.y,
			a.position.z + a.size.z * 0.5)


static func _bottom_center(a: AABB) -> Vector3:
	return Vector3(a.position.x + a.size.x * 0.5, a.position.y,
			a.position.z + a.size.z * 0.5)


static func _pivot(parent: Node3D, n: String, at: Vector3) -> Node3D:
	var p := Node3D.new()
	p.name = n
	p.position = at
	parent.add_child(p)
	return p


## Pose `mesh` sous le pivot `p`. `raw` est le point de pivot dans le repere
## brut de l'export : puisque les sommets du maillage portent deja leur
## position absolue dans ce repere, reculer le maillage de `-raw` fait tomber
## l'articulation exactement sur l'origine de `p`, quel que soit le nombre de
## pivots parents traverses — voir l'en-tete du fichier pour la derivation.
##
## `flip` tourne le maillage de 180 degres sur le lacet, **autour du meme
## pivot** plutot qu'autour de son propre centre : la formule generale de
## rotation autour d'un point (`R*(p - pivot)`, exprimee comme un
## `Transform3D`) donne `position = -R*raw` au lieu de `-raw`, et seul `y`
## survit a `R` puisque c'est une rotation sur l'axe vertical.
static func _attache(p: Node3D, mesh: Mesh, raw: Vector3,
		flip: bool = false) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if flip:
		mi.rotation.y = PI
		mi.position = Vector3(raw.x, -raw.y, raw.z)
	else:
		mi.position = -raw
	p.add_child(mi)


## Anime le corps pour l'image courante. `horizontal_speed` est la norme de la
## vitesse horizontale du controleur, en blocs/s — c'est elle qui decide de
## l'amble contre le repos, et de son amplitude.
##
## Marche et repos ne sont plus deux etats qui se remplacent d'une image sur
## l'autre : `_walk_blend` fond de l'un a l'autre (`BLEND_SPEED`), et les deux
## jeux de rotations se superposent, ponderes par ce fondu plutot que choisis
## par un `if`. Sans ca, relacher ZQSD au milieu d'une enjambee ramenait les
## membres a zero d'une image sur l'autre — un arret plus raide que le pas qui
## le precedait.
func animate(delta: float, horizontal_speed: float) -> void:
	var walking: bool = horizontal_speed > STRIDE_MIN_SPEED
	_walk_blend = move_toward(_walk_blend, 1.0 if walking else 0.0,
			delta * BLEND_SPEED)
	# La phase ne tourne que pendant l'appui : geler la foulee a l'arret est ce
	# qui la fait reprendre exactement ou elle s'est interrompue, plutot que de
	# sauter en avant pendant que le fondu efface un mouvement qui a continue
	# de courir dans le vide.
	if walking:
		_phase += delta * horizontal_speed * STRIDE_RATE

	var speed_ratio: float = clampf(horizontal_speed / STRIDE_SPEED_REF, 0.0, 1.0)
	var amp: float = STRIDE_AMPLITUDE * speed_ratio * _walk_blend
	var swing: float = sin(_phase) * amp
	_left_hip.rotation.x = swing
	_right_hip.rotation.x = -swing
	# Le bras oppose a la jambe qui avance : une vraie marche, pas un pantin
	# qui balance tout du meme cote.
	_left_shoulder.rotation.x = -swing
	_right_shoulder.rotation.x = swing

	# Le rebond du torse : un pic par appui, donc le double de la frequence de
	# la foulee. `absf(sin)` fait ce doublement sans deuxieme compteur de
	# phase ; centre sur zero (`- 0.5`) pour rebondir des deux cotes du repos
	# plutot que de ne faire que descendre.
	var bob: float = (absf(sin(_phase)) - 0.5) * 2.0 * BOB_AMPLITUDE \
			* speed_ratio * _walk_blend
	_torso_pivot.position.y = _torso_base_y + bob

	# Le balancement au repos tourne toujours, meme en pleine foulee : geler
	# `_idle_t` a la reprise de la marche, comme le faisait la version
	# precedente, rendait sa phase a l'arret suivant imprevisible d'une pause a
	# l'autre — un a-coup que le fondu de `_walk_blend` ne masque pas puisqu'il
	# porte sur l'amplitude, pas sur la phase.
	_idle_t += delta
	_torso_pivot.rotation.z = sin(_idle_t * TAU * IDLE_HZ) * IDLE_AMPLITUDE \
			* (1.0 - _walk_blend)
