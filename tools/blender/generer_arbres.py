"""Le lot d'arbres : 14 modeles `.vox` sous `assets/models/arbres/`.

    blender --background --factory-startup --python tools/blender/generer_arbres.py

Un modele par fonction, une graine en dur par modele : le lot se regenere a
l'identique. `-- --seul <nom>` ne refait qu'un fichier, pour iterer.

Meme chemin que `generer_flore.py`, dont il reemploie les modules : l'ecrivain
`.vox` et les garde-fous d'index (`flore_vox`), les primitives generiques
(`flore_formes`), la courbe a rayon variable et les metaballes
(`flore_blender`). Ce qui est propre aux arbres est dans `arbres_formes`.

Ce qui change par rapport a la flore, et rien d'autre
(`docs/prompt_generation_arbres.md`, Sec. 1) :

* **l'enveloppe.** La flore tient sous 53 voxels ; un arbre n'y tient pas. La
  source donne la mesure : la boite de `thorn-tree` est de 3 x 3 x 12 blocs,
  soit 160 voxels de haut. `flore_vox.ecris` recoit donc un plafond par classe
  — arbre entier, houppier, palme — au lieu de celui de la flore.
* **deux sortes d'objets.** Un **arbre entier** commence sa matiere en Z = 0,
  comme une plante. Un **houppier** est une couronne **sans pied** : sa base
  vient se poser sur le sommet d'un tronc de blocs, et lui dessiner un tronc le
  ferait flotter ou doubler celui du terrain. Une **palme** est une fronde
  seule, pas un palmier.
* **le fut est plein**, et c'est la seule matiere massive du lot : 2 a 4 voxels
  de section a la base. Tout le reste — frondaisons, rameaux, folioles — reste
  une coquille ou une lame d'un voxel.

L'echelle ne bouge pas : 1 bloc de terrain = 40/3 voxels, personnage de
reference a 32 voxels. Les index restent contraints aux plages vegetation
(128-175) et terrain (1-11, 14-31), et `flore_vox.verifie` refuse le reste a
l'ecriture.

**Ce que ce script verifie et que la suite de tests ne verifie pas encore.**
`tests/flora_test.gd` connait l'enveloppe de la flore basse, pas celle des
arbres : elle sera ecrite avec la couche de dispersion du jalon 1.11. En
attendant, la hauteur commandee par le prompt est portee dans la table `LOT`
ci-dessous et verifiee a l'ecriture — un modele hors de sa fourchette fait
sortir le script en erreur.
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import arbres_formes as af
import flore_formes as ff
import flore_vox as fv
from flore_vox import Grille, teinte

try:
    import flore_blender as fb
except ImportError:  # pragma: no cover - hors de Blender
    fb = None

SORTIE = os.path.join(fv.RACINE, "arbres")

# Enveloppes par classe, en (hauteur, rayon) voxels : proposition du prompt,
# Sec. 1.1. Elles ne sont pas encore verrouillees par un test — c'est la couche
# de dispersion des arbres qui fixera la marge reelle — mais elles bornent
# l'ecriture, comme le plafond de la flore borne le lot precedent.
ARBRE = (160, 45)
HOUPPIER = (80, 45)
PALME = (60, 45)


# -- Composites partages ------------------------------------------------------

def _fut(g, rng, hauteur, r_bas, r_haut, clair, sombre, azimut=None,
         penche=0.0, sinuosite=0.03, segments=9, branches=None,
         epaisseur=0.45):
    """Un fut et sa charpente, traces d'un seul tenant.

    Un seul objet Blender pour l'arbre entier : la courbe a rayon variable
    affine chaque branche vers sa pointe sans qu'on ait a la modeliser deux
    fois, et l'echantillonnage ne balaie la boite qu'une fois.

    Rend (points du fut, charpente), pour y accrocher le feuillage.
    """
    fb.scene_vide()
    azimut = rng.uniform(0.0, math.tau) if azimut is None else azimut
    fut = af.fut_points(rng, hauteur, azimut, penche, segments, sinuosite,
                        Vector=fb.Vector)
    brins = [fut]
    rayons = [[r_bas + (r_haut - r_bas) * (i / segments) ** 0.75
               for i in range(segments + 1)]]
    charp = []
    if branches is not None:
        charp = af.charpente(rng, fb, fut, **branches)
        for pts, _a, _L in charp:
            brins.append(pts)
            rayons.append(fb.rayons_effiles(pts, r_haut * 1.05, r_haut * 0.32))
    fb.voxelise(g, fb.courbe(brins, rayons), fb.par_hauteur(clair, sombre),
                mode=fb.VOLUME, epaisseur=epaisseur, marge=1)
    return fut, charp


def _houppier(g, rng, nombre, nuage, lobe, z_bas, z_haut, clair, sombre,
              aplati=1.0, debord=1.45, epaisseur=0.62, pousses=(0, 0.0),
              largeur=3.0, retombe=0.16):
    """Une couronne posee sur rien : le corps commun des quatre houppiers.

    Aucun pied n'est dessine. Un houppier sera pose sur des troncs de hauteurs
    differentes, parfois a deux ou trois exemplaires sur le meme tronc : il
    doit tenir comme forme independante, et tout ce qui descendrait sous sa
    base doublerait le tronc ou le ferait flotter.
    """
    els = af.lobes(rng, nombre, nuage, lobe, z_bas, z_haut, aplati, debord)
    af.masse(g, fb, els, clair, sombre, epaisseur=epaisseur)
    if pousses[0] > 0:
        af.pousses(g, rng, els, pousses[0], pousses[1], clair, sombre,
                   largeur=largeur, retombe=retombe)
    return els


# =============================================================================
# herbe/ — le feuillu de prairie, en deux pieces
# =============================================================================

def houppier_01(g, rng):
    """La couronne ronde et haute du feuillu. La piece qu'on voit le plus du
    lot : elle se pose a un a trois exemplaires sur chaque tronc de prairie."""
    _houppier(g, rng, 9, 11.0, 15.0, 14.0, 61.0, 128, 136, debord=1.5,
              pousses=(16, 7.0), largeur=3.2)


def houppier_02(g, rng):
    """La variante large et basse. Elle ne se distingue pas de la premiere par
    un voxel mais par sa proportion : deux masses etalees au lieu d'une haute,
    et un flanc creuse."""
    _houppier(g, rng, 8, 15.0, 14.0, 12.0, 52.0, 128, 136, aplati=0.84,
              debord=1.5, pousses=(20, 8.0), largeur=3.6, retombe=0.24)


def tronc_feuillu(g, rng):
    """Le fut du feuillu : nu, avec la fourche qui portera les houppiers.

    Il porte son propre modele alors que la source ecrit le tronc dans le
    terrain, en colonnes de blocs (`docs/systems/02`, Sec. 5.2). Les deux ne
    s'excluent pas : l'assemblage du jalon 1.11 ecrira le tronc en matiere
    la ou il faut qu'on le creuse et qu'il porte collision, et ce modele donne
    la meme silhouette la ou une instance suffit — un bosquet lointain, une
    reduction de niveau de detail.
    """
    _fut(g, rng, 72.0, 2.1, 1.05, 148, 153, penche=0.03, sinuosite=0.045,
         branches=dict(depart_t=0.52, nombre=5, longueur=17.0, montee=0.55,
                       derive=0.18, inclinaison=(0.55, 0.95)))


# =============================================================================
# herbe_seche/ — l'arbre d'automne
# =============================================================================

def arbre_sec(g, rng):
    """Arbre entier de savane : un fut court, une charpente etalee, et du
    feuillage seulement au bout des branches.

    C'est la forme qui porte l'aspect du biome : large, claire, trouee. Le
    feuillage n'est pas une masse posee sur la charpente mais des paquets a
    chaque extremite — vu a cent blocs, c'est ce qui la distingue d'un feuillu.
    """
    fut, charp = _fut(g, rng, 62.0, 2.4, 1.1, 150, 155, penche=0.05,
                      sinuosite=0.05,
                      branches=dict(depart_t=0.34, nombre=7, longueur=26.0,
                                    montee=0.42, derive=0.26,
                                    inclinaison=(0.65, 1.15), segments=5))
    # Trois lobes serres par bout de branche, et non un seul : vu en jeu, une
    # boule unique par branche rendait des oranges accrochees a un arbre. Ce
    # qu'il faut, c'est un paquet de feuilles, donc une masse dont le bord est
    # decoupe — les lobes se chevauchent assez pour fusionner, et leurs creux
    # font le decoupage.
    els = []
    for pts, _a, _L in charp:
        p = pts[-1]
        for k in range(3):
            d = 3.2 if k > 0 else 0.0
            a = rng.uniform(0.0, math.tau)
            els.append((p.x + math.cos(a) * d, p.y + math.sin(a) * d,
                        p.z + rng.uniform(-2.5, 1.5), rng.uniform(5.0, 7.5)))
    af.masse(g, fb, els, 140, 145, epaisseur=0.58)
    af.pousses(g, rng, els, 26, 6.5, 140, 145, largeur=3.0, retombe=0.24)


def houppier_sec(g, rng):
    """La couronne d'automne : plus basse et plus trouee que celle de prairie.
    Trois lobes seulement portent la masse, les autres l'echancrent."""
    _houppier(g, rng, 7, 12.0, 12.0, 10.0, 47.0, 140, 147, aplati=0.92,
              debord=1.5, epaisseur=0.56, pousses=(18, 7.5), largeur=2.8,
              retombe=0.22)


