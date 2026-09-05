"""Le lot de flore : 39 modeles `.vox` sous `assets/models/flore/`.

    blender --background --factory-startup --python tools/blender/generer_flore.py

Un modele par fonction, une graine en dur par modele : le lot se regenere a
l'identique. `--seul <nom>` ne refait qu'un fichier, pour iterer.

Ce qui est dessine ici suit `docs/prompt_generation_flore.md` et
`assets/models/MODELS.md` :

* **l'echelle.** Un bloc de terrain vaut 40/3 voxels, le personnage de
  reference en fait 32. Une touffe d'herbe lui arrive au genou (10 a 14), un
  buisson a l'epaule, le grand cactus le depasse. Le plafond verifie par
  `tests/flora_test.gd` est 53 de haut et 26 de rayon.
* **la matiere est mince.** Une touffe est une dizaine de lames d'un voxel, pas
  un volume vert ; seuls les cailloux, les cactus et le gres sont pleins. C'est
  ce qui separe ce rendu de celui de Minecraft.
* **les index.** Le moteur lit un index de palette, jamais une couleur.
  `flore_vox.verifie` refuse a l'ecriture tout ce qui sort des plages
  vegetation (128-175) et terrain (1-11, 14-31) — l'air et l'eau translucide
  comprises.
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

def tige(g, rng, hauteur, clair, sombre, penche=0.16, a=None):
    """Une tige d'un voxel, legerement flechie. Rend le sommet."""
    a = rng.uniform(0.0, math.tau) if a is None else a
    d = (math.cos(a) * penche, math.sin(a) * penche, 1.0)
    return ff.trace(g, (0.0, 0.0, 0.0), d, hauteur,
                    lambda t: teinte(clair, sombre, 0.25 + 0.6 * t),
                    flechir=lambda t: (math.cos(a) * 0.035 * t,
                                       math.sin(a) * 0.035 * t, 0.0))


def feuilles_de_tige(g, rng, sommet, n, longueur, clair, sombre, base_z=2.0):
    """Quelques feuilles accrochees le long d'une tige verticale."""
    for i in range(n):
        z = base_z + (sommet[2] - base_z) * (i + 0.4) / (n + 0.6)
        a = rng.uniform(0.0, math.tau)
        d = ff.azimut(a, rng.uniform(1.0, 1.35))
        ff.feuille(g, (0.0, 0.0, z), d, longueur * rng.uniform(0.7, 1.1),
                   2.4, clair, sombre,
                   flechir=lambda t: (0.0, 0.0, -0.12 * t))


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
                      (rng.uniform(1.2, 2.4), rng.uniform(1.2, 2.4),
                       rng.uniform(1.4, 2.6)),
                      lambda f: teinte(clair, sombre, 0.3 + 0.7 * f),
                      deforme=ff.bosses(rng, 0.3, (2, 3)))


# =============================================================================
# herbe/ — prairie
# =============================================================================

def herbe_01(g, rng):
    """Petite touffe serree, celle qui couvre le sol."""
    ff.touffe(g, rng, 11, 12.0, 128, 135, etalement=0.9, rayon_base=1.3)


def herbe_02(g, rng):
    """Haute et clairsemee : quelques brins qui montent au-dessus du couvert."""
    ff.touffe(g, rng, 8, 13.5, 129, 136, etalement=0.7, courbure=0.06,
              rayon_base=1.0)
    ff.touffe(g, rng, 6, 8.0, 131, 137, etalement=1.4, rayon_base=1.8)


def herbe_03(g, rng):
    """Large et fournie, avec des brins couches : la touffe de bord de chemin."""
    ff.touffe(g, rng, 17, 13.0, 128, 137, etalement=1.5, courbure=0.11,
              rayon_base=2.0)
    for _ in range(5):
        a = rng.uniform(0.0, math.tau)
        ff.brin(g, (math.cos(a) * 1.5, math.sin(a) * 1.5, 0), a, 9.0, 0.22,
                130, 138, pousse=1.1)


def bouquet_01(g, rng):
    """Touffe et trois fleurs rouges."""
    ff.touffe(g, rng, 7, 11.0, 132, 138, etalement=1.1)
    for i in range(3):
        a = math.tau * i / 3 + rng.uniform(-0.4, 0.4)
        h = rng.uniform(11.0, 15.0)
        s = ff.trace(g, (math.cos(a) * 1.4, math.sin(a) * 1.4, 0.0),
                     (math.cos(a) * 0.18, math.sin(a) * 0.18, 1.0), h,
                     lambda t: teinte(133, 138, 0.3 + 0.6 * t),
                     flechir=lambda t, a=a: (math.cos(a) * 0.03 * t,
                                             math.sin(a) * 0.03 * t, 0.0))
        ff.petales(g, rng, s, 5, 2.6, rng.uniform(0.0, math.tau), 156, 157,
                   inclinaison=1.45, retombe=0.2)
        g.pose(s[0], s[1], s[2] + 1, 157)


