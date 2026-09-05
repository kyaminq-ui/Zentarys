# Modèles voxels Zentarys — convention et échelle

À lire avant de modéliser quoi que ce soit. La liste de ce qu'il faut produire
est dans `nextsteps.md`, §8.2 ; ce fichier dit *à quelle taille* et *avec quelles
couleurs*.

---

## 1. L'échelle de référence — fixée le 2026-09-04, alignée sur l'original le 2026-09-05

**Il y a deux grilles, pas une.**

| grille | pas | ce qu'elle porte |
|---|---|---|
| **terrain** | 1 bloc | le relief, la roche, l'eau, les arbres, les maisons |
| **modèles** | **3/40 de bloc** | le personnage, les créatures, la flore, le mobilier, les objets |

**Un bloc de terrain vaut 40/3 voxels de modèle — autrement dit 3 blocs valent
exactement 40 voxels.** Le personnage de référence mesure **32 voxels**, soit
2,4 blocs.

> **La référence à poser dans MagicaVoxel est un cube de 40, pas de 13.** Un bloc
> ne tombe pas sur un nombre entier de voxels : c'est le prix de la fidélité au
> rapport de l'original. Un cube de 40 à côté du modèle vaut trois blocs de
> terrain, et une silhouette de 32 vaut le personnage.

C'est de là que vient tout le reste, et c'est ce qui sépare ce rendu de celui de
Minecraft : le terrain est fait de gros cubes, mais ce qui est posé dessus est
treize fois plus fin. Une touffe d'herbe n'est pas un cube vert, c'est une dizaine
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
sont sur la *même* grille fine. Le rapport mesuré est de **~13 voxels par bloc**.

### La valeur exacte, relevée dans le binaire le 2026-09-05

La mesure au pixel ci-dessus a été **confirmée par une constante de l'original**,
par un chemin entièrement différent : les échelles d'instanciation du décor y
valent 0,075, 0,09 et 0,1, et **0,075 = 3/40 exactement**, soit 13,333 voxels par
bloc. La mesure à l'œil était juste.

Le projet a donc quitté 16 pour **40/3** (`docs/systems/02`, §8.3). Ce qu'il faut
en savoir en dessinant :

- **écrire la fraction, jamais 13.333**, qui dérive ;
- l'original n'a pas *un* rapport global — 0,075 est le plus courant de ses trois
  échelles de décor. L'adopter comme contrat unique est un choix, pas une
  transcription ;
- ce qu'on perd en passant de 16 à 40/3 : les réductions de LOD ne tombent plus
  sur une puissance de deux. `CWVoxelModel.reduced(n)` travaille en voxels et
  reste exacte ; c'est seulement le rapport au bloc qui n'est plus dyadique ;
- ce qu'on gagne : un modèle de 32 voxels fait 2,4 blocs, ce qui recoupe les
  **2,3 blocs mesurés** sur la capture. À 16 il en faisait 2,0.

> **À revoir au jalon 3.1.** Quand le contrôleur de joueur sera porté, la taille
> exacte du personnage sortira de la physique d'origine. Si elle s'écarte de 2
> blocs, c'est ce seul nombre qui change, et toutes les tailles ci-dessous se
> remettent à l'échelle avec lui. Le rapport de 40/3, lui, est un contrat
> d'authoring : le changer redimensionne tous les modèles déjà dessinés.

### Repères dérivés

En **voxels de modèle** — c'est l'unité dans laquelle on dessine :

> ⚠️ **Les repères ci-dessous sont faux d'un facteur ~2,5 pour ce qui pousse au
> sol, et c'est de là que vient tout le lot de flore.** Constaté le 2026-09-05
> au soir sur des captures du jeu d'origine, le personnage servant de règle :
> une touffe d'herbe y monte **à l'épaule**, pas au genou. La colonne « corrigé »
> donne la cible ; les valeurs d'origine sont laissées barrées, parce qu'elles
> expliquent la taille des 39 modèles livrés. Détail et méthode :
> `nextsteps.md`, §6.5.

