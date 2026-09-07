class_name CWClouds
extends Node3D

## La couche de nuages : des modeles voxels poses dans le ciel, a la maille du
## terrain (1 voxel = 1 bloc).
##
## -- Ce qui a change, et pourquoi ce n'est pas un reglage ----------------------
##
## Jusqu'au 2026-09-11 les nuages etaient un **bruit fractal dans le ciel**
## (`cw_sky.gdshader`) : pas de geometrie, pas de position, pas d'echelle. Ils
## sont maintenant des **objets a distance finie**, et les six consequences ne se
## deduisent pas les unes des autres :
##
## * **le brouillard les mangerait.** `fog_sky_affect` ne vaut que 0,18, donc le
##   ciel y echappe presque — mais un objet est de la geometrie et prend le
##   brouillard plein. A 0,0016 de densite, un nuage a quatre cents blocs garde
##   la moitie de sa couleur, et a mille blocs il est un aplat gris. Le remede
##   n'est pas de les rapprocher, ce qui ferait un plafond bas : c'est
##   `disable_fog` sur leur materiau (`CWPalette.build_cloud_material`). **Un
##   nuage appartient au ciel, et le ciel ne prend que 18 % du brouillard** ;
## * **ils ne sont pas ecrits dans les donnees voxels.** Un nuage estampe serait
##   creusable, il casserait le chemin rapide « bloc entierement vide » de
##   `_generate_block` sur toute la hauteur du ciel, et il faudrait le faire
##   connaitre a `generated_voxel` (invariant n. 39). Ils sont instancies, comme
##   la flore et les houppiers ;
## * **la lumiere est gratuite et juste.** Un nuage de geometrie eclaire par le
##   soleil rasant prend le lisere chaud de l'aube tout seul, sans qu'aucune
##   couleur soit calculee ici. C'est ce que le shader simulait a la main avec
##   `cloud_lit` et `cloud_shade`, qui ont disparu avec lui.
##
##   > **C'est aussi ce qui garde la regle du point d'entree unique.** On
##   > pourrait chercher dans `CWDaylight.applique` la ligne qui teinte les
##   > nuages : il n'y en a pas, et il ne doit pas y en avoir. La teinte des
##   > nuages est celle du **soleil**, que `applique` regle deja ; en ajouter une
##   > seconde ici rendrait possible exactement ce que la regle interdit — une
##   > aube au ciel rose et aux nuages bleus ;
## * **les ombres sont coupees, et c'est un arbitrage, pas un oubli.** Voir
##   `cast_shadows`.
##
## -- La pose : une grille de ciel, et une fonction pure de la cellule ----------
##
## Le ciel est pave en cellules de `MAILLE` blocs. Chaque cellule tire — ou ne
## tire pas — **un** nuage, par une fonction pure de son indice et de la graine
## du monde : rien n'est memorise, rien ne depend de l'ordre dans lequel on
## regarde, et deux visites du meme endroit rendent le meme ciel. C'est la regle
## de `CWTreeScatter._candidats` (invariant n. 25), appliquee a une couche qui
## n'a meme pas de sol a consulter.
##
## La **derive** est une translation d'ensemble, portee par un seul noeud : les
## cellules, elles, ne bougent pas. C'est ce qui permet de ne refaire le tirage
## que lorsque l'observateur — ou la derive — franchit une frontiere de cellule,
## soit toutes les quelques minutes, au lieu de le refaire a chaque image.

## Le dossier du lot, trois modeles a 1 voxel = 1 bloc.
const DOSSIER: String = "res://assets/models/nuages/"

## Les modeles et leur poids dans le tirage. Le gros temps ne sort qu'une fois
## sur quatre : un ciel qui n'a que des gros nuages n'a plus d'echelle.
const LOT: Array[Dictionary] = [
	{"nom": "cumulus", "poids": 5},
	{"nom": "cumulus_grand", "poids": 2},
	{"nom": "voile", "poids": 3},
]

