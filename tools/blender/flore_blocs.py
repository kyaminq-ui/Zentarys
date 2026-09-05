"""Formes de flore basse a **quatre voxels par bloc** (2026-09-06).

Pur Python, sans bpy : a cette resolution une metaballe echantillonnee rend un
tas de cubes, exactement comme pour le lot d'arbres. Autant les poser.

-- Pourquoi un module a part de `flore_formes` --------------------------------

`flore_formes.py` dessine a 40/3 voxels par bloc. Ses brins, ses folioles et ses
corolles sont ecrits pour du detail d'un treizieme de bloc : une touffe y fait
trente voxels de haut et ses lames un voxel d'epaisseur, soit huit centiemes de
bloc. **Les reduire d'un facteur trois donnerait des moignons** — c'est la lecon
du lot d'arbres, ou `reduced(2)` n'aurait pas suffi non plus (`nextsteps.md`,
Sec. 6.2). Les formes sont a repenser, pas a reduire, et le resultat est plus
simple :

* une touffe d'herbe est **cinq brins de sept voxels**, pas trente lames ;
* une fleur de champ est **une tige et trois voxels de corolle** ;
* un buisson est **une masse de cubes evidee**, pas une coquille de metaballe ;
* une fougere est **quatre frondes en arc**, chacune une ligne de voxels.

-- Pourquoi quatre voxels par bloc --------------------------------------------

C'est une decision de rendu, et elle s'ecarte d'une mesure : voir la note de
`CWVoxelModel.VOXELS_PER_BLOCK_FLORE`, qui la porte en entier. En deux lignes :
0,075 = 3/40 est bien l'echelle du decor de l'original, mais un brin de 0,08
bloc a cote d'un cube de terrain d'un bloc lit comme un cheveu, et une prairie
entiere comme une fourrure. A quatre voxels par bloc le grain du decor est celui
du terrain divise par quatre — assez gros pour se voir, assez fin pour qu'une
fleur reste une fleur.

-- Ce que ca change pour qui dessine ------------------------------------------

**Une constante est une mesure**, comme dans `arbres_blocs`. Un nombre ecrit
ici est un quart de bloc : `hauteur=9` se lit « deux blocs et quart », soit une
touffe a l'epaule. Le personnage de reference fait **9,6 voxels** sur cette
grille (2,4 blocs), et c'est le seul repere dont on ait besoin.

L'enveloppe verifiee par `tests/flora_test.gd` est de 4 blocs de haut et 2 de
rayon, soit **16 et 8 voxels** ici (`flore_vox.HAUTEUR_MAX`, `RAYON_MAX`).
"""

import math

from flore_vox import teinte


# -- Primitives ---------------------------------------------------------------

def brin(g, rng, x0, y0, hauteur, clair, sombre, azim=None, courbe=0.55,
         epais_bas=False):
    """Un brin d'herbe : une ligne de voxels qui monte et se couche.

    A cette grille un brin fait **un voxel de section** — c'est deja un quart de
    bloc, l'epaisseur d'un doigt a l'echelle du personnage. Le lot precedent en
    mettait deux pour compenser la finesse ; ici, doubler ferait une lame de
    couteau.

    `courbe` est le deport horizontal total, en voxels, entre le pied et la
    pointe. C'est lui qui fait la difference entre une touffe et une brosse : un
    brin droit lit comme un piquet, et cinq piquets comme une palissade.
    """
    azim = rng.uniform(0.0, math.tau) if azim is None else azim
    h = max(1, int(round(hauteur)))
    for i in range(h):
        t = i / max(1.0, h - 1.0)
        # L'arc part lentement puis s'accelere : une plante flechit du bout, pas
        # du pied. Le carre suffit a le dire a cette resolution.
        d = courbe * t * t
        x = x0 + math.cos(azim) * d
        y = y0 + math.sin(azim) * d
        g.pose(x, y, i, teinte(clair, sombre, 0.25 + 0.7 * t))
        if epais_bas and i < h // 3:
            g.pose(x + math.cos(azim + 1.57), y + math.sin(azim + 1.57), i,
                   teinte(clair, sombre, 0.15 + 0.5 * t))


def touffe(g, rng, brins, hauteur, etale, clair, sombre, epais_bas=False):
    """Une touffe : quelques brins qui partent du meme pied et s'ecartent.

    `brins` tourne autour de **cinq**. C'est le nombre qui est sorti de la
    lecon du 2026-09-06 au matin — « ce qu'on prend pour trop de detail est
    presque toujours trop petit » — et il ne bouge plus : a quatre voxels par
    bloc, onze brins dans une touffe de huit voxels de large se recouvrent
    exactement, et la touffe redevient un bloc plein.
    """
    a0 = rng.uniform(0.0, math.tau)
    for i in range(brins):
        a = a0 + math.tau * i / brins + rng.uniform(-0.5, 0.5)
        r = etale * rng.uniform(0.0, 0.5)
        brin(g, rng, math.cos(a) * r, math.sin(a) * r,
             hauteur * rng.uniform(0.7, 1.0), clair, sombre, azim=a,
             courbe=etale * rng.uniform(0.5, 1.0), epais_bas=epais_bas)


