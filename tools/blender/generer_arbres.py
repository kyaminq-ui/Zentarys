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

-- Les dix grands arbres (2026-09-06) -----------------------------------------

Deux par biome arbore, en plus des especes existantes. Ce sont des **grands
arbres** au sens du montage : un fut haut, quatre branches, et un houppier au
bout de chacune plus un a la cime — une envergure au lieu d'une hauteur.

Ils tiennent le lot par ce qui lui manquait : **la couleur**. Douze des vingt-
quatre modeles precedents puisent dans la seule rampe de feuillage (128-139), et
une foret de Greenlands n'avait qu'une teinte. Les nouveaux prennent l'automne
(140-147), les quatre couples de fleurs (156-163), la rampe des champignons et
mousses (164-169), la roche nue pour le givre (14-19) et le basalte pour la
cendre (25-27). Aucune entree nouvelle dans la palette : la variete etait deja
la, elle n'etait pas employee.

**Une seule interdiction, et elle est un invariant** : aucune plante de
Snowlands ne prend 140-147 (n. 29). Un orange chaud sur un sol de neige cyan
ressort comme une tache, et le defaut est deja revenu deux fois. Les deux
grands arbres de Snowlands prennent donc le blanc-bleu de la roche nue et le
violet des fleurs, qui sont froids.

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
# **Portes de 40 % le 2026-09-06** avec le lot lui-meme : les arbres restaient
# petits contre ceux du jeu d'origine, releve a l'oeil sur des captures. Un
# plafond n'est pas une taille visee, c'est une borne — mais une borne qui ne
# laisse pas passer la taille visee est un plafond faux.
PLAFOND_ARBRE = (48, 18)
PLAFOND_HOUPPIER = (20, 17)
PLAFOND_PALME = (12, 16)
# Une charpente porte ses branches : son rayon est celui de sa portee, pas celui
# de son fut. Sa hauteur reste sous celle d'un arbre entier.
PLAFOND_CHARPENTE = (48, 18)

# Les bouts de branche de chaque grand arbre, **en coordonnees Godot** et avant
# rotation : (dx, dz, dy), en blocs depuis la colonne du tronc et depuis sa base.
#
# **Cette table et `CWTreeRules.SPECIES` doivent dire la meme chose**, et c'est
# le meme genre d'accord que celui de `GRILLE_FINE` entre le catalogue de flore
# et `CWModelLibrary` : le generateur dessine la branche a l'endroit qu'il croit,
# le moteur y pose le houppier a l'endroit qu'il lit de son cote. La difference,
# et elle est confortable, c'est que la divergence se **verifie directement** :
# `tests/tree_test.gd` charge le modele et regarde s'il y a du bois au bout
# declare. Une branche deplacee d'un cote seulement fait tomber la verification.
#
# Quatre branches aux quatre points cardinaux : ce sont les seules directions
# qu'un quart de tour envoie l'une sur l'autre, donc les seules qui gardent la
# meme silhouette aux quatre rotations que le mailleur precalcule. Les hauteurs,
# elles, different d'une branche a l'autre — sans quoi les quatre houppiers
# formeraient un disque.
# **La portee est de huit a dix blocs, et les domes font neuf de large.** Le
# premier reglage — branches a cinq ou sept, domes a onze ou treize — a donne
# des arbres corrects et faux : les cinq masses se recouvraient presque
# entierement et l'arbre se lisait comme **un seul** parasol, ce qui est
# exactement la silhouette d'un feuillu. Ce qui distingue un grand arbre est
# qu'on **compte ses masses** ; il faut donc que la portee depasse le rayon du
# dome, pas qu'elle l'egale.
#
# Le second reglage a corrige l'ecartement et laisse un dome de **trois blocs
# d'epaisseur pour dix de large** : cinq galettes, pas cinq spheres aplaties.
# `houppier` rend a peu pres la moitie de la hauteur demandee — son profil se
# ferme avant le sommet —, donc 6,5 pour cinq blocs. Un rapport de deux entre
# largeur et hauteur est ce qui se lit comme une masse ; a trois pour un, c'est
# un plateau.
BRANCHES_GRANDES = [(13, 0, 21), (-11, 0, 18), (0, 13, 24), (0, -11, 20)]
BRANCHES_LARGES = [(14, 0, 17), (-14, 0, 20), (0, 13, 15), (0, -13, 18)]
BRANCHES_HAUTES = [(11, 0, 27), (-11, 0, 24), (0, 11, 29), (0, -10, 25)]