## Cote d'une cellule de ciel, en blocs. C'est l'espacement moyen de deux
## nuages : a 220 blocs pour des masses de 35 a 90, le ciel est garni sans etre
## bouche, et l'horizon en montre une dizaine.
const MAILLE: int = 220

## Portee, en cellules. Onze par onze : a 1 210 blocs, un nuage passe sous le
## `far` de la camera (2 048) et reste au-dessus du bord du terrain charge, donc
## le ciel ne s'arrete pas la ou le sol s'arrete.
const PORTEE: int = 5

## Altitude de la base des nuages, en blocs, et l'etalement du tirage.
##
## Le point haut du champ mesure est a 377 blocs. La base est donc posee a 420 :
## assez au-dessus pour qu'aucun sommet ne traverse un nuage — ce qui se verrait
## immediatement, un nuage n'ayant pas de collision —, assez bas pour qu'un
## joueur au niveau de la mer les voie sous un angle franc et non au zenith.
const ALTITUDE: float = 420.0
const ALTITUDE_SPAN: float = 130.0

## Gigue d'echelle.
##
## Elle ne descend pas sous 1 : un modele reduit rend ses voxels plus petits
## qu'un bloc de terrain, et la maille du monde cesse d'etre lisible d'un objet
## a l'autre. Le plafond, lui, vient d'une capture — a 1,8 le lot sortait en
## **confettis** : un cumulus de trente-cinq blocs vu de trois cents blocs plus
## bas sous-tend cinq degres, ce qui est la taille d'un caillou tenu a bout de
## bras. A 2,6 il en fait quinze, et le ciel a une echelle.
##
## C'est l'invariant n. 33 pris dans le bon sens : ici on **veut** que grandir
## le modele couvre plus de ciel, et la cellule ne bouge pas.
const ECHELLE_MIN: float = 1.4
const ECHELLE_MAX: float = 2.6

## Derive, en blocs par seconde. A cette vitesse un nuage traverse sa cellule en
## sept minutes : le ciel bouge quand on le regarde, et pas quand on joue.
const DERIVE: Vector2 = Vector2(0.55, 0.34)

## Melange du tirage par cellule. Memes constantes que `CWScatter._seed_of` :
## trois premiers impairs assez grands pour que deux cellules voisines ne
## partagent pas leurs bits de poids faible.
const HASH_X: int = 73856093
const HASH_Z: int = 19349663
const HASH_SEED: int = 83492791

## Part des cellules qui portent un nuage. 0 = ciel degage, 1 = un nuage par
## cellule.
##
## Elle a longtemps vecu dans `CWDaylight` — le temps du shader, ou elle etait
## un uniforme du ciel. Une couverture nuageuse ne depend pas de l'heure : elle
## appartient a la couche, et `--nuages c` la regle ici.
@export_range(0.0, 1.0, 0.01) var cover: float = 0.45:
	set(value):
		cover = clampf(value, 0.0, 1.0)
		_dirty = true

## Coupe la couche sans demonter le noeud, comme `--sans-arbres` pour les
## arbres : c'est ce qui permet de comparer deux captures du meme ciel.
@export var enabled: bool = true:
	set(value):
		enabled = value
		if not enabled:
			_clear()
		_dirty = true

## Les nuages portent-ils une ombre au sol ?
##
## **Faux, et c'est un arbitrage tenu a l'oeil.** Un nuage de quarante blocs
## projette une tache dure de quarante blocs — la carte d'ombres du soleil n'a
## pas de quoi l'adoucir a cette distance —, et le sol se couvre de plaques
## noires a bords nets qui lisent comme un defaut de rendu, pas comme un temps
## couvert. La bascule reste pour la reprendre le jour ou l'ombre sera douce ;
## c'etait une suite annoncee du shader, et elle ne s'est pas perdue.
@export var cast_shadows: bool = false:
	set(value):
		cast_shadows = value
		for mmi in _rendus:
			mmi.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_ON
					if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)