def bouquet_02(g, rng):
    """Touffe basse, quatre fleurs violettes et deux jaunes."""
    ff.touffe(g, rng, 6, 10.0, 132, 139, etalement=1.3, rayon_base=1.6)
    for i in range(6):
        a = math.tau * i / 6 + rng.uniform(-0.5, 0.5)
        r = rng.uniform(0.8, 2.4)
        h = rng.uniform(9.0, 16.0)
        coeur, bord = (162, 163) if i < 4 else (158, 159)
        s = ff.trace(g, (math.cos(a) * r, math.sin(a) * r, 0.0),
                     (math.cos(a) * 0.22, math.sin(a) * 0.22, 1.0), h,
                     lambda t: teinte(134, 138, 0.3 + 0.6 * t),
                     flechir=lambda t, a=a: (math.cos(a) * 0.04 * t,
                                             math.sin(a) * 0.04 * t, 0.0))
        ff.petales(g, rng, s, 5, 2.2, rng.uniform(0.0, math.tau), coeur, bord,
                   inclinaison=1.5, retombe=0.15)


def fleur_bleuet(g, rng):
    """Une tige maitresse, une seconde plus courte, corolles bleues."""
    for i, h in enumerate((14.0, 9.5)):
        a = rng.uniform(0.0, math.tau) if i == 0 else rng.uniform(0.0, math.tau)
        base = (0.0, 0.0, 0.0) if i == 0 else (math.cos(a) * 2.0,
                                               math.sin(a) * 2.0, 0.0)
        s = ff.trace(g, base, (math.cos(a) * 0.2, math.sin(a) * 0.2, 1.0), h,
                     lambda t: teinte(134, 138, 0.3 + 0.6 * t),
                     flechir=lambda t, a=a: (math.cos(a) * 0.05 * t,
                                             math.sin(a) * 0.05 * t, 0.0))
        ff.petales(g, rng, s, 7, 3.0 if i == 0 else 2.2,
                   rng.uniform(0.0, math.tau), 161, 160,
                   inclinaison=1.35, retombe=0.25)
        g.pose(s[0], s[1], s[2], 161)
    for _ in range(4):
        a = rng.uniform(0.0, math.tau)
        ff.brin(g, (math.cos(a) * 1.2, math.sin(a) * 1.2, 0), a,
                rng.uniform(4.0, 7.0), 0.14, 134, 138)


def fleur_tournesol(g, rng):
    """Grande tige, capitule incline, coeur brun et couronne jaune."""
    a = rng.uniform(0.0, math.tau)
    s = ff.trace(g, (0.0, 0.0, 0.0), (math.cos(a) * 0.1, math.sin(a) * 0.1, 1.0),
                 17.0, lambda t: teinte(134, 139, 0.3 + 0.6 * t),
                 flechir=lambda t: (math.cos(a) * 0.05 * t,
                                    math.sin(a) * 0.05 * t, 0.0),
                 rayon=lambda t: 0.9 if t < 0.5 else 0.0)
    feuilles_de_tige(g, rng, s, 3, 6.0, 132, 138, base_z=4.0)
    # Le capitule dodeline : centre de cote et un cran plus bas que la pointe
    # de la tige. Pose d'aplomb, il rendait un disque pose sur un baton, et les
    # quatre quarts de tour donnaient quatre fois la meme image.
    tete = (s[0] + math.cos(a) * 2.0, s[1] + math.sin(a) * 2.0, s[2] - 1.0)
    # Le coeur d'abord : pose apres, il recouvrait l'attache des petales et
    # mangeait une teinte entiere de la corolle.
    ff.ellipsoide(g, tete, (2.4, 2.4, 1.3), lambda f: 148)
    ff.petales(g, rng, tete, 11, 4.2, rng.uniform(0.0, math.tau), 158, 159,
               inclinaison=1.5, retombe=0.35)


def buisson(g, rng):
    """Frondaison en metaballes sur une charpente de branches.

    C'est la premiere forme ou Blender paye : trois lobes qui fusionnent
    donnent une masse continue avec des creux, la ou une union de spheres
    laisse des bosses recousues.
    """
    fb.scene_vide()
    troncs, rayons = [], []
    for i in range(5):
        a = math.tau * i / 5 + rng.uniform(-0.5, 0.5)
        p = fb.branche(rng, (0, 0, 0), ff.azimut(a, 0.5), 15.0, 5, 0.22, 0.25)
        troncs.append(p)
        rayons.append(fb.rayons_effiles(p, 1.3, 0.45))
    fb.voxelise(g, fb.courbe(troncs, rayons),
                fb.par_hauteur(148, 151), mode=fb.VOLUME, epaisseur=0.45)

    fb.scene_vide()
    els = []
    for i in range(9):
        a = math.tau * i / 9 + rng.uniform(-0.5, 0.5)
        r = rng.uniform(4.5, 9.5)
        els.append(((math.cos(a) * r, math.sin(a) * r,
                     rng.uniform(13.0, 24.0)), rng.uniform(3.2, 5.0), 2.4))
    fb.voxelise(g, fb.metaballes(els, 0.22),
                fb.par_hauteur(128, 139, depart=0.05), mode=fb.COQUE,
                epaisseur=0.55)
    # Des pousses hors de la masse : c'est ce qui separe un buisson d'un dome.
    for i in range(7):
        a = rng.uniform(0.0, math.tau)
        r = rng.uniform(5.0, 9.0)
        ff.feuille(g, (math.cos(a) * r, math.sin(a) * r,
                       rng.uniform(16.0, 25.0)),
                   ff.azimut(a, rng.uniform(0.8, 1.5)),
                   rng.uniform(3.5, 6.0), 2.8, 128, 134,
                   flechir=lambda t: (0.0, 0.0, -0.12 * t))


