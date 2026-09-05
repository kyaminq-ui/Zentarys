class_name CWTreeScatter
extends CWScatter

## Dispersion des arbres : la couche jumelle de celle de la flore (jalon 1.11).
##
## Elle herite de `CWScatter` pour le cache de cellules, le verrou, la reprise
## apres edition et la requete d'empreinte — tout cela est identique — et elle
## redefinit ce qui differe : la taille de cellule, la crete de placement, la
## densite, l'espacement minimum, et le montage d'un arbre en plusieurs pieces.
##
## -- Pourquoi une couche a part, et non un elargissement de la premiere -------
##
## `CWScatter` calcule la marge de `placements_in` sur
## `CWModelLibrary.max_radius_blocks`, tous modeles confondus — c'est
## l'invariant n° 17. Ranger un houppier de 3 blocs de rayon dans la
## bibliotheque de la flore ferait passer cette marge de 2 blocs a 9 pour
## **toute** la flore, et chaque `MultiMesh` d'herbe porterait une boite de
## visibilite demesuree. Deux couches, deux bibliotheques, deux marges.
##
## La cellule passe de 16 blocs a **64**. Ce n'est pas un reglage : a densite
## egale par unite de surface, une cellule de 16 blocs ne contiendrait qu'un
## arbre de temps en temps, et l'espacement minimum ci-dessous n'aurait
## quasiment jamais deux voisins a comparer — il ne servirait a rien. Une
## cellule doit etre grande devant l'espacement qu'elle fait respecter.
##
## -- La crete de placement a sa propre frequence ------------------------------
##
## `docs/ROADMAP.md`, §1.11, laissait ouvert : les arbres suivent-ils les deux
## cretes de selection de la flore, ou leur propre champ ? **Leur propre champ**
## — le raisonnement est dans `CWTreeRules`. Le *mecanisme* est celui de la
## source (`|bruit| > seuil` sur un reseau decale), la *frequence* est une
## decision de ce projet : a 0,05, la crete de la flore decoupe des plaques de
## 19 blocs, ce qui est la taille d'une touffe, pas d'un peuplement. A 0,02 la
## longueur d'onde est de 50 blocs, soit un bosquet.
##
## Partager la crete de la flore aurait eu un effet visible et faux : chaque
## arbre serait tombe dans une plaque d'herbe, et les vides entre plaques
## auraient ete exactement les vides entre bosquets. Deux couches correlees a
## cent pour cent se lisent comme une seule.
##
## -- L'espacement minimum, et pourquoi il n'est pas recursif ------------------
##
## Deux troncs a un bloc l'un de l'autre se voient tout de suite. Il faut donc
## un espacement reel, ce que la flore n'a pas — a un demi-bloc de haut, deux
## touffes qui se chevauchent ne genent personne.
##
## La difficulte est que la dispersion doit rester **sans etat et sans ordre** :
## une cellule ne peut pas demander a ses voisines ce qu'elles ont deja pose,
## sinon la construction devient recursive. La regle retenue :
##
##   * chaque cellule tire ses candidats a partir de sa seule graine — c'est
##     donc une fonction pure de son indice, calculable par n'importe qui ;
##   * pour decider d'un candidat, on regarde les candidats des **neuf cellules**
##     de son voisinage, et on l'ecarte si un candidat de **rang absolu
##     inferieur** est trop proche. Le rang est `(cz, cx, i)`, un ordre total qui
##     ne depend pas de la cellule qui pose la question.
##
## Comme `ESPACEMENT <= cell_size`, tout candidat capable de gener celui qu'on
## examine est dans ce voisinage 3 x 3 : la decision est donc la meme quelle que
## soit la cellule qui la prend, sans recursion et sans etat partage. Le prix est
## un leger exces de refus — un candidat lui-meme ecarte continue de bloquer ses
## voisins —, ce qui est sans consequence visible et vaut mieux qu'une regle qui
## se contredirait d'une cellule a l'autre.
##
## -- Ce que cette couche ne fait pas encore -----------------------------------
##
## Le tronc est **instancie**, pas ecrit dans le terrain. Il ne se creuse donc
## pas et ne porte pas de collision. La source, elle, ecrit ses troncs en
## colonnes de blocs (`World_fillVoxelColumnTyped`), et c'est le troisieme temps
## du jalon 1.11 — celui qui fera traverser a un meme objet la matiere et
## l'instance. Le lot d'assets livre `tronc_feuillu` et `tronc_palmier`
## precisement pour que ce temps-la soit separable de celui-ci.

