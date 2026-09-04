# Zentarys — reprise de session

Fichier de reprise après un `/clear`. À lire en entier avant de toucher au code :
il contient des décisions qui coûtent cher à redécouvrir.

---

## 1. Où sont les choses

| quoi | chemin |
|---|---|
| Projet Godot | `C:\Users\Admin\Documents\zentarys\` |
| Exécutable Godot | `C:\Users\Admin\Desktop\Zentarys\godot.windows.editor.double.x86_64.exe` |
| Source d'analyse (rétro-ingénierie) | `C:\Users\Admin\Desktop\Zentarys\CubeWorld-Reversal-master\` |

Godot 4.7.2 stable, **double précision**, module Voxel Tools 1.7 compilé dedans
(`VoxelTerrain`, `VoxelMesherCubes`, `VoxelGeneratorScript`, `VoxelVoxLoader`…).
Le greffon `addons/godot_ai` est actif : l'éditeur peut être piloté par MCP
(`session_manage`, `project_run`, `editor_screenshot`, `game_manage`…).

Dépôt : <https://github.com/kyaminq-ui/Zentarys.git> (branche `main`).
Le greffon `addons/godot_ai` est versionné avec le reste : sans lui, le projet
ne s'ouvre pas proprement (il est déclaré dans `project.godot`).

## 2. Commandes

```
# Suite de validation (80 vérifications, ~60 s)
godot.windows.editor.double.x86_64.exe --headless --path . -s tests/worldgen_test.gd

# Réimport après ajout d'un class_name (sinon l'éditeur ne le voit pas)
godot.windows.editor.double.x86_64.exe --headless --path . --import

# Réexport de la palette après modification de CWPalette
godot.windows.editor.double.x86_64.exe --headless --path . -s tools/export_palette.gd

# Gros plan ombré sur un élément de tuile, avec et sans la couche
# (x, z, unités par pixel ; sans argument : le point de départ, 6 u/px)
godot.windows.editor.double.x86_64.exe --headless --path . \
    -s tools/preview_features.gd -- 8397830 8399776 6
```

Aperçus PNG écrits par la suite de tests dans
`user://worldgen_preview/` (`height.png`, `climate.png`, `channels.png`) →
`C:\Users\Admin\AppData\Roaming\Godot\app_userdata\Zentarys\worldgen_preview\`.

Démo : `res://scenes/terrain_demo.tscn`. Clic pour capturer la souris,
ZQSD/WASD, Maj = rapide, Espace/Ctrl = monter/descendre, **F1** détails,
**Page haut/bas** distance de vue, **1-9** téléportation vers un biome,
**Échap** rend la souris puis quitte.

## 3. État

Jalon 1 (le monde) : 1.1 à 1.6 faits, le reste à faire. Détail et sources
analysées dans `docs/ROADMAP.md`. Analyse du système de terrain dans
`docs/systems/01_generation_terrain.md`.

```
src/worldgen/
  cw_value_noise.gd        bruit de valeur (Hugo Elias), arithmétique 32 bits émulée
  cw_rand.gd               LCG de la CRT MSVC
  cw_region_site.gd        structure d'un site de zone
  cw_region_site_grid.gd   grille 1024² paresseuse, caches sous mutex
  cw_tile_feature.gd       structure d'un élément de tuile
  cw_tile_feature_grid.gd  grille 8x8 par zone, paresseuse, garde de réentrance
  cw_terrain_field.gd      climat + altitude + chenaux + éléments  ← le cœur
  cw_palette.gd            palette et règles de surface (couleurs originales)
  cw_voxel_generator.gd    VoxelGeneratorScript + cache de colonnes
src/demo/terrain_demo.gd   scène de démonstration (arbre voxel construit en code)
tests/worldgen_test.gd     suite headless, 80 vérifications
tests/tile_features_test.gd  la moitié qui concerne les éléments de tuile
tools/export_palette.gd    régénère assets/palette/*.png depuis CWPalette
tools/preview_features.gd  gros plan ombré, avec et sans la couche d'éléments
assets/palette/            palette de projet + PALETTE.md
```

