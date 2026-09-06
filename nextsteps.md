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
# Suite de validation (297 vérifications, ~20 s)
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

# Apercu de la carte du monde, hors du jeu : la vue vierge et la meme apres une
# diagonale parcourue (zone x, zone z, nombre de zones, graine)
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path . -s tools/preview_map.gd
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path . -s tools/preview_map.gd -- 512 512 5 2024

# Répartition des six biomes et des matières de surface, mesurée sur le champ
# réel (zones échantillonnées, pas de sondage, graine). C'est le garde-fou de
# tout déplacement de seuil dans `CWBiome` — voir §6.
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path . -s tools/biome_stats.gd
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path . -s tools/biome_stats.gd -- 144 512

# Regénération du lot de flore (38 .vox, deux grilles, ~1 s). **Python pur** depuis le
# 2026-09-06 : à 4 voxels par bloc, Blender n'apporte rien de plus qu'aux arbres.
# Déterministe, une graine en dur par fichier ; `-- --seul <nom>` ne refait qu'un
# modèle. Les modules `flore_formes` / `flore_blender`, qui dessinaient à 40/3,
# ne sont plus appelés par ce lot — ils restent pour les créatures du jalon 2.
python tools/blender/generer_flore.py

# Regénération du lot d'arbres (24 .vox, ~2 s). **Python pur** depuis le jalon
# 1.12 : à 1 voxel = 1 bloc, Blender n'apporte rien. Mêmes garde-fous.
python tools/blender/generer_arbres.py

# Regénération des neuf filons (~1 s). Python pur : à 1 voxel = 1 bloc, Blender
# n'apporte rien. N'importe quel Python 3 fait l'affaire, celui de Blender aussi.
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python tools/blender/generer_filons.py

# Capture d'un biome donné, en jeu, sans piloter la fenêtre. C'est le SEUL moyen
# de voir une couche de rendu : un test headless n'a pas de rastériseur.
# --biome prend un index de `CWBiome` : 0 Greenlands, 1 Snowlands, 2 Deserts,
# 3 Jungles, 4 Lava Lands, 5 Oceans, --shot le délai en secondes avant la capture
# (le temps que le terrain charge), puis la session se ferme d'elle-même.
# Le PNG sort dans user://shots.
./godot.windows.editor.double.x86_64.exe --path . scenes/terrain_demo.tscn \
    --resolution 1600x900 -- --biome 7 --shot 32 --vue 256
#   options : --sans-arbres, --sans-flore, pour isoler une couche

# Planche de validation des assets : **une capture par modèle, seul, de près**,
# sur un damier neutre d'un bloc de maille, deux angles (face et trois-quarts).
# Pas de terrain, donc rien à attendre : les 84 sujets sortent en 6 secondes,
# dans user://portraits, plus une planche de contact par lot et par angle.
# --lot : flore | arbres | especes | filons | tout.  `especes` est le lot le plus
# utile — l'arbre **monté** par CWTreeScatter, tronc et houppiers assemblés,
# c'est-à-dire ce que le jeu pose, là où `arbres` ne montre que les pièces.
# --seul filtre sur un bout de chemin, --taille change le côté en pixels (640).
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --path . scenes/model_portraits.tscn -- --lot tout
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --path . scenes/model_portraits.tscn -- --lot especes --seul chene