# Index autorises pour un arbre : le feuillage et l'ecorce de la plage
# vegetation, la roche nue (pour la neige et le rocher geant), le gres et le
# basalte, plus les deux entrees de cactus. Pas de fleurs, pas de filons.
# Les fleurs (156-163) entrent dans cette plage depuis les dix grands arbres :
# un houppier de cerisier ou de jacaranda n'est pas du feuillage vert, et la
# palette n'a pas d'autre rose ni d'autre violet. La plage reste celle de la
# vegetation, aucune entree n'est ajoutee.
INDEX_ARBRES = frozenset(list(range(14, 32)) + list(range(128, 176)))


# =============================================================================
# greenlands/
# =============================================================================

def chene_tronc(g, rng):
    """Le fut du chene : trapu, deux blocs de section, douze de haut."""
    ab.colonne(g, rng, 17, 2.2, 1.4, 149, 153, penche=0.8)


def chene_houppier_01(g, rng):
    """Parasol large : quinze blocs pour sept de haut."""
    ab.houppier(g, rng, 21.0, 9.8, 128, 136, creux=2.0)


def chene_houppier_02(g, rng):
    """Le meme, plus petit et plus fonce : c'est lui qui coiffe la pile."""
    ab.houppier(g, rng, 16.8, 8.4, 130, 138, creux=1.0, bosses=0.3)


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
    centres = ab.colonne(g, rng, 20, 2.0, 1.5, 14, 16, penche=0.5)
    for (x, y, z) in centres:
        if z % 3 == 1:
            g.pose(x + rng.choice((-1, 0, 1)), y, z, 152)


def bouleau_houppier(g, rng):
    """Feuilles lime : le haut de la rampe de feuillage, le plus clair."""
    ab.houppier(g, rng, 15.4, 8.4, 128, 131, creux=1.0, bosses=0.3)


def pin(g, rng):
    """Le pin de Greenlands : vingt blocs, six plateaux."""
    ab.conifere(g, rng, 28.0, 7.0, 133, 139, etages=6, ecorce=(150, 154),
                fut_r=1.4)


def rocher_geant(g, rng):
    """Le Giant Rock : douze blocs de roche lichenee."""
    ab.rocher(g, rng, 15.4, 16.8, 15, 19)
    # Le lichen : la plage n'a que deux entrees, 28 clair et 29 sombre, donc il
    # se pose en taches et non en degrade.
    for (x, y, z), c in list(g.v.items()):
        if (x * 7 + y * 13 + z * 3) % 5 < 2 and z > 2:
            g.pose(x, y, z, 28 if z > 6 else 29)


def arbre_geant_tronc(g, rng):
    """Le fut de l'arbre geant : vingt-deux blocs, trois de section."""
    ab.colonne(g, rng, 31, 3.9, 2.2, 148, 153, penche=0.6)
    # Des contreforts au pied : c'est ce qui donne l'echelle d'en bas.
    for i in range(5):
        a = math.tau * i / 5 + rng.uniform(-0.3, 0.3)
        for k in range(3):
            g.pose(math.cos(a) * (2.5 + k * 0.8), math.sin(a) * (2.5 + k * 0.8),
                   2 - k, teinte(149, 154, 0.3 + 0.2 * k))


def arbre_geant_houppier(g, rng):
    """La couronne de l'arbre geant : vingt et un blocs de large."""
    ab.houppier(g, rng, 29.4, 12.6, 128, 137, creux=2.0, bosses=0.18)


# =============================================================================
# snowlands/
# =============================================================================