def tige(g, rng, hauteur, clair, sombre, penche=0.8):
    """Une tige droite, presque d'aplomb. Rend le sommet, ou poser la fleur.

    Elle penche **peu** : l'ancre d'un modele est le centre de son gabarit et
    non son pied (`CWVoxelModel.load_from`), donc une tige franchement couchee
    poserait sa fleur a cote de sa propre empreinte.
    """
    a = rng.uniform(0.0, math.tau)
    h = max(1, int(round(hauteur)))
    x = y = 0.0
    for i in range(h):
        t = i / max(1.0, h - 1.0)
        x = math.cos(a) * penche * t * t
        y = math.sin(a) * penche * t * t
        g.pose(x, y, i, teinte(clair, sombre, 0.2 + 0.6 * t))
    return (x, y, h - 1)


def corolle(g, sommet, rayon, couleur, coeur=None):
    """Une fleur : une croix de petales, et un coeur.

    A quatre voxels par bloc une corolle **est** cette croix : cinq voxels pour
    `rayon = 1`, treize pour `rayon = 1.5`. Chercher des petales separes ici
    revient a dessiner sous le pixel.
    """
    x0, y0, z0 = sommet
    n = int(math.ceil(rayon))
    for dy in range(-n, n + 1):
        for dx in range(-n, n + 1):
            if math.hypot(dx, dy) > rayon:
                continue
            g.pose(x0 + dx, y0 + dy, z0, couleur)
    if coeur is not None:
        g.pose(x0, y0, z0, coeur)


def ombelle(g, rng, sommet, n, rayon, couleur):
    """Des baies ou des grains disperses autour d'un sommet, pas une corolle.

    C'est ce qui distingue un ginseng ou un snowberry d'une fleur : le haut de
    la plante est **grene**, quelques voxels detaches, et non un disque plein.
    """
    x0, y0, z0 = sommet
    for i in range(n):
        a = math.tau * i / n + rng.uniform(-0.4, 0.4)
        r = rayon * rng.uniform(0.5, 1.0)
        g.pose(x0 + math.cos(a) * r, y0 + math.sin(a) * r,
               z0 + rng.choice((-1, 0, 0, 1)), couleur)


def masse(g, rng, largeur, hauteur, clair, sombre, creux=0.0, grene=0.25):
    """Un buisson : un ellipsoide de cubes, mange sur les bords.

    `grene` retire une part des voxels de peripherie. Sans lui, un buisson de
    six voxels de large est une **boule pleine et lisse**, ce qui est la seule
    facon de se tromper a cette resolution : le lot d'arbres a montre qu'un
    bord net se lit comme un objet fabrique, et le defaut se voit surtout de
    loin.

    `creux` evide le dessous, ce qu'on voit en passant a cote.
    """
    rx = largeur / 2.0
    rz = hauteur
    for z in range(int(math.ceil(rz))):
        t = z / max(1.0, rz - 1.0)
        # Large au premier tiers, arrondi au sommet : un buisson n'est pas une
        # demi-sphere, il est plus lourd du bas.
        r = rx * math.sqrt(max(0.0, 1.0 - (0.25 + 0.75 * t) ** 2.2))
        if r < 0.5:
            continue
        n = int(math.ceil(r))
        for dy in range(-n, n + 1):
            for dx in range(-n, n + 1):
                d = math.hypot(dx, dy)
                if d > r:
                    continue
                if creux > 0.0 and z < creux and d < r * 0.5:
                    continue
                if d > r - 1.0 and rng.random() < grene:
                    continue
                g.pose(dx, dy, z, teinte(clair, sombre,
                                         0.25 + 0.5 * t + 0.25 * (1.0 - d / r)))


def fronde(g, rng, hauteur, longueur, clair, sombre, azim=None, large=True):
    """Une fronde de fougere : un arc qui monte puis retombe.

    Elle est dessinee **d'un trait**, et `large` lui ajoute un voxel de part et
    d'autre a mi-longueur — la ou une fougere est la plus fournie. C'est tout ce
    qu'une fronde peut porter a quatre voxels par bloc, et c'est assez : ce qui
    fait lire une fougere est la courbe, pas les folioles.
    """
    azim = rng.uniform(0.0, math.tau) if azim is None else azim
    n = max(2, int(round(longueur)))
    for i in range(n):
        t = i / max(1.0, n - 1.0)
        d = longueur * t
        # Monte vite, retombe lentement : le profil d'une crosse deroulee.
        z = hauteur * (1.55 * t - 0.75 * t * t)
        x = math.cos(azim) * d
        y = math.sin(azim) * d
        c = teinte(clair, sombre, 0.3 + 0.6 * (1.0 - t))
        g.pose(x, y, z, c)
        if large and 0.2 < t < 0.8:
            g.pose(x + math.cos(azim + 1.57), y + math.sin(azim + 1.57), z, c)


