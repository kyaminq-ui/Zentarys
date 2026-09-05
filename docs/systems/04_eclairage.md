# Système 04 — Éclairage voxel (jalon 1.9)

Note d'analyse. Source : `qad3n/CubeWorld-Reversal`, reconstruction par classe du
binaire alpha 2013. Le pseudo-code Ghidra n'est pas recopié ; seuls le
comportement observé, les constantes et les noms de symboles le sont.

**Portée.** `VoxelChunk_propagateSunlight` (@0059a0e0), lue en entier. Une seule
fonction, entièrement déterminée : les deux passes, les quatre constantes et la
disposition des octets de lumière en sortent sans ambiguïté.

**État du portage : analysé, pas implémenté.** La §6 dit pourquoi, et ce que
cela coûterait.

---

## 1. La forme générale

Deux passes, sur une zone de chunks élargie d'une **marge** — la lumière déborde
d'un chunk sur l'autre, donc on calcule plus large que ce qu'on publie.

1. **descente du soleil**, une fois, colonne par colonne ;
2. **diffusion**, **seize itérations**, en double tampon.

Puis une passe de publication, sur la zone intérieure seulement.

---

## 2. Ce qui est transparent

Le test revient partout, à l'identique :

```
type = attributs & 0x1f
transparent  <=>  type == 0  ou  type == 2
```

Le type 0 est l'air. **Le type 2 laisse passer la lumière sans être de l'air** —
c'est très vraisemblablement l'eau, ce que corrobore `docs/systems/03`, §4 : la
sentinelle d'eau est un bloc distinct du témoin d'air, et l'eau doit
évidemment se laisser traverser par le soleil.

Un seul autre type est nommé : **le type 13 (0x0d) est une source de lumière**,
et il contribue toujours `255` à ses voisins, quelle que soit sa propre valeur.

> Ces trois numéros — 0 air, 2 eau, 13 lampe — sont les seuls types de blocs que
> le binaire nomme explicitement dans tout ce qui a été lu jusqu'ici. Ils ne
> suffisent pas à résoudre la correspondance de numérotation qui bloque
> `docs/systems/02`, §9, mais ce sont les trois premiers points d'ancrage.

---

## 3. Passe A — la descente du soleil

Pour chaque colonne de la zone élargie, on part du **haut** de la plage stockée
et on descend :

```
exposé = vrai
pour chaque voxel, du haut vers le bas :
    si transparent :
        si exposé : lumière = 255
        sinon      : lumière = 0
    sinon :
        exposé = faux
```

C'est tout. Il n'y a **pas** d'atténuation verticale : sous le ciel on est à
255, sous le premier bloc opaque on est à 0, immédiatement.

---

## 4. Passe B — la diffusion, seize fois

Pour chaque voxel transparent dont la lumière n'est pas déjà 255 :

```
m = max sur les quatre voisins horizontaux (x±1, z±1), à la même altitude :
        voisin de type 13   -> 255
        voisin transparent  -> max(lumière du voisin, 5)
        voisin opaque       -> 0
lumière suivante = m * 85 / 100
```

Quatre choses méritent d'être relevées :

- **la diffusion est purement horizontale.** Aucun voisin en Y n'est consulté.
  Le vertical est entièrement traité par la passe A : une ouverture dans un
  plafond éclaire sa propre colonne jusqu'au sol, et c'est de là que la lumière
  s'étale, étage par étage ;
- **l'atténuation est multiplicative, `× 0,85` par bloc** — et non le `− 1` par
  bloc de Minecraft. Après seize pas il reste `0,85^16 ≈ 7 %` ;
- **le plancher de 5** : un voisin transparent contribue au moins `5/255 ≈ 2 %`.
  Aucun recoin ne tombe donc jamais au noir absolu. C'est l'ambiante, et elle est
  dans l'algorithme, pas dans le rendu ;
- **seize itérations**, ce qui fixe du même coup la portée de la lumière et la
  marge nécessaire autour de la zone publiée.

### Le double tampon, et les trois octets

C'est ce qui explique la disposition relevée en `docs/systems/03`, §3. Pour un
voxel **transparent**, les trois premiers octets ne sont pas une couleur : ce
sont trois cases de lumière.

| octet | rôle |
|---|---|
| +1 | valeur **suivante**, écrite par l'itération en cours |
| +2 | valeur **courante**, lue par les voisins |
| +0 | valeur **publiée**, celle que le maillage lira |

