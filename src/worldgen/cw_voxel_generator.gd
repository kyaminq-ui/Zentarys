@tool
class_name CWVoxelGenerator
extends VoxelGeneratorScript

## Discretisation du champ de terrain en blocs voxels, pour Voxel Tools 1.7.
##
## -- Plan d'implementation ---------------------------------------------------
## Incompatibilite structurelle assumee : l'original est un generateur
## mono-thread qui remplit des colonnes persistantes de 32 octets dans une
## grille de regions 256x256 (Chunk_getColumnAt @00406100) et met en cache
## l'altitude par colonne. Voxel Tools appelle _generate_block depuis un pool de
## fils, sur des blocs cubiques, sans etat partage. On s'y conforme :
##   * le champ de terrain est purement fonctionnel, donc reentrant ;
##   * l'etat partage se limite a des caches proteges par mutex (sites de
##     region, cartes de hauteurs par colonne de blocs, cellules de flore) ;
##   * les colonnes sont remplies par intervalles (fill_area) plutot que voxel
##     par voxel.
##
## Le cache de cartes de hauteurs joue le role du cache de colonnes de
## l'original, et il est indispensable : le monde porte est haut (relief
## jusqu'a ~600 blocs), donc une meme colonne (x, z) est traversee par une
## quinzaine de blocs verticaux qui, sans lui, referaient tous le meme
## echantillonnage.
##
## Le rendu vise VoxelMesherCubes en mode `COLOR_RAW` : chaque voxel porte sa
## couleur, ce qui reproduit l'aspect « cubes colores » de l'original sans
## bibliotheque de modeles de blocs — et c'est la disposition du binaire, ou un
## bloc fait trois octets de couleur plus un d'attributs.
##
## **Deux canaux sont donc remplis**, et ils ne disent pas la meme chose :
## `CHANNEL_TYPE` porte l'index de palette, la valeur semantique dont vivent les
## surfaces, la flore, l'edition et les collisions ; `CHANNEL_COLOR` porte la
## couleur, que seul le mailleur lit. Voir `CWPalette`, en-tete.

## Nombre de colonnes de blocs gardees en cache. Au-dela, la generation
## precedente est jetee d'un bloc : un LRU a deux generations, sans ordre a
## maintenir et au cout d'eviction amorti.
##
## Ce plafond doit couvrir toute l'empreinte horizontale chargee, sinon le cache
## s'auto-evince en boucle et chaque bloc repaie l'echantillonnage complet. Une
## distance de vue de D blocs demande (2D/16)^2 entrees : 2 304 pour D = 384,
## 9 216 pour D = 768, et **16 384 pile pour D = 1024** — c'est la distance de
## vue que ce plafond borne, et au-dela le chargement s'effondre sans rien
## signaler (invariant n. 5).
##
## > ⚠️ **Le cout d'une entree etait annonce cinq fois trop bas.** Le fichier a
## > porte « ~1,3 Ko l'entree, 16 384 entrees tiennent dans ~21 Mo » ; une entree
## > porte 256 colonnes et **cinq** tableaux — hauteurs (4 o), matiere (1 o),
## > teinte (4 o), etang (8 o) et chemin (8 o) —, soit **6,4 Ko**. Le plafond
## > autorise donc **105 Mo**, et deux generations coexistent, ce qui en fait
## > 210 au pire. Mesure du 2026-09-11, corrigee sur un calcul et non sur une
## > estimation : voir `PATCH_BYTES` et la ligne memoire de la demo.
const HEIGHTMAP_CACHE_CAP: int = 16384

## Octets qu'occupe une entree du cache de colonnes.
##
## 256 colonnes par entree, et cinq tableaux par colonne : hauteur (float 32),
## matiere (octet), teinte (int 32), intervalle d'etang (deux int 32) et
## intervalle de chemin (deux int 32). Les en-tetes de `Packed*Array` et
## l'objet `RefCounted` s'ajoutent par-dessus, donc c'est une **borne basse**.
##
## Elle est ici pour que la ligne memoire de la demo puisse la citer, et pour
## qu'un chiffre de ce genre ne soit plus jamais estime a la louche dans un
## commentaire.
const PATCH_BYTES: int = 256 * (4 + 1 + 4 + 8 + 8)

## Attente maximale, en millisecondes, avant de renoncer a attendre le fil qui
## calcule deja la meme carte de hauteurs et de la calculer soi-meme. Filet de
## securite : sans lui, un fil interrompu bloquerait les autres.
const PATCH_WAIT_MAX_MS: int = 500


## Carte de hauteurs et de blocs de surface pour l'empreinte (x, z) d'un bloc.
class ColumnPatch extends RefCounted:
	## Dessus de la matiere, **creusement des etangs compris** : c'est le sol
	## reellement genere, pas la sortie brute du champ. Le creusement abaisse la
	## colonne, donc `lowest` le suit sans rien de plus — et c'est necessaire,
	## les deux chemins rapides de `_generate_block` s'appuyant dessus.
	var heights: PackedFloat32Array
	var surfaces: PackedByteArray
	## Teinte du bloc de surface, en RVB sur 24 bits — l'alpha d'une matiere de
	## terrain vaut toujours 255, donc il n'est pas range. **Ce n'est pas la
	## couleur du type** : c'est celle que `CWPalette.surface_shaded` a calculee
	## pour *cette* colonne, et deux blocs de la meme matiere n'ont pas la meme.
	var surface_colors: PackedInt32Array
	## Deux entiers par colonne : l'intervalle d'eau d'etang, borne haute
	## **incluse**. `bas > haut` — le cas courant — veut dire pas d'eau.
	## L'ocean n'est pas ici : il se deduit du niveau de la mer.
	var ponds: PackedInt32Array
	## Deux entiers par colonne : l'intervalle d'air degage **au-dessus d'un
	## chemin**, borne haute **incluse**. `bas > haut` veut dire pas de chemin.
	var roads: PackedInt32Array
	## Plus bas point de matiere continue. Prend en compte le **plancher du
	## degagement d'un chemin** : sans lui, le chemin rapide « bloc entierement
	## plein » reboucherait une tranchee sans qu'aucun test ne le voie, puisqu'il
	## ne regarde pas les intervalles.
	var lowest: float = INF
	## Plus haut point de matiere ou d'eau.
	var highest: float = -INF


