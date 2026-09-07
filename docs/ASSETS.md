# Zentarys — assets voxels

> Sorti de `nextsteps.md` le 2026-09-10. C'est de la **référence d'authoring** —
> l'échelle, ce qu'il faut produire par biome, et la décision de produire par
> script plutôt qu'à la main —, pas le récit d'une session : sa place est un
> fichier qu'on ouvre quand on fabrique un modèle, pas celui qu'on lit à chaque
> reprise. La table de hauteurs de référence, elle, est dans
> `assets/models/MODELS.md` §1, et c'est la seule (voir §9 de `nextsteps.md`).

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
| **snowlands** | `herbe_gelee` `fleur_de_glace` `buisson_neige` `snowberry` `cotonnier` | `pin_enneige`, `sapin_enneige`, `bouleau_givre_tronc` + houppier — **pas de grand arbre**, §7ter.2 |
| **deserts** | `cactus_01` `cactus_02` `broussaille_seche` `cotonnier` `habanero` | `palmier_tronc` + `palme` + `palme_diagonale` — **plus de `cactus_geant`**, §7ter.3 |
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
