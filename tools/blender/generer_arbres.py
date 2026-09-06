"""Le lot d'arbres : 24 modeles `.vox` sous `assets/models/arbres/`.

    python tools/blender/generer_arbres.py

**Pur Python** depuis le jalon 1.12 : a un voxel par bloc, Blender n'apporte
rien — une metaballe echantillonnee a cette resolution rend un tas de cubes.
N'importe quel Python 3 fait l'affaire, celui de Blender aussi. C'est le meme
constat que pour les neuf filons, pour la meme raison.

Un modele par fonction, une graine en dur par modele : le lot se regenere a
l'identique. `--seul <nom>` ne refait qu'un fichier, pour iterer.

-- Ce lot remplace celui du 2026-09-05, et voici pourquoi -----------------

Six captures du jeu d'origine, mesurees le 2026-09-05 au soir, ont montre que
le premier lot d'arbres etait faux sur **trois** points a la fois
(`nextsteps.md`, Sec. 6.1 a 6.4) :

1. **l'echelle.** Les arbres de l'alpha font six a dix fois le personnage, soit
   15 a 25 blocs. Le `sapin` du premier lot en faisait 8,3 : deux a trois fois
   trop court ;
2. **la proportion des houppiers.** Ce sont des domes en parasol, de 10 a 18
   blocs de large et **plus larges que hauts**. Les notres faisaient 4,8 blocs
   de large, aussi hauts que larges — des boules ;
3. **le grain.** Les cubes de feuillage lisent a la taille des blocs de
   terrain. Le premier lot etait dessine a 3/40 de bloc par voxel, soit sept a
   treize fois trop fin.

Deux raisons de le croire au-dela de l'oeil, et la seconde est la plus forte.
La **provenance de l'echelle** : `0,075 = 3/40` est relevee dans la voie du
*decor* du binaire, et aucune echelle n'a jamais ete relevee dans la voie des
*entites*, par ou passent les arbres — le premier lot reposait donc sur une
extrapolation. L'**argument structurel** : la source ecrit le tronc d'un feuillu
dans le terrain, en colonnes de blocs, et instancie le houppier separement ; ces
deux moities ne se rejoignent proprement que si la grille du houppier est celle
du bloc. Un voxel = un bloc explique l'architecture de la source ; 3/40 la rend
impossible.

-- Les enveloppes -------------------------------------------------------------

En blocs, et `tests/tree_test.gd` les verrouille :

    arbre entier / fut      34 de haut, 12 de rayon
    houppier                12 de haut, 11 de rayon, et plus large que haut
    palme                    8 de haut, 10 de rayon

Le plafond de l'arbre geant est plus haut que celui des autres arbres : il porte
une mission dans l'alpha, il doit se voir de loin.
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import arbres_blocs as ab
import arbres_formes as af
import flore_vox as fv
from flore_vox import Grille, teinte

RACINE_ARBRES = os.path.join(fv.RACINE, "arbres")

# Plafonds par classe, en blocs — un voxel valant un bloc, ce sont aussi des
# voxels. Ils doublent ceux de `tests/tree_test.gd` : le generateur refuse a
# l'ecriture, le test refuse au chargement, et les deux disent le meme nombre.
PLAFOND_ARBRE = (34, 12)
PLAFOND_HOUPPIER = (12, 11)
PLAFOND_PALME = (8, 10)

# Index autorises pour un arbre : le feuillage et l'ecorce de la plage
# vegetation, la roche nue (pour la neige et le rocher geant), le gres et le
# basalte, plus les deux entrees de cactus. Pas de fleurs, pas de filons.
INDEX_ARBRES = frozenset(list(range(14, 32)) + list(range(128, 176)))


# =============================================================================
# greenlands/
# =============================================================================

def chene_tronc(g, rng):
    """Le fut du chene : trapu, deux blocs de section, douze de haut."""
    ab.colonne(g, rng, 12, 1.6, 1.0, 149, 153, penche=0.8)


def chene_houppier_01(g, rng):
    """Parasol large : quinze blocs pour sept de haut."""
    ab.houppier(g, rng, 15.0, 7.0, 128, 136, creux=2.0)


def chene_houppier_02(g, rng):
    """Le meme, plus petit et plus fonce : c'est lui qui coiffe la pile."""
    ab.houppier(g, rng, 12.0, 6.0, 130, 138, creux=1.0, bosses=0.3)


