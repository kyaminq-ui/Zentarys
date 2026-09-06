"""Le catalogue des 38 modeles de flore basse, a **quatre voxels par bloc**.

Usage :

    python tools/blender/generer_flore.py
    python tools/blender/generer_flore.py -- --seul herbe_01

**Python pur depuis le 2026-09-06**, comme le lot d'arbres depuis le jalon 1.12
et pour la meme raison : a quatre voxels par bloc, une metaballe echantillonnee
rend un tas de cubes, une courbe de Blender rend une ligne de cubes, et le
detour par `bpy` n'apporte plus rien. Le module de formes est `flore_blocs`.

Le lot est **deterministe** : une graine en dur par fichier, ecrite dans `LOT`.
Regenerer ne deplace rien, et retoucher un modele ne change pas les autres.

-- Ce qui est dessine ici -----------------------------------------------------

* **l'echelle.** Un bloc de terrain vaut **4 voxels**, le personnage de
  reference en fait 9,6. Une constante ecrite ici est donc un quart de bloc :
  `hauteur=9` se lit « a l'epaule ». Le plafond verifie par
  `tests/flora_test.gd` est de 4 blocs de haut et 2 de rayon, soit 16 et 8
  voxels (`flore_vox.HAUTEUR_MAX`, `RAYON_MAX`).
* **la matiere est mince.** Une touffe est faite de brins d'un voxel, pas d'un
  volume vert ; seuls les cactus, les buissons et les champignons sont pleins.
* **les index.** Le moteur lit un index de palette, jamais une couleur.
  `flore_vox.verifie` refuse a l'ecriture tout ce qui sort des plages
  vegetation (128-175) et terrain (1-11, 14-31).

-- Le changement de maille, 2026-09-06 ----------------------------------------

Le lot etait dessine a **40/3 voxels par bloc** — l'echelle du decor relevee
dans l'original, 0,075 = 3/40. Elle est ecartee, et il faut dire dans quel sens :
la mesure n'est pas contestee, c'est **le rendu qui la refuse**. Un brin de 0,08
bloc a cote d'un cube de terrain d'un bloc ne lit pas comme un cube, il lit
comme un cheveu, et une prairie entiere comme une fourrure. Vu en jeu le
2026-09-06 ; la note complete est sur `CWVoxelModel.VOXELS_PER_BLOCK_FLORE`.

**Les formes sont repensees, pas reduites.** Diviser les anciennes par trois
aurait donne des moignons — c'est mot pour mot ce que le lot d'arbres avait
appris trois jours plus tot (`nextsteps.md`, Sec. 6.2). Une touffe est cinq
brins de sept voxels ; une fleur, une tige et une croix de trois ; une fougere,
cinq arcs. Ce qui **ne change pas** est la taille en blocs : une touffe fait
toujours 1,75 bloc de haut, dessinee avec sept voxels au lieu de vingt-trois.

-- Et deux retraits, le meme jour ---------------------------------------------

**Le lot n'a plus de caillou.** Les quatre blocs erratiques sont supprimes, et
avec eux le role `CAILLOU` : disperses a la densite de la flore, ils rendaient
des champs de rochers ou un joueur ne passait plus. Le mineral pose du monde est
`arbres/greenlands/rocher_geant`, qui passe par la couche des arbres — donc a
14 blocs d'espacement et au poids 0,05.

**Et plus d'herbe seche comme matiere de sol** : `CWPalette.GRASS_DRY` est
retire. Les deux modeles de Greenlands qui puisaient dans la rampe « automne »
(140-147) — `herbe_seche` et `broussaille` — passent sur la rampe de feuillage.
Un sol vert avec des taches orange etait le meme defaut que l'invariant n° 29,
transpose de Snowlands a Greenlands. La rampe automne reste employee la ou elle
decrit vraiment la plante : la broussaille seche et le cotonnier du desert.
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import flore_vox as fv
import flore_blocs as fb
from flore_vox import Grille, teinte


# La plage des effets, ouverte au seul champignon luisant. Un lot passe toujours
# l'ensemble d'index le plus etroit qui lui suffit, et c'est ce qui fait du
# garde-fou de `flore_vox.verifie` autre chose qu'une formalite.
INDEX_LUISANT = frozenset(set(fv.INDEX_VALIDES) | set(range(240, 248)))


# =============================================================================
# greenlands/ — la prairie temperee
# =============================================================================

def herbe_01(g, rng):
    """La touffe de reference : cinq brins a l'epaule, 1,75 bloc."""
    fb.touffe(g, rng, 5, 10.5, 4.5, 128, 133, epais_bas=True)