# =============================================================================
# jungle/ — le stipe, ses palmes, et la couronne de canopee
# =============================================================================

def houppier_jungle(g, rng):
    """La couronne de canopee : dense, haute, et qui retombe.

    Les pousses sortent presque a l'horizontale et flechissent fort : c'est la
    frange retombante qui fait la jungle, pas la couleur.
    """
    _houppier(g, rng, 10, 13.0, 15.0, 14.0, 59.0, 128, 134, epaisseur=0.66,
              pousses=(26, 9.0), largeur=3.4, retombe=0.42)


def tronc_palmier(g, rng):
    """Le stipe : long, mince, courbe, et cicatrise.

    Il ne porte pas de palmes — elles sont deux modeles a part, poses au
    sommet. La courbure est la forme : un stipe droit rend un poteau.
    """
    fut, _ = _fut(g, rng, 98.0, 2.6, 1.7, 148, 152, azimut=0.4, penche=0.10,
                  sinuosite=0.02, epaisseur=0.42)
    af.anneaux(g, rng, fut, 10.0, 92.0, 6.5, 2.2, 148, 152)


def palme(g, rng):
    """Une fronde seule, dressee puis retombante.

    Elle est ancree par son point d'attache, en (0, 0, 0) : c'est ce point qui
    vient se poser au sommet d'un stipe. Voir la note d'ancrage en fin de
    fichier — le chargeur ancre au centre du gabarit, pas ici.
    """
    af.fronde(g, rng, (0.0, 0.0, 0.0), 0.0, 74.0, 129, 135,
              inclinaison=0.62, retombe=0.0405, foliole=(4.5, 10.0),
              balance=0.004)


