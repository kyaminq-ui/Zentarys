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

**Il n'y a pas de dépôt git.** C'est le risque le plus élevé du projet en
l'état : ~2 300 lignes de code et trois documents sans historique. À faire en
premier.

## 2. Commandes

```
# Suite de validation (44 vérifications, ~40 s)
godot.windows.editor.double.x86_64.exe --headless --path . -s tests/worldgen_test.gd

# Réimport après ajout d'un class_name (sinon l'éditeur ne le voit pas)
godot.windows.editor.double.x86_64.exe --headless --path . --import
```

Aperçus PNG écrits par la suite de tests dans
`user://worldgen_preview/` (`height.png`, `climate.png`, `channels.png`) →
`C:\Users\Admin\AppData\Roaming\Godot\app_userdata\Zentarys\worldgen_preview\`.

Démo : `res://scenes/terrain_demo.tscn`. Clic pour capturer la souris,
ZQSD/WASD, Maj = rapide, Espace/Ctrl = monter/descendre, **F1** détails,
**Page haut/bas** distance de vue, **1-9** téléportation vers un biome,
**Échap** rend la souris puis quitte.

## 3. État

Jalon 1 (le monde) : 1.1 à 1.5 faits, le reste à faire. Détail et sources
analysées dans `docs/ROADMAP.md`. Analyse du système de terrain dans
`docs/systems/01_generation_terrain.md`.

```
src/worldgen/
  cw_value_noise.gd       bruit de valeur (Hugo Elias), arithmétique 32 bits émulée
  cw_rand.gd              LCG de la CRT MSVC
  cw_region_site.gd       structure d'un site de zone
  cw_region_site_grid.gd  grille 1024² paresseuse, caches sous mutex
  cw_terrain_field.gd     climat + altitude + chenaux  ← le cœur
  cw_palette.gd           palette et règles de surface (couleurs originales)
  cw_voxel_generator.gd   VoxelGeneratorScript + cache de colonnes
src/demo/terrain_demo.gd  scène de démonstration (arbre voxel construit en code)
tests/worldgen_test.gd    44 vérifications, headless
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
7. **Un test épars ne voit pas un artefact d'une colonne de large.** D'où le
   balayage dense de 3 000 colonnes dans `_test_terrain_field`. Tout nouveau
   terme du champ doit passer sous ce balayage.

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
- **Coût actuel : ~61 µs par colonne, ~17 ms par bloc 16³ à froid.** C'est le
  plafond de tout. Stabilisation mesurée : 27 s à 384 blocs de vue, 120 s à 768.

## 6. Prochaine tâche — jalon 1.6, éléments de tuile

Chaque zone porte une grille 8 × 8 d'éléments de `0x68` octets qui déforment
localement le terrain. Points d'entrée dans le dépôt d'analyse :

| fonction | adresse | rôle |
|---|---|---|
| `World_generateRegionFeatures` | `@0050e080` | générateur 8×8 par zone (`server/world/World.cpp`) |
| `World_objectFalloffWeight` | `@0052c820` | poids d'influence commun |
| `World_featureCountRange` | `@00522290` | nombre d'éléments par zone |
| `World_featureTier` | `@004d7870` | palier de difficulté depuis le centre de carte |

Effets à porter, déjà commentés à leur emplacement exact dans
`cw_terrain_field.gd::_height_from` :

- type 1 — aplanissement (bourgs, routes) ; débloque aussi `World_roadField` et
  la porte de détail complète, aujourd'hui inertes ;
- type 4 — cratère à `H − 50` ;
- types 6 et 7 — caldeira à bord relevé ;
- type 13 — piton de +150.

Attention : cette tranche change ce que produit le générateur, donc invalide
tout cache d'altitude persistant. Ne pas construire de cache disque avant.

## 7. Décisions ouvertes

**Authoring des assets voxels — recommandation : MagicaVoxel, pas d'éditeur
maison.** `VoxelVoxLoader.load_from_file(chemin, VoxelBuffer, VoxelColorPalette,
canal)` est intégré au build : un `.vox` se charge en un appel, avec sa palette,
directement dans le modèle de rendu déjà utilisé. Écrire un éditeur qui vaille
20 % de MagicaVoxel représente des semaines pour zéro gameplay.

Conséquence à trancher **avant** de produire des assets en série : une palette
de projet unique, partagée par le terrain et les modèles, exportée en PNG 256×1
pour MagicaVoxel. Sans ça, chaque `.vox` arrive avec sa propre palette et
`COLOR_MESHER_PALETTE` ne peut plus servir de palette commune. `CWPalette`
n'occupe que les index 0-13 ; il reste 242 entrées pour les assets.

Outillage Godot à écrire plus tard, et seulement là où MagicaVoxel ne peut pas
aider : placement et prévisualisation **en contexte** (une structure posée sur
le terrain réellement généré), au jalon 4. Pas un éditeur généraliste.

Autre décision reportée : le relief lointain paraît bleuté (ambiante du ciel sur
les faces détournées du soleil). Réglage d'ambiance, pas un défaut de génération.