| élément | hauteur | corrigé | empreinte |
|---|---|---|---|
| personnage de référence | **32** | — | 12 × 8 |
| herbe, brins | ~~8 – 12~~ | **27 – 30** | ≤ 20 × 20 |
| plante haute (fougère, pousse) | — | **45 – 52** | ≤ 20 × 20 |
| fleur de champ dispersée | ~~8 – 14~~ | **5 – 9** | ≤ 8 × 8 |
| grande fleur (tournesol) | 14 – 20 | **26 – 32** | ≤ 14 × 14 |
| champignon | 5 – 10 | — | ≤ 10 × 10 |
| caillou | ~~4 – 8~~ | **30 – 40** | ≤ 40 × 40 |
| buisson, broussaille, roseau, algue, corail | 16 – 28 | **16 – 22** | ≤ 32 × 32 |
| cactus, grès | 32 – 56 | — | ≤ 48 × 48 |

Et en **blocs**, pour situer ça dans le monde généré :

| élément | hauteur |
|---|---|
| personnage | 2,4 |
| touffe d'herbe | ~~0,6 – 0,9 (au genou)~~ → **2,0 – 2,3 (à l'épaule)** |
| plante haute | **3,4 – 3,9** |
| caillou | ~~0,3 – 0,6~~ → **2,3 – 3,0** (un bloc erratique, pas un galet) |
| buisson | **1,2 – 1,7** |
| cactus | 2,4 – 4,2 |
| cratère porté par un élément de tuile | 50 de creux |
| piton | 150 |
| montagnes du monde généré | jusqu'à ~600 |

### Ce que MagicaVoxel ne sait pas faire, et pourquoi ça ne gêne pas

On ne peut pas y réduire le pinceau sous un voxel — et il n'y en a pas besoin.
La grille de MagicaVoxel est **sans unité** : on ne descend pas sous le voxel, on
agrandit la boîte. Le personnage de référence se dessine dans un gabarit de 32
de haut, et c'est le moteur qui applique le 3/40 à l'import.