def caillou_prairie_01(g, rng):
    ff.caillou(g, rng, 11.0, 9.0, 8.0, 14, 19)
    eclats(g, rng, 2, 6.5, 15, 19)


def caillou_prairie_02(g, rng):
    """Une dalle plate, distincte du galet de `caillou_01`."""
    ff.caillou(g, rng, 14.0, 10.0, 6.0, 15, 19, enfonce=0.45)
    eclats(g, rng, 3, 7.5, 16, 19)


# =============================================================================
# herbe_seche/ — steppe
# =============================================================================

def herbe_seche(g, rng):
    """Brins secs : plus raides et plus ecartes que l'herbe grasse."""
    ff.touffe(g, rng, 10, 13.0, 140, 146, etalement=1.25, courbure=0.055,
              rayon_base=1.7)
    for _ in range(2):
        a = rng.uniform(0.0, math.tau)
        ff.brin(g, (0, 0, 0), a, 7.0, 0.3, 141, 147, pousse=1.4)


def broussaille_seche(g, rng):
    """Un buisson mort : la charpente sans la frondaison, et quelques feuilles
    d'automne accrochees au bout des branches."""
    fb.scene_vide()
    branches, rayons, bouts = [], [], []
    for i in range(7):
        a = math.tau * i / 7 + rng.uniform(-0.4, 0.4)
        p = fb.branche(rng, (0, 0, 0), ff.azimut(a, rng.uniform(0.35, 0.8)),
                       rng.uniform(16.0, 23.0), 6, 0.3, 0.2)
        branches.append(p)
        rayons.append(fb.rayons_effiles(p, 1.1, 0.35))
        bouts.append(p[-1])
    fb.voxelise(g, fb.courbe(branches, rayons),
                fb.par_hauteur(148, 152), mode=fb.VOLUME, epaisseur=0.45)
    # Quatre feuilles par bout, et non deux : vu en jeu sur l'herbe seche, la
    # broussaille se lisait comme un paquet de branches nues orange, sans masse
    # de feuillage — le contraire de ce que son nom annonce.
    for b in bouts:
        for _ in range(4):
            ff.feuille(g, (b[0], b[1], b[2]),
                       ff.azimut(rng.uniform(0.0, math.tau),
                                 rng.uniform(1.2, 1.9)),
                       rng.uniform(3.0, 5.5), 2.8, 140, 146)


def fleur_echinacea(g, rng):
    """Cone dresse, petales retombants : la silhouette tient a la retombee."""
    a = rng.uniform(0.0, math.tau)
    s = tige(g, rng, 14.0, 143, 147, penche=0.12, a=a)
    feuilles_de_tige(g, rng, s, 3, 5.0, 142, 147, base_z=3.0)
    ff.petales(g, rng, s, 9, 4.0, rng.uniform(0.0, math.tau), 156, 157,
               inclinaison=1.75, retombe=0.5)
    ff.ellipsoide(g, (s[0], s[1], s[2] + 1.2), (1.6, 1.6, 2.0),
                  lambda f: teinte(140, 147, 0.2 + 0.8 * f))


def caillou_gres_01(g, rng):
    ff.caillou(g, rng, 12.0, 9.0, 8.0, 20, 24)
    eclats(g, rng, 3, 7.0, 21, 24)


def caillou_gres_02(g, rng):
    ff.caillou(g, rng, 15.0, 11.0, 6.0, 21, 24, enfonce=0.5)
    eclats(g, rng, 2, 8.0, 20, 23)


# =============================================================================
# jungle/
# =============================================================================

def liane(g, rng):
    """Une liane qui monte en torsade puis retombe. La retombee est la forme :
    droite, elle rendrait un poteau."""
    fb.scene_vide()
    montee = fb.helice((0, 0, 0), 3.2, 1.6, 30.0, sens=1.0)
    retour = fb.branche(rng, montee[-1], (0.5, 0.3, 0.35), 22.0, 8, 0.2, -0.55)
    retour = [p for p in retour if p.z > 1.0]
    brins = [montee, retour]
    rayons = [[0.85] * len(montee), fb.rayons_effiles(retour, 0.75, 0.4)]
    fb.voxelise(g, fb.courbe(brins, rayons),
                fb.par_hauteur(128, 135), mode=fb.VOLUME, epaisseur=0.4)
    for p in montee[::7] + retour[::3]:
        if rng.random() < 0.55:
            ff.feuille(g, (p.x, p.y, p.z),
                       ff.azimut(rng.uniform(0.0, math.tau),
                                 rng.uniform(1.3, 2.0)),
                       rng.uniform(3.5, 6.0), 3.0, 128, 134,
                       flechir=lambda t: (0.0, 0.0, -0.2 * t))