def herbe_02(g, rng):
    """Plus haute et plus ouverte : la touffe des creux humides."""
    fb.touffe(g, rng, 5, 12.0, 5.4, 129, 136, epais_bas=True)


def herbe_03(g, rng):
    """Basse et etalee : celle qui fait le tapis entre les autres."""
    fb.touffe(g, rng, 6, 7.5, 4.8, 128, 136, epais_bas=True)


def herbe_seche(g, rng):
    """Une touffe raide, dressee, aux brins peu courbes.

    **Verdie le 2026-09-06.** Elle tirait sur la rampe automne, ce qui se
    justifiait tant qu'existait un sol d'herbe seche ; ce sol est retire, et une
    touffe orange sur une prairie verte etait la seule tache chaude du paysage.
    Sa silhouette suffit a la distinguer : des brins droits, pas des arcs.
    """
    a0 = rng.uniform(0.0, math.tau)
    for i in range(5):
        a = a0 + math.tau * i / 5 + rng.uniform(-0.4, 0.4)
        fb.brin(g, rng, math.cos(a) * 0.6, math.sin(a) * 0.6,
                12.0 * rng.uniform(0.75, 1.0), 133, 139, azim=a, courbe=3.3,
                epais_bas=True)


def fleur_bleuet(g, rng):
    """Une tige et une croix bleue : la fleur de champ, un bloc."""
    sommet = fb.tige(g, rng, 4.5, 134, 137, penche=0.7)
    fb.corolle(g, sommet, 1.5, 160, coeur=161)


def fleur_tournesol(g, rng):
    """La grande fleur jaune : deux blocs, un coeur brun."""
    sommet = fb.tige(g, rng, 10.5, 132, 137, penche=1.0)
    fb.corolle(g, sommet, 2.4, 158, coeur=148)
    # Deux feuilles a mi-tige : sans elles, c'est une epingle.
    for k in (0, 1):
        a = rng.uniform(0.0, math.tau)
        for d in (1.0, 2.0):
            g.pose(math.cos(a) * d, math.sin(a) * d, 3 + k * 3,
                   teinte(132, 136, 0.6))


def fleur_coeur(g, rng):
    """La fleur rouge a coeur clair, un bloc et demi."""
    sommet = fb.tige(g, rng, 7.5, 132, 136, penche=0.9)
    fb.corolle(g, sommet, 1.5, 156, coeur=157)


def ginseng(g, rng):
    """Une tige et une ombelle grenee : le rare de Greenlands."""
    sommet = fb.tige(g, rng, 6.0, 136, 139, penche=0.7)
    fb.ombelle(g, rng, sommet, 8, 2.7, 158)
    g.pose(sommet[0], sommet[1], sommet[2], 159)


def buisson(g, rng):
    """Une masse de feuillage sur un pied court : un bloc et demi."""
    fb.masse(g, rng, 6.5, 6.5, 128, 137, creux=1.0, grene=0.3)
    g.pose(0, 0, 0, teinte(148, 151, 0.4))


def scrub(g, rng):
    """Des branches nues qui portent peu de feuilles : le buisson maigre."""
    bouts = fb.rameaux(g, rng, 5, 3.5, 151, 154, ouverture=0.9)
    for (x, y, z) in bouts:
        for _ in range(2):
            g.pose(x + rng.choice((-1, 0, 1)), y + rng.choice((-1, 0, 1)),
                   z + rng.choice((0, 1)), teinte(133, 137, rng.random()))