Pour garder l'œil juste pendant qu'on modélise, poser dans la scène un cube de
**40 × 40 × 40** (= trois blocs de terrain, cf. §1 : un bloc seul ne tombe pas
sur un nombre entier de voxels) et une silhouette de 32 de haut (= le
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
chargé, par rangées de dix devant les mires. Ajouter le `.vox` à la table de
`CWModelLibrary.FLORA` suffit à le faire apparaître.

Le résultat est dans `docs/images/` : `echelle_gabarit.png` montre les mires de
1 à 16 blocs, la silhouette et les trente-neuf modèles du premier lot — le
personnage tombe exactement sur la mire de 2 ; `echelle_gros_plan.png` cadre les
modèles contre la silhouette, les touffes d'herbe au genou, le grand cactus au
dessus de la tête. Ces deux images sont la référence : si une modification les
invalide, c'est qu'elle a changé l'échelle.

---

## 2. Couleurs

Une seule palette de 256 entrées sert au terrain **et** aux modèles : le rendu
stocke un index par voxel, pas une couleur. Un modèle peint ailleurs arrive avec
des couleurs fausses, sans le moindre message d'erreur.

**Ouvrir `assets/palette/zentarys_palette.vox` dans MagicaVoxel**, et modéliser
dans ce fichier ou copier sa palette. C'est le seul geste qui aligne les index —
et c'est l'index, jamais la couleur, que le rendu lit.

> **Ne pas glisser `zentarys_palette_ref.png` sur le nuancier.** MagicaVoxel
> rééchantillonne la planche et rend une palette où chaque couleur apparaît deux
> fois, la vraie puis la même assombrie, dans un ordre décalé. Les teintes ont
> l'air justes, les index ne le sont pas, et rien ne le signale avant l'écran.
> C'est ce qui est arrivé au premier lot ; le détail est dans `PALETTE.md`.

Plages réservées, détail dans `assets/palette/PALETTE.md`. Pour la flore :

* **Végétation, indices 128 – 175** — feuillages, automne, écorces, fleurs,
  champignons, algues et coraux, cactus ;
* **Terrain, indices 1 – 40** — pour tout ce qui est minéral : cailloux, grès,
  basalte. Les entrées 14 – 31 sont là pour ça ; 1 – 13 sont les blocs que le
  générateur écrit lui-même, et 32 – 40 les neuf filons, réservés au lot qui
  s'estampe.

L'index **0 est l'air** et ne peut pas servir.

Un modèle déjà peint dans une autre palette n'est pas perdu :

```
godot --headless --path . -s tools/repaint_models.gd            # rapport
godot --headless --path . -s tools/repaint_models.gd -- --write  # applique
```

L'outil relit la couleur que le fichier associe à chacun de ses index, cherche la
plus proche parmi celles que la flore a le droit d'employer, et réécrit les
index **et** la palette embarquée. Rouvert dans MagicaVoxel, le modèle porte
alors la bonne palette. Il ne touche à aucun voxel : seule la couleur change.

Vérification :

```
godot.windows.editor.double.x86_64.exe --headless --path . -s tools/inspect_model.gd
```

Sans argument, l'outil passe en revue tout `assets/models/` : dimensions de la
matière en voxels **et en blocs**, nombre de voxels pleins, index employés, et il
signale tout index sorti des plages autorisées.

---

## 3. Fichiers

* **Un dossier par biome** sous `assets/models/flore/` : `herbe/`,
  `herbe_seche/`, `jungle/`, `marais/`, `sable_desert/`, `neige/`, `toundra/`,
  `roche/`, `gravier_fond_marin/`. `assets/models/culture/` pour les cinq
  cultures. **`assets/models/arbres/`** suit le même découpage pour la grande
  végétation — c'est un lot à part, avec sa propre enveloppe (§ ci-dessous) et
  son propre script.
* Noms en minuscules sans accent, souligné pour séparer, variante numérotée sur
  deux chiffres quand les modèles sont interchangeables : `herbe_01`,
  `fleur_bleuet`, `caillou_02`. Rien d'autre dans le nom — ni la taille du
  gabarit, ni le biome, qui est déjà le dossier.
* **Un même rôle peut avoir un modèle par biome.** `caillou_01` existe trois
  fois — prairie, neige, roche — et ce sont trois modèles, chacun dans les
  teintes de son biome. C'est le lot livré le 2026-09-05 qui en a décidé ainsi,
  et c'est mieux qu'un fichier partagé. Deux biomes peuvent quand même pointer le
  même chemin dans `CWModelLibrary.FLORA` : le modèle n'est alors chargé et
  maillé qu'une fois.
* Le fichier doit figurer dans la table de `CWModelLibrary.FLORA`, chemin
  complet, biome compris : `"herbe/herbe_01"`. Un test vérifie que chaque entrée
  de la table existe sur le disque.
* **Les trente-neuf modèles de flore sont produits par script**, pas dessinés à
  la main : `tools/blender/generer_flore.py`, une graine en dur par fichier. Une
  retouche faite dans MagicaVoxel serait écrasée à la prochaine génération —
  corriger le générateur, puis regénérer :

  ```
  blender --background --factory-startup --python tools/blender/generer_flore.py
  #  -- --seul <nom>  pour ne refaire qu'un fichier
  ```

  Le script recopie le bloc `RGBA` de la palette de projet tel quel et refuse à
  l'écriture tout index hors des plages autorisées : c'est là que se rattrape la
  faute de palette du premier lot. Le reste de ce fichier reste la référence
  pour les modèles qui, eux, se dessinent à la main.
* **Les quatorze modèles d'arbres le sont aussi**, par le même chemin et les
  mêmes garde-fous : `tools/blender/generer_arbres.py`, commande en
  `docs/prompt_generation_arbres.md`.

  ```
  blender --background --factory-startup --python tools/blender/generer_arbres.py
  ```

  Deux choses seulement les séparent de la flore. **L'enveloppe** : un arbre ne
  tient pas sous les 53 voxels de la flore basse, donc `flore_vox.ecris` reçoit
  un plafond par classe — arbre entier 160 voxels, houppier 80, palme 60. **La
  façon dont ils se posent** : un *arbre entier* commence sa matière en Z = 0
  comme une plante, un *houppier* est une couronne **sans pied**, dont la base
  vient se poser sur le sommet d'un tronc, et une *palme* est une fronde seule,
  ancrée par son point d'attache. Ne dessiner ni socle ni tronc sous un
  houppier : il flotterait ou doublerait le tronc.

  La plage des index, elle, ne se paramètre pas et n'a pas bougé. Le lot
  emploie en plus la rampe **148 – 155**, celle des troncs et de l'écorce, qui
  n'avait aucun usage dans la flore.
* Gabarit du `.vox` : **libre**, le plus juste possible autour de la matière.
  16³ suffit à presque tout ; un cactus de 3,5 blocs demande 48³. La matière est
  extraite au chargement et le vide jeté, donc un tampon large ne coûte rien —
  il rend seulement la relecture pénible. Ce qui est un contrat, c'est le rapport
  de **40/3 voxels par bloc**, pas la taille de la boîte.

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
treize fois trop gros. Il est maillé une fois (`VoxelMesherCubes`, la même
palette et le même matériau que le terrain, donc le même aspect), puis instancié
à l'échelle 3/40. La flore passe par un `MultiMeshInstance3D` par modèle et par
cellule de dispersion.

Conséquences à connaître :

* un modèle fin **ne se creuse pas** et ne participe pas à l'éclairage voxel ;
* il **n'a pas de collision** — la flore est décorative ;
* il disparaît au-delà d'une distance réglée (`CWFloraRenderer.view_distance`),
  comme dans l'original.

Un modèle destiné à *faire partie du terrain* — un bloc de minerai, un rocher
qu'on doit pouvoir miner — est un cas différent : celui-là se dessine à
**1 voxel = 1 bloc** et s'estampe. **Les neuf filons sont les premiers**, livrés
le 2026-09-05 sous `assets/models/filons/` par
`tools/blender/generer_filons.py` (Python pur : à un voxel par bloc, un filon
fait quatre voxels de large, Blender n'y apporterait rien).

Ce lot suit des règles à lui, et il faut les tenir séparées de celles ci-dessus :

* **1 voxel = 1 bloc**, pas 40/3 ;
* chacun de ses voxels est un **type de bloc**. C'est `CHANNEL_TYPE` qui portera
  cette valeur à l'estampage, et c'est elle qui dira ce que le bloc rend quand on
  le casse ;
* d'où une contrainte d'index plus étroite que celle de la flore
  (`flore_vox.INDEX_FILONS`) : roche (1), roche nue (14 – 19) et les neuf entrées
  de filon (32 – 40), rien d'autre. Un filon n'a pas droit au feuillage.

Les neuf entrées 32 – 40 ont demandé de déplacer `RANGE_TERRAIN_END` de 31 à 40 :
raisonnement complet dans `assets/palette/PALETTE.md` et dans l'en-tête de
`CWPalette`. **La couche qui les pose n'existe pas encore** — elle appartient à
la voie des entités, avec les points d'apparition du jalon 2.6. `CWPalette.roll_ore`
porte déjà le tirage de rareté, qui est la seule partie que la source donne
littéralement.

---

## 4. Ce qui n'est pas un modèle

* ~~**Les arbres.**~~ **Faux — corrigé le 2026-09-05.** Cette ligne disait
  qu'aucun arbre n'était un modèle et qu'il y avait un algorithme à porter. Le
  décompte de 154 modèles était lui-même faux : l'original en charge **2 449**.
  Le vrai partage, établi en `docs/systems/02` §5.2, est plus fin :
  * le **conifère** (`fir-tree`, code 129) et l'**arbre à épines**
    (`thorn-tree`, code 130, boîte 3 × 3 × 12 blocs) sont des **modèles
    entiers** ;
  * le **houppier** (`tree-leaves`, code 143) est un modèle **posé
    séparément** ; le **feuillu** et le **palmier** sont donc des assemblages —
    un tronc, puis des houppiers ou des palmes ;
  * seul le **tronc** est procédural : il n'existe aucun modèle de tronc, et
    l'original a la primitive pour l'écrire en colonnes de blocs.

  À dessiner, donc, sauf le tronc. **Dessinés le 2026-09-05** : quatorze
  modèles sous `assets/models/arbres/`, commande en
  `docs/prompt_generation_arbres.md`. Le tronc, lui, a fini avec **deux formes**
  — `tronc_feuillu` et `tronc_palmier` existent comme modèles instanciables, à
  côté de la colonne de blocs que l'assemblage écrira dans le terrain. Les deux
  ne s'excluent pas : la matière là où il faut la creuser, le modèle pour le
  bosquet lointain et la réduction de niveau de détail.
* **Les maisons.** Une grille de 3 × 3 × 4 cellules remplie procéduralement. Ce
  sont les *meubles* qui sont des modèles, pas le bâtiment.
