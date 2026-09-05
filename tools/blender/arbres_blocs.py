"""Formes d'arbres a la maille du bloc (jalon 1.12).

Pur Python, **sans bpy** : a un voxel par bloc, Blender n'apporte rien. Une
metaballe echantillonnee a cette resolution rend un tas de cubes ; autant les
poser directement, et c'est ce que fait ce module.

-- Pourquoi un module a part de `arbres_formes` -------------------------------

`arbres_formes.py` dessine a 40/3 voxels par bloc : ses folioles de palme, ses
rameaux de conifere et ses pousses de houppier sont ecrits pour du detail d'un
voxel. Les reduire d'un facteur treize donnerait des moignons — `reduced(2)`
n'aurait pas suffi non plus. **Les formes sont a repenser, pas a reduire**
(`nextsteps.md`, Sec. 6.4), et le resultat est plus simple, pas plus complique :

* un houppier est **quelques dizaines de cubes bien places**, pas une coquille
  de metaballe ;
* un conifere est une **pile de disques plats** d'un bloc d'epaisseur, larges a
  la base — c'est cette superposition qui fait la silhouette sur les captures,
  pas des rameaux ;
* un fut est une colonne de un a trois blocs de section.

Le seul module partage avec le lot de flore est `flore_vox` : la grille creuse,
l'ecriture `.vox`, et le garde-fou de plages. Le plafond, lui, est passe par le
generateur — un arbre ne tient pas sous les 53 voxels de la flore.

-- L'echelle ------------------------------------------------------------------

**Un voxel = un bloc de terrain.** Le personnage fait 2,4 blocs. Un arbre de
l'alpha fait six a dix fois le personnage, soit 15 a 25 blocs, et ses houppiers
10 a 18 blocs de large, **plus larges que hauts**. Ce sont ces nombres-la qu'on
lit directement dans le code ci-dessous : a cette grille, une constante est une
mesure.
"""

import math

from flore_vox import teinte


# -- Primitives ---------------------------------------------------------------

def disque(g, cx, cy, z, r, couleur, plein=True, epaisseur=1.0):
    """Un disque horizontal d'un bloc d'epaisseur.

    `couleur` recoit la distance relative au centre (0 au coeur, 1 au bord) —
    c'est ce qui permet d'assombrir la peripherie d'un etage de conifere sans
    passer par un degre de hauteur.
    """
    n = int(math.ceil(r))
    for dy in range(-n, n + 1):
        for dx in range(-n, n + 1):
            d = math.hypot(dx, dy)
            if d > r:
                continue
            if not plein and d < r - epaisseur:
                continue
            g.pose(cx + dx, cy + dy, z, couleur(d / r if r > 0 else 0.0))


def colonne(g, rng, hauteur, r_bas, r_haut, clair, sombre, penche=0.0,
            azim=None, derive=0.0):
    """Un fut : une pile de disques, du plus large au plus etroit.

    `penche` est le deport horizontal total, en blocs, du sommet par rapport au
    pied. Il reste **petit** et c'est structurel : l'ancre d'un modele est le
    centre de son gabarit, pas le pied du tronc, donc un fut franchement penche
    se poserait a cote de sa propre colonne (`nextsteps.md`, Sec. 7).

    Rend la liste des centres, pour y accrocher une charpente ou une couronne.
    """
    azim = rng.uniform(0.0, math.tau) if azim is None else azim
    centres = []
    for z in range(int(hauteur)):
        t = z / max(1.0, hauteur - 1.0)
        r = r_bas + (r_haut - r_bas) * t
        dx = math.cos(azim) * penche * t
        dy = math.sin(azim) * penche * t
        if derive > 0.0:
            dx += math.sin(t * 3.1) * derive
            dy += math.cos(t * 2.3) * derive
        disque(g, dx, dy, z, r, lambda u, t=t: teinte(clair, sombre,
                                                      0.25 + 0.55 * (1.0 - t)
                                                      + 0.2 * u))
        centres.append((dx, dy, z))
    return centres


