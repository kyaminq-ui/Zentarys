# Système 01 — Génération de terrain voxel

Note d'analyse et de portage. Source analysée : `qad3n/CubeWorld-Reversal`,
reconstruction par classe (RTTI + graphe d'appels) du binaire alpha 2013 de
Cube World. Le pseudo-code Ghidra n'est pas recopié dans le projet ; seuls le
comportement observé et les constantes numériques sont documentés ici.

---

## 1. Résumé du système

Le monde est une grille de 1024 × 1024 zones. Chaque zone possède un unique
« site » tiré au sort, porteur d'une température, d'une humidité et d'une
altitude de base. Le climat et l'ossature du relief en tout point s'obtiennent
en mélangeant les 9 sites voisins par distance, sur un domaine déformé par du
bruit. Par-dessus s'ajoutent cinq octaves de bruit de valeur dont l'amplitude
est elle-même pilotée par cinq champs de bruit basse fréquence, et un réseau de
chenaux en bruit rectifié qui aplatit les fonds de vallée. Enfin, chaque zone
porte une grille 8 × 8 d'« éléments de tuile » qui déforment le relief
localement : un bourg qui aplanit, des cratères, des caldeiras, des pitons, et
un relèvement qui fait émerger un îlot sous une structure tombée en mer. Aucune
autre source d'aléa n'intervient : tout le monde dérive d'une seule fonction de
bruit et d'un seul LCG.

## 2. Analyse du pseudo-code

### 2.1 Découpage spatial reconstruit

Déduit des décalages de `World_getTileAtCoords` (@004286f0), des bornes de
`Chunk_getColumnAt` (@00406100) et des fenêtres 3 × 3 des mélanges climatiques :

| niveau | taille | grille | indexation |
|---|---|---|---|
| monde | 16 777 216 u | — | `x < 0x1000000` |
| zone | 16 384 u | 1024 × 1024 | `x >> 14` |
| tuile | 2 048 u | 8 × 8 par zone | `x >> 11` |
| région de colonnes | 256 u | 8 × 8 par tuile | `x >> 8` |
| colonne | 1 u | 256 × 256 par région | enregistrement de 32 octets |

Une unité monde vaut une colonne de blocs. Deux tableaux de 1024 × 1024
pointeurs se suivent dans `cube::World` : les zones à `+0xbc`, les sites à
`+0x4000bc` (= `0xbc + 1024·1024·4`).

### 2.2 Bruit (`valueNoise2D` @004d5d30)

Bruit de valeur à interpolation cosinus, algorithme public dit « Hugo Elias » :
`n = x + y·57`, `n ^= n << 13`, puis `((n·n·60493 + 19990303)·n + 3521384707)`
masqué sur 31 bits et normalisé sur 2^30. Le binaire utilise le **second**
triplet de nombres premiers publié avec cet algorithme, pas le plus courant
(15731 / 789221 / 1376312589). Pas de sommation d'octaves dans la fonction :
elle est faite par les appelants.

Détail relevé : le binaire indexe le réseau par troncature vers zéro, ce qui
replierait le bruit autour de l'origine. Sans effet sur le domaine réellement
échantillonné (coordonnées rendues positives par de grands décalages de graine).

### 2.3 Sites de région (`World_generateRegionSite` @0050b870)

Structure de 0x1c octets, mémoïsée par zone. `srand(rx + 0x108a + rz·0x400 +
graine·3)` puis une séquence de `rand()` de la CRT MSVC. Un tirage pair/impair
choisit entre un climat tempéré (T 0,3-0,7 ; H 0,4-0,8) et un climat extrême où
température et humidité sont chacune poussées vers un bord (0-0,1 ou 0,9-1,0) —
c'est ce qui donne des régions franchement désertiques ou franchement glaciaires
plutôt qu'un dégradé. Un tirage sur 10 dans la branche tempérée produit un
marais. La zone contenant le point de départ court-circuite tous ces tirages.

L'altitude de base vient de deux échantillons de bruit indexés par la région :
`(n1+1)·100 − 70 + n2·30`. Sous 1, la région devient océanique (−100
supplémentaires, plancher à −100) ; la zone de départ en est exemptée.

### 2.4 Mélanges climatiques (`World_temperatureBlend` @004f8570, `World_humidityBlend` @004f8b40)

Fenêtre 3 × 3 de zones autour du point, déformée de ±768 unités par du bruit à
5e-4 — avec croisement des axes : le décalage en X est tiré de Z et
réciproquement (`World_terrainOffset2D` @00522d80). On cherche le site le plus
proche, puis on pondère chaque site par `1 − min(1, (d² − d²min)·5e-7)`.

### 2.5 Champ d'altitude (`World_baseHeightField` @004f9b70)

| octave | fréquence | amplitude | masque |
|---|---|---|---|
| continental A | 2e-4 | 200 | `ampLowA` × part de terre ferme |
| continental B | 2e-4 | 200 | `ampLowB` × part de terre ferme |
| médian A | 2e-3 | 100 | `ampMidA` × porte de chenaux × porte de détail |
| médian B | 2e-3 | 100 | `ampMidB` × porte de chenaux × porte de détail |
| détail | 1e-2 | 40 | `ampHigh` × porte de chenaux × porte de détail |

Les cinq masques valent `((bruit + 1)/2)²` aux fréquences 1e-4 (×2), 1e-3 (×2)
et 2e-3. Le carré biaise vers le bas : la majorité du monde reste plate, et les
massifs abrupts sont localisés. C'est le mécanisme central de la signature
visuelle de l'original.

Le mélange de sites fournit deux valeurs, avec un poids
`(1 − min(1, (d² − d²min)·5e-8))²` — dix fois plus large que le poids
climatique, donc un relief qui varie plus doucement que le climat :
l'altitude de base moyenne, et la « part de terre ferme » (fraction du poids
portée par les sites d'altitude positive), qui écrase le relief continental
au-dessus des océans.

### 2.6 Réseau de chenaux (`World_riverClimateGate` @0052cd50)

`|bruit(1e-3) + bruit(1e-2)·0,1|`, modulé par un bruit **sans graine** (donc
identique dans tous les mondes), puis passé dans `min(1, e·4)` et un smoothstep
cubique élevé au carré. Les zéros du bruit rectifié forment un réseau de lignes
continues : ce sont les vallées, où le détail est éteint.

### 2.7 Éléments de tuile (`World_generateRegionFeatures` @0050e080)

Chaque zone porte une grille 8 × 8 d'éléments de `0x68` octets, un par tuile de
2048 unités. Adressage (`World_getTileAtCoords` @004286f0) : tuile = `x >> 11`,
zone = tuile / 8, index dans la zone = `(tz % 8) + (tx % 8)·8`, tableau à
`+0x14018` de l'enregistrement de zone.

**Structure de l'élément**, reconstruite depuis les motifs d'écriture et de
lecture : `+0x00/+0x08` position en virgule fixe 16.16, `+0x10` rayon,
`+0x14` altitude échantillonnée au placement, `+0x18` type, `+0x1c` variante,
`+0x20` identifiant, `+0x24` palier, `+0x28` difficulté.

**Placement**, après `srand(graine + zz·1024 + zx)` :

1. la tuile qui contient le site de région reçoit d'office un **bourg**
   (type 1, rayon 512–711), posé sur le site lui-même puis rabattu à
   l'intérieur de sa tuile avec une marge de `rayon + 256` ;
2. toute autre tuile ne devient candidate que si son centre *et* la position
   tirée relèvent bien de ce site — c'est-à-dire si le site le plus proche du
   point déformé est celui de la zone ;
3. les candidats sont triés par « distance au bourg + bruit uniforme ±2 » ;
4. sur 64 itérations, les indices impairs sont sautés ; les indices valant
   2 mod 4 reçoivent le type 14 (agglomération, calée sur la grille de 256),
   ceux valant 0 mod 4 un type tiré parmi huit ;
5. jusqu'à cinq candidats restants deviennent des donjons (type 10).

**Le type 13 n'est jamais produit.** Le `switch(rand()%8)` ne rend que 2, 3,
4/15, 5, 6/15, 7/15, 11 et 12. Le piton est géré par le champ d'altitude mais
posé ailleurs — client, ou passe non identifiée. L'effet est porté quand même.

**Le type 1 n'est pas « les routes ».** Il y a un et un seul élément de type 1
par zone, et `World_roadField` ne rend une valeur non nulle que sur sa tuile. Ce
champ est donc l'aplanissement du bourg, pas un réseau de voies.

#### Récursion, et comment l'original la casse

L'altitude figée dans chaque élément vient de `World_baseHeightField`, qui relit
lui-même la grille d'éléments. L'original n'écrit le pointeur de zone qu'à la
**fin** de `World_generateRegionFeatures` : pendant la construction, la zone se
voit vide, donc l'altitude retenue est celle du terrain *sans* couche
d'éléments. Toutes les positions tirées restant dans leur propre tuile, aucune
zone n'en interroge une autre.

Ici, la même chose sur plusieurs fils : la zone n'est publiée qu'une fois
terminée, le fil constructeur la voit vide (garde de réentrance par identifiant
de fil), les autres attendent. Sans cette attente, une colonne échantillonnée
pendant la fenêtre de construction serait figée sans déformation dans le cache
de hauteurs, et le même monde ne se régénérerait pas à l'identique.

#### Effets sur l'altitude

`W` désigne le poids d'influence, soit un carré de distance normalisé : 0 au
centre, 1 au bord.

| type | effet |
|---|---|
| 1 | `roadField > 0,5` atténue le masque de détail ; puis les trois masques mid/high sont multipliés par `1 − (1−W)²/2` |
| 4 | `W < 0,25` : altitude remplacée, `H−50` au centre montant vers `H−25` ; `0,25 < W < 1` : raccord vers `H−25` |
| 6, 7 | même découpage, relatif au terrain : `−30` au centre, `+10` au bord, jamais sous l'altitude de base du site |
| 13 | `+150` sur le centième central, décrue en puissance quatre jusqu'au bord |
| tout type ≠ 0, 0xb | si le site le plus proche de l'élément est océanique, le terrain est **relevé** de son altitude de base (négative) sur `rayon + 256` : c'est ce qui fait émerger un îlot sous une structure tombée en mer |

**`World_objectFalloffWeight` (@0052c820)** :
`|p + déformation(p) − centre|² / rayon²`, déformation désactivée pour les types
0xb, 0xc et 0xe. Les arguments flottants de `ftol2` sont perdus, mais les
constantes en virgule fixe se recoupent exactement avec le terme de relèvement
océanique de `World_baseHeightField`, lui écrit en clair : `0x1617D0000 → 90493`,
`0xD5F0000 → 3423`, `0x700000 → 112`. D'où deux échantillons de bruit à
`f = 2,5e-3`, d'amplitude 100 unités, de graines (8433496, 90493) pour le
décalage en X et (3423, 112) pour celui en Z. Seule la graine X diffère entre les
deux emplacements, de 512 exactement — deux champs distincts, pas une erreur de
lecture.

Conséquence visible : le fond d'un cratère n'est pas au centre géométrique de
l'élément mais à une centaine d'unités de là, où le point déformé retombe sur le
centre. Les tests en tiennent compte.

#### Lacune assumée : le palier

L'original écrit `round(formula_inverse(i / 64))` dans `+0x24`, où
`formula_inverse` est un import non résolu du dépôt d'analyse. Pris à la lettre —
fonction identité — le palier vaudrait 0 ou 1, donc toujours sous le premier
seuil, et les quatre branches de difficulté (5 / 10 / 15 / 18) seraient mortes :
la lecture littérale est donc fausse. Le palier de zone (`World_featureTier`
@004d7870) est écrit par le générateur et jamais relu ailleurs, ce qui en fait
l'entrée la plus vraisemblable.

Substitut retenu : palier de zone + terme littéral. Le palier n'a aucun effet sur
l'altitude, mais il décide si la branche de difficulté consomme un tirage — donc
il décale la suite du flux. C'est une reconstruction, au même titre que les
décalages de bruit du monde.

### 2.8 Fonctions dont le portage est partiel ou différé

- **`World_biomeBorderDistance` (@00522840)** — distance au carré, en unités
  monde, entre le point déformé (±500) et les arêtes reliant le site courant à
  ses quatre voisins.

  **Défaut d'unités, corrigé.** Les deux termes qui consomment cette distance la
  comparent à des seuils de l'ordre de l'unité : `1 − d·0,75 > 0` pour la crête
  du champ de chenaux, `min(1, max(d, 0,02)·2)` pour la porte d'atténuation du
  détail. Avec un *carré* de distance en unités monde, ces seuils ne sont
  franchis que sur une bande de moins d'un bloc de large. Mesuré ici : la porte
  de détail creuse une tranchée d'**une seule colonne, 2,3 blocs de profondeur**,
  le long de chaque arête du graphe de sites — des lignes fines et parfaitement
  droites qui tranchent le paysage, traversant les frontières de biome. Le terme
  de crête, lui, est bien inerte : il ne déplace le champ de chenaux que de 0,48
  à 0,53, en deçà de la saturation.

  Ces artefacts sont désactivés par défaut (`site_edge_radius = 0`). Une valeur
  positive normalise la distance par `rayon²` et rend l'effet vraisemblablement
  voulu : une dépression large le long des lignes reliant les régions. À
  réévaluer avec la couche d'éléments de tuile, où les routes sont un type
  d'élément — ces arêtes sont peut-être leur tracé.

  Un test de non-régression balaie 3 000 colonnes consécutives : un artefact
  d'une colonne de large est invisible à tout pas d'échantillonnage plus grossier.
- **`World_waterDepthField` (@0052d990)** — malgré le nom proposé par l'audit,
  ne calcule pas une profondeur d'eau : c'est la porte d'aplanissement du
  détail, égale à la distance aux arêtes sauf au voisinage des agglomérations.
  `site_edge_radius` valant 0 par défaut, elle vaut « très grand », donc détail
  à pleine amplitude ; l'atténuation par le bourg passe désormais par
  `World_roadField`, portée (§2.7).
- **`World_waterProximityInfluence` (@00522e20)** — la structure du mélange est
  claire mais le champ effectivement sommé au numérateur est perdu (valeur de
  retour flottante en xmm0). Porté avec le drapeau marais, poids exposé et
  **désactivé par défaut** plutôt que deviné.
- **Contenu des éléments — différé au jalon 1.7.** Les types 2, 3, 5, 10, 11,
  12, 14 et 15 sont placés, typés et variantés par la couche portée ici, mais
  n'ont aucun effet visible : ce sont les ancres du contenu de biome
  (`WorldInfo_generateBiomeContent` @005e4850). Leurs tirages sont reproduits
  dans l'ordre pour ne pas décaler le flux aléatoire.

## 3. Mapping vers Godot / Voxel Tools 1.7

| système d'origine | équivalent porté |
|---|---|
| `valueNoise2D` | `CWValueNoise` (statique, hachage 32 bits émulé) |
| `rand()` de la CRT MSVC | `CWRand` |
| tableau de sites `+0x4000bc` | `CWRegionSiteGrid` (paresseux, mutex, cache de fenêtres 3 × 3) |
| grille d'éléments `+0x14018` | `CWTileFeatureGrid` (paresseux par zone, mutex, garde de réentrance) + `CWTileFeature` |
| mélanges climat + altitude | `CWTerrainField.sample_column` (une seule passe) |
| cache de colonnes 32 octets | cache de cartes de hauteurs par colonne de blocs, dans `CWVoxelGenerator` |
| remplissage de colonnes | `VoxelBuffer.fill_area` par intervalle |
| rendu en cubes | `VoxelMesherCubes` en mode `COLOR_MESHER_PALETTE` |

**Incompatibilité structurelle assumée.** L'original est mono-thread et
s'appuie sur un cache de colonnes persistant. Voxel Tools appelle
`_generate_block` depuis un pool de fils, sur des blocs cubiques, sans état
partagé. Le champ a donc été rendu purement fonctionnel (reentrant), et les
deux seuls caches sont protégés par mutex. Le cache de cartes de hauteurs est
indispensable et non optionnel : le monde monte à ~600 blocs, donc une même
colonne (x, z) est traversée par une quinzaine de blocs verticaux.

**GDScript et pas GDExtension, pour l'instant.** ~62 µs par colonne hors
influence d'un élément, ~75 µs dedans (deux échantillons de bruit de plus pour
la déformation du domaine), soit ~16 à 19 ms par bloc 16³ non caché, réparti sur
le pool de fils de Voxel Tools. La consultation de la grille d'éléments est
sortie de la boucle de colonnes dans `sample_patch` — une tuile fait 2048
unités, donc les 256 colonnes d'un bloc y tombent presque toujours ensemble :
le chemin de streaming ne paie pas la couche là où elle ne fait rien. C'est
suffisant pour la démonstration. Le portage en GDExtension C++ est le levier
évident si la distance de vue doit dépasser ~200 blocs, et le champ est écrit
pour être transposable ligne à ligne.