def vrille(g, rng):
    """Une vrille : l'helice seule, plus fine et plus serree que la liane."""
    fb.scene_vide()
    tour = fb.helice((0, 0, 0), 4.5, 3.2, 24.0, sens=-1.0)
    pointe = fb.branche(rng, tour[-1], (0.2, 0.2, 1.0), 6.0, 4, 0.25, -0.2)
    fb.voxelise(g, fb.courbe([tour, pointe],
                             [[0.7] * len(tour),
                              fb.rayons_effiles(pointe, 0.6, 0.3)]),
                fb.par_hauteur(129, 134), mode=fb.VOLUME, epaisseur=0.38)
    for p in tour[::9]:
        ff.feuille(g, (p.x, p.y, p.z),
                   ff.azimut(rng.uniform(0.0, math.tau), 1.5),
                   rng.uniform(3.0, 4.5), 2.4, 128, 133)


def lierre(g, rng, clair=129, sombre=135, hauteur=20.0, feuillage=(129, 135)):
    """Un lierre : des coulees rampantes qui montent, garnies de feuilles.

    Sert a la jungle et au marais ; seules les teintes changent.
    """
    fb.scene_vide()
    coulees, rayons = [], []
    for i in range(4):
        a = math.tau * i / 4 + rng.uniform(-0.7, 0.7)
        p = fb.branche(rng, (math.cos(a) * 1.5, math.sin(a) * 1.5, 0),
                       ff.azimut(a, rng.uniform(0.3, 0.7)),
                       hauteur * rng.uniform(0.7, 1.05), 7, 0.35, 0.15)
        coulees.append(p)
        rayons.append(fb.rayons_effiles(p, 0.8, 0.4))
    fb.voxelise(g, fb.courbe(coulees, rayons),
                fb.par_hauteur(clair, sombre), mode=fb.VOLUME, epaisseur=0.4)
    for p in coulees:
        for q in p[1::2]:
            ff.feuille(g, (q.x, q.y, q.z),
                       ff.azimut(rng.uniform(0.0, math.tau),
                                 rng.uniform(1.25, 1.9)),
                       rng.uniform(3.0, 4.8), 3.0, feuillage[0], feuillage[1],
                       flechir=lambda t: (0.0, 0.0, -0.18 * t))


def lierre_jungle(g, rng):
    lierre(g, rng, 129, 135, 21.0, (129, 135))


def lierre_marais(g, rng):
    lierre(g, rng, 135, 139, 19.0, (133, 139))


def feuille_jungle(g, rng):
    """Trois grandes feuilles depuis une souche basse : la plante de sous-bois
    qu'on voit d'abord par sa silhouette."""
    a0 = rng.uniform(0.0, math.tau)
    for i in range(3):
        a = a0 + math.tau * i / 3 + rng.uniform(-0.35, 0.35)
        h = rng.uniform(4.5, 7.5)
        ff.trace(g, (0, 0, 0), ff.azimut(a, 0.3), h,
                 lambda t: teinte(130, 134, 0.3 + 0.5 * t))
        base = (math.cos(a) * h * 0.3, math.sin(a) * h * 0.3, h)
        ff.feuille(g, base, ff.azimut(a, rng.uniform(0.75, 1.0)),
                   rng.uniform(8.0, 11.0), 5.5, 128, 132,
                   flechir=lambda t: (0.0, 0.0, -0.1 * t), nervure=131)


def fleur_coeur(g, rng):
    """Fleur en coeur pendante, portee par une hampe arquee."""
    a = rng.uniform(0.0, math.tau)
    s = ff.trace(g, (0, 0, 0), (math.cos(a) * 0.15, math.sin(a) * 0.15, 1.0),
                 15.0, lambda t: teinte(133, 138, 0.3 + 0.6 * t),
                 flechir=lambda t: (math.cos(a) * 0.075 * t,
                                    math.sin(a) * 0.075 * t, 0.0))
    feuilles_de_tige(g, rng, s, 3, 5.0, 132, 137, base_z=3.0)
    for i in range(3):
        d = 2.6 * i
        c = (s[0] - math.cos(a) * d * 0.5, s[1] - math.sin(a) * d * 0.5,
             s[2] - d * 0.55)
        ff.ellipsoide(g, c, (2.0, 2.0, 1.6),
                      lambda f: teinte(157, 156, 0.15 + 0.85 * f))
        g.pose(c[0], c[1], c[2] - 2, 156)