def broussaille(g, rng):
    """Une broussaille basse et large : des rameaux et leur feuillage.

    **Verdie le 2026-09-06**, pour la meme raison que `herbe_seche` : elle etait
    l'autre tache chaude de la prairie. Elle garde son ecorce sombre, qui est ce
    qui la distingue du buisson.
    """
    bouts = fb.rameaux(g, rng, 6, 3.0, 148, 151, ouverture=1.4)
    for (x, y, z) in bouts:
        for _ in range(3):
            g.pose(x + rng.choice((-1, 0, 1)), y + rng.choice((-1, 0, 1)),
                   z + rng.choice((-1, 0, 1)), teinte(133, 139, rng.random()))


def fougere(g, rng):
    """Cinq frondes en arc : la plante haute du sous-bois, plus de trois blocs."""
    a0 = rng.uniform(0.0, math.tau)
    for i in range(5):
        fb.fronde(g, rng, 16.0, 4.5, 129, 135,
                  azim=a0 + math.tau * i / 5 + rng.uniform(-0.3, 0.3))


# =============================================================================
# snowlands/ — le froid
# =============================================================================

def herbe_gelee(g, rng):
    """Une touffe courte et serree, prise dans le gel."""
    fb.touffe(g, rng, 4, 9.0, 1.8, 136, 139, epais_bas=True)
    fb.neige_dessus(g, rng, part=0.6)


def fleur_de_glace(g, rng):
    """Une tige pale et une corolle bleue."""
    sommet = fb.tige(g, rng, 7.5, 136, 139, penche=0.7)
    fb.corolle(g, sommet, 1.5, 161, coeur=160)


def buisson_neige(g, rng):
    """Une masse basse, blanchie sur le dessus."""
    fb.masse(g, rng, 6.5, 6.5, 136, 139, creux=1.0, grene=0.3)
    fb.neige_dessus(g, rng, part=0.85)


def snowberry(g, rng):
    """Un buisson bas et ses baies blanches.

    **Les baies etaient dedans.** Tirees a un rayon de 1 a 2,4 dans une masse
    large de six, elles tombaient sous la peau : le buisson sortait uni, et la
    planche du 2026-09-06 l'a lu comme un caillou moussu. `fb.semis` les pose
    maintenant a l'exterieur.
    """
    fb.masse(g, rng, 6.0, 4.0, 137, 139, grene=0.35)
    fb.semis(g, rng, 6, 14, hauteur_min=1.0)


def cotonnier_neige(g, rng):
    """Des tiges raides et leurs capsules blanches."""
    bouts = fb.rameaux(g, rng, 4, 5.0, 152, 155, ouverture=0.45)
    for (x, y, z) in bouts:
        g.pose(x, y, z, 14)
        g.pose(x, y, z + 1, 15)


# =============================================================================
# deserts/ — le chaud et le sec
# =============================================================================

def cactus_01(g, rng):
    """Le saguaro : quatre blocs de fut cannele, deux bras, des areoles.

    **Refait le 2026-09-06**, et c'est le seul modele du lot a qui la refonte
    des arbres a laisse une place a prendre. Le desert avait deux cactus : le
    `cactus_geant` de la couche des arbres, dessine a un voxel par bloc, et
    celui-ci. Le premier est retire — a la maille du bloc, un saguaro n'a ni
    cannelure ni epine, il a la forme que la grille lui laisse — et c'est donc
    **ici** que le desert doit trouver sa silhouette. Il monte a quatre blocs,
    le plafond de la flore, ce qui le rend plus grand qu'un personnage sans
    faire de lui un arbre.

    Trois choses le distinguent d'un poteau vert, et aucune ne coute cher :

      1. **les cannelures.** `colonne_cannelee` prend sa teinte sur l'azimut :
         quatre cretes claires, quatre sillons sombres, sur toute la hauteur.
         C'est ce qui se lit de loin ;
      2. **le fuselage.** Le pied fait un voxel et demi de rayon, la cime un.
         Un cactus qui ne s'affine pas est un tuyau ;
      3. **les bras a des hauteurs differentes.** Deux coudes au meme niveau
         rendent un chandelier symetrique, qui est exactement le cliche qu'on
         cherche a eviter. Ils partent de 4 et de 7, et le plus bas monte le
         plus haut sans jamais depasser la cime — un bras qui double le fut
         casse la silhouette.

    > **Le fut est mince parce que les bras en dependent.** Premier essai, fut
    > a deux voxels de rayon et bras a trois : les deux premiers voxels du coude
    > tombaient *dans* le fut, et le bras se posait contre lui sans un voxel
    > d'air entre les deux. Il n'y avait donc pas de bras, seulement une bosse.
    > Ce qui fait lire un saguaro n'est pas le bras, c'est **le jour qu'on voit
    > entre le bras et le fut** — d'ou un fut de trois voxels de large et un
    > coude qui va chercher son bras deux voxels plus loin qu'il n'en a besoin.
    """
    fb.colonne_cannelee(g, rng, 16, 1.5, 1.1, 172, 175)
    a0 = rng.uniform(0.0, math.tau)
    for cote, base, monte in ((0.0, 4, 8), (math.pi, 7, 5)):
        a = a0 + cote + rng.uniform(-0.5, 0.5)
        cx, cy = math.cos(a), math.sin(a)
        # Le coude : deux voxels d'epaisseur, sinon il disparait contre le fut.
        for k in range(1, 5):
            for dz in (0, 1):
                g.pose(cx * k, cy * k, base + dz,
                       teinte(172, 175, 0.55 - 0.15 * dz))
        fb.colonne_cannelee(g, rng, monte, 1.0, 1.0, 172, 175,
                            x0=cx * 4, y0=cy * 4, depuis=base + 1)
    fb.epines(g, rng, part=0.07)


