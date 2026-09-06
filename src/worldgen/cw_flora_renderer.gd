class_name CWFloraRenderer
extends Node3D

## Rendu de la couche de flore (jalon 1.7) : les plantes dispersees par
## `CWScatter`, instanciees autour de l'observateur.
##
## -- Pourquoi pas dans le terrain ---------------------------------------------
## Un modele de flore est sur une grille plus fine que le terrain — 4 voxels par
## bloc, ou 6 pour les petits props : l'ecrire dans les donnees voxels du monde
## reviendrait a le grossir de quatre a six fois. Il est donc maille a part — meme mailleur, meme palette, meme
## materiau que le terrain, ce qui est la condition pour que les deux grilles
## lisent comme un seul monde — puis instancie a l'echelle.
##
## Ce qu'on perd, et qu'il faut savoir : la flore ne se creuse pas, ne porte pas
## de collision, et ne participera pas a l'eclairage voxel du jalon 1.9. Ce
## qu'on gagne : elle quitte le chemin critique de generation, qui est le poste
## dominant du chargement.
##
## -- La cellule est l'unite ---------------------------------------------------
## Une cellule de dispersion (CWScatter.CELL_SIZE blocs de cote) donne un noeud,
## portant un `MultiMeshInstance3D` par modele qu'elle emploie. On cree et on
## detruit par cellule entiere : c'est la granularite du tirage, donc il n'y a
## rien a decouper ni a recoudre.
##
## -- Ce qui coute -------------------------------------------------------------
## Construire une cellule demande un echantillonnage de colonne par plante
## (~75 us), soit de l'ordre de la milliseconde. Une vue de 128 blocs en demande
## deux cents : c'est trop pour le fil principal. Les cellules manquantes sont
## donc construites par lots sur un fil du pool — `CWScatter.cell` est sur a
## appeler depuis plusieurs fils — et le fil principal ne fait plus que lire le
## resultat et poser les transformations, ce qui est immediat.

## Cellules construites par lot sur le fil de fond. Assez grand pour que le cout
## d'une tache soit negligeable devant son contenu, assez petit pour que la
## flore apparaisse par vagues plutot que d'un bloc apres un long silence.
const BATCH: int = 48

## Marge, en cellules, avant qu'une cellule sortie du champ soit detruite.
## Sans elle, une camera qui oscille sur une frontiere reconstruit sans fin.
const KEEP_MARGIN: int = 1

## Distance de vue de la flore, en blocs.
##
## La demo y recopie la distance de vue du terrain, et rien d'autre : une couche
## de vegetation qui s'arrete avant lui dessine un cercle net autour du joueur,
## et ce cercle se voit de loin. Le champ reste reglable pour les bancs d'essai
## et les captures, ou l'on veut parfois isoler une couche.
##
## Ce que ca coute : la portee est un **rayon en cellules**, donc le nombre de
## cellules croit avec son carre. Doubler la distance quadruple la memoire et le
## travail de construction.
@export var view_distance: int = 128:
	set(value):
		view_distance = maxi(0, value)
		_wanted.clear()

## Coupe le rendu de la flore sans demonter le noeud (gabarit d'echelle,
## comparaison d'un meme monde avec et sans).
@export var enabled: bool = true:
	set(value):
		enabled = value
		if not enabled:
			clear()

## Les instances portent-elles une ombre ?
##
## Faux pour la flore, et c'est mesure : des milliers de touffes d'un demi-bloc
## dans la carte d'ombres coutent cher pour une ombre qu'on ne distingue pas de
## celle du sol. Vrai pour les **arbres**, ou c'est l'inverse — l'ombre portee
## d'un arbre de huit blocs est la moitie de ce qui le pose dans le paysage, et
## il y en a cent fois moins.
@export var cast_shadows: bool = false

var _scatter: CWScatter = null
var _origin: Vector2i = Vector2i.ZERO
var _camera: Node3D = null

## Cellules posees : indice de cellule -> noeud.
var _live: Dictionary = {}
## Cellules a construire, de la plus proche a la plus lointaine.
var _queue: Array[Vector2i] = []
## Cellules demandees par la position courante. Vide = a recalculer.
var _wanted: Dictionary = {}
var _task: int = -1
var _batch: Array[Vector2i] = []
var _last_cell: Vector2i = Vector2i(0x7FFFFFFF, 0x7FFFFFFF)

