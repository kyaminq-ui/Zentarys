"""Le personnage de reference : 4 modeles `.vox` sous
`assets/models/personnage/` — tete, torse, bras, jambe.

    python tools/blender/generer_personnage.py

Pur Python, comme la flore et les arbres depuis le jalon 1.12 : a des boites
et des colonnes pres, `bpy` n'apporterait rien qu'un decompte de voxels ne
fasse aussi bien.

-- Pourquoi quatre fichiers, et pas un seul ----------------------------------

`docs/ASSETS.md` §8.1 le disait depuis le 2026-09-10 : « a revoir au
jalon 3.1 », quand le controleur donnerait la taille reelle du personnage.
`CWPlayerController` (jalon 3.1, premiere tranche) l'a donnee — 2,4 blocs,
32 voxels a la grille fine — mais restait sans silhouette, en premiere
personne. Ce lot lui en donne une, et **articulee** : la tete, le torse et
chaque membre sont un fichier a part parce que `CWPlayerBody` les pose sous
des pivots distincts (nuque, hanches, epaules) pour l'animation procedurale de
la marche — un modele unique, lui, ne bouge qu'en bloc.

Un seul bras et une seule jambe sont dessines : `CWPlayerBody` pose l'autre
cote par symetrie de noeud, ce qu'aucune geometrie voxel ne peut faire
elle-meme sans dupliquer le fichier pour rien.

-- Le repere de chaque piece --------------------------------------------------

Chaque piece est dessinee **debout, pieds au sol** (z=0 en bas), comme
n'importe quel autre modele du depot — c'est `CWPlayerBody` qui la retourne
au moment de la poser, pour que son **pivot** (l'articulation) tombe au bon
endroit :

* la tete se pose telle quelle : son pivot est la nuque, en bas, exactement la
  convention d'ancrage de `CWVoxelModel` (centre du gabarit au sol) ;
* le torse aussi : son bas est la ceinture, qui est le pivot des hanches ;
* le bras et la jambe, eux, pendent d'une **epaule** ou d'une **hanche** —
  leur pivot est en **haut**, l'oppose de la convention d'ancrage. C'est
  `CWPlayerBody` qui compense, en reculant le modele de sa propre hauteur
  (`m.height / m.voxels_per_block`) avant de le poser sous le pivot :
  dessiner la piece a l'endroit reste plus lisible que la dessiner inversee.

-- La palette -----------------------------------------------------------------

Neuf index, et seulement ceux-la (`flore_vox.INDEX_PERSONNAGE`) : ce sont les
`CWPalette.PLAYER_*` ouverts pour ce personnage, voir la note au-dessus de ces
constantes dans `src/worldgen/cw_palette.gd`. Un personnage n'a pas plus le
droit a une teinte de feuillage qu'un filon n'a le droit au vert.

-- La grille --------------------------------------------------------------

40/3 voxels par bloc (`CWVoxelModel.VOXELS_PER_BLOCK`) : c'est la grille du
personnage, des creatures, du mobilier et des objets — jamais celle du
terrain. Hauteur totale visee, hors meches de cheveux : **32 voxels, 2,4
blocs**, la reference mesuree de `docs/ASSETS.md` §8.1. Les meches depassent
un peu au-dessus : une silhouette hirsute n'a pas a s'arreter pile a la cote
de reference, qui mesure un corps, pas une coiffure.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import flore_vox as fv
from flore_vox import Grille

SORTIE = os.path.join(fv.RACINE, "personnage")

# La palette du personnage de reference : voir `CWPalette.PLAYER_*` et la note
# au-dessus de ces constantes. Recopiees ici en dur, comme partout ailleurs
# dans ce dossier (`generer_filons.py` fait de meme pour `ORE_*`).
SKIN = 41
HAIR = 91
EYE = 92
TUNIC = 227
TUNIC_LIGHT = 226
BOOTS = 239
BELT = 96

# Enveloppe large et non contraignante : ce lot n'a que quatre pieces, dessinees
# une a une, et le vrai garde-fou est `INDEX_PERSONNAGE`. 40 voxels de haut
# (davantage que le corps de 32) laisse aux meches la place de depasser sans
# faire echouer `verifie` pour une pointe de cheveux.
PLAFOND = (40, 12)


## -- Le repere d'auteur, et pourquoi il ne se pose pas comme le fichier -------
##
## Les fonctions ci-dessous dessinent en **largeur** (x, gauche-droite),
## **profondeur** (y, positif = vers l'avant du personnage) et **hauteur**
## (z), l'ordre le plus lisible a la main. Deux corrections, verifiees en jeu
## et non devinees :
##
## 1. `VoxelVoxLoader` permute les axes en chargeant un `.vox` — `vox(x, y, z)
##    -> godot(y, z, x)`, voir `CWVoxelModel` — donc ecrire naivement
##    `g.pose(x, y, z, c)` fait ressortir la largeur d'auteur sur la
##    **profondeur** de Godot et la profondeur d'auteur sur sa **largeur** :
##    une piece large et peu profonde (le torse, 9 sur 5) devient etroite et
##    profonde. Vu en jeu le 2026-09-16 : le torse manquait a l'appel de face,
##    reduit a une tranche de 0,375 bloc.
## 2. Le personnage avance vers **-Z** (`CWPlayerController`, `-transform.
##    basis.z`), et la permutation ci-dessus envoie l'axe des profondeurs
##    d'auteur (Y) tel quel sur le Z de Godot, sans le retourner : un visage
##    peint en profondeur positive regarde donc vers **+Z**, l'arriere du
##    personnage — vu en jeu, les yeux regardaient dans le dos, si bien que
##    marcher en avant aurait fait reculer le personnage face a la camera.
##
## `_pose`/`_caisse` appliquent les deux corrections ici, une fois pour
## toutes ; le reste du fichier ne raisonne plus qu'en largeur/profondeur (+ =
## avant)/hauteur.
def _pose(g, x, y, z, c):
    g.pose(-y, x, z, c)


def _caisse(g, x0, x1, y0, y1, z0, z1, c):
    """Remplit un pave [x0, x1] x [y0, y1] x [z0, z1], bornes incluses, en
    coordonnees d'auteur (largeur, profondeur, hauteur)."""
    for z in range(z0, z1 + 1):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                _pose(g, x, y, z, c)


