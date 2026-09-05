"""Le lot de flore : 42 modeles `.vox` sous `assets/models/flore/`.

    blender --background --factory-startup --python tools/blender/generer_flore.py

Un modele par fonction, une graine en dur par modele : le lot se regenere a
l'identique. `--seul <nom>` ne refait qu'un fichier, pour iterer.

Ce qui est dessine ici suit `docs/prompt_generation_flore.md` et
`assets/models/MODELS.md` :

* **l'echelle.** Un bloc de terrain vaut 40/3 voxels, le personnage de
  reference en fait 32. Le plafond verifie par `tests/flora_test.gd` est 53 de
  haut et 26 de rayon.
* **la matiere est mince.** Une touffe est faite de lames, pas d'un volume
  vert ; seuls les cailloux, les cactus et le gres sont pleins. C'est ce qui
  separe ce rendu de celui de Minecraft.
* **les index.** Le moteur lit un index de palette, jamais une couleur.
  `flore_vox.verifie` refuse a l'ecriture tout ce qui sort des plages
  vegetation (128-175) et terrain (1-11, 14-31).

-- Ce qui a change au jalon 1.12 ---------------------------------------------

**Le lot est reorganise par biome** : six dossiers — `greenlands`, `snowlands`,
`deserts`, `jungles`, `lavalands`, `oceans` — au lieu des neuf matieres de
surface. Les biomes sont ceux de l'alpha 2013, et c'est `CWBiome` qui les
decide.

**Et il est redimensionne.** Six captures du jeu d'origine, mesurees le
2026-09-05 au soir, ont montre que tout le lot precedent etait dessine au bas
de son enveloppe (`nextsteps.md`, Sec. 6.5). En hauteurs de personnage :

    touffe d'herbe   0,45 x  ->  ~1,0 x  (a l'epaule, pas au genou)
    plante haute     absente ->  ~1,5 x
    caillou          0,30 x  ->  ~1,0 x  (un bloc erratique, pas un galet)
    buisson          1,05 x  ->  ~0,65 x
    fleur de champ   0,60 x  ->  ~0,2 x  (quelques cubes)

La cause tenait en une ligne fausse de `assets/models/MODELS.md`, Sec. 1 —
« touffe d'herbe au genou » —, corrigee depuis. Trois consequences se
retrouvent dans le code ci-dessous, et aucune n'est cosmetique :

1. **moins de brins, pas plus.** Cinq ou six par touffe au lieu de onze a
   vingt-deux. Les touffes lisaient « clairsemees » en jeu parce qu'elles
   faisaient la moitie de leur taille, donc le quart de la surface a l'ecran ;
   on avait repondu en densifiant, ce qui etait le remede inverse ;
2. **des brins epais.** Deux voxels de large a la base (`ff.brin(epaisseur=)`).
   A 28 voxels de long, une lame d'un voxel est un cheveu ;
3. **des cailloux qui sont des blocs**, pas des galets : 30 a 40 voxels.
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import arbres_formes as af
import flore_vox as fv
import flore_formes as ff
from flore_vox import Grille, teinte

try:
    import flore_blender as fb
except ImportError:  # pragma: no cover - hors de Blender
    fb = None


# -- Composites partages ------------------------------------------------------

def tige(g, rng, hauteur, clair, sombre, penche=0.16, a=None, epaisseur=0.0):
    """Une tige legerement flechie. Rend le sommet."""
    a = rng.uniform(0.0, math.tau) if a is None else a
    d = (math.cos(a) * penche, math.sin(a) * penche, 1.0)
    rayon = None
    if epaisseur > 0.0:
        rayon = lambda t: epaisseur * (1.0 - 0.5 * t)
    return ff.trace(g, (0.0, 0.0, 0.0), d, hauteur,
                    lambda t: teinte(clair, sombre, 0.25 + 0.6 * t),
                    flechir=lambda t: (math.cos(a) * 0.035 * t,
                                       math.sin(a) * 0.035 * t, 0.0),
                    rayon=rayon)


def feuilles_de_tige(g, rng, sommet, n, longueur, clair, sombre, base_z=2.0):
    """Quelques feuilles accrochees le long d'une tige verticale."""
    for i in range(n):
        z = base_z + (sommet[2] - base_z) * (i + 0.4) / (n + 0.6)
        a = rng.uniform(0.0, math.tau)
        d = ff.azimut(a, rng.uniform(1.0, 1.35))
        ff.feuille(g, (0.0, 0.0, z), d, longueur * rng.uniform(0.7, 1.1),
                   2.6, clair, sombre)


def chapeau(g, rng, centre, rayon, hauteur, clair, sombre, lamelles):
    """Une coupole creuse d'un a deux voxels, et ses lamelles dessous.

    Un chapeau plein serait un demi-bloc de couleur ; c'est la coupole qui rend
    la silhouette de champignon a trente blocs.
    """
    f = ff.bosses(rng, 0.09, (5, 7))
    cx, cy, cz = centre
    n = int(rayon) + 2
    for z in range(int(cz) - 1, int(cz + hauteur) + 2):
        for y in range(int(cy) - n, int(cy) + n + 1):
            for x in range(int(cx) - n, int(cx) + n + 1):
                ux, uy, uz = (x - cx) / rayon, (y - cy) / rayon, (z - cz) / hauteur
                q = math.sqrt(ux * ux + uy * uy + uz * uz)
                if q < 1e-6:
                    continue
                lim = f(math.atan2(uy, ux),
                        math.asin(max(-1.0, min(1.0, uz / q))))
                if q > lim:
                    continue
                if z < cz:
                    continue
                if q < lim - 0.34 and z > cz:
                    continue
                g.pose(x, y, z, teinte(clair, sombre,
                                       0.25 + 0.75 * (z - cz) / hauteur))
    # Le dessous : un anneau de lamelles, visible des que le regard passe sous
    # le chapeau, et qui epaissit le bord.
    for k in range(9):
        a = math.tau * k / 9 + rng.uniform(-0.1, 0.1)
        for r in range(2, int(rayon)):
            g.pose_si_vide(cx + math.cos(a) * r, cy + math.sin(a) * r,
                           cz - 0.5, lamelles)


def eclats(g, rng, n, autour, clair, sombre):
    """Des debris au pied d'un caillou : ce qui empeche la bille posee."""
    for _ in range(n):
        a = rng.uniform(0.0, math.tau)
        d = autour * rng.uniform(0.7, 1.25)
        ff.ellipsoide(g, (math.cos(a) * d, math.sin(a) * d, 0.0),
                      (rng.uniform(1.4, 2.8), rng.uniform(1.4, 2.8),
                       rng.uniform(1.6, 3.0)),
                      lambda f: teinte(clair, sombre, 0.3 + 0.7 * f),
                      deforme=ff.bosses(rng, 0.3, (2, 3)))