def palme_diagonale(g, rng):
    """La meme fronde, mais orientee sur la diagonale.

    Le moteur ne precalcule que **quatre quarts de tour** ; l'original a donc
    deux modeles de palme, `palm-leaf` et `palm-leaf-diagonal`, ce qui donne
    huit directions au lieu de quatre pour une couronne. Ce n'est pas une
    variante de dessin, c'est une variante d'orientation — d'ou le meme
    generateur a 45 degres, un peu plus longue et un peu plus plate.
    """
    af.fronde(g, rng, (0.0, 0.0, 0.0), math.pi / 4.0, 78.0, 130, 135,
              inclinaison=0.70, retombe=0.0380, foliole=(4.5, 10.5),
              balance=-0.005)


# =============================================================================
# marais/ — l'arbre mort
# =============================================================================

def arbre_mort(g, rng):
    """Un fut tordu et des branches cassees, sans une feuille.

    Le seul modele du lot qui n'emploie que l'ecorce, et le plus sombre : la
    rampe 152-155 est le bas de la rampe des troncs. Les branches montent peu
    et derivent beaucoup — une charpente reguliere rendrait un arbre vivant
    sans ses feuilles, pas un arbre mort.
    """
    fut, charp = _fut(g, rng, 70.0, 2.6, 1.2, 152, 155, penche=0.045,
                      sinuosite=0.075,
                      branches=dict(depart_t=0.3, nombre=8, longueur=22.0,
                                    montee=0.34, derive=0.34,
                                    inclinaison=(0.5, 1.15), segments=5))
    # Les moignons : des departs de branche casses net, plus courts que les
    # autres. Sans eux le fut est lisse sur toute sa moitie basse.
    fb.scene_vide()
    brins, rayons = [], []
    for i in range(4):
        z = 14.0 + i * 11.0 + rng.uniform(-3.0, 3.0)
        p = af.axe_a(fut, z)
        a = rng.uniform(0.0, math.tau)
        pts = fb.branche(rng, p, ff.azimut(a, rng.uniform(0.9, 1.3)),
                         rng.uniform(5.0, 10.0), 3, 0.3, 0.1)
        brins.append(pts)
        rayons.append(fb.rayons_effiles(pts, 1.15, 0.55))
    fb.voxelise(g, fb.courbe(brins, rayons), fb.par_hauteur(152, 155),
                mode=fb.VOLUME, epaisseur=0.42, marge=1)


