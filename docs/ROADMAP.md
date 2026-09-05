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
| 1.7 | **Contenu de biome, dispersion** | `creature_generateAppearance` + @005e4850 + @005d8750 | 🔶 | mécanique faite, 28 modèles livrés, table des entités lue ; `docs/systems/02` |
| 1.8 | Colonnes persistantes, édition | `Chunk_getColumnAt` @00406100 + `VoxelTool` | ✅ | `docs/systems/03` |
| 1.9 | Éclairage voxel | `VoxelChunk_propagateSunlight` @0059a0e0 | ✅ | porté, rendu passé en `COLOR_RAW` ; `docs/systems/04` |
| 1.10 | Carte du monde | `WorldMap.cpp`, `loadLandscapeTile` @006024d0, `NameGen_generateRegionName` | ✅ | pièces de Voronoï, découverte, noms ; `docs/systems/05` |

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
- **Les types 13 et 9 ne sont jamais produits** par
  `World_generateRegionFeatures` : son `switch(rand()%8)` ne rend que 2, 3,
  4/15, 5, 6/15, 7/15, 11 et 12. L'effet du 13 (piton de +150) est porté ; les
  deux types sont pourtant traités par `generateBiomeContent`, donc une passe de
  placement reste à trouver. Le 9 y construit un `cube::Spawn`.
- **Les types sans effet sur l'altitude sont quand même placés** (2, 3, 5, 10,
  11, 12, 14, 15). Le flux aléatoire est une seule séquence : n'en porter que la
  moitié changerait tous les types et toutes les positions. Ce sont les ancres
  du jalon 1.7.

`World_featureTier` @004d7870 est porté et gradue la difficulté depuis le centre
de la carte (zone 512, 512).

### 1.7 — Contenu de biome (en cours)

**Fait.** La mécanique de dispersion et le rendu sont portés, testés et mesurés :
`CWVoxelModel` (un `.vox` en liste creuse, quatre quarts de tour précalculés,
ancre au centre de l'empreinte et à la base, maillage à l'échelle fine),
`CWModelLibrary` (chargement partagé, table modèle/biome, densités), `CWScatter`
(cellules de 16 blocs, une graine par cellule, position sous le bloc, cache sous
mutex) et `CWFloraRenderer` (un `MultiMesh` par modèle et par cellule, cellules
construites par lots sur un fil du pool, détruites au-delà de la distance de vue
de la flore). 33 vérifications dans `tests/flora_test.gd`. Coût : **1,1 ms par
cellule** de 256 colonnes en prairie, hors du fil principal — et **plus rien** sur
le chemin de génération du terrain.

**Les 28 modèles du lot de flore sont livrés et intégrés** (2026-09-05), en 39
fichiers rangés par biome : plusieurs rôles ont reçu un modèle par biome plutôt
qu'un fichier partagé, et `CWModelLibrary.FLORA` porte donc des chemins. 5 650
plantes se posent sur 576 cellules d'essai, toutes dans leur biome et sur leur
sol. Trois réparations ont été nécessaires avant que le lot arrive en jeu — la
palette des fichiers, deux plages de palette inutilisables, et les noms ; le
détail est dans `nextsteps.md`, §6.

> **Le piège de la palette, à ne pas redécouvrir.** Le rendu lit un *index*,
> jamais une couleur. Les 39 fichiers sont arrivés avec les bonnes teintes aux
> mauvais index, parce que la planche de référence avait été glissée sur le
> nuancier de MagicaVoxel, qui la rééchantillonne. Rien ne le signale : ni le
> chargement, ni les tests d'alors, seulement l'écran. Le geste correct est
> d'**ouvrir `assets/palette/zentarys_palette.vox`** ; `tools/repaint_models.gd`
> répare un lot déjà peint.

**L'échelle des assets est fixée** — c'était le point bloquant, elle n'est
déductible d'aucune décompilation.

> **Deux grilles.** Le terrain a un pas d'un bloc, les modèles un pas treize fois
> plus fin : **1 bloc = 40/3 voxels de modèle**, soit **3 blocs = 40 voxels** ;
> **personnage de référence = 32 voxels = 2,4 blocs**, touffe d'herbe à 0,9 bloc.
> Le rapport était de 16 jusqu'au 2026-09-05 ; il est passé à la valeur exacte de
> l'original, `0,075 = 3/40`. C'est ce rapport qui sépare
> ce rendu de celui de Minecraft, et il est mesuré au pixel sur une capture du
> jeu d'origine — le brin d'herbe et la pupille du personnage y font la même
> largeur, donc la flore et les personnages sont sur la même grille fine.

Conséquence d'architecture, prise le 2026-09-04 : **la flore n'est plus estampée
dans les données voxels du monde**, elle y serait treize fois trop grosse. Elle
est maillée à part — même mailleur, même palette, même matériau que le terrain,
ce qui est la condition pour que les deux grilles lisent comme un seul monde —
puis instanciée. Ce qu'on perd : la flore ne se creuse pas, ne porte pas de
collision, ne participera pas à l'éclairage voxel du jalon 1.9. Ce qu'on gagne :
elle quitte le chemin critique de génération, qui est le poste dominant du
chargement.

Méthode, mesures et gabarits dans `assets/models/MODELS.md`. À revoir au jalon
3.1, quand la physique du joueur donnera la taille réelle du personnage : c'est
alors le nombre de blocs qui bougera, pas le rapport de 16, qui est un contrat
d'authoring.

**Reste.** `WorldInfo_generateBiomeContent` (@005e4850, 4 200 lignes) a reçu une
première passe d'analyse le 2026-09-05 : **`docs/systems/02`**. Elle n'est pas ce
que son nom annonce — c'est le constructeur d'une cellule de 256 × 256 colonnes,
et **elle ne disperse pas de flore**. Ce qui en est sorti : le champ de densité
de végétation à quatre octaves (constantes exactes), l'identité de quatre types
d'éléments de tuile (6 = champ de rochers, 11 = massif isolé, 12 = plan d'eau,
3 = parcelle bâtie), les constantes de pose des points d'apparition pour le
jalon 2.6, et une corroboration indépendante du portage du jalon 1.6 (stride
`0x68`, base `+0x14018`, ordre `tz + tx·8`).

**La table modèle/biome est trouvée** (2026-09-05, seconde passe). Elle n'était
dans aucune des deux fonctions au nom prometteur : `generateVegetationCluster`
(@005d8750) est le *résolveur de contenu d'une tuile*, pas un disperseur. La
table est le `switch` d'apparence de `creature_generateAppearance`
(game_misc.cpp:3197), croisé avec les slots de chargement de `GameController`.

