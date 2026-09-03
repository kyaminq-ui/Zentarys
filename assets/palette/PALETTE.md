# Palette de projet Zentarys

Une seule palette de 256 entrées sert à tout : le terrain généré **et** les
modèles voxels. C'est imposé par le rendu — `VoxelMesherCubes` en mode
`COLOR_MESHER_PALETTE` stocke un index par voxel, pas une couleur. Un modèle
peint dans une autre palette arrive donc avec des couleurs fausses, sans le
moindre message d'erreur.

## Fichiers

| fichier | usage |
|---|---|
| `zentarys_palette.png` | 256 × 1 — à glisser sur la palette de MagicaVoxel |
| `zentarys_palette_ref.png` | planche 16 × 16 agrandie, pour l'œil |

**Ne jamais éditer ces PNG à la main.** La source est `CWPalette.colors()` dans
`src/worldgen/cw_palette.gd`. Pour changer une teinte : modifier le code, puis

```
godot --headless --path . -s tools/export_palette.gd
```

## Plages réservées

L'index **0 est l'air** et ne peut pas servir : le mailleur le traite comme du
vide.

| plage | indices | entrées | contenu |
|---|---|---|---|
| Terrain | 1 – 31 | 31 | 13 utilisées par la génération, 18 en réserve (lave, argile, grès, obsidienne…) |
| Créatures | 32 – 95 | 64 | peaux, fourrures, écailles, chitine, yeux, cornes |
| Armes et équipement | 96 – 127 | 32 | acier, or, manches, cuir, gemmes |
| Végétation | 128 – 175 | 48 | feuillages, automne, écorces, fleurs, champignons, cactus |
| Structures | 176 – 239 | 64 | planches, pierre, tuiles, plâtre, tissus, verre, métal |
| Effets et repères | 240 – 255 | 16 | lumière, magie, et 8 couleurs criardes pour l'édition |

Les teintes actuelles sont des **rampes de départ**, à ajuster nuance par
nuance. Ce qui ne doit pas bouger, c'est le découpage : il garantit qu'un modèle
peint aujourd'hui reste lisible quand les couleurs évolueront.

## Deux faits vérifiés sur l'import `.vox`

Mesurés le 2026-09-04 avec un fichier témoin, pas supposés.

**1. Les index se conservent exactement.** L'emplacement `i` de la palette
MagicaVoxel ressort en valeur `i` dans le canal `CHANNEL_COLOR`. Le décalage
d'un cran du format `.vox` (le bloc `RGBA` stocke la couleur de l'index `i` en
position `i-1`) est absorbé par le chargeur. Rien à compenser.

**2. Les axes sont permutés.** MagicaVoxel est Z-up, Godot est Y-up :

```
vox(x, y, z)  ->  godot(y, z, x)
```

Le haut reste le haut (vox Z → godot Y), mais le plan horizontal est échangé :
vox X arrive en godot Z et vox Y en godot X. À compenser soit en orientant les
modèles dans MagicaVoxel, soit par une rotation à l'import.

## Charger un modèle

```gdscript
var buffer := VoxelBuffer.new()
var palette := CWPalette.build_voxel_palette()
var loader := VoxelVoxLoader.new()
loader.load_from_file("res://assets/models/hache.vox", buffer,
        palette, VoxelBuffer.CHANNEL_COLOR)
```

Le chargeur **redimensionne le buffer** aux dimensions du modèle : inutile de
l'appeler avec la bonne taille.