def cactus_02(g, rng):
    """Le figuier de barbarie : trois raquettes empilees et leurs fruits.

    **Refait le 2026-09-06.** C'etait un tonneau — une `colonne_pleine` de deux
    blocs coiffee de deux voxels de fleur —, et un tonneau a cette grille est un
    seau : la planche de validation ne pouvait pas le lire autrement, un
    cylindre de huit de haut sur quatre de large n'ayant aucun trait a montrer.

    L'oponce resout les deux problemes a la fois. Il donne au desert la seule
    silhouette **large et basse** de son lot, ce qui le distingue enfin du
    saguaro au lieu d'en etre une version courte ; et c'est deja le nom que la
    table de recolte lui donne — `CWFloraDrops` rend « prickly pear » pour les
    deux cactus depuis le jalon 1.7, sans qu'aucun des deux modeles n'en ait
    jamais eu la forme.

    Les trois raquettes se recouvrent volontairement d'un voxel ou deux : c'est
    ainsi qu'elles poussent, et c'est aussi ce qui evite a la passe de soudure
    d'inventer un petiole entre deux palettes qui n'en ont pas.
    """
    a0 = rng.uniform(0.0, math.tau)
    ux, uy = math.cos(a0), math.sin(a0)
    # La raquette de pied, la plus grande, posee sur sa tranche.
    fb.raquette(g, rng, 0, 0, 4, a0, 3.4, 4.0, 172, 175, epaisseur=2)
    # Les deux filles, en haut de sa tranche, chacune vrillee de son cote : deux
    # raquettes dans le meme plan rendraient une planche.
    fb.raquette(g, rng, ux * 2.2, uy * 2.2, 9, a0 + rng.uniform(0.5, 0.9),
                2.8, 3.2, 172, 175, epaisseur=2)
    fb.raquette(g, rng, -ux * 2.0, -uy * 2.0, 8, a0 - rng.uniform(0.6, 1.0),
                2.3, 2.7, 172, 175, epaisseur=2)
    fb.epines(g, rng, part=0.07)
    # Les figues, sur la tranche haute des raquettes et nulle part ailleurs.
    fb.semis(g, rng, 5, 156, hauteur_min=9.0, lateral=False)


def broussaille_seche(g, rng):
    """Des rameaux secs, sans feuille. La rampe automne est ici a sa place."""
    fb.rameaux(g, rng, 6, 3.2, 141, 146, ouverture=1.2)


def cotonnier_desert(g, rng):
    """Le cotonnier du desert : des tiges seches et leurs capsules."""
    bouts = fb.rameaux(g, rng, 4, 5.0, 142, 146, ouverture=0.5)
    for (x, y, z) in bouts:
        g.pose(x, y, z, 14)
        g.pose(x, y, z + 1, 15)