# Gabarit d'échelle en jeu : mettre scale_board = true sur le nœud racine de
# scenes/terrain_demo.tscn, puis lancer. Deux captures dans user://shots.
# Carte ouverte au démarrage, pour une capture sans piloter la fenêtre :
# auto_open_map = true, auto_shot_delay = 30.
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --path . scenes/terrain_demo.tscn
```

Aperçus PNG écrits par la suite de tests dans
`user://worldgen_preview/` (`height.png`, `climate.png`, `channels.png`) →
`C:\Users\Admin\AppData\Roaming\Godot\app_userdata\Zentarys\worldgen_preview\`.

Démo : `res://scenes/terrain_demo.tscn`. Clic pour capturer la souris,
ZQSD/WASD, Maj = rapide, Espace/Ctrl = monter/descendre, **F1** détails,
**clic gauche** creuser, **clic droit** poser,
**F12** capture d'écran dans `user://shots`, **Page haut/bas** distance de vue,
**M** carte du monde (`+`/`−` pour l'élargir), **1-6** téléportation vers un
biome, **Échap** rend la souris puis quitte.

## 3. État

> **Le jalon 1 est clos** — le tronc écrit dans le terrain (§7) et la planche de
> validation des assets (§6quater) étaient ses deux derniers points. **La
> prochaine session est décrite en §7bis : la falaise d'abord, puis les lacs et
> les chemins ensemble.** 2.6, l'apparition, reste l'autre porte ouverte.

Jalon 1 (le monde) : **1.1 à 1.12 sont portés, testés et vus en jeu**. Suite de
validation : **327 vérifications, 0 échec**, ~20 s.

**1.11 — le tronc en matière, fait** (2026-09-06, §7). Un feuillu se pose en
deux temps : un tronc **écrit dans les données du monde** par
`CWVoxelGenerator._stamp_trunks` — donc il se creuse, il portera la collision et
l'éclairage voxel le voit — et un à trois houppiers instanciés au-dessus. C'est
le premier objet du projet à traverser la matière et l'instance, et les deux
moitiés sortent du **même tirage, dans la même liste** : `Placement.matiere`
marque la pièce que le générateur estampe et que le rendu ignore. Le type de
bloc est `CWPalette.WOOD`, l'index 4 recyclé le jour même ; la teinte reste
celle du modèle, ce qui donne quatre écorces pour un seul type. Coût mesuré :
**+2 % sur le chargement** (18,1 → 18,4 s à 384 blocs de vue).

Ce que la capture a attrapé au passage, et qui datait du jalon 1.7 : **le
terrain charge une boîte, la végétation garnissait un disque** — les quatre
coins portaient du terrain sans porter de cellules. Invisible tant que l'arbre
entier était instancié, un fût nu depuis que le tronc est de la matière.

**Trois remaniements de rendu, le 2026-09-06 au soir, tous décidés en regardant
le jeu** — le détail est en §6ter :

* **la flore est passée à 4 voxels par bloc**, puis ses **petits props —
  herbes et fleurs — à 6**. C'est le seul de ces points qui touche une valeur
  mesurée, et il s'en écarte délibérément : voir §8.1 ;
* **les bandes d'altitude sont retirées** : plus de roche nue ni de calotte de
  neige hors des biomes dont c'est la matière. Elles ne portaient aucun décor,
  donc chaque sommet rendait un plateau nu ;
* **le rôle `CAILLOU` est supprimé**, et les quatre blocs erratiques avec lui.
  Le minéral posé du monde est le seul `rocher_geant`, qui passe par la couche
  des arbres ;
* **un biome n'a plus qu'une matière de plaine.** `GRASS_DRY` et `TUNDRA` sont
  retirées : c'étaient les deux franges d'humidité héritées d'avant 1.12, et
  elles faisaient dire au sol le contraire de ce que disait le nom du biome.

**1.12 — les six biomes, fait** (2026-09-06). C'est le plus gros remaniement
depuis 1.7, et il tient en une phrase : **un biome est une zone climatique, une
matière de surface est ce dont le sol est fait, et ce n'étaient pas deux noms
pour la même chose.**

* `CWBiome.at` rend l'un des **six** biomes de l'alpha 2013 — Greenlands,
  Snowlands, Deserts, Jungles, Lava Lands, Oceans — à partir du climat et de
  l'altitude. `CWPalette.surface_of` en déduit la matière : les trois bandes
  d'altitude (plage, roche nue, neige de sommet) traversent presque tous les
  biomes, et c'est la matière de plaine qui change ;
* `CWDecorRules.decor_allowed` filtre ce qui est nu par nature — roche, magma,
  eau — avec un cas à deux sens : **la neige est le sol d'une Snowlands et une
  calotte de sommet partout ailleurs** ;
* `DENSITY`, `ROLES` et `SPECIES` sont indexés par biome ; les dossiers d'assets
  aussi (`greenlands/`, `snowlands/`, `deserts/`, `jungles/`, `lavalands/`,
  `oceans/`) ;
* **Lava Lands** apporte deux types de bloc, `MAGMA` et `SCORIA`, logés aux
  entrées 30 et 31 de la réserve terrain — les deux seules qu'aucun modèle
  n'employait, donc sans déplacer une frontière. Ses coulées sont une crête de
  bruit, la seule règle de surface qui ait besoin de la position ;
* `CWFloraDrops` porte la table des drops et les trois chaînes d'artisanat de
  l'alpha. **Rien ne la consomme** avant le jalon 3.2 ; elle est écrite
  maintenant parce que c'est maintenant qu'on connaît l'information.

**Et les deux lots d'assets sont refaits** — c'était la tâche que §6 posait en
premier, et elle tombait au bon moment : on ne regénère qu'une fois. **24
arbres** à 1 voxel = 1 bloc, **42 modèles de flore** à 3/40 — ce lot-là a été
refait depuis, à 4 voxels par bloc et à 38 modèles (§6ter) — mais deux fois et
demie plus grands et deux fois moins denses. Détail en §6.

**1.11 — arbres et grande végétation, aux trois quarts** (2026-09-05, lot refait
le 2026-09-06). Le **lot d'assets** : 24 arbres sous `assets/models/arbres/` et
9 filons sous `assets/models/filons/`, produits par script, déterministes. La
**couche de dispersion** : `CWTreeScatter`, cellule de 64 blocs, bibliothèque à
part, espacement minimum de **14** blocs qui tient au travers des frontières de
cellule. Les arbres **sont en jeu**, cinq biomes vérifiés en capture. Ce qui
reste : le tronc en matière (donc la collision), et la pose des filons, qui
appartient à la voie des entités du jalon 2.6.

**1.7 — contenu de biome, fait** (2026-09-05, au soir). La mécanique de
dispersion était en place depuis le 2026-09-04 ; ce qui manquait était le
*quoi*. **La table type de décor → modèle est trouvée**, et elle n'était dans
aucune fonction : elle est dans le **tableau des slots de chargement** de
`GameController`, qui range 2 449 modèles `.cub` à des indices qui ne suivent
pas l'ordre de chargement. La relation est `slot = 2418 + type`, tenue par cinq
recoupements pris dans trois fonctions — le roseau sur sol humide, les deux
nénuphars sur l'eau, les huit enseignes pour les huit genres de bâtiment, le
lierre et les rosiers de mur, l'art incan. La réserve est dite en clair dans
`docs/systems/02`, §8.5 : la même base ne tient pas sous le type 22.

Portée dans `CWDecorRules`. Trois choses en sont sorties : **il y a deux crêtes
de sélection à 0,01 et non une** (décalages `(9843, 8437)` et
`(34234, 234234)`, famille puis variante — leurs signes ne s'accordent que
50,8 % du temps, donc la seconde porte bien une information propre) ; **le
second seuil est biaisé** (`n2 <= 0,5`), ce qui garde le minoritaire à une fois
sur quatre ; **les échelles disent la taille du rôle**, 0,075 étant la référence
— soit exactement `3/40`, le rapport de ce projet. `CWScatter._choose` et sa
parité d'indice, qui étaient une invention de ce projet, sont retirés.
`CWModelLibrary` passe d'une table par biome à une table **par rôle**.

**1.8 — édition et persistance, fait.** Creuser, poser, interroger, et le seul
diff sur le disque.

**1.9 — éclairage voxel, fait** (2026-09-05). `CWLight` porte les deux passes, et
le rendu est passé en **`COLOR_RAW`** : un voxel porte son type dans
`CHANNEL_TYPE` et sa couleur dans `CHANNEL_COLOR`, comme dans l'original. Le
terrain généré n'appelle pas l'éclairage — un champ de hauteurs est éclairé
partout où on le voit — donc il ne sert que là où le joueur a creusé. Un coup de
pioche isolé coûte 30 ms. Le même jour, le **chargement a doublé de vitesse**
(vue de 384 blocs : 39 s → 16,4 s) : l'index de clés du flux SQLite, et le pool
ramené des quatorze fils logiques à la moitié — voir « la falaise des fils » dans
`docs/ROADMAP.md`.

**1.10 — carte du monde, fait** (2026-09-05). `CWWorldMap` et `CWRegionName` :
pièces de Voronoï dans le domaine déformé, une case par chunk de 256 unités,
trois clartés `200 / 220 / 255`, découverte persistée par graine, marqueurs pris
aux éléments de tuile, noms de région à deux syllabes. Touche **M** en jeu,
`tools/preview_map.gd` hors du jeu. Analyse : `docs/systems/05`.

Détail et sources analysées dans `docs/ROADMAP.md`. Analyses :
`docs/systems/01_generation_terrain.md` (terrain),
`docs/systems/02_contenu_de_biome.md` (contenu de biome, éléments de tuile,
apparitions), `docs/systems/03_colonnes_et_edition.md` (colonnes, blocs,
édition, persistance), `docs/systems/04_eclairage.md` (éclairage voxel),
`docs/systems/05_carte_du_monde.md` (carte, découverte, noms).

```
src/worldgen/
  cw_value_noise.gd        bruit de valeur (Hugo Elias), arithmétique 32 bits émulée
  cw_rand.gd               LCG de la CRT MSVC
  cw_region_site.gd        structure d'un site de zone
  cw_region_site_grid.gd   grille 1024² paresseuse, caches sous mutex
  cw_tile_feature.gd       structure d'un élément de tuile
  cw_tile_feature_grid.gd  grille 8x8 par zone, paresseuse, garde de réentrance
  cw_terrain_field.gd      climat + altitude + chenaux + éléments  ← le cœur
  cw_biome.gd              les six biomes et la règle qui les décide (1.12)
  cw_palette.gd            palette, matières de surface, coulées de lave (1.12)
  cw_voxel_generator.gd    VoxelGeneratorScript, cache de colonnes, troncs estampes
  cw_voxel_model.gd        modèle .vox préparé : deux grilles de dessin (1.12)
  cw_model_library.gd      chargement des modèles + tables par biome et par rôle
  cw_scatter.gd            grille de dispersion 16², cellules en cache
  cw_decor_rules.gd        rôles du décor : deux crêtes, rareté, taille, filtre
  cw_flora_drops.gd        ce que rend une plante, et les chaînes d'artisanat (1.12)
  cw_flora_renderer.gd     instanciation de la flore (MultiMesh par cellule)
  cw_tree_rules.gd         les espèces d'arbres et leurs trois montages (1.11)
  cw_tree_scatter.gd       la couche jumelle : cellule de 64, espacement de 14,
                           et le tronc en matiere (1.11)
  cw_world_edits.gd        creuser, poser, interroger un bloc (jalon 1.8)
  cw_light.gd              éclairage voxel : deux passes, cases à repeindre (1.9)
  cw_world_map.gd          carte : dalles de Voronoï, découverte, teintes (1.10)
  cw_region_name.gd        noms de région : deux tables de vingt syllabes (1.10)
src/demo/terrain_demo.gd   scène de démonstration, touches 1-6 par biome
src/demo/scale_board.gd    gabarit d'échelle : mires, silhouette, modèles
src/demo/model_portraits.gd  planche de validation : un modèle par capture (§6quater)
src/demo/map_overlay.gd    affichage de la carte (touche M)
tests/worldgen_test.gd     suite headless, 312 vérifications
tests/tile_features_test.gd  la moitié qui concerne les éléments de tuile
tests/decor_test.gd        rôles, tables croisées, filtre de matière, composition
tests/flora_test.gd        modèles, dispersion, maillage et pose
tests/tree_test.gd         lot, enveloppes, grille, dispersion, espacement, montage
tests/edit_test.gd         règles d'édition, requête ponctuelle, persistance (1.8)
tests/light_test.gd        les deux passes, l'atténuation, les cases à repeindre (1.9)
tests/map_test.gd          échelle, découverte, puzzle, rendu, noms (1.10)
tools/export_palette.gd    régénère assets/palette/* depuis CWPalette
tools/biome_stats.gd       répartition des biomes et des matières, mesurée (1.12)
tools/preview_features.gd  gros plan ombré, avec et sans la couche d'éléments
tools/inspect_model.gd     inventaire d'un .vox : gabarit, index, plages, morceaux
tools/repaint_models.gd    remet un .vox dans la palette de projet
tools/preview_map.gd       aperçu de la carte, vierge et après une diagonale
tools/blender/             générateurs des lots de modèles
  flore_vox.py               palette verbatim, écriture .vox, garde-fous
  flore_formes.py            brins, tiges, feuilles, corolles, cailloux
  flore_blender.py           courbes, métaballes, échantillonnage sur grille
  flore_blocs.py             formes de flore a la maille de 4 voxels par bloc
  generer_flore.py           le catalogue des 38 modèles de flore, à 4 vox/bloc
  arbres_formes.py           formes à la grille fine — plus employé par les arbres
  arbres_blocs.py            formes à la maille du bloc : disques, dômes, palmes
  generer_arbres.py          le catalogue des 24 arbres, à 1 voxel = 1 bloc
  generer_filons.py          les 9 filons, à 1 voxel = 1 bloc
docs/prompt_generation_flore.md   la commande du lot de flore
docs/prompt_generation_arbres.md  la commande du lot d'arbres
assets/palette/            palette de projet + PALETTE.md
assets/models/flore/<biome>/  38 modèles, un dossier par biome (six)
assets/models/arbres/<biome>/ 24 modèles d'arbres, à la maille du bloc
assets/models/filons/      9 filons, estampables (1 voxel = 1 bloc)
assets/models/             MODELS.md (échelle, palette et conventions)
docs/images/               gabarit, carte et composition de flore, en jeu
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

    **Depuis le 2026-09-06, cette constante ne porte plus la flore** : elle porte
    le personnage, les créatures, le mobilier et les objets. La flore est passée
    à 4 voxels par bloc (§6ter.1, §8.1), et c'est le premier écart assumé entre
    ce projet et une valeur relevée dans l'original. La constante reste la
    référence mesurée et la valeur par défaut d'un modèle chargé sans grille.
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
22. **`CWDecorRules.FAMILIES` et `CWModelLibrary.ROLES` doivent se répondre
    exactement.** Un rôle qu'une surface sait *choisir* mais pas *poser* ne lève
    rien : la plante disparaît, et la densité moyenne ne bouge pas assez pour
    se voir — un quart des candidats d'un biome peut s'évaporer en silence.
    L'inverse, un modèle rangé sous un rôle que les deux crêtes n'atteignent
    jamais, est plus discret encore : le fichier est chargé, maillé, et ne sort
    pas une seule fois. Deux vérifications de `tests/decor_test.gd` tiennent les
    deux sens, et c'est la seule chose qui les tienne.
23. **Les tirages d'un candidat sont pris tous ensemble, avant tout test.**
    `CWScatter._build_cell` tire ses six valeurs — position, quart de tour,
    choix de variante, gigue, rareté — d'un bloc, puis décide. Un tirage placé
    *après* un `continue` désynchroniserait le flux du LCG d'un candidat à
    l'autre, et une cellule ne se reproduirait plus à l'identique selon les
    rejets qu'elle a rencontrés — un monde qui change entre deux visites, sans
    rien pour le signaler.
24. **La flore et les arbres ont deux bibliothèques, et ce n'est pas du
    rangement.** `CWScatter` calcule la marge de `placements_in` sur
    `CWModelLibrary.max_radius_blocks`, *tous modèles confondus* (invariant
    n° 17). Ranger un houppier dans la bibliothèque de la flore ferait passer
    cette marge de 2 blocs à 9 pour **toute** la flore, et chaque `MultiMesh`
    d'herbe porterait une boîte de visibilité démesurée — sans qu'aucun test ne
    tombe, seulement des images de plus à dessiner. `shared()` et
    `shared_trees()` restent séparées ; deux vérifications de `tests/tree_test.gd`
    mesurent les deux maxima et refusent qu'ils se rejoignent.
25. **L'espacement minimum des arbres ne doit jamais consulter une cellule
    construite.** `CWTreeScatter._candidats` est une fonction **pure de l'indice
    de cellule** : c'est ce qui permet à une cellule de regarder ses huit
    voisines sans déclencher leur construction. Le jour où cette fonction
    échantillonnerait autre chose que le bruit et le centre de sa cellule, la
    dispersion deviendrait récursive et se bloquerait sous verrou. La règle du
    **rang absolu** `(cz, cx, i)` va avec : elle rend la décision indépendante
    de la cellule qui la pose, et elle n'est valable que tant que
    `ESPACEMENT <= cell_size`.
27. **Un biome n'est pas une matière de surface.** `CWBiome.at` dit *où on
    est*, `CWPalette.surface_of` dit *de quoi c'est fait*. Les tables de contenu
    — `DENSITY`, `ROLES`, `SPECIES`, `FAMILIES` — sont indexées par **biome** ;
    seules deux exceptions sont indexées par matière (`FAMILIES_SURFACE` : le
    sol humide et l'herbe sèche), et chacune déclare le biome qui la produit
    dans `FAMILIES_SURFACE_BIOME` pour qu'un test puisse vérifier que ses rôles
    ont des modèles là où elle peut se produire. Confondre les deux ferait
    pousser des bleuets sur la roche nue d'une prairie de montagne — ce que
    `decor_allowed` empêche, et qu'aucun test de table ne verrait.
28. **Il y a quatre grilles de dessin, et `VOXELS_PER_BLOCK` n'est plus la
    seule.** Les arbres et les filons sont à **1** voxel par bloc, le personnage
    et les créatures à **40/3**, et la flore à **4 ou 6** selon le modèle —
    6 pour les herbes et les fleurs (`CWModelLibrary.GRILLE_FINE`), 4 pour tout
    ce qui a du volume.

    **La grille n'est donc plus décidée par la bibliothèque mais par le
    modèle.** C'est `_grid_of` qui tranche, et il consulte une table de chemins.
    Cette table et la colonne `FIN` du catalogue de `generer_flore.py` doivent
    dire la même chose : le générateur dessine à la grille qu'il croit, le
    moteur instancie à celle qu'il lit. S'ils divergent, la plante sort à une
    taille fausse **d'un facteur un et demi** — assez pour se voir, pas assez
    pour qu'on remonte à la cause. Deux vérifications de `tests/flora_test.gd`
    tiennent les deux sens : aucun modèle chargé à une autre grille que la
    sienne, et aucune entrée de `GRILLE_FINE` qui ne désigne rien.
    C'est un champ de `CWVoxelModel` (`voxels_per_block`), posé au chargement par
    la bibliothèque. Tout ce qui convertit des voxels en blocs doit lire **celui
    du modèle**, jamais la constante. Tant que la flore était à 40/3 — la valeur
    de la constante —, l'erreur était invisible sur les trois quarts du lot ;
    depuis que les trois grilles sont distinctes, plus aucun lot ne tombe sur la
    constante par hasard, et c'est une amélioration silencieuse. Deux
    vérifications de `tests/tree_test.gd` et une de `tests/flora_test.gd`
    tiennent le contrat.
29. **Aucune plante de Snowlands ne prend la rampe 140-147.** C'est la rampe
    « automne, herbe sèche », un orange chaud ; sur un sol de neige — un cyan
    très clair — chaque plante qui l'emploie ressort en tache orange, seul objet
    chaud du paysage. Le défaut a été relevé **deux fois** : le 2026-09-05 sur la
    broussaille de neige, corrigé pour elle seule, puis le 2026-09-06 sur cinq
    modèles du nouveau lot. Snowlands puise dans le bas de la rampe de feuillage
    (136-139), l'écorce sombre (151-155) et le clair de la roche nue (14-15).
    Aucun test ne peut le voir : c'est une capture, ou rien.
30. **Une palme est une paire de frondes opposées, et une paire est symétrique.**
    Le dessin par paires met l'attache sur l'ancre — qui est le centre du
    gabarit, pas le point d'attache — dans le **plan horizontal**. Mais tourner
    une paire d'un demi-tour rend exactement la même image :
    `_couronne_de_palmes` n'avance donc son quart de tour **qu'une pièce sur
    deux**, sinon la troisième palme se pose sur la première et la couronne se
    lit comme une planche en travers du stipe.
31. **La frontière `RANGE_TERRAIN_END` / `RANGE_CREATURES_BEGIN` a bougé une
    fois, le 2026-09-05, et ce sera la dernière fois gratuitement.** Elle est
    passée de 31/32 à 40/41 pour loger les neuf filons. C'était sans coût
    *parce que la plage créatures n'avait aucune entrée peinte* ; dès qu'un
    modèle de créature existera, le même geste imposera de repasser tout un lot
    par `tools/repaint_models.gd`. Vérifier avec `inspect_model.gd` avant de
    toucher à une frontière, jamais après.
32. **Une pièce dont le point d'attache n'est pas sa base doit être décalée en Z
    par l'assembleur.** `_piece` pose un modèle par sa base, ce qui est juste
    pour un tronc et pour un houppier. Une palme retombe : son attache est son
    voxel le plus **haut**, et sans correction la couronne se pose `height - 1`
    blocs au-dessus du stipe. Le décalage se calcule à l'échelle de l'instance
    et à la grille du modèle (`* echelle / m.voxels_per_block`, invariant
    n° 28), jamais en voxels bruts.

    Ce qui rend le piège cher : le décalage avait été traité **dans le dessin**,
    en centrant la paire sur son attache (invariant n° 30), et l'affaire passait
    pour close. Elle ne l'était que sur deux axes sur trois. Une correction
    partielle est plus dangereuse qu'une absence de correction, parce qu'elle
    ferme la question.
33. **Changer la taille d'un modèle, c'est changer sa densité — et rien dans le
    code ne le rappelle.** `CWModelLibrary.DENSITY` et `CWTreeRules` se lisent en
    *objets par cellule*, pas en surface couverte : multiplier un modèle par
    quatre en volume sans toucher à sa densité multiplie par quatre ce qu'il
    couvre. Le 2026-09-06, le caillou est passé de 8 à 30 voxels à densité
    constante, et Greenlands s'est retrouvée avec des champs de rochers où l'on
    ne passait plus — assez serrés pour qu'on croie à un élément de tuile. Le
    rôle a fini supprimé (§6ter.2). L'espacement des arbres, lui, a été doublé
    *en même temps* que le lot grandissait, et c'est pour cela qu'on ne l'a pas
    vu venir de ce côté-là. Aucun test ne peut attraper ça : une densité trop
    forte est une densité valide.
34. **Un modèle est d'un seul tenant.** Deux voxels qui ne se touchent même pas
    par un coin sont deux objets : en jeu, le second flotte. Vérifié depuis le
    2026-09-06 sur tout le lot de flore (`tests/flora_test.gd`, 26-voisinage) et
    rapporté à chaque écriture par les générateurs et par
    `tools/inspect_model.gd`. **La seule exception du dépôt est la palme**, qui
    est une paire de frondes opposées tenue par un stipe absent de son fichier :
    elle passe `souder=False` dans `generer_arbres.LOT`, et c'est le seul
    endroit où ce drapeau apparaît.

    La cause du défaut se répétait dans onze fonctions de dessin écrites
    séparément, et elle était toujours la même : **le pas de parcours d'un arc
    était pris sur son étendue horizontale**, alors que sa hauteur était trois
    fois plus grande. Une fronde de fougère longue de 4,5 et haute de 16 sortait
    en cinq voxels espacés de cinq. Corriger la primitive (`fb.fronde`,
    `fb.feuille`, `fb.rameaux`) valait mieux que corriger onze plantes ; la passe
    de soudure (`Grille.soude`) est le filet, pas le remède — un modèle qui
    demande beaucoup de soudure a une forme fausse, et le compte s'affiche pour
    ça.
35. **Un arbre est un tirage et une liste, jamais deux.** Le tronc estampé et
    les houppiers instanciés sortent de la même passe de montage
    (`CWTreeScatter._monte`) ; ce sont ses deux consommateurs qui se partagent
    la liste, par `Placement.matiere`. Recalculer la position du tronc côté
    générateur — ce qui serait plus direct à écrire — ferait diverger les deux
    moitiés d'un demi-bloc le jour où une constante de montage bouge, et
    personne ne saurait laquelle des deux a raison.

    Corollaire : **une matière ne se met pas à l'échelle**. La gigue d'instance
    d'un tronc devient un rééchantillonnage vertical au plus proche voisin, et
    c'est `Placement.hauteur` — un nombre entier de blocs — qui dit où
    s'accroche le premier houppier. Le produit `hauteur × échelle` ne décrit
    plus rien de posé.
36. **La portée de la végétation est un carré, parce que le terrain est une
    boîte.** `CWFloraRenderer` posait ses cellules dans un disque : les quatre
    coins de la boîte chargée portaient du terrain sans porter de flore, et
    depuis que le tronc est écrit dans le terrain, un fût nu. Toute portée
    exprimée en cellules doit suivre la forme de ce que Voxel Tools charge, pas
    la forme d'une distance. Le surcoût de 4/π ne se mesure pas : le verrou du
    chargement est la génération du terrain.

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
- **Changer une entrée de la palette change tous les `.vox` à la génération
  suivante.** `flore_vox.write_vox` recopie le bloc `RGBA` de
  `assets/palette/zentarys_palette.vox` **verbatim** dans chaque fichier : le
  jour où l'index 4 est passé d'herbe sèche à bois, les 24 modèles d'arbres
  regénérés ce jour-là ont changé d'un octet et les 38 de flore, non. Sans
  conséquence à l'exécution — le chargeur reçoit la palette du projet, pas celle
  du fichier — mais le lot cesse d'être homogène pour qui l'ouvre dans
  MagicaVoxel. **Regénérer les trois lots après toute modification de
  `CWPalette`**, comme on réexporte `assets/palette/`.
- **Les 38 modèles de flore sont générés, pas dessinés.** Les rouvrir dans
  MagicaVoxel pour les retoucher est du travail perdu : la prochaine exécution
  de `tools/blender/generer_flore.py` les écrase. Corriger le générateur, puis
  regénérer. Le script recopie le bloc `RGBA` de la palette de projet tel quel
  et refuse à l'écriture tout index hors plage — c'est ce qui rend impossible
  la faute de palette du premier lot.
- **Un `Control` sous un `CanvasLayer` n'a pas de taille si on ne pose que ses
  ancres.** `set_anchors_preset(PRESET_FULL_RECT)` laisse les marges telles
  quelles, donc `size` reste nul : le dessin part d'une origine négative et sort
  par le coin supérieur gauche. C'est `set_anchors_and_offsets_preset` qu'il
  faut, plus un raccord sur `size_changed`. Aucun test ne peut le voir — un nœud
  invisible calcule juste ; c'est la capture en jeu qui l'a montré (2026-09-05,
  la carte du monde).
- **Le pas d'un arc se prend sur l'arc, pas sur sa projection au sol.** Onze
  fonctions de dessin échantillonnaient `round(longueur)` points sur une courbe
  qui montait trois fois plus haut qu'elle n'avançait : le modèle sortait en
  voxels détachés. Cause unique de treize des vingt-sept défauts du 2026-09-06
  (§6quater), et invisible dans les nombres — la boîte englobante, le compte de
  voxels et les plages de palette étaient tous justes.
- **Ne pas mettre d'appel de liaison moteur sur le chemin chaud.**
  `OS.get_thread_caller_id()` dans `CWTileFeatureGrid.get_zone` coûtait ~15 µs
  par colonne avant d'être déplacé sur le chemin froid. Mesurer avant de
  supposer que c'est le verrou qui coûte.

## 6. La refonte des biomes et des assets — **faite le 2026-09-06**

*Cette section était « la prochaine tâche » ; elle est faite. Elle est gardée
parce qu'elle contient des mesures qui coûteraient cher à refaire, et deux
leçons de méthode qui valent au-delà de ce jalon.*

### 6.1 Ce que les captures du jeu d'origine ont montré

Méthode : le personnage sert de règle (2,3 – 2,4 blocs), comparé à des marches
de terrain à la même profondeur. Les captures restent **hors du dépôt**
(`.gitignore`) : on en tire des nombres, jamais des pixels.

**Les arbres sont immenses, et c'est délibéré.** Ils lisent à **15 – 25 blocs**,
soit six à dix fois le personnage. **Leurs houppiers sont larges et aplatis** —
des dômes en parasol, **plus larges que hauts**, de 10 à 18 blocs. **Et leur
grain est celui du terrain** : sur les captures, les cubes de feuillage et les
blocs de terrain lisent à la même taille.

Deux raisons de le croire au-delà de l'œil, et la seconde est la plus forte. La
**provenance de l'échelle** : `0,075 = 3/40` est relevée dans la voie du *décor*
du binaire (`docs/systems/02`, §8.3), et **aucune échelle n'a jamais été relevée
dans la voie des *entités***, par où passent les arbres. L'**argument
structurel** : §5.2 établit que le tronc d'un feuillu est écrit dans le terrain
en colonnes de blocs et que le houppier est instancié séparément ; ces deux
moitiés ne se rejoignent proprement que si la grille du houppier est celle du
bloc. **Un voxel = un bloc explique l'architecture de la source ; 3/40 la rend
impossible.**

**La flore, elle, était à la bonne grille mais deux fois et demie trop petite**,
et la cause était un repère faux de `assets/models/MODELS.md` §1 — « touffe
d'herbe au genou », là où les captures la montrent à l'épaule.

### 6.2 Ce qui a été fait

| | avant | après |
|---|---|---|
| grille des arbres | 3/40 de bloc | **1 bloc** |
| `pin` / conifère, hauteur | 8,3 blocs | **19 – 22 blocs** |
| houppier, largeur | 4,8 blocs | **11 – 22 blocs** |
| houppier, proportion | aussi haut que large | **au moins 1,4 fois plus large** |
| espacement des arbres | 7 blocs | **14 blocs** |
| touffe d'herbe | 12 voxels, 11 brins d'un voxel | **25 – 30 voxels, 5 brins de deux** |
| caillou | 8 voxels | **28 – 34** (un bloc erratique) |
| plante haute | absente | **fougère, 40 – 46 voxels** |
| fleur de champ | 13 voxels | **6 – 10** |
| lot de flore | 39 modèles, 9 dossiers | **42 modèles, 6 dossiers** |
| lot d'arbres | 14 modèles | **24 modèles** |

**Les formes ont été repensées, pas réduites.** `reduced(2)` aurait donné des
moignons : les folioles de palme, les rameaux de conifère et les pousses de
houppier sont écrits pour du détail d'un voxel. À la maille du bloc, un conifère
est une **pile de disques plats** et un houppier **quelques dizaines de cubes
bien placés**. D'où `tools/blender/arbres_blocs.py`, tenu séparé de
`arbres_formes.py`, et un générateur d'arbres qui est passé en **Python pur** :
à cette résolution, une métaballe échantillonnée rend un tas de cubes.

### 6.3 Les deux leçons de méthode

**Ce qu'on prend pour « trop de détail » est presque toujours « trop petit ».**
Un objet à la moitié de sa taille garde tous ses éléments dans le quart de la
surface, donc il paraît chargé — et le réflexe d'en ajouter aggrave exactement
ce qu'on voulait corriger. C'est ce qui s'était passé le 2026-09-05 au matin :
les touffes lisaient « clairsemées », on est passé de 6 brins à 11, et c'était
le remède inverse.

**Une règle peut être juste et vide.** La première règle de Lava Lands traduisait
correctement « 30 – 40 °C, rare » et rendait **60 colonnes sur 147 456**, parce
que le champ de climat de ce projet est bimodal et que la bande d'humidité
qu'elle visait n'existe pas. Baisser son seuil de 0,88 à 0,80 l'a portée à 64.
`tools/biome_stats.gd` existe pour ça, et **tout déplacement de seuil dans
`CWBiome` doit passer par lui** — c'est écrit dans l'en-tête du fichier.

### 6.4 Ce que la capture a attrapé et que la suite headless ne voyait pas

Cinq défauts, et c'est le meilleur argument pour `-- --biome N --shot S` :

1. le fût des conifères ressortait **au-dessus** du feuillage, sur tous les
   conifères du monde à la fois ;
2. la scorie, à sa teinte « lave refroidie » d'origine (176,44,20), rendait un
   rose saumon uniforme dont la coulée incandescente ne se détachait pas ;
3. le magma, à 255,152,48, se confondait avec le sable du désert (253,185,82) ;
4. **cinq modèles de Snowlands sur six** ressortaient en taches orange sur un
   sol cyan — voir l'invariant n° 29, qui est né de là ;
5. la couronne d'un palmier n'avait que **deux directions** au lieu de quatre —
   voir l'invariant n° 30.

Aucun n'aurait pu être trouvé autrement.

### 6.5 Ce qui reste ouvert du côté des assets

> **Trois défauts sont apparus après coup, en jouant.** Ils ont leur propre
> section, §6bis ; ils sont **corrigés**.

- **`CWVoxelModel.reduced(n)` n'a toujours aucun usage.** Un arbre de 22 blocs
  est le premier modèle assez gros pour la justifier, et la couche existe
  maintenant pour l'accrocher.
- **Oceans n'a pas été vu en jeu.** La recherche de biome pose la caméra
  au-dessus de la mer, et le fond est 75 blocs plus bas : la capture rend une
  étendue d'eau vide. Les trois modèles de fond marin existent et sont testés,
  mais personne ne les a regardés. Il faudrait une pose sous l'eau.
- **Les cultures des villages** (`blé`, `maïs`, `carotte`, `coton`, `citrouille`)
  restent à produire, et elles ne sont pas dispersées par biome : elles se
  posent en rangées par le système de champs du jalon 4.3.

## 6bis. Les trois défauts vus en jeu — **corrigés le 2026-09-06 au soir**

*Cette section était « à corriger en premier » ; c'est fait, et vérifié en
capture. Elle est gardée pour les deux profils en Z qui ont servi de preuve, et
pour la leçon du §6bis.1, qui est la plus utile des trois.*

### 6bis.1 La flèche des conifères flottait — deux corrections en une

Symptôme : le sommet de tous les conifères détaché du reste de l'arbre.

**Ce n'était pas la flèche qui était mal placée, c'était l'étage qui la porte.**
Profil en Z de `arbres/greenlands/pin.vox` (22 blocs de haut), avant :

```
  z= 15   21 voxels      <- avant-dernier etage
  z= 16    —  VIDE
  z= 17    —  VIDE
  z= 18    5 voxels      <- dernier etage, deja detache
  z= 19-21               <- la fleche, contigue a l'etage 18
```

Les **deux derniers étages** sont espacés de 2,8 blocs alors qu'un étage fait un
bloc d'épaisseur, et le fût ne comblait pas l'écart : il s'arrêtait à
`hauteur * 0,82`, soit z = 15. Les trois quarts supérieurs de l'arbre flottaient
en un seul morceau. `sapin_enneige` avait le même défaut, en plus court.

**Le remède** (`tools/blender/arbres_blocs.py`, `conifere()`) : le fût monte
**jusqu'au dernier étage posé** et non à une fraction de la hauteur nominale.
C'est la seule des deux contraintes qui compte — un fût qui s'arrête *au* dernier
étage ne dépasse pas et ne laisse pas de trou, quel que soit le pas. D'où les
étages calculés d'abord, le fût ensuite, le dessin en dernier.

**Et la capture d'après a montré la moitié qui manquait au diagnostic.** Le fût
comblait bien l'écart, mais **en écorce** : les deux à trois blocs entre étages
laissaient voir une colonne brune, et l'arbre se lisait comme une pile
d'assiettes enfilées sur un piquet. Le commentaire du code disait déjà la règle
juste — « un conifère ne montre son tronc qu'entre le sol et son premier étage ;
au-dessus, il est dans la masse » — mais le code ne la faisait pas. Il la fait
maintenant : au-dessus du premier étage, le fût est repeint dans le sombre du
feuillage, avant que les plateaux ne soient dessinés par-dessus.

> **La leçon, et elle vaut au-delà de ce défaut : un profil en Z ne montre pas
> une couleur.** Le dump disait « plus de trou » et il avait raison ; il ne
> pouvait rien dire du fait que le trou était comblé avec la mauvaise matière.
> Une mesure ne répond qu'à la question qu'on lui pose. C'est le même argument
> que §6.4, d'un cran plus fin : la capture ne sert pas qu'à trouver ce qu'un
> test headless ne voit pas, elle sert à vérifier **le remède** aussi.

### 6bis.2 Les palmes du dattier flottaient — l'ancre est en haut du modèle

Symptôme : la couronne du palmier de désert posée trop haut, détachée du stipe.

Profil en Z de `arbres/deserts/palme.vox` (3 blocs de haut) :

```
  z= 0    2 voxels   x 0 et 16    <- les deux pointes, qui retombent
  z= 1    2 voxels   x 1 et 15
  z= 2   28 voxels   x 2..14      <- le rachis et son attache, au CENTRE
```

Une paire de palmes retombe : son **point d'attache est le voxel le plus haut du
modèle**, pas le plus bas. Or `_piece` pose une pièce par sa base, donc l'attache
se retrouvait `m.height - 1` blocs au-dessus du sommet du stipe — trois blocs
pour le dattier, quatre pour le palmier de jungle, dont la canopée le cachait
mieux.

C'était le décalage d'attache annoncé en §7 : il avait été réglé *dans le dessin*
— une paire met l'attache sur l'ancre dans le plan horizontal, invariant n° 30 —
mais **pas en Z**. Il était réglé sur deux axes sur trois, et c'est précisément
ce qui a fait croire l'affaire close.

**Le remède** (`src/worldgen/cw_tree_scatter.gd`, `_couronne_de_palmes`) :
retrancher la hauteur du modèle, à son échelle et à sa grille —
`float(m.height - 1) * echelle / m.voxels_per_block`, la même formule que `haut`
juste au-dessus. La conversion passe par `voxels_per_block` du modèle et non par
la constante : c'est l'invariant n° 28.

### 6bis.3 Ne garder que les gros cailloux — et remplacer, pas retirer

`greenlands/caillou_02` (19 voxels, dalle plate) et `deserts/gres` (34 voxels,
colonne à chapeau) sont supprimés. Restent les quatre blocs erratiques :
`greenlands/caillou_01` (31), `snowlands/caillou_01` (29),
`lavalands/caillou_basalte` (28), et le nouveau.

**`deserts/gres` était le seul modèle du rôle `CAILLOU` de Deserts**, et le
supprimer sans plus aurait vidé un rôle que les deux crêtes atteignent encore —
exactement ce que refuse `tests/decor_test.gd` (invariant n° 22). Le choix pris
est de le **remplacer** : `deserts/caillou_gres` est un bloc erratique dessiné
par le même `bloc_erratique` que les trois autres, dans la plage du grès
(20 – 24). `FAMILIES` et `ROLES` gardent donc leur forme, et le désert sa
composition.

Ce qui a décidé du remplacement plutôt que du retrait : **un lot n'est pas une
collection de bonnes idées, c'est une famille.** Le grès sculpté par le vent
était la meilleure silhouette des cinq, et c'est ce qui le condamnait — seul de
son espèce, il ne se comparait à rien. Les quatre minéraux du monde ont
maintenant la même masse basse et large, et quatre matières.


## 6ter. Les remaniements de rendu — **2026-09-06 au soir**

*Tous les trois viennent de la même capture, et aucun n'aurait pu sortir d'un
test. Le premier est le plus lourd et le plus intéressant.*

### 6ter.1 La flore passe à 4 voxels par bloc

**Le symptôme n'était pas celui qu'on croyait.** Le lot avait été regénéré le
matin même « avec moins de détails » — deux fois et demie plus grand, deux fois
moins dense, cinq brins au lieu de onze — et le résultat en jeu était
*indiscernable* de l'avant. Vérifié avant de rien changer : les `.vox` sur le
disque étaient octet pour octet ceux que produisait le générateur. Le lot avait
bien été refait ; c'est le remède qui ne portait pas.

**Parce que le remède agissait sur le nombre d'éléments, et le défaut est dans
la maille.** À 40/3 voxels par bloc, un brin fait 0,08 bloc d'épaisseur : à côté
d'un cube de terrain d'un bloc, ce n'est pas un cube, c'est un cheveu. Cinq
cheveux au lieu de onze font une touffe plus claire, pas une touffe plus grosse.
Aucun réglage d'un lot dessiné à cette finesse ne pouvait donner ce qu'on
cherchait.

Le lot est donc redessiné à **4 voxels par bloc**, avec un module de formes à
part — `tools/blender/flore_blocs.py` — exactement comme le lot d'arbres avait
eu `arbres_blocs.py` trois jours plus tôt, et pour la même raison : **les formes
sont à repenser, pas à réduire.** Une touffe est cinq brins de sept voxels ; une
fleur, une tige et une croix de trois ; une fougère, cinq arcs. Le générateur
passe en **Python pur** : à cette résolution, `bpy` n'apporte plus rien.

Ce qui **n'a pas bougé** : la taille des plantes en blocs. La touffe fait
toujours 1,75 bloc. Et l'enveloppe de `tests/flora_test.gd` n'a pas eu à
bouger non plus, parce qu'elle est dite **en blocs** — c'est le genre de détail
qui ne se remarque que le jour où il paye.

> **C'est le premier écart assumé entre ce projet et une valeur mesurée dans
> l'original**, et il est signalé comme tel dans
> `CWVoxelModel.VOXELS_PER_BLOCK_FLORE` et en §8.1. 3/40 n'est pas contesté :
> c'est bien l'échelle du décor de l'alpha. C'est le rendu qui la refuse.

### 6ter.2 Le rôle `CAILLOU` est supprimé

Les quatre blocs erratiques — un par biome minéral, dont le `deserts/caillou_gres`
produit le matin même — sont retirés du lot, et `Role.CAILLOU` de `FAMILIES` et
de `ROLES`. Motif, vu en jeu : **dispersés à la densité de la flore, ils
rendaient des champs de rochers** de plusieurs dizaines de blocs, serrés au point
qu'un joueur n'y passait plus.

La leçon est celle du 2026-09-06, prise par l'autre bout : on avait
grossi les cailloux de 8 à 30 voxels *sans toucher à leur densité*, qui avait été
réglée quand ils faisaient la taille d'un galet. Un objet qu'on multiplie par
quatre en volume ne garde pas sa densité. **Changer une taille, c'est changer une
densité**, et rien dans le code ne le rappelle.

Le minéral posé du monde est désormais le seul `arbres/greenlands/rocher_geant`,
qui passe par la couche des arbres : espacement de 14 blocs, poids 0,05 dans
`CWTreeRules`. Un rocher de loin en loin, ce qui est ce qu'on voulait.

Les branches où `CAILLOU` était une feuille se referment sur sa sœur —
Greenlands `[[FLEUR, SOUS_BOIS], [COUVERT]]`, et de même pour Snowlands, Deserts
et Lava Lands.

### 6ter.3 Un biome n'a plus qu'une matière de plaine

`CWPalette.GRASS_DRY` et `CWPalette.TUNDRA` sont retirées de `surface_of`.
C'étaient les deux **franges d'humidité** héritées d'avant le jalon 1.12 : une
prairie sous 0,46 d'humidité virait au kaki, une Snowlands sous 0,50 au
gris-olive.

Le défaut se voyait à l'ATH avant de se voir au sol : « Greenlands / herbe
sèche » sur un sol kaki, c'est-à-dire un nom de biome et une couleur qui se
contredisent. Depuis que `CWBiome` classe le climat, une seconde matière de
plaine par biome ne dit **rien que le biome ne dise déjà**. Les trois bandes
d'altitude — plage, roche nue, neige de sommet — restent : celles-là ne sont pas
des franges de climat, elles disent l'altitude, et c'est une autre information.

**Les deux index restent alloués**, et c'est délibéré : les libérer décalerait
tout ce qui suit dans la réserve 1-13, donc les plages 14-19, 20-24 et 25-27 qui
sont peintes dans les 62 `.vox` du dépôt. Deux entrées sur 256 contre un
repassage complet par `tools/repaint_models.gd` : c'est l'arbitrage de
l'invariant n° 31, tranché dans le même sens. Aucun modèle ne les employait —
vérifié avant, pas après.

Le retrait a emporté avec lui l'exception `FAMILIES_SURFACE[GRASS_DRY]`, et
verdi les deux modèles de Greenlands qui puisaient dans la rampe « automne »
(`herbe_seche`, `broussaille`) : une tache orange sur une prairie désormais
toujours verte, c'était l'invariant n° 29 transposé de Snowlands à Greenlands.

Un balayage de `tests/decor_test.gd` refuse maintenant que `surface_of` rende
l'une des deux matières retirées, sur 4 096 climats × 6 biomes × 6 altitudes.
Sans lui, remettre une frange ne lèverait rien.


### 6ter.4 Et la flore prend une seconde grille : 6 pour les petits props

**Quatre voxels par bloc était juste pour la moitié du lot.** Un buisson, un
cactus, un champignon sont des *masses* : leur forme est leur volume, et un
volume se lit à n'importe quelle résolution. Ce qui s'y perdait, ce sont les
objets **dont toute la forme tient dans un trait** — une touffe d'herbe est cinq
lignes, une fleur est une tige et une corolle. À quatre voxels par bloc, une
corolle est une croix de cinq voxels et une touffe un paquet de bâtonnets : le
grain était juste, la silhouette ne l'était plus.

**Quinze modèles passent donc à six voxels par bloc** — les herbes, les fleurs,
le ginseng, le roseau —, le reste garde quatre. Une touffe passe de sept à onze
voxels de haut, sans revenir au cheveu : un brin fait un sixième de bloc, pas un
treizième. C'est le rapport d'un et demi entre les deux grilles qui compte, pas
les valeurs.

**Conséquence d'architecture, et c'est la partie qui coûte.** La grille n'est
plus décidée par la bibliothèque mais **par modèle** : `CWModelLibrary._grid_of`
consulte `GRILLE_FINE`, une liste de chemins. Cette liste et la colonne `FIN` du
catalogue de `generer_flore.py` sont **deux sources qui doivent dire la même
chose** — le générateur dessine à la grille qu'il croit, le moteur instancie à
celle qu'il lit. Une divergence sort la plante à une taille fausse d'un facteur
un et demi : assez pour se voir, pas assez pour qu'on remonte à la cause. Deux
vérifications tiennent les deux sens (invariant n° 28).

Pourquoi une liste et non une règle sur le rôle : le partage passe par le rôle
**à deux modèles près**, et ces deux-là suffisent à le disqualifier —
`feuille_large` est un `COUVERT` de jungle mais c'est une grande feuille, et
`herbe_de_lave` est rangée en `SOUS_BOIS` alors que c'en est. Une règle qui se
trompe sur deux modèles sur trente-huit coûte plus qu'une liste, parce qu'on ne
sait pas lesquels sans les regarder un par un.

### 6ter.5 La flèche des conifères était une boule

Symptôme, vu en jeu sur Snowlands : le sommet des conifères lit comme une
**boule posée sur un cou**. Le profil en Z de `sapin_enneige` le disait mot pour
mot :

```
  z= 12    9 voxels
  z= 13    9 voxels
  z= 14    1 voxel     <- le cou
  z= 15    5 voxels
  z= 16    9 voxels    <- la boule : la silhouette REGONFLE
  z= 17    5 voxels
  z= 18    1 voxel
```

**Deux causes, et il fallait les deux.** Le fût se réduisait à un fil entre les
deux derniers étages : `colonne` reçoit `fut_r` comme rayon haut, et sous 1,0 un
disque ne pose plus qu'**un** voxel. Et la flèche était **plus large que l'étage
qui la portait** — son rayon était la constante 1,8, soit neuf voxels, quand le
dernier étage d'un conifère fait 1,3 à 1,5, soit cinq à neuf. *Une pointe qui
s'élargit avant de se fermer est une boule, par définition.*

Remèdes : le rayon haut du fût est **planchéisé à 1,0** (cinq voxels), et la
flèche part de l'**avant-dernier** étage en **remplaçant le dernier** au lieu de
s'y ajouter. Ses rayons décroissent donc strictement, la silhouette est monotone
du pied à la pointe, et l'arbre perd exactement **un bloc** — la pointe passe de
`dernier + 3` à `dernier + 2`, ce qui était l'autre moitié de la demande.

Profil après, sur le même modèle : `21, 9, 9, 5, 5, 1, 1`. Vérifié aussi sur
`pin`, `pin_enneige` et `arbre_epineux`.

> C'est la **troisième** fois que le sommet des conifères est repris en trois
> jours — le fût qui dépassait, la flèche qui flottait, la flèche qui gonflait.
> À chaque fois le diagnostic était juste et le remède partiel, parce qu'il
> traitait le symptôme qu'on voyait sans regarder le **profil entier**. Un
> `zprofile` de dix lignes aurait montré les trois d'un coup.

### 6ter.6 Les bandes d'altitude sont retirées

`surface_of` ne rend plus de roche nue ni de calotte de neige hors des biomes
dont c'est la matière. Il ne reste que la matière du biome, la plage, et la
règle propre à Lava Lands.

**Ce n'est pas le même motif que le retrait des franges d'humidité** (§6ter.3),
et c'est ce qui rend le cas intéressant. Les franges se *contredisaient* : une
prairie annoncée « Greenlands » avec un sol kaki. Les bandes d'altitude, elles,
ne se contredisaient pas — une montagne a de la roche et de la neige, le
raisonnement de vraisemblance était bon. Elles ne **portaient rien** :
`decor_allowed` refuse le décor sur la roche et sur la neige hors Snowlands,
si bien que chaque relief un peu haut d'une Greenlands rendait un plateau nu,
sans une plante ni un arbre, où l'on marchait sans rien rencontrer.

*Une matière qui ne porte rien n'est pas un sous-biome, c'est un trou dans le
monde.* Le raisonnement de vraisemblance tenait tant qu'on regardait une carte
de hauteurs ; il ne tient plus dès qu'on marche dessus.

Les trois constantes — `SNOW_LINE_BASE`, `ROCK_BAND`, `ROCK_MIN` — restent, et
ne servent plus qu'à Lava Lands, dont la règle décrit un volcan et non une
altitude. Elles serviront de point de départ le jour où la **falaise** aura sa
règle : la source force le type 6 sur la falaise
(`terrain_surfaceColor_blend`), et ce sera une **pente** à mesurer, pas une
altitude — c'est probablement là que la roche nue doit revenir.

Répartition mesurée après (`tools/biome_stats.gd`) : herbe 37,2 %, neige 27,0 %,
gravier 23,9 %, marais 6,6 %, scorie 2,4 %, sable 2,0 %, jungle 0,5 %, magma
0,5 %. **Plus une seule colonne de roche** hors Lava Lands.

Un balayage de `tests/decor_test.gd` refuse maintenant qu'un biome autre
qu'Oceans ou Lava Lands produise une matière que `decor_allowed` rejette — c'est
la formulation générale du défaut, et elle attrape aussi le prochain.


## 6quater. La planche de validation des assets — **faite, dans la foulée**

> Demandée le 2026-09-06 au soir, après trois sessions où chaque défaut d'asset
> avait été trouvé par hasard, en jouant, une fois le lot déjà commité.

### L'outil

`scenes/model_portraits.tscn` (`src/demo/model_portraits.gd`) : **une capture
par modèle, seul, de près**, sur un damier neutre dont une case vaut un bloc de
terrain, sous deux angles — de face et de trois-quarts au-dessus. Pas de terrain
du tout, donc rien à streamer : **84 sujets en 5,6 secondes**. Sortie dans
`user://portraits`, plus une planche de contact par lot et par angle, avec le
nom sous chaque vignette. Commande en §2.

Trois décisions valent d'être dites :

- **une scène à part, et pas une option de la démo.** « Sans rien autour » est
  la moitié du travail : le gabarit d'échelle se pose sur le terrain généré,
  donc sur de l'herbe, avec des plantes autour et un relief derrière ;
- **un `SubViewport` de taille fixe**, et non la fenêtre : le cadrage ne dépend
  ni de la résolution ni de la machine, donc deux planches se comparent ;
- **un quatrième lot qui n'était pas demandé, `especes`** — l'arbre **monté**,
  tronc et houppiers assemblés en appelant `CWTreeScatter._monte`, c'est-à-dire
  exactement ce que le jeu pose. C'est le lot le plus utile des quatre, et pour
  une raison qu'on aurait pu prévoir : les trois derniers défauts corrigés
  (§6bis) étaient tous dans l'assemblage et dans aucun modèle.

### Ce que la planche a montré, et la seule chose qui se mesurait

**Treize modèles sur trente-huit étaient faits de cubes qui ne se touchent pas.**
La fougère sortait en **douze morceaux** dont le plus gros portait 38 % de la
matière, la fougère géante en onze, le cotonnier de neige en cinq de quatre
voxels. De loin, dispersés par centaines, ils passaient pour du grain ; de près,
ce sont des confettis qui flottent.

C'est le seul des défauts relevés qui se **mesure**, donc le seul qu'un outil
puisse attraper — d'où, le même jour, trois ajouts qui le verrouillent :
`tools/inspect_model.gd` compte les morceaux (26-voisinage) et le dit à chaque
inspection, les générateurs le disent à chaque écriture, et
`tests/flora_test.gd` en fait un invariant (n° 34). La suite passe de 315 à
**316 vérifications**.

> **La cause était une seule ligne, recopiée dans onze fonctions de dessin.**
> Le pas de parcours d'un arc était pris sur son **étendue horizontale** :
> `n = round(longueur)`. Une fronde de fougère longue de 4,5 monte de 16, donc
> cinq pas horizontaux posaient cinq voxels espacés de cinq en hauteur.
> Corriger `fb.fronde`, `fb.feuille` et `fb.rameaux` a réparé neuf plantes d'un
> coup. La passe de soudure (`Grille.soude`, un pétiole du morceau au corps) est
> le **filet**, pas le remède : le nombre de voxels soudés s'affiche à
> l'écriture, et un modèle qui en demande beaucoup a une forme fausse.

**Et trois défauts de fond, que rien ne mesure :**

1. **Les sept fleurs du lot étaient des panneaux de signalisation.** La corolle
   était un disque plein posé à plat au sommet de la tige — neuf voxels pour
   `rayon = 1,5`, vingt et un pour 2,4. Sept modèles, la même silhouette en T,
   et aucun ne se lisait comme une fleur. `fb.corolle` dessine maintenant une
   **coupe** : les pétales montent d'un voxel autour d'un cœur resté en bas, et
   la pointe des grandes corolles redescend. C'est le minimum qui fasse une
   fleur, et à quatre ou six voxels par bloc c'est aussi le maximum disponible.
2. **Ce qu'on posait sur une masse était posé dedans.** Les baies du snowberry
   étaient tirées à un rayon de 1 à 2,4 dans un buisson large de six, les
   piments de l'habanero et les braises du fire shrub de même : la moitié
   tombait sous la peau, invisible. Les trois modèles sortaient unis — le fire
   shrub se lisait comme un rocher noir. `fb.peau` et `fb.semis` posent
   désormais les grains **sur** la surface, et de côté plutôt que par le haut :
   des baies poussées vers le haut se rejoignent en calotte, ce qui est un
   buisson sous la neige et non un buisson à baies.
3. **Deux troncs tenaient sur un piquet d'un bloc.** `disque` garde ce dont la
   distance au centre ne dépasse pas le rayon : à `r_bas = 1,0` décroissant vers
   0,8, le fût du bouleau faisait cinq voxels au pied et **un seul** dès le
   premier étage. Un bouleau de quatorze blocs de haut sur un bloc de section,
   c'est un houppier qui flotte. 1,4 → 1,05 donne une croix de cinq voxels sur
   toute la hauteur, soit trois blocs de large, un de moins que le chêne.

### Le verdict, modèle par modèle

**71 modèles regardés un par un, plus 13 arbres montés.** Ce qui a été corrigé :

| modèle(s) | verdict | ce qui a changé |
|---|---|---|
| les 7 fleurs (`fleur_bleuet`, `fleur_tournesol`, `fleur_coeur` ×2, `fleur_de_glace`, `fleur_ame`, `fleur_de_lave`) | panneau de signalisation | `fb.corolle` : une coupe, pétales relevés, cœur en creux |
| `fougere`, `fougere_geante` | 12 et 11 morceaux | `fb.fronde` : le pas se prend sur l'arc, pas sur sa projection |
| `lierre`, `liane`, `feuille_large` | morcelés | même cause : `fb.feuille`, et un pas doublé dans `lierre_jungle` |
| `broussaille_seche`, `scrub`, `broussaille`, les deux `cotonnier`, `corail`, `herbe_01`, `herbe_03` | 2 à 9 morceaux | `fb.rameaux` corrigée, plus la soudure en filet |
| `snowberry`, `habanero`, `fire_shrub` | masse unie, garniture invisible | `fb.semis` : les grains sur la peau, et de côté |
| `deserts/cactus_01` | une colonne verte | bras doublés en section, dressés sur six blocs |
| `bouleau_tronc`, `bouleau_givre_tronc` | un piquet d'un bloc | section portée à cinq voxels sur toute la hauteur |
| `lavalands/arbre_epineux` | une poignée de cubes en l'air | fût de même section, branches doublées à leur naissance |

Ce qui **passe sans retouche** : les quatre herbes, `buisson`, `buisson_neige`,
`herbe_gelee`, `ginseng`, `cactus_02`, `vrille`, `roseau`, les deux champignons,
`herbe_de_lave`, `algue`, `etoile_de_mer` ; côté arbres, les trois chênes, le
`pin`, le `rocher_geant`, l'`arbre_geant`, les deux conifères enneigés, les
tropicaux, les stipes et les quatre palmes ; et **les neuf filons**, qui se
jugeront de toute façon en paroi, le jour où leur pose existera (jalon 2.6).

Ce qui **passe mais reste le point faible du lot**, noté pour ne pas le
redécouvrir :

- **`snowberry`** : à quatre voxels par bloc une baie est un quart de bloc, et
  six baies blanches sur un buisson vert foncé lisent encore comme des plaques
  de neige. La bonne réponse est probablement une autre couleur, ce qui suppose
  de renoncer au nom ;
- **`deserts/cactus_geant`** : de face c'est un saguaro, de trois-quarts une
  colonne bosselée — ses bras sont dans un seul plan ;
- **`roseau`** : deux tons franchement séparés, vert sur jaune. Ce n'est pas
  faux pour un roseau, c'est seulement le modèle qu'on lit le moins vite.

### La leçon, et elle vaut au-delà des assets

Les huit défauts trouvés depuis le 2026-09-05 l'avaient tous été parce qu'ils se
**répétaient** — le fût qui dépasse, la tache orange, le champ de rochers. Les
vingt-sept d'aujourd'hui étaient dans le lot depuis le début, visibles au premier
coup d'œil, et invisibles autrement : à trente blocs une plante de deux blocs
fait dix pixels, et **dix pixels sont toujours plausibles**. Une capture de
biome répond à « est-ce que le paysage tient ? », jamais à « est-ce qu'on
reconnaît l'objet ? ».

Et la moitié de ce qui a été corrigé n'aurait pas dû demander un œil : un modèle
morcelé se compte. **Ce qui se mesure doit être mesuré avant d'être regardé** —
la planche sert alors à ce qu'elle seule sait faire, juger une silhouette.

---


## 7. Le tronc écrit dans le terrain — **fait le 2026-09-06**

C'était le dernier point du jalon 1, et le premier objet du projet à traverser
les deux mondes : **la matière et l'instance**. Un feuillu se pose désormais en
deux temps — un tronc écrit dans les données voxels par `CWVoxelGenerator`, un à
trois houppiers instanciés au-dessus par `CWFloraRenderer` — et les deux moitiés
sortent du même tirage, dans la même liste de placements.

### Ce qui a rendu la chose possible, et pourquoi elle ne l'était pas avant

Deux décisions prises pour d'autres raisons se paient ici :

- **le lot d'arbres est à un voxel par bloc** (jalon 1.12). Un tronc dessiné à
  3/40 n'avait aucune correspondance avec la grille du monde ; c'était
  l'argument *structurel* qui a fait changer la grille, et c'est lui qui se
  réalise ;
- **`CHANNEL_TYPE` et `CHANNEL_COLOR` sont séparés** (jalon 1.9). Un voxel de
  tronc porte le type `CWPalette.WOOD` — il est du bois pour tout le code qui
  raisonne en blocs — et **la teinte de son propre modèle** dans le canal de
  rendu. Les quatre écorces du lot survivent au passage dans le terrain, et
  aucun modèle n'est à repeindre. Sans ce partage, il aurait fallu un type de
  bloc par nuance.

### Le type de bloc : l'index 4, recyclé le jour même

Un tronc estampé a besoin d'un type dans la plage que le générateur écrit (0-13).
L'entrée prise est le **4**, libéré le matin même par le retrait de `GRASS_DRY` :
son index restait alloué pour ne pas décaler la réserve peinte dans les `.vox`, et
aucun modèle ne l'employait. Il change donc de statut sans qu'une frontière bouge
et sans qu'un fichier soit à repeindre — exactement le geste de `MAGMA` et
`SCORIA` sur 30 et 31, et exactement ce qui évite de repayer l'opération de
l'invariant n° 31.

> **Ce qui reste alloué finit par servir.** La note du matin justifiait de garder
> le 4 et le 9 plutôt que de les libérer ; le 4 a servi le soir même. C'est
> l'argument le plus court en faveur de cette prudence, et il vaut pour le 9.

### Une matière ne se met pas à l'échelle : elle se rééchantillonne

La gigue d'échelle d'un arbre va de 0,85 à 1,25, et un tronc estampé ne peut pas
être « 1,17 fois plus grand » : ses voxels sont des blocs. Un tronc fait donc
`round(hauteur × échelle)` blocs, et ses niveaux sont copiés **au plus proche
voisin** — la gigue survit, en nombres entiers. C'est cette hauteur-là,
`Placement.hauteur`, qui dit où s'accroche le premier houppier ; le produit
flottant ne décrit plus rien de posé, et un test le vérifie.

Le dessin **horizontal**, lui, n'est pas mis à l'échelle : un tronc 20 % plus
large ne se voit pas, et le garder entier maintient son empreinte alignée sur sa
colonne — celle-là même que `_piece` centre avec `fx = fz = 0.5` depuis le
2026-09-05, en prévision de ce jour.

### Une liste, deux lecteurs

`Placement.matiere` marque la seule pièce écrite dans le terrain. Un arbre reste
**un objet, un tirage, une liste** ; ce sont ses deux consommateurs qui se la
partagent — `CWVoxelGenerator._stamp_trunks` estampe ce qui est marqué,
`CWFloraRenderer` ignore ce qui l'est. Dupliquer la passe de montage aurait été
la faute évidente : deux moitiés d'arbre calculées séparément finissent toujours
par diverger d'un demi-bloc.

**Les espèces de montage ENTIER ne sont pas estampées.** Le pin, le sapin, le
cactus géant, le rocher géant et l'arbre à épines sont des modèles entiers, que
la source pose en entités (`docs/systems/02`, §5.2) : leur feuillage est dans le
même fichier que leur fût, et l'écrire dans le terrain donnerait du feuillage
qu'on ne traverse plus. On les traverse donc toujours — leur collision est un
sujet du jalon 3.1, et ce sera un volume approché, pas de la matière.

### Ce que la capture a montré, et qu'aucun test ne voyait

Le premier essai en jeu a rendu des **fûts nus, sans houppier**, au bord de la
vue. Le diagnostic a demandé trois hypothèses ; la bonne était une différence de
*forme* que personne n'avait remarquée depuis le jalon 1.7 :

> **Le terrain charge une boîte, la végétation garnissait un disque.**
> `CWFloraRenderer` posait ses cellules dans un disque de rayon
> `view_distance` — la forme naturelle d'une distance de vue — là où Voxel Tools
> charge une **boîte** de blocs autour de l'observateur. Les quatre coins de la
> boîte portaient donc du terrain sans porter de cellules. Tant que l'arbre
> entier était instancié, la cellule manquait et l'arbre avec elle : invisible.
> Depuis que le tronc est de la matière, le générateur l'écrit dès que son bloc
> existe — sans rien savoir des cellules — et le coin rend un fût nu.

La portée est donc un **carré**, pour les deux couches. Le prix est de 4/π, soit
27 % de cellules en plus, payées sur le fil du pool ; ce qu'il achète est la
seule chose qui compte ici : *ce que le terrain montre, la végétation le garnit*.

Une seconde correction est venue avec : une cellule à cheval sur le bord du
terrain chargé échouait **en bloc** (`_ground_ready` interroge la cellule
entière), donc soixante-quatre blocs sans une plante, y compris la moitié qui
repose sur du sol chargé. Elle se pose maintenant **à moitié** et se refait
entière quand le terrain la rattrape. Le test par plante interroge **sa colonne**
et non son volume : un houppier flotte à dix blocs du sol et déborde de sept,
exiger que *son* cadre soit chargé le refuserait alors que son tronc, lui, est
bel et bien écrit.

### Ce que ça coûte

**+2 %**, soit 0,4 s sur un chargement de 18. Vue de 384 blocs, au point de
départ : **17,9 et 18,1 s sans l'étampage, 18,4 s avec**. L'appel ne touche que
les blocs qui croisent la surface — les deux chemins rapides sortent avant —,
`trunks_in` consulte une à quatre cellules d'arbres, toutes en cache après le
premier bloc de la pile verticale, et une cellule de 64 blocs contient de
l'ordre de sept arbres.

Le passage du disque au carré, lui, **ne se mesure pas** : les 27 % de cellules
en plus se paient sur le fil du pool, et le verrou du chargement est la
génération du terrain, pas la végétation.

> **Une mesure de chargement se prend au démarrage, pas après un téléport — et
> ça a failli coûter une journée.** Les premières mesures ont été prises avec
> `-- --biome 0`, la commande de toutes les captures : elles donnaient 41 à 43 s
> là où la feuille de route annonce 16,4 s, et le premier réflexe a été de
> chercher une régression de facteur 2,5 introduite depuis le 2026-09-05. Il n'y
> en a pas. **Un téléport charge deux fois plus de blocs qu'un démarrage** — la
> zone quittée est encore en file quand celle d'arrivée entre —, et le compteur
> le disait depuis le début : 70 000 tâches contre 35 000. Sans téléport, le
> même monde se stabilise en **18,4 s pour 35 000 tâches**, ce qui reproduit la
> ligne de la feuille de route à deux secondes près — les 61 → 80 µs par colonne
> apportés depuis par `CWBiome` et les coulées de lave.
>
> La leçon n'est pas « il fallait lire le compteur » : c'est qu'**une mesure ne
> vaut que si son protocole est écrit à côté du nombre**. Les deux lignes sont
> maintenant dans `docs/ROADMAP.md`, chacune avec la sienne.

### Ce qui reste ouvert, et qui n'est plus bloquant

- **abattre un arbre est grossier.** `_supported` écarte tout candidat dont la
  colonne porte une édition : creuser un tronc retire donc ses houppiers à la
  reconstruction de la cellule, mais le fût garde son trou et reste debout. C'est
  le premier abattage du projet, pas le dernier mot — un vrai abattage demande de
  retirer la matière du tronc, ce qui est du jalon 3.2 (l'outil) plus qu'ici ;
- **la collision n'est pas branchée.** Le terrain de la démo a
  `generate_collisions = false` : la matière est là, le corps qui s'y cogne
  n'existe pas encore. C'est le jalon 3.1 qui l'allumera, et il n'aura rien à
  ajouter côté arbres ;
- **la pose des filons.** Les neuf modèles existent, le tirage de rareté est
  porté (`CWPalette.roll_ore`), il manque *où* ils affleurent. Cela appartient à
  la voie des entités, donc au jalon 2.6 — et l'estampage vient de faire la
  démonstration du mécanisme dont ils auront besoin ;
- **la réduction en distance.** `CWVoxelModel.reduced(n)` n'a toujours aucun
  usage. Un houppier de 22 blocs de large est le premier modèle assez gros pour
  la justifier, et il est maintenant seul dans son instance — le tronc ne le suit
  plus.

### Dix grands arbres, et la couleur qui manquait au lot

Demandés le 2026-09-06 : **deux par biome arboré**, un tronc, des branches, et
plusieurs feuillages en sphères aplaties, *dans d'autres couleurs que le vert*.
Dix espèces, vingt modèles, un quatrième montage.

**`Montage.GRAND`** est ce qui les distingue, et ce n'est pas un réglage de
FEUILLU : un feuillu empile ses houppiers **sur l'axe** de son tronc — sa
silhouette est une colonne coiffée, et son envergure ne dépasse jamais celle
d'un seul houppier. Un grand arbre porte ses masses **en dehors** de son axe, au
bout de branches dessinées dans le modèle de tronc, plus une à la cime. Cinq
masses, et c'est le fait qu'on puisse les compter qui le rend différent.

**Les branches sont écrites dans le terrain avec le fût** — elles font partie du
même modèle, et le tronc est estampé depuis §7. Un grand arbre pose donc dix
blocs de charpente de chaque côté de sa colonne, ce qui a fait passer
`MARGE_TRONC` de 4 à 11.

> **Deux tables doivent dire la même chose, et pour une fois la vérification est
> directe.** `CWTreeRules.SPECIES[...]["branches"]` déclare où sont les bouts,
> `generer_arbres.BRANCHES_*` les dessine. C'est le piège de `GRILLE_FINE`, à
> ceci près qu'on peut le trancher : `tests/tree_test.gd` charge le modèle et
> regarde s'il y a **du bois au bout déclaré**. Une branche déplacée d'un seul
> côté fait tomber la vérification.
>
> Les deux listes sont en coordonnées **Godot**, pas en coordonnées `.vox` :
> l'import fait tourner les axes (`vox(x, y, z) -> godot(y, z, x)`), et une
> liste écrite dans le repère du fichier porterait le houppier à quatre-vingt-dix
> degrés de sa branche. La conversion est faite une fois, dans `ab.charpente`.

**Les couleurs étaient déjà dans la palette, elles n'étaient pas employées.**
Douze des vingt-quatre modèles précédents puisaient dans la seule rampe de
feuillage : une forêt de Greenlands n'avait qu'une teinte. Les dix nouveaux
prennent l'automne (140-147), les quatre couples de fleurs (156-163), la rampe
des champignons et mousses (164-169), la roche nue pour le givre (14-19) et le
basalte pour la cendre (25-27). **Aucune entrée nouvelle** : érable doré,
cerisier rose, saule givré, arbre pourpre, acacia doré, baobab terre cuite,
flamboyant rouge, jacaranda violet, arbre de cendre noir à braises, arbre de
braise incandescent.

Une seule interdiction, et c'est l'invariant n° 29 : **aucune plante de
Snowlands ne prend la rampe d'automne**. Ses deux grands arbres prennent donc le
blanc-bleu et le violet, qui sont froids.

**Puis deux défauts vus en regardant le paysage, et le premier touchait tout le
lot, pas seulement les grands arbres :**

1. **il manquait la moitié basse de tous les dômes.** Le profil de `houppier`
   partait de sa largeur maximale **à la base** et ne faisait que rétrécir en
   montant : un parasol, pas une sphère aplatie. De loin, un arbre n'avait donc
   pas de feuillage sous ses branches — un chapeau de champignon posé sur un
   fût, et cinq chapeaux pour un grand arbre.

   > **Le défaut a survécu au jalon 1.12 parce que la note d'origine disait
   > « dôme en parasol »**, ce qui décrivait fidèlement une capture *vue d'en
   > haut* : d'en haut, une sphère aplatie et un parasol sont la même
   > silhouette. Ils ne le sont plus dès qu'on est dessous, c'est-à-dire tout le
   > temps. Le profil est maintenant un **ellipsoïde tronqué** — maximum à 42 %
   > de la hauteur, la moitié de la largeur aux deux pôles.

2. **tout le lot était trop petit** contre le jeu d'origine, relevé à l'œil sur
   des captures. Les vingt-quatre modèles et les dix nouveaux sont **agrandis de
   40 %** : le chêne monte à 32 blocs, l'arbre géant à 54, l'érable à 33. Les
   plafonds suivent (`(34, 12)` → `(48, 18)` pour un arbre, `(12, 11)` →
   `(20, 17)` pour un houppier), des deux côtés — le générateur refuse à
   l'écriture, le test refuse au chargement.

   **Et la densité suit, c'est l'invariant n° 33.** L'espacement passe de 14 à
   **20 blocs** — la moitié de la largeur d'un houppier, l'écart auquel deux
   couronnes se touchent sans se pénétrer — et les densités sont **divisées par
   deux**, soit le rapport des carrés `(20/14)² = 2,04`. Sans ça, des arbres
   deux fois plus larges à densité constante ferment la forêt : c'est
   exactement ce qui était arrivé aux cailloux le 2026-09-06.

**Deux réglages qu'il avait fallu voir pour trancher**, et aucun ne se déduisait :

1. **la portée doit dépasser le rayon du dôme, pas l'égaler.** Premier essai,
   branches à 5-7 blocs et dômes de 11-13 : les cinq masses se recouvraient
   presque entièrement et l'arbre se lisait comme **un seul** parasol —
   c'est-à-dire comme un feuillu. Branches à 8-10, dômes à 10 ;
2. **un dôme de trois blocs d'épaisseur pour dix de large est une galette.**
   `houppier` rend à peu près la moitié de la hauteur demandée — son profil se
   ferme avant le sommet —, donc 6,5 pour cinq blocs. Un rapport de deux entre
   largeur et hauteur se lit comme une masse ; à trois pour un, c'est un plateau.

### La suite : 2.6, l'apparition

**Le jalon 1 est clos.** La porte suivante est **2.6**, la pose des points
d'apparition, et elle est largement déblayée :

- `WorldInfo_scatterObjectsInArea` (@005f56c0) est lue — elle **ne disperse pas
  d'objets**, elle choisit la liste d'espèces d'un point d'apparition selon le
  climat et le niveau, et écrit son résultat dans un `cube::Spawn` ;
- les **constantes de pose sont déjà extraites** : `docs/systems/02`, §6 — pas
  de 0x55 = 85 unités, décalage +24, gigue `rand()%10`, une tentative sur quatre
  abandonnée d'entrée, rejet si le poids d'influence d'un élément de tuile non
  nul et non-10 dépasse 0,3 (les poses **évitent** les éléments, sauf le
  donjon), une chance sur quatre d'abandonner sous 0,2 d'humidité et de même
  pour la température, espacement minimum de 20 unités, lacet initial uniforme ;
- la **couche d'éléments de tuile** qui les porte existe depuis 1.6, et la
  **carte du jalon 1.10 sait déjà les afficher** ;
- le constructeur est repéré : `cube::Spawn::ctor_0` alloue **0x10f0 octets**,
  et la boucle de pose de `World_populateRegionDecorations` en remplit les
  champs — `+0x28` la sorte, `+0x2c` le code de type d'entité (celui du `switch`
  de §5, donc le même espace que la flore), `+0x34` le niveau, `+0x7a` des
  drapeaux dont `0x200` « porte un inventaire » et `0x1000`, `+0x58` un index
  d'apparence. `creature_generateAppearance` et `creature_initBehaviorByType`
  sont appelées juste après, ce qui donne l'enchaînement complet
  pose → apparence → comportement ;
- **et la pose des filons y trouve son appelant.** Les neuf modèles existent,
  le tirage de rareté est porté, l'étampage vient d'être démontré sur les
  troncs : il ne manque que *où* un filon affleure.

Ce qu'il faudra décider avant d'écrire : un point d'apparition **persiste-t-il**
comme la découverte de la carte, ou se recalcule-t-il à la volée comme la flore ?
L'original le recalcule par tuile et lui donne un niveau **dynamique** — le
niveau maximum des joueurs présents, §7 —, ce qui plaide pour la seconde voie et
évite une seconde base sur le disque.

### Ce qui reste ouvert dans le jalon 1, sans bloquer

- **Le nénuphar n'est pas porté** : le lot des 38 modèles n'en a pas, et
  `CWPalette.surface_index` ne rend jamais `WATER`. Le rôle est identifié, la
  branche de la source aussi (`docs/systems/02`, §8.6).
- **Le lacet libre** de trois rôles — roseau, sous-bois humide, nénuphar. Noté
  dans `CWDecorRules.FREE_YAW`, pas rendu : `CWVoxelModel` ne précalcule que
  quatre quarts de tour. Il faudrait une rotation continue du maillage.
- **La crête de placement à 0,6.** La source emploie 0,5 sur le sol humide,
  0,6 sur le sol végétalisé, 0,7 sur l'eau ; ce projet en garde une seule à 0,5.
  C'est un réglage de taille de plaque, et `PLACEMENT_PASS_RATE` est mesuré sur
  0,5 : le porter demande une part passante par crête, et un budget par surface.
- **Le décalage de cinq** entre les deux moitiés du domaine de types de décor
  (`docs/systems/02`, §8.5). Se lèvera si le consommateur du champ `type` est
  un jour localisé — il ne l'a pas été.
- **Le type 13 (piton de +150) n'a pas de source.** `World_generateRegionFeatures`
  ne le produit jamais. L'effet est porté et testé, mais aucun élément ne le
  porte.
- **Le palier d'un élément est reconstruit.** `formula_inverse` n'est pas résolue
  dans le dépôt d'analyse. Sans effet sur l'altitude, mais il décide si la
  branche de difficulté consomme un tirage, donc il décale la suite du flux.
  Voir `CWTileFeatureGrid._tier_of`.
- **Les types d'éléments 2, 10, 14, 15** n'ont pas été isolés ; 6 = champ de
  rochers, 11 = massif isolé, 12 = plan d'eau, 3 = parcelle bâtie le sont.
- **La numérotation des blocs** est presque établie :
  `terrain_surfaceColor_blend` (@005c56e0) est la règle de surface de l'original
  et n'écrit que cinq types — 4 par défaut, 9, 10, 12 et 6 forcé par l'appelant
  sur la falaise. Reste à trancher lequel de ses deux paramètres climatiques est
  la température (`docs/systems/02`, §9).

Un cache disque du terrain reste prématuré : la couche d'éléments de tuile écrit
encore dans les données du monde, et c'est elle qui bougerait la première.

| fonction | adresse | rôle |
|---|---|---|
| `WorldInfo_scatterObjectsInArea` | `@005f56c0` | **la cible de 2.6** : choix d'espèce d'un point d'apparition |
| `cube::Spawn::ctor_0` | — | l'enregistrement, 0x10f0 octets |
| `creature_generateAppearance` | `game_misc.cpp:3197` | code d'entité → modèle + boîte (`docs/systems/02`, §5) |
| `creature_initBehaviorByType` | — | l'arbre de comportement, jalon 2.2 |
| `World_generateVegetationCluster` | `@005d8750` | résolveur de contenu d'une tuile : combien d'objets, dans quelle cellule |
| `World_populateRegionDecorations` | `@005cc510` | bâtisseur de village, sites de région 3 et 5 (jalon 4.3) |
| `WorldInfo_placeStructure` | `@005f0ce0` | placement de structures et de leur décor (jalon 4) |
| `terrain_surfaceColor_blend` | `@005c56e0` | la règle de surface d'origine |

**Onze noms trompeurs** ont été relevés dans le dépôt d'analyse ; ils sont
listés dans `docs/ROADMAP.md`, §1.7, « correction de sources ». Les deux qui
comptent pour la suite : `WorldInfo_scatterObjectsInArea` **ne disperse pas
d'objets** et `World_generateTreeRecursive` **ne génère pas d'arbres**.

## 7bis. La prochaine session — **la falaise, puis les lacs et les chemins**

Décidé le 2026-09-06, après la question « a-t-on prévu un jalon pour les lacs,
les rivières, les chemins entre POI et les falaises ? ». Réponse : non, aucun des
quatre n'a de jalon, et ils ne sont pas au même stade. L'ordre qui suit n'est pas
un ordre de préférence, c'est celui de leurs dépendances.

### 1 — La falaise, d'abord

**C'est une règle de la source, quelques lignes dans `surface_of`, et elle rend
au relief ce qu'on lui a enlevé.**

`terrain_surfaceColor_blend` (@005c56e0) force le bloc **6 — la roche** quand
« le facteur de falaise dépasse 0,5 » (`docs/systems/02`, §9.1). C'est la
cinquième et dernière règle de la table de surface d'origine, et la seule que ce
projet n'a pas portée. Ce qu'il manque est le **facteur** lui-même : une pente,
mesurée sur le champ d'altitude, dont le seuil est déjà connu.

Elle referme un trou ouvert volontairement le 2026-09-06 : les trois bandes
d'altitude ont été retirées parce qu'**une matière qui ne porte rien est un trou
dans le monde** — la roche nue et la calotte de neige rendaient des plateaux nus
où l'on marchait sans rien rencontrer. Le raisonnement était juste et le remède
trop large : une montagne *a* de la roche, simplement elle en a sur ses **pentes
raides**, pas sur ses sommets plats. C'est exactement ce que dit la source, et
`nextsteps.md` l'avait noté le jour même — « ce sera une pente à mesurer, et
c'est probablement là que la roche nue doit revenir ».

Points d'attention :

- `surface_of` prend déjà `(x, z)` depuis les coulées de lave : la pente s'y
  échantillonne sans changer de signature ;
- `tools/biome_stats.gd` donne la répartition avant/après en douze secondes,
  et c'est lui qui dira si le seuil de 0,5 rend 2 % ou 30 % du monde en roche ;
- `CWDecorRules.decor_allowed` refuse déjà le décor sur la roche : une falaise
  sera nue, et c'est **voulu** cette fois — une paroi verticale ne porte rien.
  Le test de `decor_test.gd` qui refuse les matières nues hors Oceans et Lava
  Lands devra apprendre cette exception, et c'est là qu'il faudra être précis :
  l'exception est *la pente*, pas *l'altitude*.

### 2 — Les lacs et les chemins, ensemble

**Parce qu'ils sont littéralement la même fonction à analyser**, et parce que
les deux butent sur la même décision.

`World_generateWaterOrPathFeature` : le nom porte les deux mots. C'est elle que
l'élément de tuile **type 12 — plan d'eau** appelle, une fois au centre de sa
tuile, en rayon 80 × 80 et mode 6 (`docs/systems/02`, §4). Elle n'est pas
analysée (§9.5). Le mode est un paramètre : il y a tout lieu de croire qu'un
autre mode donne le chemin, et c'est la première chose à vérifier en la lisant.

Côté chemins, il faut savoir ce qu'on cherche : **la source n'a pas de réseau de
routes entre POI**, et c'est une correction déjà écrite (jalon 1.6). Le type 1
n'est pas « les routes », `World_roadField` est l'aplanissement du bourg, et les
arêtes du graphe de sites ne sont pas des voies — `site_edge_radius` reste à 0.
Si des chemins existent dans l'original, ils passent par cette fonction-ci, à
l'échelle d'une tuile. Un réseau reliant les bourgs d'une région serait une
**création de ce projet**, et il faudra le dire comme tel.

> **La seule vraie question d'architecture des trois : comment le monde
> porte-t-il de l'eau au-dessus du niveau de la mer ?**
>
> Aujourd'hui il ne le peut pas. « L'eau n'est pas de la matière, c'est le vide
> sous le niveau de la mer » (jalon 1.8, `docs/systems/03`) : `World_getBlockAt`
> ne lit jamais un bloc d'eau, il rend un témoin d'eau si `z <= 0` et un témoin
> d'air sinon, et `CWWorldEdits.erase_value` rejoue la même règle. Un lac à
> l'altitude 40 est donc impossible **par construction**, et une rivière aussi —
> le réseau de chenaux du jalon 1.4 creuse bien les vallées, mais rien ne les
> remplit.
>
> Trois issues, et aucune n'est gratuite :
>
> 1. **un niveau d'eau par élément de tuile.** L'eau reste implicite, mais son
>    niveau devient une propriété locale au lieu d'une constante globale. C'est
>    le moins invasif et ça suffit aux lacs ; ça ne suffit pas aux rivières, qui
>    descendent ;
> 2. **l'eau redevient de la matière écrite**, comme au tout début. On y gagne
>    les rivières et les cascades, on y perd la règle d'effacement de 1.8 et il
>    faut un type de bloc qui coule ;
> 3. **une couche d'eau séparée**, ni terrain ni décor, avec sa propre surface.
>    C'est ce que font la plupart des moteurs voxel ; c'est aussi le plus gros
>    morceau, et il ne ressemble à rien de ce que la source fait.
>
> Trancher **avant** d'écrire une ligne : les trois donnent des lacs, une seule
> donne des rivières, et le choix se paie sur tout le reste du jalon 1.

### Et 2.6 reste ouverte

L'apparition n'attend rien de ce qui précède : la fonction est lue, les
constantes de pose extraites, la couche d'éléments existe depuis 1.6 et la carte
sait les afficher (voir la section suivante). C'est l'autre porte, et elle mène
au jalon 2 plutôt qu'à la fin du jalon 1.

---


## 8. Assets voxels

### 8.1 L'échelle — fixée le 2026-09-04, alignée sur l'original le 2026-09-05

**Il y a quatre grilles depuis le 2026-09-06, et les quatre servent à
dessiner.**

* **la grille fine, 40/3 voxels par bloc** — trois blocs valent exactement
  40 voxels, et le personnage de référence mesure 32 voxels, soit 2,4 blocs.
  Elle porte le personnage, les créatures, le mobilier, les objets. C'est **la
  valeur mesurée** : les échelles d'instanciation du décor de l'original sont
  0,075 / 0,09 / 0,1, et 0,075 = 3/40 exactement ;
* **les petits props de flore, 6 voxels par bloc** — herbes et fleurs. La liste
  est `CWModelLibrary.GRILLE_FINE`, et elle doit dire la même chose que la
  colonne `FIN` du catalogue de `generer_flore.py` ;
* **le reste de la flore, 4 voxels par bloc** — buissons, cactus, champignons,
  fougères, coraux : ce qui a du volume ;
* **la grille du terrain, 1 voxel = 1 bloc.** Elle porte **les arbres et les
  filons**. C'est un champ de `CWVoxelModel` (`voxels_per_block`) et non une
  constante — voir l'invariant n° 28.

**Pourquoi la flore en a deux et pas une.** Quatre voxels par bloc va bien à ce
qui est une *masse* : un buisson, un cactus, un champignon se lisent à n'importe
quelle résolution parce que leur forme est leur volume. Ce qui s'y perd, ce sont
les objets **dont toute la forme tient dans un trait** — une touffe d'herbe est
cinq lignes, une fleur est une tige et une corolle. À quatre voxels par bloc,
une corolle est une croix de cinq voxels et une touffe un paquet de bâtonnets :
le grain est juste, la silhouette ne l'est plus. Six voxels par bloc rend à ces
objets de quoi dire leur forme — une touffe passe de sept à onze voxels de haut
— **sans revenir au cheveu**, un brin faisant un sixième de bloc et non un
treizième.

**Pourquoi la flore a quitté la valeur mesurée, et il faut le dire dans ce
sens-là.** 3/40 n'est pas contesté : c'est bien l'échelle du décor de
l'original, et elle implique qu'une touffe d'herbe y est dessinée treize fois
plus fin qu'un bloc de terrain. Ce projet l'a portée fidèlement jusqu'au lot du
2026-09-06. C'est **le rendu qui l'a refusée** : vu en jeu, un brin de
0,08 bloc à côté d'un cube de terrain d'un bloc ne lit pas comme un cube, il lit
comme un cheveu, et une prairie entière comme une fourrure. Le lot d'arbres
avait montré l'autre moitié de l'argument trois jours plus tôt — ce qui lit
juste, c'est ce qui partage le grain du terrain.

Quatre voxels par bloc est le compromis : assez gros pour que le grain se voie,
assez fin pour qu'une fleur reste une fleur à deux ou trois voxels. **La taille
des plantes en blocs n'a pas bougé** — une touffe fait toujours 1,75 bloc, avec
sept voxels au lieu de vingt-trois. C'est une résolution de dessin qu'on change,
pas une enveloppe, et c'est pour ça que le plafond de `tests/flora_test.gd`, qui
est dit **en blocs**, a survécu au changement sans qu'on y touche.

Cette entrée relève donc de l'expression et non de l'algorithme, au sens de la
note de périmètre du `README` — elle est signalée comme telle dans
`CWVoxelModel.VOXELS_PER_BLOCK_FLORE`, qui porte la note complète.

Le détail par catégorie d'objet est dans `assets/models/MODELS.md`, le fichier à
donner à qui modélise.

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

### 8.2 Ce qu'il faut produire, par biome

**Rien pour le jalon 1.6** : il ne fait que déformer l'altitude, rendue avec la
palette existante. Le jalon 1.7 (dispersion sur le terrain) est le premier qui
demande des modèles — et la mécanique qui les pose est en place : déposer un
`.vox` dans `assets/models/flore/` suffit à le voir dans le monde, dès lors que
son nom figure dans la table de `CWModelLibrary`.

La liste des *rôles* n'est plus une estimation : le binaire d'origine charge
**2 550 modèles voxels nommés** (`.cub`) — le chiffre de 154 retenu jusqu'au
2026-09-05 était une énumération partielle. On n'en reprend aucun — ce sont des
créations originales — mais ce dont un monde comme celui-là a besoin est établi.

**Les rôles produits sont tous confirmés** par ce relevé, nom pour nom :
`cornflower` = bleuet, `sunflower` = tournesol, `heartflower` = fleur_coeur,
`soulflower` = fleur_ame, `ginseng-root` = ginseng, `reed` = roseau,
`ivy` = lierre, `tendril` = vrille, `alga` = algue, `coral` = corail. Le lot du
jalon 1.12 en ajoute une dizaine pris à la même liste et jusque-là non produits :
`snow-berry`, `snow-bush`, `heartflower-frozen` (notre `fleur_de_glace`),
`shimmer-mushroom`, `lava-grass`, `lava-flower`, plus le coton et le habanero du
désert. Restent non produits : `berry-bush`, `thorn-plant`, `desert-flower01/02`,
`water-lily01/02`, `underwater-plant`, `plant-fiber`, `runestone`, `stone2`,
`sandstone`.

**Les arbres sont des assets — correction du 2026-09-05.** Le corpus charge
`fir-tree.cub`, `thorn-tree.cub`, `christmas-tree.cub`, `tree-leaves.cub`,
`palm-leaf.cub`, `palm-leaf-diagonal.cub`, `wood-log.cub`. Il n'y a **pas**
d'algorithme d'arbre à porter : `World_generateTreeRecursive` est nommée d'après
les arbres rouge-noir de la STL. **Tranché** : le feuillu est une composition
tronc + houppiers instanciés — `tree-leaves` porte son propre code d'entité,
loin des deux arbres, et le corpus n'a aucun modèle de tronc.

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

#### Les six biomes, et ce que chacun porte

Ce sont les biomes de l'alpha 2013, décidés par `CWBiome.at`. Touches **1** à
**6** de la démo pour s'y téléporter, `-- --biome 0..5` pour une capture.

| biome | flore | arbres |
|---|---|---|
| **greenlands** | `herbe_01` `herbe_02` `herbe_03` `herbe_seche` `fleur_bleuet` `fleur_tournesol` `fleur_coeur` `ginseng` `buisson` `scrub` `broussaille` `fougere` | `chene_tronc` + 2 houppiers, `bouleau_tronc` + houppier, `pin`, `rocher_geant`, `arbre_geant_tronc` + houppier |
| **snowlands** | `herbe_gelee` `fleur_de_glace` `buisson_neige` `snowberry` `cotonnier` | `pin_enneige`, `sapin_enneige`, `bouleau_givre_tronc` + houppier |
| **deserts** | `cactus_01` `cactus_02` `broussaille_seche` `cotonnier` `habanero` | `cactus_geant`, `palmier_tronc` + `palme` + `palme_diagonale` |
| **jungles** | `feuille_large` `fougere_geante` `liane` `vrille` `lierre` `fleur_coeur` `fleur_ame` `roseau` `champignon` | `tropical_tronc` + 2 houppiers, `palmier_tronc` + 2 palmes |
| **lavalands** | `fire_shrub` `herbe_de_lave` `fleur_de_lave` `champignon_luisant` | `arbre_epineux` |
| **oceans** | `algue` `corail` `etoile_de_mer` | — |

**38 modèles de flore, 24 d'arbres, 9 filons.** Oceans n'a pas d'arbre : une île
émergée n'est pas Oceans, c'est son climat qui la nomme, et elle porte les
arbres qui vont avec.

**Aucun fichier n'est partagé entre deux biomes**, et un test refuse qu'un
chemin traverse. Rien ne l'interdit techniquement — le cache est indexé par
chemin — mais un modèle partagé porte les teintes d'un seul biome. Le
champignon luisant est dessiné deux fois pour cette raison.

Quelques matières de surface ont leur propre composition, indépendamment du
biome : le **sol humide** (roseau, dans Jungles) et l'**herbe sèche** (dans
Greenlands). Ce sont les deux seules, elles vivent dans
`CWDecorRules.FAMILIES_SURFACE`, et chacune déclare le biome qui la produit —
voir l'invariant n° 27.