# =============================================================================
# sable_desert/ — le dattier, arbre entier
# =============================================================================

def palmier_dattier(g, rng):
    """Le dattier : un stipe et sa couronne de palmes, en un seul modele.

    C'est le seul assemblage que ce lot livre monte, et pour une raison : le
    desert n'a qu'un arbre, et le poser en deux pieces couterait une couche de
    dispersion pour un seul cas. La couronne reemploie la fronde de la jungle,
    dans les teintes du biome.

    Les palmes partent d'un meme point et s'inclinent d'autant plus qu'elles
    sont vieilles : les trois dernieres retombent presque a la verticale, ce
    qui donne la jupe seche sous la couronne.
    """
    fut, _ = _fut(g, rng, 92.0, 3.0, 2.0, 148, 152, azimut=1.1, penche=0.085,
                  sinuosite=0.022, epaisseur=0.42)
    af.anneaux(g, rng, fut, 8.0, 86.0, 7.0, 2.5, 148, 152)
    sommet = af.axe_a(fut, 91.0)
    a0 = rng.uniform(0.0, math.tau)
    for i in range(9):
        a = a0 + i * af.TOUR_DOR + rng.uniform(-0.2, 0.2)
        vieille = i >= 6
        af.fronde(g, rng, sommet, a,
                  rng.uniform(30.0, 38.0) * (0.82 if vieille else 1.0),
                  133, 139,
                  inclinaison=rng.uniform(1.35, 1.6) if vieille
                  else rng.uniform(0.62, 1.05),
                  retombe=0.2 if vieille else 0.135,
                  foliole=(3.5, 8.0), rachis=(0.95, 0.3))


# =============================================================================
# neige/ et toundra/ — les coniferes
# =============================================================================

def sapin(g, rng):
    """Le conifere de neige : douze etages de rameaux sur un fut mince.

    La table de teintes du prompt ne donne que du feuillage pour ce modele, et
    c'est coherent : les etages descendent jusqu'au pied, le fut n'est visible
    qu'en un moignon, et il est pris dans le bas de la rampe (138-139) plutot
    que dans l'ecorce. Le `sapin_rabougri`, lui, montre son tronc et recoit
    l'ecorce — le prompt le dit explicitement pour lui seul.
    """
    af.conifere(g, rng, 108.0, 20.0, 130, 139, 13,
                tronc=(138, 139, 1.8, 0.9), retombe=0.34, largeur=(3.6, 6.4))


def sapin_enneige(g, rng):
    """Le meme, sous la neige.

    La neige se pose sur ce qui voit le ciel : le dessus des rameaux, la
    fleche. Elle emploie 14-15 — le clair de la roche nue — faute de blanc dans
    la plage vegetation ; c'est le seul point du lot ou le prompt demande
    explicitement de signaler plutot que de decider.
    """
    af.conifere(g, rng, 112.0, 19.0, 130, 139, 13,
                tronc=(138, 139, 1.8, 0.9), retombe=0.36, largeur=(3.4, 6.2))
    af.neige_dessus(g, rng, part=0.58, seuil_z=12)


