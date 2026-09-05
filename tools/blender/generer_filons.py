"""Le lot de filons : 9 modeles `.vox` sous `assets/models/filons/`.

    blender --background --factory-startup --python tools/blender/generer_filons.py
    # ou, avec n'importe quel Python 3 :
    python tools/blender/generer_filons.py

Ce lot n'a pas besoin de `bpy` : a un voxel par bloc, un filon fait quatre
voxels de large. Passer par une geometrie puis un echantillonnage n'ajouterait
que du bruit — c'est le meme arbitrage que pour les brins d'herbe
(`docs/prompt_generation_flore.md`, Sec. 4).

-- Ce lot n'est pas comme les autres -----------------------------------------

Les 39 modeles de flore et les 14 d'arbres sont **instancies** : ils sont maille
une fois puis poses a l'echelle 3/40, treize fois plus fins qu'un bloc, et ils ne
se creusent pas. Un filon, lui, **s'estampe dans le terrain** : on doit pouvoir
le miner. Il suit donc l'autre regle de `assets/models/MODELS.md`, Sec. 3 :

* **1 voxel = 1 bloc**, et non 40/3 voxels par bloc ;
* chacun de ses voxels est un **type de bloc**, pas seulement une couleur. C'est
  `CHANNEL_TYPE` qui portera cette valeur a l'estampage, et c'est elle qui dira
  ce que le bloc rend quand on le casse ;
* d'ou la contrainte d'index, plus etroite que celle de la flore
  (`flore_vox.INDEX_FILONS`) : roche (1), roche nue (14-19) et les neuf entrees
  de filon (32-40), rien d'autre.

-- La decision de palette du 2026-09-05 --------------------------------------

Ce lot etait bloque : les neuf filons demandaient neuf types de bloc et la
reserve de terrain 14-31 etait pleine. `RANGE_TERRAIN_END` est passe de 31 a 40
et `RANGE_CREATURES_BEGIN` de 32 a 41 — **une seule frontiere deplacee, aucun
modele a repeindre**, la plage creatures n'ayant aucune entree peinte. Le
raisonnement complet est dans `src/worldgen/cw_palette.gd`, au-dessus de
`RANGE_TERRAIN_BEGIN`.

Les neuf index sont **consecutifs et dans l'ordre des codes d'entite 131-139**
de la source (`docs/systems/02`, Sec. 5.2), qui est lui-meme l'ordre de la table
de rarete de Sec. 5.4. La correspondance `index = 32 + (code - 131)` est
verrouillee par un test.

-- Ce que le filon n'est pas encore ------------------------------------------

Ce lot livre les **modeles**. La couche qui les pose — ou affleure un filon,
selon quelle roche et quelle profondeur — n'est pas ecrite : elle appartient a
la voie des entites, avec les points d'apparition du jalon 2.6. `roll_ore` dans
`CWPalette` porte deja le tirage de rarete, qui est la seule partie que la
source donne litteralement.
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import flore_vox as fv
from flore_vox import Grille

SORTIE = os.path.join(fv.RACINE, "filons")

# Enveloppe : un affleurement, pas une caverne. Six blocs de haut, quatre de
# rayon — au-dela ce n'est plus un filon, c'est du relief, et le relief se
# genere.
FILON = (6, 4)

# Les index, recopies de `CWPalette`. Ils sont en dur ici comme les couleurs le
# sont dans le generateur de flore : le script ne lit pas le GDScript, et un
# test verifie que les deux tables disent la meme chose.
OR = 32
FER = 33
ARGENT = 34
GRES = 35
EMERAUDE = 36
SAPHIR = 37
RUBIS = 38
DIAMANT = 39
CRISTAL_DE_GLACE = 40

# La gangue. `1` est la roche que le generateur ecrit lui-meme : un filon
# estampe s'y fond au lieu de dessiner un caillou pose sur la paroi.
ROCHE = 1


def _blocs_de_gangue(rng, rx, ry, rz, plein=0.78):
    """La masse de roche qui porte le filon : un ellipsoide grignote.

    `plein` est la part de l'ellipsoide gardee. En dessous de 1 le bord devient
    irregulier, et c'est tout ce qu'on demande a cette echelle — a quatre blocs
    de large, une forme lisse n'existe pas.
    """
    out = []
    for z in range(int(math.ceil(rz * 2))):
        for y in range(-int(ry), int(ry) + 1):
            for x in range(-int(rx), int(rx) + 1):
                ux = x / max(0.5, rx)
                uy = y / max(0.5, ry)
                uz = (z - rz + 0.5) / max(0.5, rz)
                q = ux * ux + uy * uy + uz * uz
                if q > 1.0:
                    continue
                # Le grignotage porte sur le bord : le coeur reste plein, sinon
                # le filon sort troue et on voit le ciel au travers.
                if q > 0.35 and rng.random() > plein:
                    continue
                out.append((x, y, z))
    return out


def _veine(rng, cases, index, part, depart=None):
    """Fait courir une veine dans la gangue et rend {case: index}.

    On ne peint pas au hasard case par case : du minerai saupoudre rend du
    bruit, pas une veine. On tire quelques germes et on les fait pousser vers
    leurs voisins, ce qui donne des amas connexes — c'est ce qui se lit comme
    un filon dans une paroi.
    """
    cible = max(1, int(round(len(cases) * part)))
    dedans = set(cases)
    peint = {}
    germes = max(1, cible // 5)
    front = []
    ordre = sorted(dedans)
    for _ in range(germes):
        c = ordre[rng.randrange(len(ordre))]
        front.append(c)
        peint[c] = index
    if depart is not None and depart in dedans:
        peint[depart] = index
        front.append(depart)
    voisins = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)]
    while len(peint) < cible and front:
        c = front.pop(rng.randrange(len(front)))
        rng.shuffle(voisins)
        for d in voisins:
            n = (c[0] + d[0], c[1] + d[1], c[2] + d[2])
            if n in dedans and n not in peint:
                peint[n] = index
                front.append(n)
                if len(peint) >= cible:
                    break
    return peint


def _pointes(g, rng, cases, index, nombre, hauteur):
    """Des cristaux qui sortent de la masse, un bloc de section.

    Reserve aux gemmes et au cristal de glace : c'est ce qui les distingue d'un
    filon metallique a la meme place, et a quatre blocs de large c'est le seul
    detail de silhouette qu'on puisse se payer.
    """
    hauts = sorted(cases, key=lambda c: (-c[2], c[0], c[1]))[:max(3, len(cases) // 3)]
    for _ in range(nombre):
        c = hauts[rng.randrange(len(hauts))]
        h = hauteur if rng.random() < 0.6 else hauteur - 1
        for k in range(1, h + 1):
            g.pose(c[0], c[1], c[2] + k, index)


def _filon(g, rng, rayons, index, part, pointes=(0, 0), gangue=ROCHE,
           plein=0.78):
    """Le corps commun des neuf : une gangue, une veine, parfois des pointes."""
    cases = _blocs_de_gangue(rng, rayons[0], rayons[1], rayons[2], plein)
    peint = _veine(rng, cases, index, part)
    for c in cases:
        g.pose(c[0], c[1], c[2], peint.get(c, gangue))
    if pointes[0] > 0:
        _pointes(g, rng, [c for c in cases if c in peint], index, *pointes)


# =============================================================================
# Les neuf
# =============================================================================

def filon_fer(g, rng):
    """Le plus commun — 70 % du tirage — et donc le plus gros : c'est celui
    qu'on croisera partout, il doit tenir sans etre precieux."""
    _filon(g, rng, (2.4, 2.0, 1.8), FER, 0.50)


