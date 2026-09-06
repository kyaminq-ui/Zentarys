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
## 9 216 pour D = 768. A ~1,3 Ko l'entree, 16 384 entrees tiennent dans ~21 Mo,
## ce qui couvre D = 1024 et reste negligeable a cote des blocs voxels eux-memes.
const HEIGHTMAP_CACHE_CAP: int = 16384

## Valeur d'altitude qui dit « pas de tablier de pont dans cette colonne ».
## Un entier hors du monde, plutot qu'un booleen de plus a garder en phase.
const DECK_NONE: int = -0x7FFFFFFF

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
	## Idem pour le dessus d'un surplomb. Alloue seulement si le bloc en porte.
	var cap_colors: PackedInt32Array
	## Deux entiers par colonne : l'intervalle d'eau d'etang, borne haute
	## **incluse**. `bas > haut` — le cas courant — veut dire pas d'eau.
	## L'ocean n'est pas ici : il se deduit du niveau de la mer.
	var ponds: PackedInt32Array
	## Deux entiers par colonne : l'intervalle de matiere ajoute par la couche
	## de surplombs (jalon 1.15), borne haute **incluse**. `bas > haut` — le cas
	## de la quasi-totalite du monde — veut dire pas de surplomb.
	var slabs: PackedInt32Array
	## Deux entiers par colonne : l'intervalle d'air creuse par une grotte.
	var caves: PackedInt32Array
	## Deux entiers par colonne : l'intervalle d'air degage **au-dessus d'un
	## chemin**. Distinct de celui des grottes, et il doit le rester — voir
	## `road_shape`.
	var roads: PackedInt32Array
	## Matiere du **dessus du chapeau** d'un surplomb, qui n'est pas celle du
	## sol de la meme colonne : elle se decide a l'altitude du chapeau, et sur
	## une surface plate. Un octet par colonne, comme `surfaces`.
	var cap_surfaces: PackedByteArray
	## Deux entiers par colonne : le tablier d'un pont (jalon 1.16). Le premier
	## est son altitude, le second vaut 1 pour un garde-corps. `bas` a
	## `DECK_NONE` veut dire pas de pont, et c'est le cas partout sauf sur une
	## poignee de colonnes du monde.
	var decks: PackedInt32Array
	## Plus bas point de matiere continue. Prend en compte le **plancher des
	## grottes** : sans lui, le chemin rapide « bloc entierement plein » boucherait
	## une grotte sans qu'aucun test ne le voie, puisqu'il ne regarde pas les
	## intervalles.
	var lowest: float = INF
	## Plus haut point de matiere ou d'eau, **chapeau de surplomb compris**.
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
## les donnees du monde par `_stamp_trunks`. C'est le meme exemplaire que celui
## du rendu — un seul cache de cellules, donc le tronc estampe et le houppier
## instancie viennent forcement du meme tirage.
func tree_scatter_grid() -> CWTreeScatter:
	field()
	return _tree_scatter


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
## `[slab_lo, slab_hi]` est le chapeau de surplomb du jalon 1.15, borne haute
## **incluse**, et `[cave_lo, cave_hi]` le tube de grotte qui le perce. Les deux
## sont vides — `bas > haut` — sur la quasi-totalite du monde, et leurs valeurs
## par defaut disent exactement cela : un appelant qui ne connait pas la couche
## de surplombs decrit le monde d'avant elle, ce qui est ce que veulent les
## verifications de la regle nue.
##
## **L'ordre complet des recouvrements est donc : grotte, surplomb, etang,
## terrain.** La grotte passe en premier parce qu'elle est de l'air et que l'air
## efface tout — c'est elle qui traverse le socle d'un surplomb *et* le terrain
## qui le porte. Le surplomb vient ensuite : une dalle de roche recouvre l'eau
## d'une mare comme le sol qu'elle surplombe.
static func voxel_of(y: int, top: int, surface: int, subsurface: int,
		sea: int, pond_lo: int, pond_hi: int,
		slab_lo: int = 1, slab_hi: int = 0, cap_surface: int = 0,
		cave_lo: int = 1, cave_hi: int = 0,
		deck_y: int = DECK_NONE, rail: bool = false,
		road_lo: int = 1, road_hi: int = 0) -> int:
	if deck_y != DECK_NONE and y == deck_y:
		return CWPalette.WOOD
	if y >= cave_lo and y <= cave_hi:
		return CWPalette.AIR
	if y >= road_lo and y <= road_hi:
		return CWPalette.AIR
	if y >= slab_lo and y <= slab_hi:
		if y == slab_hi:
			return cap_surface
		if y > slab_hi - subsurface:
			return CWPalette.subsurface_index(cap_surface)
		return CWPalette.STONE
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
	var c: Vector4 = f.sample_column_full(wx, wz)
	var sea: int = p.sea_level
	var biome: int = CWBiome.at(c.x, c.y, c.z, sea)
	var prof: Vector3i = CWTerrainField.column_profile(c.x, c.w, sea, biome)
	var slope: float = f.slope_at(wx, wz) if p.cliff_slope else 0.0
	var surface: int = CWPalette.surface_of(
			CWBiome.at_dithered(c.x, c.y, c.z, sea, wx, wz,
					CWBiome.fringe_amplitude(f.climate_gradient(wx, wz))),
			c.x - float(sea), c.y, c.z, wx, wz, slope)
	surface = pond_surface(surface, biome, prof,
			CWTerrainField.pond_gate(c.x, c.w, sea, biome))
	var rel := Vector4i(1, 0, 1, 0)
	if p.overhangs:
		rel = CWMesaGrid.relief(f.mesas().mesas_at(wx, wz, f), wx, wz, prof.x)
	var cap: int = 0
	if rel.y >= rel.x:
		# Meme regle qu'au chemin chaud : la matiere du dessus d'un massif se
		# decide a son altitude **et sur son epaisseur**. Voir `_get_patch`.
		cap = CWPalette.blended(
				CWPalette.surface_of(biome, float(rel.y - sea), c.y, c.z,
						wx, wz, 0.0),
				CWPalette.STONE,
				clampf((float(rel.y - prof.x) - CWMesa.SKIN_GRASS)
						/ CWMesa.SKIN_ROCK, 0.0, 1.0), wx, wz)
	var zone: CWPathNetwork.Zone = f.paths().empty_zone()
	if p.road_network:
		zone = f.paths().zone_at(wx, wz, f)
	var cells: PackedInt32Array = zone.index.get(
			CWPathNetwork.cell_key(wx, wz), PackedInt32Array())
	var road := Vector2(INF, 0.0)
	var shape := Vector4i(prof.x, 1, 0, DECK_NONE)
	if not cells.is_empty():
		road = CWPathNetwork.nearest(zone, cells, float(wx), float(wz))
		shape = road_shape(road, prof.x, prof, sea, rel.y,
				CWPathNetwork.deck_at(zone, float(wx), float(wz)))
		prof.x = shape.x
		surface = CWPalette.blended(CWPalette.GRAVEL, surface,
				clampf((road.x - CWPathNetwork.HALF_WIDTH)
						/ CWPathNetwork.ROAD_FADE, 0.0, 1.0), wx, wz)
	return voxel_of(y, prof.x, surface, subsurface_depth, sea, prof.y, prof.z,
			rel.x, rel.y, cap, rel.z, rel.w, shape.w,
			shape.w != DECK_NONE and road_rail(road), shape.y, shape.z)


