class_name CWTreeRules
extends RefCounted

## Les especes d'arbres, et comment chacune se monte (jalon 1.11).
##
## -- Pourquoi une table a part, et non un role de plus dans `CWDecorRules` ----
##
## `docs/ROADMAP.md`, §1.11, laissait la question ouverte : le role ARBRE
## s'ajoute-t-il aux deux cretes de selection de la flore, ou se decide-t-il sur
## son propre champ ? **Son propre champ**, et pour deux raisons qui n'ont rien
## d'esthetique :
##
##   1. les deux cretes de `CWDecorRules` sont a 0,01, soit une longueur d'onde
##      de cent blocs, et elles tranchent une *famille de decor* — de l'herbe
##      contre des fleurs. Un arbre n'est pas une variante d'herbe : il ne
##      concourt pas avec le couvert pour la meme place, il se pose par-dessus ;
##   2. la source elle-meme les separe. La flore basse est du **decor**, pousse
##      en fin de boucle de colonne par `WorldInfo_generateBiomeContent` ; les
##      arbres passent par la **voie des entites**, avec son propre code de type
##      et sa propre boucle de pose (`docs/systems/02`, §5 et §6). Les faire
##      partager une crete serait inventer un lien que la source n'a pas.
##
## Ce qui est ici est donc, comme la table de `CWModelLibrary`, une decision de
## ce projet : la source range ses arbres par code d'entite, pas par biome.
##
## -- Trois montages, et c'est la source qui les impose ------------------------
##
## `tree-leaves` (code 143) porte son propre code d'entite, loin des deux arbres
## (129 `fir-tree`, 130 `thorn-tree`), et le corpus n'a aucun modele de tronc.
## Il suit qu'il y a **deux sortes d'arbres** dans l'original, pas une :
##
##   * l'arbre **entier**, pose en une fois — le conifere et l'arbre a epines ;
##   * l'**assemblage**, un tronc surmonte de houppiers ou de palmes instancies.
##
## Le lot d'assets du 2026-09-05 livre les deux, d'ou les trois montages
## ci-dessous. Le troisieme, le palmier, est un assemblage dont les pieces du
## haut sont des palmes et non des houppiers : il tourne autour du sommet au
## lieu de s'empiler.

## Comment une espece se monte.
enum Montage {
	## Un seul modele, pose au sol. `tronc` porte le modele, `couronnes` est vide.
	ENTIER = 0,
	## Un tronc, puis un a trois houppiers empiles pres de son sommet.
	FEUILLU,
	## Un stipe, puis une couronne de palmes rayonnantes a son sommet.
	PALMIER,
	## Une charpente — un fut et quatre branches — puis un houppier au bout de
	## chaque branche, plus un a la cime. Ajoute le 2026-09-06.
	##
	## -- Ce qu'il apporte que FEUILLU n'a pas ---------------------------------
	##
	## Un feuillu empile ses houppiers **sur l'axe du tronc** : sa silhouette est
	## une colonne coiffee, et son envergure ne depasse jamais celle d'un seul
	## houppier. Un grand arbre porte ses masses **en dehors** de son axe, au
	## bout de branches dessinees dans le modele de tronc : c'est ce qui fait la
	## difference entre un arbre de foret et un arbre isole qu'on remarque de
	## loin.
	##
	## Les bouts de branche sont declares dans `branches`, et la meme liste est
	## ecrite dans `tools/blender/generer_arbres.py`. Elles sont en coordonnees
	## **Godot** des deux cotes — l'import fait tourner les axes, et une liste
	## ecrite dans le repere du fichier `.vox` porterait le houppier a quatre-
	## vingt-dix degres de sa branche. `tests/tree_test.gd` charge le modele et
	## verifie qu'il y a bien du bois a chaque bout declare.
	GRAND,
}

## Racine du lot d'arbres. Chemins relatifs, dossier de biome compris, comme
## pour la flore.
const TREE_DIR: String = "res://assets/models/arbres/"

