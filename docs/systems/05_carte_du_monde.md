# Système 05 — Carte du monde (jalon 1.10)

Note d'analyse. Source : `qad3n/CubeWorld-Reversal`, reconstruction par classe du
binaire alpha 2013. Le pseudo-code Ghidra n'est pas recopié ; seuls le
comportement observé, les constantes et les noms de symboles le sont.

**Portée.** Onze fonctions, lues en entier :

| symbole du dépôt | adresse | ce que c'est réellement |
|---|---|---|
| `cube::WorldMap::ctor_1` | @005fae40 | construction : curseur, sprites de marqueurs, deux grilles 1024² |
| `WorldMap_ctor` | @00601f80 | en fait le **destructeur** : il écrit `discovered` puis libère |
| `GameController_tryLockAndProcess` | @005fc160 | **`WorldMap::markDiscovered`** — le seul point d'écriture de la découverte |
| `hash_or_index_compute` | @00602440 | **`WorldMap::getTile(x, z)`** — l'indexation de la grille de cases |
| `GameController::loadLandscapeTile` | @006024d0 | **le cœur** : construit ou relit la pièce de carte d'une zone |
| `locked_pair_update` | @00601cc0 | recherche du **site de région le plus proche** (déjà porté) |
| `GameController_getField16` | @004a6ad0 | cellule de 16 octets par chunk, dans la région |
| `GameController_getVoxelColumn8` | @00487da0 | enregistrement d'élément de tuile (`0x68`, `+0x14018`) |
| `NameGen_generateRegionName` | @005a6550 | **le nom d'une région** : deux syllabes tirées de deux tables de 20 |
| `Terrain_sampleHeightNoise` | @0059fc90 | **la déformation du domaine**, en unités de zone — pas une altitude |
| `World_getColumnDataAt2` | @005eefa0 | la déformation ±768 du terrain, à l'identique |

**État du portage : fait.** `CWWorldMap` et `CWRegionName`, `tests/map_test.gd`.

---

## 1. L'échelon manquant : la case de carte

Le jalon 1.8 avait recomposé l'échelle du monde jusqu'au chunk de 256 colonnes.
La carte s'appuie dessus, et le confirme une troisième fois :

```
WorldMap::getTile(x, z) :
    rejette hors de [0, 0x10000)          <- 65 536 cases de côté
    zone   = (x >> 6, z >> 6)             <- grille 1024 x 1024
    case   = (x & 63, z & 63)             <- 64 x 64 cases par zone
    retour = zone.cases + (cx * 0x40 + cz) * 0x34
```

`0x10000` cases pour `0x1000000` unités : **une case de carte vaut 256 unités**,
c'est-à-dire exactement un chunk. La carte du monde est donc dessinée à raison
d'**un pixel par chunk**, et son unité de découverte est le chunk — pas la zone,
pas la tuile.

Chaque case fait `0x34` octets (`cube::ZoneTile`), dont :

| décalage | contenu |
|---|---|
| `+0x10` … `+0x1f` | copie des 16 octets de résumé du chunk (`getField16`) |
| `+0x30` | drapeaux : **bit 0 = découverte**, bit 1 = données chargées |

---

## 2. La découverte

Une seule fonction écrit le drapeau, et elle est minuscule :

```
WorldMap::markDiscovered(x, z) :          # x, z en cases de carte
    verrou
    case = getTile(x, z)
    si case existe et (case.drapeaux & 1) == 0 :
        case.drapeaux |= 1
        compteur += 1
    fin verrou
```

Le compteur — un seul entier — est ce qui est **persisté**, sous la clé
`"discovered"`, en quatre octets, à la fermeture (@00601f80) et à chaque
sauvegarde (`GameController.cpp:93400`). C'est le pourcentage d'exploration, pas
la carte.

> **La carte elle-même se persiste ailleurs et autrement** : par *pièce*, sous
> une clé construite à partir des coordonnées de zone, en image compressée par
> zlib (`loadLandscapeTile`). Le drapeau de découverte, lui, voyage dans le
> résumé de chunk de la région. Deux stockages, deux granularités.

---

## 3. La pièce de carte est une cellule de Voronoï

C'est le résultat le plus important de cette note, et il n'était pas prévisible
depuis l'apparence du jeu.