def habanero(g, rng):
    """Un buisson bas et ses piments rouges : le rare du desert."""
    fb.masse(g, rng, 5.0, 4.0, 129, 134, grene=0.3)
    # Sur la peau, et non dans la masse : voir `snowberry`.
    fb.semis(g, rng, 6, 156)


# =============================================================================
# jungles/ — le chaud et l'humide
# =============================================================================

def feuille_large(g, rng):
    """Trois grandes feuilles depuis une souche basse."""
    a0 = rng.uniform(0.0, math.tau)
    for i in range(3):
        fb.feuille(g, rng, 5.0, 6.0, 128, 133,
                   azim=a0 + math.tau * i / 3 + rng.uniform(-0.3, 0.3),
                   epaisseur=3)


def fougere_geante(g, rng):
    """La grande fougere de jungle : trois blocs, cinq frondes."""
    a0 = rng.uniform(0.0, math.tau)
    for i in range(5):
        fb.fronde(g, rng, 15.0, 5.0, 128, 134,
                  azim=a0 + math.tau * i / 5 + rng.uniform(-0.3, 0.3))


def liane(g, rng):
    """Une liane dressee : une tige haute et ses feuilles etagees."""
    a = rng.uniform(0.0, math.tau)
    for z in range(10):
        t = z / 9.0
        g.pose(math.cos(a) * t * 1.2, math.sin(a) * t * 1.2, z,
               teinte(128, 134, 0.25 + 0.6 * t))
        if z % 3 == 1:
            b = a + rng.uniform(1.5, 4.5)
            g.pose(math.cos(b) * 2.2, math.sin(b) * 2.2, z,
                   teinte(129, 133, 0.7))


def vrille(g, rng):
    """Une vrille qui s'enroule : deux blocs et demi, en spirale."""
    a = rng.uniform(0.0, math.tau)
    for z in range(10):
        t = z / 9.0
        r = 1.6 * (1.0 - 0.5 * t)
        g.pose(math.cos(a + t * 6.0) * r, math.sin(a + t * 6.0) * r, z,
               teinte(128, 133, 0.25 + 0.65 * t))


def lierre_jungle(g, rng):
    """Du lierre rampant : large et bas, il couvre le sol."""
    a0 = rng.uniform(0.0, math.tau)
    for i in range(5):
        a = a0 + math.tau * i / 5 + rng.uniform(-0.4, 0.4)
        lg = rng.uniform(4.0, 6.0)
        # Deux echantillons par voxel : la tige monte de 4,5 sur cinq pas
        # horizontaux, donc un pas par voxel de longueur laissait des trous.
        # C'est la meme cause que les frondes de fougere (`fb.fronde`).
        n = int(lg * 2)
        for k in range(n + 1):
            t = k / float(n)
            g.pose(math.cos(a) * lg * t, math.sin(a) * lg * t,
                   1.0 + 4.5 * t * t, teinte(129, 134, 0.3 + 0.5 * t))


def fleur_coeur_jungle(g, rng):
    """La fleur rouge de jungle, sur une tige plus longue."""
    sommet = fb.tige(g, rng, 7.5, 132, 136, penche=1.0)
    fb.corolle(g, sommet, 1.8, 156, coeur=157)


def fleur_ame(g, rng):
    """Une fleur violette et etroite : le rare de la jungle humide."""
    sommet = fb.tige(g, rng, 7.5, 136, 139, penche=0.6)
    fb.corolle(g, sommet, 1.5, 162, coeur=163)


def roseau(g, rng):
    """Quatre tiges droites : le roseau du sol humide, plus de deux blocs.

    Ses brins sont **droits** — c'est ce qui le separe d'une touffe d'herbe a
    cette resolution, ou la courbe est le seul trait qui reste.
    """
    a0 = rng.uniform(0.0, math.tau)
    for i in range(4):
        a = a0 + math.tau * i / 4 + rng.uniform(-0.5, 0.5)
        r = rng.uniform(0.0, 1.0)
        fb.brin(g, rng, math.cos(a) * r, math.sin(a) * r,
                13.5 * rng.uniform(0.8, 1.0), 138, 143, azim=a, courbe=0.6,
                epais_bas=True)