#### Plus cinq cultures, pour les champs des villages

`ble` `mais` `carotte` `coton` `citrouille` — mêmes conventions, dossier
`assets/models/culture/`. Elles ne sont pas dispersées par biome mais posées en
rangées par le système de champs (`Field.cpp`, jalon 4.3). À faire après les 28.

#### Une réserve d'honnêteté sur l'affectation

Quels modèles vont dans quel biome **n'est pas lu dans le binaire** : la table de
correspondance est dans `WorldInfo_generateBiomeContent` (@005e4850), 3 100
lignes, pas encore analysée. La répartition ci-dessus vient de la **liste de
contenu par biome de l'alpha 2013**, relevée à part, et du bon sens pour le
reste. Les *noms de biomes* et les *rôles* sont sûrs ; l'affectation d'un modèle
donné peut bouger, et coûte une ligne de code.

Ça ne change rien à ce qu'il faut produire — la *liste* des 28 est sûre, elle
vient des noms de modèles du binaire. Seule l'affectation peut bouger, et
réaffecter un modèle existant coûte une ligne de code.

#### Ce que les lots mesurent réellement

Relevé par `tools/inspect_model.gd` sur les lots du 2026-09-06. L'outil connaît
les **deux grilles** depuis ce jalon : il annonçait le pin à 1,65 bloc de haut là
où il en fait 22, et c'est justement l'outil qu'on consulte pour vérifier une
échelle.

