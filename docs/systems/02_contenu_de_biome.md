# Système 02 — Contenu de biome (jalon 1.7)

Note d'analyse. Source : `qad3n/CubeWorld-Reversal`, reconstruction par classe du
binaire alpha 2013. Le pseudo-code Ghidra n'est pas recopié ; seuls le
comportement observé, les constantes et les noms de symboles le sont.

**Statut : première passe.** `WorldInfo_generateBiomeContent` (@005e4850) fait
4 200 lignes ; elle est ici cartographiée, pas portée. Ce qui suit est ce qui a
été établi avec certitude, et ce qui reste ouvert est dit comme tel.

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
7. points d'apparition (§5) ;
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
| 1, 5 | gardent une dispersion par distance à leur centre, dans la boucle d'apparition de §5. | moyenne |
| 13, 4 | convertissent leur position 16.16 en cellule et descendent la colonne jusqu'au premier bloc solide — préparation d'une pose, dont la suite n'est pas isolée. | faible |

Types **9 et 13 traités ici mais jamais produits** par
`World_generateRegionFeatures` : la lacune notée au jalon 1.6 pour le type 13
vaut aussi pour le 9. Une passe de placement reste non identifiée.

Le point d'apparition du monde est en `world + 0x8000f0` / `+0x8000f4`, et
`WorldInfo_placeStructure(def, pos, 0, 6, 0, monde, 1, out)` n'est appelée que
sur **la cellule de ce point**, une seule fois — c'est la structure de départ,
centrée par `pos = spawn − taille/2` avec la taille lue en `+0x44` / `+0x48`.

## 5. Points d'apparition — matière du jalon 2.6

La grande boucle finale place des `cube::Spawn`. Elle confirme la correction
déjà notée (`WorldInfo_scatterObjectsInArea` choisit une espèce, ne disperse
rien) et donne des constantes utilisables telles quelles :

- pas de 0x55 = **85 unités**, décalage +24, gigue `rand() % 10` ;
- 1 tentative sur 4 abandonnée d'entrée (`rand() % 4 == 0`) ;
- rejet si le poids d'influence d'un élément de tuile non nul et non-10 dépasse
  0.3 — les apparitions **évitent** les éléments, sauf le donjon ;
- humidité < 0.2 : 1 chance sur 4 d'abandonner. Idem pour la température ;
- **espacement minimum de 20 unités** entre apparitions (comparaison à 400 sur
  le carré de la distance, en 16.16) ;
- la colonne est remontée jusqu'au premier bloc **d'air (0) ou d'eau (2)**, et
  c'est le bloc en dessous qui décide : le bloc de type **12** force l'espèce à
  126 ou 130 selon un tirage, et la catégorie à 6 ;
- lacet initial `rand() · 360 / 32767`, uniforme.

Les identifiants 120 à 138 rencontrés dans la fonction sont des **espèces**,
écrites dans le champ `[0x0b]` d'un `Spawn` ; `[0x0a]` est une catégorie. Aucun
n'a de rapport avec un modèle de flore.

## 6. Deux corrections à la feuille de route

### 6.1 Les arbres *sont* des modèles

La feuille de route affirmait qu'aucun modèle d'arbre ne figure parmi les assets
et que les arbres sont construits par le code. C'est faux. Le corpus charge
nommément :

```
fir-tree.cub   thorn-tree.cub   christmas-tree.cub
tree-leaves.cub   palm-leaf.cub   palm-leaf-diagonal.cub   wood-log.cub
```

La lecture la plus probable, à confirmer : les conifères et l'épineux sont des
modèles entiers, tandis que le feuillu est **composé** — un tronc et des
houppiers `tree-leaves.cub` instanciés, ce qui expliquerait qu'il existe un
modèle de feuillage sans modèle d'arbre feuillu correspondant. Cette composition
reste à établir ; ce qui est acquis, c'est qu'il n'y a **pas** de générateur
d'arbre récursif à porter.

`World_generateTreeRecursive` (@005d9460) porte bien mal son nom : le corpus
n'emploie « tree » que pour les arbres rouge-noir de la STL (`tree_nodeAlloc`,
`tree_insertRecursive`, `tree_nodeInsertLeaf`…), et la fonction est appelée en
toute fin de `generateBiomeContent`, juste avant le chargement du blob
sauvegardé — c'est une **finalisation de cellule**.

### 6.2 Le compte de modèles

La feuille de route parle de « 154 modèles voxels nommés ». Le corpus contient
**2 550 noms de fichiers `.cub` distincts**. Les 154 étaient sans doute une
énumération particulière ; la liste des rôles, elle, est bien plus large.

## 7. Rôles de flore — liste relevée

Relevé par filtrage des noms `.cub`. **Les 28 rôles déjà produits sont tous
confirmés** et se recoupent nom pour nom avec la liste du projet (`cornflower` =
bleuet, `sunflower` = tournesol, `heartflower` = fleur_coeur, `soulflower` =
fleur_ame, `ginseng-root` = fleur_ginseng, `reed` = roseau, `ivy` = lierre,
`tendril` = vrille, `alga` = algue, `coral` = corail…). Le lot livré le
2026-09-05 visait juste.

Ce qui **manque** au projet, et qui est dans le binaire :

- végétal : `berry-bush`, `snow-berry`, `snow-bush`, `thorn-plant`,
  `shimmer-mushroom`, `desert-flower01/02`, `flowers`, `flowers2`,
  `heartflower-frozen`, `water-lily01/02`, `underwater-plant`, `plant-fiber`,
  `lava-grass`, `lava-flower`, `cotton-plant` ;
- arboré : les sept fichiers de §6.1 ;
- minéral : `runestone`, `stone2`, `sandstone` ;
- **filons**, catégorie entièrement absente du projet et pourtant jouable :
  `gold-`, `iron-`, `silver-`, `sandstone-`, `emerald-`, `diamond-`, `ruby-`,
  `sapphire-`, `ice-crystal-deposit`.

Les variantes `lava-*` impliquent une surface volcanique que
`CWPalette.surface_index` ne produit pas aujourd'hui.

## 8. Ce qui reste ouvert

1. **La table modèle → biome n'est toujours pas lue.** Elle n'est pas dans
   `generateBiomeContent`, qui ne disperse pas de flore. La piste est
   `World_generateVegetationCluster` (@005d8750, **600 lignes**) et son appelant
   décrit à `game_misc.cpp:42457` comme le générateur de haut niveau qui pilote
   `generateVegetationCluster` et `generateTreeRecursive`. C'est la prochaine
   cible évidente, et elle est petite.
2. `World_populateRegionDecorations` (@005cc510, 4 000 lignes) n'est appelée que
   pour les **sites de région de type 3 et 5**, avec un drapeau 3 pour le type 5.
   Elle empile `World_fillVoxelColumnTyped` (40 appels) et `Terrain_fillCuboid`
   (11) : c'est le bâtisseur de villages du jalon 4.3, pas de la flore.
3. Les types 2, 10, 14, 15 n'ont pas été isolés dans cette passe.
4. `World_carveTerrainFeatureA` / `B` et `World_generateWaterOrPathFeature`
   sont appelées mais non analysées : ce sont elles qui donnent la forme des
   rochers, des massifs et des plans d'eau de §4.