def champignon_jungle(g, rng):
    """Un champignon de sous-bois : un stipe et un chapeau."""
    fb.colonne_pleine(g, rng, 3.0, 0.6, 166, 168)
    fb.chapeau(g, rng, 3, 2.0, 164, 167, bombe=1)


# =============================================================================
# lavalands/ — le volcanique
# =============================================================================

def fire_shrub(g, rng):
    """Un buisson de scorie parcouru d'une veine incandescente."""
    fb.masse(g, rng, 6.5, 6.5, 25, 27, creux=1.0, grene=0.35)
    # Douze braises sur la peau. La version precedente en tirait cinq **dans**
    # la masse, ou rien ne les voyait : le modele sortait noir uni, et la
    # planche du 2026-09-06 l'a pris pour un rocher.
    fb.semis(g, rng, 12, 30, hauteur_min=2.0, dehors=False)


def herbe_de_lave(g, rng):
    """Une touffe noire aux pointes rouges : elle brule par le haut."""
    a0 = rng.uniform(0.0, math.tau)
    for i in range(4):
        a = a0 + math.tau * i / 4 + rng.uniform(-0.4, 0.4)
        h = int(round(9.0 * rng.uniform(0.7, 1.0)))
        fb.brin(g, rng, math.cos(a) * 0.75, math.sin(a) * 0.75, h, 25, 27,
                azim=a, courbe=2.1, epais_bas=True)
    for (x, y, z) in list(g.v):
        if (x, y, z + 1) not in g.v and z > 3:
            g.v[(x, y, z)] = 30


def fleur_de_lave(g, rng):
    """Une tige de scorie et un bourgeon de braise."""
    sommet = fb.tige(g, rng, 6.0, 25, 27, penche=0.45)
    fb.corolle(g, sommet, 1.5, 30, coeur=31)
    g.pose(sommet[0], sommet[1], sommet[2] + 1, 30)


def champignon_luisant(g, rng):
    """Le champignon qui eclaire : son chapeau est dans la plage des effets."""
    fb.colonne_pleine(g, rng, 3.0, 0.6, 166, 168)
    fb.chapeau(g, rng, 3, 1.8, 240, 243, bombe=1)


# =============================================================================
# oceans/ — le fond marin
# =============================================================================

def algue(g, rng):
    """Une algue haute et ondulante : deux blocs et quart."""
    a0 = rng.uniform(0.0, math.tau)
    for i in range(3):
        a = a0 + math.tau * i / 3 + rng.uniform(-0.5, 0.5)
        for z in range(9):
            t = z / 8.0
            g.pose(math.cos(a + t * 2.5) * (0.6 + 1.4 * t),
                   math.sin(a + t * 2.5) * (0.6 + 1.4 * t), z,
                   teinte(130, 133, 0.3 + 0.6 * t))


def corail(g, rng):
    """Un corail branchu : deux teintes, et rien d'autre."""
    bouts = fb.rameaux(g, rng, 5, 4.0, 170, 171, ouverture=0.8)
    for (x, y, z) in bouts:
        g.pose(x, y, z + 1, 170)


def etoile_de_mer(g, rng):
    """Cinq bras poses a plat : un demi-bloc de haut."""
    a0 = rng.uniform(0.0, math.tau)
    for i in range(5):
        a = a0 + math.tau * i / 5
        for k in range(2):
            g.pose(math.cos(a) * (k + 1), math.sin(a) * (k + 1), 0,
                   teinte(156, 157, 0.4 + 0.4 * k))
    g.pose(0, 0, 0, 157)
    g.pose(0, 0, 1, 156)


# Les deux grilles du lot. **Elles doivent dire la meme chose que
# `CWModelLibrary.GRILLE_FINE`** : le generateur dessine a la grille qu'il croit,
# le moteur instancie a celle qu'il lit de son cote. S'ils divergent, le modele
# sort a une taille fausse d'un facteur un et demi — assez pour se voir, pas
# assez pour qu'on sache pourquoi.
GROS = 4.0   # buissons, cactus, champignons, fougeres, coraux : des masses
FIN = 6.0    # herbes et fleurs : des objets dont la forme tient dans un trait