@export var params: CWWorldParams:
	set(value):
		params = value
		_field = null
		_scatter = null
		_tree_scatter = null
		clear_caches()

## Epaisseur de la couche meuble sous la surface.
@export_range(0, 8, 1) var subsurface_depth: int = 3

var _field: CWTerrainField
var _scatter: CWScatter
var _tree_scatter: CWTreeScatter
var _field_mutex: Mutex = Mutex.new()
var _patches: Dictionary = {}
var _patches_prev: Dictionary = {}
var _in_progress: Dictionary = {}
var _patch_mutex: Mutex = Mutex.new()
var _shutting_down: bool = false


## Rend instantanee toute generation encore en file.
##
## A la fermeture, Voxel Tools attend que son pool de fils ait vide sa file
## avant de rendre la main. Une file de plusieurs milliers de blocs a ~20 ms
## piece fait attendre l'utilisateur pour un travail dont le resultat sera jete
## immediatement. On ne peut pas annuler les taches deja soumises, mais on peut
## les rendre gratuites : a partir d'ici, chaque bloc est rempli d'air et rendu.
##
## Lu depuis les fils de generation, ecrit depuis le fil principal. Un booleen
## suffit : sa valeur ne fait que passer de faux a vrai, et lire l'ancienne
## valeur une fois de plus ne coute qu'un bloc genere pour rien.
func request_shutdown() -> void:
	_shutting_down = true
	clear_caches()


func is_shutting_down() -> bool:
	return _shutting_down


func field() -> CWTerrainField:
	if _field != null:
		return _field
	_field_mutex.lock()
	if _field == null:
		if params == null:
			params = CWWorldParams.new()
		_field = CWTerrainField.new(params)
		_scatter = CWScatter.new(_field)
		_tree_scatter = CWTreeScatter.new(_field)
	var f: CWTerrainField = _field
	_field_mutex.unlock()
	return f


## Grille de dispersion de la flore. Construite avec le champ de terrain.
##
## Le generateur ne s'en sert pas : la flore est instanciee par-dessus le
## terrain, pas ecrite dedans. Elle vit ici parce que c'est ici qu'est le champ
## sur lequel elle s'appuie, et que le rendu (`CWFloraRenderer`) doit disperser
## sur exactement le meme relief que celui qui est genere.
func scatter_grid() -> CWScatter:
	field()
	return _scatter


## Grille de dispersion des **arbres** — la couche jumelle, cellule de 64 blocs
## et bibliotheque a part (`CWTreeScatter`). Meme raison d'etre ici : elle
## s'appuie sur le meme champ de terrain que la flore et que la generation.
##
## **Le generateur s'en sert, lui** (jalon 1.11) : les troncs sont ecrits dans
## les donnees du monde par `_stamp_trees`. C'est le meme exemplaire que celui
## du rendu — un seul cache de cellules, donc le tronc estampe et le houppier
## instancie viennent forcement du meme tirage.
func tree_scatter_grid() -> CWTreeScatter:
	field()
	return _tree_scatter


## Entrees de cache de colonnes vivantes, les deux generations comprises.
## Pour l'ATH : multipliee par `PATCH_BYTES`, elle donne ce que la couche de
## generation tient en memoire, qui est le seul poste qu'elle possede.
func patch_count() -> int:
	_patch_mutex.lock()
	var n: int = _patches.size() + _patches_prev.size()
	_patch_mutex.unlock()
	return n


func clear_caches() -> void:
	_patch_mutex.lock()
	_patches.clear()
	_patches_prev.clear()
	_in_progress.clear()
	_patch_mutex.unlock()
	if _scatter != null:
		_scatter.clear_cache()
	if _tree_scatter != null:
		_tree_scatter.clear_cache()


## Bloc occupant l'altitude `y` d'une colonne, en fonction de son profil.
##
## C'est **la** regle qui dit ce qu'il y a a un endroit donne, et elle a deux
## consommateurs : `_generate_block`, qui la deroule par intervalles pour remplir
## un bloc voxel vite, et `generated_voxel`, qui l'evalue en un point pour
## repondre a une requete. Les deux doivent dire la meme chose ; ils sont ecrits
## differemment parce qu'ils n'ont pas le meme cout a optimiser, et un test les
## compare colonne par colonne pour que la derive ne s'installe pas en silence.
##
## L'ordre des tests est celui des recouvrements de `_generate_block`, ou les
## intervalles sont poses du plus profond au plus superficiel et s'ecrasent :
## avec `subsurface = 0`, le remplissage de roche monte jusqu'a `top` et le bloc
## de surface le recouvre. Tester la roche en premier ici rendrait de la roche
## la ou le monde genere montre de l'herbe.
##
## Portage : `World_getBlockAt` @00405fd0 rend de meme un bloc par colonne et
## altitude. L'original ne stocke pas l'eau — au-dessus de la matiere, il rend
## un temoin d'eau si `z <= 0` et un temoin d'air sinon, `z = 0` etant son niveau
## de la mer. Ici l'eau est ecrite dans les donnees, mais la regle est la meme et
## `CWWorldEdits` la rejoue a l'effacement. Voir `docs/systems/03`, section 4.
##
## `[pond_lo, pond_hi]` est l'intervalle d'eau d'etang du jalon 1.14, borne
## haute **incluse** ; `pond_lo > pond_hi` veut dire pas d'etang, et c'est le cas
## de 96,6 % des colonnes. Il est **teste en premier**, parce qu'un etang
## *recouvre* le terrain : l'ordre des tests doit suivre celui des recouvrements
## de `_generate_block`, comme la note ci-dessus l'exige deja pour la roche.
##
## `top` est ici le sol **apres creusement** (`CWTerrainField.column_profile`),
## pas la sortie brute du champ ; les deux consommateurs doivent lui passer la
## meme valeur, et c'est ce que la verification des 4 096 points compare.
## `[road_lo, road_hi]` est le degagement creuse au-dessus d'un chemin (jalon
## 1.16), borne haute **incluse**. Il est vide — `bas > haut` — sur la
## quasi-totalite du monde, et ses valeurs par defaut disent exactement cela :
## un appelant qui ne connait pas la couche de chemins decrit le monde d'avant
## elle, ce qui est ce que veulent les verifications de la regle nue.
##
## **L'ordre complet des recouvrements est donc : chemin, etang, terrain.** Le
## chemin passe en premier parce qu'il est de l'air et que l'air efface tout.
static func voxel_of(y: int, top: int, surface: int, subsurface: int,
		sea: int, pond_lo: int, pond_hi: int,
		road_lo: int = 1, road_hi: int = 0) -> int:
	if y >= road_lo and y <= road_hi:
		return CWPalette.AIR
	if y >= pond_lo and y <= pond_hi:
		return CWPalette.water_index(float(pond_hi - y))
	if y == top:
		return surface
	if y > top:
		if y <= sea:
			return CWPalette.water_index(float(sea - top))
		return CWPalette.AIR
	if y > top - subsurface:
		return CWPalette.subsurface_index(surface)
	return CWPalette.STONE


