# Système 02 — Contenu de biome (jalon 1.7)

Note d'analyse. Source : `qad3n/CubeWorld-Reversal`, reconstruction par classe du
binaire alpha 2013. Le pseudo-code Ghidra n'est pas recopié ; seuls le
comportement observé, les constantes et les noms de symboles le sont.

**Portée.** Cinq fonctions, analysées ensemble parce qu'elles ne se
comprennent pas séparément : `WorldInfo_generateBiomeContent` (@005e4850,
4 200 l), `World_generateVegetationCluster` (@005d8750, 604 l), le `switch`
d'apparence de `creature_generateAppearance` (game_misc.cpp:3197, 2 464 l),
`WorldInfo_placeStructure` (@005f0ce0) et `terrain_surfaceColor_blend`
(@005c56e0). Ce qui suit est ce qui a été établi avec certitude ; ce qui reste
ouvert est dit comme tel.

**La règle de sélection du décor est portée** depuis le 2026-09-05 : §8.5 donne
la table type → modèle et §8.6 l'arbre de décision, tous deux dans
`src/worldgen/cw_decor_rules.gd`. Le reste de la note est cartographié, pas
porté.

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
| 12 | **grand objet de végétation.** Un seul appel au centre de la tuile, `World_generateWaterOrPathFeature` de rayon 80 × 80 et de variété 6. **Ce n'est pas un plan d'eau** — le nom de la fonction est trompeur, voir §10. | haute |
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

**La base d'index des entités est `slot = 1969 + code`** (2026-09-05, sixième
passe). C'est le même mécanisme que celui du décor (§8.5), sur un second bloc de
slots, et il est tenu par **treize valeurs consécutives** :

| code | slot | modèle |
|---|---|---|
| 126 | 2095 | `fire-scrub` |
| 127 | 2096 | `ginseng` |
| **129** | **2098** | **`fir-tree`** |
| **130** | **2099** | **`thorn-tree`** |
| 131-139 | 2100-2108 | `gold-`, `iron-`, `silver-`, `sandstone-`, `emerald-`, `sapphire-`, `ruby-`, `diamond-`, `ice-crystal-deposit` |
| 140 | 2109 | `scarecrow` |
| 141 | 2110 | `aim` |
| 142 | 2111 | `dummy` |
| **143** | **2112** | **`tree-leaves`** |

Les **neuf filons sortent dans l'ordre exact** de la table de rareté de §5.4, et
les trois cibles confirment la ligne « 140-142 = cibles et épouvantail » de §5.1
que rien n'étayait jusque-là. Cinq recoupements de plus, sur un bloc de slots
différent de celui du décor : le mécanisme « le slot de chargement *est* le code,
à une base près » est donc général, et ce n'est pas une coïncidence du décor.

> **Réserve sur les codes bas.** Sous cette base, les codes 120 à 125 et 128
> tombent sur `cobwebscrub`, `berry-bush`, `snow-berry`, `snow-berry-mash`,
> `scrub`, `scrub-green` et `ginseng-root` — pas sur ce que la table ci-dessus
> annonce, qui vient de la lecture du `switch`. Les deux lectures divergent d'un
> ou deux rangs, et sans uniformité : 124 et 126 s'accordent, 120 et 128 non.
> Le bloc de slots 2087-2099 contient d'ailleurs deux buissons et deux aliments
> (`snow-berry`, `snow-berry-mash`, `ginseng-root`) que le `switch` ne cite pas.
> **La partie haute — arbres, filons, cibles, houppier — est sûre ; la partie
> basse ne l'est pas.** Elle n'a pas été retranchée car c'est la lecture du
> `switch`, faite indépendamment.

**Ce que cela règle : `tree-leaves` a son propre code d'entité.** Il est en 143,
loin des deux arbres en 129-130, juste après les trois cibles — donc il est
**posé séparément**, pas contenu dans un modèle d'arbre. Et il n'existe dans tout
le corpus **aucun** `tree-trunk`, `oak`, `broadleaf` ni équivalent. Il suit que :

- le **sapin** (`fir-tree`) et l'**arbre à épines** (`thorn-tree`) sont des
  modèles entiers, posés en une fois ;
- le **feuillu n'est pas un modèle** : c'est un assemblage, un tronc surmonté
  d'un ou plusieurs houppiers `tree-leaves` instanciés. Le tronc n'étant pas un
  modèle non plus, il est très probablement **écrit dans le terrain** en
  colonnes de blocs — l'original en a la primitive, `World_fillVoxelColumnTyped`
  (@005df600), qui écrit un type et une couleur bruitée sur une hauteur donnée ;