# (dossier, nom, graine, fonction, grille[, index autorises]). La graine est en
# dur : le lot se regenere a l'identique, et retoucher un modele ne deplace pas
# les autres. Les graines sont reprises des lots precedents la ou le modele
# existait deja — un modele qu'on n'a pas voulu changer ne doit pas changer.
LOT = [
    ("greenlands", "herbe_01", 1001, herbe_01, FIN),
    ("greenlands", "herbe_02", 1002, herbe_02, FIN),
    ("greenlands", "herbe_03", 1003, herbe_03, FIN),
    ("greenlands", "herbe_seche", 1004, herbe_seche, FIN),
    ("greenlands", "fleur_bleuet", 1006, fleur_bleuet, FIN),
    ("greenlands", "fleur_tournesol", 1007, fleur_tournesol, FIN),
    ("greenlands", "fleur_coeur", 1011, fleur_coeur, FIN),
    ("greenlands", "ginseng", 1012, ginseng, FIN),
    ("greenlands", "buisson", 1008, buisson, GROS),
    ("greenlands", "scrub", 1013, scrub, GROS),
    ("greenlands", "broussaille", 1014, broussaille, GROS),
    ("greenlands", "fougere", 1015, fougere, GROS),

    ("snowlands", "herbe_gelee", 2001, herbe_gelee, FIN),
    ("snowlands", "fleur_de_glace", 2002, fleur_de_glace, FIN),
    ("snowlands", "buisson_neige", 2003, buisson_neige, GROS),
    ("snowlands", "snowberry", 2004, snowberry, GROS),
    ("snowlands", "cotonnier", 2005, cotonnier_neige, GROS),

    ("deserts", "cactus_01", 5001, cactus_01, GROS),
    ("deserts", "cactus_02", 5002, cactus_02, GROS),
    ("deserts", "broussaille_seche", 5003, broussaille_seche, GROS),
    ("deserts", "cotonnier", 5005, cotonnier_desert, GROS),
    ("deserts", "habanero", 5006, habanero, GROS),

    ("jungles", "feuille_large", 3004, feuille_large, GROS),
    ("jungles", "fougere_geante", 3007, fougere_geante, GROS),
    ("jungles", "liane", 3001, liane, GROS),
    ("jungles", "vrille", 3002, vrille, GROS),
    ("jungles", "lierre", 3003, lierre_jungle, GROS),
    ("jungles", "fleur_coeur", 3005, fleur_coeur_jungle, FIN),
    ("jungles", "fleur_ame", 4004, fleur_ame, FIN),
    ("jungles", "roseau", 4001, roseau, FIN),
    ("jungles", "champignon", 3006, champignon_jungle, GROS),

    ("lavalands", "fire_shrub", 6101, fire_shrub, GROS),
    ("lavalands", "herbe_de_lave", 6102, herbe_de_lave, FIN),
    ("lavalands", "fleur_de_lave", 6103, fleur_de_lave, FIN),
    ("lavalands", "champignon_luisant", 6105, champignon_luisant, GROS,
     INDEX_LUISANT),

    ("oceans", "algue", 9001, algue, GROS),
    ("oceans", "corail", 9002, corail, GROS),
    ("oceans", "etoile_de_mer", 9003, etoile_de_mer, GROS),
]


def main(argv):
    seul = None
    if "--seul" in argv:
        seul = argv[argv.index("--seul") + 1]
    bloc = fv.lit_bloc_rgba()
    dossier_courant = None
    fait = 0
    for entree in LOT:
        dossier, nom, graine, f, grille = entree[:5]
        indices = entree[5] if len(entree) > 5 else None
        if seul is not None and seul not in (nom, "%s/%s" % (dossier, nom)):
            continue
        if dossier != dossier_courant:
            print("[%s/]" % dossier)
            dossier_courant = dossier
        g = Grille()
        f(g, random.Random(graine))
        fv.ecris(dossier, nom, g, bloc, indices=indices,
                 plafond=fv.plafond_de(grille))
        fait += 1
    print("%d modele(s) ecrit(s) dans %s" % (fait, fv.SORTIE))


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    main(argv)
