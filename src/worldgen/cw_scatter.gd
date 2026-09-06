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
##   * **0,01 decide *laquelle*.** L'original a deux cretes a cette frequence,
##     de decalages differents : la premiere tranche la famille de decor, la
##     seconde la variante. Sur une centaine de blocs c'est donc le meme choix
##     qui domine, et c'est ce qui donne a chaque region sa composition. Cette
##     partie vit maintenant dans `CWDecorRules`.
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
## -- Quel modele, et non plus seulement ou ------------------------------------
## Depuis le 2026-09-05 (seconde version), le *quoi* est porte aussi :
## `CWDecorRules` tient la regle de selection de la source — deux cretes a 0,01
## de decalages differents, la premiere pour la famille, la seconde pour la
## variante, puis une rarete entiere pour le role rare. La dispersion n'a plus
## a inventer de mecanisme de composition ; elle demande un role, puis un modele
## de ce role. Analyse : `docs/systems/02`, §8.6.
##
## Ce qui reste hors du portage : la loi de densite par biome (`DENSITY`), que
## la source ne porte pas — elle visite chaque colonne —, et le lacet libre de
## trois roles, qui attend une rotation continue du maillage.

## Cote d'une cellule de dispersion, en blocs. Aligne sur le bloc de donnees de
## Voxel Tools : une cellule par bloc, donc une couronne de 3 x 3 a consulter.
##
## C'est la valeur de la **flore basse**. Depuis le jalon 1.11, la couche des
## arbres (`CWTreeScatter`) herite de cette classe avec une cellule quatre fois
## plus grande : les deux tailles coexistent, et c'est pourquoi les champs
## `cell_size` / `cell_shift` ci-dessous existent en plus des constantes. Le
## code qui ne sert qu'a la flore continue de lire les constantes ; le code
## partage — le rendu — lit les champs de l'instance.
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

## Les deux cretes de selection — celles qui decident *laquelle* — ont demenage
## dans `CWDecorRules` avec le reste de la regle : `SELECT_FREQ`, `SELECT_A_*`
## et `SELECT_B_*`. Elles sont dix fois plus lentes que la crete de placement,
## donc une region entiere partage sa dominante.

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
	## Decalage vertical sous le bloc, en blocs. Nul pour tout ce qui pose au
	## sol — c'est-a-dire toute la flore. Il sert aux pieces d'un arbre
	## assemble : un houppier se pose au sommet d'un tronc, dont la hauteur est
	## un nombre de voxels divise par 40/3 et ne tombe donc pas sur un bloc.
	## Arrondir le mettrait a un demi-bloc de son tronc, ce qui se voit.
	var fy: float = 0.0
	var model: CWVoxelModel = null
	var rotation: int = 0
	## Role tenu par la plante (`CWDecorRules.Role`). Decide sa taille, et
	## servira au lacet libre quand le mailleur saura tourner autrement que par
	## quarts de tour.
	var role: int = CWDecorRules.Role.AUCUN
	## Gigue d'echelle de l'instance, dans [SCALE_MIN, SCALE_MAX]. L'original
	## multiplie l'echelle de chaque decor par `rand()/32767 + 1` : deux touffes
	## du meme modele n'ont pas la meme taille. Multiplie l'echelle de dessin,
	## pas la position — l'ancre reste au sol et au centre de l'empreinte.
	var scale: float = 1.0
	## Cette piece est-elle **ecrite dans le terrain** plutot qu'instanciee ?
	##
	## Vrai pour le seul tronc d'un feuillu ou d'un palmier (jalon 1.11, troisieme
	## temps). Une piece de matiere est produite par la meme passe et rangee dans
	## la meme liste que les autres — un arbre est un objet, pas deux —, mais ses
	## deux consommateurs se la partagent : `CWVoxelGenerator` l'estampe,
	## `CWFloraRenderer` l'ignore. Une seule source de verite, deux lectures.
	##
	## `hauteur` est alors la hauteur estampee **en blocs entiers**, qui n'est pas
	## `model.height * scale` : de la matiere ne se met pas a l'echelle, elle se
	## reechantillonne. C'est cette valeur-la, et non le produit, qui dit ou
	## s'accroche le premier houppier.
	var matiere: bool = false
	var hauteur: int = 0

	## Position de l'ancre, en blocs, coordonnees monde.
	func origin() -> Vector3:
		return Vector3(float(x) + fx, float(y) + fy, float(z) + fz)

	## Rayon reellement occupe, en blocs, gigue comprise. C'est cette valeur —
	## et non `model.radius_blocks` — qui decide si la plante mord dans un cadre.
	func radius_blocks() -> int:
		return ceili(float(model.radius_blocks) * scale)