## Cellules tirees, mais dont le terrain n'est pas encore charge. Voir
## `set_terrain`.
var _waiting: Array[Vector2i] = []
## Cellules posees **incompletes** : leur sol n'etait charge que par endroits.
## Elles restent dans `_waiting` et se refont en entier des que le terrain les
## rattrape. Voir `_plantes_posables`.
var _partiel: Dictionary = {}
var _terrain: VoxelTool = null


## Donne a la couche de flore de quoi savoir si le sol est arrive.
##
## Sans cela, la flore devance le terrain : elle se construit en une quinzaine de
## secondes la ou le terrain en demande le double, et le joueur voit des touffes
## flotter dans le vide en attendant que le sol les rejoigne. L'ecart grandit
## avec la distance de vue, donc il empire exactement la ou l'on veut aller.
##
## La cellule attend donc que les blocs de donnees soient la sous ses plantes.
## Le terrain passe ainsi toujours en premier — au pire d'une frame, le temps
## que le maillage suive les donnees, ce qui est le bon ordre : du sol sans
## flore se lit comme un monde qui charge, de la flore sans sol comme un bogue.
func set_terrain(tool: VoxelTool) -> void:
	_terrain = tool


## Transformation d'une plante : de son ancre en coordonnees monde vers le
## repere du maillage de son modele.
##
## Isolee ici parce que c'est le seul endroit ou les deux grilles se rencontrent,
## et le seul calcul de cette couche qui puisse etre faux sans qu'on le voie —
## une plante enterree d'un demi-bloc ou glissee d'un quart de gabarit a chaque
## quart de tour reste plausible a l'oeil. Verifiee dans `tests/flora_test.gd`.
static func instance_transform(pl: CWScatter.Placement,
		world_origin: Vector2i) -> Transform3D:
	# Deux facteurs, et il faut les deux : le rapport des grilles, qui est un
	# contrat d'authoring, et la gigue d'instance, qui est ce qui separe un champ
	# vivant d'un motif repete. Elle entre dans la base, donc elle grandit la
	# plante depuis son ancre — au sol, au centre — et non depuis le coin du
	# gabarit ; sinon une touffe a 2x s'enterrerait de sa demi-hauteur.
	# La grille est celle du **modele** et non la constante : depuis le jalon
	# 1.12 un houppier est dessine a un voxel par bloc et une touffe d'herbe a
	# 40/3. Lire la constante ici rendrait les arbres treize fois trop petits.
	var scale: float = pl.scale / pl.model.voxels_per_block
	var basis := Basis(Vector3.UP, float(pl.rotation) * PI * 0.5).scaled(
			Vector3(scale, scale, scale))
	var pos := Vector3(
			float(pl.x - world_origin.x) + pl.fx,
			float(pl.y) + pl.fy,
			float(pl.z - world_origin.y) + pl.fz)
	# `mesh_offset` est dans le repere du maillage : il subit la rotation et
	# l'echelle comme le reste, sinon la plante glisse d'un quart de gabarit a
	# chaque quart de tour.
	return Transform3D(basis, pos + basis * pl.model.mesh_offset())


func setup(scatter: CWScatter, world_origin: Vector2i, camera: Node3D) -> void:
	_scatter = scatter
	_origin = world_origin
	_camera = camera


## Cellules posees et plantes instanciees. Pour l'ATH et les tests.
func stats() -> Vector2i:
	var plants: int = 0
	for c in _live:
		plants += int(_live[c].get_meta("plant_count", 0))
	return Vector2i(_live.size(), plants)


func clear() -> void:
	for c in _live:
		_live[c].queue_free()
	_live.clear()
	_queue.clear()
	_waiting.clear()
	_partiel.clear()
	_wanted.clear()
	_last_cell = Vector2i(0x7FFFFFFF, 0x7FFFFFFF)


func _process(_delta: float) -> void:
	if not enabled or _scatter == null or _camera == null:
		return
	if not _scatter.library().has_any():
		return
	_drop_edited()
	_refresh_wanted()
	_retry_waiting()
	_pump()