**La flore**, en voxels de modèle (40/3 = un bloc), et en hauteurs de personnage
(2,4 blocs) :

| rôle | hauteur | × personnage |
|---|---|---|
| `etoile_de_mer` | 6 | 0,22 |
| `fleur_bleuet` | 10 | 0,38 |
| `champignon_luisant`, `champignon` | 13 – 15 | 0,49 – 0,56 |
| `snowberry`, `habanero` | 15 | 0,56 |
| `scrub`, `broussaille`, `ginseng`, `feuille_large` | 16 – 17 | 0,60 – 0,64 |
| `buisson`, `fleur_coeur`, `fire_shrub`, `herbe_gelee` | 20 – 21 | 0,75 – 0,79 |
| `cotonnier`, `corail`, `lierre`, `herbe_01` | 23 | 0,86 – 0,90 |
| `herbe_seche`, `herbe_02`, `fleur_tournesol`, `cactus_02` | 26 – 27 | 0,97 – 1,01 |
| `algue`, `caillou_basalte`, `caillou_01` | 28 – 31 | 1,05 – 1,16 |
| `roseau`, `vrille`, `liane`, `gres` | 31 – 35 | 1,16 – 1,31 |
| `fougere_geante` | 40 | 1,50 |
| `fougere`, `cactus_01` | 43 | **1,61** |