def filon_or(g, rng):
    """Or : une veine plus mince que celle du fer, mais qui affleure haut."""
    _filon(g, rng, (2.2, 1.9, 1.7), OR, 0.40)


def filon_argent(g, rng):
    """Argent : meme rarete que l'or, veine plus dispersee."""
    _filon(g, rng, (2.2, 2.0, 1.6), ARGENT, 0.40)


def filon_gres(g, rng):
    """Gres : le seul du lot qui ne soit pas un metal ni une gemme. C'est un
    banc, pas une veine — large, plat, et presque entierement du gres."""
    _filon(g, rng, (3.0, 2.4, 1.2), GRES, 0.72, plein=0.85)


def filon_emeraude(g, rng):
    """Emeraude : la premiere des gemmes, ~9 % du tirage. Petite masse et deux
    pointes."""
    _filon(g, rng, (1.8, 1.6, 1.5), EMERAUDE, 0.34, pointes=(2, 2))


def filon_saphir(g, rng):
    """Saphir : 0,5 %. Plus petit encore, et plus pointu."""
    _filon(g, rng, (1.7, 1.5, 1.4), SAPHIR, 0.32, pointes=(2, 2))


def filon_rubis(g, rng):
    """Rubis : 0,3 %. Trapu, une seule pointe franche."""
    _filon(g, rng, (1.7, 1.6, 1.3), RUBIS, 0.34, pointes=(1, 3))


def filon_diamant(g, rng):
    """Diamant : 0,1 %, le plus rare du tirage. Peu de matiere, trois pointes —
    il doit se voir de loin, sinon personne ne le trouvera jamais."""
    _filon(g, rng, (1.6, 1.5, 1.4), DIAMANT, 0.26, pointes=(3, 3))


def filon_cristal_de_glace(g, rng):
    """Cristal de glace : hors du tirage de rarete, comme le gres — la source
    le charge mais sa branche de pose n'a pas ete trouvee. Le plus haut du lot,
    et le seul dont les pointes font l'essentiel de la silhouette."""
    _filon(g, rng, (1.8, 1.6, 1.2), CRISTAL_DE_GLACE, 0.40, pointes=(4, 3))


# =============================================================================
# Le lot
# =============================================================================

# (nom, graine, fonction). Les noms suivent l'ordre des codes d'entite 131-139,
# qui est celui de la table de rarete.
LOT = [
    ("or", 21001, filon_or),
    ("fer", 21002, filon_fer),
    ("argent", 21003, filon_argent),
    ("gres", 21004, filon_gres),
    ("emeraude", 21005, filon_emeraude),
    ("saphir", 21006, filon_saphir),
    ("rubis", 21007, filon_rubis),
    ("diamant", 21008, filon_diamant),
    ("cristal_de_glace", 21009, filon_cristal_de_glace),
]


def main(argv):
    seul = None
    if "--seul" in argv:
        seul = argv[argv.index("--seul") + 1]
    bloc = fv.lit_bloc_rgba()
    fait = 0
    print("[filons/]")
    for nom, graine, f in LOT:
        if seul is not None and seul != nom:
            continue
        g = Grille()
        f(g, random.Random(graine))
        fv.ecris("", nom, g, bloc, racine=SORTIE, plafond=FILON,
                 indices=fv.INDEX_FILONS)
        fait += 1
    print("%d modele(s) ecrit(s) dans %s" % (fait, SORTIE))
    return 0


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    sys.exit(main(argv))
