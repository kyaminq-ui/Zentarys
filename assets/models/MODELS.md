# Modèles voxels Zentarys — convention et échelle

À lire avant de modéliser quoi que ce soit. La liste de ce qu'il faut produire
est dans `nextsteps.md`, §7.2 ; ce fichier dit *à quelle taille* et *avec quelles
couleurs*.

---

## 1. L'échelle de référence — fixée le 2026-09-04

**Il y a deux grilles, pas une.**

| grille | pas | ce qu'elle porte |
|---|---|---|
| **terrain** | 1 bloc | le relief, la roche, l'eau, les arbres, les maisons |
| **modèles** | **1/16 de bloc** | le personnage, les créatures, la flore, le mobilier, les objets |

**Un bloc de terrain vaut 16 voxels de modèle. Le personnage de référence mesure
2 blocs, soit 32 voxels.**

C'est de là que vient tout le reste, et c'est ce qui sépare ce rendu de celui de
Minecraft : le terrain est fait de gros cubes, mais ce qui est posé dessus est
seize fois plus fin. Une touffe d'herbe n'est pas un cube vert, c'est une dizaine
de lames d'un voxel d'épaisseur. Un personnage n'est pas six pavés, il a des yeux
d'un voxel.

### D'où sort le nombre

D'une mesure au pixel sur une capture du jeu d'origine, pas d'un jugement à l'œil
ni d'une décompilation — le binaire ne dit nulle part combien de blocs fait un
personnage.

| mesure sur la capture | pixels | en voxels | en blocs |
|---|---|---|---|
| brin d'herbe (largeur) | 7 | 1 | 1/13 |
| pupille du personnage | 6 | 1 | 1/13 |
| écart entre les yeux | 28 | 4 | 0,3 |
| chapeau de champignon | 30 | 4–5 | 0,33 |
| touffe d'herbe (largeur) | 80 | 11 | 0,9 |
| **hauteur du personnage** | **205** | **~29** | **2,3** |
| **face verticale d'une marche de terrain** | **90** | **~13** | **1** |

Le brin d'herbe et la pupille font la même largeur : la flore et le personnage
sont sur la *même* grille fine. Le rapport mesuré est de ~13 voxels par bloc ;
on retient **16**, la puissance de deux la plus proche — les réductions de LOD y
sont exactes, et le budget de détail y est un peu plus large.

> **À revoir au jalon 3.1.** Quand le contrôleur de joueur sera porté, la taille
> exacte du personnage sortira de la physique d'origine. Si elle s'écarte de 2
> blocs, c'est ce seul nombre qui change, et toutes les tailles ci-dessous se
> remettent à l'échelle avec lui. Le rapport de 16, lui, est un contrat
> d'authoring : le changer invalide tous les modèles déjà dessinés.

### Repères dérivés

En **voxels de modèle** — c'est l'unité dans laquelle on dessine :

| élément | hauteur | empreinte |
|---|---|---|
| personnage de référence | **32** | 12 × 8 |
| herbe, brins | 8 – 12 | ≤ 14 × 14 |
| fleur | 8 – 14 | ≤ 12 × 12 |
| champignon | 5 – 10 | ≤ 10 × 10 |
| caillou | 4 – 8 | ≤ 12 × 12 |
| buisson, broussaille, roseau, algue, corail | 16 – 28 | ≤ 32 × 32 |
| cactus, grès | 32 – 56 | ≤ 32 × 32 |

Et en **blocs**, pour situer ça dans le monde généré :

| élément | hauteur |
|---|---|
| personnage | 2 |
| touffe d'herbe | 0,5 – 0,75 (au genou) |
| buisson | 1 – 1,75 |
| cactus | 2 – 3,5 |
| cratère porté par un élément de tuile | 50 de creux |
| piton | 150 |
| montagnes du monde généré | jusqu'à ~600 |

### Ce que MagicaVoxel ne sait pas faire, et pourquoi ça ne gêne pas

On ne peut pas y réduire le pinceau sous un voxel — et il n'y en a pas besoin.
La grille de MagicaVoxel est **sans unité** : on ne descend pas sous le voxel, on
agrandit la boîte. Un personnage de 2 blocs se dessine dans un gabarit de 32 de
haut, et c'est le moteur qui applique le 1/16 à l'import.

Pour garder l'œil juste pendant qu'on modélise, poser dans la scène un cube de
16 × 16 × 16 (= un bloc de terrain) et une silhouette de 32 de haut (= le
personnage). C'est ça qui remplace le réglage de taille du pinceau.

### Revoir l'échelle soi-même

```
# Dans scenes/terrain_demo.tscn, mettre scale_board = true sur le noeud racine
godot.windows.editor.double.x86_64.exe --path . scenes/terrain_demo.tscn
```