def champignon(g, rng, pied, pied_bas, chapeau_clair, chapeau_sombre,
               lamelles, tailles=(1.0, 0.66, 0.45)):
    """Une touffe de champignons de tailles franchement differentes."""
    a0 = rng.uniform(0.0, math.tau)
    for i, k in enumerate(tailles):
        a = a0 + math.tau * i / len(tailles) + rng.uniform(-0.3, 0.3)
        r = 0.0 if i == 0 else rng.uniform(3.0, 5.0)
        cx, cy = math.cos(a) * r, math.sin(a) * r
        h = 7.5 * k
        for z in range(int(h)):
            u = z / max(1.0, h - 1.0)
            rr = 1.35 * k * (1.0 - 0.35 * u)
            n = int(rr) + 1
            for y in range(-n, n + 1):
                for x in range(-n, n + 1):
                    if x * x + y * y <= rr * rr:
                        g.pose(cx + x, cy + y, z, teinte(pied, pied_bas, u))
        chapeau(g, rng, (cx, cy, h), 4.6 * k, 3.0 * k,
                chapeau_clair, chapeau_sombre, lamelles)


def champignon_jungle(g, rng):
    champignon(g, rng, 168, 168, 164, 166, 166, tailles=(1.0, 0.6, 0.42))


def champignon_marais(g, rng):
    champignon(g, rng, 168, 169, 165, 169, 167, tailles=(1.0, 0.8, 0.5))


# =============================================================================
# marais/
# =============================================================================

def roseau(g, rng):
    """Des lames hautes et raides, et deux epis. La verticalite est la forme :
    un roseau qui s'incurve devient un brin d'herbe."""
    a0 = rng.uniform(0.0, math.tau)
    for i in range(9):
        a = a0 + math.tau * i / 9 + rng.uniform(-0.4, 0.4)
        r = rng.uniform(0.0, 2.6)
        ff.brin(g, (math.cos(a) * r, math.sin(a) * r, 0), a,
                rng.uniform(16.0, 27.0), rng.uniform(0.012, 0.05),
                138, 144, pousse=rng.uniform(0.0, 0.2))
    for i in range(2):
        a = a0 + math.pi * i + rng.uniform(-0.5, 0.5)
        r = rng.uniform(1.0, 2.5)
        s = ff.trace(g, (math.cos(a) * r, math.sin(a) * r, 0),
                     (math.cos(a) * 0.05, math.sin(a) * 0.05, 1.0),
                     rng.uniform(20.0, 25.0),
                     lambda t: teinte(139, 143, 0.3 + 0.6 * t))
        ff.ellipsoide(g, (s[0], s[1], s[2] - 1.5), (1.5, 1.5, 3.4),
                      lambda f: teinte(141, 144, 0.2 + 0.8 * f))


def fleur_ame(g, rng):
    """Clochettes pendantes le long d'une hampe : la fleur du marais."""
    a = rng.uniform(0.0, math.tau)
    s = tige(g, rng, 17.0, 137, 139, penche=0.1, a=a)
    feuilles_de_tige(g, rng, s, 3, 5.5, 136, 139, base_z=2.5)
    for i in range(4):
        z = 8.0 + i * 2.6
        ang = a + math.pi * 0.5 * i + rng.uniform(-0.4, 0.4)
        d = rng.uniform(2.2, 3.6)
        cx, cy = math.cos(ang) * d, math.sin(ang) * d
        ff.trace(g, (0.0, 0.0, z), (math.cos(ang), math.sin(ang), 0.15), d,
                 lambda t: 137)
        ff.ellipsoide(g, (cx, cy, z - 1.6), (1.5, 1.5, 1.9),
                      lambda f: teinte(163, 162, 0.1 + 0.9 * f))


# =============================================================================
# sable_desert/
# =============================================================================

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


def _pas(a, b, n):
    return [a + (b - a) * i / (n - 1) for i in range(n)]


def cactus_01(g, rng):
    """Le grand cactus a bras : 3,5 blocs, il depasse le personnage."""
    a = rng.uniform(0.0, math.tau)
    _cactus(g, rng, 44.0, 3.8,
            [(14.0, a, 9.5, 16.0, 2.4),
             (24.0, a + math.pi + rng.uniform(-0.5, 0.5), 8.0, 12.0, 2.1)])


def cactus_02(g, rng):
    """Le tonneau : trapu, tres cannele, sans bras."""
    _cactus(g, rng, 26.0, 6.0, [], cotes=13)
    for _ in range(6):
        a = rng.uniform(0.0, math.tau)
        r = rng.uniform(4.0, 6.5)
        ff.ellipsoide(g, (math.cos(a) * r, math.sin(a) * r,
                          rng.uniform(20.0, 26.0)), (1.6, 1.6, 1.6),
                      lambda f: 173)