def bloc_erratique(g, rng, largeur, hauteur, clair, sombre, debris=3):
    """Un bloc pose au sol, a la taille du personnage.

    Le lot precedent avait des galets de 8 voxels ; sur les captures ce sont des
    **blocs erratiques** qui montent a la hauteur d'un personnage. La difference
    n'est pas qu'une taille : a 8 voxels un caillou est une bosse dans l'herbe,
    a 34 c'est un point de repere qu'on contourne.
    """
    ff.caillou(g, rng, largeur, largeur * rng.uniform(0.72, 0.9), hauteur,
               clair, sombre, enfonce=0.3)
    eclats(g, rng, debris, largeur * 0.62, clair + 1, sombre)


def charpente(g, rng, branches_n, longueur, clair, sombre, ouverture=(0.4, 0.9),
              base=1.1, pointe=0.35, segments=5):
    """Une charpente de branches nues, et les bouts ou accrocher un feuillage."""
    fb.scene_vide()
    branches, rayons, bouts = [], [], []
    for i in range(branches_n):
        a = math.tau * i / branches_n + rng.uniform(-0.4, 0.4)
        p = fb.branche(rng, (0, 0, 0),
                       ff.azimut(a, rng.uniform(ouverture[0], ouverture[1])),
                       longueur * rng.uniform(0.78, 1.12), segments, 0.3, 0.2)
        branches.append(p)
        rayons.append(fb.rayons_effiles(p, base, pointe))
        bouts.append(p[-1])
    fb.voxelise(g, fb.courbe(branches, rayons), fb.par_hauteur(clair, sombre),
                mode=fb.VOLUME, epaisseur=0.45)
    return bouts


def buisson_generique(g, rng, hauteur, rayon, clair, sombre, ecorce=(148, 151),
                      lobes=8, pousses=6):
    """Un buisson : charpente courte, frondaison en metaballes, et des pousses
    qui sortent de la masse.

    C'est la premiere forme ou Blender paye : des lobes qui fusionnent donnent
    une masse continue avec des creux, la ou une union de spheres laisse des
    bosses recousues.
    """
    fb.scene_vide()
    troncs, rayons = [], []
    for i in range(5):
        a = math.tau * i / 5 + rng.uniform(-0.5, 0.5)
        p = fb.branche(rng, (0, 0, 0), ff.azimut(a, 0.5), hauteur * 0.55, 5,
                       0.22, 0.25)
        troncs.append(p)
        rayons.append(fb.rayons_effiles(p, 1.2, 0.4))
    fb.voxelise(g, fb.courbe(troncs, rayons),
                fb.par_hauteur(ecorce[0], ecorce[1]), mode=fb.VOLUME,
                epaisseur=0.45)

    fb.scene_vide()
    els = []
    for i in range(lobes):
        a = math.tau * i / lobes + rng.uniform(-0.5, 0.5)
        r = rayon * rng.uniform(0.45, 1.0)
        els.append(((math.cos(a) * r, math.sin(a) * r,
                     hauteur * rng.uniform(0.45, 0.92)),
                    rayon * rng.uniform(0.32, 0.46), 2.4))
    fb.voxelise(g, fb.metaballes(els, 0.22),
                fb.par_hauteur(clair, sombre, depart=0.05), mode=fb.COQUE,
                epaisseur=0.55)
    for _ in range(pousses):
        a = rng.uniform(0.0, math.tau)
        r = rayon * rng.uniform(0.55, 1.0)
        ff.feuille(g, (math.cos(a) * r, math.sin(a) * r,
                       hauteur * rng.uniform(0.55, 0.95)),
                   ff.azimut(a, rng.uniform(0.8, 1.5)),
                   rng.uniform(3.0, 5.0), 2.6, clair, sombre,
                   flechir=lambda t: (0.0, 0.0, -0.12 * t))


def fronde(g, rng, base, a, longueur, clair, sombre, folioles=9, incline=0.55):
    """Une fronde de fougere : un rachis arque et ses folioles.

    La fougere est la « plante haute » que le lot precedent n'avait pas — le
    seul role de flore qui depasse le personnage sans etre un arbre.
    """
    d = ff.azimut(a, incline)
    # `incline` est un angle **depuis la verticale** : au-dela de 0,7 radian la
    # fronde part plus loin qu'elle ne monte, et le modele sort de l'enveloppe
    # de rayon (26 voxels) avant d'atteindre sa hauteur. C'est le seul endroit
    # du lot ou les deux plafonds se disputent, la fougere etant a la fois la
    # plus haute plante et la plus etalee.
    # `flechir` s'accumule pas a pas sur toute la marche : a 0,035 par unite et
    # cent pas, le rachis finissait couche et la fronde partait a trente voxels
    # de son pied, deux fois l'enveloppe. La retombee doit rester **faible** et
    # ne porter que sur Z.
    sommet = ff.trace(g, base, d, longueur,
                      lambda t: teinte(clair, sombre, 0.2 + 0.6 * t),
                      flechir=lambda t: (0.0, 0.0, -0.02 * t),
                      rayon=lambda t: 0.8 * (1.0 - 0.7 * t))
    # Les folioles sont posees le long de la corde base -> sommet : c'est une
    # approximation du rachis, et elle suffit — l'arc est faible sur la
    # longueur d'une fronde.
    for i in range(folioles):
        t = 0.22 + 0.75 * i / max(1, folioles - 1)
        p = (base[0] + (sommet[0] - base[0]) * t,
             base[1] + (sommet[1] - base[1]) * t,
             base[2] + (sommet[2] - base[2]) * t)
        L = longueur * 0.20 * (1.0 - 0.65 * t) + 2.0
        for s in (-1.0, 1.0):
            ff.feuille(g, p, ff.azimut(a + s * 1.45, rng.uniform(1.2, 1.7)),
                       L, 2.4, clair, sombre,
                       flechir=lambda t2: (0.0, 0.0, -0.14 * t2))
    return sommet


def champignon(g, rng, pied, pied_bas, chapeau_clair, chapeau_sombre,
               lamelles, tailles=(1.0, 0.66, 0.45), echelle=1.0):
    """Une touffe de champignons de tailles franchement differentes."""
    a0 = rng.uniform(0.0, math.tau)
    for i, k in enumerate(tailles):
        a = a0 + math.tau * i / len(tailles) + rng.uniform(-0.3, 0.3)
        r = 0.0 if i == 0 else rng.uniform(3.0, 5.5)
        cx, cy = math.cos(a) * r, math.sin(a) * r
        h = 9.0 * k * echelle
        for z in range(int(h)):
            u = z / max(1.0, h - 1.0)
            rr = 1.5 * k * echelle * (1.0 - 0.35 * u)
            n = int(rr) + 1
            for y in range(-n, n + 1):
                for x in range(-n, n + 1):
                    if x * x + y * y <= rr * rr:
                        g.pose(cx + x, cy + y, z, teinte(pied, pied_bas, u))
        chapeau(g, rng, (cx, cy, h), 5.2 * k * echelle, 3.4 * k * echelle,
                chapeau_clair, chapeau_sombre, lamelles)