## Cote d'une cellule d'arbres, en blocs, et son decalage. Quatre fois la
## cellule de la flore : 64 = 16 << 2, donc une cellule d'arbres couvre
## exactement seize cellules de flore, ce qui rend la conversion des cellules
## salies par une edition exacte et non approchee.
const TREE_CELL_SIZE: int = 64
const TREE_CELL_SHIFT: int = 6

## Espacement minimum entre deux troncs, en blocs.
##
## `docs/systems/02`, §6, donne **20 unites** pour la boucle de pose des
## entites, et une unite est une colonne de blocs (`CWWorldParams`). Cette
## valeur n'est pas reprise telle quelle, et il faut dire pourquoi : cette
## boucle-la place des `cube::Spawn`, c'est-a-dire des points d'apparition de
## creatures, un par tuile de 2048 unites. Le *mecanisme* est porte —
## comparaison sur le carre de la distance, rejet du candidat le plus recent —,
## la valeur est celle du projet.
##
## **Passe de 7 a 14 blocs au jalon 1.12**, et ce n'est pas un reglage de gout :
## le lot d'arbres est redessine a un voxel par bloc, ses houppiers font 12 a 16
## blocs de large la ou ils en faisaient 4,8. A 7 blocs d'ecart, deux houppiers
## voisins se traversaient de part en part. A 14, deux couronnes de rayon 7 se
## touchent sans se penetrer — c'est exactement la moitie de la largeur visee,
## et c'est de la que sort le nombre.
##
## La cellule doit rester grande devant lui (voir l'en-tete) : 64 / 14 fait
## encore 4,5 cellules de large, l'espacement mord toujours au travers des
## frontieres.
const ESPACEMENT: int = 14

## Nombre moyen d'arbres par cellule de 64 blocs, soit 4 096 colonnes.
##
## Comme `CWModelLibrary.DENSITY`, ce n'est pas un portage : la source visite
## chaque colonne. Les ordres de grandeur sont poses a l'oeil, contre le seul
## repere qu'on ait — la jungle est le biome le plus dense de l'original, le
## desert le plus vide.
##
## Plafond theorique au nouvel espacement : un empilement hexagonal de disques
## de 7 blocs de rayon dans 4 096 colonnes en tient environ **24**. Toutes les
## valeurs ci-dessous ont donc ete divisees a peu pres par deux en meme temps
## que l'espacement doublait — sans quoi la moitie des candidats de jungle
## seraient rejetes par l'espacement et la densite ne voudrait plus rien dire.
##
## La cle est le **biome** depuis le jalon 1.12. Oceans n'y figure pas : une ile
## emergee porte le biome de son climat, et une colonne sous l'eau ne porte
## aucun arbre.
const DENSITE: Dictionary = {
	CWBiome.GREENLANDS: 7.0,
	CWBiome.SNOWLANDS: 5.5,
	CWBiome.DESERTS: 0.8,
	CWBiome.JUNGLES: 14.0,
	CWBiome.LAVALANDS: 0.5,
}

## Crete de placement des arbres. Meme forme que celle de la flore, meme seuil,
## memes decalages de graine ; seule la frequence change — voir l'en-tete.
const PLACEMENT_FREQ_ARBRES: float = 0.02

## Part de la surface qui passe la crete a cette frequence. Mesuree, comme celle
## de la flore, et verrouillee par un test : le budget de candidats est divise
## par elle, donc `DENSITE` continue de se lire en arbres par cellule.
const PLACEMENT_PASS_RATE_ARBRES: float = 0.2917

## Gigue d'echelle d'un arbre. Bien plus serree que celle de la flore, qui va de
## 1x a 2x : un sapin de 8 blocs double ferait 16 blocs, plus haut que l'arbre a
## epines de la source, qui est le plus grand modele du corpus. Toutes les pieces
## d'un meme arbre partagent ce tirage, sinon le houppier ne serait plus a
## l'echelle de son tronc.
const ECHELLE_MIN: float = 0.85
const ECHELLE_MAX: float = 1.25