## Matiere de surface d'une colonne, une fois l'etang pris en compte.
##
## Deux cas viennent de la source, et le troisieme est une reserve de ce projet.
##
## **Le lit d'une mare garde la matiere de dessous, pas celle de dessus.** La
## source ne repeint pas le fond : elle ecrase d'eau des blocs qui etaient de la
## couche meuble, et c'est cette couche qu'on voit a travers l'eau. Rendre
## l'herbe du dessus mettrait une prairie verte au fond de chaque mare.
##
## **Une colonne de la porte sans eau porte du sol humide** — c'est la **rive**,
## et non le lit. Le pseudo-code de `docs/systems/02` disait le contraire ; la
## relecture de la source a montre que l'ecriture du type 3 est gardee par « le
## bloc qui s'y trouve n'est pas de l'eau », garde qui echoue precisement quand
## il y en a. Le sol humide est donc l'anneau autour de chaque mare, ce qui est
## beaucoup mieux : `CWDecorRules.FAMILIES_SURFACE` y fait pousser des roseaux,
## et un roseau se tient sur la rive.
##
## > **Et la rive n'est humide que dans le biome qui sait la garnir.** C'est une
## > reserve assumee, pas un oubli. `FAMILIES_SURFACE[SWAMP]` appelle le role
## > ROSEAU, et le seul modele de roseau du lot est `jungles/roseau` : poser du
## > sol humide dans les cinq autres biomes rendrait un anneau **nu** autour de
## > chaque mare. C'est exactement le defaut qui a fait retirer les franges
## > d'humidite, puis les bandes d'altitude, puis la falaise — *une matiere qui
## > ne porte rien est un trou dans le monde*, et on ne le repaiera pas une
## > quatrieme fois pour un anneau de deux blocs. La table lue est
## > `FAMILIES_SURFACE_BIOME`, qui declare deja quel biome garnit quelle
## > matiere : le jour ou chaque biome aura son roseau, elle grandira et la rive
## > suivra sans qu'on retouche a ceci.
static func pond_surface(surface: int, biome: int, prof: Vector3i,
		in_gate: bool) -> int:
	if not in_gate:
		return surface
	if prof.y <= prof.z:
		return CWPalette.subsurface_index(surface)
	if int(CWDecorRules.FAMILIES_SURFACE_BIOME.get(CWPalette.SWAMP, -1)) == biome:
		return CWPalette.SWAMP
	return surface


