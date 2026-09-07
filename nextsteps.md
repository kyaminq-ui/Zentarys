# Zentarys — reprise de session

Fichier de reprise après un `/clear`. Il porte **les décisions qui coûtent cher
à redécouvrir**, et rien d'autre : où sont les choses, les commandes, les
invariants, les pièges, les décisions ouvertes.

> **Pour démarrer, `CLAUDE.md` suffit** — 180 lignes, les commandes et les cinq
> invariants les plus chers. Ce fichier-ci se lit quand on va toucher au monde.
> Le **récit des sessions** — mesures, essais ratés, tableaux avant/après — est
> en annexe de `docs/ROADMAP.md` depuis le 2026-09-10 : il est ce qui empêche de
> refaire une erreur, mais il n'a pas sa place au début du fichier qu'on lit en
> premier.

---

## 0. La prochaine session — **cinq demandes, 2026-09-11 au soir**

> **Rien n'en est commencé.** Le programme précédent — les cinq demandes du
> 2026-09-10 — est entièrement traité ; son compte rendu est en §0ter, et le
> récit est dans le journal de `docs/ROADMAP.md`.

Les trois premières touchent au monde, les deux dernières à la carte. **Deux
d'entre elles ferment quelque chose que la session du 2026-09-11 a ouvert**, et
c'est dit à sa place.

**Et quatre choses traînent depuis la veille, hors de ce programme.** Aucune
n'est bloquante, et aucune ne s'oppose à ce qui suit :

| ce qui traîne | où | pourquoi ça n'est pas fait |
|---|---|---|
| **compiler la GDExtension** | §0ter.5 | le SDK Windows n'est pas installé sur cette machine. C'est une modification de la machine, pas du projet |
| **la collision des cactus** | §0ter.2 | ils sont à 4 voxels par bloc : inestampables. Ils veulent une forme de physique, et c'est le jalon 3.1 |
| **la saccade au chargement** | §0ter.4 | affaire de latence, pas de débit. Aucune mesure ne la voit ; elle se juge manette en main |
| **la gigue de taille des cinq arbres entiers** | §0ter.2 | perdue en passant en matière. La variété devra venir de variantes de modèles |

Plus les quatre points de fond listés en fin de §0ter — les fichiers à mille
lignes, la falaise, le plafond du cache, et 2.6.

---

### 1. Un biome, une matière — et la roche seulement en falaise

*Corriger les biomes et leurs surfaces : Greenlands/herbe, Deserts/sable,
Jungles/jungle (supprimer marais), Oceans/gravier, Lava Lands/scorie et magma.
La surface roche sert uniquement pour les falaises.*

**La moitié est déjà là, et c'est la moitié qui ne bougera pas.**
`CWPalette._plain_of` rend déjà une matière et une seule par biome — neige,
sable, jungle, herbe —, et l'en-tête qui la précède raconte les trois franges
retirées le 2026-09-06 pour exactement cette raison : *un biome, une matière de
plaine, sans exception*. La demande prolonge cette règle, elle ne la contredit
pas.

**Ce qui reste à faire, mesuré le 2026-09-11** (parts du monde) :

| matière | part | d'où elle vient | ce qu'il faut |
|---|---|---|---|
| roche | **2,8 %** | deux sources : la falaise (voulue) **et la bande de roche de Lava Lands** | couper la seconde |
| marais | 0,1 % | la **rive** d'un plan d'eau, en Jungles seulement | la retirer |
| terre | 1,0 % | le **lit** des mares (`subsurface_index`) | à trancher, ce n'est pas une matière de biome |
| sable | 18,1 % | le désert **et** la plage **et** le haut-fond | voir plus bas |
| gravier | 15,3 % | le fond marin profond | l'étendre à tout l'océan |

**Trois pièges, et le premier est un piège de suppression :**

* ⚠️ **le roseau ne pousse que sur le marais.** `CWDecorRules.FAMILIES_SURFACE`
  et `FAMILIES_SURFACE_BIOME` indexent deux rôles **par matière** et non par
  biome — le marais en est un. Retirer la matière sans retirer son entrée laisse
  un rôle que la surface sait choisir et que rien ne peut plus poser : la plante
  disparaît, la densité moyenne ne bouge pas assez pour se voir, et **aucun test
  de table ne le signale** (invariant n° 22, qui est exactement ce cas). Il faut
  décider *où va le roseau* avant de retirer le marais, pas après ;
* ⚠️ **la bande de roche de Lava Lands est celle qui a triplé le 2026-09-11.**
  Elle est passée de 0,3 % à 2,8 % du monde parce que le niveau de la mer est
  descendu de soixante blocs et que la règle est exprimée en altitude *au-dessus
  de la mer* (§0ter.3). La couper ferme donc **deux points d'un coup** : la
  demande d'aujourd'hui, et l'effet de bord laissé ouvert hier. C'est la branche
  `lava_rock` / `ROCK_MIN` de `CWPalette.surface_shaded` ;
* ⚠️ **la plage n'est pas dans la liste, et il faut trancher exprès.** Prise à la
  lettre, « un biome une matière » retire aussi le sable de rivage — et le
  fichier a une opinion écrite en face : *une matière qui vaut la peine est celle
  qui nomme un endroit, pas celle qui nuance un gradient*. La plage et la rive
  nomment un endroit ; la frange d'humidité n'en nommait pas. **Recommandation :
  garder la plage, retirer le marais** — mais c'est une décision, pas une
  déduction, et il vaut mieux la poser avant de commencer.

Idem pour le haut-fond : l'océan mélange aujourd'hui du sable près du rivage et
du gravier au large, sur douze blocs de fond. « Oceans/gravier » demande de le
supprimer ; c'est la seule transition qu'on voit **à travers l'eau**, et c'est
aussi ce qui distingue une plage d'une falaise vue de la mer.

---

### 2. Un biome a une taille minimum

*Un biome doit faire une taille minimum, pour éviter des transitions trop
rapides.*

**Il n'existe rien pour ça aujourd'hui, et c'est structurel.** `CWBiome.at` est
une **fonction pure d'une colonne** : elle compare le climat de ce point à des
seuils, sans savoir ce que valent les colonnes voisines. Un biome peut donc
faire une colonne de large partout où le climat frôle un seuil, et rien dans le
code ne l'en empêche.

> ⚠️ **Et la session du 2026-09-11 a rendu le défaut plus visible, mécaniquement.**
> Les quatre seuils de température allaient de 0,16 à 0,985 ; ils vont maintenant
> de 0,28 à 0,63. Ils sont donc **2,4 fois plus serrés**, sur un champ de climat
> qui n'a pas changé de pente : à distance parcourue égale, on traverse 2,4 fois
> plus de frontières. *L'égalisation des six parts a acheté l'égalité au prix de
> la longueur d'onde*, et c'est très probablement ce qui se voit en jeu.

**Deux routes, et elles ne coûtent pas la même chose.**

1. **Lisser davantage le champ de climat.** C'est le levier le plus direct — les
   provinces climatiques ont trois constantes réglées à l'œil sur une seule
   graine (fréquence, largeur du cœur, décalages), et `tools/biome_stats.gd`
   mesure ce qu'elles rendent. Élargir les provinces allonge les transitions
   sans toucher à la règle. **Mais ça ne garantit pas une taille minimum**, ça
   la rend seulement plus probable ;
2. **Décider le biome au site de région, et non à la colonne.** C'est la route
   qui garantit. `CWRegionSite` porte déjà `temperature` et `humidity`, et
   `CWWorldMap.icon_of_zone` s'en sert déjà pour choisir son icône : un biome
   décidé là aurait **la taille d'une région par construction**, et les
   frontières seraient celles du diagramme de Voronoï des sites. La colonne ne
   servirait plus qu'à l'écotone.

   ⚠️ Ce qu'il faut savoir avant de la prendre : le climat d'une colonne est un
   **mélange** de plusieurs sites (c'est ce qui fait qu'une Snowlands peut
   toucher un désert sans que ce soit absurde). Décider au site jette ce mélange
   pour la classification, et il faudra vérifier que le voisinage reste crédible
   — `tools/biome_stats.gd` compte déjà les paires « neige contre désert »,
   c'est le garde-fou tout trouvé.

**Et il faut relancer `tools/biome_balance.gd` après**, quelle que soit la route :
les seuils sont des quantiles du champ, et changer le champ change les quantiles.
Les six parts égales ne survivront pas toutes seules.

---

### 3. Les nuages : la moitié basse manque, et ils sont trop petits

*Régénérer les nuages : il manque la moitié basse, et il faudrait aussi les
agrandir.*

**La moitié basse ne manque pas, elle est coupée exprès** — et le remède n'est
donc pas de la remettre telle quelle. `generer_nuages._pose` pose la masse à
cheval sur `z = 0` et laisse la grille jeter ce qui passe dessous : c'est ce qui
donne le **dessous plat** d'un cumulus, qui est une condensation à altitude
constante et non une forme dessinée. Le paramètre est `coupe`, à **0,30** pour
les deux cumulus et **0,22** pour le voile.

⚠️ **À zéro, un nuage est un galet** : rond partout, sans base, et il cesse de
lire comme un nuage vu d'en dessous — ce qui est le seul angle sous lequel on le
voit. Ce qu'il faut n'est pas `coupe = 0` mais **plus de masse sous le plus large
lobe** : baisser `coupe` *et* descendre l'étage bas de `_lobes`, pour que la
coupe tombe sous le ventre au lieu de le trancher.

**Pour agrandir**, deux réglages, et ils ne font pas la même chose :

* `generer_nuages` — `largeur`, `profondeur`, `hauteur` des trois modèles.
  Agrandir ici change la **forme** : plus de lobes tiennent dans la même masse ;
* `CWClouds.ECHELLE_MIN` / `ECHELLE_MAX` (1,4 – 2,6) — agrandir ici ne coûte
  rien à la génération et ne change pas la silhouette, seulement sa taille
  apparente.

⚠️ **L'enveloppe est vérifiée**, et c'est voulu : `NUAGE = (24, 32)` dans le
générateur, et `tests/sky_test.gd` refuse un modèle qui la dépasse. Grandir
demande de monter les deux ensemble — le test tombera sinon, ce qui est
exactement son travail.

---

### 4. La carte ne nomme qu'une région sur deux

*Corriger la carte, qui n'affiche le nom des régions que dans certaines zones.*

**Deux causes, et corriger l'une ne corrige pas l'autre.** Les deux sont
trouvées, et chacune tient en une ligne :