## Plafond dur d'arbres par cellule. Meme role de garde-fou que `MAX_PER_CELL`.
const MAX_ARBRES_PAR_CELLULE: int = 48

## Part de la hauteur du tronc a laquelle se pose le premier houppier. Un
## houppier pose au ras du sommet laisse voir la pointe du tronc au travers du
## feuillage ; pose trop bas, il enterre le fut.
const ACCROCHE_HOUPPIER: float = 0.72

## Ecart vertical entre deux houppiers empiles, en part de leur propre hauteur.
## Nettement moins de 1 : ils doivent se chevaucher, sinon on voit le tronc
## entre les deux.
const EMPILEMENT: float = 0.42

## Melangeurs propres a cette couche. Ils doivent differer de ceux de
## `CWScatter`, sinon un arbre et une touffe partagent leur flux de tirages et
## tombent au meme endroit dans chaque cellule.
const TREE_HASH_X: int = 40503551
const TREE_HASH_Z: int = 55049129
const TREE_HASH_SEED: int = 61403981


func _init(terrain_field: CWTerrainField, models: CWModelLibrary = null) -> void:
	super(terrain_field,
			models if models != null else CWModelLibrary.shared_trees())
	cell_size = TREE_CELL_SIZE
	cell_shift = TREE_CELL_SHIFT


## Cellules d'arbres salies par une edition du terrain.
##
## `CWWorldEdits` compte en cellules de flore, qui est la seule taille qu'il
## connaisse. Une cellule d'arbres en couvre exactement seize : la conversion est
## un decalage, sans perte. On deduplique, sinon seize coups de pioche dans la
## meme cellule d'arbres la feraient reconstruire seize fois.
func take_dirty_cells() -> Array:
	var fines: Array = super()
	if fines.is_empty():
		return fines
	var seen: Dictionary = {}
	var out: Array = []
	var shift: int = TREE_CELL_SHIFT - CELL_SHIFT
	for c in fines:
		var g := Vector2i(c.x >> shift, c.y >> shift)
		if not seen.has(g):
			seen[g] = true
			out.append(g)
	return out


## Les candidats bruts d'une cellule : positions et tirages, avant tout test de
## terrain et avant l'espacement.
##
## Fonction **pure de l'indice de cellule** — c'est ce qui permet a une cellule
## de consulter ses huit voisines sans declencher leur construction. Elle ne
## touche ni au champ de terrain, ni au cache.
func _candidats(cx: int, cz: int) -> Array:
	var rng := CWRand.new(_tree_seed_of(cx, cz))
	rng.next()
	rng.next()
	var base_x: int = cx << cell_shift
	var base_z: int = cz << cell_shift
	var out: Array = []
	# Le budget se decide sur la surface au centre de la cellule, comme pour la
	# flore : un biome ne change pas a l'interieur de 64 blocs.
	@warning_ignore("integer_division")
	var mid: int = cell_size / 2
	var centre: Vector3 = _field.sample_column(base_x + mid, base_z + mid)
	var biome: int = CWBiome.at(centre.x, centre.y, centre.z,
			_field.params().sea_level)
	var density: float = float(DENSITE.get(biome, 0.0))
	if density <= 0.0:
		return out
	var budget: float = density / PLACEMENT_PASS_RATE_ARBRES
	var count: int = floori(budget)
	if rng.unit() < budget - float(count):
		count += 1
	count = mini(count, MAX_ARBRES_PAR_CELLULE * 4)

	for i in count:
		# Les six tirages sont pris pour tous les candidats, et toujours les six :
		# un tirage conditionnel desynchroniserait le flux du LCG et la cellule ne
		# serait plus reproductible. C'est la meme discipline que dans `CWScatter`.
		var x: int = base_x + rng.mod(cell_size)
		var z: int = base_z + rng.mod(cell_size)
		var turn: int = rng.mod(CWVoxelModel.ROTATIONS)
		var pick: float = rng.unit()
		var jitter: float = rng.unit()
		var pieces: float = rng.unit()
		if absf(CWValueNoise.sample(
				float(x) * PLACEMENT_FREQ_ARBRES + PLACEMENT_OFFSET_X,
				float(z) * PLACEMENT_FREQ_ARBRES + PLACEMENT_OFFSET_Z)) \
				<= PLACEMENT_RIDGE:
			continue
		out.append({"x": x, "z": z, "rang": i, "turn": turn, "pick": pick,
				"jitter": jitter, "pieces": pieces})
	return out


