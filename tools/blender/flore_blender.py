"""Formes de flore construites sous Blender, puis echantillonnees sur la grille.

Blender sert a **construire des formes**, pas a exporter : il n'y a pas d'ecriture
de fichier ici. Le pipeline est celui du prompt (`docs/prompt_generation_flore.md`,
Sec. 4) :

1. `bpy` construit la geometrie — courbes a rayon variable pour les tiges, les
   branches et les lianes, metaballes pour les frondaisons, `Simple Deform` pour
   les courbures ;
2. on echantillonne le maillage evalue sur une grille entiere, par
   `closest_point_on_mesh` : distance a la surface pour les formes minces,
   distance signee par la normale pour les volumes ;
3. un index de palette est affecte par voxel selon sa hauteur ou sa partie ;
4. l'appelant ecrit le `.vox`.

Ce module n'est importable que sous l'interpreteur de Blender. Les formes qui
n'y gagnent rien — brins, cailloux, fleurs — sont dans `flore_formes.py`.
"""

import math

import bpy
from mathutils import Vector

from flore_vox import teinte

COQUE = "coque"
VOLUME = "volume"


# -- Scene --------------------------------------------------------------------

def scene_vide():
    """Repart d'une scene sans rien. Appele avant chaque modele : deux modeles
    qui partagent une scene partagent aussi ses restes."""
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _lie(obj):
    bpy.context.collection.objects.link(obj)
    return obj


# -- Construction -------------------------------------------------------------

def courbe(points, rayons, resolution=3, lisse=True, nom="courbe"):
    """Une courbe a rayon variable, biseautee en tube.

    `points` est une liste de listes : une branche par sous-liste, ce qui donne
    un seul objet pour une forme ramifiee. `rayons` suit la meme structure, et
    module le biseau point par point — c'est ce qui affine une branche vers sa
    pointe sans la modeliser deux fois.
    """
    data = bpy.data.curves.new(nom, type="CURVE")
    data.dimensions = "3D"
    data.bevel_depth = 1.0
    data.bevel_resolution = resolution
    data.use_fill_caps = True
    for branche, rs in zip(points, rayons):
        spline = data.splines.new("POLY")
        spline.points.add(len(branche) - 1)
        for i, (p, r) in enumerate(zip(branche, rs)):
            spline.points[i].co = (p[0], p[1], p[2], 1.0)
            spline.points[i].radius = max(0.02, r)
        spline.use_smooth = lisse
    return _lie(bpy.data.objects.new(nom, data))


def metaballes(elements, resolution=0.35, nom="meta"):
    """Une frondaison : des boules qui fusionnent. C'est ce que Blender fait de
    mieux ici — une union de spheres donnerait des bosses recousues, la
    metaballe donne une masse continue avec des creux entre les lobes."""
    data = bpy.data.metaballs.new(nom)
    data.resolution = resolution
    data.render_resolution = resolution
    for (x, y, z), r, rigide in elements:
        e = data.elements.new()
        e.co = (x, y, z)
        e.radius = r
        e.stiffness = rigide
    return _lie(bpy.data.objects.new(nom, data))


def plie(obj, angle, axe="X", origine=(0.0, 0.0, 0.0)):
    """Un `Simple Deform` en flexion. Sert aux bras de cactus et aux tiges
    lourdes : la courbure vient du modificateur, pas d'un point de controle
    place a la main."""
    vide = _lie(bpy.data.objects.new("origine_" + obj.name, None))
    vide.location = origine
    m = obj.modifiers.new("plie", "SIMPLE_DEFORM")
    m.deform_method = "BEND"
    m.angle = angle
    m.deform_axis = axe
    m.origin = vide
    return obj


# -- Echantillonnage ----------------------------------------------------------

def _maillage_evalue(obj):
    """Le maillage de l'objet, modificateurs appliques, en coordonnees monde."""
    deps = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(deps)
    me = bpy.data.meshes.new_from_object(ev, depsgraph=deps)
    me.transform(obj.matrix_world)
    return me