def pin_enneige(g, rng):
    """Le pin sous la neige : la meme pile de plateaux, blanchie au sommet."""
    ab.conifere(g, rng, 28.0, 7.3, 134, 139, etages=6, ecorce=(151, 155),
                fut_r=1.4)
    af.neige_dessus(g, rng, part=0.7, seuil_z=3)


def sapin_enneige(g, rng):
    """Plus court et plus serre que le pin : sept etages sur dix-sept blocs."""
    ab.conifere(g, rng, 23.8, 6.4, 135, 139, etages=7, ecorce=(152, 155),
                fut_r=1.3)
    af.neige_dessus(g, rng, part=0.85, seuil_z=2)


def bouleau_givre_tronc(g, rng):
    # Meme correction de section que `bouleau_tronc`.
    centres = ab.colonne(g, rng, 17, 2.0, 1.5, 14, 16, penche=0.4)
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
    ab.houppier(g, rng, 15.4, 9.8, 136, 139, creux=1.5, bosses=0.35)
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
    ab.colonne(g, rng, 14, 2.5, 2.0, 172, 175)
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
    ab.colonne(g, rng, 20, 1.7, 1.3, 150, 153, penche=1.2, derive=0.35)


def palme_desert(g, rng):
    ab.palme_paire(g, rng, 11.2, 133, 139)


def palme_diagonale_desert(g, rng):
    ab.palme_paire(g, rng, 11.2, 133, 139, diagonale=True)


# =============================================================================
# jungles/
# =============================================================================

def tropical_tronc(g, rng):
    """Le fut tropical : **base large**, comme le demande l'alpha.

    Treize blocs de haut sur quatre de section au pied, un et demi au sommet.
    C'est l'evasement qui le distingue du chene, pas la hauteur.
    """
    ab.colonne(g, rng, 18, 3.1, 1.4, 148, 152, penche=0.5)
    for i in range(6):
        a = math.tau * i / 6 + rng.uniform(-0.35, 0.35)
        for k in range(2):
            g.pose(math.cos(a) * (2.0 + k), math.sin(a) * (2.0 + k), 1 - k,
                   teinte(149, 153, 0.35 + 0.25 * k))


def tropical_houppier_01(g, rng):
    """La canopee : dix-sept blocs de large pour huit de haut."""
    ab.houppier(g, rng, 23.8, 11.2, 129, 137, creux=2.0, bosses=0.2)


def tropical_houppier_02(g, rng):
    ab.houppier(g, rng, 19.6, 9.8, 131, 138, creux=1.5, bosses=0.28)


def palmier_tronc(g, rng):
    ab.colonne(g, rng, 21, 1.7, 1.3, 149, 153, penche=1.4, derive=0.4)


def palme(g, rng):
    ab.palme_paire(g, rng, 12.6, 129, 136)


def palme_diagonale(g, rng):
    ab.palme_paire(g, rng, 12.6, 129, 136, diagonale=True)


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
    ab.colonne(g, rng, 17, 2.0, 1.5, 153, 155, penche=0.6)
    for z in (6, 10, 14):
        bouts = ab.branches(g, rng, (0, 0, z), 3, 3.0, 154, 155,
                            montee=0.35, ouverture=1.25, epaisse=2)
        # Les epines : un bloc plus clair au bout de chaque branche. Un arbre
        # a epines sans pointes est un arbre mort.
        for (x, y, zz) in bouts:
            g.pose(x, y, zz + 1, 152)


# =============================================================================
# Les dix grands arbres. Deux par biome arbore, hors du vert.
# =============================================================================

def erable_charpente(g, rng):
    """L'erable de Greenlands : un fut clair et quatre branches portantes."""
    ab.charpente(g, rng, 24, 2.5, 1.7, 149, 152, BRANCHES_GRANDES, penche=0.5)


def erable_dome(g, rng):
    """Le houppier d'automne : or au-dessus, rouille en dessous."""
    ab.houppier(g, rng, 14.0, 9.1, 140, 146, creux=1.0, bosses=0.28)


def cerisier_charpente(g, rng):
    """Le cerisier : plus bas, plus etale, une ecorce sombre."""
    ab.charpente(g, rng, 20, 2.2, 1.5, 151, 154, BRANCHES_LARGES, penche=0.6)