Tout tient largement dans l'enveloppe dure vérifiée par le test (53 de haut,
26 de rayon), et le rayon maximum du lot est de **2 blocs** — c'est lui qui
dimensionne la marge de `placements_in` pour toute la flore.

**Les arbres**, en blocs, un voxel valant un bloc :

| modèle | largeur × hauteur | × personnage |
|---|---|---|
| `palme`, `palme_diagonale` | 13 – 19 × 3 – 4 | 1,25 – 1,67 |
| `chene_tronc`, `bouleau_givre_tronc` | 3 – 4 × 12 | 5,0 |
| `arbre_epineux`, `tropical_tronc` | 6 × 13 | 5,4 |
| `bouleau_tronc`, `palmier_tronc` | 3 – 4 × 14 – 15 | 5,8 – 6,3 |
| `rocher_geant` | 12 × 12 | 5,0 |
| `sapin_enneige` | 9 × 19 | 7,9 |
| `pin`, `pin_enneige`, `arbre_geant_tronc` | 9 – 11 × 22 | **9,2** |
| houppiers | **11 – 22 de large × 5 – 8 de haut** | — |

**Les houppiers sont tous plus larges que hauts**, d'un facteur 2 à 3, et un
test le vérifie. C'est la forme qu'ils ont sur les captures du jeu d'origine, et
c'est ce qui fait une canopée plutôt qu'une brochette de boules.