def voxelise(g, obj, couleur, mode=COQUE, epaisseur=0.72, marge=2,
             filtre=None):
    """Echantillonne `obj` sur la grille entiere de `g`.

    `mode = COQUE` ne garde que les voxels a moins de `epaisseur` de la
    surface : c'est ce qu'il faut pour une frondaison ou une algue, qui doivent
    rester des lames et non des blocs verts. `mode = VOLUME` remplit l'interieur,
    reserve a ce qui est vraiment massif — un cactus, un bloc de gres.

    `couleur(x, y, z, f)` recoit la position entiere et la hauteur relative dans
    la boite de l'objet.
    """
    me = _maillage_evalue(obj)
    if len(me.polygons) == 0:
        bpy.data.meshes.remove(me)
        raise ValueError("maillage vide pour %s" % obj.name)
    sonde = _lie(bpy.data.objects.new("sonde_" + obj.name, me))

    lo = [min(v.co[i] for v in me.vertices) for i in range(3)]
    hi = [max(v.co[i] for v in me.vertices) for i in range(3)]
    hauteur = max(1e-6, hi[2] - lo[2])
    pose = 0
    for z in range(int(math.floor(lo[2])) - marge, int(math.ceil(hi[2])) + marge + 1):
        if z < 0:
            continue
        for y in range(int(math.floor(lo[1])) - marge, int(math.ceil(hi[1])) + marge + 1):
            for x in range(int(math.floor(lo[0])) - marge, int(math.ceil(hi[0])) + marge + 1):
                p = Vector((x, y, z))
                ok, loc, nor, _i = sonde.closest_point_on_mesh(p)
                if not ok:
                    continue
                d = (loc - p).length
                if mode == VOLUME:
                    dedans = (p - loc).dot(nor) <= 0.0
                    if not dedans and d > epaisseur:
                        continue
                elif d > epaisseur:
                    continue
                if filtre is not None and not filtre(x, y, z):
                    continue
                g.pose(x, y, z, couleur(x, y, z, (z - lo[2]) / hauteur))
                pose += 1

    bpy.data.objects.remove(sonde, do_unlink=True)
    bpy.data.meshes.remove(me)
    return pose


def par_hauteur(clair, sombre, depart=0.18):
    """Le degrade par defaut : plus clair en haut, plus sombre a la base."""
    return lambda x, y, z, f: teinte(clair, sombre, depart + (1.0 - depart) * f)


# -- Chemins ------------------------------------------------------------------

def branche(rng, depart, direction, longueur, segments, derive=0.35,
            montee=0.0):
    """Une suite de points qui erre autour d'une direction. La derive est
    cumulative : la branche part droit et finit tordue, comme une vraie."""
    p = Vector(depart)
    d = Vector(direction).normalized()
    pts = [p.copy()]
    pas = longueur / segments
    for _ in range(segments):
        d = (d + Vector((rng.uniform(-derive, derive),
                         rng.uniform(-derive, derive),
                         rng.uniform(-derive, derive) + montee))).normalized()
        p = p + d * pas
        pts.append(p.copy())
    return pts


def rayons_effiles(points, base, pointe, courbe_=1.4):
    """Rayons decroissants le long d'une branche."""
    n = len(points) - 1
    return [base + (pointe - base) * (i / n) ** (1.0 / courbe_) for i in range(n + 1)]


def helice(depart, rayon, tours, hauteur, pas_angle=0.35, sens=1.0):
    """Une helice : la vrille de jungle, et la torsade d'une liane."""
    pts = []
    n = max(4, int(tours * math.tau / pas_angle))
    for i in range(n + 1):
        t = i / n
        a = sens * tours * math.tau * t
        pts.append(Vector((depart[0] + math.cos(a) * rayon * (1.0 - 0.35 * t),
                           depart[1] + math.sin(a) * rayon * (1.0 - 0.35 * t),
                           depart[2] + hauteur * t)))
    return pts
