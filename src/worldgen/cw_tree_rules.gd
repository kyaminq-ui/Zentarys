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
## `pieces` est le nombre de houppiers empiles (FEUILLU) ou de palmes en
## couronne (PALMIER), tire dans l'intervalle donne.
const SPECIES: Dictionary = {
	CWPalette.GRASS: [
		{
			"nom": "feuillu",
			"montage": Montage.FEUILLU,
			"tronc": "herbe/tronc_feuillu",
			"couronnes": ["herbe/houppier_01", "herbe/houppier_02"],
			"pieces": [2, 3],
			"poids": 1.0,
		},
	],
	CWPalette.GRASS_DRY: [
		{
			"nom": "arbre sec",
			"montage": Montage.ENTIER,
			"tronc": "herbe_seche/arbre_sec",
			"couronnes": [],
			"pieces": [0, 0],
			"poids": 0.65,
		},
		{
			"nom": "feuillu d'automne",
			"montage": Montage.FEUILLU,
			"tronc": "herbe/tronc_feuillu",
			"couronnes": ["herbe_seche/houppier_sec"],
			"pieces": [1, 2],
			"poids": 0.35,
		},
	],
	CWPalette.GRASS_JUNGLE: [
		{
			"nom": "canopee",
			"montage": Montage.FEUILLU,
			"tronc": "jungle/tronc_palmier",
			"couronnes": ["jungle/houppier_jungle"],
			"pieces": [1, 2],
			"poids": 0.6,
		},
		{
			"nom": "palmier",
			"montage": Montage.PALMIER,
			"tronc": "jungle/tronc_palmier",
			"couronnes": ["jungle/palme", "jungle/palme_diagonale"],
			"pieces": [5, 8],
			"poids": 0.4,
		},
	],
	CWPalette.SWAMP: [
		{
			"nom": "arbre mort",
			"montage": Montage.ENTIER,
			"tronc": "marais/arbre_mort",
			"couronnes": [],
			"pieces": [0, 0],
			"poids": 1.0,
		},
	],
	CWPalette.SAND: [
		{
			"nom": "dattier",
			"montage": Montage.ENTIER,
			"tronc": "sable_desert/palmier_dattier",
			"couronnes": [],
			"pieces": [0, 0],
			"poids": 1.0,
		},
	],
	CWPalette.SNOW: [
		{
			"nom": "sapin enneige",
			"montage": Montage.ENTIER,
			"tronc": "neige/sapin_enneige",
			"couronnes": [],
			"pieces": [0, 0],
			"poids": 0.6,
		},
		{
			"nom": "sapin",
			"montage": Montage.ENTIER,
			"tronc": "neige/sapin",
			"couronnes": [],
			"pieces": [0, 0],
			"poids": 0.4,
		},
	],
	CWPalette.TUNDRA: [
		{
			"nom": "sapin rabougri",
			"montage": Montage.ENTIER,
			"tronc": "toundra/sapin_rabougri",
			"couronnes": [],
			"pieces": [0, 0],
			"poids": 1.0,
		},
	],
}


## Tous les chemins employes par les especes d'une surface, tronc et couronnes
## confondus. Sert a construire la bibliotheque et a verifier le lot.
static func paths_of(surface: int) -> Array:
	var out: Array = []
	for sp in SPECIES.get(surface, []):
		for path in ([sp["tronc"]] as Array) + (sp["couronnes"] as Array):
			if not out.has(path):
				out.append(path)
	return out


## Tous les chemins du lot, toutes surfaces confondues.
static func all_paths() -> Array:
	var out: Array = []
	for surface in SPECIES:
		for path in paths_of(surface):
			if not out.has(path):
				out.append(path)
	return out


## L'espece a poser, tiree dans `[0, 1)` selon les poids de la surface, ou un
## dictionnaire vide si la surface n'a pas d'arbre.
##
## Le tirage est un simple choix pondere et non une crete de bruit : a la
## difference du decor, deux especes d'arbres voisines ne se disputent pas la
## composition d'une region — un bosquet de sapins et un de sapins enneiges se
## melangent sans que cela choque. Si un jour il faut des peuplements purs, c'est
## ici que se brancherait une crete a 0,01, exactement comme dans `CWDecorRules`.
static func species_at(surface: int, pick: float) -> Dictionary:
	var list: Array = SPECIES.get(surface, [])
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


## Surfaces qui portent des arbres.
static func surfaces() -> Array:
	return SPECIES.keys()