#### Les lots suivants, pour information

- ~~**Jalon 1.11, arbres et grande végétation (14)**~~ **livré le 2026-09-05,
  puis entièrement refait le 2026-09-06** : 24 modèles à **1 voxel = 1 bloc**,
  sous `assets/models/arbres/`. Deux choses le distinguent du lot de flore, et
  elles se retrouvent dans le code : la **grille**, imposée par la bibliothèque
  au chargement (invariant n° 28), et le fait qu'un **houppier n'a pas de
  tronc** — il se pose au sommet d'un fût, ce qui en fait le premier objet du
  projet à traverser les deux mondes.
- ~~**Jalon 1.11, les neuf filons** : bloqués sur une décision de palette.~~
  **Tranché et dessiné le 2026-09-05** : `RANGE_TERRAIN_END` est passé de 31 à
  40 et rien d'autre n'a bougé. Ce qui reste est leur **pose**, qui appartient à
  la voie des entités du jalon 2.6.
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

### 8.3 Décision d'authoring — prise, et confirmée

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

## 9. Décisions ouvertes

- Le relief lointain paraît bleuté (ambiante du ciel sur les faces détournées du
  soleil). Réglage d'ambiance, pas un défaut de génération.
- Les teintes des plages d'assets sont des rampes de départ, à ajuster. Le
  découpage en plages, lui, est un contrat : le changer invalide les modèles
  déjà peints. Depuis le 2026-09-05 il y a des modèles peints dessus, donc
  ajuster une teinte se voit maintenant en jeu — c'est justement le bon moment
  pour le faire, avant le lot suivant.