## Le type de bloc d'un arbre estampe en ce point, ou `AIR`. Coordonnees
## **monde**.
##
## -- Pourquoi cette fonction existe -------------------------------------------
##
## `_stamp_trees` ecrit les arbres **dans les donnees du monde**, mais du seul
## cote de `_generate_block`. La requete ponctuelle les ignorait, et les deux
## ecritures de la regle decrivaient donc deux mondes differents sur chaque
## colonne qui porte un arbre : le bloc genere rend du bois, la requete rendait
## de l'air. C'est l'invariant n. 18 en defaut, et il n'etait pas visible parce
## que les deux balayages qui le tiennent — les 4 096 points du jalon 1.8 et
## l'accord de `tests/relief_test.gd` — tombaient l'un sur un bloc sans arbre,
## l'autre sur le coeur d'un massif. Releve le 2026-09-10, en repointant le
## second sur une chaussee apres le retrait des massifs.
##
## **Depuis le 2026-09-11 elle couvre aussi le feuillage**, qui est passe en
## matiere avec le reste de l'arbre. C'etait le piege annonce : une couche
## ajoutee d'un seul cote donne un monde dont les collisions et l'edition
## decrivent autre chose que ce qu'on voit, et le tronc en avait deja fait la
## demonstration pendant quatre jalons.
##
## Elle rend un **type** et non un booleen, parce qu'un arbre n'est plus d'une
## seule matiere : bois, feuillage, et roche pour le rocher geant. Le type se
## lit sur la palette du voxel (`CWPalette.matiere_de`), jamais sur la piece.
##
## Ce que ca coute : une consultation de la grille d'arbres, soit une a quatre
## cellules, toutes en cache apres la premiere. C'est du chemin **froid** —
## `_generate_block` ne passe pas par ici, il a sa propre boucle.
func tree_at(wx: int, y: int, wz: int) -> int:
	if not field().params().trees:
		return CWPalette.AIR
	var trees: CWTreeScatter = tree_scatter_grid()
	if trees == null:
		return CWPalette.AIR
	var trouve: int = CWPalette.AIR
	for pl in trees.pieces_in(wx, wz, 1, 1):
		var span: Vector2i = CWTreeScatter.piece_span(pl)
		if y < span.x or y > span.y:
			continue
		for v in CWTreeScatter.piece_voxels(pl):
			if v.x != wx or v.y != y or v.z != wz:
				continue
			var t: int = CWPalette.matiere_de(v.w)
			# **Le feuillage ne recouvre rien**, et c'est ce qui rend la
			# reponse independante de l'ordre. Sans cette regle, une couronne
			# posee sur l'axe de son fut couvre le fut, et les deux ecritures
			# de la regle se departagent par l'ordre de leurs listes : le bloc
			# rendait du feuillage, la requete du bois. Constate le
			# 2026-09-11, a la premiere execution de la suite.
			if t != CWPalette.LEAVES:
				return t
			trouve = t
	return trouve