**`world_origin`.** Le point de départ de l'original se trouve vers 8,4 millions
d'unités. Les coordonnées Godot sont relatives à `CWWorldParams.world_origin` :
on joue au centre de la carte d'origine tout en gardant des coordonnées de scène
proches de zéro. Le décalage est appliqué dans `CWVoxelGenerator._get_patch` et
nulle part ailleurs.

## 4. Écarts assumés

1. **Palette de couleurs — remplacée délibérément.** La palette de Cube World
   relève de son expression artistique, pas de son algorithme. Aucune couleur
   n'est extraite du jeu. Seule la *règle* de sélection (surface pilotée par le
   climat mélangé et l'altitude relative) est portée ; les teintes de
   `CWPalette` sont originales.
2. **Indexation du réseau de bruit** par `floor` et non par troncature.
3. **Distances en flottant** là où l'original tronque les carrés de distance en
   entier avant de les pondérer. Écart imperceptible.
3 bis. **Termes liés aux arêtes du graphe de sites désactivés** par défaut : ils
   ne produisent qu'une tranchée d'une colonne de large, artefact d'unités et
   non relief. Voir §2.8.
4. **Bord du monde** : l'original abandonne le mélange et renvoie une valeur non
   initialisée si une case de la fenêtre 3 × 3 sort de la grille ; on ignore les
   cases manquantes et on renvoie un fond océanique.
