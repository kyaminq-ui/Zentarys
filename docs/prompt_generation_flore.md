# Prompt — génération du lot de flore

Document à donner tel quel à un agent. Il est autoportant : tout ce qui suit est
vérifiable dans le dépôt, et la boucle de validation est fournie.

> **Le lot est passé à quatre voxels par bloc le 2026-09-06, et le générateur
> est en Python pur** (`tools/blender/generer_flore.py`, formes dans
> `tools/blender/flore_blocs.py`). À cette maille, `bpy` n'apporte plus rien :
> une métaballe échantillonnée rend un tas de cubes, une courbe rend une ligne
> de cubes. La section 4 ci-dessous, sur l'usage de Blender, ne vaut donc plus
> que pour les lots à la **grille fine** — le personnage et les créatures du
> jalon 2. Le raisonnement du changement de maille est en `nextsteps.md`,
> §6ter.1.

---

## Le prompt

> Tu produis **38 fichiers `.vox`** de flore pour Zentarys, un jeu voxel sous
> Godot. Tu travailles **uniquement en Python** : à quatre voxels par bloc, tu
> poses les voxels directement, puis un écrivain `.vox` maison pour la sortie.
>
> Le dépôt est en `C:\Users\Admin\Documents\zentarys`. Lis
> `assets/models/MODELS.md` avant de commencer : il fait autorité sur l'échelle
> et les couleurs, et ce prompt en est le résumé opérationnel.

### 1. Trois règles dont dépend tout le reste

**1.1 — La palette. C'est ici que le lot précédent a échoué.**

Le moteur lit un **index de palette**, jamais une couleur. Un modèle aux bonnes
teintes mais aux mauvais index sort peint avec les couleurs des créatures, et
**rien ne le signale** : ni le chargement, ni les tests, seulement l'écran.

Le geste sûr, et le seul :

```python
import struct

def read_rgba_chunk(vox_path):
    """Les 1024 octets du bloc RGBA de la palette de projet, tels quels."""
    d = open(vox_path, "rb").read()
    i = d.find(b"RGBA")
    n = struct.unpack("<I", d[i + 4:i + 8])[0]
    assert n == 1024, n
    return d[i + 12:i + 12 + 1024]

PALETTE = read_rgba_chunk(r"assets\palette\zentarys_palette.vox")
```

Tu **copies ce bloc verbatim** dans chaque fichier produit. Tu ne le
reconstruis pas, tu ne le réordonnes pas, tu ne le régénères pas depuis des
valeurs RGB.

Le décalage du format est déjà absorbé : dans le fichier, `RGBA[i]` porte la
couleur d'**index `i + 1`**. Donc **l'octet de couleur que tu écris dans `XYZI`
est directement l'index du projet** — index 128 = premier vert de feuillage.
Vérifié : `RGBA[127]` vaut bien `(154, 216, 96)`, qui est l'index 128 du code.

**1.2 — Les index autorisés sont contraints, et un test le vérifie.**

Un modèle de flore ne peut porter **que** :

| plage | indices | contenu |
|---|---|---|
| Terrain | **1 – 11** et **14 – 31** | tout ce qui est minéral |
| Végétation | **128 – 175** | tout ce qui est végétal |

Interdits, sans exception : **0** (c'est l'air), **12 et 13** (eau, translucide)
et tout ce qui est hors de ces plages. Les indices translucides sortent opaques
au rendu — c'est un piège silencieux de plus.

**1.3 — L'échelle : 1 bloc = 4 voxels, ou 6 pour les petits props.**

Ce n'est pas la valeur de l'original — la sienne est 3/40, relevée dans le
binaire (`docs/systems/02`, §8.3) — et l'écart est délibéré : à 3/40 un brin
d'herbe fait 0,08 bloc et lit comme un cheveu à côté d'un cube de terrain. Note
complète sur `CWVoxelModel.VOXELS_PER_BLOCK_FLORE`.

**Deux grilles, et le critère n'est pas la taille de l'objet mais la façon dont
il porte sa forme.** Un buisson, un cactus, un champignon sont des *masses* :
leur forme est leur volume, et un volume se lit à quatre voxels par bloc. Une
touffe d'herbe et une fleur portent leur forme **dans un trait** — cinq lignes,
ou une tige et une corolle — et à quatre voxels il ne reste d'une corolle qu'une
croix. Celles-là sont à **six**. La liste qui fait foi est la colonne `FIN` du
catalogue, et elle doit dire la même chose que `CWModelLibrary.GRILLE_FINE`.

Ce qu'il faut en retenir en dessinant :