## Une espece : son montage, son tronc, et les pieces qui le coiffent.
##
## `tronc` et `couronnes` sont des chemins relatifs a `TREE_DIR`. Pour un
## montage ENTIER, `couronnes` est vide. Une espece dont un seul fichier manque
## du disque est ignoree en entier — un tronc nu vaut moins qu'une clairiere.
##
## `pieces` est le nombre de houppiers empiles (FEUILLU) ou de **paires** de
## palmes en couronne (PALMIER), tire dans l'intervalle donne. Un montage GRAND
## l'ignore : son nombre de pieces est celui de ses branches, plus la cime.
##
## `branches` n'existe que pour GRAND : les bouts de branche du modele de tronc,
## en coordonnees Godot `(dx, dz, dy)`, en blocs depuis la colonne et la base.
##
## Des paires, et non des palmes : depuis le jalon 1.12 un modele de palme porte
## deux frondes opposees passant par son ancre. La raison est l'ancre elle-meme,
## qui est le centre du gabarit et non le point d'attache — une fronde unique se
## posait au sommet du stipe *par son milieu*, la moitie passant de l'autre cote
## du tronc. C'etait le decalage d'attache signale a la production du lot
## precedent ; il est resolu par le dessin, sans que l'assembleur change.
## Deux a quatre paires font donc quatre a huit frondes, le compte voulu.
const SPECIES: Dictionary = {
	CWBiome.GREENLANDS: [
		{
			"nom": "chene",
			"montage": Montage.FEUILLU,
			"tronc": "greenlands/chene_tronc",
			"couronnes": ["greenlands/chene_houppier_01",
					"greenlands/chene_houppier_02"],
			"pieces": [2, 3],
			"poids": 0.42,
		},
		{
			"nom": "bouleau",
			"montage": Montage.FEUILLU,
			"tronc": "greenlands/bouleau_tronc",
			"couronnes": ["greenlands/bouleau_houppier"],
			"pieces": [1, 2],
			"poids": 0.26,
		},
		{
			"nom": "pin",
			"montage": Montage.ENTIER,
			"tronc": "greenlands/pin",
			"couronnes": [],
			"pieces": [0, 0],
			"poids": 0.25,
		},
		# Le rocher geant : « ressemble a l'Arbre de Mana » dans l'alpha. Ce
		# n'est pas un arbre, mais il se pose par la meme couche — meme taille,
		# meme espacement, meme grille de dessin. Le ranger ailleurs aurait
		# demande une troisieme couche de dispersion pour un seul modele.
		{
			"nom": "rocher geant",
			"montage": Montage.ENTIER,
			"tronc": "greenlands/rocher_geant",
			"couronnes": [],
			"pieces": [0, 0],
			"poids": 0.05,
		},
		# L'arbre geant porte une mission dans l'alpha. Son poids le rend
		# presque unique a l'echelle d'une region : a 0,02 et 7 arbres par
		# cellule, il en sort un tous les sept cellules environ, soit tous les
		# 170 blocs. C'est encore trop frequent pour un objectif de quete, et ce
		# sera au jalon 4 de le poser par les elements de tuile plutot que par
		# la dispersion — la couche n'existe pas encore, le modele si.
		{
			"nom": "arbre geant",
			"montage": Montage.FEUILLU,
			"tronc": "greenlands/arbre_geant_tronc",
			"couronnes": ["greenlands/arbre_geant_houppier"],
			"pieces": [3, 4],
			"poids": 0.02,
		},
		{
			"nom": "erable",
			"montage": Montage.GRAND,
			"tronc": "greenlands/erable_charpente",
			"couronnes": ["greenlands/erable_dome"],
			"branches": [Vector3i(13, 0, 21), Vector3i(-11, 0, 18),
					Vector3i(0, 13, 24), Vector3i(0, -11, 20)],
			"pieces": [0, 0],
			"poids": 0.12,
		},
		{
			"nom": "cerisier",
			"montage": Montage.GRAND,
			"tronc": "greenlands/cerisier_charpente",
			"couronnes": ["greenlands/cerisier_dome"],
			"branches": [Vector3i(14, 0, 17), Vector3i(-14, 0, 20),
					Vector3i(0, 13, 15), Vector3i(0, -13, 18)],
			"pieces": [0, 0],
			"poids": 0.06,
		},
	],
	CWBiome.SNOWLANDS: [
		{
			"nom": "pin enneige",
			"montage": Montage.ENTIER,
			"tronc": "snowlands/pin_enneige",
			"couronnes": [],
			"pieces": [0, 0],
			"poids": 0.45,
		},
		{
			"nom": "sapin enneige",
			"montage": Montage.ENTIER,
			"tronc": "snowlands/sapin_enneige",
			"couronnes": [],
			"pieces": [0, 0],
			"poids": 0.35,
		},
		{
			"nom": "bouleau givre",
			"montage": Montage.FEUILLU,
			"tronc": "snowlands/bouleau_givre_tronc",
			"couronnes": ["snowlands/bouleau_givre_houppier"],
			"pieces": [1, 2],
			"poids": 0.20,
		},
		{
			"nom": "saule givre",
			"montage": Montage.GRAND,
			"tronc": "snowlands/saule_givre_charpente",
			"couronnes": ["snowlands/saule_givre_dome"],
			"branches": [Vector3i(14, 0, 17), Vector3i(-14, 0, 20),
					Vector3i(0, 13, 15), Vector3i(0, -13, 18)],
			"pieces": [0, 0],
			"poids": 0.10,
		},
		{
			"nom": "arbre pourpre",
			"montage": Montage.GRAND,
			"tronc": "snowlands/arbre_pourpre_charpente",
			"couronnes": ["snowlands/arbre_pourpre_dome"],
			"branches": [Vector3i(13, 0, 21), Vector3i(-11, 0, 18),
					Vector3i(0, 13, 24), Vector3i(0, -11, 20)],
			"pieces": [0, 0],
			"poids": 0.06,
		},
	],
	CWBiome.DESERTS: [
		{
			"nom": "cactus geant",
			"montage": Montage.ENTIER,
			"tronc": "deserts/cactus_geant",
			"couronnes": [],
			"pieces": [0, 0],
			"poids": 0.6,
		},
		# Le dattier d'oasis. Meme montage que le palmier de jungle, teintes du
		# desert : c'est un lot par biome, pas un lot partage.
		{
			"nom": "dattier",
			"montage": Montage.PALMIER,
			"tronc": "deserts/palmier_tronc",
			"couronnes": ["deserts/palme", "deserts/palme_diagonale"],
			"pieces": [3, 4],
			"poids": 0.4,
		},
		{
			"nom": "acacia",
			"montage": Montage.GRAND,
			"tronc": "deserts/acacia_charpente",
			"couronnes": ["deserts/acacia_dome"],
			"branches": [Vector3i(11, 0, 27), Vector3i(-11, 0, 24),
					Vector3i(0, 11, 29), Vector3i(0, -10, 25)],
			"pieces": [0, 0],
			"poids": 0.16,
		},
		{
			"nom": "baobab",
			"montage": Montage.GRAND,
			"tronc": "deserts/baobab_charpente",
			"couronnes": ["deserts/baobab_dome"],
			"branches": [Vector3i(14, 0, 17), Vector3i(-14, 0, 20),
					Vector3i(0, 13, 15), Vector3i(0, -13, 18)],
			"pieces": [0, 0],
			"poids": 0.08,
		},
	],
	CWBiome.JUNGLES: [
		# « Grands arbres tropicaux (base large) » : le fut est le plus epais du
		# lot et porte deux a trois houppiers, ce qui fait la canopee fermee.
		{
			"nom": "arbre tropical",
			"montage": Montage.FEUILLU,
			"tronc": "jungles/tropical_tronc",
			"couronnes": ["jungles/tropical_houppier_01",
					"jungles/tropical_houppier_02"],
			"pieces": [2, 3],
			"poids": 0.6,
		},
		{
			"nom": "palmier",
			"montage": Montage.PALMIER,
			"tronc": "jungles/palmier_tronc",
			"couronnes": ["jungles/palme", "jungles/palme_diagonale"],
			"pieces": [3, 4],
			"poids": 0.4,
		},
		{
			"nom": "flamboyant",
			"montage": Montage.GRAND,
			"tronc": "jungles/flamboyant_charpente",
			"couronnes": ["jungles/flamboyant_dome"],
			"branches": [Vector3i(11, 0, 27), Vector3i(-11, 0, 24),
					Vector3i(0, 11, 29), Vector3i(0, -10, 25)],
			"pieces": [0, 0],
			"poids": 0.10,
		},
		{
			"nom": "jacaranda",
			"montage": Montage.GRAND,
			"tronc": "jungles/jacaranda_charpente",
			"couronnes": ["jungles/jacaranda_dome"],
			"branches": [Vector3i(13, 0, 21), Vector3i(-11, 0, 18),
					Vector3i(0, 13, 24), Vector3i(0, -11, 20)],
			"pieces": [0, 0],
			"poids": 0.08,
		},
	],
	CWBiome.LAVALANDS: [
		# « Thorn Tree : rare, pas de drop ». C'est le seul arbre du biome, et sa
		# rarete vient de la densite de Lava Lands (0,5 par cellule), pas d'un
		# poids : il n'a pas de concurrent.
		{
			"nom": "arbre a epines",
			"montage": Montage.ENTIER,
			"tronc": "lavalands/arbre_epineux",
			"couronnes": [],
			"pieces": [0, 0],
			"poids": 1.0,
		},
		{
			"nom": "arbre de cendre",
			"montage": Montage.GRAND,
			"tronc": "lavalands/arbre_de_cendre_charpente",
			"couronnes": ["lavalands/arbre_de_cendre_dome"],
			"branches": [Vector3i(13, 0, 21), Vector3i(-11, 0, 18),
					Vector3i(0, 13, 24), Vector3i(0, -11, 20)],
			"pieces": [0, 0],
			"poids": 0.30,
		},
		{
			"nom": "arbre de braise",
			"montage": Montage.GRAND,
			"tronc": "lavalands/arbre_de_braise_charpente",
			"couronnes": ["lavalands/arbre_de_braise_dome"],
			"branches": [Vector3i(11, 0, 27), Vector3i(-11, 0, 24),
					Vector3i(0, 11, 29), Vector3i(0, -10, 25)],
			"pieces": [0, 0],
			"poids": 0.20,
		},
	],
}


