"""Primitives de dessin pour la flore : brins, tiges, feuilles, cailloux.

Pur Python. Blender n'apporte rien sur ces formes-la — un brin d'herbe est une
ligne d'un voxel d'epaisseur, une etoile de mer cinq segments — et le passage
par une geometrie puis un echantillonnage ne ferait qu'ajouter du bruit. Les
formes qui payent vraiment sous bpy (buissons, cactus, coraux, lianes) sont
dans `flore_blender.py`.

Tout ici est deterministe : les generateurs recoivent leur `random.Random`.
"""

import math

from flore_vox import teinte


def normalise(v):
    n = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])
    if n < 1e-9:
        return (0.0, 0.0, 1.0)
    return (v[0] / n, v[1] / n, v[2] / n)


def azimut(a, inclinaison=0.0):
    """Vecteur unite : `a` en radians autour de Z, `inclinaison` depuis la
    verticale (0 = droit vers le haut)."""
    s = math.sin(inclinaison)
    return (math.cos(a) * s, math.sin(a) * s, math.cos(inclinaison))


def trace(g, depart, direction, longueur, couleur,
          flechir=None, rayon=None, pas=0.4):
    """Marche le long d'une courbe en posant la matiere au fil de l'eau.

    `couleur(t)` rend un index, `flechir(t)` un vecteur ajoute a la direction
    par unite de longueur — c'est lui qui fait l'arc d'un brin ou la retombee
    d'une liane — et `rayon(t)` le rayon de la bille posee, nul par defaut :
    une lame d'un seul voxel. `t` va de 0 (la base) a 1 (la pointe).

    Rend la derniere position, pour y accrocher une fleur ou une feuille.
    """
    x, y, z = depart
    dx, dy, dz = normalise(direction)
    n = max(1, int(round(longueur / pas)))
    for i in range(n + 1):
        t = i / n
        r = rayon(t) if rayon is not None else 0.0
        g.bille(x, y, z, r, couleur(t))
        if flechir is not None:
            f = flechir(t)
            dx, dy, dz = normalise((dx + f[0] * pas, dy + f[1] * pas,
                                    dz + f[2] * pas))
        x += dx * pas
        y += dy * pas
        z += dz * pas
    return (x, y, z)


def brin(g, base, a, longueur, courbure, clair, sombre, pousse=0.0):
    """Un brin : une lame d'un voxel, droite a la base et qui s'incurve.

    `courbure` est le flechissement par unite de longueur ; au-dela de ~0,09 la
    pointe redescend, ce qui est ce qu'on veut d'une herbe haute.
    """
    dirh = (math.cos(a), math.sin(a), 0.0)
    return trace(
        g, (base[0], base[1], base[2]),
        (dirh[0] * pousse, dirh[1] * pousse, 1.0), longueur,
        lambda t: teinte(clair, sombre, 0.25 + 0.75 * t),
        flechir=lambda t: (dirh[0] * courbure * t, dirh[1] * courbure * t, 0.0))


def touffe(g, rng, brins, longueur, clair, sombre, etalement=1.0,
           courbure=0.075, rayon_base=1.2):
    """Une touffe de brins autour de l'origine.

    Les azimuts sont tires dans des secteurs inegaux : une repartition
    reguliere rendrait la meme image aux quatre quarts de tour.
    """
    depart = rng.uniform(0.0, math.tau)
    for i in range(brins):
        a = depart + math.tau * (i + rng.uniform(-0.35, 0.35)) / brins
        r = rayon_base * math.sqrt(rng.random())
        base = (math.cos(a) * r, math.sin(a) * r, 0)
        long_i = longueur * rng.uniform(0.62, 1.0)
        brin(g, base, a + rng.uniform(-0.6, 0.6), long_i,
             courbure * rng.uniform(0.7, 1.4) * etalement,
             clair, sombre, pousse=rng.uniform(0.0, 0.35))


def ellipsoide(g, centre, rayons, couleur, deforme=None, creux=None):
    """Ellipsoide plein, ou coque si `creux` donne l'epaisseur en voxels.

    `deforme(theta, phi)` module le rayon ; c'est ce qui evite la bille
    parfaite. `couleur(f)` recoit la hauteur relative dans l'ellipsoide.
    """
    cx, cy, cz = centre
    rx, ry, rz = rayons
    for z in range(int(math.floor(cz - rz)), int(math.ceil(cz + rz)) + 1):
        if z < 0:
            continue
        for y in range(int(math.floor(cy - ry)), int(math.ceil(cy + ry)) + 1):
            for x in range(int(math.floor(cx - rx)), int(math.ceil(cx + rx)) + 1):
                ux, uy, uz = (x - cx) / rx, (y - cy) / ry, (z - cz) / rz
                q = math.sqrt(ux * ux + uy * uy + uz * uz)
                if q < 1e-6:
                    q = 1e-6
                limite = 1.0
                if deforme is not None:
                    limite = deforme(math.atan2(uy, ux),
                                     math.asin(max(-1.0, min(1.0, uz / q))))
                if q > limite:
                    continue
                if creux is not None and q < limite - creux / max(rx, ry, rz):
                    continue
                f = (z - (cz - rz)) / (2.0 * rz)
                g.pose(x, y, z, couleur(f))


