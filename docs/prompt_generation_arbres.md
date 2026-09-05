# Prompt — génération du lot d'arbres sous Blender (bpy)

Document à donner tel quel à un agent disposant du MCP Blender. Il est
autoportant, et il suit le même chemin que
`docs/prompt_generation_flore.md`, qui a produit les 39 modèles de flore basse
du jalon 1.7 : un document de commande, un script Python déterministe, une
graine en dur par fichier, le lot se régénère à l'identique.

**Lis d'abord `docs/prompt_generation_flore.md`.** Les règles 1.1 à 1.3, la
section 2 (orientation et ancrage), la section 3 (l'écrivain `.vox`) et la
section 4 (comment employer Blender) s'appliquent **mot pour mot** et ne sont pas
répétées ici. Ce document ne dit que ce qui **change** pour les arbres.

---

## Le prompt

> Tu produis **14 fichiers `.vox`** d'arbres, de houppiers et de palmes pour
> Zentarys, sous `assets/models/arbres/`. Tu travailles **uniquement en
> Python** : `bpy` pour construire les formes, l'écrivain `.vox` de
> `tools/blender/flore_vox.py` pour la sortie. Aucune interaction manuelle avec
> l'interface de Blender.
>
> Le dépôt est en `C:\Users\Admin\Documents\zentarys`. Réemploie
> `tools/blender/flore_vox.py`, `flore_formes.py` et `flore_blender.py` : la
> palette, les garde-fous d'index et le tracé de courbes à rayon variable y sont
> déjà, et c'est ce dernier qui fait les troncs et les branches.

### 1. Ce qui change par rapport à la flore

**1.1 — L'échelle est la même, l'enveloppe non.**

Le rapport ne bouge pas : **1 bloc = 40/3 ≈ 13,333 voxels**, personnage de
référence à **32 voxels = 2,4 blocs**. Mais la flore tenait sous 53 voxels de
haut ; un arbre n'y tient pas. La source donne la mesure : la boîte de
`thorn-tree` est de **3 × 3 × 12 blocs**, soit **160 voxels** de haut
(`docs/systems/02`, §5.2).

Enveloppes visées, par classe — **proposition, à verrouiller par un test quand la
couche de dispersion des arbres existera** (jalon 1.11) :

| classe | hauteur | rayon | remarque |
|---|---|---|---|
| arbre entier | 80 – 160 voxels (6 – 12 blocs) | ≤ 45 | le sapin et l'arbre mort |
| houppier | 40 – 80 voxels | ≤ 45 | posé **au sommet d'un tronc**, pas au sol |
| palme | 30 – 60 voxels | ≤ 45 | une seule fronde |

**1.2 — Il y a deux sortes d'objets dans ce lot, et elles ne se posent pas
pareil.**

C'est le résultat d'analyse qui a ouvert ce jalon (`docs/systems/02`, §5.2) :

- le **conifère** et l'**arbre à épines** de l'original sont des **modèles
  entiers**, posés en une fois au sol ;
- le **houppier** (`tree-leaves`) porte son propre code d'entité : il est posé
  **séparément**, au-dessus d'un tronc. Il n'existe aucun modèle de tronc dans
  le corpus — le tronc est écrit dans le terrain, en colonnes de blocs.

Donc : un **arbre entier** commence sa matière en Z = 0, comme une plante. Un
**houppier** est une couronne qui n'a **pas de tronc** — son ancre est le centre
de son empreinte à sa base, et cette base viendra se poser sur le sommet d'un
tronc de blocs. Ne dessine pas de pied sous un houppier : il flotterait de la
hauteur du pied, ou il doublerait le tronc.

Même chose pour les palmes : une palme est **une fronde seule**, ancrée par son
point d'attache, pas un palmier.

**1.3 — La matière reste mince, sauf le tronc.**

Une frondaison est une coquille : des paquets de feuillage sur le pourtour, du
vide au milieu. Un arbre plein est un rocher vert. Le **tronc d'un arbre
entier**, lui, est plein — c'est la seule partie massive du lot, et elle fait
2 à 4 voxels de section à la base pour un arbre de 8 blocs.

### 2. Ce qu'il faut produire

Un dossier par biome sous `assets/models/arbres/`. Mêmes conventions de nommage
que la flore : minuscules sans accent, le nom ne porte ni le biome — c'est le
dossier — ni la taille.

| dossier | fichiers | hauteur visée (voxels) | teintes |
|---|---|---|---|
| `herbe/` | `houppier_01` `houppier_02` | 50 – 80 | feuillage 128 – 136 |
| | `tronc_feuillu` | 60 – 100 | écorce 148 – 153 |
| `herbe_seche/` | `arbre_sec` | 80 – 120 | écorce 150 – 155, feuillage 140 – 145 |
| | `houppier_sec` | 40 – 70 | automne 140 – 147 |
| `jungle/` | `houppier_jungle` | 50 – 80 | feuillage 128 – 134 |
| | `tronc_palmier` | 80 – 130 | écorce 148 – 152 |
| | `palme` `palme_diagonale` | 30 – 60 | 129 – 135 |
| `marais/` | `arbre_mort` | 70 – 110 | écorce 152 – 155, sans feuillage |
| `sable_desert/` | `palmier_dattier` | 90 – 140 | écorce 148 – 152, palmes 133 – 139 |
| `neige/` | `sapin` | 90 – 140 | feuillage 130 – 139 |
| | `sapin_enneige` | 90 – 140 | feuillage 130 – 139 + neige : **pas d'index blanc dans la plage végétation, emploie 14 – 15** |
| `toundra/` | `sapin_rabougri` | 50 – 90 | feuillage 132 – 139, écorce 150 – 154 |

Rappel de la contrainte d'index, inchangée : **terrain 1 – 11 et 14 – 31**,
**végétation 128 – 175**, rien d'autre. L'index 0 est l'air, 12 et 13 sont
translucides. La rampe **148 – 155 est celle des troncs et de l'écorce** ; elle
n'avait aucun usage dans le lot de flore, elle en a un ici.

> **Le `sapin_enneige` est le seul cas délicat.** La plage végétation n'a aucun
> blanc. Le clair de la rampe de roche nue (14 – 15) est le moins mauvais
> substitut ; si le rendu déçoit, **ne modifie pas la palette** — signale-le, la
> décision d'ajouter un blanc appartient au projet et déplacerait un contrat.

### 3. Ce qui est attendu, en termes de forme

Reprend la section 6 de `prompt_generation_flore.md`, avec trois ajouts propres
aux arbres :

- **la silhouette se juge à cent blocs, pas à trente.** Un arbre est ce qu'on
  voit d'abord d'un biome. Une frondaison franche et asymétrique vaut mieux
  qu'une boule régulière ;
- **le houppier doit rester lisible tout seul.** Il sera posé sur des troncs de
  hauteurs différentes, parfois à deux ou trois exemplaires sur le même tronc :
  il doit tenir comme forme indépendante ;
- **pas de symétrie d'ordre 4.** Les quatre quarts de tour sont appliqués à la
  pose ; un sapin conique parfait rendra quatre fois la même image. Décale les
  étages, laisse une branche plus longue.

### 4. Boucle de validation

```
# Inventaire : gabarit, index employes, plages de palette.
# Sans argument, il balaie tout assets/models/ — donc le lot d'arbres avec.
# Avec des arguments, il n'inspecte que les fichiers cites.
<godot> --headless --path . -s tools/inspect_model.gd

# Suite complete
<godot> --headless --path . -s tests/worldgen_test.gd
```

`inspect_model.gd` marche déjà sur n'importe quel `.vox` et c'est lui qui
attrape le piège de la palette. **La suite de tests, en revanche, ne connaît pas
encore ce lot** : les vérifications d'enveloppe de `tests/flora_test.gd` sont
celles de la flore basse (4 blocs de haut, 2 de rayon) et un arbre les
échouerait. Elles seront écrites avec la couche de dispersion du jalon 1.11 ; en
attendant, l'inventaire et l'œil font foi.

### 5. Ce que tu rends

1. les 14 `.vox` sous `assets/models/arbres/<biome>/` ;
2. `tools/blender/generer_arbres.py`, avec les graines en dur, et les modules
   partagés réemployés plutôt que recopiés ;
3. la sortie de `inspect_model.gd` ;
4. la liste des modèles dont tu es le moins sûr.

---

## Ce qui n'est pas dans ce lot, et pourquoi

**Les neuf filons** (`gold-`, `iron-`, `silver-`, `sandstone-`, `emerald-`,
`sapphire-`, `ruby-`, `diamond-`, `ice-crystal-deposit`, codes 131 – 139) font
partie du jalon 1.11 mais **pas de cette commande**, et il faut une décision
avant de les dessiner.

Ils sont d'une autre nature : un filon **s'estampe dans le terrain** — on doit
pouvoir le miner —, donc il se dessine à **1 voxel = 1 bloc**
(`assets/models/MODELS.md`, §3) et chacun de ses voxels est un **type de bloc**,
pas seulement une couleur. Or `CWPalette` n'a pas de type pour eux : la réserve
de terrain 14 – 31 a été remplie le 2026-09-05 (roche, grès, argile, basalte,
roche lichénée, lave) et elle est pleine.

> **Tranché le 2026-09-05.** Aucune des trois issues ci-dessous telle quelle :
> `RANGE_TERRAIN_END` est passé de 31 à 40 et `RANGE_CREATURES_BEGIN` de 32 à 41,
> **et rien d'autre**. Le prix annoncé de l'issue 2 — « invalide tous les modèles
> déjà peints » — ne valait que si l'on déplaçait *toutes* les frontières ; les
> 53 modèles du dépôt n'emploient que 14 – 29 et 128 – 175, et la plage créatures
> n'a aucune entrée peinte. Les neuf filons sont dessinés et vivent sous
> `assets/models/filons/`. Raisonnement complet : `assets/palette/PALETTE.md` et
> l'en-tête de `CWPalette`.

Trois issues, à trancher au jalon 1.11 :

1. prendre les teintes dans la plage équipement (96 – 127, qui a déjà une rampe
   de gemmes en 122 – 127) et accepter qu'un filon soit un type de bloc hors de
   la plage terrain — le découpage en plages est un contrat d'**authoring**,
   pas une contrainte du moteur, mais le franchir demande de le dire ;
2. déplacer la frontière `RANGE_CREATURES_BEGIN` pour agrandir la réserve de
   terrain — ce qui **invalide tous les modèles déjà peints** et impose de
   repasser le lot de flore par `tools/repaint_models.gd` ;
3. réemployer les entrées existantes et distinguer les filons par leur seule
   couleur — impossible depuis 1.9 sans perdre l'information de type, puisque
   c'est `CHANNEL_TYPE` qui porte la sémantique du bloc.

Tant que ce n'est pas tranché, dessiner les filons serait dessiner à l'aveugle.

---

## Note à l'intention du projet

Ce prompt fixe les hauteurs **en voxels**, comme celui de la flore, et pour la
même raison : c'est l'unité dans laquelle on dessine, et elle ne bouge pas si la
taille du personnage est révisée au jalon 3.1.

L'enveloppe proposée en §1.1 n'est **pas** verrouillée par un test aujourd'hui.
C'est le premier lot du projet dans ce cas, et c'est assumé : la couche de
dispersion des arbres n'existe pas encore, et c'est elle qui fixera la marge
réelle. Un modèle qui dépasse ne cassera rien — il sera rogné aux bordures de
cellule, ce qui se voit.
