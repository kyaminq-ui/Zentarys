class_name CWScatter
extends RefCounted

## Dispersion de la flore sur le terrain genere (jalon 1.7).
##
## -- Pourquoi une grille de cellules ------------------------------------------
## La dispersion doit etre reproductible sans etat partage : le monde est
## parcouru dans un ordre imprevisible, par le rendu comme par les tests, et une
## plante doit tomber au meme endroit quel que soit ce qui a ete visite avant.
## On decoupe donc le monde en cellules de CELL_SIZE, et chaque cellule tire ses
## plantes a partir de son seul indice — sans ordre d'evaluation, sans
## voisinage. La cellule est du meme coup l'unite de rendu : un jeu de
## `MultiMesh` par cellule, cree et detruit d'un bloc (`CWFloraRenderer`).
##
## -- Cout ---------------------------------------------------------------------
## Chaque plante coute un echantillonnage de colonne (~75 us) : il faut son
## altitude exacte pour la poser, et la surface exacte pour verifier qu'elle a
## le droit d'y etre. Le *nombre* de plantes, lui, se decide sur un seul
## echantillon au centre de la cellule : un biome s'etend sur des milliers de
## blocs, il ne change pas a l'interieur d'une cellule de seize. Une cellule
## coute donc 1 + n echantillons au lieu d'un par candidat rejete — de l'ordre
## d'une milliseconde en prairie. C'est trop pour le fil principal quand la vue
## en demande deux cents d'un coup : le rendu les fait construire par lots sur
## un fil du pool, ce que le cache sous mutex ci-dessous rend sur.
##
## -- Les deux frequences de bruit ---------------------------------------------
## Porte le 2026-09-05 depuis `docs/systems/02`, §8.4. L'original ne seme pas au
## hasard uniforme : il croise deux echelles de decision.
##
##   * **0,05 decide *ou* il y a de la flore.** `|bruit(x*0,05 + 9843,
##     z*0,05 + 8437)| > 0,5` decoupe le sol en plaques — mesure ici : 29,2 % de
##     la surface passe, en plaques de 19,1 blocs de long, ce qui est bien la
##     longueur d'onde 1/0,05. C'est cette crete, et elle seule, qui produit les
##     grappes serrees puis les larges vides des captures de l'original. Il n'y
##     a pas de mecanisme de groupement separe a chercher : la dette technique
##     « groupement de la flore en grappes » se ferme ici.
##   * **0,01 decide *laquelle*.** L'original teste le *signe* de la basse
##     frequence pour trancher entre deux decors ; sur une centaine de blocs,
##     c'est donc le meme choix qui domine. Generalise ici a une liste de n
##     modeles : le signe designe une moitie de la liste — un indice sur deux —
##     et le tirage d'instance choisit dedans. Pour n = 2, c'est exactement le
##     test de signe d'origine.
##
## -- Pourquoi la rarete entiere n'est pas portee telle quelle ------------------
## L'original visite **chaque colonne** et garde `rand()%8 == 0` de celles qui
## sont dans une plaque. Ce serait 256 echantillonnages de colonne par cellule,
## soit ~19 ms : c'est precisement ce qu'on ne peut pas payer. On tire donc un
## budget de candidats, et on ne paie la colonne que pour ceux qui passent la
## crete. Les deux schemas ont la meme moyenne, et le calcul le montre :
## 256 colonnes x 0,2917 x 1/8 = **9,3 plantes par cellule**, la ou la densite
## de bon sens de `CWModelLibrary` en donnait 9,8 sur l'herbe avant ce portage.
## Les deux chemins, independants, tombent sur le meme nombre : la densite
## posee au juge etait la bonne.
##
## Ajouter malgre tout un tirage `%8` par candidat ne changerait rien : filtrer
## au hasard des positions deja tirees au hasard rend des positions au hasard.
## C'est une ligne decorative, pas un portage — d'ou son absence.
##
## -- Ce qui n'est pas encore porte --------------------------------------------
## La table modele -> biome reste une proposition de bon sens : la
## correspondance entre les types de blocs de l'original et ceux de `CWPalette`
## n'est pas etablie (`docs/systems/02`, §9). La loi de densite par biome l'est
## aussi. La *structure* — deux frequences, un budget par cellule, une gigue
## d'echelle par instance, un quart de tour — vient, elle, de la lecture.