## 4. Invariants à ne pas casser

1. **Les constantes de référence du bruit et du LCG sont porteuses.** Les
   valeurs attendues dans `_test_value_noise` et la séquence MSVC
   `41, 18467, 6334…` fixent l'identité de tous les mondes générés. Si elles
   bougent, chaque monde déjà exploré change. Ne jamais « corriger » ces tests
   pour les faire passer : c'est le code qui a régressé.
2. **`world_origin` s'applique dans `CWVoxelGenerator._get_patch`, nulle part
   ailleurs.** Le sampler travaille en coordonnées monde (~8,4 millions), la
   scène en coordonnées Godot proches de zéro. Appliquer le décalage deux fois,
   ou l'oublier, fait décrire deux endroits différents au terrain rendu et à
   l'ATH — et ça ne se voit qu'en comparant des couleurs de biome.
3. **`site_edge_radius = 0` est délibéré.** Les deux termes liés aux arêtes du
   graphe de sites comparent un *carré de distance en unités monde* à des seuils
   de l'ordre de l'unité. Résultat : une tranchée d'une seule colonne le long de
   chaque arête. Voir `docs/systems/01`, §2.7.
4. **`swamp_channel_weight = 0` est délibéré.** Le champ sommé par
   `World_waterProximityInfluence` est perdu dans la décompilation. On connaît
   la structure du mélange, pas la grandeur mélangée. Ne pas deviner.
5. **Le plafond du cache de colonnes doit couvrir l'empreinte chargée.**
   `HEIGHTMAP_CACHE_CAP` ≥ `(2 × distance_de_vue / 16)²`, sinon le cache
   s'auto-évince en boucle et le chargement s'effondre sans rien signaler.
6. **Le marqueur « en cours » de `_get_patch` n'est pas décoratif.** Sans lui,
   les blocs verticaux d'une même colonne recalculent tous la même carte de
   hauteurs en parallèle et le cache ne sert plus à rien pendant le chargement.
7. **Un test épars ne voit pas un artefact d'une colonne de large.** D'où les
   deux balayages denses de 3 000 colonnes, l'un dans `_test_terrain_field`,
   l'autre en travers d'un élément de tuile. Tout nouveau terme du champ doit
   passer sous ce balayage.
8. **La grille d'éléments ne doit jamais être publiée à moitié.** Le générateur
   d'éléments échantillonne le champ d'altitude, qui relit la grille : la zone
   en construction doit se voir *vide*, et seulement pour le fil qui la
   construit. Les autres fils attendent. Publier tôt, ou laisser deux fils
   construire la même zone, ferait figer dans le cache de hauteurs des colonnes
   calculées sans déformation — un monde qui ne se régénère pas à l'identique,
   et rien pour le signaler. Le test « même monde depuis huit fils concurrents »
   est là pour ça.
9. **Le poids d'influence d'un élément est déformé.** Le fond d'un cratère n'est
   pas à son centre géométrique mais à une centaine d'unités de là. Un test qui
   échantillonne le centre exact mesure autre chose que ce qu'il croit.

## 5. Pièges connus

- **`VoxelLodTerrain` est inutilisable avec un rendu en cubes** : des dalles
  d'eau apparaissent en pleine plaine dès le LOD 1. Bascule conservée
  (`TerrainDemo.use_lod`) pour revérifier après une mise à jour. Cause exacte
  non établie.
- **La propriété est `bounds` sur `VoxelTerrain`, `voxel_bounds` sur
  `VoxelLodTerrain`.** Deux noms, deux classes.
- **L'éditeur ne voit pas un nouvel `@export` tant qu'il n'a pas rechargé le
  script.** `filesystem_manage(op="scan")` ne suffit pas toujours ; changer la
  valeur par défaut dans le source est plus fiable pour un test ponctuel.
- **Coût actuel : ~62 µs par colonne hors influence d'un élément, ~75 µs
  dedans**, soit ~16 à 19 ms par bloc 16³ à froid. C'est le plafond de tout.
  Stabilisation mesurée avant la couche d'éléments : 27 s à 384 blocs de vue,
  120 s à 768 ; la couche n'ajoute rien mesurable sur le chemin de streaming,
  qui passe par `sample_patch` et sort la consultation de la grille de la boucle
  de colonnes.