> **Flore, filons et créatures sont un seul espace de types d'entités.** Codes
> 120–130 = plantes, 131–139 = filons, 145–155 = poissons, en dessous les
> créatures. Une touffe d'herbe et un ours sont la même sorte d'objet : une
> entité portant un code, jamais de la matière écrite dans le terrain. **La
> décision du 2026-09-04 de sortir la flore des données voxels est donc confirmée
> par la source** — pour une raison qui n'avait pas été anticipée.

Les boîtes englobantes du `switch` sont en blocs de terrain et **recoupent
l'échelle fixée ici** : `thorn-tree` 12 blocs, `cactus1` 4 blocs, buisson 2 blocs
— soit le personnage de référence. La sélection se fait sur le **type de bloc de
surface**, pondérée par température et humidité, jamais sur un identifiant de
biome : c'est exactement la forme de `CWPalette.surface_index`. Tables complètes,
rareté des filons comprise, en `docs/systems/02`, §5.

**Ce qui bloque encore le portage :** la numérotation des blocs de l'original
n'est pas celle de `CWPalette`, et la correspondance reste à établir — recopier
la table telle quelle mettrait des cactus dans les marais.

**La seconde voie de pose est identifiée** (`docs/systems/02`, §8). Il y a bien
deux voies : les plantes à silhouette sont des **entités** (§5), la flore basse
est du **décor instancié** sans entité, produit dans la même passe que le
terrain, en fin de boucle de colonne, et poussé par
`ChunkBuffer_loadAndNotify` (@005c03f0). L'enregistrement est reconstruit :
type à +0, échelle à +32, lacet à +36, drapeaux à +56.

> **Le rapport d'échelle est confirmé par une constante du binaire.** Les
> échelles de décor valent 0,075 / 0,09 / 0,1 — et **0,075 = 1/13,333
> exactement**. La feuille de route avait obtenu ~13 voxels par bloc par une
> mesure au pixel sur une capture, et retenu 16 ; le binaire porte la même
> valeur, par un chemin entièrement différent. La mesure à l'œil était juste.
> Le projet est donc à 16 là où l'original est à 13,33 : nos modèles sont
> **20 % plus fins** à bloc égal. `VOXELS_PER_BLOCK = 16` reste délibéré — une
> puissance de deux vaut mieux qu'un rapport bâtard — mais l'écart est
> désormais chiffré.

**Les deux manques de `CWFloraRenderer` sont comblés** (2026-09-05) : la gigue
d'échelle de 1× à 2× par instance, et les deux fréquences de bruit. Ce que le
portage a appris, au-delà de ce qui était prévu :

- **la crête à 0,05 est le mécanisme de groupement**, et il n'y en a pas
  d'autre. La dette « semer par grappes » n'était pas du code à écrire : la
  crête passe 29,2 % de la surface en plaques de 19,1 blocs, ce qui donne des
  paquets serrés et de larges vides. Mesuré après portage : variance/moyenne de
  **14,3** par cellule contre ~1 pour un tirage uniforme, 195 cellules vides
  sur 576 ;
- **la rareté entière (`rand()%8 == 0`) n'est pas portée, délibérément.**
  L'original la tire par colonne, ce qui suppose 256 échantillonnages par
  cellule — ~19 ms, hors budget. `CWScatter` tire un budget de candidats et ne
  paie la colonne qu'après la crête. Même moyenne : 256 × 0,2917 × 1/8 = 9,3
  plantes par cellule, contre les 9,8 que donnait la densité posée au jugé.
  Deux chemins indépendants, le même nombre ;
- **le test de signe se généralise par la parité de l'indice**, pas en deux
  moitiés contiguës — sans quoi une région sort à 40 % de cailloux, la table
  groupant les modèles par nature. Le défaut s'est vu en jeu, pas dans un test.

Détail et mesures en `docs/systems/02`, §8.3 et §8.4. Coût : la cellule de flore
passe de 1,07 à 1,29 ms, toujours hors du fil principal.

**Ce qui reste :** la table type de décor → modèle. Trois pistes sont déjà
éliminées (`docs/systems/02`, §8.5) ; la cible est le consommateur du champ
`type` de l'enregistrement.

**Correction de sources.** Onze noms du dépôt d'analyse sont trompeurs — les
quatre derniers sont venus avec la carte, et sont détaillés en
`docs/systems/05`, §8 :

- `WorldInfo_scatterObjectsInArea` (@005f56c0), listée ici comme seconde source
  de 1.7, **ne disperse pas d'objets** : elle choisit la liste d'espèces d'un
  point d'apparition selon le climat et le niveau, et son résultat est écrit
  dans un `cube::Spawn`. C'est du jalon 2.6.
- `World_generateTreeRecursive` (@005d9460) **ne génère pas d'arbres** : son
  corps est de la gestion de cellules de région et de `cube::Spawn`. Le corpus
  n'emploie « tree » que pour les arbres rouge-noir de la STL. Appelée en fin de
  `generateBiomeContent`, c'est une finalisation de cellule.
- `WorldInfo_generateBiomeContent` (@005e4850) **n'est pas le contenu de biome**
  mais le constructeur d'une cellule de 256 × 256 colonnes. `docs/systems/02`.
- `terrain_generateColumnColor` **ne rend pas une couleur** mais une hauteur de
  colonne : sa valeur sert de base d'altitude et devient une coordonnée Y.
- `World_placeObjectWithSpacing` **ne place rien** : elle rend un poids scalaire
  par colonne, facteur du champ de densité de végétation.
- `World_generateVegetationCluster` (@005d8750) **ne disperse pas de
  végétation** : c'est le résolveur de contenu d'une tuile. `docs/systems/02`, §7.
- `creature_generateAppearance` (`game_misc.cpp:3197`) **n'est pas propre aux
  créatures** : son `switch` couvre aussi les plantes, les filons et les
  poissons. C'est la table code d'entité → modèle. `docs/systems/02`, §5.
- `hash_or_index_compute` (@00602440) **ne calcule pas de hachage** : c'est
  `WorldMap::getTile`, l'indexation de la grille de cases de carte.
- `GameController_tryLockAndProcess` (@005fc160) **n'est pas un enrobage de
  verrou** : c'est `WorldMap::markDiscovered`, le seul point d'écriture de la
  découverte.
- `locked_pair_update` (@00601cc0) **ne met rien à jour** : c'est la recherche du
  site de région le plus proche, déjà portée en `CWTerrainField.nearest_site`.
- `Terrain_sampleHeightNoise` (@0059fc90) **n'échantillonne pas une altitude** :
  c'est la déformation du domaine à ±500, rendue en unités de zone.

### Assets à produire