## Refait les cellules ou le terrain a bouge.
##
## Le lot vient de `CWWorldEdits`, qui accumule au lieu de signaler bloc par
## bloc : un cratere de six cents coups de pioche touche une poignee de cellules,
## et les reconstruire a chaque coup couterait cent fois le travail utile.
##
## Reconstruire est ici la seule option honnete : la dispersion d'une cellule est
## un tirage d'un bloc, sans etat par plante, donc on ne peut pas en retirer une
## sans rejouer le tirage. C'est aussi ce qui garde la cellule reproductible —
## une cellule editee puis rechargee doit donner le meme resultat.
func _drop_edited() -> void:
	var dirty: Array = _scatter.take_dirty_cells()
	for c in dirty:
		_scatter.invalidate_cell(c.x, c.y)
		if _live.has(c):
			_live[c].queue_free()
			_live.erase(c)
			_partiel.erase(c)
			_wanted.clear()


## Recalcule l'ensemble des cellules a poser. Tant que l'observateur reste dans
## la meme cellule, il n'y a rien a decider.
func _refresh_wanted() -> void:
	var here := Vector2i(
			_scatter.cell_index(_origin.x + floori(_camera.global_position.x)),
			_scatter.cell_index(_origin.y + floori(_camera.global_position.z)))
	if here == _last_cell and not _wanted.is_empty():
		return
	_last_cell = here

	var reach: int = (view_distance + _scatter.cell_size - 1) >> _scatter.cell_shift
	_wanted.clear()
	var pending: Array[Vector2i] = []

	# Du plus proche au plus loin, par anneaux carres — et non par un tri.
	#
	# La portee suit desormais la distance de vue du joueur, qui monte a plusieurs
	# milliers de blocs : a 3072, ce sont cent mille cellules, et les trier par
	# comparateur GDScript prendrait plusieurs secondes **a chaque fois que la
	# camera change de cellule**, soit tous les seize blocs parcourus. Emettre les
	# anneaux dans l'ordre donne la meme chose — ce qu'on a sous les yeux d'abord —
	# pour le prix du parcours seul.
	# -- Un carre, et non un disque -----------------------------------------
	#
	# La portee etait un disque (`dx*dx + dz*dz <= reach*reach`) : c'est la forme
	# naturelle d'une distance de vue, et c'est faux ici. Le terrain, lui, charge
	# une **boite** de blocs autour de l'observateur — Voxel Tools ne connait que
	# ca —, donc les quatre coins de la boite portaient du terrain sans porter de
	# cellules. La flore y manquait sans qu'on le remarque ; depuis que le tronc
	# est ecrit dans le terrain (jalon 1.11), le meme coin rend un **fut nu, sans
	# houppier**, et le defaut se voit. Les deux couches suivent maintenant la
	# meme forme.
	#
	# Le prix est de 4/pi, soit 27 % de cellules en plus. Il se paie sur le fil
	# du pool, et il achete la seule chose qui compte ici : ce que le terrain
	# montre, la vegetation le garnit.
	for r in range(0, reach + 1):
		for dz in range(-r, r + 1):
			# L'anneau de rayon r : ses deux lignes entieres, puis les deux seules
			# colonnes qui restent. Sans ce saut on reparcourrait le carre entier
			# a chaque rayon.
			var step: int = 1 if absi(dz) == r else 2 * r
			var dx: int = -r
			while dx <= r:
				var c := Vector2i(here.x + dx, here.y + dz)
				_wanted[c] = true
				if not _live.has(c):
					pending.append(c)
				dx += step
	_queue = pending

	# Au-dela de la marge, on rend la memoire.
	var drop: int = reach + KEEP_MARGIN
	var stale: Array[Vector2i] = []
	for c in _live:
		if absi(c.x - here.x) > drop or absi(c.y - here.y) > drop:
			stale.append(c)
	for c in stale:
		_live[c].queue_free()
		_live.erase(c)
		_partiel.erase(c)


