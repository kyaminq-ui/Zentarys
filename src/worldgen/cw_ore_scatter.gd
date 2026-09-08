class_name CWOreScatter
extends CWScatter

## Dispersion des filons (jalon 2.6, l'apparition) : où un filon affleure.
##
## -- Ce que le jalon 1 avait laisse en suspens --------------------------------
##
## Les neuf modeles existent depuis le jalon 1.11 (`assets/models/filons/`), le
## tirage de rarete est porte verbatim (`CWPalette.roll_ore`, `docs/systems/02`
## §5.4), et les deux tables de contenu — `RANGE_TERRAIN_END` deplace, l'index
## de palette accorde au code d'entite 131-139 — attendaient depuis le
## 2026-09-05 « la couche qui les pose ». `tools/blender/generer_filons.py` le
## dit en toutes lettres : « ou affleure un filon, selon quelle roche et quelle
## profondeur, n'est pas ecrit : elle appartient a la voie des entites, avec les
## points d'apparition du jalon 2.6 ». C'est cette couche-ci.
##
## -- Ou un filon affleure, et pourquoi ce n'est pas une invention -------------
##
## `docs/systems/02` §6 donne la boucle de pose commune aux creatures et aux
## plantes, avec ses constantes utilisables telles quelles — mais elle ne dit
## nulle part *quelle* surface porte un filon. La reponse est dans le modele
## lui-meme : `generer_filons._blocs_de_gangue` dessine un filon comme une
## **gangue de roche** (index 1, celle que le generateur ecrit deja) qui grignote
## une veine de minerai en son coeur — « un filon estampe s'y fond au lieu de
## dessiner un caillou pose sur la paroi ». Un filon n'a donc de sens que la ou
## il y a de la roche a fondre dedans, et la **falaise** est la seule matiere de
## ce monde qui en soit (invariant n° 27, la seule matiere hors biome). Semer un
## filon sur de l'herbe planterait un caillou peint, pas un affleurement.
##
## -- Ce qui est porte verbatim, et ce qui est adapte a l'architecture ---------
##
## L'espacement minimum (20 unites), le rejet pres d'un element de tuile
## (poids d'influence, sauf le donjon) et l'abandon sous 0,2 d'humidite ou de
## temperature sont les constantes extraites de §6, et ils s'appliquent tels
## quels : rien ne dit qu'ils etaient reserves aux creatures, et les filons
## partagent le meme espace de codes d'entite (invariant du jalon 1, §5.1).
##
## Le **raster** lui-meme — pas de 85 unites, decalage +24, gigue `rand()%10` —
## ne l'est pas : c'est la geometrie d'une boucle qui parcourt une tuile entiere
## en une passe, pas celle d'une grille de cellules mises en cache. Ce projet
## dispose deja de cette architecture (`CWScatter`, `CWTreeScatter`) : une
## cellule de bord fixe, plusieurs candidats tires a l'interieur, une regle de
## voisinage sans recursion (invariant n° 25). C'est elle qui est reutilisee,
## avec sa propre taille de cellule et son propre budget de candidats — les
## deux sont des reglages de ce projet, pas des extractions.
##
## -- Pourquoi si peu de candidats par cellule ---------------------------------
##
## Un filon n'est pas une plante : sa rarete ne vient pas d'une crete de bruit
## ni d'une table de densite par biome, elle vient de la **matiere** — la
## falaise ne couvre que 0,4 % du monde (`nextsteps.md`, §0). Demander beaucoup
## de candidats par cellule pour compenser paierait `slope_at` (~225 us, trois
## echantillons de colonne) sur une cellule qui n'a neuf fois sur dix aucune
## roche a offrir. `CANDIDATS_PAR_CELLULE` reste donc bas ; c'est la rarete de
## la matiere-cible qui fait le travail, pas le budget de tirage.
##
## -- Ce que cette couche ne fait pas -------------------------------------------
##
## Elle ne connait pas le reseau de chemins : un filon qui affleurerait sous une
## chaussee resterait mine par un joueur qui ne la voit jamais, et le croisement
## est trop rare pour justifier une troisieme dependance (chemins, etangs,
## filons) sur le meme point. Elle ne pose pas de creature : l'apparence des
## creatures est hors perimetre du jalon 2 (`docs/ROADMAP.md`), et rien dans
## `docs/systems/02` ne dit comment cette meme boucle choisirait entre un filon
## et une creature en un point donne — c'est une decision qui attend le jalon
## 2.1.