## Dessus **praticable** d'une colonne : le dessus du chapeau quand un surplomb
## la couvre, le sol du terrain sinon.
##
## C'est le point unique ou les trois poseurs d'objets — les deux dispersions et
## le generateur — se mettent d'accord sur *ou est le sol*. Depuis le jalon
## 1.15, une colonne en a deux : celui du terrain, qui peut etre enseveli sous
## le socle d'un surplomb ou se trouver a l'ombre de son chapeau, et le dessus
## plat du chapeau lui-meme. **C'est le second qui porte la vegetation** — c'est
## ce qu'on voit sur les captures du jeu d'origine, ou une mesa porte ses arbres
## sur le dos et rien dessous.
static func standing_top(rel: Vector4i, ground_top: int) -> int:
	return rel.y if rel.y >= rel.x else ground_top


## Matiere de ce dessus praticable. Le dessus d'un chapeau est **plat et haut** :
## sa matiere ne se decide ni a l'altitude du sol qu'il domine, ni sur sa pente.
static func standing_surface(rel: Vector4i, ground_surface: int, biome: int,
		temperature: float, humidity: float, x: int, z: int, sea: int) -> int:
	if rel.y < rel.x:
		return ground_surface
	return CWPalette.surface_of(biome, float(rel.y - sea), temperature,
			humidity, x, z, 0.0)


## Vrai si une grotte perce le sol de cette colonne : rien ne peut s'y poser,
## le bloc qui devrait porter l'objet ayant ete creuse.
static func cave_breaks(rel: Vector4i, ground_top: int) -> bool:
	return rel.w >= rel.z and ground_top >= rel.z and ground_top <= rel.w