Chaque itération écrit `+1`, puis une seconde balayage recopie `+2 = +1` — le
échange de tampon. Sans lui, la lumière se propagerait de plusieurs blocs par
itération dans le sens du parcours et d'un seul dans l'autre, et l'éclairage
dépendrait de l'ordre de balayage.

À la toute fin, et **seulement sur la zone intérieure** (sans la marge),
`+0 = +2`. La marge a servi à calculer juste ; elle n'est pas publiée.

---

## 5. Ce que cela donnerait sur ce projet

Le terrain porté est un **champ de hauteurs pur** : pas de grottes, pas de
surplombs. La passe A y répond donc entièrement, et sa réponse est triviale —
tout ce qui est au-dessus de la surface est à 255, tout ce qui est dessous est à
0 et n'est de toute façon jamais visible.

> **L'éclairage voxel ne change rien à un monde intact.** Il ne devient visible
> qu'aux endroits que le joueur a creusés — c'est-à-dire exactement ce que le
> jalon 1.8 vient de rendre possible. C'est la bonne nouvelle sur le calendrier :
> 1.9 arrive juste après le système qui lui donne quelque chose à éclairer.

---

## 6. Ce qui bloque le portage : le rendu, pas le calcul

Le calcul est facile et se poserait bien : c'est une passe par chunk, et il n'y
a pas de dépendance longue portée à gérer puisque la marge est bornée à seize.

**Le problème est de faire arriver la valeur à l'écran.** `VoxelMesherCubes`
n'a pas de canal de lumière. Il a trois modes de couleur :

| mode | ce qu'il fait | utilisable ici |
|---|---|---|
| `COLOR_MESHER_PALETTE` | index → couleur de palette, cuite en couleur de sommet | **actuel** ; aucun endroit où loger la lumière |
| `COLOR_SHADER_PALETTE` | l'index part au nuanceur | la lumière n'a toujours pas de canal pour voyager |
| `COLOR_RAW` | le canal **est** la couleur | le seul qui permette de moduler |

Le portage complet suppose donc de passer le canal de couleur en **`COLOR_RAW`**,
c'est-à-dire de stocker par voxel une couleur `RGBA` au lieu d'un index — et
d'y pré-multiplier la lumière.

> **C'est exactement ce que fait l'original** (`docs/systems/03`, §3 : trois
> octets de couleur par bloc, avec une gigue et un canal vert modulé par du
> bruit). Le rapprochement n'est pas fortuit : on ne peut pas éclairer par voxel
> un rendu dont la couleur est un index partagé.

**Ce que le changement coûterait :**

- le canal de couleur passe de 1 à 2 octets par voxel (RGBA4444) ou 4 (RGBA8888) ;
- `CWVoxelGenerator` écrit des couleurs au lieu d'index — et perd le bénéfice
  des remplissages par intervalle sur les grands aplats ? non, `fill_area`
  fonctionne pareil, mais la valeur devient dépendante de la lumière, donc du
  voisinage : les chemins rapides « bloc entièrement plein » sont à revoir ;
- `CWVoxelModel` charge ses `.vox` en index via `VoxelVoxLoader` : il faudrait
  convertir à l'import ;
- toutes les vérifications qui lisent `CHANNEL_COLOR` en attendant un index —
  il y en a dans les trois fichiers de test.

**Ce que le changement rapporterait, en plus de la lumière :** c'est peut-être
la réponse à la **dalle d'eau du LOD 1** (`docs/ROADMAP.md`), restée
inexpliquée. Une couleur survit à une moyenne de résolution ; un index de
palette non. L'hypothèse est formulée en `docs/systems/03`, §3 et attend d'être
mise à l'épreuve.

**La palette ne disparaîtrait pas** : elle resterait la *source* des couleurs et
le contrat d'authoring des modèles `.vox`. Ce qui change est l'encodage du
canal, pas le nuancier — les 39 modèles de flore ne seraient pas à repeindre.

---

## 7. Décision à prendre

Deux voies, et elles ne se recouvrent pas :

1. **passer en `COLOR_RAW` et porter l'éclairage en entier.** Gros chantier, qui
   touche le générateur, les modèles, et les tests ; il ouvre la lumière par
   voxel et met à l'épreuve l'hypothèse du LOD ;
2. **rester en palette indexée** et refermer 1.9 sur ce qui n'en dépend pas —
   la flore qui suit le terrain édité, faite le 2026-09-05 — en gardant cette
   note comme l'état de l'art du système, à reprendre quand le rendu bougera
   pour une autre raison.

La note ci-dessus est valable dans les deux cas : l'algorithme est établi, et
c'est la partie qui ne se redécouvre pas.