1. **le nom voyage sur un marqueur, et une région d'océan n'en a pas.**
   `CWWorldMap.markers` n'ajoute une entrée que `if site != null and
   icon != ICON_NONE`, et `icon_of_zone` rend `ICON_NONE` dès que
   `site.is_ocean()`. Une région marine est donc **sans nom par construction**,
   et c'est un sixième du monde depuis hier ;
2. **le nom ne se dessine qu'à partir d'un certain zoom.**
   `map_overlay.gd`, `if m.has("name") and scale >= 2.0`. La carte s'ouvre sur
   cinq zones (`CWDemoMap._zones`, réglable de 3 à 9 par `+`/`−`) : au-delà de
   cinq, l'échelle passe sous deux et les noms disparaissent tous d'un coup.

> Le garde-fou du zoom n'est pas absurde — un nom de onze pixels sur une carte
> de neuf zones se chevauche avec ses voisins. Ce qu'il faut décider est
> **quoi faire à la place** : des noms plus courts, un nom sur deux, ou un nom
> seulement pour la région sous le curseur. C'est un choix d'affichage, et il
> se juge sur une capture — `-- --carte` l'ouvre au démarrage sans piloter la
> fenêtre.

---

### 5. La carte confond la neige et l'océan

*Revoir les couleurs pour différencier un biome neige d'un biome océan.*

**La cause est nommée, et c'est l'invariant n° 27 pris à l'envers.**
`CWWorldMap.tint_of_zone` peint une région avec **la couleur du terrain** :
`CWPalette.colors()[surface_index]`. Or la neige est `Color8(125, 181, 199)` et
l'eau `Color8(42, 200, 252)` — deux cyans clairs. Elles se confondent parce
qu'elles se ressemblent *vraiment*, et une carte qui recopie le sol recopie
aussi ses confusions.

⚠️ **Le remède n'est pas de repeindre la palette** : `SNOW` est un type de bloc
écrit dans le monde, et le changer repeint toute la neige du jeu pour régler un
problème de carte. Le remède est de **donner à la carte sa propre table**,
indexée par **biome** et non par matière de surface — *une carte est une légende,
pas une photographie*. Six teintes franches, choisies pour se distinguer les unes
des autres, valent mieux que dix teintes justes qui se ressemblent.

C'est aussi ce qui règle le cas où deux biomes partagent une matière : depuis le
2026-09-11 l'océan est un sixième du monde, et il touche partout de la neige, du
sable et de l'herbe.

---
## 0ter. Le programme des cinq demandes, et ce qu'il a rendu

L'ordre ci-dessous est celui d'exécution, et il est celui qui a été demandé : le
C++ venait en dernier et **seulement si le maillage ne suffisait pas**. Il ne
suffisait pas — c'est la mesure de la n° 4 qui l'a dit.

---

### 1. Les nuages deviennent des modèles, et le temps ralentit — **fait**

*Supprimer les nuages et les remplacer par des modèles générés par Blender via
bpy, dessinés à la taille du terrain — 1 voxel = 1 bloc —, deux ou trois
variantes, placés dans le ciel. Faire défiler le temps moins vite.*

**Fait le 2026-09-11.** Trois modèles (`assets/models/nuages/`, 34 × 24 × 14 à
56 × 38 × 16 blocs), un `CWClouds` qui les pose, le shader de nuages retiré, et
`DAY_LENGTH` de 720 s à **2 400 s**. La couche de nuages en bruit fractal est
partie entière : le fbm, ses cinq octaves, ses uniformes, et les six constantes
`CLOUD_*` de `CWDaylight`.

**Les cinq pièges annoncés se sont tous vérifiés, et deux ont demandé une
capture pour être vus.**

* **le brouillard.** Réglé comme prévu par `disable_fog` sur le matériau
  (`CWPalette.build_cloud_material`), et l'argument est mesuré : le ciel ne
  prend que 18 % du brouillard, un objet en prendrait 100 %, et à 0,0016 de
  densité un nuage à mille blocs serait un aplat gris ;
* ⚠️ **la première capture rendait des soucoupes bleu marine**, et ce n'était
  ni la palette ni l'éclairage. On regarde un nuage **par en dessous**, et un
  dessous ne reçoit que l'ambiante — 0,45 d'une teinte de ciel bleue. La cause
  est que **la matière était fausse** : un nuage est traversé par la lumière.
  `backlight` dit exactement cela, et il le dit proportionnellement au soleil,
  donc le nuage reste sombre la nuit — ce qu'une émission n'aurait pas fait ;
* ⚠️ **la deuxième rendait des méduses turquoise.** La rampe 240-247 va jusqu'à
  un bleu de ciel franc, et c'est le bas de la rampe qu'on voit d'en dessous ;
  il se cumulait avec l'ambiante. Elle s'arrête à **243**. *Les deux défauts
  étaient le même mécanisme vu deux fois, et aucun test ne pouvait les voir* ;
* **la palette n'était pas pleine, et personne n'avait regardé au bon endroit.**
  Le relevé annonçait la neige, la glace et le clair de la roche nue. Il y avait
  mieux : `_ramp(c, 240, 8, blanc, bleu clair)`, la plage **effets**, jamais
  peinte, et la seule du nuancier qui ne soit pas une matière. Aucune frontière
  n'a bougé, aucun lot n'a été repassé ;
* **les ombres sont coupées** (`CWClouds.cast_shadows`, à faux). Une tache dure
  de quarante blocs lit comme un défaut de rendu ; la bascule reste ;
* **la lumière est gratuite et juste, et c'est vérifié en capture.** À 6 h 28,
  les nuages prennent le soleil rasant sur leur flanc et sortent crème sur un
  ciel violet, sans une ligne de code de teinte. C'est ce que `CLOUD_TWILIGHT`
  simulait à la main.

**Un manque d'outillage est tombé avec** : `--ici`, `--vers` et `--altitude`
savent tous viser un point du **sol**, et rien ne savait regarder en l'air.
`--regard d` pose l'assiette de la caméra en degrés — sans elle, cadrer une
couche du ciel obligeait à monter la caméra à son altitude, c'est-à-dire à la
regarder d'ailleurs que d'où on la verra.

**Ce qui reste ouvert de ce côté :**

- **la couverture est toujours une constante** (`CWClouds.cover`, 0,45). La
  faire varier demande un champ de temps, qui est un autre sujet ;
- **les nuages ne portent pas d'ombre**, et c'est l'arbitrage ci-dessus, pas un
  manque de code : une ligne le rallume ;
- **la dérive est une translation d'ensemble.** Deux nuages ne se croisent
  jamais. Ça ne se voit pas, et le jour où ça se verra, ce sera une vitesse par
  altitude.

### 2. La collision du feuillage — **faite, sauf les cactus**

*Ce sera oui pour les feuillages des arbres, le rocher géant et les cactus.*

**Fait le 2026-09-11 pour les deux premiers.** Toutes les pièces d'un arbre —
houppiers, dômes, palmes, et les cinq modèles entiers dont le rocher géant —
sont désormais écrites dans les données voxels par
`CWVoxelGenerator._stamp_trees`. La couche d'instances d'arbres a disparu avec
elles : elle ne posait plus rien.

**Les cactus sont le seul morceau qui ne se fasse pas, et la raison est
structurelle, pas un manque de temps.** Ils sont à **4 voxels par bloc** —
quatre fois plus fins que la grille du terrain — et l'invariant n° 12 dit
pourquoi la flore n'y entre jamais. Les deux façons de forcer le passage sont
toutes deux mauvaises, et le dépôt les a déjà écartées une fois :

* **les redessiner à 1 voxel = 1 bloc** ferait d'un cactus de quatre blocs une
  pile de quatre cubes. C'est exactement ce qui a fait retirer `cactus_geant` le
  2026-09-06 — « à un voxel par bloc un saguaro n'a ni cannelure ni épine » ;
* **estamper un volume approché** (`CWVoxelModel.reduced(4)` existe pour ça)
  mettrait un pâté de blocs *visible* à l'intérieur du modèle fin, qui continue
  d'être instancié. Deux cactus au même endroit, dont un moche.

**Ce que le cactus veut vraiment, c'est une forme de physique**, et c'est ce que
l'annexe de `docs/ROADMAP.md` (§3) proposait déjà : `Placement` porte position,
rayon et hauteur, un cylindre par cactus coûte zéro voxel. Ça se pose au jalon
3.1 avec le contrôleur — **et rien de tout ceci ne se voit avant lui**, puisque
`generate_collisions` est à faux.

**Ce que la mesure a corrigé, et c'est le vrai résultat de la passe :**

| | vue de 384 blocs |
|---|---|
| avant (fût seul, borne du chemin rapide à 48) | **26,1 s** |
| après (arbre entier, borne à 72) | **27,5 s** |
| après, avec `--sans-arbres` — coupe l'écriture, **pas** la borne | 27,1 s |

* **+5,4 %, là où ce fichier annonçait +25 %.** L'estimation datait d'avant le
  retrait des massifs et d'avant le réglage du pool, et c'est l'invariant n° 51
  une fois de plus ;
* ⚠️ **et le poste dominant n'est pas celui qu'on écrit.** Écrire douze fois
  plus de voxels coûte **0,4 s** ; faire reculer `HAUTEUR_TRONC_MAX` de 48 à 72
  en coûte **1,0**, et cette seconde dépense se paie **partout**, y compris
  au-dessus d'un désert sans un arbre. C'était annoncé comme le piège qu'on
  oublierait ; il est le plus cher des deux.

**Trois choses que seule la mise en œuvre a montrées.**

1. ⚠️ **Une couronne recouvre le fût qui la porte, et l'ordre des deux listes
   les départageait.** Le bloc rendait du feuillage là où la requête ponctuelle
   rendait du bois — invariant n° 18 en défaut, dès la première exécution. La
   règle qui referme le cas est écrite des deux côtés : **le feuillage ne
   recouvre que le vide**. C'est la seule couche du monde qui ait cette forme —
   un fût, un chemin, un étang recouvrent ce qu'ils traversent ;
2. **la marge se mesure sur les espèces, pas sur ce qui pousse autour du
   départ.** Le premier relevé donnait 12 blocs d'étalement et 31 de haut ; en
   montant chaque espèce de chaque biome aux deux extrêmes de la gigue, c'est
   **21 et 57** — le pire cas est un dôme de cerisier au bout d'une branche, et
   le houppier de l'arbre géant. La prairie du point de départ n'a ni palmier,
   ni baobab, ni arbre géant ;
3. **les cinq modèles entiers perdent leur gigue de taille.** Un modèle entier
   est estampé tel quel : le rééchantillonner étirerait une **silhouette**, et
   la flèche d'un conifère a déjà demandé trois reprises en trois jours au jalon
   1.12. Deux pins, un sapin, l'arbre épineux et le rocher géant sortent donc
   tous à la même taille. La variété devra venir de variantes de modèles.

**Et une entrée de palette de plus, sans qu'une frontière bouge** :
`LEAVES = 19`, dernier ton de la rampe de roche nue et la seule que ne peignait
aucun modèle du dépôt. Le geste est celui de `WOOD` sur le 4 et de
`MAGMA`/`SCORIA` sur 30 et 31. **Le type se lit sur la palette du voxel**
(`CWPalette.matiere_de`) et non sur la pièce — un `pin` porte du bois et du
feuillage, un `rocher_geant` de la roche, et une table par modèle aurait menti
dès le premier modèle mixte.

### 3. Des biomes mieux répartis, et égaux — **fait**

*J'aimerais que les biomes soient mieux répartis et qu'ils soient égaux.*

**Fait le 2026-09-11, dans la lecture la plus chère des trois** — six parts
égales du monde, Oceans compris, ce qui demande de déplacer le **niveau de la
mer** et non seulement des seuils.

| | avant | après |
|---|---|---|
| Greenlands | **41,0 %** | 18,5 % |
| Jungles | 14,2 % | 18,1 % |
| Snowlands | 9,0 % | 13,8 % |
| Deserts | 5,9 % | 13,5 % |
| Lava Lands | **1,1 %** | 16,6 % |
| Oceans | 28,9 % | 19,5 % |

*(parts du monde, graine 1337, 144 zones. Sur la graine de la démo — 2024 — la
dispersion est plus serrée encore : 14,7 à 18,8 %.)*

**Ce qui a changé n'est pas six valeurs, c'est la forme de la règle.** Le
solveur a trouvé la part de Snowlands, de Jungles, de Lava Lands et de l'océan,
et **il n'a pas pu trouver celle des déserts** : `DESERT_T` est descendu jusqu'à
zéro en ne rendant que 3 % du monde. La cause n'était pas un seuil mal placé —
Lava Lands, testé avant le désert, prenait toute la moitié sèche au-dessus de
son seuil, et il ne restait au désert que le sec *froid*, que ce champ ne
produit presque pas. Il y avait **deux frontières d'humidité** (`JUNGLE_H` à
0,62 et `DESERT_H` à 0,34), soit une de trop pour un champ bimodal.

Il n'y en a plus qu'une, `HUMID_H` : le monde se partage en **sec et humide**,
une seule fois, et la température fait tout le reste — Snowlands au froid, puis
Deserts et Lava Lands se partagent le sec par température croissante, Jungles
prend le chaud humide, Greenlands garde le tempéré des deux versants.

**Trois choses à savoir avant de retoucher quoi que ce soit ici :**

* ⚠️ **Lava Lands a cessé d'être rare, et c'était le prix annoncé.** L'alpha le
  donne « rare, loin du spawn » ; à parts égales c'est un sixième du monde. Ce
  n'est plus un accident, c'est un pays — et il se voit, ce qui n'était pas le
  cas à 1,1 % ;
* ⚠️ **les degrés ne se lisent plus.** Un désert commence maintenant à 2 °C et
  une Lava Lands à 20 °C sur l'échelle d'affichage de l'ATH. Les seuils sont des
  **quantiles d'un champ**, pas des températures ; `TEMP_MIN_C` / `TEMP_MAX_C`
  ne sont plus qu'une convention d'affichage ;
* ⚠️ **le niveau de la mer n'est pas stable d'une graine à l'autre.** Les cinq
  seuils de climat tiennent dans trois centièmes sur cinq graines ; le niveau
  qui rend un sixième d'océan va de **−54 à −68** selon la graine, parce qu'une
  graine décide où sont les continents et pas seulement leur climat. **−60** est
  la moyenne de cinq, et une graine donnée s'en écarte de deux points.

**Et un effet de bord mesuré, qu'il faut regarder avant de le corriger.** Les
règles de surface exprimées en altitude **au-dessus de la mer** — la ligne de
neige, la bande de roche, la plage — voient maintenant des terres soixante
blocs plus hautes. La roche nue passe de 0,3 % à 2,8 % du monde, toute dans les
hauteurs de Lava Lands. Vu en capture : ça lit comme la calotte rocheuse d'un
volcan, et c'est gardé. Si un jour ça gêne, c'est `CWPalette.ROCK_MIN` qu'il
faut remonter de soixante, pas les seuils de biome.

**`tools/biome_balance.gd` est le nouvel outil**, et il est fait pour être
relancé : il échantillonne une fois, lit les seuils comme des **quantiles**, et
rend des valeurs prêtes à recopier. Le jour où le champ de climat bougera, il
refait la table en quinze secondes.

> **Ce que le fichier annonçait ici s'est vérifié à moitié.** Le trou du champ
> d'humidité entre 0,10 et 0,40 est bien réel — c'est lui qui rendait `DESERT_H`
> à 0,34 impraticable, et c'est pour cette raison que la frontière unique est à
> 0,65, dans la partie dense. Mais la conclusion qu'on en tirait — « certains
> biomes ne sont pas réglables de façon continue » — était fausse : ils ne
> l'étaient pas **avec deux frontières**. Avec une seule, ils le sont tous.

### 4. Le maillage — **mesuré, et le soupçon était faux**

**Fait le 2026-09-11.** Deux outils, et un résultat qui retourne la prémisse.

> Ce fichier disait : *« le ~1,1 Go observé en jeu ressemble plus à des
> maillages qu'à des données voxels. C'est une constatation, pas un profil. »*
> C'en est un maintenant, et **les maillages font 57 Mo sur 1,09 Go**, soit
> cinq pour cent. Le gigaoctet était bien réel ; il n'était pas là.

**Le profil mémoire, vue de 384 blocs, graine 2024, éditeur fermé.** Il sort
tout seul à la ligne « stabilisée en » de la démo, et il est aussi dans l'ATH
détaillé (F1) :

| poste | 128 blocs | 256 | 384 |
|---|---|---|---|
| statique (processeur) | 143 Mo | 226 Mo | **347 Mo** |
| vidéo | 267 Mo | 486 Mo | **745 Mo** |
| dont **maillages** | 32 Mo | 42 Mo | **57 Mo** |
| dont textures | 110 Mo | 110 Mo | 110 Mo |
| cache de colonnes | — | — | 2 500 entrées, **15 Mo** |

* **les textures ne bougent pas** — 110 Mo à toutes les distances, dans un
  projet qui n'a pas une seule texture. C'est le décor du moteur : cartes
  d'ombres et cibles de rendu. Il ne borne rien, et il ne se règle pas ici ;
* **les maillages croissent lentement** : 32 → 57 Mo quand l'aire est
  multipliée par neuf. Ils ne borneront pas la distance de vue ;
* **le reste du statique est la donnée voxel**, et c'est le poste qui grandit
  vraiment — de l'ordre de 190 Mo à 384 blocs. C'est inhérent à un monde de
  voxels, et le seul levier connu est le LOD, qui est éteint pour une autre
  raison (§5).

**La piste qu'on désignait comme bonne l'était, mais elle est bon marché.**
`tools/profile_mesh.gd` compte les sommets d'un pavé de trois façons :

| | sommets par pavé | écart |
|---|---|---|
| le monde tel qu'il est (tramé, glouton) | **214** | — |
| couleur plate par type (glouton) | 178 | **−17 %** |
| tramé, sans fusion gloutonne | 1 457 | +580 % |

* **le tramage coûte 17 % des sommets**, soit une dizaine de mégaoctets à
  384 blocs. L'arbitrage *rendu contre mémoire* est donc tranché, et il l'est
  dans le sens du rendu : **on garde le dégradé**. Trois tons pour une prairie
  valent dix mégaoctets ;
* **le maillage glouton achète un facteur 6,8**, et c'est ce qui rend le rendu
  en cubes praticable. Le gain facile était déjà pris, et il est gros ;
* **le maillage coûte 0,07 ms par pavé.** Sur les ~7 000 pavés d'une vue de
  384 blocs, c'est une demi-seconde de fil pour un chargement de 27,5 s. Le
  mailleur n'est pas le verrou.

**Et une correction de commentaire qui vaut une mesure.** `HEIGHTMAP_CACHE_CAP`
annonçait « ~1,3 Ko l'entrée, 16 384 entrées tiennent dans ~21 Mo ». Une entrée
porte 256 colonnes et **cinq** tableaux : elle fait **6,4 Ko**, le plafond
autorise donc 105 Mo, et deux générations coexistent. Le chiffre est maintenant
calculé (`CWVoxelGenerator.PATCH_BYTES`) et affiché, pas estimé.

**Ce qui reste ouvert, et pourquoi ça ne se ferme pas au banc :**

- **la saccade.** C'est une affaire de *latence et d'ordonnancement*, pas de
  débit : un mailleur deux fois plus rapide qui rend ses pavés au même moment
  saccade toujours. Elle ne se juge qu'en jouant, manette en main, et aucune
  des mesures ci-dessus ne la voit ;
- **le plafond du cache borne toujours la vue à 1 024 blocs** (invariant n° 5),
  et c'est maintenant le seul plafond chiffré du projet. Le lever coûte 105 Mo
  par doublement — ce qui, à côté des 347 Mo de données voxels, est acceptable.

### 5. Le C++ — **écrit et prêt, mais pas compilable sur cette machine**

*Si vraiment les performances n'y sont pas, la prochaine tâche sera de passer en
C++.*

**La condition est remplie**, et c'est la mesure de la n° 4 qui la remplit : le
maillage coûte 0,5 s sur un chargement de 27,5 s, donc il ne reste rien à
gagner de ce côté. Le champ reste 83 % du temps, et le bruit la moitié du champ.

**Ce qui est fait, et qui est dans le dépôt :**

* `native/` — une GDExtension complète : `CWNoiseNative`, son `SConstruct`, son
  manifeste, son script de construction et son `README.md`. La route est la
  **GDExtension** et non le module, pour la raison écrite ici depuis le début :
  le moteur est un build personnalisé, et un module obligerait à reconstruire
  et redistribuer les 190 Mo ;
* **`CWValueNoise` a deux corps**, et il choisit. `sample` passe au natif quand
  il est là, `sample_gd` reste la référence lisible et testée ;
* ⚠️ **et il ne lui fait pas confiance parce qu'elle est là.** L'exactitude au
  bit près est un invariant (n° 1) : une bibliothèque compilée ailleurs, par un
  autre compilateur, avec une autre `libm`, peut différer d'un ulp sur le
  cosinus sans que rien ne le signale — et le défaut ne se verrait que le jour
  où deux machines compareraient deux captures du même endroit.
  `_natif_accorde` la fait donc **passer un examen au chargement** et la refuse
  si elle ne rend pas exactement les mêmes bits. La suite refait la preuve sur
  20 000 points et **dit laquelle des deux tourne** ;
* le manifeste `.gdextension` est **posé par la construction**, pas versionné :
  Godot lit tout `.gdextension` qu'il trouve, et un manifeste sans bibliothèque
  fait une erreur à chaque démarrage pour tout le monde. Sans construction, le
  dépôt est silencieux et le monde identique — seulement plus lent.

**Ce qui bloque, et ce n'est pas du code.** Cette machine a MSVC (14.44 et
14.51) et SCons, mais **pas le SDK Windows** : `C:\Program Files (x86)\Windows
Kits\10` n'a ni `Include` ni `Lib`, donc `cl.exe` ne trouve pas `stddef.h`. La
compilation part, génère les liaisons de godot-cpp, et s'arrête là. Installer un
SDK de plusieurs gigaoctets est une modification de la machine, pas du projet :
elle n'a pas été faite.

```
# Le composant qui manque, par l'installateur de Visual Studio :
#   Modifier -> Développement Desktop en C++ -> cocher « SDK Windows 11 »
"C:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe" modify ^
    --installPath "C:\Program Files\Microsoft Visual Studio\2022\Community" ^
    --add Microsoft.VisualStudio.Component.Windows11SDK.22621 --passive
