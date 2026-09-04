class_name CWTileFeature
extends RefCounted

## Un « element de tuile » : le jalon qui deforme localement le terrain et qui
## sert d'ancre au contenu d'une tuile de 2048 unites monde.
##
## Tracabilite : structure de 0x68 octets, une par tuile, rangee dans un tableau
## de 8 x 8 par zone a l'offset +0x14018 de l'enregistrement de zone. Adressage
## reconstruit depuis `World_getTileAtCoords` (@004286f0) :
##   tuile = x >> 11 (grille 8192 x 8192), zone = tuile / 8,
##   index dans la zone = (tz % 8) + (tx % 8) * 8.
##
## Champs reconstruits depuis les motifs d'ecriture de
## `World_generateRegionFeatures` (@0050e080) et de lecture de
## `World_baseHeightField` (@004f9b70) :
##   +0x00 int64 x        position monde, virgule fixe 16.16
##   +0x08 int64 z        idem
##   +0x10 float rayon    en unites monde
##   +0x14 float altitude echantillonnee au moment du placement
##   +0x18 int   type
##   +0x1c int   variante
##   +0x20 int   identifiant (graine du site pour le bourg, compteur sinon)
##   +0x24 int   palier
##   +0x28 int   difficulte
##
## Les positions sont conservees ici en flottant double : le format 16.16 de
## l'original n'est qu'un detail de representation, et sa precision (1/65536
## d'unite monde) est tres au-dela de ce que le champ d'altitude peut resoudre.

# -- Types --------------------------------------------------------------------
# Seuls ces cinq types deforment l'altitude. Les autres sont des ancres de
# contenu, posees ici pour que le flux aleatoire reste fidele, et exploitees au
# jalon 1.7 :
#   2, 3 (3 variantes), 5 (4 variantes selon le climat), 11, 12,
#   14 (agglomeration, calee sur la grille de 256), 15 (variante oceanique).

## Bourg. Un seul par zone, pose sur le site de region lui-meme. Aplanit le
## relief et pilote `World_roadField`.
const TYPE_TOWN: int = 1
## Cratere : le terrain descend a `altitude - 50` au centre.
const TYPE_CRATER: int = 4
## Caldeira a bord releve, deux variantes indistinctes pour l'altitude.
const TYPE_CALDERA_A: int = 6
const TYPE_CALDERA_B: int = 7
## Donjon. Pose par une passe separee, sans effet sur l'altitude.
const TYPE_DUNGEON: int = 10
## Piton de +150. Le champ d'altitude le gere, mais
## `World_generateRegionFeatures` ne le produit jamais : son `switch(rand()%8)`
## ne rend que 2, 3, 4/15, 5, 6/15, 7/15, 11 et 12. Porte pour completude, et
## parce que le client ou une autre passe le pose vraisemblablement.
const TYPE_SPIRE: int = 13

## Types pour lesquels `World_objectFalloffWeight` desactive la deformation du
## domaine et compare une distance nue.
const UNWARPED_TYPES: Array[int] = [11, 12, 14]

var x: float = 0.0
var z: float = 0.0
var radius: float = 0.0
var height: float = 0.0
var type: int = 0
var variant: int = 0
var id: int = 0
var tier: int = 0
var difficulty: int = 0

## Altitude de base du site de region le plus proche de *cet element*, quand
## elle est negative ; 0 sinon.
##
## Tracabilite : `World_baseHeightField` interroge
## `World_findNearestEntityInRegion` a la position de l'element et lit son
## altitude de base (+0x18). Si elle est negative, le terrain est *releve* de
## cette quantite autour de l'element : c'est ce qui fait emerger un ilot sous
## une structure tombee en pleine mer.
##
## La valeur ne depend que de la position de l'element, donc on la fige au
## placement plutot que de refaire un melange de sites par colonne.
var ocean_lift: float = 0.0


## Vrai si l'element modifie l'altitude. Permet a la colonne de sortir avant
## d'echantillonner la deformation du domaine, qui coute deux bruits.
func affects_height() -> bool:
	if ocean_lift < 0.0 and type != 0 and type != 0x0b:
		return true
	return (type == TYPE_TOWN or type == TYPE_CRATER or type == TYPE_CALDERA_A
			or type == TYPE_CALDERA_B or type == TYPE_SPIRE)


func _to_string() -> String:
	return "CWTileFeature(type=%d, pos=(%.1f, %.1f), r=%.1f, h=%.1f)" % [
			type, x, z, radius, height]