- ~~**Deux tables de hauteurs coexistent et ne disent pas la même chose.**~~
  **Réglé le 2026-09-06** : `assets/models/MODELS.md` §1 porte les valeurs du lot
  regénéré, et c'est la seule table de référence. Rappel de ce qui l'a fait
  bouger : c'est cette ligne-là — « touffe d'herbe au genou » — qui avait
  dimensionné les trente-neuf premiers modèles. Un repère faux dans un document
  d'authoring coûte un lot entier.
- Les arêtes du graphe de sites ne sont **pas** le tracé des routes : le type 1
  est un élément unique par zone, posé sur son site. `site_edge_radius` reste
  donc à 0, et l'hypothèse notée au jalon 1.5 est close.
- **La gigue d'échelle de 1× à 2× est appliquée partout ici, nulle part dans la
  source.** L'original ne la tire que sur le décor immergé ; ailleurs il écrit
  une échelle fixe ou une petite plage par type. Elle est gardée parce que notre
  lot a moins de variantes par rôle et que le champ se lirait comme un motif
  répété sans elle — mais c'est une décision de ce projet, et elle se multiplie
  désormais au rapport de taille du rôle (`CWDecorRules.SCALE_RATIO`), ce qui
  porte une instance de caillou jusqu'à 2,9× son modèle.