def broussaille_desert(g, rng):
    """Buisson epineux : des branches nues et rien d'autre."""
    fb.scene_vide()
    branches, rayons = [], []
    for i in range(9):
        a = math.tau * i / 9 + rng.uniform(-0.35, 0.35)
        p = fb.branche(rng, (0, 0, 0), ff.azimut(a, rng.uniform(0.5, 1.0)),
                       rng.uniform(12.0, 19.0), 5, 0.28, 0.15)
        branches.append(p)
        rayons.append(fb.rayons_effiles(p, 0.85, 0.3))
    fb.voxelise(g, fb.courbe(branches, rayons),
                fb.par_hauteur(141, 147), mode=fb.VOLUME, epaisseur=0.4)


def gres(g, rng):
    """Un bloc de gres sculpte par le vent : deux etages et un surplomb."""
    ff.colonne(g, rng, 26.0, 7.5, 4.5, 20, 24, plis=(3, 5), force=0.2,
               penche=0.035)
    ff.ellipsoide(g, (0.0, 0.0, 27.0), (6.0, 5.0, 4.5),
                  lambda f: teinte(20, 23, 0.3 + 0.7 * f),
                  deforme=ff.bosses(rng, 0.2, (2, 3, 5)))
    a = rng.uniform(0.0, math.tau)
    ff.colonne(g, rng, 12.0, 4.0, 2.6, 21, 24, penche=0.05)
    for (x, y, z), c in list(g.v.items()):
        # Le pied s'evase : sans lui, la colonne flotte sur son ombre.
        if z < 3:
            g.pose_si_vide(x + (1 if x > 0 else -1), y, z, teinte(21, 24, 0.1))


# =============================================================================
# neige/, toundra/, roche/
# =============================================================================

def caillou_neige(g, rng):
    ff.caillou(g, rng, 12.0, 10.0, 8.0, 14, 19, enfonce=0.4)
    eclats(g, rng, 3, 7.0, 15, 18)


def broussaille_neige(g, rng):
    """Bois mort sous la neige : des branches raides, sans une feuille — mais
    avec de la neige dessus.

    Vu en jeu le 2026-09-05, c'etait le point faible du biome : la neige est
    d'un cyan tres clair, et un buisson d'ecorce brune y ressortait en tache
    orange, seul objet chaud d'un paysage froid. La neige posee sur ce qui voit
    le ciel — le meme geste que pour `sapin_enneige`, meme fonction — le
    raccroche a son sol. Les index 14-15 sont le clair de la roche nue, faute de
    blanc dans la plage vegetation ; voir `arbres_formes.neige_dessus`.
    """
    fb.scene_vide()
    branches, rayons = [], []
    for i in range(6):
        a = math.tau * i / 6 + rng.uniform(-0.4, 0.4)
        p = fb.branche(rng, (0, 0, 0), ff.azimut(a, rng.uniform(0.4, 0.9)),
                       rng.uniform(11.0, 17.0), 5, 0.25, 0.2)
        branches.append(p)
        rayons.append(fb.rayons_effiles(p, 0.95, 0.3))
        for q in p[3:]:
            if rng.random() < 0.4:
                r = fb.branche(rng, q, ff.azimut(rng.uniform(0, math.tau), 0.9),
                               rng.uniform(3.0, 6.0), 3, 0.2, 0.1)
                branches.append(r)
                rayons.append(fb.rayons_effiles(r, 0.5, 0.25))
    # Bois sombre : le haut de la rampe d'ecorce (148-150) est un brun chaud qui,
    # sur un sol cyan clair, ressort en orange vif. Le bas de la meme rampe passe.
    fb.voxelise(g, fb.courbe(branches, rayons),
                fb.par_hauteur(151, 155), mode=fb.VOLUME, epaisseur=0.4)
    # Des paquets de neige dans la fourche des branches, avant la couche posee
    # sur le dessus : sans eux le buisson n'a aucune masse blanche, seulement un
    # lisere, et il reste une tache brune dans un paysage blanc.
    for i in range(0, len(branches), 2):
        p = branches[i][max(1, len(branches[i]) - 3)]
        g.bille(p.x, p.y, p.z, rng.uniform(1.6, 2.6),
                14 if rng.random() < 0.6 else 15)
    af.neige_dessus(g, rng, part=0.85, seuil_z=2)


def broussaille_toundra(g, rng):
    """Arbrisseau ras : une charpente courte et un feuillage terne accroche."""
    fb.scene_vide()
    branches, rayons, bouts = [], [], []
    for i in range(7):
        a = math.tau * i / 7 + rng.uniform(-0.4, 0.4)
        p = fb.branche(rng, (0, 0, 0), ff.azimut(a, rng.uniform(0.6, 1.1)),
                       rng.uniform(10.0, 15.0), 5, 0.3, 0.2)
        branches.append(p)
        rayons.append(fb.rayons_effiles(p, 0.9, 0.3))
        bouts.append(p[-1])
    fb.voxelise(g, fb.courbe(branches, rayons),
                fb.par_hauteur(143, 145), mode=fb.VOLUME, epaisseur=0.4)
    for b in bouts:
        for _ in range(5):
            ff.feuille(g, (b.x, b.y, b.z),
                       ff.azimut(rng.uniform(0.0, math.tau),
                                 rng.uniform(1.1, 1.9)),
                       rng.uniform(2.5, 4.2), 2.4, 139, 142)


