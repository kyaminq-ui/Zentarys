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

# Regénération du lot de flore (39 .vox, ~2 min). Déterministe : une graine en
# dur par fichier. `-- --seul <nom>` ne refait qu'un modèle.
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python tools/blender/generer_flore.py

# Regénération du lot d'arbres (14 .vox, ~13 s). Même chemin, mêmes garde-fous.
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python tools/blender/generer_arbres.py

# Regénération des neuf filons (~1 s). Python pur : à 1 voxel = 1 bloc, Blender
# n'apporte rien. N'importe quel Python 3 fait l'affaire, celui de Blender aussi.
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python tools/blender/generer_filons.py

# Capture d'un biome donné, en jeu, sans piloter la fenêtre. C'est le SEUL moyen
# de voir une couche de rendu : un test headless n'a pas de rastériseur.
# --biome prend un index de surface (3 herbe, 4 herbe sèche, 5 jungle, 6 sable,
# 7 neige, 9 toundra, 10 marais), --shot le délai en secondes avant la capture
# (le temps que le terrain charge), puis la session se ferme d'elle-même.
# Le PNG sort dans user://shots.
./godot.windows.editor.double.x86_64.exe --path . scenes/terrain_demo.tscn \
    --resolution 1600x900 -- --biome 7 --shot 32 --vue 256
