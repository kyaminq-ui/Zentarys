class_name CWFloraDrops
extends RefCounted

## Ce que rend une plante quand on la ramasse, et ce qu'on en fait ensuite.
##
## -- Pourquoi cette table existe avant l'inventaire ---------------------------
##
## Rien ne la consomme aujourd'hui : l'inventaire est au jalon 3.2 et la recolte
## au jalon 3.1. Elle est ecrite maintenant parce que **c'est maintenant qu'on
## connait l'information** — le lot de flore du jalon 1.12 a ete commande a
## partir des roles de l'alpha 2013, et chacun de ces roles y a un drop connu.
## Saisir la chaine au moment ou on dessine la plante coute une ligne ; la
## rededuire dans six mois coutera de rouvrir la question « quelle plante etait
## le lin, deja ».
##
## C'est aussi le seul endroit du projet ou une plante a un sens *de jeu* et non
## de paysage. `CWDecorRules` dit ou elle pousse, `CWModelLibrary` de quel
## fichier elle sort ; ici on dit a quoi elle sert.
##
## -- Perimetre juridique ------------------------------------------------------
##
## Les *noms* d'objets ci-dessous sont ceux de l'alpha 2013, en anglais, parce
## qu'ils nomment une mecanique observee et servent de cle de recoupement avec
## l'analyse. Ce sont des noms courts et fonctionnels — « plant fiber »,
## « silk yarn » —, pas de l'expression artistique. Les modeles, les couleurs et
## les statistiques associees, eux, sont des creations de ce projet (voir
## `README.md`, perimetre et mention legale).
##
## -- Ce qui n'est pas ici -----------------------------------------------------
##
## Aucune quantite, aucune probabilite, aucune statistique d'objet. La source ne
## les donne pas et ce projet ne les a pas mesurees : mettre « 1 a 3 fibres »
## serait inventer un chiffre que le jalon 3.2 aurait ensuite a defendre. La
## table dit **quoi**, pas **combien**.

## Cle : le nom de fichier d'un modele de flore, sans dossier ni extension —
## celui-la meme que `CWModelLibrary` charge. Valeur : la liste des objets
## rendus au ramassage.
##
## Un modele absent de la table ne rend rien, et c'est la reponse par defaut :
## on ne ramasse pas un brin d'herbe.
const DROPS: Dictionary = {
	# Le buisson est la plante utile de base, et elle l'est dans tous les
	# biomes : c'est la seule qui rende deux matieres a la fois.
	"buisson": ["wood logs", "plant fiber"],
	"buisson_neige": ["wood logs", "plant fiber"],
	"broussaille": ["wood logs", "plant fiber"],
	"broussaille_seche": ["wood logs", "plant fiber"],
	# « Fire Shrub : drops identiques au Bush » — releve de l'alpha, garde tel
	# quel. C'est ce qui rend Lava Lands jouable malgre le magma.
	"fire_shrub": ["wood logs", "plant fiber"],

	# Le scrub rend de la toile, pas de la fibre. C'est la seconde chaine
	# textile, et la seule source de soie.
	"scrub": ["cobweb"],

	# Les fleurs a effet. L'iceflower est la variante gelee de la fleur de
	# coeur et rend la meme chose : c'est un climat, pas une autre plante.
	"fleur_coeur": ["life potion"],
	"fleur_de_glace": ["life potion"],
	"ginseng": ["ginseng root"],
	"fleur_ame": ["soul essence"],

	# Le desert et ses deux cultures.
	"cactus_01": ["prickly pear"],
	"cactus_02": ["prickly pear"],
	"cotonnier": ["cotton capsules"],
	"habanero": ["habanero"],

	# Snowlands.
	"snowberry": ["snowberry"],

	# Le champignon luisant n'a **aucun usage de jeu dans l'alpha** : il n'est
	# la que pour sa lumiere. Il figure ici avec une liste vide, et c'est
	# volontaire — sans cette entree, la prochaine relecture se demanderait s'il
	# a ete oublie.
	"champignon_luisant": [],
}

## Ce qu'on fait des matieres : matiere -> [etapes suivantes].
##
## Trois chaines, et elles menent chacune a une armure. C'est la boucle
## d'artisanat de l'alpha, et elle explique la repartition des plantes dans les
## biomes : le lin pousse partout, la soie sort d'un role minoritaire, le coton
## ne pousse qu'au chaud et au froid extreme.
const CRAFT: Dictionary = {
	"plant fiber": ["linen yarn"],
	"linen yarn": ["linen armor", "bow string"],
	"cobweb": ["silk yarn"],
	"silk yarn": ["silk armor"],
	"cotton capsules": ["cotton yarn"],
	"cotton yarn": ["rogue armor"],
	"prickly pear": ["cactus potion"],
	"ginseng root": ["ginseng soup"],
}


## Ce que rend ce modele, ou un tableau vide.
static func drops_of(model_name: String) -> Array:
	return DROPS.get(model_name, [])


## Ce qu'on peut faire de cette matiere, ou un tableau vide.
static func craft_from(item: String) -> Array:
	return CRAFT.get(item, [])


## La chaine complete a partir d'une matiere, sans doublon et sans cycle.
## Sert aux tests et a l'inspection : `plant fiber` -> `linen yarn` ->
## `linen armor`, `bow string`.
static func chain_from(item: String) -> Array:
	var out: Array = []
	var todo: Array = [item]
	while not todo.is_empty():
		var current: String = todo.pop_front()
		for next in craft_from(current):
			if out.has(next):
				continue
			out.append(next)
			todo.append(next)
	return out
