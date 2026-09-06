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
| Terrain | 1 – 40 | 40 | 13 écrites par la génération, dont **4 = le bois d'un tronc estampé** ; 14 – 31 sont de la **matière de terrain pour les modèles** (roche nue, grès, argile, basalte, roche lichénée, lave) ; **32 – 40 sont les neuf filons** |
| Créatures | 41 – 95 | 55 | peaux, fourrures, écailles, chitine, yeux, cornes |
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

Une troisième a bougé le 2026-09-05 au soir, et c'est la seule **frontière** qui
ait jamais bougé.

* **Terrain 32 – 40 : les neuf filons.** Un filon s'estampe dans le terrain —
  on doit pouvoir le miner —, donc chacun de ses voxels est un **type de bloc**
  et non seulement une couleur. Il lui faut une entrée à lui, et la réserve
  14 – 31 était pleine. `RANGE_TERRAIN_END` passe donc de 31 à 40 et
  `RANGE_CREATURES_BEGIN` de 32 à 41.

  **Une seule frontière déplacée, aucun modèle à repeindre** — vérifié plutôt que
  supposé : `inspect_model.gd` sur les 53 modèles du dépôt ne rend que des index
  dans 14 – 29 et 128 – 175. La plage créatures perd neuf entrées sur 64 et n'en a
  aucune de peinte, l'apparence des créatures étant hors périmètre ; ses sept
  rampes ont été recompactées de 56 entrées à 47, **les huit teintes ponctuelles
  gardant leurs index 88 – 95**.

  Les deux autres issues envisagées ont été écartées, et il vaut la peine de dire
  pourquoi. Mettre les filons dans la plage équipement (96 – 127, qui a déjà une
  rampe de gemmes) aurait fait porter à un bloc minable un index que cette table
  déclare « armes et équipement » : le découpage existe précisément pour qu'un
  modèle peint aujourd'hui reste juste quand les teintes évoluent, et ajuster la
  rampe des gemmes aurait repeint les filons. Réemployer des entrées existantes
  est impossible depuis 1.9, où `CHANNEL_TYPE` porte la sémantique du bloc.

  Les neuf index sont **consécutifs et dans l'ordre des codes d'entité 131 – 139**
  de la source, qui est l'ordre de sa table de rareté : `index = 32 + (code −
  131)`, verrouillé par un test.

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