## Bloc genere en un point, en coordonnees de scene. Ne consulte aucune edition :
## c'est le monde tel que le champ le decrit.
##
## Chemin froid, une colonne par appel (~75 us). Pour un volume, passer par
## `_generate_block` ou par `sample_patch` — la remarque de `nextsteps.md` sur
## `sample_column` vaut ici mot pour mot.
func generated_voxel(x: int, y: int, z: int) -> int:
	var f: CWTerrainField = field()
	var p: CWWorldParams = f.params()
	var wx: int = p.world_origin.x + x
	var wz: int = p.world_origin.y + z
	# L'arbre estampe (jalon 1.11, feuillage compris depuis le 2026-09-11) passe
	# **avant tout le reste**, parce que `_stamp_trees` ecrit apres tous les
	# remplissages de `_generate_block` : il recouvre ce qui precede, et l'ordre
	# des tests d'ici est celui des recouvrements, a l'envers (invariant n. 39).
	var arbre: int = tree_at(wx, y, wz)
	if arbre != CWPalette.AIR and arbre != CWPalette.LEAVES:
		return arbre
	var c: Vector4 = f.sample_column_full(wx, wz)
	var sea: int = p.sea_level
	var biome: int = CWBiome.at(c.x, c.y, c.z, sea)
	var prof: Vector3i = CWTerrainField.column_profile(c.x, c.w, sea, biome)
	var slope: float = f.slope_at(wx, wz) if p.cliff_slope else 0.0
	var surface: int = CWPalette.surface_of(f.fringe_biome(wx, wz, c.x),
			c.x - float(sea), wx, wz, slope)
	surface = pond_surface(surface, prof,
			CWTerrainField.pond_gate(c.x, c.w, sea, biome))
	var zone: CWPathNetwork.Zone = f.paths().empty_zone()
	if p.road_network:
		zone = f.paths().zone_at(wx, wz, f)
	var cells: PackedInt32Array = zone.index.get(
			CWPathNetwork.cell_key(wx, wz), PackedInt32Array())
	var road := Vector2(INF, 0.0)
	var shape := Vector3i(prof.x, 1, 0)
	if not cells.is_empty():
		road = CWPathNetwork.nearest(zone, cells, float(wx), float(wz))
		shape = road_shape(road, prof.x,
				CWPathNetwork.causeway_at(zone, float(wx), float(wz)),
				CWTerrainField.free_water(prof, sea))
		prof.x = shape.x
		# La levee **enterre l'eau qu'elle comble** : sans cette coupe, l'etang
		# reste ecrit dans le remblai, et le chemin traverse une riviere qui
		# coule dedans. Voir `road_shape`.
		prof.y = maxi(prof.y, prof.x + 1)
		surface = CWPalette.blended(CWPalette.GRAVEL, surface,
				clampf((road.x - CWPathNetwork.HALF_WIDTH)
						/ CWPathNetwork.ROAD_FADE, 0.0, 1.0), wx, wz)
	var sol: int = voxel_of(y, prof.x, surface, subsurface_depth, sea, prof.y,
			prof.z, shape.y, shape.z)
	# **Le feuillage ne recouvre que le vide**, et c'est la seule couche du
	# monde qui ait cette forme-la. Un fut, un chemin, un etang recouvrent ce
	# qu'ils traversent ; une couronne, non — elle est posee autour d'un fut
	# qu'elle ne doit pas effacer, et elle deborde parfois jusqu'au sol qu'elle
	# ne doit pas remplacer par des feuilles.
	#
	# La regle est ecrite ici **et** dans `_stamp_trees`, comme tout ce qui est
	# dans `voxel_of` (invariant n. 18). Elle vaut d'etre dite plutot que
	# devinee : sans elle, l'ordre des deux listes decide, et deux listes
	# construites par deux chemins differents ne sont pas dans le meme ordre.
	if sol == CWPalette.AIR and arbre == CWPalette.LEAVES:
		return CWPalette.LEAVES
	return sol


## Matiere de surface d'une colonne, une fois l'etang pris en compte.
##
## **Le lit d'une mare garde la matiere de dessous, pas celle de dessus.** La
## source ne repeint pas le fond : elle ecrase d'eau des blocs qui etaient de la
## couche meuble, et c'est cette couche qu'on voit a travers l'eau. Rendre
## l'herbe du dessus mettrait une prairie verte au fond de chaque mare.
##
## C'est la seule matiere de ce depot qui ne soit ni celle d'un biome ni celle
## d'une falaise, et elle survit a la regle « un biome, une matiere » pour une
## raison qui n'est pas une exception : **ce n'est pas une matiere de surface**.
## C'est le sous-sol, vu en coupe parce que l'eau a creuse — exactement ce qu'on
## voit en creusant soi-meme, et `subsurface_index` est le point unique qui le
## dit dans les deux cas.
##
## **La rive, elle, garde la matiere de son biome depuis le 2026-09-12.** Elle
## portait du sol humide, qui etait la seconde matiere de Jungles et le seul sol
## ou poussait le roseau ; les deux sont partis ensemble (`CWDecorRules`, note
## des exceptions par matiere). Ce que la rive dessine est de la geometrie — une
## berge seche entre l'eau et le terrain —, et la geometrie ne dependait pas de
## la couleur.
static func pond_surface(surface: int, prof: Vector3i, in_gate: bool) -> int:
	if not in_gate:
		return surface
	if prof.y <= prof.z:
		return CWPalette.subsurface_index(surface)
	return surface


## Ce qu'un chemin fait a une colonne : `Vector3i(dessus, air_bas, air_haut)`.
##
## Trois cas :
##
##   * **hors de portee** — l'immense majorite des colonnes du monde — rien ne
##     change, et la fonction sort avant tout calcul ;
##   * **sur la terre** : la colonne est tranchee a l'altitude du chemin — au
##     moins un bloc sous le terrain, sur toute la largeur du ruban — et la
##     tranche de `CLEARANCE` blocs au-dessus est **effacee**. C'est cet
##     effacement qui debarrasse la chaussee de ce qui la surplombe de trop
##     pres ;
##   * **au-dessus de l'eau** : la colonne est **remblayee** jusqu'a la levee.
##     Cette branche n'est pas ici — elle est dans `CWPathNetwork.shaped_top`,
##     avec le reste de la regle de dessus, parce que les deux dispersions en
##     ont besoin autant que le generateur. Ici, seul le degagement change : une
##     levee se degage comme une chaussee.
##
## Hors chaussee, un chemin ne creuse rien : l'accotement se contente d'epouser
## le profil, et l'intervalle rendu est vide.
static func road_shape(road: Vector2, ground_top: int, span: float = NAN,
		libre: int = CWTerrainField.NO_WATER) -> Vector3i:
	if road.x >= CWPathNetwork.reach():
		return Vector3i(ground_top, 1, 0)
	var top: int = CWPathNetwork.shaped_top(ground_top, road, span, libre)
	if not CWPathNetwork.on_roadway(road):
		return Vector3i(top, 1, 0)
	return Vector3i(top, top + 1, top + CWPathNetwork.CLEARANCE)


func _get_used_channels_mask() -> int:
	return (1 << CWPalette.CHANNEL_TYPE) | (1 << CWPalette.CHANNEL_COLOR)


