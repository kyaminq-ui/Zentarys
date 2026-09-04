# Zentarys — feuille de route

Réimplémentation « clean room » des systèmes de jeu de l'alpha Cube World sur
Godot 4.7.2 + Voxel Tools 1.7.

**Cadre.** On porte des *algorithmes*, jamais du code ni des données. Aucun
asset du jeu d'origine (`.plx`, `data*.db`, textures, sons, palette) n'entre
dans ce dépôt. Toute expression artistique reconnaissable — palettes, silhouettes
de créatures, noms propres, textes — est remplacée par une création originale et
signalée comme telle dans la note du système concerné.

**Source d'analyse.** `qad3n/CubeWorld-Reversal` : reconstruction par classe
(RTTI + graphe d'appels) du binaire alpha 2013. 1 370 fonctions de jeu côté
client, 288 côté serveur ; le reste est de la bibliothèque tierce (SQLite, CRT,
STL, FreeType) et n'a pas à être porté.

**Méthode, par système.** Analyse du pseudo-code → note dans
`docs/systems/NN_*.md` → implémentation GDScript typée → test headless qui
verrouille les invariants numériques → validation visuelle en jeu.

Statuts : ✅ fait · 🔶 partiel · ⬜ à faire · ⛔ hors périmètre

---

## Jalon 1 — Le monde

Le terrain conditionne tout le reste : physique, rendu, placement des créatures
et des structures.

| # | Système | Source analysée | Statut | Note |
|---|---|---|---|---|
| 1.1 | Bruit de valeur | `valueNoise2D` @004d5d30 | ✅ | `docs/systems/01` |
| 1.2 | LCG de la CRT MSVC | `World_generateRegionSite` | ✅ | idem |
| 1.3 | Sites de région, climat | `World_{temperature,humidity}Blend` | ✅ | idem |
| 1.4 | Champ d'altitude, chenaux | `World_baseHeightField` @004f9b70 | ✅ | idem |
| 1.5 | Générateur voxel + rendu cubes | — (portage Godot) | ✅ | idem |
| 1.6 | Éléments de tuile | `World_generateRegionFeatures` @0050e080 | ✅ | `docs/systems/01`, §2.7 |
| 1.7 | **Contenu de biome, dispersion** | `WorldInfo_generateBiomeContent` @005e4850 | ⬜ | **prochaine tranche** |
| 1.8 | Colonnes persistantes, édition | `Chunk_getColumnAt` @00406100 + `VoxelTool` | ⬜ | |
| 1.9 | Éclairage voxel | `VoxelChunk_propagateSunlight` | ⬜ | |
| 1.10 | Carte du monde | `WorldMap.cpp`, `NameGen_generateRegionName` | ⬜ | |

### 1.6 — Éléments de tuile (fait)

Grille 8 × 8 d'éléments par zone, un par tuile de 2048 unités. Cinq types
déforment l'altitude — bourg (aplanissement + `World_roadField`), cratère à
`H−50`, deux caldeiras à bord relevé, piton de +150 — plus un relèvement qui
fait émerger un îlot sous tout élément posé sur un site océanique. Détail et
constantes dans `docs/systems/01`, §2.7.

Trois points relevés à l'analyse, qui n'étaient pas dans le plan :

- **Le type 1 n'est pas « les routes ».** Il y a un et un seul élément de type 1
  par zone, sur la tuile de son site : `World_roadField` est l'aplanissement du
  bourg, pas un réseau de voies. Les arêtes du graphe de sites ne sont donc pas
  des routes, et `site_edge_radius` reste à 0.
- **Le type 13 n'est jamais produit** par `World_generateRegionFeatures` : son
  `switch(rand()%8)` ne rend que 2, 3, 4/15, 5, 6/15, 7/15, 11 et 12. L'effet
  est porté, sa source reste à trouver.
- **Les types sans effet sur l'altitude sont quand même placés** (2, 3, 5, 10,
  11, 12, 14, 15). Le flux aléatoire est une seule séquence : n'en porter que la
  moitié changerait tous les types et toutes les positions. Ce sont les ancres
  du jalon 1.7.

`World_featureTier` @004d7870 est porté et gradue la difficulté depuis le centre
de la carte (zone 512, 512).

### 1.7 — Contenu de biome (prochaine tranche)

`WorldInfo_generateBiomeContent` (@005e4850) et `WorldInfo_scatterObjectsInArea`
(@005f56c0). C'est la première tranche qui demande des assets : les ancres
existent, il faut désormais poser quelque chose dessus. Voir « Assets à
produire » ci-dessous.

### Assets à produire

Le jalon 1.6 n'a demandé aucun asset. Le jalon 1.7 est le premier qui en demande.

