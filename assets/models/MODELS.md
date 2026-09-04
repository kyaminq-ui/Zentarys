# Modèles voxels Zentarys — convention et échelle

À lire avant de modéliser quoi que ce soit. La liste de ce qu'il faut produire
est dans `nextsteps.md`, §7.2 ; ce fichier dit *à quelle taille* et *avec quelles
couleurs*.

---

## 1. L'échelle de référence — fixée le 2026-09-04

**Un voxel de modèle = un bloc de terrain.** Il n'y a pas de facteur d'échelle à
l'import, et il n'y en aura pas : le modèle est estampé directement dans les
données voxels du monde, comme le fait l'original.

**Le personnage de référence mesure 8 blocs de haut.** C'est la mesure qui manque
partout ailleurs : elle n'est déductible d'aucune décompilation, le binaire ne
dit nulle part combien de blocs fait un personnage. Elle a donc été tranchée à
l'œil, sur le terrain généré, contre des mires de hauteur connue — c'est la
silhouette rouge et blanche de `docs/images/echelle_gros_plan.png`.

> **À revoir au jalon 3.1.** Quand le contrôleur de joueur sera porté, la taille
> réelle du personnage en blocs sortira de la physique d'origine. Si elle
> s'écarte de 8, c'est ce seul nombre qui change, et toutes les tailles
> ci-dessous se remettent à l'échelle avec lui. D'ici là, 8 blocs est le
> contrat : mieux vaut vingt-huit modèles cohérents entre eux et à retailler
> ensemble que vingt-huit modèles qui ne s'accordent pas.

Repères dérivés, en blocs :

| élément | hauteur | empreinte |
|---|---|---|
| personnage de référence | 8 | 3 × 1 |
| **herbe, fleur, champignon, caillou** | **2 – 4** | **≤ 4 × 4** |
| buisson, broussaille, roseau, algue, corail | 4 – 6 | ≤ 6 × 6 |
| cactus, grès | 6 – 10 | ≤ 6 × 6 |
| relief : cratère porté par un élément de tuile | 50 de creux | — |
| relief : piton | 150 | — |
| montagnes du monde généré | jusqu'à ~600 | — |

Autrement dit : **une touffe d'herbe arrive au genou du personnage**, pas à son
épaule. Le premier modèle témoin, `herbe_01`, fait 14 × 14 × 10 — soit près de
deux fois la taille du personnage. Il est à refaire au quart environ.

`docs/images/echelle_gabarit.png` montre la règle complète : dix mires de 1, 2,
3, 4, 6, 8, 12, 16, 24 et 32 blocs (un cube jaune tous les quatre blocs pour
pouvoir compter), la silhouette, puis chaque modèle chargé suivi de la même
silhouette réduite au quart et de moitié.

### Revoir l'échelle soi-même

```
# Dans scenes/terrain_demo.tscn, mettre scale_board = true sur le noeud racine
godot.windows.editor.double.x86_64.exe --path . scenes/terrain_demo.tscn
```

La démo pose le gabarit devant le point d'apparition, cadre dessus, et écrit
deux captures dans `user://shots` (vue d'ensemble, puis gros plan). **F12**
capture à tout moment. Poser un nouveau `.vox` dans `assets/models/flore/` suffit
à le faire apparaître sur le gabarit — rien d'autre à déclarer.

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
matière, nombre de voxels pleins, index employés, et il signale tout index sorti
des plages autorisées.

---

## 3. Fichiers

* Dossier `assets/models/flore/`, un `.vox` par entrée de la liste de
  `nextsteps.md`, §7.2 ; `assets/models/culture/` pour les cinq cultures.
* Noms en minuscules sans accent, souligné pour séparer, variante numérotée sur
  deux chiffres quand les modèles sont interchangeables : `herbe_01`,
  `fleur_bleuet`, `caillou_02`.
* Un même fichier sert plusieurs biomes — on ne le produit qu'une fois.

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

---

## 4. Ce qui n'est pas un modèle

* **Les arbres.** Aucun modèle d'arbre parmi les 154 chargés par l'original :
  ils sont construits par le code. Algorithme à porter, pas modèle à dessiner.
* **Les maisons.** Une grille de 3 × 3 × 4 cellules remplie procéduralement. Ce
  sont les *meubles* qui sont des modèles, pas le bâtiment.