## Cote d'une cellule de dispersion, en blocs. Aligne sur le bloc de donnees de
## Voxel Tools : une cellule par bloc, donc une couronne de 3 x 3 a consulter.
const CELL_SIZE: int = 16
const CELL_SHIFT: int = 4

## Finesse de la position d'une plante *sous* son bloc : le decalage tire est
## `mod(SUBBLOCK_STEPS) / SUBBLOCK_STEPS`. Sans ce decalage, toute la flore
## s'alignerait sur la grille du terrain et le damier se verrait.
##
## C'est une grille de **position**, sans rapport avec celle du dessin
## (`CWVoxelModel.VOXELS_PER_BLOCK`, qui vaut 40/3 depuis le 2026-09-05 et n'est
## donc plus entier). Les deux ont ete confondues tant que le rapport tombait
## juste ; elles sont independantes, et seule celle-ci a besoin d'etre entiere.
## Sa valeur n'a pas d'effet visible au-dela de quelques pas : 16 suffit.
const SUBBLOCK_STEPS: int = 16

## Plafond dur du nombre de plantes par cellule. Garde-fou : une densite mal
## reglee ne doit pas pouvoir faire exploser le cout d'une cellule en silence.
## Chaque plante coute un echantillonnage de colonne (~75 us).
##
## Porte de 32 a 64 le 2026-09-05, avec la crete de placement. Le budget est
## desormais divise par la part passante (~0,32), donc la jungle tire jusqu'a 50
## candidats : a 32, le plafond ne gardait plus, il *rabotait* — une cellule
## entierement dans une plaque perdait un tiers de sa flore, et la densite
## moyenne tombait de 9,8 a 8,2 sans que rien ne le dise. `DENSITY` doit rester
## lisible en plantes par cellule ; c'est le plafond qui devait bouger.
const MAX_PER_CELL: int = 64

## Plafond du nombre de *candidats* tires. Distinct du precedent : un candidat
## refuse par la crete de placement ne coute qu'un echantillon de bruit (~1 us),
## pas une colonne. Le cout d'une cellule suit donc les plantes posees, pas les
## candidats — c'est ce qui rend la compensation ci-dessous abordable.
const MAX_CANDIDATES: int = 128

## Crete de placement : la basse-frequence qui decide *ou* il y a de la flore.
## Constantes de l'original (`docs/systems/02`, §8.4), decalages de graine
## compris — ce sont eux qui eloignent le reseau de bruit de l'origine, ou
## l'indexation par troncature de `CWValueNoise` differerait de `floori`.
const PLACEMENT_FREQ: float = 0.05
const PLACEMENT_OFFSET_X: float = 9843.0
const PLACEMENT_OFFSET_Z: float = 8437.0
const PLACEMENT_RIDGE: float = 0.5

## Part de la surface qui passe la crete : **0,2917**, mesure sur un million de
## colonnes reparties sur quatre regions eloignees. Les 250 000 colonnes du seul
## point de depart donnent 0,3012 — trois points de trop, et c'est la valeur
## qu'on avait d'abord retenue ; la part varie de 0,274 a 0,304 selon la region.
## Le budget de candidats est divise par elle, ce qui
## conserve la densite moyenne par biome — `CWModelLibrary.DENSITY` continue de
## se lire « plantes par cellule ». Ce qui change est la *variance* : des
## plaques garnies et des vides, au lieu d'un saupoudrage regulier.
##
## Verrouillee par un test : si `CWValueNoise` ou les constantes ci-dessus
## bougent, la densite de tous les biomes derive en silence sans lui.
const PLACEMENT_PASS_RATE: float = 0.2917

