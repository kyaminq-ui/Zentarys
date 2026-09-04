# Palette de projet Zentarys

Une seule palette de 256 entrées sert à tout : le terrain généré **et** les
modèles voxels. C'est imposé par le rendu — `VoxelMesherCubes` en mode
`COLOR_MESHER_PALETTE` stocke un index par voxel, pas une couleur. Un modèle
peint dans une autre palette arrive donc avec des couleurs fausses, sans le
moindre message d'erreur.

## Fichiers

| fichier | usage |
|---|---|
| `zentarys_palette.vox` | planche 16 × 16 — **à ouvrir dans MagicaVoxel** |
| `zentarys_palette.png` | 256 × 1, forme linéaire |
| `zentarys_palette_ref.png` | planche 16 × 16 agrandie, **pour l'œil seulement** |

**Ne jamais éditer ces PNG à la main.** La source est `CWPalette.colors()` dans
`src/worldgen/cw_palette.gd`. Pour changer une teinte : modifier le code, puis

```
godot --headless --path . -s tools/export_palette.gd
```

## Charger la palette dans MagicaVoxel

**Ouvrir `zentarys_palette.vox`.** C'est le seul geste sûr. Le fichier porte la
palette dans son bloc `RGBA`, emplacement par emplacement : les 256 index
arrivent exactement où le code les attend. Modéliser ensuite dans ce fichier, ou
copier sa palette vers un nouveau modèle.

**Ne pas glisser `zentarys_palette_ref.png` sur le nuancier.** Cette planche est
faite pour l'œil humain : ses cases sont agrandies et bordées d'un liseré
sombre. MagicaVoxel la rééchantillonne pour la ramener à 256 cases, retombe une
case sur deux sur le liseré, et produit une palette où **chaque couleur du
projet apparaît deux fois — la vraie, puis la même assombrie de 45 %**, dans
l'ordre des lignes inversé.

C'est arrivé sur le premier lot de flore, le 2026-09-05. Les teintes étaient
justes à l'œil dans MagicaVoxel ; les *index* écrits dans les fichiers, non — et
comme le rendu lit l'index et jamais la couleur, les 39 modèles seraient sortis
peints avec la palette des créatures et des structures, sans le moindre message
d'erreur. Le lot a été remis dans la palette de projet par
`tools/repaint_models.gd`, qui reste là pour recommencer si besoin.

Cette confusion ne peut pas se produire avec le `.vox` : il n'y a rien à
rééchantillonner.

## Plages réservées

L'index **0 est l'air** et ne peut pas servir : le mailleur le traite comme du
vide.

| plage | indices | entrées | contenu |
|---|---|---|---|
| Terrain | 1 – 31 | 31 | 13 écrites par la génération ; 14 – 31 sont de la **matière de terrain pour les modèles** : roche nue, grès, argile, basalte, roche lichénée, lave |
| Créatures | 32 – 95 | 64 | peaux, fourrures, écailles, chitine, yeux, cornes |
| Armes et équipement | 96 – 127 | 32 | acier, or, manches, cuir, gemmes |
| Végétation | 128 – 175 | 48 | feuillages, automne, écorces, fleurs, champignons, algues et coraux, cactus |
| Structures | 176 – 239 | 64 | planches, pierre, tuiles, plâtre, tissus, verre, métal |
| Effets et repères | 240 – 255 | 16 | lumière, magie, et 8 couleurs criardes pour l'édition |

Les teintes actuelles sont des **rampes de départ**, à ajuster nuance par
nuance. Ce qui ne doit pas bouger, c'est le découpage : il garantit qu'un modèle
peint aujourd'hui reste lisible quand les couleurs évolueront.

Deux plages ont bougé le 2026-09-05, en intégrant le premier lot de flore, et
pour la même raison : un modèle ne trouvait pas sa couleur.

* **Terrain 14 – 31, remplie.** Elle était vide. Un caillou, un bloc de grès, une
  paroi de basalte sont de la matière de terrain, et la plage végétation n'a
  aucun gris : sans ces entrées, les six cailloux du lot se rabattaient tous sur
  `STONE` et rendaient la même couleur.
* **Végétation : deux entrées pour l'aquatique** (170 – 171), prises sur la rampe
  des champignons, ramenée de 8 à 6. Le fond marin est l'une des neuf surfaces
  que le générateur produit ; rien d'autre dans la palette n'est froid et saturé,
  et le corail se rabattait sur le vert de prairie.

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
VoxelVoxLoader.load_from_file("res://assets/models/hache.vox", buffer,
        palette, VoxelBuffer.CHANNEL_COLOR)
```

`load_from_file` est **statique** : l'appeler sur une instance fonctionne mais
alloue un chargeur pour rien, et Godot le signale. Le chargeur **redimensionne
le buffer** aux dimensions du modèle : inutile de l'appeler avec la bonne taille.

En pratique on passe par `CWVoxelModel.load_from()`, qui fait cet appel puis
convertit le résultat en liste creuse — voir `assets/models/MODELS.md`.