## Ce qu'un chemin fait a une colonne : `Vector4i(dessus, air_bas, air_haut,
## tablier)`.
##
## Trois cas, et le troisieme est celui qui a demande le plus de soin :
##
##   * **hors de portee** — l'immense majorite des colonnes du monde — rien ne
##     change, et la fonction sort avant tout calcul ;
##   * **au-dessus de l'eau** : pas de tranchee, un **tablier**. Le terrain et
##     l'eau restent ce qu'ils sont, et le chemin passe par-dessus, deux blocs
##     au-dessus de la surface libre. C'est la seule maniere honnete de
##     traverser une riviere : la combler ferait un barrage, et un barrage
##     retient une eau que ce monde ne simule pas ;
##   * **sur la terre** : la colonne est tranchee a l'altitude du chemin, et la
##     tranche de `CLEARANCE` blocs au-dessus est **effacee**. C'est cet
##     effacement qui fait qu'un chemin traverse le socle d'un surplomb au lieu
##     de buter dessus, et qu'il en sort un tunnel quand le socle est plus haut
##     que le degagement.
##
## L'intervalle d'air du chemin est **distinct de celui des grottes**, et il
## faut qu'il le reste : reunir les deux en un seul intervalle creuserait tout
## ce qui les separe, c'est-a-dire un puits de plusieurs dizaines de blocs le
## jour ou un chemin passe au-dessus d'une grotte.
static func road_shape(road: Vector2, ground_top: int, prof: Vector3i,
		sea: int, slab_hi: int = -0x7FFFFFFF,
		span: float = NAN) -> Vector4i:
	if road.x >= CWPathNetwork.reach():
		return Vector4i(ground_top, 1, 0, DECK_NONE)
	var on: bool = CWPathNetwork.on_roadway(road)
	var water_top: int = DECK_NONE
	if prof.y <= prof.z:
		water_top = prof.z
	elif ground_top < sea:
		water_top = sea
	var top: int = CWPathNetwork.shaped_top(ground_top, road)
	# Le dessus de la **chaussee**, meme hors d'elle : c'est le centre du cercle
	# de l'alesage, et il ne depend pas de la colonne qu'on regarde.
	var road_top: int = CWPathNetwork.shaped_top(ground_top,
			Vector2(0.0, road.y))
	var arche: int = tunnel_arch(top, road_top, slab_hi, road.x)

	if not on:
		# Hors chaussee, un chemin ne creuse rien — **sauf sous une masse**, ou
		# la voute du tunnel deborde le ruban. Sans ce debordement, un tunnel
		# reste la fente rectangulaire que le reproche du 2026-09-08 visait.
		if arche <= 0:
			return Vector4i(top, 1, 0, DECK_NONE)
		return Vector4i(top, top + 1, top + arche, DECK_NONE)

	# -- Le tablier suit le profil, et il rejoint la rive (2026-09-09) --------
	#
	# Il se posait a `surface + BRIDGE_CLEAR` **la ou il y avait de l'eau sous la
	# colonne, et nulle part ailleurs**. Deux defauts en un, et le second ne
	# s'est vu qu'en mesurant :
	#
	#   * aux culees, la chaussee de la rive etait a `sol - MIN_CUT` : entre
	#     elle et le tablier il y avait une marche, et l'ouvrage flottait ;
	#   * « y a-t-il de l'eau **sous cette colonne** » est une condition qui
	#     **clignote**. Sur un franchissement de la zone de depart, elle change
	#     140 fois d'avis la ou un pont a deux culees : le tablier avait des
	#     trous.
	#
	# Trois choses ensemble y repondent, et il fallait les trois :
	#
	#   * le degagement est porte par le **profil** (`CWPathNetwork._profil`),
	#     donc `road.y` *est* l'altitude du tablier — la meme que celle dont la
	#     travee instanciee se sert. Deux nombres calcules a deux endroits n'ont
	#     aucune raison de coincider ;
	#   * la chaussee a le droit de passer **au-dessus** du sol
	#     (`CWPathNetwork.shaped_top`), donc la rampe d'acces est un remblai de
	#     gravier et non cent blocs de bois a un bloc du sol ;
	#   * et la condition du tablier devient **geometrique** : il y a du bois la
	#     ou le terrain descend **plus bas que le remblai ne peut monter**,
	#     c'est-a-dire sous `sol + MAX_FILL`. Ailleurs, de la terre. Cette
	#     condition-la ne clignote pas : elle suit le terrain, qui est continu,
	#     au lieu de suivre la presence d'eau, qui ne l'est pas.
	#
	# Et les deux surfaces se rejoignent par construction : a la colonne ou le
	# remblai rattrape le profil, les deux valent `road.y`.
	# `span` est l'altitude du tablier releve (`CWPathNetwork.deck_at`), et
	# `NAN` hors d'un ouvrage. C'est **l'ouvrage qui dit ou il y a du bois**, et
	# non la colonne : voir la note de `deck_at` pour ce que coutait l'inverse.
	if is_nan(span):
		return Vector4i(top, top + 1,
				top + maxi(CWPathNetwork.CLEARANCE, arche), DECK_NONE)
	var deck: int = roundi(span)
	if water_top != DECK_NONE:
		# Le degagement est ici un **plancher** et non une consigne : une
		# riviere plus profonde que ne le disait le jalon voisin du profil ne
		# doit pas noyer le tablier.
		deck = maxi(deck, water_top + CWPathNetwork.BRIDGE_CLEAR)
	# **On ne redecide pas colonne par colonne s'il y a un tablier.** L'essai
	# precedent l'annulait des que le remblai rattrapait le bois (`deck <= top`)
	# : c'est juste a la culee et faux au milieu, ou un banc de sable emerge
	# entre deux bras d'une riviere. Il rendait 178 passages bois/terre sur les
	# ouvrages d'une zone. **L'etendue de l'ouvrage est celle du releve**, qui
	# s'arrete deja au premier point sec de chaque rive ; le tablier la couvre
	# entierement, et la culee est la ou le releve finit.
	#
	# Reste a ne pas enterrer de bois : si la colonne est plus haute que le
	# tablier, c'est elle qu'on garde.
	if deck < top:
		return Vector4i(top, top + 1,
				top + maxi(CWPathNetwork.CLEARANCE, arche), DECK_NONE)
	if water_top != DECK_NONE:
		# Le sol garde exactement ce qu'il etait : le lit, la berge et l'eau ne
		# sont ni tranches ni effaces, le chemin passe par-dessus. Le combler
		# ferait un barrage, et un barrage retient une eau que ce monde ne
		# simule pas.
		return Vector4i(ground_top, 1, 0, deck)
	return Vector4i(top, top + 1,
			top + maxi(CWPathNetwork.CLEARANCE, arche), deck)