- **Les feuilles de `CWDecorRules.FAMILIES` sont réattribuées, pas lues.** Trois
  branches viennent mot pour mot de la source — sol tempéré, sol chaud, fond
  marin ; les autres lignes rangent nos biomes dans la forme de la règle. Les
  changer coûte une ligne, et rien dans la source ne les contraint : c'est le bon
  endroit où ajuster ce qui se voit mal en jeu.
- **La règle des six biomes est une classification de ce projet.** La *liste*
  vient de l'alpha 2013 et les fourchettes de climat aussi, mais la conversion
  entre le champ normalisé de `CWTerrainField` et les degrés Celsius est une
  convention (`CWBiome.TEMP_MIN_C` / `TEMP_MAX_C`), et les seuils ont été
  **recalés sur la répartition mesurée** plutôt que sur les degrés. Ils sont donc
  ajustables sans rien casser, à condition de relancer `tools/biome_stats.gd` —
  c'est écrit dans l'en-tête du fichier, et §6.3 dit pourquoi.
- **La bande d'herbe sèche de Greenlands est large.** `DRY_GRASS_H` est à 0,46,
  ce qui donne 5,1 % du monde ; l'alpha place Greenlands entre 30 et 70 %
  d'humidité, ce qui la mettrait plus bas. La raison est mesurée : le champ
  d'humidité n'a presque rien entre 0,10 et 0,40, donc le seuil ne peut pas se
  poser au milieu — il attrape ou non l'amas 0,40-0,45 tout entier. À 0,42 la
  steppe disparaîtrait du monde.
- **Oceans n'a été vu que d'au-dessus.** Voir §6.5.