- **`sample_column` paie ce que `sample_patch` ne paie pas.** La grille
  d'éléments est protégée par mutex ; une consultation par colonne coûte ~2 µs.
  `sample_patch` n'en fait qu'une par tuile traversée. Pour tout nouveau
  consommateur en volume — l'étage de terrain lointain, par exemple — passer par
  `sample_patch`.
- **Ne pas mettre d'appel de liaison moteur sur le chemin chaud.**
  `OS.get_thread_caller_id()` dans `CWTileFeatureGrid.get_zone` coûtait ~15 µs
  par colonne avant d'être déplacé sur le chemin froid. Mesurer avant de
  supposer que c'est le verrou qui coûte.

## 6. Prochaine tâche — jalon 1.7, contenu de biome

Les ancres sont posées : chaque tuile de 2048 unités porte au plus un élément,
typé et varianté. Reste à poser quelque chose dessus.

| fonction | adresse | rôle |
|---|---|---|
| `WorldInfo_generateBiomeContent` | `@005e4850` | contenu par biome |
| `WorldInfo_scatterObjectsInArea` | `@005f56c0` | dispersion (végétation) |
| `WorldInfo_placeStructure` | `@005f0ce0` | placement de structures (jalon 4) |

**C'est la première tranche qui demande des assets** : liste et ordre de
production en §7.1. Deux points à trancher pendant l'analyse de
`WorldInfo_generateBiomeContent` : la génération procédurale des arbres (aucun
modèle d'arbre n'existe dans l'original), et l'identité de chaque type
d'élément de tuile, qui n'est pas encore établie.

Ce qui reste ouvert dans la couche 1.6, à reprendre si l'occasion se présente :

- **Le type 13 (piton de +150) n'a pas de source.** `World_generateRegionFeatures`
  ne le produit jamais. L'effet est porté et testé, mais aucun élément ne le
  porte. Chercher côté client, ou dans une passe non identifiée.
- **Le palier d'un élément est reconstruit.** `formula_inverse` n'est pas
  résolue dans le dépôt d'analyse. Sans effet sur l'altitude, mais il décide si
  la branche de difficulté consomme un tirage, donc il décale la suite du flux.
  Voir `CWTileFeatureGrid._tier_of`.
- **`World_findNearestEntityInRegion` a un nom trompeur** : c'est la recherche
  du site de région le plus proche du point déformé, portée en
  `CWTerrainField.nearest_site`. Rien à voir avec les entités.

Attention : la couche d'éléments change ce que produit le générateur, donc
invalide tout cache d'altitude persistant. Ne pas construire de cache disque
tant que 1.7 n'est pas figé non plus.

## 7. Assets voxels

### 7.1 Ce qu'il faut produire — et dans quel ordre

**Rien pour le jalon 1.6.** Il ne fait que déformer l'altitude, rendue avec la
palette existante.

Le jalon 1.7 (dispersion sur le terrain) est le premier qui en demande. La liste
n'est plus une estimation : le binaire d'origine charge **154 modèles voxels**
nommés, et leurs noms disent exactement de quels objets le monde a besoin. On
n'en reprend évidemment aucun — ce sont des créations originales — mais la
liste des *rôles* à remplir, elle, est sûre.

**Deux choses ne sont pas des assets, contrairement à ce qu'on croirait :**

- **Les arbres.** Aucun modèle d'arbre dans les 154. Ils sont construits par le
  code, dans `WorldInfo_generateBiomeContent`. C'est un algorithme à porter, pas
  un modèle à dessiner.
- **Les maisons.** `cube::House::ctor_0(3, 3, 4)` : une maison est une grille de
  3 × 3 × 4 cellules remplie procéduralement. Là encore un algorithme (jalon
  4.3). Ce sont les *meubles* qui sont des modèles, pas le bâtiment.

**Lot A — jalon 1.7, la végétation et le sol.** ~35 modèles, c'est par là qu'il
faut commencer :

| famille | rôles à remplir |
|---|---|
| herbes | 3 variantes d'herbe, 1 buisson, 1 broussaille, 1 roseau |
| fleurs | 2 bouquets génériques + 5 fleurs distinctes (dont une « rare » lumineuse) |
| désert | 2 cactus |
| sous-bois | 1 champignon, 1 lierre, 1 liane, 1 vrille, 1 feuille au sol |
| aquatique | 1 algue, 1 corail, 1 étoile de mer |
| minéral | 2 pierres, 1 grès |
| cultures | blé, maïs, carotte, coton, citrouille — pour les champs des villages |

**Lot B — jalon 4, le décor bâti.** ~50 modèles : mobilier (table, tabouret,
banc, lit, table de chevet, buffet, 3 étagères, comptoir, 3 tapis, 2 tableaux,
4 vases, lustre, 3 bougies), artisanat (enclume, four, établi, scie, métier à
tisser, rouet, fourche), extérieur (4 clôtures, portail, porte, fenêtre, torche,
lanterne, feu de camp, tente, abri, épouvantail, tonneau, caisse, sac, obélisque,
pierre runique), ambiance de donjon (toiles d'araignée, crâne, dépouille).

**Hors périmètre pour l'instant** : objets d'inventaire (~40 : nourriture, armes,
équipement — jalon 3.2), créatures et poissons (jalon 2, et l'apparence des
créatures est explicitement hors périmètre), effets et icônes d'interface.

### 7.2 Avant de dessiner 35 modèles : en faire un seul

L'échelle n'est pas déductible de la décompilation. **Fais un seul modèle de
test — un buisson, par exemple — et on le pose en jeu sur le terrain généré
avant que tu produises la suite.** Une demi-heure pour caler l'échelle, contre
plusieurs jours de modèles à refaire s'ils sortent deux fois trop gros.

Repères sûrs en attendant :
- 1 voxel de modèle = 1 bloc de terrain. Le monde monte à ~600 blocs de relief ;
- un élément de tuile de type 14 (l'unité d'agglomération) revendique un rayon
  de 150 blocs, calé sur la grille de 256 : c'est un *quartier*, pas un bâtiment.
  Le modèle qu'on y posera est bien plus petit que ce rayon.

### 7.3 Décision d'authoring — prise

**MagicaVoxel, pas d'éditeur maison.** `VoxelVoxLoader` est intégré au build : un
`.vox` se charge en un appel, avec sa palette, directement dans le modèle de
rendu déjà utilisé. Un éditeur maison représenterait des semaines pour zéro
gameplay, et c'est l'auteur des assets qui en subirait chaque manque.

La palette de projet est en place : `assets/palette/zentarys_palette.png` à
glisser sur la palette de MagicaVoxel, plages réservées documentées dans
`assets/palette/PALETTE.md`, source unique dans `CWPalette`, et six
vérifications qui empêchent une plage de bouger en silence.

Deux faits mesurés sur l'import `.vox`, à ne pas redécouvrir :
- les index de palette se conservent exactement (le décalage d'un cran du format
  est absorbé par le chargeur) ;
- les axes sont permutés : `vox(x, y, z) -> godot(y, z, x)`. Le haut reste le
  haut, le plan horizontal est échangé.

Outillage Godot à écrire plus tard, et seulement là où MagicaVoxel ne peut pas
aider : placement et prévisualisation **en contexte** (une structure posée sur le
terrain réellement généré), au jalon 4. Pas un éditeur généraliste.

## 8. Décisions ouvertes

- Le relief lointain paraît bleuté (ambiante du ciel sur les faces détournées du
  soleil). Réglage d'ambiance, pas un défaut de génération.
- Les teintes des plages d'assets sont des rampes de départ, à ajuster. Le
  découpage en plages, lui, est un contrat : le changer invalide les modèles
  déjà peints.
- Les arêtes du graphe de sites ne sont **pas** le tracé des routes : le type 1
  est un élément unique par zone, posé sur son site. `site_edge_radius` reste
  donc à 0, et l'hypothèse notée au jalon 1.5 est close.
