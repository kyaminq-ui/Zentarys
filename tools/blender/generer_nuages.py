"""Le lot de nuages : trois modeles `.vox` sous `assets/models/nuages/`.

    "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background \
        --factory-startup --python tools/blender/generer_nuages.py

-- Pourquoi bpy ici, alors que les trois derniers lots s'en sont passes -------

Les arbres et les filons sont en Python pur : a un voxel par bloc, un filon fait
quatre voxels de large, et passer par une geometrie puis un echantillonnage
n'ajouterait que du bruit. Un nuage est a la meme maille — 1 voxel = 1 bloc —
mais il fait **cinquante blocs de large**, et ce qu'on lui demande est
exactement ce qu'une union de spheres ne sait pas rendre : une masse continue,
creusee entre ses lobes, sans les bosses recousues d'un empilement. C'est la
metaballe, et c'est le premier lot depuis la flore ou elle se justifie.

-- Trois decisions qui se voient dans les fichiers -----------------------------

* **le dessous est plat, et il est coupe, pas dessine.** Une masse de
  metaballes est ronde partout ; un cumulus a une base plate, qui est la
  condensation a altitude constante. On pose donc la masse a cheval sur `z = 0`
  et on laisse la grille jeter ce qui passe dessous (`Grille.pose` refuse les
  z negatifs). Dessiner la coupe reviendrait a la deviner ;
* **la couleur se pose apres la forme, sur la masse mesuree.** Le degrade de
  `flore_blender` se rapporte a la boite de l'objet, qui descend ici sous la
  coupe ; et la hauteur qu'on croit dessiner n'est pas celle qu'on obtient, la
  surface d'une metaballe etant plus petite que le rayon de ses elements. Les
  deux sortent un lot qui n'atteint jamais le blanc. Voir `_degrade` ;
* **la rampe est le haut de la plage « effets »**, 240 a 243. C'est la seule
  plage de `CWPalette` qui porte un degrade blanc vers bleu, et elle n'etait
  peinte par personne. Les autres blancs disponibles — la neige (7), la glace
  (8), le clair de la roche nue (14-15) — sont des **matieres de terrain** :
  peindre un nuage avec eux aurait interdit d'ajuster l'un sans l'autre, et un
  sommet enneige a la meme teinte qu'un nuage est exactement ce qu'on ne veut
  pas au telemetre du regard. Pourquoi 243 et non 247 : voir `BLEU`.

-- Ce que le lot n'est pas ----------------------------------------------------

Un nuage n'est **jamais ecrit dans les donnees voxels** : il serait creusable,
il casserait le chemin rapide « bloc entierement vide » de `_generate_block` sur
toute la hauteur du ciel, et il faudrait le faire connaitre a `generated_voxel`
(invariant n. 39). Il est instancie par `CWClouds`, comme la flore et les
houppiers.
"""

import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import flore_vox as fv
import flore_blender as fb
from flore_vox import Grille

SORTIE = os.path.join(fv.RACINE, "nuages")

# Enveloppe, en voxels — donc en blocs, la grille etant a 1. Vingt-quatre blocs
# de haut et trente-deux de rayon : au-dela, un nuage cesse d'etre un objet du
# ciel et devient un plafond, et la gigue d'instance de `CWClouds` le porte deja
# jusqu'a 2,6 fois.
NUAGE = (24, 32)

# La rampe de la plage « effets ». Voir l'en-tete.
#
# **Elle ne va que jusqu'a 243, soit la moitie de la rampe, et c'est une
# correction de capture (2026-09-11).** A 247 — le bleu de ciel franc — le lot
# sortait en **meduses turquoise** : on regarde un nuage par en dessous, donc
# c'est le bas de la rampe qu'on voit, et l'ambiante du ciel est elle-meme
# bleue. Les deux se cumulaient. A 243 le ventre est un blanc a peine froid
# (216, 239, 255), et c'est l'eclairage qui fait le reste du modele — ce qui
# etait deja le raisonnement de `build_cloud_material`.
BLANC = 240
BLEU = 243


def _degrade(g):
    """Repeint la masse : blanc au sommet, bleute sous le ventre.

    -- Pourquoi une passe apres coup, et non la fonction de `voxelise` --------

    `flore_blender.voxelise` offre un degrade, mais il se rapporte a la **boite
    de l'objet**, qui descend ici sous la coupe : le fondu sortirait decale de
    ce qu'on a jete. Le rapporter a la hauteur qu'on croit avoir dessinee ne
    marche pas non plus — la surface d'une metaballe est sensiblement plus
    petite que le rayon de ses elements, et la premiere version n'atteignait
    jamais le blanc, sortant un lot entierement bleu sans que rien ne le
    signale. On mesure donc la masse **une fois posee**, ce qui est la seule
    hauteur qui ne mente pas.
    """
    lo, hi = g.boite()
    haut = max(1, hi[2] - lo[2])
    for p in g.v:
        g.v[p] = fv.teinte(BLANC, BLEU, float(p[2] - lo[2]) / float(haut))