Le binaire d'origine charge **154 modèles voxels nommés** ; leurs noms donnent la
liste sûre des *rôles* que le monde doit remplir. Aucun n'est repris — ce sont
des créations originales — mais la liste des besoins, elle, ne se devine plus.
Détail et ordre de production dans `nextsteps.md`, §7.1. En résumé :

- **~35 modèles pour le jalon 1.7** : herbes, fleurs, cactus, sous-bois,
  aquatique, pierres, cultures ;
- **~50 pour le jalon 4** : mobilier, artisanat, décor extérieur et de donjon ;
- le reste (objets d'inventaire, créatures, interface) vient plus tard.

**Ni les arbres ni les maisons ne sont des assets.** Aucun modèle d'arbre parmi
les 154 : ils sont construits par le code, dans `WorldInfo_generateBiomeContent`.
Et `cube::House::ctor_0(3, 3, 4)` montre qu'une maison est une grille de
3 × 3 × 4 cellules remplie procéduralement — ce sont les meubles qui sont des
modèles, pas le bâtiment. Deux algorithmes à porter, pas deux lots à dessiner.

Gabarits mesurés en sortie du générateur d'éléments, utiles pour situer les
échelles — le rayon est un rayon d'*influence*, la distance sur laquelle
l'élément revendique le terrain, pas l'encombrement du modèle :

| type | par zone | rayon | position | variantes |
|---|---|---|---|---|
| 14 | ~16 | 150 u | calée sur la grille de 256 | 4, plus 2 réservées aux climats très humides |
| 11 | ~2 | 128 u | calée sur la grille de 256 | — |
| 12 | ~2 | 128 u | calée sur la grille de 256 | — |
| 10 | ≤ 5 | 512–767 u | libre dans la tuile | — |
| 2 | ~2 | 512–767 u | libre dans la tuile | — |
| 3 | ~2 | 512–767 u | libre dans la tuile | 3 |
| 5 | ~2 | 256–511 u | libre dans la tuile | 3, choisies par le climat du site |
| 15 | variable | 512–767 u | libre dans la tuile | remplace 4, 6 et 7 au-dessus d'un site océanique |

L'identité de chaque type reste à établir : elle vient de
`WorldInfo_generateBiomeContent` (@005e4850), pas encore analysée.

Authoring : MagicaVoxel, palette de projet dans
`assets/palette/zentarys_palette.png`, plages réservées documentées dans
`assets/palette/PALETTE.md`. À l'import, `vox(x, y, z) -> godot(y, z, x)`.

---

## Jalon 2 — Créatures et combat

| # | Système | Source | Taille | Statut |
|---|---|---|---|---|
| 2.1 | Modèle de créature, statistiques | `entity/Creature.cpp` | ~1 200 l | ⬜ |
| 2.2 | Arbre de comportement | `ai/SequentialBehavior` + nœuds | ~180 l | ⬜ |
| 2.3 | Déplacement, chemins | `RandomWalk`, `WalkPath`, `SpawnLocation` | ~700 l | ⬜ |
| 2.4 | Combat | `ai/CombatBehavior.cpp` | 2 100 l client / 4 000 l serveur | ⬜ |
| 2.5 | Compagnon, interactions | `Companion`, `RandomInteraction`, `LookAtPlayer` | ~1 000 l | ⬜ |
| 2.6 | Apparition | `world/Spawn.cpp` | | ⬜ |

Dépend de 1.6 (les points d'apparition sont accrochés aux éléments de tuile) et
de 1.8 (requêtes de collision sur les colonnes).

Le comportement de combat est la plus grosse fonction de jeu du dépôt ; la
version serveur fait le double de la version client, ce qui laisse penser que
c'est elle qui fait autorité. À porter depuis le serveur.

⛔ **Hors périmètre :** apparence des créatures. Les silhouettes, proportions et
palettes de Cube World sont de l'expression artistique. Le système porté est le
gréement et l'animation procédurale, pas les modèles.

---

## Jalon 3 — Joueur et boucle de jeu

| # | Système | Source | Statut |
|---|---|---|---|
| 3.1 | Contrôleur, caméra, physique | `control/GameController.cpp` (115 000 l) | ⬜ |
| 3.2 | Inventaire, objets | `ui/InventoryWidget`, `format_object_singular_name` | ⬜ |
| 3.3 | Compétences, progression | `ui/SkillsWidget` | ⬜ |
| 3.4 | Vol à voile, escalade, monture | `GameController` | ⬜ |

`GameController.cpp` est un agrégat de 115 000 lignes : à découper par
fonctionnalité et à porter par morceaux, jamais d'un bloc.

---

## Jalon 4 — Structures et contenu

| # | Système | Source | Statut |
|---|---|---|---|
| 4.1 | Placement de structures | `WorldInfo_placeStructure` @005f0ce0 | ⬜ |
| 4.2 | Donjons | `world/Dungeon.cpp` | ⬜ |
| 4.3 | Maisons, villages | `world/House.cpp`, `Field.cpp` | ⬜ |
| 4.4 | Quêtes, dialogues | `entity/QuestText`, `Speech.cpp` | ⬜ |

⛔ **Hors périmètre :** textes de dialogue et de quête, noms de lieux et de
personnages. Ce sont des œuvres écrites. On porte le *générateur* (grammaire,
tables de composition) et on fournit nos propres tables.

---

## Jalon 5 — Réseau

| # | Système | Source | Taille | Statut |
|---|---|---|---|---|
| 5.1 | Protocole, paquets | `net/Connection.cpp` | 604 l | ⬜ |
| 5.2 | Boucle serveur | `net/Server.cpp` | 275 l | ⬜ |
| 5.3 | Sérialisation d'entités | `EntityState_serializeToBuffer` | | ⬜ |

Le protocole est petit et bien délimité. Intérêt d'interopérabilité réel, mais
sans valeur tant que les jalons 2 et 3 ne sont pas là.

---

## Dette technique et outillage

| Sujet | Statut | Détail |
|---|---|---|
| Suite de tests headless | ✅ | 80 vérifications, `tests/worldgen_test.gd` |
| Aperçu rapproché des éléments | ✅ | `tools/preview_features.gd`, avec et sans la couche |
| Aperçus PNG (altitude, climat, chenaux) | ✅ | `user://worldgen_preview/` |
| Arrêt immédiat du streaming | ✅ | `CWVoxelGenerator.request_shutdown()`, 23 ms → 1 µs par bloc en file |
| Cache de colonnes | ✅ | 17 ms → 5 µs par bloc réutilisé |
| Débit de chargement | ✅ | vue 384 : > 3 min → **27 s** ; vue 768 : **120 s** |
| Portage du champ en GDExtension C++ | ⬜ | ~80 µs/colonne en GDScript ; **verrou de la vue lointaine**, voir ci-dessous |
| `VoxelStream` (sauvegarde du monde modifié) | ⬜ | dépend de 1.8 |
| LOD natif (`VoxelLodTerrain`) | ⛔ | testé, inutilisable avec un rendu en cubes — voir ci-dessous |
| Étage de terrain lointain (façon Distant Horizons) | ⬜ | bloqué par la vitesse d'échantillonnage |
| Intégration continue sur la suite headless | ⬜ | |

### Débit de chargement — ce qui a été mesuré

Le poste dominant est la **génération**, jamais le maillage : à 384 blocs de vue
le compteur montrait `gen 33880 / maillage 2`, c'est-à-dire un mailleur à
l'arrêt qui attend. Inutile donc de toucher au budget du fil principal ou à la
taille des blocs de maillage tant que ce déséquilibre tient.

Quatre corrections, dans l'ordre de leur effet :

1. **Doublons entre fils.** Les ~11 blocs verticaux d'une même colonne (x, z)
   partent ensemble dans la file et sont pris par des fils différents. Sans
   marqueur « en cours », ils manquaient tous le cache au même instant et
   recalculaient tous la même carte de hauteurs : le cache ne servait à rien
   pendant la phase de chargement, la seule qui compte. Le second arrivé attend
   désormais le premier.
2. **Plafond du cache trop bas.** 2 048 entrées pour une empreinte de 2 304 à
   384 blocs de vue : le cache s'auto-évinçait en boucle. Porté à 16 384, ce qui
   couvre une vue de 1 024 pour ~21 Mo.
3. **Distance aux arêtes calculée pour rien** depuis que les termes qui
   l'utilisent sont désactivés : 80 → 61 µs par colonne.
4. **Pool de fils** porté de 8 à `cœurs − 2` (14 ici) ; Voxel Tools n'en prend
   que la moitié par défaut, ce qui est prudent pour un générateur natif mais
   bride un générateur GDScript.

| distance de vue | temps de stabilisation | pic de tâches |
|---|---|---|
| 384 blocs | **27 s** | 35 000 |
| 768 blocs | **120 s** | 198 000 |

Le débit ne s'écroule pas quand l'empreinte grandit : 1 290 tâches/s à 384,
1 650 à 768. C'est le **nombre** de blocs qui explose — il croît comme le
produit des trois axes — pas leur coût unitaire. Doubler la distance de vue
multiplie donc l'attente par ~4,5, pas davantage.

Ces mesures s'affichent seules : l'ATH montre `gen N / maillage M` pendant le
chargement, et le temps de stabilisation part dans le journal au front
descendant. Page haut / Page bas règlent la distance en jeu.

**Limite pratique.** 768 blocs sont exploitables pour une session de test
(2 min d'attente initiale, puis fluide) ; au-delà, l'attente croît vite. C'est le
portage en GDExtension qui débloque la suite, pas l'optimisation de
l'ordonnancement : le pool est déjà saturé et le mailleur déjà à l'arrêt faute
de matière.

### Vue lointaine — état des lieux

Cube World se regarde de loin : les bandes de biomes et les massifs sont
lisibles à des kilomètres. Une vue de quelques centaines de blocs ne reproduit
pas ce comportement, donc la question est légitime dès maintenant.

**Le LOD natif de Voxel Tools ne répond pas au besoin.** Mesuré le 2026-09-03 :
`VoxelLodTerrain` accepte `VoxelMesherCubes` sans se plaindre et construit bien
la géométrie lointaine, mais **des blocs d'eau apparaissent en pleine plaine à
partir du LOD 1** — de larges dalles bleues horizontales, à des altitudes où le
terrain est de l'herbe. Le même point de vue en `VoxelTerrain` n'en montre
aucune. La cause exacte n'est pas établie : le canal utilisé est un *index* de
palette, une valeur qui ne survit à aucune réduction de résolution numérique,
mais il n'est pas démontré que ce soit bien là que la réduction se produit.
Ce qui est établi, c'est que le défaut est propre au mode LOD et qu'il rend le
rendu inutilisable tel quel.

Le basculement reste exposé (`TerrainDemo.use_lod`) pour revérifier après un
changement de version ou de mesher. À investiguer avant toute décision : où la
réduction de LOD a lieu (générateur appelé par niveau, ou sous-échantillonnage
du LOD 0), et si un canal séparé ou un mesher interpolant en espace couleur
règle le problème.

*Non lié :* le relief lointain paraît bleuté dans les deux modes. C'est
l'éclairage ambiant du ciel sur des faces détournées du soleil, pas un défaut de
LOD ; sujet de réglage d'ambiance, à traiter séparément.

**Ce qu'il faut retenir de Distant Horizons.** Son idée centrale n'est pas son
moteur de rendu, c'est son *modèle de données* : ne pas stocker des voxels au
loin, mais un profil de colonne (hauteur, couleur de surface, runs). Ce modèle
est déjà celui du générateur ici — `CWTerrainField.sample_column` rend
(altitude, température, humidité) et `ColumnPatch` est exactement une tuile de
profils. **Aucune dette d'architecture n'est en train de se créer** : l'étage
lointain se branchera sur ces primitives sans les modifier.

**Le vrai verrou est ailleurs.** Un anneau lointain de 2 km de rayon
échantillonné tous les 32 blocs représente ~16 000 colonnes, soit **~1,3 s** de
calcul au coût actuel ; le même anneau à 4 km tous les 16 blocs demande ~21 s.
Ce n'est pas la structure qui bloque, c'est les 80 µs par colonne. L'ordre des
travaux est donc :

1. porter `CWValueNoise` + `CWTerrainField` en GDExtension C++ (le champ est
   écrit pour être transposable ligne à ligne) ;
2. seulement ensuite, un maillage de terrain lointain construit à partir de
   `sample_column` seul — pas de voxels, une grille de hauteurs par grande
   tuile, la palette pour la couleur, du brouillard à la jonction ;
3. cache disque de cet étage lointain, à mutualiser avec le `VoxelStream`.

Construire l'étage 2 avant l'étape 1 reviendrait à bâtir une pyramide de LOD
au-dessus d'un échantillonneur trop lent : on multiplierait le problème au lieu
de le résoudre.

---

## Journal

| Date | Fait |
|---|---|
| 2026-09-04 | Jalon 1.6. Grille d'elements de tuile, cinq effets d'altitude, relevement des ilots oceaniques, champ de routes. Recursion generateur/champ cassee comme dans l'original, et rendue sure sur plusieurs fils. 30 verifications de plus. Cout : +0 us/colonne hors influence sur le chemin de streaming, +13 us dedans. |
| 2026-09-03 | Debit de chargement : doublons entre fils, plafond de cache, distance aux aretes inutile, pool de fils. Vue 384 stabilisee en 27 s au lieu de > 3 min. Teleportation par biome et reglage de la vue au clavier. |
| 2026-09-03 | Corrige : tranchee d'une colonne le long des aretes du graphe de sites (defaut d'unites, signale par l'utilisateur). Saut max entre colonnes voisines 2,35 -> 0,37 bloc. Test de non-regression par balayage dense ajoute. |
| 2026-09-03 | Vue lointaine : LOD natif teste et ecarte (dalles d'eau en pleine plaine des le LOD 1). Bascule `use_lod` conservee. |
| 2026-09-03 | Jalon 1.1–1.5. Analyse du pipeline de terrain, portage complet du champ (bruit, LCG, sites, climat, altitude, chenaux), générateur voxel + rendu `VoxelMesherCubes`, scène de démonstration, 43 tests. Corrigé : `world_origin` non appliqué dans le générateur ; absence de cache de colonnes. Ajouté : ATH compact, arrêt immédiat. |