def houppier(g, rng, largeur, hauteur, clair, sombre, creux=0.0, bosses=0.22):
    """Un dome en parasol : **plus large que haut**, et c'est la forme.

    Sur les captures du jeu d'origine, un houppier est un chapeau de champignon
    ou un parasol, de 10 a 18 blocs de large pour la moitie de haut. Le lot du
    2026-09-05 les faisait aussi hauts que larges, ce qui rendait des boules :
    des boules empilees font un arbre en brochette, pas une canopee.

    Le dessous est **legerement creuse** (`creux`) : c'est ce qu'on voit d'en
    bas quand on marche sous l'arbre, et un dome plein y montre une soucoupe.
    """
    rx = largeur / 2.0
    rz = hauteur
    ph = rng.uniform(0.0, math.tau)
    ph2 = rng.uniform(0.0, math.tau)
    for z in range(int(math.ceil(rz))):
        # Le profil : large au premier tiers, arrondi au sommet. Une demi-sphere
        # donnerait un dome trop haut et trop regulier.
        t = z / max(1.0, rz - 1.0)
        r = rx * math.sqrt(max(0.0, 1.0 - (0.35 + 0.65 * t) ** 2.4))
        r = max(r, rx * 0.25 * (1.0 - t))
        if r < 0.6:
            continue
        n = int(math.ceil(r)) + 1
        for dy in range(-n, n + 1):
            for dx in range(-n, n + 1):
                a = math.atan2(dy, dx)
                # Le bord est mange irregulierement : un disque net se lit comme
                # un objet fabrique, et le defaut se voit surtout de loin.
                lim = r * (1.0 + bosses * (math.sin(3.0 * a + ph) * 0.6
                                           + math.sin(5.0 * a + ph2) * 0.4))
                d = math.hypot(dx, dy)
                if d > lim:
                    continue
                if creux > 0.0 and z < creux and d < lim * 0.55:
                    continue
                g.pose(dx, dy, z, teinte(clair, sombre,
                                         0.2 + 0.6 * t + 0.25 * (1.0 - d / lim)))


def conifere(g, rng, hauteur, r_base, clair, sombre, etages=6,
             ecorce=(150, 154), fut_r=1.0):
    """Un conifere : un fut, et des plateaux plats empiles.

    « Le conifere devient des disques empiles : sur les captures, ses etages
    sont des plateaux plats et nets d'un bloc d'epaisseur, larges a la base, et
    c'est cette superposition qui fait la silhouette — pas des rameaux »
    (`nextsteps.md`, Sec. 6.4). C'est litteralement ce que fait cette fonction,
    et elle tient en dix lignes la ou la version fine en demandait cinquante.
    """
    # **Le fut s'arrete sous le dernier plateau.** Vu en capture le 2026-09-06 :
    # monte jusqu'au sommet, il ressortait en stub brun au-dessus du feuillage,
    # sur tous les coniferes du monde a la fois. Un conifere ne montre son tronc
    # qu'entre le sol et son premier etage ; au-dessus, il est dans la masse.
    colonne(g, rng, hauteur * 0.82, fut_r + 0.4, fut_r, ecorce[0], ecorce[1])
    z0 = hauteur * 0.20
    dernier = z0
    for i in range(etages):
        t = i / max(1, etages - 1)
        z = z0 + (hauteur - z0 - 2.0) * t
        # Le plus haut etage garde de la matiere : a 0,82 de decroissance il
        # tombait sous le seuil et laissait le sommet nu.
        r = r_base * (1.0 - 0.72 * t) * rng.uniform(0.92, 1.08)
        if r < 0.9:
            continue
        # Deux disques par etage quand il est large : un plateau d'un seul bloc
        # d'epaisseur disparait vu de cote a partir de quinze blocs.
        disque(g, 0, 0, int(z), r,
               lambda u, t=t: teinte(clair, sombre, 0.15 + 0.5 * t + 0.35 * u))
        if r > 2.5:
            disque(g, 0, 0, int(z) + 1, r * 0.72,
                   lambda u, t=t: teinte(clair, sombre, 0.2 + 0.5 * t + 0.3 * u))
        dernier = z
    # La fleche : le sommet d'un conifere est une pointe, pas un plateau. Elle
    # part du dernier etage pose, et non d'une hauteur nominale — sans quoi elle
    # flotte des qu'un etage est refuse par le seuil de rayon.
    #
    # **Elle est conique, pas filaire.** Premiere version, c'etait une colonne
    # d'un voxel de large sur trois de haut : a vingt blocs de distance elle
    # rendait un pieu brun plante au sommet de l'arbre, et on la prenait pour le
    # fut qui depassait. Deux disques qui retrecissent puis un voxel : la pointe
    # se lit comme la fin de la pile d'etages, ce qu'elle est.
    disque(g, 0, 0, int(dernier) + 1, 1.8,
           lambda u: teinte(clair, sombre, 0.6 + 0.3 * u))
    disque(g, 0, 0, int(dernier) + 2, 1.1,
           lambda u: teinte(clair, sombre, 0.75 + 0.2 * u))
    g.pose(0, 0, int(dernier) + 3, teinte(clair, sombre, 0.9))