func _generate_block(out_buffer: VoxelBuffer, origin_in_voxels: Vector3i, lod: int) -> void:
	if _shutting_down:
		out_buffer.fill(CWPalette.AIR, CWPalette.CHANNEL_TYPE)
		out_buffer.fill(CWPalette.raw_of(CWPalette.AIR), CWPalette.CHANNEL_COLOR)
		return

	var f: CWTerrainField = field()
	var p: CWWorldParams = f.params()
	var size: Vector3i = out_buffer.get_size()
	var stride: int = 1 << lod
	var sea: int = p.sea_level

	out_buffer.fill(CWPalette.AIR, CWPalette.CHANNEL_TYPE)
	out_buffer.fill(CWPalette.raw_of(CWPalette.AIR), CWPalette.CHANNEL_COLOR)

	var patch: ColumnPatch = _get_patch(f, p, origin_in_voxels, size, stride, lod, sea)

	var y_min: int = origin_in_voxels.y
	var y_max: int = origin_in_voxels.y + (size.y - 1) * stride  # borne incluse

	# Chemins rapides : bloc entierement vide ou entierement plein. Ce sont eux
	# qui rendent praticable un monde de mille blocs de haut.
	#
	# La flore ne s'invite pas ici : ses modeles sont quatre a six fois plus fins
	# que la grille du terrain, donc ils ne sont pas ecrits dans les donnees du
	# monde mais instancies par-dessus (`CWFloraRenderer`). Le generateur n'a plus
	# a les consulter, ni a garder vivant un bloc vide pour la moitie haute d'une
	# plante.
	#
	# **Les arbres, eux, s'invitent** depuis le jalon 1.11 : ils sont ecrits dans
	# le terrain. Le vide au-dessus du sol n'est donc plus vide sur la hauteur
	# d'un arbre, et le chemin rapide doit reculer d'autant. La borne est une
	# constante et non une mesure du voisinage : un arbre pose hors du bloc peut
	# y mordre, et sa colonne n'est pas dans ce releve de hauteurs.
	#
	# Le feuillage est passe en matiere le 2026-09-11, et cette borne avec lui :
	# 48 blocs, puis 72. Elle rend le chemin rapide moins efficace **partout**,
	# y compris au-dessus d'un desert sans un arbre, et ce cout n'apparait dans
	# aucun compte de voxels ecrits. Voir `CWTreeScatter.HAUTEUR_TRONC_MAX`.
	if float(y_min) > patch.highest + float(CWTreeScatter.HAUTEUR_TRONC_MAX) \
			and y_min > sea:
		return
	if float(y_max) < patch.lowest - float(subsurface_depth):
		out_buffer.fill(CWPalette.STONE, CWPalette.CHANNEL_TYPE)
		out_buffer.fill(CWPalette.raw_of(CWPalette.STONE), CWPalette.CHANNEL_COLOR)
		return

	# Le tableau rare est teste **une fois par bloc** et non une fois par
	# colonne : il est vide dans la quasi-totalite des blocs.
	var has_roads: bool = not patch.roads.is_empty()

	var i: int = 0
	for lz in size.z:
		for lx in size.x:
			var h: float = patch.heights[i]
			var surface: int = patch.surfaces[i]
			var pond_lo: int = patch.ponds[i * 2]
			var pond_hi: int = patch.ponds[i * 2 + 1]
			var col: int = (patch.surface_colors[i] << 8) | 0xFF
			var road_lo: int = patch.roads[i * 2] if has_roads else 1
			var road_hi: int = patch.roads[i * 2 + 1] if has_roads else 0
			i += 1
			var top: int = floori(h)

			# Roche, du bas du bloc jusqu'a la couche meuble.
			_fill_run(out_buffer, lx, lz, y_min, y_max, stride,
					y_min, top - subsurface_depth, CWPalette.STONE)
			# Couche meuble.
			if subsurface_depth > 0:
				_fill_run(out_buffer, lx, lz, y_min, y_max, stride,
						top - subsurface_depth + 1, top - 1,
						CWPalette.subsurface_index(surface))
			# Bloc de surface. **Sa teinte n'est pas celle de son type** : c'est
			# celle que la regle de surface a calculee pour cette colonne, et
			# c'est elle qui fait le degrade. Voir `CWPalette.SHADE_STEPS`.
			_fill_run(out_buffer, lx, lz, y_min, y_max, stride, top, top,
					surface, col)
			# Eau, de la surface du terrain jusqu'au niveau de la mer.
			if top < sea:
				_fill_run(out_buffer, lx, lz, y_min, y_max, stride,
						top + 1, sea, CWPalette.water_index(float(sea - top)))
			# L'etang, en dernier : il *recouvre* tout ce qui precede, et c'est
			# l'ordre que `voxel_of` reproduit en le testant en premier. Les
			# deux se croisent au ras du rivage, ou une mare peut mordre sous le
			# niveau de la mer ; c'est de l'eau des deux cotes.
			#
			# Un seul intervalle, et non un remplissage par bloc : une mare
			# plafonne a **quatre** blocs de fond — la rampe triangulaire ne
			# peut pas faire mieux, et une verification de la suite le
			# verrouille — la ou `water_index` ne bascule en eau profonde qu'a
			# huit. Les deux nuances ne peuvent donc pas se cotoyer dans une
			# mare, et `voxel_of` rend la meme chose colonne par colonne.
			_fill_run(out_buffer, lx, lz, y_min, y_max, stride,
					pond_lo, pond_hi, CWPalette.WATER)

			# Le degagement du chemin, en dernier : c'est de l'air, et l'air
			# efface tout — l'eau que la levee comble comme le terrain que la
			# chaussee tranche.
			if road_hi >= road_lo:
				_fill_run(out_buffer, lx, lz, y_min, y_max, stride,
						road_lo, road_hi, CWPalette.AIR)

	_stamp_trees(out_buffer, origin_in_voxels, size, stride, lod, p, patch)