#   options : --sans-arbres, --sans-flore, pour isoler une couche

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
**M** carte du monde (`+`/`−` pour l'élargir), **1-9** téléportation vers un
biome, **Échap** rend la souris puis quitte.

## 3. État

Jalon 1 (le monde) : 1.1 à 1.10 sont **portés, testés et vus en jeu** ; **1.11
est aux trois quarts** — assets, dispersion et rendu faits, il manque le tronc
écrit dans le terrain et la pose des filons. Suite de validation :
**297 vérifications, 0 échec**, ~20 s.

**1.11 — arbres et grande végétation, en cours** (2026-09-05). Trois temps
prévus, deux faits. Le **lot d'assets** : 14 arbres sous
`assets/models/arbres/` et 9 filons sous `assets/models/filons/`, produits par
script comme la flore, déterministes — les 62 modèles du dépôt se régénèrent à
l'identique. La **couche de dispersion** : `CWTreeScatter`, cellule de 64 blocs,
bibliothèque à part, espacement minimum de 7 blocs qui tient au travers des
frontières de cellule. Les arbres **sont en jeu**, sept biomes vérifiés en
capture. Ce qui reste : le tronc en matière (donc la collision), et la pose des
filons, qui appartient à la voie des entités du jalon 2.6.

Deux décisions prises au passage, toutes deux notées dans les invariants §4 :
la **frontière de palette** a bougé une fois (terrain 1–31 → 1–40) pour loger
les filons, sans repeindre un seul modèle ; et les arbres se décident sur
**leur propre champ** de bruit, pas sur les deux crêtes de la flore.

> ⚠️ **Les deux lots posés au sol sont mal dimensionnés** (2026-09-05 au soir,
> après examen de six captures du jeu d'origine).
>
> Le **lot d'arbres** est à refaire : **deux à trois fois trop petit**, ses
> houppiers **trois fois trop étroits et de la mauvaise proportion**, et dessiné
> **sept à treize fois trop fin** — les arbres de l'original sont bâtis des mêmes
> cubes que le terrain, pas de ceux de la flore.
>
> Le **lot de flore** est à la bonne grille — 3/40 est mesuré pour le décor —
> mais **deux fois et demie trop petit et deux à quatre fois trop dense** : une
> touffe d'herbe monte à l'épaule du personnage, pas au genou, et elle a cinq
> brins, pas vingt. La cause est un repère faux de `MODELS.md` §1, corrigé
> depuis.
>
> Dans les deux cas, **la couche de dispersion et le montage restent valables** :
> ce sont les tailles et le grain qui changent, pas l'architecture. Détail,
> chiffres et méthode en §6.

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
  cw_palette.gd            palette et règles de surface (couleurs originales)
  cw_voxel_generator.gd    VoxelGeneratorScript + cache de colonnes
  cw_voxel_model.gd        modèle .vox préparé : liste creuse, maillage 3/40
  cw_model_library.gd      chargement des modèles + table modèle/biome
  cw_scatter.gd            grille de dispersion 16², cellules en cache
  cw_decor_rules.gd        rôles du décor : deux crêtes, rareté, taille (1.7)
  cw_flora_renderer.gd     instanciation de la flore (MultiMesh par cellule)
  cw_world_edits.gd        creuser, poser, interroger un bloc (jalon 1.8)
  cw_light.gd              éclairage voxel : deux passes, cases à repeindre (1.9)
  cw_world_map.gd          carte : dalles de Voronoï, découverte, teintes (1.10)
  cw_region_name.gd        noms de région : deux tables de vingt syllabes (1.10)
src/demo/terrain_demo.gd   scène de démonstration (arbre voxel construit en code)
src/demo/scale_board.gd    gabarit d'échelle : mires, silhouette, modèles
src/demo/map_overlay.gd    affichage de la carte (touche M)
tests/worldgen_test.gd     suite headless, 256 vérifications
tests/tile_features_test.gd  la moitié qui concerne les éléments de tuile
tests/decor_test.gd        rôles, tables croisées, composition régionale (1.7)
tests/flora_test.gd        modèles, dispersion, maillage et pose (jalon 1.7)
tests/edit_test.gd         règles d'édition, requête ponctuelle, persistance (1.8)
tests/light_test.gd        les deux passes, l'atténuation, les cases à repeindre (1.9)
tests/map_test.gd          échelle, découverte, puzzle, rendu, noms (1.10)
tools/export_palette.gd    régénère assets/palette/*.png depuis CWPalette
tools/preview_features.gd  gros plan ombré, avec et sans la couche d'éléments
tools/inspect_model.gd     inventaire d'un .vox : gabarit, index, plages
tools/repaint_models.gd    remet un .vox dans la palette de projet
tools/preview_map.gd       aperçu de la carte, vierge et après une diagonale
docs/prompt_generation_arbres.md  commande du lot d'arbres (jalon 1.11)
tools/blender/             générateurs des lots de modèles (Python + bpy)
  flore_vox.py               palette verbatim, écriture .vox, garde-fous
  flore_formes.py            brins, tiges, feuilles, corolles, cailloux
  flore_blender.py           courbes, métaballes, échantillonnage sur grille
  generer_flore.py           les 39 modèles de flore basse (jalon 1.7)
  arbres_formes.py           futs, charpentes, frondaisons, conifères, palmes
  generer_arbres.py          les 14 modèles d'arbres (jalon 1.11)
  generer_flore.py           le catalogue des 39, une graine par modèle
  arbres_formes.py           futs, charpentes, frondaisons, conifères, palmes
  generer_arbres.py          le catalogue des 14 arbres (jalon 1.11)
  generer_filons.py          les 9 filons, à 1 voxel = 1 bloc
src/worldgen/cw_tree_rules.gd    les espèces d'arbres et leurs trois montages
src/worldgen/cw_tree_scatter.gd  la couche jumelle : cellule de 64, espacement
tests/tree_test.gd         lot, enveloppes, dispersion, espacement, montage
assets/palette/            palette de projet + PALETTE.md
assets/models/flore/<biome>/  39 modèles, un dossier par biome
assets/models/arbres/<biome>/ 14 modèles d'arbres
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
26. **La frontière `RANGE_TERRAIN_END` / `RANGE_CREATURES_BEGIN` a bougé une
    fois, le 2026-09-05, et ce sera la dernière fois gratuitement.** Elle est
    passée de 31/32 à 40/41 pour loger les neuf filons. C'était sans coût
    *parce que la plage créatures n'avait aucune entrée peinte* ; dès qu'un
    modèle de créature existera, le même geste imposera de repasser tout un lot
    par `tools/repaint_models.gd`. Vérifier avec `inspect_model.gd` avant de
    toucher à une frontière, jamais après.

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
- **Un `Control` sous un `CanvasLayer` n'a pas de taille si on ne pose que ses
  ancres.** `set_anchors_preset(PRESET_FULL_RECT)` laisse les marges telles
  quelles, donc `size` reste nul : le dessin part d'une origine négative et sort
  par le coin supérieur gauche. C'est `set_anchors_and_offsets_preset` qu'il
  faut, plus un raccord sur `size_changed`. Aucun test ne peut le voir — un nœud
  invisible calcule juste ; c'est la capture en jeu qui l'a montré (2026-09-05,
  la carte du monde).
- **Ne pas mettre d'appel de liaison moteur sur le chemin chaud.**
  `OS.get_thread_caller_id()` dans `CWTileFeatureGrid.get_zone` coûtait ~15 µs
  par colonne avant d'être déplacé sur le chemin froid. Mesurer avant de
  supposer que c'est le verrou qui coûte.

## 6. Prochaine tâche — l'échelle et le grain des modèles

> **À FAIRE EN PREMIER, session du 2026-09-06.** *Les deux lots de modèles posés
> au sol sont mal dimensionnés. Ce n'est pas une question de goût : six captures
> du jeu d'origine, regardées le 2026-09-05 au soir, le montrent. **Les arbres**
> sont à la mauvaise échelle ET au mauvais grain (§6.1 à §6.4) ; **la flore** est
> à la bonne grille mais trop petite et trop dense (§6.5). Les deux se corrigent
> ensemble, et le remède n'est pas le même.*
>
> ### 6.1 Ce que les captures montrent
>
> Méthode : le personnage sert de règle (2,3 – 2,4 blocs, mesure de
> `assets/models/MODELS.md`, §1), comparé à des marches de terrain à la même
> profondeur. Les captures restent **hors du dépôt** (`.gitignore`) : on en tire
> des nombres, jamais des pixels.
>
> **1. Les arbres sont immenses, et c'est délibéré.** Les conifères occupent
> toute la hauteur du cadre, le personnage n'en fait qu'une fraction au pied. Ils
> lisent à **15 – 25 blocs de haut**, soit six à dix fois le personnage. Nos
> `sapin` font 8,3 blocs : **deux à trois fois trop courts**.
>
> **2. Les houppiers sont larges et aplatis.** Ce sont des dômes en parasol ou en
> chapeau de champignon, **plus larges que hauts**, de **10 à 18 blocs de large**.
> Nos houppiers font 4,8 blocs de large et sont aussi hauts que larges : **trois
> fois trop étroits, et de la mauvaise proportion**. C'est la canopée qui *est*
> l'objet ; le tronc n'en est que le support, souvent caché.
>
> **3. Le grain d'un arbre est celui du terrain, pas celui de la flore.** Sur les
> captures, les cubes de feuillage et les blocs de terrain lisent à la **même
> taille**, à un facteur deux près. Un arbre y est bâti des mêmes cubes que le
> monde. Nos arbres sont dessinés à 3/40 de bloc par voxel : **sept à treize fois
> trop fin**.
>
> Ce que les captures montrent aussi, et qui confirme le reste du lot : les
> touffes d'herbe et les fleurs, elles, sont bien sur la grille fine — des lames
> minces devant de gros blocs. **La flore est juste, les arbres ne le sont pas**,
> ce qui recoupe exactement la provenance des deux échelles (§6.2).
>
> ### 6.2 Pourquoi c'est cohérent avec la source
>
> **L'échelle 0,075 = 3/40 est relevée dans la voie du décor**
> (`docs/systems/02`, §8.3, à l'intérieur de la section du décor). Les arbres
> passent par la **voie des entités** (§5, §6), et **aucune échelle
> d'instanciation n'y a été relevée** — vérifié : la section 5 ne cite l'échelle
> que pour dire que les boîtes en blocs la recoupent. Le lot d'arbres reposait
> donc sur une extrapolation, et c'est la seule pièce du jalon 1.11 dans ce cas.
>
> **L'argument structurel, et c'est le plus fort.** §5.2 établit que le tronc
> d'un feuillu est **écrit dans le terrain**, en colonnes de blocs, et que le
> houppier est **instancié séparément**. Ces deux moitiés ne se rejoignent
> proprement que si la grille du houppier est celle du bloc, ou un diviseur
> propre. À 3/40, un houppier instancié ne tomberait jamais sur la colonne de
> blocs qui le porte. **Un voxel = un bloc explique l'architecture de la source ;
> 3/40 la rend impossible.**
>
> Réserve honnête : les boîtes de §5.2 ne tranchent pas. `thorn-tree` fait
> 3 × 3 × 12 blocs, ce qui se lirait bien comme les dimensions d'un modèle à un
> voxel par bloc — mais `cactus1` fait 1,5 × 1,5 × 4, et une dimension
> fractionnaire dit qu'il s'agit de boîtes **physiques**, pas de gabarits. Les
> captures restent la meilleure preuve.
>
> ### 6.3 Ce que je ferais
>
> **Redessiner le lot d'arbres à 1 voxel = 1 bloc**, la flore gardant 3/40. Une
> grille par voie de pose, ce qui est cohérent avec le fait que la source en a
> deux — et c'est aussi la grille des filons, pour la même raison qu'eux : ce qui
> touche le terrain se dessine à la maille du terrain.
>
> | | aujourd'hui | cible |
> |---|---|---|
> | `sapin`, hauteur | 8,3 blocs (111 voxels à 3/40) | **18 – 22 blocs** (18 – 22 voxels) |
> | houppier, largeur | 4,8 blocs (64 voxels) | **12 – 16 blocs** (12 – 16 voxels) |
> | houppier, proportion | aussi haut que large | **1,5 à 2 fois plus large que haut** |
> | `tronc_feuillu`, hauteur | 6,6 blocs | **10 – 14 blocs** |
>
> Un houppier deviendrait un modèle de ~14 × 14 × 8 voxels — quelques centaines
> de voxels au lieu de sept mille. C'est vingt fois moins de matière pour une
> silhouette **plus grande** à l'écran.
>
> ### 6.4 Ce que ça déplace, et ce qui est déjà prêt
>
> - **`VOXELS_PER_BLOCK` devient un champ par bibliothèque**, comme
>   `max_radius_blocks` l'est déjà (invariant n° 24). **La séparation des deux
>   bibliothèques, faite le 2026-09-05, paie ici** : la flore ne bouge pas.
> - **`CWTreeScatter` doit être resserré.** Des houppiers de 12 – 16 blocs de
>   large avec un espacement de 7 blocs s'interpénétreraient : espacement à
>   **12 – 18 blocs**, densité par cellule divisée d'autant, et la cellule de 64
>   redevient peut-être trop petite pour que l'espacement morde (elle doit rester
>   grande devant lui — voir l'en-tête de `CWTreeScatter`).
> - `max_radius_blocks` des arbres passerait de 3 à **6 – 8 blocs**, donc la
>   marge de `placements_in` et les boîtes de visibilité avec.
> - Les enveloppes en voxels de `tests/tree_test.gd` et la table de
>   `docs/prompt_generation_arbres.md` sont à réécrire **en blocs**, pas en
>   voxels : à un voxel par bloc, les deux unités se confondent, et c'est plus
>   clair ainsi.
> - **Les formes sont à repenser, pas à réduire.** `reduced(2)` donnerait des
>   moignons : les folioles de palme, les rameaux de conifère et les `pousses`
>   des houppiers sont écrits pour du détail d'un voxel. À la maille du bloc, un
>   houppier est **quelques dizaines de cubes bien placés**, pas une coquille de
>   métaballe échantillonnée. Le générateur en sort simplifié, pas compliqué.
> - **Le conifère devient des disques empilés** : sur les captures, ses étages
>   sont des plateaux plats et nets d'un bloc d'épaisseur, larges à la base, et
>   c'est cette superposition qui fait la silhouette — pas des rameaux.
>
> ### 6.5 La flore : même diagnostic, remède opposé
>
> Trois captures de plus, regardées dans la foulée, portent sur l'herbe et les
> fleurs. Elles disent que **la flore est trop petite et trop dense**, pas que sa
> grille est fausse — l'inverse exact des arbres, et c'est important : le
> rapport 3/40 est **mesuré pour le décor** (§8.3), donc il reste.
>
> Comparaison en hauteurs de personnage, l'unité la plus sûre parce qu'elle se
> lit sur la capture comme dans `inspect_model.gd` :
>
> | | chez nous | sur les captures |
> |---|---|---|
> | touffe d'herbe | **0,45 ×** | **~1,0 ×** — les brins montent à l'épaule |
> | plante haute (fougère, pousse) | absente | **~1,5 ×** |
> | caillou | **0,30 ×** | **~1,0 – 1,3 ×** — ce sont des blocs erratiques, pas des cailloux |
> | buisson | **1,05 ×** | **~0,65 ×** |
> | fleur de champ dispersée | 0,60 × | **~0,2 ×**, quelques cubes |
> | tournesol | 0,64 × | ~1,0 × |
>
> **La densité, ensuite.** Sur les captures, une touffe est faite de **quatre à
> six brins**, longs, lisses, franchement arqués et bien écartés. Les nôtres en
> ont onze à vingt-deux.
>
> > **Et c'est moi qui les ai densifiées le matin même, et c'était la mauvaise
> > correction.** En jeu, les touffes lisaient « clairsemées » — j'ai monté les
> > brins de 6 à 11, de 5+3 à 8+6, de 12+3 à 17+5. Elles lisaient clairsemées
> > **parce qu'elles font la moitié de la taille qu'elles devraient**, donc un
> > quart de la surface à l'écran, pas parce qu'il leur manquait des brins. J'ai
> > traité le symptôme à l'envers. **À défaire en même temps qu'on les
> > agrandit.**
>
> **La cause première est dans nos propres documents.**
> `assets/models/MODELS.md` §1 dit « touffe d'herbe 0,6 – 0,9 bloc (au genou) »
> et `docs/prompt_generation_flore.md` commande 10 – 14 voxels. Les captures
> disent **à l'épaule**, soit 27 – 30 voxels. Ce repère a été posé à l'œil au
> jalon 1.7, il est faux d'un facteur 2,5, et tout le lot en découle.
> L'enveloppe, elle, était juste : le plafond de 53 voxels (4 blocs) laissait
> largement la place — **on a dessiné tout le lot au bas de son enveloppe**.
>
> **Ce que je ferais, sans toucher au rapport 3/40 :**
>
> - **agrandir** : herbes 12 → 27 – 30 voxels, cailloux 8 → 30 – 40, ajouter une
>   plante haute à ~50 voxels ; **réduire** le buisson et les fleurs de champ ;
> - **désépaissir** : revenir à **cinq ou six brins** par touffe, longs et bien
>   écartés, au lieu de onze à vingt-deux serrés ;
> - **épaissir le brin lui-même** : 1 → **2 voxels de large**. À 27 voxels de
>   long, un brin d'un voxel est un cheveu ; sur les captures un brin montre ses
>   cubes. C'est ce qui donne le rendu « cubique » que l'original a et que nous
>   n'avons pas ;
> - corriger les deux repères ci-dessus **avant** de regénérer, sinon la
>   prochaine reprise redessinera au genou.
>
> **La leçon commune aux deux lots :** ce qu'on prend pour « trop de détail »
> est presque toujours « trop petit ». Un objet à la moitié de sa taille garde
> tous ses éléments dans le quart de la surface, donc il paraît chargé — et le
> réflexe d'en ajouter aggrave exactement ce qu'on voulait corriger.
>
> ### 6.6 Comment trancher
>
> Regarder, ne pas raisonner : générer le lot à deux échelles (1 et 1/2 bloc par
> voxel), et comparer en jeu par `-- --biome 3 --shot 32` (§2), avec le
> personnage de référence dans le cadre. C'est ce qui a déjà attrapé trois
> défauts que la suite headless ne voyait pas.

## 7. Ensuite — 1.11 (le tronc en matière) ou 2.6 (apparition)

> **Mise à jour du 2026-09-05, tard.** Le jalon 1.11 est **aux trois quarts
> fait** : les 14 modèles d'arbres, les 9 filons, la couche de dispersion, et
> les arbres sont **en jeu** — sept biomes regardés en capture. La suite passe à
> **297 vérifications, 0 échec**, dont un fichier neuf, `tests/tree_test.gd`,
> qui a remplacé le garde-fou provisoire qui vivait dans le script Python.
>
> **Ce qui reste de 1.11, et c'est la partie intéressante :**
>
> * **le tronc écrit dans le terrain.** Aujourd'hui il est *instancié*, comme
>   le reste : il ne se creuse pas et ne porte pas de collision. La source
>   l'écrit en colonnes de blocs (`World_fillVoxelColumnTyped`), et c'est le
>   premier objet du projet à traverser la matière et l'instance — `CWWorldEdits`
>   sait déjà écrire, `CWFloraRenderer` sait déjà instancier, il faut les faire
>   poser au même endroit et **rester d'accord après une édition**. C'est pour
>   cela que `CWTreeScatter._piece` met `fx = fz = 0.5` : le tronc est centré sur
>   sa colonne, comme le sera la colonne de blocs ;
> * **la pose des filons.** Les neuf modèles existent, le tirage de rareté est
>   porté (`CWPalette.roll_ore`), il manque *où* ils affleurent. Cela appartient
>   à la voie des entités, donc au jalon 2.6 ;
> * **la réduction en distance.** `CWVoxelModel.reduced(n)` n'a toujours aucun
>   usage. Un arbre est le premier modèle assez gros pour la justifier, et la
>   couche existe maintenant pour l'accrocher.
>
> **Deux choses apprises en produisant, qui coûteraient cher à redécouvrir :**
>
> * **l'ancre est le centre du gabarit**, pas le pied du tronc. Les futs sont
>   dessinés presque d'aplomb pour cette raison. Pour une **palme**, dont le
>   point d'attache est à une extrémité, l'écart est structurel : le montage d'un
>   palmier pose ses palmes au sommet du stipe sans décalage d'attache, ce qui se
>   voit d'un peu près. À corriger avec le tronc en matière ;
> * **un test headless ne montre pas une couche de rendu.** Trois défauts n'ont
>   été trouvés qu'en capture — houppiers grumeleux, touffes d'herbe trop
>   clairsemées, broussaille de neige orange sur sol cyan — et aucun n'aurait pu
>   l'être autrement. D'où `-- --biome N --shot S` sur la démo (§2).


**Où on en est, au 2026-09-05 au soir.** Les **dix systèmes du terrain sont
faits** (1.1 à 1.10). 1.7 s'est fermé avec la table type de décor → modèle, qui
n'était dans aucune fonction : elle est dans le tableau des slots de chargement
de `GameController`. Détail en `docs/systems/02`, §8.5 et §8.6 ; portage en
`src/worldgen/cw_decor_rules.gd`.

**Un onzième système a été ouvert dans la foulée** : 1.11, les arbres. La même
lecture des slots a réglé la question laissée ouverte depuis le 2026-09-05 —
`tree-leaves` porte son propre code d'entité (143), donc le conifère et l'arbre
à épines sont des modèles entiers tandis que le feuillu et le palmier sont des
assemblages dont le tronc n'est pas un modèle. Il n'y avait aucune étape prévue
pour les arbres ; il y en a une maintenant.

**Deux portes sont ouvertes, et elles ne demandent pas le même travail.**

- **Jalon 1.11 — arbres et grande végétation** : le lot d'assets ~~est d'abord
  à produire~~ **est produit** (14 modèles, le 2026-09-05, encadré ci-dessus).
  Ce qui reste est du code : une **seconde couche de dispersion** — cellule de
  64 blocs plutôt que 16, densité en arbres par cellule, espacement minimum
  entre deux troncs, sa propre marge —, puis l'**assemblage** tronc +
  houppiers, premier objet du projet à traverser la matière et l'instance.
  `docs/ROADMAP.md`, §1.11.
- **Jalon 2.6 — les points d'apparition** : c'est du **code pur**, et la source
  est déjà lue.

Le reste de cette section décrit 2.6, qui était la relève désignée par la
feuille de route :

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
  pose → apparence → comportement.

Ce qu'il faudra décider avant d'écrire : un point d'apparition **persiste-t-il**
comme la découverte de la carte, ou se recalcule-t-il à la volée comme la flore ?
L'original le recalcule par tuile et lui donne un niveau **dynamique** — le
niveau maximum des joueurs présents, §7 —, ce qui plaide pour la seconde voie et
évite une seconde base sur le disque.

### Ce qui reste ouvert dans le jalon 1, sans bloquer

- **Le nénuphar n'est pas porté** : le lot des 39 modèles n'en a pas, et
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

## 8. Assets voxels

### 8.1 L'échelle — fixée le 2026-09-04, alignée sur l'original le 2026-09-05

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

- ~~**Jalon 1.11, arbres et grande végétation (14)**~~ **livré le 2026-09-05** :
  houppiers, troncs, sapins, palmes, arbre mort, sous `assets/models/arbres/`.
  Même chaîne que la flore. Deux choses le distinguaient du lot précédent, et
  elles se retrouvent dans le code : un arbre sort de l'enveloppe de la flore
  (jusqu'à 160 voxels, la boîte de `thorn-tree` étant de 3 × 3 × 12 blocs),
  d'où un plafond par classe passé à `flore_vox.ecris` ; et un **houppier n'a
  pas de tronc** — il se pose au sommet d'un tronc, ce qui fait de lui le
  premier objet du projet à traverser les deux mondes.
- **Jalon 1.11, les neuf filons** : **bloqués sur une décision de palette**, pas
  sur le dessin. Un filon s'estampe dans le terrain, donc chacun de ses voxels
  est un *type de bloc*, et la réserve terrain 14 – 31 est pleine depuis le
  2026-09-05. Les trois issues sont posées à la fin de
  `docs/prompt_generation_arbres.md`. Trancher avant de dessiner.
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
- **La gigue d'échelle de 1× à 2× est appliquée partout ici, nulle part dans la
  source.** L'original ne la tire que sur le décor immergé ; ailleurs il écrit
  une échelle fixe ou une petite plage par type. Elle est gardée parce que notre
  lot a moins de variantes par rôle et que le champ se lirait comme un motif
  répété sans elle — mais c'est une décision de ce projet, et elle se multiplie
  désormais au rapport de taille du rôle (`CWDecorRules.SCALE_RATIO`), ce qui
  porte une instance de caillou jusqu'à 2,9× son modèle.
- **Les feuilles de `CWDecorRules.FAMILIES` sont réattribuées, pas lues.** Trois
  branches viennent mot pour mot de la source — sol tempéré, sol chaud, fond
  marin ; les six autres lignes rangent nos surfaces dans la forme de la règle.
  Les changer coûte une ligne, et rien dans la source ne les contraint : c'est
  le bon endroit où ajuster ce qui se voit mal en jeu.