- le **palmier** suit la même construction : `palm-leaf` (2300) et
  `palm-leaf-diagonal` (2301) sont deux palmes, il n'y a pas de modèle de
  palmier.

C'est la réponse à la question ouverte n° 2 de §9, et elle a une conséquence de
portage : un feuillu ne se pose pas comme une plante. Voir `docs/ROADMAP.md`,
§1.11.

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
> **Le projet a suivi le 2026-09-05** : `VOXELS_PER_BLOCK` est passé de 16 à
> `40 / 3`. Le rapport n'est plus une puissance de deux — les réductions de LOD
> ne tombent plus rond — mais il est celui de l'original, et un modèle de 32
> voxels fait désormais 2,4 blocs, ce qui recoupe les 2,3 blocs mesurés sur la
> capture. Le lot de flore a été redessiné à cette échelle le même jour.

**Porté le 2026-09-05.** `CWScatter.Placement.scale` tire `1 + rand()/32767` et
`CWFloraRenderer.instance_transform` l'applique dans la base, donc l'instance
grandit depuis son ancre — au sol, au centre de l'empreinte — et non depuis le
coin de son gabarit ; sinon une touffe à 2× s'enterrerait de sa demi-hauteur.

Deux conséquences à porter avec, sous peine de plantes tronquées à l'écran : la
marge de `CWScatter.placements_in` et la boîte de visibilité de chaque
`MultiMesh` se calculent désormais sur le rayon de l'**instance**
(`Placement.radius_blocks()`), pas sur celui du modèle nu.

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
  *laquelle* (des régions bien plus larges) ;
- **la rareté est un tirage entier**, `rand()%8 == 0` ou `%10 == 0`, appliqué
  *après* le seuil de bruit — pas une densité continue.

**Portées le 2026-09-05**, avec trois constats qui n'étaient pas prévus.

> **La crête à 0,05 *est* le mécanisme de groupement.** La feuille de route
> portait depuis le 2026-09-04 une dette technique « groupement de la flore en
> grappes », ouverte sur le constat que l'original sème par paquets de trois à
> six pieds et qu'un tirage uniforme ne sait pas le faire. Il n'y avait rien à
> inventer : `|bruit(x·0,05 …)| > 0,5` passe **29,2 %** de la surface, en
> plaques de **19,1 blocs** de long — la longueur d'onde 1/0,05. Mesuré après
> portage : variance/moyenne = **14,3** par cellule, contre ~1 pour un tirage
> uniforme, et 195 cellules vides sur 576. Les grappes et les vides sortent de
> la crête seule. La dette se ferme sans code de groupement.

> **La rareté entière ne se porte pas telle quelle, et c'est délibéré.**
> L'original visite *chaque colonne* et garde `rand()%8 == 0` de celles qui sont
> dans une plaque : 256 échantillonnages de colonne par cellule, soit ~19 ms —
> précisément ce que le projet ne peut pas payer. `CWScatter` tire donc un
> budget de candidats et n'échantillonne la colonne que pour ceux qui passent la
> crête. Les deux schémas ont la même moyenne, et le calcul le vérifie :
> 256 × 0,2917 × 1/8 = **9,3 plantes par cellule**, là où la densité posée au
> jugé dans `CWModelLibrary` en donnait **9,8** sur l'herbe. Deux chemins
> indépendants, le même nombre — la densité devinée était la bonne.
>
> Ajouter malgré tout un `%8` par candidat serait décoratif : filtrer au hasard
> des positions déjà tirées au hasard rend des positions au hasard.

> **Le test de signe se généralise par la parité de l'indice, pas en deux
> moitiés contiguës.** L'original tranche entre `alga` et `coral` — deux
> variantes de même nature. Sur une liste de dix modèles, couper en deux blocs
> contigus donne une région à 40 % de cailloux et une sans aucun, parce que la
> table de `CWModelLibrary` groupe les modèles par nature et que les deux
> cailloux de l'herbe se suivent en fin de liste. C'était une propriété de
> l'*ordre de la table*, qui est provisoire, pas du mécanisme — et ça se voyait
> en jeu avant de se voir dans un test. La parité entrelace les natures et ne
> dépend pas de cet ordre ; pour n = 2, elle reste mot pour mot le test de signe
> d'origine.
>
> **Caduc depuis le 2026-09-05 au soir.** La parité était une généralisation de
> ce projet, faite faute de connaître la table. Elle est connue depuis — §8.5 —
> et l'original ne généralise rien : il a **deux** crêtes de décalages
> différents, la première pour la famille, la seconde pour la variante. La
> parité a été retirée avec `CWScatter._choose` ; le mécanisme porté est en §8.6.
> Ce paragraphe est gardé parce que le défaut qu'il décrit — une composition qui
> dépend de l'*ordre* d'une table — reste le piège de tout raccourci de ce genre.