def lierre(g, rng, clair, sombre, hauteur, feuillage):
    """Des coulees rampantes qui montent, garnies de feuilles."""
    fb.scene_vide()
    coulees, rayons = [], []
    for i in range(4):
        a = math.tau * i / 4 + rng.uniform(-0.7, 0.7)
        p = fb.branche(rng, (math.cos(a) * 1.5, math.sin(a) * 1.5, 0),
                       ff.azimut(a, rng.uniform(0.3, 0.7)),
                       hauteur * rng.uniform(0.7, 1.05), 7, 0.35, 0.15)
        coulees.append(p)
        rayons.append(fb.rayons_effiles(p, 0.9, 0.45))
    fb.voxelise(g, fb.courbe(coulees, rayons),
                fb.par_hauteur(clair, sombre), mode=fb.VOLUME, epaisseur=0.4)
    for p in coulees:
        for q in p[1::2]:
            ff.feuille(g, (q.x, q.y, q.z),
                       ff.azimut(rng.uniform(0.0, math.tau),
                                 rng.uniform(1.25, 1.9)),
                       rng.uniform(3.5, 5.5), 3.0, feuillage[0], feuillage[1],
                       flechir=lambda t: (0.0, 0.0, -0.18 * t))


def _pas(a, b, n):
    return [a + (b - a) * i / (n - 1) for i in range(n)]


def _cactus(g, rng, hauteur, rayon, bras, cotes=9):
    """Fut cannele et bras plies. Le cactus est l'un des rares volumes pleins
    du lot : c'est une masse, pas un feuillage."""
    fb.scene_vide()
    troncs, rayons = [], []
    axe = fb.branche(rng, (0, 0, 0), (0.02, 0.01, 1.0), hauteur, 4, 0.05, 0.9)
    troncs.append(axe)
    rayons.append([rayon * (1.0 - 0.22 * (i / (len(axe) - 1)) ** 2)
                   for i in range(len(axe))])
    for (z0, a, sortie, montee, r) in bras:
        # Le bras sort franchement avant de monter. Une sortie courte le fondait
        # dans le fut : le cactus rendait une colonne renflee, pas un saguaro.
        p = [fb.Vector((math.cos(a) * d, math.sin(a) * d, z0))
             for d in _pas(0.0, sortie, 6)]
        p += [fb.Vector((math.cos(a) * sortie, math.sin(a) * sortie, z0 + h))
              for h in _pas(1.0, montee, 6)]
        troncs.append(p)
        rayons.append([r] * (len(p) - 2) + [r * 0.85, r * 0.7])
    obj = fb.courbe(troncs, rayons)

    # Cannelures : la section est modulee au moment de l'echantillonnage. Une
    # geometrie cannelee au vertex donnerait le meme voxel une fois arrondie.
    ph = rng.uniform(0.0, math.tau)

    def couleur(x, y, z, f):
        a = math.atan2(y, x)
        cote = 0.5 + 0.5 * math.cos(cotes * a + ph)
        return teinte(172, 175, 0.15 + 0.55 * cote + 0.3 * f)

    fb.voxelise(g, obj, couleur, mode=fb.VOLUME, epaisseur=0.4)
    # Epines : un voxel clair sur les aretes, tous les trois etages.
    for (x, y, z), c in list(g.v.items()):
        if z % 4 == 2 and rng.random() < 0.06:
            g.pose(x, y, z, 172)


def cotonnier(g, rng, feuille_clair, feuille_sombre, tige_clair, tige_sombre):
    """Le cotonnier : une touffe de tiges, des feuilles, et les capsules.

    Le meme plant pousse au desert et dans Snowlands — deux climats extremes,
    et c'est ainsi dans l'alpha. Seules les teintes de feuillage changent ; les
    capsules restent le gris tres clair de la roche nue (14), la plage
    vegetation n'ayant aucun blanc.
    """
    a0 = rng.uniform(0.0, math.tau)
    sommets = []
    for i in range(4):
        a = a0 + math.tau * i / 4 + rng.uniform(-0.4, 0.4)
        r = rng.uniform(0.0, 2.2)
        s = ff.trace(g, (math.cos(a) * r, math.sin(a) * r, 0.0),
                     ff.azimut(a, 0.18), rng.uniform(17.0, 25.0),
                     lambda t: teinte(tige_clair, tige_sombre, 0.25 + 0.6 * t),
                     flechir=lambda t, a=a: (math.cos(a) * 0.045 * t,
                                             math.sin(a) * 0.045 * t, 0.0),
                     rayon=lambda t: 0.7 * (1.0 - 0.4 * t))
        sommets.append(s)
        for k in range(3):
            z = 5.0 + k * 5.0
            b = rng.uniform(0.0, math.tau)
            ff.feuille(g, (math.cos(a) * r, math.sin(a) * r, z),
                       ff.azimut(b, rng.uniform(1.15, 1.7)),
                       rng.uniform(4.5, 7.0), 3.2, feuille_clair, feuille_sombre)
    for s in sommets:
        # Une capsule ouverte : quatre lobes autour d'un coeur clair.
        ff.ellipsoide(g, (s[0], s[1], s[2]), (2.2, 2.2, 2.0),
                      lambda f: 14 if f > 0.35 else 15)
        for _ in range(3):
            b = rng.uniform(0.0, math.tau)
            g.pose(s[0] + math.cos(b) * 2.6, s[1] + math.sin(b) * 2.6,
                   s[2] + rng.uniform(-1.0, 1.0), 14)


# =============================================================================
# greenlands/ — les plaines temperees
# =============================================================================

def herbe_01(g, rng):
    """La touffe de base : cinq lames a l'epaule du personnage.

    Cinq brins de 28 voxels, epais de deux, largement ecartes. C'est la forme
    exacte des captures — et l'inverse du modele du jalon 1.7, qui en avait onze
    de 12 voxels d'un seul voxel d'epaisseur.
    """
    ff.touffe(g, rng, 5, 28.0, 128, 135, etalement=0.85, courbure=0.07,
              rayon_base=1.6, epaisseur=1.0)


def herbe_02(g, rng):
    """Haute et arquee : six lames dont deux qui retombent franchement."""
    ff.touffe(g, rng, 4, 30.0, 129, 136, etalement=0.7, courbure=0.055,
              rayon_base=1.3, epaisseur=1.0)
    for _ in range(2):
        a = rng.uniform(0.0, math.tau)
        ff.brin(g, (math.cos(a) * 1.6, math.sin(a) * 1.6, 0), a, 24.0, 0.13,
                131, 137, pousse=0.5, epaisseur=0.9)


def herbe_03(g, rng):
    """Large et couchee : la touffe de bord de chemin, plus etalee que haute."""
    ff.touffe(g, rng, 5, 25.0, 128, 137, etalement=1.35, courbure=0.1,
              rayon_base=2.4, epaisseur=1.0)
    for _ in range(2):
        a = rng.uniform(0.0, math.tau)
        ff.brin(g, (math.cos(a) * 2.0, math.sin(a) * 2.0, 0), a, 18.0, 0.24,
                130, 138, pousse=1.1, epaisseur=0.8)