## -- L'alesage d'un tunnel : un rayon, pas une hauteur -----------------------
##
## La premiere version rendait une **hauteur** : le chemin creusait une tranche
## rectangulaire au-dessus de sa chaussee, de largeur constante. Sous quarante
## blocs de roche, ca donne une fente, pas une arche — et c'est le reproche du
## 2026-09-08, *« un degagement proportionnel, avec un diametre, sans couper la
## montagne en deux »*.
##
## Le tunnel a donc un **rayon**, et sa section est un cercle centre sur l'axe de
## la chaussee a hauteur de celle-ci. Le degagement au point de distance `d` vaut
## `sqrt(R² - d²)` : maximal sur l'axe, nul au piedroit. La voute deborde la
## chaussee des que `R > HALF_WIDTH`, ce qui est le cas sous toute masse un peu
## haute — c'est ce debordement qui fait la difference entre une arche et une
## fente.
##
## **Et il garde un toit.** Au moins `TUNNEL_ROOF_MIN` blocs de matiere au-dessus
## de la voute, sinon le chemin ne perce plus le massif : il le **coupe en deux**
## et laisse une tranchee a ciel ouvert la ou on attendait une arche. C'est la
## seconde moitie du reproche, et elle etait deja tenue.

## Rayon de l'alesage sous une masse, en blocs, ou zero s'il n'y a pas de masse
## a percer.
static func tunnel_bore(road_top: int, slab_hi: int) -> int:
	var mass: int = slab_hi - road_top
	if mass < CWPathNetwork.CLEARANCE + CWPathNetwork.TUNNEL_ROOF_MIN:
		return 0
	return maxi(CWPathNetwork.CLEARANCE,
			mini(int(float(mass) * CWPathNetwork.TUNNEL_SHARE),
					mass - CWPathNetwork.TUNNEL_ROOF_MIN))


## Degagement au-dessus de la colonne, a la distance laterale `d` de l'axe.
##
## Rend zero hors de l'alesage. `top` est le dessus de **cette** colonne une fois
## le chemin passe, `road_top` celui de la chaussee : la voute se mesure depuis
## la chaussee — c'est un cercle, il a un centre — et le degagement se compte
## depuis la colonne, qui est plus haute des qu'on quitte le ruban.
static func tunnel_arch(top: int, road_top: int, slab_hi: int, d: float) -> int:
	var r: int = tunnel_bore(road_top, slab_hi)
	if r <= 0 or d >= float(r):
		return 0
	var voute: int = road_top + floori(sqrt(float(r * r) - d * d))
	return maxi(0, voute - top)


## Hauteur degagee au-dessus de la chaussee, sur l'axe.
##
## A ciel ouvert, c'est `CLEARANCE` : de quoi effacer ce qui traine au-dessus du
## chemin. Sous un massif, c'est le rayon de l'alesage — la fleche de la voute,
## qui est maximale la.
static func tunnel_height(road_top: int, slab_hi: int) -> int:
	return maxi(CWPathNetwork.CLEARANCE, tunnel_bore(road_top, slab_hi))