`loadLandscapeTile(zx, zz)` construit la pièce de la zone `(zx, zz)` ainsi :

```
pour cx de zx*64 - 64 à (zx+2)*64 :          # la zone, plus une zone de marge
  pour cz de zz*64 - 64 à (zz+2)*64 :
        p = déformer(cx * 256, cz * 256)     # World_getColumnDataAt2
        d = distance²(site(zx, zz), p)
        si un des 8 sites voisins est plus proche : passer
        garder le pixel ; étendre la boîte englobante
```

Autrement dit : **une pièce est l'ensemble des chunks dont le site de région le
plus proche, dans le domaine déformé, est celui de la zone.** Une seconde passe,
identique, remplit l'image aux dimensions de la boîte englobante.

Trois conséquences :

- la carte n'est **pas** un quadrillage de zones : c'est un puzzle de pièces
  irrégulières, aux frontières ondulées par la déformation de ±768 unités ;
- ces frontières sont **exactement celles du climat** — le mélange de sites du
  jalon 1.3 et cette recherche de plus proche site partagent le point déformé.
  Une pièce de carte est une région climatique, au pixel près ;
- la marge d'une zone entière n'est pas de la prudence : le site d'une zone est
  tiré n'importe où dans ses 16 384 unités, donc sa cellule peut mordre loin
  dans la zone voisine.

`World_getColumnDataAt2` (@005eefa0) est mot pour mot la déformation déjà portée
en `CWTerrainField.warped_point` : bruit à `5e-4`, amplitude `3 × 256`, graines
`3423` et `23421`, **axes croisés** (le décalage en X se tire de Z). La recherche
du plus proche site est `CWTerrainField.nearest_site`, portée au jalon 1.6 sous
le nom `World_findNearestEntityInRegion`. **Le jalon 1.10 n'apporte donc aucune
nouvelle constante numérique** — il assemble ce qui existe.

---

## 4. L'image ne porte pas de couleur

Le remplissage n'écrit que trois valeurs, et elles sont grises :

| valeur RVB | quand |
|---|---|
| `200, 200, 200` | aucune case de carte à cet endroit (chunk jamais approché) |
| `220, 220, 220` | la case existe, drapeaux non nuls, **bit 0 à zéro** : connue, non découverte |
| `255, 255, 255` | **bit 0 à un** : découverte |

Trois clartés, pas de teinte. La couleur d'une région vient donc d'ailleurs, au
moment du dessin — l'image stockée est un **masque de clarté**, et la pièce est
teintée à l'affichage.

C'est ce que le portage fait : `CWWorldMap` garde la clarté par chunk et la
teinte par région, et ne les combine qu'au rendu.

---

## 5. Les marqueurs viennent des éléments de tuile

`WorldMap::ctor_1` charge cinq modèles nommés — `map-tile-plains.cub`,
`map-tile-village.cub`, `map-tile-forest.cub`, `map-tile-mountains.cub`,
`map-tile-hills.cub` — plus `skull.cub`, et construit à la main un curseur de
4 × 4 voxels : bordure `(10, 10, 10)`, centre `(255, 255, 255)`.

Et dans `loadLandscapeTile`, après avoir copié les résumés des 64 × 64 chunks,
une seconde boucle parcourt les **8 × 8 tuiles** de la zone et recopie, pour
chacune, un enregistrement de `0x68` octets pris à `+0x14018` de la région.

> Ce couple `0x68` / `+0x14018` est celui du jalon 1.6, relevé une troisième
> fois. Les marqueurs de la carte **sont les éléments de tuile** : bourg,
> donjon, cratère, plan d'eau. Rien de neuf à générer — la couche existe depuis
> le 2026-09-04, il fallait seulement savoir qu'elle alimentait la carte.

---

## 6. Le nom d'une région

`NameGen_generateRegionName(x, z)` :

```
(deux tables de 20 chaînes, initialisées une fois, sous garde de bits)

p = Terrain_sampleHeightNoise(x, z)      # domaine déformé, en unités de zone
a = int(p.x) ;  b = int(p.z)
nom = tableA[(a*3 + graineA + b) % 20] + tableB[(b*3 + graineB + a) % 20]
```

Deux relevés :