def cerisier_dome(g, rng):
    """Un dome de fleurs : rose clair dessus, rose soutenu dessous.

    Les deux entrees 156 et 157 sont un couple de fleur, pas une rampe : le
    degrade de `houppier` n'a donc que deux marches, ce qui suffit — une masse
    rose a la taille du bloc se lit a sa couleur, pas a son modele.
    """
    ab.houppier(g, rng, 14.0, 9.1, 157, 156, creux=1.0, bosses=0.32)


def saule_givre_charpente(g, rng):
    """Snowlands : un fut pale, des branches basses et larges."""
    ab.charpente(g, rng, 21, 2.4, 1.5, 14, 17, BRANCHES_LARGES, penche=0.4)


def saule_givre_dome(g, rng):
    """Un dome de givre : blanc bleute, froid. Jamais l'automne (invariant 29)."""
    ab.houppier(g, rng, 14.0, 9.1, 14, 18, creux=1.0, bosses=0.3)
    af.neige_dessus(g, rng, part=0.5, seuil_z=1)


def arbre_pourpre_charpente(g, rng):
    """Snowlands : l'arbre a baies du froid, ecorce sombre."""
    ab.charpente(g, rng, 22, 2.2, 1.5, 152, 155, BRANCHES_GRANDES, penche=0.5)


def arbre_pourpre_dome(g, rng):
    """Violet : froid comme le biome, et la seule autre couleur qu'il accepte."""
    ab.houppier(g, rng, 14.0, 9.1, 163, 162, creux=1.0, bosses=0.3)


def acacia_charpente(g, rng):
    """Deserts : un fut nu et haut, des branches qui montent tard."""
    ab.charpente(g, rng, 25, 2.1, 1.4, 148, 152, BRANCHES_HAUTES, penche=0.7)


def acacia_dome(g, rng):
    """Le parasol d'acacia : **tres** plat, doré-olive, et c'est sa signature."""
    ab.houppier(g, rng, 14.0, 9.1, 141, 145, creux=1.0, bosses=0.24)


def baobab_charpente(g, rng):
    """Deserts : un tronc massif, court, et quatre branches trapues."""
    ab.charpente(g, rng, 18, 3.6, 2.2, 149, 153, BRANCHES_LARGES, penche=0.3)


def baobab_dome(g, rng):
    """Une masse claire et seche : la rampe des mousses, terre cuite a olive."""
    ab.houppier(g, rng, 14.0, 9.1, 164, 168, creux=1.0, bosses=0.35)


def flamboyant_charpente(g, rng):
    """Jungles : haut, droit, l'ecorce claire des arbres tropicaux."""
    ab.charpente(g, rng, 27, 2.5, 1.7, 148, 151, BRANCHES_HAUTES, penche=0.5)


def flamboyant_dome(g, rng):
    """Rouge franc : c'est l'arbre qu'on voit d'un bout a l'autre d'une clairiere."""
    ab.houppier(g, rng, 14.0, 9.1, 157, 156, creux=1.0, bosses=0.3)


def jacaranda_charpente(g, rng):
    """Jungles : un peu plus bas que le flamboyant, plus etale."""
    ab.charpente(g, rng, 24, 2.4, 1.5, 149, 152, BRANCHES_GRANDES, penche=0.6)


def jacaranda_dome(g, rng):
    """Violet clair sur violet soutenu."""
    ab.houppier(g, rng, 14.0, 9.1, 163, 162, creux=1.0, bosses=0.3)


def arbre_de_cendre_charpente(g, rng):
    """Lava Lands : un fut de basalte, mort et dur."""
    ab.charpente(g, rng, 21, 2.4, 1.5, 153, 155, BRANCHES_GRANDES, penche=0.8)


def arbre_de_cendre_dome(g, rng):
    """Une masse de cendre parcourue de braises.

    Les braises sont posees **sur la peau** du dome et non dedans : c'est la
    lecon du 2026-09-06 sur le buisson de feu, ou cinq braises tirees dans la
    masse etaient cinq voxels perdus.
    """
    ab.houppier(g, rng, 14.0, 9.1, 25, 27, creux=1.0, bosses=0.35)
    _braises(g, rng, 14, 30)