var _seed: int = 0
var _origin: Vector2i = Vector2i.ZERO
var _camera: Node3D = null

## Les modeles charges, dans l'ordre de `LOT`, et la table de tirage ponderee.
var _modeles: Array[CWVoxelModel] = []
var _tirage: PackedInt32Array = PackedInt32Array()

## Le noeud qui porte la derive : tout le champ y pend, et il est le seul a
## bouger d'une image a l'autre.
var _champ: Node3D = null
var _rendus: Array[MultiMeshInstance3D] = []

var _derive: Vector2 = Vector2.ZERO
var _cellule: Vector2i = Vector2i(0x7FFFFFFF, 0x7FFFFFFF)
var _dirty: bool = true
var _poses: int = 0


## Charge le lot et construit la table de tirage ponderee.
##
## Statique et sans noeud : c'est ce qui permet a `tests/sky_test.gd` de
## verifier la pose sans monter de scene, et c'est la seule facon de garantir
## que le test regarde le meme lot que le jeu.
static func charge_lot() -> Dictionary:
	var modeles: Array[CWVoxelModel] = []
	var tirage := PackedInt32Array()
	var palette: Resource = CWPalette.build_voxel_palette()
	for entree in LOT:
		var nom: String = entree["nom"]
		# La grille du terrain, et non celle de la flore : un nuage est dessine
		# a la taille du monde (invariant n. 28).
		var m: CWVoxelModel = CWVoxelModel.load_from(DOSSIER + nom + ".vox",
				palette, nom, CWVoxelModel.VOXELS_PER_BLOCK_TERRAIN)
		if m == null:
			push_warning("[nuages] %s introuvable" % nom)
			continue
		var indice: int = modeles.size()
		modeles.append(m)
		for _i in int(entree["poids"]):
			tirage.append(indice)
	return {"modeles": modeles, "tirage": tirage}


func _ready() -> void:
	_champ = Node3D.new()
	_champ.name = "Champ"
	add_child(_champ)

	var lot: Dictionary = charge_lot()
	_modeles = lot["modeles"]
	_tirage = lot["tirage"]
	for m in _modeles:
		var nom: String = m.name
		var mmi := MultiMeshInstance3D.new()
		mmi.name = nom
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = m.mesh()
		mmi.multimesh = mm
		mmi.material_override = CWPalette.build_cloud_material()
		mmi.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		_rendus.append(mmi)
		_champ.add_child(mmi)


func setup(world_seed: int, world_origin: Vector2i, camera: Node3D) -> void:
	_seed = world_seed
	_origin = world_origin
	_camera = camera
	_dirty = true


## Nuages poses. Pour l'ATH.
func count() -> int:
	return _poses


func _process(delta: float) -> void:
	if _camera == null or _modeles.is_empty():
		return
	if enabled:
		_derive += DERIVE * delta
		_champ.position = Vector3(_derive.x, 0.0, _derive.y)
	# La cellule de l'observateur **dans le repere du champ** : la derive fait
	# glisser les nuages sous lui, donc elle se retranche avant de chercher la
	# cellule. Sans cela le champ se recentrerait sur la camera et la derive ne
	# se verrait jamais.
	var ici := Vector2i(
			_cell_of(_origin.x + floori(_camera.global_position.x - _derive.x)),
			_cell_of(_origin.y + floori(_camera.global_position.z - _derive.y)))
	if ici == _cellule and not _dirty:
		return
	_cellule = ici
	_dirty = false
	_repose(ici)


func _cell_of(w: int) -> int:
	return floori(float(w) / float(MAILLE))


func _clear() -> void:
	_poses = 0
	for mmi in _rendus:
		mmi.multimesh.instance_count = 0