## Ecrit dans le bloc les pieces d'arbre qui le traversent (jalon 1.11 pour le
## fut, 2026-09-11 pour le feuillage et les modeles entiers).
##
## -- Pourquoi ici, et pas par la couche d'edition ----------------------------
##
## Un arbre est du monde procedural, pas une modification du joueur : le passer
## par `CWWorldEdits` mettrait chaque arbre du monde sur le disque. Il est donc
## ecrit a la generation, comme la source le fait
## (`World_fillVoxelColumnTyped`), ce qui lui donne gratuitement la persistance
## — il n'y a rien a persister —, l'edition, l'eclairage et la collision.
##
## -- Ce que ca coute ---------------------------------------------------------
##
## L'appel ne concerne que les blocs qui touchent la surface : les autres sont
## sortis par les deux chemins rapides. `pieces_in` consulte une a quatre
## cellules d'arbres, toutes en cache apres le premier bloc de la pile
## verticale, et une cellule de 64 blocs contient de l'ordre de sept arbres.
##
## -- Le type et la couleur ---------------------------------------------------
##
## Le type se lit sur la **palette du voxel** (`CWPalette.matiere_de`) et non sur
## la piece : un arbre n'est pas d'une seule matiere — un fut est du bois, un
## houppier du feuillage, et un `pin` ou un `rocher_geant` sont des modeles
## entiers qui portent les deux, ou de la roche. Attacher le type a la piece
## aurait demande une table par modele, qui aurait menti des le premier modele
## mixte.
##
## La teinte, elle, reste celle du voxel du modele. C'est le partage du jalon
## 1.9 : le canal semantique dit du bois ou du feuillage, le canal de rendu
## garde l'ecorce claire du bouleau, la sombre du tropical et les douze verts de
## la rampe de feuillage. Sans lui, il aurait fallu un type de bloc par nuance.
func _stamp_trees(buf: VoxelBuffer, origin: Vector3i, size: Vector3i,
		stride: int, lod: int, p: CWWorldParams, patch: ColumnPatch) -> void:
	# Le LOD n'est pas gere : un tronc de trois blocs de large disparait a la
	# premiere reduction, et `VoxelTerrain` ne demande que le niveau 0. La garde
	# est la pour le jour ou la pyramide reviendrait sur le tapis.
	if lod != 0 or _shutting_down or not p.trees:
		return
	var trees: CWTreeScatter = tree_scatter_grid()
	if trees == null:
		return
	# La dispersion travaille en coordonnees monde, le bloc en coordonnees de
	# scene. C'est le meme decalage qu'au jalon 1.9, et c'est le piege de repere
	# que `nextsteps.md` signale : une table rangee dans le mauvais repere ne
	# tombe jamais juste, et rien ne bronche.
	var wx: int = p.world_origin.x + origin.x
	var wz: int = p.world_origin.y + origin.z
	var placements: Array = trees.pieces_in(wx, wz, size.x, size.z)
	if placements.is_empty():
		return

	var y_min: int = origin.y
	var y_max: int = origin.y + size.y - 1
	for pl in placements:
		# L'etendue verticale d'abord : une piece entierement au-dessus ou en
		# dessous du bloc ne demande pas qu'on deroule ses milliers de voxels.
		# C'est ce qui rend le feuillage abordable — un houppier de chene fait
		# 2 316 voxels, celui de l'arbre geant 5 994, et la pile verticale des
		# blocs d'une colonne en traverse la plupart pour rien.
		var span: Vector2i = CWTreeScatter.piece_span(pl)
		if span.y < y_min or span.x > y_max:
			continue
		for v in CWTreeScatter.piece_voxels(pl):
			if v.y < y_min or v.y > y_max:
				continue
			var lx: int = v.x - wx
			var lz: int = v.z - wz
			if lx < 0 or lz < 0 or lx >= size.x or lz >= size.z:
				continue
			var ly: int = v.y - y_min
			var t: int = CWPalette.matiere_de(v.w)
			# **Le feuillage ne recouvre que le vide.** Une couronne est posee
			# autour du fut qui la porte : la laisser ecraser ce qu'elle
			# traverse effacerait le fut sur toute sa hauteur, et rendrait de
			# plus la reponse dependante de l'ordre des listes — le bloc disait
			# feuillage la ou la requete ponctuelle disait bois. La regle est la
			# meme des deux cotes, et c'est `generated_voxel` qui la porte en
			# face (invariant n. 18).
			if t == CWPalette.LEAVES and buf.get_voxel(
					lx, ly, lz, CWPalette.CHANNEL_TYPE) != CWPalette.AIR:
				continue
			buf.set_voxel(t, lx, ly, lz, CWPalette.CHANNEL_TYPE)
			buf.set_voxel(CWPalette.raw_of(v.w), lx, v.y - y_min, lz,
					CWPalette.CHANNEL_COLOR)


