"""Ecriture .vox et outils de grille pour le lot de flore Zentarys.

Pur Python, sans bpy : ce module sert aussi bien sous l'interpreteur systeme
que sous celui de Blender.

Deux points sur lesquels le lot precedent s'est fait prendre, et qui sont
verrouilles ici :

* **la palette.** Le moteur lit un index, jamais une couleur. On recopie donc
  le bloc RGBA de `assets/palette/zentarys_palette.vox` tel quel, sans le
  reconstruire. Le decalage du format (`RGBA[i]` porte la couleur de l'index
  `i + 1`) est deja absorbe : l'octet ecrit dans XYZI est directement l'index
  de projet.
* **les plages.** Un index hors des plages autorisees ne leve rien a
  l'execution, il ressort peint avec la palette d'un autre lot. `verifie` le
  refuse a l'ecriture.
"""

import os
import struct

DEPOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PALETTE_VOX = os.path.join(DEPOT, "assets", "palette", "zentarys_palette.vox")
RACINE = os.path.join(DEPOT, "assets", "models")
SORTIE = os.path.join(RACINE, "flore")

# Plages autorisees pour un modele de flore ou d'arbre. 0 est l'air, 12 et 13
# sont l'eau (translucide, qui sort opaque au rendu), le reste appartient a
# d'autres lots.
#
# La reserve de terrain va jusqu'a 31 ici et non 40 : les neuf filons (32-40)
# sont bien du terrain, mais aucune plante n'a de raison d'etre peinte en filon
# d'or. Le garde-fou reste donc etroit pour ce lot-ci, et les filons ont le leur.
INDEX_VALIDES = frozenset(list(range(1, 12)) + list(range(14, 32))
                          + list(range(128, 176)))

# Plages autorisees pour un **filon**. Un filon s'estampe : chacun de ses voxels
# est un type de bloc. Il n'a donc le droit qu'a de la roche (1, la meme que
# celle qu'ecrit le generateur, pour qu'il se fonde dans la paroi), a la roche
# nue des modeles (14-19) et aux neuf entrees de filon (32-40). Rien de
# vegetal : un filon vert serait un filon d'emeraude, pas une plante.
INDEX_FILONS = frozenset([1] + list(range(14, 20)) + list(range(32, 41)))

# Enveloppe verifiee par tests/flora_test.gd : 4 blocs de haut, 2 de rayon.
#
# **La grille du lot de flore est passee de 40/3 a 4 voxels par bloc le
# 2026-09-06** (`CWVoxelModel.VOXELS_PER_BLOCK_FLORE`), puis les petits props —
# herbes et fleurs — a **6** le soir meme
# (`VOXELS_PER_BLOCK_FLORE_FINE`). L'enveloppe, elle, n'a jamais bouge : elle est
# dite en *blocs*, et c'est pour cela qu'elle a survecu aux deux changements sans
# qu'on y touche. Ce sont les plafonds en voxels qui suivent, d'ou `plafond_de`.
VOXELS_PAR_BLOC = 4.0
HAUTEUR_MAX = int(4 * VOXELS_PAR_BLOC)   # 16
RAYON_MAX = int(2 * VOXELS_PAR_BLOC)     # 8


def plafond_de(voxels_par_bloc):
    """L'enveloppe (hauteur, rayon) en voxels, pour une grille donnee.

    L'enveloppe est **4 blocs de haut et 2 de rayon**, quelle que soit la
    grille : c'est une taille d'objet dans le monde, pas une resolution de
    dessin. Passer la grille ici plutot que d'ecrire deux couples de constantes
    est ce qui garantit que les deux lots de flore restent comparables.
    """
    return (int(4 * voxels_par_bloc), int(2 * voxels_par_bloc))


def lit_bloc_rgba(chemin=PALETTE_VOX):
    """Les 1024 octets du bloc RGBA de la palette de projet, tels quels."""
    with open(chemin, "rb") as f:
        d = f.read()
    i = d.find(b"RGBA")
    n = struct.unpack("<I", d[i + 4:i + 8])[0]
    assert n == 1024, n
    bloc = d[i + 12:i + 12 + 1024]
    # Temoin : RGBA[127] porte l'index 128, premier vert de feuillage.
    assert tuple(bloc[127 * 4:127 * 4 + 3]) == (154, 216, 96), \
        "palette inattendue en 128 : %s" % (tuple(bloc[127 * 4:127 * 4 + 3]),)
    return bloc


def couleurs_projet(bloc=None):
    """Les 256 couleurs indexees comme le code les voit (RGBA decalee)."""
    bloc = bloc if bloc is not None else lit_bloc_rgba()
    c = [(0, 0, 0, 0)]
    for i in range(255):
        c.append(tuple(bloc[i * 4:i * 4 + 4]))
    return c


def write_vox(chemin, voxels, size, bloc_rgba):
    """voxels : iterable de (x, y, z, index), index de projet 1..255.
    size : (sx, sy, sz), Z vers le haut. bloc_rgba : les 1024 octets copies."""
    assert len(bloc_rgba) == 1024
    v = [t for t in voxels]
    assert all(1 <= c <= 255 for _, _, _, c in v), "index 0 = air, interdit"
    assert all(max(x, y, z) < 256 for x, y, z, _ in v)

    size_c = struct.pack("<4sII", b"SIZE", 12, 0) + struct.pack("<III", *size)
    body = struct.pack("<I", len(v)) + b"".join(
        bytes((x, y, z, c)) for x, y, z, c in v)
    xyzi_c = struct.pack("<4sII", b"XYZI", len(body), 0) + body
    rgba_c = struct.pack("<4sII", b"RGBA", 1024, 0) + bloc_rgba
    children = size_c + xyzi_c + rgba_c
    main = struct.pack("<4sII", b"MAIN", 0, len(children)) + children
    with open(chemin, "wb") as f:
        f.write(b"VOX " + struct.pack("<I", 150) + main)


