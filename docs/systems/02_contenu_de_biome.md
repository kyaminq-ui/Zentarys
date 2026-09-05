# Système 02 — Contenu de biome (jalon 1.7)

Note d'analyse. Source : `qad3n/CubeWorld-Reversal`, reconstruction par classe du
binaire alpha 2013. Le pseudo-code Ghidra n'est pas recopié ; seuls le
comportement observé, les constantes et les noms de symboles le sont.

**Portée.** Trois fonctions, analysées ensemble parce qu'elles ne se
comprennent pas séparément : `WorldInfo_generateBiomeContent` (@005e4850,
4 200 l), `World_generateVegetationCluster` (@005d8750, 604 l) et le `switch`
d'apparence de `creature_generateAppearance` (game_misc.cpp:3197, 2 464 l).
Cartographiées, pas portées. Ce qui suit est ce qui a été établi avec certitude ;
ce qui reste ouvert est dit comme tel.

**Il y a deux voies de pose de la flore, pas une.** Les plantes à silhouette
(buissons, cactus, arbres) sont des **entités** portant un code de type — §5.
La flore basse (herbe, fleurs, algues, corail, roseaux) est du **décor
instancié** sans entité — §8. Les deux premières fonctions citées portent des
noms trompeurs : ni l'une ni l'autre ne disperse de végétation.

---

## 1. Ce que la fonction est réellement

Le nom du dépôt d'analyse est trompeur d'un cran. `generateBiomeContent` n'est
pas « le contenu par biome » : c'est **le constructeur d'une cellule de 256 × 256
colonnes**, qui fait dans l'ordre le terrain fin, les déformations locales, la
couleur de surface, puis les points d'apparition. La dispersion de la flore n'y
est pas.

Signature réelle reconstruite : `generateBiomeContent(cellX, cellZ)`, avec
`cellX, cellZ` dans `[0, 65536)`. La zone vaut `cell >> 6`, donc **64 cellules
par zone sur chaque axe**, et une cellule couvre 16384 / 64 = **256 unités
monde**. C'est exactement la « région de colonnes » du tableau de découpage du
système 01 — les deux lectures concordent, sans avoir été faites ensemble.

Piège de lecture : Ghidra type `local_135c` et `local_1330` en `float *`. Les
bornes de boucle `+ 0x40` sont donc de l'arithmétique de pointeur, soit
**+256 unités**, pas +64. Une lecture littérale fait croire que la fonction ne
traite qu'un seizième de sa cellule.

### Enchaînement

1. `GameController::generateRegion` sur le voisinage **3 × 3** de zones ;
2. pré-échantillonnage d'une grille 256² de `(température, humidité, pointeur de
   cellule de région)`, enregistrements de 0x20 octets ;
3. carte de hauteurs de base par colonne, plus un **drapeau de pente** : la
   colonne est marquée abrupte si `|h − h(x+1)| > 0.3` ou `|h − h(z+1)| > 0.3` ;
4. champ de densité de végétation (§3) ;
5. écriture des colonnes : altitude fine, couleur mélangée, type de bloc ;
6. déformations par type d'élément de tuile (§4) ;
7. points d'apparition et pose des plantes (§5, §6) ;
8. `World_generateTreeRecursive`, puis chargement du blob sauvegardé en base.

### Confirmation indépendante du portage existant

La fonction adresse les éléments de tuile par
`(tz + tx·8)·0x68 + zone + 0x14018`, et lit le type à l'index `[6]` d'un
`float *`, soit l'octet `+0x18`. **Stride 0x68, base +0x14018, ordre
`tz + tx·8`, type à +0x18** : c'est mot pour mot ce que `CWTileFeature` et
`CWTileFeatureGrid` implémentent déjà, reconstruit ici depuis un autre site
d'appel. Le portage du jalon 1.6 est corroboré.

## 2. Constantes entières déguisées en flottants

Le décompilateur rend les comparaisons de type comme des flottants dénormaux :
`n × 1.4013e-45` est l'entier `n` réinterprété. Sans ce décodage la fonction est
illisible — `local_1304[6] == 8.40779e-45` est un test « type == 6 ».

## 3. Champ de densité de végétation

Quatre octaves de `perlinNoise2D_cosInterp` (le bruit de valeur du système 01),
combinées en deux crêtes puis sommées. Pour une colonne `(x, z)` :

```
n1 = bruit(x·0.04 + 432,    z·0.04 + 432)
n2 = bruit(x·0.08 + 432,    z·0.08 + 432)
r1 = 1 − |n1 + 0.05·n2| ;  r1 = 1 − r1³ ;  c1 = r1²