## Garde-corps : le bord exterieur du tablier. Un pont sans lui se lit comme une
## planche posee sur l'eau ; avec lui, comme un ouvrage.
static func road_rail(road: Vector2) -> bool:
	return road.x > CWPathNetwork.HALF_WIDTH - 1.0


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
	# **Les troncs, eux, s'invitent** depuis le jalon 1.11 : ils sont ecrits dans
	# le terrain. Le vide au-dessus du sol n'est donc plus vide sur la hauteur
	# d'un tronc, et le chemin rapide doit reculer d'autant. La borne est une
	# constante et non une mesure du voisinage : un tronc pose hors du bloc peut
	# y mordre, et sa colonne n'est pas dans ce releve de hauteurs.
	if float(y_min) > patch.highest + float(CWTreeScatter.HAUTEUR_TRONC_MAX) \
			and y_min > sea:
		return
	if float(y_max) < patch.lowest - float(subsurface_depth):
		out_buffer.fill(CWPalette.STONE, CWPalette.CHANNEL_TYPE)
		out_buffer.fill(CWPalette.raw_of(CWPalette.STONE), CWPalette.CHANNEL_COLOR)
		return

	# Les cinq tableaux rares sont testes **une fois par bloc** et non une fois
	# par colonne : ils sont vides dans la quasi-totalite des blocs.
	var has_slabs: bool = not patch.slabs.is_empty()
	var has_caves: bool = not patch.caves.is_empty()
	var has_roads: bool = not patch.roads.is_empty()
	var has_decks: bool = not patch.decks.is_empty()

	var i: int = 0
	for lz in size.z:
		for lx in size.x:
			var h: float = patch.heights[i]
			var surface: int = patch.surfaces[i]
			var pond_lo: int = patch.ponds[i * 2]
			var pond_hi: int = patch.ponds[i * 2 + 1]
			var col: int = (patch.surface_colors[i] << 8) | 0xFF
			var slab_lo: int = patch.slabs[i * 2] if has_slabs else 1
			var slab_hi: int = patch.slabs[i * 2 + 1] if has_slabs else 0
			var cave_lo: int = patch.caves[i * 2] if has_caves else 1
			var cave_hi: int = patch.caves[i * 2 + 1] if has_caves else 0
			var road_lo: int = patch.roads[i * 2] if has_roads else 1
			var road_hi: int = patch.roads[i * 2 + 1] if has_roads else 0
			var deck_y: int = patch.decks[i * 2] if has_decks else DECK_NONE
			var rail: bool = has_decks and patch.decks[i * 2 + 1] == 1
			var cap: int = patch.cap_surfaces[i] if has_slabs else 0
			var cap_col: int = ((patch.cap_colors[i] << 8) | 0xFF) \
					if has_slabs else 0
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

			# Le surplomb (jalon 1.15), qui recouvre tout ce qui precede :
			# roche, puis la couche meuble et le sol de son dessus plat. C'est
			# l'ordre que `voxel_of` reproduit en le testant avant l'etang.
			if slab_hi >= slab_lo:
				_fill_run(out_buffer, lx, lz, y_min, y_max, stride,
						slab_lo, slab_hi - subsurface_depth, CWPalette.STONE)
				if subsurface_depth > 0:
					_fill_run(out_buffer, lx, lz, y_min, y_max, stride,
							maxi(slab_lo, slab_hi - subsurface_depth + 1),
							slab_hi - 1, CWPalette.subsurface_index(cap))
				_fill_run(out_buffer, lx, lz, y_min, y_max, stride,
						slab_hi, slab_hi, cap, cap_col)

			# La grotte, puis le degagement du chemin : c'est de l'air, et
			# l'air efface tout — le socle du surplomb comme le terrain qui le
			# porte. Deux intervalles et non un : voir `road_shape`.
			if cave_hi >= cave_lo:
				_fill_run(out_buffer, lx, lz, y_min, y_max, stride,
						cave_lo, cave_hi, CWPalette.AIR)
			if road_hi >= road_lo:
				_fill_run(out_buffer, lx, lz, y_min, y_max, stride,
						road_lo, road_hi, CWPalette.AIR)
			# Le tablier du pont, tout en haut de l'ordre : il est bati sur du
			# vide, donc rien ne peut le recouvrir.
			#
			# **Un bloc, et rien de plus.** Le garde-corps etait de la matiere
			# jusqu'au 2026-09-08 ; il est passe au lot d'ouvrages, instancie a
			# six voxels par bloc (`CWBridgeRenderer`). Le meme partage que le
			# tronc et le houppier depuis le jalon 1.11 : la matiere porte ce
			# sur quoi on marche, le modele porte ce qu'on regarde.
			if deck_y != DECK_NONE:
				_fill_run(out_buffer, lx, lz, y_min, y_max, stride,
						deck_y, deck_y, CWPalette.WOOD)

	_stamp_trunks(out_buffer, origin_in_voxels, size, stride, lod, p, patch)


