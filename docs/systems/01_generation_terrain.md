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
chenaux en bruit rectifié qui aplatit les fonds de vallée. Aucune autre source
d'aléa n'intervient : tout le monde dérive d'une seule fonction de bruit et
d'un seul LCG.

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

### 2.7 Fonctions dont le portage est partiel ou différé

- **`World_objectFalloffWeight` (@0052c820)** — poids d'influence d'un élément
  de tuile : `|p + déformation(p) − centre|² / rayon²`, la déformation étant
  désactivée pour les types 0xb, 0xc et 0xe. L'amplitude exacte de la
  déformation est perdue (arguments flottants de `ftol2` non modélisés par
  Ghidra) ; par analogie avec le code inline de `World_baseHeightField`, elle
  vaut ~100 unités à la fréquence 2,5e-3.
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
  Sans la couche d'éléments de tuile, elle vaut « très grand », donc détail à
  pleine amplitude.
- **`World_waterProximityInfluence` (@00522e20)** — la structure du mélange est
  claire mais le champ effectivement sommé au numérateur est perdu (valeur de
  retour flottante en xmm0). Porté avec le drapeau marais, poids exposé et
  **désactivé par défaut** plutôt que deviné.
- **Couche « éléments de tuile » — non portée.** L'original place, par zone,
  une grille 8 × 8 d'éléments de 0x68 octets (`World_generateRegionFeatures`
  @0050e080) qui modifient localement l'altitude : type 1 aplanit (bourgs,
  routes), type 4 creuse un cratère à `H−50`, types 6 et 7 forment une caldeira
  à bord relevé, type 13 dresse un piton de +150. C'est la tranche suivante.

## 3. Mapping vers Godot / Voxel Tools 1.7

| système d'origine | équivalent porté |
|---|---|
| `valueNoise2D` | `CWValueNoise` (statique, hachage 32 bits émulé) |
| `rand()` de la CRT MSVC | `CWRand` |
| tableau de sites `+0x4000bc` | `CWRegionSiteGrid` (paresseux, mutex, cache de fenêtres 3 × 3) |
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

**GDScript et pas GDExtension, pour l'instant.** ~80 µs par colonne, soit ~20 ms
par bloc 16³ non caché, réparti sur le pool de fils de Voxel Tools. C'est
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
   non relief. Voir §2.7.
4. **Bord du monde** : l'original abandonne le mélange et renvoie une valeur non
   initialisée si une case de la fenêtre 3 × 3 sort de la grille ; on ignore les
   cases manquantes et on renvoie un fond océanique.
5. **Décalages de bruit** dérivés de la graine par le même LCG. Leur séquence
   d'initialisation d'origine n'est pas récupérable, donc l'équivalence est
   structurelle, pas bit à bit.
6. **Mélange marais** désactivé par défaut (`swamp_channel_weight = 0`).
7. **Couche d'éléments de tuile** absente : ni bourgs, ni cratères, ni pitons.

## 5. Validation

`godot --headless --path . -s tests/worldgen_test.gd` — 37 vérifications.

Verrous numériques : valeurs de référence de `lattice` et `sample` calculées
indépendamment sur l'arithmétique 32 bits du binaire, et séquence de référence
du LCG MSVC pour `srand(1)` (41, 18467, 6334, …). Si ces références bougent,
tous les mondes déjà générés changent.

Invariants vérifiés : site contenu dans sa propre zone et calé au centre de
tuile, climat dans [0, 1], plancher océanique à −100, zone de départ tempérée et
émergée, altitude finie et continue d'un bloc au suivant, coexistence terre/mer,
déterminisme entre instances, sensibilité à la graine, champ de chenaux positif
et modulé.

Aperçus PNG écrits dans `user://worldgen_preview/` (altitude, climat, chenaux).
La carte climatique montre des régions Voronoï à frontières déformées et à
climats francs — la signature de la carte du monde d'origine.

## 6. Suite

1. Couche d'éléments de tuile (grille 8 × 8 par zone) : aplanissement des
   bourgs, cratères, caldeiras, pitons. Débloque aussi la porte de détail
   complète et le champ de routes.
2. Contenu de biome : `WorldInfo_generateBiomeContent` (@005e4850) et
   `WorldInfo_scatterObjectsInArea` (@005f56c0) — végétation et dispersion.
3. Colonnes persistantes et édition en temps réel via `VoxelTool`.
4. Portage du champ en GDExtension si la distance de vue doit augmenter.