func _get_patch(f: CWTerrainField, p: CWWorldParams, origin_in_voxels: Vector3i,
		size: Vector3i, stride: int, lod: int, sea: int) -> ColumnPatch:
	var key := Vector3i(origin_in_voxels.x, origin_in_voxels.z, lod)

	# Les blocs d'une meme colonne (x, z) partent ensemble dans la file et sont
	# pris par des fils differents. Sans marqueur « en cours », ils manquent tous
	# le cache au meme instant et recalculent tous la meme carte de hauteurs :
	# le cache ne sert alors plus a rien pendant la phase de chargement, celle
	# qui compte. Le second arrive attend le premier au lieu de dupliquer.
	var waited: int = 0
	while true:
		_patch_mutex.lock()
		var hit: Variant = _patches.get(key)
		if hit == null:
			hit = _patches_prev.get(key)
			if hit != null:
				# Remonte l'entree dans la generation courante.
				_patches[key] = hit
		if hit != null:
			_patch_mutex.unlock()
			return hit
		if not _in_progress.has(key) or waited >= PATCH_WAIT_MAX_MS:
			# A nous de la calculer, soit parce que personne ne s'en charge, soit
			# parce que l'attente a assez dure pour qu'on cesse de faire
			# confiance a l'autre fil.
			_in_progress[key] = true
			_patch_mutex.unlock()
			break
		_patch_mutex.unlock()
		OS.delay_msec(1)
		waited += 1
		if _shutting_down:
			return _empty_patch(size)

	# Les coordonnees Godot sont relatives a l'origine de monde : c'est ce qui
	# permet de jouer au centre de la carte d'origine (coordonnees monde de
	# l'ordre de 8,4 millions) tout en gardant des coordonnees de scene proches
	# de zero. Le decalage s'applique ici et nulle part ailleurs, sans quoi le
	# terrain rendu et les mesures de l'interface decrivent deux endroits
	# differents du monde.
	var ox: int = p.world_origin.x + origin_in_voxels.x
	var oz: int = p.world_origin.y + origin_in_voxels.z

	var patch := ColumnPatch.new()
	var n: int = size.x * size.z
	patch.heights.resize(n)
	patch.surfaces.resize(n)
	patch.surface_colors.resize(n)
	patch.ponds.resize(n * 2)
	# `roads` decrit un accident rare — une tranchee, une levee — et reste
	# **vide** dans les blocs qui n'en portent pas, c'est-a-dire l'immense
	# majorite. L'allouer d'office ferait grossir de moitie une carte de
	# hauteurs, et le cache en garde seize mille.
	# Le reseau de chemins (jalon 1.16), consulte **une fois par bloc**. Une
	# cellule d'index fait 256 unites et un bloc de terrain 16, tous deux
	# alignes : les 256 colonnes tombent dans la meme cellule, et l'index a deja
	# elargi l'emprise de chaque segment de la portee du chemin.
	var road_zone: CWPathNetwork.Zone = f.paths().empty_zone()
	if p.road_network:
		road_zone = f.paths().zone_at(ox, oz, f)
	var road_cells: PackedInt32Array = road_zone.index.get(
			CWPathNetwork.cell_key(ox, oz), PackedInt32Array())
	# Une seule descente dans le champ : sample_patch ne consulte le cache de
	# fenetres de sites qu'une fois par zone traversee, au lieu d'une fois par
	# colonne.
	#
	# **Une colonne de plus sur chaque axe**, depuis que la falaise est revenue
	# (jalon 1.15) : la pente se mesure par difference avant, donc la derniere
	# rangee a besoin de la premiere rangee du bloc voisin. C'est 33 colonnes de
	# plus sur 256, soit **+12,9 %** d'echantillonnage, et c'est le prix de la
	# falaise — paye ici et nulle part ailleurs. Le pochoir est aligne sur la
	# grille du monde et non sur celle du bloc, ce qui est la condition pour que
	# la requete ponctuelle (`slope_at`) rende exactement le meme nombre.
	var ring: int = 1 if p.cliff_slope else 0
	var rx: int = size.x + ring
	var raw: PackedFloat32Array = f.sample_patch(ox, oz, rx, size.z + ring,
			stride)
	var step_f: float = float(stride)
	# La fenetre de sites de l'ecotone, prise une fois par zone traversee et non
	# une fois par colonne : les 256 colonnes d'un bloc de 16 tombent presque
	# toujours dans la meme zone de 16384 unites, et le cache de fenetres est
	# protege par mutex. C'est la meme economie que celle de `sample_patch`,
	# refaite ici parce que la recherche de site tramee est le seul consommateur
	# de la fenetre qui ne passe pas par lui.
	var win: Array = []
	var last_zx: int = 0x7FFFFFFF
	var last_zz: int = 0x7FFFFFFF
	for i in n:
		# Meme parcours que `sample_patch` : iz a l'exterieur, ix a l'interieur.
		# La regle de surface a besoin des coordonnees monde depuis le jalon
		# 1.12 — voir `CWPalette.lava_flow`.
		@warning_ignore("integer_division")
		var iz: int = i / size.x
		var ix: int = i - iz * size.x
		var cx: int = ox + ix * stride
		var cz: int = oz + iz * stride
		var zx: int = CWWorldParams.zone_of(cx - CWWorldParams.ZONE_SIZE)
		var zz: int = CWWorldParams.zone_of(cz - CWWorldParams.ZONE_SIZE)
		if zx != last_zx or zz != last_zz:
			win = f.sites().get_window(zx, zz)
			last_zx = zx
			last_zz = zz
		var j: int = (iz * rx + ix) * 4
		var h: float = raw[j]
		var chan: float = raw[j + 3]
		var slope: float = 0.0
		if ring > 0:
			slope = CWTerrainField.slope_from(h,
					raw[(iz * rx + ix + 1) * 4], raw[((iz + 1) * rx + ix) * 4],
					step_f)

		# L'etang du jalon 1.14. `column_profile` rend le sol **apres**
		# creusement ; c'est lui qu'on range dans `heights`, et non la sortie
		# brute du champ.
		#
		# **C'est le piege de cette passe** : les deux chemins rapides de
		# `_generate_block` s'appuient sur `lowest` et `highest`. Un creusement
		# abaisse la colonne, donc si `lowest` gardait la hauteur d'avant, un
		# bloc entierement plein de roche serait rendu la ou il y a desormais un
		# trou — et le fond de la mare serait invisible, bouche par le chemin
		# rapide. Prendre le minimum **apres** le profil est tout ce qu'il faut,
		# et c'est la raison pour laquelle le creusement s'exprime ici en
		# abaissement de colonne plutot qu'en passe separee.
		var biome: int = CWBiome.at(h, raw[j + 1], raw[j + 2], sea)
		var prof: Vector3i = CWTerrainField.column_profile(h, chan, sea, biome)



		# Le chemin, en dernier : il tranche la colonne que tout le reste vient
		# de decrire.
		var road := Vector2(INF, 0.0)
		var shape := Vector3i(prof.x, 1, 0)
		if not road_cells.is_empty():
			road = CWPathNetwork.nearest(road_zone, road_cells,
					float(cx), float(cz))
			shape = road_shape(road, prof.x,
					CWPathNetwork.causeway_at(road_zone, float(cx), float(cz)),
					CWTerrainField.free_water(prof, sea))
			prof.x = shape.x
			# La levee **enterre l'eau qu'elle comble** : sans cette coupe,
			# l'etang reste ecrit dans le remblai. Voir `road_shape`.
			prof.y = maxi(prof.y, prof.x + 1)
		var ph: float = float(shape.x)
		patch.heights[i] = ph
		patch.ponds[i * 2] = prof.y
		patch.ponds[i * 2 + 1] = prof.z
		if shape.z >= shape.y:
			patch.roads = _spans(patch.roads, n)
			patch.roads[i * 2] = shape.y
			patch.roads[i * 2 + 1] = shape.z

		# La matiere du sol prend le biome **trame** — celui du site le plus
		# proche d'un point brouille de trente blocs ; tout le reste — l'eau, le
		# decor, le nom affiche — garde celui du point vrai. Voir l'en-tete de
		# `CWTerrainField.fringe_point`.
		var ss: Vector2i = CWPalette.surface_shaded(
				f.fringe_biome_in(win, cx, cz, h), h - float(sea), cx, cz, slope)
		var surf: int = pond_surface(ss.x, prof,
				CWTerrainField.pond_gate(h, chan, sea, biome))
		var col: int = ss.y if surf == ss.x else CWPalette.toned(
				CWPalette.raw_of(surf), cx, cz)
		# La chaussee, tramee dans la matiere du lieu : un chemin de terre
		# battue qui s'arreterait sur un trait aurait l'air peint. C'est le
		# meme degrade que la plage et que la falaise, sur sa propre variable.
		if road.x < CWPathNetwork.reach():
			var rs: Vector2i = CWPalette.blended_shaded(CWPalette.GRAVEL, surf,
					clampf((road.x - CWPathNetwork.HALF_WIDTH)
							/ CWPathNetwork.ROAD_FADE, 0.0, 1.0), cx, cz)
			surf = rs.x
			col = rs.y
		patch.surfaces[i] = surf
		patch.surface_colors[i] = (col >> 8) & 0xFFFFFF

		patch.lowest = minf(patch.lowest, ph)
		if shape.z >= shape.y:
			# Le plancher du degagement d'un chemin est le point d'air le plus
			# bas de la colonne : sans lui, le chemin rapide « bloc entierement
			# plein » reboucherait la tranchee, et rien ne le signalerait.
			patch.lowest = minf(patch.lowest, float(shape.y))
		# `highest` borne le vide au-dessus du monde : c'est la **surface libre**
		# qui compte, l'eau comprise, sinon le chemin rapide du haut rendrait de
		# l'air a la place du dessus d'une mare.
		patch.highest = maxf(patch.highest, maxf(ph, float(prof.z)))

	_patch_mutex.lock()
	if _patches.size() >= HEIGHTMAP_CACHE_CAP:
		_patches_prev = _patches
		_patches = {}
	_patches[key] = patch
	_in_progress.erase(key)
	_patch_mutex.unlock()
	return patch