- **`Terrain_sampleHeightNoise` n'échantillonne pas une altitude.** Elle rend un
  point déformé — deux octaves (`0,01` pondérée à `0,1`, et `5e-4`), amplitude
  `500` — **divisé par 16 384**, donc exprimé en zones. C'est mot pour mot
  `CWTerrainField.edge_warped_point`, portée au jalon 1.4 sous le nom
  `World_sampleTerrainGradient`. Septième nom trompeur du dépôt d'analyse.
- le nom est donc constant sur une **cellule de zone du domaine déformé**, ce qui
  recoupe les pièces de carte sans les épouser : deux mécanismes voisins, pas le
  même. Le portage nomme une pièce en évaluant la formule **à la position du
  site**, ce qui donne un nom et un seul par pièce.

`graineA` et `graineB` sont deux entiers du bloc de données du monde
(`+0x80028c`, `+0x800290`), du même tonneau que les 28 décalages de bruit : leur
séquence d'initialisation n'est pas récupérable, on les dérive du LCG comme les
autres (`CWWorldParams`, même choix, même raison).

> **Les syllabes, elles, ne sont pas portées.** Six sont lisibles en clair dans
> le binaire ; ce sont des créations artistiques du jeu d'origine, donc hors du
> périmètre « clean room ». `CWRegionName` porte **deux tables originales de
> 20 syllabes**, écrites pour ce projet. Le mécanisme — deux tables de vingt, la
> formule d'indice, la concaténation — est porté à la lettre.

---

## 7. Ce qui est porté, et ce qui s'en écarte

**Porté à la lettre :** la case de 256 unités et la grille 65 536², les trois
clartés `200 / 220 / 255`, le bit de découverte et son compteur, la cellule de
Voronoï dans le domaine déformé (même déformation, même fenêtre 3 × 3), les
marqueurs pris aux éléments de tuile, la formule de nom.

**Trois écarts, délibérés :**

1. **La dalle plutôt que la pièce.** L'original stocke une pièce par zone, à sa
   boîte englobante, et la dessine comme un sprite. `CWWorldMap` garde une
   **dalle de 64 × 64 cases par zone**, où chaque case porte l'indice de la zone
   propriétaire. Même géométrie (le propriétaire est calculé par la même
   recherche), mais un cache qui se compose par simple juxtaposition et se
   déplace sans recouvrement. Le contour du puzzle est retrouvé au rendu, là où
   deux cases voisines changent de propriétaire.
2. **La teinte d'une région est échantillonnée à son site.** L'original tire sa
   couleur d'affichage d'un chemin qui n'est pas dans les fonctions lues ; on
   prend le bloc de surface de la colonne du site (`CWPalette.surface_index`),
   ce qui donne une couleur par région et respecte le fait que l'image stockée
   n'en porte pas.
3. **La mer est peinte en eau.** `surface_index` rend du sable ou du gravier sous
   le niveau de la mer, ce qui est juste pour le terrain et illisible sur une
   carte. Une région dont le site est océanique est peinte en eau.

**Pas porté :** le stockage compressé par pièce (notre dalle se recalcule en
38 ms et le cache mémoire suffit tant qu'il n'y a pas de partie longue à
reprendre) ; les six modèles de marqueurs, qui sont des assets à produire et
rejoignent la liste du jalon 4.

---

## 8. Corrections de sources

Quatre noms de plus à la liste des noms trompeurs du dépôt d'analyse :

- **`hash_or_index_compute` (@00602440) ne calcule pas de hachage** : c'est
  `WorldMap::getTile`, l'indexation à deux niveaux de la grille de cases.
- **`GameController_tryLockAndProcess` (@005fc160) n'est pas un enrobage de
  verrou** : c'est `WorldMap::markDiscovered`, le seul endroit du binaire qui
  écrive le bit de découverte.
- **`locked_pair_update` (@00601cc0) ne met rien à jour** : c'est la recherche du
  site de région le plus proche sur la fenêtre 3 × 3, déjà portée en
  `CWTerrainField.nearest_site`.
- **`Terrain_sampleHeightNoise` (@0059fc90) n'échantillonne pas une altitude** :
  c'est la déformation du domaine à ±500, rendue en unités de zone (§6).

Et un nom exact, pour une fois : `WorldMap_ctor` (@00601f80) est bien le
destructeur, ce que la fiche du dépôt annonce sous le mot « ctor ».
