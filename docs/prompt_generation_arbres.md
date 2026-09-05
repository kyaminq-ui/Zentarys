# Prompt — génération du lot d'arbres, à la maille du bloc

Document à donner tel quel à un agent. Il est autoportant, et il suit le même
chemin que `docs/prompt_generation_flore.md`, qui a produit les 43 modèles de
flore basse : un document de commande, un script Python déterministe, une graine
en dur par fichier, le lot se régénère à l'identique.

**Lis d'abord `docs/prompt_generation_flore.md`.** La section 2 (orientation et
ancrage) et la section 3 (l'écrivain `.vox`) s'appliquent **mot pour mot** et ne
sont pas répétées ici. Ce document ne dit que ce qui **change** pour les arbres —
et ce qui change en premier, c'est **la grille de dessin**.

> **Ce document a été réécrit le 2026-09-06.** La version précédente commandait
> quatorze modèles à 40/3 voxels par bloc, et ce lot-là était faux sur trois
> points à la fois : deux à trois fois trop petit, ses houppiers trois fois trop
> étroits et de la mauvaise proportion, et son grain sept à treize fois trop
> fin. Raisonnement complet dans `nextsteps.md`, §6.

---

## Le prompt

> Tu produis **24 fichiers `.vox`** d'arbres, de houppiers et de palmes pour
> Zentarys, sous `assets/models/arbres/`. Tu travailles **en Python pur** :
> l'écrivain `.vox` de `tools/blender/flore_vox.py` pour la sortie, et
> `tools/blender/arbres_blocs.py` pour les formes. **N'emploie pas Blender** :
> à un voxel par bloc, une métaballe échantillonnée rend un tas de cubes, autant
> les poser directement.
>
> Le dépôt est en `C:\Users\Admin\Documents\zentarys`.

### 1. Ce qui change par rapport à la flore

**1.1 — L'échelle n'est pas la même, et c'est le point central.**

**Un voxel d'arbre vaut un bloc de terrain**, là où un voxel de flore en vaut
3/40. Le personnage fait 2,4 blocs, donc 2,4 voxels dans ce lot.

C'est la correction du 2026-09-06, et elle a deux appuis plus solides que
l'œil. La **provenance de l'échelle fine** : `0,075 = 3/40` est relevée dans la
voie du *décor* du binaire, et **aucune échelle n'a jamais été relevée dans la
voie des *entités***, par où passent les arbres. L'**argument structurel** : la
source écrit le tronc d'un feuillu dans le terrain, en colonnes de blocs, et
instancie le houppier séparément ; ces deux moitiés ne se rejoignent proprement
que si le houppier est sur la grille du bloc. Les captures du jeu d'origine
disent la même chose par un troisième chemin : les cubes de feuillage y lisent à
la taille des blocs de terrain.

**Conséquence d'authoring : une constante est une mesure.** « Houppier de 15 »
veut dire quinze blocs de large, soit six fois le personnage. Il n'y a plus de
conversion à faire de tête, et c'est ce qui rend ce lot beaucoup plus simple à
juger que le précédent.

Enveloppes, en blocs, verrouillées par `tests/tree_test.gd` **et** par le
générateur — les deux disent le même nombre :

| classe | hauteur | rayon | remarque |
|---|---|---|---|
| arbre entier, fût | ≤ 34 | ≤ 12 | l'arbre géant est le seul à monter si haut |
| houppier | ≤ 12 | ≤ 11 | et **plus large que haut**, d'un facteur 1,4 au moins |
| palme | ≤ 8 | ≤ 10 | une **paire** de frondes, voir 1.2 |

Et un plancher, qui est le défaut inverse et celui qui a coûté le lot précédent :
**aucune espèce n'a un fût de moins de 8 blocs.** Sur les captures, un arbre fait
six à dix fois le personnage.

**1.2 — Il y a trois sortes d'objets dans ce lot, et elles ne se posent pas
pareil.**

C'est le résultat d'analyse qui a ouvert ce jalon (`docs/systems/02`, §5.2) :

- le **conifère** et l'**arbre à épines** de l'original sont des **modèles
  entiers**, posés en une fois au sol ;
- le **houppier** (`tree-leaves`) porte son propre code d'entité : il est posé
  **séparément**, au-dessus d'un tronc. Il n'existe aucun modèle de tronc dans
  le corpus — le tronc est écrit dans le terrain, en colonnes de blocs ;
- la **palme** coiffe un stipe.

Donc : un **arbre entier** commence sa matière en Z = 0, comme une plante. Un
**houppier** est une couronne qui n'a **pas de tronc** — ne dessine pas de pied
sous lui, il flotterait de la hauteur du pied ou doublerait le tronc.

**Et une palme est une *paire de frondes opposées*, pas une fronde seule.**
L'ancre d'un modèle est le **centre de son gabarit** et non son point d'attache :
une fronde unique se poserait au sommet du stipe par son milieu, la moitié
passant de l'autre côté du tronc. Une paire est centrée sur son attache par
construction. En contrepartie, une paire tournée d'un demi-tour est identique à
elle-même — l'assembleur en tient compte, mais si tu changes le dessin, garde la
symétrie centrale.

**1.3 — Les formes sont à repenser, pas à réduire.**

C'est le piège de ce lot. Réduire d'un facteur treize les formes de la grille
fine donne des moignons : les folioles de palme, les rameaux de conifère et les
pousses de houppier sont écrits pour du détail d'un voxel. À la maille du bloc :

- un **conifère** est une **pile de disques plats** d'un bloc d'épaisseur,
  larges à la base, plus une flèche au sommet. C'est cette superposition qui fait
  la silhouette sur les captures, pas des rameaux ;
- un **houppier** est un **dôme en parasol**, quelques dizaines de cubes, au bord
  mangé irrégulièrement et légèrement creusé dessous — c'est ce qu'on voit d'en
  bas en marchant sous l'arbre ;
- un **fût** est une colonne de un à trois blocs de section, dessinée **presque
  d'aplomb** : l'ancre étant le centre du gabarit, un fût franchement penché se
  poserait à côté de sa propre colonne.

Le générateur en sort **plus simple**, pas plus compliqué : le conifère tient en
dix lignes là où la version fine en demandait cinquante.

### 2. Ce qu'il faut produire

Un dossier par biome sous `assets/models/arbres/`, et ce sont les **six biomes**
de `CWBiome`. Mêmes conventions de nommage que la flore : minuscules sans accent,
le nom ne porte ni le biome — c'est le dossier — ni la taille.

| dossier | fichiers | dimensions visées (blocs) | teintes |
|---|---|---|---|
| `greenlands/` | `chene_tronc` | 4 × 12 | écorce 149 – 153 |
| | `chene_houppier_01` `_02` | 12 – 16 large × 5 – 7 | feuillage 128 – 138 |
| | `bouleau_tronc` | 3 × 14 | écorce **claire** 14 – 16, marques 152 |
| | `bouleau_houppier` | 12 – 13 × 5 – 6 | feuilles lime 128 – 131 |
| | `pin` | 9 × 22, six plateaux | 133 – 139, écorce 150 – 154 |
| | `rocher_geant` | 12 × 12 | roche 15 – 19, lichen 28 – 29 |
| | `arbre_geant_tronc` | 9 × 22 + contreforts | écorce 148 – 153 |
| | `arbre_geant_houppier` | 20 – 22 × 8 – 9 | feuillage 128 – 137 |
| `snowlands/` | `pin_enneige` | 11 × 22 | 134 – 139 + neige 14 – 15 |
| | `sapin_enneige` | 9 × 19, sept étages | 135 – 139 + neige |
| | `bouleau_givre_tronc` | 3 × 12 | 14 – 16, marques 153 |
| | `bouleau_givre_houppier` | 11 – 12 × 6 – 7 | **136 – 139**, pas d'orange |
| `deserts/` | `cactus_geant` | 5 – 7 × 10 | cactus 172 – 175 |
| | `palmier_tronc` | 3 – 4 × 14 | écorce 150 – 153 |
| | `palme` `palme_diagonale` | 13 – 17 × 3 | 133 – 139 |
| `jungles/` | `tropical_tronc` | 6 – 7 × 13, **base large** | écorce 148 – 152 |
| | `tropical_houppier_01` `_02` | 14 – 18 × 6 – 8 | feuillage 129 – 138 |
| | `palmier_tronc` | 4 × 15 | écorce 149 – 153 |
| | `palme` `palme_diagonale` | 13 – 19 × 3 – 4 | 129 – 136 |
| `lavalands/` | `arbre_epineux` | 6 × 13 | écorce 152 – 155, épines 152 |

`oceans/` n'a pas d'arbre : une île émergée n'est pas Oceans, c'est son climat
qui la nomme, et elle porte les arbres qui vont avec.

Contrainte d'index de ce lot (`generer_arbres.INDEX_ARBRES`) : **terrain
14 – 31** et **végétation 128 – 175**, rien d'autre. Pas de filon — un houppier
n'a pas droit à l'or. La rampe **148 – 155 est celle des troncs et de l'écorce**.

> **Deux cas délicats, et ils tirent tous les deux sur la même absence de blanc
> dans la plage végétation.** Le `bouleau_tronc` et la neige des conifères
> emploient le clair de la rampe de roche nue (14 – 15). Si le rendu déçoit,
> **ne modifie pas la palette** — signale-le, la décision d'ajouter un blanc
> appartient au projet et déplacerait un contrat.
>
> **Et la règle de Snowlands** : aucune plante ni aucun feuillage de ce biome ne
> prend la rampe 140 – 147, l'orange d'automne. Sur un sol de neige cyan, il
> ressort en tache chaude, et le défaut a été relevé deux fois.

### 3. Ce qui est attendu, en termes de forme

- **la silhouette se juge à cent blocs, pas à trente.** Un arbre est ce qu'on
  voit d'abord d'un biome. Une frondaison franche et asymétrique vaut mieux
  qu'une boule régulière ;
- **le houppier doit rester lisible tout seul.** Il sera posé sur des troncs de
  hauteurs différentes, parfois à deux ou trois exemplaires sur le même tronc :
  il doit tenir comme forme indépendante ;
- **pas de symétrie d'ordre 4.** Les quatre quarts de tour sont appliqués à la
  pose ; un sapin conique parfait rendra quatre fois la même image. Décale les
  étages, laisse une branche plus longue ;
- **le fût ne doit jamais dépasser du feuillage.** Vu en capture le 2026-09-06 :
  la colonne d'un conifère montait jusqu'au sommet et ressortait en stub brun
  au-dessus des plateaux, sur tous les conifères du monde à la fois. Un conifère
  ne montre son tronc qu'entre le sol et son premier étage.

### 4. Boucle de validation

```
# Inventaire : gabarit, index employes, plages de palette.
# Sans argument, il balaie tout assets/models/ — donc le lot d'arbres avec.
# Avec des arguments, il n'inspecte que les fichiers cites.
<godot> --headless --path . -s tools/inspect_model.gd

# Suite complete
<godot> --headless --path . -s tests/worldgen_test.gd
```

`inspect_model.gd` marche sur n'importe quel `.vox`, **et il connaît les deux
grilles** : il lit un fichier de `arbres/` ou de `filons/` à un voxel par bloc,
et le reste à 40/3. Il annonçait le pin à 1,65 bloc de haut là où il en fait 22,
et c'est justement l'outil qu'on consulte pour vérifier une échelle.

`tests/tree_test.gd` tient le reste : les enveloppes par classe **en blocs**, le
plancher de 8 blocs par fût, la proportion des houppiers, la grille du lot, et le
fait que les deux bibliothèques gardent des rayons maximums séparés.

**Et rien de tout cela ne remplace une capture en jeu.** Cinq défauts du lot du
2026-09-06 n'ont été trouvés qu'ainsi, dont un qui touchait tous les conifères du
monde à la fois :

```
<godot> --path . scenes/terrain_demo.tscn --resolution 1600x900 -- --biome 0 --shot 40 --vue 224
#   --biome : 0 Greenlands, 1 Snowlands, 2 Deserts, 3 Jungles, 4 Lava Lands, 5 Oceans
```

### 5. Ce que tu rends

1. les 24 `.vox` sous `assets/models/arbres/<biome>/` ;
2. `tools/blender/generer_arbres.py` et `arbres_blocs.py`, avec les graines en
   dur, et `flore_vox` réemployé plutôt que recopié ;
3. la sortie de `inspect_model.gd` ;
4. **une capture par biome arboré**, prise en jeu ;
5. la liste des modèles dont tu es le moins sûr.

---

## Ce qui n'est pas dans ce lot, et pourquoi

**Les neuf filons** (`gold-`, `iron-`, `silver-`, `sandstone-`, `emerald-`,
`sapphire-`, `ruby-`, `diamond-`, `ice-crystal-deposit`, codes 131 – 139) sont un
lot à part, **dessiné le 2026-09-05** sous `assets/models/filons/` par
`tools/blender/generer_filons.py`.

Ils partagent la grille de ce lot — 1 voxel = 1 bloc — mais pour une autre
raison : un filon **s'estampe dans le terrain**, donc chacun de ses voxels est un
**type de bloc** et pas seulement une couleur. Un arbre, lui, est encore
instancié ; il est dessiné à la maille du bloc parce que c'est sa grille dans la
source, pas parce qu'il s'estampe.

La décision de palette qui les bloquait a été prise le 2026-09-05 :
`RANGE_TERRAIN_END` est passé de 31 à 40 et `RANGE_CREATURES_BEGIN` de 32 à 41,
**et rien d'autre**. Le prix annoncé — « invalide tous les modèles déjà peints »
— ne valait que si l'on déplaçait *toutes* les frontières. Raisonnement complet :
`assets/palette/PALETTE.md` et l'en-tête de `CWPalette`. Ce qui reste des filons
est leur **pose**, qui appartient à la voie des entités du jalon 2.6.

**Deux entrées de plus ont changé de statut le 2026-09-06** : 30 et 31, les deux
teintes de lave, sont devenues les types de bloc `MAGMA` et `SCORIA` de Lava
Lands. C'étaient les deux seules de la réserve 14 – 31 qu'aucun modèle
n'employait, ce qui a rendu l'opération gratuite — ni frontière déplacée, ni
modèle à repeindre. Un modèle de flore peut encore les employer comme couleur :
la flore est instanciée, elle n'entre jamais dans les données du monde.

---

## Note à l'intention du projet

Ce prompt fixe les dimensions **en blocs**, et non en voxels comme celui de la
flore. À un voxel par bloc les deux unités se confondent, et c'est plus clair
ainsi : « houppier de 15 » se compare directement au personnage, qui fait 2,4
blocs. C'est aussi ce qui rend ce lot plus facile à juger que le précédent — la
version antérieure de ce document donnait « houppier 40 – 80 voxels », un nombre
dont personne ne pouvait dire s'il était grand ou petit sans une division.

Les enveloppes de §1.1 sont **verrouillées deux fois** : par
`tests/tree_test.gd` au chargement, et par le générateur à l'écriture. Les deux
disent le même nombre, et c'est délibéré — un lot refusé à l'écriture ne pose
jamais la question de savoir si un test est trop sévère.

**Ce que ce document ne remplace pas.** Cinq défauts du lot livré n'ont été
trouvés qu'en capture, et aucun ne pouvait l'être autrement : un fût qui dépasse
du feuillage, une couleur de sol qui avale la couleur qu'elle doit faire
ressortir, une palette de biome qui jure avec son sol, une couronne de palmier
qui n'a que deux directions. La boucle de validation de §4 finit **toujours** par
une capture en jeu.