def bouleau_tronc(g, rng):
    """Le fut du bouleau : haut, mince, et **clair**.

    L'ecorce du bouleau est blanche, et la plage vegetation n'a rien de blanc :
    on prend le clair de la rampe de roche nue (14-15), comme la neige, et on y
    pose les marques sombres qui font reconnaitre l'arbre.

    **Son rayon passe de 1,0 a 1,4 le 2026-09-06.** `disque` garde ce dont la
    distance au centre ne depasse pas le rayon : a 1,0 le fut faisait cinq
    voxels au pied et **un seul** des le premier etage, parce que le rayon
    decroit vers 0,8. Un bouleau de quatorze blocs tenait donc sur un piquet
    d'un bloc, ce que la planche de validation a lu comme un houppier qui
    flotte. A 1,4 - 1,05, la section est une croix de cinq voxels sur toute la
    hauteur : trois blocs de large, un de moins que le chene.
    """
    centres = ab.colonne(g, rng, 14, 1.4, 1.05, 14, 16, penche=0.5)
    for (x, y, z) in centres:
        if z % 3 == 1:
            g.pose(x + rng.choice((-1, 0, 1)), y, z, 152)


def bouleau_houppier(g, rng):
    """Feuilles lime : le haut de la rampe de feuillage, le plus clair."""
    ab.houppier(g, rng, 11.0, 6.0, 128, 131, creux=1.0, bosses=0.3)


def pin(g, rng):
    """Le pin de Greenlands : vingt blocs, six plateaux."""
    ab.conifere(g, rng, 20.0, 5.0, 133, 139, etages=6, ecorce=(150, 154),
                fut_r=1.0)


def rocher_geant(g, rng):
    """Le Giant Rock : douze blocs de roche lichenee."""
    ab.rocher(g, rng, 11.0, 12.0, 15, 19)
    # Le lichen : la plage n'a que deux entrees, 28 clair et 29 sombre, donc il
    # se pose en taches et non en degrade.
    for (x, y, z), c in list(g.v.items()):
        if (x * 7 + y * 13 + z * 3) % 5 < 2 and z > 2:
            g.pose(x, y, z, 28 if z > 6 else 29)


def arbre_geant_tronc(g, rng):
    """Le fut de l'arbre geant : vingt-deux blocs, trois de section."""
    ab.colonne(g, rng, 22, 2.8, 1.6, 148, 153, penche=0.6)
    # Des contreforts au pied : c'est ce qui donne l'echelle d'en bas.
    for i in range(5):
        a = math.tau * i / 5 + rng.uniform(-0.3, 0.3)
        for k in range(3):
            g.pose(math.cos(a) * (2.5 + k * 0.8), math.sin(a) * (2.5 + k * 0.8),
                   2 - k, teinte(149, 154, 0.3 + 0.2 * k))


def arbre_geant_houppier(g, rng):
    """La couronne de l'arbre geant : vingt et un blocs de large."""
    ab.houppier(g, rng, 21.0, 9.0, 128, 137, creux=2.0, bosses=0.18)


# =============================================================================
# snowlands/
# =============================================================================

def pin_enneige(g, rng):
    """Le pin sous la neige : la meme pile de plateaux, blanchie au sommet."""
    ab.conifere(g, rng, 20.0, 5.2, 134, 139, etages=6, ecorce=(151, 155),
                fut_r=1.0)
    af.neige_dessus(g, rng, part=0.7, seuil_z=3)


def sapin_enneige(g, rng):
    """Plus court et plus serre que le pin : sept etages sur dix-sept blocs."""
    ab.conifere(g, rng, 17.0, 4.6, 135, 139, etages=7, ecorce=(152, 155),
                fut_r=0.9)
    af.neige_dessus(g, rng, part=0.85, seuil_z=2)


def bouleau_givre_tronc(g, rng):
    # Meme correction de section que `bouleau_tronc`.
    centres = ab.colonne(g, rng, 12, 1.4, 1.05, 14, 16, penche=0.4)
    for (x, y, z) in centres:
        if z % 3 == 2:
            g.pose(x + rng.choice((-1, 0, 1)), y, z, 153)


def bouleau_givre_houppier(g, rng):
    """Une couronne clairsemee et givree : l'arbre du froid garde peu de
    feuilles, et ce qui reste est pris dans le gel.

    Le feuillage est pris au **bas** de la rampe verte et non dans les oranges
    d'automne : vu en capture le 2026-09-06, un houppier orange sur un stipe
    blanc, au milieu d'une plaine de neige cyan, se lisait comme un champignon
    geant et non comme un arbre. C'est la meme regle que pour toute la flore de
    Snowlands — voir `generer_flore.herbe_gelee`.
    """
    ab.houppier(g, rng, 11.0, 7.0, 136, 139, creux=1.5, bosses=0.35)
    af.neige_dessus(g, rng, part=0.85, seuil_z=0)