### 8.5 La table type de décor → modèle — trouvée (2026-09-05, sixième passe)

Trois pistes avaient été éliminées lors de la passe précédente, et elles le
restent : les slots de flore n'apparaissent que dans le chargeur, le registre
entier de `World.cpp` ne porte que douze pièces de charpente, `SpriteManager`
ne porte aucune table. La quatrième piste — **une base d'index fixe** — avait
été écartée trop tôt : elle tient, sur une large partie du domaine, et c'est
elle qui donne la table.

**Le tableau des slots de modèle.** `GameController_load_game_assets` charge
2 449 fichiers `.cub`, et l'appel qui précède chaque nom donne son **slot** :
`vector_at_stride4(N)`. L'ordre des slots n'est **pas** l'ordre de chargement —
les huit enseignes sont chargées dans le désordre et rangées, elles, à la
suite —, ce qui est le premier indice que le slot porte un sens. Le décor
occupe un bloc contigu à partir de 2423 :

| slot | modèle | | slot | modèle |
|---|---|---|---|---|
| 2418 | `seahorse` | | 2443 | `sunflower` |
| 2419-2421 | *(jamais remplis)* | | 2444 | `bean-tendril` |
| 2422 | `key1` | | 2445-2446 | `desert-flower01/02` |
| 2423-2424 | `flowers2`, `flowers` | | 2447-2448 | `wheat`, `corn` |
| 2425-2427 | `grass`, `grass2`, `grass3` | | 2449-2450 | `water-lily01/02` |
| 2428-2429 | `lava-flower`, `lava-grass` | | 2451-2458 | les **huit enseignes** |
| 2430-2431 | `thorn-plant`, `echinacea2` | | 2459 | `ivy` |
| 2432-2434 | `leaf`, `lantern02`, `torch` | | 2460-2461 | `wall-roses-red/white` |
| 2435-2436 | `stone`, `stone2` | | 2462 | `christmas-tree` |
| 2437 | `tendril` | | 2463 | `underwater-plant` |
| 2438-2439 | `tulips-colorful`, `cornflower` | | 2464-2465 | `alga`, `coral` |
| 2440 | `reed` | | 2466-2469 | `inca-art1..4` |
| 2441-2442 | `pumpkin-leaves`, `pineapple-leaves` | | 2470-2477 | blasons, torches, `liana` |

**La relation est `slot = 2418 + type`**, et cinq recoupements indépendants la
tiennent — pris dans trois fonctions différentes :

| type | vient de | condition de pose | modèle rendu |
|---|---|---|---|
| 22 | `generateBiomeContent` | bloc 3, humidité > 0,2 | `reed` — un roseau sur sol humide |
| 31, 32 | `generateBiomeContent` | **bloc 2**, altitude > 0 | `water-lily01/02` — deux nénuphars sur l'eau |
| 33-40 | `WorldInfo_placeStructure` | un par **genre de bâtiment** (2, 3, 4, 5, 6, 13, 14, 15) | les **huit enseignes**, dans l'ordre |
| 41-43 | `WorldInfo_placeStructure` | `rand()%3`, au-dessus d'un vide, échelle 0,15 | `ivy`, `wall-roses-red/white` |
| 48 | `WorldInfo_placeStructure` | décor mural de structure | `inca-art1` |

Le troisième est le plus fort : huit genres de bâtiment, huit types consécutifs,
huit enseignes consécutives, et l'ordre colle nom par nom — auberge, boutique,
armurier, forgeron, charpentier, tisserand. Le deuxième l'est presque autant :
deux modèles adjacents dont le nom dit l'eau, deux types adjacents, sur le bloc
que `docs/systems/03` §4 identifie déjà comme l'eau.