- **une constante que tu écris est un quart de bloc** — un sixième sur la grille
  fine. `hauteur = 7` à quatre voxels se lit « 1,75 bloc », et `hauteur = 10,5` à
  six voxels dit la même chose ;
- le **personnage de référence fait 9,6 voxels** de haut sur la grille à quatre,
  **14,4** sur celle à six, soit 2,4 blocs dans les deux cas. C'est ton mètre
  étalon : une touffe d'herbe lui arrive à l'épaule, un cactus le dépasse de
  moitié ;
- plafond dur, vérifié par un test : **4 blocs de haut, 2 de rayon**, soit 16 et
  8 voxels sur la grille à quatre, 24 et 12 sur celle à six (`flore_vox.
  plafond_de`). Au-delà le lot est refusé ;
- la matière est **mince, pas fine**. Un brin d'herbe fait **un voxel de
  section** — c'est déjà un quart de bloc, l'épaisseur d'un doigt à l'échelle du
  personnage. Doubler ferait une lame de couteau. Ce qui reste vrai : ne remplis
  jamais un volume que tu peux suggérer.

### 2. Orientation et ancrage

- **Z est vers le haut** dans le `.vox`, comme dans Blender. Aucune conversion
  d'axe à faire : tu construis debout en Z, tu écris en Z.
- Le modèle est **recadré sur sa matière** au chargement, et son ancre est le
  **centre de l'empreinte, à la base**. Centre donc tes formes horizontalement,
  sinon la plante penche à la pose.
- Les quatre quarts de tour sont précalculés par le moteur. Ne produis pas de
  variantes tournées.

### 3. L'écrivain `.vox`

Format testé contre le chargeur du projet. Coordonnées sur un octet, donc
gabarit ≤ 255 — largement suffisant.

```python
def write_vox(path, voxels, size, rgba_chunk):
    """voxels : iterable de (x, y, z, index) ; index = index de projet, 1..255.
    size : (sx, sy, sz), Z vers le haut. rgba_chunk : les 1024 octets copiés."""
    assert len(rgba_chunk) == 1024
    v = [t for t in voxels]
    assert all(1 <= c <= 255 for _, _, _, c in v), "index 0 = air, interdit"
    assert all(max(x, y, z) < 256 for x, y, z, _ in v)

    size_c = struct.pack("<4sII", b"SIZE", 12, 0) + struct.pack("<III", *size)
    body = struct.pack("<I", len(v)) + b"".join(bytes((x, y, z, c)) for x, y, z, c in v)
    xyzi_c = struct.pack("<4sII", b"XYZI", len(body), 0) + body
    rgba_c = struct.pack("<4sII", b"RGBA", 1024, 0) + rgba_chunk
    children = size_c + xyzi_c + rgba_c
    main = struct.pack("<4sII", b"MAIN", 0, len(children)) + children
    open(path, "wb").write(b"VOX " + struct.pack("<I", 150) + main)
```

**N'écris que les voxels pleins.** Un modèle de flore n'occupe que quelques
pour cent de sa boîte.

### 4. Comment utiliser Blender

Blender sert à **construire des formes**, pas à exporter. Le pipeline est :

1. `bpy` construit la géométrie — courbes de Bézier pour les tiges et les
   lianes, métaballes ou icosphères pour les frondaisons et les cailloux,
   modificateurs `Array` / `Simple Deform` pour les répétitions et les
   courbures, `mathutils.noise` pour les irrégularités ;
2. tu **échantillonnes** cette géométrie sur une grille entière — soit par test
   d'inclusion (`closest_point_on_mesh` + normale), soit par `Remesh` en mode
   `BLOCKS` puis lecture des sommets ;
3. tu affectes un index de palette par voxel selon sa hauteur ou sa partie ;
4. tu écris le `.vox`.

Pour les formes très simples — brins d'herbe, cailloux, étoiles de mer — passer
par Blender n'apporte rien : génère la grille directement en Python. Utilise
Blender là où il paye : buissons, cactus, coraux, lianes.

**Rends le tout déterministe** : une graine fixe par fichier, notée dans le
script. On doit pouvoir régénérer le lot à l'identique.

### 5. Ce qu'il faut produire

Un dossier par biome sous `assets/models/flore/`, et il y en a **six** depuis le
jalon 1.12 : ce sont les biomes de l'alpha 2013, décidés par `CWBiome`, et non
les neuf matières de surface d'avant. Noms en minuscules sans accent. **Le nom
ne porte ni le biome — c'est le dossier — ni la taille.**