## Cote d'une cellule de filons, en blocs, et son decalage binaire.
##
## Choisi comme celui des arbres — assez grand pour que l'espacement minimum
## (20 blocs) morde encore au travers de plusieurs cellules — et non celui,
## bien plus fin, de la boucle source : voir l'en-tete.
const ORE_CELL_SIZE: int = 64
const ORE_CELL_SHIFT: int = 6

## Candidats tires par cellule. Voir l'en-tete : c'est la rarete de la falaise,
## et non ce budget, qui rend un filon rare. Le porter plus haut ne poserait pas
## plus de filons de facon utile, seulement plus de `slope_at` payes pour rien
## sur les 99,6 % de cellules sans roche.
const CANDIDATS_PAR_CELLULE: int = 8

## Espacement minimum entre deux filons, en blocs. Porte verbatim de
## `docs/systems/02`, §6 : « espacement minimum de 20 unites (comparaison a 400
## sur le carre de la distance, en 16.16) ». C'est la seule constante de cette
## couche qui soit la valeur source elle-meme, et non une adaptation — voir
## `CWTreeScatter.ESPACEMENT`, qui porte le mecanisme mais pas le nombre.
const ESPACEMENT: int = 20

## Chance d'abandon d'un candidat. Porte verbatim de §6 :
## « 1 tentative sur 4 abandonnee d'entree » et, plus bas, « 1 chance sur 4
## d'abandonner » sous 0,2 d'humidite ou de temperature. Les trois usages
## partagent le meme nombre dans la source ; ce projet garde la meme constante
## pour le dire.
const CHANCE_ABANDON: float = 0.25

## Seuil climatique sous lequel l'abandon ci-dessus s'applique. Porte verbatim :
## « humidite < 0,2 : 1 chance sur 4 d'abandonner. Idem pour la temperature ».
## `CWTerrainField.sample_column` rend les deux dans [0, 1], donc le seuil se
## lit tel quel, sans conversion.
const CLIMAT_SEUIL: float = 0.2

## Seuil du poids d'influence d'un element de tuile sous lequel un candidat est
## rejete. Porte de §6 : « rejet si le poids d'influence d'un element de tuile
## non nul et non-10 depasse 0,3 — les poses evitent les elements, sauf le
## donjon ». `CWTerrainField.falloff_weight` rend 0 au centre d'un element et 1
## a son bord ; « depasse 0,3 » n'a de sens que pres du bord, donc la lecture
## retenue ici est l'inverse : un candidat est rejete s'il tombe **dans** le
## rayon utile de l'element, poids < 0,3. Note comme une lecture, pas comme un
## fait etabli — le sens du poids dans le code source n'est pas confirmable
## depuis le seul releve de §6.
const REJET_ELEMENT: float = 0.3

## Filon force par biome, pour les deux especes que le tirage de rarete ne rend
## jamais. `docs/systems/02` §5.4 le note en toutes lettres : « gres et cristal
## de glace n'apparaissent pas dans cette table [...] vraisemblablement poses
## par une autre branche, liee au biome (du gres en desert, du cristal en
## neige), qui n'a pas ete trouvee ». Cette branche n'a jamais ete retrouvee
## dans le binaire ; ce qui suit est la decision de ce projet pour lui donner un
## sens plutot que de laisser deux modeles du lot ne jamais sortir.
const ESPECE_PAR_BIOME: Dictionary = {
	CWBiome.DESERTS: CWPalette.ORE_SANDSTONE,
	CWBiome.SNOWLANDS: CWPalette.ORE_ICE_CRYSTAL,
}

## Chemin du modele charge, par index de palette de filon (`CWPalette.ORE_*`).
## Un seul modele par espece : contrairement a un arbre, un filon n'a ni tronc
## ni houppier, c'est une piece unique, deja peinte gangue et veine comprises.
const MODEL_OF: Dictionary = {
	CWPalette.ORE_GOLD: "or",
	CWPalette.ORE_IRON: "fer",
	CWPalette.ORE_SILVER: "argent",
	CWPalette.ORE_SANDSTONE: "gres",
	CWPalette.ORE_EMERALD: "emeraude",
	CWPalette.ORE_SAPPHIRE: "saphir",
	CWPalette.ORE_RUBY: "rubis",
	CWPalette.ORE_DIAMOND: "diamant",
	CWPalette.ORE_ICE_CRYSTAL: "cristal_de_glace",
}

## Dossier des neuf modeles. Meme grille que les arbres — un voxel par bloc,
## voir `assets/models/filons/generer_filons.py` en-tete.
const ORES_DIR: String = "res://assets/models/filons/"

