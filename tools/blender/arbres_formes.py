"""Primitives propres au lot d'arbres : futs, charpentes, frondaisons, palmes.

Meme partage que pour la flore : ce qui est generique est dans
`flore_formes.py` (brins, feuilles, ellipsoides, rampes) et dans
`flore_blender.py` (courbes a rayon variable, metaballes, echantillonnage), ce
qui est propre au lot est ici. Rien n'est recopie de la flore.

Trois choses seulement changent par rapport a la flore, et elles sont toutes
dans ce module (`docs/prompt_generation_arbres.md`, Sec. 1) :

* **le fut.** C'est la seule matiere massive du lot : 2 a 4 voxels de section a
  la base. Il est trace par `flore_blender.courbe`, qui module le biseau point
  par point ;
* **la frondaison est une coquille.** Des paquets de feuillage sur le pourtour,
  du vide au milieu. Un arbre plein est un rocher vert ;
* **pas de symetrie d'ordre 4.** Les quatre quarts de tour sont appliques a la
  pose : les azimuts avancent ici du tour d'or (2,399 rad), jamais d'un pas
  regulier, et un etage sur deux est decale.

Le module ne depend pas de `bpy` : `flore_blender` lui est passe en argument
par l'appelant, ce qui garde les fonctions purement Python testables hors de
Blender.
"""

import math

import flore_formes as ff
from flore_vox import teinte

# L'angle d'or en radians. Un pas d'azimut qui ne retombe jamais sur lui-meme,
# donc jamais sur un quart de tour.
TOUR_DOR = 2.39996


# -- Charpente ----------------------------------------------------------------

def fut_points(rng, hauteur, azimut, penche=0.0, segments=9, sinuosite=0.03,
               Vector=None):
    """Les points d'un fut, du pied vers la cime.

    La deviation croit en `t^2` : le pied reste d'aplomb et c'est la tete qui
    part, ce qui est la forme d'un tronc pousse au vent. La sinuosite est
    perpendiculaire a la penche, pour que le fut ne soit pas un segment.

    `penche` reste faible sur un arbre entier, et ce n'est pas un gout :
    l'ancre d'un modele est le **centre de son gabarit**, pas son pied
    (`CWVoxelModel.load_from`), donc un fut trop penche pose l'arbre a cote de
    son propre tronc.
    """
    dx, dy = math.cos(azimut), math.sin(azimut)
    phase = rng.uniform(0.0, math.tau)
    amp = sinuosite * hauteur
    pts = []
    for i in range(segments + 1):
        t = i / segments
        d = penche * hauteur * t * t
        w = amp * math.sin(t * 2.6 + phase) * t
        p = (dx * d - dy * w, dy * d + dx * w, hauteur * t)
        pts.append(Vector(p) if Vector is not None else p)
    return pts


def axe_a(fut, z):
    """Le point du fut a la hauteur `z`, par interpolation lineaire.

    Sert a raccrocher au tronc ce qui n'est pas trace avec lui : les anneaux
    d'un stipe, la couronne de palmes d'un dattier.
    """
    for i in range(len(fut) - 1):
        a, b = fut[i], fut[i + 1]
        if a[2] <= z <= b[2]:
            u = 0.0 if b[2] - a[2] < 1e-6 else (z - a[2]) / (b[2] - a[2])
            return (a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u, z)
    return (fut[-1][0], fut[-1][1], z)


def charpente(rng, fb, fut, depart_t, nombre, longueur, montee=0.25,
              derive=0.22, inclinaison=(0.55, 1.05), segments=4):
    """Des branches accrochees le long d'un fut, au-dessus de `depart_t`.

    Rend une liste de (points, azimut, longueur) : l'azimut et la longueur
    servent a l'appelant pour accrocher un paquet de feuillage au bout, sans
    avoir a relire la geometrie.
    """
    a0 = rng.uniform(0.0, math.tau)
    n = len(fut) - 1
    out = []
    for i in range(nombre):
        t = depart_t + (1.0 - depart_t) * (i + rng.uniform(0.15, 0.85)) / nombre
        p = fut[min(n, int(round(t * n)))]
        a = a0 + i * TOUR_DOR + rng.uniform(-0.3, 0.3)
        L = longueur * rng.uniform(0.68, 1.18)
        pts = fb.branche(rng, (p[0], p[1], p[2]),
                         ff.azimut(a, rng.uniform(*inclinaison)), L, segments,
                         derive, montee)
        out.append((pts, a, L))
    return out


