class_name CWDecorRules
extends RefCounted

## Choix du decor a poser : role, rarete, taille, orientation (jalon 1.7).
##
## C'est la piece qui manquait au jalon 1.7 — la table « type de decor ->
## modele » de `docs/systems/02`, §8.5. Elle est portee de la **seconde voie de
## pose** de l'original : la flore basse n'est pas une entite, c'est un
## enregistrement de decor pousse en fin de boucle de colonne par
## `WorldInfo_generateBiomeContent` (@005e4850). Analyse : `docs/systems/02`,
## §8.6.
##
## -- Ce que la source donne, et ce qu'on en fait ------------------------------
##
## L'original decide en trois temps, et les trois sont portes ici :
##
##   1. **une crete de placement** a 0,05 dit *ou* il y a du decor — c'est
##      `CWScatter.PLACEMENT_RIDGE`, porte le 2026-09-05 ;
##   2. **deux cretes de selection** a 0,01, de decalages differents, disent
##      *lequel*. La premiere tranche la famille, la seconde la variante. Ce
##      sont deux champs de bruit tres lents : sur une centaine de blocs, c'est
##      le meme choix qui domine, et c'est de la que vient la composition
##      regionale — une prairie de bleuets et, mille blocs plus loin, une
##      prairie d'herbe rase ;
##   3. **une rarete entiere** (`rand()%8`, `%10`, `%100`) filtre certains
##      roles, appliquee *apres* les cretes.
##
## Les decalages `(9843, 8437)` et `(34234, 234234)` sont ceux du binaire, et
## ils comptent : ce sont eux qui eloignent les deux reseaux de bruit l'un de
## l'autre. Deux cretes au meme decalage donneraient deux fois la meme carte.
##
## -- Ce qui n'est pas transposable tel quel -----------------------------------
##
## L'original choisit sur son **type de bloc de surface** (0 air, 2 eau, 3 sol
## humide, 4 et 9 sol vegetalise, 10 neige, 12 sol de region, 6 roche), puis
## affine par des seuils de climat *dans la regle*. `CWPalette.surface_index`,
## lui, a deja mange le climat : la jungle et le marais y sont des surfaces, pas
## des branches. La forme de la regle est donc portee telle quelle — deux
## cretes, une famille puis une variante, une rarete entiere — et ce sont ses
## *feuilles* qui sont reattribuees a nos neuf surfaces. Le detail de la
## correspondance, branche par branche, est dans `docs/systems/02`, §8.6.
##
## Trois roles de la source n'ont pas de modele ici et sont donc absents :
## le nenuphar (types 31/32 de l'original, sur l'eau), et les deux decors de mur
## (lierre et rosier, types 41-43) qui sont du jalon 4.3.

## Les roles du decor. Un role est une *fonction* dans le paysage, pas un
## modele : chaque surface donne sa propre liste de modeles pour chaque role
## (`CWModelLibrary.ROLES`), et c'est ce qui fait qu'un caillou de neige n'est
## pas un caillou de prairie.
enum Role {
	## Rien a poser.
	AUCUN = 0,
	## Couvert bas et dense : herbe, feuillage au sol. Types 2, 3, 4 de la
	## source, les plus frequents.
	COUVERT,
	## Fleurs et bouquets. Types 0 et 1 de la source.
	FLEUR,
	## Mineral pose : caillou, gres. Type 12, et sa taille est plus grande.
	CAILLOU,
	## Sous-bois : buisson, broussaille, liane. Type 11, plus petit.
	SOUS_BOIS,
	## Le rare : cactus, champignon. Type 27/28, tirage a 1 sur 100.
	RARE,
	## Roseau de rive. Type 22 : lacet libre, un peu plus grand.
	ROSEAU,
	## Algue de fond marin. Type 5.
	ALGUE,
	## Corail de fond marin. Type 6.
	CORAIL,
	## Ce qui rampe au fond : etoile de mer. Type 7.
	FOND,
}

## Frequence des deux cretes de selection. Dix fois plus lente que la crete de
## placement : une region entiere partage sa dominante.
const SELECT_FREQ: float = 0.01

## Premiere crete : elle tranche la **famille**. Decalages du binaire.
const SELECT_A_X: float = 9843.0
const SELECT_A_Z: float = 8437.0