# puis
native\build.bat template_release
```

**Ce qu'il faudra vérifier le jour où elle compilera, dans cet ordre :**

1. **la suite passe, et elle dit « bruit natif : ACTIF ».** Si elle dit
   « absent » alors que la bibliothèque est là, c'est que l'examen l'a refusée —
   et c'est un vrai défaut, pas un réglage ;
2. **`tools/profile_worldgen.gd` chiffre le gain** : il mesure maintenant les
   deux corps côte à côte et affiche le rapport, frontière d'appel comprise.
   L'attente est un **facteur deux** sur le chargement (27,5 s → ~17 s), pas un
   facteur dix ;
3. ⚠️ **refaire la falaise des fils.** Un champ deux fois plus rapide déplace
   l'optimum du pool ; les deux réglages ne sont pas indépendants. `-- --fils n`
   refait la mesure ;
4. **puis, seulement si ça ne suffit pas, porter `_height_from`.**
   `CWNoiseNative.sample_octaves` est déjà là pour ça : il évalue N octaves en
   **un seul passage de frontière**, ce qui est la moitié de l'enjeu — un appel
   de méthode depuis GDScript coûte une fraction de microseconde et
   `_height_from` en fait quinze par colonne. Il n'est encore appelé par
   personne.

### Ce qui reste ouvert par ailleurs, et qui n'est dans aucune des cinq

- **les quatre fichiers de `worldgen` à mille lignes.** La démo est rangée
  — 1 147 → 962 —, le générateur pas encore ;
- **la falaise vaut-elle 12 % du chargement ?** Depuis le retrait des massifs
  elle n'a plus de paroi à raconter. Ça se tranche à l'œil, pas au banc ;
- ⚠️ **le plafond du cache de colonnes borne la distance de vue.** L'invariant
  n° 5 demande `(2 × distance / 16)²` entrées ; à 1 024 blocs de vue on est
  **exactement** au plafond de 16 384. Au-delà, le cache s'auto-évince en boucle
  et le chargement s'effondre **sans rien signaler**. À relever avant d'augmenter
  la distance, ce qui est l'objectif affiché — et le prix est maintenant chiffré
  et non plus estimé : **6,4 Ko l'entrée**, donc 105 Mo au plafond actuel et
  autant par doublement (§4, `CWVoxelGenerator.PATCH_BYTES`) ;
- **2.6, l'apparition** — la porte du jalon 2. Elle n'attend rien.

---

## 0bis. Ce qui a été fait le 2026-09-10

**1. Supprimer les surplombs.** *« Je n'aime pas le rendu en jeu. »* Troisième
retrait du dépôt après la falaise et les ponts. La couche est partie entière —
`CWMesa`, `CWMesaGrid`, les grottes, le porche, les tunnels de chemin, le terme
de masse du coût de tracé, trois outils, deux suites de vérification. **−2 240
lignes.** La falaise survit — elle mesure la pente du champ, qui n'a jamais rien
su de cette couche — et le réseau de chemins aussi.

Trois choses en sont sorties, et elles comptent pour la suite :

* **le chargement à 384 blocs passe de 107,7 s à 55,4 s.** Ce fichier annonçait
  28,5 s ; c'était la mesure du 2026-09-08, et deux passes sur les massifs
  l'avaient quadruplée sans que personne la refasse. *La couche de massifs était
  le premier poste du chargement, pas `sample_column`* — ce qui change la
  prémisse de la demande n° 3 ;
* **le coût par colonne descend de 88,4 à 75,8 µs**, soit le coût du champ seul ;
* **un vrai défaut est tombé avec elle.** En repointant l'accord des deux
  écritures de la règle sur une chaussée — sa place était le cœur d'un massif —,
  la vérification a trouvé que `generated_voxel` **ignorait les troncs
  estampés** : le bloc généré rendait du bois, la requête ponctuelle de l'air, et
  `CWWorldEdits` interrogeait donc un monde sans arbres. Défaut depuis le jalon
  1.11, invisible parce que les deux balayages qui tiennent l'invariant n° 18
  tombaient l'un sur un bloc sans arbre, l'autre sur une mesa. Corrigé
  (`CWVoxelGenerator.trunk_at`).

**4a. La moitié documentaire du rangement.** Ce fichier passe de 4 196 lignes à
~700 ; le récit des sessions est en annexe de `docs/ROADMAP.md`, la référence
d'authoring dans `docs/ASSETS.md`, et `CLAUDE.md` existe.

---

### Le n° 4 — le rangement du code, à moitié fait

*Correction des potentiels bugs et erreurs, nettoyage du projet, le rendre plus
modulaire et facile à maintenir.*

La moitié documentaire est faite ; **la moitié code est commencée.** Deux
métiers sont sortis de `terrain_demo.gd` le 2026-09-10 — l'**environnement**
dans `CWDaylight`, qui est l'endroit où le cycle jour/nuit du n° 3 viendra se
poser, et la **carte du monde** dans `CWDemoMap`, un métier complet avec son
rendu de fond et son fichier sur le disque. Le fichier passe de 1 147 à 1 008
lignes, et une bascule `--carte` évite désormais d'éditer la scène pour
regarder la carte sans piloter la fenêtre.

Ce qui reste :

| fichier | lignes | métiers mêlés |
|---|---|---|
| `src/worldgen/cw_terrain_field.gd` | 1 117 | altitude, climat, chenaux, étangs, profil de colonne, caches |
| `src/demo/terrain_demo.gd` | 962 | arguments, terrain, ATH, caméra, captures, persistance |
| `src/worldgen/cw_palette.gd` | 1 002 | palette, matières de surface, teintes, tramage |
| `src/worldgen/cw_path_network.gd` | 946 | graphe de zone, relaxation, profil, franchissements, règle de colonne |
| `src/worldgen/cw_voxel_generator.gd` | 797 | chemin froid, chemin chaud, troncs estampés |

**La recherche de biome est sortie aussi** (`CWBiomeSearch`, même forme que la
carte) : 1 008 → 928 lignes.

> **L'ATH, lui, ne sort pas, et c'est une décision.** `_update_hud` lit
> **dix-sept** morceaux d'état de la démo — les trois files d'attente, la
> caméra, les éditions, les deux dispersions, la carte, la recherche, la
> palette du bloc posé… L'extraire demanderait soit dix-sept arguments, soit
> une référence arrière vers la démo. La seconde casse la règle *une couche ne
> connaît que celle du dessous* ; la première est une signature que personne ne
> maintiendra. **Un affichage qui est une vue sur tout n'est pas une couche**,
> et le sortir coûterait plus qu'il ne rapporte. Relevé le 2026-09-10 pour
> qu'on ne le repropose pas.

Deux règles de découpe, et ce sont des règles, pas du goût : **un fichier, une
décision** ; **une couche ne connaît que celle du dessous** — la chaîne va
aujourd'hui `chemins → champ` et ne revient pas, ce qui est exactement ce qu'il
faut généraliser.

**Et la partie « bugs » n'est pas rhétorique** — le défaut du tronc vient de le
montrer. La suite passe 379 vérifications, mais elle vérifie de la
**géométrie**, jamais du rendu, et les quatre systèmes retirés par ce dépôt
passaient tous leurs tests. Ce qu'elle ne peut pas voir, et qui vaut une
relecture : les ordres de recouvrement, les accords entre le chemin froid et le
chemin chaud, et les endroits où deux copies d'une même règle ont eu le droit de
diverger.

### Le n° 3 — l'optimisation, mesurée

*Objectif : distance de rendu maximale sans perte de fps ni saccade au
chargement des chunks.*

> **L'objectif contient deux problèmes qui n'ont pas le même remède, et les
> mélanger coûtera une journée.**
>
> * **le débit** — combien de colonnes par seconde. C'est lui qui fixe la
>   distance de vue atteignable, et c'est là que le C++ jouerait ;
> * **la saccade** — un à-coup quand un pavé arrive. C'est une affaire de
>   *latence* et d'ordonnancement, pas de débit : un générateur deux fois plus
>   rapide qui rend toujours ses pavés au même moment saccade toujours.

**Les étapes 1 et 2 sont faites le 2026-09-10.** Chargement d'une vue de
384 blocs : **107,7 s** la veille, **55,4 s** après le retrait des massifs,
**42,0 s** après le réglage du pool ci-dessous. Le profil par poste vient de
`tools/profile_worldgen.gd`, écrit pour ça et à relancer après toute
modification du champ — graine de la démo, éditeur fermé :

| poste | coût | part |
|---|---|---|
| **génération d'un pavé, tout allumé** | **93,7 µs/colonne** | 100 % |
| dont le **champ nu**, les trois couches éteintes | **77,6 µs** | **83 %** |
| dont la falaise | 11,5 µs | 12 % |
| dont les chemins | 5,1 µs | 5 % |
| dont les éléments de tuile | 4,9 µs | 5 % |
| — | | |
| une colonne isolée (`sample_column_full`) | 81,4 µs | |
| **dont ~15 échantillons de `CWValueNoise`** | **46 µs** | **~49 % du total** |
| dont les éléments de tuile | 14,9 µs | |
| le climat seul (`climate_blend`) | 13,0 µs | |
| — | | |
| flore : une cellule de 16 × 16 | 2,03 ms | 7,9 µs/colonne |
| **dont l'assiette (les quatre coins)** | **1,30 ms** | **64 %** |
| arbres : une cellule de 64 × 64 | 1,66 ms | 0,41 µs/colonne |

**Trois choses en sortent, et elles décident la suite.**

1. **Le champ est bien le poste dominant — 83 %** —, et *à l'intérieur du champ,
   c'est le bruit* : `CWValueNoise.sample` coûte **3,08 µs** l'échantillon, et
   une colonne en fait une quinzaine. **La moitié du temps de génération est
   passée dans une seule fonction de vingt lignes**, qui émule de l'arithmétique
   32 bits que GDScript n'a pas. C'est la cible du C++, et elle est unique ;
2. **La falaise coûte 12 %**, deux fois plus que les chemins ou les éléments.
   C'est cohérent avec les +12,9 % d'échantillonnage annoncés (invariant n° 44),
   donc ce n'est pas une régression — mais c'est cher pour une règle de surface,
   et la question « la falaise vaut-elle 12 % » se pose maintenant qu'elle n'a
   plus de massif à raconter ;
3. **L'assiette a presque triplé le coût de la dispersion de flore** — 722 µs la
   cellule avant, 2 025 après —, et personne ne l'avait mesuré. Vérifié en la
   désactivant.

   > **Et ce n'est pas un défaut d'écriture, c'est le prix de la chose.** La
   > première idée était que les quatre coins, pris un par un par
   > `sample_column_full`, repayaient la comptabilité par colonne que
   > `sample_patch` ne paie qu'une fois — les quatre forment exactement une
   > grille 2 × 2 de pas 2r. **Essayé, mesuré, faux** : 2 035 µs contre 2 025,
   > et la suite passe des deux côtés, donc les deux chemins disent bien la
   > même chose. Ce que coûte l'assiette, ce sont **les quatre échantillons de
   > champ eux-mêmes**, c'est-à-dire le bruit — le même poste que partout
   > ailleurs. Elle ne deviendra moins chère que si le champ le devient.
   >
   > Reste donc une **question de conception, pas d'optimisation** : quatre
   > colonnes de plus par plante posée valent-elles qu'aucun caillou n'ait un
   > bord en l'air ? Elle se tranche à l'œil, et la dispersion tourne sur un fil
   > du pool, donc elle ne borne pas forcément le chargement.

**Et un gain gratuit, trouvé en cherchant les réglages : le pool était trop
grand.** Le nombre de fils de génération valait la moitié des processeurs
logiques — huit ici — depuis le 2026-09-05, où le ramener de quatorze à sept
avait doublé la vitesse. Personne n'avait cherché l'optimum. Il est plus bas :

| fils | 4 | 5 | **6** | 7 | 8 (l'ancien défaut) | 12 | 16 |
|---|---|---|---|---|---|---|---|
| stabilisation | 53,4 s | 45,5 s | **42,2 s** | 43,4 s | 58,6 s | > 90 s | > 90 s |

Le défaut était **déjà au-delà du sommet, de vingt-huit pour cent**. La règle
laisse désormais deux cœurs physiques au reste — un au mailleur, un au flux —,
ce qui rend six ici. La cause de la falaise n'est pas établie ; les candidats
sont les verrous des grilles de sites et d'éléments, que chaque colonne
consulte. *Un optimum de pool est propre à une machine* : `-- --fils n` refait
la mesure, et c'est le premier réglage à reprendre sur un autre processeur.

À faire ensuite :

1. ~~**Mesurer par poste.**~~ Fait — `tools/profile_worldgen.gd` ;
2. ~~**Les gains qui ne demandent pas de C++.**~~ Fait, et il y en avait un :
   le pool. Il n'en reste pas d'autre que la mesure désigne — les trois couches
   ne pèsent que 17 % à elles trois, et l'assiette est intrinsèque. Restent le
   plafond du cache de pavés (16 384) et `generate_collisions`, déjà à faux, ni
   l'un ni l'autre suspect.

   > ⚠️ **Le LOD n'est pas le gain gratuit qu'il paraît.** `use_lod` est à faux,
   > `VoxelLodTerrain` est câblé, `lod_count = 6`, `lod_view_distance = 2048` —
   > cinq fois la distance actuelle. **Mais §5 dit pourquoi il est éteint** : en
   > rendu cubes, des dalles d'eau apparaissent en pleine plaine dès le LOD 1,
   > cause non établie. C'est une piste à *déboguer*, pas un interrupteur.

3. **Puis le C++, et la mesure le demande.** La cible est
   `CWValueNoise.sample`, puis `CWTerrainField._height_from` qui l'appelle
   quinze fois. Porter la dispersion, la palette ou la carte n'achèterait rien.

   **Ce qu'on peut en attendre, chiffré.** Un `sample` natif tient en quelques
   dizaines de nanosecondes — c'est trois multiplications 32 bits et une
   interpolation bicubique. Les 46 µs par colonne tomberaient sous 2, soit
   **93,7 → ~50 µs/colonne** et un chargement de 384 blocs autour de **22 s** au
   lieu de 42. Porter `_height_from` entier irait plus loin. C'est donc un
   facteur deux, pas un facteur dix : *à décider en sachant ce qu'une chaîne de
   compilation coûte au dépôt.* Et à décider **après** avoir vu si la falaise
   des fils se déplace une fois le champ deux fois plus rapide : les deux
   réglages ne sont pas indépendants.

> ⚠️ **Le C++ ici n'est pas une case à cocher : le moteur est un build
> personnalisé.** `godot.windows.editor.double.x86_64.exe`, **double précision**,
> module Voxel Tools 1.7 compilé dedans. Il n'y a **ni `.gdextension` ni
> `SConstruct`** dans le dépôt. Deux routes, et elles n'ont pas le même coût :
>
> * **une GDExtension** (godot-cpp) : à compiler contre *exactement* ce build —
>   même version, même précision —, sinon elle ne charge pas. Le dépôt gagne une
>   chaîne de compilation et une bibliothèque par plate-forme ;
> * **un module dans le moteur** : plus rapide à l'appel, mais il faut alors
>   reconstruire et redistribuer le binaire, que le dépôt embarque déjà à 190 Mo
>   à sa racine.
>
> La première est la bonne par défaut. La décision se prend avec la mesure de
> l'étape 1 en main, pas avant.

### Le n° 2 — le ciel et le cycle jour/nuit

**Tout se déduit d'un scalaire d'heure dans `[0, 1)` par la seule fonction
`CWDaylight.applique`** — rotation, énergie et couleur du soleil ; zénith,
horizon et sol du ciel ; couleur et relief des nuages ; ambiante ; couleur,
densité et diffusion du brouillard. C'est une contrainte et non une commodité :
si l'angle du soleil se réglait ici et la couleur du brouillard ailleurs, l'aube
aurait un ciel rose et un brouillard bleu, et le défaut ne se verrait qu'à
l'aube — c'est-à-dire rarement et tard.

Les nuages sont un **bruit fractal en coordonnées de direction**
(`src/demo/cw_sky.gdshader`), pas un dôme texturé : pas de géométrie, pas de
plafond de couverture, et c'est la route qui donnera les ombres de nuages si on
les veut — la même fonction, échantillonnée au sol.

`--heure h` se pose à une heure et fige le cycle, `--jour n` change sa durée,
`--nuages c` la couverture ; en jeu, **F2** fige, **F3** et **F4** reculent ou
avancent d'une heure. *Regarder une aube en temps réel n'est pas une méthode de
réglage.*

**Le doute sur l'éclairage cuit est levé, et dans le bon sens.** `CWLight` ne
suit pas le soleil, et on craignait que sa composante « ciel » à 255 garde le
monde clair la nuit. Ce n'est pas le cas : le terrain **généré** ne passe jamais
par `CWLight` — un champ de hauteurs est éclairé partout où on le voit —, donc
ses voxels portent leur couleur pleine et s'assombrissent avec le soleil et
l'ambiante comme n'importe quelle surface. Seul ce que le joueur a creusé porte
de l'ombre cuite, et **une ombre reste une ombre à toute heure** : le voxel cuit
est devenu un terme d'occlusion sans qu'on ait rien à y toucher.

Trois réglages ont demandé une capture, et aucun ne se voyait dans le code :

* **`fog_sky_affect` vaut 1 par défaut**, donc le brouillard repeignait le ciel
  entier de sa couleur — dégradé, nuages et disque du soleil disparus sous un
  aplat. La première capture de midi rendait exactement cela, quand celle de
  minuit montrait le dégradé, simplement parce qu'à cette heure le brouillard
  est de la couleur du ciel qu'il cachait. *Un défaut qui se voit le jour et pas
  la nuit ressemble à un bug de shader ; c'en était un de réglage* ;
* **la projection des nuages divergeait à l'horizon.** `EYEDIR.xz / EYEDIR.y`
  est juste physiquement et illisible à l'écran — une vue à la première personne
  regarde surtout là, et les nuages s'y écrasaient en filaments d'un pixel. Un
  décalage au dénominateur borne la perspective au lieu de la laisser diverger ;
* **les deux bandes de `smoothstep` se lisaient contre `[0, 1]`** au lieu de
  l'étendue réelle du bruit fractal, qui ne monte guère au-dessus de 0,72. Tout
  le nuage restait dans son fondu et dans sa teinte d'ombre : des masses grises
  et délavées, ce qui ressemblait à un problème d'éclairage.

**Ce qui reste ouvert, et rien ne presse :**

- **la couverture nuageuse est une constante.** La faire varier demande un champ
  de temps, qui est un autre sujet ;
- **les ombres de nuages au sol** : la même fonction de bruit, échantillonnée en
  `(x, z)`, multipliée à la lumière. Le shader est écrit pour ça ;
- **le brouillard reste réglé pour une vue de 384 blocs** (`FOG_DENSITY_*`).
  C'est l'accouplement avec le n° 2 : si la distance de vue augmente, il se
  reprend.

---

### Les portes déjà ouvertes

1. ~~**La collision, objet par objet.**~~ **L'arbitrage est tranché le
   2026-09-10 : le feuillage passe en matière**, avec le rocher géant et les
   cactus. C'est devenu la demande n° 2 du programme ci-dessus ; le tableau des
   cinq modèles à passer reste dans l'annexe de `docs/ROADMAP.md`, et le
   branchage comme les filons étaient déjà réglés.
2. **2.6, l'apparition** — la porte qui reste, et elle mène au jalon 2. Elle
   n'attend rien : la fonction est lue, les constantes de pose extraites, la
   couche d'éléments existe depuis 1.6 et la carte sait les afficher.

**Quatre petites choses laissées ouvertes**, aucune bloquante :

- **la rive n'est humide qu'en Jungles**, faute d'un roseau par biome. C'est un
  besoin d'assets, pas de code — et c'est le seul endroit du monde où le marais
  subsiste ;
- **deux termes du champ de chenaux ne sont pas portés** : les bosses par type de
  cellule de région, qui *interdisent* l'eau près d'un bourg
  (`docs/systems/02` §10.2.1). Les porter déplacerait le lit des vallées
  existantes, donc c'est un travail à faire d'un bloc, avec une capture avant et
  après ;
- **les provinces climatiques ont trois constantes réglées à l'œil sur une seule
  graine** : fréquence, largeur du cœur, décalages de graine.
  `tools/biome_stats.gd` mesure ce qu'elles rendent — répartition et voisinage —,
  donc les bouger est cheap et vérifiable. Elles n'ont pas été balayées, et
  **c'est un levier de la demande n° 3** : la répartition des biomes dépend
  autant de la forme des provinces que des seuils de `CWBiome` ;
- **les chemins ignorent les biomes** : même gravier de chaussée partout. Une
  ligne dans `CWPalette`.

## 1. Où sont les choses

| quoi | chemin |
|---|---|
| Projet Godot | `C:\Users\Admin\Documents\zentarys\` |
| Exécutable Godot | `C:\Users\Admin\Desktop\godot.windows.editor.double.x86_64.exe` |
| Source d'analyse (rétro-ingénierie) | `C:\Users\Admin\Documents\zentarys\CubeWorld-Reversal-master\` (ignorée par git) |

Godot 4.7.2 stable, **double précision**, module Voxel Tools 1.7 compilé dedans
(`VoxelTerrain`, `VoxelMesherCubes`, `VoxelGeneratorScript`, `VoxelVoxLoader`…).
Le greffon `addons/godot_ai` est actif : l'éditeur peut être piloté par MCP
(`session_manage`, `project_run`, `editor_screenshot`, `game_manage`…).

Dépôt : <https://github.com/kyaminq-ui/Zentarys.git> (branche `main`).
Le greffon `addons/godot_ai` est versionné avec le reste : sans lui, le projet
ne s'ouvre pas proprement (il est déclaré dans `project.godot`).

## 2. Commandes

```
# Suite de validation (379 vérifications, ~25 s)
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path . -s tests/worldgen_test.gd