def anneaux(g, rng, fut, z_bas, z_haut, pas, rayon, clair, sombre):
    """Les cicatrices de palmes d'un stipe : un anneau tous les `pas` voxels.

    Sans elles un tronc de palmier est un tuyau ; c'est a peu pres la seule
    chose qui le distingue d'un fut de feuillu vu a cent blocs.
    """
    z = z_bas
    k = 0
    while z <= z_haut:
        c = axe_a(fut, z)
        u = (z - z_bas) / max(1.0, z_haut - z_bas)
        r = rayon * (1.0 - 0.45 * u)
        a0 = rng.uniform(0.0, math.tau)
        n = max(6, int(r * 6.0))
        for i in range(n):
            a = a0 + math.tau * i / n
            g.pose_si_vide(c[0] + math.cos(a) * (r + 0.7),
                           c[1] + math.sin(a) * (r + 0.7), z,
                           teinte(clair, sombre, 0.1 if k % 2 else 0.65))
        z += pas
        k += 1


# -- Frondaison ---------------------------------------------------------------

def lobes(rng, nombre, rayon_nuage, rayon_lobe, z_bas, z_haut, aplati=1.0,
          debord=1.45, coeur=1.35):
    """Des centres de lobes pour une frondaison en metaballes.

    Les azimuts avancent du tour d'or et les distances au centre sont tirees :
    aucune symetrie, et **un** lobe pousse plus loin que les autres — c'est lui
    qui donne la silhouette franche et asymetrique que demande le prompt, une
    frondaison reguliere se lisant comme une boule.

    Le **coeur** n'est pas un detail. Sans lobe central, les lobes du pourtour
    ne se rejoignent pas et la couronne sort en guirlande : un anneau de billes
    separees, troue au milieu, qui ne lit ni comme un houppier ni comme quoi
    que ce soit. Il faut donc que `rayon_nuage` reste du meme ordre que
    `rayon_lobe` — les lobes doivent se chevaucher — et qu'un lobe central les
    tienne ensemble. La coquille se fait a l'echantillonnage (`masse`), pas en
    ecartant les lobes.
    """
    a0 = rng.uniform(0.0, math.tau)
    # Le lobe qui deborde est tire dans la bande du milieu, jamais au sommet :
    # en haut la couronne est etroite, et un lobe pousse loin s'y detache de la
    # masse au lieu de l'echancrer.
    long_i = rng.randrange(1, max(2, nombre - 1))
    out = []
    if coeur > 0.0:
        out.append((0.0, 0.0, (z_bas + z_haut) * 0.5, rayon_lobe * coeur))
    for i in range(nombre):
        a = a0 + i * TOUR_DOR
        u = (i + 0.5) / nombre
        # Enveloppe en oeuf : etroite au pied, la plus large aux deux
        # cinquiemes, refermee au sommet. Sans elle les lobes hauts partent
        # aussi loin que ceux du milieu et sortent de la masse.
        env = math.sin(math.pi * (0.22 + 0.62 * u))
        d = rayon_nuage * env * (
            debord if i == long_i else 0.35 + 0.65 * math.sqrt(rng.random()))
        z = z_bas + (z_haut - z_bas) * (u ** 0.8) * rng.uniform(0.7, 1.15)
        r = rayon_lobe * rng.uniform(0.72, 1.12)
        out.append((math.cos(a) * d, math.sin(a) * d * aplati, z, r))
    return out


