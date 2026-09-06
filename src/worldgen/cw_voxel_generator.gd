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
	## Deux entiers par colonne : l'intervalle d'eau d'etang, borne haute
	## **incluse**. `bas > haut` — le cas courant — veut dire pas d'eau.
	## L'ocean n'est pas ici : il se deduit du niveau de la mer.
	var ponds: PackedInt32Array
	var lowest: float = INF
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
static func voxel_of(y: int, top: int, surface: int, subsurface: int,
		sea: int, pond_lo: int, pond_hi: int) -> int:
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
	var prof: Vector3i = CWTerrainField.column_profile(c.x, c.w, sea)
	var biome: int = CWBiome.at(c.x, c.y, c.z, sea)
	var surface: int = CWPalette.surface_of(biome, c.x - float(sea),
			c.y, c.z, wx, wz)
	surface = pond_surface(surface, biome, prof,
			CWTerrainField.pond_gate(c.x, c.w, sea))
	return voxel_of(y, prof.x, surface, subsurface_depth, sea, prof.y, prof.z)


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

	var i: int = 0
	for lz in size.z:
		for lx in size.x:
			var h: float = patch.heights[i]
			var surface: int = patch.surfaces[i]
			var pond_lo: int = patch.ponds[i * 2]
			var pond_hi: int = patch.ponds[i * 2 + 1]
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
			# Bloc de surface.
			_fill_run(out_buffer, lx, lz, y_min, y_max, stride, top, top, surface)
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
	patch.ponds.resize(n * 2)
	# Une seule descente dans le champ : sample_patch ne consulte le cache de
	# fenetres de sites qu'une fois par zone traversee, au lieu d'une fois par
	# colonne.
	var raw: PackedFloat32Array = f.sample_patch(ox, oz, size.x, size.z, stride)
	var j: int = 0
	for i in n:
		var h: float = raw[j]
		var chan: float = raw[j + 3]
		# Meme parcours que `sample_patch` : iz a l'exterieur, ix a l'interieur.
		# La regle de surface a besoin des coordonnees monde depuis le jalon
		# 1.12 — voir `CWPalette.lava_flow`.
		@warning_ignore("integer_division")
		var iz: int = i / size.x
		var ix: int = i - iz * size.x
		var cx: int = ox + ix * stride
		var cz: int = oz + iz * stride

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
		var prof: Vector3i = CWTerrainField.column_profile(h, chan, sea)
		var ph: float = float(prof.x)
		patch.heights[i] = ph
		patch.ponds[i * 2] = prof.y
		patch.ponds[i * 2 + 1] = prof.z

		var biome: int = CWBiome.at(h, raw[j + 1], raw[j + 2], sea)
		var surf: int = CWPalette.surface_of(biome, h - float(sea),
				raw[j + 1], raw[j + 2], cx, cz)
		patch.surfaces[i] = pond_surface(surf, biome, prof,
				CWTerrainField.pond_gate(h, chan, sea))

		patch.lowest = minf(patch.lowest, ph)
		# `highest` borne le vide au-dessus du monde : c'est la **surface libre**
		# qui compte, eau comprise, sinon le chemin rapide du haut rendrait de
		# l'air a la place du dessus d'une mare.
		patch.highest = maxf(patch.highest, maxf(ph, float(prof.z)))
		j += 4

	_patch_mutex.lock()
	if _patches.size() >= HEIGHTMAP_CACHE_CAP:
		_patches_prev = _patches
		_patches = {}
	_patches[key] = patch
	_in_progress.erase(key)
	_patch_mutex.unlock()
	return patch


## Carte de hauteurs neutre, rendue quand l'arret survient pendant une attente.
func _empty_patch(size: Vector3i) -> ColumnPatch:
	var patch := ColumnPatch.new()
	var n: int = size.x * size.z
	patch.heights.resize(n)
	patch.surfaces.resize(n)
	# Un intervalle d'eau vide se dit `bas > haut` : le zero par defaut d'un
	# `PackedInt32Array` dirait [0, 0], soit un bloc d'eau a l'altitude zero
	# dans chaque colonne d'un bloc rendu pendant l'arret.
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
func _fill_run(buf: VoxelBuffer, lx: int, lz: int, y_min: int, y_max: int,
		stride: int, wy0: int, wy1: int, value: int) -> void:
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
	buf.fill_area(CWPalette.raw_of(value), lo, hi, CWPalette.CHANNEL_COLOR)
