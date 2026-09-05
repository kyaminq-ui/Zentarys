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
SORTIE = os.path.join(DEPOT, "assets", "models", "flore")

# Plages autorisees pour un modele de flore. 0 est l'air, 12 et 13 sont l'eau
# (translucide, qui sort opaque au rendu), le reste appartient a d'autres lots.
INDEX_VALIDES = frozenset(list(range(1, 12)) + list(range(14, 32))
                          + list(range(128, 176)))

# Enveloppe verifiee par tests/flora_test.gd : 4 blocs de haut, 2 de rayon,
# a 40/3 voxels par bloc.
VOXELS_PAR_BLOC = 40.0 / 3.0
HAUTEUR_MAX = int(4 * VOXELS_PAR_BLOC)   # 53
RAYON_MAX = int(2 * VOXELS_PAR_BLOC)     # 26


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


def verifie(nom, voxels, size):
    """Refuse ce que le lot precedent laissait passer en silence."""
    mauvais = sorted({c for _, _, _, c in voxels} - INDEX_VALIDES)
    if mauvais:
        raise ValueError("%s : index hors plage %s" % (nom, mauvais))
    sx, sy, sz = size
    if sz > HAUTEUR_MAX:
        raise ValueError("%s : %d voxels de haut, plafond %d"
                         % (nom, sz, HAUTEUR_MAX))
    # Rayon tel que le chargeur le mesure : ancre au centre du gabarit.
    rayon = max(max(sx // 2, sx - 1 - sx // 2), max(sy // 2, sy - 1 - sy // 2))
    if rayon > RAYON_MAX:
        raise ValueError("%s : rayon %d, plafond %d" % (nom, rayon, RAYON_MAX))
    return rayon


def ecris(dossier, nom, grille, bloc_rgba, verbeux=True):
    """Normalise, verifie et ecrit `<SORTIE>/<dossier>/<nom>.vox`."""
    if len(grille) == 0:
        raise ValueError("%s/%s : grille vide" % (dossier, nom))
    voxels, size = grille.normalise()
    rayon = verifie("%s/%s" % (dossier, nom), voxels, size)
    cible = os.path.join(SORTIE, dossier)
    os.makedirs(cible, exist_ok=True)
    write_vox(os.path.join(cible, nom + ".vox"), voxels, size, bloc_rgba)
    if verbeux:
        index = sorted({c for _, _, _, c in voxels})
        print("  %-14s %2d x %2d x %2d  r=%-2d  %5d voxels  index %s"
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