n3 = bruit(x·0.08 + 4234,   z·0.08 + 234)
n4 = bruit(x·0.05 + 423432, z·0.05 + 54352)
r2 = 1 − |0.05·n3 + n4| ;  r2 = 1 − r2³ ;  c2 = r2²

densite_bruit = c1 + c2
```

L'asymétrie est dans le binaire : la première crête pondère l'octave **haute**
par 0.05, la seconde pondère la **basse**. Ce n'est pas une transcription fautive.

Ce champ est multiplié par un poids par colonne rendu par
`World_placeObjectWithSpacing` (nom trompeur : la fonction ne place rien, elle
rend un scalaire), puis passé dans un lissage de Hermite :

```
d = clamp01(poids × densite_bruit × 1.25)
melange = 3d² − 2d³
```

`melange > 0.5` force le type de bloc de surface à **6**. Au-dessus, l'altitude
fine de la colonne vaut :

```
h = (bruit(x·0.01 + 34432, z·0.01 + 8992) + 1.5) · 60 · poids
    + 8 · (poids × densite_bruit)
    + h_base
```

**Misnomer relevé.** `terrain_generateColumnColor` ne rend pas une couleur : sa
valeur sert de `h_base` dans l'expression ci-dessus, alimente la détection de
pente au seuil 0.3, et est convertie en coordonnée Y de bloc. C'est une
**hauteur de colonne**. À renommer dans toute note qui s'en servira.

## 4. Identité des types d'éléments de tuile

C'était la question laissée ouverte au jalon 1.6. Quatre types sont maintenant
identifiés par ce qu'ils **construisent**, et non plus par leur seul effet sur
l'altitude.

| type | ce que la fonction en fait | confiance |
|---|---|---|
| 6 | **champ de rochers.** Grille 12 × 12 au pas de 64 u dans la cellule, position `cell·256 + i/3 + 42`. Chaque site : 3 chances sur 4 d'être tenté, retenu si le poids d'influence de l'élément ≥ 0.5 et si aucune entrée existante n'est à moins de 80 u. Rayons `rand()%10 + 20` sur les deux axes, hauteur `rand()%16 + 20`, creusé par `World_carveTerrainFeatureB`. Sauté à moins de 60 u du point d'apparition du monde. | haute |
| 11 | **massif isolé.** Un seul appel, au centre de la tuile (`cell·256 + 128`), `carveTerrainFeatureB` de rayon 100 × 100 et de hauteur `rand()%100 + 100`. | haute |
| 12 | **plan d'eau.** Un seul appel au centre de la tuile, `World_generateWaterOrPathFeature` de rayon 80 × 80, mode 6. | haute |
| 3 | **parcelle bâtie.** Balayage 14 × 14 au pas de 18 u (252 u, soit la cellule), poids d'influence par site, puis `World_buildPropInstance` sur l'élément. Les 3 variantes du jalon 1.6 sont vraisemblablement les 3 dispositions. | moyenne |
| 9 | construit un `cube::Spawn` (alloc de 0x10f0) au centre, si la cellule courante est celle de l'élément. | moyenne |
| 1, 5 | gardent une dispersion par distance à leur centre, dans la boucle de pose de §6. | moyenne |
| 13, 4 | convertissent leur position 16.16 en cellule et descendent la colonne jusqu'au premier bloc solide — préparation d'une pose, dont la suite n'est pas isolée. | faible |

Types **9 et 13 traités ici mais jamais produits** par
`World_generateRegionFeatures` : la lacune notée au jalon 1.6 pour le type 13
vaut aussi pour le 9. Une passe de placement reste non identifiée.

Le point d'apparition du monde est en `world + 0x8000f0` / `+0x8000f4`, et
`WorldInfo_placeStructure(def, pos, 0, 6, 0, monde, 1, out)` n'est appelée que
sur **la cellule de ce point**, une seule fois — c'est la structure de départ,
centrée par `pos = spawn − taille/2` avec la taille lue en `+0x44` / `+0x48`.

## 5. Le lot d'entités : flore, filons, créatures, poissons

**C'est ici qu'est la réponse à la question du jalon 1.7**, et elle n'est pas où
la feuille de route la cherchait.

### 5.1 Un seul espace de types

`creature_generateAppearance(kindOut, entite, graine)` (game_misc.cpp:3197,
2 464 lignes) est un `switch` géant sur un **code de type d'entité** qui écrit
l'identifiant de modèle en `+0x1c` et une boîte englobante. Le même espace de
codes couvre, sans séparation :

| plage | contenu |
|---|---|
| … – 119 | créatures (117 = `lich-body`) |
| **120 – 130** | **plantes** |
| **131 – 139** | **filons** |
| 140 – 142 | cibles et épouvantail |
| 145 – 155 | poissons et créatures aquatiques |

**Conséquence d'architecture.** Dans l'original, une touffe d'herbe et un ours
sont la même sorte d'objet : une entité portant un code de type, pas de la
matière écrite dans le terrain. C'est exactement la décision prise ici le
2026-09-04 en sortant la flore des données voxels — elle est confirmée par la
source, et pour une raison qui n'avait pas été anticipée.

### 5.2 Code de type → modèle

Relevé croisé entre le `switch` ci-dessus et la table de chargement de
`GameController` (`vector_at_stride4(slot)` donne le slot de chaque `.cub`).

| code | modèle | boîte |
|---|---|---|
| 120 | `bush` | 2 × 2 × 2 |
| 121 | `snow-bush` | 2 × 2 × 2 |
| 122 | `berry-bush` | 2 × 2 × 2 |
| 123 | `cotton-plant` | 0,5 × 0,5 × 1,5 |
| 124 | `scrub` / `scrub-green` (tirage) | 2 × 2 × 2 |
| 125 | `cobwebscrub` | 0,5 × 0,5 × 1,7 |
| 126 | `fire-scrub` | 2 × 2 × 2 |
| 127 | `ginseng` | 1 × 1 × 1 |
| 128 | `cactus1` | 1,5 × 1,5 × 4 |
| 129 | `fir-tree` | — |
| 130 | `thorn-tree` | 3 × 3 × 12 |
| 131 – 139 | `gold-`, `iron-`, `silver-`, `sandstone-`, `emerald-`, `sapphire-`, `ruby-`, `diamond-`, `ice-crystal-deposit` | — |

Les boîtes sont en **blocs de terrain**, et elles recoupent l'échelle fixée ici :
`thorn-tree` fait 12 blocs de haut, `cactus1` 4 blocs, un buisson 2 blocs — soit
le personnage de référence. Le `cactus_01` du lot livré, mesuré à 48 voxels =
3 blocs, est donc dans le bon ordre de grandeur.

### 5.3 Choix de la plante par type de bloc de surface

La sélection se fait sur le **type du bloc sous la surface** (la colonne est
remontée jusqu'au premier bloc d'air ou d'eau, et c'est celui d'en dessous qui
décide), jamais sur un identifiant de biome.

| bloc | condition | résultat |
|---|---|---|
| 12 | — | `thorn-tree` (130) ou `fire-scrub` (126), tirage à pile ou face |
| 4, 5, 9 | `rand()%3 ≠ 0` et humidité > 0,8 et température < 0,1 | `scrub-green` (124) ou `cactus1` (128), 50/50 |
| 4 | `rand()%3 ≠ 0` et température > 0,1 | `rand()%4` : 1 → `cotton-plant`, 2 → `ginseng`, 3 → `cobwebscrub`, sinon `bush` |
| 10 | `rand()%4 == 0` | `rand()%4` : 1 → `cotton-plant`, 2 → `cobwebscrub`, 3 → `berry-bush`, sinon `snow-bush` |

Le bloc **10 donne `snow-bush`** et le bloc **12 donne `fire-scrub`** : le premier
est donc une surface neigeuse, le second une surface volcanique. Les blocs 4, 5
et 9 sont des surfaces végétalisées, le 4 étant le plus tempéré.

> **Attention avant de porter.** La numérotation des blocs de l'original n'est
> **pas** celle de `CWPalette` (ici `AIR = 0`, `WATER = 12`, `SWAMP = 10`) ; dans
> l'original `0` est l'air et `2` l'eau. La correspondance entre les deux
> numérotations reste à établir : recopier la table telle quelle mettrait des
> cactus dans les marais. Le portage utile est la **forme** de la règle — une
> sélection par type de sol, pondérée par le climat — pas les entiers.

Réserve de lecture : la condition « humidité > 0,8 et température < 0,1 » donne
un cactus en climat froid et humide, ce qui surprend. Les deux variables sont
réaffectées plusieurs fois dans la fonction et Ghidra peut les avoir confondues ;
la ligne est reportée telle qu'elle est lue, avec une confiance moyenne.

### 5.4 Rareté des filons

Tirage à deux étages, entièrement déterminé :

```
rand() % 10 :  0 -> or        1 -> argent
               3 -> rand() % 100 :  0     -> diamant
                                    1-3   -> rubis
                                    4-8   -> saphir
                                    sinon -> emeraude
               sinon -> fer