def construit_jambe():
    """Une jambe, pieds au sol : botte puis pantalon. Pivot a la hanche, en
    haut — `CWPlayerBody` la pose a l'envers de son ancrage naturel."""
    g = Grille()
    _caisse(g, -1, 1, -1, 1, 0, 2, BOOTS)     # botte
    _caisse(g, -1, 1, -1, 1, 3, 11, TUNIC)    # jambe de pantalon
    return g


def construit_torse():
    """Le torse : ceinture (avec boucle), tunique, liseret au col. Pivot aux
    hanches, en bas — l'ancrage naturel d'un modele qui tient debout."""
    g = Grille()
    _caisse(g, -4, 4, -2, 2, 0, 0, TUNIC)      # ceinture
    _pose(g, 0, 2, 0, BELT)                    # boucle, face avant
    _caisse(g, -4, 4, -2, 2, 1, 9, TUNIC)      # tunique
    _caisse(g, -1, 1, 2, 2, 7, 9, TUNIC_LIGHT)  # col, face avant
    return g


def construit_bras():
    """Un bras, poing au sol : epaulette, avant-bras nu, poing. Pivot a
    l'epaule, en haut — dessine a l'endroit, retourne par `CWPlayerBody`."""
    g = Grille()
    _caisse(g, -1, 1, -1, 1, 0, 1, SKIN)       # poing
    _caisse(g, -1, 0, -1, 0, 2, 7, SKIN)       # avant-bras, bras
    _caisse(g, -1, 1, -1, 1, 8, 8, TUNIC_LIGHT)  # epaulette
    return g


def construit_tete():
    """La tete : crane, calotte de cheveux, meches, yeux. Pivot a la nuque, en
    bas — l'ancrage naturel."""
    g = Grille()
    _caisse(g, -4, 4, -3, 4, 0, 6, SKIN)       # crane
    _caisse(g, -4, 4, -3, 4, 7, 8, HAIR)       # calotte

    # Meches : hirsutes, plus hautes vers l'avant, comme le modele de
    # reference. Chacune est une colonne etroite, plus simple qu'un cone et
    # suffisant a la grille fine (une meche fait 1 a 2 voxels de large).
    for x0, x1, y, haut in (
            (-3, -2, -2, 11), (-1, 0, 3, 14), (1, 2, -1, 13),
            (3, 4, 1, 11), (-1, 0, -3, 12)):
        _caisse(g, x0, x1, y, y, 9, haut, HAIR)

    # Yeux : un voxel chacun, face avant, comme la silhouette de gabarit
    # (`CWScaleBoard._build_figure`) le fait deja pour demontrer que la grille
    # fine suffit a un visage.
    _pose(g, -2, 4, 4, EYE)
    _pose(g, 2, 4, 4, EYE)
    return g


def main():
    bloc_rgba = fv.lit_bloc_rgba()
    print("Personnage -> %s" % SORTIE)
    pieces = (
        ("jambe", construit_jambe()),
        ("torse", construit_torse()),
        ("bras", construit_bras()),
        ("tete", construit_tete()),
    )
    for nom, grille in pieces:
        fv.ecris("personnage", nom, grille, bloc_rgba, racine=fv.RACINE,
                 plafond=PLAFOND, indices=fv.INDEX_PERSONNAGE)


if __name__ == "__main__":
    main()