## Seconde crete : elle tranche la **variante** dans la famille. Ses decalages
## sont differents, et c'est tout l'interet — au meme decalage, les deux cretes
## rendraient la meme carte et la seconde ne dirait rien.
const SELECT_B_X: float = 34234.0
const SELECT_B_Z: float = 234234.0

## Seuil asymetrique de la branche humide de la source
## (`local_30c = (n2 <= 0.5) + 0xb`) : la seconde crete y penche nettement d'un
## cote. Reproduit tel quel — c'est ce qui rend le sous-bois minoritaire.
const SELECT_B_BIAS: float = 0.5

## Denominateur du tirage entier qui garde le role `RARE` : la source ne pose sa
## paire humide et froide que si `rand() % 100 == 0`, **en plus** du tirage a
## 1 sur 8 qui filtre deja toute la branche. C'est le seul endroit ou elle
## empile deux raretes, et c'est ce qui fait de ce role un role rare.
##
## Les autres roles n'en ont pas, et c'est delibere : leur `rand()%8` d'origine
## est le tirage *par colonne*, celui que ce projet a remplace le 2026-09-05 par
## un budget de candidats par cellule (`CWScatter`, « pourquoi la rarete entiere
## n'est pas portee telle quelle »). Le reappliquer ici le compterait deux fois
## et viderait le paysage des sept huitiemes de sa flore. Le roseau, a 1 sur 8
## dans la source, tombe donc dans ce cas : sa rarete est deja payee.
const RARITY_RARE: int = 100

## Multiplicateur de taille par role, rapporte a l'echelle d'auteur.
##
## La source ecrit ses echelles en dur : **0,075** est la taille de reference —
## et c'est exactement `3/40`, le rapport voxel/bloc de ce projet, ce qui veut
## dire que nos modeles sont dessines a la taille nominale du decor d'origine.
## Les ecarts sont donc lisibles en clair : le roseau et le nenuphar sont a
## 0,09, soit **1,2x** ; le caillou a 0,1-0,12, soit **1,33x a 1,6x** ; le
## sous-bois humide a 0,05-0,10, soit **0,67x a 1,33x**.
##
## Ces rapports multiplient la gigue d'instance de `CWScatter`, ils ne la
## remplacent pas : la source ne tire une gigue que sur le decor immerge, mais
## notre lot a moins de variantes par role et le champ se lirait comme un motif
## sans elle.
const SCALE_RATIO: Dictionary = {
	Role.COUVERT: 1.0,
	Role.FLEUR: 1.0,
	Role.CAILLOU: 1.45,
	Role.SOUS_BOIS: 0.85,
	Role.RARE: 1.0,
	Role.ROSEAU: 1.2,
	Role.ALGUE: 1.0,
	Role.CORAIL: 1.33,
	Role.FOND: 1.33,
}

## Le plus grand rapport de la table. Entre dans la marge de `placements_in` et
## dans la boite de visibilite des `MultiMesh` : une instance peut deborder de
## `SCALE_MAX x SCALE_RATIO_MAX` fois le rayon de son modele, et l'oublier fait
## disparaitre les plus grosses touffes du bord du champ.
const SCALE_RATIO_MAX: float = 1.45

## Roles dont le lacet est libre plutot que par quarts de tour. La source a les
## deux regimes : `(rand()%4) * 90` pour ce qui pose au sol, `rand() * 360/32767`
## pour le roseau, le nenuphar et le decor de sous-bois humide.
##
## `CWVoxelModel` ne precalcule que quatre quarts de tour ; le lacet libre est
## donc note ici mais pas encore rendu. Il attend une rotation continue du
## maillage — sans effet sur la selection, qui est ce que ce fichier decide.
const FREE_YAW: Dictionary = {
	Role.ROSEAU: true,
	Role.SOUS_BOIS: true,
}