def sapin_rabougri(g, rng):
    """Le conifere de toundra : court, trapu, et qui montre son bois.

    Les rameaux sont plus courts et retombent davantage, le fut est plus epais
    pour la hauteur, et deux branches nues sortent sous le premier etage : au
    ras du sol, un sapin de toundra a perdu son bas.
    """
    af.conifere(g, rng, 64.0, 13.5, 132, 139, 9,
                tronc=(150, 154, 2.0, 1.1), retombe=0.46, largeur=(3.0, 5.6),
                longue=1.7)
    a0 = rng.uniform(0.0, math.tau)
    for i in range(2):
        a = a0 + i * af.TOUR_DOR
        ff.trace(g, (0.0, 0.0, 4.0 + i * 3.0), ff.azimut(a, 1.35),
                 rng.uniform(9.0, 13.0),
                 lambda t: teinte(150, 154, 0.55 - 0.3 * t),
                 flechir=lambda t: (0.0, 0.0, -0.12 * t),
                 rayon=lambda t: 1.1 * (1.0 - 0.6 * t))


# =============================================================================
# Le lot
# =============================================================================

# (dossier, nom, graine, fonction, plafond de classe, fourchette commandee).
#
# La graine est en dur : le lot se regenere a l'identique, et retoucher un
# modele ne deplace pas les autres. La fourchette est celle de la table du
# prompt, Sec. 2 ; elle est verifiee a l'ecriture faute de test dans la suite.
LOT = [
    ("herbe", "houppier_01", 11001, houppier_01, HOUPPIER, (50, 80)),
    ("herbe", "houppier_02", 11002, houppier_02, HOUPPIER, (50, 80)),
    ("herbe", "tronc_feuillu", 11003, tronc_feuillu, ARBRE, (60, 100)),

    ("herbe_seche", "arbre_sec", 12001, arbre_sec, ARBRE, (80, 120)),
    ("herbe_seche", "houppier_sec", 12002, houppier_sec, HOUPPIER, (40, 70)),

    ("jungle", "houppier_jungle", 13001, houppier_jungle, HOUPPIER, (50, 80)),
    ("jungle", "tronc_palmier", 13002, tronc_palmier, ARBRE, (80, 130)),
    ("jungle", "palme", 13003, palme, PALME, (30, 60)),
    ("jungle", "palme_diagonale", 13004, palme_diagonale, PALME, (30, 60)),

    ("marais", "arbre_mort", 14001, arbre_mort, ARBRE, (70, 110)),

    ("sable_desert", "palmier_dattier", 15001, palmier_dattier, ARBRE, (90, 140)),

    ("neige", "sapin", 16001, sapin, ARBRE, (90, 140)),
    ("neige", "sapin_enneige", 16002, sapin_enneige, ARBRE, (90, 140)),

    ("toundra", "sapin_rabougri", 17001, sapin_rabougri, ARBRE, (50, 90)),
]


def main(argv):
    seul = None
    if "--seul" in argv:
        seul = argv[argv.index("--seul") + 1]
    bloc = fv.lit_bloc_rgba()
    dossier_courant = None
    fait = 0
    hors = []
    for dossier, nom, graine, f, plafond, (h_min, h_max) in LOT:
        if seul is not None and seul not in (nom, "%s/%s" % (dossier, nom)):
            continue
        if dossier != dossier_courant:
            print("[%s/]" % dossier)
            dossier_courant = dossier
        g = Grille()
        f(g, random.Random(graine))
        size = fv.ecris(dossier, nom, g, bloc, racine=SORTIE, plafond=plafond)
        if not (h_min <= size[2] <= h_max):
            hors.append("%s/%s : %d voxels, commande %d-%d"
                        % (dossier, nom, size[2], h_min, h_max))
        fait += 1
    print("%d modele(s) ecrit(s) dans %s" % (fait, SORTIE))
    if hors:
        print("\nHORS DE LA FOURCHETTE COMMANDEE :")
        for ligne in hors:
            print("  " + ligne)
        return 1
    return 0


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    sys.exit(main(argv))