def masse(g, fb, els, clair, sombre, epaisseur=0.62, resolution=0.22,
          depart=0.05, rigide=2.3, marge=1):
    """Une frondaison : des lobes qui fusionnent, gardee en **coquille**.

    C'est ici que Blender paye : une union de spheres laisse des bosses
    recousues, la metaballe donne une masse continue avec des creux entre les
    lobes. `COQUE` n'en garde que le pourtour — un houppier plein serait un
    rocher vert, et peserait dix fois plus de voxels pour la meme silhouette.

    `resolution` est passee de 0,32 a 0,22 le 2026-09-05, apres avoir regarde
    les houppiers en jeu : a 0,32 le maillage de la metaballe est facette a
    l'echelle du voxel, et la coquille echantillonnee dessus sort grumeleuse —
    de loin, un chou-fleur plutot qu'un feuillage. Le cout est une poignee de
    secondes sur la generation du lot, qui n'est pas un chemin critique.
    """
    fb.scene_vide()
    obj = fb.metaballes([((x, y, z), r, rigide) for x, y, z, r in els],
                        resolution)
    return fb.voxelise(g, obj, fb.par_hauteur(clair, sombre, depart),
                       mode=fb.COQUE, epaisseur=epaisseur, marge=marge)


def pousses(g, rng, els, nombre, longueur, clair, sombre, largeur=3.0,
            retombe=0.16):
    """Des feuilles qui sortent de la masse. C'est ce qui separe une frondaison
    d'un dome : le bord doit etre decoupe, pas lisse."""
    for _ in range(nombre):
        x, y, z, r = els[rng.randrange(len(els))]
        a = math.atan2(y, x) + rng.uniform(-1.1, 1.1)
        d = r * rng.uniform(0.75, 1.05)
        ff.feuille(g, (x + math.cos(a) * d, y + math.sin(a) * d,
                       z + rng.uniform(-r * 0.5, r * 0.4)),
                   ff.azimut(a, rng.uniform(1.15, 1.85)),
                   longueur * rng.uniform(0.7, 1.25), largeur, clair, sombre,
                   flechir=lambda t: (0.0, 0.0, -retombe * t))


# -- Conifere -----------------------------------------------------------------

def conifere(g, rng, hauteur, rayon_base, clair, sombre, etages,
             base_z=0.0, tronc=None, retombe=0.34, largeur=(3.4, 6.2),
             longue=1.5):
    """Un sapin : des etages de rameaux plats sur un fut mince.

    Chaque rameau est une lame d'un voxel (`flore_formes.feuille`), large au
    premier tiers et pointue au bout : vue de dessus c'est une branche de
    conifere, vue de cote c'est une jupe. Empilees, elles donnent le cone sans
    jamais remplir de volume — un sapin plein serait un rocher vert de douze
    blocs.

    Les etages sont **decales** d'un tour d'or, leurs rayons sont tires, et un
    rameau par etage depasse de `longue` : un cone regulier rendrait quatre
    fois la meme image aux quatre quarts de tour.
    """
    haut = base_z + hauteur
    if tronc is not None:
        t_clair, t_sombre, r_bas, r_haut = tronc
        z = base_z
        while z < haut - hauteur * 0.12:
            u = (z - base_z) / max(1.0, hauteur)
            g.bille(0.0, 0.0, z, r_bas + (r_haut - r_bas) * u,
                    teinte(t_clair, t_sombre, 0.2 + 0.5 * u))
            z += 0.7
    a = rng.uniform(0.0, math.tau)
    for k in range(etages):
        u = k / max(1, etages - 1)
        z = base_z + hauteur * (0.06 + 0.86 * u)
        r = rayon_base * ((1.0 - u) ** 1.25) * rng.uniform(0.82, 1.1) + 2.0
        n = max(4, int(round(r * 0.85)))
        longue_i = rng.randrange(n)
        for i in range(n):
            a += TOUR_DOR + rng.uniform(-0.25, 0.25)
            L = r * rng.uniform(0.72, 1.05) * (longue if i == longue_i else 1.0)
            w = largeur[0] + (largeur[1] - largeur[0]) * (1.0 - u)
            c = 0.35 + 0.65 * u
            ff.feuille(g, (0.0, 0.0, z + rng.uniform(-0.6, 0.6)),
                       ff.azimut(a, 1.28 + 0.22 * (1.0 - u)), L, w,
                       teinte(clair, sombre, c),
                       teinte(clair, sombre, max(0.0, c - 0.45)),
                       flechir=lambda t: (0.0, 0.0, -retombe * t))
    # La fleche : sans elle le sapin est un cone tronque.
    ff.trace(g, (0.0, 0.0, haut - hauteur * 0.15), (0.0, 0.0, 1.0),
             hauteur * 0.17, lambda t: teinte(clair, sombre, 0.95),
             rayon=lambda t: 1.5 * (1.0 - t))