# =============================================================================
# deserts/
# =============================================================================

def cactus_geant(g, rng):
    """Le saguaro a la maille du bloc : un fut et deux bras.

    C'est le seul « arbre » du desert hors oasis, et il n'est pas un arbre :
    il est range ici parce qu'il se pose par la couche des arbres — sa taille et
    son espacement sont ceux d'un arbre, pas ceux d'une touffe.
    """
    ab.colonne(g, rng, 10, 1.8, 1.4, 172, 175)
    a = rng.uniform(0.0, math.tau)
    # Les bras sortent sur **deux axes** et non sur un seul : alignes, ils
    # rendaient une plaque verte vue de face et rien du tout vue de cote.
    for s, z0, h in ((0.0, 3, 5), (math.pi, 5, 4),
                     (math.pi * 0.5, 4, 3)):
        for k in range(3):
            g.pose(math.cos(a + s) * (1 + k), math.sin(a + s) * (1 + k), z0,
                   teinte(172, 175, 0.4))
        for k in range(h):
            g.pose(math.cos(a + s) * 3, math.sin(a + s) * 3, z0 + k,
                   teinte(172, 175, 0.3 + 0.5 * k / h))


def palmier_tronc_desert(g, rng):
    """Le stipe du dattier : quatorze blocs, presque d'aplomb.

    L'ecorce et non la rampe d'automne : a 145-147 le stipe rendait un poteau
    rouge brique au milieu du sable, la ou un dattier est gris-brun.
    """
    ab.colonne(g, rng, 14, 1.2, 0.9, 150, 153, penche=1.2, derive=0.35)


def palme_desert(g, rng):
    ab.palme_paire(g, rng, 8.0, 133, 139)


def palme_diagonale_desert(g, rng):
    ab.palme_paire(g, rng, 8.0, 133, 139, diagonale=True)


# =============================================================================
# jungles/
# =============================================================================

def tropical_tronc(g, rng):
    """Le fut tropical : **base large**, comme le demande l'alpha.

    Treize blocs de haut sur quatre de section au pied, un et demi au sommet.
    C'est l'evasement qui le distingue du chene, pas la hauteur.
    """
    ab.colonne(g, rng, 13, 2.2, 1.0, 148, 152, penche=0.5)
    for i in range(6):
        a = math.tau * i / 6 + rng.uniform(-0.35, 0.35)
        for k in range(2):
            g.pose(math.cos(a) * (2.0 + k), math.sin(a) * (2.0 + k), 1 - k,
                   teinte(149, 153, 0.35 + 0.25 * k))


def tropical_houppier_01(g, rng):
    """La canopee : dix-sept blocs de large pour huit de haut."""
    ab.houppier(g, rng, 17.0, 8.0, 129, 137, creux=2.0, bosses=0.2)


def tropical_houppier_02(g, rng):
    ab.houppier(g, rng, 14.0, 7.0, 131, 138, creux=1.5, bosses=0.28)


def palmier_tronc(g, rng):
    ab.colonne(g, rng, 15, 1.2, 0.9, 149, 153, penche=1.4, derive=0.4)


def palme(g, rng):
    ab.palme_paire(g, rng, 9.0, 129, 136)


def palme_diagonale(g, rng):
    ab.palme_paire(g, rng, 9.0, 129, 136, diagonale=True)


# =============================================================================
# lavalands/
# =============================================================================

def arbre_epineux(g, rng):
    """Le Thorn Tree : « rare, pas de drop ».

    La boite relevee dans la source est de **3 x 3 x 12 blocs**
    (`docs/systems/02`, Sec. 5.2), et a un voxel par bloc elle se lit
    directement comme un gabarit — c'est le seul modele du lot dont la source
    donne les dimensions, et c'est aussi celui qui a fait douter le plus
    longtemps de la grille.
    """
    # Le fut garde une section de cinq voxels jusqu'en haut, et les branches
    # sont doublees a leur naissance : a 1,2 - 0,7 et a une branche d'un voxel,
    # la planche du 2026-09-06 ne montrait qu'une poignee de cubes en l'air.
    ab.colonne(g, rng, 12, 1.4, 1.05, 153, 155, penche=0.6)
    for z in (4, 7, 10):
        bouts = ab.branches(g, rng, (0, 0, z), 3, 3.0, 154, 155,
                            montee=0.35, ouverture=1.25, epaisse=2)
        # Les epines : un bloc plus clair au bout de chaque branche. Un arbre
        # a epines sans pointes est un arbre mort.
        for (x, y, zz) in bouts:
            g.pose(x, y, zz + 1, 152)