def fleur_ginseng(g, rng):
    """Ombelle jaune sur une tige courte, feuilles a la base."""
    a = rng.uniform(0.0, math.tau)
    s = tige(g, rng, 11.0, 136, 139, penche=0.14, a=a)
    for _ in range(4):
        b = rng.uniform(0.0, math.tau)
        ff.feuille(g, (0.0, 0.0, 1.0), ff.azimut(b, 1.42),
                   rng.uniform(4.5, 6.5), 3.0, 136, 139)
    ff.petales(g, rng, s, 7, 2.4, rng.uniform(0.0, math.tau), 158, 159,
               inclinaison=1.2, retombe=0.1)
    for i in range(3):
        b = rng.uniform(0.0, math.tau)
        c = (s[0] + math.cos(b) * 1.6, s[1] + math.sin(b) * 1.6, s[2] - 1.0)
        ff.petales(g, rng, c, 5, 1.8, rng.uniform(0.0, math.tau), 158, 159,
                   inclinaison=1.35)


def caillou_toundra(g, rng):
    """Roche lichenee : la plage n'a que deux entrees, 28 clair et 29 sombre.
    Le lichen est donc pose en taches, pas en degrade."""
    ff.caillou(g, rng, 12.0, 10.0, 8.0, 28, 29, enfonce=0.4)
    for (x, y, z), c in list(g.v.items()):
        if (x * 7 + y * 13 + z * 3) % 5 < 2:
            g.pose(x, y, z, 28 if z > 3 else 29)
    eclats(g, rng, 2, 7.0, 29, 29)


def caillou_roche_01(g, rng):
    """Bloc de roche nue, plus haut que les galets de prairie."""
    ff.caillou(g, rng, 13.0, 11.0, 11.0, 14, 19, enfonce=0.3)
    eclats(g, rng, 3, 7.5, 16, 19)


def caillou_roche_02(g, rng):
    """Basalte : des angles, pas des galets. Trois blocs empiles a la diable."""
    for i in range(3):
        a = rng.uniform(0.0, math.tau)
        d = rng.uniform(0.0, 3.0) * i
        ff.ellipsoide(g, (math.cos(a) * d, math.sin(a) * d, 1.0 + 3.0 * i),
                      (rng.uniform(4.0, 6.0), rng.uniform(3.5, 5.5),
                       rng.uniform(2.6, 4.0)),
                      lambda f, i=i: teinte(25, 27, 0.15 * i + 0.75 * f),
                      deforme=ff.bosses(rng, 0.3, (2, 4)))


# =============================================================================
# gravier_fond_marin/
# =============================================================================

def algue(g, rng):
    """Rubans qui ondulent : le seul modele du lot a melanger le froid des
    coraux (170-171) et le vert de feuillage."""
    fb.scene_vide()
    rubans, rayons = [], []
    for i in range(5):
        a = math.tau * i / 5 + rng.uniform(-0.6, 0.6)
        pts = []
        h = rng.uniform(18.0, 27.0)
        n = 9
        phase = rng.uniform(0.0, math.tau)
        for k in range(n + 1):
            t = k / n
            r = 1.2 + 3.2 * t
            ang = a + math.sin(t * 4.0 + phase) * 0.8
            pts.append(fb.Vector((math.cos(ang) * r, math.sin(ang) * r, h * t)))
        rubans.append(pts)
        rayons.append([0.9 - 0.45 * (k / n) for k in range(n + 1)])
    fb.voxelise(g, fb.courbe(rubans, rayons),
                lambda x, y, z, f: teinte(130, 134, 0.15 + 0.85 * f),
                mode=fb.VOLUME, epaisseur=0.4)
    for p in rubans:
        for q in p[2::2]:
            ff.feuille(g, (q.x, q.y, q.z),
                       ff.azimut(rng.uniform(0.0, math.tau),
                                 rng.uniform(1.35, 2.0)),
                       rng.uniform(3.0, 5.0), 2.6, 170, 171,
                       flechir=lambda t: (0.0, 0.0, -0.15 * t))


def corail(g, rng):
    """Corail ramifie. Les deux seules entrees froides et saturees de la
    palette sont 170 et 171 ; sans elles il rendrait en vert de prairie, et
    c'est pour lui qu'elles ont ete prises sur la rampe des champignons."""
    fb.scene_vide()
    branches, rayons = [], []
    souche = fb.branche(rng, (0, 0, 0), (0.05, 0.05, 1.0), 7.0, 3, 0.1, 0.5)
    branches.append(souche)
    rayons.append(fb.rayons_effiles(souche, 2.2, 1.5))
    depart = rng.uniform(0.0, math.tau)
    for i in range(5):
        a = depart + math.tau * i / 5 + rng.uniform(-0.4, 0.4)
        p = fb.branche(rng, souche[-1], ff.azimut(a, rng.uniform(0.5, 0.9)),
                       rng.uniform(9.0, 14.0), 5, 0.25, 0.35)
        branches.append(p)
        rayons.append(fb.rayons_effiles(p, 1.4, 0.55))
        for q in (p[2], p[3]):
            if rng.random() < 0.7:
                r = fb.branche(rng, q,
                               ff.azimut(rng.uniform(0.0, math.tau), 0.7),
                               rng.uniform(4.0, 7.0), 3, 0.2, 0.5)
                branches.append(r)
                rayons.append(fb.rayons_effiles(r, 0.8, 0.35))
    fb.voxelise(g, fb.courbe(branches, rayons),
                lambda x, y, z, f: 170 if f > 0.45 else 171,
                mode=fb.VOLUME, epaisseur=0.42)


