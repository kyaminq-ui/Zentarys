# Système 03 — Colonnes persistantes et édition (jalon 1.8)

Note d'analyse. Source : `qad3n/CubeWorld-Reversal`, reconstruction par classe du
binaire alpha 2013. Le pseudo-code Ghidra n'est pas recopié ; seuls le
comportement observé, les constantes et les noms de symboles le sont.

**Portée.** Le chemin de lecture et d'écriture d'un bloc :
`World_getBlockFloat` (@00406050), `World_getBlockAt` (@00405fd0),
`Chunk_getColumnAt` (@00406100), `Column_getBlockChecked` (@00405f20),
`Region_getChunkCell` (@00406290), `Grid_lookup1024` (@00406210) et
`VoxelColumn_setBlock` (@0041fe60). Sept fonctions courtes et sans ambiguïté —
c'est le système le mieux déterminé rencontré jusqu'ici.

**Ce qui en est porté** est volontairement mince, et la §6 dit pourquoi : la
structure de données de l'original est exactement le rôle que Voxel Tools tient
déjà, en natif. Ce qui se porte, ce sont les **règles** qu'aucun moteur ne
devine.

---

## 1. L'échelle du monde, confirmée par un autre chemin

`Chunk_getColumnAt` commence par rejeter toute coordonnée hors de
`[0, 0x1000000)` sur les deux axes horizontaux. **0x1000000 = 16 777 216**, ce
qui est exactement `CWWorldParams.WORLD_SIZE`.

Cette valeur avait été obtenue par un tout autre raisonnement : la grille de
sites de région fait 1024 × 1024 zones (`docs/systems/01`) et une zone vaut
16 384 unités, donc 1024 × 16 384 = 16 777 216. Le binaire porte le même nombre
en dur, dans une fonction qui ne connaît ni les zones ni les sites. Les deux
lectures se recoupent.

`Grid_lookup1024` (@00406210) borne son index à `0..0x3ff` : c'est **la grille
de zones**, 1024 de côté, et elle est indexée avant la grille de chunks. Elle
donne son nom au portage `CWRegionSiteGrid`.

### L'échelon manquant : le chunk de 256 colonnes

L'échelle du monde se lisait jusqu'ici : monde → zone (16 384) → tuile (2 048) →
bloc. Il y a un barreau de plus, entre la tuile et le bloc :

| échelon | côté | par échelon supérieur | d'où il vient |
|---|---|---|---|
| monde | 16 777 216 | — | borne de `Chunk_getColumnAt` |
| zone | 16 384 | 1024 × 1024 | `Grid_lookup1024`, bornes `0..0x3ff` |
| tuile | 2 048 | 8 × 8 par zone | `World_generateRegionFeatures`, §2.7 de `01` |
| **chunk** | **256** | **8 × 8 par tuile** | `Chunk_getColumnAt`, décalage `>> 8` |
| colonne | 1 | 256 × 256 par chunk | idem |

Le chunk de 256 × 256 colonnes est **la cellule que construit
`WorldInfo_generateBiomeContent`** (`docs/systems/02`, §1). Les deux analyses,
menées séparément, décrivent le même objet — et le tableau ci-dessus dit
maintenant où il se range : un soixante-quatrième de tuile.

`Region_getChunkCell` (@00406290) borne ses indices de chunk à `0..0xffff`, soit
65 536 — et 16 777 216 / 256 = 65 536. Troisième recoupement.

---

## 2. La colonne

`Chunk_getColumnAt(monde, x, y, chunk)` rend un pointeur de colonne :

```
colonne = *(chunk + 0xa8) + (lx + ly * 0x100) * 0x20
```

- le tableau des colonnes est à `+0xa8` dans le chunk ;
- l'index est `lx + ly · 256` — **x contigu**, y en lignes ;
- une colonne fait **0x20 = 32 octets**.