## Frequence de selection : elle decide *laquelle*. Dix fois plus lente que la
## crete de placement, donc une region entiere partage sa dominante.
const SELECTION_FREQ: float = 0.01
const SELECTION_OFFSET_X: float = 9843.0
const SELECTION_OFFSET_Z: float = 8437.0

## Gigue d'echelle par instance : `rand()/32767 + 1` dans l'original, soit 1x a
## 2x. Sans elle, toutes les touffes d'un meme modele sont a la meme taille et
## le champ se lit comme un motif repete.
##
## `SCALE_MAX` n'est pas decoratif : il entre dans la marge de `placements_in`
## et dans la boite de visibilite du rendu. Une plante peut deborder de deux
## fois le rayon de son modele.
const SCALE_MIN: float = 1.0
const SCALE_MAX: float = 2.0

## Plafond du cache de cellules. Meme raisonnement que HEIGHTMAP_CACHE_CAP :
## il doit couvrir l'empreinte chargee, sinon le cache s'auto-evince en boucle.
## Une cellule est bien plus legere qu'une carte de hauteurs.
const CELL_CACHE_CAP: int = 32768

## Melangeurs de l'indice de cellule vers la graine du LCG. Premiers larges,
## comme dans toute fonction de hachage spatiale ; ils n'ont pas d'equivalent
## dans l'original, qui disperse en parcourant les regions dans l'ordre.
const HASH_X: int = 73856093
const HASH_Z: int = 19349663
const HASH_SEED: int = 83492791
const HASH_MIX: int = 2654435761


## Une plante posee : sa colonne, sa base, son modele et son orientation.
class Placement extends RefCounted:
	var x: int = 0
	var z: int = 0
	## Altitude du premier bloc du modele : le bloc d'air juste au-dessus du sol.
	var y: int = 0
	## Position a l'interieur de la colonne, dans [0, 1). Le modele est seize
	## fois plus fin que le bloc : le poser au coin de sa colonne alignerait
	## toute la flore sur la grille du terrain, ce qui se voit immediatement.
	## Tire au pas d'un voxel, donc reproductible comme le reste.
	var fx: float = 0.0
	var fz: float = 0.0
	var model: CWVoxelModel = null
	var rotation: int = 0
	## Gigue d'echelle de l'instance, dans [SCALE_MIN, SCALE_MAX]. L'original
	## multiplie l'echelle de chaque decor par `rand()/32767 + 1` : deux touffes
	## du meme modele n'ont pas la meme taille. Multiplie l'echelle de dessin,
	## pas la position — l'ancre reste au sol et au centre de l'empreinte.
	var scale: float = 1.0

	## Position de l'ancre, en blocs, coordonnees monde.
	func origin() -> Vector3:
		return Vector3(float(x) + fx, float(y), float(z) + fz)

	## Rayon reellement occupe, en blocs, gigue comprise. C'est cette valeur —
	## et non `model.radius_blocks` — qui decide si la plante mord dans un cadre.
	func radius_blocks() -> int:
		return ceili(float(model.radius_blocks) * scale)


var _field: CWTerrainField
var _lib: CWModelLibrary
var _cells: Dictionary = {}
var _cells_prev: Dictionary = {}
var _mutex: Mutex = Mutex.new()


func _init(terrain_field: CWTerrainField, models: CWModelLibrary = null) -> void:
	_field = terrain_field
	_lib = models if models != null else CWModelLibrary.shared()


func library() -> CWModelLibrary:
	return _lib


func clear_cache() -> void:
	_mutex.lock()
	_cells.clear()
	_cells_prev.clear()
	_mutex.unlock()


static func cell_of(v: int) -> int:
	return v >> CELL_SHIFT


