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


def charpente(g, rng, hauteur, r_bas, r_haut, clair, sombre, branches,
              penche=0.0):
    """Un fut **et ses branches**, pour un grand arbre a plusieurs houppiers.

    -- Ce qui distingue un grand arbre d'un feuillu ---------------------------

    Un feuillu empile un a trois houppiers sur l'axe de son tronc : sa
    silhouette est une colonne coiffee. Un grand arbre porte ses masses **en
    dehors** de son axe, au bout de branches, et c'est ce qui lui donne une
    envergure plutot qu'une hauteur. Il faut donc que le tronc montre les
    branches qui portent les houppiers, sans quoi les masses flottent a cote de
    l'arbre — le defaut du 2026-09-06 sur les palmes, transpose.

    `branches` est la liste des bouts, **en coordonnees Godot** et avant
    rotation : `(dx, dz, dy)`, en blocs depuis la colonne du tronc et depuis sa
    base. La **meme liste, ecrite a l'identique**, est declaree dans
    `CWTreeRules.SPECIES`, qui y pose les houppiers.

    Elles sont en coordonnees Godot et non en coordonnees `.vox` pour une seule
    raison, et elle vaut d'etre dite : l'import fait tourner les axes
    (`vox(x, y, z) -> godot(y, z, x)`), donc une liste ecrite dans le repere du
    fichier serait la meme a **deux axes echanges** pres de celle du moteur. Une
    branche a l'est du modele porterait le houppier au nord. La conversion est
    faite ici, une fois, et les deux listes se relisent l'une contre l'autre sans
    rien transposer de tete. Un test verifie en plus que chaque bout declare
    tombe sur de la matiere du modele charge — le bois y est, ou il n'y est pas.

    La branche est **epaisse de deux voxels** a sa naissance et d'un a son bout :
    a un voxel par bloc, une branche d'un seul bloc de section lit comme une
    file de cubes en l'air (jalon 1.11, l'arbre a epines).
    """
    centres = colonne(g, rng, hauteur, r_bas, r_haut, clair, sombre,
                      penche=penche)
    for (gx, gz, gy) in branches:
        # (vox_x, vox_y, vox_z) = (godot_z, godot_x, godot_y) : voir plus haut.
        bx, by, bz = gz, gx, gy
        n = max(abs(bx), abs(by))
        if n <= 0:
            continue
        # La branche part du fut a la hauteur du bout moins sa montee : elle
        # monte en s'eloignant, comme une branche portante.
        z0 = bz - max(1, n // 3)
        for k in range(n + 1):
            t = k / float(n)
            x = bx * t
            y = by * t
            z = z0 + (bz - z0) * t
            c = teinte(clair, sombre, 0.3 + 0.4 * (1.0 - t))
            g.pose(x, y, z, c)
            # Epaisse pres du tronc : c'est la que le poids passe.
            if k < n * 0.6:
                g.pose(x, y, z - 1, c)
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
    # -- Le fut monte jusqu'au dernier etage pose, et pas plus haut -----------
    #
    # Deux contraintes se sont telescopees le 2026-09-06, et il a fallu une
    # capture en jeu pour les voir toutes les deux :
    #
    #   * un fut qui monte jusqu'au sommet ressort en stub brun **au-dessus** du
    #     feuillage, sur tous les coniferes du monde a la fois ;
    #   * un fut arrete a une **fraction de la hauteur nominale** — c'etait
    #     `hauteur * 0.82`, le remede du matin — laisse un trou des que le pas
    #     entre etages depasse un bloc. Pour le pin, le pas vaut 2,8 blocs : le
    #     fut s'arretait a z = 15, l'avant-dernier etage etait a z = 15 et le
    #     dernier a z = 18. Les deux etages du haut et la fleche flottaient
    #     ensemble, detaches du reste de l'arbre.
    #
    # La seule des deux contraintes qui compte est la premiere, et elle se dit
    # sans fraction : **le fut s'arrete au dernier etage pose**. Il ne depasse
    # pas — l'etage est dessine par-dessus lui et `Grille.pose` ecrase — et il ne
    # laisse pas de trou, quel que soit le pas. D'ou les etages calcules
    # d'abord, le fut ensuite, et le dessin en dernier.
    z0 = hauteur * 0.20
    plateaux = []
    for i in range(etages):
        t = i / max(1, etages - 1)
        z = z0 + (hauteur - z0 - 2.0) * t
        # Le plus haut etage garde de la matiere : a 0,82 de decroissance il
        # tombait sous le seuil et laissait le sommet nu.
        r = r_base * (1.0 - 0.72 * t) * rng.uniform(0.92, 1.08)
        if r < 0.9:
            continue
        plateaux.append((z, r, t))
    dernier = plateaux[-1][0] if plateaux else z0
    premier = plateaux[0][0] if plateaux else z0

    avant_fut = set(g.v)
    # Le rayon haut est **plancheise a 1,0**, ce qui vaut cinq voxels. Sous
    # cette valeur `disque` n'en pose plus qu'un seul, et le fut se reduit a un
    # fil entre deux etages : sur `sapin_enneige`, z = 14 ne portait qu'**un**
    # voxel entre un etage de neuf et un de cinq. C'est la moitie de ce qui
    # faisait lire le sommet comme une boule posee sur un cou.
    colonne(g, rng, int(dernier) + 1, fut_r + 0.4, max(1.0, fut_r),
            ecorce[0], ecorce[1])

    # **Un conifere ne montre son ecorce qu'entre le sol et son premier etage.**
    # Au-dessus, le fut est dans la masse du feuillage, et c'est ce qu'on voit
    # sur les captures. Le pas entre etages vaut deux a trois blocs : sans cette
    # reprise, chaque intervalle laisse voir une colonne brune et l'arbre se lit
    # comme une pile d'assiettes enfilees sur un piquet. Vu en jeu le
    # 2026-09-06, une fois le fut prolonge jusqu'au dernier etage.
    #
    # La reprise se fait ici et non dans `colonne` : c'est le conifere qui a des
    # etages, pas le fut. Elle passe avant le dessin des plateaux, qui ecrasent.
    # Elle ne touche que les voxels que `colonne` vient de poser : un appelant
    # qui aurait deja dessine dans la grille — une souche, un contrefort — ne
    # verrait pas sa matiere repeinte en feuillage.
    for cle in set(g.v) - avant_fut:
        if cle[2] > int(premier):
            g.v[cle] = teinte(clair, sombre, 0.9)

    # Le dernier etage n'est **pas dessine** : la fleche prend sa place. Voir
    # ci-dessous.
    for (z, r, t) in plateaux[:-1]:
        # Deux disques par etage quand il est large : un plateau d'un seul bloc
        # d'epaisseur disparait vu de cote a partir de quinze blocs.
        disque(g, 0, 0, int(z), r,
               lambda u, t=t: teinte(clair, sombre, 0.15 + 0.5 * t + 0.35 * u))
        if r > 2.5:
            disque(g, 0, 0, int(z) + 1, r * 0.72,
                   lambda u, t=t: teinte(clair, sombre, 0.2 + 0.5 * t + 0.3 * u))

    # -- La fleche : conique, et jamais plus large que ce qui la porte --------
    #
    # Vu en jeu le 2026-09-06 : le sommet des coniferes de Snowlands lisait
    # comme une **boule** posee sur un cou. Le profil en Z de `sapin_enneige` le
    # disait mot pour mot — 9, 1, 5, **9**, 5, 1 : la silhouette se pincait a un
    # voxel puis regonflait a neuf.
    #
    # Deux causes, et il fallait les deux :
    #
    #   * le fut se reduisait a un fil entre les deux derniers etages (corrige
    #     plus haut, rayon planche a 1,0) ;
    #   * **la fleche etait plus large que l'etage qui la portait.** Son rayon
    #     etait une constante — 1,8, soit neuf voxels — alors que le dernier
    #     etage d'un conifere fait 1,3 a 1,5, soit cinq a neuf. Une pointe qui
    #     s'elargit avant de se fermer est une boule, par definition.
    #
    # La fleche part donc de l'avant-dernier etage et **remplace le dernier**
    # plutot que de s'ajouter a lui. Deux consequences voulues : ses rayons
    # decroissent strictement, donc la silhouette est monotone du pied a la
    # pointe ; et l'arbre perd exactement **un bloc** de haut, la pointe passant
    # de `dernier + 3` a `dernier + 2`.
    r_ref = plateaux[-2][1] if len(plateaux) > 1 else 1.8
    disque(g, 0, 0, int(dernier), max(1.0, r_ref * 0.55),
           lambda u: teinte(clair, sombre, 0.6 + 0.3 * u))
    disque(g, 0, 0, int(dernier) + 1, max(0.6, r_ref * 0.30),
           lambda u: teinte(clair, sombre, 0.75 + 0.2 * u))
    g.pose(0, 0, int(dernier) + 2, teinte(clair, sombre, 0.9))


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
             ouverture=1.1, epaisse=0):
    """Des branches nues qui partent d'un point. Rend leurs bouts.

    `epaisse` double les `n` premiers blocs de chaque branche, par en dessous.
    A un voxel par bloc, une branche d'un seul bloc de section **disparait**
    contre le ciel : elle lit comme une file de cubes qui flottent, pas comme
    du bois. C'est ce que la planche de validation du 2026-09-06 a montre sur
    l'arbre a epines, seul modele du lot ou la charpente est toute la
    silhouette.
    """
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
            c = teinte(clair, sombre, 0.3 + 0.5 * k / max(1.0, L))
            g.pose(x, y, z, c)
            if k < epaisse:
                g.pose(x, y, z - 1, c)
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