def etoile_de_mer(g, rng):
    """Cinq bras plats. Le plus petit modele du lot : quelques voxels au sol."""
    a0 = rng.uniform(0.0, math.tau)
    for i in range(5):
        a = a0 + math.tau * i / 5 + rng.uniform(-0.15, 0.15)
        L = rng.uniform(5.0, 7.0)
        # Les bras partent du haut du disque et redescendent : a plat, l'etoile
        # ne faisait que trois voxels et disparaissait dans le gravier.
        ff.feuille(g, (0.0, 0.0, 3.0), (math.cos(a), math.sin(a), -0.3), L,
                   3.0, 157, 156)
    ff.ellipsoide(g, (0.0, 0.0, 2.4), (3.0, 3.0, 2.6),
                  lambda f: teinte(157, 156, 0.2 + 0.8 * f))


# =============================================================================
# Le lot
# =============================================================================

# (dossier, nom, graine, fonction). La graine est en dur : le lot se regenere a
# l'identique, et retoucher un modele ne deplace pas les autres.
LOT = [
    ("herbe", "herbe_01", 1001, herbe_01),
    ("herbe", "herbe_02", 1002, herbe_02),
    ("herbe", "herbe_03", 1003, herbe_03),
    ("herbe", "bouquet_01", 1004, bouquet_01),
    ("herbe", "bouquet_02", 1005, bouquet_02),
    ("herbe", "fleur_bleuet", 1006, fleur_bleuet),
    ("herbe", "fleur_tournesol", 1007, fleur_tournesol),
    ("herbe", "buisson", 1008, buisson),
    ("herbe", "caillou_01", 1009, caillou_prairie_01),
    ("herbe", "caillou_02", 1010, caillou_prairie_02),

    ("herbe_seche", "herbe_seche", 2001, herbe_seche),
    ("herbe_seche", "broussaille", 2002, broussaille_seche),
    ("herbe_seche", "fleur_echinacea", 2003, fleur_echinacea),
    ("herbe_seche", "caillou_01", 2004, caillou_gres_01),
    ("herbe_seche", "caillou_02", 2005, caillou_gres_02),

    ("jungle", "liane", 3001, liane),
    ("jungle", "vrille", 3002, vrille),
    ("jungle", "lierre", 3003, lierre_jungle),
    ("jungle", "feuille", 3004, feuille_jungle),
    ("jungle", "fleur_coeur", 3005, fleur_coeur),
    ("jungle", "champignon", 3006, champignon_jungle),

    ("marais", "roseau", 4001, roseau),
    ("marais", "champignon", 4002, champignon_marais),
    ("marais", "lierre", 4003, lierre_marais),
    ("marais", "fleur_ame", 4004, fleur_ame),

    ("sable_desert", "cactus_01", 5001, cactus_01),
    ("sable_desert", "cactus_02", 5002, cactus_02),
    ("sable_desert", "broussaille", 5003, broussaille_desert),
    ("sable_desert", "gres", 5004, gres),

    ("neige", "caillou_01", 6001, caillou_neige),
    ("neige", "broussaille", 6002, broussaille_neige),

    ("toundra", "broussaille", 7001, broussaille_toundra),
    ("toundra", "fleur_ginseng", 7002, fleur_ginseng),
    ("toundra", "caillou_01", 7003, caillou_toundra),

    ("roche", "caillou_01", 8001, caillou_roche_01),
    ("roche", "caillou_02", 8002, caillou_roche_02),

    ("gravier_fond_marin", "algue", 9001, algue),
    ("gravier_fond_marin", "corail", 9002, corail),
    ("gravier_fond_marin", "etoile_de_mer", 9003, etoile_de_mer),
]


def main(argv):
    seul = None
    if "--seul" in argv:
        seul = argv[argv.index("--seul") + 1]
    bloc = fv.lit_bloc_rgba()
    dossier_courant = None
    fait = 0
    for dossier, nom, graine, f in LOT:
        if seul is not None and seul not in (nom, "%s/%s" % (dossier, nom)):
            continue
        if dossier != dossier_courant:
            print("[%s/]" % dossier)
            dossier_courant = dossier
        g = Grille()
        f(g, random.Random(graine))
        fv.ecris(dossier, nom, g, bloc)
        fait += 1
    print("%d modele(s) ecrit(s) dans %s" % (fait, fv.SORTIE))


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    main(argv)