5. **Décalages de bruit** dérivés de la graine par le même LCG. Leur séquence
   d'initialisation d'origine n'est pas récupérable, donc l'équivalence est
   structurelle, pas bit à bit.
6. **Mélange marais** désactivé par défaut (`swamp_channel_weight = 0`).
7. **Palier d'un élément** reconstruit : `formula_inverse` n'est pas résolue
   dans le dépôt d'analyse. Sans effet sur l'altitude, mais décale le flux
   aléatoire. Voir §2.7.
8. **Contenu des éléments** absent : les ancres sont posées et typées, rien
   n'est encore rendu dessus (jalon 1.7).

## 5. Validation

`godot --headless --path . -s tests/worldgen_test.gd` — 80 vérifications.

Verrous numériques : valeurs de référence de `lattice` et `sample` calculées
indépendamment sur l'arithmétique 32 bits du binaire, et séquence de référence
du LCG MSVC pour `srand(1)` (41, 18467, 6334, …). Si ces références bougent,
tous les mondes déjà générés changent.

Invariants vérifiés : site contenu dans sa propre zone et calé au centre de
tuile, climat dans [0, 1], plancher océanique à −100, zone de départ tempérée et
émergée, altitude finie et continue d'un bloc au suivant, coexistence terre/mer,
déterminisme entre instances, sensibilité à la graine, champ de chenaux positif
et modulé.