Les rôles reviennent d'un biome à l'autre : un `cotonnier` de Snowlands et un du
désert sont **deux fichiers différents**, chacun dans les teintes de son biome.
Un test refuse qu'un chemin traverse.

> **Les hauteurs de cette table sont en voxels de la grille du modèle** — 6 pour
> les lignes marquées `FIN`, 4 pour les autres. Divise par la grille pour lire
> des blocs. Les **tailles en blocs n'ont pas changé** depuis le lot du matin :
> c'est la résolution de dessin qui a changé, pas l'enveloppe.
>
> **Deux règles de forme comptent autant que ces hauteurs** : une touffe se fait
> de **cinq ou six brins** longs et écartés ; et ce qui distingue deux plantes à
> cette maille est la **courbe**, pas le détail — un roseau est droit, une touffe
> d'herbe est arquée, une fronde de fougère monte et retombe. Il n'y a plus de
> place pour des folioles, et il n'en faut pas.

| dossier | fichiers | grille | hauteur (voxels) | teintes |
|---|---|---|---|---|
| `greenlands/` | `herbe_01` | **FIN** | 10 | feuillage 128 – 133 |
| | `herbe_02` | **FIN** | 12 | feuillage 129 – 135 |
| | `herbe_03` | **FIN** | 6 | feuillage 128 – 135 |
| | `herbe_seche` | **FIN** | 11 | feuillage 133 – 139, brins **droits** |
| | `fleur_bleuet` | **FIN** | 4 | tige 135 – 136, pétales 160 – 161 |
| | `fleur_tournesol` | **FIN** | 10 | tige 133 – 136, cœur 148, pétales 158 |
| | `fleur_coeur` | **FIN** | 8 | tige 133 – 135, cœurs 156 – 157 |
| | `ginseng` | **FIN** | 7 | tige 137 – 138, ombelle 158 – 159 |
| | `buisson` | GROS | 6 | feuillage 128 – 135, pied 150 |
| | `scrub` | GROS | 6 | branches 151 – 153, feuilles 133 – 137 |
| | `broussaille` | GROS | 5 | branches 148 – 150, feuilles 133 – 139 |
| | `fougere` | GROS | 14 | 130 – 133 |
| `snowlands/` | `herbe_gelee` | **FIN** | 8 | 136 – 139 + neige 14 – 15 |
| | `fleur_de_glace` | **FIN** | 8 | 137 – 138, corolle 160 – 161 |
| | `buisson_neige` | GROS | 6 | 136 – 138 + neige 14 – 15 |
| | `snowberry` | GROS | 4 | 137 – 138, baies 14 |
| | `cotonnier` | GROS | 7 | tiges 153 – 154, capsules 14 – 15 |
| `deserts/` | `cactus_01` | GROS | 13 | cactus 172 – 174 |
| | `cactus_02` | GROS | 9 | 172 – 174, fleur 156 – 157 |
| | `broussaille_seche` | GROS | 5 | automne 142 – 145 |
| | `cotonnier` | GROS | 7 | 143 – 145, capsules 14 – 15 |
| | `habanero` | GROS | 3 | 130 – 133, piments 156 |
| `jungles/` | `feuille_large` | GROS | 5 (large) | 128 – 131 |
| | `fougere_geante` | GROS | 13 | 129 – 132 |
| | `liane` `vrille` | GROS | 10 | feuillage 128 – 132 |
| | `lierre` | GROS | 5 (rampant) | 130 – 132 |
| | `fleur_coeur` | **FIN** | 8 | tige 133 – 135, fleur 156 – 157 |
| | `fleur_ame` | **FIN** | 8 | tige 137 – 138, corolle 162 – 163 |
| | `roseau` | **FIN** | 13 | 138 – 142, brins **droits** |
| | `champignon` | GROS | 5 | pied 166 – 167, chapeau 164 – 165 |
| `lavalands/` | `fire_shrub` | GROS | 6 | scorie 25 – 26, braises 30 |
| | `herbe_de_lave` | **FIN** | 9 | scorie 25 – 27, pointes 30 |
| | `fleur_de_lave` | **FIN** | 7 | hampe 26 – 27, corolle 30 – 31 |
| | `champignon_luisant` | GROS | 5 | pied 166 – 167, chapeau **240 – 242** |
| `oceans/` | `algue` | GROS | 9 | 130 – 132 |
| | `corail` | GROS | 6 | **170 – 171** |
| | `etoile_de_mer` | GROS | 2 | 156 – 157 |

**Trois contraintes de palette, et aucune n'est cosmétique.**