## Melangeurs propres a cette couche. Distincts de ceux de la flore et des
## arbres, sinon un filon et une plante partageraient leur flux de tirages et
## tomberaient au meme endroit dans chaque cellule.
const ORE_HASH_X: int = 15485863
const ORE_HASH_Z: int = 32452867
const ORE_HASH_SEED: int = 49979693


func _init(terrain_field: CWTerrainField, models: CWModelLibrary = null) -> void:
	super(terrain_field, models if models != null else CWModelLibrary.shared_ores())
	cell_size = ORE_CELL_SIZE
	cell_shift = ORE_CELL_SHIFT


## Cellules de filons salies par une edition du terrain. Meme conversion que
## `CWTreeScatter.take_dirty_cells` : `CWWorldEdits` ne compte qu'en cellules de
## flore.
func take_dirty_cells() -> Array:
	var fines: Array = super()
	if fines.is_empty():
		return fines
	var seen: Dictionary = {}
	var out: Array = []
	var shift: int = ORE_CELL_SHIFT - CELL_SHIFT
	for c in fines:
		var g := Vector2i(c.x >> shift, c.y >> shift)
		if not seen.has(g):
			seen[g] = true
			out.append(g)
	return out


## Les candidats bruts d'une cellule : positions et tirages, avant tout test de
## terrain et avant l'espacement.
##
## Fonction **pure de l'indice de cellule**, comme celle des arbres — elle ne
## touche ni au champ de terrain, ni au cache, ce qui permet a une cellule de
## consulter ses huit voisines sans en declencher la construction.
func _candidats(cx: int, cz: int) -> Array:
	var rng := CWRand.new(_ore_seed_of(cx, cz))
	rng.next()
	rng.next()
	var base_x: int = cx << cell_shift
	var base_z: int = cz << cell_shift
	var out: Array = []
	for i in CANDIDATS_PAR_CELLULE:
		# Les sept tirages sont pris pour tous les candidats, et toujours les
		# sept : un tirage conditionnel desynchroniserait le flux du LCG d'un
		# candidat a l'autre (invariant n° 23).
		var x: int = base_x + rng.mod(cell_size)
		var z: int = base_z + rng.mod(cell_size)
		var abandon: float = rng.unit()
		var turn: int = rng.mod(CWVoxelModel.ROTATIONS)
		var r10: int = rng.next()
		var r100: int = rng.next()
		var clim_h: float = rng.unit()
		var clim_t: float = rng.unit()
		# « 1 tentative sur 4 abandonnee d'entree » (§6) : le seul test qui ne
		# coute qu'un tirage, avant tout echantillonnage de colonne.
		if abandon < CHANCE_ABANDON:
			continue
		out.append({"x": x, "z": z, "rang": i, "turn": turn, "r10": r10,
				"r100": r100, "clim_h": clim_h, "clim_t": clim_t})
	return out