## Vrai si du decor peut pousser sur cette matiere, dans ce biome.
##
## C'est la piece qui manquait tant que « biome » voulait dire « matiere de
## surface » : depuis le jalon 1.12 les deux sont separes, et une prairie de
## Greenlands garde son biome jusqu'au sommet de sa montagne. Sans ce filtre,
## elle y semerait ses bleuets sur la roche nue et sur la neige de crete.
##
## La neige est le cas interessant : elle est **le sol** d'une Snowlands, et une
## simple calotte de sommet partout ailleurs. Le meme bloc, deux sens — d'ou un
## filtre qui prend les deux arguments et non le seul materiau.
static func decor_allowed(biome: int, surface: int) -> bool:
	match surface:
		CWPalette.STONE, CWPalette.MAGMA, CWPalette.WATER, CWPalette.WATER_DEEP:
			return false
		CWPalette.SNOW:
			return biome == CWBiome.SNOWLANDS
		_:
			return true


## Role a poser dans `biome`, sur la matiere `surface`, au point (x, z), ou
## `Role.AUCUN`.
##
## Deterministe et sans etat : deux appels au meme point rendent le meme role,
## quel que soit ce qui a ete visite avant. Les tirages entiers de rarete, eux,
## restent a l'appelant — c'est lui qui tient le flux du LCG de sa cellule.
##
## La matiere n'intervient que par les deux exceptions de `FAMILIES_SURFACE` :
## c'est le **biome** qui decide de la composition, et c'est tout l'objet du
## jalon 1.12.
static func role_at(biome: int, surface: int, x: int, z: int) -> int:
	var families: Array = FAMILIES_SURFACE.get(surface, EMPTY)
	if families.is_empty():
		families = FAMILIES.get(biome, EMPTY)
	if families.is_empty():
		return Role.AUCUN
	# Premiere crete : la famille. Le test est celui de la source, sur le signe.
	var a: float = CWValueNoise.sample(
			float(x) * SELECT_FREQ + SELECT_A_X,
			float(z) * SELECT_FREQ + SELECT_A_Z)
	var branch: Array = families[0] if a <= 0.0 else families[1]
	if branch.size() == 1:
		return branch[0]
	# Seconde crete : la variante. Le seuil est biaise, comme dans la source.
	var b: float = CWValueNoise.sample(
			float(x) * SELECT_FREQ + SELECT_B_X,
			float(z) * SELECT_FREQ + SELECT_B_Z)
	return branch[0] if b <= SELECT_B_BIAS else branch[1]


## Denominateur du tirage entier de rarete : le role n'est pose que si
## `rand() % rarity_of(role) == 0`.
static func rarity_of(role: int) -> int:
	return RARITY_RARE if role == Role.RARE else 1


static func scale_ratio_of(role: int) -> float:
	return SCALE_RATIO.get(role, 1.0)


static func free_yaw_of(role: int) -> bool:
	return FREE_YAW.has(role)


static func name_of(role: int) -> String:
	match role:
		Role.COUVERT: return "couvert"
		Role.FLEUR: return "fleur"
		Role.CAILLOU: return "caillou"
		Role.SOUS_BOIS: return "sous-bois"
		Role.RARE: return "rare"
		Role.ROSEAU: return "roseau"
		Role.ALGUE: return "algue"
		Role.CORAIL: return "corail"
		Role.FOND: return "fond"
		_: return "aucun"


const EMPTY: Array = []

