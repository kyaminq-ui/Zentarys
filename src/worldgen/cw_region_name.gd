class_name CWRegionName
extends RefCounted

## Nom d'une région (jalon 1.10). Portage de `NameGen_generateRegionName`
## (@005a6550). Analyse complète : `docs/systems/05`, §6.
##
## -- Le mécanisme -------------------------------------------------------------
## Deux tables de vingt syllabes, initialisées une fois. Le point demandé est
## déformé, ramené en unités de zone, tronqué en deux entiers `a` et `b`, et le
## nom est la concaténation de deux syllabes indexées en croix :
##
##     nom = tableA[(a*3 + graineA + b) % 20] + tableB[(b*3 + graineB + a) % 20]
##
## Le croisement (`a` puis `b` dans un indice, `b` puis `a` dans l'autre) est
## dans l'original ; il évite que deux régions d'une même diagonale partagent
## leurs deux syllabes.
##
## -- La déformation -----------------------------------------------------------
## `Terrain_sampleHeightNoise` (@0059fc90) ne rend pas une altitude malgré son
## nom : c'est la déformation à ±500 unités, divisée par 16 384, donc exprimée
## en zones. C'est mot pour mot `CWTerrainField.edge_warped_point`, portée au
## jalon 1.4. Un nom est donc constant sur une cellule de zone du *domaine
## déformé*, et non sur la grille de zones : les frontières de noms ondulent
## comme celles du climat.
##
## -- Les syllabes ne sont pas portées -----------------------------------------
## Six des quarante syllabes de l'original sont lisibles en clair dans le
## binaire. Ce sont des créations artistiques du jeu d'origine, donc hors
## périmètre : les deux tables ci-dessous sont **écrites pour ce projet**. Seul
## le mécanisme — deux tables de vingt, la formule d'indice, la concaténation —
## est porté.

## Taille des deux tables. C'est le `% 0x14` de l'original, et il est porteur :
## il fixe le nombre de noms distincts qu'un monde peut produire (400).
const TABLE_SIZE: int = 20

## Facteur du terme croisé, `a*3 + graine + b`. Verbatim.
const CROSS_FACTOR: int = 3

## Taille d'une zone, en unités monde : la déformation est rendue en zones.
const ZONE_SIZE: int = CWWorldParams.ZONE_SIZE

## Première syllabe. Création originale (voir l'en-tête).
const PREFIX: Array[String] = [
	"bel", "cor", "dun", "esk", "fal", "gor", "hin", "irk", "jor", "kel",
	"lum", "mar", "nis", "orr", "pel", "quen", "ras", "sol", "tir", "vel",
]

## Seconde syllabe. Création originale.
const SUFFIX: Array[String] = [
	"andra", "beth", "corin", "dane", "eth", "faye", "goth", "helm", "ith",
	"karn", "lund", "mere", "noss", "ovar", "pyre", "reth", "sund", "thal",
	"vane", "wyn",
]

## Décalage de graine du tirage des deux constantes de nom. Les deux entiers
## `+0x80028c` et `+0x800290` du bloc de données du monde ne sont pas
## récupérables ; on les dérive du même LCG que les décalages de bruit, ce qui
## garde le déterminisme sans prétendre à l'équivalence bit à bit.
const SEED_SALT: int = 0x4E414D45  # "NAME"

var _field: CWTerrainField
var _seed_a: int = 0
var _seed_b: int = 0


func _init(field: CWTerrainField) -> void:
	_field = field
	var rng := CWRand.new(field.params().world_seed ^ SEED_SALT)
	_seed_a = rng.next()
	_seed_b = rng.next()


## Les deux constantes de nom du monde, pour les tests et l'outillage.
func seeds() -> Vector2i:
	return Vector2i(_seed_a, _seed_b)


## Nom de la région qui contient le point monde (x, z).
func at(x: int, z: int) -> String:
	return _from_cell(cell_of(x, z))


## Nom de la région d'une zone, évalué **à la position de son site**.
##
## C'est la forme qui sert à la carte : la formule d'origine est ponctuelle, donc
## une pièce de carte assez large pour franchir une frontière du domaine déformé
## porterait deux noms. Ancrer le nom au site en donne un et un seul par pièce,
## et c'est le point le plus représentatif de la région puisque tout le climat
## en découle.
func of_zone(zx: int, zz: int) -> String:
	var site: CWRegionSite = _field.sites().get_site(zx, zz)
	if site == null:
		return ""
	return at(site.x, site.z)


## Cellule de nom : le point déformé, en unités de zone, tronqué.
##
## `Vec2_DoubleToInt` tronque vers zéro ; les coordonnées monde sont positives
## sur toute la carte, donc `floori` en est l'équivalent exact ici — et il reste
## correct si un appelant sort du monde par la gauche.
func cell_of(x: int, z: int) -> Vector2i:
	var p: Vector2 = _field.edge_warped_point(x, z)
	return Vector2i(
			floori(p.x / float(ZONE_SIZE)),
			floori(p.y / float(ZONE_SIZE)))


func _from_cell(c: Vector2i) -> String:
	var i: int = posmod(c.x * CROSS_FACTOR + _seed_a + c.y, TABLE_SIZE)
	var j: int = posmod(c.y * CROSS_FACTOR + _seed_b + c.x, TABLE_SIZE)
	var name: String = PREFIX[i] + SUFFIX[j]
	return name.substr(0, 1).to_upper() + name.substr(1)