## Ecrit dans le bloc les troncs qui le traversent (jalon 1.11).
##
## -- Pourquoi ici, et pas par la couche d'edition ----------------------------
##
## Un tronc est du monde procedural, pas une modification du joueur : le passer
## par `CWWorldEdits` mettrait chaque arbre du monde sur le disque. Il est donc
## ecrit a la generation, comme la source le fait
## (`World_fillVoxelColumnTyped`), ce qui lui donne gratuitement la persistance
## — il n'y a rien a persister —, l'edition, l'eclairage et la collision.
##
## -- Ce que ca coute ---------------------------------------------------------
##
## L'appel ne concerne que les blocs qui touchent la surface : les autres sont
## sortis par les deux chemins rapides. `trunks_in` consulte une a quatre
## cellules d'arbres, toutes en cache apres le premier bloc de la pile
## verticale, et une cellule de 64 blocs contient de l'ordre de sept arbres.
##
## -- Le type et la couleur ---------------------------------------------------
##
## Le type ecrit est `CWPalette.WOOD` pour **tous** les troncs, la teinte est
## celle du voxel du modele. C'est le partage du jalon 1.9 : le canal semantique
## dit « du bois », le canal de rendu garde l'ecorce claire du bouleau et la
## sombre du tropical. Sans lui, il aurait fallu un type de bloc par nuance.
func _stamp_trunks(buf: VoxelBuffer, origin: Vector3i, size: Vector3i,
		stride: int, lod: int, p: CWWorldParams, patch: ColumnPatch) -> void:
	# Le LOD n'est pas gere : un tronc de trois blocs de large disparait a la
	# premiere reduction, et `VoxelTerrain` ne demande que le niveau 0. La garde
	# est la pour le jour ou la pyramide reviendrait sur le tapis.
	if lod != 0 or _shutting_down:
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
	var placements: Array = trees.trunks_in(wx, wz, size.x, size.z)
	if placements.is_empty():
		return

	var y_min: int = origin.y
	var y_max: int = origin.y + size.y - 1
	for pl in placements:
		for v in CWTreeScatter.trunk_voxels(pl):
			if v.y < y_min or v.y > y_max:
				continue
			var lx: int = v.x - wx
			var lz: int = v.z - wz
			if lx < 0 or lz < 0 or lx >= size.x or lz >= size.z:
				continue
			buf.set_voxel(CWPalette.WOOD, lx, v.y - y_min, lz,
					CWPalette.CHANNEL_TYPE)
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
	# Les cinq tableaux qui suivent decrivent des accidents rares — un surplomb,
	# une grotte, un chemin, un pont — et restent **vides** dans les blocs qui
	# n'en portent pas, c'est-a-dire l'immense majorite. Les allouer d'office
	# ferait passer une carte de hauteurs de 4,4 a 12 Ko, et le cache en garde
	# seize mille.
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
	var mesas: CWMesaGrid = f.mesas()
	var win: Array[CWMesa] = []
	var last_mcx: int = 0x7FFFFFFF
	var last_mcz: int = 0x7FFFFFFF
	# L'amplitude de l'ecotone, prise une fois par cellule de climat traversee
	# et non une fois par colonne : le gradient du champ de climat est une
	# grandeur regionale, et sa lecture prend un verrou. Meme economie que celle
	# de la fenetre de massifs juste au-dessus.
	var amp := Vector2.ZERO
	var last_gcx: int = 0x7FFFFFFF
	var last_gcz: int = 0x7FFFFFFF
	for i in n:
		# Meme parcours que `sample_patch` : iz a l'exterieur, ix a l'interieur.
		# La regle de surface a besoin des coordonnees monde depuis le jalon
		# 1.12 — voir `CWPalette.lava_flow`.
		@warning_ignore("integer_division")
		var iz: int = i / size.x
		var ix: int = i - iz * size.x
		var cx: int = ox + ix * stride
		var cz: int = oz + iz * stride
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

		# Le massif (jalon 1.15), **apres** le profil : sa hauteur se mesure
		# depuis le sol de *cette* colonne, sans quoi son contour est une marche
		# de la hauteur du relief qu'il traverse. Voir `CWMesa.slab_from_shape`.
		#
		# La fenetre est prise une fois par cellule de 512 traversee et non une
		# fois par colonne : les 256 colonnes d'un bloc tombent dans une ou deux
		# cellules, et la consultation prend un verrou. Meme economie que celle
		# de `sample_patch` sur la fenetre de sites.
		var rel := Vector4i(1, 0, 1, 0)
		if p.overhangs:
			var mcx: int = CWMesaGrid.cell_of(cx)
			var mcz: int = CWMesaGrid.cell_of(cz)
			if mcx != last_mcx or mcz != last_mcz:
				win = mesas.get_window(mcx, mcz, f)
				last_mcx = mcx
				last_mcz = mcz
			if not win.is_empty():
				rel = CWMesaGrid.relief(win, cx, cz, prof.x)

		# Le sol **avant** le chemin : c'est celui sur lequel le massif s'est
		# pose, donc celui dont son epaisseur se mesure. Le prendre apres ferait
		# grossir la masse de la profondeur de la tranchee, et la teinte de son
		# dessus ne serait plus la meme des deux cotes de l'invariant n. 18.
		var sol0: int = prof.x

		# Le chemin, en dernier : il tranche la colonne que tout le reste vient
		# de decrire.
		var road := Vector2(INF, 0.0)
		var shape := Vector4i(prof.x, 1, 0, DECK_NONE)
		if not road_cells.is_empty():
			road = CWPathNetwork.nearest(road_zone, road_cells,
					float(cx), float(cz))
			shape = road_shape(road, prof.x, prof, sea, rel.y,
					CWPathNetwork.deck_at(road_zone, float(cx), float(cz)))
			prof.x = shape.x
		var ph: float = float(shape.x)
		patch.heights[i] = ph
		patch.ponds[i * 2] = prof.y
		patch.ponds[i * 2 + 1] = prof.z
		if shape.z >= shape.y:
			patch.roads = _spans(patch.roads, n)
			patch.roads[i * 2] = shape.y
			patch.roads[i * 2 + 1] = shape.z
		if shape.w != DECK_NONE:
			if patch.decks.is_empty():
				patch.decks.resize(n * 2)
				for k in n:
					patch.decks[k * 2] = DECK_NONE
			patch.decks[i * 2] = shape.w
			patch.decks[i * 2 + 1] = 1 if road_rail(road) else 0

		# La matiere du sol prend le biome **trame** ; tout le reste — l'eau, le
		# decor, le nom affiche — garde celui de `CWBiome.at`. Voir l'en-tete de
		# `at_dithered`.
		var gcx: int = cx >> CWTerrainField.CLIMATE_GRAD_SHIFT
		var gcz: int = cz >> CWTerrainField.CLIMATE_GRAD_SHIFT
		if gcx != last_gcx or gcz != last_gcz:
			amp = CWBiome.fringe_amplitude(f.climate_gradient(cx, cz))
			last_gcx = gcx
			last_gcz = gcz
		var ss: Vector2i = CWPalette.surface_shaded(
				CWBiome.at_dithered(h, raw[j + 1], raw[j + 2], sea, cx, cz, amp),
				h - float(sea), raw[j + 1], raw[j + 2], cx, cz, slope)
		var surf: int = pond_surface(ss.x, biome, prof,
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

		if rel.y >= rel.x:
			patch.slabs = _spans(patch.slabs, n)
			patch.slabs[i * 2] = rel.x
			patch.slabs[i * 2 + 1] = rel.y
			# Le dessus d'un massif se decide a **son** altitude : une masse de
			# quatre-vingts blocs de haut au-dessus d'une plage n'a pas de sable
			# sur le dos.
			#
			# **Et il se decide aussi sur son epaisseur.** Sans cela, une masse
			# rocheuse arrondie sort couverte d'herbe sur toute sa surface et se
			# lit comme une colline de plus : le relief qu'elle ajoute est
			# invisible. La regle de falaise ne peut pas l'aider — elle mesure
			# la pente du **champ**, qui ignore tout de cette couche. On prend
			# donc l'epaisseur : la frange, ou la masse affleure de deux ou
			# trois blocs, garde l'herbe du pre qu'elle traverse ; le coeur, ou
			# elle fait dix blocs et plus, est de la roche nue. C'est un
			# affleurement, et c'est ce que montrent les captures du jeu.
			var ep: float = float(rel.y - sol0)
			var cs: Vector2i = CWPalette.surface_shaded(biome,
					float(rel.y - sea), raw[j + 1], raw[j + 2], cx, cz, 0.0)
			cs = CWPalette.blended_shaded(cs.x, CWPalette.STONE,
					clampf((ep - CWMesa.SKIN_GRASS)
							/ CWMesa.SKIN_ROCK, 0.0, 1.0), cx, cz)
			if patch.cap_surfaces.is_empty():
				patch.cap_surfaces.resize(n)
				patch.cap_colors.resize(n)
			patch.cap_surfaces[i] = cs.x
			patch.cap_colors[i] = (cs.y >> 8) & 0xFFFFFF
		if rel.w >= rel.z:
			patch.caves = _spans(patch.caves, n)
			patch.caves[i * 2] = rel.z
			patch.caves[i * 2 + 1] = rel.w

		patch.lowest = minf(patch.lowest, ph)
		if shape.z >= shape.y:
			patch.lowest = minf(patch.lowest, float(shape.y))
		if shape.w != DECK_NONE:
			patch.highest = maxf(patch.highest, float(shape.w + 1))
		if rel.w >= rel.z:
			# Le plancher d'une grotte est le point d'air le plus bas de la
			# colonne : sans lui, le chemin rapide « bloc entierement plein »
			# reboucherait la grotte, et rien ne le signalerait.
			patch.lowest = minf(patch.lowest, float(rel.z))
		# `highest` borne le vide au-dessus du monde : c'est la **surface libre**
		# qui compte, eau et chapeau de surplomb compris, sinon le chemin rapide
		# du haut rendrait de l'air a la place du dessus d'une mare ou d'une mesa.
		patch.highest = maxf(patch.highest, maxf(ph, float(prof.z)))
		if rel.y >= rel.x:
			patch.highest = maxf(patch.highest, float(rel.y))

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