## Cote de cellule de *cette* couche, et son decalage binaire. Egaux aux
## constantes pour la flore ; `CWTreeScatter` les remonte a 64 blocs.
var cell_size: int = CELL_SIZE
var cell_shift: int = CELL_SHIFT

var _field: CWTerrainField
var _lib: CWModelLibrary
## Couche d'edition, si le monde en a une. Sert a savoir quelles colonnes ne
## portent plus leur relief genere — voir `_supported`.
var _edits: CWWorldEdits = null
var _cells: Dictionary = {}
var _cells_prev: Dictionary = {}
var _mutex: Mutex = Mutex.new()


func _init(terrain_field: CWTerrainField, models: CWModelLibrary = null) -> void:
	_field = terrain_field
	_lib = models if models != null else CWModelLibrary.shared()


func library() -> CWModelLibrary:
	return _lib


## Branche la couche d'edition. Sans elle, la dispersion se comporte comme avant :
## le monde n'est pas editable, donc le relief genere est le relief tout court.
func set_edits(edits: CWWorldEdits) -> void:
	_edits = edits


## Vrai si la colonne porte encore une plante posee sur `y`.
##
## Une plante se tient sur le bloc `y - 1`. Tant que la colonne est intacte, le
## relief genere fait foi et il n'y a rien a verifier — c'est le cas de la quasi
## totalite du monde, et le test se resume a un dictionnaire vide. Une colonne
## creusee, elle, a un sommet connu : si la plante ne repose plus dessus, elle
## flotte ou elle est enterree, et dans les deux cas elle n'a plus lieu d'etre.
func _supported(x: int, z: int, y: int) -> bool:
	if _edits == null:
		return true
	var top: int = _edits.edited_top(x, z)
	return top == CWWorldEdits.NOT_EDITED or top == y - 1


## Cellules dont le terrain a bouge depuis le dernier appel. Passe-plat vers la
## couche d'edition : le rendu ne connait que la dispersion, et n'a pas a savoir
## si le monde est editable.
func take_dirty_cells() -> Array:
	return [] if _edits == null else _edits.take_dirty_cells()


## Oublie une cellule : sa flore sera retiree au prochain passage.
func invalidate_cell(cx: int, cz: int) -> void:
	var key: int = (cz << 24) ^ cx
	_mutex.lock()
	_cells.erase(key)
	_cells_prev.erase(key)
	_mutex.unlock()


func clear_cache() -> void:
	_mutex.lock()
	_cells.clear()
	_cells_prev.clear()
	_mutex.unlock()


static func cell_of(v: int) -> int:
	return v >> CELL_SHIFT