def palme_paire(g, rng, longueur, clair, sombre, diagonale=False, retombe=0.35):
    """**Deux** frondes opposees, passant par l'ancre.

    -- Pourquoi une paire et non une palme seule ------------------------------

    L'ancre d'un modele est le **centre de son gabarit** et non son point
    d'attache (`CWVoxelModel.load_from`). Une palme dessinee comme une fronde
    unique partant de l'origine se pose donc au sommet du stipe *par son
    milieu* : la moitie de la fronde passe de l'autre cote du tronc. Le defaut
    etait releve a la production du lot precedent — « pour une palme, dont le
    point d'attache est a une extremite, l'ecart est structurel »
    (`nextsteps.md`, Sec. 7) — et il devait attendre un decalage d'attache
    explicite dans l'assembleur.

    Il n'en a plus besoin : une **paire opposee** est centree sur son attache
    par construction. Le modele porte deux frondes, l'assembleur en pose deux a
    quatre, et la couronne a quatre a huit frondes — le compte voulu, sans
    toucher a `CWTreeScatter`.

    `diagonale` tourne la paire de 45 degres. Le moteur ne precalcule que quatre
    quarts de tour ; les deux modeles ensemble donnent huit directions, et c'est
    exactement la raison pour laquelle l'original a `palm-leaf` et
    `palm-leaf-diagonal`.
    """
    a0 = math.pi * 0.25 if diagonale else 0.0
    for s in (0.0, math.pi):
        a = a0 + s
        for i in range(int(longueur)):
            t = i / max(1.0, longueur - 1.0)
            # La fronde monte d'abord, puis retombe : c'est l'arc qui fait la
            # palme. Droite, elle rendrait une planche.
            #
            # Le terme constant n'est pas cosmetique : `Grille.pose` ignore ce
            # qui tombe sous z = 0, et un arc qui plonge sous zero perd sa
            # pointe **en silence**. Premiere version, la palme sortait a deux
            # blocs de haut au lieu de quatre, amputee de sa retombee.
            z = int(round(longueur * 0.38
                          + retombe * longueur * (t - 1.7 * t * t)))
            x = math.cos(a) * (i + 1)
            y = math.sin(a) * (i + 1)
            g.pose(x, y, z, teinte(clair, sombre, 0.2 + 0.7 * (1.0 - t)))
            # Les folioles : un bloc de part et d'autre, la ou la fronde est
            # large. A cette grille, c'est tout ce qu'une foliole peut etre.
            if 0.15 < t < 0.85:
                for c in (-1.0, 1.0):
                    g.pose(x + math.cos(a + math.pi * 0.5) * c,
                           y + math.sin(a + math.pi * 0.5) * c, z,
                           teinte(clair, sombre, 0.35 + 0.5 * (1.0 - t)))


def branches(g, rng, depart, nombre, longueur, clair, sombre, montee=0.45,
             ouverture=1.1):
    """Des branches nues qui partent d'un point. Rend leurs bouts."""
    bouts = []
    a0 = rng.uniform(0.0, math.tau)
    for i in range(nombre):
        a = a0 + math.tau * i / nombre + rng.uniform(-0.4, 0.4)
        L = longueur * rng.uniform(0.7, 1.15)
        dx = math.cos(a) * math.sin(ouverture)
        dy = math.sin(a) * math.sin(ouverture)
        dz = montee
        x, y, z = depart
        for k in range(int(L)):
            x += dx
            y += dy
            z += dz
            g.pose(x, y, z, teinte(clair, sombre, 0.3 + 0.5 * k / max(1.0, L)))
        bouts.append((x, y, z))
    return bouts


def rocher(g, rng, largeur, hauteur, clair, sombre, plis=(2, 3, 5), force=0.28):
    """Un bloc de roche pose au sol : le Giant Rock.

    « Giant Rock : ressemble a l'Arbre de Mana » — c'est un objet de la taille
    d'un arbre, d'ou sa presence dans ce lot et non dans celui de la flore. Un
    caillou de flore fait deux blocs ; celui-ci en fait douze.
    """
    rx = largeur / 2.0
    ph = [rng.uniform(0.0, math.tau) for _ in plis]
    for z in range(int(hauteur)):
        t = z / max(1.0, hauteur - 1.0)
        r = rx * math.sqrt(max(0.05, 1.0 - (0.15 + 0.85 * t) ** 2.0))
        n = int(math.ceil(r)) + 1
        for dy in range(-n, n + 1):
            for dx in range(-n, n + 1):
                a = math.atan2(dy, dx)
                lim = r
                for k, p in enumerate(plis):
                    lim += r * force / len(plis) * math.sin(p * a + ph[k])
                if math.hypot(dx, dy) > lim:
                    continue
                g.pose(dx, dy, z, teinte(clair, sombre, 0.2 + 0.75 * t))