## Vrai si le candidat `c`, de la cellule (cx, cz), survit a l'espacement.
## Meme regle du rang absolu que `CWTreeScatter._espace_libre` : voisinage 3x3,
## rang `(cz, cx, i)`, sans recursion.
func _espace_libre(c: Dictionary, cx: int, cz: int, voisins: Dictionary) -> bool:
	var d2: int = ESPACEMENT * ESPACEMENT
	for key in voisins:
		var vz: int = key.y
		var vx: int = key.x
		for o in voisins[key]:
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

	# Les huit voisines, pour l'espacement seul : aucune construction n'est
	# declenchee, aucun cache n'est touche (invariant n° 25).
	var voisins: Dictionary = {}
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := Vector2i(cx + dx, cz + dz)
			voisins[key] = mine if (dx == 0 and dz == 0) \
					else _candidats(cx + dx, cz + dz)

	var sea: int = _field.params().sea_level
	var cliff_slope: bool = _field.params().cliff_slope
	var road_zone: CWPathNetwork.Zone = _field.paths().empty_zone()
	var road_cells := PackedInt32Array()

	for c in mine:
		if not _espace_libre(c, cx, cz, voisins):
			continue
		var x: int = int(c["x"])
		var z: int = int(c["z"])
		var col: Vector4 = _field.sample_column_full(x, z)
		# Aucun filon sous l'eau : un affleurement se trouve, il ne se peche pas.
		if col.x < float(sea):
			continue
		var biome: int = CWBiome.at(col.x, col.y, col.z, sea)
		var prof: Vector3i = CWTerrainField.column_profile(col.x, col.w, sea, biome)
		# Ni au fond d'une mare (meme piege qu'aux jalons 1.14 et 1.11) : la
		# colonne est tranchee et couverte d'eau, ce n'est plus une paroi.
		if prof.y <= prof.z:
			continue
		var slope: float = _field.slope_at(x, z) if cliff_slope else 0.0
		var surface: int = CWPalette.surface_of(
				_field.fringe_biome(x, z, col.x), col.x - float(sea), x, z, slope)
		# **Le coeur du placement** : voir l'en-tete. Un filon n'affleure que
		# la ou il y a de la roche a fondre dedans, et la falaise est la seule
		# matiere du monde qui en soit (invariant n° 27).
		if surface != CWPalette.STONE:
			continue
		# Rejet pres d'un element de tuile, sauf le donjon (§6). Voir la note de
		# `REJET_ELEMENT` sur le sens retenu pour le poids d'influence.
		var feature: CWTileFeature = _field.feature_at(x, z)
		if feature != null and feature.type != 0 \
				and feature.type != CWTileFeature.TYPE_DUNGEON \
				and _field.falloff_weight(feature, x, z) < REJET_ELEMENT:
			continue
		# Abandon climatique (§6) : une chance sur quatre sous 0,2 d'humidite,
		# independamment sous 0,2 de temperature.
		if col.z < CLIMAT_SEUIL and float(c["clim_h"]) < CHANCE_ABANDON:
			continue
		if col.y < CLIMAT_SEUIL and float(c["clim_t"]) < CHANCE_ABANDON:
			continue

		var ore: int = ESPECE_PAR_BIOME.get(biome, -1)
		if ore == -1:
			ore = CWPalette.roll_ore(int(c["r10"]), int(c["r100"]))
		var path: String = MODEL_OF.get(ore, "")
		var m: CWVoxelModel = _lib.model(path) if path != "" else null
		if m == null:
			continue

		# Le sol est celui **d'apres** creusement, comme la flore et les arbres.
		var ground: int = prof.x + 1
		if not _supported(x, z, ground):
			continue

		# L'assiette (2026-09-09) : un affleurement pose a cheval sur une
		# rupture de pente flotterait ou s'enterrerait d'un cote. La marche
		# tolerable est plus large que pour la flore, parce qu'un filon est
		# suppose sortir d'une paroi et non poser a plat.
		var r: int = m.radius_blocks
		if r > 0:
			var a: Vector2i = _assiette(x, z, r, sea, road_zone, road_cells)
			if a.y - a.x > ASSIETTE_MAX * 2:
				continue
			ground = mini(ground, a.x)

		var p := Placement.new()
		p.x = x
		p.z = z
		p.y = ground
		p.fx = 0.5
		p.fz = 0.5
		p.model = m
		p.rotation = int(c["turn"])
		p.role = CWDecorRules.Role.AUCUN
		# Un filon ne se met pas a l'echelle : c'est une piece unique, deja
		# peinte gangue et veine comprises, comme un modele d'arbre ENTIER
		# (invariant n° 35, corollaire — une matiere se reechantillonne, elle
		# ne s'etire pas, et ici il n'y a meme pas de hauteur a reechantillonner).
		p.scale = 1.0
		p.matiere = true
		out.append(p)
	return out


## Les voxels d'un filon estampe : `(x, y, z, index de palette)`, coordonnees
## monde. Toujours la meme piece — pas de fut a reechantillonner, un filon n'a
## qu'une geometrie.
static func piece_voxels(pl: CWScatter.Placement) -> Array:
	var out: Array = []
	var m: CWVoxelModel = pl.model
	if m == null:
		return out
	var dx0: PackedInt32Array = m.offsets_x(pl.rotation)
	var dy0: PackedInt32Array = m.offsets_y(pl.rotation)
	var dz0: PackedInt32Array = m.offsets_z(pl.rotation)
	var v0: PackedByteArray = m.values(pl.rotation)
	var y0: int = pl.y + roundi(pl.fy)
	for i in m.voxel_count:
		out.append(Vector4i(pl.x + dx0[i], y0 + dy0[i], pl.z + dz0[i], v0[i]))
	return out


## L'etendue verticale d'un filon estampe, bornes incluses, en blocs monde.
static func piece_span(pl: CWScatter.Placement) -> Vector2i:
	var m: CWVoxelModel = pl.model
	if m == null:
		return Vector2i(0, -1)
	var y0: int = pl.y + roundi(pl.fy)
	return Vector2i(y0, y0 + m.height - 1)


func _ore_seed_of(cx: int, cz: int) -> int:
	var s: int = (cx * ORE_HASH_X) ^ (cz * ORE_HASH_Z) \
			^ (_field.params().world_seed * ORE_HASH_SEED)
	return (s * HASH_MIX) & 0xFFFFFFFF