## Vrai si le candidat `c`, de la cellule (cx, cz), survit a l'espacement.
##
## Voir l'en-tete : on compare au rang absolu `(cz, cx, i)` sur le voisinage
## 3 x 3, ce qui rend la decision independante de la cellule qui la pose.
func _espace_libre(c: Dictionary, cx: int, cz: int, voisins: Dictionary) -> bool:
	var d2: int = ESPACEMENT * ESPACEMENT
	for key in voisins:
		var vz: int = key.y
		var vx: int = key.x
		for o in voisins[key]:
			# Rang absolu : cellule d'abord (z puis x), puis rang dans la cellule.
			if vz > cz or (vz == cz and vx > cx) \
					or (vz == cz and vx == cx and int(o["rang"]) >= int(c["rang"])):
				continue
			var dx: int = int(o["x"]) - int(c["x"])
			var dz: int = int(o["z"]) - int(c["z"])
			if dx * dx + dz * dz < d2:
				return false
	return true


func _build_cell(cx: int, cz: int) -> Array:
	var out: Array = []
	if not _lib.has_any():
		return out
	var mine: Array = _candidats(cx, cz)
	if mine.is_empty():
		return out

	# Les huit voisines, pour l'espacement seul. Leurs candidats sont bruts :
	# aucune construction n'est declenchee, aucun cache n'est touche.
	var voisins: Dictionary = {}
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := Vector2i(cx + dx, cz + dz)
			voisins[key] = mine if (dx == 0 and dz == 0) \
					else _candidats(cx + dx, cz + dz)

	var sea: int = _field.params().sea_level
	for c in mine:
		if out.size() >= MAX_ARBRES_PAR_CELLULE:
			break
		if not _espace_libre(c, cx, cz, voisins):
			continue

		var x: int = int(c["x"])
		var z: int = int(c["z"])
		var col: Vector3 = _field.sample_column(x, z)
		# Un arbre les pieds dans l'eau n'existe pas ici : le sol humide est une
		# matiere a part, au-dessus du niveau de la mer.
		if col.x < float(sea):
			continue
		var biome_c: int = CWBiome.at(col.x, col.y, col.z, sea)
		# La matiere exacte du point est verifiee, comme pour la flore : un
		# bosquet de Greenlands ne monte pas sur la roche nue de sa propre
		# montagne, ni sur sa calotte de neige.
		var surface: int = CWPalette.surface_of(biome_c,
				col.x - float(sea), col.y, col.z, x, z)
		if not CWDecorRules.decor_allowed(biome_c, surface):
			continue
		var sp: Dictionary = CWTreeRules.species_at(biome_c, float(c["pick"]))
		if sp.is_empty():
			continue
		var ground: int = floori(col.x) + 1
		if not _supported(x, z, ground):
			continue
		_monte(out, sp, x, z, ground, c)
	return out


## Monte un arbre : une a plusieurs pieces, toutes a la meme echelle et au meme
## quart de tour que son tronc.
func _monte(out: Array, sp: Dictionary, x: int, z: int, ground: int,
		c: Dictionary) -> void:
	var tronc: CWVoxelModel = _lib.model(sp["tronc"])
	if tronc == null:
		return
	var echelle: float = ECHELLE_MIN \
			+ float(c["jitter"]) * (ECHELLE_MAX - ECHELLE_MIN)
	var turn: int = int(c["turn"])
	var pied := _piece(tronc, x, z, ground, 0.0, turn, echelle)
	out.append(pied)

	var montage: int = int(sp["montage"])
	if montage == CWTreeRules.Montage.ENTIER:
		return

	var couronnes: Array = sp["couronnes"]
	if couronnes.is_empty():
		return
	# Hauteur du tronc en blocs, a l'echelle de *cette* instance. C'est le seul
	# calcul de cette couche qui puisse etre faux sans qu'on le voie : un
	# houppier a un demi-bloc de trop flotte, a un demi-bloc de moins il avale la
	# cime. D'ou `fy`, qui garde la fraction au lieu de l'arrondir.
	var haut: float = float(tronc.height) * echelle / tronc.voxels_per_block
	var bornes: Array = sp["pieces"]
	var n: int = int(bornes[0]) + int(float(c["pieces"])
			* float(int(bornes[1]) - int(bornes[0]) + 1))
	n = clampi(n, int(bornes[0]), int(bornes[1]))

	if montage == CWTreeRules.Montage.PALMIER:
		_couronne_de_palmes(out, couronnes, x, z, ground, haut, turn, echelle, n)
		return

	# FEUILLU : les houppiers s'empilent en se chevauchant, du premier point
	# d'accroche vers le haut.
	var y0: float = haut * ACCROCHE_HOUPPIER
	for k in n:
		var m: CWVoxelModel = _lib.model(couronnes[(turn + k) % couronnes.size()])
		if m == null:
			continue
		var hm: float = float(m.height) * echelle / m.voxels_per_block
		var y: float = y0 + float(k) * hm * EMPILEMENT
		# Un quart de tour different par houppier : deux houppiers du meme modele
		# empiles a la meme orientation rendent une image doublee.
		out.append(_piece(m, x, z, ground, y, (turn + k * 3) % CWVoxelModel.ROTATIONS,
				echelle))


