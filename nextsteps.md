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
# Suite de validation (113 vérifications, ~70 s)
godot.windows.editor.double.x86_64.exe --headless --path . -s tests/worldgen_test.gd

# Réimport après ajout d'un class_name (sinon l'éditeur ne le voit pas)
godot.windows.editor.double.x86_64.exe --headless --path . --import

# Réexport de la palette après modification de CWPalette
godot.windows.editor.double.x86_64.exe --headless --path . -s tools/export_palette.gd

# Gros plan ombré sur un élément de tuile, avec et sans la couche
# (x, z, unités par pixel ; sans argument : le point de départ, 6 u/px)
godot.windows.editor.double.x86_64.exe --headless --path . \
    -s tools/preview_features.gd -- 8397830 8399776 6

# Inventaire des modèles voxels : gabarit, index employés, plages de palette
# (sans argument : tout assets/models/)
godot.windows.editor.double.x86_64.exe --headless --path . -s tools/inspect_model.gd

# Gabarit d'échelle en jeu : mettre scale_board = true sur le nœud racine de
# scenes/terrain_demo.tscn, puis lancer. Deux captures dans user://shots.
godot.windows.editor.double.x86_64.exe --path . scenes/terrain_demo.tscn
```

Aperçus PNG écrits par la suite de tests dans
`user://worldgen_preview/` (`height.png`, `climate.png`, `channels.png`) →
`C:\Users\Admin\AppData\Roaming\Godot\app_userdata\Zentarys\worldgen_preview\`.

Démo : `res://scenes/terrain_demo.tscn`. Clic pour capturer la souris,
ZQSD/WASD, Maj = rapide, Espace/Ctrl = monter/descendre, **F1** détails,
**F12** capture d'écran dans `user://shots`, **Page haut/bas** distance de vue,
**1-9** téléportation vers un biome, **Échap** rend la souris puis quitte.

## 3. État

Jalon 1 (le monde) : 1.1 à 1.6 faits ; **1.7 à moitié** — toute la mécanique de
dispersion est en place et testée, l'échelle des assets est fixée, il reste la
lecture du binaire qui dira *quoi* poser *où*. Le reste à faire. Détail et
sources analysées dans `docs/ROADMAP.md`. Analyse du système de terrain dans
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
  cw_voxel_model.gd        modèle .vox préparé : liste creuse, maillage 1/16
  cw_model_library.gd      chargement des modèles + table modèle/biome
  cw_scatter.gd            grille de dispersion 16², cellules en cache
  cw_flora_renderer.gd     instanciation de la flore (MultiMesh par cellule)