Le paramètre `chunk` est un indice : à zéro, la fonction le résout elle-même par
`Region_getChunkCell(x >> 8, y >> 8)` ; sinon elle le prend pour argent comptant
mais **vérifie qu'il contient bien (x, y)**, en comparant à ses champs `+0x60` et
`+0x64` multipliés par 256 — ce sont les indices de chunk, et cela confirme que
la base du chunk est `indice · 256`.

Champs de la colonne établis :

| offset | champ |
|---|---|
| +0x10 | `base_z` — altitude du premier bloc stocké |
| +0x18 | pointeur vers le tableau de blocs |
| +0x1c | nombre de blocs |

> **Une colonne n'est pas un tableau pleine hauteur, c'est une *plage*.** Elle
> stocke `count` blocs consécutifs à partir de `base_z`, et rien d'autre. C'est
> le modèle de données que la feuille de route avait déjà identifié comme celui
> de Distant Horizons, et que `CWTerrainField.sample_column` produit déjà.

---

## 3. Le bloc — quatre octets, et une couleur

`Column_getBlockChecked` (@00405f20) indexe le tableau par pas de **4 octets**.
Les sentinelles qu'elle renvoie hors bornes en donnent la disposition :

- sous la colonne : octets `00 00 00 01` ;
- au-dessus : octets `ff ff ff 00`.

Soit **trois octets de couleur puis un octet d'attributs**. L'octet 3 est
décomposé par les appelants :

| bits | usage | où on le voit |
|---|---|---|
| 0–4 (`& 0x1f`) | type de bloc, 32 valeurs | `World_getBlockAt`, `VoxelColumn_setBlock` |
| 6 (`& 0x40`) | drapeau, posé à l'écriture du décor | `World_getBlockAt`, `World_fillVoxelColumnTyped` |
| 7 (`& 0x80`) | **protection** | `VoxelColumn_setBlock` |

> **La couleur est par bloc, ce n'est pas un index de palette.**
> `World_fillVoxelColumnTyped` (@005df600) le montre en clair : elle prend une
> couleur `byte[3]`, y ajoute une gigue tirée d'une table de 23 entrées indexée
> par un hachage spatial, et **pousse le canal vert vers 120 en fonction d'un
> échantillon de bruit** avant d'écrire. Chaque bloc porte donc sa teinte, et
> deux blocs du même type n'ont pas la même.
>
> Ce projet stocke un *index* sur un octet, et c'est un choix assumé (le rendu
> `VoxelMesherCubes` en mode palette). Mais cela éclaire peut-être la **dalle
> d'eau du LOD 1** restée inexpliquée dans `docs/ROADMAP.md` : une couleur RVB
> survit à une moyenne de résolution, un index de palette non. C'est une piste,
> pas une démonstration — la réduction n'a pas été localisée.

---

## 4. L'eau n'est pas de la matière

C'est le résultat le plus directement utilisable de cette passe.
`World_getBlockAt` (@00405fd0) ne lit **jamais** un bloc d'eau stocké. Au-dessus
de la matière d'une colonne, il rend une sentinelle, et laquelle dépend de
l'altitude :

```
si z >= base_z + count :      z > 0  ->  sentinelle « air »
                              z <= 0 ->  sentinelle « eau »
```

Et même pour un bloc **stocké**, si son type est nul, que `z < 1` et que le
drapeau `0x40` est absent, la fonction le rabat sur la sentinelle « eau ».

> **Le niveau de la mer de l'original est `z = 0`, et sous cette altitude le vide
> est de l'eau.** `CWWorldParams.sea_level` vaut déjà 0 — les deux coïncident
> sans qu'on l'ait cherché.

Conséquence pour l'édition, et c'est la règle portée : **creuser sous le niveau
de la mer laisse de l'eau, pas un trou.** Une tranchée depuis la plage se
remplit. C'est `CWWorldEdits.erase_value`, et c'est la seule règle d'édition que
la source donne explicitement.