## Fait avancer la construction : un lot en vol a la fois.
func _pump() -> void:
	if _task != -1:
		if not WorkerThreadPool.is_task_completed(_task):
			return
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		# Les cellules sont desormais dans le cache de CWScatter : les relire est
		# immediat, et c'est le fil principal qui cree les noeuds.
		for c in _batch:
			if _wanted.has(c) and not _live.has(c):
				_poser(c)
		_batch.clear()

	if _queue.is_empty():
		return
	_batch.assign(_queue.slice(0, BATCH))
	_queue = _queue.slice(BATCH)
	var cells: Array[Vector2i] = _batch.duplicate()
	var scatter: CWScatter = _scatter
	_task = WorkerThreadPool.add_task(func() -> void:
		for c in cells:
			scatter.cell(c.x, c.y))


## Repasse sur les cellules qui attendaient leur sol.
##
## Borne a un lot par frame, et par rotation : une cellule qui n'est toujours pas
## prete repart en fin de file au lieu de bloquer celles qui suivent. Sans cette
## rotation, une seule cellule hors de la tranche verticale du terrain — un
## sommet loin au-dessus de la camera, par exemple — arreterait toute la flore.
func _retry_waiting() -> void:
	if _waiting.is_empty():
		return
	var n: int = mini(_waiting.size(), BATCH)
	var again: Array[Vector2i] = []
	for i in n:
		var c: Vector2i = _waiting[i]
		if not _wanted.has(c):
			continue
		# Une cellule deja posee n'est reprise que si elle l'a ete a moitie, et
		# seulement quand tout son sol est la : la refaire coute un noeud entier,
		# et une cellule complete n'a rien a y gagner.
		if _live.has(c):
			if not _partiel.has(c) or not _ground_ready(c):
				again.append(c)
				continue
			_live[c].queue_free()
			_live.erase(c)
			_partiel.erase(c)
		if not _poser(c):
			again.append(c)
	_waiting = _waiting.slice(n)
	_waiting.append_array(again)


## Pose une cellule, entiere si son sol est la, a moitie sinon. Rend vrai quand
## il n'y a plus rien a attendre.
##
## -- Pourquoi une pose partielle ---------------------------------------------
##
## `_ground_ready` interroge la **cellule entiere**, donc une cellule a cheval
## sur le bord du terrain charge echouait en bloc : aucune plante, aucun arbre,
## sur les soixante-quatre blocs, y compris la moitie qui repose sur du sol
## charge. Personne ne l'avait vu tant que les deux moities d'un arbre etaient
## instanciees ensemble — la cellule manquait, l'arbre entier avec elle.
##
## Depuis que le tronc est ecrit dans le terrain (jalon 1.11), le defaut se voit
## : le generateur estampe le tronc des que son bloc existe, sans rien savoir des
## cellules, et une cellule refusee laissait donc un **fut nu, sans houppier**,
## sur tout le pourtour de la vue. C'est ce que la capture du 2026-09-06 a
## montre. Les deux couches doivent s'accorder au bloc pres, pas a la cellule.
func _poser(c: Vector2i) -> bool:
	var plants: Array = _scatter.cell(c.x, c.y)
	if plants.is_empty():
		return true
	if _ground_ready(c):
		_build_node(c, plants)
		return true
	var posables: Array = _plantes_posables(plants)
	if not posables.is_empty():
		_build_node(c, posables)
		_partiel[c] = true
	_waiting.append(c)
	return false


## Vrai si les blocs de terrain sont charges sous les plantes de la cellule.
##
## On interroge l'etendue verticale reelle des plantes, et non la colonne
## entiere : le terrain ne charge qu'une tranche autour de l'observateur
## (`view_distance_vertical_ratio`), donc exiger toute la hauteur du monde
## reviendrait a ne jamais rien poser.
##
## C'est le **chemin rapide** : une seule requete pour toute la cellule, et elle
## suffit partout sauf au bord du terrain charge. Voir `_plantes_posables`.
func _ground_ready(c: Vector2i) -> bool:
	if _terrain == null:
		return true
	var plants: Array = _scatter.cell(c.x, c.y)
	if plants.is_empty():
		return true
	var lo: float = INF
	var hi: float = -INF
	for pl in plants:
		lo = minf(lo, float(pl.y))
		hi = maxf(hi, float(pl.y))
	var size: float = float(_scatter.cell_size)
	return _terrain.is_area_editable(AABB(
			Vector3(float(c.x * _scatter.cell_size - _origin.x), lo,
					float(c.y * _scatter.cell_size - _origin.y)),
			Vector3(size, hi - lo + 1.0, size)))