src/demo/terrain_demo.gd   scène de démonstration (arbre voxel construit en code)
src/demo/scale_board.gd    gabarit d'échelle : mires, silhouette, modèles
tests/worldgen_test.gd     suite headless, 113 vérifications
tests/tile_features_test.gd  la moitié qui concerne les éléments de tuile
tests/flora_test.gd        modèles, dispersion, maillage et pose (jalon 1.7)
tools/export_palette.gd    régénère assets/palette/*.png depuis CWPalette
tools/preview_features.gd  gros plan ombré, avec et sans la couche d'éléments
tools/inspect_model.gd     inventaire d'un .vox : gabarit, index, plages
assets/palette/            palette de projet + PALETTE.md
assets/models/             modèles voxels + MODELS.md (échelle et conventions)
docs/images/               gabarit d'échelle photographié en jeu
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
10. **Un bloc de terrain vaut 16 voxels de modèle, et rien ne doit l'assouplir.**
    `CWVoxelModel.VOXELS_PER_BLOCK` est un contrat d'authoring : le changer
    invalide tous les `.vox` déjà dessinés, qui sont irrécupérables autrement
    qu'en les redessinant. Un test le verrouille. Ce qui *peut* bouger au jalon
    3.1, c'est la taille du personnage en blocs (2 aujourd'hui) — les modèles,
    eux, se remettent à l'échelle ensemble.
11. **La flore n'est jamais écrite dans les données voxels du monde.** Elle est
    seize fois plus fine que la grille du terrain. Le générateur ne la consulte
    plus du tout ; elle est instanciée par `CWFloraRenderer`. Le test « le
    terrain ne contient plus de flore » attrape un retour en arrière — qui, sans
    lui, ferait juste doublon avec l'instance, sans erreur.
12. **Le mailleur consomme sa marge.** L'origine d'un maillage tombe sur le
    premier voxel utile du tampon, pas sur son coin : tout maillage construit à
    la main doit retrancher `CWVoxelModel.mesher_padding()`. L'oublier enterre
    l'objet d'un voxel — assez peu pour passer inaperçu à l'œil, d'où le test
    « la plante pose sur le sol, quelle que soit son orientation ».
13. **L'ancre d'un modèle est au centre de son empreinte et à sa base.** Le
    déplacer décale toute la flore déjà produite, et un modèle dessiné avec un
    socle vide sous lui flotte de la hauteur du socle.

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
- **La couche de flore ne coûte plus rien au générateur.** Depuis qu'elle est
  instanciée au lieu d'être estampée, `_generate_block` ne la consulte plus : les
  +14 % par bloc mesurés le 2026-09-04 ont disparu du chemin de génération. Le
  coût s'est déplacé sur `CWFloraRenderer`, qui construit ses cellules sur un
  fil du pool — **1,1 ms par cellule** de 256 colonnes en prairie (1 + n
  échantillonnages : un pour décider la densité, un par plante posée). Ne pas
  revenir à un tirage à rejet : échantillonner un candidat pour le jeter ensuite
  triplait la facture.
- **Ne pas mettre d'appel de liaison moteur sur le chemin chaud.**
  `OS.get_thread_caller_id()` dans `CWTileFeatureGrid.get_zone` coûtait ~15 µs
  par colonne avant d'être déplacé sur le chemin froid. Mesurer avant de
  supposer que c'est le verrou qui coûte.

## 6. Prochaine tâche — jalon 1.7, contenu de biome

### Ce qui est fait (2026-09-04)

La **mécanique** de dispersion est en place, testée et mesurée. Ce qui manque
n'est plus du code d'infrastructure, c'est la lecture du binaire.

- `CWVoxelModel` : un `.vox` chargé, converti en liste creuse, quatre quarts de
  tour précalculés, ancre au centre de l'empreinte et à la base. Plus une
  réduction par union (`reduced(n)`), qui ne sert qu'à montrer une échelle cible.
- `CWModelLibrary` : chargement partagé et table modèle/biome. Un modèle absent
  du disque est ignoré en silence — la production des assets est étalée.
- `CWScatter` : grille de cellules de 16, une graine par cellule, densité décidée
  sur le centre de la cellule et position tirée dedans. Cellules en cache sous
  mutex, comme les cartes de hauteurs.
- `CWFloraRenderer` instancie : un `MultiMeshInstance3D` par modèle et par
  cellule, cellules construites par lots sur un fil du pool, détruites au-delà
  de la distance de vue de la flore. `CWVoxelGenerator`, lui, ne connaît plus la
  flore du tout.
- 30 vérifications dans la suite (`tests/flora_test.gd`) : rotations,
  déterminisme, huit fils concurrents, pose sur le sol aux quatre quarts de
  tour, absence de flore dans les données du terrain, coût d'une cellule.
- **L'échelle des assets est fixée** : voir §7.1. Deux grilles, 16 voxels par
  bloc, personnage à 2 blocs. C'était le point bloquant.

### Ce qui reste — l'analyse de `WorldInfo_generateBiomeContent` (@005e4850)

4 200 lignes, non analysées. Trois choses à en tirer :

1. **la table qui dit quel modèle va dans quel biome.** La répartition de §7.2 et
   les densités de `CWModelLibrary.DENSITY` sont des propositions de bon sens ;
   les remplacer coûte quelques lignes ;
2. **la génération procédurale des arbres.** Aucun modèle d'arbre parmi les 154
   du binaire : c'est un algorithme, pas un asset ;
3. **l'identité de chaque type d'élément de tuile** — ce que sont réellement les
   types 2, 3, 5, 10, 11, 12, 14 et 15 posés au jalon 1.6.

| fonction | adresse | rôle |
|---|---|---|
| `WorldInfo_generateBiomeContent` | `@005e4850` | contenu par biome, arbres, décor |
| `World_populateRegionDecorations` | `game_misc.cpp:36135` | dispersion du décor |
| `World_carveTerrainFeatureA` / `B` | `game_misc.cpp:35597` / `35872` | formes creusées dans le terrain |
| `WorldInfo_placeStructure` | `@005f0ce0` | placement de structures (jalon 4) |

**Deux noms trompeurs relevés à l'analyse**, à ne pas redécouvrir :

- **`WorldInfo_scatterObjectsInArea` (@005f56c0) ne disperse pas d'objets.** Elle
  échantillonne température et humidité, puis empile des identifiants dans un
  vecteur selon le climat et le niveau ; son résultat est écrit dans un objet
  `cube::Spawn` fraîchement construit. C'est le **choix d'espèce d'un point
  d'apparition** — jalon 2.6, pas 1.7. La feuille de route la listait comme la
  seconde source de 1.7 : c'est corrigé.
- **`World_generateTreeRecursive` (@005d9460) ne génère pas d'arbres.** Le corps
  est de la gestion de cellules de région et de `cube::Spawn` (décalages de 3 et
  6 bits, bornes 0x2000 et 0x400). Le générateur d'arbres est ailleurs, sans
  doute inliné dans `generateBiomeContent`.

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

Un cache disque du terrain reste prématuré tant que 1.7 n'est pas figé — non
plus à cause de la flore, qui a quitté les données du monde, mais parce que la
couche d'éléments de tuile, elle, y écrit encore.

## 7. Assets voxels

### 7.1 L'échelle — fixée le 2026-09-04

**Il y a deux grilles.** Le terrain a un pas d'un bloc ; les modèles ont un pas
seize fois plus fin. **Un bloc de terrain vaut 16 voxels de modèle
(`CWVoxelModel.VOXELS_PER_BLOCK`), et le personnage de référence mesure 2 blocs,
soit 32 voxels.** Le détail par catégorie d'objet est dans
`assets/models/MODELS.md` — c'est le fichier à donner à qui modélise.

C'est ce rapport, et lui seul, qui sépare ce rendu de celui de Minecraft : de
gros cubes de terrain, mais du détail sur ce qui est posé dessus. Une touffe
d'herbe est faite de lames d'un voxel d'épaisseur ; un personnage de 2 blocs a
des yeux d'un voxel.

**D'où sort le nombre.** D'une mesure au pixel sur une capture du jeu d'origine,
pas d'un jugement à l'œil : brin d'herbe 7 px de large, pupille du personnage
6 px, écart entre les yeux 28 px, hauteur du personnage 205 px, face verticale
d'une marche de terrain 90 px. Le brin d'herbe et la pupille font la même
largeur — **la flore et le personnage sont sur la même grille fine**. Rapport
mesuré : ~13 voxels par bloc ; on retient 16, la puissance de deux la plus
proche.

**À revoir au jalon 3.1**, quand le contrôleur donnera la taille réelle du
personnage. Si elle s'écarte de 2 blocs, c'est ce seul nombre qui change. Le
rapport de 16, lui, est un contrat d'authoring : le changer invalide tous les
modèles déjà dessinés, et il est verrouillé par un test.

**Ce que ça a changé dans le code** (2026-09-04) :

- la flore n'est **plus estampée** dans les données voxels du monde — elle y
  serait seize fois trop grosse. `CWVoxelGenerator` ne la consulte plus du tout,
  et le surcoût de +14 % par bloc a disparu du chemin de génération ;
- `CWVoxelModel.mesh()` maille le modèle une fois, avec **le même mailleur, la
  même palette et le même matériau que le terrain** — c'est la condition pour
  que les deux grilles lisent comme un seul monde ;
- `CWFloraRenderer` instancie : un `MultiMeshInstance3D` par modèle et par
  cellule de dispersion, construit par lots sur un fil du pool, détruit au-delà
  de `view_distance` (128 blocs par défaut) ;
- les plantes se posent **sous le bloc** (`Placement.fx`, `fz`, au pas d'un
  voxel) : sans ça toute la flore s'alignerait sur la grille du terrain ;
- les densités de `CWModelLibrary` sont doublées — à nombre égal, des plantes
  huit fois plus courtes laissent le sol nu.

Conséquences à connaître : la flore ne se creuse pas, ne porte pas de collision,
et ne participera pas à l'éclairage voxel du jalon 1.9.

**Pour revoir l'échelle soi-même** : mettre `scale_board = true` sur le nœud
racine de `scenes/terrain_demo.tscn` et lancer la démo. Le gabarit pose des mires
de 1 à 16 blocs, la silhouette du personnage à la grille fine, puis chaque modèle
chargé ; deux captures partent dans `user://shots`. Un `.vox` déposé dans
`assets/models/flore/` y apparaît sans qu'il y ait rien à déclarer.

Pour regarder autre chose que le gabarit sans piloter la fenêtre :
`auto_shot_delay` sur le même nœud, puis `--quit-after`.

### 7.2 Ce qu'il faut produire, par biome

**Rien pour le jalon 1.6** : il ne fait que déformer l'altitude, rendue avec la
palette existante. Le jalon 1.7 (dispersion sur le terrain) est le premier qui
demande des modèles — et la mécanique qui les pose est en place : déposer un
`.vox` dans `assets/models/flore/` suffit à le voir dans le monde, dès lors que
son nom figure dans la table de `CWModelLibrary`.

La liste des *rôles* n'est plus une estimation : le binaire d'origine charge
**154 modèles voxels nommés**. On n'en reprend aucun — ce sont des créations
originales — mais ce dont un monde comme celui-là a besoin est établi.

**Deux choses ne sont pas des assets**, contrairement à ce qu'on croirait :

- **Les arbres.** Aucun modèle d'arbre parmi les 154. Ils sont construits par le
  code, dans `WorldInfo_generateBiomeContent`. Algorithme à porter, pas modèle à
  dessiner.
- **Les maisons.** `cube::House::ctor_0(3, 3, 4)` : une grille de 3 × 3 × 4
  cellules remplie procéduralement (jalon 4.3). Ce sont les *meubles* qui sont
  des modèles, pas le bâtiment.

#### Convention de nommage

Dossier `assets/models/flore/`, un fichier `.vox` par entrée. Noms en minuscules
sans accent, souligné pour séparer, variante numérotée sur deux chiffres quand
les modèles sont interchangeables. Les couleurs viennent de la plage
**Végétation, indices 128 – 175** de la palette de projet (voir
`assets/palette/PALETTE.md`) — sauf les cailloux et le grès, qui prennent la
plage **Terrain, 1 – 31**.

#### Les neuf surfaces que le générateur produit

Ce sont les biomes réels : `CWPalette.surface_index` ne peut en rendre aucun
autre. Touches **1** à **9** de la démo pour s'y téléporter.

| biome | fichiers à produire |
|---|---|
| **herbe** (tempéré) | `herbe_01` `herbe_02` `herbe_03` `buisson` `bouquet_01` `bouquet_02` `fleur_bleuet` `fleur_tournesol` `caillou_01` `caillou_02` |
| **herbe sèche** (steppe) | `herbe_seche` `broussaille` `fleur_echinacea` `caillou_01` `caillou_02` |
| **jungle** (chaud, humide) | `liane` `vrille` `lierre` `feuille` `fleur_coeur` `champignon` |
| **marais** | `roseau` `champignon` `lierre` `fleur_ame` |
| **sable** (désert et plage) | `cactus_01` `cactus_02` `broussaille` `gres` |
| **neige** | `caillou_01` `broussaille` |
| **toundra** | `broussaille` `fleur_ginseng` `caillou_01` |
| **roche** | `caillou_01` `caillou_02` |
| **gravier** (fond marin) | `algue` `corail` `etoile_de_mer` |

Beaucoup de fichiers reviennent dans plusieurs biomes : **c'est voulu**, on n'en
produit qu'un seul exemplaire. Total réel : **28 modèles**.

#### Plus cinq cultures, pour les champs des villages

`ble` `mais` `carotte` `coton` `citrouille` — mêmes conventions, dossier
`assets/models/culture/`. Elles ne sont pas dispersées par biome mais posées en
rangées par le système de champs (`Field.cpp`, jalon 4.3). À faire après les 28.

#### Une réserve d'honnêteté sur l'affectation

Quels modèles vont dans quel biome **n'est pas encore lu dans le binaire** : la
table de correspondance est dans `WorldInfo_generateBiomeContent` (@005e4850),
3 100 lignes, pas encore analysée. La répartition ci-dessus est une proposition
de bon sens (cactus au désert, corail sous l'eau).

Ça ne change rien à ce qu'il faut produire — la *liste* des 28 est sûre, elle
vient des noms de modèles du binaire. Seule l'affectation peut bouger, et
réaffecter un modèle existant coûte une ligne de code.

#### Les lots suivants, pour information

- **Jalon 4, décor bâti (~50)** : mobilier (table, tabouret, banc, lit, table de
  chevet, buffet, 3 étagères, comptoir, 3 tapis, 2 tableaux, 4 vases, lustre,
  3 bougies), artisanat (enclume, four, établi, scie, métier à tisser, rouet,
  fourche), extérieur (4 clôtures, portail, porte, fenêtre, torche, lanterne,
  feu de camp, tente, abri, épouvantail, tonneau, caisse, sac, obélisque, pierre
  runique), donjon (toiles d'araignée, crâne, dépouille).
- **Jalon 3.2, objets d'inventaire (~40)** : nourriture, armes, équipement.
- **Jalon 2, créatures et poissons.** L'apparence des créatures est
  explicitement hors périmètre : c'est le gréement et l'animation procédurale
  qui sont portés, pas les modèles.

### 7.3 Décision d'authoring — prise, et confirmée

**MagicaVoxel, pas d'éditeur maison.** `VoxelVoxLoader` est intégré au build : un
`.vox` se charge en un appel, avec sa palette, directement dans le modèle de
rendu déjà utilisé. Un éditeur maison représenterait des semaines pour zéro
gameplay, et c'est l'auteur des assets qui en subirait chaque manque.

**La seule objection sérieuse est levée.** On ne peut pas réduire le pinceau de
MagicaVoxel sous un voxel — et il n'y en a pas besoin : sa grille est *sans
unité*. On ne descend pas sous le voxel, on agrandit la boîte, et c'est le moteur
qui applique le 1/16 à l'import. Un personnage détaillé se dessine dans un
gabarit de 32 de haut, une touffe d'herbe dans 12.

Pour garder l'œil juste en modélisant, poser dans la scène MagicaVoxel un cube de
16³ (= un bloc de terrain) et une silhouette de 32 de haut (= le personnage).
C'est ça qui remplace le réglage de taille du pinceau.

**L'établi de personnalisation façon Cube World reste au programme** — il est
d'ailleurs dans la liste du mobilier du jalon 4. Mais c'est une *fonctionnalité
de jeu*, pas un outil d'authoring : grille fixe et petite, palette contrainte par
le matériau, sortie = un objet d'inventaire et ses statistiques. Il se pose sur
l'inventaire (3.2), qui se pose sur le contrôleur (3.1). Il réutilisera
`CWVoxelModel` et son maillage tels quels — le travail est déjà fait.

La palette de projet est en place : `assets/palette/zentarys_palette.png` à
glisser sur la palette de MagicaVoxel, plages réservées documentées dans
`assets/palette/PALETTE.md`, source unique dans `CWPalette`, et six
vérifications qui empêchent une plage de bouger en silence.

Trois faits mesurés sur l'import et le maillage, à ne pas redécouvrir :
- les index de palette se conservent exactement (le décalage d'un cran du format
  est absorbé par le chargeur) ;
- les axes sont permutés : `vox(x, y, z) -> godot(y, z, x)`. Le haut reste le
  haut, le plan horizontal est échangé ;
- **le mailleur consomme sa marge** : l'origine du maillage tombe sur le premier
  voxel utile, pas sur le coin du tampon. Sans retrancher
  `CWVoxelModel.mesher_padding()`, tout ce qui est instancié est enterré d'un
  voxel — assez peu pour rester plausible à l'œil, ce qui est exactement la
  raison pour laquelle un test le mesure.

Gabarits mesurés en sortie du générateur d'éléments de tuile, utiles pour situer
les échelles — le rayon est un rayon d'*influence*, pas l'encombrement du modèle :

| type | par zone | rayon | position |
|---|---|---|---|
| 14 | ~16 | 150 u | calée sur la grille de 256 |
| 11, 12 | ~2 chacun | 128 u | calée sur la grille de 256 |
| 10 (donjon) | ≤ 5 | 512–767 u | libre dans la tuile |
| 2, 3 | ~2 chacun | 512–767 u | libre dans la tuile |
| 5 | ~2 | 256–511 u | libre dans la tuile |

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