## La couronne d'un palmier : des palmes rayonnantes au sommet du stipe.
##
## Le moteur ne precalcule que **quatre quarts de tour**, d'ou les deux modeles
## de palme du lot — `palme` et `palme_diagonale`, la seconde dessinee a 45
## degres. Les deux ensemble donnent huit directions, et c'est exactement la
## raison pour laquelle l'original a `palm-leaf` et `palm-leaf-diagonal`.
##
## -- Un demi-tour ne change rien a une paire ---------------------------------
##
## Depuis le jalon 1.12, une palme est une **paire de frondes opposees** (voir
## `arbres_blocs.palme_paire` : c'est ce qui met l'attache sur l'ancre). Une
## paire est symetrique par rapport a son centre, donc la tourner d'un demi-tour
## rend exactement la meme image. Avancer le quart de tour a chaque piece —
## `(turn + k) % 4` — posait donc la troisieme palme par-dessus la premiere et
## la quatrieme par-dessus la seconde : quatre pieces, deux directions, et la
## couronne se lisait comme une planche posee en travers du stipe. Vu en capture
## sur le dattier d'oasis, le 2026-09-06.
##
## Le quart de tour n'avance donc **qu'une piece sur deux**, et le modele
## alterne a chaque piece. Quatre pieces donnent quatre paires distinctes —
## deux axes et deux diagonales, soit huit frondes — ce qui est le maximum que
## quatre quarts de tour permettent.
func _couronne_de_palmes(out: Array, couronnes: Array, x: int, z: int,
		ground: int, haut: float, turn: int, echelle: float, n: int) -> void:
	var poses: int = 0
	for k in n:
		var m: CWVoxelModel = _lib.model(couronnes[k % couronnes.size()])
		if m == null:
			continue
		# Les palmes descendent legerement a mesure qu'on en pose : une couronne
		# dont toutes les pieces sont a la meme hauteur se lit comme un disque.
		var y: float = haut - float(k) * 0.35
		@warning_ignore("integer_division")
		var quart: int = (turn + k / couronnes.size()) % CWVoxelModel.ROTATIONS
		out.append(_piece(m, x, z, ground, y, quart, echelle))
		poses += 1
	if poses == 0:
		return


## Une piece d'arbre, prete a instancier.
func _piece(m: CWVoxelModel, x: int, z: int, ground: int, dy: float,
		turn: int, echelle: float) -> Placement:
	var p := Placement.new()
	p.x = x
	p.z = z
	p.y = ground
	p.fy = dy
	# Les arbres ne sont pas decales sous leur bloc : un tronc au coin de sa
	# colonne se voit moins qu'une touffe, et surtout le tronc ecrit dans le
	# terrain, au troisieme temps du jalon, sera aligne sur la grille. Les deux
	# doivent tomber au meme endroit.
	p.fx = 0.5
	p.fz = 0.5
	p.model = m
	p.rotation = turn
	p.role = CWDecorRules.Role.AUCUN
	p.scale = echelle
	return p


func _tree_seed_of(cx: int, cz: int) -> int:
	var s: int = (cx * TREE_HASH_X) ^ (cz * TREE_HASH_Z) \
			^ (_field.params().world_seed * TREE_HASH_SEED)
	return (s * HASH_MIX) & 0xFFFFFFFF