# =============================================================================
# Le lot
# =============================================================================

# (dossier, nom, graine, fonction, plafond[, souder]).
#
# `souder` rattache les morceaux detaches (`flore_vox.Grille.soude`) et vaut
# vrai par defaut. Les quatre palmes sont les seules a passer faux : une palme
# est une **paire de frondes opposees** passant par son ancre (jalon 1.12), donc
# deux morceaux par construction, et ce qui les tient est le stipe du palmier —
# qui n'est pas dans leur fichier. Les souder poserait une barre en travers du
# tronc.
LOT = [
    ("greenlands", "chene_tronc", 1101, chene_tronc, PLAFOND_ARBRE),
    ("greenlands", "chene_houppier_01", 1102, chene_houppier_01, PLAFOND_HOUPPIER),
    ("greenlands", "chene_houppier_02", 1103, chene_houppier_02, PLAFOND_HOUPPIER),
    ("greenlands", "bouleau_tronc", 1104, bouleau_tronc, PLAFOND_ARBRE),
    ("greenlands", "bouleau_houppier", 1105, bouleau_houppier, PLAFOND_HOUPPIER),
    ("greenlands", "pin", 1106, pin, PLAFOND_ARBRE),
    ("greenlands", "rocher_geant", 1107, rocher_geant, PLAFOND_ARBRE),
    ("greenlands", "arbre_geant_tronc", 1108, arbre_geant_tronc, PLAFOND_ARBRE),
    ("greenlands", "arbre_geant_houppier", 1109, arbre_geant_houppier,
     PLAFOND_HOUPPIER),

    ("snowlands", "pin_enneige", 2101, pin_enneige, PLAFOND_ARBRE),
    ("snowlands", "sapin_enneige", 2102, sapin_enneige, PLAFOND_ARBRE),
    ("snowlands", "bouleau_givre_tronc", 2103, bouleau_givre_tronc, PLAFOND_ARBRE),
    ("snowlands", "bouleau_givre_houppier", 2104, bouleau_givre_houppier,
     PLAFOND_HOUPPIER),

    ("deserts", "cactus_geant", 5101, cactus_geant, PLAFOND_ARBRE),
    ("deserts", "palmier_tronc", 5102, palmier_tronc_desert, PLAFOND_ARBRE),
    ("deserts", "palme", 5103, palme_desert, PLAFOND_PALME, False),
    ("deserts", "palme_diagonale", 5104, palme_diagonale_desert, PLAFOND_PALME, False),

    ("jungles", "tropical_tronc", 3101, tropical_tronc, PLAFOND_ARBRE),
    ("jungles", "tropical_houppier_01", 3102, tropical_houppier_01, PLAFOND_HOUPPIER),
    ("jungles", "tropical_houppier_02", 3103, tropical_houppier_02, PLAFOND_HOUPPIER),
    ("jungles", "palmier_tronc", 3104, palmier_tronc, PLAFOND_ARBRE),
    ("jungles", "palme", 3105, palme, PLAFOND_PALME, False),
    ("jungles", "palme_diagonale", 3106, palme_diagonale, PLAFOND_PALME, False),

    ("lavalands", "arbre_epineux", 6101, arbre_epineux, PLAFOND_ARBRE),
]


def main(argv):
    seul = None
    if "--seul" in argv:
        seul = argv[argv.index("--seul") + 1]
    bloc = fv.lit_bloc_rgba()
    dossier_courant = None
    fait = 0
    for entree in LOT:
        dossier, nom, graine, f, plafond = entree[:5]
        souder = entree[5] if len(entree) > 5 else True
        if seul is not None and seul not in (nom, "%s/%s" % (dossier, nom)):
            continue
        if dossier != dossier_courant:
            print("[%s/]" % dossier)
            dossier_courant = dossier
        g = Grille()
        f(g, random.Random(graine))
        fv.ecris(dossier, nom, g, bloc, racine=RACINE_ARBRES, plafond=plafond,
                 indices=INDEX_ARBRES, souder=souder)
        fait += 1
    print("%d modele(s) ecrit(s) dans %s" % (fait, RACINE_ARBRES))


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    main(argv)
