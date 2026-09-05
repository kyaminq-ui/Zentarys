# Zentarys — reprise de session

Fichier de reprise après un `/clear`. À lire en entier avant de toucher au code :
il contient des décisions qui coûtent cher à redécouvrir.

---

## 1. Où sont les choses

| quoi | chemin |
|---|---|
| Projet Godot | `C:\Users\Admin\Documents\zentarys\` |
| Exécutable Godot | `C:\Users\Admin\Desktop\godot.windows.editor.double.x86_64.exe` |
| Source d'analyse (rétro-ingénierie) | `C:\Users\Admin\Documents\zentarys\CubeWorld-Reversal-master\` (ignorée par git) |

Godot 4.7.2 stable, **double précision**, module Voxel Tools 1.7 compilé dedans
(`VoxelTerrain`, `VoxelMesherCubes`, `VoxelGeneratorScript`, `VoxelVoxLoader`…).
Le greffon `addons/godot_ai` est actif : l'éditeur peut être piloté par MCP
(`session_manage`, `project_run`, `editor_screenshot`, `game_manage`…).

Dépôt : <https://github.com/kyaminq-ui/Zentarys.git> (branche `main`).
Le greffon `addons/godot_ai` est versionné avec le reste : sans lui, le projet
ne s'ouvre pas proprement (il est déclaré dans `project.godot`).

## 2. Commandes

```
# Suite de validation (162 vérifications, ~70 s)
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path . -s tests/worldgen_test.gd

# Réimport après ajout d'un class_name (sinon l'éditeur ne le voit pas)
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path . --import

# Réexport de la palette après modification de CWPalette
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path . -s tools/export_palette.gd

# Gros plan ombré sur un élément de tuile, avec et sans la couche
# (x, z, unités par pixel ; sans argument : le point de départ, 6 u/px)
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path . \
    -s tools/preview_features.gd -- 8397830 8399776 6

# Inventaire des modèles voxels : gabarit, index employés, plages de palette
# (sans argument : tout assets/models/)
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path . -s tools/inspect_model.gd

# Remise d'un lot de modèles dans la palette de projet (rapport, puis écriture)
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path . -s tools/repaint_models.gd
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path .     -s tools/repaint_models.gd -- --write

# Regénération du lot de flore (39 .vox, ~2 min). Déterministe : une graine en
# dur par fichier. `-- --seul <nom>` ne refait qu'un modèle.
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python tools/blender/generer_flore.py

# Gabarit d'échelle en jeu : mettre scale_board = true sur le nœud racine de
# scenes/terrain_demo.tscn, puis lancer. Deux captures dans user://shots.
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --path . scenes/terrain_demo.tscn
```

Aperçus PNG écrits par la suite de tests dans
`user://worldgen_preview/` (`height.png`, `climate.png`, `channels.png`) →
`C:\Users\Admin\AppData\Roaming\Godot\app_userdata\Zentarys\worldgen_preview\`.

Démo : `res://scenes/terrain_demo.tscn`. Clic pour capturer la souris,
ZQSD/WASD, Maj = rapide, Espace/Ctrl = monter/descendre, **F1** détails,
**clic gauche** creuser, **clic droit** poser,
**F12** capture d'écran dans `user://shots`, **Page haut/bas** distance de vue,
**1-9** téléportation vers un biome, **Échap** rend la souris puis quitte.

## 3. État

Jalon 1 (le monde) : 1.1 à 1.6 faits ; **1.7 à moitié** — la mécanique de
dispersion est en place, **conforme aux deux fréquences de l'original** depuis
le 2026-09-05, testée, l'échelle est fixée, et depuis le 2026-09-05
**les 28 modèles du lot de flore sont livrés, intégrés et visibles en jeu** (39
fichiers : plusieurs rôles ont un modèle par biome). Le lot a été **redessiné le
même jour à l'échelle 40/3**, et il est maintenant **produit par script**
(`tools/blender/generer_flore.py`) et non plus à la main. Il reste la lecture du
binaire, qui dira *quoi* poser *où* et à quelle densité. **La table des entités
est lue** (2026-09-05) : elle est dans le `switch` de
`creature_generateAppearance`, et non dans les deux fonctions au nom prometteur,
qui ne dispersent de la flore ni l'une ni l'autre. Reste la seconde voie de pose,
celle de la flore basse. **Le jalon 1.8 est fait** (2026-09-05) : édition du
terrain, requête ponctuelle et persistance du diff. Restent 1.9 et 1.10. Détail et sources
analysées dans `docs/ROADMAP.md`. Analyses : `docs/systems/01_generation_terrain.md` (terrain),
`docs/systems/02_contenu_de_biome.md` (contenu de biome, éléments de tuile,
apparitions), `docs/systems/03_colonnes_et_edition.md` (colonnes, blocs,
édition, persistance), `docs/systems/04_eclairage.md` (éclairage voxel :
algorithme établi, portage suspendu à une décision de rendu).

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
  cw_voxel_model.gd        modèle .vox préparé : liste creuse, maillage 3/40
  cw_model_library.gd      chargement des modèles + table modèle/biome
  cw_scatter.gd            grille de dispersion 16², cellules en cache
  cw_flora_renderer.gd     instanciation de la flore (MultiMesh par cellule)
  cw_world_edits.gd        creuser, poser, interroger un bloc (jalon 1.8)