## Plantes dont le gabarit mord dans l'empreinte [x0, x0 + nx) x [z0, z0 + nz),
## en coordonnees monde, exprimee en blocs.
##
## Le rendu de la flore, lui, travaille cellule par cellule (`cell`) : une
## instance n'est pas rognee sur les bornes d'un bloc, elle n'a donc pas besoin
## d'etre reclamee par chacun d'eux. Cette requete reste la requete d'empreinte
## de la couche — celle dont auront besoin les tests, les collisions du jalon
## 1.8 et tout modele qui, lui, s'estampe.
func placements_in(x0: int, z0: int, nx: int, nz: int) -> Array:
	var out: Array = []
	if not _lib.has_any():
		return out
	# Marge a l'echelle maximale : depuis la gigue, une plante deborde jusqu'a
	# deux fois le rayon de son modele. Une marge calculee sur le modele seul
	# laisserait passer une demi-plante a la frontiere de deux blocs.
	var margin: int = ceili(float(_lib.max_radius_blocks) * SCALE_MAX)
	var cx0: int = cell_of(x0 - margin)
	var cx1: int = cell_of(x0 + nx - 1 + margin)
	var cz0: int = cell_of(z0 - margin)
	var cz1: int = cell_of(z0 + nz - 1 + margin)
	var x1: int = x0 + nx
	var z1: int = z0 + nz
	for cz in range(cz0, cz1 + 1):
		for cx in range(cx0, cx1 + 1):
			for p in cell(cx, cz):
				var r: int = p.radius_blocks()
				if p.x + r < x0 or p.x - r >= x1:
					continue
				if p.z + r < z0 or p.z - r >= z1:
					continue
				out.append(p)
	return out


## Plantes d'une cellule. Mise en cache : une cellule sert aux neuf blocs qui
## l'entourent et a toute leur pile verticale.
func cell(cx: int, cz: int) -> Array:
	var key: int = (cz << 24) ^ cx
	_mutex.lock()
	var hit: Variant = _cells.get(key)
	if hit == null:
		hit = _cells_prev.get(key)
		if hit != null:
			_cells[key] = hit
	_mutex.unlock()
	if hit != null:
		return hit

	# Calcul hors verrou : il echantillonne le champ de terrain, ce qui est
	# reentrant et prend ~300 us. Deux fils peuvent calculer la meme cellule au
	# meme instant ; ils obtiennent le meme resultat, et payer deux fois coute
	# moins cher que faire attendre.
	var built: Array = _build_cell(cx, cz)

	_mutex.lock()
	if _cells.size() >= CELL_CACHE_CAP:
		_cells_prev = _cells
		_cells = {}
	_cells[key] = built
	_mutex.unlock()
	return built