## Les plantes de la liste dont le sol est charge, une par une.
##
## Chemin froid : il ne sert qu'aux cellules du bord, celles dont la requete
## d'ensemble a echoue. Ailleurs on paie une seule requete pour toute la cellule,
## et c'est ce qui rend ce test-ci abordable — `is_area_editable` sur soixante
## touffes a chaque cellule serait un cout sur le fil principal.
##
## **Ce qu'on interroge est la colonne, pas la piece.** Un houppier flotte a dix
## blocs du sol et deborde de sept : demander que *son* volume soit charge le
## refuserait des que son cadre depasse la limite du terrain, alors que son
## tronc, lui, est bel et bien ecrit — c'est ainsi qu'un fut nu apparaissait au
## bord de la vue. La bonne question est celle que se pose le generateur avant
## d'estamper : **le bloc de sol de cette colonne existe-t-il ?**
func _plantes_posables(plants: Array) -> Array:
	var out: Array = []
	for pl in plants:
		var pos: Vector3 = pl.origin() - Vector3(
				float(_origin.x), 0.0, float(_origin.y))
		# `pl.y` est le premier bloc d'air : le sol est juste dessous.
		if _terrain.is_area_editable(AABB(
				Vector3(floorf(pos.x), float(pl.y - 1), floorf(pos.z)),
				Vector3(1.0, 2.0, 1.0))):
			out.append(pl)
	return out


## Un noeud par cellule, un MultiMesh par modele qu'elle emploie.
##
## `plants` est la liste a poser : celle de la cellule, ou le sous-ensemble dont
## le sol est charge (`_poser`).
func _build_node(c: Vector2i, plants: Array) -> void:
	if plants.is_empty():
		return

	var by_model: Dictionary = {}
	for pl in plants:
		# Une piece de matiere est ecrite dans le terrain par le generateur, pas
		# instanciee ici : l'instancier en plus donnerait deux troncs au meme
		# endroit, dont un qui ne se creuse pas. Voir `CWScatter.Placement.matiere`.
		if pl.matiere:
			continue
		if not by_model.has(pl.model):
			by_model[pl.model] = []
		by_model[pl.model].append(pl)

	var node := Node3D.new()
	node.name = "Cell%d_%d" % [c.x, c.y]
	node.set_meta("plant_count", plants.size())

	var instances: Array[MultiMeshInstance3D] = []
	var bounds := AABB()
	var first: bool = true

	for model in by_model:
		var mesh: ArrayMesh = model.mesh()
		if mesh == null:
			continue
		var list: Array = by_model[model]
		# Grille du modele, pas celle de la bibliotheque : un houppier et une
		# touffe d'herbe peuvent se retrouver dans la meme cellule.
		var scale: float = 1.0 / model.voxels_per_block

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			var pl: CWScatter.Placement = list[i]
			mm.set_instance_transform(i, instance_transform(pl, _origin))
			# Gabarit de *cette* instance : la gigue va jusqu'a 2x, et une boite
			# calculee sur le modele nu ferait disparaitre les grandes touffes
			# des que leur centre sort du champ.
			var reach: float = float(model.radius) * scale * pl.scale
			var tall: float = float(model.height) * scale * pl.scale
			var pos: Vector3 = pl.origin() - Vector3(
					float(_origin.x), 0.0, float(_origin.y))
			var box := AABB(pos - Vector3(reach, 0.0, reach),
					Vector3(reach * 2.0, tall, reach * 2.0))
			bounds = box if first else bounds.merge(box)
			first = false

		var mmi := MultiMeshInstance3D.new()
		mmi.name = model.name
		mmi.multimesh = mm
		mmi.material_override = CWPalette.build_opaque_material()
		mmi.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		instances.append(mmi)
		node.add_child(mmi)

	if instances.is_empty():
		node.queue_free()
		return

	# Sans boite explicite, la visibilite d'un MultiMesh se recalcule a partir de
	# ses instances ; on la connait deja, on la donne. Le noeud est a l'origine,
	# donc les coordonnees locales sont celles du monde rendu.
	for mmi in instances:
		mmi.custom_aabb = bounds

	add_child(node)
	_live[c] = node