src/demo/terrain_demo.gd   scène de démonstration (arbre voxel construit en code)
src/demo/scale_board.gd    gabarit d'échelle : mires, silhouette, modèles
tests/worldgen_test.gd     suite headless, 162 vérifications
tests/tile_features_test.gd  la moitié qui concerne les éléments de tuile
tests/flora_test.gd        modèles, dispersion, maillage et pose (jalon 1.7)
tests/edit_test.gd         règles d'édition, requête ponctuelle, persistance (1.8)
tools/export_palette.gd    régénère assets/palette/*.png depuis CWPalette
tools/preview_features.gd  gros plan ombré, avec et sans la couche d'éléments
tools/inspect_model.gd     inventaire d'un .vox : gabarit, index, plages
tools/repaint_models.gd    remet un .vox dans la palette de projet
tools/blender/             générateur du lot de flore (Python + bpy)
  flore_vox.py               palette verbatim, écriture .vox, garde-fous
  flore_formes.py            brins, tiges, feuilles, corolles, cailloux
  flore_blender.py           courbes, métaballes, échantillonnage sur grille
  generer_flore.py           le catalogue des 39, une graine par modèle
assets/palette/            palette de projet + PALETTE.md
assets/models/flore/<biome>/  39 modèles, un dossier par biome
assets/models/             MODELS.md (échelle, palette et conventions)
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
10. **Un bloc de terrain vaut 40/3 voxels de modèle — 3 blocs = 40 voxels.**
    `CWVoxelModel.VOXELS_PER_BLOCK` est un contrat d'authoring, verrouillé par
    deux tests. La valeur vient de l'original : ses échelles d'instanciation du
    décor sont 0,075 / 0,09 / 0,1, et **0,075 = 3/40 exactement**. Écrire
    `13.333` ferait dériver le rapport ; c'est la fraction qui est dans le code.
    Un cube de référence d'un bloc n'est pas entier : dans MagicaVoxel on pose un
    cube de **40 = 3 blocs**. Ce qui *peut* bouger au jalon 3.1, c'est la taille
    du personnage en blocs (2,4 aujourd'hui) — les modèles se remettent à
    l'échelle ensemble.
11. **`CWScatter.SUBBLOCK_STEPS` n'est pas `VOXELS_PER_BLOCK`.** La finesse de
    *position* d'une plante sous son bloc est une grille entière (16 pas) ; la
    grille de *dessin* vaut 40/3 et n'est plus entière. Les deux ont été
    confondues tant que le rapport tombait juste. Repasser la position sur
    `VOXELS_PER_BLOCK` casse le parse — `rng.mod()` prend un entier.
12. **La flore n'est jamais écrite dans les données voxels du monde.** Elle est
    treize fois plus fine que la grille du terrain. Le générateur ne la consulte
    plus du tout ; elle est instanciée par `CWFloraRenderer`. Le test « le
    terrain ne contient plus de flore » attrape un retour en arrière — qui, sans
    lui, ferait juste doublon avec l'instance, sans erreur.
13. **Le mailleur consomme sa marge.** L'origine d'un maillage tombe sur le
    premier voxel utile du tampon, pas sur son coin : tout maillage construit à
    la main doit retrancher `CWVoxelModel.mesher_padding()`. L'oublier enterre
    l'objet d'un voxel — assez peu pour passer inaperçu à l'œil, d'où le test
    « la plante pose sur le sol, quelle que soit son orientation ».
14. **L'ancre d'un modèle est au centre de son empreinte et à sa base.** Le
    déplacer décale toute la flore déjà produite, et un modèle dessiné avec un
    socle vide sous lui flotte de la hauteur du socle.
15. **La crête de placement s'évalue avant l'échantillonnage de colonne.**
    Un candidat hors plaque doit coûter un bruit (~1 µs), pas une colonne
    (~75 µs). Inverser les deux lignes de `CWScatter._build_cell` triple le coût
    d'une cellule *sans rien changer au résultat* — c'est le piège du tirage à
    rejet, déjà payé une fois le 2026-09-04.
16. **`PLACEMENT_PASS_RATE` compense le budget de candidats.** C'est elle qui
    fait que `CWModelLibrary.DENSITY` se lit encore en plantes par cellule. Si
    `CWValueNoise`, la fréquence ou le seuil bougent sans qu'elle suive, la
    densité de tous les biomes dérive en silence. Un test la mesure. Et elle se
    mesure sur **plusieurs régions éloignées** : autour du seul point de départ
    elle sort à 0,3012 au lieu de 0,2917.
17. **La gigue d'échelle doit atteindre l'empreinte, pas seulement le dessin.**
    Une instance va jusqu'à 2× son modèle : la marge de
    `CWScatter.placements_in` et la boîte de visibilité de chaque `MultiMesh` se
    calculent sur `Placement.radius_blocks()`, jamais sur `model.radius_blocks`.
    L'oublier fait disparaître les grandes touffes de la bordure du champ — et
    seulement celles-là, donc ça se voit tard.
18. **`CWVoxelGenerator.voxel_of` a deux consommateurs qui doivent s'accorder.**
    `_generate_block` la déroule par intervalles, `generated_voxel` l'évalue en un
    point. Rien dans le code ne les y oblige : c'est le test « la requête
    ponctuelle dit la même chose que le bloc généré » (4 096 points) qui tient le
    contrat. Une couche ajoutée au générateur et oubliée dans la règle donnerait
    des collisions portant sur un monde qui n'est plus celui qu'on voit. Et
    l'ordre des tests dans `voxel_of` est celui des recouvrements de
    `_generate_block` : la surface avant la roche, sinon `subsurface_depth = 0`
    rend de la roche là où le monde montre de l'herbe.
19. **Les éditions ne partent sur le disque que si `_flush_edits` tourne.**
    Fermer la fenêtre passe par `WM_CLOSE_REQUEST`, mais `--quit-after` et tout
    `SceneTree.quit()` direct n'envoient rien : d'où la seconde branche sur
    `NOTIFICATION_EXIT_TREE`. Sans elle, une session lancée pour une capture
    perd ses éditions sans un mot — constaté, 647 appliquées et zéro écrite.
20. **`CWWorldEdits` est en coordonnées de scène, `CWScatter` en coordonnées
    monde.** La table des sommets édités est lue par la dispersion : elle est
    donc rangée en coordonnées **monde**, et la conversion se fait dans
    `_set_top`, nulle part ailleurs. La première version s'est trompée de
    repère ; la recherche ne tombait jamais juste, la flore continuait de
    flotter, et **aucun test ne bronchait** parce que les deux côtés employaient
    le même repère. Un test qui ne traverse pas la conversion ne teste rien.
21. **`save_generator_output` doit rester à faux.** À vrai, chaque bloc visité
    part sur le disque et la sauvegarde grossit comme le monde exploré au lieu
    de grossir comme ce qu'on a touché. C'est aussi le modèle de l'original, qui
    ne sérialise que les colonnes modifiées.

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
- **Les 39 modèles de flore sont générés, pas dessinés.** Les rouvrir dans
  MagicaVoxel pour les retoucher est du travail perdu : la prochaine exécution
  de `tools/blender/generer_flore.py` les écrase. Corriger le générateur, puis
  regénérer. Le script recopie le bloc `RGBA` de la palette de projet tel quel
  et refuse à l'écriture tout index hors plage — c'est ce qui rend impossible
  la faute de palette du premier lot.
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

### Ce qui est fait (2026-09-05) — le lot de flore est livré et intégré

Les **28 modèles** de §7.2 sont dessinés. Livrés en **39 fichiers**, rangés par
biome : plusieurs rôles ont reçu un modèle par biome au lieu d'un fichier
partagé — trois `caillou_01` (prairie, neige, roche), quatre `broussaille`, deux
`champignon`, trois `lierre`. C'est mieux que ce que prévoyait §7.2, et
`CWModelLibrary.FLORA` porte donc maintenant des **chemins**, dossier de biome
compris.

Trois choses ont dû être réparées pour que le lot arrive en jeu :

1. **La palette.** Les 39 fichiers étaient peints sur une palette rééchantillonnée
   par MagicaVoxel (la planche de référence glissée sur le nuancier), donc avec
   les bonnes teintes aux **mauvais index** — et le rendu ne lit que l'index.
   Ils seraient sortis peints en couleurs de créatures et de structures, sans le
   moindre message d'erreur. Remis dans la palette de projet par
   `tools/repaint_models.gd`, qui réécrit index *et* palette embarquée : rouverts
   dans MagicaVoxel, les fichiers portent désormais la bonne palette. La cause et
   le geste correct — **ouvrir `assets/palette/zentarys_palette.vox`**, jamais
   glisser le PNG de référence — sont dans `assets/palette/PALETTE.md`.
2. **Deux plages de palette étaient inutilisables.** La réserve de terrain 14-31
   était vide : les six cailloux se rabattaient tous sur `STONE`. Et rien dans la
   palette n'était froid et saturé : le corail se rabattait sur le vert de
   prairie. La réserve de terrain est remplie (roche, grès, argile, basalte,
   roche lichénée, lave) et deux entrées aquatiques (170-171) sont prises sur la
   rampe des champignons. Le **découpage** des plages n'a pas bougé.
3. **Les noms.** `caillou_1`/`caillou_2` → `caillou_01`/`caillou_02`, et
   `cactus_01_grille48`/`cactus_02_grille32` → `cactus_01`/`cactus_02` : la
   taille du gabarit ne se met pas dans le nom, elle est libre.

Trois vérifications de plus (116 au total) : chaque entrée de la table existe sur
le disque, aucun modèle ne porte d'index translucide, la réserve de terrain est
renseignée. Le gabarit d'échelle range les modèles par rangées de dix, sinon
trente-neuf modèles en file font cent vingt blocs de large et le gros plan n'en
cadre plus trois. Images refaites dans `docs/images/`.

### Fait (2026-09-05) — première passe sur `WorldInfo_generateBiomeContent`

Analysée, note complète dans **`docs/systems/02_contenu_de_biome.md`**. Les
4 200 lignes sont cartographiées, pas portées. Ce qu'il faut en retenir ici :

- **elle ne disperse pas de flore.** Ce n'est pas « le contenu de biome » mais le
  **constructeur d'une cellule de 256 × 256 colonnes** — terrain fin, couleur,
  déformations, points d'apparition. Chercher la table modèle/biome dedans était
  une impasse ;
- **piège de lecture à ne pas redécouvrir** : Ghidra type les bornes de boucle en
  `float *`, donc `+ 0x40` est de l'arithmétique de pointeur = **+256 unités**.
  Une lecture littérale fait croire que la fonction ne traite qu'un seizième de
  sa cellule ;
- **second piège** : les comparaisons de type sont rendues en flottants
  dénormaux. `n × 1.4013e-45` est l'entier `n`. Sans ce décodage la fonction est
  illisible ;
- le **champ de densité de végétation** est extrait avec ses constantes exactes
  (quatre octaves, deux crêtes) — `docs/systems/02`, §3 ;
- **`terrain_generateColumnColor` ne rend pas une couleur mais une hauteur de
  colonne.** Troisième nom trompeur du dépôt d'analyse ;
- le portage du jalon 1.6 est **corroboré indépendamment** : stride `0x68`, base
  `+0x14018`, ordre `tz + tx·8`, type à `+0x18`.

**Identité des types d'éléments de tuile** (la question ouverte du jalon 1.6) :
6 = champ de rochers, 11 = massif isolé, 12 = plan d'eau, 3 = parcelle bâtie.
Les types 2, 10, 14, 15 restent à isoler. Le type 9, comme le 13, est traité par
la fonction mais jamais produit par `World_generateRegionFeatures`.

### Fait (2026-09-05, seconde passe) — la table modèle/biome est trouvée

Elle n'était dans **aucune** des deux fonctions au nom prometteur.
`World_generateVegetationCluster` (@005d8750) ne disperse pas de végétation :
c'est le *résolveur de contenu d'une tuile* — il vide les poses des 8 × 8
cellules, lit le type de l'élément, en tire une « sorte » de contenu, choisit la
meilleure cellule par poids d'influence et fixe un compte d'objets. Troisième
nom trompeur du lot.

La table est le `switch` d'apparence de **`creature_generateAppearance`**
(`game_misc.cpp:3197`), croisé avec les slots de chargement de `GameController`
(`vector_at_stride4(slot)` après chaque `"nom.cub"`). Tout est en
`docs/systems/02`, §5.

> **Flore, filons et créatures sont un seul espace de types d'entités.** Codes
> 120–130 = plantes, 131–139 = filons, 145–155 = poissons, en dessous les
> créatures. Une touffe d'herbe et un ours sont la même sorte d'objet. **La
> décision du 2026-09-04 de sortir la flore des données voxels est confirmée par
> la source** — pour une raison qui n'avait pas été anticipée.

Deux recoupements qui valident du travail déjà fait :

- les **boîtes englobantes** du `switch` sont en blocs de terrain et collent à
  l'échelle fixée ici : `thorn-tree` 12 blocs, `cactus1` 4, buisson 2 (= le
  personnage). Le `cactus_01` livré, à 48 voxels = 3 blocs, est dans le bon
  ordre de grandeur ;
- la sélection se fait sur le **type de bloc de surface**, pondérée par
  température et humidité, jamais sur un identifiant de biome — c'est exactement
  la forme de `CWPalette.surface_index`.

**Verrou avant de porter la table** : la numérotation des blocs de l'original
n'est pas celle de `CWPalette` (ici `AIR = 0`, `WATER = 12`, `SWAMP = 10` ; dans
l'original `0` = air et `2` = eau). Recopier la table telle quelle mettrait des
cactus dans les marais. Établir la correspondance d'abord.

### Fait (2026-09-05, troisième passe) — la seconde voie de pose

**Il y a bien deux voies.** Les plantes à silhouette (buissons, cactus, arbres)
sont des **entités** à code de type. La flore basse (herbe, fleurs, algues,
corail, roseaux) est du **décor instancié** sans entité, sans comportement,
produit dans la même passe que le terrain — en fin de boucle de colonne de
`generateBiomeContent` — et poussé par `ChunkBuffer_loadAndNotify` (@005c03f0).
L'enregistrement est reconstruit : type à +0, échelle à +32, lacet à +36,
drapeaux à +56. Détail complet en `docs/systems/02`, §8.

> **Le rapport de 16 est confirmé par une constante du binaire.** Les échelles
> de décor sont 0,075 / 0,09 / 0,1, et **0,075 = 1/13,333 exactement** — la
> même valeur que la mesure au pixel de §7.1, obtenue par un chemin
> entièrement différent. La mesure à l'œil était juste. Nos modèles sont 20 %
> plus fins que l'original à bloc égal ; `VOXELS_PER_BLOCK = 16` reste
> délibéré, mais l'écart est maintenant chiffré au lieu d'être supposé.

**Les deux améliorations repérées ici ont été faites le même jour** — voir la
cinquième passe ci-dessous : gigue d'échelle par instance, et les deux
fréquences de bruit.

### Fait (2026-09-05, quatrième passe) — le lot de flore redessiné à 40/3

Le passage de 16 à 40/3 voxels par bloc rendait le lot précédent faux à 20 %, et
neuf de ses modèles étaient des tapis d'un ou deux voxels (cf. §8, point clos).
Les 39 fichiers ont donc été **refaits par script** plutôt qu'à la main, d'après
`docs/prompt_generation_flore.md` : `tools/blender/generer_flore.py`, une graine
en dur par modèle, le lot se regénère à l'identique.

Ce que le générateur verrouille, et qui était justement ce qui avait cassé :

- **la palette** est le bloc `RGBA` de `assets/palette/zentarys_palette.vox`,
  recopié octet pour octet dans chaque fichier, avec un témoin sur l'index 128 ;
- **les index** hors des plages végétation (128-175) et terrain (1-11, 14-31)
  sont refusés à l'écriture — l'air et l'eau translucide compris ;
- **l'enveloppe** (53 voxels de haut, 26 de rayon) l'est aussi.

Répartition du travail : Python direct pour ce qui est une ligne d'un voxel
(brins, tiges, corolles, cailloux, étoile de mer), `bpy` là où il paye — courbes
à rayon variable pour les lianes, les branches et les algues, métaballes pour la
frondaison des buissons, `Simple Deform` pour les courbures — puis
échantillonnage du maillage évalué sur la grille entière par
`closest_point_on_mesh` : distance à la surface pour ce qui doit rester mince,
distance signée par la normale pour les quatre volumes pleins du lot (les deux
cactus, le grès, les cailloux).

Résultat : 117 vérifications, 0 échec ; `inspect_model.gd` ne signale aucun index
hors plage sur les 39. Les hauteurs vont de 6 voxels (`etoile_de_mer`) à 45
(`cactus_01`, 3,4 blocs, au-dessus de la tête du personnage). Images de référence
de `docs/images/` refaites sur ce lot.

Les six modèles les moins sûrs, à regarder à l'œil avant de les tenir pour
acquis : `sable_desert/gres` (3 640 voxels pleins pour peu de silhouette),
`jungle/liane` et `jungle/vrille` (deux torsades qui risquent de se ressembler
en jeu), les deux `lierre` (même générateur, seules les teintes changent),
`gravier_fond_marin/algue` (le mélange turquoise/vert imposé par la table peut
lire comme du bruit) et `toundra/broussaille` (la table ne lui laisse que
139-145, donc ses branches sont vertes faute de rampe d'écorce).

### Fait (2026-09-05, cinquième passe) — les deux fréquences sont portées

`CWScatter` disperse désormais selon les deux lois lues en §8.4 de
`docs/systems/02`, et `CWFloraRenderer` applique la gigue d'échelle. Trois
choses ont été apprises en le faisant, et aucune n'était dans le plan.

**La crête à 0,05 est le mécanisme de groupement — il n'y en a pas d'autre.**
La dette « la flore vient par grappes, un tirage uniforme ne sait pas le faire »
était ouverte depuis le 2026-09-04. Elle se ferme sans une ligne de code de
groupement : `|bruit(x·0,05 + 9843, z·0,05 + 8437)| > 0,5` passe **29,2 %** de
la surface, en plaques de **19,1 blocs** — la longueur d'onde 1/0,05, soit plus
qu'une cellule de dispersion de 16. Des cellules entières sont donc dans une
plaque ou dans un vide. Mesuré après portage : **variance/moyenne = 14,3** par
cellule contre ~1 pour un tirage uniforme, et 195 cellules vides sur 576.

**La rareté entière n'est pas portée, et ce n'est pas un oubli.** L'original
visite chaque colonne et garde `rand()%8 == 0` de celles qui sont dans une
plaque : 256 échantillonnages de colonne par cellule, ~19 ms — hors budget.
`CWScatter` tire un budget de candidats et ne paie la colonne qu'après la crête.
Même moyenne, et le calcul le vérifie : 256 × 0,2917 × 1/8 = **9,3 plantes par
cellule**, contre les **9,8** que donnait la densité posée au jugé dans
`CWModelLibrary`. Deux chemins entièrement indépendants sur le même nombre.
Ajouter quand même un `%8` par candidat ne ferait rien : filtrer au hasard des
positions déjà tirées au hasard rend des positions au hasard.

**Le test de signe se généralise par la parité de l'indice.** Couper la liste en
deux moitiés contiguës — le réflexe — donne une région à 40 % de cailloux et une
sans aucun, parce que la table groupe les modèles par nature et que les deux
cailloux de l'herbe se suivent en fin de liste. C'est une propriété de l'*ordre
de la table*, qui est provisoire, pas du mécanisme. **Le défaut s'est vu sur une
capture en jeu, pas dans un test** — aucune des 124 vérifications ne l'attrapait,
et aucune ne l'attraperait aujourd'hui : c'est du ressort de l'œil.

Deux corrections faites en chemin :

- **`PLACEMENT_PASS_RATE` mesuré trop près.** 250 000 colonnes autour du point de
  départ donnent 0,3012 ; un million réparties sur quatre régions éloignées
  donnent **0,2917**, et la part varie de 0,274 à 0,304 selon la région. Trois
  points d'erreur sur la constante qui compense le budget, c'est 10 % de flore en
  moins partout. Une constante mesurée sur une seule région ne vaut rien.
- **`MAX_PER_CELL` porté de 32 à 64.** Avec le budget divisé par la part
  passante, la jungle tire jusqu'à 50 candidats : à 32, le plafond ne gardait
  plus, il rabotait — une cellule entièrement dans une plaque perdait un tiers de
  sa flore en silence.

Coût : la cellule de flore passe de 1,07 à **1,29 ms**, toujours hors du fil
principal. 124 vérifications, dont 7 nouvelles sur la forme de la distribution —
ce sont des vérifications statistiques, parce que le fait à tenir n'est la
valeur d'aucune plante mais la variance de l'ensemble.

### Ce qui reste — la table type de décor → modèle

Seule inconnue de la seconde voie. Trois pistes sont déjà **éliminées**, et
`docs/systems/02` §8.5 le dit pour qu'on ne les refasse pas : les slots de
modèles de flore n'apparaissent que dans le chargeur ; le registre entier de
`World.cpp` ne contient que 12 pièces de charpente ; `SpriteManager` ne porte
aucune table ; et aucune base d'index fixe ne tient. La cible est le
**consommateur du champ `type` (+0)** de l'enregistrement de décor.

En attendant, la répartition de §7.2 et les densités de `CWModelLibrary.DENSITY`
restent des propositions de bon sens ; les remplacer coûte quelques lignes.

| fonction | adresse | rôle |
|---|---|---|
| `creature_generateAppearance` | `game_misc.cpp:3197` | **la table** : code d'entité → modèle + boîte |
| `WorldInfo_generateBiomeContent` | `@005e4850` | constructeur de cellule 256², choix des plantes par type de sol |
| `World_generateVegetationCluster` | `@005d8750` | résolveur de contenu d'une tuile |
| — son appelant de haut niveau | `game_misc.cpp:42457` | pilote le contenu et la finalisation |
| `World_populateRegionDecorations` | `game_misc.cpp:36135` | bâtisseur de village, sites de région 3 et 5 seulement (jalon 4.3) |
| `World_carveTerrainFeatureA` / `B` | `game_misc.cpp:35597` / `35872` | formes creusées : rochers, massifs |
| `World_generateWaterOrPathFeature` | `@005df960` | plans d'eau (type 12) |
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

### 7.1 L'échelle — fixée le 2026-09-04, alignée sur l'original le 2026-09-05

**Il y a deux grilles.** Le terrain a un pas d'un bloc ; les modèles ont un pas
treize fois plus fin. **Un bloc de terrain vaut 40/3 voxels de modèle
(`CWVoxelModel.VOXELS_PER_BLOCK`) — trois blocs valent exactement 40 voxels — et
le personnage de référence mesure 32 voxels, soit 2,4 blocs.** Le détail par catégorie d'objet est dans
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
mesuré : ~13 voxels par bloc. On avait d'abord retenu 16, la puissance de deux la
plus proche ; le 2026-09-05 le binaire a rendu la valeur exacte — ses échelles
d'instanciation du décor sont 0,075, 0,09 et 0,1, et **0,075 = 3/40** — et le
projet a suivi. Ce qu'on perd : les réductions de LOD ne tombent plus sur une
puissance de deux. Ce qu'on gagne : un modèle de 32 voxels fait 2,4 blocs, ce qui
recoupe les 2,3 blocs mesurés sur la capture. Détail dans
`docs/systems/02_contenu_de_biome.md`, §8.3.

**À revoir au jalon 3.1**, quand le contrôleur donnera la taille réelle du
personnage. Si elle s'écarte de 2 blocs, c'est ce seul nombre qui change. Le
rapport de 40/3, lui, est un contrat d'authoring : le changer redimensionne tous
les modèles déjà dessinés, et il est verrouillé par un test.

**Ce que ça a changé dans le code** (2026-09-04) :

- la flore n'est **plus estampée** dans les données voxels du monde — elle y
  serait treize fois trop grosse. `CWVoxelGenerator` ne la consulte plus du tout,
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
**2 550 modèles voxels nommés** (`.cub`) — le chiffre de 154 retenu jusqu'au
2026-09-05 était une énumération partielle. On n'en reprend aucun — ce sont des
créations originales — mais ce dont un monde comme celui-là a besoin est établi.

**Les 28 rôles déjà produits sont tous confirmés** par ce relevé, nom pour nom :
`cornflower` = bleuet, `sunflower` = tournesol, `heartflower` = fleur_coeur,
`soulflower` = fleur_ame, `ginseng-root` = fleur_ginseng, `reed` = roseau,
`ivy` = lierre, `tendril` = vrille, `alga` = algue, `coral` = corail. Le lot
livré visait juste.

**Les arbres sont des assets — correction du 2026-09-05.** Le corpus charge
`fir-tree.cub`, `thorn-tree.cub`, `christmas-tree.cub`, `tree-leaves.cub`,
`palm-leaf.cub`, `palm-leaf-diagonal.cub`, `wood-log.cub`. Il n'y a **pas**
d'algorithme d'arbre à porter : `World_generateTreeRecursive` est nommée d'après
les arbres rouge-noir de la STL. Reste à trancher si le feuillu est un modèle
entier ou une composition tronc + houppiers `tree-leaves` instanciés — un modèle
de feuillage sans arbre feuillu correspondant plaide pour la composition.

**Les maisons, elles, ne sont pas des assets.** `cube::House::ctor_0(3, 3, 4)` :
une grille de 3 × 3 × 4 cellules remplie procéduralement (jalon 4.3). Ce sont les
*meubles* qui sont des modèles, pas le bâtiment.

**Rôles relevés que le projet n'a pas produits** (`docs/systems/02`, §7) :
`berry-bush`, `snow-berry`, `snow-bush`, `thorn-plant`, `shimmer-mushroom`,
`desert-flower01/02`, `flowers`, `flowers2`, `heartflower-frozen`,
`water-lily01/02`, `underwater-plant`, `plant-fiber`, `lava-grass`,
`lava-flower`, `runestone`, `stone2`, `sandstone` — plus une catégorie
entièrement absente et pourtant jouable, les **filons** (`gold-`, `iron-`,
`silver-`, `sandstone-`, `emerald-`, `diamond-`, `ruby-`, `sapphire-`,
`ice-crystal-deposit`). Les variantes `lava-*` supposent une surface volcanique
que `CWPalette.surface_index` ne produit pas.

#### Convention de nommage

**Un dossier par biome** sous `assets/models/flore/`, un fichier `.vox` par
entrée. Noms en minuscules sans accent, souligné pour séparer, variante numérotée
sur deux chiffres quand les modèles sont interchangeables ; rien d'autre dans le
nom — ni le biome, qui est le dossier, ni la taille du gabarit, qui est libre.
Les couleurs viennent de la plage **Végétation, indices 128 – 175** de la palette
de projet — sauf ce qui est minéral, qui prend la plage **Terrain, 1 – 31**.
Charger la palette en **ouvrant `assets/palette/zentarys_palette.vox`** ; le
détail et le piège sont dans `assets/palette/PALETTE.md`.

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

Beaucoup de rôles reviennent dans plusieurs biomes. La prévision était d'en
produire un seul exemplaire partagé : **le lot livré le 2026-09-05 a fait
autrement**, et mieux — un modèle par biome, dans les teintes du biome. Total :
**28 rôles, 39 fichiers**, tous en place et visibles en jeu.

`CWModelLibrary.FLORA` porte donc des chemins complets (`"herbe/herbe_01"`).
Deux biomes peuvent toujours pointer le même fichier : il n'est alors chargé et
maillé qu'une fois.

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

#### Ce que le lot mesure réellement

Relevé par `tools/inspect_model.gd` sur le lot regénéré du 2026-09-05, en voxels
de modèle (**40/3 = un bloc**) :

| rôle | hauteur | en blocs |
|---|---|---|
| `etoile_de_mer` | 6 | 0,4 |
| cailloux | 7 – 11 | 0,5 – 0,8 |
| herbes, `feuille` | 11 – 13 | 0,8 – 1,0 |
| champignons | 11 | 0,8 |
| fleurs | 13 – 18 | 1,0 – 1,3 |
| lierres, broussailles | 15 – 22 | 1,1 – 1,6 |
| `corail` | 20 | 1,5 |
| `roseau`, `algue`, `buisson`, `vrille` | 27 – 30 | 2,0 – 2,2 |
| `cactus_02`, `gres`, `liane` | 27 – 34 | 2,0 – 2,5 |
| `cactus_01` | **45** | **3,4** — au-dessus de la tête du personnage |

Tout tient dans les fourchettes de `docs/prompt_generation_flore.md` §5, et
largement dans l'enveloppe dure vérifiée par le test (53 de haut, 26 de rayon).
Les tapis d'un voxel du premier lot ont disparu : la plante la plus plate du lot
fait 6 voxels. Les repères de MODELS.md §1 sont un peu plus serrés que ceux du
prompt sur trois rôles — voir §8, c'est la seule divergence qui reste.

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
qui applique le 3/40 à l'import. Un personnage détaillé se dessine dans un
gabarit de 32 de haut, une touffe d'herbe dans 12.

Pour garder l'œil juste en modélisant, poser dans la scène MagicaVoxel un cube de
**40³** (= trois blocs de terrain ; un bloc seul ne tombe pas sur un nombre
entier de voxels) et une silhouette de 32 de haut (= le personnage). C'est ça qui
remplace le réglage de taille du pinceau.

**La flore, elle, est générée.** Depuis le 2026-09-05 les 39 `.vox` de flore
sortent de `tools/blender/generer_flore.py` — Python pour les brins, les fleurs
et les cailloux, `bpy` pour ce qui y gagne (buissons, cactus, coraux, lianes),
une graine en dur par fichier. Ça ne remet pas en cause la décision ci-dessus :
MagicaVoxel reste l'outil pour tout ce qui se dessine — personnages, mobilier,
objets — et le générateur sert ce qui se répète et se mesure. Ce qu'il apporte
et qu'une main n'apporte pas : le lot se regénère à l'identique après un
changement d'échelle ou de palette, ce qui vient de servir deux fois en deux
jours.

**L'établi de personnalisation façon Cube World reste au programme** — il est
d'ailleurs dans la liste du mobilier du jalon 4. Mais c'est une *fonctionnalité
de jeu*, pas un outil d'authoring : grille fixe et petite, palette contrainte par
le matériau, sortie = un objet d'inventaire et ses statistiques. Il se pose sur
l'inventaire (3.2), qui se pose sur le contrôleur (3.1). Il réutilisera
`CWVoxelModel` et son maillage tels quels — le travail est déjà fait.

La palette de projet est en place : **ouvrir `assets/palette/zentarys_palette.vox`
dans MagicaVoxel** — pas glisser un PNG sur le nuancier, c'est ce qui a faussé
les index du premier lot. Plages réservées documentées dans
`assets/palette/PALETTE.md`, source unique dans `CWPalette`, sept vérifications
qui empêchent une plage de bouger ou de se vider en silence.

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
  déjà peints. Depuis le 2026-09-05 il y a des modèles peints dessus, donc
  ajuster une teinte se voit maintenant en jeu — c'est justement le bon moment
  pour le faire, avant le lot suivant.
- **Deux tables de hauteurs coexistent et ne disent pas la même chose** : les
  repères de `assets/models/MODELS.md` §1 (écrits quand un bloc valait 16 voxels)
  et la table de `docs/prompt_generation_flore.md` §5, qui est celle que le lot
  regénéré suit. Les écarts sont petits mais réels — herbe 10-14 contre 8-12,
  caillou 5-10 contre 4-8, champignon 6-12 contre 5-10. C'est la table du prompt
  qui a servi ; il faudrait aligner MODELS.md dessus, ou trancher l'inverse.
  Aucune des deux n'est verrouillée par un test : seule l'enveloppe dure
  (4 blocs de haut, 2 de rayon) l'est, et le lot y tient largement.
- Les arêtes du graphe de sites ne sont **pas** le tracé des routes : le type 1
  est un élément unique par zone, posé sur son site. `site_edge_radius` reste
  donc à 0, et l'hypothèse notée au jalon 1.5 est close.