func _build_cell(cx: int, cz: int) -> Array:
	var out: Array = []
	var rng := CWRand.new(_seed_of(cx, cz))
	# Les premiers tirages d'un LCG seme par un hachage restent correles d'une
	# cellule a l'autre : les cellules voisines partagent leurs bits hauts.
	rng.next()
	rng.next()

	var sea: int = _field.params().sea_level
	var base_x: int = cx << CELL_SHIFT
	var base_z: int = cz << CELL_SHIFT

	# Combien de plantes : decide sur le centre de la cellule.
	@warning_ignore("integer_division")
	var mid: int = CELL_SIZE / 2
	var centre: Vector3 = _field.sample_column(base_x + mid, base_z + mid)
	var density: float = CWModelLibrary.density_of(
			CWPalette.surface_index(centre.x, centre.y, centre.z, sea))
	if density <= 0.0:
		return out
	# Le budget est un nombre de *candidats*, pas de plantes : la crete de
	# placement en refusera environ deux sur trois. On divise donc par la part
	# passante, ce qui laisse `DENSITY` se lire en plantes par cellule — c'est
	# la moyenne qui est conservee, pas la regularite.
	var budget: float = density / PLACEMENT_PASS_RATE
	var count: int = floori(budget)
	if rng.unit() < budget - float(count):
		count += 1
	count = mini(count, MAX_CANDIDATES)

	for i in count:
		if out.size() >= MAX_PER_CELL:
			break
		var x: int = base_x + rng.mod(CELL_SIZE)
		var z: int = base_z + rng.mod(CELL_SIZE)

		# Crete de placement, *avant* l'echantillonnage de colonne : un candidat
		# hors plaque coute un bruit (~1 us) au lieu d'une colonne (~75 us).
		# Inverser les deux lignes multiplierait par trois le cout d'une cellule
		# sans rien changer au resultat — c'est le piege du tirage a rejet.
		if absf(CWValueNoise.sample(
				float(x) * PLACEMENT_FREQ + PLACEMENT_OFFSET_X,
				float(z) * PLACEMENT_FREQ + PLACEMENT_OFFSET_Z)) <= PLACEMENT_RIDGE:
			continue

		var sub_x: int = rng.mod(SUBBLOCK_STEPS)
		var sub_z: int = rng.mod(SUBBLOCK_STEPS)
		var turn: int = rng.mod(CWVoxelModel.ROTATIONS)
		var pick: float = rng.unit()
		var jitter: float = rng.unit()

		# La surface exacte du point, elle, est verifiee : une cellule a cheval
		# sur une plage ou une ligne de neige ne doit pas y semer sa prairie.
		var c: Vector3 = _field.sample_column(x, z)
		var surface: int = CWPalette.surface_index(c.x, c.y, c.z, sea)
		var choices: Array = _lib.for_surface(surface)
		if choices.is_empty():
			continue
		# Sous l'eau, seul le fond marin se garnit : le reste de la flore
		# n'aurait pas de sens et se verrait de loin a travers l'eau.
		if c.x < float(sea) and surface != CWPalette.GRAVEL:
			continue

		var p := Placement.new()
		p.x = x
		p.z = z
		p.y = floori(c.x) + 1
		p.fx = float(sub_x) / float(SUBBLOCK_STEPS)
		p.fz = float(sub_z) / float(SUBBLOCK_STEPS)
		p.model = choices[_choose(choices.size(), x, z, pick)]
		p.rotation = turn
		p.scale = SCALE_MIN + jitter * (SCALE_MAX - SCALE_MIN)
		out.append(p)
	return out


## Indice du modele choisi dans `choices`, croisement de la basse frequence de
## selection et du tirage d'instance.
##
## L'original teste le *signe* de `bruit(x*0,01, z*0,01)` pour trancher entre
## deux decors — `alga` ou `coral` : deux variantes de meme nature, pas deux
## familles. Generalise ici a n modeles par la **parite de l'indice** : le signe
## prend un indice sur deux, `pick` choisit dedans. Pour deux modeles, c'est mot
## pour mot le test de signe d'origine.
##
## Pourquoi la parite et non les deux moities contigues, qui viennent d'abord a
## l'esprit : la table de `CWModelLibrary` groupe les modeles par nature, les
## deux cailloux de l'herbe se suivent en fin de liste. Couper en deux blocs
## donnait donc une region a 40 % de cailloux et une sans aucun — visible sur
## la premiere capture, et ce n'etait pas une propriete du mecanisme mais de
## l'ordre de la table, qui est provisoire. La parite entrelace les natures et
## ne depend pas de cet ordre.
##
## Sans cette couche, `pick` seul melangerait uniformement les dix modeles d'un
## biome a chaque cellule : la variete serait la, la *composition regionale* pas
## du tout, et deux prairies distantes de mille blocs se ressembleraient.
static func _choose(n: int, x: int, z: int, pick: float) -> int:
	if n < 2:
		return 0
	var region: float = CWValueNoise.sample(
			float(x) * SELECTION_FREQ + SELECTION_OFFSET_X,
			float(z) * SELECTION_FREQ + SELECTION_OFFSET_Z)
	var parity: int = 0 if region < 0.0 else 1
	var span: int = (n - parity + 1) >> 1
	return parity + 2 * mini(int(pick * float(span)), span - 1)


func _seed_of(cx: int, cz: int) -> int:
	var s: int = (cx * HASH_X) ^ (cz * HASH_Z) ^ (_field.params().world_seed * HASH_SEED)
	return (s * HASH_MIX) & 0xFFFFFFFF