# Réimport après ajout d'un class_name (sinon l'éditeur ne le voit pas)
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path . --import

# Réexport de la palette après modification de CWPalette
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path . -s tools/export_palette.gd

# Gros plan ombré sur un élément de tuile, avec et sans la couche
# (x, z, unités par pixel ; sans argument : le point de départ, 6 u/px)
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path . \
    -s tools/preview_features.gd -- 8397830 8399776 6

# Inventaire des modèles voxels : gabarit, index employés, plages de palette
# (sans argument : tout assets/models/)
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path . -s tools/inspect_model.gd

# Remise d'un lot de modèles dans la palette de projet (rapport, puis écriture)
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path . -s tools/repaint_models.gd
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path .     -s tools/repaint_models.gd -- --write

# Apercu de la carte du monde, hors du jeu : la vue vierge et la meme apres une
# diagonale parcourue (zone x, zone z, nombre de zones, graine)
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path . -s tools/preview_map.gd
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path . -s tools/preview_map.gd -- 512 512 5 2024

# Les seuils de `CWBiome` et le niveau de la mer qui rendent SIX PARTS EGALES
# du monde, resolus sur le champ reel (memes arguments que biome_stats). Il
# echantillonne une fois puis lit les seuils comme des quantiles : c'est lui qui
# a montre qu'avec DEUX frontieres d'humidite le desert etait insoluble.
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path . -s tools/biome_balance.gd -- 144 512

# Répartition des six biomes et des matières de surface, mesurée sur le champ
# réel (zones échantillonnées, pas de sondage, graine). C'est le garde-fou de
# tout déplacement de seuil dans `CWBiome`.
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path . -s tools/biome_stats.gd
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path . -s tools/biome_stats.gd -- 144 512