def herbe_seche(g, rng):
    """La frange seche de Greenlands : plus raide, plus ecartee, plus pale.

    C'est le couvert de la matiere `GRASS_DRY`, qui est une *matiere* de
    Greenlands et non un biome depuis le jalon 1.12.
    """
    ff.touffe(g, rng, 5, 26.0, 140, 146, etalement=1.2, courbure=0.045,
              rayon_base=2.0, epaisseur=1.0)
    for _ in range(2):
        a = rng.uniform(0.0, math.tau)
        ff.brin(g, (0, 0, 0), a, 15.0, 0.28, 141, 147, pousse=1.4,
                epaisseur=0.8)


def fleur_bleuet(g, rng):
    """La fleur de champ dispersee : quelques cubes bleus au ras de l'herbe.

    0,2 fois le personnage sur les captures, contre 0,6 dans le lot precedent.
    C'est le seul modele qui **retrecit** franchement : une fleur de champ n'est
    pas un objet, c'est une ponctuation de couleur dans le couvert.
    """
    for i in range(3):
        a = rng.uniform(0.0, math.tau)
        r = 0.0 if i == 0 else rng.uniform(1.5, 3.0)
        h = rng.uniform(6.0, 9.0)
        s = ff.trace(g, (math.cos(a) * r, math.sin(a) * r, 0.0),
                     ff.azimut(a, 6.0), h,
                     lambda t: teinte(134, 138, 0.3 + 0.6 * t))
        ff.petales(g, rng, s, 5, 2.0, rng.uniform(0.0, math.tau), 161, 160,
                   inclinaison=1.35, retombe=0.2)


def fleur_tournesol(g, rng):
    """Grande tige, capitule incline : a la taille du personnage."""
    a = rng.uniform(0.0, math.tau)
    s = ff.trace(g, (0.0, 0.0, 0.0), (math.cos(a) * 0.1, math.sin(a) * 0.1, 1.0),
                 27.0, lambda t: teinte(134, 139, 0.3 + 0.6 * t),
                 flechir=lambda t: (math.cos(a) * 0.04 * t,
                                    math.sin(a) * 0.04 * t, 0.0),
                 rayon=lambda t: 1.0 if t < 0.6 else 0.4)
    feuilles_de_tige(g, rng, s, 4, 8.0, 132, 138, base_z=6.0)
    # Le capitule dodeline : centre de cote et un cran plus bas que la pointe
    # de la tige. Pose d'aplomb, il rendait un disque pose sur un baton, et les
    # quatre quarts de tour donnaient quatre fois la meme image.
    tete = (s[0] + math.cos(a) * 2.4, s[1] + math.sin(a) * 2.4, s[2] - 1.4)
    ff.ellipsoide(g, tete, (3.0, 3.0, 1.6), lambda f: 148)
    ff.petales(g, rng, tete, 13, 5.4, rng.uniform(0.0, math.tau), 158, 159,
               inclinaison=1.5, retombe=0.35)


def fleur_coeur(g, rng, hampe=138, feuillage=(132, 137), corolle=(157, 156)):
    """La heartflower : des coeurs pendants sur une hampe arquee.

    Elle rend la potion de vie dans l'alpha (`CWFloraDrops`), d'ou une
    silhouette qui doit se reconnaitre de loin : trois coeurs alignes sous un
    arc, et rien d'autre.
    """
    a = rng.uniform(0.0, math.tau)
    s = ff.trace(g, (0, 0, 0), (math.cos(a) * 0.15, math.sin(a) * 0.15, 1.0),
                 20.0, lambda t: teinte(133, hampe, 0.3 + 0.6 * t),
                 flechir=lambda t: (math.cos(a) * 0.07 * t,
                                    math.sin(a) * 0.07 * t, 0.0),
                 rayon=lambda t: 0.6)
    feuilles_de_tige(g, rng, s, 3, 6.5, feuillage[0], feuillage[1], base_z=4.0)
    for i in range(3):
        d = 3.2 * i
        c = (s[0] - math.cos(a) * d * 0.5, s[1] - math.sin(a) * d * 0.5,
             s[2] - d * 0.55)
        ff.ellipsoide(g, c, (2.4, 2.4, 2.0),
                      lambda f: teinte(corolle[0], corolle[1], 0.15 + 0.85 * f))
        g.pose(c[0], c[1], c[2] - 3, corolle[1])


def ginseng(g, rng):
    """Ombelle jaune sur une tige courte, grandes feuilles a la base.

    Le ginseng rend une racine, donc une soupe : c'est la plante utile de
    Greenlands, et elle doit se distinguer du bleuet a distance de ramassage.
    """
    a = rng.uniform(0.0, math.tau)
    s = tige(g, rng, 15.0, 136, 139, penche=0.12, a=a, epaisseur=0.6)
    for _ in range(5):
        b = rng.uniform(0.0, math.tau)
        ff.feuille(g, (0.0, 0.0, 1.0), ff.azimut(b, 1.42),
                   rng.uniform(6.0, 9.0), 3.4, 136, 139)
    ff.petales(g, rng, s, 8, 3.2, rng.uniform(0.0, math.tau), 158, 159,
               inclinaison=1.2, retombe=0.1)
    for i in range(3):
        b = rng.uniform(0.0, math.tau)
        c = (s[0] + math.cos(b) * 2.0, s[1] + math.sin(b) * 2.0, s[2] - 1.4)
        ff.petales(g, rng, c, 5, 2.2, rng.uniform(0.0, math.tau), 158, 159,
                   inclinaison=1.35)


def buisson(g, rng):
    """Le bush de l'alpha : rondins et fibre vegetale.

    **Il retrecit** — 0,65 fois le personnage au lieu de 1,05. C'est la seconde
    moitie de la correction du jalon 1.12 : ce qui devait grandir a grandi, et
    ce qui ecrasait le reste a diminue.
    """
    buisson_generique(g, rng, 21.0, 8.0, 128, 139)


def scrub(g, rng):
    """Le scrub : basses branches emmelees, feuillage rare, toiles dedans.

    Il rend de la toile d'araignee et non de la fibre — c'est la seconde chaine
    textile de l'alpha —, d'ou une silhouette volontairement plus maigre et plus
    grise que celle du buisson : on doit pouvoir les distinguer sans les
    ramasser.
    """
    bouts = charpente(g, rng, 8, 15.0, 151, 155, ouverture=(0.7, 1.3),
                      base=0.85, pointe=0.28)
    for b in bouts:
        for _ in range(2):
            ff.feuille(g, (b.x, b.y, b.z),
                       ff.azimut(rng.uniform(0.0, math.tau),
                                 rng.uniform(1.2, 1.9)),
                       rng.uniform(3.0, 4.5), 2.4, 133, 139)
    # Les toiles : des cordes claires tendues entre deux bouts de branche.
    for i in range(4):
        a, b = rng.sample(bouts, 2)
        ff.trace(g, (a.x, a.y, a.z),
                 (b.x - a.x, b.y - a.y, b.z - a.z),
                 math.dist((a.x, a.y, a.z), (b.x, b.y, b.z)),
                 lambda t: 14)