## La meme, mais sur la taille de cellule de *cette* couche. Le rendu passe par
## celle-ci : c'est le seul point ou il doit ignorer s'il sert la flore ou les
## arbres.
func cell_index(v: int) -> int:
	return v >> cell_shift


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
	# deux fois le rayon de son modele, et le rapport de taille de son role peut
	# encore l'agrandir. Une marge calculee sur le modele seul laisserait passer
	# une demi-plante a la frontiere de deux blocs.
	var margin: int = ceili(float(_lib.max_radius_blocks) * SCALE_MAX
			* CWDecorRules.SCALE_RATIO_MAX)
	var cx0: int = cell_index(x0 - margin)
	var cx1: int = cell_index(x0 + nx - 1 + margin)
	var cz0: int = cell_index(z0 - margin)
	var cz1: int = cell_index(z0 + nz - 1 + margin)
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
	var base_x: int = cx << cell_shift
	var base_z: int = cz << cell_shift

	# Combien de plantes : decide sur le centre de la cellule.
	@warning_ignore("integer_division")
	var mid: int = cell_size / 2
	var centre: Vector3 = _field.sample_column(base_x + mid, base_z + mid)
	# La densite se lit sur le **biome**, pas sur la matiere du centre : une
	# cellule de prairie dont le centre tombe sur un rocher garde la densite de
	# sa prairie, et ce sont ses candidats, un a un, que le filtre de matiere
	# ecarte plus bas. L'ancienne table, indexee par matiere, rendait sterile
	# toute une cellule pour un centre malheureux.
	var density: float = CWModelLibrary.density_of(
			CWBiome.at(centre.x, centre.y, centre.z, sea))
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
		var x: int = base_x + rng.mod(cell_size)
		var z: int = base_z + rng.mod(cell_size)

		# Crete de placement, *avant* l'echantillonnage de colonne : un candidat
		# hors plaque coute un bruit (~1 us) au lieu d'une colonne (~75 us).
		# Inverser les deux lignes multiplierait par trois le cout d'une cellule
		# sans rien changer au resultat — c'est le piege du tirage a rejet.
		if absf(CWValueNoise.sample(
				float(x) * PLACEMENT_FREQ + PLACEMENT_OFFSET_X,
				float(z) * PLACEMENT_FREQ + PLACEMENT_OFFSET_Z)) <= PLACEMENT_RIDGE:
			continue

		# Les cinq tirages sont pris *avant* tout test, et toujours les cinq :
		# un tirage conditionnel desynchroniserait le flux du LCG d'un candidat
		# a l'autre, et la cellule ne serait plus reproductible.
		var sub_x: int = rng.mod(SUBBLOCK_STEPS)
		var sub_z: int = rng.mod(SUBBLOCK_STEPS)
		var turn: int = rng.mod(CWVoxelModel.ROTATIONS)
		var pick: float = rng.unit()
		var jitter: float = rng.unit()
		var rare: int = rng.next()

		# Le biome et la matiere exacte du point, tous deux verifies : une
		# cellule a cheval sur une plage, une ligne de neige ou une frontiere de
		# climat ne doit pas y semer sa prairie.
		var c: Vector3 = _field.sample_column(x, z)
		var biome: int = CWBiome.at(c.x, c.y, c.z, sea)
		var surface: int = CWPalette.surface_of(biome, c.x - float(sea),
				c.y, c.z, x, z)
		# Sous l'eau, seul le fond marin se garnit : le reste de la flore
		# n'aurait pas de sens et se verrait de loin a travers l'eau.
		if c.x < float(sea) and surface != CWPalette.GRAVEL:
			continue
		# Scorie, coulee de lave, neige hors Snowlands : rien n'y pousse. C'est
		# le filtre qui remplace l'ancienne table par matiere — voir
		# `CWDecorRules.decor_allowed`.
		if not CWDecorRules.decor_allowed(biome, surface):
			continue

		# Le role d'abord, le modele ensuite. Les deux cretes de selection sont
		# regionales : sur une centaine de blocs c'est le meme role qui domine,
		# et c'est de la que vient la composition d'une prairie.
		var role: int = CWDecorRules.role_at(biome, surface, x, z)
		if role == CWDecorRules.Role.AUCUN:
			continue
		var rarity: int = CWDecorRules.rarity_of(role)
		if rarity > 1 and rare % rarity != 0:
			continue
		var choices: Array = _lib.for_role(biome, role)
		if choices.is_empty():
			continue

		var ground: int = floori(c.x) + 1
		if not _supported(x, z, ground):
			continue

		var p := Placement.new()
		p.x = x
		p.z = z
		p.y = ground
		p.fx = float(sub_x) / float(SUBBLOCK_STEPS)
		p.fz = float(sub_z) / float(SUBBLOCK_STEPS)
		p.model = choices[mini(int(pick * float(choices.size())), choices.size() - 1)]
		p.rotation = turn
		p.role = role
		p.scale = CWDecorRules.scale_ratio_of(role) 				* (SCALE_MIN + jitter * (SCALE_MAX - SCALE_MIN))
		out.append(p)
	return out


## Selection du modele : le role vient de `CWDecorRules`, ici on ne fait plus
## que departager les variantes d'un meme role par le tirage d'instance.
##
## Ce qui etait la avant le 2026-09-05 (seconde version) : `_choose`, qui prenait
## un indice sur deux dans la liste du biome selon le signe d'une crete de bruit.
## C'etait une invention de ce projet, faute de connaitre la table d'origine. La
## source, elle, choisit un **role** par deux cretes de decalages differents,
## puis pose le modele de ce role : `docs/systems/02`, §8.6. La parite d'indice
## disparait donc, et avec elle la dependance a l'ordre de la table — qui etait
## sa faiblesse connue.


func _seed_of(cx: int, cz: int) -> int:
	var s: int = (cx * HASH_X) ^ (cz * HASH_Z) ^ (_field.params().world_seed * HASH_SEED)
	return (s * HASH_MIX) & 0xFFFFFFFF