La démo pose le gabarit devant le point d'apparition, cadre dessus, et écrit
deux captures dans `user://shots` (vue d'ensemble, puis gros plan). **F12**
capture à tout moment. Le gabarit montre des mires de hauteur connue **en
blocs**, la silhouette du personnage **à la grille fine**, puis chaque modèle
chargé. Poser un nouveau `.vox` dans `assets/models/flore/` suffit à le faire
apparaître — rien d'autre à déclarer.

Le résultat est dans `docs/images/` : `echelle_gabarit.png` montre les mires de
1 à 16 blocs, la silhouette et `herbe_01` alignés — le personnage tombe
exactement sur la mire de 2 ; `echelle_gros_plan.png` cadre la silhouette et sa
touffe d'herbe, qui lui arrive au genou. Ces deux images sont la référence :
si une modification les invalide, c'est qu'elle a changé l'échelle.

---

## 2. Couleurs

Une seule palette de 256 entrées sert au terrain **et** aux modèles : le rendu
stocke un index par voxel, pas une couleur. Un modèle peint ailleurs arrive avec
des couleurs fausses, sans le moindre message d'erreur.

Charger `assets/palette/zentarys_palette.png` dans MagicaVoxel (glisser sur la
palette), plages réservées dans `assets/palette/PALETTE.md`. Pour la flore :

* **Végétation, indices 128 – 175** — feuillages, automne, écorces, fleurs,
  champignons, cactus ;
* **Terrain, indices 1 – 31** — pour les cailloux et le grès seulement.

L'index **0 est l'air** et ne peut pas servir.

Vérification :

```
godot.windows.editor.double.x86_64.exe --headless --path . -s tools/inspect_model.gd
```

Sans argument, l'outil passe en revue tout `assets/models/` : dimensions de la
matière en voxels **et en blocs**, nombre de voxels pleins, index employés, et il
signale tout index sorti des plages autorisées.

---

## 3. Fichiers

* Dossier `assets/models/flore/`, un `.vox` par entrée de la liste de
  `nextsteps.md`, §7.2 ; `assets/models/culture/` pour les cinq cultures.
* Noms en minuscules sans accent, souligné pour séparer, variante numérotée sur
  deux chiffres quand les modèles sont interchangeables : `herbe_01`,
  `fleur_bleuet`, `caillou_02`.
* Un même fichier sert plusieurs biomes — on ne le produit qu'une fois.
* Gabarit du `.vox` : le plus juste possible autour de la matière. Un tampon de
  40³ pour une plante de 10 ne coûte rien au chargement — la matière est extraite
  et le vide jeté — mais il rend la relecture pénible.

### Orientation

`VoxelVoxLoader` permute les axes : `vox(x, y, z) -> godot(y, z, x)`. Le haut
reste le haut (vox Z → godot Y) ; le plan horizontal est échangé. Sans compenser,
un modèle qui a un « devant » se retrouve tourné d'un quart de tour — sans
conséquence pour une touffe d'herbe, mais pas pour un meuble.

De toute façon la dispersion applique un quart de tour aléatoire à chaque
plante : pour la flore, l'orientation d'origine n'a pas d'importance.

### Ce qui se pose sur le sol

Le modèle est posé par sa **base** et par le **centre de son empreinte** :
l'ancre est au milieu du gabarit en X et Z, et au premier voxel plein en Y.
Modéliser la plante posée à même le fond de la boîte, centrée — pas de socle
vide sous elle, pas de décalage sur le côté.

### Comment le modèle arrive en jeu

Un modèle fin n'est **pas** écrit dans les données voxels du monde : il y serait
seize fois trop gros. Il est maillé une fois (`VoxelMesherCubes`, la même palette
et le même matériau que le terrain, donc le même aspect), puis instancié à
l'échelle 1/16. La flore passe par un `MultiMeshInstance3D` par modèle et par
cellule de dispersion.

Conséquences à connaître :

* un modèle fin **ne se creuse pas** et ne participe pas à l'éclairage voxel ;
* il **n'a pas de collision** — la flore est décorative ;
* il disparaît au-delà d'une distance réglée (`CWFloraRenderer.view_distance`),
  comme dans l'original.

Un modèle destiné à *faire partie du terrain* — un bloc de minerai, un rocher
qu'on doit pouvoir miner — est un cas différent : celui-là se dessine à
**1 voxel = 1 bloc** et s'estampe. Il n'y en a aucun pour l'instant.

---

## 4. Ce qui n'est pas un modèle

* **Les arbres.** Aucun modèle d'arbre parmi les 154 chargés par l'original :
  ils sont construits par le code, à l'échelle du terrain. Algorithme à porter,
  pas modèle à dessiner.
* **Les maisons.** Une grille de 3 × 3 × 4 cellules remplie procéduralement. Ce
  sont les *meubles* qui sont des modèles, pas le bâtiment.