## Les deux branches de la premiere crete, par surface : `[branche_negative,
## branche_positive]`, chacune de un ou deux roles que la seconde crete
## departage.
##
## La **forme** vient de la source — deux cretes, famille puis variante — et les
## trois branches qu'elle donne litteralement sont ici verbatim :
##
##   * sol tempere : `n1 <= 0` -> fleur, sinon couvert (types 0/1 contre 2/3) ;
##   * sol chaud et sec : la seconde crete y fait entrer le mineral (type 12) ;
##   * fond marin : `n1 <= 0` -> un role a part (type 7), sinon les deux autres
##     (types 5 et 6), ce qui est mot pour mot le test de signe `alga`/`coral`.
##
## Les autres lignes reattribuent ces feuilles a nos surfaces, qui portent deja
## le climat. Ce sont des affectations de ce projet, pas des lectures : les
## changer coute une ligne, et rien dans la source ne les contraint.
const FAMILIES: Dictionary = {
	# Greenlands : la branche temperee de la source, telle quelle — fleur contre
	# couvert. La seconde crete y fait entrer nos deux minoritaires, le
	# sous-bois et le caillou, que la branche d'origine, a deux feuilles,
	# n'avait pas ou mettre. C'est le biome le plus fourni du monde et celui ou
	# les quatre roles ont chacun plusieurs modeles.
	CWBiome.GREENLANDS: [[Role.FLEUR, Role.SOUS_BOIS], [Role.COUVERT, Role.CAILLOU]],
	# Snowlands : le froid inverse les poids. Le couvert y est rare et court, le
	# sous-bois — buisson blanc, snowberry — porte l'essentiel de la silhouette,
	# et le caillou erratique tient le role du mineral pose.
	CWBiome.SNOWLANDS: [[Role.FLEUR, Role.CAILLOU], [Role.SOUS_BOIS, Role.COUVERT]],
	# Deserts : la branche chaude et seche de la source, ou la seconde crete
	# fait entrer le mineral. Pas de couvert du tout — un desert n'a pas de
	# tapis herbace, et c'est ce qui le distingue d'une steppe. Les cactus
	# tiennent le sous-bois, sans quoi la rarete a 1 sur 100 les effacerait.
	CWBiome.DESERTS: [[Role.SOUS_BOIS, Role.CAILLOU], [Role.SOUS_BOIS, Role.RARE]],
	# Jungles : la branche humide et chaude. La source y met du decor a echelle
	# reduite d'un cote, du couvert de l'autre. C'est le biome le plus dense.
	CWBiome.JUNGLES: [[Role.SOUS_BOIS, Role.RARE], [Role.COUVERT, Role.FLEUR]],
	# Lava Lands : « Thorn Tree rare, Fire Shrub, et les plantes persistent »
	# (alpha 2013). Le sous-bois est donc le role dominant — c'est le Fire Shrub
	# et l'herbe de lave —, le mineral est de la scorie, et le rare porte le
	# champignon luisant. La fleur est la `lava-flower` du corpus de modeles
	# (`docs/systems/02`, Sec. 7), l'une des trois variantes `lava-*` que ce
	# projet n'avait pas pu produire tant qu'il n'avait pas de surface
	# volcanique — il en a une depuis le jalon 1.12.
	CWBiome.LAVALANDS: [[Role.SOUS_BOIS, Role.CAILLOU], [Role.FLEUR, Role.RARE]],
	# Oceans : le test de signe du fond marin, verbatim — d'un cote ce qui
	# rampe, de l'autre les deux dresses. Une ile n'est pas Oceans : des qu'une
	# colonne emerge, `CWBiome.at` rend son biome climatique et elle porte la
	# vegetation qui va avec.
	CWBiome.OCEANS: [[Role.FOND], [Role.ALGUE, Role.CORAIL]],
}

## Les deux exceptions ou c'est la **matiere** qui decide, et non le biome.
## Consultees avant `FAMILIES`.
##
## Le sol humide est la seule branche de la source qui soit attachee a un type
## de bloc et non a un climat (`reed` sur le type 3), et elle est gardee telle
## quelle : un bord de riviere de jungle porte des roseaux, pas des lianes.
## L'herbe seche, elle, est la frange de Greenlands vers le desert — elle garde
## la composition de Greenlands moins la fleur, qui n'y tient pas.
const FAMILIES_SURFACE: Dictionary = {
	CWPalette.SWAMP: [[Role.ROSEAU, Role.RARE], [Role.COUVERT, Role.FLEUR]],
	CWPalette.GRASS_DRY: [[Role.SOUS_BOIS, Role.CAILLOU], [Role.COUVERT, Role.SOUS_BOIS]],
}

## Le biome qui produit chacune de ces deux matieres. Ce n'est pas de la
## documentation : c'est ce qui permet a `tests/decor_test.gd` de verifier que
## les roles d'une exception ont bien un modele **dans le biome ou l'exception
## peut se produire**.
##
## Sans cette table, le trou serait exactement celui de l'invariant n° 22, en
## plus discret encore : le sol humide choisirait un roseau, `CWModelLibrary`
## irait le chercher dans Jungles, ne le trouverait pas, et la rive serait nue
## sans qu'aucune densite ne bouge. C'est `CWPalette.surface_of` qui decide qui
## produit quoi, et les deux tables doivent rester d'accord.
const FAMILIES_SURFACE_BIOME: Dictionary = {
	CWPalette.SWAMP: CWBiome.JUNGLES,
	CWPalette.GRASS_DRY: CWBiome.GREENLANDS,
}