Pour la couche d'éléments (`tests/tile_features_test.gd`) : un bourg et un seul
par zone, sur la tuile de son site ; tout élément contenu dans sa tuile ;
adressage tuile → élément ; poids d'influence nul au centre et unitaire au bord
pour les types non déformés ; fond de cratère à `H−50` et bord à `H−25` ;
plancher de caldeira borné par le socle du site ; champ inchangé hors influence ;
et surtout **même monde depuis huit fils concurrents**, qui est le test de la
garde de réentrance.

Deux balayages denses, de 3 000 colonnes consécutives chacun, cherchent les
coutures d'une seule colonne de large — l'un sur le champ de base, l'autre en
travers d'un élément, dont les bords de masque sont exactement le genre
d'endroit où une discontinuité peut naître sans qu'aucun test clairsemé la voie.
Mesuré : 0,37 bloc de saut maximal sur le champ, 0,20 sur un cratère.

Aperçus PNG écrits dans `user://worldgen_preview/` (altitude, climat, chenaux)
au pas de 256 unités — trop grossier pour montrer un élément de 550 unités de
rayon. `tools/preview_features.gd` rend un gros plan ombré, avec et sans la
couche, autour d'un point donné. La carte climatique, elle, montre des régions
Voronoï à frontières déformées et à climats francs — la signature de la carte du
monde d'origine.

## 6. Suite

1. Contenu de biome : `WorldInfo_generateBiomeContent` (@005e4850) et
   `WorldInfo_scatterObjectsInArea` (@005f56c0) — végétation et dispersion.
2. Colonnes persistantes et édition en temps réel via `VoxelTool`.
3. Portage du champ en GDExtension si la distance de vue doit augmenter.