## Alloue au besoin un tableau d'intervalles, pre-rempli de « rien ici ».
##
## Un intervalle vide se dit `bas > haut` ; le zero par defaut d'un
## `PackedInt32Array` dirait `[0, 0]`, soit un bloc de matiere a l'altitude zero
## dans chaque colonne. C'est le piege que `_empty_patch` avait deja paye une
## fois pour les etangs.
static func _spans(arr: PackedInt32Array, n: int) -> PackedInt32Array:
	if not arr.is_empty():
		return arr
	arr.resize(n * 2)
	for k in n:
		arr[k * 2] = 1
	return arr


## Carte de hauteurs neutre, rendue quand l'arret survient pendant une attente.
func _empty_patch(size: Vector3i) -> ColumnPatch:
	var patch := ColumnPatch.new()
	var n: int = size.x * size.z
	patch.heights.resize(n)
	patch.surfaces.resize(n)
	# Un intervalle d'eau vide se dit `bas > haut` : le zero par defaut d'un
	# `PackedInt32Array` dirait [0, 0], soit un bloc d'eau a l'altitude zero
	# dans chaque colonne d'un bloc rendu pendant l'arret.
	patch.surface_colors.resize(n)
	patch.ponds.resize(n * 2)
	for k in n:
		patch.ponds[k * 2] = 1
	patch.lowest = 0.0
	patch.highest = 0.0
	return patch


## Remplit l'intervalle [wy0, wy1] (coordonnees monde, bornes incluses) d'une
## colonne du bloc, en le rognant sur l'etendue verticale du bloc.
## `value` est un **index de palette** : les deux canaux sont remplis ici, le
## semantique tel quel et le rendu par `CWPalette.raw_of`. Les separer serait la
## faute a faire — un terrain dont la couleur ne suit plus le type est un monde
## qui ment a l'oeil sans qu'aucun test de logique ne s'en apercoive.
## `raw` force la couleur du canal de rendu ; `-1` prend celle du type. C'est le
## seul endroit ou les deux canaux peuvent dire autre chose l'un que l'autre, et
## c'est delibere : le type est la matiere, la couleur est sa **nuance**. Un
## appelant qui oublie `raw` obtient l'aplat d'avant le 2026-09-07, pas une
## incoherence.
func _fill_run(buf: VoxelBuffer, lx: int, lz: int, y_min: int, y_max: int,
		stride: int, wy0: int, wy1: int, value: int, raw: int = -1) -> void:
	if wy1 < wy0:
		return
	var a: int = maxi(wy0, y_min)
	var b: int = mini(wy1, y_max)
	if b < a:
		return
	# Le pas est une puissance de deux et les bornes sont alignees sur le bloc :
	# la division entiere est exactement la conversion voulue.
	@warning_ignore("integer_division")
	var ly0: int = (a - y_min) / stride
	@warning_ignore("integer_division")
	var ly1: int = (b - y_min) / stride
	var lo := Vector3i(lx, ly0, lz)
	var hi := Vector3i(lx + 1, ly1 + 1, lz + 1)
	buf.fill_area(value, lo, hi, CWPalette.CHANNEL_TYPE)
	buf.fill_area(CWPalette.raw_of(value) if raw < 0 else raw, lo, hi,
			CWPalette.CHANNEL_COLOR)