def broussaille(g, rng):
    """Un arbrisseau sec : la charpente et quelques feuilles d'automne."""
    bouts = charpente(g, rng, 7, 16.0, 148, 152, ouverture=(0.35, 0.8))
    for b in bouts:
        for _ in range(4):
            ff.feuille(g, (b.x, b.y, b.z),
                       ff.azimut(rng.uniform(0.0, math.tau),
                                 rng.uniform(1.2, 1.9)),
                       rng.uniform(3.5, 6.0), 2.8, 140, 146)


def fougere(g, rng):
    """La plante haute : une fougere a hauteur d'epaule et demie.

    Elle comble le trou releve dans `nextsteps.md`, Sec. 6.5 — « plante haute :
    absente chez nous, ~1,5 x sur les captures ». C'est le seul modele de flore
    qui depasse franchement le personnage sans etre un arbre, et c'est lui qui
    donne du relief au sous-bois de Greenlands.
    """
    a0 = rng.uniform(0.0, math.tau)
    for i in range(5):
        a = a0 + math.tau * i / 5 + rng.uniform(-0.35, 0.35)
        fronde(g, rng, (math.cos(a) * 1.2, math.sin(a) * 1.2, 0.0), a,
               rng.uniform(38.0, 44.0), 129, 136,
               folioles=10, incline=rng.uniform(0.16, 0.30))


def caillou_01(g, rng):
    """Un bloc erratique dresse, a hauteur de personnage."""
    bloc_erratique(g, rng, 22.0, 30.0, 14, 19)


def caillou_02(g, rng):
    """Une dalle basculee, plus large que haute."""
    ff.caillou(g, rng, 30.0, 22.0, 18.0, 15, 19, enfonce=0.42)
    eclats(g, rng, 4, 16.0, 16, 19)


# =============================================================================
# snowlands/ — la toundra et le grand froid
# =============================================================================

def herbe_gelee(g, rng):
    """Quelques lames raides qui percent la neige, et du givre dessus.

    -- La regle de couleur de Snowlands, et pourquoi elle est ecrite ici -------

    **Aucune plante de ce biome ne prend la rampe 140-147.** C'est la rampe
    « automne, herbe seche », un orange chaud ; sur un sol de neige — un cyan
    tres clair — chaque plante qui l'employait ressortait en tache orange, seul
    objet chaud du paysage. Le defaut avait deja ete releve en jeu le 2026-09-05
    sur la broussaille de neige, corrige pour elle seule, et il est revenu au
    complet avec le lot du jalon 1.12 : cinq modeles sur six.

    Snowlands puise donc dans le **bas de la rampe de feuillage** (136-139, les
    verts sombres et froids), dans l'ecorce sombre (151-155) et dans le clair de
    la roche nue (14-15) pour la neige. Rien d'autre.
    """
    ff.touffe(g, rng, 5, 22.0, 136, 139, etalement=0.9, courbure=0.04,
              rayon_base=1.8, epaisseur=0.9)
    af.neige_dessus(g, rng, part=0.5, seuil_z=4)


def fleur_de_glace(g, rng):
    """L'iceflower : la heartflower gelee, meme drop, autres teintes.

    « Iceflower : variante gelee de Heartflower » — c'est le releve de l'alpha,
    et c'est pour cela que les deux partagent leur forme ici et leur objet dans
    `CWFloraDrops`. Seuls le feuillage et la corolle changent : bleu de gel au
    lieu du rouge.
    """
    fleur_coeur(g, rng, hampe=139, feuillage=(136, 139), corolle=(161, 160))
    af.neige_dessus(g, rng, part=0.35, seuil_z=6)


def buisson_neige(g, rng):
    """Le bush blanc : la meme masse que celui de Greenlands, sous la neige.

    Vu en jeu le 2026-09-05, c'etait le point faible du biome : la neige est
    d'un cyan tres clair, et un buisson d'ecorce brune y ressortait en tache
    orange, seul objet chaud d'un paysage froid. Le bois est donc pris au bas de
    la rampe d'ecorce, et la neige posee sur ce qui voit le ciel le raccroche a
    son sol.
    """
    buisson_generique(g, rng, 19.0, 7.5, 136, 139, ecorce=(151, 155), lobes=7,
                      pousses=4)
    af.neige_dessus(g, rng, part=0.8, seuil_z=2)


def snowberry(g, rng):
    """Le snowberry : branches basses, feuilles sombres, baies claires."""
    bouts = charpente(g, rng, 6, 13.0, 151, 155, ouverture=(0.5, 1.0),
                      base=0.85, pointe=0.3)
    for b in bouts:
        for _ in range(3):
            ff.feuille(g, (b.x, b.y, b.z),
                       ff.azimut(rng.uniform(0.0, math.tau),
                                 rng.uniform(1.1, 1.8)),
                       rng.uniform(2.5, 4.0), 2.2, 136, 139)
        for _ in range(2):
            a = rng.uniform(0.0, math.tau)
            g.bille(b.x + math.cos(a) * 1.6, b.y + math.sin(a) * 1.6,
                    b.z + rng.uniform(-1.0, 0.5), 1.4, 14)
    af.neige_dessus(g, rng, part=0.55, seuil_z=3)


def cotonnier_neige(g, rng):
    cotonnier(g, rng, 136, 139, 137, 139)
    af.neige_dessus(g, rng, part=0.4, seuil_z=8)


def caillou_neige(g, rng):
    """Un bloc erratique pris dans la neige."""
    bloc_erratique(g, rng, 24.0, 28.0, 14, 19)
    af.neige_dessus(g, rng, part=0.9, seuil_z=2)


# =============================================================================
# deserts/ — le sable et la roche chaude
# =============================================================================

def cactus_01(g, rng):
    """Le saguaro a bras : il depasse le personnage d'un tiers."""
    a = rng.uniform(0.0, math.tau)
    _cactus(g, rng, 42.0, 4.0,
            [(14.0, a, 9.5, 16.0, 2.5),
             (24.0, a + math.pi + rng.uniform(-0.5, 0.5), 8.0, 12.0, 2.2)])


def cactus_02(g, rng):
    """Le tonneau : trapu, tres cannele, sans bras — et ses figues.

    Les figues de barbarie sont le drop de l'alpha (`prickly pear`), donc elles
    doivent se voir : ce sont les six billes rouges du pourtour.
    """
    _cactus(g, rng, 26.0, 6.5, [], cotes=13)
    for _ in range(6):
        a = rng.uniform(0.0, math.tau)
        r = rng.uniform(4.5, 7.0)
        ff.ellipsoide(g, (math.cos(a) * r, math.sin(a) * r,
                          rng.uniform(19.0, 26.0)), (1.8, 1.8, 1.8),
                      lambda f: 156 if f > 0.4 else 157)


def broussaille_seche(g, rng):
    """Le shrub jaune-brun : des branches nues et rien d'autre."""
    charpente(g, rng, 9, 17.0, 141, 147, ouverture=(0.5, 1.0), base=0.85,
              pointe=0.3)


def cotonnier_desert(g, rng):
    cotonnier(g, rng, 140, 145, 142, 147)