def arbre_de_braise_charpente(g, rng):
    """Lava Lands : plus haut, plus mince, presque un cierge."""
    ab.charpente(g, rng, 25, 2.1, 1.4, 152, 155, BRANCHES_HAUTES, penche=0.6)


def arbre_de_braise_dome(g, rng):
    """Un dome de feuillage incandescent : la rampe d'automne, ici a sa place."""
    ab.houppier(g, rng, 14.0, 9.1, 140, 145, creux=1.0, bosses=0.3)
    _braises(g, rng, 8, 30)


def _braises(g, rng, combien, index):
    """Repeint quelques voxels de **surface** en braise.

    Meme role que `flore_blocs.semis`, refait ici parce que celui-la travaille
    sur la grille de la flore. La liste des candidats est **triee** avant le
    tirage : sans cela l'ordre d'un dictionnaire deciderait du resultat, et le
    lot ne se regenererait plus a l'identique.
    """
    peau = []
    for (x, y, z) in g.v:
        for dx, dy, dz in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0),
                           (0, 0, 1), (0, 0, -1)):
            if (x + dx, y + dy, z + dz) not in g.v:
                peau.append((x, y, z))
                break
    peau.sort()
    if not peau:
        return
    for p in rng.sample(peau, min(combien, len(peau))):
        g.v[p] = index


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

    # -- Les dix grands arbres, deux par biome arbore --
    ("greenlands", "erable_charpente", 1201, erable_charpente, PLAFOND_CHARPENTE),
    ("greenlands", "erable_dome", 1202, erable_dome, PLAFOND_HOUPPIER),
    ("greenlands", "cerisier_charpente", 1203, cerisier_charpente, PLAFOND_CHARPENTE),
    ("greenlands", "cerisier_dome", 1204, cerisier_dome, PLAFOND_HOUPPIER),

    ("snowlands", "saule_givre_charpente", 2201, saule_givre_charpente,
     PLAFOND_CHARPENTE),
    ("snowlands", "saule_givre_dome", 2202, saule_givre_dome, PLAFOND_HOUPPIER),
    ("snowlands", "arbre_pourpre_charpente", 2203, arbre_pourpre_charpente,
     PLAFOND_CHARPENTE),
    ("snowlands", "arbre_pourpre_dome", 2204, arbre_pourpre_dome, PLAFOND_HOUPPIER),

    ("deserts", "acacia_charpente", 5201, acacia_charpente, PLAFOND_CHARPENTE),
    ("deserts", "acacia_dome", 5202, acacia_dome, PLAFOND_HOUPPIER),
    ("deserts", "baobab_charpente", 5203, baobab_charpente, PLAFOND_CHARPENTE),
    ("deserts", "baobab_dome", 5204, baobab_dome, PLAFOND_HOUPPIER),

    ("jungles", "flamboyant_charpente", 3201, flamboyant_charpente,
     PLAFOND_CHARPENTE),
    ("jungles", "flamboyant_dome", 3202, flamboyant_dome, PLAFOND_HOUPPIER),
    ("jungles", "jacaranda_charpente", 3203, jacaranda_charpente,
     PLAFOND_CHARPENTE),
    ("jungles", "jacaranda_dome", 3204, jacaranda_dome, PLAFOND_HOUPPIER),

    ("lavalands", "arbre_de_cendre_charpente", 6201, arbre_de_cendre_charpente,
     PLAFOND_CHARPENTE),
    ("lavalands", "arbre_de_cendre_dome", 6202, arbre_de_cendre_dome,
     PLAFOND_HOUPPIER),
    ("lavalands", "arbre_de_braise_charpente", 6203, arbre_de_braise_charpente,
     PLAFOND_CHARPENTE),
    ("lavalands", "arbre_de_braise_dome", 6204, arbre_de_braise_dome,
     PLAFOND_HOUPPIER),
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