def neige_dessus(g, rng, part=0.62, seuil_z=0, clair=14, sombre=15):
    """Pose de la neige sur ce qui voit le ciel.

    **La plage vegetation n'a aucun blanc.** Le clair de la rampe de roche nue,
    14-15, est le substitut retenu par le prompt (Sec. 2) ; si le rendu decoit,
    la decision d'ajouter un blanc appartient au projet et deplacerait un
    contrat de palette. Signale, pas decide ici.

    Le critere est geometrique et non pas seulement aleatoire : un voxel prend
    la neige s'il n'a rien au-dessus de lui, c'est-a-dire la ou elle tiendrait.
    """
    dessus = sorted(p for p in g.v
                    if p[2] >= seuil_z and (p[0], p[1], p[2] + 1) not in g.v)
    pris = 0
    for p in dessus:
        if rng.random() < part:
            g.v[p] = clair if rng.random() < 0.6 else sombre
            pris += 1
    return pris


# -- Palme --------------------------------------------------------------------

def fronde(g, rng, depart, azimut, longueur, clair, sombre, inclinaison=0.95,
           retombe=0.16, foliole=(4.5, 9.5), rachis=(1.0, 0.35), pas=0.55,
           balance=0.0, ecart=3, chute=0.34):
    """Une palme : un rachis arque et ses folioles, par paires.

    Une palme est **une fronde seule**, pas un palmier : elle est ancree par
    son point d'attache et vient se poser au sommet d'un stipe. Le rachis part
    vers le haut et retombe de plus en plus — c'est la retombee qui fait la
    palme, droite elle rendrait une plume.

    `ecart` est le pas entre deux paires de folioles, en points de rachis. Il
    ne se met pas a 1 : des folioles a chaque point se rejoignent et la palme
    sort en lame pleine, un concombre vert. Ce sont les creux entre folioles
    qui la font lire comme une palme, et ils doivent survivre a
    l'arrondi sur la grille entiere.

    `balance` est un lacet par pas, et il se compte : la rotation totale vaut a
    peu pres `balance * longueur / 2`. Au-dela de 0,01 la palme s'enroule sur
    elle-meme au lieu de s'incurver.

    Rend les points du rachis, pour y accrocher autre chose.
    """
    dx, dy, dz = ff.azimut(azimut, inclinaison)
    x, y, z = depart
    n = max(6, int(round(longueur / pas)))
    pts = []
    for i in range(n + 1):
        t = i / n
        g.bille(x, y, z, rachis[0] + (rachis[1] - rachis[0]) * t,
                teinte(clair, sombre, 0.2 + 0.5 * (1.0 - t)))
        pts.append((x, y, z, t))
        lat = balance * math.sin(t * 3.4) * pas
        dx, dy, dz = ff.normalise((dx - dy * lat, dy + dx * lat,
                                   dz - retombe * t * pas))
        x += dx * pas
        y += dy * pas
        z += dz * pas
    for (px, py, pz, t) in pts[ecart:-1:ecart]:
        L = foliole[0] + (foliole[1] - foliole[0]) * math.sin(
            math.pi * min(1.0, t * 1.08)) ** 0.7
        for s in (1.0, -1.0):
            a = azimut + s * (1.02 + 0.28 * t)
            ff.trace(g, (px, py, pz), ff.azimut(a, 1.18 + 0.22 * t),
                     L * rng.uniform(0.82, 1.15),
                     lambda u: teinte(clair, sombre, 0.28 + 0.62 * (1.0 - u)),
                     flechir=lambda u: (0.0, 0.0, -chute * u), pas=0.55)
    return pts
