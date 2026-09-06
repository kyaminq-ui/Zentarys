"""Le lot d'ouvrages : les travees de pont de Zentarys (jalon 1.16).

Pur Python, comme les arbres et les filons : a cette maille, Blender n'apporte
rien.

    python tools/blender/generer_ponts.py

-- Pourquoi ce lot existe, et pourquoi a six voxels par bloc ------------------

Le tablier d'un pont est ecrit dans le terrain : c'est de la matiere, elle se
creuse, elle portera la collision. Mais un tablier de matiere est fait de blocs
d'un metre, et un ouvrage d'art fait de blocs d'un metre n'est pas un ouvrage
d'art, c'est une planche posee sur l'eau. Demande du 2026-09-08 : *redessine les
ponts a six voxels par bloc pour plus de details*.

Six voxels par bloc, c'est la grille des petits props de la flore
(`CWVoxelModel.VOXELS_PER_BLOCK_FLORE_FINE`), et c'est la plus fine du projet.
A cette maille, un garde-corps a une section, un poteau a un chapeau, et un
platelage a des planches qu'on distingue.

**Le partage est donc le meme que celui des arbres depuis le jalon 1.11** : la
matiere d'un cote, le detail de l'autre. Le tablier de blocs reste le sol sur
lequel on marche et qu'on peut abattre ; la travee de ce lot vient par-dessus,
instanciee, et ne porte ni collision ni edition. Ce qu'on gagne est un ouvrage
qui se regarde ; ce qu'on perd est deja perdu pour tout ce qui est instancie.

-- Une seule piece, et pourquoi ---------------------------------------------

Un pont est une suite de travees identiques posees le long d'une courbe. Une
piece unique, longue de deux blocs et posee tous les 1,5 bloc, se recouvre
d'un demi-bloc a chaque fois : les travees se soudent visuellement quel que
soit l'angle, et il n'y a ni trou dans les diagonales ni piece speciale aux
extremites. C'est la meme idee que le chevauchement des houppiers d'un feuillu.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import flore_vox as fv

# Six voxels par bloc : la grille fine du projet.
VPB = 6

# Largeur de la chaussee, en blocs — `CWPathNetwork.HALF_WIDTH x 2`. La travee
# est un peu plus large : ses garde-corps se posent **au bord** du tablier, pas
# dessus.
DEMI_LARGEUR = 4.5
LONGUEUR = 2.0          # longueur d'une travee, en blocs

# Plages autorisees pour un ouvrage. Les planches (176-187) et la pierre taillee
# (188-199) sont exactement ce que la palette reserve a la construction ; on y
# ajoute l'ecorce (148-155) pour les pieces de bois brut. Rien d'autre : un pont
# n'a pas le droit au feuillage, et le garde-fou de `flore_vox.verifie` est la
# pour ca.
INDEX_OUVRAGE = frozenset(list(range(148, 156)) + list(range(176, 200)))

# Un ouvrage n'est pas une plante : son plafond de gabarit lui est propre.
PLAFOND = (64, 40)

# Rampes employees. `fv.teinte(clair, sombre, f)` va du sombre (f = 0) au clair.
PLANCHE_CLAIR, PLANCHE_SOMBRE = 176, 187
PIERRE_CLAIR, PIERRE_SOMBRE = 188, 199

# -- Une seule teinte de bois (2026-09-09) -----------------------------------
#
# La premiere travee employait **neuf index** de la rampe des planches plus un
# de pierre pour les chapeaux de poteau. A six voxels par bloc, une planche fait
# trois voxels de large : neuf teintes reparties la-dessus ne se lisent pas
# comme du bois, elles se lisent comme du bruit — et le reproche du 2026-09-08
# le dit sans detour.
#
# Un seul index, donc, **et la forme fait le reste** :
#
#   * le joint entre deux planches etait une teinte plus sombre ; c'est
#     maintenant une **rainure** — le voxel du dessus manque. A un sixieme de
#     bloc elle est fine, mais elle porte une ombre, ce qu'une teinte ne fait
#     pas ;
#   * le chapeau d'un poteau etait de la pierre ; il **deborde** deja d'un voxel
#     de chaque cote, et c'est ce debord qui le designe. La pierre ne lui
#     apprenait rien.
#
# La note precedente objectait que creuser le joint le ferait disparaitre au
# premier pas de recul. C'est vrai, et c'est le but : de pres on voit des
# planches, de loin on voit un tablier. Neuf teintes, elles, se voyaient de
# loin — comme du grain.
BOIS = fv.teinte(PLANCHE_CLAIR, PLANCHE_SOMBRE, 0.62)


def travee(graine=0):
    """Une travee : platelage, longerons, deux garde-corps, deux poteaux.

    Les coordonnees sont en voxels, Z vers le haut, origine au coin. `x` est la
    largeur (en travers de la chaussee), `y` la longueur (dans l'axe).
    """
    g = fv.Grille()
    larg = int(round(DEMI_LARGEUR * 2.0 * VPB))     # 54 voxels
    lon = int(round(LONGUEUR * VPB))                # 12 voxels

    # -- Le platelage : deux voxels d'epaisseur, planches dans l'axe ----------
    #
    # Une planche fait trois voxels de large, un demi-bloc. Le joint est une
    # **rainure** et non une teinte : le voxel du dessus manque. Voir `BOIS`.
    #
    # Les deux bords du tablier n'en portent pas — une rainure au ras du vide
    # ferait un tablier qui s'effrite, pas une planche.
    for x in range(larg):
        joint = (x % 3) == 0 and 0 < x < larg - 1
        for y in range(lon):
            for z in range(2 if not joint else 1):
                g.pose(x, y, z, BOIS)

    # -- Les deux longerons, sous le platelage -------------------------------
    for cote in (0, 1):
        x0 = 2 if cote == 0 else larg - 6
        for x in range(x0, x0 + 4):
            for y in range(lon):
                g.pose(x, y, -1, BOIS)

    # -- Les garde-corps -----------------------------------------------------
    #
    # Un poteau tous les deux blocs — donc un par travee et par cote —, une
    # lisse haute et une lisse basse. La lisse court sur toute la longueur : ce
    # sont elles qui se soudent d'une travee a l'autre.
    haut = int(round(1.15 * VPB))       # 7 voxels : hauteur d'appui
    for cote in (0, 1):
        x0 = 0 if cote == 0 else larg - 2
        # Le poteau, au tiers de la travee pour que deux travees voisines n'en
        # posent pas deux cote a cote.
        py = lon // 3
        for x in range(x0, x0 + 2):
            for y in range(py, py + 2):
                for z in range(2, haut + 2):
                    g.pose(x, y, z, BOIS)
        # Le chapeau du poteau deborde d'un voxel de chaque cote.
        for x in range(x0 - 1, x0 + 3):
            for y in range(py - 1, py + 3):
                g.pose(x, y, haut + 2, BOIS)
        # Les deux lisses.
        for z in (haut, haut - 3):
            for x in range(x0, x0 + 2):
                for y in range(lon):
                    g.pose(x, y, z, BOIS)
    return g


def main():
    bloc = fv.lit_bloc_rgba()
    racine = os.path.join(fv.RACINE, "structures")
    print("lot d'ouvrages, %d voxels par bloc" % VPB)
    fv.ecris("", "pont_travee", travee(), bloc, racine=racine,
             plafond=PLAFOND, indices=INDEX_OUVRAGE, souder=False)


if __name__ == "__main__":
    main()