> **La réserve, et elle est honnête.** La même base ne tient **pas** sous 22.
> La branche de flore basse de `generateBiomeContent` produit les types 0 à 4,
> 11, 12 et 5 à 7 ; sous la base 2418 ils tomberaient sur `seahorse`, trois
> slots vides et `key1` — impossible. Sous la base **2423**, en revanche, les
> types 0 à 4 donnent exactement `flowers2`, `flowers`, `grass`, `grass2`,
> `grass3` : les cinq couvre-sols, en tête du bloc de décor, et dans l'ordre où
> la règle les emploie. Le type 12, plus grand (échelle 0,1-0,12), y donne
> `stone` — un caillou.
>
> **Il y a donc un décalage de cinq entre les deux moitiés du domaine**, exact
> sur tous les points mesurés (22−17, 31−26, 33−28, 41−36, 48−43). Cinq valeurs
> de type sans modèle dans ce bloc, ou une table qui n'est pas tout à fait
> linéaire : le consommateur n'a pas été localisé, et sans lui on ne peut pas
> trancher. Ce qui compte pour le portage est que **les deux lectures
> s'accordent sur la nature** de chaque décor — un roseau au bord de l'eau, des
> nénuphars dessus, de l'herbe et des fleurs sur le sol tempéré, un caillou sur
> le sol chaud, trois modèles immergés au fond. C'est cette nature qui est
> portée, sous le nom de **rôle**.

### 8.6 L'arbre de décision, et ce qui en est porté

La branche de décor est en fin de boucle de colonne de
`WorldInfo_generateBiomeContent` (`cube/world/WorldInfo.cpp`, ~4330-4740). Elle
est reproduite ici avec ses constantes exactes. `bloc` est le type du bloc de
surface, `z` l'altitude du sommet de colonne, `h` et `t` l'humidité et la
température, `n05(dx, dz)` le bruit à 0,05 et `n01(dx, dz)` celui à 0,01.

```
bloc 3   : h > 0,2  et  |n05(9843, 8437)| > 0,5   et  rand()%8 == 0
           -> type 22, échelle 0,09, lacet libre, drapeau 4

bloc 2   : h > 0,2  et  z > 0  et  |n05(24234, 53565)| > 0,7  et  rand()%10 == 0
           -> type 31 ou 32 (rand()%2), échelle 0,09, lacet libre

blocs 4, 9, 10, 12 : |n05(9843, 8437)| > 0,6  et  rand()%8 == 0
  z <= -5 (immergé)            lacet par quarts de tour
      n01(9843, 8437) <= 0     -> type 7, échelle 0,1, drapeau 4
      sinon                    -> type 5 ou 6 (rand()%2)
                                  type 5 : échelle 0,075, drapeau 4
      puis échelle *= 1 + rand()/32767
  -5 < z < 1                   -> rien
  z >= 1, bloc 4 ou 9
      h <= 0,75                lacet par quarts de tour, échelle 0,075
          t <= 0,5
              n01(9843, 8437) <= 0  -> type 1 si n01(34234, 234234) <= 0, sinon 0
              sinon                 -> type 3 si n01(34234, 234234) <= 0, sinon 2
          t > 0,5
              n01(9843, 8437) <= 0  -> type 1 si n01(34234, 234234) <= 0, sinon 0
              sinon                 -> type 12 si n01(34234, 234234) > 0, sinon 4
          types 2, 3, 4, 12 : drapeau 4 ; type 12 : échelle 0,1 + rand()*0,02/32767
          posé si bloc == 4 ou type parmi {2, 3, 4}
      h > 0,75
          t <= 0,25   rand()%100 == 0 -> type 27 ou 28, échelle 0,075, quarts de tour
          t > 0,25    lacet libre, échelle 0,075
              n01(9843, 8437) <= 0 -> type 12 si n01(34234, 234234) <= 0,5, sinon 11
              sinon                -> type 4 si n01(34234, 234234) > 0, sinon 3
              type 11 : drapeau 4, échelle 0,05 + rand()*0,05/32767
              type 12 : drapeau 4, échelle 0,1 + rand()*0,02/32767
              posé si bloc == 4 ou type parmi {2, 3}
```

Six choses en sortent, et c'est ce qui est porté dans
`src/worldgen/cw_decor_rules.gd` :

1. **Il y a deux crêtes à 0,01, pas une.** La première, de décalage
   `(9843, 8437)` — le même que la crête de placement à 0,05 —, tranche la
   *famille*. La seconde, de décalage `(34234, 234234)`, tranche la *variante*.
   Deux décalages différents, donc deux cartes différentes : mesuré ici, les
   deux signes ne s'accordent que 50,8 % du temps, soit le hasard. Au même
   décalage, la seconde ne dirait rien et une famille sur deux disparaîtrait.
   **C'est le mécanisme de composition régionale**, et il était deviné jusqu'ici
   — `CWScatter._choose` prenait un indice sur deux par le signe d'une crête
   unique, une invention de ce projet, aujourd'hui retirée.