def habanero(g, rng):
    """Le habanero : un plant bas, et ses piments qui pendent.

    C'est le role rare du desert (une pose sur cent) : sa silhouette compte
    moins que sa couleur, un rouge franc dans un biome ocre.
    """
    a0 = rng.uniform(0.0, math.tau)
    bouts = []
    for i in range(4):
        a = a0 + math.tau * i / 4 + rng.uniform(-0.4, 0.4)
        s = ff.trace(g, (0.0, 0.0, 0.0), ff.azimut(a, 0.55),
                     rng.uniform(11.0, 16.0),
                     lambda t: teinte(130, 137, 0.3 + 0.6 * t),
                     rayon=lambda t: 0.6 * (1.0 - 0.4 * t))
        bouts.append(s)
        for _ in range(2):
            b = rng.uniform(0.0, math.tau)
            ff.feuille(g, (s[0] * 0.6, s[1] * 0.6, s[2] * 0.6),
                       ff.azimut(b, 1.4), rng.uniform(3.5, 5.5), 2.6, 129, 136)
    for s in bouts:
        # Un piment : une gousse allongee, pointe en bas.
        ff.trace(g, (s[0], s[1], s[2]), (0.1, 0.1, -1.0), 5.0,
                 lambda t: teinte(156, 156, 1.0),
                 rayon=lambda t: 1.5 * (1.0 - 0.75 * t))


def gres(g, rng):
    """Un bloc de gres sculpte par le vent : deux etages et un surplomb."""
    ff.colonne(g, rng, 26.0, 9.0, 5.5, 20, 24, plis=(3, 5), force=0.2,
               penche=0.035)
    ff.ellipsoide(g, (0.0, 0.0, 28.0), (8.0, 6.5, 5.5),
                  lambda f: teinte(20, 23, 0.3 + 0.7 * f),
                  deforme=ff.bosses(rng, 0.2, (2, 3, 5)))
    for (x, y, z), c in list(g.v.items()):
        # Le pied s'evase : sans lui, la colonne flotte sur son ombre.
        if z < 3:
            g.pose_si_vide(x + (1 if x > 0 else -1), y, z, teinte(21, 24, 0.1))


# =============================================================================
# jungles/ — le chaud et l'humide
# =============================================================================

def feuille_large(g, rng):
    """Trois grandes feuilles depuis une souche basse : la plante de sous-bois
    qu'on voit d'abord par sa silhouette."""
    a0 = rng.uniform(0.0, math.tau)
    for i in range(3):
        a = a0 + math.tau * i / 3 + rng.uniform(-0.35, 0.35)
        h = rng.uniform(8.0, 12.0)
        ff.trace(g, (0, 0, 0), ff.azimut(a, 0.3), h,
                 lambda t: teinte(130, 134, 0.3 + 0.5 * t),
                 rayon=lambda t: 0.6)
        base = (math.cos(a) * h * 0.3, math.sin(a) * h * 0.3, h)
        ff.feuille(g, base, ff.azimut(a, rng.uniform(0.75, 1.0)),
                   rng.uniform(13.0, 17.0), 7.0, 128, 132,
                   flechir=lambda t: (0.0, 0.0, -0.1 * t), nervure=131)


def fougere_geante(g, rng):
    """La fougere arborescente du sous-bois : la plus haute plante du lot."""
    a0 = rng.uniform(0.0, math.tau)
    ff.trace(g, (0, 0, 0), (0.02, 0.02, 1.0), 12.0,
             lambda t: teinte(150, 154, 0.3 + 0.6 * t),
             rayon=lambda t: 2.0 - 0.7 * t)
    for i in range(6):
        a = a0 + math.tau * i / 6 + rng.uniform(-0.3, 0.3)
        fronde(g, rng, (0.0, 0.0, 11.0), a, rng.uniform(26.0, 32.0), 128, 135,
               folioles=11, incline=rng.uniform(0.38, 0.60))


def liane(g, rng):
    """Une liane qui monte en torsade puis retombe. La retombee est la forme :
    droite, elle rendrait un poteau."""
    fb.scene_vide()
    montee = fb.helice((0, 0, 0), 3.4, 1.6, 32.0, sens=1.0)
    retour = fb.branche(rng, montee[-1], (0.5, 0.3, 0.35), 24.0, 8, 0.2, -0.55)
    retour = [p for p in retour if p.z > 1.0]
    brins = [montee, retour]
    rayons = [[0.95] * len(montee), fb.rayons_effiles(retour, 0.85, 0.45)]
    fb.voxelise(g, fb.courbe(brins, rayons),
                fb.par_hauteur(128, 135), mode=fb.VOLUME, epaisseur=0.4)
    for p in montee[::7] + retour[::3]:
        if rng.random() < 0.55:
            ff.feuille(g, (p.x, p.y, p.z),
                       ff.azimut(rng.uniform(0.0, math.tau),
                                 rng.uniform(1.3, 2.0)),
                       rng.uniform(4.0, 6.5), 3.0, 128, 134,
                       flechir=lambda t: (0.0, 0.0, -0.2 * t))


def vrille(g, rng):
    """Une vrille : l'helice seule, plus fine et plus serree que la liane."""
    fb.scene_vide()
    tour = fb.helice((0, 0, 0), 4.8, 3.2, 27.0, sens=-1.0)
    pointe = fb.branche(rng, tour[-1], (0.2, 0.2, 1.0), 6.0, 4, 0.25, -0.2)
    fb.voxelise(g, fb.courbe([tour, pointe],
                             [[0.75] * len(tour),
                              fb.rayons_effiles(pointe, 0.65, 0.3)]),
                fb.par_hauteur(129, 134), mode=fb.VOLUME, epaisseur=0.38)
    for p in tour[::9]:
        ff.feuille(g, (p.x, p.y, p.z),
                   ff.azimut(rng.uniform(0.0, math.tau), 1.5),
                   rng.uniform(3.5, 5.0), 2.6, 128, 133)


def lierre_jungle(g, rng):
    lierre(g, rng, 129, 135, 26.0, (129, 135))


def fleur_coeur_jungle(g, rng):
    fleur_coeur(g, rng)


def fleur_ame(g, rng):
    """Clochettes pendantes le long d'une hampe : la fleur du sol humide."""
    a = rng.uniform(0.0, math.tau)
    s = tige(g, rng, 21.0, 137, 139, penche=0.1, a=a, epaisseur=0.6)
    feuilles_de_tige(g, rng, s, 3, 7.0, 136, 139, base_z=3.0)
    for i in range(4):
        z = 10.0 + i * 3.0
        ang = a + math.pi * 0.5 * i + rng.uniform(-0.4, 0.4)
        d = rng.uniform(2.6, 4.2)
        cx, cy = math.cos(ang) * d, math.sin(ang) * d
        ff.trace(g, (0.0, 0.0, z), (math.cos(ang), math.sin(ang), 0.15), d,
                 lambda t: 137)
        ff.ellipsoide(g, (cx, cy, z - 2.0), (1.8, 1.8, 2.3),
                      lambda f: teinte(163, 162, 0.1 + 0.9 * f))