## Tous les chemins employes par les especes d'un biome, tronc et couronnes
## confondus. Sert a construire la bibliotheque et a verifier le lot.
static func paths_of(biome: int) -> Array:
	var out: Array = []
	for sp in SPECIES.get(biome, []):
		for path in ([sp["tronc"]] as Array) + (sp["couronnes"] as Array):
			if not out.has(path):
				out.append(path)
	return out


## Tous les chemins du lot, tous biomes confondus.
static func all_paths() -> Array:
	var out: Array = []
	for biome in SPECIES:
		for path in paths_of(biome):
			if not out.has(path):
				out.append(path)
	return out


## L'espece a poser, tiree dans `[0, 1)` selon les poids du biome, ou un
## dictionnaire vide si le biome n'a pas d'arbre.
##
## Le tirage est un simple choix pondere et non une crete de bruit : a la
## difference du decor, deux especes d'arbres voisines ne se disputent pas la
## composition d'une region — un bosquet de sapins et un de sapins enneiges se
## melangent sans que cela choque. Si un jour il faut des peuplements purs, c'est
## ici que se brancherait une crete a 0,01, exactement comme dans `CWDecorRules`.
static func species_at(biome: int, pick: float) -> Dictionary:
	var list: Array = SPECIES.get(biome, [])
	if list.is_empty():
		return {}
	var total: float = 0.0
	for sp in list:
		total += float(sp["poids"])
	var t: float = clampf(pick, 0.0, 0.999999) * total
	for sp in list:
		t -= float(sp["poids"])
		if t < 0.0:
			return sp
	return list[-1]


## Biomes qui portent des arbres. Oceans n'en a pas : une ile emergee n'est
## pas Oceans, c'est son climat qui la nomme, et elle porte les arbres qui vont
## avec.
static func biomes() -> Array:
	return SPECIES.keys()