# Regénération du lot de flore (38 .vox, deux grilles, ~1 s). **Python pur** depuis le
# 2026-09-06 : à 4 voxels par bloc, Blender n'apporte rien de plus qu'aux arbres.
# Déterministe, une graine en dur par fichier ; `-- --seul <nom>` ne refait qu'un
# modèle. Les modules `flore_formes` / `flore_blender`, qui dessinaient à 40/3,
# ne sont plus appelés par ce lot — ils restent pour les créatures du jalon 2.
python tools/blender/generer_flore.py

# Regénération du lot d'arbres (39 .vox, ~2 s). **Python pur** depuis le jalon
# 1.12 : à 1 voxel = 1 bloc, Blender n'apporte rien. Mêmes garde-fous.
python tools/blender/generer_arbres.py

# Regénération du lot de nuages (3 .vox, ~10 s). **Le seul lot qui ait vraiment
# besoin de bpy** : à un voxel par bloc une métaballe ne rend rien pour un
# houppier de six blocs, mais un nuage en fait cinquante de large, et c'est
# exactement là qu'une union de sphères donne des bosses recousues.
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python tools/blender/generer_nuages.py

# Regénération des neuf filons (~1 s). Python pur : à 1 voxel = 1 bloc, Blender
# n'apporte rien. N'importe quel Python 3 fait l'affaire, celui de Blender aussi.
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python tools/blender/generer_filons.py

# Capture d'un biome donné, en jeu, sans piloter la fenêtre. C'est le SEUL moyen
# de voir une couche de rendu : un test headless n'a pas de rastériseur.
# --biome prend un index de `CWBiome` : 0 Greenlands, 1 Snowlands, 2 Deserts,
# 3 Jungles, 4 Lava Lands, 5 Oceans, --shot le délai en secondes avant la capture
# (le temps que le terrain charge), puis la session se ferme d'elle-même.
# Le PNG sort dans user://shots.
./godot.windows.editor.double.x86_64.exe --path . scenes/terrain_demo.tscn \
    --resolution 1600x900 -- --biome 7 --shot 32 --vue 256
#   options : --sans-arbres, --sans-flore, --sans-chemins, --sans-falaise,
#   --sans-nuages, pour isoler une couche. **--sans-arbres coupe une ecriture
#   dans le terrain depuis le 2026-09-11, plus un rendu** : il vide donc les
#   caches, et il ne coupe **pas** la borne du chemin rapide, qui est une
#   constante. C'est ce qui a permis de separer les deux couts. Les deux dernieres servent aussi a mesurer ce
#   qu'elle coute au chargement. --carte ouvre la carte du monde au demarrage.
#   --fils n force le nombre de fils de generation : c'est le reglage le plus
#   rentable du projet, et son optimum est propre a chaque machine.
#   --heure h se pose a une heure du cycle jour/nuit et **fige le cycle** :
#   0 minuit, 0,25 lever, 0,5 midi, 0,75 coucher. C'est le seul moyen de
#   capturer une aube sans attendre qu'elle arrive, donc de la regler.
#   --jour n change la duree d'un jour (720 s par defaut), --nuages c la
#   couverture nuageuse.
#   --vers x z oriente la camera vers un point, --altitude n la leve : sans les
#   deux, une capture d'un objet pose a cent blocs est une capture de ce qui se
#   trouvait dans l'autre sens.
#   --regard d pose l'assiette de la camera, en degres au-dessus de l'horizon.
#   Les trois precedentes savent viser un point du **sol** ; celle-ci est la
#   seule qui sache regarder en l'air, et c'est ce qu'il faut pour cadrer une
#   couche du ciel depuis l'endroit d'ou on la verra jouer.

# Ce que coute le MAILLAGE : sommets par pave, avec et sans le tramage, avec et
# sans la fusion gloutonne, plus l'ordre de grandeur en memoire. C'est lui qui a
# montre que les maillages font 57 Mo sur 1,09 Go — le soupcon qui les
# accusait etait faux. **Fermer l'editeur d'abord** pour les temps.
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path . -s tools/profile_mesh.gd

# Profil du chargement, poste par poste : champ, bruit, elements, falaise,
# chemins, dispersions. C'est l'etape 1 de toute optimisation, et le seul
# endroit ou les chiffres du §0 se refont. **Fermer l'editeur d'abord.**
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path . -s tools/profile_worldgen.gd

# Reperer un chemin — une chaussee, une levee. Rend des lignes pretes a coller
# derriere `--`, **sur la graine 2024** — celle de la demo, invariant n. 37.
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path . -s tools/find_path.gd

# Reperer une mare, pour viser une capture dessus. Rend des coordonnees pretes
# a passer a `--ici`, **sur la graine 2024** — celle de la demo, invariant n. 37.
./godot.windows.editor.double.x86_64.exe --headless --path . -s tools/find_pond.gd

# Se poser a un point **nomme** plutot qu'au premier endroit qui convient : les
# coordonnees sont celles de l'ATH, donc celles qu'on lit sur une capture
# precedente. C'est ce qu'il faut pour viser un objet local — un element de
# tuile, un bosquet — au lieu de relancer --biome jusqu'a tomber dessus.
# **La demo tourne sur la graine 2024**, pas sur le 1337 des outils headless.
./godot.windows.editor.double.x86_64.exe --path . scenes/terrain_demo.tscn \
    --resolution 1600x900 -- --ici 8396632 8396464 --shot 30 --vue 224

# Planche de validation des assets : **une capture par modèle, seul, de près**,
# sur un damier neutre d'un bloc de maille, deux angles (face et trois-quarts).
# Pas de terrain, donc rien à attendre : les 84 sujets sortent en 6 secondes,
# dans user://portraits, plus une planche de contact par lot et par angle.
# --lot : flore | arbres | especes | filons | tout.  `especes` est le lot le plus
# utile — l'arbre **monté** par CWTreeScatter, tronc et houppiers assemblés,
# c'est-à-dire ce que le jeu pose, là où `arbres` ne montre que les pièces.
# --seul filtre sur un bout de chemin, --taille change le côté en pixels (640).
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --path . scenes/model_portraits.tscn -- --lot tout
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --path . scenes/model_portraits.tscn -- --lot especes --seul chene