def roseau(g, rng):
    """Des lames hautes et raides, et deux epis. La verticalite est la forme :
    un roseau qui s'incurve devient un brin d'herbe."""
    a0 = rng.uniform(0.0, math.tau)
    for i in range(6):
        a = a0 + math.tau * i / 6 + rng.uniform(-0.4, 0.4)
        r = rng.uniform(0.0, 2.8)
        ff.brin(g, (math.cos(a) * r, math.sin(a) * r, 0), a,
                rng.uniform(22.0, 30.0), rng.uniform(0.012, 0.045),
                138, 144, pousse=rng.uniform(0.0, 0.2), epaisseur=0.9)
    for i in range(2):
        a = a0 + math.pi * i + rng.uniform(-0.5, 0.5)
        r = rng.uniform(1.0, 2.5)
        s = ff.trace(g, (math.cos(a) * r, math.sin(a) * r, 0),
                     (math.cos(a) * 0.05, math.sin(a) * 0.05, 1.0),
                     rng.uniform(24.0, 29.0),
                     lambda t: teinte(139, 143, 0.3 + 0.6 * t),
                     rayon=lambda t: 0.6)
        ff.ellipsoide(g, (s[0], s[1], s[2] - 1.8), (1.7, 1.7, 4.0),
                      lambda f: teinte(141, 144, 0.2 + 0.8 * f))


def champignon_jungle(g, rng):
    champignon(g, rng, 168, 168, 164, 166, 166, tailles=(1.0, 0.6, 0.42),
               echelle=1.15)


# =============================================================================
# lavalands/ — le magma et la scorie
# =============================================================================

def fire_shrub(g, rng):
    """Le Fire Shrub : un buisson rouge, aux memes drops que le bush.

    « Fire Shrub : buisson rouge, drops identiques au Bush » — c'est ce qui rend
    Lava Lands habitable, et c'est pour cela qu'il porte la meme masse que le
    buisson de Greenlands sous une autre couleur. Le rouge vient de la plage des
    fleurs (156-157), la seule chaude et saturee de la vegetation ; les braises
    prennent l'index du magma (30), que le generateur ecrit par ailleurs comme
    type de bloc — un modele instancie n'entre jamais dans les donnees du monde,
    donc les deux usages ne se croisent pas.
    """
    buisson_generique(g, rng, 20.0, 7.5, 156, 157, ecorce=(153, 155), lobes=7,
                      pousses=5)
    for _ in range(9):
        a = rng.uniform(0.0, math.tau)
        r = rng.uniform(2.0, 7.0)
        g.pose(math.cos(a) * r, math.sin(a) * r, rng.uniform(8.0, 19.0), 30)


def herbe_de_lave(g, rng):
    """La lava-grass : des lames sombres a la pointe incandescente."""
    ff.touffe(g, rng, 5, 20.0, 25, 27, etalement=1.0, courbure=0.06,
              rayon_base=1.8, epaisseur=1.0)
    # La pointe seule est chaude : une touffe entierement orange se lirait comme
    # une flamme, pas comme une plante.
    for (x, y, z), c in list(g.v.items()):
        if z >= 14 and rng.random() < 0.55:
            g.pose(x, y, z, 30 if z >= 17 else 31)


def fleur_de_lave(g, rng):
    """La lava-flower : une corolle etroite sur une hampe de scorie."""
    a = rng.uniform(0.0, math.tau)
    s = tige(g, rng, 14.0, 25, 27, penche=0.1, a=a, epaisseur=0.7)
    ff.petales(g, rng, s, 6, 3.0, rng.uniform(0.0, math.tau), 30, 31,
               inclinaison=1.4, retombe=0.3)
    g.pose(s[0], s[1], s[2] + 1, 30)


def caillou_basalte(g, rng):
    """Des orgues basaltiques : des angles, pas des galets."""
    for i in range(4):
        a = rng.uniform(0.0, math.tau)
        d = rng.uniform(0.0, 5.0) * i
        ff.ellipsoide(g, (math.cos(a) * d, math.sin(a) * d, 2.0 + 6.0 * i),
                      (rng.uniform(6.0, 9.0), rng.uniform(5.0, 8.0),
                       rng.uniform(4.0, 6.5)),
                      lambda f, i=i: teinte(25, 27, 0.12 * i + 0.75 * f),
                      deforme=ff.bosses(rng, 0.3, (2, 4)))
    # Une veine incandescente dans la fissure : c'est ce qui le distingue d'un
    # caillou gris pose sur de la scorie grise.
    for _ in range(6):
        a = rng.uniform(0.0, math.tau)
        r = rng.uniform(3.0, 7.0)
        g.pose(math.cos(a) * r, math.sin(a) * r, rng.uniform(2.0, 16.0), 30)


def champignon_luisant(g, rng):
    """Le Shimmer Mushroom : lumiere statique, aucun usage de jeu dans l'alpha.

    Il figure au lot pour ce qu'il apporte a l'oeil dans un biome sombre, et sa
    fiche de drop est **explicitement vide** (`CWFloraDrops`) — sans quoi la
    prochaine relecture se demanderait s'il a ete oublie.

    C'est le seul modele du lot autorise a puiser dans la plage des effets
    (240-247) : le chapeau doit rendre une lumiere, et aucune entree de la plage
    vegetation n'est assez claire pour cela. L'autorisation est passee
    explicitement a l'ecriture, elle n'elargit pas le garde-fou des autres.
    """
    champignon(g, rng, 166, 169, 240, 243, 241, tailles=(1.0, 0.62, 0.4))
    for _ in range(7):
        a = rng.uniform(0.0, math.tau)
        r = rng.uniform(2.0, 6.0)
        g.pose(math.cos(a) * r, math.sin(a) * r, rng.uniform(1.0, 6.0), 242)


# =============================================================================
# oceans/ — le fond marin
# =============================================================================

def algue(g, rng):
    """Rubans qui ondulent : le seul modele du lot a melanger le froid des
    coraux (170-171) et le vert de feuillage."""
    fb.scene_vide()
    rubans, rayons = [], []
    for i in range(5):
        a = math.tau * i / 5 + rng.uniform(-0.6, 0.6)
        pts = []
        h = rng.uniform(22.0, 30.0)
        n = 9
        phase = rng.uniform(0.0, math.tau)
        for k in range(n + 1):
            t = k / n
            r = 1.2 + 3.6 * t
            ang = a + math.sin(t * 4.0 + phase) * 0.8
            pts.append(fb.Vector((math.cos(ang) * r, math.sin(ang) * r, h * t)))
        rubans.append(pts)
        rayons.append([1.0 - 0.5 * (k / n) for k in range(n + 1)])
    fb.voxelise(g, fb.courbe(rubans, rayons),
                lambda x, y, z, f: teinte(130, 134, 0.15 + 0.85 * f),
                mode=fb.VOLUME, epaisseur=0.4)
    for p in rubans:
        for q in p[2::2]:
            ff.feuille(g, (q.x, q.y, q.z),
                       ff.azimut(rng.uniform(0.0, math.tau),
                                 rng.uniform(1.35, 2.0)),
                       rng.uniform(3.5, 5.5), 2.6, 170, 171,
                       flechir=lambda t: (0.0, 0.0, -0.15 * t))


