# Prompt — génération du lot de flore sous Blender (bpy)

Document à donner tel quel à un agent disposant du MCP Blender. Il est
autoportant : tout ce qui suit est vérifiable dans le dépôt, et la boucle de
validation est fournie.

---

## Le prompt

> Tu produis **39 fichiers `.vox`** de flore pour Zentarys, un jeu voxel sous
> Godot. Tu travailles **uniquement en Python** : `bpy` pour construire les
> formes, puis un écrivain `.vox` maison pour la sortie. Aucune interaction
> manuelle avec l'interface de Blender.
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

**1.3 — L'échelle : 3 blocs = 40 voxels.**

Un bloc de terrain vaut **40/3 ≈ 13,333 voxels de modèle**. La valeur vient de
l'original (`docs/systems/02`, §8.3) ; elle n'est pas ronde, c'est assumé.

Ce qu'il faut en retenir en dessinant :

- le **personnage de référence fait 32 voxels** de haut, soit 2,4 blocs. C'est
  ton mètre étalon : une touffe d'herbe lui arrive au genou, un cactus le
  dépasse ;
- plafond dur, vérifié par un test : **hauteur ≤ 53 voxels**, **rayon ≤ 26
  voxels** depuis l'axe. Au-delà le lot est refusé ;
- la matière est **fine**. Une touffe d'herbe est une dizaine de lames d'**un
  voxel d'épaisseur**, pas un volume vert. C'est ce qui sépare ce rendu de
  celui de Minecraft. Ne remplis jamais un volume que tu peux suggérer.

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

Un dossier par biome sous `assets/models/flore/`. Noms en minuscules sans
accent. **Le nom ne porte ni le biome — c'est le dossier — ni la taille.**

Les rôles reviennent d'un biome à l'autre : un `caillou_01` de prairie et un de
neige sont **deux fichiers différents**, chacun dans les teintes de son biome.
C'est voulu.

> ⚠️ **Les hauteurs de cette table sont trop petites d'un facteur ~2,5 pour ce
> qui pousse au sol** — constaté le 2026-09-05 au soir sur des captures du jeu
> d'origine : une touffe d'herbe y monte à l'épaule du personnage, pas au genou.
> Le lot des 39 modèles a été dessiné sur ces chiffres et hérite du défaut. La
> table reste ici telle qu'elle a servi ; les valeurs corrigées sont dans
> `assets/models/MODELS.md`, §1, et le raisonnement dans `nextsteps.md`, §6.5.
>
> Deuxième correction, du même jour : une touffe se fait de **cinq ou six brins**
> longs et écartés, pas de dix à vingt serrés. La densité a été montée le
> 2026-09-05 au matin pour compenser un rendu « clairsemé » — c'était traiter le
> symptôme à l'envers, les touffes lisaient clairsemées parce qu'elles faisaient
> la moitié de leur taille.

| dossier | fichiers | hauteur visée (voxels) | teintes |
|---|---|---|---|
| `herbe/` | `herbe_01` `herbe_02` `herbe_03` | 10 – 14 | feuillage 128 – 136 |
| | `bouquet_01` `bouquet_02` | 10 – 16 | tiges 132 – 138, fleurs 156 – 163 |
| | `fleur_bleuet` | 10 – 16 | tige 134, pétales 160 – 161 |
| | `fleur_tournesol` | 14 – 20 | tige 134, cœur 148, pétales 158 – 159 |
| | `buisson` | 20 – 30 | feuillage 128 – 139, branches 148 – 151 |
| | `caillou_01` `caillou_02` | 5 – 10 | roche nue 14 – 19 |
| `herbe_seche/` | `herbe_seche` | 10 – 14 | automne 140 – 147 |
| | `broussaille` | 18 – 28 | 140 – 147 + branches 148 – 152 |
| | `fleur_echinacea` | 12 – 18 | tige 143, pétales 156 – 157 |
| | `caillou_01` `caillou_02` | 5 – 10 | grès 20 – 24 |
| `jungle/` | `liane` `vrille` | 20 – 40 (retombantes) | feuillage 128 – 134 |
| | `lierre` | 16 – 26 | 129 – 135 |
| | `feuille` | 8 – 14 | 128 – 132 |
| | `fleur_coeur` | 12 – 18 | tige 133, fleur 156 – 157 |
| | `champignon` | 6 – 12 | pied 168, chapeau 164 – 166 |
| `marais/` | `roseau` | 20 – 32 | 138 – 144 |
| | `champignon` | 6 – 12 | 164 – 169 |
| | `lierre` | 16 – 26 | 133 – 139 |
| | `fleur_ame` | 14 – 20 | tige 137, fleur 162 – 163 |
| `sable_desert/` | `cactus_01` | 40 – 52 | cactus 172 – 175 |
| | `cactus_02` | 24 – 36 | 172 – 175 |
| | `broussaille` | 16 – 24 | 141 – 147 |
| | `gres` | 20 – 40 | grès 20 – 24 |
| `neige/` | `caillou_01` | 5 – 10 | roche nue 14 – 19 |
| | `broussaille` | 14 – 22 | branches 148 – 153 |
| `toundra/` | `broussaille` | 14 – 22 | 139 – 145 |
| | `fleur_ginseng` | 10 – 16 | tige 136, fleur 158 – 159 |
| | `caillou_01` | 5 – 10 | roche lichénée 28 – 29 |
| `roche/` | `caillou_01` `caillou_02` | 6 – 12 | roche nue 14 – 19, basalte 25 – 27 |
| `gravier_fond_marin/` | `algue` | 20 – 32 | 170 – 171 + 130 – 134 |
| | `corail` | 14 – 24 | **170 – 171** |
| | `etoile_de_mer` | 4 – 8 | 156 – 157 |

**Le corail et l'algue sont les seuls à devoir employer 170 – 171.** Ces deux
entrées existent précisément parce que rien d'autre dans la palette n'est froid
et saturé ; sans elles un corail rend en vert de prairie.

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

1. les 39 `.vox` en place sous `assets/models/flore/<biome>/` ;
2. le ou les scripts Python qui les produisent, dans `tools/blender/`, avec les
   graines en dur ;
3. la sortie de `inspect_model.gd` et le compte final de la suite de tests ;
4. la liste des modèles dont tu es le moins sûr, pour retouche à la main dans
   MagicaVoxel.

---

## Note à l'intention du projet

Ce prompt fixe volontairement les **hauteurs en voxels** plutôt qu'en blocs :
c'est l'unité dans laquelle on dessine, et elle ne bouge pas si la taille du
personnage est révisée au jalon 3.1.

Les teintes indiquées sont celles des rampes actuelles de `CWPalette`, qui sont
des **rampes de départ**. Si une teinte est ajustée plus tard, les modèles
restent justes : ils portent des index, pas des couleurs.