---

## 5. L'écriture

`VoxelColumn_setBlock` (@0041fe60) écrit un bloc à un index relatif à `base_z` :

- **index négatif** → `resize_dword_array(colonne, count - index, -index)` : le
  tableau grandit **vers le bas** et son contenu est décalé. Une colonne
  s'étend donc dans les deux sens, à la demande ;
- **index ≥ count** → il grandit vers le haut ;
- si le bloc visé porte déjà la **protection** (`0x80`) :
  - écrire de l'air (type 0) est **refusé, en silence** ;
  - écrire de la matière est accepté et **repose** la protection.

> La protection est donc un « ceci n'est pas du terrain ». Ses producteurs sont
> les structures — maisons, donjons —, c'est-à-dire le jalon 4 : rien ne la pose
> aujourd'hui. Elle n'a pas non plus où se ranger dans un canal d'un octet qui
> porte déjà un index de palette. Le jour où 4.2 arrive, c'est un second canal
> (`CHANNEL_DATA2`) qui l'accueillera ; la réserver maintenant coûterait de la
> mémoire pour rien.

---

## 6. Ce qui est porté, et ce qui ne l'est pas

La structure de l'original — grille de chunks, colonnes paginées, plages
redimensionnables — est **exactement** le rôle que tient `VoxelTerrain` : blocs
de données, pagination par distance, accès depuis un pool de fils, et un
`VoxelStream` pour le disque. La réécrire serait porter une *implémentation*, ce
que la méthode du projet exclut explicitement.

Ce qui est porté, en `src/worldgen/cw_world_edits.gd` :

| règle | source |
|---|---|
| creuser sous le niveau de la mer laisse de l'eau | §4 |
| le monde est borné à `WORLD_SIZE`, hors bornes est sans effet | §1 |
| une requête hors du monde chargé retombe sur le champ, sans se plaindre | `World_getBlockAt` |

Et la persistance suit le modèle de l'original — qui ne sérialise que les
colonnes touchées — par `VoxelStreamSQLite` avec
`save_generator_output = false` : le monde intact reste procédural, seul le
*diff* part sur le disque. Mesure du 2026-09-05 : 647 éditions occupent 20 Ko.

**Non porté, et pourquoi :**

- la **protection** (§5) — pas de producteur avant le jalon 4, pas de place dans
  un canal d'un octet ;
- la **couleur par bloc** (§3) — le projet est en palette indexée, c'est un choix
  de rendu antérieur et cohérent ;
- le **sol du monde** : l'original borne X et Y mais laisse l'axe vertical libre,
  la colonne grandissant vers le bas à la demande. Ici le terrain a des bornes
  fixes, donc `CWWorldEdits` refuse de creuser la dernière couche. Décision de ce
  projet, pas un portage.

---

## 7. Ce qui reste ouvert

1. **La flore ne réagit pas aux éditions.** Creuser un cratère y laisse les
   plantes en l'air : elles sont instanciées à partir du relief *généré*, que
   l'édition ne change pas. C'était une conséquence connue et acceptée de la
   décision du 2026-09-04 de sortir la flore des données voxels ; elle est
   simplement devenue visible. La corriger demande une requête d'édition par
   plante — ~75 µs pièce sur le chemin de construction des cellules — donc à
   traiter avec le jalon 1.9, pas avant.
2. **Les collisions ne sont pas branchées.** `CWWorldEdits.voxel_at` est la
   primitive dont le jalon 2 aura besoin ; `generate_collisions` reste à faux et
   le sera jusqu'au contrôleur du jalon 3.1.
3. **Le type de bloc sur 5 bits** (§3) donne 32 valeurs, et `CWPalette` réserve
   justement 1..31 au terrain. La coïncidence est jolie mais ne prouve rien :
   la correspondance des numérotations reste l'inconnue n° 1 de
   `docs/systems/02`, §9.