Le jalon 1.6 n'a demandé aucun asset. Le jalon 1.7 est le premier qui en demande.

Le binaire d'origine charge **2 550 modèles voxels nommés** (`.cub`) ; leurs noms
donnent la liste sûre des *rôles* que le monde doit remplir. Le chiffre de 154
retenu jusqu'ici était une énumération partielle — relevé corrigé le 2026-09-05,
`docs/systems/02`, §6.2. Aucun n'est repris — ce sont des créations
originales — mais la liste des besoins, elle, ne se devine plus.
Liste par biome, noms de fichiers et ordre de production dans `nextsteps.md`,
§7.2. En résumé :

- **28 modèles pour le jalon 1.7** ✅ **faits** (39 fichiers, un dossier par
  biome), repartis sur les neuf surfaces que `CWPalette.surface_index` sait
  produire ; plus 5 cultures pour les champs, à faire ;
- **~50 pour le jalon 4** : mobilier, artisanat, décor extérieur et de donjon ;
- le reste (objets d'inventaire, créatures, interface) vient plus tard.

**Les arbres sont des assets — correction du 2026-09-05.** La feuille de route
affirmait le contraire. Le corpus charge nommément `fir-tree.cub`,
`thorn-tree.cub`, `christmas-tree.cub`, `tree-leaves.cub`, `palm-leaf.cub`,
`palm-leaf-diagonal.cub` et `wood-log.cub`. Il n'y a **pas** de générateur
d'arbre récursif à porter : `World_generateTreeRecursive` (@005d9460) est nommée
d'après les arbres rouge-noir de la STL, elle finalise une cellule. Reste à
établir si le feuillu est un modèle entier ou une composition tronc +
houppiers `tree-leaves` instanciés — l'existence d'un modèle de feuillage sans
arbre feuillu correspondant plaide pour la seconde lecture. Détail en
`docs/systems/02`, §6.1.

**Les maisons, elles, ne sont pas des assets.** `cube::House::ctor_0(3, 3, 4)`
montre qu'une maison est une grille de 3 × 3 × 4 cellules remplie
procéduralement — ce sont les meubles qui sont des modèles, pas le bâtiment. Un
algorithme à porter, pas un lot à dessiner.

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

Authoring : MagicaVoxel, palette de projet chargée en **ouvrant
`assets/palette/zentarys_palette.vox`** — et pas en glissant un PNG sur le
nuancier, qui décale les index sans rien dire. Plages réservées documentées dans
`assets/palette/PALETTE.md`. À l'import, `vox(x, y, z) -> godot(y, z, x)`.
**Échelle et conventions de fichiers : `assets/models/MODELS.md`** — c'est le
document à donner à qui modélise.

Pas d'éditeur voxel maison : la seule objection sérieuse était l'impossibilité de
descendre sous le voxel dans MagicaVoxel, et elle tombe avec le rapport de 16 —
sa grille est sans unité, on ne réduit pas le pinceau, on agrandit la boîte.
L'établi de personnalisation façon Cube World reste au programme comme
*fonctionnalité de jeu* (jalon 3.2/4, sur l'inventaire), pas comme outil de
production ; il réutilisera `CWVoxelModel` tel quel.

---

### 1.8 — Colonnes persistantes et édition (fait)

Analyse complète en **`docs/systems/03`**. Sept fonctions courtes et sans
ambiguïté — le système le mieux déterminé rencontré jusqu'ici.

**L'échelle du monde est confirmée par un second chemin.**
`Chunk_getColumnAt` refuse toute coordonnée hors de `[0, 0x1000000)`, soit
exactement `CWWorldParams.WORLD_SIZE`, obtenu jusqu'ici en multipliant 1024 zones
par 16 384 unités. Deux lectures indépendantes, le même nombre. `Grid_lookup1024`
borne à `0..0x3ff` — c'est la grille de zones — et `Region_getChunkCell` à
`0..0xffff`, soit 16 777 216 / 256. Trois recoupements.

**Un échelon manquait à l'échelle du monde :** le **chunk de 256 × 256
colonnes**, entre la tuile de 2 048 et le bloc — huit par huit dans une tuile.
C'est la cellule que construit `WorldInfo_generateBiomeContent` : les deux
analyses, menées séparément, décrivaient le même objet sans qu'on sache où le
ranger.

**La structure d'origine n'est pas portée, délibérément.** Grille de chunks,
colonnes paginées, plages redimensionnables : c'est exactement ce que
`VoxelTerrain` fait déjà, en natif. La réécrire serait porter une
implémentation. Ce qui est porté, ce sont les règles qu'aucun moteur ne devine.

> **L'eau n'est pas de la matière, c'est le vide sous le niveau de la mer.**
> `World_getBlockAt` ne lit jamais un bloc d'eau : au-dessus de la colonne il
> rend un témoin d'eau si `z <= 0` et un témoin d'air sinon, et il rabat de même
> un bloc *stocké* de type nul sous la même altitude. Le niveau de la mer de
> l'original est `z = 0` — `CWWorldParams.sea_level` valait déjà 0. Creuser sous
> la mer laisse donc de l'eau, pas un trou : une tranchée depuis la plage se
> remplit. C'est `CWWorldEdits.erase_value`.

Deux relevés qui n'étaient pas cherchés :

- **un bloc d'origine fait quatre octets : trois de couleur RVB et un
  d'attributs** (type sur 5 bits, drapeau 0x40, protection 0x80).
  `World_fillVoxelColumnTyped` donne à chaque bloc sa teinte, avec une gigue de
  table et un canal vert poussé vers 120 par un échantillon de bruit. Ce projet
  est en palette indexée par choix de rendu — mais cela éclaire peut-être la
  **dalle d'eau du LOD 1** restée inexpliquée : une couleur survit à une moyenne
  de résolution, un index de palette non. Piste, pas démonstration ;
- **la protection (0x80) empêche la génération d'effacer un bloc posé par une
  structure** — écrire de l'air y est refusé en silence, écrire de la matière
  repose le drapeau. Pas de producteur avant le jalon 4, et pas de place dans un
  canal d'un octet : documentée, non portée.

**Persistance.** `VoxelStreamSQLite` avec `save_generator_output = false`, un
fichier par graine : le monde intact reste procédural, seul le diff part sur le
disque — le modèle de l'original, qui ne sérialise que les colonnes touchées.
647 éditions occupent 20 Ko, écrites en 4 ms.

**Une régression attrapée par la validation en jeu, pas par les tests :**
fermer par `--quit-after` ou par un `SceneTree.quit()` direct n'envoie pas
`WM_CLOSE_REQUEST`, donc la sauvegarde ne partait pas — 647 éditions appliquées,
zéro écrite, sans un mot. `NOTIFICATION_EXIT_TREE` est le second filet.

**Ce que 1.8 laisse ouvert :** la flore ne réagit pas aux éditions — creuser un
cratère y laisse les plantes en l'air. C'est la conséquence connue de la
décision du 2026-09-04, devenue visible ; la corriger demande une requête par
plante, donc c'est un sujet du jalon 1.9. Les collisions ne sont pas branchées
non plus : `CWWorldEdits.voxel_at` est la primitive, le consommateur est le
contrôleur du jalon 3.1.

---

### 1.9 — Éclairage voxel (fait)

**L'algorithme est entièrement établi**, `docs/systems/04`. Deux passes : une
descente du soleil par colonne, puis **seize itérations** de diffusion
**purement horizontale**, atténuation **multiplicative `× 0,85`** par bloc (et
non le `− 1` de Minecraft), avec un **plancher de 5/255** qui empêche tout recoin
de tomber au noir. Le type 13 est une **source de lumière** à 255. Le double
tampon explique la disposition d'octets relevée au jalon 1.8 : pour un voxel
transparent, les trois premiers octets ne sont pas une couleur mais
suivant / courant / publié.

Trois types de blocs sont nommés au passage — **0 air, 2 eau, 13 lampe**. Ce
sont les trois premiers points d'ancrage vers la correspondance de numérotation
qui bloque `docs/systems/02`, §9.

> **Sur un monde intact, l'éclairage ne change rien.** Le terrain porté est un
> champ de hauteurs pur : la passe A répond « éclairé au-dessus, noir en
> dessous », et le dessous n'est jamais visible. La lumière ne devient visible
> que dans ce que le joueur a creusé — c'est-à-dire ce que le jalon 1.8 vient
> d'ouvrir.

**Ce qui bloquait n'était pas le calcul, c'était le rendu — et la décision est
prise.** `VoxelMesherCubes` n'a pas de canal de lumière : en mode palette il cuit
la couleur du nuancier dans les sommets, et il n'y a nulle part où loger une
luminosité par voxel. Le rendu est donc **passé en `COLOR_RAW`** — une couleur
par voxel au lieu d'un index — ce qui est **exactement ce que fait l'original**.
Un voxel porte maintenant deux choses : son **type** dans `CHANNEL_TYPE`, qui
reste ce que lit tout le code raisonnant en blocs, et sa **couleur** dans
`CHANNEL_COLOR`, que seul le mailleur lit. La palette reste la source des
couleurs et le contrat d'authoring : **les 39 modèles de flore n'ont pas été
repeints.**

**`CWLight` porte les deux passes**, et le terrain généré ne l'appelle pas : un
champ de hauteurs est éclairé partout où on le voit, donc la lumière ne sert que
là où le joueur a creusé. Deux choix d'implémentation ont porté tout le gain :

- les deux passes sont indexées dans **l'ordre natif de `VoxelBuffer`** (Y
  d'abord), ce qui permet de leur passer le canal de types tel quel — trente-six
  mille `get_voxel` de moins par coup de pioche ;
- `shaded_cells` **pousse la lumière depuis l'air vers ses voisins pleins** au
  lieu de sonder chaque bloc, si bien que la roche enterrée ne coûte rien.

Un coup de pioche isolé passe ainsi de 71 à **30 ms**, à profil de lumière
inchangé.

**Fait dans ce jalon :** la flore suit désormais le terrain édité. Creuser sous
une touffe la laissait en l'air — conséquence connue de la sortie de la flore
des données voxels (2026-09-04), devenue visible avec 1.8. `CWWorldEdits` tient
le sommet plein des colonnes éditées, calculé sur le fil principal au moment de
l'édition, et `CWScatter` y consulte un dictionnaire — rien sur le chemin chaud,
et pas de `VoxelTool` lu depuis un fil du pool.

> **Un piège de repère, et un test qui passait au vert pour rien.**
> `CWWorldEdits` travaille en coordonnées de scène, comme `VoxelTool` ;
> `CWScatter` en coordonnées monde. La première version rangeait la table dans
> le mauvais repère : la recherche ne tombait jamais juste et la flore
> continuait de flotter, **sans qu'aucune vérification ne bronche** — les deux
> côtés du test employaient le même repère. C'est la capture en jeu qui l'a
> montré. Le test traverse maintenant la conversion.

---

### 1.10 — Carte du monde (fait)

Analyse complète en **`docs/systems/05`**. Onze fonctions, dont quatre dont le
nom du dépôt d'analyse dit autre chose que ce qu'elles font.

**Une pièce de carte est une cellule de Voronoï.** C'est le résultat qui n'était
pas prévisible depuis l'apparence du jeu : `loadLandscapeTile` (@006024d0) balaie
la zone plus une zone de marge, déforme chaque point de la grille de chunks et ne
garde que ceux dont le **site de région le plus proche** est celui de la zone.
La carte n'est donc pas un quadrillage : c'est un puzzle aux frontières
ondulées — et ces frontières sont **exactement celles du climat**, puisque le
mélange de sites du jalon 1.3 travaille sur le même point déformé.

Conséquence pratique : **le jalon 1.10 n'apporte aucune constante numérique
nouvelle.** `World_getColumnDataAt2` est mot pour mot `CWTerrainField.warped_point`,
et la recherche du plus proche site est `nearest_site`, portée au jalon 1.6. La
carte assemble ce que le terrain avait déjà.

**L'échelle du monde est confirmée une troisième fois.** `WorldMap::getTile`
(@00602440, nommée `hash_or_index_compute` dans le dépôt) borne ses coordonnées à
`[0, 0x10000)` et indexe en deux temps, `>> 6` puis `& 63` : une case de carte
vaut **256 unités**, c'est-à-dire le chunk retrouvé au jalon 1.8, et il y en a
64 × 64 par zone.

**L'image stockée ne porte pas de couleur.** Le remplissage n'écrit que trois
valeurs, et elles sont grises : `200` là où aucune case n'existe, `220` pour une
case connue, `255` pour une case découverte. La teinte vient du dessin. Le
portage garde cette séparation — la clarté est une propriété du chunk, la teinte
une propriété de la région, et elles ne se rencontrent qu'au rendu.

**La découverte** tient en une fonction de dix lignes (`WorldMap::markDiscovered`,
@005fc160) : un bit par chunk, et un compteur — le seul état que l'original
persiste, en quatre octets sous la clé `discovered`.

**Les marqueurs sont les éléments de tuile du jalon 1.6**, relevés une troisième
fois par le couple stride `0x68` / base `+0x14018`. Rien de neuf à générer : la
couche existait, il fallait savoir qu'elle alimentait la carte.

**Les noms de région** sont deux syllabes tirées de deux tables de vingt,
indexées en croix par le point déformé ramené en unités de zone :
`tableA[(a*3 + graineA + b) % 20] + tableB[(b*3 + graineB + a) % 20]`. Le
mécanisme est porté à la lettre ; **les syllabes, elles, ne le sont pas** — ce
sont des créations artistiques du jeu d'origine, et `CWRegionName` porte deux
tables écrites pour ce projet.

> **Septième nom trompeur.** `Terrain_sampleHeightNoise` (@0059fc90)
> n'échantillonne pas une altitude : c'est la déformation du domaine à ±500,
> rendue en unités de zone. C'est `CWTerrainField.edge_warped_point`, portée au
> jalon 1.4. Trois autres noms sont corrigés en `docs/systems/05`, §8.

**Porté :** `CWWorldMap` (dalles, découverte, teintes, marqueurs, rendu),
`CWRegionName`, l'affichage `CWMapOverlay` (touche **M**, `+`/`−` pour élargir),
la persistance de la découverte par graine, et `tools/preview_map.gd` pour
regarder une carte sans lancer le jeu. 56 vérifications dans `tests/map_test.gd`.

**Trois écarts délibérés**, pesés en `docs/systems/05`, §7 : une dalle de 64 × 64
par zone plutôt qu'une pièce à sa boîte englobante (même géométrie, cache qui se
juxtapose sans recouvrement) ; une teinte de région échantillonnée à son site ;
la mer peinte en eau, parce que `surface_index` rend du sable sous le niveau de
la mer — juste pour le terrain, illisible sur une carte.

**Coût :** une dalle de 4 096 cases en **43 ms**, une vue de 5 × 5 zones en
1,4 s à froid, sur un fil du pool ; se recentrer ne recalcule que les zones qui
entrent dans le cadre. Un nom coûte 14 µs.

> **Un défaut de dessin que seul le jeu a montré.** Poser les seules ancres d'un
> `Control` sous un `CanvasLayer` le laisse de taille nulle : tout le dessin
> partait d'une origine négative et la carte sortait par le coin supérieur
> gauche. Aucune vérification ne pouvait broncher — un nœud invisible calcule
> juste. Ce sont les ancres **et les marges** qu'il faut poser.

**Ce que 1.10 laisse ouvert :** les six modèles de marqueurs
(`map-tile-{plains,village,forest,mountains,hills}.cub`, `skull.cub`) sont des
assets à produire ; l'affichage dessine des glyphes en attendant. Le type 14
reste sans identité — la carte l'a montré autrement : le compter comme village
en met dix-huit par région.

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
| Suite de tests headless | ✅ | 256 vérifications, `tests/worldgen_test.gd` |
| Gabarit d'échelle en jeu | ✅ | `src/demo/scale_board.gd`, capture automatique ; mires en blocs et modèles à la grille fine |
| Capture différée de la démo | ✅ | `TerrainDemo.auto_shot_delay` + `--quit-after` : regarder une couche sans piloter la fenêtre |
| Flore instanciée (MultiMesh par cellule) | ✅ | `src/worldgen/cw_flora_renderer.gd`, 1,1 ms/cellule hors fil principal |
| Groupement de la flore en grappes | ✅ | il n'y avait pas de mécanisme à écrire : la crête de bruit à 0,05 le produit seule (variance/moyenne 14,3 contre ~1) |
| Éclairage et LOD des modèles instanciés | ⬜ | la flore ne profite ni de l'éclairage voxel (1.9) ni d'une réduction en distance ; `CWVoxelModel.reduced(n)` est prêt |
| Aperçu de la carte hors du jeu | ✅ | `tools/preview_map.gd`, vierge et parcourue |
| Cache disque des dalles de carte | ⬜ | 43 ms la dalle, recalculée à chaque session ; l'original la compresse en base |
| Inventaire des modèles `.vox` | ✅ | `tools/inspect_model.gd`, contrôle des plages de palette |
| Aperçu rapproché des éléments | ✅ | `tools/preview_features.gd`, avec et sans la couche |
| Aperçus PNG (altitude, climat, chenaux) | ✅ | `user://worldgen_preview/` |
| Arrêt immédiat du streaming | ✅ | `CWVoxelGenerator.request_shutdown()`, 23 ms → 1 µs par bloc en file |
| Cache de colonnes | ✅ | 17 ms → 5 µs par bloc réutilisé |
| Débit de chargement | ✅ | vue 384 : > 3 min → **27 s** ; vue 768 : **120 s** |
| Portage du champ en GDExtension C++ | ⬜ | ~80 µs/colonne en GDScript ; **verrou de la vue lointaine**, voir ci-dessous |
| `VoxelStream` (sauvegarde du monde modifié) | ✅ | `VoxelStreamSQLite`, `save_generator_output = false` : seul le diff part sur le disque, 647 éditions = 20 Ko |
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
   bride un générateur GDScript. ⚠️ **Cette correction était une erreur** : voir
   « la falaise des fils » ci-dessous. Le bon nombre est celui des cœurs
   *physiques*, pas des cœurs logiques.
5. **Index des clés du flux SQLite** (`set_key_cache_enabled`), mesuré le
   2026-09-05 — voir la section suivante, qui corrige le constat ci-dessus.

| distance de vue | temps de stabilisation | pic de tâches |
|---|---|---|
| 384 blocs | **16 s** (8 fils, flux avec index) | 35 000 |
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

### Le flux de sauvegarde est passé devant la génération (2026-09-05)

Le constat d'ouverture — « le poste dominant est la génération » — a cessé
d'être vrai le jour où le jalon 1.8 a posé un `VoxelStreamSQLite` sur le
terrain, et personne ne l'a vu parce que l'ATH n'affiche que `gen` et
`maillage`. La file qui comptait était une troisième, invisible :

| | `streaming` | `generation` | stabilisation |
|---|---|---|---|
| flux, sans index de clés | 34 508 en attente | **14** (= le nombre de fils) | **39 s** |
| flux, index de clés | 33 029 en attente | 14 | **32 s** |
| aucun flux | 0 | 32 328 en attente | **29 s** |

Un `generation` bloqué à quatorze, c'est-à-dire exactement le nombre de fils,
n'est pas un pool saturé : c'est un pool **affamé**. Chaque bloc attendait une
requête SQLite avant d'être seulement mis en file de génération, et le
chargement était borné par le disque au lieu de l'être par le champ de terrain.

`VoxelStreamSQLite.set_key_cache_enabled(true)` tient en mémoire l'index des
clés présentes dans la base et répond « absent » sans la toucher. Il ne peut pas
se tromper ici : `save_generator_output = false`, donc la base ne contient que
des blocs édités. C'est une **méthode et non une propriété exportée**, ce qui
explique qu'elle soit passée inaperçue. Persistance revérifiée après coup :
creuser, quitter, relire — le bloc revient bien en air.

Il reste 3 s d'écart avec le monde sans flux, et elles sont structurelles : une
tâche de flux par bloc subsiste, même quand elle ne fait que consulter un
ensemble en mémoire. 34 500 tâches à ce prix, c'est ~8 % de débit en moins —
c'est ce que coûte la persistance, et le prix est honnête.

L'ATH affiche désormais les trois files — `flux N / gen N / maillage N` — et la
ligne de stabilisation dit si un flux est monté. Sans cela, un ralentissement de
ce côté serait resté invisible une seconde fois.

### La falaise des fils (2026-09-05)

Le pool avait été porté à `cœurs logiques − 2`, soit 14 sur cette machine, en
supposant que plus de fils ne peut pas nuire. C'est faux, et pas d'un peu.
Échantillonnage du champ sur une empreinte de 48 × 16 cartes de hauteurs, avec
de vrais `Thread` :

| fils | 1 | 4 | 6 | **8** | 10 | 12 | 14 |
|---|---|---|---|---|---|---|---|
| temps mur | 12,4 s | 5,7 s | 4,4 s | **3,2 s** | 7,9 s | 10,9 s | 13,5 s |
| coût par fil (µs/colonne) | 63 | 113 | 112 | 128 | 368 | 604 | 885 |

À quatorze fils, le travail est **plus lent qu'en mono-fil**. La falaise tombe
exactement entre 8 et 10, c'est-à-dire au passage du nombre de cœurs physiques
(16 fils logiques, 8 cœurs). Deux fils GDScript par cœur se disputent le cache
et l'allocateur, et le surcoût dépasse largement ce que le SMT rapporte. Un
témoin d'arithmétique purement locale, lui, monte bien à ×7,6 sur 14 fils : la
falaise est propre au travail du générateur, pas à la machine.

Confirmé en jeu, vue de 384 blocs :

| fils | 6 | **8** | 10 | 14 |
|---|---|---|---|---|
| stabilisation | 17,6 s | **16,2 s** | 20,7 s | 31,5 s |

Le pool prend donc la moitié des fils logiques (`TerrainDemo._pick_threads`, que
`generation_threads` permet de forcer sur une autre machine). **31,5 s → 16,2 s
pour un seul nombre changé**, et le temps CPU cumulé passe de 433 s à 127 s.

*Méthode, pour la prochaine fois :* trois de mes bancs successifs ont menti
avant celui-ci — l'un mesurait la taille du `WorkerThreadPool`, un autre des
`Thread.start` qui échouaient en silence parce que j'avais filtré les erreurs.
Un banc de parallélisme doit toujours porter un témoin dont on connaît d'avance
le résultat.

### La flore attend son sol

La flore se construisait en ~16 s là où le terrain en demandait 32 : le joueur
voyait des touffes flotter dans le vide en attendant que le sol les rejoigne, et
l'écart grandissait avec la distance de vue — donc empirait exactement là où on
veut aller. Une cellule attend désormais que les blocs de données soient chargés
sous ses plantes (`CWFloraRenderer.set_terrain`, `is_area_editable` sur
l'étendue verticale réelle des plantes, jamais sur la colonne entière : le
terrain ne charge qu'une tranche autour de l'observateur).

Les cellules pas encore prêtes tournent en fin de file plutôt que de bloquer
celles qui suivent — sans quoi un sommet hors de la tranche verticale arrêterait
toute la flore.

### Ce qui reste, et ce qui débloquerait vraiment

Après ces deux corrections, une vue de 384 blocs se stabilise en ~16 s, dont
l'essentiel est toujours l'échantillonnage du champ : 2 304 cartes de hauteurs à
68 µs la colonne, soit ~40 s de CPU mono-fil incompressibles en GDScript. Les
leviers d'ordonnancement sont épuisés ; ce qui reste est le **portage du champ en
GDExtension C++**, déjà identifié comme le verrou de la vue lointaine.

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
| 2026-09-05 | Jalon 1.10 : la carte du monde. Analyse dans `docs/systems/05` — onze fonctions, dont quatre au nom trompeur. **Une piece de carte est une cellule de Voronoi** : `loadLandscapeTile` balaie la zone plus une zone de marge, deforme chaque point de la grille de chunks et ne garde que ceux dont le site de region le plus proche est celui de la zone. La carte n'est donc pas un quadrillage, et ses frontieres sont **exactement celles du climat** — meme point deforme que le melange de sites du jalon 1.3. Consequence : **aucune constante numerique nouvelle**, `World_getColumnDataAt2` est mot pour mot `warped_point` et la recherche est `nearest_site`. **Troisieme confirmation de l'echelle** : `WorldMap::getTile` borne a `[0, 0x10000)` et indexe `>> 6` puis `& 63`, soit une case de 256 unites — le chunk du jalon 1.8 — et 64 x 64 par zone. **L'image stockee ne porte pas de couleur** : trois clartes, 200 / 220 / 255, et rien d'autre ; la teinte vient du dessin, et le portage garde cette separation. Decouverte : un bit par chunk et un compteur, seul etat persiste par l'original (4 octets, cle `discovered`). Marqueurs : ce sont les elements de tuile du jalon 1.6, releves une troisieme fois par le couple `0x68` / `+0x14018`. Noms de region : deux syllabes tirees de deux tables de vingt, indexees en croix par le point deforme en unites de zone ; le mecanisme est porte, les syllabes sont des creations originales. **Septieme nom trompeur** : `Terrain_sampleHeightNoise` n'echantillonne pas une altitude, c'est la deformation a ±500 en unites de zone — `edge_warped_point`, portee au 1.4. Defaut vu en jeu et par aucun test : poser les seules ancres d'un `Control` sous un `CanvasLayer` le laisse de taille nulle, et la carte sortait par le coin superieur gauche. Cout : dalle de 4 096 cases en 43 ms, vue de 5 x 5 zones en 1,4 s a froid, nom en 14 us. 256 verifications. |
| 2026-09-05 | Jalon 1.9, seconde moitie : **l'eclairage est porte**, et le chargement double de vitesse. Le rendu passe en `COLOR_RAW` — un voxel porte son type dans `CHANNEL_TYPE` et sa couleur dans `CHANNEL_COLOR`, ce qui est exactement ce que fait l'original, et les 39 modeles de flore n'ont pas ete repeints. `CWLight` porte les deux passes ; le terrain genere ne l'appelle pas, un champ de hauteurs etant eclaire partout ou on le voit. Deux choix portent tout le gain : les passes sont indexees dans l'ordre natif de `VoxelBuffer` (Y d'abord), donc le canal de types leur est passe tel quel — trente-six mille `get_voxel` de moins par coup de pioche — et `shaded_cells` pousse la lumiere depuis l'air vers ses voisins pleins au lieu de sonder chaque bloc, si bien que la roche enterree ne coute rien : 71 ms -> **30 ms** par coup de pioche, profil inchange. Chargement, deux defauts mesures : le **flux SQLite etait passe devant la generation** sans que rien ne le montre (l'ATH n'affichait que `gen` et `maillage`), chaque bloc attendant une requete disque avant d'etre mis en file — `set_key_cache_enabled` repond « absent » sans toucher la base ; et le pool tournait a quatorze fils, **au-dela des coeurs physiques le travail ne ralentit pas, il s'effondre** (14 fils plus lents qu'un seul). Vue de 384 blocs : 39 s -> **16,4 s**, et 433 s de temps CPU cumule ramenes a 127 s. La flore suit desormais la distance de vue du joueur et attend que le sol soit charge sous ses plantes. |
| 2026-09-05 | Jalon 1.9, premiere moitie. **L'algorithme d'eclairage est entierement etabli** (`docs/systems/04`) : descente du soleil par colonne, puis seize iterations de diffusion **purement horizontale**, attenuation **multiplicative x 0,85** par bloc et non le -1 de Minecraft, plancher de 5/255 qui interdit le noir absolu, type 13 = source a 255. Le double tampon explique la disposition d'octets du jalon 1.8 : pour un voxel transparent, les trois premiers octets sont suivant/courant/publie, pas une couleur. Trois types de blocs nommes au passage — 0 air, 2 eau, 13 lampe — les premiers points d'ancrage vers la correspondance de numerotation. **Le portage est suspendu a une decision de rendu** : `VoxelMesherCubes` n'a pas de canal de lumiere, il faudrait passer en `COLOR_RAW`, ce qui est exactement ce que fait l'original ; cout et gain peses en `docs/systems/04` §6-7. Sur un monde intact l'eclairage ne change rien de toute facon — le terrain est un champ de hauteurs pur, la lumiere ne se voit que dans ce qu'on a creuse. **Fait** : la flore suit le terrain edite, les touffes ne flottent plus au-dessus des crateres. Piege releve : `CWWorldEdits` est en coordonnees de scene, `CWScatter` en coordonnees monde ; la premiere version rangeait la table dans le mauvais repere et **aucun test ne bronchait**, les deux cotes employant le meme repere — c'est la capture en jeu qui l'a montre. 162 verifications. |
| 2026-09-05 | Jalon 1.8 : edition du terrain et persistance. Analyse dans `docs/systems/03` — sept fonctions courtes, le systeme le mieux determine jusqu'ici. **L'echelle du monde est confirmee par un second chemin** : `Chunk_getColumnAt` borne a `[0, 0x1000000)`, soit exactement WORLD_SIZE, obtenu jusqu'ici en multipliant 1024 zones par 16 384 ; `Grid_lookup1024` borne a 0..0x3ff (la grille de zones) et `Region_getChunkCell` a 0..0xffff. **Un echelon manquait** : le chunk de 256 x 256 colonnes, 8 x 8 par tuile — c'est la cellule de `WorldInfo_generateBiomeContent`, dont on ne savait pas ou la ranger. **L'eau n'est pas de la matiere** : `World_getBlockAt` ne lit jamais un bloc d'eau, il rend un temoin selon que z <= 0 ou non, le niveau de la mer d'origine etant 0 — la valeur que `sea_level` avait deja. Creuser sous la mer laisse donc de l'eau. Releve au passage : un bloc d'origine fait 4 octets, trois de couleur **RVB** et un d'attributs (type 5 bits, 0x40, protection 0x80) — ce qui donne une piste sur la dalle d'eau du LOD 1, une couleur survivant a une moyenne la ou un index de palette non. La structure d'origine n'est **pas** portee : `VoxelTerrain` tient deja ce role en natif, la reecrire serait porter une implementation. Persistance par `VoxelStreamSQLite`, `save_generator_output = false` : 647 editions = 20 Ko. Regression attrapee en jeu et non par les tests : `--quit-after` n'envoie pas `WM_CLOSE_REQUEST`, donc rien n'etait sauve — `NOTIFICATION_EXIT_TREE` est le second filet. 155 verifications. |
| 2026-09-05 | Les deux frequences de bruit portees dans `CWScatter`, et la gigue d'echelle par instance. **La crete a 0,05 est le mecanisme de groupement** : la dette « semer par grappes », ouverte le 2026-09-04, se ferme sans code de groupement — `|bruit(x*0,05)| > 0,5` passe 29,2 % de la surface en plaques de 19,1 blocs, et la variance/moyenne par cellule monte a 14,3 contre ~1 pour un tirage uniforme (195 cellules vides sur 576). La **rarete entiere n'est pas portee, deliberement** : l'original la tire par colonne, soit 256 echantillonnages par cellule (~19 ms, hors budget) ; le budget de candidats a la meme moyenne, et le calcul le confirme — 256 x 0,2917 x 1/8 = 9,3 plantes par cellule contre les 9,8 de la densite posee au juge, deux chemins independants sur le meme nombre. Le **test de signe se generalise par la parite de l'indice** et non en deux moities contigues : celles-ci donnaient une region a 40 % de cailloux, propriete de l'ordre de la table et non du mecanisme — defaut vu en jeu, pas dans un test. Corrige au passage : `PLACEMENT_PASS_RATE` mesure sur 250 000 colonnes autour du point de depart donnait 0,3012, trois points de trop ; la vraie valeur sur un million de colonnes reparties est 0,2917. `MAX_PER_CELL` 32 -> 64, sans quoi il rabotait au lieu de garder. 124 verifications. |
| 2026-09-05 | `VOXELS_PER_BLOCK` passe de 16 a **40/3**, la valeur de l'original : ses echelles d'instanciation du decor sont 0,075 / 0,09 / 0,1, et 0,075 = 3/40 exactement. Ecrit en fraction, pas en 13.333 qui derive. Un cube de reference d'un bloc n'etant plus entier, la reference d'authoring devient **3 blocs = 40 voxels**. Le personnage de 32 voxels passe de 2,0 a 2,4 blocs, ce qui recoupe les 2,3 blocs mesures au pixel : le changement rapproche du terrain mesure. Piege regle au passage : `CWScatter` utilisait le rapport comme modulo entier pour la position sous le bloc — les deux notions sont independantes et sont separees, `CWScatter.SUBBLOCK_STEPS = 16` d'un cote, la grille de dessin de l'autre. Deux tests verrouillent la fraction. 117 verifications. Ajoute : `docs/prompt_generation_flore.md`, prompt autoportant pour regenerer le lot sous Blender/bpy, avec un ecrivain .vox valide de bout en bout par le chargeur du projet. |
| 2026-09-05 | Seconde voie de pose identifiee, `docs/systems/02` §8. Il y a **deux** voies : les plantes a silhouette sont des entites a code de type, la flore basse (herbe, fleurs, algues, corail, roseaux) est du decor instancie sans entite, produit dans la meme passe que le terrain et pousse par `ChunkBuffer_loadAndNotify` (@005c03f0). Enregistrement reconstruit par recoupement de cinq branches : type a +0, echelle a +32, lacet a +36, drapeaux a +56. **Le rapport d'echelle est confirme par une constante du binaire** : les echelles de decor valent 0,075 / 0,09 / 0,1 et 0,075 = 1/13,333 exactement — la meme valeur que la mesure au pixel du 2026-09-04, par un chemin entierement different. Nos modeles sont 20 % plus fins que l'original a bloc egal ; VOXELS_PER_BLOCK = 16 reste delibere, mais l'ecart est chiffre. Deux manques de CWFloraRenderer releves : la gigue d'echelle de 1x a 2x par instance, et les deux frequences de bruit (0,05 pour ou, 0,01 pour laquelle). Reste la table type de decor -> modele ; trois pistes eliminees, la cible est le consommateur du champ type. |
| 2026-09-05 | Table modele/biome trouvee, seconde passe : `docs/systems/02` §5. Elle n'etait dans aucune des deux fonctions au nom prometteur — `World_generateVegetationCluster` (@005d8750) est le resolveur de contenu d'une tuile, pas un disperseur. La table est le switch d'apparence de `creature_generateAppearance` (game_misc.cpp:3197) croise avec les slots de chargement de `GameController`. **Flore, filons et creatures sont un seul espace de types d'entites** : 120-130 plantes, 131-139 filons, 145-155 poissons — ce qui confirme par la source la decision du 2026-09-04 de sortir la flore des donnees voxels. Les boites englobantes recoupent l'echelle fixee ici (thorn-tree 12 blocs, cactus1 4, buisson 2). Selection par type de bloc de surface pondere par le climat, jamais par un identifiant de biome. Rarete des filons entierement determinee (fer 70 %, or 10 %, argent 10 %, diamant 0,1 %). Reste : la correspondance des numerotations de blocs, et la seconde voie de pose de la flore basse (grass, flowers, alga, coral, reed n'ont pas de code d'entite). |
| 2026-09-05 | Premiere passe d'analyse de `WorldInfo_generateBiomeContent` (@005e4850, 4 200 lignes) : `docs/systems/02`. Ce n'est pas le disperseur de flore mais le constructeur d'une cellule de 256 x 256 colonnes. Sortis : le champ de densite de vegetation a quatre octaves avec ses constantes, l'identite de quatre types d'elements de tuile (6 = champ de rochers, 11 = massif isole, 12 = plan d'eau, 3 = parcelle batie), les constantes de pose des points d'apparition (jalon 2.6), et une corroboration independante du portage 1.6 (stride 0x68, base +0x14018, ordre tz + tx*8). Deux affirmations de la feuille de route corrigees : **les arbres sont des assets** (`fir-tree`, `thorn-tree`, `tree-leaves`...) et il n'y a pas de generateur d'arbre recursif a porter ; et le binaire charge 2 550 modeles nommes, pas 154. Prochaine cible reduite de 4 200 a 600 lignes : `World_generateVegetationCluster` @005d8750. |
| 2026-09-05 | Les 28 modeles du lot de flore livres et integres, en 39 fichiers ranges par biome ; `CWModelLibrary.FLORA` porte des chemins. Repare : les fichiers etaient peints sur une palette reechantillonnee par MagicaVoxel (planche de reference glissee sur le nuancier), donc bonnes teintes et mauvais index — invisible partout sauf a l'ecran ; `tools/repaint_models.gd` les remet dans la palette de projet, index et palette embarquee. Reserve de terrain 14-31 remplie (les six cailloux se rabattaient tous sur STONE) et deux entrees aquatiques ajoutees a la vegetation (le corail se rabattait sur le vert de prairie) ; le decoupage des plages n'a pas bouge. `zentarys_palette.vox` exporte : c'est le seul chargement de palette qui aligne les index. Gabarit d'echelle range par rangees de dix. 116 verifications. |
| 2026-09-04 | Echelle des assets refixee sur une mesure au pixel d'une capture du jeu d'origine : deux grilles, 1 bloc = 16 voxels de modele, personnage a 2 blocs (contre 8 blocs et 1 voxel = 1 bloc, tranches a l'oeil le matin meme). La flore quitte les donnees voxels du monde : maillage a part, instanciation par `CWFloraRenderer`. Le generateur ne connait plus la flore, ses +14 % par bloc disparaissent ; une cellule de flore coute 1,1 ms hors du fil principal. Gabarit d'echelle refait : mires en blocs, silhouette de 32 voxels avec des yeux d'un voxel. |
| 2026-09-04 | Jalon 1.6. Grille d'elements de tuile, cinq effets d'altitude, relevement des ilots oceaniques, champ de routes. Recursion generateur/champ cassee comme dans l'original, et rendue sure sur plusieurs fils. 30 verifications de plus. Cout : +0 us/colonne hors influence sur le chemin de streaming, +13 us dedans. |
| 2026-09-03 | Debit de chargement : doublons entre fils, plafond de cache, distance aux aretes inutile, pool de fils. Vue 384 stabilisee en 27 s au lieu de > 3 min. Teleportation par biome et reglage de la vue au clavier. |
| 2026-09-03 | Corrige : tranchee d'une colonne le long des aretes du graphe de sites (defaut d'unites, signale par l'utilisateur). Saut max entre colonnes voisines 2,35 -> 0,37 bloc. Test de non-regression par balayage dense ajoute. |
| 2026-09-03 | Vue lointaine : LOD natif teste et ecarte (dalles d'eau en pleine plaine des le LOD 1). Bascule `use_lod` conservee. |
| 2026-09-03 | Jalon 1.1–1.5. Analyse du pipeline de terrain, portage complet du champ (bruit, LCG, sites, climat, altitude, chenaux), générateur voxel + rendu `VoxelMesherCubes`, scène de démonstration, 43 tests. Corrigé : `world_origin` non appliqué dans le générateur ; absence de cache de colonnes. Ajouté : ATH compact, arrêt immédiat. |