- **Le corail et l'algue sont les seuls à devoir employer 170 – 171.** Ces deux
  entrées existent précisément parce que rien d'autre dans la palette n'est
  froid et saturé ; sans elles un corail rend en vert de prairie.
- **Aucune plante de Snowlands ne prend la rampe 140 – 147.** C'est la rampe
  « automne, herbe sèche », un orange chaud ; sur un sol de neige — un cyan très
  clair — chaque plante qui l'emploie ressort en tache orange, seul objet chaud
  du paysage. Le défaut a été relevé **deux fois**, le 2026-09-05 sur un modèle
  et le 2026-09-06 sur cinq. Snowlands puise dans 136 – 139, 151 – 155 et
  14 – 15.
- **Le champignon luisant est le seul modèle autorisé à puiser dans 240 – 247**,
  la plage des effets : son chapeau doit rendre une lumière, et aucune entrée de
  la plage végétation n'est assez claire. L'autorisation est passée explicitement
  à l'écriture, elle n'élargit pas le garde-fou des autres modèles.

Deux modèles de Lava Lands emploient **30 et 31**, qui sont depuis le jalon 1.12
des *types de bloc* (magma et scorie). Ce n'est pas une collision : un modèle de
flore est instancié, il n'entre jamais dans les données voxels du monde, donc les
deux usages ne se croisent pas.

### 6. Ce qui est attendu d'un modèle, en termes de forme

- **Une silhouette lisible de loin.** À 2 blocs de haut vu à trente blocs, seule
  la silhouette compte. Préfère une forme franche à du détail.
- **De l'asymétrie.** Les quatre rotations sont appliquées à la pose : un modèle
  symétrique rendra quatre fois la même image.
- **Pas de socle.** La matière commence au sol, en Z = 0 dans ton repère.
- **Deux à quatre index par modèle suffisent.** Le dégradé sert à donner du
  volume, pas à faire riche : plus clair en haut, plus sombre à la base.
- **Des variantes réellement différentes.** `herbe_01`, `_02` et `_03` doivent se
  distinguer en nombre de brins et en hauteur, pas seulement par un voxel.

### 7. Boucle de validation — à faire tourner avant de rendre le travail

L'exécutable Godot est en
`C:\Users\Admin\Desktop\godot.windows.editor.double.x86_64.exe`.

```
# Inventaire : gabarit, index employés, plages de palette
<godot> --headless --path . -s tools/inspect_model.gd

# Suite complète (117 vérifications, ~70 s)
<godot> --headless --path . -s tests/worldgen_test.gd
```

Le lot est bon quand la suite passe **sans aucun échec**. Les vérifications qui
te concernent directement :

- tous les modèles de la table existent sur le disque ;
- indices dans les plages végétation ou terrain ;
- aucun modèle ne porte d'index translucide ;
- aucun modèle hors de l'enveloppe (4 blocs de haut, 2 de rayon) ;
- le maillage pose sur l'ancre, et à la bonne hauteur.

Si un index est hors plage, **ne corrige pas la palette du projet** : corrige ton
générateur. Le découpage des plages est un contrat.

### 8. Ce que tu rends

1. les 42 `.vox` en place sous `assets/models/flore/<biome>/`, six biomes ;
2. le ou les scripts Python qui les produisent, dans `tools/blender/`, avec les
   graines en dur ;
3. la sortie de `inspect_model.gd` et le compte final de la suite de tests ;
4. la liste des modèles dont tu es le moins sûr, pour retouche à la main dans
   MagicaVoxel.

---

## Note à l'intention du projet

Ce prompt fixe volontairement les **hauteurs en voxels** plutôt qu'en blocs :
c'est l'unité dans laquelle on dessine, et elle ne bouge pas si la taille du
personnage est révisée au jalon 3.1. Le lot d'arbres, lui, fixe les siennes en
**blocs**, parce qu'à un voxel par bloc les deux unités se confondent — voir
`docs/prompt_generation_arbres.md`.

**Un repère faux dans ce document coûte un lot entier.** C'est arrivé : la
première version commandait des touffes de 10 – 14 voxels d'après une ligne de
`MODELS.md` qui disait « au genou », là où les captures du jeu d'origine montrent
« à l'épaule ». Les trente-neuf modèles ont hérité du défaut, et il a fallu tout
regénérer. Les deux documents ont été alignés le 2026-09-06.

Les teintes indiquées sont celles des rampes actuelles de `CWPalette`, qui sont
des **rampes de départ**. Si une teinte est ajustée plus tard, les modèles
restent justes : ils portent des index, pas des couleurs.