def bosses(rng, force=0.2, plis=(2, 3, 5)):
    """Un modulateur de rayon pour `ellipsoide` : quelques sinus de phases
    tirees. Assez pour qu'aucun caillou ne soit une bille, et deterministe."""
    ph = [rng.uniform(0.0, math.tau) for _ in plis]
    pv = [rng.uniform(0.0, math.tau) for _ in plis]
    amp = [force * rng.uniform(0.5, 1.0) / (i + 1) for i in range(len(plis))]

    def f(theta, phi):
        r = 1.0
        for k, n in enumerate(plis):
            r += amp[k] * math.sin(n * theta + ph[k]) * math.cos(phi)
            r += 0.6 * amp[k] * math.sin(n * phi + pv[k])
        return r
    return f


def caillou(g, rng, largeur, profondeur, hauteur, clair, sombre, enfonce=0.35):
    """Un caillou pose au sol : ellipsoide bossele, tronque sous la surface.

    `enfonce` est la part du rayon vertical qui passe sous z = 0 ; sans elle le
    caillou est une bille en equilibre, ce qui se voit tout de suite.
    """
    rz = hauteur / (1.0 - enfonce)
    # Le degrade porte sur la hauteur *hors sol*, pas sur la fraction de
    # l'ellipsoide : la moitie basse est enterree, et sans ce report un caillou
    # n'emploie que les trois teintes claires de sa rampe.
    def couleur(f):
        z = hauteur - 2.0 * rz + f * 2.0 * rz
        return teinte(clair, sombre, max(0.0, min(1.0, z / hauteur)))

    ellipsoide(g, (0.0, 0.0, hauteur - rz),
               (largeur / 2.0, profondeur / 2.0, rz), couleur,
               deforme=bosses(rng, 0.22, (2, 3, 5)))


def feuille(g, base, direction, longueur, largeur, clair, sombre,
            flechir=None, nervure=None):
    """Une feuille : une lame plate d'un voxel, large au premier tiers et
    pointue aux deux bouts. Le plan de la feuille suit la marche, sa largeur
    est portee par l'horizontale perpendiculaire."""
    x, y, z = base
    dx, dy, dz = normalise(direction)
    pas = 0.5
    n = max(2, int(round(longueur / pas)))
    for i in range(n + 1):
        t = i / n
        w = largeur * 0.5 * math.sin(math.pi * min(1.0, t * 1.15) ** 0.75)
        perp = normalise((-dy, dx, 0.0))
        c = teinte(clair, sombre, 0.3 + 0.7 * (1.0 - abs(2 * t - 1)))
        k = 0.0
        while k <= w:
            for s in (1.0, -1.0):
                g.pose(x + perp[0] * k * s, y + perp[1] * k * s,
                       z + perp[2] * k * s, c)
            k += 0.7
        if nervure is not None and t < 0.98:
            g.pose(x, y, z, nervure)
        if flechir is not None:
            f = flechir(t)
            dx, dy, dz = normalise((dx + f[0] * pas, dy + f[1] * pas,
                                    dz + f[2] * pas))
        x += dx * pas
        y += dy * pas
        z += dz * pas


def petales(g, rng, centre, nombre, longueur, a0, coeur, bord,
            inclinaison=1.25, largeur=0.0, retombe=0.0):
    """Une corolle : `nombre` petales rayonnants depuis `centre`.

    Un nombre impair et une phase tiree evitent la fleur qui rend la meme image
    a chaque quart de tour.
    """
    for i in range(nombre):
        a = a0 + math.tau * i / nombre + rng.uniform(-0.12, 0.12)
        inc = inclinaison * rng.uniform(0.85, 1.15)
        d = azimut(a, inc)
        L = longueur * rng.uniform(0.82, 1.12)
        if largeur > 0.0:
            feuille(g, centre, d, L, largeur, bord, coeur,
                    flechir=lambda t: (0.0, 0.0, -retombe * t))
        else:
            trace(g, centre, d, L,
                  lambda t: bord if t > 0.35 else coeur,
                  flechir=lambda t: (0.0, 0.0, -retombe * t))


def colonne(g, rng, hauteur, rayon_bas, rayon_haut, clair, sombre,
            plis=(3, 5), force=0.18, penche=0.0):
    """Un fut : gres, souche, pied de champignon epais. Section modulee pour
    qu'il ne soit pas un cylindre."""
    f = bosses(rng, force, plis)
    a = rng.uniform(0.0, math.tau)
    for z in range(int(round(hauteur))):
        u = z / max(1.0, hauteur - 1.0)
        r = rayon_bas + (rayon_haut - rayon_bas) * u
        ox = math.cos(a) * penche * u * hauteur
        oy = math.sin(a) * penche * u * hauteur
        n = int(r) + 2
        for y in range(-n, n + 1):
            for x in range(-n, n + 1):
                dx, dy = x - ox, y - oy
                q = math.sqrt(dx * dx + dy * dy) / max(0.5, r)
                if q <= f(math.atan2(dy, dx), (u - 0.5) * 2.0):
                    g.pose(x, y, z, teinte(clair, sombre, 0.2 + 0.8 * u))