def _lobes(rng, largeur, profondeur, hauteur, n_bas, n_haut):
    """Les elements de metaballe d'un cumulus.

    Deux etages, et c'est tout ce qui fait la silhouette : une rangee basse qui
    donne l'etalement et le ventre, quelques boules hautes et plus petites qui
    donnent le chou-fleur. Les rayons de l'etage haut sont **volontairement plus
    faibles** — a rayons egaux les deux etages fusionnent en un ballon, et le
    nuage perd ses creux.
    """
    elements = []
    for i in range(n_bas):
        t = (i + 0.5) / n_bas
        # Une parabole sur la rangee : les boules du bord sont plus basses et
        # plus petites, sinon le nuage sort en saucisse a bouts carres.
        bord = 1.0 - (2.0 * t - 1.0) ** 2
        x = (t - 0.5) * largeur
        y = rng.uniform(-0.5, 0.5) * profondeur * 0.5
        z = hauteur * (0.02 + 0.16 * bord) + rng.uniform(-0.5, 0.5)
        r = hauteur * (0.34 + 0.30 * bord) * rng.uniform(0.88, 1.12)
        elements.append(((x, y, z), r, 2.0))
    for i in range(n_haut):
        t = (i + 0.5) / n_haut
        x = (t - 0.5) * largeur * 0.62 + rng.uniform(-1.5, 1.5)
        y = rng.uniform(-0.5, 0.5) * profondeur * 0.36
        z = hauteur * rng.uniform(0.46, 0.68)
        r = hauteur * rng.uniform(0.26, 0.38)
        elements.append(((x, y, z), r, 2.0))
    return elements


def _pose(g, rng, largeur, profondeur, hauteur, n_bas, n_haut,
          aplati=1.0, coupe=0.30):
    """Construit la masse, l'aplatit s'il le faut, et l'echantillonne.

    `coupe` est la part de la hauteur qui passe **sous** `z = 0` et que la
    grille jette : c'est elle qui fait le dessous plat. A zero, le nuage est un
    galet ; au-dela de 0,4 il ne reste qu'une croute.
    """
    fb.scene_vide()
    elements = _lobes(rng, largeur, profondeur, hauteur, n_bas, n_haut)
    # La resolution est en unites de scene. A 0,35 — celle de la flore, qui
    # travaille sur des objets de seize unites — une masse de cinquante unites
    # demanderait un million et demi de cellules pour un contour qu'on va de
    # toute facon echantillonner au voxel entier.
    obj = fb.metaballes(elements, resolution=0.9, nom="nuage")
    obj.location = (0.0, 0.0, -hauteur * coupe)
    obj.scale = (1.0, 1.0, aplati)
    # La couleur est posee ensuite, sur la masse mesuree : voir `_degrade`.
    n = fb.voxelise(g, obj, lambda _x, _y, _z, _f: BLANC, mode=fb.VOLUME,
                    epaisseur=0.7, marge=1)
    _degrade(g)
    return n


# =============================================================================
# Les trois nuages
# =============================================================================

def cumulus(g, rng):
    """Le nuage ordinaire. C'est celui qu'on voit le plus, donc c'est lui qui
    fixe l'echelle du ciel : une trentaine de blocs de large, une douzaine de
    haut, ce qui sous-tend cinq degres depuis le sol."""
    return _pose(g, rng, largeur=34.0, profondeur=20.0, hauteur=24.0,
                 n_bas=4, n_haut=3)


def cumulus_grand(g, rng):
    """Le gros temps : deux fois le volume du precedent, et un etage de plus.

    Il ne sort qu'une fois sur quatre du tirage de `CWClouds` — un ciel qui n'a
    que des gros nuages n'a plus d'echelle.
    """
    return _pose(g, rng, largeur=56.0, profondeur=30.0, hauteur=32.0,
                 n_bas=6, n_haut=4)


def voile(g, rng):
    """Le nuage etale : large, mince, et sans chou-fleur.

    Il est fait de la meme masse, **aplatie par la transformation de l'objet**
    et non par un jeu de rayons a part : deux dessins pour la meme forme
    divergeraient a la premiere retouche.
    """
    return _pose(g, rng, largeur=76.0, profondeur=28.0, hauteur=26.0,
                 n_bas=7, n_haut=2, aplati=0.52, coupe=0.22)


# =============================================================================
# Le lot
# =============================================================================

LOT = [
    ("cumulus", 31001, cumulus),
    ("cumulus_grand", 31002, cumulus_grand),
    ("voile", 31003, voile),
]


def main(argv):
    seul = None
    if "--seul" in argv:
        seul = argv[argv.index("--seul") + 1]
    bloc = fv.lit_bloc_rgba()
    fait = 0
    print("[nuages/]")
    for nom, graine, f in LOT:
        if seul is not None and seul != nom:
            continue
        g = Grille()
        f(g, random.Random(graine))
        fv.ecris("", nom, g, bloc, racine=SORTIE, plafond=NUAGE,
                 indices=fv.INDEX_NUAGES)
        fait += 1
    print("%d modele(s) ecrit(s) dans %s" % (fait, SORTIE))
    return 0


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    sys.exit(main(argv))