2. **Le second seuil est biaisé.** `(n2 <= 0,5)` dans la branche humide, contre
   `(n2 <= 0)` ailleurs : la variante minoritaire ne sort qu'à peu près une fois
   sur quatre. C'est ce qui garde le caillou et le sous-bois rares au milieu de
   l'herbe. Mesure après portage sur 4 000 points de prairie : couvert 43,5 %,
   fleur 41,0 %, caillou 8,4 %, sous-bois 7,0 %.
3. **Les échelles disent la taille du rôle.** 0,075 est la référence — et c'est
   exactement `3/40`, le rapport voxel/bloc de ce projet, donc nos modèles sont
   dessinés à la taille nominale du décor d'origine. Les écarts se lisent en
   clair : roseau et nénuphar à 0,09 (**1,2×**), caillou à 0,1-0,12
   (**1,33-1,6×**), sous-bois humide à 0,05-0,10 (**0,67-1,33×**). Portés dans
   `CWDecorRules.SCALE_RATIO`.
4. **Le lacet a deux régimes**, par quarts de tour pour ce qui pose au sol,
   libre pour le roseau, le nénuphar et le sous-bois humide. Noté dans
   `CWDecorRules.FREE_YAW`, **pas encore rendu** : `CWVoxelModel` ne précalcule
   que quatre quarts de tour.
5. **Une seule rareté est empilée sur la crête**, celle du couple 27/28 :
   `rand()%100 == 0` *en plus* du `rand()%8` qui filtre déjà la branche. Elle
   est portée telle quelle (`Role.RARE`). Les autres `rand()%8` et `%10` sont le
   tirage *par colonne* que ce projet a remplacé le 2026-09-05 par un budget de
   candidats par cellule ; les réappliquer les compterait deux fois.
6. **Le bloc 9 ne reçoit qu'un sous-ensemble** des types que reçoit le bloc 4 —
   c'est la condition de pose finale. Une surface secondaire porte donc moins de
   *variété*, pas seulement moins de plantes.

**Ce qui n'est pas transposable tel quel.** L'original choisit sur son type de
bloc de surface puis affine par des seuils de climat *dans la règle* ;
`CWPalette.surface_index` a déjà mangé le climat — la jungle et le marais y sont
des surfaces, pas des branches. La *forme* est donc portée telle quelle et ce
sont ses *feuilles* qui sont réattribuées à nos neuf surfaces
(`CWDecorRules.FAMILIES`). Trois branches sont reprises mot pour mot : le sol
tempéré (fleur contre couvert), le sol chaud (où la seconde crête fait entrer le
minéral) et le fond marin (le test de signe entre `alga` et `coral`). Les autres
lignes sont des affectations de ce projet, signalées comme telles dans le code.

**Le nénuphar n'est pas porté** : le lot des 39 modèles n'en a pas, et la
surface `WATER` n'est jamais rendue par `surface_index`. Les décors de mur
(types 41-43, 48) relèvent du jalon 4.3.