## Refait le tirage sur toutes les cellules a portee.
##
## Onze par onze font cent vingt et une cellules, soit autant de tirages de six
## valeurs : quelques dizaines de microsecondes, et cela ne se produit qu'au
## franchissement d'une frontiere de cellule. C'est ce qui autorise a tout
## refaire plutot qu'a tenir une difference — il n'y a donc **aucun etat** a
## desynchroniser.
func _repose(centre: Vector2i) -> void:
	if not enabled:
		_clear()
		return
	var par_modele: Array[Array] = []
	for _i in _modeles.size():
		par_modele.append([])

	for dz in range(-PORTEE, PORTEE + 1):
		for dx in range(-PORTEE, PORTEE + 1):
			var pose: Array = nuage_de(centre.x + dx, centre.y + dz, _seed,
					_origin, _modeles, _tirage, cover)
			if not pose.is_empty():
				par_modele[int(pose[0])].append(pose[1])

	_poses = 0
	for i in _modeles.size():
		var liste: Array = par_modele[i]
		var mm: MultiMesh = _rendus[i].multimesh
		mm.instance_count = liste.size()
		for j in liste.size():
			mm.set_instance_transform(j, liste[j])
		_poses += liste.size()
		# La boite de visibilite couvre la portee entiere : un `MultiMesh` la
		# deduirait de ses instances, mais elles bougent avec la derive et la
		# recalculer a chaque image couterait plus que ce qu'elle economise.
		var portee: float = float((PORTEE + 1) * MAILLE)
		_rendus[i].custom_aabb = AABB(
				Vector3(float(centre.x * MAILLE - _origin.x) - portee, ALTITUDE,
						float(centre.y * MAILLE - _origin.y) - portee),
				Vector3(portee * 2.0, ALTITUDE_SPAN + 64.0, portee * 2.0))


## Le nuage d'une cellule : `[indice de modele, Transform3D]`, ou vide si la
## cellule ne porte rien.
##
## Statique, et c'est ce qui la rend verifiable : elle ne lit **que** son indice
## de cellule et la graine du monde, jamais l'etat du noeud ni ce qu'une cellule
## voisine a decide. `tests/sky_test.gd` l'appelle donc sans monter de scene.
##
## **Les six tirages sont pris ensemble, avant toute decision** (invariant
## n. 23) : un tirage place apres le test de couverture desynchroniserait le flux
## d'une cellule a l'autre, et baisser la couverture changerait la **forme** du
## ciel au lieu de simplement l'eclaircir — deux visites du meme endroit a deux
## reglages ne se compareraient plus.
static func nuage_de(cx: int, cz: int, world_seed: int, origin: Vector2i,
		modeles: Array[CWVoxelModel], tirage: PackedInt32Array,
		couverture: float) -> Array:
	var rng := CWRand.new((cx * HASH_X) ^ (cz * HASH_Z) ^ (world_seed * HASH_SEED))
	var couvre: float = rng.unit()
	var variante: int = tirage[rng.mod(tirage.size())]
	var fx: float = rng.unit()
	var fz: float = rng.unit()
	var altitude: float = ALTITUDE + rng.unit() * ALTITUDE_SPAN
	var quart: int = rng.mod(CWVoxelModel.ROTATIONS)
	var echelle: float = lerpf(ECHELLE_MIN, ECHELLE_MAX, rng.unit())
	if couvre >= couverture:
		return []

	var m: CWVoxelModel = modeles[variante]
	# La grille est celle du **modele** et non la constante (invariant n. 28) :
	# un nuage est dessine a 1 voxel par bloc, et lire `VOXELS_PER_BLOCK` le
	# rendrait treize fois trop petit.
	var k: float = echelle / m.voxels_per_block
	var base := Basis(Vector3.UP, float(quart) * PI * 0.5).scaled(Vector3(k, k, k))
	var pos := Vector3(
			float(cx * MAILLE - origin.x) + fx * float(MAILLE),
			altitude,
			float(cz * MAILLE - origin.y) + fz * float(MAILLE))
	# `mesh_offset` est dans le repere du maillage : il subit la rotation et
	# l'echelle comme le reste, exactement comme pour une plante posee.
	return [variante, Transform3D(base, pos + base * m.mesh_offset())]