def corail(g, rng):
    """Corail ramifie. Les deux seules entrees froides et saturees de la
    palette sont 170 et 171 ; sans elles il rendrait en vert de prairie, et
    c'est pour lui qu'elles ont ete prises sur la rampe des champignons."""
    fb.scene_vide()
    branches, rayons = [], []
    souche = fb.branche(rng, (0, 0, 0), (0.05, 0.05, 1.0), 8.0, 3, 0.1, 0.5)
    branches.append(souche)
    rayons.append(fb.rayons_effiles(souche, 2.4, 1.6))
    depart = rng.uniform(0.0, math.tau)
    for i in range(5):
        a = depart + math.tau * i / 5 + rng.uniform(-0.4, 0.4)
        p = fb.branche(rng, souche[-1], ff.azimut(a, rng.uniform(0.5, 0.9)),
                       rng.uniform(10.0, 16.0), 5, 0.25, 0.35)
        branches.append(p)
        rayons.append(fb.rayons_effiles(p, 1.5, 0.6))
        for q in (p[2], p[3]):
            if rng.random() < 0.7:
                r = fb.branche(rng, q,
                               ff.azimut(rng.uniform(0.0, math.tau), 0.7),
                               rng.uniform(4.5, 8.0), 3, 0.2, 0.5)
                branches.append(r)
                rayons.append(fb.rayons_effiles(r, 0.85, 0.35))
    fb.voxelise(g, fb.courbe(branches, rayons),
                lambda x, y, z, f: 170 if f > 0.45 else 171,
                mode=fb.VOLUME, epaisseur=0.42)


def etoile_de_mer(g, rng):
    """Cinq bras plats. Le plus petit modele du lot : quelques voxels au sol."""
    a0 = rng.uniform(0.0, math.tau)
    for i in range(5):
        a = a0 + math.tau * i / 5 + rng.uniform(-0.15, 0.15)
        L = rng.uniform(6.0, 8.0)
        # Les bras partent du haut du disque et redescendent : a plat, l'etoile
        # ne faisait que trois voxels et disparaissait dans le gravier.
        ff.feuille(g, (0.0, 0.0, 3.5), (math.cos(a), math.sin(a), -0.3), L,
                   3.2, 157, 156)
    ff.ellipsoide(g, (0.0, 0.0, 2.8), (3.4, 3.4, 3.0),
                  lambda f: teinte(157, 156, 0.2 + 0.8 * f))


# =============================================================================
# Le lot
# =============================================================================

# La plage des effets, ouverte au seul champignon luisant. Voir sa fonction : un
# lot passe toujours l'ensemble d'index le plus etroit qui lui suffit, et c'est
# ce qui fait du garde-fou de `flore_vox.verifie` autre chose qu'une formalite.
INDEX_LUISANT = frozenset(set(fv.INDEX_VALIDES) | set(range(240, 248)))

# (dossier, nom, graine, fonction[, index autorises]). La graine est en dur : le
# lot se regenere a l'identique, et retoucher un modele ne deplace pas les
# autres. Les graines sont reprises du lot precedent la ou le modele existait
# deja — un modele qu'on n'a pas voulu changer ne doit pas changer.
LOT = [
    ("greenlands", "herbe_01", 1001, herbe_01),
    ("greenlands", "herbe_02", 1002, herbe_02),
    ("greenlands", "herbe_03", 1003, herbe_03),
    ("greenlands", "herbe_seche", 1004, herbe_seche),
    ("greenlands", "fleur_bleuet", 1006, fleur_bleuet),
    ("greenlands", "fleur_tournesol", 1007, fleur_tournesol),
    ("greenlands", "fleur_coeur", 1011, fleur_coeur),
    ("greenlands", "ginseng", 1012, ginseng),
    ("greenlands", "buisson", 1008, buisson),
    ("greenlands", "scrub", 1013, scrub),
    ("greenlands", "broussaille", 1014, broussaille),
    ("greenlands", "fougere", 1015, fougere),
    ("greenlands", "caillou_01", 1009, caillou_01),
    ("greenlands", "caillou_02", 1010, caillou_02),

    ("snowlands", "herbe_gelee", 2001, herbe_gelee),
    ("snowlands", "fleur_de_glace", 2002, fleur_de_glace),
    ("snowlands", "buisson_neige", 2003, buisson_neige),
    ("snowlands", "snowberry", 2004, snowberry),
    ("snowlands", "cotonnier", 2005, cotonnier_neige),
    ("snowlands", "caillou_01", 2006, caillou_neige),

    ("deserts", "cactus_01", 5001, cactus_01),
    ("deserts", "cactus_02", 5002, cactus_02),
    ("deserts", "broussaille_seche", 5003, broussaille_seche),
    ("deserts", "cotonnier", 5005, cotonnier_desert),
    ("deserts", "habanero", 5006, habanero),
    ("deserts", "gres", 5004, gres),

    ("jungles", "feuille_large", 3004, feuille_large),
    ("jungles", "fougere_geante", 3007, fougere_geante),
    ("jungles", "liane", 3001, liane),
    ("jungles", "vrille", 3002, vrille),
    ("jungles", "lierre", 3003, lierre_jungle),
    ("jungles", "fleur_coeur", 3005, fleur_coeur_jungle),
    ("jungles", "fleur_ame", 4004, fleur_ame),
    ("jungles", "roseau", 4001, roseau),
    ("jungles", "champignon", 3006, champignon_jungle),

    ("lavalands", "fire_shrub", 6101, fire_shrub),
    ("lavalands", "herbe_de_lave", 6102, herbe_de_lave),
    ("lavalands", "fleur_de_lave", 6103, fleur_de_lave),
    ("lavalands", "caillou_basalte", 6104, caillou_basalte),
    ("lavalands", "champignon_luisant", 6105, champignon_luisant,
     INDEX_LUISANT),

    ("oceans", "algue", 9001, algue),
    ("oceans", "corail", 9002, corail),
    ("oceans", "etoile_de_mer", 9003, etoile_de_mer),
]


def main(argv):
    seul = None
    if "--seul" in argv:
        seul = argv[argv.index("--seul") + 1]
    bloc = fv.lit_bloc_rgba()
    dossier_courant = None
    fait = 0
    for entree in LOT:
        dossier, nom, graine, f = entree[:4]
        indices = entree[4] if len(entree) > 4 else None
        if seul is not None and seul not in (nom, "%s/%s" % (dossier, nom)):
            continue
        if dossier != dossier_courant:
            print("[%s/]" % dossier)
            dossier_courant = dossier
        g = Grille()
        f(g, random.Random(graine))
        fv.ecris(dossier, nom, g, bloc, indices=indices)
        fait += 1
    print("%d modele(s) ecrit(s) dans %s" % (fait, fv.SORTIE))


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    main(argv)