class Grille:
    """Grille creuse (x, y, z) -> index de palette. Z est vers le haut.

    On n'y pose que de la matiere : un modele de flore n'occupe que quelques
    pour cent de sa boite, et seuls les voxels pleins sont ecrits.
    """

    def __init__(self):
        self.v = {}

    def pose(self, x, y, z, c):
        x, y, z = int(round(x)), int(round(y)), int(round(z))
        if z < 0:
            return
        self.v[(x, y, z)] = int(c)

    def pose_si_vide(self, x, y, z, c):
        x, y, z = int(round(x)), int(round(y)), int(round(z))
        if z < 0 or (x, y, z) in self.v:
            return
        self.v[(x, y, z)] = int(c)

    def bille(self, x, y, z, r, c):
        """Une boule de rayon r. r < 0.5 pose un seul voxel."""
        if r < 0.5:
            self.pose(x, y, z, c)
            return
        n = int(r) + 1
        cx, cy, cz = int(round(x)), int(round(y)), int(round(z))
        for dz in range(-n, n + 1):
            for dy in range(-n, n + 1):
                for dx in range(-n, n + 1):
                    if dx * dx + dy * dy + dz * dz <= r * r:
                        self.pose(cx + dx, cy + dy, cz + dz, c)

    def fusionne(self, autre):
        self.v.update(autre.v)

    def __len__(self):
        return len(self.v)

    def boite(self):
        xs = [p[0] for p in self.v]
        ys = [p[1] for p in self.v]
        zs = [p[2] for p in self.v]
        return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))

    def normalise(self):
        """Recadre sur la matiere : rend (voxels, size), coin bas en (0, 0, 0).

        Le chargeur recadre de toute facon, mais un gabarit ajuste evite
        d'ecrire une boite pleine d'air et rend l'inspection lisible.
        """
        lo, hi = self.boite()
        voxels = [(x - lo[0], y - lo[1], z - lo[2], c)
                  for (x, y, z), c in sorted(self.v.items())]
        size = (hi[0] - lo[0] + 1, hi[1] - lo[1] + 1, hi[2] - lo[2] + 1)
        return voxels, size


def verifie(nom, voxels, size, plafond=None, indices=None):
    """Refuse ce que le lot precedent laissait passer en silence.

    `plafond` est le couple (hauteur, rayon) en voxels ; par defaut celui de la
    flore basse, que verrouille `tests/flora_test.gd`. Le lot d'arbres passe le
    sien : un arbre ne tient pas sous 53 voxels, et son enveloppe est celle du
    prompt (`docs/prompt_generation_arbres.md`, Sec. 1.1).

    `indices` est l'ensemble des index autorises. Il se parametre lui aussi
    depuis le lot de filons, mais **jamais pour elargir** : chaque lot passe le
    sien, plus etroit que la plage de la palette, et c'est ce qui fait du
    garde-fou autre chose qu'une formalite. Un filon n'a pas le droit au
    feuillage, une plante n'a pas le droit a l'or.
    """
    h_max, r_max = plafond if plafond is not None else (HAUTEUR_MAX, RAYON_MAX)
    permis = INDEX_VALIDES if indices is None else indices
    mauvais = sorted({c for _, _, _, c in voxels} - permis)
    if mauvais:
        raise ValueError("%s : index hors plage %s" % (nom, mauvais))
    sx, sy, sz = size
    if sz > h_max:
        raise ValueError("%s : %d voxels de haut, plafond %d" % (nom, sz, h_max))
    # Rayon tel que le chargeur le mesure : ancre au centre du gabarit.
    rayon = max(max(sx // 2, sx - 1 - sx // 2), max(sy // 2, sy - 1 - sy // 2))
    if rayon > r_max:
        raise ValueError("%s : rayon %d, plafond %d" % (nom, rayon, r_max))
    return rayon


def ecris(dossier, nom, grille, bloc_rgba, verbeux=True, racine=None,
          plafond=None, indices=None):
    """Normalise, verifie et ecrit `<racine>/<dossier>/<nom>.vox`.

    `racine` vaut le dossier de la flore par defaut ; le lot d'arbres passe
    `RACINE/arbres`.
    """
    if len(grille) == 0:
        raise ValueError("%s/%s : grille vide" % (dossier, nom))
    racine = SORTIE if racine is None else racine
    voxels, size = grille.normalise()
    rayon = verifie("%s/%s" % (dossier, nom), voxels, size, plafond, indices)
    cible = os.path.join(racine, dossier)
    os.makedirs(cible, exist_ok=True)
    write_vox(os.path.join(cible, nom + ".vox"), voxels, size, bloc_rgba)
    if verbeux:
        index = sorted({c for _, _, _, c in voxels})
        print("  %-16s %3d x %3d x %3d  r=%-2d  %6d voxels  index %s"
              % (nom, size[0], size[1], size[2], rayon, len(voxels),
                 ",".join(str(i) for i in index)))
    return size


def teinte(clair, sombre, f):
    """Index d'une rampe : f = 1 en haut (clair), f = 0 a la base (sombre).

    Les rampes de `CWPalette` vont du clair au sombre en index croissant, donc
    l'interpolation se fait a l'envers.
    """
    f = 0.0 if f < 0.0 else (1.0 if f > 1.0 else f)
    return int(round(sombre + (clair - sombre) * f))