![La composition d'une prairie, en jeu](../images/flore_composition.png)

## 9. Ce qui reste ouvert

1. **La correspondance entre les types de blocs de l'original et ceux de
   `CWPalette`** — le verrou avant de porter la table de §5.3. Il s'est
   entrouvert : `terrain_surfaceColor_blend` (@005c56e0) *est* la règle de
   surface de l'original, l'équivalent exact de `CWPalette.surface_index`, et
   elle n'écrit que cinq types. Par ordre d'application, le dernier gagnant :
   **4** par défaut ; **9** si la pente est faible et le second paramètre
   climatique > 0,75, ou si le terme de bruit à 0,01 croisé au niveau est
   positif ; **10** si ce paramètre < 0,3 ; **12** si le poids d'influence de
   la cellule de région dépasse 0,5 ; et **6** que l'appelant force quand le
   facteur de falaise dépasse 0,5 — **portée au jalon 1.13** : le seuil est
   celui-ci, la *mesure* du facteur est de ce projet (une pente sur un treillis
   de 4 blocs, `CWTerrainField.cliff_factor`), et elle rend 4,4 % des terres en
   roche nue. Avec §5.3 (bloc 10 → `snow-bush`, bloc 12
   → `fire-scrub`), cela donne : 4 = sol végétalisé tempéré, 6 = roche,
   9 = second sol végétalisé, 10 = neige, 12 = sol de région spéciale,
   2 = eau, 3 = sol humide. Reste à décider lequel de `param_5`/`param_6` est
   la température et lequel l'humidité — Ghidra les échange plusieurs fois
   dans la fonction, et c'est la même réserve qu'en §5.3.
2. ~~La composition des arbres~~ — **résolue** le 2026-09-05, §5.2.
   `tree-leaves` porte son propre code d'entité (143), donc il est posé
   séparément ; `fir-tree` (129) et `thorn-tree` (130) sont des modèles entiers ;
   le feuillu et le palmier sont des assemblages, et leur tronc n'est pas un
   modèle. Reste à trouver *qui* assemble : la fonction qui pose un tronc puis
   ses houppiers n'a pas été localisée, et elle est sans doute inlinée dans
   `generateBiomeContent`. Jalon 1.11.
3. ~~La table type de décor → modèle~~ — **résolue** le 2026-09-05, §8.5 et
   §8.6, avec une réserve documentée sur les types inférieurs à 22. Portée
   dans `src/worldgen/cw_decor_rules.gd`.
4. Les types d'éléments 2, 10, 14, 15 n'ont pas été isolés.
5. ~~`World_generateWaterOrPathFeature`~~ — **analysée** le 2026-09-06, §10.
   Elle ne fait ni eau ni chemin. `World_carveTerrainFeatureA` / `B`, qui
   donnent la forme des rochers et massifs de §4, restent non analysées.
6. `World_populateRegionDecorations` (@005cc510, 4 000 lignes) n'est appelée que
   pour les **sites de région de type 3 et 5**, avec un drapeau 3 pour le type 5.
   Elle empile `World_fillVoxelColumnTyped` (40 appels) et `Terrain_fillCuboid`
   (11) : bâtisseur de villages, jalon 4.3.

## 10. Les lacs, et le nom qui les cachait (2026-09-06)

Cette section est née d'une question de feuille de route — « où sont les lacs et
les rivières ? » — dont la réponse attendue était : dans
`World_generateWaterOrPathFeature`, qui n'est pas analysée. Elle l'est
maintenant, et **elle n'a rien à voir avec l'eau**. Les lacs étaient ailleurs,
dans une fonction déjà portée aux trois quarts.

### 10.1 `World_generateWaterOrPathFeature` (@005df960) — le douzième nom trompeur

2 025 lignes, sept variétés, et pas une qui écrive de l'eau. Ce qu'elle bâtit :

| ce qu'elle appelle | combien | ce que ça fait |
|---|---|---|
| `Terrain_paintSphere` | 7 | des sphères de **bois** (type 7), dont un motif en croix — centre, puis (x ± r, z) et (x, z ± r) |
| `World_generateFoliageBlob` | 5 | des masses de **feuillage** (type 8) |
| `WorldInfo_placeStructure` | 8 | deux groupes de quatre, avec un indice de rotation qui parcourt 0, 1, 2, 3 |
| `Terrain_paintDisk` | 2 | les disques de la variété 1 |

La signature réelle est
`(x, z, altitude_de_base, rayon, hauteur, variété, contexte)` — **`param_4` est
un rayon, pas un mode** : la fonction le manipule en flottant, `(int)(r × 0,2)`
plafonné à 3, `r << 3`. La variété est `param_6`, et elle vaut 0 à 6.

Ce que chaque variété change, relevé dans le prologue :

- **2** : les six composantes de couleur à 255 — un objet **blanc** ;
- **3** : (240, 180, 120) et (220, 100, 50) — un objet **orangé**, de désert ;
- **1** : moitié moins épais, deux fois plus haut, et le corps devient une
  **spirale** — l'angle avance de 0,3 π par tour de boucle sur trente
  itérations, soit quatre tours et demi, le rayon se resserre et la hauteur
  monte, avec deux teintes RVB tirées au hasard interpolées le long de l'arc ;
- **5** : hauteur × 0,7, rayon plafonné à 3 ;
- **6** : garde les couleurs tirées du climat. C'est la variété que l'élément
  de tuile 12 emploie, au centre de sa tuile, en rayon 80 et hauteur 80.

Les couleurs par défaut viennent de `GameController_sampleHumidityGrid` et
`GameController_sampleTemperatureGrid`, échantillonnées en tête de fonction.

**La preuve tient dans un octet.** `Terrain_paintSphere` et `Terrain_paintDisk`
prennent un `byte*` de quatre octets — `{R, V, B, type}` — et le passent à
`tilemap_writeGlyphColumn`. Les seuls types que cette fonction écrit sont
`0x27` et `0x28` ; le type réel est `octet & 0x1f`, le bit `0x20` étant un
drapeau, donc **7 et 8**. Et `World_generateFoliageBlob` — le *feuillage*, le
nom est sûr — écrit `0x28`. Donc 8 = feuillage, 7 = bois, et cette fonction est
un **générateur de grande végétation**, pas un générateur d'eau.

> Au passage, `Terrain_paintSphere` dit aussi comment l'original ombre sa
> végétation : quand son drapeau de mélange est levé, il tire du bruit 3D en
> (x, y, z) et interpole la couleur passée vers **(50, 120, 60)**, un vert de
> feuillage. La teinte n'est donc pas uniforme dans une masse, elle est bruitée
> par voxel — ce que ce projet obtient autrement, par des rampes de palette.

**Conséquence pour §4 : l'élément de tuile 12 n'est pas un plan d'eau.** C'est un
grand objet de végétation posé au centre de sa tuile, rayon 80, hauteur 80. La
ligne du tableau était marquée « confiance haute », et elle l'était à tort : la
confiance portait sur *quel appel* le type 12 fait — ce qui est juste et vérifié
— et non sur *ce que cet appel fait*, qui n'était qu'un nom.

### 10.2 Où l'eau est réellement écrite

Dans `WorldInfo_generateBiomeContent` (@005e4850) — la fonction que ce projet a
déjà portée pour la flore (§8.6) —, dans une **autre passe** de la même cellule,
une boucle de 64 × 64 colonnes distincte de celle du décor.
`WorldInfo.cpp:2694-2805`, et elle tient en entier :

```
pour chaque colonne (x, z) de la cellule :

    v = WorldInfo_sampleTerrainHeight(x, z)          -- le CHAMP DE CHENAUX
    si v <= 0,02                                     -- la porte
      et garde_de_region(x, z) <= 0,95               -- §10.2.2

        niveau = terrain_generateColumnColor(x, z)   -- une hauteur, pas une couleur
        q      = floor(niveau / 5) * 5               -- quantifié au pas de 5
        frac   = (niveau - q) / 5
        t      = 2 x frac                si frac < 0,5
                 1 - (frac - 0,5) x 4    sinon,  et si t < 0 : (t+1)^2 - 1
        bas    = q - 5t + 2

        si bas <= q :                                -- vrai ssi t >= 0,4
            remplir [bas, q] d'EAU (type 2), couleur (0, 0, 255 x (1 - t))
            écrire du SOL HUMIDE (type 3) en q       -- le lit, et la rive
            une chance sur 200 : poser un objet en q

        -- puis on ouvre la colonne au-dessus : les berges
        creux = niveau + 5 x (1 - (50v)^3) + (bruit(x x 0,02, z x 0,02) + 1) x 2
        remplir [q + 1, creux[ d'AIR
```

#### 10.2.1 Ce que chaque ligne apporte

1. **la porte est le champ de chenaux**, et c'est la découverte qui compte :
   `WorldInfo_sampleTerrainHeight` (@005f9340) **ne lit pas une hauteur**. Elle
   calcule `|bruit(1e-3) + bruit(1e-2) x 0,1|`, module par un bruit non graîné à
   1e-3 (`x ((m+1) x 0,1 + 0,8)`), puis ajoute un terme de crête en
   `(1 - d x 0,75)^2 x 0,05`. **C'est mot pour mot `CWTerrainField._channel`**,
   que ce projet porte depuis le jalon 1.4 sous le nom
   `World_riverClimateGate` (@0052cd50) — mêmes fréquences, même valeur absolue,
   même modulation non graînée, même terme de crête.

   > **Le réseau qui creuse les vallées est celui qui les remplit.**
   > `nextsteps.md` écrivait « le réseau de chenaux du jalon 1.4 creuse bien les
   > vallées, mais rien ne les remplit ». Il ne manquait pas un champ, il
   > manquait un seuil : **0,02**.

   Deux termes de la version décompilée que notre portage n'a pas : des bosses
   par **type de cellule de région** (types 1, 2, 4, 13 : `+ (1-d²)²` ; types
   6 et 7 : `+ (1-d²)² x 0,5`) et un terme additif final tiré de la cellule.
   Ils **élèvent** le champ, donc ils **interdisent** l'eau près de ces
   cellules — un bourg n'a pas d'étang en son centre. À porter avec les lacs,
   pas avant : ils déplaceraient le lit des vallées existantes ;

2. **le niveau est quantifié au pas de 5.** C'est ce qui donne à l'eau sa
   surface plate par paliers, et c'est ce qui fait que deux colonnes voisines
   partagent un niveau tant qu'elles tombent dans le même pas ;

3. **`t` est une rampe triangulaire, et c'est elle qui fait les étangs.** Elle
   vaut 0 aux deux bouts d'un palier et 1 en son milieu ; la condition
   `bas <= q` équivaut à `t >= 0,4`, donc à `frac` entre **0,2 et 0,65**. Le
   long d'un chenal, l'eau apparaît et disparaît à chaque fois que le niveau
   traverse un multiple de 5 : **un chapelet de mares, pas une rivière
   continue**. La profondeur maximale est de quatre blocs, atteinte au milieu
   du palier ;

4. **le lit est du sol humide (type 3)**, et c'est la boucle qui ferme une
   question ouverte du jalon 1.7 : `CWDecorRules.FAMILIES_SURFACE` donne au sol
   humide sa propre composition — roseau, sous-bois humide — et c'est la
   **seule exception attachée à une matière** du projet. On savait quoi y faire
   pousser sans savoir qui produisait la matière. C'est cette passe ;

5. **les berges sont creusées, et l'eau n'est donc pas enterrée.** Sans les
   quatre dernières lignes, remplir `[bas, q]` d'eau sous un terrain plus haut
   donnerait une poche invisible. La passe ouvre la colonne de `q+1` jusqu'à
   `niveau + 5 x (1 - (50v)^3) + bruit`, et l'exposant cubique fait que le creux
   est **maximal au centre du chenal** (v = 0 → +5) et **nul au bord de la
   porte** (v = 0,02 → +0). C'est un bol, et c'est ce qui donne la rive.

#### 10.2.2 Les deux réserves qui restent

- **`Terrain_sampleHeightAtWorldXY` (@005989d0) est elle aussi mal nommée** :
  elle ne lit aucune altitude. Elle prend la cellule de région de `x >> 11`,
  `z >> 11` — la grille de **2 048 unités**, soit la tuile — et ne rend une
  valeur que si le type de cette cellule vaut **1** ; partout ailleurs elle rend
  **0**, donc la porte `<= 0,95` passe par défaut. C'est une exclusion locale
  autour d'un seul type de site, pas un garde-fou d'altitude. Le **sens** de
  l'exclusion n'est pas tranché : la valeur rendue est une distance au carré
  selon le nom proposé, un poids de retombée selon la forme du code, et les deux
  donnent des exclusions inverses. Sans effet sur la carte d'ensemble ;
- **quelle hauteur `terrain_generateColumnColor` rend.** Que ce soit une
  couleur est déjà corrigé (elle rend une hauteur, `docs/ROADMAP.md` §1.7). Reste
  à savoir si c'est la hauteur **finale** de la colonne ou son **ossature
  continentale** avant les octaves de détail. Les berges creusées rendent les
  deux jouables, et l'écart se voit : avec la finale, l'étang se creuse dans le
  sol ; avec l'ossature, il se pose au fond de la vallée telle qu'elle est
  taillée. **C'est la seule chose qui manque pour porter la passe**, et c'est
  une lecture, pas un choix.

#### 10.2.3 Ce que la porte rend sur notre champ

Mesuré sur `CWTerrainField.channel_field`, 147 456 colonnes sur 36 zones
éloignées, graine 1337 :

| chenal | part du monde |
|---|---|
| 0,00 – 0,01 | 1,72 % |
| 0,01 – 0,02 | 1,78 % |
| **≤ 0,02 (la porte)** | **3,51 % du monde, 3,40 % des terres** |

Le champ est presque uniforme par centièmes — 1,7 à 1,8 % par tranche —, donc le
seuil se déplace linéairement et se règle sans surprise. **La règle n'est pas
vide** : 3,4 % des terres, et comme le champ est rectifié, ce sont des **lignes
ramifiées** et non des taches. À quoi il faut appliquer la rampe `t`, qui n'en
garde que 45 % : de l'ordre de **1,5 % des terres en eau**, en chapelets le long
des fonds de vallée.

### 10.3 Et les chemins ?

**Rien.** Aucune des sept variétés de @005df960 ne trace quoi que ce soit entre
deux points, et la seule interpolation qu'elle contient est le bras d'une
spirale. Cela **confirme** la correction déjà écrite au jalon 1.6 : la source
n'a pas de réseau de routes entre points d'intérêt. Un chemin reliant les bourgs
d'une région serait une création de ce projet, et il faudra le dire comme tel.