# Gabarit d'échelle en jeu : mettre scale_board = true sur le nœud racine de
# scenes/terrain_demo.tscn, puis lancer. Deux captures dans user://shots.
# (La carte, elle, a sa bascule en ligne de commande : `-- --carte`.)
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --path . scenes/terrain_demo.tscn
```

Aperçus PNG écrits par la suite de tests dans
`user://worldgen_preview/` (`height.png`, `climate.png`, `channels.png`) →
`C:\Users\Admin\AppData\Roaming\Godot\app_userdata\Zentarys\worldgen_preview\`.

Démo : `res://scenes/terrain_demo.tscn`. Clic pour capturer la souris,
ZQSD/WASD, Maj = rapide, Espace/Ctrl = monter/descendre, **F1** détails,
**clic gauche** creuser, **clic droit** poser,
**F12** capture d'écran dans `user://shots`, **Page haut/bas** distance de vue,
**M** carte du monde (`+`/`−` pour l'élargir), **1-6** téléportation vers un
biome, **F2** fige l'heure, **F3**/**F4** reculent ou avancent d'une heure,
**Échap** rend la souris puis quitte.

## 3. État

**Jalon 1 (le monde) : 1.1 à 1.16 sont portés, testés et vus en jeu.** Suite de
validation : **408 vérifications, 0 échec**, ~25 s. Le détail de chaque jalon est
dans `docs/ROADMAP.md` ; ce qui suit est ce qu'il faut savoir *avant de toucher
au code*.

### Ce que le monde contient aujourd'hui

Le champ d'altitude et son climat (1.1-1.5), les **éléments de tuile** qui le
déforment (1.6), les **six biomes** de l'alpha 2013 — Greenlands, Snowlands,
Deserts, Jungles, Lava Lands, Oceans — et les matières de surface qui en
découlent (1.12), les **provinces climatiques** qui font qu'une Snowlands peut
toucher un désert (1.12bis), la **falaise** qui habille de roche les flancs
raides (1.13, retirée puis rétablie tramée), les **lacs et rivières** qui suivent
les fonds de vallée (1.14), le **réseau de chemins** et ses levées (1.16).

Par-dessus : la **flore** (1.7), instanciée ; les **arbres** (1.11), dont
toutes les pièces sont **écrites dans le terrain** depuis le 2026-09-11 —
la couche d'instances d'arbres n'existe plus, l'**édition** et sa persistance (1.8),
l'**éclairage voxel** là où le joueur a creusé (1.9), et la **carte du monde**
(1.10).

### Ce qui a été retiré, et c'est ce qui coûte le plus cher à redécouvrir

Quatre systèmes ont été portés puis retirés. **Les quatre passaient tous leurs
tests** — c'est la leçon centrale du dépôt, et elle est écrite en tête de
`tests/relief_test.gd` : *cette suite vérifie de la géométrie, jamais du rendu ;
la capture reste le juge.*

| retiré | quand | pourquoi |
|---|---|---|
| **la falaise**, première version | 2026-09-06 | peindre de la roche sur un flanc à 27° fait une tache, pas une paroi. *Une falaise ne se peint pas, elle se taille.* Revenue le lendemain, **tramée** |
| **les ponts** et le lot d'ouvrages | 2026-09-09 | *trop compliqués à intégrer*. Remplacés par une **levée** : le chemin comble l'eau au lieu de l'enjamber. C'est un barrage, et c'est assumé |
| **les surplombs** et leurs grottes | 2026-09-10 | trois refontes en trois jours — chapeau sur socle, masses escaladables, masses déformées à gradins — et aucune ne convainc en jeu. *Trois refontes qui ne convainquent pas disent que ce n'est pas la forme qui est en cause* |

Ce qu'il faut en retenir avant de reproposer l'un des trois : **une chose absente
de la source n'est pas hors périmètre, elle est à décider** — c'est ce qui a
justifié les chemins, qui eux sont restés.

### Les couches, et l'ordre dans lequel elles se posent

La chaîne va dans un seul sens et ne revient pas :

```
chemins  →  champ d'altitude (climat, chenaux, éléments, étangs)
```

Le réseau de chemins lit l'altitude du terrain ; le terrain ne le lit pas. C'est
l'**invariant n° 38**, et c'est ce qui dispense cette couche de la garde de
réentrance que `CWTileFeatureGrid` doit porter — ses éléments, eux, déforment le
champ dont ils lisent l'altitude.

L'ordre des recouvrements dans une colonne — **invariant n° 39** — est : *le
tronc estampé recouvre tout, le chemin creuse, l'étang mouille, le terrain
porte*. `_generate_block` les pose du plus profond au plus superficiel,
`voxel_of` les teste à l'envers.

### Les trois choses qu'un nouveau venu confond

1. **Un biome n'est pas une matière de surface** (invariant n° 27). `CWBiome.at`
   dit *où on est*, `CWPalette.surface_of` dit *de quoi c'est fait*.
2. **Il y a quatre grilles de dessin** (invariant n° 28), et `VOXELS_PER_BLOCK`
   (40/3) n'est plus la seule : arbres et filons à **1** voxel par bloc, flore à
   **4 ou 6**, personnage et créatures à **40/3**. La grille est portée par le
   *modèle*, pas par la bibliothèque.
3. **La flore n'est jamais écrite dans les données voxels** (invariant n° 12) ;
   **un arbre, entièrement, si** — le fût depuis le jalon 1.11, le feuillage et
   les modèles entiers depuis le 2026-09-11. Toutes ses pièces sortent du même
   tirage, dans la même liste (invariant n° 35). C'est aussi ce qui interdit
   d'estamper les cactus : ils sont de la **flore**, à 4 voxels par bloc.

### La carte des fichiers

```
src/worldgen/
  cw_value_noise.gd        bruit de valeur (Hugo Elias), arithmétique 32 bits
                           émulée — et le choix entre ses deux corps, GDScript
                           et natif (2026-09-11)
  cw_rand.gd               LCG de la CRT MSVC
  cw_region_site.gd        structure d'un site de zone
  cw_region_site_grid.gd   grille 1024² paresseuse, caches sous mutex
  cw_tile_feature.gd       structure d'un élément de tuile
  cw_tile_feature_grid.gd  grille 8x8 par zone, paresseuse, garde de réentrance
  cw_terrain_field.gd      climat + altitude + chenaux + éléments  ← le cœur
  cw_biome.gd              les six biomes et la règle qui les décide (1.12)
  cw_path_network.gd       le réseau de chemins, ses portes et ses levées (1.16)
  cw_palette.gd            palette, matières de surface, coulées de lave (1.12)
  cw_voxel_generator.gd    VoxelGeneratorScript, cache de colonnes, arbres estampés
  cw_voxel_model.gd        modèle .vox préparé : deux grilles de dessin (1.12)
  cw_model_library.gd      chargement des modèles + tables par biome et par rôle
  cw_scatter.gd            grille de dispersion 16², cellules en cache
  cw_decor_rules.gd        rôles du décor : deux crêtes, rareté, taille, filtre
  cw_flora_drops.gd        ce que rend une plante, et les chaînes d'artisanat (1.12)
  cw_flora_renderer.gd     instanciation de la flore (MultiMesh par cellule)
  cw_tree_rules.gd         les espèces d'arbres et leurs trois montages (1.11)
  cw_tree_scatter.gd       la couche jumelle : cellule de 64, espacement de 14,
                           et l'arbre entier en matière (1.11, feuillage
                           compris depuis le 2026-09-11)
  cw_world_edits.gd        creuser, poser, interroger un bloc (1.8)
  cw_light.gd              éclairage voxel : deux passes, cases à repeindre (1.9)
  cw_world_map.gd          carte : dalles de Voronoï, découverte, teintes (1.10)
  cw_region_name.gd        noms de région : deux tables de vingt syllabes (1.10)
src/demo/terrain_demo.gd     scène de démonstration, touches 1-6 par biome
src/demo/cw_clouds.gd        la couche de nuages : une grille de ciel, un tirage
                             pur par cellule, une derive d'ensemble (2026-09-11)
src/demo/cw_daylight.gd      le cycle jour/nuit : un scalaire d'heure, et une
                             seule fonction qui en déduit soleil, ciel, nuages,
                             ambiante et brouillard
src/demo/cw_sky.gdshader     le ciel nu : dégradé à trois bandes et soleil. Les
                             nuages en sont partis le 2026-09-11
src/demo/cw_demo_map.gd      l'état de la carte du monde : rendu de fond,
                             découverte, sauvegarde (1.10)
src/demo/scale_board.gd      gabarit d'échelle : mires, silhouette, modèles
src/demo/model_portraits.gd  planche de validation : un modèle par capture
src/demo/map_overlay.gd      affichage de la carte (touche M)
tests/worldgen_test.gd       suite headless, tient le compte des vérifications
tests/tile_features_test.gd  la moitié qui concerne les éléments de tuile
tests/decor_test.gd          rôles, tables croisées, filtre de matière, composition
tests/flora_test.gd          modèles, dispersion, maillage et pose
tests/tree_test.gd           lot, enveloppes, grille, dispersion, espacement, montage
tests/edit_test.gd           règles d'édition, requête ponctuelle, persistance (1.8)
tests/light_test.gd          les deux passes, l'atténuation, les cases à repeindre (1.9)
tests/map_test.gd            échelle, découverte, puzzle, rendu, noms (1.10)
tests/relief_test.gd         chemins, levées, tramage (1.16)
tests/sky_test.gd            le lot de nuages, la pureté du tirage, et les deux
                             accords que rien d'autre ne tient (2026-09-11)
tools/export_palette.gd      régénère assets/palette/* depuis CWPalette
tools/biome_stats.gd         répartition des biomes et des matières, mesurée (1.12)
tools/biome_balance.gd       les seuils qui rendent six parts égales, résolus
                             par quantiles (2026-09-11)
tools/preview_features.gd    gros plan ombré, avec et sans la couche d'éléments
tools/inspect_model.gd       inventaire d'un .vox : gabarit, index, plages, morceaux
tools/repaint_models.gd      remet un .vox dans la palette de projet
tools/preview_map.gd         aperçu de la carte, vierge et après une diagonale
tools/find_path.gd           une chaussée, une levée (1.16)
tools/profile_worldgen.gd    le profil du chargement, poste par poste
tools/profile_mesh.gd        ce que coute le maillage : sommets, tramage,
                             fusion gloutonne, memoire (2026-09-11)
native/                      la GDExtension : le bruit de valeur en C++, sa
                             chaine de construction et l'examen d'exactitude
                             qui decide si on s'en sert (2026-09-11)
tools/blender/               générateurs des lots de modèles
  flore_vox.py                 palette verbatim, écriture .vox, garde-fous
  flore_formes.py              brins, tiges, feuilles, corolles, cailloux
  flore_blender.py             courbes, métaballes, échantillonnage sur grille
  flore_blocs.py               formes de flore à la maille de 4 voxels par bloc
  generer_flore.py             le catalogue des 38 modèles de flore, à 4 vox/bloc
  arbres_formes.py             formes à la grille fine — plus employé par les arbres
  arbres_blocs.py              formes à la maille du bloc : disques, dômes, palmes
  generer_arbres.py            le catalogue des arbres, à 1 voxel = 1 bloc
  generer_filons.py            les 9 filons, à 1 voxel = 1 bloc
  generer_nuages.py            les 3 nuages, à 1 voxel = 1 bloc, par métaballes
docs/ROADMAP.md              la feuille de route, le journal, et le récit des sessions
docs/ASSETS.md               l'échelle d'authoring et ce qu'il faut produire par biome
docs/systems/01..05          les analyses de rétro-ingénierie
assets/palette/              palette de projet + PALETTE.md
assets/models/flore/<biome>/   38 modèles, un dossier par biome (six)
assets/models/arbres/<biome>/  39 modèles d'arbres, à la maille du bloc
assets/models/filons/          9 filons, estampables (1 voxel = 1 bloc)
assets/models/nuages/          3 nuages, instanciés dans le ciel (1 voxel = 1 bloc)
assets/models/                 MODELS.md (échelle, palette et conventions)
docs/images/                 gabarit, carte et composition de flore, en jeu
```

## 4. Invariants à ne pas casser

1. **Les constantes de référence du bruit et du LCG sont porteuses.** Les
   valeurs attendues dans `_test_value_noise` et la séquence MSVC
   `41, 18467, 6334…` fixent l'identité de tous les mondes générés. Si elles
   bougent, chaque monde déjà exploré change. Ne jamais « corriger » ces tests
   pour les faire passer : c'est le code qui a régressé.
2. **`world_origin` s'applique dans `CWVoxelGenerator._get_patch`, nulle part
   ailleurs.** Le sampler travaille en coordonnées monde (~8,4 millions), la
   scène en coordonnées Godot proches de zéro. Appliquer le décalage deux fois,
   ou l'oublier, fait décrire deux endroits différents au terrain rendu et à
   l'ATH — et ça ne se voit qu'en comparant des couleurs de biome.
3. **`site_edge_radius = 0` est délibéré.** Les deux termes liés aux arêtes du
   graphe de sites comparent un *carré de distance en unités monde* à des seuils
   de l'ordre de l'unité. Résultat : une tranchée d'une seule colonne le long de
   chaque arête. Voir `docs/systems/01`, §2.7.
4. **`swamp_channel_weight = 0` est délibéré.** Le champ sommé par
   `World_waterProximityInfluence` est perdu dans la décompilation. On connaît
   la structure du mélange, pas la grandeur mélangée. Ne pas deviner.
5. **Le plafond du cache de colonnes doit couvrir l'empreinte chargée.**
   `HEIGHTMAP_CACHE_CAP` ≥ `(2 × distance_de_vue / 16)²`, sinon le cache
   s'auto-évince en boucle et le chargement s'effondre sans rien signaler.
6. **Le marqueur « en cours » de `_get_patch` n'est pas décoratif.** Sans lui,
   les blocs verticaux d'une même colonne recalculent tous la même carte de
   hauteurs en parallèle et le cache ne sert plus à rien pendant le chargement.
7. **Un test épars ne voit pas un artefact d'une colonne de large.** D'où les
   deux balayages denses de 3 000 colonnes, l'un dans `_test_terrain_field`,
   l'autre en travers d'un élément de tuile. Tout nouveau terme du champ doit
   passer sous ce balayage.
8. **La grille d'éléments ne doit jamais être publiée à moitié.** Le générateur
   d'éléments échantillonne le champ d'altitude, qui relit la grille : la zone
   en construction doit se voir *vide*, et seulement pour le fil qui la
   construit. Les autres fils attendent. Publier tôt, ou laisser deux fils
   construire la même zone, ferait figer dans le cache de hauteurs des colonnes
   calculées sans déformation — un monde qui ne se régénère pas à l'identique,
   et rien pour le signaler. Le test « même monde depuis huit fils concurrents »
   est là pour ça.
9. **Le poids d'influence d'un élément est déformé.** Le fond d'un cratère n'est
   pas à son centre géométrique mais à une centaine d'unités de là. Un test qui
   échantillonne le centre exact mesure autre chose que ce qu'il croit.
10. **Un bloc de terrain vaut 40/3 voxels de modèle — 3 blocs = 40 voxels.**
    `CWVoxelModel.VOXELS_PER_BLOCK` est un contrat d'authoring, verrouillé par
    deux tests. La valeur vient de l'original : ses échelles d'instanciation du
    décor sont 0,075 / 0,09 / 0,1, et **0,075 = 3/40 exactement**. Écrire
    `13.333` ferait dériver le rapport ; c'est la fraction qui est dans le code.
    Un cube de référence d'un bloc n'est pas entier : dans MagicaVoxel on pose un
    cube de **40 = 3 blocs**. Ce qui *peut* bouger au jalon 3.1, c'est la taille
    du personnage en blocs (2,4 aujourd'hui) — les modèles se remettent à
    l'échelle ensemble.

    **Depuis le 2026-09-06, cette constante ne porte plus la flore** : elle porte
    le personnage, les créatures, le mobilier et les objets. La flore est passée
    à 4 voxels par bloc (`docs/ASSETS.md` §1), et c'est le premier écart assumé
    ce projet et une valeur relevée dans l'original. La constante reste la
    référence mesurée et la valeur par défaut d'un modèle chargé sans grille.
11. **`CWScatter.SUBBLOCK_STEPS` n'est pas `VOXELS_PER_BLOCK`.** La finesse de
    *position* d'une plante sous son bloc est une grille entière (16 pas) ; la
    grille de *dessin* vaut 40/3 et n'est plus entière. Les deux ont été
    confondues tant que le rapport tombait juste. Repasser la position sur
    `VOXELS_PER_BLOCK` casse le parse — `rng.mod()` prend un entier.
12. **La flore n'est jamais écrite dans les données voxels du monde.** Elle est
    treize fois plus fine que la grille du terrain. Le générateur ne la consulte
    plus du tout ; elle est instanciée par `CWFloraRenderer`. Le test « le
    terrain ne contient plus de flore » attrape un retour en arrière — qui, sans
    lui, ferait juste doublon avec l'instance, sans erreur.
13. **Le mailleur consomme sa marge.** L'origine d'un maillage tombe sur le
    premier voxel utile du tampon, pas sur son coin : tout maillage construit à
    la main doit retrancher `CWVoxelModel.mesher_padding()`. L'oublier enterre
    l'objet d'un voxel — assez peu pour passer inaperçu à l'œil, d'où le test
    « la plante pose sur le sol, quelle que soit son orientation ».
14. **L'ancre d'un modèle est au centre de son empreinte et à sa base.** Le
    déplacer décale toute la flore déjà produite, et un modèle dessiné avec un
    socle vide sous lui flotte de la hauteur du socle.
15. **La crête de placement s'évalue avant l'échantillonnage de colonne.**
    Un candidat hors plaque doit coûter un bruit (~1 µs), pas une colonne
    (~75 µs). Inverser les deux lignes de `CWScatter._build_cell` triple le coût
    d'une cellule *sans rien changer au résultat* — c'est le piège du tirage à
    rejet, déjà payé une fois le 2026-09-04.
16. **`PLACEMENT_PASS_RATE` compense le budget de candidats.** C'est elle qui
    fait que `CWModelLibrary.DENSITY` se lit encore en plantes par cellule. Si
    `CWValueNoise`, la fréquence ou le seuil bougent sans qu'elle suive, la
    densité de tous les biomes dérive en silence. Un test la mesure. Et elle se
    mesure sur **plusieurs régions éloignées** : autour du seul point de départ
    elle sort à 0,3012 au lieu de 0,2917.
17. **La gigue d'échelle doit atteindre l'empreinte, pas seulement le dessin.**
    Une instance va jusqu'à 2× son modèle : la marge de
    `CWScatter.placements_in` et la boîte de visibilité de chaque `MultiMesh` se
    calculent sur `Placement.radius_blocks()`, jamais sur `model.radius_blocks`.
    L'oublier fait disparaître les grandes touffes de la bordure du champ — et
    seulement celles-là, donc ça se voit tard.
18. **`CWVoxelGenerator.voxel_of` a deux consommateurs qui doivent s'accorder.**
    `_generate_block` la déroule par intervalles, `generated_voxel` l'évalue en un
    point. Rien dans le code ne les y oblige : c'est le test « la requête
    ponctuelle dit la même chose que le bloc généré » (4 096 points) qui tient le
    contrat. Une couche ajoutée au générateur et oubliée dans la règle donnerait
    des collisions portant sur un monde qui n'est plus celui qu'on voit. Et
    l'ordre des tests dans `voxel_of` est celui des recouvrements de
    `_generate_block` : la surface avant la roche, sinon `subsurface_depth = 0`
    rend de la roche là où le monde montre de l'herbe.
19. **Les éditions ne partent sur le disque que si `_flush_edits` tourne.**
    Fermer la fenêtre passe par `WM_CLOSE_REQUEST`, mais `--quit-after` et tout
    `SceneTree.quit()` direct n'envoient rien : d'où la seconde branche sur
    `NOTIFICATION_EXIT_TREE`. Sans elle, une session lancée pour une capture
    perd ses éditions sans un mot — constaté, 647 appliquées et zéro écrite.
20. **`CWWorldEdits` est en coordonnées de scène, `CWScatter` en coordonnées
    monde.** La table des sommets édités est lue par la dispersion : elle est
    donc rangée en coordonnées **monde**, et la conversion se fait dans
    `_set_top`, nulle part ailleurs. La première version s'est trompée de
    repère ; la recherche ne tombait jamais juste, la flore continuait de
    flotter, et **aucun test ne bronchait** parce que les deux côtés employaient
    le même repère. Un test qui ne traverse pas la conversion ne teste rien.
21. **`save_generator_output` doit rester à faux.** À vrai, chaque bloc visité
    part sur le disque et la sauvegarde grossit comme le monde exploré au lieu
    de grossir comme ce qu'on a touché. C'est aussi le modèle de l'original, qui
    ne sérialise que les colonnes modifiées.
22. **`CWDecorRules.FAMILIES` et `CWModelLibrary.ROLES` doivent se répondre
    exactement.** Un rôle qu'une surface sait *choisir* mais pas *poser* ne lève
    rien : la plante disparaît, et la densité moyenne ne bouge pas assez pour
    se voir — un quart des candidats d'un biome peut s'évaporer en silence.
    L'inverse, un modèle rangé sous un rôle que les deux crêtes n'atteignent
    jamais, est plus discret encore : le fichier est chargé, maillé, et ne sort
    pas une seule fois. Deux vérifications de `tests/decor_test.gd` tiennent les
    deux sens, et c'est la seule chose qui les tienne.
23. **Les tirages d'un candidat sont pris tous ensemble, avant tout test.**
    `CWScatter._build_cell` tire ses six valeurs — position, quart de tour,
    choix de variante, gigue, rareté — d'un bloc, puis décide. Un tirage placé
    *après* un `continue` désynchroniserait le flux du LCG d'un candidat à
    l'autre, et une cellule ne se reproduirait plus à l'identique selon les
    rejets qu'elle a rencontrés — un monde qui change entre deux visites, sans
    rien pour le signaler.
24. **La flore et les arbres ont deux bibliothèques, et ce n'est pas du
    rangement.** `CWScatter` calcule la marge de `placements_in` sur
    `CWModelLibrary.max_radius_blocks`, *tous modèles confondus* (invariant
    n° 17). Ranger un houppier dans la bibliothèque de la flore ferait passer
    cette marge de 2 blocs à 9 pour **toute** la flore, et chaque `MultiMesh`
    d'herbe porterait une boîte de visibilité démesurée — sans qu'aucun test ne
    tombe, seulement des images de plus à dessiner. `shared()` et
    `shared_trees()` restent séparées ; deux vérifications de `tests/tree_test.gd`
    mesurent les deux maxima et refusent qu'ils se rejoignent.
25. **L'espacement minimum des arbres ne doit jamais consulter une cellule
    construite.** `CWTreeScatter._candidats` est une fonction **pure de l'indice
    de cellule** : c'est ce qui permet à une cellule de regarder ses huit
    voisines sans déclencher leur construction. Le jour où cette fonction
    échantillonnerait autre chose que le bruit et le centre de sa cellule, la
    dispersion deviendrait récursive et se bloquerait sous verrou. La règle du
    **rang absolu** `(cz, cx, i)` va avec : elle rend la décision indépendante
    de la cellule qui la pose, et elle n'est valable que tant que
    `ESPACEMENT <= cell_size`.
27. **Un biome n'est pas une matière de surface.** `CWBiome.at` dit *où on
    est*, `CWPalette.surface_of` dit *de quoi c'est fait*. Les tables de contenu
    — `DENSITY`, `ROLES`, `SPECIES`, `FAMILIES` — sont indexées par **biome** ;
    seules deux exceptions sont indexées par matière (`FAMILIES_SURFACE` : le
    sol humide et l'herbe sèche), et chacune déclare le biome qui la produit
    dans `FAMILIES_SURFACE_BIOME` pour qu'un test puisse vérifier que ses rôles
    ont des modèles là où elle peut se produire. Confondre les deux ferait
    pousser des bleuets sur la roche nue d'une prairie de montagne — ce que
    `decor_allowed` empêche, et qu'aucun test de table ne verrait.
28. **Il y a quatre grilles de dessin, et `VOXELS_PER_BLOCK` n'est plus la
    seule.** Les arbres et les filons sont à **1** voxel par bloc, le personnage
    et les créatures à **40/3**, et la flore à **4 ou 6** selon le modèle —
    6 pour les herbes et les fleurs (`CWModelLibrary.GRILLE_FINE`), 4 pour tout
    ce qui a du volume.

    **La grille n'est donc plus décidée par la bibliothèque mais par le
    modèle.** C'est `_grid_of` qui tranche, et il consulte une table de chemins.
    Cette table et la colonne `FIN` du catalogue de `generer_flore.py` doivent
    dire la même chose : le générateur dessine à la grille qu'il croit, le
    moteur instancie à celle qu'il lit. S'ils divergent, la plante sort à une
    taille fausse **d'un facteur un et demi** — assez pour se voir, pas assez
    pour qu'on remonte à la cause. Deux vérifications de `tests/flora_test.gd`
    tiennent les deux sens : aucun modèle chargé à une autre grille que la
    sienne, et aucune entrée de `GRILLE_FINE` qui ne désigne rien.
    C'est un champ de `CWVoxelModel` (`voxels_per_block`), posé au chargement par
    la bibliothèque. Tout ce qui convertit des voxels en blocs doit lire **celui
    du modèle**, jamais la constante. Tant que la flore était à 40/3 — la valeur
    de la constante —, l'erreur était invisible sur les trois quarts du lot ;
    depuis que les trois grilles sont distinctes, plus aucun lot ne tombe sur la
    constante par hasard, et c'est une amélioration silencieuse. Deux
    vérifications de `tests/tree_test.gd` et une de `tests/flora_test.gd`
    tiennent le contrat.
29. **Aucune plante de Snowlands ne prend la rampe 140-147.** C'est la rampe
    « automne, herbe sèche », un orange chaud ; sur un sol de neige — un cyan
    très clair — chaque plante qui l'emploie ressort en tache orange, seul objet
    chaud du paysage. Le défaut a été relevé **deux fois** : le 2026-09-05 sur la
    broussaille de neige, corrigé pour elle seule, puis le 2026-09-06 sur cinq
    modèles du nouveau lot. Snowlands puise dans le bas de la rampe de feuillage
    (136-139), l'écorce sombre (151-155) et le clair de la roche nue (14-15).
    Aucun test ne peut le voir : c'est une capture, ou rien.
30. **Une palme est une paire de frondes opposées, et une paire est symétrique.**
    Le dessin par paires met l'attache sur l'ancre — qui est le centre du
    gabarit, pas le point d'attache — dans le **plan horizontal**. Mais tourner
    une paire d'un demi-tour rend exactement la même image :
    `_couronne_de_palmes` n'avance donc son quart de tour **qu'une pièce sur
    deux**, sinon la troisième palme se pose sur la première et la couronne se
    lit comme une planche en travers du stipe.
31. **La frontière `RANGE_TERRAIN_END` / `RANGE_CREATURES_BEGIN` a bougé une
    fois, le 2026-09-05, et ce sera la dernière fois gratuitement.** Elle est
    passée de 31/32 à 40/41 pour loger les neuf filons. C'était sans coût
    *parce que la plage créatures n'avait aucune entrée peinte* ; dès qu'un
    modèle de créature existera, le même geste imposera de repasser tout un lot
    par `tools/repaint_models.gd`. Vérifier avec `inspect_model.gd` avant de
    toucher à une frontière, jamais après.
32. **Une pièce dont le point d'attache n'est pas sa base doit être décalée en Z
    par l'assembleur.** `_piece` pose un modèle par sa base, ce qui est juste
    pour un tronc et pour un houppier. Une palme retombe : son attache est son
    voxel le plus **haut**, et sans correction la couronne se pose `height - 1`
    blocs au-dessus du stipe. Le décalage se calcule à l'échelle de l'instance
    et à la grille du modèle (`* echelle / m.voxels_per_block`, invariant
    n° 28), jamais en voxels bruts.

    Ce qui rend le piège cher : le décalage avait été traité **dans le dessin**,
    en centrant la paire sur son attache (invariant n° 30), et l'affaire passait
    pour close. Elle ne l'était que sur deux axes sur trois. Une correction
    partielle est plus dangereuse qu'une absence de correction, parce qu'elle
    ferme la question.
33. **Changer la taille d'un modèle, c'est changer sa densité — et rien dans le
    code ne le rappelle.** `CWModelLibrary.DENSITY` et `CWTreeRules` se lisent en
    *objets par cellule*, pas en surface couverte : multiplier un modèle par
    quatre en volume sans toucher à sa densité multiplie par quatre ce qu'il
    couvre. Le 2026-09-06, le caillou est passé de 8 à 30 voxels à densité
    constante, et Greenlands s'est retrouvée avec des champs de rochers où l'on
    ne passait plus — assez serrés pour qu'on croie à un élément de tuile. Le
    rôle a fini supprimé. L'espacement des arbres, lui, a été doublé
    *en même temps* que le lot grandissait, et c'est pour cela qu'on ne l'a pas
    vu venir de ce côté-là. Aucun test ne peut attraper ça : une densité trop
    forte est une densité valide.
34. **Un modèle est d'un seul tenant.** Deux voxels qui ne se touchent même pas
    par un coin sont deux objets : en jeu, le second flotte. Vérifié depuis le
    2026-09-06 sur tout le lot de flore (`tests/flora_test.gd`, 26-voisinage) et
    rapporté à chaque écriture par les générateurs et par
    `tools/inspect_model.gd`. **La seule exception du dépôt est la palme**, qui
    est une paire de frondes opposées tenue par un stipe absent de son fichier :
    elle passe `souder=False` dans `generer_arbres.LOT`, et c'est le seul
    endroit où ce drapeau apparaît.

    La cause du défaut se répétait dans onze fonctions de dessin écrites
    séparément, et elle était toujours la même : **le pas de parcours d'un arc
    était pris sur son étendue horizontale**, alors que sa hauteur était trois
    fois plus grande. Une fronde de fougère longue de 4,5 et haute de 16 sortait
    en cinq voxels espacés de cinq. Corriger la primitive (`fb.fronde`,
    `fb.feuille`, `fb.rameaux`) valait mieux que corriger onze plantes ; la passe
    de soudure (`Grille.soude`) est le filet, pas le remède — un modèle qui
    demande beaucoup de soudure a une forme fausse, et le compte s'affiche pour
    ça.
35. **Un arbre est un tirage et une liste, jamais deux.** Le tronc estampé et
    les houppiers instanciés sortent de la même passe de montage
    (`CWTreeScatter._monte`) ; ce sont ses deux consommateurs qui se partagent
    la liste, par `Placement.matiere`. Recalculer la position du tronc côté
    générateur — ce qui serait plus direct à écrire — ferait diverger les deux
    moitiés d'un demi-bloc le jour où une constante de montage bouge, et
    personne ne saurait laquelle des deux a raison.

    Corollaire : **une matière ne se met pas à l'échelle**. La gigue d'instance
    d'un tronc devient un rééchantillonnage vertical au plus proche voisin, et
    c'est `Placement.hauteur` — un nombre entier de blocs — qui dit où
    s'accroche le premier houppier. Le produit `hauteur × échelle` ne décrit
    plus rien de posé.
36. **La portée de la végétation est un carré, parce que le terrain est une
    boîte.** `CWFloraRenderer` posait ses cellules dans un disque : les quatre
    coins de la boîte chargée portaient du terrain sans porter de flore, et
    depuis que le tronc est écrit dans le terrain, un fût nu. Toute portée
    exprimée en cellules doit suivre la forme de ce que Voxel Tools charge, pas
    la forme d'une distance. Le surcoût de 4/π ne se mesure pas : le verrou du
    chargement est la génération du terrain.

37. **La démo et les outils headless ne tournent pas sur la même graine.**
    `terrain_demo` porte `world_seed = 2024`, `CWWorldParams` a `1337` par
    défaut, et `tools/biome_stats.gd` prend la sienne en argument. Un point
    repéré par un sondage headless puis visé par `--ici` décrit donc **deux
    endroits différents**, et rien ne le signale : les coordonnées sont valides
    des deux côtés, seul le terrain change. Tout script jetable qui sert à viser
    une capture doit poser `p.world_seed = 2024`. Compté une fois, trois quarts
    d'heure.

38. **Les couches de relief sont posées *au-dessus* du champ, jamais dedans.**
    Le réseau de chemins lit l'altitude du terrain ; le terrain ne le lit pas.
    C'est ce qui le dispense de la garde de réentrance, des trois verrous et de
    l'attente entre fils que `CWTileFeatureGrid` doit porter — ses éléments, eux,
    déforment le champ dont ils lisent l'altitude. Le jour où un terme de
    `_height_from` consulterait un chemin, tout cet appareil redeviendrait
    nécessaire, et rien ne le signalerait avant qu'un monde cesse de se
    régénérer à l'identique.
39. **L'ordre des recouvrements est un contrat entre deux fonctions écrites à
    l'envers l'une de l'autre.** `_generate_block` pose ses intervalles du plus
    profond au plus superficiel et les laisse s'écraser ; `voxel_of` les teste
    dans l'ordre **inverse** et sort au premier. L'ordre complet est : *le
    chemin creuse, l'étang mouille, le terrain porte* — et l'**arbre estampé**
    passe avant tout, puisque `_stamp_trees` écrit après tous les
    remplissages. Une couche ajoutée d'un seul côté donne un monde dont les
    collisions et l'édition décrivent autre chose que ce qu'on voit — c'est
    l'invariant n° 18, et le tronc en a été l'exemple : il a manqué du côté de
    la requête ponctuelle du jalon 1.11 au 2026-09-10, sans qu'aucune
    vérification tombe.

    ⚠️ **Une exception, et une seule : le feuillage ne recouvre que le vide**
    (2026-09-11). Une couronne est posée *autour* du fût qui la porte ; la
    laisser écraser ce qu'elle traverse effacerait le fût sur toute sa hauteur,
    et surtout ferait décider l'**ordre des listes** — le bloc rendait du
    feuillage là où la requête ponctuelle rendait du bois, dès la première
    exécution de la suite. La règle est écrite des deux côtés :
    `_stamp_trees` saute une feuille sur un voxel non vide, `generated_voxel`
    ne rend `LEAVES` que si le terrain sous elle est de l'air. C'est la seule
    couche du monde qui ait cette forme-là.
40. ~~*Les deux intervalles d'air ne se réunissent jamais en un seul.*~~ Sans
    objet depuis le retrait des grottes : il ne reste qu'un intervalle d'air,
    celui du dégagement d'un chemin.
41. ~~*Une déformation de bord se règle en nombre de lobes par tour.*~~ Partie
    avec les massifs (2026-09-10) ; la leçon est gardée dans l'annexe de
    `docs/ROADMAP.md` (§7nonies.3), et vaudra pour tout ce qui déformera un objet
    de taille variable.
42. **Le dessus *praticable* d'une colonne a un point unique, et quatre
    consommateurs.** `CWPathNetwork.shaped_top` dit où est le sol quand un
    chemin traverse la colonne — il la tranche sur terre, il la remblaie sur
    l'eau. Le générateur, la requête ponctuelle, `CWScatter` et `CWTreeScatter`
    doivent tous les quatre passer par là. C'est le piège du creusement des
    étangs au jalon 1.14, repris trois fois : un objet posé à la hauteur brute
    du champ **flotte ou s'enterre**, et le défaut ne se voit que sur une
    capture.
43. **Un chemin ne sort pas de sa zone, et c'est ce qui rend la couche
    abordable.** Sans cette borne, une colonne devrait consulter le réseau des
    neuf zones voisines, donc les construire toutes — 350 ms chacune. Les zones
    se raccordent par des **portes** dont la position est une fonction pure de
    l'identité de la frontière : les deux voisines tombent sur le même point sans
    se lire. Toute modification du tracé doit garder le `clampf` sur les bornes
    de zone dans `_relaxe`, et une vérification compte les bornes qui sortent.
44. **Le pochoir de la pente est aligné sur la grille du monde, pas sur celle du
    bloc.** La pente se mesure par différence **avant** sur un bloc, ce qui
    demande une colonne de plus sur chaque axe de l'empreinte — +12,9 %
    d'échantillonnage, le prix de la falaise. Une différence *centrée*, ou un
    pochoir qui dépendrait de la position dans le bloc, coûterait moins ou
    autant mais ferait diverger `_generate_block` et `slope_at` d'une colonne sur
    seize : la requête ponctuelle ne connaît pas l'origine du bloc.
45. **La couleur d'un bloc de surface n'est plus celle de son type, et c'est le
    contrat.** Depuis le 2026-09-08, `CHANNEL_TYPE` porte la matière et
    `CHANNEL_COLOR` une **nuance** de sa couleur : trois tons pour une prairie,
    cinq marches de fondu au bord d'une plage. Le seul endroit où les deux canaux
    peuvent diverger est `_fill_run`, par son paramètre `raw` — un appelant qui
    l'oublie obtient l'aplat d'avant, pas une incohérence. Ce qui reste
    vérifiable est le voisinage : une teinte doit rester reconnaissable comme
    celle de sa matière, et `tests/edit_test.gd` refuse tout ce qui s'en éloigne
    de plus de la moitié de la distance à la couleur de terrain la plus
    lointaine. **Le facteur de fondu se tire du même bruit que le type** : avec
    deux bruits indépendants, le damier et le dégradé se déphasent et le sol se
    couvre de blocs à contre-teinte.
46. ~~*Un massif doit s'escalader.*~~ Le contrat avait déjà été retiré le
    2026-09-09 ; les massifs l'ont suivi le 2026-09-10.
47. ~~*Une déformation se règle en nombre de lobes par tour.*~~ Doublon du n° 41,
    parti avec lui.
48. ~~*La galerie d'une grotte part du seuil du massif.*~~ Sans objet : il n'y a
    plus de grotte.
49. **Un relevé grossier d'une chose fine ne s'affine pas partout.** Le profil
    d'un chemin pose un jalon tous les 32 blocs ; une rivière en fait six de
    large, donc elle passe entre deux jalons neuf fois sur dix, et le premier
    relevé des franchissements n'en a trouvé aucun de ceux qu'on voyait en jeu.
    Le remède n'est pas de descendre le profil à 4 blocs — ce serait huit fois le
    coût d'un réseau — mais de **raffiner là où la chose peut être** : le champ
    de chenaux est lisse, un jalon à trente blocs d'une rivière a déjà une valeur
    basse, et moins d'un segment sur dix est sondé de près.
50. ~~*Une travée de pont a sa longueur sur X.*~~ Sans objet : il n'y a plus de
    pont (2026-09-09).
51. **Une mesure de chargement se refait, elle ne se recopie pas.** Le fichier a
    porté « 28,5 s à 384 blocs » pendant deux jours pendant que le chiffre réel
    dérivait à **107,7 s** : deux passes sur la couche de massifs l'avaient
    quadruplé, et aucune des deux ne l'a remesuré. Le retrait de la couche l'a
    ramené à **55,4 s** le 2026-09-10, et le réglage du pool à **42,0 s** le
    même jour. Toute mesure de coût citée ici porte donc sa date, et une date qui
    a plus d'une session vaut comme ordre de grandeur, pas comme référence.

52. **Un nuage appartient au ciel, et c'est le seul réglage de rendu du dépôt
    qui diverge de celui du terrain.** Tout ce qui est instancié partage le
    matériau du terrain — même palette, même mailleur, même rugosité —, et c'est
    la condition pour que les grilles lisent comme un seul monde. Les nuages en
    dérogent sur **deux points, et les deux ont une raison mécanique** :
    `disable_fog`, parce que le brouillard est réglé pour cacher le bord d'une
    vue de 384 blocs **au sol** et qu'un objet à mille blocs y deviendrait un
    aplat gris quand le ciel derrière lui n'en prend que 18 % ; et `backlight`,
    parce qu'un nuage est **traversé** par la lumière et qu'un dessous qui ne
    reçoit que l'ambiante sort bleu marine — constaté à la première capture du
    2026-09-11. Ces deux-là suffisent, et **il ne doit pas s'en ajouter un
    troisième** : la teinte, elle, continue de venir du soleil que
    `CWDaylight.applique` règle pour tout le monde. `tests/sky_test.gd` compare
    les deux matériaux terme à terme pour cette raison.

## 5. Pièges connus

- **`VoxelLodTerrain` est inutilisable avec un rendu en cubes** : des dalles
  d'eau apparaissent en pleine plaine dès le LOD 1. Bascule conservée
  (`TerrainDemo.use_lod`) pour revérifier après une mise à jour. Cause exacte
  non établie.
- **La propriété est `bounds` sur `VoxelTerrain`, `voxel_bounds` sur
  `VoxelLodTerrain`.** Deux noms, deux classes.
- **L'éditeur ne voit pas un nouvel `@export` tant qu'il n'a pas rechargé le
  script.** `filesystem_manage(op="scan")` ne suffit pas toujours ; changer la
  valeur par défaut dans le source est plus fiable pour un test ponctuel.
- **Coût mesuré le 2026-09-10 : 93,7 µs par colonne générée** — dont 77,6 pour
  le champ nu et ~46 pour le seul bruit —, et **42,0 s** pour stabiliser une vue
  de 384 blocs. C'est le plafond de tout. Ces chiffres portent leur date, et
  c'est délibéré — voir l'invariant n° 51 : le précédent a dérivé de 28,5 s à
  107,7 s en deux jours sans que personne le refasse. Le profil complet est en
  §0, et `tools/profile_worldgen.gd` le refait. La couche d'éléments n'ajoute rien de mesurable
  sur le chemin de streaming, qui passe par `sample_patch` et sort la
  consultation de la grille de la boucle de colonnes.
- **`sample_column` paie ce que `sample_patch` ne paie pas.** La grille
  d'éléments est protégée par mutex ; une consultation par colonne coûte ~2 µs.
  `sample_patch` n'en fait qu'une par tuile traversée. Pour tout nouveau
  consommateur en volume — l'étage de terrain lointain, par exemple — passer par
  `sample_patch`.
- **La couche de flore ne coûte plus rien au générateur.** Depuis qu'elle est
  instanciée au lieu d'être estampée, `_generate_block` ne la consulte plus : les
  +14 % par bloc mesurés le 2026-09-04 ont disparu du chemin de génération. Le
  coût s'est déplacé sur `CWFloraRenderer`, qui construit ses cellules sur un
  fil du pool — **1,1 ms par cellule** de 256 colonnes en prairie (1 + n
  échantillonnages : un pour décider la densité, un par plante posée). Ne pas
  revenir à un tirage à rejet : échantillonner un candidat pour le jeter ensuite
  triplait la facture.
- **Changer une entrée de la palette change tous les `.vox` à la génération
  suivante.** `flore_vox.write_vox` recopie le bloc `RGBA` de
  `assets/palette/zentarys_palette.vox` **verbatim** dans chaque fichier : le
  jour où l'index 4 est passé d'herbe sèche à bois, les 24 modèles d'arbres
  regénérés ce jour-là ont changé d'un octet et les 38 de flore, non. Sans
  conséquence à l'exécution — le chargeur reçoit la palette du projet, pas celle
  du fichier — mais le lot cesse d'être homogène pour qui l'ouvre dans
  MagicaVoxel. **Regénérer les trois lots après toute modification de
  `CWPalette`**, comme on réexporte `assets/palette/`.
- **Les 38 modèles de flore sont générés, pas dessinés.** Les rouvrir dans
  MagicaVoxel pour les retoucher est du travail perdu : la prochaine exécution
  de `tools/blender/generer_flore.py` les écrase. Corriger le générateur, puis
  regénérer. Le script recopie le bloc `RGBA` de la palette de projet tel quel
  et refuse à l'écriture tout index hors plage — c'est ce qui rend impossible
  la faute de palette du premier lot.
- **Un `Control` sous un `CanvasLayer` n'a pas de taille si on ne pose que ses
  ancres.** `set_anchors_preset(PRESET_FULL_RECT)` laisse les marges telles
  quelles, donc `size` reste nul : le dessin part d'une origine négative et sort
  par le coin supérieur gauche. C'est `set_anchors_and_offsets_preset` qu'il
  faut, plus un raccord sur `size_changed`. Aucun test ne peut le voir — un nœud
  invisible calcule juste ; c'est la capture en jeu qui l'a montré (2026-09-05,
  la carte du monde).
- **Le pas d'un arc se prend sur l'arc, pas sur sa projection au sol.** Onze
  fonctions de dessin échantillonnaient `round(longueur)` points sur une courbe
  qui montait trois fois plus haut qu'elle n'avançait : le modèle sortait en
  voxels détachés. Cause unique de treize des vingt-sept défauts du 2026-09-06
  (annexe de `docs/ROADMAP.md`, §6quater), et invisible dans les nombres — la
  boîte englobante, le compte de voxels et les plages de palette étaient tous
  justes.
- **Ne pas mettre d'appel de liaison moteur sur le chemin chaud.**
  `OS.get_thread_caller_id()` dans `CWTileFeatureGrid.get_zone` coûtait ~15 µs
  par colonne avant d'être déplacé sur le chemin froid. Mesurer avant de
  supposer que c'est le verrou qui coûte.

- **Chercher un itinéraire et épouser un sol ne se font pas à la même
  échelle.** Le premier tracé de chemin posait un jalon tous les 192 blocs et en
  déduisait l'altitude : entre deux jalons, l'altitude du chemin est une
  **corde**, le terrain bombe au milieu, et la colonne est tranchée de tout ce
  qui les sépare — seize blocs mesurés, à paroi verticale, qu'un accotement de
  quatre blocs ne pouvait pas raccorder. Deux mailles, deux rôles : l'itinéraire
  se cherche grossièrement, le profil épouse finement, et le bornage se reprend
  **colonne par colonne** parce que la corde survit à la maille fine.
- **La pente d'un champ lisse est un champ lisse, et ses valeurs fortes suivent
  les courbes de niveau.** Toute règle de surface posée sur un seuil de pente bas
  dessine donc des **rubans** le long des lignes de niveau — dans l'axe même des
  marches d'un bloc que la voxelisation dessine déjà. Le paysage se lit comme
  une carte topographique. Le remède est de ne prendre que le haut de la
  distribution, pas de tramer plus fin.
- **Une mesure de coût se prend sur une session qui ne fait que ça.** Le banc de
  `worldgen_test` a sorti 125 µs/colonne une fois, contre 73 à 80 les fois
  suivantes, simplement parce qu'une autre instance de Godot tournait en fond.
  Le chiffre n'avait rien à voir avec le code qui venait de changer, et il a
  failli déclencher une chasse à la régression.

## 6. Décisions ouvertes

- Le relief lointain paraît bleuté (ambiante du ciel sur les faces détournées du
  soleil). Réglage d'ambiance, pas un défaut de génération.
- Les teintes des plages d'assets sont des rampes de départ, à ajuster. Le
  découpage en plages, lui, est un contrat : le changer invalide les modèles
  déjà peints. Depuis le 2026-09-05 il y a des modèles peints dessus, donc
  ajuster une teinte se voit maintenant en jeu — c'est justement le bon moment
  pour le faire, avant le lot suivant.
- ~~**Deux tables de hauteurs coexistent et ne disent pas la même chose.**~~
  **Réglé le 2026-09-06** : `assets/models/MODELS.md` §1 porte les valeurs du lot
  regénéré, et c'est la seule table de référence. Rappel de ce qui l'a fait
  bouger : c'est cette ligne-là — « touffe d'herbe au genou » — qui avait
  dimensionné les trente-neuf premiers modèles. Un repère faux dans un document
  d'authoring coûte un lot entier.
- Les arêtes du graphe de sites ne sont **pas** le tracé des routes : le type 1
  est un élément unique par zone, posé sur son site. `site_edge_radius` reste
  donc à 0, et l'hypothèse notée au jalon 1.5 est close.
- **La gigue d'échelle de 1× à 2× est appliquée partout ici, nulle part dans la
  source.** L'original ne la tire que sur le décor immergé ; ailleurs il écrit
  une échelle fixe ou une petite plage par type. Elle est gardée parce que notre
  lot a moins de variantes par rôle et que le champ se lirait comme un motif
  répété sans elle — mais c'est une décision de ce projet, et elle se multiplie
  désormais au rapport de taille du rôle (`CWDecorRules.SCALE_RATIO`), ce qui
  porte une instance de caillou jusqu'à 2,9× son modèle.
- **Les feuilles de `CWDecorRules.FAMILIES` sont réattribuées, pas lues.** Trois
  branches viennent mot pour mot de la source — sol tempéré, sol chaud, fond
  marin ; les autres lignes rangent nos biomes dans la forme de la règle. Les
  changer coûte une ligne, et rien dans la source ne les contraint : c'est le bon
  endroit où ajuster ce qui se voit mal en jeu.
- **La règle des six biomes est une classification de ce projet.** La *liste*
  vient de l'alpha 2013, mais depuis le 2026-09-11 les seuils ne traduisent
  plus ses fourchettes du tout : ils sont **résolus pour que les six biomes
  fassent chacun un sixième du monde** (`tools/biome_balance.gd`). La conversion
  en degrés (`CWBiome.TEMP_MIN_C` / `TEMP_MAX_C`) n'est plus qu'une convention
  d'affichage, et elle ne se lit plus — un désert commence à 2 °C. Les seuils
  restent ajustables sans rien casser, à condition de relancer l'un des deux
  outils ; l'annexe de `docs/ROADMAP.md` (§6.3) dit pourquoi.
- ~~**La bande d'herbe sèche de Greenlands est large.**~~ **Sans objet** :
  `DRY_GRASS_H` n'existe plus depuis le 2026-09-06, avec le retrait de l'herbe
  sèche et de la toundra. Ce qui reste vrai de cette note est la mesure qui la
  portait — *le champ d'humidité n'a presque rien entre 0,10 et 0,40* —, et
  c'est elle qui a décidé où poser `CWBiome.HUMID_H` le 2026-09-11.
- **Oceans n'a été vu que d'au-dessus.** Voir l'annexe de `docs/ROADMAP.md`,
  §6.5.