def feuille(g, rng, longueur, hauteur, clair, sombre, azim=None, epaisseur=2):
    """Une feuille large, posee en oblique : la plante de sous-bois.

    Elle differe d'une fronde par sa **section** : deux ou trois voxels de large
    sur toute sa longueur, ce qui lui donne une surface au lieu d'une ligne.
    """
    azim = rng.uniform(0.0, math.tau) if azim is None else azim
    n = max(2, int(round(longueur)))
    for i in range(n):
        t = i / max(1.0, n - 1.0)
        d = longueur * t
        z = hauteur * (1.4 * t - 0.6 * t * t)
        c = teinte(clair, sombre, 0.25 + 0.65 * (1.0 - t))
        # La feuille s'elargit au milieu et se ferme a la pointe.
        w = epaisseur * math.sin(math.pi * min(1.0, t + 0.15))
        for k in range(int(round(w))):
            dec = (k + 1) // 2 * (1 if k % 2 else -1)
            g.pose(math.cos(azim) * d + math.cos(azim + 1.57) * dec,
                   math.sin(azim) * d + math.sin(azim + 1.57) * dec, z, c)


def colonne_pleine(g, rng, hauteur, rayon, clair, sombre, x0=0.0, y0=0.0):
    """Un fut plein : cactus, stipe de champignon, tige epaisse."""
    h = max(1, int(round(hauteur)))
    n = int(math.ceil(rayon))
    for z in range(h):
        t = z / max(1.0, h - 1.0)
        for dy in range(-n, n + 1):
            for dx in range(-n, n + 1):
                if math.hypot(dx, dy) > rayon:
                    continue
                g.pose(x0 + dx, y0 + dy, z,
                       teinte(clair, sombre, 0.3 + 0.4 * t
                              + 0.3 * (1.0 - math.hypot(dx, dy)
                                       / max(0.5, rayon))))


def chapeau(g, rng, z, rayon, clair, sombre, bombe=1):
    """Un chapeau de champignon : un ou deux disques qui retrecissent."""
    for k in range(bombe + 1):
        r = rayon * (1.0 - 0.45 * k)
        if r < 0.5:
            break
        n = int(math.ceil(r))
        for dy in range(-n, n + 1):
            for dx in range(-n, n + 1):
                d = math.hypot(dx, dy)
                if d > r:
                    continue
                g.pose(dx, dy, z + k,
                       teinte(clair, sombre, 0.3 + 0.25 * k + 0.4 * (1.0 - d / r)))


def rameaux(g, rng, n, longueur, clair, sombre, depuis=0.0, ouverture=0.7):
    """Des branches nues qui partent d'un pied : broussaille, buisson d'hiver.

    Une branche est une ligne de voxels ; a cette grille elle n'a pas de
    section. Ce qui la fait lire est son **inclinaison**, d'ou `ouverture`.
    """
    bouts = []
    a0 = rng.uniform(0.0, math.tau)
    for i in range(n):
        a = a0 + math.tau * i / n + rng.uniform(-0.4, 0.4)
        pente = ouverture * rng.uniform(0.7, 1.3)
        lg = longueur * rng.uniform(0.75, 1.15)
        m = max(2, int(round(lg)))
        x = y = 0.0
        z = depuis
        for k in range(m):
            t = k / max(1.0, m - 1.0)
            x = math.cos(a) * pente * lg * t
            y = math.sin(a) * pente * lg * t
            z = depuis + lg * t
            g.pose(x, y, z, teinte(clair, sombre, 0.25 + 0.6 * t))
        bouts.append((x, y, z))
    return bouts


def neige_dessus(g, rng, part=0.7, index=(14, 15)):
    """Repeint en neige les voxels qui n'ont rien au-dessus d'eux.

    Meme role que `arbres_formes.neige_dessus`, refait ici parce que celui-la
    raisonne sur des epaisseurs de la grille fine. A quatre voxels par bloc la
    neige est **une couche d'un voxel**, et il n'y a pas de demi-mesure.
    """
    for (x, y, z) in list(g.v):
        if (x, y, z + 1) in g.v:
            continue
        if rng.random() < part:
            g.v[(x, y, z)] = index[0] if rng.random() < 0.6 else index[1]