```

Soit fer 70 %, or 10 %, argent 10 %, émeraude ~9,1 %, saphir 0,5 %, rubis 0,3 %,
diamant 0,1 %.

## 6. Points d'apparition — matière du jalon 2.6

La grande boucle de pose est commune aux créatures et aux plantes ; elle place
des `cube::Spawn` et donne des constantes utilisables telles quelles :

- pas de 0x55 = **85 unités**, décalage +24, gigue `rand() % 10` ;
- 1 tentative sur 4 abandonnée d'entrée (`rand() % 4 == 0`) ;
- rejet si le poids d'influence d'un élément de tuile non nul et non-10 dépasse
  0.3 — les poses **évitent** les éléments, sauf le donjon ;
- humidité < 0.2 : 1 chance sur 4 d'abandonner. Idem pour la température ;
- **espacement minimum de 20 unités** (comparaison à 400 sur le carré de la
  distance, en 16.16) ;
- lacet initial `rand() · 360 / 32767`, uniforme.

`WorldInfo_scatterObjectsInArea` remplit le champ `[0x0b]` — le code de type —
quand l'entité est une créature ; les branches de §5.3 y écrivent un code de
plante. C'est le **même champ**, ce qui confirme §5.1.

## 7. `World_generateVegetationCluster` — encore un nom trompeur

@005d8750, 604 lignes. Elle ne disperse pas de végétation : c'est le
**résolveur de contenu d'une tuile**. Signature reconstruite
`(tuileX, tuileZ, liste)`, sur la grille de tuiles 8192².

1. Vide le vecteur de poses (`+0xa0`) des **8 × 8 cellules** de la tuile, prises
   dans un tableau 64 × 64 à `zone + 0x10018`.
2. Localise l'élément de tuile — `zone + 0x14018 + (tz%8 + (tx%8)·8)·0x68`.
   **Troisième confirmation indépendante** de l'adressage porté au jalon 1.6.
3. Remet à zéro les champs `+0x34`, `+0x41`, `+0x44`, `+0x48`.
4. **Si le type vaut 10 (donjon), retour immédiat** : une tuile de donjon ne
   reçoit aucun contenu par cette voie.
5. Choisit une « sorte » de contenu par tirage uniforme dans une liste dictée par
   le type de l'élément :

   | type d'élément | sortes possibles |
   |---|---|
   | 0 (aucun) | {1} |
   | 1 (bourg) | {9, 3, 4} |
   | 14 | {5} |
   | tout autre non nul | {5} |

6. Parcourt les entités du monde pour retenir le **niveau maximum** des joueurs
   présents, et le passe aux constructeurs de contenu : la difficulté du contenu
   d'une tuile est **dynamique**, pas figée à la génération.
7. Selon la sorte : soit un contenu direct (sortes 7, 10, 11), soit la
   **restitution d'un contenu déjà mémorisé** (sorte 1, qui recopie `+0x54`,
   `+0x60`, `+0x64`), soit un choix de cellule.
8. Le choix de cellule note les 64 cellules par leur poids d'influence
   `(1 − d)²`, les trie (`introsort_float`) et retient la meilleure. Les sortes
   **12 et 13 doublent le poids sur un damier** — `(cellX + cellZ)` impair.
9. Le compte d'objets part dans `+0x48` : `rand()%8 + 25` (sorte 7),
   `rand()%5 + 10` (10), `rand()%5 + 15` (11), `rand()%5 + 6` (12),
   `rand()%10 + 10` (défaut).

## 8. La seconde voie de pose — le décor instancié

La flore basse (`grass`, `flowers`, `alga`, `coral`, `reed`…) n'a pas de code
d'entité. Elle passe par une **seconde voie**, distincte de celle du §5 : un
enregistrement de décor instancié, sans entité, sans comportement, sans
inventaire.

### 8.1 Où elle se trouve

Trois producteurs poussent dans la même liste, via
`ChunkBuffer_loadAndNotify` (@005c03f0) — c'est l'adresse qui donne son nom au
`list_pushBack_via5c03f0` du dépôt d'analyse :

| producteur | sites | rôle |
|---|---|---|
| `WorldInfo_generateBiomeContent` | 3 | **la flore naturelle**, dans la boucle par colonne |
| `World_populateRegionDecorations` | 7 | décor de village (jalon 4.3) |
| `Chunk_generateObjects` | 2 | contenu de chunk |

La flore naturelle est donc produite **dans la même passe que le terrain**, en
fin de boucle de colonne, et non par un système séparé.

### 8.2 L'enregistrement

Reconstruit par recoupement de **cinq branches indépendantes**, qui emploient
toutes le même écart d'offsets :

| offset | champ |
|---|---|
| +0 | type de décor (petit entier) |
| +32 | échelle (flottant) |
| +36 | lacet, en degrés |
| +56 | drapeaux (le bit 4 est posé par plusieurs branches) |

La position est écrite séparément, en virgule fixe 16.16, par
`int_toFixed16` + `arrayElem_stride8(0..2)`.

### 8.3 Les échelles — et ce qu'elles disent du contrat d'authoring

Les seules constantes d'échelle du décor sont **0,075**, **0,09** et **0,1**,
souvent multipliées par `rand()/32767 + 1`, soit une **gigue de 1× à 2×** sur la
taille de chaque instance.

> **0,075 = 1/13,333 exactement.**
>
> La feuille de route fixait le rapport modèle/bloc par une mesure au pixel sur
> une capture : « rapport mesuré ~13 voxels par bloc ; on retient 16, la
> puissance de deux la plus proche ». **Le binaire porte la même valeur dans une
> constante**, obtenue par un chemin entièrement différent. La mesure à l'œil
> était juste.
>
> Le projet est donc à 16 voxels par bloc là où l'original est à 13,33 : nos
> modèles sont **20 % plus fins** à taille de bloc égale. Ce n'est pas une
> erreur — `VOXELS_PER_BLOCK = 16` reste un contrat d'authoring délibéré, et
> une puissance de deux vaut mieux qu'un rapport bâtard — mais l'écart est
> maintenant chiffré au lieu d'être supposé.

Ce qui **manque encore au projet** et que l'original fait : la **gigue
d'échelle de 1× à 2× par instance**. `CWFloraRenderer` pose aujourd'hui toutes
les instances d'un modèle à la même taille. C'est une ligne à ajouter, et c'est
sans doute ce qui sépare le plus un champ d'herbe répétitif d'un champ vivant.

Le **lacet** a deux régimes selon la branche : par quarts de tour
(`(rand()%4) · 90`) pour la flore posée au sol, libre (`rand() · 360 / 32767`)
pour le reste. `CWScatter` ne fait que les quarts de tour — ce qui est correct
pour la flore, et à élargir pour les autres décors.

### 8.4 Les règles de sélection

Même forme partout : type de bloc de surface, puis seuils de climat, puis une
crête de bruit, puis une rareté par tirage.

| bloc | condition | décor |
|---|---|---|
| 3 | humidité > 0,2 · \|bruit(x·0,05 + 9843, z·0,05 + 8437)\| > 0,5 · `rand()%8 == 0` | type 22, échelle 0,09, lacet libre |
| 2 | humidité > 0,2 · altitude > 0 · \|bruit(x·0,05 + 24234, z·0,05 + 53565)\| > 0,7 · `rand()%10 == 0` | type 31 ou 32, échelle 0,09, lacet libre |
| 4, 9, 10, 12 | \|bruit(x·0,05 + 9843, z·0,05 + 8437)\| > 0,6 · `rand()%8 == 0` · altitude ≤ −5 | types 9 / 10 selon le signe de `bruit(x·0,01 + 9843, z·0,01 + 8437)`, échelle 0,075 ou 0,03–0,05 |
| ≠ 12, ≠ 10 | humidité ≤ 0,75, puis température ≤ 0,5 et deux crêtes de bruit à 0,01 | types 2 / 3, échelle 0,075 |
| — | branche à `local_37c` | types 5 / 6 / 7, échelle 0,075 ou 0,1 |

Deux régularités qui valent d'être portées telles quelles :

- **la fréquence de bruit sépare deux échelles de décision.** 0,05 décide *où
  il y a de la flore* (des plaques de quelques dizaines de blocs), 0,01 décide
  *laquelle* (des régions bien plus larges). `CWScatter` ne fait aujourd'hui
  qu'un tirage par cellule, sans cette structure à deux niveaux ;
- **la rareté est un tirage entier**, `rand()%8 == 0` ou `%10 == 0`, appliqué
  *après* le seuil de bruit — pas une densité continue.

### 8.5 Ce qui reste à trouver

La correspondance **type de décor → modèle** n'est pas résolue. Ce qui a été
éliminé, pour ne pas le refaire :

- les slots des modèles de flore (2423–2465 dans le vecteur de
  `GameController_load_game_assets`) n'apparaissent **nulle part** ailleurs que
  dans le chargeur : la résolution est calculée, pas littérale ;
- le registre entier de `World.cpp` (`rbtree_findOrInsert_intKey`) ne contient
  que **12 pièces de charpente** de bâtiment — clés 0 à 11, jalon 4.3 ;
- `SpriteManager` ne porte aucune table ;
- une base d'index fixe ne tient pas : aucune valeur de base ne rend cohérentes
  à la fois la branche sous-marine (types 9/10, qui doivent donner `alga` et
  `coral`) et les autres.

La cible restante est donc précise et petite : **trouver le consommateur du
champ `type` (+0) de l'enregistrement de décor.** C'est lui qui porte la table.

## 9. Ce qui reste ouvert

1. **La correspondance entre les types de blocs de l'original et ceux de
   `CWPalette`** — c'est le seul verrou avant de porter la table de §5.3.
2. La composition des arbres : `fir-tree` et `thorn-tree` sont des modèles
   entiers, mais `tree-leaves` existe sans arbre feuillu correspondant. Un
   assemblage tronc + houppiers reste à confirmer.
3. **La table type de décor → modèle**, seule inconnue restante de la seconde
   voie : voir §8.5, qui dit où elle n'est pas.
4. Les types d'éléments 2, 10, 14, 15 n'ont pas été isolés.
5. `World_carveTerrainFeatureA` / `B` et `World_generateWaterOrPathFeature`
   donnent la forme des rochers, massifs et plans d'eau de §4 : non analysées.
6. `World_populateRegionDecorations` (@005cc510, 4 000 lignes) n'est appelée que
   pour les **sites de région de type 3 et 5**, avec un drapeau 3 pour le type 5.
   Elle empile `World_fillVoxelColumnTyped` (40 appels) et `Terrain_fillCuboid`
   (11) : bâtisseur de villages, jalon 4.3.
