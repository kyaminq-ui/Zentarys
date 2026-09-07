# Zentarys — feuille de route

Réimplémentation « clean room » des systèmes de jeu de l'alpha Cube World sur
Godot 4.7.2 + Voxel Tools 1.7.

**Cadre.** On porte des *algorithmes*, jamais du code ni des données. Aucun
asset du jeu d'origine (`.plx`, `data*.db`, textures, sons, palette) n'entre
dans ce dépôt. Toute expression artistique reconnaissable — palettes, silhouettes
de créatures, noms propres, textes — est remplacée par une création originale et
signalée comme telle dans la note du système concerné.

**Source d'analyse.** `qad3n/CubeWorld-Reversal` : reconstruction par classe
(RTTI + graphe d'appels) du binaire alpha 2013. 1 370 fonctions de jeu côté
client, 288 côté serveur ; le reste est de la bibliothèque tierce (SQLite, CRT,
STL, FreeType) et n'a pas à être porté.

**Méthode, par système.** Analyse du pseudo-code → note dans
`docs/systems/NN_*.md` → implémentation GDScript typée → test headless qui
verrouille les invariants numériques → validation visuelle en jeu.

Statuts : ✅ fait · 🔶 partiel · ⬜ à faire · ⛔ hors périmètre

---

## Jalon 1 — Le monde

Le terrain conditionne tout le reste : physique, rendu, placement des créatures
et des structures.

**Les treize systèmes du monde qui restent au périmètre sont portés et
vérifiés.** Le monde se génère, se creuse, se sauvegarde, s'éclaire, se garnit,
se cartographie, se boise et **porte ses lacs** :

- **1.1 à 1.10**, le terrain ;
- **1.11**, la grande végétation — un lot d'assets, une seconde couche de
  dispersion, et **le tronc écrit dans le terrain**, qui est le premier objet du
  projet à traverser la matière et l'instance. **Fait le 2026-09-06** ;
- **1.12**, les six biomes — une couche de classification climatique au-dessus
  des matières de surface, et la refonte des deux lots d'assets qui en découle.
  **Fait le 2026-09-06**, et les deux lots revus un par un sur planche le même
  jour ;
- **1.13**, la falaise — portée le 2026-09-06 au matin et **retirée le soir
  même** : la règle de la source est juste, la pente était mesurée, les tests
  passaient, et le rendu en jeu ne valait pas la peine. C'est le premier système
  que ce projet défait pour une raison qui n'est ni un bogue ni une erreur
  d'analyse, et le compte rendu ci-dessous garde la mesure — c'est elle qui dit
  à quelle condition une falaise pourra revenir ;
- **1.14**, les lacs — l'eau de surface, dont la porte est le **champ de chenaux
  porté au jalon 1.4** : il ne manquait pas un champ, il manquait un seuil.
  **Fait le 2026-09-06**, et son analyse a corrigé deux erreurs de ce dépôt —
  `World_generateWaterOrPathFeature` **ne fait ni eau ni chemin**, c'est le
  douzième nom trompeur, et l'élément de tuile 12 n'est donc pas un plan d'eau.

- **1.15**, les **massifs**, leurs **grottes**, et la falaise qui revient — une
  seconde nappe de matière posée par-dessus le champ d'altitude. **Fait le
  2026-09-07**, et sa forme refaite **deux fois** : les mesas à chapeau plat sont
  devenues des masses arrondies qu'on peut gravir (2026-09-08), puis des masses
  **délibérément infranchissables** — allongées, déformées, à gradins — le
  2026-09-09, le contrat d'escalade ayant été retiré pour les obtenir ;
- **1.16**, les **chemins** et leurs **levées** — le réseau qui relie les jalons
  d'une zone, posé en dernier, qui tranche la colonne, perce les surplombs et
  **comble** les rivières. **Fait le 2026-09-07** ; le tablier de bois et son lot
  d'ouvrages ont été retirés le 2026-09-09, *les ponts étant trop compliqués à
  intégrer*.

**Le jalon 1 a été clos le 2026-09-06 et rouvert le lendemain**, pour trois
systèmes demandés en regardant le jeu d'origine à côté du nôtre. Ils ont ceci de
commun qu'aucun n'est dans la source, et la charte demande de le dire : ce sont
des **créations de ce projet**, écrites pour rapprocher le paysage de ce que
montrent les captures. C'est la deuxième fois — après les provinces climatiques
du 1.12bis — que ce dépôt ajoute une couche que l'analyse n'a pas trouvée, et
c'est la première où il en ajoute trois d'un coup.

> **Ce que 1.15 répare, c'est le diagnostic de 1.13.** *Une falaise ne se peint
> pas, elle se taille*, disait le compte rendu du retrait, et il ajoutait à
> quelle condition elle pourrait revenir : « il faudrait que le champ
> d'altitude produise d'abord des parois ». C'est exactement ce que fait la
> couche de surplombs, et la roche de pente revient avec elle — cette fois
> **tramée**, ce qui est la seconde moitié de la réponse.

Il reste ensuite la **collision**, objet par objet (`nextsteps.md`, §7bis.3), la
finition listée en dette technique, et les questions d'analyse pendantes de
`docs/systems/02`, §9. La porte suivante côté entités est **2.6, l'apparition**.

> **Correction de périmètre, 2026-09-07.** Cette feuille disait « les chemins
> sortent du périmètre : la source n'a pas de réseau de routes ». Le constat
> reste vrai — `World_roadField` est l'aplanissement du bourg, les arêtes du
> graphe de sites ne sont pas des voies, et l'invariant n° 3 tient. Ce qui
> change est la conclusion qu'on en tirait : *une chose absente de la source
> n'est pas hors périmètre, elle est à décider*. Elle a été décidée, et elle est
> écrite comme une création, signalée comme telle dans l'en-tête de
> `CWPathNetwork`.

| # | Système | Source analysée | Statut | Note |
|---|---|---|---|---|
| 1.1 | Bruit de valeur | `valueNoise2D` @004d5d30 | ✅ | `docs/systems/01` |
| 1.2 | LCG de la CRT MSVC | `World_generateRegionSite` | ✅ | idem |
| 1.3 | Sites de région, climat | `World_{temperature,humidity}Blend` | ✅ | idem |
| 1.4 | Champ d'altitude, chenaux | `World_baseHeightField` @004f9b70 | ✅ | idem |
| 1.5 | Générateur voxel + rendu cubes | — (portage Godot) | ✅ | idem |
| 1.6 | Éléments de tuile | `World_generateRegionFeatures` @0050e080 | ✅ | `docs/systems/01`, §2.7 |
| 1.7 | Contenu de biome, dispersion | `creature_generateAppearance` + @005e4850 + @005d8750 + @005f0ce0 | ✅ | dispersion, 39 modèles, **table de sélection portée** ; `docs/systems/02` |
| 1.8 | Colonnes persistantes, édition | `Chunk_getColumnAt` @00406100 + `VoxelTool` | ✅ | `docs/systems/03` |
| 1.9 | Éclairage voxel | `VoxelChunk_propagateSunlight` @0059a0e0 | ✅ | porté, rendu passé en `COLOR_RAW` ; `docs/systems/04` |
| 1.10 | Carte du monde | `WorldMap.cpp`, `loadLandscapeTile` @006024d0, `NameGen_generateRegionName` | ✅ | pièces de Voronoï, découverte, noms ; `docs/systems/05` |
| 1.11 | **Arbres et grande végétation** | voie des entités, `docs/systems/02` §5.2 | ✅ | assets, dispersion, montage, et **le tronc écrit dans le terrain** ; reste la pose des filons, qui appartient à 2.6 |
| 1.12 | **Les six biomes** | climat de 1.3 + biomes de l'alpha 2013 | ✅ | couche `CWBiome` au-dessus des matières, Lava Lands et ses coulées, **42 modèles de flore et 24 d'arbres regénérés** (la flore a été refaite le soir même : 38 modèles, à 4 voxels par bloc et 6 pour les petits props) |
| 1.13 | **La falaise** | `terrain_surfaceColor_blend` @005c56e0, 5ᵉ branche | ✅ | portée puis **retirée** le 2026-09-06, **rétablie le 2026-09-07** une fois le relief taillé par 1.15, et cette fois **tramée** : 2,6 % des terres |
| 1.15 | **Massifs, grottes, falaise** | — (création de ce projet) | ✅ | masses **allongées, déformées et à gradins**, cœur de roche et frange enherbée, galeries brisées à bouche évasée sous leur porche ; **1,5 % des terres sous un massif** |
| 1.16 | **Chemins et levées** | — (création de ce projet) | ✅ | arbre couvrant par zone, portes de frontière partagées, tracé relaxé, chaussée **creusée sur toute sa largeur**, tunnels proportionnels à la masse, et une **levée** qui comble la rivière au lieu de l'enjamber |
| 1.14 | **Les lacs** | `WorldInfo_generateBiomeContent` @005e4850, seconde passe | ✅ | porte = chenaux à 0,02 ; niveau quantifié au pas de 5, rampe triangulaire, berges creusées. **1,90 % des terres en eau, 1,35 % en rive**, profondeur 1 à 4 blocs ; coût sous le bruit de mesure |

### 1.6 — Éléments de tuile (fait)

Grille 8 × 8 d'éléments par zone, un par tuile de 2048 unités. Cinq types
déforment l'altitude — bourg (aplanissement + `World_roadField`), cratère à
`H−50`, deux caldeiras à bord relevé, piton de +150 — plus un relèvement qui
fait émerger un îlot sous tout élément posé sur un site océanique. Détail et
constantes dans `docs/systems/01`, §2.7.

Trois points relevés à l'analyse, qui n'étaient pas dans le plan :

- **Le type 1 n'est pas « les routes ».** Il y a un et un seul élément de type 1
  par zone, sur la tuile de son site : `World_roadField` est l'aplanissement du
  bourg, pas un réseau de voies. Les arêtes du graphe de sites ne sont donc pas
  des routes, et `site_edge_radius` reste à 0.
- **Les types 13 et 9 ne sont jamais produits** par
  `World_generateRegionFeatures` : son `switch(rand()%8)` ne rend que 2, 3,
  4/15, 5, 6/15, 7/15, 11 et 12. L'effet du 13 (piton de +150) est porté ; les
  deux types sont pourtant traités par `generateBiomeContent`, donc une passe de
  placement reste à trouver. Le 9 y construit un `cube::Spawn`.
- **Les types sans effet sur l'altitude sont quand même placés** (2, 3, 5, 10,
  11, 12, 14, 15). Le flux aléatoire est une seule séquence : n'en porter que la
  moitié changerait tous les types et toutes les positions. Ce sont les ancres
  du jalon 1.7.

`World_featureTier` @004d7870 est porté et gradue la difficulté depuis le centre
de la carte (zone 512, 512).

### 1.7 — Contenu de biome (fait)

**Fait.** La mécanique de dispersion et le rendu sont portés, testés et mesurés :
`CWVoxelModel` (un `.vox` en liste creuse, quatre quarts de tour précalculés,
ancre au centre de l'empreinte et à la base, maillage à l'échelle fine),
`CWModelLibrary` (chargement partagé, table modèle/biome, densités), `CWScatter`
(cellules de 16 blocs, une graine par cellule, position sous le bloc, cache sous
mutex) et `CWFloraRenderer` (un `MultiMesh` par modèle et par cellule, cellules
construites par lots sur un fil du pool, détruites au-delà de la distance de vue
de la flore). 33 vérifications dans `tests/flora_test.gd`. Coût : **1,1 ms par
cellule** de 256 colonnes en prairie, hors du fil principal — et **plus rien** sur
le chemin de génération du terrain.

**Les 28 modèles du lot de flore sont livrés et intégrés** (2026-09-05), en 39
fichiers rangés par biome : plusieurs rôles ont reçu un modèle par biome plutôt
qu'un fichier partagé, et `CWModelLibrary.FLORA` porte donc des chemins. 5 650
plantes se posent sur 576 cellules d'essai, toutes dans leur biome et sur leur
sol. Trois réparations ont été nécessaires avant que le lot arrive en jeu — la
palette des fichiers, deux plages de palette inutilisables, et les noms ; le
détail est dans `nextsteps.md`, §6.

> **Le piège de la palette, à ne pas redécouvrir.** Le rendu lit un *index*,
> jamais une couleur. Les 39 fichiers sont arrivés avec les bonnes teintes aux
> mauvais index, parce que la planche de référence avait été glissée sur le
> nuancier de MagicaVoxel, qui la rééchantillonne. Rien ne le signale : ni le
> chargement, ni les tests d'alors, seulement l'écran. Le geste correct est
> d'**ouvrir `assets/palette/zentarys_palette.vox`** ; `tools/repaint_models.gd`
> répare un lot déjà peint.

**L'échelle des assets est fixée** — c'était le point bloquant, elle n'est
déductible d'aucune décompilation.

> **Deux grilles.** Le terrain a un pas d'un bloc, les modèles un pas treize fois
> plus fin : **1 bloc = 40/3 voxels de modèle**, soit **3 blocs = 40 voxels** ;
> **personnage de référence = 32 voxels = 2,4 blocs**, touffe d'herbe à 0,9 bloc.
> Le rapport était de 16 jusqu'au 2026-09-05 ; il est passé à la valeur exacte de
> l'original, `0,075 = 3/40`. C'est ce rapport qui sépare
> ce rendu de celui de Minecraft, et il est mesuré au pixel sur une capture du
> jeu d'origine — le brin d'herbe et la pupille du personnage y font la même
> largeur, donc la flore et les personnages sont sur la même grille fine.

Conséquence d'architecture, prise le 2026-09-04 : **la flore n'est plus estampée
dans les données voxels du monde**, elle y serait treize fois trop grosse. Elle
est maillée à part — même mailleur, même palette, même matériau que le terrain,
ce qui est la condition pour que les deux grilles lisent comme un seul monde —
puis instanciée. Ce qu'on perd : la flore ne se creuse pas, ne porte pas de
collision, ne participera pas à l'éclairage voxel du jalon 1.9. Ce qu'on gagne :
elle quitte le chemin critique de génération, qui est le poste dominant du
chargement.

Méthode, mesures et gabarits dans `assets/models/MODELS.md`. À revoir au jalon
3.1, quand la physique du joueur donnera la taille réelle du personnage : c'est
alors le nombre de blocs qui bougera, pas le rapport de 16, qui est un contrat
d'authoring.

**Reste.** `WorldInfo_generateBiomeContent` (@005e4850, 4 200 lignes) a reçu une
première passe d'analyse le 2026-09-05 : **`docs/systems/02`**. Elle n'est pas ce
que son nom annonce — c'est le constructeur d'une cellule de 256 × 256 colonnes,
et **elle ne disperse pas de flore**. Ce qui en est sorti : le champ de densité
de végétation à quatre octaves (constantes exactes), l'identité de quatre types
d'éléments de tuile (6 = champ de rochers, 11 = massif isolé, 12 = plan d'eau,
3 = parcelle bâtie), les constantes de pose des points d'apparition pour le
jalon 2.6, et une corroboration indépendante du portage du jalon 1.6 (stride
`0x68`, base `+0x14018`, ordre `tz + tx·8`).

**La table modèle/biome est trouvée** (2026-09-05, seconde passe). Elle n'était
dans aucune des deux fonctions au nom prometteur : `generateVegetationCluster`
(@005d8750) est le *résolveur de contenu d'une tuile*, pas un disperseur. La
table est le `switch` d'apparence de `creature_generateAppearance`
(game_misc.cpp:3197), croisé avec les slots de chargement de `GameController`.

> **Flore, filons et créatures sont un seul espace de types d'entités.** Codes
> 120–130 = plantes, 131–139 = filons, 145–155 = poissons, en dessous les
> créatures. Une touffe d'herbe et un ours sont la même sorte d'objet : une
> entité portant un code, jamais de la matière écrite dans le terrain. **La
> décision du 2026-09-04 de sortir la flore des données voxels est donc confirmée
> par la source** — pour une raison qui n'avait pas été anticipée.

Les boîtes englobantes du `switch` sont en blocs de terrain et **recoupent
l'échelle fixée ici** : `thorn-tree` 12 blocs, `cactus1` 4 blocs, buisson 2 blocs
— soit le personnage de référence. La sélection se fait sur le **type de bloc de
surface**, pondérée par température et humidité, jamais sur un identifiant de
biome : c'est exactement la forme de `CWPalette.surface_index`. Tables complètes,
rareté des filons comprise, en `docs/systems/02`, §5.

**Ce qui bloque encore le portage :** la numérotation des blocs de l'original
n'est pas celle de `CWPalette`, et la correspondance reste à établir — recopier
la table telle quelle mettrait des cactus dans les marais.

**La seconde voie de pose est identifiée** (`docs/systems/02`, §8). Il y a bien
deux voies : les plantes à silhouette sont des **entités** (§5), la flore basse
est du **décor instancié** sans entité, produit dans la même passe que le
terrain, en fin de boucle de colonne, et poussé par
`ChunkBuffer_loadAndNotify` (@005c03f0). L'enregistrement est reconstruit :
type à +0, échelle à +32, lacet à +36, drapeaux à +56.

> **Le rapport d'échelle est confirmé par une constante du binaire.** Les
> échelles de décor valent 0,075 / 0,09 / 0,1 — et **0,075 = 1/13,333
> exactement**. La feuille de route avait obtenu ~13 voxels par bloc par une
> mesure au pixel sur une capture, et retenu 16 ; le binaire porte la même
> valeur, par un chemin entièrement différent. La mesure à l'œil était juste.
> Le projet est donc à 16 là où l'original est à 13,33 : nos modèles sont
> **20 % plus fins** à bloc égal. `VOXELS_PER_BLOCK = 16` reste délibéré — une
> puissance de deux vaut mieux qu'un rapport bâtard — mais l'écart est
> désormais chiffré.

**Les deux manques de `CWFloraRenderer` sont comblés** (2026-09-05) : la gigue
d'échelle de 1× à 2× par instance, et les deux fréquences de bruit. Ce que le
portage a appris, au-delà de ce qui était prévu :

- **la crête à 0,05 est le mécanisme de groupement**, et il n'y en a pas
  d'autre. La dette « semer par grappes » n'était pas du code à écrire : la
  crête passe 29,2 % de la surface en plaques de 19,1 blocs, ce qui donne des
  paquets serrés et de larges vides. Mesuré après portage : variance/moyenne de
  **14,3** par cellule contre ~1 pour un tirage uniforme, 195 cellules vides
  sur 576 ;
- **la rareté entière (`rand()%8 == 0`) n'est pas portée, délibérément.**
  L'original la tire par colonne, ce qui suppose 256 échantillonnages par
  cellule — ~19 ms, hors budget. `CWScatter` tire un budget de candidats et ne
  paie la colonne qu'après la crête. Même moyenne : 256 × 0,2917 × 1/8 = 9,3
  plantes par cellule, contre les 9,8 que donnait la densité posée au jugé.
  Deux chemins indépendants, le même nombre ;
- **le test de signe se généralise par la parité de l'indice**, pas en deux
  moitiés contiguës — sans quoi une région sort à 40 % de cailloux, la table
  groupant les modèles par nature. Le défaut s'est vu en jeu, pas dans un test.

Détail et mesures en `docs/systems/02`, §8.3 et §8.4. Coût : la cellule de flore
passe de 1,07 à 1,29 ms, toujours hors du fil principal.

**La table type de décor → modèle est trouvée, et portée** (2026-09-05,
sixième passe). Elle n'était pas dans une fonction : elle est dans le
**tableau des slots de chargement**. `GameController_load_game_assets` range
2 449 modèles `.cub` à des indices qui ne suivent pas l'ordre de chargement, et
le décor y occupe un bloc contigu ; la relation est `slot = 2418 + type`, tenue
par cinq recoupements indépendants pris dans trois fonctions — le roseau sur
sol humide, les deux nénuphars sur l'eau, les **huit enseignes** pour les huit
genres de bâtiment, le lierre et les rosiers de mur, l'art incan. Réserve
documentée : la même base ne tient pas sous le type 22, où les cinq couvre-sols
demandent une base décalée de cinq — les deux lectures s'accordent en revanche
sur la *nature* de chaque décor, et c'est elle qui est portée. `docs/systems/02`,
§8.5.

**Ce que le portage a changé** (`src/worldgen/cw_decor_rules.gd`) :

- **il y a deux crêtes de sélection à 0,01, pas une**, de décalages différents
  — `(9843, 8437)` pour la famille, `(34234, 234234)` pour la variante. Mesuré :
  leurs signes ne s'accordent que 50,8 % du temps, soit le hasard, donc la
  seconde dit bien quelque chose que la première ne dit pas. C'est **le**
  mécanisme de composition régionale, et il était deviné jusqu'ici : la parité
  d'indice de `CWScatter._choose` était une invention de ce projet, elle est
  retirée ;
- **le second seuil est biaisé** (`n2 <= 0,5` et non `<= 0`), ce qui garde la
  variante minoritaire à une fois sur quatre. Prairie sur 4 000 points après
  portage : couvert 43,5 %, fleur 41,0 %, caillou 8,4 %, sous-bois 7,0 % ;
- **les échelles disent la taille du rôle** : 0,075 est la référence — soit
  exactement `3/40`, le rapport de ce projet —, le roseau et le nénuphar sont à
  1,2×, le caillou à 1,33-1,6×, le sous-bois humide à 0,67-1,33× ;
- **une seule rareté est empilée sur la crête**, `rand()%100` pour le couple
  humide et froid. Les autres `%8` et `%10` sont le tirage par colonne déjà
  remplacé par le budget de candidats ; les réappliquer les compterait deux fois.

La table par biome de `CWModelLibrary` devient une table **par rôle** : les 39
modèles sont répartis en neuf rôles (couvert, fleur, caillou, sous-bois, rare,
roseau, algue, corail, fond), et deux vérifications tiennent la correspondance —
aucun rôle atteignable sans modèle, aucun modèle rangé sous un rôle
inatteignable. 271 vérifications au total à cette date.

**Ce qui reste ouvert**, et ce n'est plus bloquant : le nénuphar (pas de modèle
dans le lot, et `surface_index` ne rend jamais `WATER`), le lacet libre de trois
rôles (le mailleur ne précalcule que quatre quarts de tour), et la crête de
placement à 0,6 que la source emploie sur le sol végétalisé là où ce projet en
garde une seule à 0,5 — c'est un réglage de taille de plaque, et
`PLACEMENT_PASS_RATE` est calibré sur 0,5.

![La composition d'une prairie, en jeu](images/flore_composition.png)

**Correction de sources.** Douze noms du dépôt d'analyse sont trompeurs —
quatre sont venus avec la carte, détaillés en `docs/systems/05`, §8, et le
douzième avec les lacs, détaillé en `docs/systems/02`, §10 :

- `World_generateWaterOrPathFeature` (@005df960) **ne fait ni eau ni chemin** :
  elle bâtit un grand objet de végétation, en sept variétés. Elle peint des
  sphères de bois (type 7) et des masses de feuillage (type 8) par
  `World_generateFoliageBlob`, pose huit structures en quatre rotations, et sa
  variété 1 est une **spirale** de trente disques. Aucune de ses branches
  n'écrit le type 2. C'est le nom qui a fait croire que l'élément de tuile 12
  était un plan d'eau : la correction est en `docs/systems/02`, §4 et §10.

- `WorldInfo_scatterObjectsInArea` (@005f56c0), listée ici comme seconde source
  de 1.7, **ne disperse pas d'objets** : elle choisit la liste d'espèces d'un
  point d'apparition selon le climat et le niveau, et son résultat est écrit
  dans un `cube::Spawn`. C'est du jalon 2.6.
- `World_generateTreeRecursive` (@005d9460) **ne génère pas d'arbres** : son
  corps est de la gestion de cellules de région et de `cube::Spawn`. Le corpus
  n'emploie « tree » que pour les arbres rouge-noir de la STL. Appelée en fin de
  `generateBiomeContent`, c'est une finalisation de cellule.
- `WorldInfo_generateBiomeContent` (@005e4850) **n'est pas le contenu de biome**
  mais le constructeur d'une cellule de 256 × 256 colonnes. `docs/systems/02`.
- `terrain_generateColumnColor` **ne rend pas une couleur** mais une hauteur de
  colonne : sa valeur sert de base d'altitude et devient une coordonnée Y.
- `World_placeObjectWithSpacing` **ne place rien** : elle rend un poids scalaire
  par colonne, facteur du champ de densité de végétation.
- `World_generateVegetationCluster` (@005d8750) **ne disperse pas de
  végétation** : c'est le résolveur de contenu d'une tuile. `docs/systems/02`, §7.
- `creature_generateAppearance` (`game_misc.cpp:3197`) **n'est pas propre aux
  créatures** : son `switch` couvre aussi les plantes, les filons et les
  poissons. C'est la table code d'entité → modèle. `docs/systems/02`, §5.
- `hash_or_index_compute` (@00602440) **ne calcule pas de hachage** : c'est
  `WorldMap::getTile`, l'indexation de la grille de cases de carte.
- `GameController_tryLockAndProcess` (@005fc160) **n'est pas un enrobage de
  verrou** : c'est `WorldMap::markDiscovered`, le seul point d'écriture de la
  découverte.
- `locked_pair_update` (@00601cc0) **ne met rien à jour** : c'est la recherche du
  site de région le plus proche, déjà portée en `CWTerrainField.nearest_site`.
- `Terrain_sampleHeightNoise` (@0059fc90) **n'échantillonne pas une altitude** :
  c'est la déformation du domaine à ±500, rendue en unités de zone.

### Assets à produire

Le jalon 1.6 n'a demandé aucun asset. Le jalon 1.7 est le premier qui en demande.

Le binaire d'origine charge **2 550 modèles voxels nommés** (`.cub`) ; leurs noms
donnent la liste sûre des *rôles* que le monde doit remplir. Le chiffre de 154
retenu jusqu'ici était une énumération partielle — relevé corrigé le 2026-09-05,
`docs/systems/02`, §6.2. Aucun n'est repris — ce sont des créations
originales — mais la liste des besoins, elle, ne se devine plus.
Liste par biome, noms de fichiers et ordre de production dans `nextsteps.md`,
§8.2. En résumé :

- **28 modèles pour le jalon 1.7** ✅ **faits** (39 fichiers, un dossier par
  biome), repartis sur les neuf surfaces que `CWPalette.surface_index` sait
  produire ; plus 5 cultures pour les champs, à faire ;
- **14 arbres et houppiers, plus 9 filons, pour le jalon 1.11** ✅ **faits**
  (2026-09-05) — même chemin de production que la flore : un document de
  commande, un script Blender, une graine en dur par fichier. Les filons sont le
  premier lot à **1 voxel = 1 bloc**, parce qu'ils s'estampent dans le terrain et
  doivent se miner ;
- **~50 pour le jalon 4** : mobilier, artisanat, décor extérieur et de donjon ;
- le reste (objets d'inventaire, créatures, interface) vient plus tard.

**Les arbres sont des assets — correction du 2026-09-05, complétée le même
jour.** La feuille de route affirmait le contraire. Le corpus charge nommément
`fir-tree.cub`, `thorn-tree.cub`, `christmas-tree.cub`, `tree-leaves.cub`,
`palm-leaf.cub`, `palm-leaf-diagonal.cub` et `wood-log.cub`. Il n'y a **pas** de
générateur d'arbre récursif à porter : `World_generateTreeRecursive` (@005d9460)
est nommée d'après les arbres rouge-noir de la STL, elle finalise une cellule.
La composition est **tranchée** depuis : `tree-leaves` porte son propre code
d'entité (143), loin des deux arbres (129, 130), donc le conifère et l'arbre à
épines sont des modèles entiers tandis que le feuillu et le palmier sont des
assemblages dont le tronc n'est pas un modèle. `docs/systems/02`, §5.2 ; travaux
en §1.11.

**Les maisons, elles, ne sont pas des assets.** `cube::House::ctor_0(3, 3, 4)`
montre qu'une maison est une grille de 3 × 3 × 4 cellules remplie
procéduralement — ce sont les meubles qui sont des modèles, pas le bâtiment. Un
algorithme à porter, pas un lot à dessiner.

Gabarits mesurés en sortie du générateur d'éléments, utiles pour situer les
échelles — le rayon est un rayon d'*influence*, la distance sur laquelle
l'élément revendique le terrain, pas l'encombrement du modèle :

| type | par zone | rayon | position | variantes |
|---|---|---|---|---|
| 14 | ~16 | 150 u | calée sur la grille de 256 | 4, plus 2 réservées aux climats très humides |
| 11 | ~2 | 128 u | calée sur la grille de 256 | — |
| 12 | ~2 | 128 u | calée sur la grille de 256 | — |
| 10 | ≤ 5 | 512–767 u | libre dans la tuile | — |
| 2 | ~2 | 512–767 u | libre dans la tuile | — |
| 3 | ~2 | 512–767 u | libre dans la tuile | 3 |
| 5 | ~2 | 256–511 u | libre dans la tuile | 3, choisies par le climat du site |
| 15 | variable | 512–767 u | libre dans la tuile | remplace 4, 6 et 7 au-dessus d'un site océanique |

L'identité de chaque type reste à établir : elle vient de
`WorldInfo_generateBiomeContent` (@005e4850), pas encore analysée.

Authoring : MagicaVoxel, palette de projet chargée en **ouvrant
`assets/palette/zentarys_palette.vox`** — et pas en glissant un PNG sur le
nuancier, qui décale les index sans rien dire. Plages réservées documentées dans
`assets/palette/PALETTE.md`. À l'import, `vox(x, y, z) -> godot(y, z, x)`.
**Échelle et conventions de fichiers : `assets/models/MODELS.md`** — c'est le
document à donner à qui modélise.

Pas d'éditeur voxel maison : la seule objection sérieuse était l'impossibilité de
descendre sous le voxel dans MagicaVoxel, et elle tombe avec le rapport de 16 —
sa grille est sans unité, on ne réduit pas le pinceau, on agrandit la boîte.
L'établi de personnalisation façon Cube World reste au programme comme
*fonctionnalité de jeu* (jalon 3.2/4, sur l'inventaire), pas comme outil de
production ; il réutilisera `CWVoxelModel` tel quel.

---

### 1.8 — Colonnes persistantes et édition (fait)

Analyse complète en **`docs/systems/03`**. Sept fonctions courtes et sans
ambiguïté — le système le mieux déterminé rencontré jusqu'ici.

**L'échelle du monde est confirmée par un second chemin.**
`Chunk_getColumnAt` refuse toute coordonnée hors de `[0, 0x1000000)`, soit
exactement `CWWorldParams.WORLD_SIZE`, obtenu jusqu'ici en multipliant 1024 zones
par 16 384 unités. Deux lectures indépendantes, le même nombre. `Grid_lookup1024`
borne à `0..0x3ff` — c'est la grille de zones — et `Region_getChunkCell` à
`0..0xffff`, soit 16 777 216 / 256. Trois recoupements.

**Un échelon manquait à l'échelle du monde :** le **chunk de 256 × 256
colonnes**, entre la tuile de 2 048 et le bloc — huit par huit dans une tuile.
C'est la cellule que construit `WorldInfo_generateBiomeContent` : les deux
analyses, menées séparément, décrivaient le même objet sans qu'on sache où le
ranger.

**La structure d'origine n'est pas portée, délibérément.** Grille de chunks,
colonnes paginées, plages redimensionnables : c'est exactement ce que
`VoxelTerrain` fait déjà, en natif. La réécrire serait porter une
implémentation. Ce qui est porté, ce sont les règles qu'aucun moteur ne devine.

> **L'eau n'est pas de la matière, c'est le vide sous le niveau de la mer.**
> `World_getBlockAt` ne lit jamais un bloc d'eau : au-dessus de la colonne il
> rend un témoin d'eau si `z <= 0` et un témoin d'air sinon, et il rabat de même
> un bloc *stocké* de type nul sous la même altitude. Le niveau de la mer de
> l'original est `z = 0` — `CWWorldParams.sea_level` valait déjà 0. Creuser sous
> la mer laisse donc de l'eau, pas un trou : une tranchée depuis la plage se
> remplit. C'est `CWWorldEdits.erase_value`.

Deux relevés qui n'étaient pas cherchés :

- **un bloc d'origine fait quatre octets : trois de couleur RVB et un
  d'attributs** (type sur 5 bits, drapeau 0x40, protection 0x80).
  `World_fillVoxelColumnTyped` donne à chaque bloc sa teinte, avec une gigue de
  table et un canal vert poussé vers 120 par un échantillon de bruit. Ce projet
  est en palette indexée par choix de rendu — mais cela éclaire peut-être la
  **dalle d'eau du LOD 1** restée inexpliquée : une couleur survit à une moyenne
  de résolution, un index de palette non. Piste, pas démonstration ;
- **la protection (0x80) empêche la génération d'effacer un bloc posé par une
  structure** — écrire de l'air y est refusé en silence, écrire de la matière
  repose le drapeau. Pas de producteur avant le jalon 4, et pas de place dans un
  canal d'un octet : documentée, non portée.

**Persistance.** `VoxelStreamSQLite` avec `save_generator_output = false`, un
fichier par graine : le monde intact reste procédural, seul le diff part sur le
disque — le modèle de l'original, qui ne sérialise que les colonnes touchées.
647 éditions occupent 20 Ko, écrites en 4 ms.

**Une régression attrapée par la validation en jeu, pas par les tests :**
fermer par `--quit-after` ou par un `SceneTree.quit()` direct n'envoie pas
`WM_CLOSE_REQUEST`, donc la sauvegarde ne partait pas — 647 éditions appliquées,
zéro écrite, sans un mot. `NOTIFICATION_EXIT_TREE` est le second filet.

**Ce que 1.8 laisse ouvert :** la flore ne réagit pas aux éditions — creuser un
cratère y laisse les plantes en l'air. C'est la conséquence connue de la
décision du 2026-09-04, devenue visible ; la corriger demande une requête par
plante, donc c'est un sujet du jalon 1.9. Les collisions ne sont pas branchées
non plus : `CWWorldEdits.voxel_at` est la primitive, le consommateur est le
contrôleur du jalon 3.1.

---

### 1.9 — Éclairage voxel (fait)

**L'algorithme est entièrement établi**, `docs/systems/04`. Deux passes : une
descente du soleil par colonne, puis **seize itérations** de diffusion
**purement horizontale**, atténuation **multiplicative `× 0,85`** par bloc (et
non le `− 1` de Minecraft), avec un **plancher de 5/255** qui empêche tout recoin
de tomber au noir. Le type 13 est une **source de lumière** à 255. Le double
tampon explique la disposition d'octets relevée au jalon 1.8 : pour un voxel
transparent, les trois premiers octets ne sont pas une couleur mais
suivant / courant / publié.

Trois types de blocs sont nommés au passage — **0 air, 2 eau, 13 lampe**. Ce
sont les trois premiers points d'ancrage vers la correspondance de numérotation
qui bloque `docs/systems/02`, §9.

> **Sur un monde intact, l'éclairage ne change rien.** Le terrain porté est un
> champ de hauteurs pur : la passe A répond « éclairé au-dessus, noir en
> dessous », et le dessous n'est jamais visible. La lumière ne devient visible
> que dans ce que le joueur a creusé — c'est-à-dire ce que le jalon 1.8 vient
> d'ouvrir.

**Ce qui bloquait n'était pas le calcul, c'était le rendu — et la décision est
prise.** `VoxelMesherCubes` n'a pas de canal de lumière : en mode palette il cuit
la couleur du nuancier dans les sommets, et il n'y a nulle part où loger une
luminosité par voxel. Le rendu est donc **passé en `COLOR_RAW`** — une couleur
par voxel au lieu d'un index — ce qui est **exactement ce que fait l'original**.
Un voxel porte maintenant deux choses : son **type** dans `CHANNEL_TYPE`, qui
reste ce que lit tout le code raisonnant en blocs, et sa **couleur** dans
`CHANNEL_COLOR`, que seul le mailleur lit. La palette reste la source des
couleurs et le contrat d'authoring : **les 39 modèles de flore n'ont pas été
repeints.**

**`CWLight` porte les deux passes**, et le terrain généré ne l'appelle pas : un
champ de hauteurs est éclairé partout où on le voit, donc la lumière ne sert que
là où le joueur a creusé. Deux choix d'implémentation ont porté tout le gain :

- les deux passes sont indexées dans **l'ordre natif de `VoxelBuffer`** (Y
  d'abord), ce qui permet de leur passer le canal de types tel quel — trente-six
  mille `get_voxel` de moins par coup de pioche ;
- `shaded_cells` **pousse la lumière depuis l'air vers ses voisins pleins** au
  lieu de sonder chaque bloc, si bien que la roche enterrée ne coûte rien.

Un coup de pioche isolé passe ainsi de 71 à **30 ms**, à profil de lumière
inchangé.

**Fait dans ce jalon :** la flore suit désormais le terrain édité. Creuser sous
une touffe la laissait en l'air — conséquence connue de la sortie de la flore
des données voxels (2026-09-04), devenue visible avec 1.8. `CWWorldEdits` tient
le sommet plein des colonnes éditées, calculé sur le fil principal au moment de
l'édition, et `CWScatter` y consulte un dictionnaire — rien sur le chemin chaud,
et pas de `VoxelTool` lu depuis un fil du pool.

> **Un piège de repère, et un test qui passait au vert pour rien.**
> `CWWorldEdits` travaille en coordonnées de scène, comme `VoxelTool` ;
> `CWScatter` en coordonnées monde. La première version rangeait la table dans
> le mauvais repère : la recherche ne tombait jamais juste et la flore
> continuait de flotter, **sans qu'aucune vérification ne bronche** — les deux
> côtés du test employaient le même repère. C'est la capture en jeu qui l'a
> montré. Le test traverse maintenant la conversion.

---

### 1.10 — Carte du monde (fait)

Analyse complète en **`docs/systems/05`**. Onze fonctions, dont quatre dont le
nom du dépôt d'analyse dit autre chose que ce qu'elles font.

**Une pièce de carte est une cellule de Voronoï.** C'est le résultat qui n'était
pas prévisible depuis l'apparence du jeu : `loadLandscapeTile` (@006024d0) balaie
la zone plus une zone de marge, déforme chaque point de la grille de chunks et ne
garde que ceux dont le **site de région le plus proche** est celui de la zone.
La carte n'est donc pas un quadrillage : c'est un puzzle aux frontières
ondulées — et ces frontières sont **exactement celles du climat**, puisque le
mélange de sites du jalon 1.3 travaille sur le même point déformé.

Conséquence pratique : **le jalon 1.10 n'apporte aucune constante numérique
nouvelle.** `World_getColumnDataAt2` est mot pour mot `CWTerrainField.warped_point`,
et la recherche du plus proche site est `nearest_site`, portée au jalon 1.6. La
carte assemble ce que le terrain avait déjà.

**L'échelle du monde est confirmée une troisième fois.** `WorldMap::getTile`
(@00602440, nommée `hash_or_index_compute` dans le dépôt) borne ses coordonnées à
`[0, 0x10000)` et indexe en deux temps, `>> 6` puis `& 63` : une case de carte
vaut **256 unités**, c'est-à-dire le chunk retrouvé au jalon 1.8, et il y en a
64 × 64 par zone.

**L'image stockée ne porte pas de couleur.** Le remplissage n'écrit que trois
valeurs, et elles sont grises : `200` là où aucune case n'existe, `220` pour une
case connue, `255` pour une case découverte. La teinte vient du dessin. Le
portage garde cette séparation — la clarté est une propriété du chunk, la teinte
une propriété de la région, et elles ne se rencontrent qu'au rendu.

**La découverte** tient en une fonction de dix lignes (`WorldMap::markDiscovered`,
@005fc160) : un bit par chunk, et un compteur — le seul état que l'original
persiste, en quatre octets sous la clé `discovered`.

**Les marqueurs sont les éléments de tuile du jalon 1.6**, relevés une troisième
fois par le couple stride `0x68` / base `+0x14018`. Rien de neuf à générer : la
couche existait, il fallait savoir qu'elle alimentait la carte.

**Les noms de région** sont deux syllabes tirées de deux tables de vingt,
indexées en croix par le point déformé ramené en unités de zone :
`tableA[(a*3 + graineA + b) % 20] + tableB[(b*3 + graineB + a) % 20]`. Le
mécanisme est porté à la lettre ; **les syllabes, elles, ne le sont pas** — ce
sont des créations artistiques du jeu d'origine, et `CWRegionName` porte deux
tables écrites pour ce projet.

> **Septième nom trompeur.** `Terrain_sampleHeightNoise` (@0059fc90)
> n'échantillonne pas une altitude : c'est la déformation du domaine à ±500,
> rendue en unités de zone. C'est `CWTerrainField.edge_warped_point`, portée au
> jalon 1.4. Trois autres noms sont corrigés en `docs/systems/05`, §8.

**Porté :** `CWWorldMap` (dalles, découverte, teintes, marqueurs, rendu),
`CWRegionName`, l'affichage `CWMapOverlay` (touche **M**, `+`/`−` pour élargir),
la persistance de la découverte par graine, et `tools/preview_map.gd` pour
regarder une carte sans lancer le jeu. 56 vérifications dans `tests/map_test.gd`.

**Trois écarts délibérés**, pesés en `docs/systems/05`, §7 : une dalle de 64 × 64
par zone plutôt qu'une pièce à sa boîte englobante (même géométrie, cache qui se
juxtapose sans recouvrement) ; une teinte de région échantillonnée à son site ;
la mer peinte en eau, parce que `surface_index` rend du sable sous le niveau de
la mer — juste pour le terrain, illisible sur une carte.

**Coût :** une dalle de 4 096 cases en **43 ms**, une vue de 5 × 5 zones en
1,4 s à froid, sur un fil du pool ; se recentrer ne recalcule que les zones qui
entrent dans le cadre. Un nom coûte 14 µs.

> **Un défaut de dessin que seul le jeu a montré.** Poser les seules ancres d'un
> `Control` sous un `CanvasLayer` le laisse de taille nulle : tout le dessin
> partait d'une origine négative et la carte sortait par le coin supérieur
> gauche. Aucune vérification ne pouvait broncher — un nœud invisible calcule
> juste. Ce sont les ancres **et les marges** qu'il faut poser.

**Ce que 1.10 laisse ouvert :** les six modèles de marqueurs
(`map-tile-{plains,village,forest,mountains,hills}.cub`, `skull.cub`) sont des
assets à produire ; l'affichage dessine des glyphes en attendant. Le type 14
reste sans identité — la carte l'a montré autrement : le compter comme village
en met dix-huit par région.

---

### 1.11 — Arbres et grande végétation (fait)

Le jalon 1.7 a porté la **flore basse** : ce qui pousse au sol, treize fois plus
fin qu'un bloc, instancié sans entité. Il ne couvre pas **ce qui a une
silhouette** — arbres, grands buissons, cactus dressés, filons affleurants —, qui
passe dans l'original par une voie entièrement différente, celle des entités
(`docs/systems/02`, §5). C'est le seul contenu du monde qui manque encore, et il
change beaucoup l'aspect d'un biome.

**Ce que la source donne, et c'est presque tout.** Le code d'entité indexe le
tableau de chargement à une base près : **`slot = 1969 + code`**, tenu par treize
valeurs consécutives (`docs/systems/02`, §5.2). D'où, sans ambiguïté :

| code | modèle | ce que c'est |
|---|---|---|
| 129 | `fir-tree` | un conifère, **modèle entier** |
| 130 | `thorn-tree` | un arbre à épines, **modèle entier**, boîte 3 × 3 × **12 blocs** |
| 143 | `tree-leaves` | un **houppier**, posé séparément |
| 131-139 | les neuf filons | affleurements minéraux, rareté en `docs/systems/02` §5.4 |

**Le feuillu n'est pas un modèle.** `tree-leaves` porte son propre code, loin des
deux arbres, et le corpus ne contient ni `tree-trunk`, ni `oak`, ni équivalent :
un feuillu est donc un **assemblage**, un tronc surmonté de houppiers instanciés.
Le tronc n'étant pas un modèle non plus, il est très probablement écrit dans le
terrain en colonnes de blocs — l'original en a la primitive,
`World_fillVoxelColumnTyped` (@005df600). Le palmier suit la même construction :
`palm-leaf` et `palm-leaf-diagonal` sont deux palmes, il n'y a pas de palmier.
Ce qui reste à trouver est **l'assembleur** — la fonction qui pose un tronc puis
ses houppiers —, sans doute inlinée dans `generateBiomeContent`.

> **Correction d'une affirmation ancienne.** `assets/models/MODELS.md` §4 et une
> version antérieure de cette feuille disaient « les arbres sont construits par
> le code, pas des modèles à dessiner ». C'est faux pour le conifère et l'arbre
> à épines, qui sont des `.cub` nommés, et à moitié vrai pour le feuillu, dont
> seul le tronc est procédural. Les deux textes sont corrigés.

**Trois choses à faire, dans cet ordre.**

**1 — Le lot d'assets, par le même chemin que la flore. ✅ Fait le 2026-09-05.**
Le lot des 39 modèles de flore est produit par script —
`tools/blender/generer_flore.py`, une graine en dur par fichier, le lot se
régénère à l'identique —, et le document qui a servi à le commander est
`docs/prompt_generation_flore.md`. Le lot d'arbres a suivi exactement ce chemin :
`docs/prompt_generation_arbres.md` pour la commande,
`tools/blender/generer_arbres.py` + `arbres_formes.py` pour la production, les
mêmes garde-fous — palette de projet recopiée verbatim, index hors plages
refusés à l'écriture, enveloppe vérifiée. **14 modèles livrés** sous
`assets/models/arbres/<biome>/` :

| surface | modèles |
|---|---|
| herbe | `tronc_feuillu`, `houppier_01`, `houppier_02` |
| herbe sèche | `arbre_sec`, `houppier_sec` |
| jungle | `tronc_palmier`, `palme`, `palme_diagonale`, `houppier_jungle` |
| marais | `arbre_mort` |
| sable | `palmier_dattier` (réemploie `palme`) |
| neige | `sapin`, `sapin_enneige` |
| toundra | `sapin_rabougri` |

Mesures réelles : les trois futs font 88 à 105 voxels de haut (6,6 à 7,9 blocs)
pour moins d'un bloc de rayon ; les quatre houppiers 47 à 53 de haut pour 28 à
32 de rayon (2,4 blocs) ; le `sapin` 111 pour 14 de rayon. Le rayon maximum du
lot est de 32 voxels, soit 3 blocs.

> ⚠️ **Ce lot est à refaire — l'échelle et le grain sont faux.** Constaté le
> 2026-09-05 au soir sur trois captures du jeu d'origine. Les arbres y sont
> **six à dix fois le personnage** (15 – 25 blocs, contre 8,3 pour notre
> `sapin`), leurs houppiers sont des **dômes en parasol de 10 à 18 blocs de
> large, plus larges que hauts** (contre 4,8 blocs, aussi hauts que larges), et
> surtout leurs cubes de feuillage lisent **à la taille du bloc de terrain** —
> un arbre y est bâti des mêmes cubes que le monde, pas de ceux de la flore.
>
> Deux raisons de le croire au-delà de l'œil. D'abord la **provenance de
> l'échelle** : `0,075 = 3/40` est relevée dans la voie du *décor* (§8.3), et
> aucune échelle n'a été relevée dans la voie des *entités*, par où passent les
> arbres — ce lot reposait donc sur une extrapolation. Ensuite l'**argument
> structurel** : §5.2 établit que le tronc est écrit dans le terrain en colonnes
> de blocs et que le houppier est instancié séparément ; ces deux moitiés ne se
> rejoignent proprement que si la grille du houppier est celle du bloc. Un voxel
> = un bloc explique l'architecture de la source, 3/40 la rend impossible.
>
> **La couche de dispersion et le montage restent valables** ; ce sont le grain
> et les tailles qui changent. Chiffres cibles, effets de bord et ordre des
> travaux : `nextsteps.md`, §6.

**Deux points d'ancrage relevés à la production, qui concernent l'assemblage :**

- **l'ancre d'un modèle est le centre de son gabarit**, pas le pied du tronc
  (`CWVoxelModel.load_from`). Les futs sont donc dessinés presque d'aplomb —
  au-delà, l'arbre se poserait à côté de son propre tronc. Pour les palmes, dont
  le point d'attache est à une extrémité, l'écart est structurel : l'assembleur
  devra porter un décalage d'attache explicite, il ne peut pas le déduire du
  modèle ;
- **le tronc existe en deux formes** et ce n'est pas une contradiction :
  `tronc_feuillu` et `tronc_palmier` sont des modèles instanciables, là où la
  source écrit le tronc en colonnes de blocs. L'assemblage écrira la matière là
  où il faut qu'on la creuse et qu'elle porte collision ; le modèle sert au
  bosquet lointain et à la réduction de niveau de détail.

Plus les **neuf filons** (code 131-139), qui sont un lot à part : ceux-là se
dessinent à **1 voxel = 1 bloc** et s'estampent dans le terrain, puisqu'on doit
pouvoir les miner. C'est le premier lot de ce genre du projet, et
`assets/models/MODELS.md` §3 en donne déjà la règle. **Dessinés le 2026-09-05**,
sous `assets/models/filons/`, une fois la décision de palette prise :

> **La décision.** Les filons demandaient neuf **types de bloc** et la réserve
> terrain 14 – 31 était pleine. Des trois issues posées par
> `docs/prompt_generation_arbres.md`, aucune n'a été prise telle quelle. La plage
> équipement (96 – 127) aurait fait porter à un bloc minable un index déclaré
> « armes et équipement », c'est-à-dire organisé la panne que le découpage
> existe pour éviter. Réemployer des entrées existantes est impossible depuis
> 1.9. Restait la troisième — déplacer une frontière —, dont le prix annoncé
> était « invalide tous les modèles déjà peints » ; il ne l'était que si on les
> déplace **toutes**.
>
> `RANGE_TERRAIN_END` passe donc de 31 à 40 et `RANGE_CREATURES_BEGIN` de 32 à
> 41, **et rien d'autre**. Aucun modèle n'est à repeindre, vérifié plutôt que
> supposé : les 53 modèles du dépôt n'emploient que 14 – 29 et 128 – 175. La
> plage créatures perd neuf entrées sur 64 et n'en a **aucune de peinte**,
> l'apparence des créatures étant hors périmètre — c'est ce qui rend l'opération
> gratuite, et c'est pour cela qu'elle est possible aujourd'hui et ne le sera
> plus au jalon 2. Les neuf index sont consécutifs et alignés sur les codes
> d'entité : `index = 32 + (code − 131)`, verrouillé par un test, comme la table
> de rareté de §5.4 (fer 70 %, or 10 %, argent 10 %, émeraude 9,1 %, saphir
> 0,5 %, rubis 0,3 %, diamant 0,1 % — portée verbatim dans `CWPalette.roll_ore`).

**Ce qui reste des filons** est leur *pose* : où affleure un filon, selon quelle
roche et quelle profondeur. Elle appartient à la voie des entités, avec les
points d'apparition du jalon 2.6 — c'est là que le tirage de rareté trouvera son
appelant.

**2 — Une seconde couche de dispersion, et non un élargissement de la première.
✅ Faite le 2026-09-05.** `CWScatter` calcule sa marge sur
`CWModelLibrary.max_radius_blocks`, tous modèles confondus (invariant n° 17).
Ranger un houppier dans la même bibliothèque ferait passer cette marge de 2 blocs
à 9 pour **toute** la flore : `placements_in` balaierait une couronne de cellules
cinq fois plus large, et chaque `MultiMesh` d'herbe porterait une boîte de
visibilité démesurée. D'où une couche jumelle, `CWTreeScatter`, qui **hérite** de
`CWScatter` — cache de cellules, verrou, reprise après édition et requête
d'empreinte sont identiques — et redéfinit ce qui diffère :

- **cellule de 64 blocs** (16 << 2, donc une cellule d'arbres couvre exactement
  seize cellules de flore : la conversion des cellules salies par une édition est
  un décalage, sans perte) ;
- **bibliothèque à part**, `CWModelLibrary.shared_trees()`. Mesuré : rayon
  maximum 2 blocs pour la flore, 3 pour les arbres. Deux maxima, deux marges ;
- **espacement minimum réel entre deux troncs**, 7 blocs. Le mécanisme est celui
  de la source (comparaison sur le carré de la distance, §6) ; la valeur ne l'est
  pas, et il faut le dire — les 20 unités de §6 appartiennent à la boucle des
  points d'apparition, qui place des `cube::Spawn`, et à 20 blocs d'écart aucune
  forêt ne serait possible. La règle est **sans état et sans récursion** : chaque
  cellule tire ses candidats de sa seule graine, et un candidat est écarté si un
  candidat de **rang absolu inférieur** du voisinage 3 × 3 est trop proche. Comme
  l'espacement est inférieur à la cellule, la décision est la même quelle que
  soit la cellule qui la pose. Vérifié par un test, frontières comprises ;
- **crête de placement à 0,02** au lieu de 0,05. Même forme, même seuil, mêmes
  décalages ; seule la fréquence change, et c'est ce qui **répond à la question
  laissée ouverte ci-dessous** : les arbres se décident sur leur propre champ. À
  0,05 les plaques font 19 blocs — la taille d'une touffe, pas d'un peuplement —
  et partager la crête de la flore aurait mis chaque arbre dans une plaque
  d'herbe, deux couches corrélées à cent pour cent se lisant comme une seule.

**Le montage est fait au niveau de l'instance**, pas encore de la matière :
`CWTreeRules` tient les espèces et leurs trois montages — arbre entier, feuillu
(un tronc puis un à trois houppiers empilés en se chevauchant), palmier (un stipe
puis une couronne de palmes). Toutes les pièces d'un arbre partagent leur
colonne, leur altitude et leur échelle ; les houppiers se posent à une hauteur
**fractionnaire** (`Placement.fy`, ajouté pour eux), la hauteur d'un tronc étant
un nombre de voxels divisé par 40/3 qui ne tombe pas sur un bloc.

**3 — L'assemblage. ✅ Fait le 2026-09-06.** Un feuillu se pose en deux temps :
un tronc **écrit dans les données voxels** — donc il se creuse, il portera la
collision et l'éclairage voxel le voit — puis un à trois houppiers instanciés
au-dessus. C'est le premier objet du projet qui traverse les deux mondes.

L'écriture est faite par le **générateur** (`CWVoxelGenerator._stamp_trunks`) et
non par la couche d'édition : un tronc est du monde procédural, pas une
modification du joueur, et le passer par `CWWorldEdits` mettrait chaque arbre du
monde sur le disque. C'est aussi ce que fait la source
(`World_fillVoxelColumnTyped`). Deux décisions prises pour d'autres raisons se
paient ici : le lot d'arbres est **à un voxel par bloc** depuis 1.12 — sans quoi
il n'y aurait aucune correspondance entre les voxels du modèle et ceux du monde —
et **`CHANNEL_TYPE` et `CHANNEL_COLOR` sont séparés** depuis 1.9, ce qui permet
au tronc de porter le type `WOOD` et **la teinte de son propre modèle**. Sans ce
partage, il aurait fallu un type de bloc par nuance d'écorce.

> **Une matière ne se met pas à l'échelle : elle se rééchantillonne.** La gigue
> d'instance va de 0,85 à 1,25, et un tronc estampé ne peut pas être « 1,17 fois
> plus grand » — ses voxels sont des blocs. Il fait donc `round(hauteur × échelle)`
> blocs, niveaux copiés au plus proche voisin, et c'est cette hauteur entière qui
> dit où s'accroche le premier houppier. Un arbre reste **un tirage et une
> liste** : `Placement.matiere` marque la pièce que le générateur estampe et que
> le rendu ignore (invariant n° 35).

**Les espèces de montage ENTIER ne sont pas estampées** — le pin, le sapin, le
cactus géant, le rocher géant, l'arbre à épines : leur feuillage est dans le même
fichier que leur fût, et l'écrire donnerait du feuillage qu'on ne traverse plus.
La source les pose en entités. Leur collision est un sujet du jalon 3.1, et ce
sera un volume approché.

**Ce que la validation en jeu a attrapé, et qui datait du jalon 1.7 :** le
terrain charge une **boîte** de blocs, la végétation garnissait un **disque**.
Les quatre coins de la boîte portaient donc du terrain sans porter de cellules —
invisible tant que l'arbre entier était instancié, un **fût nu** dès que le tronc
est devenu de la matière. Les deux couches suivent maintenant la même forme
(invariant n° 36). Coût mesuré de l'étampage : **+2 %**, soit 17,9 et 18,1 s
sans contre 18,4 s avec, à 384 blocs de vue.

**Dix grands arbres, ajoutés le 2026-09-06.** Deux par biome arboré, un
quatrième montage (`Montage.GRAND`), vingt modèles. Un fût, **quatre branches
dessinées dans le modèle de tronc**, et un houppier au bout de chacune plus un à
la cime : ce qui distingue un grand arbre d'un feuillu est qu'on **compte ses
masses**, là où le feuillu empile les siennes sur son axe. Les branches sont
estampées avec le fût, d'où `MARGE_TRONC` porté de 4 à 11 blocs.

Ils apportent au lot ce qui lui manquait le plus : **la couleur**. Douze des
vingt-quatre modèles précédents puisaient dans la seule rampe de feuillage, et
une forêt de Greenlands n'avait qu'une teinte. Les nouveaux prennent l'automne,
les quatre couples de fleurs, la rampe des mousses, la roche nue et le basalte —
**aucune entrée nouvelle dans la palette** : érable doré, cerisier rose, saule
givré, arbre pourpre, acacia, baobab, flamboyant, jacaranda, arbre de cendre,
arbre de braise. L'invariant n° 29 tient : les deux espèces de Snowlands
prennent le blanc-bleu et le violet, jamais l'orange d'automne.

> **Ils sont dix à la production et huit le soir même.** Snowlands a rendu les
> siens — le saule givré et l'arbre pourpre —, et la raison n'est pas leur
> exécution mais leur montage : un `GRAND` tient sa lecture de l'étalement de ses
> cinq masses, c'est une silhouette d'été, et une taïga se lit à l'inverse par
> des flèches étroites. Les peindre en froid n'y changeait rien. Le biome garde
> ses deux conifères entiers et son bouleau. Voir `nextsteps.md`, §7ter.2.

**Le lot entier est corrigé et agrandi le même jour**, sur deux défauts vus en
regardant le paysage :

- **il manquait la moitié basse de tous les dômes.** Le profil de `houppier`
  partait de sa largeur maximale *à la base* et ne faisait que rétrécir : un
  parasol, pas une sphère aplatie. Le défaut a traversé le jalon 1.12 parce que
  la note d'origine disait « dôme en parasol », ce qui décrivait fidèlement une
  capture **vue d'en haut** — d'en haut, une sphère aplatie et un parasol ont la
  même silhouette. Ils ne l'ont plus dès qu'on est dessous. Le profil est
  désormais un ellipsoïde tronqué, maximum à 42 % de la hauteur ;
- **les arbres étaient trop petits** contre ceux de l'original. Tout le lot est
  **agrandi de 40 %** — le chêne à 32 blocs, l'arbre géant à 54 —, les plafonds
  suivent des deux côtés, l'espacement passe de 14 à 20 blocs et **les densités
  sont divisées par deux** : invariant n° 33, un arbre qui couvre deux fois plus
  de surface à densité constante ferme la forêt.

**Ce qui reste :**

- **la collision n'est pas branchée, et elle ne couvre pas tout.** Le terrain
  de la démo a `generate_collisions = false` : la matière est là, le corps qui
  s'y cogne n'existe pas encore. Surtout, tout n'est pas de la matière — le
  tronc **et son branchage** le sont (les branches sont dans le modèle de
  charpente, donc estampées avec le fût), les neuf filons le seront par
  construction, mais les **houppiers**, les cinq **modèles entiers** (`pin`,
  `sapin_enneige`, `pin_enneige`, `arbre_epineux`, `rocher_geant`) et les cactus
  de flore sont instanciés, donc traversables.
  Décompte, coûts mesurés et arbitrage — matière contre volume approché — en
  `nextsteps.md`, §7bis.3. Le résumé : les cinq modèles entiers sont à passer en
  matière (186 à 1 907 voxels, une ligne de code), le feuillage ne l'est
  probablement pas (×12 sur ce qu'un arbre écrit dans le monde) et relève d'un
  volume approché au jalon 3.1.
- **abattre un arbre est grossier.** Creuser un tronc retire ses houppiers — la
  colonne porte une édition, donc la dispersion écarte le candidat — mais le fût
  garde son trou et reste debout.
- **la réduction en distance.** `CWVoxelModel.reduced(n)` est prêt et ne sert
  encore à rien. Un houppier de 22 blocs de large est le premier modèle assez
  gros pour la justifier, et il est maintenant seul dans son instance.
- ~~**la sélection.**~~ **Tranché le 2026-09-05 : son propre champ.** Le rôle
  `ARBRE` ne rejoint pas `CWDecorRules.FAMILIES`, pour deux raisons. Les deux
  crêtes de la flore sont à 0,01 et tranchent une *famille de décor* — de l'herbe
  contre des fleurs ; un arbre ne concourt pas avec le couvert pour la même
  place, il se pose par-dessus. Et la source les sépare elle-même : la flore
  basse est du décor poussé en fin de boucle de colonne, les arbres passent par
  la voie des entités. Détail dans `CWTreeRules`, en-tête.

**Dépend de :** 1.7 (les rôles, la bibliothèque, le mailleur), 1.8 (l'écriture
dans le terrain, pour le tronc). **Débloque :** un paysage lisible à distance, et
le premier usage réel de la réduction de niveau de détail.

---

### 1.12 — Les six biomes (fait, 2026-09-06)

Jusqu'ici, « biome » voulait dire `CWPalette.surface_index` : **neuf matières de
bloc** qui servaient aussi de clé aux tables de flore, d'arbres et de densité.
Les deux notions y étaient confondues, et ça se voyait dès qu'on essayait de
dire une phrase simple — une crête rocheuse au-dessus d'une prairie n'est pas un
« biome roche », une île au milieu de l'océan porte la végétation de la terre
ferme, une plage n'est pas un désert.

**Un biome est désormais une zone climatique**, il y en a six, et il décide *ce
qui pousse*. La **matière de surface** est une conséquence du biome et de
l'altitude, et elle décide *ce qu'on voit et ce qu'on creuse*. `CWBiome` fait la
première moitié, `CWPalette.surface_of` la seconde.

Les six sont ceux de l'alpha 2013 — Greenlands, Snowlands, Deserts, Jungles,
Lava Lands, Oceans. Ce sont des noms du jeu d'origine, gardés parce qu'ils
nomment une *classification* et non un asset ; le contenu de chacun est une
création de ce projet.

#### Ce que le champ de climat a imposé, et qu'aucun raisonnement n'aurait donné

`tools/biome_stats.gd` balaie le champ réel sur 144 zones éloignées et rend la
répartition. Il a servi trois fois, et à chaque fois il a contredit une règle
qui se lisait juste. Le tableau croisé des terres, en pourcents :

| t \ h | 0-20 % | 20-40 | 40-60 | 60-80 | 80-100 |
|---|---|---|---|---|---|
| 0,0 – 0,2 | 10,68 | 0,05 | 0,04 | 0,03 | 14,00 |
| 0,2 – 0,4 | 0,01 | 0,06 | 8,03 | 6,52 | 1,35 |
| 0,4 – 0,6 | 0,00 | 0,02 | 8,74 | 11,87 | 1,05 |
| 0,6 – 0,8 | 0,01 | 0,05 | 5,55 | 8,39 | 0,08 |
| 0,8 – 1,0 | 11,52 | 0,04 | 0,04 | 0,04 | 11,81 |

**Le champ est bimodal.** Les quatre coins portent 48 % des terres ; un point
chaud est soit très sec, soit très humide, jamais entre les deux. La première
règle de Lava Lands prenait justement la bande d'humidité laissée libre entre le
désert et la jungle aux hautes températures : elle rendait **60 colonnes sur
147 456**. Baisser son seuil de température de 0,88 à 0,80 n'a rien changé — 64.
*Une règle peut être juste et vide.*

Ce qui marche est de découper dans le coin chaud-sec, tout en haut : au-dessus
de 0,97 de température, le mélange climatique ne produit que le **cœur d'une
région dont le site est à l'extrême**. Lava Lands est donc un cœur de région,
entouré de son propre désert — exactement la forme voulue, et ce qu'un tirage
par colonne n'aurait pas donné. « Loin du spawn » suit sans qu'on ait à le
demander : le point de départ est au centre de la carte, où le climat est médian.

Répartition obtenue, sur 147 456 colonnes :

| biome | du monde | des terres |
|---|---|---|
| Greenlands | 43,5 % | 57,7 % |
| Snowlands | 10,5 % | 13,9 % |
| Deserts | 10,5 % | 13,9 % |
| Jungles | 8,7 % | 11,6 % |
| Lava Lands | 2,2 % | **2,9 %** |
| Oceans | 28,8 % | — |

#### Lava Lands : deux types de bloc, sans déplacer une frontière

Le biome volcanique a besoin de matière que le générateur **écrit** — on doit
pouvoir creuser une croûte de scorie et reconnaître une coulée dans
`CHANNEL_TYPE`. Les deux entrées prises sont **30 et 31**, déjà peintes en lave
dans la réserve terrain 14 – 31, et les deux seules de cette réserve qu'aucun
modèle n'employait. Elles changent de statut sans qu'une frontière bouge : la
limite terrain/créatures reste à 40/41, et l'opération de l'invariant n° 26 n'est
pas repayée.

**Les coulées sont une crête de bruit**, comme la crête de placement du décor :
ce qui est près de zéro est du magma, le reste est de la scorie. C'est la seule
règle de surface qui ait besoin de la position, et c'est pour elle que
`surface_of` prend (x, z) depuis ce jalon — un échantillon de bruit sur 1,9 % des
terres. Sa fréquence est passée de 0,004 à 0,012 après capture : à 250 blocs de
longueur d'onde, une vue de 224 blocs pouvait tomber entièrement entre deux
coulées, et le biome rendait une plaine de scorie nue.

#### La refonte des deux lots d'assets

Elle était déjà due (`nextsteps.md`, §6) et elle tombait au bon moment : on ne
regénère qu'une fois.

**Les 24 arbres passent à 1 voxel = 1 bloc.** C'est la correction la plus lourde
du jalon, et elle repose sur deux arguments plus solides que l'œil. La
*provenance* : `0,075 = 3/40` est relevée dans la voie du **décor** du binaire, et
aucune échelle n'a jamais été relevée dans celle des **entités**, par où passent
les arbres. Le *structurel* : la source écrit le tronc en colonnes de blocs et
instancie le houppier séparément, ce qui n'est cohérent que si le houppier est
sur la grille du bloc. Conséquences portées : `VOXELS_PER_BLOCK` devient un champ
par bibliothèque, l'espacement des arbres passe de 7 à 14 blocs, leurs densités
sont divisées d'autant, et leurs formes sont **repensées et non réduites** — un
conifère est une pile de disques plats, un houppier quelques dizaines de cubes
bien placés. Le générateur en sort en Python pur : à cette maille, Blender
n'apporte rien.

**Les 42 modèles de flore gardent 3/40 et grandissent.** Une touffe d'herbe monte
à l'épaule du personnage et non au genou, elle a cinq ou six brins et non vingt,
et chaque brin fait deux voxels de large. La cause première était une ligne
fausse de `assets/models/MODELS.md`, §1, corrigée avant la regénération — sans
quoi la reprise suivante aurait redessiné au genou.

#### Ce que les captures ont attrapé, et qu'aucun test ne voyait

Cinq défauts, tous trouvés en jeu, aucun détectable en headless :

1. le fût des conifères ressortait **au-dessus** du feuillage, sur tous les
   conifères du monde à la fois ;
2. la scorie, à sa teinte « lave refroidie » d'origine, rendait un rose saumon
   uniforme dont la coulée incandescente ne se détachait pas ;
3. le magma, à 255,152,48, se confondait avec le sable du désert (253,185,82) ;
4. **cinq modèles de Snowlands sur six** puisaient dans la rampe « automne », un
   orange chaud, et ressortaient en taches orange sur un sol de neige cyan. Le
   défaut avait déjà été relevé et corrigé pour un seul modèle le 2026-09-05 ; il
   est revenu au complet avec le nouveau lot. D'où une règle écrite en toutes
   lettres dans le générateur : **aucune plante de Snowlands ne prend 140 – 147** ;
5. la couronne d'un palmier n'avait que **deux directions** au lieu de quatre.
   Une palme est désormais une paire de frondes opposées — c'est ce qui met
   l'attache sur l'ancre, et c'est la correction du décalage d'attache signalé à
   la production du lot précédent — mais une paire tournée d'un demi-tour est
   identique à elle-même. Le quart de tour n'avance donc qu'une pièce sur deux.

#### Trois défauts vus après coup — corrigés le 2026-09-06 au soir

Constatés en jouant, après le commit du jalon. Diagnostics vérifiés sur les
profils en Z des modèles, remèdes vérifiés en capture. Détail en
`nextsteps.md`, §6bis.

1. **La flèche des conifères flottait** — et ce n'était pas elle qui était mal
   placée, c'était son étage. Les deux derniers étages du `pin` sont espacés de
   2,8 blocs pour un bloc d'épaisseur, et le fût, raccourci à 0,82 de la hauteur
   le même jour pour ne pas dépasser du feuillage, ne comblait plus l'écart.
   Deux corrections qui se télescopaient. **Le fût monte désormais jusqu'au
   dernier étage posé** — la seule des deux contraintes qui compte, et la seule
   qui se dise sans fraction.

   La capture d'après a montré la moitié qui manquait au diagnostic : le fût
   comblait l'écart, mais **en écorce**, et les deux à trois blocs entre étages
   laissaient voir une colonne brune. L'arbre se lisait comme une pile
   d'assiettes enfilées sur un piquet. Un conifère ne montre son écorce
   qu'entre le sol et son premier étage ; au-dessus il est dans la masse, et
   c'est maintenant ce que le générateur dessine.
2. **Les palmes du dattier flottaient** — le décalage d'attache avait été réglé
   *dans le dessin* (une paire met l'attache sur l'axe horizontal) mais **pas en
   Z** : une paire retombe, donc son attache est le voxel le plus haut du modèle,
   et l'assembleur la posait par sa base. `_couronne_de_palmes` retranche
   désormais `(hauteur - 1)` blocs du modèle, à son échelle et à sa grille.
3. **Ne garder que les gros cailloux** : `greenlands/caillou_02` (une dalle
   plate de 19 voxels) et `deserts/gres` (une colonne à chapeau de 34) sont
   supprimés. Le second était le seul modèle du rôle `CAILLOU` de Deserts, et
   le vider aurait fait tomber la vérification de l'invariant n° 22 — c'est
   exactement ce pour quoi elle existe. Il est **remplacé** plutôt que retiré :
   `deserts/caillou_gres` est un bloc erratique à la matière du grès (20 – 24),
   et le désert garde sa composition. Les quatre minéraux du monde sont
   maintenant une famille — même masse basse et large, quatre matières.

**Dépend de :** 1.3 (le climat), 1.7 (les rôles et la bibliothèque), 1.11 (la
couche des arbres). **Débloque :** six biomes qu'on peut nommer, et un contenu
par biome qui n'est plus une liste de matières de sol.

#### La planche de validation des assets — 2026-09-06, après les remaniements de rendu

Trois sessions de suite, chaque défaut d'asset avait été trouvé par hasard, en
jouant, une fois le lot déjà commité. `scenes/model_portraits.tscn` pose la
question dans l'autre sens : **une capture par modèle, seul, sur un damier
neutre d'un bloc de maille, sous deux angles** — plus un quatrième lot, les
arbres **montés** par `CWTreeScatter`, c'est-à-dire ce que le jeu pose et non ce
que le générateur écrit. 84 sujets en 5,6 secondes, sans terrain à streamer.

**Vingt-sept modèles sur soixante et onze ont été regénérés.** Ce que la planche a
appris tient en une phrase : *la moitié de ce qu'on croyait devoir regarder se
comptait*. Treize modèles étaient faits de cubes qui ne se touchent pas — la
fougère en douze morceaux — parce que onze fonctions de dessin échantillonnaient
un arc sur son étendue **horizontale** alors qu'il montait trois fois plus haut.
Rien dans les nombres ne bronchait : boîte englobante, compte de voxels et
plages de palette étaient tous justes. C'est désormais un invariant vérifié
(`tests/flora_test.gd`, 26-voisinage, invariant n° 34), rapporté par
`tools/inspect_model.gd` et par les générateurs à chaque écriture.

Les sept autres défauts demandaient bien un œil, et aucun n'était détectable
autrement : les sept fleurs du lot étaient des **panneaux de signalisation**
(une corolle était un disque plat sur une tige) ; ce qu'on posait *sur* une
masse — baies, piments, braises — était en fait tiré *dedans*, donc invisible,
et le buisson de feu se lisait comme un rocher noir ; et deux fûts de bouleau
tenaient sur **un bloc de section** sur quatorze de haut, parce qu'un rayon de
1,0 décroissant ne garde qu'un voxel par étage. Verdict modèle par modèle,
mesures et remèdes dans `nextsteps.md`, §6quater.

### 1.12bis — Les provinces climatiques (2026-09-06, création de ce projet)

**Le climat de la source n'est pas géographique**, et ça se voit en marchant.
`World_generateRegionSite` tire la température et l'humidité d'une zone avec un
LCG graîné sur `(rx, rz)` — **indépendamment de ses voisines** — et une fois sur
deux il prend un extrême : froid sous 0,1 ou chaud au-dessus de 0,9. Deux zones
côte à côte peuvent donc sortir 0,05 et 0,95.

> **Relevé en jeu le 2026-09-06 : « un biome neige à côté du désert, c'est
> bizarre. »** C'est la même bimodalité que le jalon 1.12 avait mesurée sans en
> tirer cette conséquence — « ses quatre coins portent 48 % des terres ». On
> l'avait lue comme une propriété du champ ; c'en est un défaut.

**Ce qui est écrit ici est une création de ce projet**, et la charte demande de
le dire : la source n'a pas de provinces. Le mécanisme est le plus petit qui
réponde au défaut.

Un bruit basse fréquence sur la **grille de zones** décide, pour chaque zone qui
tire un extrême, **lequel** — le signe — et **à quel point** — la valeur absolue.
Au cœur d'une province, l'extrême est celui de la source, intact ; au bord, il
glisse vers 0,5.

> **La seconde moitié est celle qui compte.** Ne prendre que le signe aurait
> regroupé les extrêmes en provinces mais laissé une couture franche entre deux
> provinces voisines — c'est-à-dire le même défaut, plus rare. En adoucissant
> vers le tempéré au bord, un cœur froid et un cœur chaud **ne peuvent plus se
> toucher** : entre les deux, le champ passe par 0,5, et c'est une bande de
> Greenlands qui apparaît là où il y avait une couture.

**Le relief est identique au bloc près**, et c'est délibéré. `base_height` sort
d'un bruit et non du LCG, et **tous les tirages du LCG sont conservés** :
`rng.coin()` est toujours appelé, sa valeur simplement ignorée au profit du
champ. Le nombre de tirages ne bouge pas, donc les positions de sites non plus,
donc le champ d'altitude non plus. Mesure à l'appui : la part d'océan est
inchangée **au chiffre près**, 12 108 colonnes sur 49 152 avant comme après.

#### Ce que ça change, mesuré

| | avant | après |
|---|---|---|
| Greenlands, des terres | 49,5 % | **57,7 %** |
| Snowlands | 35,8 % | 13,9 % |
| Deserts | **1,2 %** | **13,9 %** |
| Jungles | 9,6 % | 11,6 % |
| Lava Lands | 3,8 % | 2,9 % |
| coin froid-sec du climat | 17,98 % | **0,00 %** |
| paires neige/désert à 4 096 unités | 6 sur 50 083 | **0** |

Les deux dernières lignes sont la mesure qui compte, et la première des deux est
la plus parlante : **le coin froid-sec du tableau croisé se vide entièrement**.
C'est la bimodalité qui disparaît, et avec elle la cause.

Le désert, lui, passe de 1,2 % à 13,9 % des terres — il était si rare qu'on ne
pouvait pas juger de sa forme. `tools/biome_stats.gd` porte désormais le
**voisinage des biomes**, mesuré à 4 096 unités et non à 256 : à 256 unités deux
sondages tombent presque toujours dans le même climat, et la mesure y rendait
zéro avant comme après, c'est-à-dire rien.

---

### 1.13 — La falaise (portée puis retirée, 2026-09-06)

**Écrite le matin, retirée le soir, sur une seule phrase :** *au final ça ne rend
pas si bien que ça en jeu.* Rien de ce qui suit n'est une erreur — la règle est
bien dans la source, la pente était mesurée et non devinée, les trois
vérifications passaient, le surcoût était sous le bruit de mesure. Ce qui a
manqué est ailleurs, et c'est ce que cette section garde.

#### Ce qui a été porté

`terrain_surfaceColor_blend` (@005c56e0) laisse son appelant forcer le bloc
**6 — la roche** quand « le facteur de falaise dépasse 0,5 »
(`docs/systems/02`, §9.1). La décompilation donne le seuil et le nom du facteur ;
elle ne donne pas son calcul. Le facteur écrit ici était donc une pente mesurée
sur le champ d'altitude, prise sur un **treillis de 4 blocs** à sommets partagés
— seize colonnes pour quatre échantillons, en cache — et rapportée à une
constante de référence, `CLIFF_SLOPE_REF`, pour que tout ce qui était inventé
tienne en un seul nombre.

#### Les trois mesures, qui restent vraies

Elles ont coûté deux essais et une capture chacune, et elles décrivent le
**terrain**, pas la règle. Elles resserviront telles quelles.

- **Ce monde n'a pas de parois verticales.** Sur huit mille colonnes en ligne,
  le plus grand dénivelé d'un bloc au suivant est de **0,65 bloc**. Un relief
  fait de bruit de valeur à interpolation cosinus est lisse par construction ;
  ce qu'il a de plus raide est un flanc.
- **Chercher quarante-cinq degrés, c'est chercher ce qui n'existe pas.** Premier
  essai, `CLIFF_SLOPE_REF = 2,0` : **0,62 % des terres**, c'est-à-dire rien. À
  1,0 — quatre blocs de dénivelé sur huit parcourus, vingt-sept degrés moyens —
  la roche prenait **4,4 % des terres**, 3,4 % du monde.
- **Un pas de treillis long mesure le flanc, pas la paroi.** À 8 blocs la part
  qui bascule ne bouge pas (4,5 contre 4,4 %) mais la queue de la distribution
  se vide : au-delà d'un facteur de 0,9, huit blocs donnent 0,02 % des terres et
  quatre en donnent 0,29 %, quinze fois plus.

#### Pourquoi elle a été retirée, et ce que ça apprend

Les trois mesures ci-dessus se contredisent moins qu'elles ne s'additionnent, et
lues ensemble elles disent la chose que la capture a montrée :

> **Une falaise ne se peint pas, elle se taille.** À vingt-sept degrés, de la
> roche grise posée sur un flanc vert ne se lit pas comme une paroi : elle se
> lit comme une **tache**, une plaque de couleur au milieu d'une pente que rien
> ne distingue de ses voisines. Le seuil avait été baissé de 2,0 à 1,0
> précisément parce qu'à 2,0 la règle ne rendait rien — mais ce que 0,62 %
> disait n'était pas « le seuil est trop haut », c'était **« il n'y a pas de
> falaise dans ce terrain »**. Baisser le seuil n'a pas trouvé de parois, il a
> teinté des flancs.

C'est le **même défaut de méthode que les bandes d'altitude retirées le matin
même**, pris par un troisième bout, et c'est ce qui rend le cas cher à
redécouvrir : à chaque fois la règle est défendable, à chaque fois elle passe
les tests, et à chaque fois elle échoue sur une chose qu'aucun test headless ne
voit. Les bandes ne **portaient rien** ; la falaise ne **ressemblait à rien**.
Une matière n'est jamais jugée par sa règle de placement, elle est jugée par ce
qu'on voit en marchant dessus.

**À quelle condition elle peut revenir.** Il faudrait que le champ d'altitude
produise d'abord des parois — un terme de terrasse, une discontinuité, quelque
chose qui casse la douceur du bruit à interpolation cosinus. La roche viendrait
alors *habiller* une forme qui existe, au lieu d'essayer de la suggérer seule.
C'est un travail sur `CWTerrainField._height_from`, pas sur `CWPalette`, et il
n'a pas de jalon : le noter ici suffit, avec les trois mesures qui le cadrent.
`CWPalette.SNOW_LINE_BASE`, `ROCK_BAND` et `ROCK_MIN` restent en place pour Lava
Lands et serviront encore de point de départ.

**Ce qui est resté du jalon.** L'option `--ici x z` de la démo, ajoutée pour
viser une capture sur un point nommé plutôt que de relancer `--biome` jusqu'à
tomber sur ce qu'on cherche. Elle a survécu à ce qui l'avait motivée, et elle
sert pour tout objet local.

### 1.14 — Les lacs (fait, 2026-09-06)

**L'eau de surface**, et le dernier système du monde. Elle n'est ni un élément de
tuile ni un niveau global : c'est une seconde passe de
`WorldInfo_generateBiomeContent` (@005e4850), colonne par colonne, et **sa porte
est le champ de chenaux porté au jalon 1.4**.

> **Il ne manquait pas un champ, il manquait un seuil.** Ce dépôt écrivait « le
> réseau de chenaux creuse bien les vallées, mais rien ne les remplit ». Ce qui
> les remplit est le même réseau, à **0,02**.

#### Ce qui a débloqué le portage

Une lecture, faite le soir même (`docs/systems/02`, §10.4) :
`terrain_generateColumnColor` rend la hauteur **finale** de la colonne — elle
consulte la porte des chenaux, contient l'octave de détail à 1e-2 et applique la
couche d'éléments de tuile. Mieux : ses quatre graines de déformation d'éléments
sont mot pour mot les nôtres, donc **c'est `World_baseHeightField`**, la fonction
que ce projet porte depuis le jalon 1.4. Le niveau d'un étang est
`CWTerrainField.sample_column(x, z).x`, sans rien de nouveau à calculer.

#### La règle, et les trois corrections que la relecture a imposées

Le pseudo-code de `docs/systems/02` §10.2 datait de l'analyse de la veille. Écrit
depuis un nom et non depuis les lignes, il était juste dans les grandes lignes et
faux sur trois points — tous relevés en le relisant *pour l'écrire*, et le
premier change le sens de la passe :

- **le sol humide est la rive, pas le lit.** Son écriture est gardée par « le
  bloc qui se trouve là n'est pas de l'eau », garde qui échoue précisément quand
  il y en a. Le type 3 est donc l'anneau autour de chaque mare — ce qui est
  beaucoup mieux, `CWDecorRules.FAMILIES_SURFACE` y faisant pousser des roseaux,
  et un roseau se tient sur la rive ;
- **le lit remonte dans le dernier quart d'un palier**, à `q + 5|t|` et non à
  `q`. C'est ce qui évite une marche franche de cinq blocs à chaque bord de
  palier ;
- **la porte de la rampe est `t > 0,2` et non `t >= 0,4`**, par troncature
  entière : 60 % du palier au lieu de 45 %. Mesuré après portage, **58,4 % des
  colonnes de la porte** — les deux s'accordent.

#### Ce que ça rend, mesuré

`tools/biome_stats.gd`, 49 152 colonnes, graine 1337 :

| | part des terres |
|---|---|
| colonnes dans la porte | **3,35 %** |
| dont en **eau** | **2,77 %** (82,8 % de la porte) |
| dont en **rive** | 0,58 % |
| creusement moyen dans la porte | 4,37 blocs |

Profondeur : 1 à 4 blocs, dont 57 % à un seul bloc — la rampe ne décide plus de
la présence de l'eau, et les seuils qu'elle laissait à sec sont maintenant
couverts d'un fond de nappe. En jeu, l'eau suit les fonds de vallée en **rubans
ramifiés continus** : le champ de chenaux est rectifié, donc ses zéros dessinent
des lignes.

#### Ce que le portage a demandé d'autre

- **le profil de colonne remplace la hauteur.** `CWTerrainField.column_profile`
  rend `(sol, eau_bas, eau_haut)` et c'est lui qui décide ; `pond_span` isole
  l'arithmétique de la rampe, pure et testée seule. Le creusement s'exprime en
  **abaissement de colonne** plutôt qu'en passe séparée, ce qui règle du même
  coup le piège annoncé : les deux chemins rapides de `_generate_block`
  s'appuient sur `patch.lowest`, et prendre le minimum *après* le profil suffit ;
- **`_sample` rend un `Vector4`** — le champ de chenaux sort avec l'altitude et
  le climat. Il était déjà calculé, donc **zéro échantillon de bruit de plus** ;
  `sample_column` et `sample_column_raw` gardent leur `Vector3`, et les
  trente-cinq consommateurs n'ont pas bougé ;
- **les deux dispersions savent nager.** Flore et arbres refusent une colonne
  d'eau et se posent sur le sol *après* creusement ; sans quoi chaque mare se
  couvre d'herbe flottante, et un tronc — qui est de la matière depuis 1.11 —
  traverserait l'eau sans que rien ne l'en retire ;
- **coût : sous le bruit de mesure.** Médiane de cinq passes, 76,4 µs par colonne
  contre 75,7 sans les lacs, soit +0,9 % quand la dispersion d'une passe à
  l'autre est de ±6 %.

#### Quatre écarts assumés à la source, demandés le soir même

Le portage fidèle a été vu en jeu, et quatre choses en sont ressorties. Aucune
n'est dans la source ; toutes sont écrites comme des créations de ce projet.

- **l'eau ne touche plus la rive.** Dans la source, l'eau monte jusqu'au palier
  `q` et la berge est tranchée au même `q` : les deux affleurent. Une nappe à ras
  bord ne se lit pas comme de l'eau, elle se lit comme une matière bleue posée à
  plat. La surface descend d'un bloc (`POND_BANK_DROP`), et la berge lui donne un
  bord ;
- **les rivières sont continues.** Le découpage venait de la rampe triangulaire,
  qui ne laissait passer l'eau que sur 60 % d'un palier : un cours d'eau
  s'interrompait chaque fois que le terrain traversait un multiple de 5. La rampe
  garde le **fond** et perd la **présence** — il y a toujours au moins un bloc
  d'eau dans le lit —, donc le tracé redevient continu et la rampe garde son
  rôle : elle creuse les cuvettes et laisse les seuils peu profonds ;
- **les rivières finissent en lacs.** Le seuil du chenal n'est plus constant : il
  vaut 0,02 en altitude — la valeur de la source — et **0,055 au ras du niveau de
  la mer**, l'écart se refermant sur les 90 premiers blocs. Un réseau de chenaux
  ne dit pas où est un bassin ; il faudrait un voisinage, donc un coût par colonne
  qu'on ne peut pas payer. Mais il dit l'altitude, et *une rivière qui s'élargit
  en descendant est ce qu'on voit d'un bassin*. Mesuré : une fenêtre de 64 blocs
  autour d'un point bas est à **27 % d'eau**, contre un ruban en altitude ;
- **ni les Deserts ni les Lava Lands n'ont d'eau de surface.** La source n'a pas
  de biomes — c'est une couche de ce projet, jalon 1.12 —, donc cette règle non
  plus. Elle se défend seule : un désert est défini par l'absence d'eau.

Et une conséquence à laquelle il a fallu répondre : **avec l'eau partout dans la
porte, la rive disparaissait**, donc le sol humide, donc le roseau — le seul
modèle de la flore qui pousse sur cette matière. La rive redevient ce qu'elle est
dans le paysage, **la bande extérieure du lit** (`POND_WATER_FRAC`), celle où le
chenal est encore sous le seuil mais déjà trop haut pour porter de l'eau. Elle a
l'avantage d'être continue le long du cours d'eau, là où celle de la source
apparaissait par plaques entre deux mares.

#### La réserve assumée : la rive n'est humide qu'en Jungles

`FAMILIES_SURFACE[SWAMP]` appelle le rôle ROSEAU, et le seul modèle de roseau du
lot est `jungles/roseau`. Poser du sol humide dans les cinq autres biomes
rendrait un anneau **nu** autour de chaque mare — *une matière qui ne porte rien
est un trou dans le monde*, et ce dépôt l'a déjà payé trois fois : les franges
d'humidité, les bandes d'altitude, la falaise. La rive n'est donc humide que dans
le biome que `FAMILIES_SURFACE_BIOME` déclare capable de la garnir. Le jour où
chaque biome aura son roseau, cette table grandira et la rive suivra sans qu'on
retouche au code.

### 1.15 — Les surplombs, les grottes, et la falaise qui revient (2026-09-07, ~~retiré~~ le 2026-09-10)

> ⚠️ **Les surplombs et leurs grottes n'existent plus.** Retirés le 2026-09-10
> sur la demande *« je n'aime pas le rendu en jeu »*, après trois refontes en
> trois jours. Ce qui suit décrit un système disparu, et on le garde parce que
> *savoir pourquoi une chose a été retirée vaut plus cher que la chose*.
> **La falaise, elle, survit** : elle mesure la pente du champ d'altitude, qui
> n'a jamais rien su de cette couche. Le récit du retrait est dans le journal,
> à la date du 2026-09-10.

**Trois choses sortent d'un seul mécanisme**, et c'est ce qui le justifie : la
paroi verticale que la falaise attendait depuis le 1.13, le surplomb sous lequel
on marche, et l'abri sous roche qui donne aux grottes une entrée qu'on n'a pas
à creuser.

#### Une seconde nappe, jamais un terme d'altitude

Le champ du jalon 1.4 est un **champ de hauteurs** : une colonne, une altitude,
rien au-dessus. C'est ce qui le rend assez bon marché pour le streaming, et
c'est aussi ce qui lui interdit une paroi — un bruit de valeur à interpolation
cosinus est lisse par construction, et 1.13 a mesuré son plus grand dénivelé
d'un bloc au suivant : **0,65 bloc**.

La couche de surplombs ne touche pas à ce champ. `_height_from` est mot pour mot
ce qu'il était, et le relief du monde n'a pas bougé d'un bloc. Elle **ajoute**
une seconde nappe de matière, décrite elle aussi par colonne, et composée de
deux morceaux :

- un **chapeau** plat sur un disque déformé. Son bord est une paroi verticale de
  8 à 31 blocs : c'est la falaise, et elle est taillée ;
- un **socle** qui descend sous le terrain au centre et s'arrête net à une
  fraction du rayon. Entre le bord du socle et celui du chapeau, il n'y a rien :
  c'est le porte-à-faux, et il va jusqu'à **64 blocs de vide** sur le premier
  surplomb mesuré près du départ.

> **La recursion n'existe pas ici, et c'est ce qui rend la couche bon marché.**
> `CWTileFeatureGrid` doit se garder contre elle par trois verrous et une garde
> de réentrance, parce que ses éléments déforment le champ dont ils lisent
> l'altitude. Une cellule de surplombs peut échantillonner le terrain
> librement : rien dans le champ ne la consultera jamais. **Le jour où un terme
> d'altitude lirait un surplomb, tout l'appareil de 1.6 deviendrait nécessaire.**

#### La forme, refaite le lendemain : un massif, pas une mesa

> ⚠️ **Cette section décrit la forme du 2026-09-08, qui a été remplacée le
> 2026-09-09.** Elle est gardée parce que sa dernière ligne est celle qui a
> décidé de la suivante : *le contrat d'escalade est ce qui rendait la masse
> ronde*. La forme actuelle — déformation du domaine, ellipse tournée, lobes
> angulaires, exposant de profil et gradins, sans aucun contrat de pente — est
> en **`nextsteps.md` §7nonies.3**, avec ses mesures.

La première version était un **chapeau plat sur un socle étroit** — une mesa au
sens propre, sa paroi verticale et son porte-à-faux. Elle a tenu une journée.
L'objection ne se discute pas : *le joueur doit pouvoir y monter*, et un chapeau
qui déborde de son socle est fait pour qu'on ne le puisse pas.

La forme est donc devenue un **champ de bosses** — un dôme radial déformé par
deux bruits, qui retombe à zéro sur son contour :

```
f(x, z) = (1 − u²) + bruit lent + bruit fin
dessus  = sol de la colonne + hauteur × max(0, f)²
```

Trois choses la rendent gravissable, et les trois ont été trouvées en mesurant :

1. **le dessus se mesure depuis le sol de *sa* colonne**, pas depuis celui du
   centre du massif. Une masse posée sur un flanc qui descend de douze blocs
   entre son centre et son bord finissait sinon par une **marche de douze
   blocs** sur tout son contour ;
2. **le profil est au carré**, `f²` et non `f` : la masse rejoint le sol
   *tangentiellement*, sa pente s'annule sur son contour au lieu d'y valoir son
   maximum ;
3. **les fréquences des deux bruits sont relatives au rayon.** Un bruit à
   fréquence fixe donne dix lobes à une grosse masse et un demi-lobe à une
   petite — deux formes qui n'ont rien à voir, et sur la grosse une pente
   proportionnelle à la hauteur. *Une déformation se règle en nombre de lobes
   par tour, et ce nombre vaut `2π × rayon × fréquence`.*

**Le contrat est vérifié, pas supposé.** Une vérification balaie un massif en
croix sur vingt-quatre rayons et relève la plus grande marche : **deux blocs**,
et deux est le minimum atteignable — le dessus vaut
`plancher(sol) + plancher(hauteur × f²)`, et chacun des deux termes a le droit
de changer d'une unité d'une colonne à la suivante.

> **Un massif tout vert est une colline, pas un relief.** La règle de falaise ne
> peut pas l'aider : elle mesure la pente du *champ d'altitude*, qui ne sait rien
> de cette couche. On prend donc l'**épaisseur** — la frange, où la masse
> affleure de deux ou trois blocs, garde l'herbe du pré qu'elle traverse ; le
> cœur, où elle fait dix blocs et plus, est de la roche nue. C'est un
> affleurement, et c'est ce qui le fait voir.

Le seul surplomb qui subsiste est le **porche** d'une grotte, et il est là pour
rendre son entrée visible.

#### Où ils sont : des pays de canyons, et des buttes isolées entre eux

Un tirage uniforme met des mesas partout à la même fréquence, ce que les
captures du jeu ne montrent pas : on y voit soit une butte seule au milieu d'une
prairie, soit un canyon où elles se touchent presque. La chance d'une cellule de
512 unités est donc modulée par un bruit de très basse fréquence — la même idée
que la crête de placement du décor, à une échelle mille fois plus grande. Le
monde a des *pays de canyons* de la taille d'une région.

Mesuré sur 36 zones éloignées, graine 1337 :

| | part des terres |
|---|---|
| sous un massif | **1,37 %** |
| dans une grotte | 0,182 % |
| roche de pente (la falaise) | **2,59 %** |

Rayon médian **73 blocs**, hauteur médiane **32 blocs** — passée à **43** après
la refonte du 2026-09-09, qui a retiré le plafond que le contrat d'escalade
imposait. Le porte-à-faux, lui, est tombé à zéro et c'est voulu : le seul endroit
où de la roche surplombe encore du vide est le **porche** d'une grotte.

#### Les grottes : accessibles par construction, pas par réglage

La demande était précise : *pas profondes comme celles de Minecraft, toujours
accessibles par une falaise ou un surplomb, jamais besoin de creuser*. Elle est
tenue par la géométrie et non par un seuil.

Une grotte est un **tube brisé** qui s'enfonce dans la masse. Son entrée est
prise au **seuil** du massif — la dernière colonne où celui-ci n'a aucune
épaisseur, donc un endroit qui est déjà de l'air —, et **son plancher est
l'altitude du sol à ce point-là**, relevée au placement. Les deux ensemble font
qu'on entre de plain-pied dans un trou qui donne sur l'extérieur.

Trois propriétés viennent de la seconde passe, sur trois reproches faits à la
première :

- **plus profondes** : la galerie fait de 55 à 130 % du rayon du massif, contre
  un tiers. Mesuré sur la zone de départ : **67 blocs** pour la plus courte ;
- **plus aléatoires** : l'axe est une ligne brisée de deux à quatre coudes, avec
  un écart latéral qui va jusqu'à la moitié du segment. On ne voit pas le fond
  depuis l'entrée ;
- **plus visibles** : la bouche s'évase — deux fois le rayon de la galerie — et
  le dessous de la masse se soulève autour d'elle. C'est le **porche**.

Une vérification constate l'accessibilité **sur le monde généré** et non sur la
règle qui l'a posée : elle part de l'entrée, s'éloigne de vingt-cinq blocs à la
hauteur du plancher, et exige de l'air tout du long. Elle a attrapé deux
défauts, et le second n'était pas prévisible :

> **Sortir de la masse ne suffit pas à voir le ciel.** Un massif posé au pied
> d'un versant a des côtés où le terrain *remonte* dès qu'on le quitte, et une
> galerie percée de ce côté-là donne sur un talus. On essaie donc **huit
> directions** et on garde la première qui descend.

#### La falaise, reprise et tramée

Elle revient, et deux choses ont changé depuis son retrait :

- **la roche n'est plus seule.** Une plaque grise sur un flanc vert lisait comme
  une tache parce qu'elle était le seul accident du paysage ; elle est
  maintenant la même matière que les parois qui la dominent ;
- **la frontière est tramée** — c'est la demande, et c'est ce qui manquait le
  plus. Voir la section suivante.

Un réglage a été refait en capture, et il mérite d'être noté parce qu'il se
reproduira : **à seuil bas, la roche de pente dessine des courbes de niveau**.
La pente d'un champ lisse est elle-même un champ lisse, ses valeurs fortes
forment des rubans qui suivent les lignes de plus grande pente, et une colline
verte se retrouve cerclée de gris — dans l'axe même des marches d'un bloc que la
voxelisation dessine déjà. Deux quadrillages superposés, et le paysage se lit
comme une carte topographique. Le remède n'est pas de tramer plus fin, c'est de
ne prendre que le haut de la distribution : **au-dessus de 0,34 bloc par bloc,
une pente n'est plus un ruban, c'est un flanc.**

#### Le dégradé adouci entre deux matières

Jusqu'ici, toute frontière de matière était un seuil, et la ligne entre deux
matières suivait une courbe de niveau au bloc près. Le jeu d'origine ne fait pas
ça : sur une capture de plage ou de flanc, les deux matières **s'interpénètrent**
sur une dizaine de blocs, et l'œil lit un dégradé là où il n'y a pourtant que
deux couleurs.

C'est un **tramage**, pas un mélange de couleurs : un bloc reste d'une seule
matière, il se creuse et il porte son décor. Ce qui varie est la proportion, et
elle est décidée par un bruit à **deux fréquences** — et c'est la seconde qui
fait le travail. Une seule crête fine rend un poivre-et-sel qui se lit comme du
bruit de compression ; en lui ajoutant une fréquence lente, on obtient des
*plaques* : des langues de sable qui remontent une combe, des îlots d'herbe dans
une plage. Mesuré : **88 % d'accord entre deux colonnes voisines** à
mi-transition, contre 50 % pour un tirage indépendant.

Quatre frontières l'emploient : le haut de plage, la roche de pente, le bord de
la chaussée du jalon 1.16 — et la **frontière entre deux biomes**, qui est la
plus grande de toutes et qu'on a failli oublier.

> **La plus grande frontière de matière du monde n'est pas une bande d'altitude,
> c'est un désert qui rencontre une prairie.** `CWBiome.at` compare un climat
> continu à des seuils : sa frontière est donc une *courbe de niveau du champ de
> climat*, et le sol y changeait de couleur sur un trait. Le tramage s'y applique
> autrement — on ne trame pas deux matières, on **brouille le climat avant de le
> comparer aux seuils** —, mais le résultat est le même : une bande d'une
> trentaine de blocs où les deux s'interpénètrent, un écotone.
>
> **Le biome tramé ne sert qu'à la matière du sol.** Le biome *nommé* — celui qui
> choisit ce qui pousse, ce que l'ATH affiche et ce que la carte teinte — reste
> celui de `at`, sans quoi une prairie ferait pousser un cactus tous les vingt
> blocs le long de son désert. En frange, une touffe d'herbe se tient donc sur
> une plaque de sable : c'est exactement ce qu'on voit au bord d'un désert.
>
> Et une sortie rapide qui n'est pas cosmétique : loin de tout seuil — la
> quasi-totalité du monde — le brouillage ne peut rien changer, et la fonction
> sort avant d'échantillonner. Sans elle, ce seraient quatre bruits par colonne
> partout.

#### Plusieurs teintes par matière — la seconde passe

Deux couleurs ne font pas un dégradé au bloc près : elles font un damier. La
frontière était bien répartie, elle n'était pas *fondue*.

La correction tient à une propriété du rendu qu'on n'avait pas encore
exploitée : depuis le jalon 1.9, un voxel porte **son type dans `CHANNEL_TYPE` et
sa couleur dans `CHANNEL_COLOR`**, et le second n'est pas un index de palette
mais une couleur RVBA libre. *Rien n'oblige deux blocs d'herbe à être de la même
teinte.* D'où deux nuances, l'une sur l'autre :

- **la teinte de transition** : entre deux matières, la couleur *interpole* en
  cinq marches pendant que le type, lui, bascule d'un coup. Le sol garde une
  matière par bloc — il se creuse, il porte son décor — mais l'œil lit un fondu
  de cinq tons là où il ne voyait qu'un damier de deux ;
- **la teinte propre** : loin de toute frontière, une prairie prend trois tons de
  vert au lieu d'un. C'est ce qui empêche une plaine d'être un aplat.

> **Le facteur de fondu est tiré du même bruit que le type**, et ce n'est pas un
> détail : un bloc qui bascule en sable prend une teinte déjà tirée vers le
> sable, donc le damier et le dégradé sont **en phase**. Avec deux bruits
> indépendants, on obtiendrait un fondu correct parsemé de blocs à contre-teinte.

Conséquence sur un contrat ancien : `tests/edit_test.gd` vérifiait que la couleur
d'un voxel est *exactement* celle de son type. Elle demande désormais qu'elle
reste une **nuance plausible** de sa matière ; ce qu'elle attrape est le vrai
défaut, *un sol dont la couleur ne dit plus du tout la matière*.

**Coût.** La pente se mesure par différence avant sur un bloc, donc l'empreinte
échantillonnée par bloc gagne une colonne sur chaque axe — **+12,9 %**
d'échantillonnage. C'est le seul poste vraiment cher des deux jalons, et il est
isolable : `CWWorldParams.cliff_slope`. Le tramage lui-même ne coûte deux
échantillons de bruit que dans la bande de transition, c'est-à-dire nulle part
la plupart du temps.

Chargement d'une vue de 384 blocs au démarrage, les bascules mesurées dans la
même session : **24,1 s les trois éteintes, 28,5 s les trois allumées** — soit
**+18 %**. La veille, avant les teintes multiples et la refonte des massifs, le
même écart valait +13 % (22,2 → 25,1 s) : ce que la seconde passe a ajouté est
un échantillon de bruit par colonne de surface pour la teinte propre, et la
recherche de direction des grottes.

---

### 1.16 — Les chemins et les ponts (fait, 2026-09-07 ; les ponts retirés le 2026-09-09, les tunnels le 2026-09-10)

Le réseau qui relie les jalons d'une zone — son bourg, ses donjons, ses
agglomérations — et qui se raccorde à celui des zones voisines.

**Ce n'est pas dans la source, et c'est dit dans l'en-tête de `CWPathNetwork`.**
Ce dépôt l'a établi deux fois : `World_roadField` est l'aplanissement du bourg
et non un champ de routes, et les arêtes du graphe de sites ne sont pas des
voies (invariant n° 3). Ce qui justifie la couche est ce qu'on voit sur les
captures du jeu : des sentiers clairs qui montent en lacets le long d'un flanc et
passent d'un lieu habité à un autre.

#### Trois propriétés qui décident de toute l'architecture

**1. Un chemin se pose en dernier.** Il ne déforme pas le champ : il *tranche*
la colonne à son altitude, efface ce qui le surplombe de trop près — y compris
le socle d'un surplomb, d'où les **tunnels** — et jette un tablier au-dessus de
l'eau. L'ordre complet des recouvrements est désormais : **grotte et chemin
creusent, le surplomb remplit, l'étang mouille, le terrain porte.**

**2. Un chemin ne sort pas de sa zone.** C'est ce qui rend la couche abordable :
sinon une colonne devrait consulter le réseau des neuf zones voisines, donc les
construire toutes. Les zones se raccordent par des **portes** — un point de
passage sur chaque frontière, calculé à partir de l'identité de la frontière
elle-même, donc identique des deux côtés sans qu'aucune des deux zones ait
besoin de lire l'autre. Deux voisines tracent chacune leur moitié.

**3. Le tracé se relaxe, il ne se cherche pas.** Un A* sur une grille de hauteurs
demanderait des dizaines de milliers d'échantillons de colonne à 75 µs pièce.
Ici, chaque arête part d'une ligne droite et ses points intérieurs glissent
perpendiculairement, six fois, vers ce qui monte le moins. Ce n'est pas un
optimum, c'est un contournement — et c'est tout ce qu'on demande.

#### Chercher un itinéraire et épouser un sol ne sont pas la même échelle

C'est la seule erreur de conception du jalon, et elle s'est vue en capture :
**des tranchées de seize blocs à paroi verticale**. Avec un seul jalon de tracé
tous les 192 blocs, l'altitude du chemin entre deux jalons est une **corde** : le
terrain bombe au milieu, le chemin passe dessous, et la colonne est tranchée de
tout ce qui les sépare. Mesure : 167 blocs de sol pour un chemin à 151.

Le tracé se fait donc en deux temps, à deux mailles :

1. **l'itinéraire**, tous les 256 blocs, relaxé — chaque point y coûte deux
   échantillons de colonne par passe, donc la maille est grossière par
   construction ;
2. **le profil**, tous les 32 blocs : l'itinéraire est rééchantillonné, chaque
   point posé sur le sol, l'altitude lissée puis **bornée** à 4 blocs de
   déblai et 3 de remblai. Le bornage est repris une seconde fois **colonne par
   colonne**, parce qu'entre deux jalons de profil l'altitude reste une corde —
   4 colonnes de chaussée sur 340 dépassaient encore, et c'est exactement le
   genre d'écart qui devient une paroi au milieu d'un chemin. *Le chemin préfère
   onduler.*

**Au-dessus de l'eau, la référence n'est pas le fond mais la surface**, sans quoi
le profil plongerait dans chaque rivière et le tablier serait un escalier.

#### La chaussée : toujours en contrebas, et plus large

Deux réglages de la seconde passe, et le premier n'est pas cosmétique : la
chaussée est **toujours creusée d'au moins un bloc** sous le terrain qui la
borde. C'est ce qui lui donne son ombre portée et sa berge, donc ce qui la fait
lire comme un chemin plutôt que comme une bande de gravier peinte. Sur
l'accotement, la borne se relève avec le raccord, sinon le bord serait une
marche au lieu d'une pente. La demi-chaussée passe de 3 à **4,5 blocs**.

#### Les tunnels : un dégagement proportionnel, jamais une coupe en deux

Six blocs de dégagement sous quarante blocs de roche est un terrier. Sous un
massif, le dégagement vaut **55 % de la masse traversée**, avec deux bornes :
jamais moins que six blocs, et **jamais au point de laisser moins de huit blocs
de toit**. Sans la seconde, le chemin ne perce plus le massif — il le coupe en
deux et laisse une tranchée à ciel ouvert là où on attendait une arche.

#### Les franchissements : d'un pont à une levée

**Il n'y a plus de pont depuis le 2026-09-09**, et ce qui suit décrit ce qui
reste. La demande était directe — *les ponts sont trop compliqués à intégrer,
remplacer par remplir le gap par le chemin* — et elle a retiré un système
entier : le nœud de rendu `CWBridgeRenderer`, la travée à six voxels par bloc et
son script Blender, le tablier de bois, le garde-corps, et la condition « y
a-t-il un ouvrage ici » qu'il fallait porter jusqu'au générateur et jusqu'aux
deux dispersions.

Ce qui reste tient en une phrase : **là où le chemin rencontre l'eau, il la
comble.** Le remblai qui montait déjà à l'approche — la rampe d'accès du pont,
fabriquée par le lissage du profil — ne redescend plus. C'est une **levée**, deux
blocs au-dessus de la surface libre, et elle se termine par une rampe qui
descend rejoindre le sol d'au plus un bloc tous les deux.

> **Une levée est un barrage, et c'est dit en clair.** Ce monde ne simule pas
> l'écoulement, donc rien ne monte derrière elle ; mais une rivière coupée reste
> une rivière coupée. C'était l'argument qui avait fait choisir le pont le
> 2026-09-07 — *« la combler ferait un barrage »* — et il est écarté
> délibérément : un pont qui ne s'intègre pas coûte plus cher au paysage qu'une
> rivière coupée.

Le **relevé des franchissements** reste, et il ne sert plus à la même chose : il
disait *où poser du bois*, il dit maintenant *où le chemin remblaie au lieu de
creuser*. Détail complet et mesures en `nextsteps.md` §7nonies.2.

Et une erreur de conception que seule la capture pouvait montrer :

> **Le profil d'un chemin ne voit pas les rivières.** Il pose un jalon tous les
> 32 blocs ; une rivière de ce monde en fait six de large. Elle passe donc entre
> deux jalons neuf fois sur dix, et le premier relevé des franchissements n'a
> trouvé **aucun** des ponts qu'on voyait en jeu — la matière du tablier, elle,
> se décide colonne par colonne et les posait bien. On raffine donc, mais
> seulement là où il peut y avoir de l'eau : le champ de chenaux est déjà lu à
> chaque jalon et il est lisse, donc un jalon à trente blocs d'une rivière a déjà
> une valeur basse. *Un relevé grossier d'une chose fine ne se corrige pas en
> affinant tout ; il se corrige en affinant là où la chose peut être.*

#### Ce que ça rend, mesuré

Zone du départ, graine 2024 : **2 376 segments** de 32 blocs, 389 cellules
d'index, réseau construit en **350 ms** — une fois par zone, sur le fil qui la
demande, les autres attendant. Sur 340 colonnes de chaussée sondées, 14 sont sur
un pont, aucune ne tranche plus de quatre blocs, toutes ont leur dégagement de
six blocs libre, et rien n'y pousse.

**La chaussée est en gravier, tramé** dans la matière du lieu sur quatre blocs :
un chemin qui s'arrêterait sur un trait aurait l'air peint.

#### Ce que les deux dispersions ont dû apprendre

Comme au jalon 1.14 pour le creusement des étangs, et pour la même raison :
**flore et arbres poussent sur le sol remodelé**, pas sur celui du champ. Trois
règles s'ajoutent à leur boucle, et chacune répare un défaut qu'on aurait vu en
jeu :

- **rien ne pousse sur la chaussée** — c'est ce qui la rend lisible de loin ;
- **l'accotement suit le terrain remodelé**, sinon la première touffe de bord de
  route flotte ou s'enterre ;
- **ce qui pousse au-dessus d'un surplomb pousse sur son chapeau**, jamais sur
  le sol qu'il ensevelit ou qu'il ombrage. Une mesa porte ses arbres sur le dos
  et son ombre est nue — c'est ce que montrent les captures d'origine.

---

---

---

## Jalon 2 — Créatures et combat

| # | Système | Source | Taille | Statut |
|---|---|---|---|---|
| 2.1 | Modèle de créature, statistiques | `entity/Creature.cpp` | ~1 200 l | ⬜ |
| 2.2 | Arbre de comportement | `ai/SequentialBehavior` + nœuds | ~180 l | ⬜ |
| 2.3 | Déplacement, chemins | `RandomWalk`, `WalkPath`, `SpawnLocation` | ~700 l | ⬜ |
| 2.4 | Combat | `ai/CombatBehavior.cpp` | 2 100 l client / 4 000 l serveur | ⬜ |
| 2.5 | Compagnon, interactions | `Companion`, `RandomInteraction`, `LookAtPlayer` | ~1 000 l | ⬜ |
| 2.6 | Apparition | `world/Spawn.cpp` | | ⬜ |

Dépend de 1.6 (les points d'apparition sont accrochés aux éléments de tuile) et
de 1.8 (requêtes de collision sur les colonnes).

Le comportement de combat est la plus grosse fonction de jeu du dépôt ; la
version serveur fait le double de la version client, ce qui laisse penser que
c'est elle qui fait autorité. À porter depuis le serveur.

⛔ **Hors périmètre :** apparence des créatures. Les silhouettes, proportions et
palettes de Cube World sont de l'expression artistique. Le système porté est le
gréement et l'animation procédurale, pas les modèles.

---

## Jalon 3 — Joueur et boucle de jeu

| # | Système | Source | Statut |
|---|---|---|---|
| 3.1 | Contrôleur, caméra, physique | `control/GameController.cpp` (115 000 l) | ⬜ |
| 3.2 | Inventaire, objets | `ui/InventoryWidget`, `format_object_singular_name` | ⬜ |
| 3.3 | Compétences, progression | `ui/SkillsWidget` | ⬜ |
| 3.4 | Vol à voile, escalade, monture | `GameController` | ⬜ |

`GameController.cpp` est un agrégat de 115 000 lignes : à découper par
fonctionnalité et à porter par morceaux, jamais d'un bloc.

---

## Jalon 4 — Structures et contenu

| # | Système | Source | Statut |
|---|---|---|---|
| 4.1 | Placement de structures | `WorldInfo_placeStructure` @005f0ce0 | ⬜ |
| 4.2 | Donjons | `world/Dungeon.cpp` | ⬜ |
| 4.3 | Maisons, villages | `world/House.cpp`, `Field.cpp` | ⬜ |
| 4.4 | Quêtes, dialogues | `entity/QuestText`, `Speech.cpp` | ⬜ |

⛔ **Hors périmètre :** textes de dialogue et de quête, noms de lieux et de
personnages. Ce sont des œuvres écrites. On porte le *générateur* (grammaire,
tables de composition) et on fournit nos propres tables.

---

## Jalon 5 — Réseau

| # | Système | Source | Taille | Statut |
|---|---|---|---|---|
| 5.1 | Protocole, paquets | `net/Connection.cpp` | 604 l | ⬜ |
| 5.2 | Boucle serveur | `net/Server.cpp` | 275 l | ⬜ |
| 5.3 | Sérialisation d'entités | `EntityState_serializeToBuffer` | | ⬜ |

Le protocole est petit et bien délimité. Intérêt d'interopérabilité réel, mais
sans valeur tant que les jalons 2 et 3 ne sont pas là.

---

## Dette technique et outillage

| Sujet | Statut | Détail |
|---|---|---|
| Suite de tests headless | ✅ | **377 vérifications**, `tests/worldgen_test.gd` |
| Planche de validation des assets | ✅ | `scenes/model_portraits.tscn` : un modèle par capture, seul, deux angles, plus les arbres **montés** ; 84 sujets en 5,6 s |
| Gabarit d'échelle en jeu | ✅ | `src/demo/scale_board.gd`, capture automatique ; mires en blocs et modèles à la grille fine |
| Capture différée de la démo | ✅ | `TerrainDemo.auto_shot_delay` + `--quit-after` : regarder une couche sans piloter la fenêtre |
| Flore instanciée (MultiMesh par cellule) | ✅ | `src/worldgen/cw_flora_renderer.gd`, 1,1 ms/cellule hors fil principal |
| Groupement de la flore en grappes | ✅ | il n'y avait pas de mécanisme à écrire : la crête de bruit à 0,05 le produit seule (variance/moyenne 14,3 contre ~1) |
| Table de sélection du décor | ✅ | `src/worldgen/cw_decor_rules.gd` : deux crêtes à 0,01, neuf rôles, `docs/systems/02` §8.5-8.6 |
| Lacet libre du décor | ⬜ | trois rôles le demandent ; `CWVoxelModel` ne précalcule que quatre quarts de tour |
| Collision des modèles instanciés | 🔶 | **tout l'arbre est de la matière depuis le 2026-09-11** : houppiers, dômes, palmes et les cinq modèles entiers, dont le rocher géant, s'ajoutent aux troncs, branchages et filons. Il ne reste traversables que les **cactus de flore**, qui sont à 4 voxels par bloc et veulent une forme de physique, pas de la matière (jalon 3.1) |
| Éclairage et LOD des modèles instanciés | 🔶 | **l'arbre entier a rejoint le terrain** (le tronc en 1.11, le reste le 2026-09-11) : il est éclairé, se creuse et porte son ombre comme une colline. Ce qui reste instancié — la flore et les nuages — ne profite ni de l'éclairage voxel ni d'une réduction en distance ; `CWVoxelModel.reduced(n)` est prêt et n'a toujours aucun usage |
| Aperçu de la carte hors du jeu | ✅ | `tools/preview_map.gd`, vierge et parcourue |
| Mesure de la couche de surplombs | ✅ | `tools/mesa_stats.gd` : part des terres sous un chapeau, en porte-à-faux, en grotte, en roche de pente, plus l'histogramme des pentes |
| Repérage d'un surplomb, d'un canyon, d'un chemin | ✅ | `tools/find_mesa.gd`, `tools/find_canyon.gd`, `tools/find_path.gd` : trois points de vue prêts à passer à `--ici` / `--vers` |
| Viser une capture | ✅ | `--vers x z` oriente la caméra, `--altitude n` la lève. Sans les deux, une capture d'un objet posé à cent blocs est une capture de ce qui se trouvait dans l'autre sens |
| Isoler une couche au chargement | ✅ | `--sans-surplombs`, `--sans-chemins`, `--sans-falaise`, comme `tile_features` avant elles |
| Lot d'ouvrages (`assets/models/structures/`) | ➖ | **retiré le 2026-09-09** avec les ponts : la travée, son script Blender et son nœud de rendu. Les seuls modèles à 6 voxels par bloc sont désormais les petits props de flore |
| Souder les massifs au terrain (talus) | ⬜ | le pied d'un massif rencontre l'herbe sans transition ; un éboulis lui donnerait son assise |
| Piles de pont | ➖ | sans objet : il n'y a plus de pont, mais une **levée** |
| Collision des surplombs et des chemins | ✅ | gratuite : les deux sont de la **matière** dans les données du monde, comme le tronc depuis 1.11 |
| Cache disque des dalles de carte | ⬜ | 43 ms la dalle, recalculée à chaque session ; l'original la compresse en base |
| Inventaire des modèles `.vox` | ✅ | `tools/inspect_model.gd` : plages de palette, échelle par lot, et **compte de morceaux** |
| Aperçu rapproché des éléments | ✅ | `tools/preview_features.gd`, avec et sans la couche |
| Aperçus PNG (altitude, climat, chenaux) | ✅ | `user://worldgen_preview/` |
| Arrêt immédiat du streaming | ✅ | `CWVoxelGenerator.request_shutdown()`, 23 ms → 1 µs par bloc en file |
| Cache de colonnes | ✅ | 17 ms → 5 µs par bloc réutilisé |
| Débit de chargement | ✅ | vue 384 : > 3 min → **27 s** ; vue 768 : **120 s** |
| Portage du champ en GDExtension C++ | ⬜ | ~80 µs/colonne en GDScript ; **verrou de la vue lointaine**, voir ci-dessous |
| `VoxelStream` (sauvegarde du monde modifié) | ✅ | `VoxelStreamSQLite`, `save_generator_output = false` : seul le diff part sur le disque, 647 éditions = 20 Ko |
| LOD natif (`VoxelLodTerrain`) | ⛔ | testé, inutilisable avec un rendu en cubes — voir ci-dessous |
| Étage de terrain lointain (façon Distant Horizons) | ⬜ | bloqué par la vitesse d'échantillonnage |
| Intégration continue sur la suite headless | ⬜ | |

### Débit de chargement — ce qui a été mesuré

Le poste dominant est la **génération**, jamais le maillage : à 384 blocs de vue
le compteur montrait `gen 33880 / maillage 2`, c'est-à-dire un mailleur à
l'arrêt qui attend. Inutile donc de toucher au budget du fil principal ou à la
taille des blocs de maillage tant que ce déséquilibre tient.

Quatre corrections, dans l'ordre de leur effet :

1. **Doublons entre fils.** Les ~11 blocs verticaux d'une même colonne (x, z)
   partent ensemble dans la file et sont pris par des fils différents. Sans
   marqueur « en cours », ils manquaient tous le cache au même instant et
   recalculaient tous la même carte de hauteurs : le cache ne servait à rien
   pendant la phase de chargement, la seule qui compte. Le second arrivé attend
   désormais le premier.
2. **Plafond du cache trop bas.** 2 048 entrées pour une empreinte de 2 304 à
   384 blocs de vue : le cache s'auto-évinçait en boucle. Porté à 16 384, ce qui
   couvre une vue de 1 024 pour ~21 Mo.
3. **Distance aux arêtes calculée pour rien** depuis que les termes qui
   l'utilisent sont désactivés : 80 → 61 µs par colonne.
4. **Pool de fils** porté de 8 à `cœurs − 2` (14 ici) ; Voxel Tools n'en prend
   que la moitié par défaut, ce qui est prudent pour un générateur natif mais
   bride un générateur GDScript. ⚠️ **Cette correction était une erreur** : voir
   « la falaise des fils » ci-dessous. Le bon nombre est celui des cœurs
   *physiques*, pas des cœurs logiques.
5. **Index des clés du flux SQLite** (`set_key_cache_enabled`), mesuré le
   2026-09-05 — voir la section suivante, qui corrige le constat ci-dessus.

| distance de vue | temps de stabilisation | pic de tâches |
|---|---|---|
| 384 blocs | **16 s** (8 fils, flux avec index) | 35 000 |
| 768 blocs | **120 s** | 198 000 |

> **Ces nombres tiennent toujours — mais ils décrivent un chargement, pas un
> téléport.** Revérifié le 2026-09-06, même machine, même vue : **18 s pour
> 35 000 tâches** au point de départ, ce qui reproduit la ligne ci-dessus (les
> ~2 s de plus sont les 61 → 80 µs par colonne apportés depuis par `CWBiome` et
> les coulées de lave). Le même monde après un saut de biome — `-- --biome N`,
> c'est-à-dire la commande de toutes les captures — demande **43 s pour 70 000
> tâches** : un téléport charge deux fois plus de blocs qu'un démarrage, parce
> que la zone quittée est encore en file quand celle d'arrivée entre.
>
> C'est la nuance qui a failli coûter cher : mesuré au téléport, le chargement
> paraissait avoir triplé depuis le 2026-09-05, et le premier réflexe a été de
> chercher une régression qui n'existait pas. **Une mesure de chargement se
> prend au démarrage** ; le téléport a sa propre ligne, et elle est utile
> puisque c'est ce qu'on fait pour valider.

Le débit ne s'écroule pas quand l'empreinte grandit : 1 290 tâches/s à 384,
1 650 à 768. C'est le **nombre** de blocs qui explose — il croît comme le
produit des trois axes — pas leur coût unitaire. Doubler la distance de vue
multiplie donc l'attente par ~4,5, pas davantage.

Ces mesures s'affichent seules : l'ATH montre `gen N / maillage M` pendant le
chargement, et le temps de stabilisation part dans le journal au front
descendant. Page haut / Page bas règlent la distance en jeu.

**Limite pratique.** 768 blocs sont exploitables pour une session de test
(2 min d'attente initiale, puis fluide) ; au-delà, l'attente croît vite. C'est le
portage en GDExtension qui débloque la suite, pas l'optimisation de
l'ordonnancement : le pool est déjà saturé et le mailleur déjà à l'arrêt faute
de matière.

### Le flux de sauvegarde est passé devant la génération (2026-09-05)

Le constat d'ouverture — « le poste dominant est la génération » — a cessé
d'être vrai le jour où le jalon 1.8 a posé un `VoxelStreamSQLite` sur le
terrain, et personne ne l'a vu parce que l'ATH n'affiche que `gen` et
`maillage`. La file qui comptait était une troisième, invisible :

| | `streaming` | `generation` | stabilisation |
|---|---|---|---|
| flux, sans index de clés | 34 508 en attente | **14** (= le nombre de fils) | **39 s** |
| flux, index de clés | 33 029 en attente | 14 | **32 s** |
| aucun flux | 0 | 32 328 en attente | **29 s** |

Un `generation` bloqué à quatorze, c'est-à-dire exactement le nombre de fils,
n'est pas un pool saturé : c'est un pool **affamé**. Chaque bloc attendait une
requête SQLite avant d'être seulement mis en file de génération, et le
chargement était borné par le disque au lieu de l'être par le champ de terrain.

`VoxelStreamSQLite.set_key_cache_enabled(true)` tient en mémoire l'index des
clés présentes dans la base et répond « absent » sans la toucher. Il ne peut pas
se tromper ici : `save_generator_output = false`, donc la base ne contient que
des blocs édités. C'est une **méthode et non une propriété exportée**, ce qui
explique qu'elle soit passée inaperçue. Persistance revérifiée après coup :
creuser, quitter, relire — le bloc revient bien en air.

Il reste 3 s d'écart avec le monde sans flux, et elles sont structurelles : une
tâche de flux par bloc subsiste, même quand elle ne fait que consulter un
ensemble en mémoire. 34 500 tâches à ce prix, c'est ~8 % de débit en moins —
c'est ce que coûte la persistance, et le prix est honnête.

L'ATH affiche désormais les trois files — `flux N / gen N / maillage N` — et la
ligne de stabilisation dit si un flux est monté. Sans cela, un ralentissement de
ce côté serait resté invisible une seconde fois.

### La falaise des fils (2026-09-05)

Le pool avait été porté à `cœurs logiques − 2`, soit 14 sur cette machine, en
supposant que plus de fils ne peut pas nuire. C'est faux, et pas d'un peu.
Échantillonnage du champ sur une empreinte de 48 × 16 cartes de hauteurs, avec
de vrais `Thread` :

| fils | 1 | 4 | 6 | **8** | 10 | 12 | 14 |
|---|---|---|---|---|---|---|---|
| temps mur | 12,4 s | 5,7 s | 4,4 s | **3,2 s** | 7,9 s | 10,9 s | 13,5 s |
| coût par fil (µs/colonne) | 63 | 113 | 112 | 128 | 368 | 604 | 885 |

À quatorze fils, le travail est **plus lent qu'en mono-fil**. La falaise tombe
exactement entre 8 et 10, c'est-à-dire au passage du nombre de cœurs physiques
(16 fils logiques, 8 cœurs). Deux fils GDScript par cœur se disputent le cache
et l'allocateur, et le surcoût dépasse largement ce que le SMT rapporte. Un
témoin d'arithmétique purement locale, lui, monte bien à ×7,6 sur 14 fils : la
falaise est propre au travail du générateur, pas à la machine.

Confirmé en jeu, vue de 384 blocs :

| fils | 6 | **8** | 10 | 14 |
|---|---|---|---|---|
| stabilisation | 17,6 s | **16,2 s** | 20,7 s | 31,5 s |

Le pool prend donc la moitié des fils logiques (`TerrainDemo._pick_threads`, que
`generation_threads` permet de forcer sur une autre machine). **31,5 s → 16,2 s
pour un seul nombre changé**, et le temps CPU cumulé passe de 433 s à 127 s.

*Méthode, pour la prochaine fois :* trois de mes bancs successifs ont menti
avant celui-ci — l'un mesurait la taille du `WorkerThreadPool`, un autre des
`Thread.start` qui échouaient en silence parce que j'avais filtré les erreurs.
Un banc de parallélisme doit toujours porter un témoin dont on connaît d'avance
le résultat.

### La flore attend son sol

La flore se construisait en ~16 s là où le terrain en demandait 32 : le joueur
voyait des touffes flotter dans le vide en attendant que le sol les rejoigne, et
l'écart grandissait avec la distance de vue — donc empirait exactement là où on
veut aller. Une cellule attend désormais que les blocs de données soient chargés
sous ses plantes (`CWFloraRenderer.set_terrain`, `is_area_editable` sur
l'étendue verticale réelle des plantes, jamais sur la colonne entière : le
terrain ne charge qu'une tranche autour de l'observateur).

Les cellules pas encore prêtes tournent en fin de file plutôt que de bloquer
celles qui suivent — sans quoi un sommet hors de la tranche verticale arrêterait
toute la flore.

### Ce qui reste, et ce qui débloquerait vraiment

Après ces deux corrections, une vue de 384 blocs se stabilise en ~16 s, dont
l'essentiel est toujours l'échantillonnage du champ : 2 304 cartes de hauteurs à
68 µs la colonne, soit ~40 s de CPU mono-fil incompressibles en GDScript. Les
leviers d'ordonnancement sont épuisés ; ce qui reste est le **portage du champ en
GDExtension C++**, déjà identifié comme le verrou de la vue lointaine.

### Vue lointaine — état des lieux

Cube World se regarde de loin : les bandes de biomes et les massifs sont
lisibles à des kilomètres. Une vue de quelques centaines de blocs ne reproduit
pas ce comportement, donc la question est légitime dès maintenant.

**Le LOD natif de Voxel Tools ne répond pas au besoin.** Mesuré le 2026-09-03 :
`VoxelLodTerrain` accepte `VoxelMesherCubes` sans se plaindre et construit bien
la géométrie lointaine, mais **des blocs d'eau apparaissent en pleine plaine à
partir du LOD 1** — de larges dalles bleues horizontales, à des altitudes où le
terrain est de l'herbe. Le même point de vue en `VoxelTerrain` n'en montre
aucune. La cause exacte n'est pas établie : le canal utilisé est un *index* de
palette, une valeur qui ne survit à aucune réduction de résolution numérique,
mais il n'est pas démontré que ce soit bien là que la réduction se produit.
Ce qui est établi, c'est que le défaut est propre au mode LOD et qu'il rend le
rendu inutilisable tel quel.

Le basculement reste exposé (`TerrainDemo.use_lod`) pour revérifier après un
changement de version ou de mesher. À investiguer avant toute décision : où la
réduction de LOD a lieu (générateur appelé par niveau, ou sous-échantillonnage
du LOD 0), et si un canal séparé ou un mesher interpolant en espace couleur
règle le problème.

*Non lié :* le relief lointain paraît bleuté dans les deux modes. C'est
l'éclairage ambiant du ciel sur des faces détournées du soleil, pas un défaut de
LOD ; sujet de réglage d'ambiance, à traiter séparément.

**Ce qu'il faut retenir de Distant Horizons.** Son idée centrale n'est pas son
moteur de rendu, c'est son *modèle de données* : ne pas stocker des voxels au
loin, mais un profil de colonne (hauteur, couleur de surface, runs). Ce modèle
est déjà celui du générateur ici — `CWTerrainField.sample_column` rend
(altitude, température, humidité) et `ColumnPatch` est exactement une tuile de
profils. **Aucune dette d'architecture n'est en train de se créer** : l'étage
lointain se branchera sur ces primitives sans les modifier.

**Le vrai verrou est ailleurs.** Un anneau lointain de 2 km de rayon
échantillonné tous les 32 blocs représente ~16 000 colonnes, soit **~1,3 s** de
calcul au coût actuel ; le même anneau à 4 km tous les 16 blocs demande ~21 s.
Ce n'est pas la structure qui bloque, c'est les 80 µs par colonne. L'ordre des
travaux est donc :

1. porter `CWValueNoise` + `CWTerrainField` en GDExtension C++ (le champ est
   écrit pour être transposable ligne à ligne) ;
2. seulement ensuite, un maillage de terrain lointain construit à partir de
   `sample_column` seul — pas de voxels, une grille de hauteurs par grande
   tuile, la palette pour la couleur, du brouillard à la jonction ;
3. cache disque de cet étage lointain, à mutualiser avec le `VoxelStream`.

Construire l'étage 2 avant l'étape 1 reviendrait à bâtir une pyramide de LOD
au-dessus d'un échantillonneur trop lent : on multiplierait le problème au lieu
de le résoudre.

---

## Journal

| Date | Fait |
|---|---|
| 2026-09-10 (soir) | **Le monde a une heure.** Un cycle jour/nuit où **tout se déduit d'un scalaire dans `[0, 1)` par la seule fonction `CWDaylight.applique`** — rotation, énergie et couleur du soleil ; zénith, horizon et sol du ciel ; couleur et relief des nuages ; ambiante ; couleur, densité et diffusion du brouillard. C'est une contrainte, pas une commodité : deux points d'entrée donneraient une aube au ciel rose et au brouillard bleu, et le défaut ne se verrait qu'à l'aube. Les nuages sont un **bruit fractal en coordonnées de direction** (`src/demo/cw_sky.gdshader`) et non un dôme texturé — pas de géométrie, pas de plafond de couverture, et c'est la route qui donnera les ombres de nuages : la même fonction, échantillonnée au sol. `--heure h` se pose à une heure et fige le cycle, `--jour n` change sa durée, `--nuages c` la couverture ; **F2** fige, **F3**/**F4** reculent ou avancent d'une heure — *regarder une aube en temps réel n'est pas une méthode de réglage*. **Le doute sur l'éclairage cuit est levé dans le bon sens** : on craignait que la composante « ciel » à 255 de `CWLight` garde le monde clair la nuit ; ce n'est pas le cas, parce que le terrain **généré** ne passe jamais par `CWLight` — un champ de hauteurs est éclairé partout où on le voit — et que seul ce que le joueur a creusé porte de l'ombre cuite. Le voxel cuit est donc devenu un terme d'occlusion sans qu'on y touche, et une ombre reste une ombre à toute heure. **Trois réglages ont demandé une capture, et aucun ne se voyait dans le code.** (a) `fog_sky_affect` vaut **1** par défaut : le brouillard repeignait le ciel entier de sa couleur, dégradé, nuages et soleil disparus sous un aplat. La capture de midi rendait cela quand celle de minuit montrait le dégradé, simplement parce qu'à minuit le brouillard est de la couleur du ciel qu'il cachait — *un défaut qui se voit le jour et pas la nuit ressemble à un bug de shader ; c'en était un de réglage*. (b) La projection des nuages, `EYEDIR.xz / EYEDIR.y`, **diverge à l'horizon** : juste physiquement, illisible à l'écran, et c'est justement là qu'une vue à la première personne regarde. Un décalage au dénominateur borne la perspective au lieu de la laisser exploser. (c) Les deux bandes de `smoothstep` des nuages se lisaient contre `[0, 1]` alors que cinq octaves d'un bruit de valeur ne montent guère au-dessus de **0,72** : tout le nuage restait dans son fondu et dans sa teinte d'ombre, ce qui donnait des masses grises et ressemblait à un problème d'éclairage. |
| 2026-09-10 (suite) | **Le profil du chargement, et deux réglages que personne n'avait cherchés.** (1) `tools/profile_worldgen.gd` mesure poste par poste, ce que rien ne faisait. Résultat : la génération d'un pavé coûte **93,7 µs/colonne**, dont **77,6 pour le champ nu** (83 %) — la falaise 12 %, les chemins 5, les éléments 5 —, et à l'intérieur du champ c'est **le bruit** : `CWValueNoise.sample` coûte 3,08 µs et une colonne en fait une quinzaine, soit 46 µs, **la moitié du temps de génération dans une seule fonction de vingt lignes**. La cible du C++ est donc unique et chiffrable : un facteur deux sur le chargement, pas un facteur dix. (2) **La falaise des fils est plus bas qu'on ne croyait.** Le pool valait la moitié des processeurs logiques — huit — depuis le 2026-09-05 ; l'optimum est **six**, et huit était déjà au-delà de vingt-huit pour cent. Balayage : 4 → 53,4 s, 5 → 45,5, **6 → 42,2**, 7 → 43,4, 8 → 58,6, 12 et 16 → plus de 90. La règle laisse maintenant deux cœurs physiques au mailleur et au flux. Chargement d'une vue de 384 blocs sur la journée : **107,7 s → 55,4 → 42,0**. (3) Deux résultats **négatifs**, gardés parce qu'ils valent les positifs : l'assiette de la flore pèse 64 % de la cellule de dispersion, et la prendre en un seul `sample_patch` **ne change rien** (2 035 µs contre 2 025) — ce sont les quatre échantillons de champ qui coûtent, pas la comptabilité ; et l'ATH ne sortira pas de `terrain_demo.gd`, il lit dix-sept morceaux d'état de la démo, *un affichage qui est une vue sur tout n'est pas une couche*. (4) Deux erreurs de méthode corrigées en cours de route et écrites dans l'outil : `climate_at` passe par la colonne entière — le climat seul est `climate_blend` —, et une mesure de dispersion prise le long d'une diagonale facture aux cellules les constructions de zone qu'elle traverse, ce qui sortait 43 ms là où une cellule en coûte deux. (5) `CWDaylight`, `CWDemoMap` et `CWBiomeSearch` sortent de `terrain_demo.gd` : 1 147 → 928 lignes. |
| 2026-09-10 | **Les surplombs quittent le monde, et le fichier de reprise cesse d'être un journal.** (1) **Le retrait**, troisième du dépôt après la falaise et les ponts. Partent `CWMesa`, `CWMesaGrid`, les grottes — des tubes qui percent une masse, donc sans objet sans masse —, le porche et sa frange enherbée, les tunnels de chemin et leur alésage, le terme de masse de la fonction de coût de tracé, trois outils de repérage, deux suites de vérification : **−2 240 lignes**. `standing_top` et `standing_surface` disparaissent avec eux — le dessus praticable d'une colonne n'a plus qu'un modeleur, le chemin, et sa règle vit dans `CWPathNetwork.shaped_top`. La falaise survit, le réseau de chemins aussi. (2) **La mesure qui a changé la prémisse de la suite.** Le fichier annonçait 28,5 s pour stabiliser une vue de 384 blocs ; c'était le chiffre du 2026-09-08, et deux passes sur les massifs l'avaient porté à **107,7 s** sans que personne le refasse. Le retrait le ramène à **55,4 s**, et le coût par colonne de 88,4 à **75,8 µs** — celui du champ seul. *La couche de massifs était le premier poste du chargement, pas `sample_column`*, ce qui déplace la cible de la demande d'optimisation. D'où l'invariant n° 51 : une mesure de chargement se refait, elle ne se recopie pas. (3) **Un vrai défaut, trouvé par le retrait.** L'accord des deux écritures de la règle était exercé au cœur d'un massif ; en le repointant sur une chaussée, il a échoué : `generated_voxel` **ignorait les troncs estampés**. Le bloc généré rendait du bois, la requête ponctuelle de l'air, et `CWWorldEdits` interrogeait donc un monde sans arbres. Défaut depuis le jalon 1.11, invisible parce que les deux balayages qui tiennent l'invariant n° 18 tombaient l'un sur un bloc sans arbre, l'autre sur une mesa. Corrigé par `CWVoxelGenerator.trunk_at`, testé avant tout le reste puisque `_stamp_trunks` écrit après tous les remplissages. (4) **Le rangement documentaire.** `nextsteps.md` passe de **4 196 à 980 lignes** : le récit des sessions part en annexe de ce fichier, la référence d'authoring dans `docs/ASSETS.md`, et `CLAUDE.md` naît — 139 lignes, les commandes, les cinq invariants les plus chers, les trois règles de découpe. Une session peut désormais commencer sur 139 lignes au lieu d'en dépenser quatre mille avant d'ouvrir un fichier de code. Suite : **379 vérifications, 0 échec**. |
| 2026-09-09 | **Les six points de la veille, puis trois demandes d'une seconde session de jeu.** (1) **L'assiette d'un objet.** Un modele etait pose sur la hauteur de sa colonne d'ancrage alors que son empreinte fait plusieurs blocs : des que le terrain descendait sous un bord, ce bord flottait. On sonde les **quatre coins** — vingt-cinq colonnes etaient hors de prix, la dispersion etant le second poste du chargement —, on ecarte le candidat au-dela de deux blocs d'ecart, et sinon on pose sur le **minimum** : de la matiere enfouie ne se voit pas, un vide sous un caillou se voit de loin. 392 plantes sur 2 403 sont concernees ; les arbres le paient toutes, leur tronc etant ecrit dans le terrain depuis 1.11. (2) **La chaussee n'etait creusee qu'au bord.** Mesure de la coupe transversale, du milieu vers l'exterieur : -0,26 -0,27 -0,26 -0,27 -0,25 -0,25 -0,32 -0,43 -0,67 -0,94 -1,00 — l'**inverse** d'une tranchee, une levre au contour et rien au centre, et 35,3 % des colonnes de chaussee en remblai. La cause etait un **ordre**, pas une borne manquante : on interpolait vers le profil puis on rabattait, et l'echappatoire ajoutee le matin meme pour la rampe d'un pont supprimait le rabattement une colonne sur trois. On calcule desormais l'altitude de la chaussee **d'abord**, et l'accotement interpole vers elle : -1,26 au centre, **100 %** des colonnes creusees. (3) **Les ponts sont retires**, *trop compliques a integrer* : partent le noeud de rendu, la travee a six voxels par bloc, son script Blender, le tablier, le garde-corps et l'option `--sans-ponts`. A la place, une **levee** — le remblai qui montait deja ne redescend plus. C'est un barrage, et c'est assume : ce monde ne simule pas l'ecoulement, et un pont qui ne s'integre pas coute plus cher au paysage qu'une riviere coupee. Le releve des franchissements reste et change d'office ; il porte maintenant deux **rampes** qui descendent jusqu'a rencontrer le sol, sans quoi la culee ressautait de 5 blocs. Et parce qu'un releve suit l'axe du trace et ne voit pas toutes les mares, `shaped_top` prend la surface libre de **sa** colonne : *le releve donne la rampe, la colonne donne le plancher*. Resultat sur 63 franchissements : marche maximale a la culee **1 bloc**, aucune culee qui ressaute, **aucune** colonne noyee sur 3 643. (4) **Les massifs cessent d'etre des domes**, et la parenthese de la demande — *ne plus tenir compte de l'escalade du personnage* — etait la condition. Le contrat d'escalade ne bornait pas un reglage, il bornait tout : la hauteur plafonnait a 0,54 du rayon pour lui, l'amplitude des bruits etait **rabattue** sur 24 massifs sur 99, et le profil etait au carre pour rejoindre le sol tangentiellement — ce qui *est* la definition d'un dome. Cinq leviers le remplacent, tires par massif : **deformation du domaine** (on deplace le point avant de le mesurer, ce qui plie le contour au lieu de le faire onduler), **ellipse tournee**, **lobes angulaires**, **exposant de profil** qui descend a 0,35 pour un dessus plat et des flancs qui tombent, et des **gradins** de trois a neuf blocs sur un massif sur deux. L'amplitude d'un lobe ne se lit pas comme un rayon — elle s'ajoute a `1 - u²`, donc 0,34 ne deplacait le contour que de 16 % et les silhouettes restaient des patates ; a 0,80 le golfe est a -55 %. Le rejet rapide teste desormais **l'ellipse** et non son cercle circonscrit, qui vaut `stretch²` fois son aire : la couche coute **29,7 us/colonne contre 32,6**, donc la forme est plus riche et ne coute pas plus cher. Trois regressions que seule cette forme pouvait reveler : les sondages radiaux du contour partaient de `1,15 x rayon` quand le contour va maintenant a `2,3 x rayon`, donc ils commencaient **dans** la masse et aucune galerie n'etait plus posee ; le seuil d'une galerie pouvait tomber **dans un golfe** entre deux bras, ou elle s'ouvrait sur un couloir ferme ; et la condition de debouche se testait en flottants contre `h0 + 0,5` alors que le plancher d'une galerie vaut `plancher(h0) + 1` — un terrain a `h0 + 0,45` passait et bouchait la sortie. Graine 1337 : hauteur mediane **32 -> 43 blocs**, rapport du contour **2,34**, 21 massifs sur 74 a dessus plat, 36 a gradins. **409 verifications, 0 echec.** |
| 2026-09-08 | **Seconde passe sur les trois couches, sur six reproches faits en jeu.** (1) **Plusieurs teintes par matiere**, et c'est ce qui manquait au degrade : deux couleurs ne font pas un fondu au bloc pres, elles font un damier. Depuis le jalon 1.9, un voxel porte son **type** dans un canal et sa **couleur** dans l'autre, et le second est une couleur libre — rien n'oblige deux blocs d'herbe a etre de la meme teinte. Une prairie prend donc trois tons, et une frontiere cinq marches de fondu, pendant que le type, lui, bascule d'un coup. Le facteur de fondu est tire du **meme bruit** que le type, sans quoi le damier et le degrade se dephasent. Consequence sur un contrat ancien : la couleur d'un voxel n'est plus *exactement* celle de son type, et la verification demande desormais qu'elle en reste une **nuance plausible**. (2) **Les surplombs deviennent des massifs.** Le chapeau sur socle a tenu une journee : *le joueur doit pouvoir y monter*, et un chapeau qui deborde de son socle est fait pour qu'on ne le puisse pas. La forme est un dome deforme par deux bruits qui retombe a zero sur son contour. Trois choses la rendent gravissable, et les trois ont ete trouvees en mesurant : la hauteur se compte **depuis le sol de sa colonne** — la mesurer depuis le centre laissait une marche de **douze blocs** sur tout le contour —, le profil est **au carre**, ce qui annule la pente au raccord, et les frequences des deux bruits sont **relatives au rayon**, faute de quoi une grosse masse prend dix lobes et une petite un demi. Contrat mesure, pas suppose : vingt-quatre rayons balayes, **deux blocs** de marche maximum, et deux est le minimum atteignable. Et parce qu'un massif tout vert est une colline et non un relief, sa matiere se decide sur son **epaisseur** : herbe sur la frange, roche nue au coeur. (3) **Les grottes** : galeries de 55 a 130 % du rayon contre un tiers — **67 blocs** pour la plus courte —, axe **brise** de deux a quatre coudes, bouche **evasee** et **porche** de roche au-dessus. Deux defauts d'acces attrapes par la meme verification : partir de la premiere colonne epaisse emmurait le tube derriere le flanc, et *sortir de la masse ne suffit pas a voir le ciel* — un massif au pied d'un versant a des cotes ou le terrain remonte, donc la direction se **choisit** parmi huit. (4) **Les chemins** sont **toujours creuses d'un bloc** — c'est ce qui leur donne leur berge et leur ombre — et leur demi-chaussee passe de 3 a 4,5 blocs. (5) **Le degagement d'un tunnel est proportionnel a la masse traversee**, 55 %, avec un **toit d'au moins huit blocs** : sans lui, le chemin ne perce plus le massif, il le coupe en deux. (6) **Le lot d'ouvrages**, a **six voxels par bloc** : le tablier reste de la matiere — c'est le sol sur lequel on marchera — et l'ouvrage (platelage, longerons, garde-corps, poteaux) devient un modele instancie, avec un **lacet libre**, seul endroit du projet ou la grille d'un modele n'est pas alignee sur celle du monde. Une erreur de conception en chemin : *le profil d'un chemin ne voit pas les rivieres*, il pose un jalon tous les 32 blocs quand une riviere en fait six de large, et le premier releve n'a trouve aucun des ponts qu'on voyait en jeu. On raffine la ou le champ de chenaux dit qu'il peut y avoir de l'eau, soit moins d'un segment sur dix. **377 verifications, 0 echec.** Cout : 24,1 s les trois couches eteintes, **28,5 s** allumees. |
| 2026-09-07 | **Trois couches par-dessus le champ : les surplombs, leurs grottes, les chemins et leurs ponts — et la falaise qui revient.** Aucune n'est dans la source, les trois en-tetes le disent, et le jalon 1 a donc ete rouvert le lendemain de sa cloture. (1) **Les surplombs.** Une seconde nappe de matiere posee au-dessus du champ d'altitude, jamais dedans : un chapeau plat sur un disque deforme, dont le bord est une paroi verticale de 8 a 31 blocs, et un socle qui s'arrete avant lui. Jusqu'a **64 blocs de vide** sous un chapeau ; 2,04 % des terres sous un chapeau, 0,40 % en porte-a-faux. Trois formes — butte une fois sur deux, surplomb une sur trois, champignon une sur six —, parce qu'un seul profil rendait vingt champignons identiques. Ou ils sont : un bruit tres basse frequence donne au monde des **pays de canyons** et, entre eux, des buttes isolees. (2) **Les grottes**, et leur garantie est geometrique : l'entree est prise **sous le chapeau**, la ou il n'y a deja pas de matiere, et le plancher du tube est l'altitude du sol a cette entree — on entre de plain-pied dans un trou qui donne dehors. Une sur six traverse le socle : c'est l'arche. La verification le constate **sur le monde genere**, pas sur la regle. (3) **La falaise revient**, et c'est le premier systeme que ce depot retire puis retablit. Les deux raisons de son echec sont levees : la roche n'est plus seule — c'est la matiere des parois qui la dominent — et **la frontiere est tramee**. Reglage refait en capture : *a seuil bas, la roche de pente dessine des courbes de niveau*, parce que la pente d'un champ lisse est un champ lisse dont les valeurs fortes suivent les lignes de niveau ; `CLIFF_SLOPE_LO` passe de 0,22 a 0,34 et la roche tombe a 2,6 % des terres. (4) **Le degrade adouci**, demande explicitement : un **tramage** a deux frequences, et c'est la seconde qui travaille — 88,2 % d'accord entre colonnes voisines a mi-transition, donc des plaques et non du poivre-et-sel. **Quatre** frontieres l'emploient, dont la plus grande du monde : celle entre deux biomes, ou l'on ne trame pas deux matieres mais ou l'on **brouille le climat avant de le comparer aux seuils** — un desert et une prairie s'interpenetrent desormais sur une trentaine de blocs, et le biome *nomme*, lui, ne bouge pas. (5) **Les chemins.** Arbre couvrant sur les jalons d'une zone, quatre **portes** de frontiere dont la position est une fonction pure de la frontiere — donc identique des deux cotes sans qu'aucune zone ne lise l'autre —, trace relaxe en six passes qui contourne le relief. Le chemin est pose **en dernier** : il tranche la colonne, efface six blocs au-dessus (d'ou les **tunnels** dans les socles de surplomb) et jette un **tablier de bois** sur l'eau plutot que de la combler. La seule erreur de conception du jalon, vue en capture : *chercher un itineraire et epouser un sol ne se font pas a la meme echelle* — un jalon tous les 192 blocs faisait de l'altitude une corde, et le terrain bombait de seize blocs au-dessus d'elle. Deux mailles, 256 et 32, plus un bornage repris colonne par colonne. (6) **Ce que les deux dispersions ont du apprendre** : rien ne pousse sur la chaussee, l'accotement suit le terrain remodele, et ce qui pousse au-dessus d'un surplomb pousse **sur son chapeau**. (7) **Cout : +13 % de chargement** (22,2 a 25,1 s a 384 blocs de vue), dont 1,8 s pour la seule falaise — sa pente demande une colonne de plus sur chaque axe de l'empreinte. Trois bascules `overhangs` / `road_network` / `cliff_slope` isolent les trois couches, comme `tile_features` avant elles. `sample_column` n'a pas bouge. **377 verifications, 0 echec**, dont une suite nouvelle, `tests/relief_test.gd`. Vu en jeu sur une mesa, une entree de grotte, un chemin, un pont et un tunnel. |
| 2026-09-06 (soir, 4) | **Cinq corrections vues en jeu : le marais, les provinces climatiques, et trois sur l'eau.** (1) **Le marais n'est plus une matiere de biome.** C'etait la derniere frange d'humidite, au-dessus de 0,92 en Jungles, et elle avait survecu aux deux retraits du matin parce qu'elle *portait* quelque chose — le roseau pousse sur ce bloc et sur aucun autre. Ce qui l'a emporte est autre chose : *une Jungles annoncee « jungle » sur un sol de marais dit deux choses a la fois*, exactement comme l'herbe seche de Greenlands. **Le marais n'a pas disparu du monde** — il est devenu la matiere de **rive** des cours d'eau, ou un roseau se tient : il passe de 6,5 % du monde a 0,1 %, et d'une frange de climat a un lieu. (2) **Les provinces climatiques**, et c'est une creation de ce projet : la source tire le climat d'une zone independamment de ses voisines et prend un extreme une fois sur deux, d'ou *une Snowlands contre un desert*. Un bruit basse frequence sur la grille de zones decide desormais quel extreme et **a quel point** — au coeur d'une province l'extreme est celui de la source, au bord il glisse vers le tempere. La seconde moitie est celle qui compte : ne prendre que le signe aurait laisse une couture franche entre deux provinces, c'est-a-dire le meme defaut plus rare. **Le relief est identique au bloc pres** — `base_height` sort d'un bruit et tous les tirages du LCG sont conserves, `rng.coin()` etant toujours appele et sa valeur ignoree ; l'ocean rend 12 108 colonnes avant comme apres. Mesure : Deserts de **1,2 a 13,9 % des terres**, Snowlands de 35,8 a 13,9, Greenlands de 49,5 a 57,7 ; le **coin froid-sec du climat passe de 17,98 % a 0,00 %**, et les paires neige/desert a 4 096 unites de 6 a **0**. `biome_stats` porte la mesure de voisinage, a 4 096 unites et non a 256 — a 256 deux sondages tombent dans le meme climat et la mesure rendait zero avant comme apres. (3) **L'eau descend d'un bloc sous la rive.** A ras bord elle ne se lisait pas comme de l'eau mais comme une matiere bleue posee a plat. (4) **Les rivieres sont continues, et finissent en lacs.** Le decoupage venait de la rampe triangulaire, qui ne laissait passer l'eau que sur 60 % d'un palier : elle garde le **fond** et perd la **presence**. Et le seuil du chenal n'est plus constant — 0,02 en altitude, **0,055 au ras de la mer** : un reseau de chenaux ne dit pas ou est un bassin, mais il dit l'altitude, et *une riviere qui s'elargit en descendant est ce qu'on voit d'un bassin*. Fenetre de 64 blocs autour d'un point bas : **27 % d'eau**. (5) **Ni Deserts ni Lava Lands n'ont d'eau de surface**, ce qui n'est pas dans la source — elle n'a pas de biomes — mais se defend seul. **Consequence a laquelle il a fallu repondre** : l'eau partout dans la porte faisait disparaitre la rive, donc le sol humide, donc le roseau. La rive redevient la **bande exterieure du lit** (`POND_WATER_FRAC`), continue le long du cours d'eau la ou celle de la source apparaissait par plaques. Eau 2,77 % des terres, rive 0,58 %. **346 verifications, 0 echec**, cout inchange (mediane de cinq passes, 76,1 us). Vu en jeu sur une riviere de Greenlands et sur un desert. |
| 2026-09-06 (soir, 3) | **Jalon 1.14 : les lacs, et le jalon 1 est clos.** (1) **La porte est le champ de chenaux, a 0,02**, celui du jalon 1.4 : il ne manquait pas un champ, il manquait un seuil. L'eau est une seconde passe de `generateBiomeContent`, colonne par colonne, avec un niveau **quantifie au pas de 5** et une **rampe triangulaire** qui decide s'il y a de l'eau et quelle profondeur — d'ou des chapelets de mares le long des fonds de vallee et non une riviere continue. (2) **Trois corrections a notre propre note d'analyse, relevees en relisant la source pour l'ecrire**, et la premiere change le sens de la passe. **Le sol humide est la rive, pas le lit** : son ecriture est gardee par « le bloc qui se trouve la n'est pas de l'eau », garde qui echoue precisement quand il y en a. Le type 3 est donc l'anneau autour de chaque mare — beaucoup mieux, `FAMILIES_SURFACE` y faisant pousser des roseaux, et un roseau se tient sur la rive et non au fond. **Le lit remonte a `q + 5|t|` dans le dernier quart d'un palier**, ce qui evite une marche franche de cinq blocs a chaque bord. **Et la porte de la rampe est `t > 0,2` et non `t >= 0,4`**, par troncature entiere : 60 % du palier au lieu de 45 %, mesure a 58,4 % apres portage. *Un pseudo-code ecrit depuis un nom se relit avant d'etre porte.* (3) **Le creusement s'exprime en abaissement de colonne**, pas en passe separee : `column_profile` rend `(sol, eau_bas, eau_haut)` et `pond_span` isole l'arithmetique de la rampe, pure et testee seule. Cela regle du meme coup le piege annonce — les deux chemins rapides de `_generate_block` s'appuient sur `patch.lowest`, et prendre le minimum *apres* le profil suffit. (4) **`_sample` rend un `Vector4`** : le chenal sort avec l'altitude et le climat, il etait deja calcule, donc **zero echantillon de bruit de plus** ; `sample_column` garde son `Vector3` et les trente-cinq consommateurs n'ont pas bouge. (5) **Les deux dispersions savent nager**, et l'ATH aussi — il annoncait « sol 117 » au bord d'une mare dont le fond est a 111. Un test de la flore a attrape le changement de contrat tout seul : 145 plantes « flottantes » qui ne l'etaient pas, parce qu'il comparait au sol d'avant creusement. (6) **La rive n'est humide qu'en Jungles, et c'est assume** : le seul roseau du lot est `jungles/roseau`, et poser du sol humide ailleurs rendrait un anneau nu — *une matiere qui ne porte rien est un trou*, paye trois fois deja. La table lue est `FAMILIES_SURFACE_BIOME` ; le jour ou chaque biome aura son roseau, elle grandira et la rive suivra sans qu'on retouche au code. **Mesures** : porte 3,25 % des terres, **eau 1,90 %**, rive 1,35 %, creusement moyen 2,78 blocs, profondeur 1 a 4 blocs a un quart chacun. **Cout sous le bruit de mesure** — mediane de cinq passes, 76,4 us par colonne contre 75,7 sans, +0,9 % pour une dispersion de +-6 %. **344 verifications, 0 echec**, vu en jeu. |
| 2026-09-06 (soir, 2) | **Les lacs : la lecture qui bloquait est faite, et la reponse est plus grande que la question.** (1) **`terrain_generateColumnColor` rend la hauteur FINALE de la colonne.** Le test decisif annonce etait : consulte-t-elle la porte des chenaux ? Elle la consulte, et pas incidemment — elle en fait un lissage sur ses octaves de detail (`chan*4` borne a 1, smoothstep, au carre). Deux autres marques du meme corps suffiraient chacune : l'octave de detail a 1e-2 y est, et la couche d'elements de tuile aussi, au couple `+0x14018` / stride `0x68` deja releve trois fois par ce depot. (2) **Ce n'est pas une fonction voisine de la notre, c'est la notre.** Les quatre graines de deformation d'elements — 8432984, 90493, 3423, 112, a la frequence 0,0025 — sont mot pour mot `LIFT_SEED_X`, `FALLOFF_SEED_XZ`, `FALLOFF_SEED_ZX`, `FALLOFF_SEED_Z` et `FALLOFF_WARP_FREQ`. `terrain_generateColumnColor` (@005c5e20, client) et `World_baseHeightField` (@004f9b70, serveur) sont **la meme fonction dans les deux binaires**, celle du jalon 1.4. **Le niveau d'un etang est `sample_column(x, z).x`**, rien de nouveau a calculer. (3) **Deux corroborations hors du corps de la fonction.** Le binaire serveur nomme le meme appel **`World_riverClimateGate`** la ou le client dit `WorldInfo_sampleTerrainHeight` : deux noms proposes independamment, le second disant « porte de riviere » en toutes lettres — la lecture du champ de chenaux du jalon 1.4 est confirmee par son nom dans l'autre binaire. Et un appelant (`WorldInfo.cpp:2562`) fait `(int)(h+1)` puis interroge la colonne pour y poser un objet en refusant l'air et l'eau : on ne pose pas un objet a « ossature + 1 ». (4) **Le plan de portage y perd la moitie de son premier point** : pas d'ossature `cont` a extraire de `_height_from`, la hauteur est deja la. `_sample` passe quand meme en `Vector4`, mais la quatrieme composante porte le **chenal**, dont la passe a besoin deux fois — comme porte et dans le creusement des berges. Les six autres points sont inchanges. (5) **Trouve au passage, et ca contredit un raisonnement de ce depot** : la passe de contenu de cellule **precalcule une grille 257 x 257 de hauteurs** puis mesure la pente **a un bloc**, contre la colonne voisine en X et en Z, seuil 0,3. L'original ne paie donc pas trois colonnes par colonne, il paie une grille par cellule amortie sur 65 536 colonnes — et « une pente d'un bloc ne decrit pas une falaise » est dementi par la source, qui mesure exactement a un bloc. **Cela ne rouvre pas la falaise**, retiree sur le rendu et non sur la mesure ; c'est note pour le jour ou le sujet reviendra. Reste non lu : `terrain_rockColor_blend` (@005c7140), fonction distincte de `terrain_surfaceColor_blend`, que le drapeau declenche quand la colonne **n'est pas** raide — l'inverse de ce que son nom laisse attendre, et les deux noms sont donnes « confiance moyenne ». Analyse : `docs/systems/02` Sec. 10.4 et 10.5. Aucun code touche. |
| 2026-09-06 (soir) | **La falaise est retiree, une demi-journee apres avoir ete portee.** Demande en une phrase — *au final ca ne rend pas si bien que ca en jeu* — et c'est **le premier systeme que ce projet defait sans qu'il y ait ni bogue ni erreur d'analyse** : la regle etait bien dans la source, la pente etait mesuree et non devinee, les trois verifications passaient, le surcout etait sous le bruit de mesure. (1) **Ce qui a manque n'etait dans aucun test, et les mesures du matin le disaient deja.** A 2,0 — quarante-cinq degres — la regle rendait 0,62 % des terres, et on avait lu « le seuil est trop haut » la ou il fallait lire **« il n'y a pas de falaise dans ce terrain »**. Le monde a un denivele maximal de 0,65 bloc d'une colonne a la suivante ; baisser le seuil a 1,0 n'a pas trouve de parois, il a **teinte des flancs a vingt-sept degres**, et de la roche grise sur un flanc vert se lit comme une tache, pas comme une paroi. *Une falaise ne se peint pas, elle se taille* — il faudra un terme de terrasse dans `_height_from` avant que `CWPalette` ait quoi que ce soit a habiller. (2) **C'est le meme defaut de methode que les bandes d'altitude, retirees le matin meme, pris par un troisieme bout** : regle defendable, tests verts, et un echec que seul un ecran montre. Les bandes ne *portaient* rien, la falaise ne *ressemblait* a rien. (3) **Retrait complet** : `CLIFF_STEP`, `CLIFF_SLOPE_REF`, le treillis et son cache a deux generations, `cliff_factor`, `CWPalette.CLIFF_RIDGE`, le septieme parametre de `surface_of` et `surface_index` sur ses six sites d'appel, l'histogramme de `biome_stats` et les trois verifications de `decor_test`. **Les invariants n° 37 et 38 tombent avec la regle qu'ils gardaient**, et l'ancien n° 39 — les deux graines — devient le n° 37. Les mesures, elles, sont **gardees en toutes lettres** dans `ROADMAP` §1.13 et `nextsteps` §7ter.4 : elles decrivent le terrain et pas la regle, et elles resserviront telles quelles. `--ici x z` survit a ce qui l'avait motive. (4) **Deux notes devenues fausses sont corrigees au passage** dans `cw_palette.gd` : celle des trois constantes de ligne de neige, qui annoncait la falaise comme a venir, et celle de `surface_of`, qui decrivait encore trois bandes d'altitude alors qu'il n'en reste qu'une — la plage. **329 verifications, 0 echec** (les trois de la falaise en moins), colonne redescendue de 76,9 a **73,8 us**, repartition des matieres identique au chiffre pres a celle d'avant le portage — herbe 37,2 %, neige 27,0 %, gravier 23,9 %, marais 6,6 %, scorie 2,4 %, sable 2,0 %, jungle 0,5 %, magma 0,5 %, **plus une colonne de roche** hors Lava Lands. Verifie en capture sur Greenlands. |
| 2026-09-06 (matin, 4) | **Les lacs : l'algorithme complet, et une decision d'architecture deux fois plus petite qu'annoncee.** (1) **La porte de l'eau est le champ de chenaux, que ce projet porte depuis le jalon 1.4.** `WorldInfo_sampleTerrainHeight` (@005f9340) ne lit aucune hauteur : c'est `|bruit(1e-3) + bruit(1e-2)x0,1|`, module par un bruit non graine, plus un terme de crete — mot pour mot `CWTerrainField._channel`. *Il ne manquait pas un champ, il manquait un seuil* : 0,02. La feuille de route ecrivait « le reseau de chenaux creuse bien les vallees, mais rien ne les remplit » ; ce qui les remplit est le meme reseau. **Mesure avant d'ecrire** : 3,40 % des terres passent la porte, et la rampe triangulaire n'en garde que 45 %, soit ~1,5 % des terres en eau, en chapelets le long des fonds de vallee. Ni vide ni envahissant — la verification valait d'etre faite, c'est la lecon de la premiere regle de Lava Lands. (2) **L'algorithme est complet** : niveau quantifie au pas de 5, rampe triangulaire `t` sur la position dans le palier, remplissage de `[q - 5t + 2, q]` en eau si `t >= 0,4`, **sol humide (type 3) en q** — ce qui ferme une question ouverte depuis le jalon 1.7, `FAMILIES_SURFACE` etant la seule exception attachee a une matiere et personne ne sachant qui produisait cette matiere —, une chance sur 200 d'un objet sur la rive, puis **creusement des berges** de `q+1` a `niveau + 5x(1-(50v)^3) + bruit` : un bol maximal au centre du chenal et nul au bord de la porte. Sans ces quatre dernieres lignes l'eau serait enterree. (3) **La decision d'architecture est tranchee, et elle etait deux fois plus petite qu'annoncee.** La source ecrit l'eau comme matiere — l'issue n° 2 des trois, les deux autres etant nos inventions. Mais surtout : **ce projet ecrit deja l'eau dans les donnees**, `voxel_of` rendant `water_index` pour tout `top < y <= sea` ; sa note le dit en toutes lettres depuis le jalon 1.8. Ce qui est global n'est donc pas le stockage mais **le niveau**, un scalaire a rendre local. Il n'y a pas de bascule matiere/vide a faire. (4) **`Terrain_sampleHeightAtWorldXY` (@005989d0) est un treizieme nom trompeur** : elle ne lit aucune altitude, elle ne rend une valeur que dans les cellules de region de type 1 et zero partout ailleurs — une exclusion locale, pas un garde-fou. (5) **Un seul verrou reste, et c'est une lecture, pas un choix** : quelle hauteur `terrain_generateColumnColor` rend, la finale ou l'ossature continentale. C'est le niveau de l'eau, et l'ecart se voit. Plan de portage en sept points dans `nextsteps.md`, §7bis.2. Aucun code touche, 332 verifications. |
| 2026-09-06 (matin, 3) | **Les lacs : la fonction designee n'etait pas la bonne, et l'eau etait ailleurs.** (1) **`World_generateWaterOrPathFeature` (@005df960) ne fait ni eau ni chemin** — c'est le **douzieme nom trompeur** du depot d'analyse. Ses 2 025 lignes batissent un grand objet de vegetation en sept varietes : sept `paintSphere`, cinq `World_generateFoliageBlob`, huit `WorldInfo_placeStructure` en quatre rotations, et une variete qui est une **spirale** de trente disques sur quatre tours et demi. La preuve tient dans un octet : les seuls types qu'elle ecrit sont `0x27` et `0x28`, soit — le bit `0x20` etant un drapeau — les types **7 (bois) et 8 (feuillage)**, et c'est `World_generateFoliageBlob`, dont le nom est sur, qui ecrit le second. (2) **Consequence : l'element de tuile 12 n'est pas un plan d'eau**, contrairement a ce que `docs/systems/02` §4 affirmait avec « confiance haute ». La confiance portait sur *quel appel* le type 12 fait — juste et verifie — et non sur *ce que cet appel fait*, qui n'etait qu'un nom emprunte. C'est la douzieme fois, et la premiere ou l'erreur avait traverse jusqu'a une table de ce projet. (3) **L'eau est ecrite dans `WorldInfo_generateBiomeContent`**, la fonction deja portee pour la flore, dans une **autre passe** de la meme cellule : porte tres etroite (un champ normalise sous 0,02), niveau rendu par `terrain_generateColumnColor` — qui rend une hauteur, correction deja notee —, **quantifie au pas de 5**, puis remplissage vertical de `{0, 0, 255x(1-t), type 2}`. (4) **La question d'architecture que la feuille de route gardait ouverte est donc tranchee par la source, et par la deuxieme de ses trois issues : l'eau est de la matiere ecrite**, avec un niveau local et par paliers. Les deux autres issues etaient nos inventions. Le cout annonce ne bouge pas — la regle d'effacement du jalon 1.8 tombe, et avec elle `World_getBlockAt` et `CWWorldEdits.erase_value` — mais on sait maintenant quoi ecrire au lieu de choisir entre trois paris. (5) **Et les chemins sortent du jalon** : aucune des sept varietes ne trace quoi que ce soit entre deux points, ce qui confirme la correction du jalon 1.6. Un reseau reliant les bourgs serait une creation de ce projet. Analyse complete : `docs/systems/02`, §10. Aucun code touche, aucune verification changee. |
| 2026-09-06 (matin, 2) | **Jalon 1.13 : la falaise, et trois assets retires.** (1) **La cinquieme et derniere regle de la table de surface d'origine est portee.** `terrain_surfaceColor_blend` force le bloc 6 — la roche — quand « le facteur de falaise depasse 0,5 » ; le seuil est relevé, la *mesure* est de ce projet. Elle referme un trou ouvert volontairement la veille : les bandes d'altitude avaient ete retirees parce qu'une matiere qui ne porte rien est un trou dans le monde, et le remede etait trop large — une montagne a de la roche sur ses **flancs**, pas sur ses sommets plats. **L'exception est la pente, pas l'altitude.** (2) **La pente se prend sur un treillis de 4 blocs**, dont les sommets sont partages : seize colonnes se repartissent quatre echantillons, en cache. Prendre la colonne voisine aurait triple le cout d'une colonne — le verrou du chargement — *et* donne un moins bon resultat, l'octave de detail montant et redescendant partout, y compris en pleine plaine. Borne haute du surcout : +6 % ; mesure, +1 %, sous le bruit de mesure (±6 % d'une passe a l'autre). (3) **Deux mesures ont corrige deux intuitions.** Premier essai a quarante-cinq degres : **0,62 % des terres**, c'est-a-dire rien. La cause n'est pas le treillis mais le terrain — sur huit mille colonnes en ligne, le plus grand denivele d'un bloc au suivant est de **0,65 bloc** ; un relief fait de bruit de valeur a interpolation cosinus est lisse par construction, et ce qu'il a de plus raide est un flanc. A 1,0 la roche prend 4,4 % des terres. Et le pas du treillis, essaye a 8, est ramene a 4 : la part qui bascule ne bouge pas (4,5 contre 4,4 %) mais la **queue** de la distribution se remplit quinze fois, un pas long mesurant le flanc et non la paroi. Tranche sur capture — a huit, la frontiere roche/herbe est un decoupage a huit blocs pose en travers de terrasses qui en font trois. (4) **`surface_of` prend un septieme parametre, sans valeur par defaut** (invariant n° 37) : un defaut a zero aurait laisse compiler les sept sites d'appel et rendu un monde sans une falaise, que rien n'aurait signale. L'ATH de la demo est celui qu'on oublie — il n'est dans aucun test. (5) **Trois assets retires et deux refaits, demandes le meme jour.** Les deux grands arbres de Snowlands : un montage GRAND se lit a l'etalement de ses cinq masses, une taiga se lit a ses fleches, et les peindre en froid n'y changeait rien. Le `cactus_geant` : a un voxel par bloc un saguaro n'a ni cannelure ni epine, il a la forme que la grille lui laisse. Le desert garde ses cactus par la couche de flore, ou ils sont refaits a 4 voxels par bloc — un saguaro cannele de 4 blocs et un **figuier de barbarie**, qui est deja le nom que `CWFloraDrops` leur donne depuis le jalon 1.7 sans qu'aucun n'en ait eu la forme. (6) **La densite de flore baisse de 40 %, uniformement.** Le reglage du jalon 1.12 avait vu juste et pas assez loin : on ne compare pas une densite a une densite, on la compare a la **surface de sol qui reste libre**. **332 verifications, 0 echec**, verifie en capture sur Greenlands, Snowlands et Deserts. |
| 2026-09-06 (nuit, 2) | **Une seconde grille pour la flore, la fleche des coniferes, et les bandes d'altitude.** (1) **Quatre voxels par bloc etait juste pour la moitie du lot.** Un buisson, un cactus, un champignon sont des *masses* : leur forme est leur volume, et un volume se lit a n'importe quelle resolution. Ce qui s'y perdait, ce sont les objets **dont la forme tient dans un trait** — une touffe est cinq lignes, une fleur une tige et une corolle, et a quatre voxels une corolle n'est plus qu'une croix de cinq. **Quinze modeles passent a six voxels par bloc** (herbes, fleurs, ginseng, roseau), le reste garde quatre ; une touffe passe de sept a onze voxels sans revenir au cheveu, un brin faisant un sixieme de bloc et non un treizieme. **Consequence d'architecture** : la grille n'est plus decidee par la bibliotheque mais **par modele** (`CWModelLibrary.GRILLE_FINE`, `_grid_of`). Cette table et la colonne `FIN` du catalogue du generateur sont deux sources qui doivent s'accorder — une divergence sort la plante a une taille fausse d'un facteur un et demi, assez pour se voir, pas assez pour qu'on remonte a la cause ; deux verifications tiennent les deux sens. Une **liste** et non une regle sur le role, parce que le partage passe par le role a deux modeles pres et que ces deux-la suffisent a le disqualifier (`feuille_large` est un COUVERT mais c'est une feuille, `herbe_de_lave` est rangee en SOUS_BOIS alors que c'en est). (2) **La fleche des coniferes etait une boule**, et le profil en Z le disait mot pour mot : sur `sapin_enneige`, 9, 9, **1**, 5, **9**, 5, 1 — la silhouette se pincait a un voxel puis regonflait a neuf. Deux causes, et il fallait les deux : le fut se reduisait a un fil entre les deux derniers etages (sous un rayon de 1,0, un disque ne pose plus qu'un voxel), et **la fleche etait plus large que l'etage qui la portait** — un rayon constant de 1,8 contre un dernier etage a 1,3-1,5. *Une pointe qui s'elargit avant de se fermer est une boule, par definition.* Le rayon haut du fut est planchei a 1,0 et la fleche part de l'**avant-dernier** etage en **remplacant le dernier** : rayons strictement decroissants, silhouette monotone, et l'arbre perd exactement un bloc — ce qui etait l'autre moitie de la demande. C'est la **troisieme** reprise du sommet des coniferes en trois jours, et a chaque fois le diagnostic etait juste et le remede partiel parce qu'il traitait le symptome visible sans regarder le profil entier. (3) **Les bandes d'altitude sont retirees** : plus de roche nue ni de calotte de neige hors des biomes dont c'est la matiere. **Le motif n'est pas celui des franges d'humidite** retirees plus tot le meme jour, et c'est ce qui rend le cas interessant : les franges se *contredisaient* (« Greenlands » sur un sol kaki), les bandes non — une montagne a de la roche, le raisonnement de vraisemblance etait bon. Elles ne **portaient rien** : `decor_allowed` refuse le decor sur la roche et la neige hors Snowlands, donc chaque relief un peu haut rendait un plateau nu ou l'on marchait sans rien rencontrer. *Une matiere qui ne porte rien n'est pas un sous-biome, c'est un trou dans le monde* — et le raisonnement de vraisemblance tenait tant qu'on regardait une carte de hauteurs, pas des qu'on marche dessus. Les trois constantes restent pour Lava Lands, dont la regle decrit un volcan et non une altitude, et serviront de point de depart le jour ou la **falaise** aura la sienne — ce sera une pente a mesurer, et c'est probablement la que la roche nue doit revenir. Repartition mesuree : herbe 37,2 %, neige 27,0 %, gravier 23,9 %, marais 6,6 %, scorie 2,4 %, sable 2,0 %, jungle 0,5 %, magma 0,5 % — **plus une seule colonne de roche** hors Lava Lands. Le nouveau balayage de `decor_test` refuse la formulation generale du defaut : aucun biome hors Oceans et Lava Lands ne produit une matiere que `decor_allowed` rejette. **315 verifications, 0 echec**, verifie en capture sur Greenlands et Snowlands. |
| 2026-09-06 (nuit) | **Trois remaniements de rendu, tous decides en regardant le jeu.** (1) **La flore passe a 4 voxels par bloc, et c'est le premier ecart assume entre ce projet et une valeur mesuree dans l'original.** Le lot avait ete regenere le matin « avec moins de detail » — deux fois et demie plus grand, cinq brins au lieu de onze — et le resultat en jeu etait *indiscernable*. Verifie avant de rien changer : les `.vox` du disque etaient octet pour octet ceux du generateur, donc le lot avait bien ete refait et c'est le remede qui ne portait pas. **Il agissait sur le nombre d'elements, et le defaut etait dans la maille** : a 40/3 voxels par bloc un brin fait 0,08 bloc, soit un cheveu a cote d'un cube de terrain, et cinq cheveux au lieu de onze font une touffe plus claire, pas plus grosse. Aucun reglage d'un lot dessine a cette finesse ne pouvait donner ce qu'on cherchait. Le lot est redessine a **4 voxels par bloc** — `tools/blender/flore_blocs.py`, exactement comme `arbres_blocs.py` trois jours plus tot et pour la meme raison, *les formes sont a repenser, pas a reduire* — et le generateur passe en **Python pur**. La taille des plantes **en blocs** ne bouge pas, et l'enveloppe de `tests/flora_test.gd` non plus, parce qu'elle est dite en blocs : le genre de detail qui ne se remarque que le jour ou il paye. 3/40 n'est pas conteste — c'est bien l'echelle du decor de l'alpha ; c'est le rendu qui la refuse, et la note le dit dans ce sens-la (`CWVoxelModel.VOXELS_PER_BLOCK_FLORE`). Lot a **38 modeles**. (2) **Le role `CAILLOU` est supprime**, et les quatre blocs erratiques avec lui — dont le `deserts/caillou_gres` produit le matin meme. Disperses a la densite de la flore, ils rendaient des **champs de rochers** ou l'on ne passait plus. La cause est la lecon du matin prise par l'autre bout : on avait grossi le caillou de 8 a 30 voxels **sans toucher a sa densite**, reglee quand il faisait la taille d'un galet. *Changer une taille, c'est changer une densite* — invariant n° 33, et aucun test ne peut l'attraper, une densite trop forte etant une densite valide. Le mineral pose du monde est desormais le seul `rocher_geant`, qui passe par la couche des arbres : 14 blocs d'espacement, poids 0,05. (3) **Un biome n'a plus qu'une matiere de plaine** : `GRASS_DRY` et `TUNDRA` sont retirees de `surface_of`. C'etaient les deux franges d'humidite heritees d'avant 1.12, et le defaut se voyait a l'ATH avant le sol — « Greenlands / herbe seche » sur un sol kaki, un nom de biome et une couleur qui se contredisent. Depuis que `CWBiome` classe le climat, une seconde matiere de plaine ne dit rien que le biome ne dise deja ; les trois bandes d'altitude restent, elles disent autre chose. **Les deux index restent alloues** — les liberer decalerait les plages 14-19, 20-24 et 25-27 peintes dans les 62 `.vox` du depot, soit l'arbitrage de l'invariant n° 31 tranche dans le meme sens ; aucun modele ne les employait, verifie avant. Un balayage de `tests/decor_test.gd` refuse desormais que `surface_of` les rende, sur 4 096 climats x 6 biomes x 6 altitudes. Au passage, `herbe_seche` et `broussaille` quittent la rampe « automne » : une tache orange sur une prairie desormais toujours verte, c'etait l'invariant n° 29 transpose de Snowlands a Greenlands. **313 verifications, 0 echec**, verifie en capture sur Greenlands et Deserts. |
| 2026-09-06 (soir) | **Les trois defauts de pose vus en jeu apres le commit du jalon 1.12, corriges.** (1) **La fleche des coniferes flottait, et ce n'etait pas elle qui etait mal placee.** Les deux derniers etages du `pin` sont espaces de 2,8 blocs pour un bloc d'epaisseur, et le fut — raccourci a 0,82 de la hauteur le matin meme, pour ne pas depasser du feuillage — ne comblait plus l'ecart : les trois quarts superieurs de l'arbre flottaient en un seul morceau. Le fut monte desormais **jusqu'au dernier etage pose**, ce qui est la seule des deux contraintes qui compte et la seule qui se dise sans fraction. (2) **La capture d'apres a montre la moitie qui manquait au diagnostic.** Le profil en Z disait « plus de trou » et il avait raison ; il ne pouvait rien dire du fait que le trou etait comble **en ecorce**, et que les deux a trois blocs entre etages laissaient voir une colonne brune — l'arbre se lisait comme une pile d'assiettes enfilees sur un piquet. Le commentaire du code portait deja la regle juste, « un conifere ne montre son tronc qu'entre le sol et son premier etage », et le code ne la faisait pas. *Une mesure ne repond qu'a la question qu'on lui pose ; la capture sert aussi a verifier le remede.* (3) **Les palmes flottaient : l'ancre est en haut du modele.** Une paire de frondes retombe, donc son point d'attache est son voxel le plus **haut**, et `_piece` pose une piece par sa base — la couronne se posait `height - 1` blocs au-dessus du stipe, trois pour le dattier, quatre pour le palmier de jungle. Le decalage d'attache avait ete traite **dans le dessin** la veille (une paire est centree sur son attache) et l'affaire passait pour close : elle ne l'etait que sur deux axes sur trois. D'ou l'invariant n° 32 — *une correction partielle est plus dangereuse qu'une absence de correction, parce qu'elle ferme la question.* (4) **Ne garder que les gros cailloux** : `greenlands/caillou_02` (dalle plate de 19 voxels) et `deserts/gres` (colonne a chapeau de 34) supprimes. Le second etait le seul modele du role `CAILLOU` de Deserts ; plutot que de vider le role — ce que `tests/decor_test.gd` refuse, invariant n° 22 —, il est **remplace** par `deserts/caillou_gres`, un bloc erratique a la matiere du gres. Les quatre mineraux du monde sont maintenant une famille : meme masse basse et large, quatre matieres. *Un lot n'est pas une collection de bonnes idees.* Lot de flore a **42 modeles**. **312 verifications, 0 echec**, et les trois remedes verifies en capture sur Greenlands, Deserts et Jungles. |
| 2026-09-06 | **Jalon 1.12 : les six biomes, et la refonte des deux lots d'assets.** (1) **Une couche de classification, pas un renommage.** « Biome » voulait dire `CWPalette.surface_index`, neuf *matieres de bloc* qui servaient aussi de cle aux tables de contenu ; les deux notions y etaient confondues, et une crete rocheuse au-dessus d'une prairie s'y rangeait comme un « biome roche ». `CWBiome.at` decide desormais **six zones climatiques** — Greenlands, Snowlands, Deserts, Jungles, Lava Lands, Oceans — et `CWPalette.surface_of` en deduit la matiere selon l'altitude ; `CWDecorRules.decor_allowed` fait le filtre que l'ancienne table par matiere faisait implicitement, avec un cas a deux sens : la neige est **le sol** d'une Snowlands et une calotte de sommet partout ailleurs. (2) **Le champ de climat a contredit trois seuils, et c'est `tools/biome_stats.gd` qui l'a dit.** Il est **bimodal** : ses quatre coins portent 48 % des terres, un point chaud est soit tres sec soit tres humide, jamais entre les deux. La premiere regle de Lava Lands prenait justement cette bande vide et rendait **60 colonnes sur 147 456** ; baisser son seuil de 0,88 a 0,80 l'a portee a 64. *Une regle peut etre juste et vide.* La regle qui marche decoupe le coin chaud-sec au-dessus de 0,97, ou le melange climatique ne produit que le **coeur d'une region a l'extreme** — Lava Lands est donc un coeur de region entoure de son propre desert, ce qu'un tirage par colonne n'aurait pas donne, et « loin du spawn » suit sans qu'on le demande. Repartition mesuree : Greenlands 42,5 % des terres, Snowlands 24,5 %, Jungles 21,4 %, Deserts 9,7 %, Lava Lands 1,9 %, Oceans 28,8 % du monde. (3) **Deux types de bloc de plus, sans deplacer une frontiere** : `MAGMA` et `SCORIA` prennent les entrees 30 et 31, deja peintes en lave et **les deux seules de la reserve terrain qu'aucun modele n'employait** — l'operation de l'invariant n° 26 n'est pas repayee. Les coulees sont une crete de bruit, seule regle de surface qui ait besoin de la position : c'est pour elle que `surface_of` prend desormais (x, z). (4) **Les 24 arbres passent a 1 voxel = 1 bloc**, ce que `nextsteps.md` §6 demandait depuis la veille. `VOXELS_PER_BLOCK` devient un champ par bibliotheque, l'espacement passe de 7 a 14 blocs et les densites suivent, et les formes sont **repensees et non reduites** — un conifere est une pile de disques plats, un houppier quelques dizaines de cubes. Le generateur en sort en Python pur : a cette maille, Blender n'apporte rien. (5) **Les 43 modeles de flore gardent 3/40 et grandissent** : a l'epaule et non au genou, cinq brins et non vingt, deux voxels d'epaisseur par brin. La cause premiere etait une ligne fausse de `MODELS.md` §1, corrigee **avant** la regeneration. (6) **Cinq defauts trouves en capture, aucun visible en headless** : le fut des coniferes ressortait au-dessus du feuillage ; la scorie rendait un rose saumon dont la coulee ne se detachait pas ; le magma se confondait avec le sable du desert ; **cinq modeles de Snowlands sur six** puisaient dans la rampe « automne » et ressortaient en taches orange sur un sol cyan — le meme defaut qu'on avait corrige la veille pour un seul modele, revenu au complet, d'ou une regle ecrite en toutes lettres dans le generateur ; et la couronne d'un palmier n'avait que deux directions, une paire de frondes opposees etant identique a elle-meme apres un demi-tour. **312 verifications, 0 echec.** |
| 2026-09-05 | Jalon 1.11, deuxieme temps : **les arbres sont en jeu**, et la question des filons est tranchee. (1) **La decision de palette.** Les neuf filons demandaient neuf types de bloc et la reserve terrain etait pleine ; des trois issues du prompt, aucune telle quelle. `RANGE_TERRAIN_END` passe de 31 a 40 et `RANGE_CREATURES_BEGIN` de 32 a 41, **et rien d'autre** — le prix annonce de cette issue (« invalide tous les modeles peints ») ne valait que si on deplacait *toutes* les frontieres. Aucun repeint : les 53 modeles du depot n'emploient que 14-29 et 128-175, et la plage creatures n'a aucune entree peinte, l'apparence des creatures etant hors perimetre. C'est ce qui rend l'operation gratuite **aujourd'hui**, et elle ne le sera plus au jalon 2. Les neuf index sont alignes sur les codes d'entite (`index = 32 + (code - 131)`) et la table de rarete de §5.4 est portee verbatim dans `CWPalette.roll_ore` — les deux verrouillees par des tests, la seconde deroulee sur ses 1 000 combinaisons plutot que tiree. Neuf modeles a **1 voxel = 1 bloc** sous `assets/models/filons/`, premier lot de ce genre du projet ; leur *pose* reste a faire et appartient au jalon 2.6. (2) **La seconde couche de dispersion.** `CWTreeScatter` herite de `CWScatter` — cache, verrou, reprise apres edition sont identiques — et redefinit la cellule (64 blocs), la bibliotheque (a part : rayon max 2 blocs pour la flore, 3 pour les arbres), la densite, et un **espacement minimum reel** de 7 blocs entre troncs. Cet espacement est le seul endroit interessant : il doit tenir **au travers des frontieres de cellule** sans etat partage ni recursion, d'ou la regle du rang absolu `(cz, cx, i)` sur le voisinage 3 x 3 — comme l'espacement est inferieur a la cellule, tout candidat genant est dans la fenetre, et la decision est la meme quelle que soit la cellule qui la pose. Verifie par un test sur 169 cellules : plus courte distance mesuree 7,0 blocs exactement. (3) **La question de la selection est tranchee** : les arbres ont leur propre champ, crete a 0,02 (bosquets de 50 blocs) et non les deux cretes de la flore a 0,01 — les partager aurait mis chaque arbre dans une plaque d'herbe, et deux couches correlees a cent pour cent se lisent comme une seule. (4) **Le montage** se fait au niveau de l'instance : `Placement.fy` est ajoute pour poser un houppier a une hauteur fractionnaire, la hauteur d'un tronc etant un nombre de voxels divise par 40/3. Le tronc ecrit dans le terrain — donc la collision — reste a faire. (5) **Validation en jeu** : `terrain_demo` accepte `-- --biome N --shot S`, ce qui donne une capture d'un biome donne sans piloter la fenetre ; sept biomes regardes. Trois defauts corriges dans la foulee, tous invisibles hors du jeu : les houppiers sortaient grumeleux (resolution de metaballe 0,32 -> 0,22), les trois touffes d'herbe — l'objet le plus instancie du jeu — etaient trop clairsemees, et la broussaille de neige ressortait en tache orange sur un sol cyan, seul objet chaud d'un paysage froid (bois assombri et neige posee dessus, meme fonction que pour `sapin_enneige`). 297 verifications, 0 echec. |
| 2026-09-05 | Jalon 1.11, premier temps : **les quatorze modeles d'arbres sont livres**, par le meme chemin que la flore — `docs/prompt_generation_arbres.md` pour la commande, `tools/blender/generer_arbres.py` et `arbres_formes.py` pour la production, une graine en dur par fichier, le lot se regenere a l'identique (verifie : quatorze empreintes md5 inchangees d'une execution a l'autre). Les garde-fous de `flore_vox` sont reemployes tels quels ; seul le **plafond d'enveloppe** est devenu un parametre, par classe — arbre entier 160 voxels, houppier 80, palme 60 —, la plage des index restant ce qu'elle etait. La suite de tests ne connaissant pas encore ce lot, la **fourchette de hauteur commandee est portee dans la table `LOT` du generateur** et verifiee a l'ecriture : c'est le garde-fou provisoire, en attendant celui de la couche de dispersion. Trois choses ont ete apprises en dessinant, toutes dans les notes de `arbres_formes` : une couronne dont les lobes ne se chevauchent pas sort en **guirlande** — un anneau de billes separees, troue au milieu — et il lui faut un lobe central plus une enveloppe en oeuf, la coquille se faisant a l'echantillonnage et non en ecartant les lobes ; une palme dont les folioles sont posees a chaque point de rachis sort en **lame pleine**, il faut un pas de trois ; un lacet par pas de 0,05 sur un rachis de 74 voxels **enroule** la palme d'a peu pres 120 degres, la rotation totale valant `balance x longueur / 2`. Le rayon maximum du lot est de **32 voxels, soit 3 blocs**, et non les 24 que laissait craindre la boite de `thorn-tree`. Restent le code : la seconde couche de dispersion, puis l'assemblage. |
| 2026-09-05 | Jalon 1.11 ouvert : **les arbres**, qui n'avaient aucune etape prevue. La meme lecture des slots de chargement qui a donne la table du decor donne celle des entites — `slot = 1969 + code`, tenue par treize valeurs consecutives : les neuf filons sortent dans l'ordre exact de la table de rarete de `docs/systems/02` §5.4, et les trois cibles confirment la ligne « 140-142 » que rien n'etayait. Le mecanisme « le slot de chargement est le code, a une base pres » est donc general, et non une particularite du decor. **La question ouverte n° 2 est reglee** : `tree-leaves` porte son propre code (143), loin des deux arbres (129 fir-tree, 130 thorn-tree), et le corpus n'a ni `tree-trunk` ni equivalent — le conifere et l'arbre a epines sont des modeles entiers, le feuillu et le palmier sont des assemblages, et leur tronc est ecrit dans le terrain. Corrige au passage une affirmation fausse de `assets/models/MODELS.md` §4 (« aucun arbre n'est un modele ») et son decompte de 154 modeles, qui est de 2 449. Travaux prevus en trois temps : le lot d'assets par le meme chemin que la flore (`docs/prompt_generation_arbres.md`, 14 modeles), une **seconde couche de dispersion** — ranger un arbre de 12 blocs dans la bibliotheque de la flore ferait passer la marge de `placements_in` de 2 a 24 blocs pour toute la flore —, puis l'assemblage tronc + houppiers, premier objet du projet a traverser la matiere et l'instance. Les neuf filons sont **bloques sur une decision de palette** : ils s'estampent, donc chacun de leurs voxels est un type de bloc, et la reserve terrain 14-31 est pleine. |
| 2026-09-05 | Jalon 1.7 clos, et le jalon 1 avec lui : **la table type de decor -> modele est trouvee**. Elle n'etait dans aucune fonction — elle est dans le **tableau des slots de chargement**. `GameController_load_game_assets` range 2 449 modeles `.cub` a des indices qui ne suivent pas l'ordre de chargement (les huit enseignes sont chargees dans le desordre et rangees a la suite), et le decor y occupe un bloc contigu : `slot = 2418 + type`, tenu par cinq recoupements pris dans trois fonctions — roseau sur sol humide, deux nenuphars sur l'eau, huit enseignes pour huit genres de batiment, lierre et rosiers de mur, art incan. Reserve dite en clair : la meme base ne tient pas sous le type 22, ou les cinq couvre-sols demandent une base decalee de cinq ; les deux lectures s'accordent en revanche sur la *nature* de chaque decor, et c'est elle qui est portee, sous le nom de **role**. Trois choses en sont sorties. **Il y a deux cretes de selection a 0,01, pas une** — decalages `(9843, 8437)` et `(34234, 234234)`, la premiere pour la famille, la seconde pour la variante ; leurs signes ne s'accordent que 50,8 % du temps, soit le hasard, donc la seconde porte bien une information que la premiere n'a pas. La parite d'indice de `CWScatter._choose` etait une invention de ce projet faute de connaitre la table : elle est retiree. **Le second seuil est biaise** (`n2 <= 0,5`), ce qui garde le minoritaire a une fois sur quatre — prairie mesuree apres portage : couvert 43,5 %, fleur 41,0 %, caillou 8,4 %, sous-bois 7,0 %. **Les echelles disent la taille du role** : 0,075 est la reference, soit exactement `3/40` — le rapport de ce projet —, le roseau a 1,2x, le caillou a 1,33-1,6x, le sous-bois humide a 0,67-1,33x. Releve au passage sur la question ouverte n° 1 : `terrain_surfaceColor_blend` (@005c56e0) **est** la regle de surface de l'original, l'equivalent exact de `CWPalette.surface_index`, et elle n'ecrit que cinq types (4, 6, 9, 10, 12) — la correspondance de numerotation n'est plus qu'a une ambiguite pres, celle de savoir lequel de ses deux parametres climatiques est la temperature. `CWModelLibrary` passe d'une table par biome a une table **par role**, et deux verifications la tiennent : aucun role atteignable sans modele, aucun modele range sous un role inatteignable. 271 verifications. |
| 2026-09-05 | Jalon 1.10 : la carte du monde. Analyse dans `docs/systems/05` — onze fonctions, dont quatre au nom trompeur. **Une piece de carte est une cellule de Voronoi** : `loadLandscapeTile` balaie la zone plus une zone de marge, deforme chaque point de la grille de chunks et ne garde que ceux dont le site de region le plus proche est celui de la zone. La carte n'est donc pas un quadrillage, et ses frontieres sont **exactement celles du climat** — meme point deforme que le melange de sites du jalon 1.3. Consequence : **aucune constante numerique nouvelle**, `World_getColumnDataAt2` est mot pour mot `warped_point` et la recherche est `nearest_site`. **Troisieme confirmation de l'echelle** : `WorldMap::getTile` borne a `[0, 0x10000)` et indexe `>> 6` puis `& 63`, soit une case de 256 unites — le chunk du jalon 1.8 — et 64 x 64 par zone. **L'image stockee ne porte pas de couleur** : trois clartes, 200 / 220 / 255, et rien d'autre ; la teinte vient du dessin, et le portage garde cette separation. Decouverte : un bit par chunk et un compteur, seul etat persiste par l'original (4 octets, cle `discovered`). Marqueurs : ce sont les elements de tuile du jalon 1.6, releves une troisieme fois par le couple `0x68` / `+0x14018`. Noms de region : deux syllabes tirees de deux tables de vingt, indexees en croix par le point deforme en unites de zone ; le mecanisme est porte, les syllabes sont des creations originales. **Septieme nom trompeur** : `Terrain_sampleHeightNoise` n'echantillonne pas une altitude, c'est la deformation a ±500 en unites de zone — `edge_warped_point`, portee au 1.4. Defaut vu en jeu et par aucun test : poser les seules ancres d'un `Control` sous un `CanvasLayer` le laisse de taille nulle, et la carte sortait par le coin superieur gauche. Cout : dalle de 4 096 cases en 43 ms, vue de 5 x 5 zones en 1,4 s a froid, nom en 14 us. 256 verifications. |
| 2026-09-05 | Jalon 1.9, seconde moitie : **l'eclairage est porte**, et le chargement double de vitesse. Le rendu passe en `COLOR_RAW` — un voxel porte son type dans `CHANNEL_TYPE` et sa couleur dans `CHANNEL_COLOR`, ce qui est exactement ce que fait l'original, et les 39 modeles de flore n'ont pas ete repeints. `CWLight` porte les deux passes ; le terrain genere ne l'appelle pas, un champ de hauteurs etant eclaire partout ou on le voit. Deux choix portent tout le gain : les passes sont indexees dans l'ordre natif de `VoxelBuffer` (Y d'abord), donc le canal de types leur est passe tel quel — trente-six mille `get_voxel` de moins par coup de pioche — et `shaded_cells` pousse la lumiere depuis l'air vers ses voisins pleins au lieu de sonder chaque bloc, si bien que la roche enterree ne coute rien : 71 ms -> **30 ms** par coup de pioche, profil inchange. Chargement, deux defauts mesures : le **flux SQLite etait passe devant la generation** sans que rien ne le montre (l'ATH n'affichait que `gen` et `maillage`), chaque bloc attendant une requete disque avant d'etre mis en file — `set_key_cache_enabled` repond « absent » sans toucher la base ; et le pool tournait a quatorze fils, **au-dela des coeurs physiques le travail ne ralentit pas, il s'effondre** (14 fils plus lents qu'un seul). Vue de 384 blocs : 39 s -> **16,4 s**, et 433 s de temps CPU cumule ramenes a 127 s. La flore suit desormais la distance de vue du joueur et attend que le sol soit charge sous ses plantes. |
| 2026-09-05 | Jalon 1.9, premiere moitie. **L'algorithme d'eclairage est entierement etabli** (`docs/systems/04`) : descente du soleil par colonne, puis seize iterations de diffusion **purement horizontale**, attenuation **multiplicative x 0,85** par bloc et non le -1 de Minecraft, plancher de 5/255 qui interdit le noir absolu, type 13 = source a 255. Le double tampon explique la disposition d'octets du jalon 1.8 : pour un voxel transparent, les trois premiers octets sont suivant/courant/publie, pas une couleur. Trois types de blocs nommes au passage — 0 air, 2 eau, 13 lampe — les premiers points d'ancrage vers la correspondance de numerotation. **Le portage est suspendu a une decision de rendu** : `VoxelMesherCubes` n'a pas de canal de lumiere, il faudrait passer en `COLOR_RAW`, ce qui est exactement ce que fait l'original ; cout et gain peses en `docs/systems/04` §6-7. Sur un monde intact l'eclairage ne change rien de toute facon — le terrain est un champ de hauteurs pur, la lumiere ne se voit que dans ce qu'on a creuse. **Fait** : la flore suit le terrain edite, les touffes ne flottent plus au-dessus des crateres. Piege releve : `CWWorldEdits` est en coordonnees de scene, `CWScatter` en coordonnees monde ; la premiere version rangeait la table dans le mauvais repere et **aucun test ne bronchait**, les deux cotes employant le meme repere — c'est la capture en jeu qui l'a montre. 162 verifications. |
| 2026-09-05 | Jalon 1.8 : edition du terrain et persistance. Analyse dans `docs/systems/03` — sept fonctions courtes, le systeme le mieux determine jusqu'ici. **L'echelle du monde est confirmee par un second chemin** : `Chunk_getColumnAt` borne a `[0, 0x1000000)`, soit exactement WORLD_SIZE, obtenu jusqu'ici en multipliant 1024 zones par 16 384 ; `Grid_lookup1024` borne a 0..0x3ff (la grille de zones) et `Region_getChunkCell` a 0..0xffff. **Un echelon manquait** : le chunk de 256 x 256 colonnes, 8 x 8 par tuile — c'est la cellule de `WorldInfo_generateBiomeContent`, dont on ne savait pas ou la ranger. **L'eau n'est pas de la matiere** : `World_getBlockAt` ne lit jamais un bloc d'eau, il rend un temoin selon que z <= 0 ou non, le niveau de la mer d'origine etant 0 — la valeur que `sea_level` avait deja. Creuser sous la mer laisse donc de l'eau. Releve au passage : un bloc d'origine fait 4 octets, trois de couleur **RVB** et un d'attributs (type 5 bits, 0x40, protection 0x80) — ce qui donne une piste sur la dalle d'eau du LOD 1, une couleur survivant a une moyenne la ou un index de palette non. La structure d'origine n'est **pas** portee : `VoxelTerrain` tient deja ce role en natif, la reecrire serait porter une implementation. Persistance par `VoxelStreamSQLite`, `save_generator_output = false` : 647 editions = 20 Ko. Regression attrapee en jeu et non par les tests : `--quit-after` n'envoie pas `WM_CLOSE_REQUEST`, donc rien n'etait sauve — `NOTIFICATION_EXIT_TREE` est le second filet. 155 verifications. |
| 2026-09-05 | Les deux frequences de bruit portees dans `CWScatter`, et la gigue d'echelle par instance. **La crete a 0,05 est le mecanisme de groupement** : la dette « semer par grappes », ouverte le 2026-09-04, se ferme sans code de groupement — `|bruit(x*0,05)| > 0,5` passe 29,2 % de la surface en plaques de 19,1 blocs, et la variance/moyenne par cellule monte a 14,3 contre ~1 pour un tirage uniforme (195 cellules vides sur 576). La **rarete entiere n'est pas portee, deliberement** : l'original la tire par colonne, soit 256 echantillonnages par cellule (~19 ms, hors budget) ; le budget de candidats a la meme moyenne, et le calcul le confirme — 256 x 0,2917 x 1/8 = 9,3 plantes par cellule contre les 9,8 de la densite posee au juge, deux chemins independants sur le meme nombre. Le **test de signe se generalise par la parite de l'indice** et non en deux moities contigues : celles-ci donnaient une region a 40 % de cailloux, propriete de l'ordre de la table et non du mecanisme — defaut vu en jeu, pas dans un test. Corrige au passage : `PLACEMENT_PASS_RATE` mesure sur 250 000 colonnes autour du point de depart donnait 0,3012, trois points de trop ; la vraie valeur sur un million de colonnes reparties est 0,2917. `MAX_PER_CELL` 32 -> 64, sans quoi il rabotait au lieu de garder. 124 verifications. |
| 2026-09-05 | `VOXELS_PER_BLOCK` passe de 16 a **40/3**, la valeur de l'original : ses echelles d'instanciation du decor sont 0,075 / 0,09 / 0,1, et 0,075 = 3/40 exactement. Ecrit en fraction, pas en 13.333 qui derive. Un cube de reference d'un bloc n'etant plus entier, la reference d'authoring devient **3 blocs = 40 voxels**. Le personnage de 32 voxels passe de 2,0 a 2,4 blocs, ce qui recoupe les 2,3 blocs mesures au pixel : le changement rapproche du terrain mesure. Piege regle au passage : `CWScatter` utilisait le rapport comme modulo entier pour la position sous le bloc — les deux notions sont independantes et sont separees, `CWScatter.SUBBLOCK_STEPS = 16` d'un cote, la grille de dessin de l'autre. Deux tests verrouillent la fraction. 117 verifications. Ajoute : `docs/prompt_generation_flore.md`, prompt autoportant pour regenerer le lot sous Blender/bpy, avec un ecrivain .vox valide de bout en bout par le chargeur du projet. |
| 2026-09-05 | Seconde voie de pose identifiee, `docs/systems/02` §8. Il y a **deux** voies : les plantes a silhouette sont des entites a code de type, la flore basse (herbe, fleurs, algues, corail, roseaux) est du decor instancie sans entite, produit dans la meme passe que le terrain et pousse par `ChunkBuffer_loadAndNotify` (@005c03f0). Enregistrement reconstruit par recoupement de cinq branches : type a +0, echelle a +32, lacet a +36, drapeaux a +56. **Le rapport d'echelle est confirme par une constante du binaire** : les echelles de decor valent 0,075 / 0,09 / 0,1 et 0,075 = 1/13,333 exactement — la meme valeur que la mesure au pixel du 2026-09-04, par un chemin entierement different. Nos modeles sont 20 % plus fins que l'original a bloc egal ; VOXELS_PER_BLOCK = 16 reste delibere, mais l'ecart est chiffre. Deux manques de CWFloraRenderer releves : la gigue d'echelle de 1x a 2x par instance, et les deux frequences de bruit (0,05 pour ou, 0,01 pour laquelle). Reste la table type de decor -> modele ; trois pistes eliminees, la cible est le consommateur du champ type. |
| 2026-09-05 | Table modele/biome trouvee, seconde passe : `docs/systems/02` §5. Elle n'etait dans aucune des deux fonctions au nom prometteur — `World_generateVegetationCluster` (@005d8750) est le resolveur de contenu d'une tuile, pas un disperseur. La table est le switch d'apparence de `creature_generateAppearance` (game_misc.cpp:3197) croise avec les slots de chargement de `GameController`. **Flore, filons et creatures sont un seul espace de types d'entites** : 120-130 plantes, 131-139 filons, 145-155 poissons — ce qui confirme par la source la decision du 2026-09-04 de sortir la flore des donnees voxels. Les boites englobantes recoupent l'echelle fixee ici (thorn-tree 12 blocs, cactus1 4, buisson 2). Selection par type de bloc de surface pondere par le climat, jamais par un identifiant de biome. Rarete des filons entierement determinee (fer 70 %, or 10 %, argent 10 %, diamant 0,1 %). Reste : la correspondance des numerotations de blocs, et la seconde voie de pose de la flore basse (grass, flowers, alga, coral, reed n'ont pas de code d'entite). |
| 2026-09-05 | Premiere passe d'analyse de `WorldInfo_generateBiomeContent` (@005e4850, 4 200 lignes) : `docs/systems/02`. Ce n'est pas le disperseur de flore mais le constructeur d'une cellule de 256 x 256 colonnes. Sortis : le champ de densite de vegetation a quatre octaves avec ses constantes, l'identite de quatre types d'elements de tuile (6 = champ de rochers, 11 = massif isole, 12 = plan d'eau, 3 = parcelle batie), les constantes de pose des points d'apparition (jalon 2.6), et une corroboration independante du portage 1.6 (stride 0x68, base +0x14018, ordre tz + tx*8). Deux affirmations de la feuille de route corrigees : **les arbres sont des assets** (`fir-tree`, `thorn-tree`, `tree-leaves`...) et il n'y a pas de generateur d'arbre recursif a porter ; et le binaire charge 2 550 modeles nommes, pas 154. Prochaine cible reduite de 4 200 a 600 lignes : `World_generateVegetationCluster` @005d8750. |
| 2026-09-05 | Les 28 modeles du lot de flore livres et integres, en 39 fichiers ranges par biome ; `CWModelLibrary.FLORA` porte des chemins. Repare : les fichiers etaient peints sur une palette reechantillonnee par MagicaVoxel (planche de reference glissee sur le nuancier), donc bonnes teintes et mauvais index — invisible partout sauf a l'ecran ; `tools/repaint_models.gd` les remet dans la palette de projet, index et palette embarquee. Reserve de terrain 14-31 remplie (les six cailloux se rabattaient tous sur STONE) et deux entrees aquatiques ajoutees a la vegetation (le corail se rabattait sur le vert de prairie) ; le decoupage des plages n'a pas bouge. `zentarys_palette.vox` exporte : c'est le seul chargement de palette qui aligne les index. Gabarit d'echelle range par rangees de dix. 116 verifications. |
| 2026-09-04 | Echelle des assets refixee sur une mesure au pixel d'une capture du jeu d'origine : deux grilles, 1 bloc = 16 voxels de modele, personnage a 2 blocs (contre 8 blocs et 1 voxel = 1 bloc, tranches a l'oeil le matin meme). La flore quitte les donnees voxels du monde : maillage a part, instanciation par `CWFloraRenderer`. Le generateur ne connait plus la flore, ses +14 % par bloc disparaissent ; une cellule de flore coute 1,1 ms hors du fil principal. Gabarit d'echelle refait : mires en blocs, silhouette de 32 voxels avec des yeux d'un voxel. |
| 2026-09-04 | Jalon 1.6. Grille d'elements de tuile, cinq effets d'altitude, relevement des ilots oceaniques, champ de routes. Recursion generateur/champ cassee comme dans l'original, et rendue sure sur plusieurs fils. 30 verifications de plus. Cout : +0 us/colonne hors influence sur le chemin de streaming, +13 us dedans. |
| 2026-09-03 | Debit de chargement : doublons entre fils, plafond de cache, distance aux aretes inutile, pool de fils. Vue 384 stabilisee en 27 s au lieu de > 3 min. Teleportation par biome et reglage de la vue au clavier. |
| 2026-09-03 | Corrige : tranchee d'une colonne le long des aretes du graphe de sites (defaut d'unites, signale par l'utilisateur). Saut max entre colonnes voisines 2,35 -> 0,37 bloc. Test de non-regression par balayage dense ajoute. |
| 2026-09-03 | Vue lointaine : LOD natif teste et ecarte (dalles d'eau en pleine plaine des le LOD 1). Bascule `use_lod` conservee. |
| 2026-09-03 | Jalon 1.1–1.5. Analyse du pipeline de terrain, portage complet du champ (bruit, LCG, sites, climat, altitude, chenaux), générateur voxel + rendu `VoxelMesherCubes`, scène de démonstration, 43 tests. Corrigé : `world_origin` non appliqué dans le générateur ; absence de cache de colonnes. Ajouté : ATH compact, arrêt immédiat. |

---

# Annexe — le récit des sessions

> **Ce qui suit vivait en tête de `nextsteps.md`, et c'est ce qui le rendait
> illisible.** Le fichier de reprise a été écrit pour porter *les décisions qui
> coûtent cher à redécouvrir* ; il en était venu à porter le récit de chaque
> session, ses mesures, ses essais ratés et ses tableaux avant/après. Ces choses
> ont leur valeur — elles sont ce qui empêche de refaire une erreur — mais elles
> n'ont pas leur place au début du fichier qu'on lit en premier. Déplacé ici le
> 2026-09-10, sans une ligne de retouche : ce qui est écrit là a été écrit le
> jour où on le savait, et le réécrire après coup lui ferait perdre sa valeur.
>
> **Deux systèmes décrits ci-dessous n'existent plus.** Les surplombs et leurs
> grottes (§6ter, §7sexies, §7septies, §7octies, §7nonies) ont été retirés le
> 2026-09-10 ; les ponts l'avaient été la veille. On garde le récit parce que
> *savoir pourquoi une chose a été retirée vaut plus cher que la chose*.

## 6. La refonte des biomes et des assets — **faite le 2026-09-06**

*Cette section était « la prochaine tâche » ; elle est faite. Elle est gardée
parce qu'elle contient des mesures qui coûteraient cher à refaire, et deux
leçons de méthode qui valent au-delà de ce jalon.*

### 6.1 Ce que les captures du jeu d'origine ont montré

Méthode : le personnage sert de règle (2,3 – 2,4 blocs), comparé à des marches
de terrain à la même profondeur. Les captures restent **hors du dépôt**
(`.gitignore`) : on en tire des nombres, jamais des pixels.

**Les arbres sont immenses, et c'est délibéré.** Ils lisent à **15 – 25 blocs**,
soit six à dix fois le personnage. **Leurs houppiers sont larges et aplatis** —
des dômes en parasol, **plus larges que hauts**, de 10 à 18 blocs. **Et leur
grain est celui du terrain** : sur les captures, les cubes de feuillage et les
blocs de terrain lisent à la même taille.

Deux raisons de le croire au-delà de l'œil, et la seconde est la plus forte. La
**provenance de l'échelle** : `0,075 = 3/40` est relevée dans la voie du *décor*
du binaire (`docs/systems/02`, §8.3), et **aucune échelle n'a jamais été relevée
dans la voie des *entités***, par où passent les arbres. L'**argument
structurel** : §5.2 établit que le tronc d'un feuillu est écrit dans le terrain
en colonnes de blocs et que le houppier est instancié séparément ; ces deux
moitiés ne se rejoignent proprement que si la grille du houppier est celle du
bloc. **Un voxel = un bloc explique l'architecture de la source ; 3/40 la rend
impossible.**

**La flore, elle, était à la bonne grille mais deux fois et demie trop petite**,
et la cause était un repère faux de `assets/models/MODELS.md` §1 — « touffe
d'herbe au genou », là où les captures la montrent à l'épaule.

### 6.2 Ce qui a été fait

| | avant | après |
|---|---|---|
| grille des arbres | 3/40 de bloc | **1 bloc** |
| `pin` / conifère, hauteur | 8,3 blocs | **19 – 22 blocs** |
| houppier, largeur | 4,8 blocs | **11 – 22 blocs** |
| houppier, proportion | aussi haut que large | **au moins 1,4 fois plus large** |
| espacement des arbres | 7 blocs | **14 blocs** |
| touffe d'herbe | 12 voxels, 11 brins d'un voxel | **25 – 30 voxels, 5 brins de deux** |
| caillou | 8 voxels | **28 – 34** (un bloc erratique) |
| plante haute | absente | **fougère, 40 – 46 voxels** |
| fleur de champ | 13 voxels | **6 – 10** |
| lot de flore | 39 modèles, 9 dossiers | **42 modèles, 6 dossiers** |
| lot d'arbres | 14 modèles | **24 modèles** |

**Les formes ont été repensées, pas réduites.** `reduced(2)` aurait donné des
moignons : les folioles de palme, les rameaux de conifère et les pousses de
houppier sont écrits pour du détail d'un voxel. À la maille du bloc, un conifère
est une **pile de disques plats** et un houppier **quelques dizaines de cubes
bien placés**. D'où `tools/blender/arbres_blocs.py`, tenu séparé de
`arbres_formes.py`, et un générateur d'arbres qui est passé en **Python pur** :
à cette résolution, une métaballe échantillonnée rend un tas de cubes.

### 6.3 Les deux leçons de méthode

**Ce qu'on prend pour « trop de détail » est presque toujours « trop petit ».**
Un objet à la moitié de sa taille garde tous ses éléments dans le quart de la
surface, donc il paraît chargé — et le réflexe d'en ajouter aggrave exactement
ce qu'on voulait corriger. C'est ce qui s'était passé le 2026-09-05 au matin :
les touffes lisaient « clairsemées », on est passé de 6 brins à 11, et c'était
le remède inverse.

**Une règle peut être juste et vide.** La première règle de Lava Lands traduisait
correctement « 30 – 40 °C, rare » et rendait **60 colonnes sur 147 456**, parce
que le champ de climat de ce projet est bimodal et que la bande d'humidité
qu'elle visait n'existe pas. Baisser son seuil de 0,88 à 0,80 l'a portée à 64.
`tools/biome_stats.gd` existe pour ça, et **tout déplacement de seuil dans
`CWBiome` doit passer par lui** — c'est écrit dans l'en-tête du fichier.

### 6.4 Ce que la capture a attrapé et que la suite headless ne voyait pas

Cinq défauts, et c'est le meilleur argument pour `-- --biome N --shot S` :

1. le fût des conifères ressortait **au-dessus** du feuillage, sur tous les
   conifères du monde à la fois ;
2. la scorie, à sa teinte « lave refroidie » d'origine (176,44,20), rendait un
   rose saumon uniforme dont la coulée incandescente ne se détachait pas ;
3. le magma, à 255,152,48, se confondait avec le sable du désert (253,185,82) ;
4. **cinq modèles de Snowlands sur six** ressortaient en taches orange sur un
   sol cyan — voir l'invariant n° 29, qui est né de là ;
5. la couronne d'un palmier n'avait que **deux directions** au lieu de quatre —
   voir l'invariant n° 30.

Aucun n'aurait pu être trouvé autrement.

### 6.5 Ce qui reste ouvert du côté des assets

> **Trois défauts sont apparus après coup, en jouant.** Ils ont leur propre
> section, §6bis ; ils sont **corrigés**.

- **`CWVoxelModel.reduced(n)` n'a toujours aucun usage.** Un arbre de 22 blocs
  est le premier modèle assez gros pour la justifier, et la couche existe
  maintenant pour l'accrocher.
- **Oceans n'a pas été vu en jeu.** La recherche de biome pose la caméra
  au-dessus de la mer, et le fond est 75 blocs plus bas : la capture rend une
  étendue d'eau vide. Les trois modèles de fond marin existent et sont testés,
  mais personne ne les a regardés. Il faudrait une pose sous l'eau.
- **Les cultures des villages** (`blé`, `maïs`, `carotte`, `coton`, `citrouille`)
  restent à produire, et elles ne sont pas dispersées par biome : elles se
  posent en rangées par le système de champs du jalon 4.3.

## 6bis. Les trois défauts vus en jeu — **corrigés le 2026-09-06 au soir**

*Cette section était « à corriger en premier » ; c'est fait, et vérifié en
capture. Elle est gardée pour les deux profils en Z qui ont servi de preuve, et
pour la leçon du §6bis.1, qui est la plus utile des trois.*

### 6bis.1 La flèche des conifères flottait — deux corrections en une

Symptôme : le sommet de tous les conifères détaché du reste de l'arbre.

**Ce n'était pas la flèche qui était mal placée, c'était l'étage qui la porte.**
Profil en Z de `arbres/greenlands/pin.vox` (22 blocs de haut), avant :

```
  z= 15   21 voxels      <- avant-dernier etage
  z= 16    —  VIDE
  z= 17    —  VIDE
  z= 18    5 voxels      <- dernier etage, deja detache
  z= 19-21               <- la fleche, contigue a l'etage 18
```

Les **deux derniers étages** sont espacés de 2,8 blocs alors qu'un étage fait un
bloc d'épaisseur, et le fût ne comblait pas l'écart : il s'arrêtait à
`hauteur * 0,82`, soit z = 15. Les trois quarts supérieurs de l'arbre flottaient
en un seul morceau. `sapin_enneige` avait le même défaut, en plus court.

**Le remède** (`tools/blender/arbres_blocs.py`, `conifere()`) : le fût monte
**jusqu'au dernier étage posé** et non à une fraction de la hauteur nominale.
C'est la seule des deux contraintes qui compte — un fût qui s'arrête *au* dernier
étage ne dépasse pas et ne laisse pas de trou, quel que soit le pas. D'où les
étages calculés d'abord, le fût ensuite, le dessin en dernier.

**Et la capture d'après a montré la moitié qui manquait au diagnostic.** Le fût
comblait bien l'écart, mais **en écorce** : les deux à trois blocs entre étages
laissaient voir une colonne brune, et l'arbre se lisait comme une pile
d'assiettes enfilées sur un piquet. Le commentaire du code disait déjà la règle
juste — « un conifère ne montre son tronc qu'entre le sol et son premier étage ;
au-dessus, il est dans la masse » — mais le code ne la faisait pas. Il la fait
maintenant : au-dessus du premier étage, le fût est repeint dans le sombre du
feuillage, avant que les plateaux ne soient dessinés par-dessus.

> **La leçon, et elle vaut au-delà de ce défaut : un profil en Z ne montre pas
> une couleur.** Le dump disait « plus de trou » et il avait raison ; il ne
> pouvait rien dire du fait que le trou était comblé avec la mauvaise matière.
> Une mesure ne répond qu'à la question qu'on lui pose. C'est le même argument
> que §6.4, d'un cran plus fin : la capture ne sert pas qu'à trouver ce qu'un
> test headless ne voit pas, elle sert à vérifier **le remède** aussi.

### 6bis.2 Les palmes du dattier flottaient — l'ancre est en haut du modèle

Symptôme : la couronne du palmier de désert posée trop haut, détachée du stipe.

Profil en Z de `arbres/deserts/palme.vox` (3 blocs de haut) :

```
  z= 0    2 voxels   x 0 et 16    <- les deux pointes, qui retombent
  z= 1    2 voxels   x 1 et 15
  z= 2   28 voxels   x 2..14      <- le rachis et son attache, au CENTRE
```

Une paire de palmes retombe : son **point d'attache est le voxel le plus haut du
modèle**, pas le plus bas. Or `_piece` pose une pièce par sa base, donc l'attache
se retrouvait `m.height - 1` blocs au-dessus du sommet du stipe — trois blocs
pour le dattier, quatre pour le palmier de jungle, dont la canopée le cachait
mieux.

C'était le décalage d'attache annoncé en §7 : il avait été réglé *dans le dessin*
— une paire met l'attache sur l'ancre dans le plan horizontal, invariant n° 30 —
mais **pas en Z**. Il était réglé sur deux axes sur trois, et c'est précisément
ce qui a fait croire l'affaire close.

**Le remède** (`src/worldgen/cw_tree_scatter.gd`, `_couronne_de_palmes`) :
retrancher la hauteur du modèle, à son échelle et à sa grille —
`float(m.height - 1) * echelle / m.voxels_per_block`, la même formule que `haut`
juste au-dessus. La conversion passe par `voxels_per_block` du modèle et non par
la constante : c'est l'invariant n° 28.

### 6bis.3 Ne garder que les gros cailloux — et remplacer, pas retirer

`greenlands/caillou_02` (19 voxels, dalle plate) et `deserts/gres` (34 voxels,
colonne à chapeau) sont supprimés. Restent les quatre blocs erratiques :
`greenlands/caillou_01` (31), `snowlands/caillou_01` (29),
`lavalands/caillou_basalte` (28), et le nouveau.

**`deserts/gres` était le seul modèle du rôle `CAILLOU` de Deserts**, et le
supprimer sans plus aurait vidé un rôle que les deux crêtes atteignent encore —
exactement ce que refuse `tests/decor_test.gd` (invariant n° 22). Le choix pris
est de le **remplacer** : `deserts/caillou_gres` est un bloc erratique dessiné
par le même `bloc_erratique` que les trois autres, dans la plage du grès
(20 – 24). `FAMILIES` et `ROLES` gardent donc leur forme, et le désert sa
composition.

Ce qui a décidé du remplacement plutôt que du retrait : **un lot n'est pas une
collection de bonnes idées, c'est une famille.** Le grès sculpté par le vent
était la meilleure silhouette des cinq, et c'est ce qui le condamnait — seul de
son espèce, il ne se comparait à rien. Les quatre minéraux du monde ont
maintenant la même masse basse et large, et quatre matières.


## 6ter. Les remaniements de rendu — **2026-09-06 au soir**

*Tous les trois viennent de la même capture, et aucun n'aurait pu sortir d'un
test. Le premier est le plus lourd et le plus intéressant.*

### 6ter.1 La flore passe à 4 voxels par bloc

**Le symptôme n'était pas celui qu'on croyait.** Le lot avait été regénéré le
matin même « avec moins de détails » — deux fois et demie plus grand, deux fois
moins dense, cinq brins au lieu de onze — et le résultat en jeu était
*indiscernable* de l'avant. Vérifié avant de rien changer : les `.vox` sur le
disque étaient octet pour octet ceux que produisait le générateur. Le lot avait
bien été refait ; c'est le remède qui ne portait pas.

**Parce que le remède agissait sur le nombre d'éléments, et le défaut est dans
la maille.** À 40/3 voxels par bloc, un brin fait 0,08 bloc d'épaisseur : à côté
d'un cube de terrain d'un bloc, ce n'est pas un cube, c'est un cheveu. Cinq
cheveux au lieu de onze font une touffe plus claire, pas une touffe plus grosse.
Aucun réglage d'un lot dessiné à cette finesse ne pouvait donner ce qu'on
cherchait.

Le lot est donc redessiné à **4 voxels par bloc**, avec un module de formes à
part — `tools/blender/flore_blocs.py` — exactement comme le lot d'arbres avait
eu `arbres_blocs.py` trois jours plus tôt, et pour la même raison : **les formes
sont à repenser, pas à réduire.** Une touffe est cinq brins de sept voxels ; une
fleur, une tige et une croix de trois ; une fougère, cinq arcs. Le générateur
passe en **Python pur** : à cette résolution, `bpy` n'apporte plus rien.

Ce qui **n'a pas bougé** : la taille des plantes en blocs. La touffe fait
toujours 1,75 bloc. Et l'enveloppe de `tests/flora_test.gd` n'a pas eu à
bouger non plus, parce qu'elle est dite **en blocs** — c'est le genre de détail
qui ne se remarque que le jour où il paye.

> **C'est le premier écart assumé entre ce projet et une valeur mesurée dans
> l'original**, et il est signalé comme tel dans
> `CWVoxelModel.VOXELS_PER_BLOCK_FLORE` et en §8.1. 3/40 n'est pas contesté :
> c'est bien l'échelle du décor de l'alpha. C'est le rendu qui la refuse.

### 6ter.2 Le rôle `CAILLOU` est supprimé

Les quatre blocs erratiques — un par biome minéral, dont le `deserts/caillou_gres`
produit le matin même — sont retirés du lot, et `Role.CAILLOU` de `FAMILIES` et
de `ROLES`. Motif, vu en jeu : **dispersés à la densité de la flore, ils
rendaient des champs de rochers** de plusieurs dizaines de blocs, serrés au point
qu'un joueur n'y passait plus.

La leçon est celle du 2026-09-06, prise par l'autre bout : on avait
grossi les cailloux de 8 à 30 voxels *sans toucher à leur densité*, qui avait été
réglée quand ils faisaient la taille d'un galet. Un objet qu'on multiplie par
quatre en volume ne garde pas sa densité. **Changer une taille, c'est changer une
densité**, et rien dans le code ne le rappelle.

Le minéral posé du monde est désormais le seul `arbres/greenlands/rocher_geant`,
qui passe par la couche des arbres : espacement de 14 blocs, poids 0,05 dans
`CWTreeRules`. Un rocher de loin en loin, ce qui est ce qu'on voulait.

Les branches où `CAILLOU` était une feuille se referment sur sa sœur —
Greenlands `[[FLEUR, SOUS_BOIS], [COUVERT]]`, et de même pour Snowlands, Deserts
et Lava Lands.

### 6ter.3 Un biome n'a plus qu'une matière de plaine

`CWPalette.GRASS_DRY` et `CWPalette.TUNDRA` sont retirées de `surface_of`.
C'étaient les deux **franges d'humidité** héritées d'avant le jalon 1.12 : une
prairie sous 0,46 d'humidité virait au kaki, une Snowlands sous 0,50 au
gris-olive.

Le défaut se voyait à l'ATH avant de se voir au sol : « Greenlands / herbe
sèche » sur un sol kaki, c'est-à-dire un nom de biome et une couleur qui se
contredisent. Depuis que `CWBiome` classe le climat, une seconde matière de
plaine par biome ne dit **rien que le biome ne dise déjà**. Les trois bandes
d'altitude — plage, roche nue, neige de sommet — restent : celles-là ne sont pas
des franges de climat, elles disent l'altitude, et c'est une autre information.

**Les deux index restent alloués**, et c'est délibéré : les libérer décalerait
tout ce qui suit dans la réserve 1-13, donc les plages 14-19, 20-24 et 25-27 qui
sont peintes dans les 62 `.vox` du dépôt. Deux entrées sur 256 contre un
repassage complet par `tools/repaint_models.gd` : c'est l'arbitrage de
l'invariant n° 31, tranché dans le même sens. Aucun modèle ne les employait —
vérifié avant, pas après.

Le retrait a emporté avec lui l'exception `FAMILIES_SURFACE[GRASS_DRY]`, et
verdi les deux modèles de Greenlands qui puisaient dans la rampe « automne »
(`herbe_seche`, `broussaille`) : une tache orange sur une prairie désormais
toujours verte, c'était l'invariant n° 29 transposé de Snowlands à Greenlands.

Un balayage de `tests/decor_test.gd` refuse maintenant que `surface_of` rende
l'une des deux matières retirées, sur 4 096 climats × 6 biomes × 6 altitudes.
Sans lui, remettre une frange ne lèverait rien.


### 6ter.4 Et la flore prend une seconde grille : 6 pour les petits props

**Quatre voxels par bloc était juste pour la moitié du lot.** Un buisson, un
cactus, un champignon sont des *masses* : leur forme est leur volume, et un
volume se lit à n'importe quelle résolution. Ce qui s'y perdait, ce sont les
objets **dont toute la forme tient dans un trait** — une touffe d'herbe est cinq
lignes, une fleur est une tige et une corolle. À quatre voxels par bloc, une
corolle est une croix de cinq voxels et une touffe un paquet de bâtonnets : le
grain était juste, la silhouette ne l'était plus.

**Quinze modèles passent donc à six voxels par bloc** — les herbes, les fleurs,
le ginseng, le roseau —, le reste garde quatre. Une touffe passe de sept à onze
voxels de haut, sans revenir au cheveu : un brin fait un sixième de bloc, pas un
treizième. C'est le rapport d'un et demi entre les deux grilles qui compte, pas
les valeurs.

**Conséquence d'architecture, et c'est la partie qui coûte.** La grille n'est
plus décidée par la bibliothèque mais **par modèle** : `CWModelLibrary._grid_of`
consulte `GRILLE_FINE`, une liste de chemins. Cette liste et la colonne `FIN` du
catalogue de `generer_flore.py` sont **deux sources qui doivent dire la même
chose** — le générateur dessine à la grille qu'il croit, le moteur instancie à
celle qu'il lit. Une divergence sort la plante à une taille fausse d'un facteur
un et demi : assez pour se voir, pas assez pour qu'on remonte à la cause. Deux
vérifications tiennent les deux sens (invariant n° 28).

Pourquoi une liste et non une règle sur le rôle : le partage passe par le rôle
**à deux modèles près**, et ces deux-là suffisent à le disqualifier —
`feuille_large` est un `COUVERT` de jungle mais c'est une grande feuille, et
`herbe_de_lave` est rangée en `SOUS_BOIS` alors que c'en est. Une règle qui se
trompe sur deux modèles sur trente-huit coûte plus qu'une liste, parce qu'on ne
sait pas lesquels sans les regarder un par un.

### 6ter.5 La flèche des conifères était une boule

Symptôme, vu en jeu sur Snowlands : le sommet des conifères lit comme une
**boule posée sur un cou**. Le profil en Z de `sapin_enneige` le disait mot pour
mot :

```
  z= 12    9 voxels
  z= 13    9 voxels
  z= 14    1 voxel     <- le cou
  z= 15    5 voxels
  z= 16    9 voxels    <- la boule : la silhouette REGONFLE
  z= 17    5 voxels
  z= 18    1 voxel
```

**Deux causes, et il fallait les deux.** Le fût se réduisait à un fil entre les
deux derniers étages : `colonne` reçoit `fut_r` comme rayon haut, et sous 1,0 un
disque ne pose plus qu'**un** voxel. Et la flèche était **plus large que l'étage
qui la portait** — son rayon était la constante 1,8, soit neuf voxels, quand le
dernier étage d'un conifère fait 1,3 à 1,5, soit cinq à neuf. *Une pointe qui
s'élargit avant de se fermer est une boule, par définition.*

Remèdes : le rayon haut du fût est **planchéisé à 1,0** (cinq voxels), et la
flèche part de l'**avant-dernier** étage en **remplaçant le dernier** au lieu de
s'y ajouter. Ses rayons décroissent donc strictement, la silhouette est monotone
du pied à la pointe, et l'arbre perd exactement **un bloc** — la pointe passe de
`dernier + 3` à `dernier + 2`, ce qui était l'autre moitié de la demande.

Profil après, sur le même modèle : `21, 9, 9, 5, 5, 1, 1`. Vérifié aussi sur
`pin`, `pin_enneige` et `arbre_epineux`.

> C'est la **troisième** fois que le sommet des conifères est repris en trois
> jours — le fût qui dépassait, la flèche qui flottait, la flèche qui gonflait.
> À chaque fois le diagnostic était juste et le remède partiel, parce qu'il
> traitait le symptôme qu'on voyait sans regarder le **profil entier**. Un
> `zprofile` de dix lignes aurait montré les trois d'un coup.

### 6ter.6 Les bandes d'altitude sont retirées

`surface_of` ne rend plus de roche nue ni de calotte de neige hors des biomes
dont c'est la matière. Il ne reste que la matière du biome, la plage, et la
règle propre à Lava Lands.

**Ce n'est pas le même motif que le retrait des franges d'humidité** (§6ter.3),
et c'est ce qui rend le cas intéressant. Les franges se *contredisaient* : une
prairie annoncée « Greenlands » avec un sol kaki. Les bandes d'altitude, elles,
ne se contredisaient pas — une montagne a de la roche et de la neige, le
raisonnement de vraisemblance était bon. Elles ne **portaient rien** :
`decor_allowed` refuse le décor sur la roche et sur la neige hors Snowlands,
si bien que chaque relief un peu haut d'une Greenlands rendait un plateau nu,
sans une plante ni un arbre, où l'on marchait sans rien rencontrer.

*Une matière qui ne porte rien n'est pas un sous-biome, c'est un trou dans le
monde.* Le raisonnement de vraisemblance tenait tant qu'on regardait une carte
de hauteurs ; il ne tient plus dès qu'on marche dessus.

Les trois constantes — `SNOW_LINE_BASE`, `ROCK_BAND`, `ROCK_MIN` — restent, et
ne servent plus qu'à Lava Lands, dont la règle décrit un volcan et non une
altitude.

> **La suite de ce paragraphe a été écrite le matin même et démentie le soir.**
> Elle annonçait que la roche nue reviendrait par la **falaise**, sur une pente
> mesurée plutôt que sur une altitude. La falaise a été portée exactement comme
> annoncé, et retirée le soir : ce qui manquait n'était ni le champ ni le
> seuil, c'était **le relief**. Une pente n'est pas plus une raison de peindre
> une matière nue qu'une altitude ne l'était ; l'une comme l'autre teintent une
> surface au lieu de créer un lieu. Le compte rendu est en §7ter.4, et la
> conclusion des deux retraits est la même à un mot près : *une matière qui ne
> porte rien est un trou, et une matière qui n'habille rien est une tache.*

Répartition mesurée après (`tools/biome_stats.gd`) : herbe 37,2 %, neige 27,0 %,
gravier 23,9 %, marais 6,6 %, scorie 2,4 %, sable 2,0 %, jungle 0,5 %, magma
0,5 %. **Plus une seule colonne de roche** hors Lava Lands.

Un balayage de `tests/decor_test.gd` refuse maintenant qu'un biome autre
qu'Oceans ou Lava Lands produise une matière que `decor_allowed` rejette — c'est
la formulation générale du défaut, et elle attrape aussi le prochain.


## 6quater. La planche de validation des assets — **faite, dans la foulée**

> Demandée le 2026-09-06 au soir, après trois sessions où chaque défaut d'asset
> avait été trouvé par hasard, en jouant, une fois le lot déjà commité.

### L'outil

`scenes/model_portraits.tscn` (`src/demo/model_portraits.gd`) : **une capture
par modèle, seul, de près**, sur un damier neutre dont une case vaut un bloc de
terrain, sous deux angles — de face et de trois-quarts au-dessus. Pas de terrain
du tout, donc rien à streamer : **84 sujets en 5,6 secondes**. Sortie dans
`user://portraits`, plus une planche de contact par lot et par angle, avec le
nom sous chaque vignette. Commande en §2.

Trois décisions valent d'être dites :

- **une scène à part, et pas une option de la démo.** « Sans rien autour » est
  la moitié du travail : le gabarit d'échelle se pose sur le terrain généré,
  donc sur de l'herbe, avec des plantes autour et un relief derrière ;
- **un `SubViewport` de taille fixe**, et non la fenêtre : le cadrage ne dépend
  ni de la résolution ni de la machine, donc deux planches se comparent ;
- **un quatrième lot qui n'était pas demandé, `especes`** — l'arbre **monté**,
  tronc et houppiers assemblés en appelant `CWTreeScatter._monte`, c'est-à-dire
  exactement ce que le jeu pose. C'est le lot le plus utile des quatre, et pour
  une raison qu'on aurait pu prévoir : les trois derniers défauts corrigés
  (§6bis) étaient tous dans l'assemblage et dans aucun modèle.

### Ce que la planche a montré, et la seule chose qui se mesurait

**Treize modèles sur trente-huit étaient faits de cubes qui ne se touchent pas.**
La fougère sortait en **douze morceaux** dont le plus gros portait 38 % de la
matière, la fougère géante en onze, le cotonnier de neige en cinq de quatre
voxels. De loin, dispersés par centaines, ils passaient pour du grain ; de près,
ce sont des confettis qui flottent.

C'est le seul des défauts relevés qui se **mesure**, donc le seul qu'un outil
puisse attraper — d'où, le même jour, trois ajouts qui le verrouillent :
`tools/inspect_model.gd` compte les morceaux (26-voisinage) et le dit à chaque
inspection, les générateurs le disent à chaque écriture, et
`tests/flora_test.gd` en fait un invariant (n° 34). La suite passe de 315 à
**316 vérifications**.

> **La cause était une seule ligne, recopiée dans onze fonctions de dessin.**
> Le pas de parcours d'un arc était pris sur son **étendue horizontale** :
> `n = round(longueur)`. Une fronde de fougère longue de 4,5 monte de 16, donc
> cinq pas horizontaux posaient cinq voxels espacés de cinq en hauteur.
> Corriger `fb.fronde`, `fb.feuille` et `fb.rameaux` a réparé neuf plantes d'un
> coup. La passe de soudure (`Grille.soude`, un pétiole du morceau au corps) est
> le **filet**, pas le remède : le nombre de voxels soudés s'affiche à
> l'écriture, et un modèle qui en demande beaucoup a une forme fausse.

**Et trois défauts de fond, que rien ne mesure :**

1. **Les sept fleurs du lot étaient des panneaux de signalisation.** La corolle
   était un disque plein posé à plat au sommet de la tige — neuf voxels pour
   `rayon = 1,5`, vingt et un pour 2,4. Sept modèles, la même silhouette en T,
   et aucun ne se lisait comme une fleur. `fb.corolle` dessine maintenant une
   **coupe** : les pétales montent d'un voxel autour d'un cœur resté en bas, et
   la pointe des grandes corolles redescend. C'est le minimum qui fasse une
   fleur, et à quatre ou six voxels par bloc c'est aussi le maximum disponible.
2. **Ce qu'on posait sur une masse était posé dedans.** Les baies du snowberry
   étaient tirées à un rayon de 1 à 2,4 dans un buisson large de six, les
   piments de l'habanero et les braises du fire shrub de même : la moitié
   tombait sous la peau, invisible. Les trois modèles sortaient unis — le fire
   shrub se lisait comme un rocher noir. `fb.peau` et `fb.semis` posent
   désormais les grains **sur** la surface, et de côté plutôt que par le haut :
   des baies poussées vers le haut se rejoignent en calotte, ce qui est un
   buisson sous la neige et non un buisson à baies.
3. **Deux troncs tenaient sur un piquet d'un bloc.** `disque` garde ce dont la
   distance au centre ne dépasse pas le rayon : à `r_bas = 1,0` décroissant vers
   0,8, le fût du bouleau faisait cinq voxels au pied et **un seul** dès le
   premier étage. Un bouleau de quatorze blocs de haut sur un bloc de section,
   c'est un houppier qui flotte. 1,4 → 1,05 donne une croix de cinq voxels sur
   toute la hauteur, soit trois blocs de large, un de moins que le chêne.

### Le verdict, modèle par modèle

**71 modèles regardés un par un, plus 13 arbres montés.** Ce qui a été corrigé :

| modèle(s) | verdict | ce qui a changé |
|---|---|---|
| les 7 fleurs (`fleur_bleuet`, `fleur_tournesol`, `fleur_coeur` ×2, `fleur_de_glace`, `fleur_ame`, `fleur_de_lave`) | panneau de signalisation | `fb.corolle` : une coupe, pétales relevés, cœur en creux |
| `fougere`, `fougere_geante` | 12 et 11 morceaux | `fb.fronde` : le pas se prend sur l'arc, pas sur sa projection |
| `lierre`, `liane`, `feuille_large` | morcelés | même cause : `fb.feuille`, et un pas doublé dans `lierre_jungle` |
| `broussaille_seche`, `scrub`, `broussaille`, les deux `cotonnier`, `corail`, `herbe_01`, `herbe_03` | 2 à 9 morceaux | `fb.rameaux` corrigée, plus la soudure en filet |
| `snowberry`, `habanero`, `fire_shrub` | masse unie, garniture invisible | `fb.semis` : les grains sur la peau, et de côté |
| `deserts/cactus_01` | une colonne verte | bras doublés en section, dressés sur six blocs |
| `bouleau_tronc`, `bouleau_givre_tronc` | un piquet d'un bloc | section portée à cinq voxels sur toute la hauteur |
| `lavalands/arbre_epineux` | une poignée de cubes en l'air | fût de même section, branches doublées à leur naissance |

Ce qui **passe sans retouche** : les quatre herbes, `buisson`, `buisson_neige`,
`herbe_gelee`, `ginseng`, `cactus_02`, `vrille`, `roseau`, les deux champignons,
`herbe_de_lave`, `algue`, `etoile_de_mer` ; côté arbres, les trois chênes, le
`pin`, le `rocher_geant`, l'`arbre_geant`, les deux conifères enneigés, les
tropicaux, les stipes et les quatre palmes ; et **les neuf filons**, qui se
jugeront de toute façon en paroi, le jour où leur pose existera (jalon 2.6).

Ce qui **passe mais reste le point faible du lot**, noté pour ne pas le
redécouvrir :

- **`snowberry`** : à quatre voxels par bloc une baie est un quart de bloc, et
  six baies blanches sur un buisson vert foncé lisent encore comme des plaques
  de neige. La bonne réponse est probablement une autre couleur, ce qui suppose
  de renoncer au nom ;
- **`deserts/cactus_geant`** : de face c'est un saguaro, de trois-quarts une
  colonne bosselée — ses bras sont dans un seul plan ;
- **`roseau`** : deux tons franchement séparés, vert sur jaune. Ce n'est pas
  faux pour un roseau, c'est seulement le modèle qu'on lit le moins vite.

### La leçon, et elle vaut au-delà des assets

Les huit défauts trouvés depuis le 2026-09-05 l'avaient tous été parce qu'ils se
**répétaient** — le fût qui dépasse, la tache orange, le champ de rochers. Les
vingt-sept d'aujourd'hui étaient dans le lot depuis le début, visibles au premier
coup d'œil, et invisibles autrement : à trente blocs une plante de deux blocs
fait dix pixels, et **dix pixels sont toujours plausibles**. Une capture de
biome répond à « est-ce que le paysage tient ? », jamais à « est-ce qu'on
reconnaît l'objet ? ».

Et la moitié de ce qui a été corrigé n'aurait pas dû demander un œil : un modèle
morcelé se compte. **Ce qui se mesure doit être mesuré avant d'être regardé** —
la planche sert alors à ce qu'elle seule sait faire, juger une silhouette.

---


## 7. Le tronc écrit dans le terrain — **fait le 2026-09-06**

C'était le dernier point du jalon 1, et le premier objet du projet à traverser
les deux mondes : **la matière et l'instance**. Un feuillu se pose désormais en
deux temps — un tronc écrit dans les données voxels par `CWVoxelGenerator`, un à
trois houppiers instanciés au-dessus par `CWFloraRenderer` — et les deux moitiés
sortent du même tirage, dans la même liste de placements.

### Ce qui a rendu la chose possible, et pourquoi elle ne l'était pas avant

Deux décisions prises pour d'autres raisons se paient ici :

- **le lot d'arbres est à un voxel par bloc** (jalon 1.12). Un tronc dessiné à
  3/40 n'avait aucune correspondance avec la grille du monde ; c'était
  l'argument *structurel* qui a fait changer la grille, et c'est lui qui se
  réalise ;
- **`CHANNEL_TYPE` et `CHANNEL_COLOR` sont séparés** (jalon 1.9). Un voxel de
  tronc porte le type `CWPalette.WOOD` — il est du bois pour tout le code qui
  raisonne en blocs — et **la teinte de son propre modèle** dans le canal de
  rendu. Les quatre écorces du lot survivent au passage dans le terrain, et
  aucun modèle n'est à repeindre. Sans ce partage, il aurait fallu un type de
  bloc par nuance.

### Le type de bloc : l'index 4, recyclé le jour même

Un tronc estampé a besoin d'un type dans la plage que le générateur écrit (0-13).
L'entrée prise est le **4**, libéré le matin même par le retrait de `GRASS_DRY` :
son index restait alloué pour ne pas décaler la réserve peinte dans les `.vox`, et
aucun modèle ne l'employait. Il change donc de statut sans qu'une frontière bouge
et sans qu'un fichier soit à repeindre — exactement le geste de `MAGMA` et
`SCORIA` sur 30 et 31, et exactement ce qui évite de repayer l'opération de
l'invariant n° 31.

> **Ce qui reste alloué finit par servir.** La note du matin justifiait de garder
> le 4 et le 9 plutôt que de les libérer ; le 4 a servi le soir même. C'est
> l'argument le plus court en faveur de cette prudence, et il vaut pour le 9.

### Une matière ne se met pas à l'échelle : elle se rééchantillonne

La gigue d'échelle d'un arbre va de 0,85 à 1,25, et un tronc estampé ne peut pas
être « 1,17 fois plus grand » : ses voxels sont des blocs. Un tronc fait donc
`round(hauteur × échelle)` blocs, et ses niveaux sont copiés **au plus proche
voisin** — la gigue survit, en nombres entiers. C'est cette hauteur-là,
`Placement.hauteur`, qui dit où s'accroche le premier houppier ; le produit
flottant ne décrit plus rien de posé, et un test le vérifie.

Le dessin **horizontal**, lui, n'est pas mis à l'échelle : un tronc 20 % plus
large ne se voit pas, et le garder entier maintient son empreinte alignée sur sa
colonne — celle-là même que `_piece` centre avec `fx = fz = 0.5` depuis le
2026-09-05, en prévision de ce jour.

### Une liste, deux lecteurs

`Placement.matiere` marque la seule pièce écrite dans le terrain. Un arbre reste
**un objet, un tirage, une liste** ; ce sont ses deux consommateurs qui se la
partagent — `CWVoxelGenerator._stamp_trunks` estampe ce qui est marqué,
`CWFloraRenderer` ignore ce qui l'est. Dupliquer la passe de montage aurait été
la faute évidente : deux moitiés d'arbre calculées séparément finissent toujours
par diverger d'un demi-bloc.

**Les espèces de montage ENTIER ne sont pas estampées.** Le pin, le sapin, le
cactus géant, le rocher géant et l'arbre à épines sont des modèles entiers, que
la source pose en entités (`docs/systems/02`, §5.2) : leur feuillage est dans le
même fichier que leur fût, et l'écrire dans le terrain donnerait du feuillage
qu'on ne traverse plus. On les traverse donc toujours — leur collision est un
sujet du jalon 3.1, et ce sera un volume approché, pas de la matière.

### Ce que la capture a montré, et qu'aucun test ne voyait

Le premier essai en jeu a rendu des **fûts nus, sans houppier**, au bord de la
vue. Le diagnostic a demandé trois hypothèses ; la bonne était une différence de
*forme* que personne n'avait remarquée depuis le jalon 1.7 :

> **Le terrain charge une boîte, la végétation garnissait un disque.**
> `CWFloraRenderer` posait ses cellules dans un disque de rayon
> `view_distance` — la forme naturelle d'une distance de vue — là où Voxel Tools
> charge une **boîte** de blocs autour de l'observateur. Les quatre coins de la
> boîte portaient donc du terrain sans porter de cellules. Tant que l'arbre
> entier était instancié, la cellule manquait et l'arbre avec elle : invisible.
> Depuis que le tronc est de la matière, le générateur l'écrit dès que son bloc
> existe — sans rien savoir des cellules — et le coin rend un fût nu.

La portée est donc un **carré**, pour les deux couches. Le prix est de 4/π, soit
27 % de cellules en plus, payées sur le fil du pool ; ce qu'il achète est la
seule chose qui compte ici : *ce que le terrain montre, la végétation le garnit*.

Une seconde correction est venue avec : une cellule à cheval sur le bord du
terrain chargé échouait **en bloc** (`_ground_ready` interroge la cellule
entière), donc soixante-quatre blocs sans une plante, y compris la moitié qui
repose sur du sol chargé. Elle se pose maintenant **à moitié** et se refait
entière quand le terrain la rattrape. Le test par plante interroge **sa colonne**
et non son volume : un houppier flotte à dix blocs du sol et déborde de sept,
exiger que *son* cadre soit chargé le refuserait alors que son tronc, lui, est
bel et bien écrit.

### Ce que ça coûte

**+2 %**, soit 0,4 s sur un chargement de 18. Vue de 384 blocs, au point de
départ : **17,9 et 18,1 s sans l'étampage, 18,4 s avec**. L'appel ne touche que
les blocs qui croisent la surface — les deux chemins rapides sortent avant —,
`trunks_in` consulte une à quatre cellules d'arbres, toutes en cache après le
premier bloc de la pile verticale, et une cellule de 64 blocs contient de
l'ordre de sept arbres.

Le passage du disque au carré, lui, **ne se mesure pas** : les 27 % de cellules
en plus se paient sur le fil du pool, et le verrou du chargement est la
génération du terrain, pas la végétation.

> **Une mesure de chargement se prend au démarrage, pas après un téléport — et
> ça a failli coûter une journée.** Les premières mesures ont été prises avec
> `-- --biome 0`, la commande de toutes les captures : elles donnaient 41 à 43 s
> là où la feuille de route annonce 16,4 s, et le premier réflexe a été de
> chercher une régression de facteur 2,5 introduite depuis le 2026-09-05. Il n'y
> en a pas. **Un téléport charge deux fois plus de blocs qu'un démarrage** — la
> zone quittée est encore en file quand celle d'arrivée entre —, et le compteur
> le disait depuis le début : 70 000 tâches contre 35 000. Sans téléport, le
> même monde se stabilise en **18,4 s pour 35 000 tâches**, ce qui reproduit la
> ligne de la feuille de route à deux secondes près — les 61 → 80 µs par colonne
> apportés depuis par `CWBiome` et les coulées de lave.
>
> La leçon n'est pas « il fallait lire le compteur » : c'est qu'**une mesure ne
> vaut que si son protocole est écrit à côté du nombre**. Les deux lignes sont
> maintenant dans `docs/ROADMAP.md`, chacune avec la sienne.

### Ce qui reste ouvert, et qui n'est plus bloquant

- **abattre un arbre est grossier.** `_supported` écarte tout candidat dont la
  colonne porte une édition : creuser un tronc retire donc ses houppiers à la
  reconstruction de la cellule, mais le fût garde son trou et reste debout. C'est
  le premier abattage du projet, pas le dernier mot — un vrai abattage demande de
  retirer la matière du tronc, ce qui est du jalon 3.2 (l'outil) plus qu'ici ;
- **la collision n'est pas branchée.** Le terrain de la démo a
  `generate_collisions = false` : la matière est là, le corps qui s'y cogne
  n'existe pas encore. C'est le jalon 3.1 qui l'allumera, et il n'aura rien à
  ajouter côté arbres ;
- **la pose des filons.** Les neuf modèles existent, le tirage de rareté est
  porté (`CWPalette.roll_ore`), il manque *où* ils affleurent. Cela appartient à
  la voie des entités, donc au jalon 2.6 — et l'estampage vient de faire la
  démonstration du mécanisme dont ils auront besoin ;
- **la réduction en distance.** `CWVoxelModel.reduced(n)` n'a toujours aucun
  usage. Un houppier de 22 blocs de large est le premier modèle assez gros pour
  la justifier, et il est maintenant seul dans son instance — le tronc ne le suit
  plus.

### Dix grands arbres, et la couleur qui manquait au lot

> **Ils sont huit depuis le soir du même jour.** Snowlands a rendu les siens —
> le saule givré et l'arbre pourpre —, voir §7ter.2. Ce qui suit décrit le lot
> tel qu'il a été produit ; tout le reste en est encore vrai.

Demandés le 2026-09-06 : **deux par biome arboré**, un tronc, des branches, et
plusieurs feuillages en sphères aplaties, *dans d'autres couleurs que le vert*.
Dix espèces, vingt modèles, un quatrième montage.

**`Montage.GRAND`** est ce qui les distingue, et ce n'est pas un réglage de
FEUILLU : un feuillu empile ses houppiers **sur l'axe** de son tronc — sa
silhouette est une colonne coiffée, et son envergure ne dépasse jamais celle
d'un seul houppier. Un grand arbre porte ses masses **en dehors** de son axe, au
bout de branches dessinées dans le modèle de tronc, plus une à la cime. Cinq
masses, et c'est le fait qu'on puisse les compter qui le rend différent.

**Les branches sont écrites dans le terrain avec le fût** — elles font partie du
même modèle, et le tronc est estampé depuis §7. Un grand arbre pose donc dix
blocs de charpente de chaque côté de sa colonne, ce qui a fait passer
`MARGE_TRONC` de 4 à 11.

> **Deux tables doivent dire la même chose, et pour une fois la vérification est
> directe.** `CWTreeRules.SPECIES[...]["branches"]` déclare où sont les bouts,
> `generer_arbres.BRANCHES_*` les dessine. C'est le piège de `GRILLE_FINE`, à
> ceci près qu'on peut le trancher : `tests/tree_test.gd` charge le modèle et
> regarde s'il y a **du bois au bout déclaré**. Une branche déplacée d'un seul
> côté fait tomber la vérification.
>
> Les deux listes sont en coordonnées **Godot**, pas en coordonnées `.vox` :
> l'import fait tourner les axes (`vox(x, y, z) -> godot(y, z, x)`), et une
> liste écrite dans le repère du fichier porterait le houppier à quatre-vingt-dix
> degrés de sa branche. La conversion est faite une fois, dans `ab.charpente`.

**Les couleurs étaient déjà dans la palette, elles n'étaient pas employées.**
Douze des vingt-quatre modèles précédents puisaient dans la seule rampe de
feuillage : une forêt de Greenlands n'avait qu'une teinte. Les dix nouveaux
prennent l'automne (140-147), les quatre couples de fleurs (156-163), la rampe
des champignons et mousses (164-169), la roche nue pour le givre (14-19) et le
basalte pour la cendre (25-27). **Aucune entrée nouvelle** : érable doré,
cerisier rose, saule givré, arbre pourpre, acacia doré, baobab terre cuite,
flamboyant rouge, jacaranda violet, arbre de cendre noir à braises, arbre de
braise incandescent.

Une seule interdiction, et c'est l'invariant n° 29 : **aucune plante de
Snowlands ne prend la rampe d'automne**. Ses deux grands arbres prennent donc le
blanc-bleu et le violet, qui sont froids.

**Puis deux défauts vus en regardant le paysage, et le premier touchait tout le
lot, pas seulement les grands arbres :**

1. **il manquait la moitié basse de tous les dômes.** Le profil de `houppier`
   partait de sa largeur maximale **à la base** et ne faisait que rétrécir en
   montant : un parasol, pas une sphère aplatie. De loin, un arbre n'avait donc
   pas de feuillage sous ses branches — un chapeau de champignon posé sur un
   fût, et cinq chapeaux pour un grand arbre.

   > **Le défaut a survécu au jalon 1.12 parce que la note d'origine disait
   > « dôme en parasol »**, ce qui décrivait fidèlement une capture *vue d'en
   > haut* : d'en haut, une sphère aplatie et un parasol sont la même
   > silhouette. Ils ne le sont plus dès qu'on est dessous, c'est-à-dire tout le
   > temps. Le profil est maintenant un **ellipsoïde tronqué** — maximum à 42 %
   > de la hauteur, la moitié de la largeur aux deux pôles.

2. **tout le lot était trop petit** contre le jeu d'origine, relevé à l'œil sur
   des captures. Les vingt-quatre modèles et les dix nouveaux sont **agrandis de
   40 %** : le chêne monte à 32 blocs, l'arbre géant à 54, l'érable à 33. Les
   plafonds suivent (`(34, 12)` → `(48, 18)` pour un arbre, `(12, 11)` →
   `(20, 17)` pour un houppier), des deux côtés — le générateur refuse à
   l'écriture, le test refuse au chargement.

   **Et la densité suit, c'est l'invariant n° 33.** L'espacement passe de 14 à
   **20 blocs** — la moitié de la largeur d'un houppier, l'écart auquel deux
   couronnes se touchent sans se pénétrer — et les densités sont **divisées par
   deux**, soit le rapport des carrés `(20/14)² = 2,04`. Sans ça, des arbres
   deux fois plus larges à densité constante ferment la forêt : c'est
   exactement ce qui était arrivé aux cailloux le 2026-09-06.

**Deux réglages qu'il avait fallu voir pour trancher**, et aucun ne se déduisait :

1. **la portée doit dépasser le rayon du dôme, pas l'égaler.** Premier essai,
   branches à 5-7 blocs et dômes de 11-13 : les cinq masses se recouvraient
   presque entièrement et l'arbre se lisait comme **un seul** parasol —
   c'est-à-dire comme un feuillu. Branches à 8-10, dômes à 10 ;
2. **un dôme de trois blocs d'épaisseur pour dix de large est une galette.**
   `houppier` rend à peu près la moitié de la hauteur demandée — son profil se
   ferme avant le sommet —, donc 6,5 pour cinq blocs. Un rapport de deux entre
   largeur et hauteur se lit comme une masse ; à trois pour un, c'est un plateau.

### La suite : 2.6, l'apparition

**Le jalon 1 est clos.** La porte suivante est **2.6**, la pose des points
d'apparition, et elle est largement déblayée :

- `WorldInfo_scatterObjectsInArea` (@005f56c0) est lue — elle **ne disperse pas
  d'objets**, elle choisit la liste d'espèces d'un point d'apparition selon le
  climat et le niveau, et écrit son résultat dans un `cube::Spawn` ;
- les **constantes de pose sont déjà extraites** : `docs/systems/02`, §6 — pas
  de 0x55 = 85 unités, décalage +24, gigue `rand()%10`, une tentative sur quatre
  abandonnée d'entrée, rejet si le poids d'influence d'un élément de tuile non
  nul et non-10 dépasse 0,3 (les poses **évitent** les éléments, sauf le
  donjon), une chance sur quatre d'abandonner sous 0,2 d'humidité et de même
  pour la température, espacement minimum de 20 unités, lacet initial uniforme ;
- la **couche d'éléments de tuile** qui les porte existe depuis 1.6, et la
  **carte du jalon 1.10 sait déjà les afficher** ;
- le constructeur est repéré : `cube::Spawn::ctor_0` alloue **0x10f0 octets**,
  et la boucle de pose de `World_populateRegionDecorations` en remplit les
  champs — `+0x28` la sorte, `+0x2c` le code de type d'entité (celui du `switch`
  de §5, donc le même espace que la flore), `+0x34` le niveau, `+0x7a` des
  drapeaux dont `0x200` « porte un inventaire » et `0x1000`, `+0x58` un index
  d'apparence. `creature_generateAppearance` et `creature_initBehaviorByType`
  sont appelées juste après, ce qui donne l'enchaînement complet
  pose → apparence → comportement ;
- **et la pose des filons y trouve son appelant.** Les neuf modèles existent,
  le tirage de rareté est porté, l'étampage vient d'être démontré sur les
  troncs : il ne manque que *où* un filon affleure.

Ce qu'il faudra décider avant d'écrire : un point d'apparition **persiste-t-il**
comme la découverte de la carte, ou se recalcule-t-il à la volée comme la flore ?
L'original le recalcule par tuile et lui donne un niveau **dynamique** — le
niveau maximum des joueurs présents, §7 —, ce qui plaide pour la seconde voie et
évite une seconde base sur le disque.

### Ce qui reste ouvert dans le jalon 1, sans bloquer

- **Le nénuphar n'est pas porté** : le lot des 38 modèles n'en a pas, et
  `CWPalette.surface_index` ne rend jamais `WATER`. Le rôle est identifié, la
  branche de la source aussi (`docs/systems/02`, §8.6).
- **Le lacet libre** de trois rôles — roseau, sous-bois humide, nénuphar. Noté
  dans `CWDecorRules.FREE_YAW`, pas rendu : `CWVoxelModel` ne précalcule que
  quatre quarts de tour. Il faudrait une rotation continue du maillage.
- **La crête de placement à 0,6.** La source emploie 0,5 sur le sol humide,
  0,6 sur le sol végétalisé, 0,7 sur l'eau ; ce projet en garde une seule à 0,5.
  C'est un réglage de taille de plaque, et `PLACEMENT_PASS_RATE` est mesuré sur
  0,5 : le porter demande une part passante par crête, et un budget par surface.
- **Le décalage de cinq** entre les deux moitiés du domaine de types de décor
  (`docs/systems/02`, §8.5). Se lèvera si le consommateur du champ `type` est
  un jour localisé — il ne l'a pas été.
- **Le type 13 (piton de +150) n'a pas de source.** `World_generateRegionFeatures`
  ne le produit jamais. L'effet est porté et testé, mais aucun élément ne le
  porte.
- **Le palier d'un élément est reconstruit.** `formula_inverse` n'est pas résolue
  dans le dépôt d'analyse. Sans effet sur l'altitude, mais il décide si la
  branche de difficulté consomme un tirage, donc il décale la suite du flux.
  Voir `CWTileFeatureGrid._tier_of`.
- **Les types d'éléments 2, 10, 14, 15** n'ont pas été isolés ; 6 = champ de
  rochers, 11 = massif isolé, 12 = plan d'eau, 3 = parcelle bâtie le sont.
- **La numérotation des blocs** est presque établie :
  `terrain_surfaceColor_blend` (@005c56e0) est la règle de surface de l'original
  et n'écrit que cinq types — 4 par défaut, 9, 10, 12 et 6 forcé par l'appelant
  sur la falaise (cette cinquième branche a été portée puis retirée, §7ter.4 ;
  la lecture de la source, elle, tient). Reste à trancher lequel de ses deux
  paramètres climatiques est la température (`docs/systems/02`, §9).

Un cache disque du terrain reste prématuré : la couche d'éléments de tuile écrit
encore dans les données du monde, et c'est elle qui bougerait la première.

| fonction | adresse | rôle |
|---|---|---|
| `WorldInfo_scatterObjectsInArea` | `@005f56c0` | **la cible de 2.6** : choix d'espèce d'un point d'apparition |
| `cube::Spawn::ctor_0` | — | l'enregistrement, 0x10f0 octets |
| `creature_generateAppearance` | `game_misc.cpp:3197` | code d'entité → modèle + boîte (`docs/systems/02`, §5) |
| `creature_initBehaviorByType` | — | l'arbre de comportement, jalon 2.2 |
| `World_generateVegetationCluster` | `@005d8750` | résolveur de contenu d'une tuile : combien d'objets, dans quelle cellule |
| `World_populateRegionDecorations` | `@005cc510` | bâtisseur de village, sites de région 3 et 5 (jalon 4.3) |
| `WorldInfo_placeStructure` | `@005f0ce0` | placement de structures et de leur décor (jalon 4) |
| `terrain_surfaceColor_blend` | `@005c56e0` | la règle de surface d'origine |

**Onze noms trompeurs** ont été relevés dans le dépôt d'analyse ; ils sont
listés dans `docs/ROADMAP.md`, §1.7, « correction de sources ». **Ils sont
douze depuis le 2026-09-06** — voir §7bis.2. Les trois qui comptent pour la
suite : `WorldInfo_scatterObjectsInArea` **ne disperse pas d'objets**,
`World_generateTreeRecursive` **ne génère pas d'arbres**, et
`World_generateWaterOrPathFeature` **ne fait ni eau ni chemin**.

## 7bis. La prochaine session — **les lacs, puis la collision**

Décidé le 2026-09-06, après la question « a-t-on prévu un jalon pour les lacs,
les rivières, les chemins entre POI et les falaises ? ». Réponse : non, aucun des
quatre n'a de jalon, et ils ne sont pas au même stade. L'ordre qui suit n'est pas
un ordre de préférence, c'est celui de leurs dépendances. S'y ajoute un
troisième point, demandé le même jour : **la collision du branchage, du
feuillage, des filons et des cactus**.

**Deux des quatre sont retombés le jour même.** La falaise a été portée puis
retirée (§7ter.4) — elle ne reviendra pas par une règle de surface, et elle
n'est plus dans cette liste. Et les **chemins** en sortent aussi : la fonction qui devait les porter n'en
contient pas, ce qui confirme la correction du jalon 1.6 — la source n'a pas de
réseau de routes, et en faire un serait une création de ce projet, à décider
comme telle. Restent les **lacs**, dont la source est trouvée ailleurs, et la
**collision**.

### 1 — La falaise — **portée puis retirée le 2026-09-06, voir §7ter.4**

Elle était le premier des trois points, et le seul qui n'attendait aucune
décision : une règle de la source, quelques lignes dans `surface_of`, un seuil
déjà relevé. Ce qui restait à écrire était la *mesure* du facteur, et c'est elle
qui a demandé deux essais et une capture — puis le rendu en jeu l'a fait
retirer le soir même.

**Ce qu'il faut en retenir avant de rouvrir le sujet** : peindre de la roche sur
une pente ne fait pas une falaise dans un terrain qui n'a pas de parois (0,65
bloc de dénivelé maximal d'une colonne à la suivante). La falaise n'est donc
**pas un point de règle de surface** ; c'est un travail sur le champ
d'altitude, sans jalon ouvert, et les mesures qui le cadrent sont en §7ter.4.

### 2 — Les lacs — **faits le 2026-09-06, voir §7quater**

> **Cette section est le plan, et il a été suivi.** Elle est gardée telle quelle
> parce qu'elle porte l'analyse ; ce qui a été *trouvé en l'exécutant* — trois
> corrections au pseudo-code, dont une qui change le sens de la passe — est en
> §7quater. À lire dans cet ordre si le sujet revient.

> **Tout ce que cette section disait avant le 2026-09-06 reposait sur un nom, et
> le nom était faux.** L'analyse est en `docs/systems/02`, §10. Ce qui suit
> remplace le plan précédent ; la décision d'architecture qu'il gardait ouverte
> est **tranchée par la source**, et pas dans le sens qu'on attendait.

**`World_generateWaterOrPathFeature` (@005df960) ne fait ni eau ni chemin.**
Elle bâtit un grand objet de végétation en sept variétés : sept `paintSphere` de
**bois**, cinq `World_generateFoliageBlob` de **feuillage**, huit
`WorldInfo_placeStructure` en quatre rotations, et une variété — la 1 — qui est
une **spirale** de trente disques sur quatre tours et demi. La preuve tient dans
un octet : les seuls types qu'elle écrit sont `0x27` et `0x28`, soit, une fois
retiré le drapeau `0x20`, les types **7 (bois) et 8 (feuillage)** — et c'est
`World_generateFoliageBlob`, dont le nom est sûr, qui écrit le second.

Deux conséquences, et la première est une erreur à corriger dans nos propres
notes :

- **l'élément de tuile 12 n'est pas un plan d'eau**, c'est un grand objet de
  végétation posé au centre de sa tuile, rayon 80, hauteur 80, variété 6. La
  ligne de `docs/systems/02`, §4 était marquée « confiance haute » : la
  confiance portait sur *quel appel* le type 12 fait, ce qui est juste, et pas
  sur *ce que cet appel fait*, qui n'était qu'un nom emprunté au dépôt
  d'analyse. C'est le **douzième nom trompeur** ;
- **la source n'a toujours pas de chemins.** Aucune des sept variétés ne trace
  quoi que ce soit entre deux points. Cela confirme la correction du jalon 1.6 :
  un réseau reliant les bourgs serait une création de ce projet, et il faudra le
  dire comme tel. **Les chemins sortent donc de ce point** — ils n'ont plus de
  fonction à analyser, seulement une décision de conception, et elle n'a rien à
  voir avec les lacs.

#### Où l'eau est réellement écrite

Dans **`WorldInfo_generateBiomeContent`** (@005e4850) — la fonction que ce projet
a déjà portée pour la flore —, dans une **autre passe** de la même cellule.
L'algorithme complet est en `docs/systems/02`, §10.2 ; en trois lignes :

```
si  chenal(x, z) <= 0,02                        -- la porte
    q = floor(niveau/5)*5 ;  t = triangle((niveau - q)/5)
    si t >= 0,4 :  [q - 5t + 2 .. q] <- EAU, puis SOL HUMIDE en q
    [q+1 .. niveau + 5*(1 - (50*chenal)^3) + bruit[ <- AIR      -- les berges
```

**La porte est le champ de chenaux, et ce projet le porte depuis le jalon 1.4.**
`WorldInfo_sampleTerrainHeight` ne lit aucune hauteur : c'est
`|bruit(1e-3) + bruit(1e-2)×0,1|`, modulé par un bruit non graîné, plus un terme
de crête — mot pour mot `CWTerrainField._channel`. Il ne manquait pas un champ,
**il manquait un seuil**. `nextsteps.md` écrivait « le réseau de chenaux creuse
bien les vallées, mais rien ne les remplit » ; ce qui les remplit est le même
réseau, à 0,02.

Mesuré sur notre champ, 147 456 colonnes : **3,40 % des terres** passent la
porte, et la rampe `t` n'en garde que 45 % — de l'ordre de **1,5 % des terres en
eau**, en chapelets le long des fonds de vallée. Ce n'est ni vide ni envahissant.
La vérification valait d'être faite avant d'écrire : c'est la leçon de la
première règle de Lava Lands, *une règle peut être juste et vide*.

#### La décision d'architecture est tranchée — et elle était plus petite qu'on ne croyait

Deux fois plus petite, et pour une raison qu'on avait sous les yeux.

**La source écrit l'eau comme matière** : type 2, colonne par colonne. C'était
l'issue n° 2 des trois, et les deux autres étaient nos inventions. Mais surtout :

> **Ce projet écrit déjà l'eau dans les données.** `CWVoxelGenerator.voxel_of`
> rend `CWPalette.water_index(...)` pour tout `top < y <= sea`, et
> `CWWorldEdits.erase_value` fait de même. La note de `voxel_of` le dit en
> toutes lettres depuis le jalon 1.8 : « **l'original ne stocke pas l'eau** […]
> ici l'eau est écrite dans les données, mais la règle est la même ».

Ce qui est global dans ce projet n'est donc pas le *stockage* de l'eau, c'est son
**niveau** — le scalaire `sea`. Le paragraphe qui annonçait qu'on « perdrait la
règle d'effacement de 1.8 » se trompait de cible : il n'y a pas de bascule
matière/vide à faire, il y a **un scalaire à rendre local**. `voxel_of` prend
déjà `sea` en paramètre ; il suffit qu'il reçoive le niveau *de la colonne*.

#### Le plan de portage, et le seul point qui bloque encore

Ce qu'il reste à écrire, dans l'ordre :

1. **`_sample` passe de `Vector3` à `Vector4`** — `(hauteur, température,
   humidité, **chenal**). `_sample` est **interne et n'a que deux appelants** ;
   `sample_column` et `sample_column_raw` gardent leur `Vector3`, donc **les
   trente-cinq consommateurs ne bougent pas**. Coût : zéro échantillon de bruit
   de plus, `chan` étant déjà calculé.

   > **Révisé le 2026-09-06 au soir, après la lecture** (`docs/systems/02`
   > §10.4). Ce point demandait de sortir l'**ossature continentale** `cont`,
   > parce qu'on ne savait pas laquelle des deux hauteurs était le niveau de
   > l'eau. C'est **la hauteur finale**, c'est-à-dire celle que `sample_column`
   > rend déjà : il n'y a pas d'ossature à extraire. La quatrième composante
   > sert au **chenal**, dont la passe a besoin deux fois — comme porte
   > (`<= 0,02`) et dans le creusement des berges (`5 × (1 − (50·chan)³)`) ;
2. **`sample_patch` passe au pas de 4**, ce qui ne touche que `_get_patch` et
   `tools/preview_features.gd` ;
3. **`pond_span(base) -> Vector2i`**, statique et pure — la quantification, la
   rampe triangulaire, et l'intervalle vide quand `t < 0,4`. C'est la seule
   arithmétique de la règle, et elle se teste seule ;
4. **`voxel_of` teste l'étang en premier**, parce que l'étang *recouvre* le
   terrain — l'ordre des tests doit suivre celui des recouvrements de
   `_generate_block`, comme sa note l'exige déjà. Puis `_generate_block` pose un
   `_fill_run` d'eau et un d'air pour les berges. **L'invariant n° 18 est le
   filet** : la vérification des 4 096 points compare les deux consommateurs, et
   c'est elle qui attrapera une berge creusée d'un côté et pas de l'autre ;
5. **les deux chemins rapides** de `_generate_block` s'appuient sur
   `patch.lowest` / `patch.highest` : creuser les berges **abaisse** la surface,
   donc `lowest` doit suivre, sinon un bloc entièrement plein de roche sera
   rendu là où il y a maintenant un trou. C'est le piège de cette étape ;
6. **la dispersion** : `CWScatter` et `CWTreeScatter` comparent `c.x` au niveau
   de la mer pour refuser de semer sous l'eau. Le test doit passer au niveau de
   la colonne, sans quoi les mares se couvriront d'herbe ;
7. **le sol humide en `q`** ferme une question ouverte depuis le jalon 1.7 :
   `CWDecorRules.FAMILIES_SURFACE` donne au sol humide sa composition — roseau,
   sous-bois — et c'est la **seule exception attachée à une matière** du projet.
   On savait quoi y faire pousser sans savoir qui produisait la matière. C'est
   cette passe, et le roseau aura enfin une rive.

**Plus rien ne bloque.** La lecture est faite le 2026-09-06 au soir
(`docs/systems/02` §10.4) : `terrain_generateColumnColor` rend la **hauteur
finale**, et c'est la fonction que ce projet porte depuis le jalon 1.4 — même
corps, mêmes quatre graines de déformation d'éléments, deux adresses dans les
deux binaires. Le niveau d'un étang est `sample_column(x, z).x`.

Trois marques le disent indépendamment, et une seule aurait suffi : elle
applique la **porte des chenaux** en lissage sur ses octaves de détail (c'était
le test décisif annoncé), elle contient l'**octave à 1e-2**, et elle applique la
**couche d'éléments de tuile**. Plus deux corroborations hors du corps : le
binaire serveur nomme le même appel `World_riverClimateGate`, et un appelant
fait `(int)(h + 1)` pour poser un objet **au sol**.

### 3 — La collision : ce qui en a, ce qui n'en a pas, et ce que ça coûte

Demandé le 2026-09-06 : *la collision doit couvrir aussi le branchage, le
feuillage, les filons et les cactus.* Ce n'était prévu que pour un tiers, et le
reste ne se traite pas d'un seul geste — il y a **trois mécanismes différents**
selon l'objet, et le choix se fait au voxel près.

Le décompte, mesuré sur le lot réel (`tools/inspect_model.gd`) :

> **Ce tableau est résolu depuis le 2026-09-11**, sauf sa dernière ligne. Tout
> ce qui pouvait devenir de la matière l'est devenu ; la colonne « ce qu'il
> faut » est gardée telle qu'elle était écrite, et la colonne d'état dit ce qui
> a été fait.

| objet | aujourd'hui | voxels | ce qu'il faut |
|---|---|---|---|
| tronc d'un feuillu, d'un palmier, d'un grand arbre | **matière** | 406 (charpente) | rien — c'est fait (§7) |
| **branchage d'un grand arbre** | **matière** | compris dans les 406 | rien : les branches sont **dans le modèle de tronc**, donc estampées avec lui |
| houppier, dôme | **matière** (2026-09-11) | 983 le dôme, ×5 par grand arbre ; 2 316 le houppier de chêne | fait |
| arbre entier (`pin`, `sapin_enneige`, `pin_enneige`) | **matière** (2026-09-11) | 692 – 809 | fait — estampé tel quel, donc sans gigue de taille |
| `arbre_epineux` | **matière** (2026-09-11) | 186 | fait |
| `rocher_geant` | **matière** (2026-09-11) | 1 907 | fait |
| les neuf filons | pas encore posés | 13 – 32 | rien de plus : ils sont dessinés à **1 voxel = 1 bloc** pour être estampés, et se minent. Il ne leur manque que leur *pose* (2.6) |
| cactus de flore (`cactus_01`, `cactus_02`) | instancié | 181 et 176 | ils sont à **4 voxels par bloc** : inestampables tels quels. Volume approché, ou rien |

> **Et la dernière ligne reste juste, elle a été réexaminée.** Redessiner un
> cactus à 1 voxel = 1 bloc en ferait une pile de quatre cubes — c'est ce qui a
> fait retirer `cactus_geant` — et estamper un volume approché mettrait un pâté
> de blocs *visible* à l'intérieur du modèle fin, qui continue d'être instancié.
> Ce que le cactus veut est **une forme de physique**, pas de la matière, et
> c'est le jalon 3.1.

> **Ce que la mesure a dit, le 2026-09-11.** Le passage du feuillage en matière
> coûte **+5,4 %** sur une vue de 384 blocs (26,1 → 27,5 s), là où ce fichier
> annonçait +25 %. Et la répartition est contre-intuitive : écrire douze fois
> plus de voxels coûte **0,4 s**, faire reculer la borne du chemin rapide de 48
> à 72 blocs en coûte **1,0** — et cette seconde dépense se paie partout, y
> compris au-dessus d'un désert sans un arbre.

> **Le tableau a perdu une ligne le 2026-09-06** : `cactus_geant` est retiré du
> lot (§7ter.3), et avec lui le seul objet du désert qui aurait pu passer en
> matière. Le désert n'a donc **plus rien à estamper** hors les troncs de ses
> trois arbres : ses cactus sont passés du côté de la flore, où la question du
> volume approché est la seule qui se pose. Les modèles entiers sont **cinq** et
> non plus six.

**Ce qui est déjà réglé, et il faut le savoir avant d'ouvrir le sujet :** le
branchage a la collision. Les quatre branches d'une charpente sont dessinées
*dans le modèle de tronc*, pas ajoutées par l'assembleur, donc `_stamp_trunks`
les écrit avec le fût. Idem pour les filons : leur grille a été choisie pour ça
au jalon 1.11, la seule chose qui leur manque est l'endroit où les poser.

**Les six modèles entiers sont le morceau facile**, et il vaut d'être fait tôt :
ce sont des objets *solides* — un cactus, un rocher, un arbre mort — et les
passer en matière tient en une ligne (`pied.matiere = true` sur le montage
ENTIER, plus leur hauteur). Coût : 186 à 1 907 voxels par instance, sur des
espèces rares. Le rocher géant est le cas le plus évident : il est déjà peint
dans la matière de roche, et c'est le seul objet du monde qu'on contourne
aujourd'hui en le traversant.

> **Le feuillage est le seul vrai arbitrage, et il ne se tranche pas au
> sentiment.** Le passer en matière multiplie par douze ce qu'un arbre écrit
> dans le monde — 406 voxels aujourd'hui, ~5 300 avec ses cinq dômes — et
> l'étampage des troncs coûte déjà +2 % du chargement. Ce serait donc de l'ordre
> de +25 %, sur le poste qui est déjà le verrou de la distance de vue. Et ça
> change deux autres choses : le feuillage deviendrait **creusable au bloc près**
> (une pioche qui perce un houppier), et **opaque à l'éclairage voxel** (une
> forêt dans le noir sous ses arbres, ce qui est peut-être voulu).
>
> L'autre voie est un **volume approché**, décidé au jalon 3.1 avec le
> contrôleur : la couche de dispersion donne déjà tout ce qu'il faut — position,
> rayon et hauteur de chaque pièce sont dans `Placement`, et un cylindre aplati
> par dôme coûte une forme de physique et zéro voxel. C'est ce que la feuille de
> route prévoit pour les entités, et c'est probablement la bonne réponse ici
> aussi.
>
> **Ce qu'il faut vérifier avant de choisir** : à quelle hauteur commence un
> houppier. Sur le lot agrandi, les dômes d'un grand arbre démarrent entre 15 et
> 25 blocs, très au-dessus d'un personnage de 2,4 — un joueur au sol ne les
> rencontre jamais. La question ne se pose donc vraiment qu'au jalon 3.4, avec le
> vol à voile et l'escalade. Ce n'est pas une raison de ne rien décider, c'en est
> une pour **ne pas payer la matière** avant de savoir qui la touchera.

**Et une remarque qui vaut pour tout ce tableau :** rien de tout cela ne se voit
tant que `generate_collisions` est à faux sur le terrain de la démo. La matière
est là, le corps qui s'y cogne n'existe pas — c'est le jalon 3.1 qui allumera
les deux, et c'est à ce moment-là qu'il faudra que ce tableau soit juste.

### Et 2.6 reste ouverte

L'apparition n'attend rien de ce qui précède : la fonction est lue, les
constantes de pose extraites, la couche d'éléments existe depuis 1.6 et la carte
sait les afficher (voir la section suivante). C'est l'autre porte, et elle mène
au jalon 2 plutôt qu'à la fin du jalon 1.

---


## 7ter. Le 2026-09-06 — **moins de flore, trois assets retirés, et la falaise faite puis défaite**

Demandé le 2026-09-06 dans cet ordre, et c'est l'ordre où ça a été fait : baisser
la quantité de flore en général, retirer les deux grands arbres de Snowlands,
retirer le cactus géant du désert et refaire ses deux cactus de flore, puis
passer au point suivant de §7bis — la falaise, **portée le matin et retirée le
soir sur le rendu en jeu** (§7ter.4).

### 7ter.1 La densité de flore descend de 40 %, uniformément

`CWModelLibrary.DENSITY` est multipliée par **0,6** sur les six biomes :
Greenlands 9,0 → 5,4, Snowlands 2,5 → 1,5, Deserts 1,4 → 0,85, Jungles 14,0 →
8,4, Lava Lands 1,2 → 0,7, Oceans 2,5 → 1,5.

**Le facteur est uniforme, et c'est le point.** Le rapport entre biomes n'était
pas en cause — une jungle doit rester six fois plus fournie qu'une plaine de
neige, et c'est le seul repère qu'on ait de l'original. Ce qui a bougé est
l'échelle commune, et elle a bougé d'un seul coup pour que la comparaison d'un
biome à l'autre reste lisible.

Ce que le réglage précédent avait raté, et qui vaut d'être noté parce que
l'erreur est reproductible : le jalon 1.12 avait bien vu que des plantes deux
fois et demie plus grandes couvrent plus de sol, et avait baissé les densités en
conséquence — **le bon geste, pas assez loin**. La raison est qu'on ne compare
pas une densité à une densité : on la compare à la **surface de sol qui reste
libre**. Une prairie où l'on distingue chaque touffe se lit comme une prairie ;
une prairie où les touffes se touchent se lit comme un tapis, et le relief sous
elle disparaît.

### 7ter.2 Snowlands n'a plus de grand arbre

Le saule givré et l'arbre pourpre sont retirés — table (`CWTreeRules`),
générateur (`generer_arbres`) et les quatre `.vox`. Ils avaient été dessinés la
veille au soir avec les huit autres.

**La raison n'est pas leur exécution, c'est leur montage.** Un `Montage.GRAND`
tient sa lecture de l'**étalement de ses cinq masses** — c'est un arbre isolé
qu'on remarque de loin, une silhouette d'été. Une taïga se lit exactement à
l'inverse, par des **flèches étroites**. Les deux ne se rencontrent pas, et les
peindre en froid (blanc-bleu et violet, comme l'exigeait l'invariant n° 29)
n'avait rien changé au fond : c'étaient deux arbres d'été peints en froid.

Le biome garde ses deux conifères entiers et son bouleau givré, et leurs poids
n'ont pas bougé — ils sommaient déjà 1,0 avant que les grands arbres s'ajoutent.
Le compte en dur de `tests/tree_test.gd` passe de dix à huit ; c'est le seul
intérêt de cette vérification, dire qu'on n'a pas perdu une espèce sans le
vouloir.

### 7ter.3 Le désert perd son cactus géant et gagne deux vrais cactus

**`arbres/deserts/cactus_geant` est retiré.** Sa propre note disait déjà qu'il
n'était pas un arbre et qu'il n'était rangé là que par sa taille ; c'est
justement la taille qui n'allait pas. À **un voxel par bloc**, un saguaro de
3,5 blocs de large n'a ni cannelure, ni épine, ni galbe — il a la forme que la
grille lui laisse, c'est-à-dire un poteau. Il pesait 0,6 sur quatre espèces, donc
c'était le poteau le plus fréquent du biome.

Les trois poids restants sont redistribués et **l'acacia passe devant** (0,5
contre 0,3 au dattier et 0,2 au baobab) : à poids constants, le dattier — un
arbre d'oasis — serait devenu l'espèce dominante du désert, ce qui est le
contraire de ce qu'il décrit.

**Et les deux cactus de flore sont refaits**, à 4 voxels par bloc, là où ils ont
la place d'avoir une forme :

* **`cactus_01`, le saguaro**, monte à **16 voxels — 4 blocs, le plafond de la
  flore**, ce qui en fait la plus haute plante du lot et lui laisse reprendre la
  place que le cactus géant laisse vide. Trois choses le distinguent d'un
  poteau, et aucune ne coûte cher :

  1. **les cannelures.** La nouvelle primitive `flore_blocs.colonne_cannelee`
     prend sa teinte sur l'**azimut** du voxel et non sur son rayon : quatre
     crêtes claires, quatre sillons sombres. Le motif ne dépend pas de la
     hauteur, donc il tient en bandes verticales sur tout le fût — c'est ce qui
     se lit de loin, et c'est gratuit. Les deux valeurs (0,80 et 0,08) sont
     calées pour que la rampe des cactus, qui n'a que **quatre entrées**, soit
     employée de bout en bout ; à moins d'écart, crête et sillon tombent sur le
     même index et la cannelure ne se voit pas du tout ;
  2. **le fuselage**, 1,5 voxel de rayon au pied, 1,1 à la cime ;
  3. **les bras à des hauteurs différentes**, 4 et 7 — deux coudes au même
     niveau rendent un chandelier symétrique.

  > **Le fût est mince parce que les bras en dépendent.** Premier essai, fût à
  > 2,0 de rayon et bras à 3 : les deux premiers voxels du coude tombaient
  > *dans* le fût, et le bras se posait contre lui sans un voxel d'air entre les
  > deux. Il n'y avait donc pas de bras, seulement une bosse. **Ce qui fait lire
  > un saguaro n'est pas le bras, c'est le jour qu'on voit entre le bras et le
  > fût.**

* **`cactus_02` devient un figuier de barbarie** — trois raquettes empilées et
  ses figues rouges — là où c'était un tonneau. Un tonneau à cette grille est un
  **seau** : un cylindre de 8 de haut sur 4 de large n'a aucun trait à montrer,
  et la planche de validation ne pouvait pas le lire autrement.

  L'oponce résout deux choses à la fois. Il donne au désert la seule silhouette
  **large et basse** de son lot, ce qui le distingue enfin du saguaro au lieu
  d'en être une version courte ; et c'est **déjà le nom que la table de récolte
  lui donne** — `CWFloraDrops` rend « prickly pear » pour les deux cactus depuis
  le jalon 1.7, sans qu'aucun des deux modèles n'en ait jamais eu la forme.
  Nouvelle primitive : `flore_blocs.raquette`, la seule forme plate du lot.

* **Les aréoles** (`flore_blocs.epines`) sont le troisième ajout, et leurs deux
  réglages ont été corrigés après les avoir vues. Une épine n'a pas de taille à
  cette grille — un voxel fait un quart de bloc, une épine de saguaro un
  centième — donc ce qu'on dessine est l'**aréole**, la tache d'où elle part. À
  l'index 14, la roche claire, elle ne se lit pas comme une épine mais comme un
  caillou collé, ou pire comme de la neige ; le grès (21) est ce que la palette
  a de plus proche, et il a l'avantage d'être la couleur du sol sur lequel la
  plante pousse. Et à une chance sur six elles couvraient la cannelure qu'elles
  étaient censées ponctuer : une sur quatorze laisse voir le fût, qui est le
  sujet.

### 7ter.4 La falaise — portée le matin, retirée le soir

**Retirée.** Demandée en une phrase : *au final ça ne rend pas si bien que ça en
jeu.* Le code est parti en entier — `CLIFF_STEP`, `CLIFF_SLOPE_REF`, le treillis
et son cache, `cliff_factor`, `CWPalette.CLIFF_RIDGE`, le septième paramètre de
`surface_of` et `surface_index`, l'histogramme de `biome_stats`, les trois
vérifications de `decor_test`, et les invariants n° 37 et 38. Ce qui suit est ce
qui **ne** doit pas repartir avec, parce que ça a coûté deux essais et une
capture et que ça décrit le terrain et non la règle.

#### Ce que le retrait apprend, et qui n'était dans aucun test

Le portage était fidèle : la règle est bien dans la source, le seuil de 0,5 est
relevé et non choisi, la pente était mesurée, les trois vérifications passaient,
le surcoût était sous le bruit de mesure. Il a quand même échoué, et **la cause
était lisible dans les mesures du matin sans qu'on la lise** :

> À `CLIFF_SLOPE_REF = 2,0` la règle rendait 0,62 % des terres. On a lu « le
> seuil est trop haut » ; il fallait lire **« il n'y a pas de falaise dans ce
> terrain »**. Baisser le seuil à 1,0 n'a pas trouvé de parois — il a **teinté
> des flancs à vingt-sept degrés**. De la roche grise sur un flanc vert ne se
> lit pas comme une paroi, elle se lit comme une tache.
>
> **Une falaise ne se peint pas, elle se taille.** Tant que `_height_from` ne
> produit pas de discontinuité, il n'y a rien à habiller, et aucune règle de
> surface ne fabriquera la forme qui manque.

**C'est le même défaut de méthode que les bandes d'altitude (§6ter.6), pris par
un troisième bout** — et §6ter.6 annonçait justement, le matin même, que la
roche nue reviendrait par la pente. Elle est revenue par la pente, et elle est
repartie. À chaque fois : une règle défendable, des tests verts, et un échec que
seul un écran montre. *Une matière qui ne porte rien est un trou ; une matière
qui n'habille rien est une tache.*

**À quelle condition elle peut revenir** — c'est un travail sur
`CWTerrainField._height_from` et pas sur `CWPalette` : un terme de terrasse, une
discontinuité, quelque chose qui casse la douceur du bruit à interpolation
cosinus. Pas de jalon ouvert pour ça ; les trois mesures ci-dessous le cadrent.

#### Les trois mesures, gardées telles quelles

Elles portent sur le **champ d'altitude** et resserviront à l'identique.

1. **Ce monde n'a pas de parois.** Sur huit mille colonnes en ligne, le plus
   grand dénivelé d'un bloc au suivant est de **0,65 bloc**. Un relief fait de
   bruit de valeur à interpolation cosinus est lisse par construction ; ce
   qu'il a de plus raide est un flanc, et un flanc de montagne de ce monde est
   à un demi.
2. **Quarante-cinq degrés ne décrit rien ici.** `CLIFF_SLOPE_REF = 2,0` rendait
   0,62 % des terres ; à 1,0 — quatre blocs de dénivelé sur huit parcourus — la
   roche prenait 4,4 % des terres, 3,4 % du monde.
3. **Un pas de treillis long mesure le flanc, pas la paroi.** À 8 blocs comme à
   4, la part qui bascule est la même (4,5 contre 4,4 %), mais la **queue** de
   la distribution change du tout au tout : au-delà d'un facteur de 0,9, huit
   blocs donnent 0,02 % des terres et quatre en donnent 0,29 %, quinze fois
   plus.

Et une mesure de coût, si la mesure de pente devait revenir : un treillis de 4
blocs à sommets partagés — seize colonnes pour quatre échantillons, en cache —
coûte au plus **+6 % par colonne** en borne haute, et **+1 %** mesuré (76,9 µs
contre 76,1, médiane de cinq passes). Prendre la colonne voisine aurait triplé
le coût d'une colonne, qui est le verrou du chargement. **Ne pas citer un
chiffre tiré d'une passe unique** : la première mesure faite ainsi disait +4,6 %
et c'était du bruit, la dispersion d'une passe à l'autre étant de ±6 %.

#### Deux leçons d'outillage, qui survivent au retrait

> **L'ATH de la démo est l'appelant qu'on oublie.** Quand `surface_of` a pris un
> paramètre de plus, les six appelants du moteur ont été corrigés et le septième
> — `_update_hud` — ne l'a pas été : il n'est dans aucun test, et l'erreur y sort
> en `SCRIPT ERROR: Parse Error` au lancement, ce qui ressemble à un blocage de
> chargement et non à une signature manquante. Compté : trois quarts d'heure.
> Toute signature partagée qui change doit être cherchée dans `src/demo/` aussi.

> **La démo et les outils headless ne tournent pas sur la même graine** —
> `world_seed = 2024` contre le défaut 1337. Un point repéré au sondage et visé
> à la capture décrit alors deux endroits différents, et rien ne le dit : les
> coordonnées sont valides des deux côtés, seul le terrain change. Tout script
> jetable qui sert à viser une capture doit poser `p.world_seed = 2024`.
> C'est l'invariant n° 37.

`--ici x z` a été ajouté à la démo pour cela — se poser à un point **nommé**, là
où `--biome` se pose au premier endroit qui convient — et il **survit à ce qui
l'avait motivé** : il sert pour tout objet local. `place_at` est la seconde
moitié de `_finish_biome_search`, extraite pour que les deux posent la caméra à
la même hauteur, sans quoi les captures ne se comparent pas.

## 7quater. Les lacs — **faits le 2026-09-06 au soir**

Le dernier système du monde. Le plan de §7bis.2 a été suivi point par point ;
ce qui suit est ce que **l'exécution** a appris, et qui n'était pas dans le plan.

### 7quater.1 Trois corrections au pseudo-code, trouvées en l'écrivant

`docs/systems/02` §10.2 avait été écrit la veille, depuis une lecture rapide.
Relu ligne à ligne *pour être porté*, il s'est révélé juste dans les grandes
lignes et faux sur trois points. **Le premier change le sens de la passe.**

> **Le sol humide est la rive, pas le lit.** L'écriture du type 3 est gardée par
> « le bloc qui se trouve là n'est pas de l'eau » — garde qui échoue précisément
> quand il y en a. Le sol humide n'apparaît donc que sur les colonnes de la porte
> **où l'eau ne monte pas** : l'anneau autour de chaque mare.
>
> C'est beaucoup mieux, et ça ferme quand même la question ouverte depuis le
> jalon 1.7 : `FAMILIES_SURFACE` fait pousser des **roseaux** sur cette matière,
> et un roseau se tient sur la rive. La lecture précédente les aurait plantés
> sous l'eau.

Les deux autres sont plus petites mais se voient :

- **le lit remonte au-dessus du palier dans le dernier quart.** Quand la rampe
  `t` passe sous zéro — `frac > 0,75`, un quart des colonnes de la porte — la
  source place le sol humide à `q + 5|t|` et commence son creusement au-dessus.
  Sans ce terme, chaque bord de palier est une marche franche de cinq blocs ;
- **la porte de la rampe est `t > 0,2`, pas `t >= 0,4`.** L'écart vient de la
  **troncature entière** : `bas = (int)(q - 5t + 2) <= q` équivaut à
  `2 - 5t < 1`. Cela fait 60 % du palier au lieu de 45 % — et la mesure d'après
  portage donne 58,4 % des colonnes de la porte, ce qui accorde les deux.

*La leçon, et elle vaut au-delà des lacs : un pseudo-code écrit depuis un nom se
relit avant d'être porté.* C'est la même famille de défaut que les douze noms
trompeurs, déplacée d'un cran — non plus le nom d'une fonction, mais le résumé
qu'on en a fait.

### 7quater.2 Le creusement s'exprime en abaissement de colonne

C'est **la** décision d'architecture du portage, et elle n'était pas dans le
plan. La source construit sa colonne puis la creuse ; ce projet la déduit d'un
champ de hauteurs. Simuler le creusement aurait demandé une passe séparée sur le
bloc généré, et l'aurait rendue invisible aux quatre autres consommateurs.

`CWTerrainField.column_profile(hauteur, chenal, mer)` rend donc
`(sol, eau_bas, eau_haut)`, où `sol` est **la colonne déjà tranchée**, et
`pond_span` isole l'arithmétique de la rampe — pure, sans bruit ni sites, testée
seule sur un palier entier échantillonné au centième.

> **Le piège annoncé au point 5 du plan tombe tout seul.** Les deux chemins
> rapides de `_generate_block` s'appuient sur `patch.lowest` et `patch.highest` ;
> un creusement les invalide. En rangeant le sol *après* profil dans
> `patch.heights` et en prenant le minimum ensuite, il n'y a rien à corriger.
> `highest`, lui, doit prendre la **surface libre** — le dessus de l'eau —, sinon
> le chemin rapide du haut rend de l'air à la place d'une mare.

### 7quater.3 Ce que le reste du projet a dû apprendre

- **`_sample` rend un `Vector4`** : le champ de chenaux sort avec l'altitude et
  le climat. Il était **déjà calculé** par `_height_from`, qui s'en sert pour
  éteindre le détail dans les vallées — donc zéro échantillon de bruit de plus.
  `sample_column` et `sample_column_raw` gardent leur `Vector3` et les
  trente-cinq consommateurs n'ont pas bougé ; qui a besoin du chenal appelle
  `sample_column_full` ;
- **`sample_column_raw` ne voit pas les étangs, et pour une raison plus forte que
  l'échelle** : la couche d'éléments de tuile lit cette altitude pour figer celle
  d'un élément. Un étang qui s'y creuserait déplacerait l'élément, qui
  déplacerait le terrain, qui déplacerait l'étang ;
- **les deux dispersions savent nager.** Elles refusent une colonne d'eau et se
  posent sur le sol *après* creusement. Sans le premier test, chaque mare se
  couvre d'herbe flottante ; sans le second, la flore de rive flotte de quelques
  blocs. Et un arbre est de la **matière** depuis le jalon 1.11 : un tronc posé
  dans une mare y resterait, rien ne le retirant ensuite ;
- **l'ATH annonçait « sol 117 » au bord d'une mare dont le fond est à 111.**
  C'est l'appelant qu'on oublie — il n'est dans aucun test —, et c'est
  l'instrument qui sert à viser les captures. Il montre désormais le sol creusé
  et le niveau d'eau.

> **Un test a attrapé le changement de contrat tout seul**, et c'est le genre de
> chose qui justifie la suite : `flora_test` a sorti **145 plantes
> « flottantes »** qui ne l'étaient pas. Il comparait la position de la plante au
> sol *d'avant* creusement. La règle vérifiée est désormais celle du monde
> généré, et une vérification jumelle a été ajoutée — aucune plante dans l'eau.

### 7quater.4 Ce que ça rend, mesuré

`tools/biome_stats.gd` porte désormais le relevé, et c'est le garde-fou du seuil
de 0,02 comme il l'est de ceux de `CWBiome` :

| | part des terres |
|---|---|
| colonnes dans la porte | **3,25 %** |
| dont en **eau** | **1,90 %** (58,4 % de la porte) |
| dont en **rive** | 1,35 % |
| creusement moyen dans la porte | 2,78 blocs |

Profondeur : 1 à 4 blocs, **un quart chacun** — la signature de la rampe
triangulaire, et un plafond que la suite verrouille.

**Coût : sous le bruit de mesure.** Médiane de cinq passes, **76,4 µs par colonne
contre 75,7 sans les lacs**, soit +0,9 % quand la dispersion d'une passe à
l'autre est de ±6 %. Le chiffre de 73,8 µs cité la veille venait d'une passe
unique — c'est exactement ce que §7ter.4 met en garde de ne pas faire, et c'est
ce dépôt qui s'y est repris.

`tools/find_pond.gd` a été ajouté pour viser une capture : il rend des
coordonnées `--ici` sur **la graine 2024**, celle de la démo, ce qui est
l'invariant n° 37.

### 7quater.5 Les deux choses laissées ouvertes

- **la rive n'est humide qu'en Jungles.** `FAMILIES_SURFACE[SWAMP]` appelle le
  rôle ROSEAU et le seul modèle du lot est `jungles/roseau` : poser du sol humide
  dans les cinq autres biomes rendrait un anneau **nu** autour de chaque mare.
  *Une matière qui ne porte rien est un trou dans le monde* — payé trois fois
  déjà (les franges d'humidité, les bandes d'altitude, la falaise), et on ne le
  repaiera pas pour un anneau de deux blocs. La table lue est
  `FAMILIES_SURFACE_BIOME` : le jour où chaque biome aura son roseau, elle
  grandira et la rive suivra sans qu'on retouche au code. **C'est un besoin
  d'assets, pas de code** ;
- **deux termes du champ de chenaux ne sont pas portés** (`docs/systems/02`
  §10.2.1) : des bosses par type de cellule de région, qui **élèvent** le champ
  et donc **interdisent** l'eau près d'un bourg. Les porter déplacerait le lit
  des vallées existantes, donc c'est un travail à faire d'un bloc, avec une
  capture avant et après.

## 7quinquies. Cinq corrections vues en jeu — **2026-09-06, fin de soiree**

Demandees apres avoir regarde le monde des lacs. Aucune n'est un bogue : ce sont
cinq endroits ou le portage fidele ne donne pas ce qu'on veut voir. Elles sont
donc **toutes des creations de ce projet**, et la charte demande de le dire.

### 7quinquies.1 Le marais quitte les biomes et devient une rive

C'etait la derniere frange d'humidite — au-dessus de 0,92 en Jungles — et elle
avait survecu aux deux retraits du 2026-09-06 au matin **parce qu'elle portait
quelque chose** : `FAMILIES_SURFACE[SWAMP]` y fait pousser le roseau, seul modele
du lot attache a une matiere.

Ce qui l'a emportee est un troisieme motif, distinct des deux precedents :

> Les franges d'humidite se **contredisaient** (« Greenlands » sur un sol kaki).
> Les bandes d'altitude ne **portaient rien**. Le marais, lui, portait et ne se
> contredisait pas — mais *une Jungles annoncee « jungle » sur un sol de marais
> dit quand meme deux choses a la fois*. C'est la meme faute que l'herbe seche,
> vue par le nom du biome et non par la couleur du sol.

**Le marais n'a pas disparu du monde** : il est devenu la matiere de **rive** des
cours d'eau (§7quater), ce qui est l'endroit ou un roseau se tient. Il passe de
**6,5 % du monde a 0,1 %**, et surtout il passe d'une frange de climat a un
**lieu** — la meme lecon que la plage, la seule bande d'altitude qui reste :
*une matiere qui vaut la peine est celle qui nomme un endroit, pas celle qui
nuance un gradient.*

### 7quinquies.2 Les provinces climatiques

**Le defaut, releve en jeu :** « un biome neige a cote du desert, c'est bizarre. »

**La cause :** `World_generateRegionSite` tire le climat d'une zone avec un LCG
graine sur `(rx, rz)`, **independamment de ses voisines**, et une fois sur deux
il prend un extreme — froid sous 0,1, chaud au-dessus de 0,9. Deux zones cote a
cote peuvent donc sortir 0,05 et 0,95.

> **Le jalon 1.12 avait mesure la cause sans la reconnaitre.** Il notait que le
> champ de climat est bimodal, « ses quatre coins portent 48 % des terres », et
> l'avait lu comme une propriete du champ. C'en est un defaut, et il a fallu
> marcher dedans pour le voir. *Une mesure ne dit pas toute seule si ce qu'elle
> montre est voulu.*

**Le remede** — creation de ce projet, la source n'a pas de provinces. Un bruit
basse frequence sur la **grille de zones** decide, pour chaque zone qui tire un
extreme, **lequel** (le signe) et **a quel point** (la valeur absolue) :

- au **coeur** d'une province, l'extreme est celui de la source, intact ;
- au **bord**, il glisse lineairement vers 0,5.

> **La seconde moitie est celle qui compte, et c'est le piege du sujet.** Ne
> prendre que le signe aurait regroupe les extremes en provinces et **laisse une
> couture franche entre deux provinces voisines** — c'est-a-dire exactement le
> defaut, seulement plus rare. En adoucissant au bord, un coeur froid et un
> coeur chaud ne peuvent plus se toucher : entre les deux, le champ passe par le
> tempere, et c'est une bande de Greenlands qui apparait la ou il y avait une
> couture.

**Le relief est identique au bloc pres, et c'est delibere.** `base_height` sort
d'un bruit et non du LCG, et **tous les tirages du LCG sont conserves** :
`rng.coin()` est toujours appele, sa valeur simplement ignoree au profit du
champ. Le nombre de tirages ne bouge donc pas, les positions de sites (`rng.mod`
plus bas dans la meme fonction) non plus, et le champ d'altitude non plus.
**Verification** : la part d'ocean est inchangee **au chiffre pres**, 12 108
colonnes sur 49 152 avant comme apres.

| | avant | apres |
|---|---|---|
| Greenlands, des terres | 49,5 % | **57,7 %** |
| Snowlands | 35,8 % | 13,9 % |
| Deserts | **1,2 %** | **13,9 %** |
| Jungles | 9,6 % | 11,6 % |
| Lava Lands | 3,8 % | 2,9 % |
| coin froid-sec du climat | 17,98 % | **0,00 %** |
| paires neige/desert a 4 096 unites | 6 sur 50 083 | **0** |

Les deux dernieres lignes sont la mesure qui compte. Le desert, lui, passe de
1,2 % a 13,9 % des terres : il etait si rare qu'on ne pouvait pas juger de sa
forme.

> **La mesure de voisinage se prend a 4 096 unites, pas a 256.** Premiere
> version : les cases adjacentes de la grille de sondage. Elle rendait **1 paire
> sur 71 937 avant** et 0 apres, c'est-a-dire rien dans les deux cas — a 256
> unites deux sondages tombent presque toujours dans le meme climat. Ce qu'on
> veut savoir est si l'on **traverse du tempere** en allant de la neige au
> desert, et ca se juge a l'echelle d'une marche. *Une mesure qui rend zero avant
> comme apres ne mesure pas ce qu'on croit.*

**Trois constantes reglees a l'oeil sur une seule graine** — `PROVINCE_FREQ`,
`PROVINCE_CORE`, et les deux decalages de graine. Elles n'ont pas ete balayees ;
`tools/biome_stats.gd` rend tout ce qu'il faut pour le faire.

### 7quinquies.3 L'eau descend d'un bloc sous la rive

Dans la source, l'eau monte jusqu'au palier `q` et la berge est tranchee au meme
`q` : les deux affleurent. **Une nappe a ras bord ne se lit pas comme de l'eau**,
elle se lit comme une matiere bleue posee a plat. Un bloc d'ecart
(`POND_BANK_DROP`) suffit a lui donner un bord, et c'est immediat en capture.

### 7quinquies.4 Les rivieres sont reliees, et finissent en lacs

**Le decoupage venait de la rampe triangulaire**, qui ne laissait passer l'eau
que sur 60 % d'un palier : un cours d'eau s'interrompait chaque fois que le
terrain traversait un multiple de 5. La rampe garde le **fond** et perd la
**presence** — il y a toujours au moins un bloc d'eau dans le lit
(`POND_DEPTH_MIN`). Le trace redevient continu et la rampe garde son role : elle
creuse les cuvettes et laisse les seuils peu profonds.

**Pour les lacs, le seuil du chenal n'est plus constant** : 0,02 en altitude — la
valeur de la source — et **0,055 au ras du niveau de la mer**, l'ecart se
refermant sur les 90 premiers blocs.

> Un reseau de chenaux **ne dit pas ou est un bassin** : il faudrait un
> voisinage, donc un cout par colonne qu'on ne peut pas payer. Mais il dit
> l'altitude, et *une riviere qui s'elargit en descendant est ce qu'on voit d'un
> bassin*. C'est un lac obtenu par ou il arrive, et non par sa forme.

Mesure : une fenetre de 64 blocs autour d'un point bas est a **27 % d'eau**,
contre un ruban en altitude. Seul un quart des terres est sous 90 blocs, donc
l'elargissement ne touche que le bas des vallees — ce qui est le but.

### 7quinquies.5 Ni Deserts ni Lava Lands n'ont d'eau

La source n'a pas de biomes — c'est une couche de ce projet, jalon 1.12 — donc
cette regle non plus. Elle se defend seule : un desert est defini par l'absence
d'eau, et une nappe au milieu des coulees demanderait une vapeur qu'on n'a pas.
`column_profile` et `pond_gate` prennent donc le biome, et les six appelants
l'avaient deja sous la main.

### 7quinquies.6 Ce que le point 4 a casse, et qu'il a fallu rattraper

**Avec de l'eau partout dans la porte, la rive disparaissait** — 100 % de la
porte en eau a la premiere mesure. Et avec elle le sol humide, donc le roseau,
donc un modele range sous un role inatteignable : le defaut que
`tests/decor_test.gd` guette depuis le jalon 1.7.

La rive redevient ce qu'elle est dans le paysage : **la bande exterieure du
lit** (`POND_WATER_FRAC` = 0,82), celle ou le chenal est encore sous le seuil
mais deja trop haut pour porter de l'eau. Elle a l'avantage d'etre **continue le
long du cours d'eau**, la ou celle de la source apparaissait par plaques entre
deux mares.

*C'est la troisieme fois de la journee qu'une regle d'eau ou de matiere se
verifie par « qu'est-ce qui pousse dessus ». Ce n'est plus une coincidence : dans
ce projet, une matiere se juge par son decor.*

## 7sexies. Les surplombs, les grottes et les chemins — **faits le 2026-09-07**

*Trois systemes demandes en regardant trois captures du jeu d'origine a cote du
notre. Aucun n'est dans la source, et c'est ecrit en clair dans l'en-tete des
trois fichiers : ce sont des creations de ce projet.*

### 7sexies.1 Ce qui a ete demande, et ce qui en a ete fait

| demande | reponse |
|---|---|
| reintegrer la surface de la falaise | `CWPalette.surface_of` prend une **pente**, mesuree par difference avant sur un bloc. 2,6 % des terres |
| un adoucissement entre deux couleurs de surface | `CWPalette.blended` : un **tramage** a deux frequences. Quatre frontieres l'emploient — le haut de plage, la roche de pente, le bord de la chaussee, et la **frontiere entre deux biomes**, qui passe par `CWBiome.at_dithered` |
| des surplombs immenses generes proceduralement | `CWMesa` / `CWMesaGrid` : chapeau plat, paroi verticale, socle etroit. Jusqu'a **64 blocs de vide** sous un chapeau |
| des grottes peu profondes, toujours accessibles par une falaise ou un surplomb | des **tubes** qui percent la paroi du socle, plancher pose sur le sol de leur entree, entree prise sous le chapeau. Accessibles **par construction** |
| des chemins qui relient les lieux, creusent les surplombs, contournent les montagnes, et un pont sur les rivieres | `CWPathNetwork` : arbre couvrant par zone, portes de frontiere partagees, trace relaxe, tranchee bornee, tunnels, tabliers de bois |

### 7sexies.2 L'architecture, en une phrase

**Rien de tout cela n'est un terme du champ d'altitude.** `_height_from` n'a pas
change d'une ligne, et le relief du monde est identique au bloc pres. Les trois
couches sont posees **au-dessus** de lui, et se lisent colonne par colonne :

```
grotte et chemin creusent   (air, deux intervalles distincts)
surplomb remplit            (roche + un dessus plat)
etang mouille               (jalon 1.14)
terrain porte               (le champ)
```

C'est l'ordre de `CWVoxelGenerator.voxel_of`, et c'est l'ordre inverse des
remplissages de `_generate_block`. **Les deux doivent s'accorder** — invariant
n. 18, et la nouvelle suite `tests/relief_test.gd` l'exerce la ou il y a
quelque chose au-dessus du sol, ce que le balayage du jalon 1.8 ne faisait pas :
il tombait sur un champ de hauteurs nu.

> **La consequence heureuse : la recursion n'existe pas.**
> `CWTileFeatureGrid` doit se garder contre la sienne par trois verrous et une
> garde de reentrance, parce que ses elements deforment le champ dont ils lisent
> l'altitude. Une cellule de surplombs et un reseau de chemins peuvent
> echantillonner le terrain librement : rien dans le champ ne les consultera
> jamais. **Le jour ou un terme d'altitude lirait un surplomb, tout l'appareil
> de 1.6 redeviendrait necessaire.**

### 7sexies.3 Les quatre captures qu'il a fallu pour la forme d'un surplomb

Chacune a corrige une chose qu'aucun test ne voyait, et les deux premieres sont
des lecons generales.

1. **une soucoupe volante.** Deformation de bord a 0,01 sur un chapeau de rayon
   76 : longueur d'onde 100 blocs, circonference 480, soit **un lobe et demi sur
   tout le contour**. La deformation *deplacait* le disque au lieu de le
   decouper. *Une deformation de bord ne se regle pas en amplitude, elle se
   regle en **nombre de lobes par tour** — et ce nombre vaut `2 pi r f`, donc il
   se calcule contre le rayon de l'objet, jamais contre l'echelle du monde.*
2. **un tour de potier.** Le socle prenait la deformation du chapeau : sa paroi
   etait une copie reduite du meme contour, les deux silhouettes se
   superposaient exactement. Il a **sa propre deformation**, plus lente et
   decalee — deux echantillons de bruit de plus, payes par les seules colonnes
   d'un surplomb.
3. **un chapeau haut de forme.** La hauteur de paroi etait tiree
   independamment du rayon : les grands chapeaux sortaient plus larges que
   hauts. Elle vaut desormais `18 + rayon x (0,15 a 0,60)`.
4. **vingt champignons identiques.** Un seul profil de socle. Il y en a trois :
   **butte** une fois sur deux (socle presque au bord, paroi droite du sol au
   sommet — c'est la mesa des captures), **surplomb** une fois sur trois,
   **champignon** une fois sur six.

### 7sexies.4 La falaise : pourquoi elle tient cette fois

Le compte rendu de son retrait (§7ter.4) disait a quelle condition elle pourrait
revenir : *il faudrait que le champ d'altitude produise d'abord des parois*.
C'est fait, et deux choses ont change :

- **la roche n'est plus seule.** Une plaque grise sur un flanc vert lisait comme
  une tache parce qu'elle etait le seul accident du paysage ; elle est la meme
  matiere que les parois qui la dominent ;
- **la frontiere est tramee.**

Et un reglage refait en capture, qui se reproduira :

> **A seuil bas, la roche de pente dessine des courbes de niveau.** La pente
> d'un champ lisse est elle-meme un champ lisse : ses valeurs fortes forment des
> **rubans** qui suivent les lignes de plus grande pente, donc les courbes de
> niveau. Posee dessus, la roche cerclait chaque colline de gris — dans l'axe
> meme des marches d'un bloc que la voxelisation dessine deja. Deux
> quadrillages superposes, et le paysage se lisait comme une carte
> topographique. Le remede n'est pas de tramer plus fin, c'est de **ne prendre
> que le haut de la distribution** : `CLIFF_SLOPE_LO` passe de 0,22 a **0,34**,
> ou une pente n'est plus un ruban mais un flanc.

Histogramme des pentes, 36 zones, en part des terres :

| pente (bloc/bloc) | 0,0 | 0,1 | 0,2 | 0,3 | 0,4 | 0,5 | 0,6+ |
|---|---|---|---|---|---|---|---|
| part | 54,9 % | 23,8 % | 10,3 % | 5,5 % | 2,2 % | 1,4 % | 1,8 % |

### 7sexies.5 Le tramage : deux frequences, et c'est la seconde qui travaille

Une seule crete fine rend un **poivre-et-sel** qui se lit comme du bruit de
compression et non comme un sol. En sommant une frequence fine (la maille du
bloc) et une frequence lente (une quinzaine de blocs), on obtient des
**plaques** : des langues de sable qui remontent une combe, des ilots d'herbe
dans une plage.

Mesure, a mi-transition : **49,0 %** de la seconde matiere (donc le tramage est
non biaise), et **88,2 % d'accord entre deux colonnes voisines** — contre 50 %
pour un tirage independant. C'est ce nombre-la qui dit « plaques » et non
« poivre ».

**Cout : deux echantillons de bruit, et seulement dans la bande de transition.**
Hors de la bande, `blended` sort sur son premier test.

**Et la quatrieme frontiere, celle qu'on a failli oublier : entre deux biomes.**
C'est la plus grande du monde — un desert qui rencontre une prairie —, et elle
ne se trame pas de la meme facon, parce qu'il n'y a pas deux matieres a melanger
mais un seuil a franchir. On **brouille donc le climat avant de le comparer aux
seuils** (`CWBiome.at_dithered`) : la frontiere cesse d'etre une courbe de niveau
du champ de climat et devient un ecotone d'une trentaine de blocs. Les
frequences y sont trois fois plus lentes que celles de `CWPalette` — une frange
de biome se compte en dizaines de blocs, pas en unites.

> **Le biome trame ne sert qu'a la matiere du sol.** Le biome *nomme* reste celui
> de `at` : il choisit ce qui pousse, ce que l'ATH affiche et ce que la carte
> teinte. Sans cette separation, une prairie ferait pousser un cactus tous les
> vingt blocs le long de son desert. En frange, une touffe d'herbe se tient donc
> sur une plaque de sable — et c'est exactement ce qu'on voit au bord d'un
> desert.

### 7sexies.6 Les grottes : la garantie est geometrique, pas numerique

*Pas profondes comme celles de Minecraft, toujours accessibles par une falaise
ou un surplomb, jamais besoin de creuser.* Trois faits tiennent la promesse, et
aucun n'est un seuil a regler :

- **l'entree est prise sous le chapeau**, au-dela de la paroi du socle : un
  endroit qui est **deja de l'air** ;
- **le plancher du tube est l'altitude du sol a son entree**, relevee au
  placement : on entre de plain-pied ;
- **le tube ne monte jamais jusqu'au dessus du chapeau** : une grotte qui
  deboucherait au milieu du plateau serait un trou dans le sol.

La verification correspondante se fait **sur le monde genere** et non sur la
regle qui l'a pose : elle part de l'entree, s'eloigne de vingt-cinq blocs a la
hauteur du plancher, et exige de l'air tout du long.

Une grotte sur six traverse le socle de part en part : c'est l'arche.

### 7sexies.7 Les chemins : la seule erreur de conception, et sa lecon

**Des tranchees de seize blocs a paroi verticale**, vues en capture. Avec un seul
jalon de trace tous les 192 blocs, l'altitude du chemin entre deux jalons est une
**corde** : le terrain bombe au milieu, le chemin passe dessous, et la colonne
est tranchee de tout ce qui les separe. Mesure sur un transect : sol 167, chemin
151, accotement de 4,5 blocs pour raccorder les seize.

> **Chercher un itineraire et epouser un sol ne se font pas a la meme echelle**,
> et il n'y avait aucune raison de payer le premier a la maille du second. Le
> trace se fait en deux temps : l'**itineraire** tous les 256 blocs, relaxe (deux
> echantillons de colonne par point et par passe, donc grossier par
> construction) ; le **profil** tous les 32 blocs, pose sur le sol, lisse, puis
> **borne** a 4 blocs de deblai et 3 de remblai.

Et le bornage est repris **une seconde fois, colonne par colonne**, parce
qu'entre deux jalons de profil l'altitude reste une corde : 4 colonnes de
chaussee sur 340 depassaient encore. Ce n'est pas beaucoup, et c'est exactement
le genre d'ecart qui devient une paroi verticale au milieu d'un chemin. *Le
chemin prefere onduler.*

**Ce que la suite de verifications a attrape, et qui n'etait pas un defaut :**
quatre plantes « sur la chaussee », toutes posees sur le **chapeau** d'un
surplomb que le chemin traverse par-dessous, donc quatre-vingts blocs au-dessus
de lui. C'est la verification qui etait fausse, pas le monde — et il a fallu la
capture pour le savoir.

### 7sexies.8 Ce que ca coute

Chargement d'une vue de 384 blocs au demarrage, meme machine, meme graine :

| | stabilisation | ce que la couche coute |
|---|---|---|
| les trois eteintes | 22,2 s | — |
| sans la falaise | 23,3 s | **falaise : 1,8 s** |
| sans les surplombs | 24,4 s | **surplombs : 0,7 s** |
| sans les chemins | 24,9 s | **chemins : 0,2 s** |
| **les trois allumees** | **25,1 s** | **+13 %** |

*Repris le 2026-09-08, apres la seconde passe : **24,1 s** les trois eteintes,
**28,5 s** allumees, soit +18 %. Ce qui s'est ajoute est un echantillon de bruit
par colonne de surface — la teinte propre — et la recherche de direction des
grottes. La reference bouge d'un jour a l'autre : c'est pourquoi elle se reprend
dans la meme session que la mesure.*

Les trois ecarts font 2,7 s et la difference des extremes 2,9 : les couches ne
se genent pas entre elles, et la somme se lit directement.

**Le poste cher est la falaise**, et ce n'est pas sa regle de couleur : la pente
se mesure par difference avant, donc l'empreinte echantillonnee par bloc gagne
une colonne sur chaque axe — **+12,9 % d'echantillonnage**, et
l'echantillonnage du champ est le verrou du chargement depuis toujours. Les
trois bascules `CWWorldParams.overhangs` / `road_network` / `cliff_slope`
existent pour cette mesure, comme `tile_features` avant elles.

> **Les 22,2 s de reference ne sont pas les 18,1 s du 2026-09-06.** C'est le
> meme monde et la meme machine, un jour plus tard : la mesure de chargement
> derive avec l'etat du systeme, et la seule facon de la lire est de **prendre la
> reference dans la meme session que la mesure**. C'est pour cela que les trois
> bascules valent leur ligne de code — sans elles, la comparaison honnete
> demanderait de defaire le travail.

Le reseau de chemins d'une zone coute **350 ms**, une fois, sur le fil qui la
demande ; les autres attendent. On traverse une zone tous les 16 384 blocs.

`sample_column` n'a pas bouge : **73 a 80 us**, la dispersion habituelle.

### 7sexies.9 Ce qui reste ouvert

- **le pied d'une paroi rencontre l'herbe sans transition.** Un eboulis lui
  donnerait son assise ; c'est un talus a poser, et il se lira mieux que la
  paroi elle-meme ne se lit aujourd'hui ;
- **le dessous d'un chapeau est presque plan** — une variation de trois blocs et
  demi le casse un peu, pas assez ;
- **les surplombs et les chemins ignorent les biomes.** Une mesa de Snowlands
  porte de la neige sur le dos, ce qui est juste, mais sa paroi est la meme
  roche grise que partout, et un chemin de desert est en gravier comme ailleurs.
  Une matiere de paroi et une matiere de chaussee par biome seraient un ajout
  d'une ligne chacune dans `CWPalette` ;
- **le reseau ne connait pas les surplombs quand il se trace.** Un chemin peut
  choisir de traverser un socle plutot que de le contourner, parce que la
  fonction de cout ne regarde que l'altitude du champ. Le tunnel qui en sort est
  joli ; ce n'est pas une raison pour le laisser au hasard ;
- **rien ne relie deux zones autrement que par leur bourg.** Les quatre portes
  d'une zone se raccordent toutes a lui, donc traverser deux zones passe par
  deux bourgs. C'est defendable — c'est ainsi que les routes reelles se sont
  faites — mais ce n'est pas un choix, c'est le plus court chemin d'ecriture.


## 7septies. La seconde passe — **2026-09-08**

*Six reproches faits aux trois couches de la veille, en les regardant en jeu.
Chacun a sa reponse, et trois d'entre elles ont demande de defaire quelque
chose.*

### 7septies.1 « L'effet de fusion nuance n'est pas present » — plusieurs teintes par matiere

Le tramage de la veille melangeait **deux couleurs**. Au bloc pres, deux couleurs
ne font pas un degrade : elles font un damier. La frontiere etait bien repartie,
elle n'etait pas *fondue*.

La correction tient a une propriete du rendu qu'on n'avait pas encore
exploitee : depuis le jalon 1.9, un voxel porte **son type dans `CHANNEL_TYPE`
et sa couleur dans `CHANNEL_COLOR`**, et le second n'est pas un index de palette
mais une couleur RVBA libre. *Rien n'oblige deux blocs d'herbe a etre de la meme
teinte.*

D'ou deux nuances, l'une sur l'autre :

* **la teinte de transition.** Entre deux matieres, la couleur **interpole** en
  cinq marches pendant que le type, lui, bascule d'un coup. Le sol garde une
  matiere par bloc — il se creuse, il porte son decor — mais l'oeil lit un fondu
  de cinq tons la ou il ne voyait qu'un damier de deux ;
* **la teinte propre.** Loin de toute frontiere, une prairie prend trois tons de
  vert au lieu d'un. C'est ce qui empeche une plaine d'etre un aplat.

> **Le facteur de fondu est tire du meme bruit que le type**, et ce n'est pas un
> detail : un bloc qui bascule en sable prend une teinte deja tiree vers le
> sable, donc le damier et le degrade sont **en phase**. Avec deux bruits
> independants, on obtiendrait un fondu correct parseme de blocs a contre-teinte.

**Ce que ca a coute au contrat des deux canaux.** `tests/edit_test.gd` verifiait
que la couleur d'un voxel est *exactement* celle de son type. Ce n'est plus
vrai, et c'est voulu : la verification demande desormais que la couleur reste
une **nuance plausible** de sa matiere — a moins de la moitie de la distance qui
la separe de la plus lointaine des couleurs de terrain. Ce qu'elle attrape est
le vrai defaut, *un sol dont la couleur ne dit plus du tout la matiere* ; le
reste, c'est la capture qui le juge.

Cout : **un echantillon de bruit par colonne de surface** pour la teinte propre.
La teinte de transition ne coute rien de plus que le tramage qui la porte deja.

### 7septies.2 « Le joueur doit pouvoir l'escalader » — les surplombs deviennent des massifs

La forme de la veille etait un **chapeau plat sur un socle etroit**. Elle est
retiree, et l'objection ne se discute pas : *un chapeau qui deborde de son socle
n'est pas escaladable, il est fait pour ne pas l'etre*.

La forme est maintenant un champ de bosses :

```
f(x, z) = (1 - u²) + bruit lent + bruit fin
dessus  = sol de la colonne + hauteur x max(0, f)²
```

Trois choses la rendent gravissable, et les trois ont ete trouvees en mesurant :

1. **le dessus se mesure depuis le sol de *sa* colonne**, pas depuis celui du
   centre du massif. Une masse posee sur un flanc qui descend de douze blocs
   entre son centre et son bord finissait sinon par une **marche de douze
   blocs** sur tout son contour. Mesure avant correction : 12 blocs de marche
   sur un massif de 16 de haut ;
2. **le profil est au carre**, `f²` et non `f`. La masse rejoint le sol
   **tangentiellement** : sa pente s'annule sur son contour au lieu d'y valoir
   son maximum. Sans cela, un ressaut d'un ou deux blocs tout autour ;
3. **les frequences des deux bruits de forme sont relatives au rayon.** Un bruit
   a frequence fixe donne dix lobes a une grosse masse et un demi-lobe a une
   petite — deux formes qui n'ont rien a voir, et sur la grosse une pente
   proportionnelle a la hauteur qui finit par depasser le bloc par bloc.

**Le contrat est verifie, pas suppose.** `tests/relief_test.gd` balaie un massif
en croix sur vingt-quatre rayons et releve la plus grande marche. Elle vaut
**deux blocs**, et deux est le minimum atteignable : le dessus vaut
`plancher(sol) + plancher(hauteur x f²)`, et chacun des deux termes a le droit
de changer d'une unite d'une colonne a la suivante.

> **Un massif tout vert est une colline, pas un relief.** La regle de falaise ne
> peut pas l'aider : elle mesure la pente du **champ d'altitude**, qui ne sait
> rien de cette couche. On prend donc l'**epaisseur** — la frange, ou la masse
> affleure de deux ou trois blocs, garde l'herbe du pre qu'elle traverse ; le
> coeur, ou elle fait dix blocs et plus, est de la roche nue. C'est un
> affleurement, et c'est ce qui le fait voir.

Le seul surplomb qui subsiste est le **porche** d'une grotte, et il est la pour
une raison : rendre l'entree visible.

### 7septies.3 « Plus profondes, plus aleatoires, entree plus visible » — les grottes

* **plus profondes** : la galerie fait de 55 a 130 % du rayon du massif, contre
  un tiers. Mesure sur la zone de depart : **67 blocs** pour la plus courte ;
* **plus aleatoires** : l'axe est une **ligne brisee** de deux a quatre coudes,
  avec un ecart lateral qui va jusqu'a la moitie du segment. On ne voit pas le
  fond depuis l'entree ;
* **plus visible** : la bouche s'**evase** — deux fois le rayon de la galerie —
  et le dessous de la masse se souleve autour d'elle. C'est le **porche**.

Et une correction que seule la verification d'acces pouvait attraper :

> **Sortir de la masse ne suffit pas a voir le ciel.** La premiere version
> partait de la premiere colonne assez epaisse pour contenir une galerie : le
> tube etait alors emmure derriere quelques blocs de flanc. La seconde part du
> **seuil** — la derniere colonne ou la masse n'a aucune epaisseur. Et il a fallu
> une seconde correction : un massif pose au pied d'un versant a des cotes ou le
> terrain **remonte** des qu'on le quitte, et une galerie percee de ce cote-la
> donne sur un talus. On essaie donc **huit directions** et on garde la premiere
> qui descend.

### 7septies.4 « Toujours creuses d'un bloc, et plus larges » — les chemins

`MIN_CUT = 1` : la chaussee est **toujours en contrebas** du terrain qui la
borde. C'est ce qui lui donne son ombre portee et sa berge, donc ce qui la fait
lire comme un chemin plutot que comme une bande de gravier peinte. Sur
l'accotement, la borne se releve avec le raccord, sinon le bord serait une
marche au lieu d'une pente.

Largeur : la demi-chaussee passe de 3 a **4,5 blocs**, l'accotement de 5 a 5,5.

### 7septies.5 « Un degagement proportionnel, sans le couper en deux » — les tunnels

Six blocs sous quarante blocs de roche est un terrier. Le degagement vaut
desormais **55 % de la masse traversee**, avec deux bornes : jamais moins que
les six blocs d'avant, et **jamais au point de laisser moins de huit blocs de
toit**. Sans la seconde, le chemin ne perce plus le massif, il le coupe en deux
et laisse une tranchee a ciel ouvert la ou on attendait une arche.

### 7septies.6 « Redessine les ponts a six voxels par bloc » — le lot d'ouvrages

Un tablier de matiere est fait de blocs d'un metre, et un ouvrage d'art fait de
blocs d'un metre est une planche posee sur l'eau. Le pont suit donc le **partage
du jalon 1.11**, celui du tronc et du houppier : la matiere d'un cote, le detail
de l'autre.

* le **tablier** reste de la matiere, un bloc d'epaisseur : c'est le sol sur
  lequel on marchera, et qu'on pourra abattre ;
* l'**ouvrage** — platelage, longerons, garde-corps, poteaux et leurs chapeaux —
  est un modele a **six voxels par bloc**, la grille la plus fine du projet,
  instancie par `CWBridgeRenderer` le long du franchissement.

Le garde-corps de matiere de la veille est retire : il faisait double emploi.

> **Le lacet est libre, et c'est le seul endroit du projet ou on l'accepte.** La
> flore et les arbres se posent au quart de tour, parce que leurs voxels doivent
> rester alignes sur la grille du monde. Un pont suit une courbe : une travee
> alignee au quart de tour le plus proche serait de travers une fois sur deux. A
> six voxels par bloc, un platelage de biais se lit comme un platelage de biais.

**Deux erreurs a la pose, et la seconde valait la premiere.** La travee a sa
**longueur sur son axe X** : `Basis(UP, yaw)` envoie X local sur `(cos, 0, -sin)`,
donc l'angle qui l'aligne sur le trace est `atan2(-dz, dx)` et non `atan2(dx,
dz)` — avec le second, la travee est en travers du pont. Et l'echelle : sans le
facteur `1 / voxels_par_bloc`, le modele sort **six fois trop grand**, ce qui
sur un pont de neuf blocs de large donne une plate-forme de cinquante.

**Et une erreur de conception, celle qui a demande le plus de reflexion.**

> **Le profil d'un chemin ne voit pas les rivieres.** Il pose un jalon tous les
> 32 blocs ; une riviere de ce monde en fait six de large. Elle passe donc
> **entre deux jalons** neuf fois sur dix, et le premier releve des
> franchissements n'a trouve **aucun** des ponts qu'on voyait en jeu — la
> matiere du tablier, elle, se decide colonne par colonne et les posait bien.
>
> On raffine donc, mais seulement la ou il peut y avoir de l'eau : le champ de
> chenaux est deja lu a chaque jalon et il est **lisse**, donc un jalon a trente
> blocs d'une riviere a deja une valeur basse. Moins d'un segment sur dix est
> raffine, et il l'est de quatre blocs en quatre blocs. *Un releve grossier
> d'une chose fine ne se corrige pas en affinant tout ; il se corrige en
> affinant la ou la chose peut etre.*

### 7septies.7 Ce qui reste ouvert

- **le pied d'un massif rencontre l'herbe sans transition** — moins qu'avant, le
  raccord etant tangentiel, mais un eboulis lui donnerait son assise ;
- **les massifs et les chemins ignorent les biomes** : meme roche d'affleurement
  et meme gravier de chaussee partout ;
- **le reseau ne connait pas les massifs quand il se trace.** Le tunnel qui en
  sort est joli ; ce n'est pas une raison pour le laisser au hasard ;
- **le tablier d'un pont n'a pas de piles.** Sur une riviere de six blocs, ca ne
  se voit pas ; sur un bras de mer, ca se verra.


## 7octies. La troisieme passe — **2026-09-09**

*Les six points releves en jeu le 2026-09-08 au soir, traites dans l'ordre ou
ils se voient.*

### 7octies.1 « De l'herbe dans le desert » — l'ecotone se borne en blocs

Le tramage de biome du 2026-09-07 brouille le climat d'une amplitude fixe —
0,07 en temperature, 0,09 en humidite — **avant** de le comparer aux seuils.
Une amplitude en unites de climat ne dit rien de la largeur de la frange **en
blocs** : celle-ci vaut l'amplitude divisee par la pente locale du champ de
climat.

**Et cette pente n'est pas ce qu'on croyait.** L'hypothese de depart etait « une
pente douce a l'echelle de la region, plus faible par endroits ». La mesure dit
autre chose, et c'est elle qui a rendu la correction evidente : le champ de
climat est fait de **plateaux exactement plats** separes de transitions
**etroites**. Le poids d'un site vaut `1 - min(1, (d2 - d2min) * 5e-7)`, donc il
tombe a zero des qu'un site est plus loin que ~1 400 unites de plus que le plus
proche ; au centre d'une region, le melange ne retient plus qu'**un seul site**
et le gradient y est **exactement nul**. Un sondage l'a montre d'un coup : sur
une frontiere Greenlands/Deserts, le gradient reel valait 0,0026 par bloc, et
celui mesure 500 blocs plus loin, dans le plateau, valait 0,000000.

Sur un plateau, un brouillage de 0,07 ne deplace pas une frontiere : **il tire a
pile ou face sur chaque colonne d'un pays entier.** C'est litteralement ce qui
mettait du sable au milieu des Lava Lands — dont le seuil, `LAVA_T = 0,985`, ne
se rencontre justement qu'au coeur d'une region, la ou le champ est le plus
plat.

**La regle qui en decoule tient en une phrase : la ou le climat est plat, il n'y
a pas de frontiere, donc il ne doit pas y avoir de frange.** L'amplitude devient
`min(DITHER_*, gradient x FRINGE_BLOCKS)`, avec `FRINGE_BLOCKS = 32` — le nombre
que la note du 2026-09-07 annoncait deja (« une trentaine de blocs ») et qui
n'etait vrai que la ou la pente valait par hasard ce qu'il fallait.

**Le gradient devait etre abordable, et il l'est parce que le climat se separe
du relief.** `climate_at` passait par `sample_column` : quinze evaluations de
bruit, le champ de chenaux et la couche d'elements, pour deux nombres qui n'en
dependent d'aucune facon. `CWTerrainField.climate_blend` ne fait que la
deformation du domaine et les deux passes sur neuf sites — **12,8 us contre
77,5 pour une colonne**. La formule du melange n'est ecrite qu'une fois
(`_climate_from`), comme `slope_from` pour l'altitude.

> **Le piege, et il a coute une mesure fausse.** La premiere version memoisait le
> gradient par cellule de 512 en le lisant **au coin** de la cellule. Elle
> rendait zero sur la frontiere ci-dessus, et l'ecotone disparaissait au lieu de
> se borner : *une maille plus large que la transition la manque entierement*.
> La maille est donc de **16 blocs**, et la portee de la difference centree de
> **64** — quatre fois la maille. Ce recouvrement n'est pas un detail de
> precision : deux cellules voisines mesurent sur des fenetres communes aux
> trois quarts, donc l'amplitude ne peut pas changer par marches. Une marche
> d'amplitude dessinerait une droite dans la frange, c'est-a-dire exactement
> l'artefact en courbe de niveau que tout le reste du projet evite.

**Ce que ca coute.** Quatre melanges climatiques par cellule de 16, soit pour
256 colonnes : **51,9 us a froid, 0,20 us par colonne amortis** — 0,26 % du cout
d'une colonne. Sur le chemin chaud, l'amplitude est prise une fois par cellule
traversee et non une fois par colonne, comme la fenetre de massifs juste
au-dessus dans la meme boucle.

**Ce que ca rend, mesure.** `tools/biome_stats.gd` ne pouvait pas voir ce defaut
et c'est la seconde lecon : il sonde tous les 256 blocs, et **une frange de
trente blocs lui est invisible**. Il a donc gagne une mesure a la maille du
bloc, qui *cherche* les frontieres de climat au lieu d'esperer en croiser — la
premiere version, sur des transects droits, n'en a rencontre que treize sur
73 000 colonnes, et la plupart etaient des frontieres d'ocean, qui se decident
sur l'altitude et que le tramage ne peut pas changer.

Sur douze frontieres de climat, fenetre de +-128 blocs :

| | avant | apres |
|---|---|---|
| colonnes en frange | 7,72 % | 3,37 % |
| incursion moyenne | **38,2 blocs** | **7,1 blocs** |
| incursion maximale | **140 blocs** (borne par la fenetre) | **25 blocs** |
| franges au-dela du contrat de 32 blocs | 37,0 % | **0 %** |
| premier couple | Deserts -> Lava Lands, 31,5 % | Greenlands -> Snowlands, 26,9 % |

L'incursion maximale de 140 blocs est celle que la fenetre de mesure autorisait
a voir ; la vraie etait plus grande. Et le premier couple d'avant nomme le
reproche mot pour mot.

**La frange n'a pas ete mangee** : 104 colonnes restent en frange, sur les cinq
memes couples de biomes. C'etait l'autre issue possible, et l'outil rend le
message explicite quand elle survient.

**Ce qui n'a pas ete fait, et pourquoi.** La seconde piste du 2026-09-08 —
*refuser purement le tramage entre certains couples, Lava Lands ne se melangeant
a rien* — n'a pas ete prise. La borne en blocs la subsume dans le cas general,
et une exclusion redonnerait a cette frontiere-la le trait net que l'ecotone
existe pour supprimer. Il reste 23 % de franges Deserts -> Lava Lands, bornees a
25 blocs : c'est un ecotone, plus une tache. Le nombre est maintenant sous la
main de l'outil, donc revenir dessus est de la mesure et non de la conception.

### 7octies.2 « Le pas maximum doit varier d'un massif a l'autre »

Les deux amplitudes de contour etaient des constantes partagees : tous les
massifs du monde avaient la **meme silhouette a l'echelle pres**. Elles se
tirent maintenant par massif, d'un **seul** nombre de rugosite — les deux
echelles d'une erosion vont ensemble, et une masse aux grands lobes doux mais a
la peau rugueuse ne ressemble a rien.

Et la borne de marche devient **derivee** plutot que constante. Le dessus vaut
`plancher(sol) + plancher(hauteur x f²)` ; sa pente se majore terme a terme —
le radial donne `0,77 x hauteur / rayon`, chaque bruit `2f x 1,5 x ondes x
amplitude x hauteur / rayon` — d'ou `CWMesa.slope_bound` et `CWMesa.max_step`.
C'est contre `m.max_step()` que la mesure d'escalade de `relief_test` se fait
desormais, et non contre un `2` ecrit en dur.

> **Le contrat d'escalade garde le dernier mot.** Une rugosite tiree qui
> porterait la marche au-dela de `CWMesa.CLIMB_MAX_STEP` est **rabattue** —
> amplitudes divisees jusqu'a rentrer — plutot que retiree ou retiree au sort :
> refuser la masse ferait des trous dans la repartition, et relancer le tirage
> couterait la reproductibilite du flux de nombres.

**Ce que ca rend, mesure** (`tools/mesa_stats.gd`, 99 massifs) :

* rugosite lente **de 0,121 a 0,275**, mediane 0,190 — un facteur 2,3 ;
* pente bornee **de 0,54 a 1,00 bloc par bloc**, mediane 0,85 ;
* **24 massifs sur 99 rabattus** par le contrat ;
* marche maximale : **2 blocs pour les 99**.

> **Et c'est le point ou la demande et le contrat de la veille se rencontrent :
> la borne *en blocs entiers* ne varie pas, et elle ne peut pas.** `max_step`
> vaut `1 + ceil(pente)` ; le `ceil` de tout ce qui est positif vaut au moins 1,
> et le terrain en ajoute un, donc le plancher est 2 — et 3 serait une marche
> qu'on ne monte pas, c'est-a-dire le contrat d'escalade du 2026-09-08 rompu.
> Ce qui varie reellement d'un massif a l'autre est la **pente continue** (0,54
> a 1,00) et la silhouette, pas le nombre entier. La demande est donc satisfaite
> dans son intention — des masses lisses et des masses abruptes dans le meme
> paysage — et refusee dans sa lettre, parce que sa lettre demandait de laisser
> passer des marches infranchissables. Le nombre est dans l'outil : c'est de la
> qu'on reviendra dessus si l'arbitrage doit changer.

**Un defaut latent est tombe avec, et il n'attendait qu'une forme plus
decoupee.** La hauteur libre d'une galerie etait prise a la **face**, une seule
colonne. Mais son axe est une ligne brisee qui derive lateralement : il traverse
des colonnes ou la masse est plus mince, et le plafond y sortait par le dessus —
un trou dans le sol vu d'en haut. Le rabattement se fait maintenant sur la
**plus mince** des colonnes traversees, et une galerie qui n'y tient plus debout
n'est pas posee. La verification « aucune grotte ne perce le dessus du massif »
existait depuis le 2026-09-07 et passait : il a fallu des masses plus decoupees
pour la mettre en defaut, ce qui est exactement le service qu'on attend d'un
test qu'on ne touche pas.

### 7octies.3 « Deux bouches en entonnoir, et un creusement plus libre » — les grottes

Trois demandes, et la troisieme est celle qui coute.

**La galerie traverse.** Elle avait une entree evasee et un fond ferme ; elle a
maintenant **deux bouches**, choisies l'une et l'autre par la regle des huit
directions qui garantissait deja qu'on debouche a l'air libre — la seconde
partant de l'oppose de la premiere, pour que le tube coupe la masse au lieu de
la raser. L'evasement s'applique aux deux bouts : *un tube evase d'un seul cote
a une entree et une fissure.* Le porche aussi, sans quoi la sortie ne se verrait
pas de l'exterieur alors qu'on entrera par elle une fois sur deux.

> **Ce que traverser a force a changer, et qui n'etait pas prevu : le plancher
> ne peut plus etre un nombre.** Les deux bouches sont a des altitudes
> differentes, et la promesse « de plain-pied a l'entree » vaut aux **deux**
> entrees. Le plancher est donc porte par l'axe, point par point, et il
> interpole d'un seuil a l'autre. Une consequence gratuite : la galerie a une
> **pente**, ce qui est la moitie de « le plafond monte et descend ».

**Le creusement est plus libre.** L'axe ne tire plus une longueur : il joint les
deux seuils, et ses coudes s'ecartent de la corde sous une enveloppe en sinus
qui s'annule aux deux bouts — une bouche doit rester la ou le terrain a dit
qu'elle etait. Le rayon et la hauteur libre sont tires **par point** et
interpoles le long de chaque segment, donc la galerie se resserre et s'ouvre.
Et 37 % des galeries portent un **embranchement** court, marque `branch` : il ne
debouche pas et n'a pas a le faire — on y accede par la galerie qui le porte, ce
qui le dispense de la verification d'acces et du porche.

**Sans cesser d'etre praticable, et c'est la contrainte qui coute.** Une section
variable peut se pincer jusqu'a boucher la galerie, et *une grotte bouchee au
milieu est pire qu'une grotte droite : on y entre, on marche, et on se cogne.*
Trois garde-fous, a deux etages :

* **au placement**, deux planchers absolus — `CAVE_SECTION_FLOOR` a trois blocs
  de rayon, `CAVE_CLEARANCE_FLOOR` a quatre blocs de haut — sous lesquels aucun
  point de l'axe ne descend ;
* **au placement encore**, le rabattement du plafond sur l'epaisseur de **chaque**
  colonne traversee, et non de la pire : une galerie qui s'ecrase sous un col et
  se rouvre apres reste une galerie ;
* **a la verification**, un parcours de l'axe d'un bout a l'autre qui exige a
  chaque point une section, une hauteur libre, et un **plancher sans marche** —
  une galerie qui monte de six blocs d'un point au suivant ne se parcourt pas
  plus qu'un mur. C'est le pendant de la verification d'acces, qui ne regardait
  que l'entree ; les planchers bornent la geometrie posee, pas ce que le
  generateur ecrit, qui est l'intersection du tube et de la masse.

> **Le piege, et il a coute la premiere execution.** Le controle de praticabilite
> appliquait ses planchers a **tous** les points de l'axe, bouches comprises — et
> il a rejete toutes les galeries du monde. Une bouche est *au seuil* de la
> masse, c'est-a-dire exactement la ou celle-ci n'a par definition aucune
> epaisseur. La verification du plafond excluait deja les bouches pour cette
> raison, depuis le 2026-09-07 ; il a fallu la relire pour comprendre pourquoi.

**Ce que ca rend, mesure** (`tools/mesa_stats.gd`, 99 massifs) :

| | avant | apres |
|---|---|---|
| galeries | culs-de-sac | **75 traversantes** |
| bouches par galerie | 1 | **2** |
| longueur mediane | ~87 blocs | **171 blocs** |
| rapport de section (large / etroit) | 1,00 — un tuyau | **1,94** |
| embranchements | aucun | **28**, sur 37 % des galeries |

### 7octies.4 « Contourner un massif, pas le percer tout droit » — les deux lectures

Ce point avait **deux lectures** et le fichier de reprise demandait de trancher
avant d'ecrire une ligne. **Les deux ont ete retenues**, et elles ne se
recouvrent pas : l'une decide *ou* passe le chemin, l'autre *de quelle forme*
est le trou quand il passe quand meme.

#### Le trace connait les massifs

La fonction de cout de `_relaxe` les ignorait totalement. Elle les compte
maintenant, avec un poids qui repond a une question ayant une reponse
naturelle : **percer un bloc de roche doit couter ce que couterait le monter.**
Le denivele y est deja compte en blocs, donc le poids est de l'ordre de 1.

> **Et ce qui en sort n'est pas un contournement construit.** La penalite etant
> proportionnelle a l'**epaisseur**, la relaxation ne fuit pas la masse : elle
> glisse vers la ou celle-ci est mince, c'est-a-dire vers son contour. Le trace
> decrit donc un arc dont le rayon suit celui de la masse — un chemin de
> corniche — et il la perce quand meme lorsque le detour couterait plus cher que
> le tunnel. C'est le mot « orbitale », obtenu par le cout plutot que par une
> regle qui l'aurait impose.

**La premiere version n'a presque rien change, et sa lecon est celle d'un piege
deja ecrit.** Elle lisait l'epaisseur **au jalon**, comme l'altitude : 0,21 bloc
d'epaisseur moyenne traversee contre 0,17. Les jalons sont espaces de
`SEGMENT_LEN`, soit 256 blocs ; un massif fait 70 a 140 blocs de rayon. **Une
masse tient tout entiere entre deux jalons**, et le cout ne la voyait jamais.
C'est *chercher un itineraire et epouser un sol ne se font pas a la meme
echelle*, dans une troisieme variante : l'altitude peut se lire au jalon parce
que c'est un champ lisse a grande echelle ; la masse est un **objet local**, et
un objet local se manque.

Integree le long des deux segments adjacents, a 48 blocs de pas :

| | avant | au jalon | integree |
|---|---|---|---|
| chemin sous un massif | 1,4 % | 1,3 % | **0,7 %** |
| epaisseur moyenne traversee | 0,21 bloc | 0,17 | **0,08** |
| traversee la plus profonde | 48 blocs | 48 | 47 |

La derniere ligne compte autant que les deux autres : **les tunnels ne
disparaissent pas.** Ils cessent d'etre subis.

**Ce que ca coute.** La relaxation touche des cellules de massifs sur tout le
corridor qu'elle explore, et les construire n'est plus gratuit depuis que les
grottes echantillonnent le terrain point par point : **+14 s sur la suite de
validation** (44 s a 58 s). C'est du travail de zone, froid, mis en cache et
fait sur un fil de fond en jeu ; l'essentiel est du travail que le terrain
aurait fait de toute facon en se chargeant, avance plus tot. La fenetre de
massifs est prise une fois par cellule traversee et non une fois par sondage,
comme dans la boucle du generateur.

#### La section du tunnel est un cercle

`tunnel_height` rendait une **hauteur** : une tranche rectangulaire de largeur
constante au-dessus de la chaussee. Sous quarante blocs de roche, cela fait une
fente, pas une arche.

Elle rend maintenant un **rayon** (`tunnel_bore`), proportionnel a la masse
traversee, et la section est un cercle centre sur l'axe a hauteur de chaussee :
le degagement vaut `sqrt(R² - d²)`, maximal sur l'axe, nul au piedroit. **La
voute deborde la chaussee** des que le rayon depasse sa demi-largeur de 4,5
blocs, c'est-a-dire sous toute masse un peu haute — et c'est ce debordement qui
fait la difference entre une arche et une fente. Le toit reste garde comme
avant : `TUNNEL_ROOF_MIN` blocs de matiere au-dessus de la voute, faute de quoi
le chemin ne percerait plus le massif mais le couperait en deux.

### 7octies.5 « Le pont flotte, et il a neuf teintes de bois »

#### Il flottait, et il avait des trous

Le tablier se posait a `surface + BRIDGE_CLEAR` **la ou il y avait de l'eau sous
la colonne, et nulle part ailleurs**. Deux defauts en un, et le second ne s'est
vu qu'en mesurant :

* aux culees, la chaussee de la rive etait a `sol - MIN_CUT` : entre elle et le
  tablier il y avait une marche, et l'ouvrage flottait — c'est ce qui a ete
  rapporte ;
* **« y a-t-il de l'eau sous cette colonne » est une condition qui clignote.**
  Sur les 63 ouvrages de la zone de depart, le tablier changeait d'avis 178 fois
  au lieu de 126 : il avait des trous, la ou un banc de sable emerge entre deux
  bras. Personne ne l'avait signale ; c'est la mesure qui l'a trouve.

**Quatre choses ensemble y repondent, et il a fallu les quatre.** Chacune a ete
essayee seule, et chacune seule laissait la marche ou la rouvrait ailleurs :

1. **le degagement est porte par le profil** (`CWPathNetwork._profil`), et non
   ajoute apres coup dans `road_shape`. Il traverse donc le lissage et le
   bornage comme le reste du chemin, ce qui *fabrique la rampe d'acces toute
   seule* ; et `road.y` devient l'altitude du tablier, la meme dont la travee
   instanciee se sert. Deux nombres calcules a deux endroits n'ont aucune raison
   de coincider ;
2. **la chaussee a le droit de passer au-dessus du sol.** `shaped_top` la
   posait *toujours* un bloc en contrebas (`MIN_CUT`) : juste pour un chemin qui
   suit le terrain, faux pour une rampe de pont, et cela rouvrait la marche que
   la rampe existait pour supprimer. Au-dessus du sol, la chaussee est un
   **remblai**, borne par `MAX_FILL` comme le reste ;
3. **le tablier passe par `shaped_top` comme la chaussee.** `road.y` est
   l'altitude *voulue*, et le terrain a le droit de la borner : deux surfaces
   qui se touchent et dont une seule est bornee ne peuvent pas se rejoindre ;
4. **l'etendue du tablier est celle du releve, pas de la colonne**
   (`CWPathNetwork.deck_at`). Un pont n'est pas une propriete de colonne, c'est
   un objet qui a une etendue — et le releve des franchissements la connaissait
   depuis le jalon 1.16 ; elle n'etait simplement pas lue par le generateur.

> **Les deux essais rates valent d'etre gardes, parce qu'ils disent chacun une
> chose.** Poser du bois partout ou la chaussee passe au-dessus du sol a couvert
> **244 colonnes de chaussee sur 343** : `shaped_top` posant le ruban en
> contrebas, « au-dessus de la chaussee » etait vrai sur presque tout le reseau —
> la rampe se mesure au **terrain**. Puis le mesurer au terrain en a laisse 131 :
> la rampe d'un pont fait une centaine de blocs, c'est le lissage du profil qui
> l'etale, et *cent blocs de bois a un bloc du sol font un viaduc, pas une
> culee*. D'ou le remblai.

**Et la verification manquait pour une raison qui se generalise.** Celles d'alors
regardaient chaque colonne **isolement** — le tablier est-il au-dessus de l'eau,
la chaussee est-elle degagee — et **une marche ne se voit pas sur une colonne
seule.** Elle se voit en marchant, donc en comparant deux colonnes voisines. La
nouvelle parcourt l'axe de chaque ouvrage, releve la surface sur laquelle on
pose le pied — le tablier s'il y en a un, la chaussee sinon — et mesure le
ressaut au passage du bois a la terre. C'est la meme famille que la mesure
d'escalade d'un massif, et la meme que le parcours d'axe d'une galerie : *ce qui
se juge en marchant se mesure en marchant.*

| | avant | apres |
|---|---|---|
| ressauts a la culee | **103**, la pire de **4 blocs** | **3**, la pire de **2** |
| passages bois/terre sur 63 ouvrages | 178 (le tablier a des trous) | **141**, soit 2,2 par ouvrage |
| colonnes de chaussee en bois | 21 | 27 |

Le contrat retenu est **deux blocs au pire, et a niveau dans plus de 95 % des
cas** — pas « aucune marche », et il ne peut pas l'etre : le tablier reste
plancher par `surface + BRIDGE_CLEAR`, donc une riviere plus profonde que ne le
disait le jalon voisin du profil releve le bois d'un bloc ou deux. Le chemin
lui-meme fait des marches de trois blocs ailleurs, ce que la ligne imprimee
rappelle a cote.

#### Une seule teinte de bois

La travee employait **neuf index** de la rampe des planches plus un de pierre
pour les chapeaux de poteau. A six voxels par bloc, une planche fait trois
voxels de large : neuf teintes reparties la-dessus ne se lisent pas comme du
bois, elles se lisent comme du **grain**.

Un seul index (180), **et la forme fait le reste** : le joint entre deux
planches etait une teinte plus sombre, c'est maintenant une **rainure** — le
voxel du dessus manque —, et le chapeau d'un poteau se designe par son
**debord** d'un voxel, qu'il avait deja, plutot que par sa matiere. La note
precedente objectait qu'une rainure disparaitrait au premier pas de recul :
c'est vrai, et c'est le but. De pres on voit des planches, de loin un tablier ;
neuf teintes, elles, se voyaient de loin — comme du bruit.

`pont_travee` : 56 x 12 x 10, 1 260 voxels, **un seul morceau, un seul index**.

---

### 7octies.6 « Tous les voxels d'un asset doivent porter sur le sol » — l'assiette

Un modele est pose sur la hauteur de **sa colonne d'ancrage**, et son empreinte
fait plusieurs blocs de large. Des que le terrain descend sous un de ses bords,
ce bord **flotte** : un rocher a demi en l'air sur une rupture de pente, un arbre
dont le pied ne touche que d'un cote.

Le remede demande de connaitre le sol **sous toute l'empreinte**, et le payer
entier etait hors de question — une empreinte de 5 x 5 blocs, c'est vingt-cinq
colonnes la ou on en paie une, et la dispersion est deja le second poste du
chargement. On sonde donc les **quatre coins**, et rien d'autre : c'est ce qui
attrape une rupture de pente, qui est le cas qu'on cherche, et qui manque un
creux central, qui n'existe pratiquement pas a cette echelle.

Puis deux issues, dans cet ordre :

* l'ecart des quatre coins depasse `CWScatter.ASSIETTE_MAX` (deux blocs) : le
  candidat est **ecarte**. Poser quoi que ce soit sur une marche de trois blocs
  donne soit un objet en l'air, soit un objet a moitie enterre, et aucun des
  deux ne vaut mieux que rien ;
* sinon, l'objet se pose sur le **minimum** des quatre. Il s'enterre un peu
  plutot que de flotter, et c'est le bon sens du compromis : *de la matiere
  enfouie ne se voit pas, un vide sous un caillou se voit de loin*.

**Le sondeur est le meme que l'ancrage, et il faut qu'il le reste.** Un coin lu
par une autre regle que son centre rendrait une assiette fausse dans un sens ou
dans l'autre, donc `_sol_pose` refait exactement ce que fait la boucle
principale — chapeau de massif, creusement d'etang, remodelage de chemin — sans
garder les valeurs intermediaires dont elle a besoin et pas lui.

**Ce que ca coute est borne par ou ca s'applique.** Le sondage est saute quand
le rayon d'empreinte est nul, ce qui est le cas de l'essentiel de la flore : sur
la zone de depart, **392 plantes sur 2 403** se posent sous leur colonne
d'ancrage, les autres n'ont rien eu a sonder. Les arbres, eux, le paient tous —
et ce sont eux qui en avaient le plus besoin, leur tronc etant **ecrit dans le
terrain** depuis le jalon 1.11 : un fut pose un bloc trop haut laisse voir le
vide sous lui, et rien ne le retirera ensuite.

La verification de `tests/flora_test.gd` a change de forme avec la regle. Elle
exigeait l'egalite au sol de la colonne ; elle exige maintenant **au plus le sol,
et jamais plus bas que `ASSIETTE_MAX`** — au-dela, le candidat aurait du etre
ecarte, pas enterre.

---

## 7nonies. La quatrieme passe — **2026-09-09, seconde soiree**

Trois demandes faites apres une seconde session de jeu. Elles ne corrigent pas
des defauts d'implementation : elles **retirent** deux decisions et en changent
une troisieme, et c'est pour ca qu'elles valent d'etre ecrites en entier.

### 7nonies.1 « Les bords sont creuses, l'interieur ne l'est pas » — la chaussee

Le reproche est litteral : *les bords sont bien creuses d'un bloc minimum sous le
sol, mais l'interieur n'est pas creuse*. Il etait juste, et **aucune
verification ne pouvait le voir** — elles mesuraient ce que le chemin *tranche
au plus* (`MAX_CUT`), jamais ce qu'il tranche *au moins*.

La mesure, avant correction, sur la zone de depart :

```
  distance a l'axe   0    1    2    3    4    5    6    7    8    9   10
  ecart au terrain -0,26 -0,27 -0,26 -0,27 -0,25 -0,25 -0,32 -0,43 -0,67 -0,94 -1,00
```

C'est **l'inverse d'une tranchee** : une levre d'un bloc a la limite exterieure
de l'accotement, et un ruban a peine entame au milieu. Et 35,3 % des colonnes de
chaussee etaient carrement en **remblai**, au-dessus du terrain.

**La cause est un ordre, pas une borne manquante.** `shaped_top` interpolait
entre le terrain et *le profil*, puis rabattait le resultat d'un bloc :

```
    y     = lerp(sol, profil, t)
    creux = sol - ceil(MIN_CUT x t)
    rendu = min(y, creux)          # sauf si y > sol, ou l'on rendait y
```

Deux choses s'y liguaient. Le `ceil` fait de `creux` une **marche** — il vaut
`-1` des que `t > 0`, donc a la limite exterieure de l'accotement, la ou l'on
attendait `0` — c'est la levre. Et l'echappatoire `y > sol`, ajoutee le matin
meme pour la rampe d'acces d'un pont, rendait le profil **sans rien rabattre** :
le profil etant lisse, il passe au-dessus du terrain une colonne sur trois, et
sur ces colonnes-la le chemin n'etait plus creuse du tout.

La correction :

```
    creux    = sol - MIN_CUT
    chaussee = clamp(profil, sol - MAX_CUT, creux)
    rendu    = round(lerp(sol, chaussee, t))
```

**Le rabattement est dans la cible, et non applique par-dessus.** Il n'y a plus
ni levre ni echappatoire, et le raccord reste continu parce qu'il n'y a plus
qu'une seule interpolation. Apres :

```
  distance a l'axe   0    1    2    3    4    5    6    7    8    9   10
  ecart au terrain -1,26 -1,24 -1,25 -1,27 -1,26 -1,25 -1,19 -0,88 -0,15 -0,02 +0,00
```

Un fond plat sur toute la chaussee, une berge qui remonte, et **100 % des
colonnes de chaussee creusees** contre 64,7 % avant.

### 7nonies.2 « Supprimer les ponts, remplir le gap par le chemin » — la levee

*Les ponts sont trop compliques a integrer.* Ce qui part est un systeme entier,
et c'est le plus gros retrait du jalon 1.16 :

* `CWBridgeRenderer` et son noeud dans la demo ;
* `assets/models/structures/pont_travee.vox` et `tools/blender/generer_ponts.py` ;
* le **tablier de matiere** de `road_shape`, son garde-corps, la constante
  `DECK_NONE`, le tableau `ColumnPatch.decks` et les deux parametres de
  `voxel_of` qui les portaient ;
* et l'option `--sans-ponts` de la demo.

Ce qui reste tient en une phrase : **la ou le chemin rencontrait l'eau, il la
comble.** Le remblai qui montait deja a l'approche — la rampe d'acces du pont,
fabriquee par le lissage du profil — ne redescend plus. C'est une **levee**.

> **Une levee est un barrage, et c'est dit en clair.** Ce monde ne simule pas
> l'ecoulement, donc rien ne monte derriere elle ; mais une riviere coupee reste
> une riviere coupee. C'etait l'argument qui avait fait choisir le pont le
> 2026-09-07 (*« la combler ferait un barrage »*), et il est ecarte
> deliberement : un pont qui ne s'integre pas coute plus cher au paysage qu'une
> riviere coupee.

**Le releve des franchissements reste, et il ne sert plus a la meme chose.** Il
donnait *ou poser du bois* ; il donne maintenant *ou le chemin remblaie au lieu
de creuser*. Trois choses ont du changer avec lui :

1. **il porte deux rampes.** Le releve s'arretait au premier point sec de chaque
   rive, et `causeway_at` tenait alors son altitude constante sur ses dix blocs
   de portee, contre un terrain qui continuait de monter. Mesure : **5 blocs de
   marche a la culee, 60 culees sur 135 qui ressautaient**. La levee se prolonge
   donc jusqu'a **rencontrer le sol**, en descendant d'au plus un bloc tous les
   deux, puis s'eteint par un **point mort** — un point d'axe si bas que
   `maxf(span, creux)` rend `creux` des qu'on l'approche. Le raccord n'est plus
   a accorder, il est *exact* : les deux regles rendent le meme nombre ;
2. **sa portee laterale est celle du chemin entier**, accotement compris. Avec
   la seule demi-chaussee, le remblai s'arretait net et la levee avait des
   parois verticales de dix blocs ; avec `reach()`, ses flancs descendent
   rejoindre le lit sur toute la largeur de l'accotement ;
3. **son pas de raffinement passe de quatre blocs a un.** Quatre suffisait a un
   tablier — il fallait seulement savoir *qu'il y avait une riviere ici*. Une
   levee demande plus, et une mare peut faire deux blocs de large.

**Et un plancher local, parce que le releve ne peut pas tout voir.** Meme au pas
d'un bloc, il suit *l'axe du trace* : il ignore les colonnes d'accotement et les
mares que le champ de chenaux ne signale pas. Sept colonnes de chaussee
restaient noyees, toutes dans une mare d'un bloc de fond. `shaped_top` prend
donc la surface libre de **sa** colonne (`CWTerrainField.free_water`, point
unique de cette regle a trois branches, ecrite quatre fois jusque-la) et passe
toujours deux blocs au-dessus. Le partage est net : *le releve donne la rampe*,
qui demande de connaitre l'ouvrage entier ; *la colonne donne le plancher*, qui
ne demande rien d'autre qu'elle.

Ce que ca rend, sur les 63 franchissements de la zone de depart :

| | avant (pont) | apres (levee) |
|---|---|---|
| plus grande marche a la culee | 2 blocs | **1 bloc** |
| culees qui ressautent | 3 sur ~130 | **0 sur 52** |
| colonnes de chaussee noyees | — | **0 sur 3 643** |
| colonnes portees par du remblai | — | **3 643 sur 3 643** |

**Et la verification a change de forme avec la chose.** Elle parcourait l'axe
d'un ouvrage en relevant *le tablier s'il y en a un, la chaussee sinon* ; elle
parcourt le meme axe en exigeant trois choses d'une levee — pas de marche a la
culee, **le pied au-dessus de la surface libre**, et **ce qui porte le pied est
du remblai et non le lit**. La lecon de la veille tient toujours : une marche ne
se voit pas sur une colonne seule, elle se voit en marchant.

---

### 7nonies.3 « Ils ressemblent trop a des domes » — la forme des massifs

*Il faut changer d'algorithme, ils ressemblent trop a des domes ; il faut que ce
soit plus abstrait et exagere dans leur deformation, **ne plus tenir compte de
l'escalade du personnage**.*

**La parenthese n'est pas un detail, c'est la condition.** Le contrat d'escalade
du 2026-09-08 ne bornait pas un reglage : il bornait *tout*. La hauteur relative
plafonnait a 0,54 du rayon pour lui, l'amplitude des bruits etait **rabattue**
des que la marche depassait deux blocs — sur la graine 1337, **24 massifs sur
99** l'etaient —, et le profil etait au carre pour rejoindre le sol
tangentiellement, ce qui *est* la definition d'un dome. Un relief escaladable
partout est un dome ; on ne pouvait pas garder l'un en demandant l'autre.

Le contrat part donc, et avec lui `CLIMB_MAX_STEP`, `slope_bound`, `max_step`,
le drapeau `damped` et la boucle de rabattement de `CWMesaGrid`.

#### Ce qui remplace le dome : cinq leviers, tires par massif

| levier | ce qu'il fait | plage |
|---|---|---|
| **deformation du domaine** | deplace le point avant de le mesurer : des caps, des golfes, des pincements | 0,14 a 0,54 du rayon |
| **ellipse tournee** | des cretes et des buttes la ou il n'y avait que des ronds | grand axe jusqu'a 2,4 fois le petit |
| **lobes angulaires** | `cos(k x theta)`, k de 2 a 6 : des bras qui partent du coeur | 0 a 0,80 |
| **exposant de profil** | `f^p` : a 2 un dome, sous 1 un dessus plat et des flancs qui tombent | 0,35 a 2,10 |
| **strates** | la hauteur monte par gradins de 3 a 9 blocs | un massif sur deux |

**Le warp est le levier qui compte le plus, et il remplace un bruit.** Un bruit
additif fait *onduler* un cercle ; un bruit de domaine le **plie**. Il rend donc
inutile le « bruit lent » de contour de la version precedente, qui faisait moins
bien la meme chose pour le meme prix — le champ de forme prend trois echantillons
au lieu de deux, et non quatre.

> **Une amplitude de lobe ne se lit pas comme un rayon, et la premiere valeur
> essayee etait invisible.** Le terme s'ajoute a `1 - u²`, donc un lobe
> d'amplitude A deplace le contour de `sqrt(1 + A)` : a 0,34, cela faisait
> **+16 % de rayon**, noye dans le warp, et les silhouettes restaient des
> patates. A 0,80, le cap est a +34 % et le golfe a **-55 %** : la masse devient
> un objet a bras. C'est le genre d'erreur qu'un dessin attrape en trois
> secondes et qu'aucun nombre ne signale.

#### Le prix : nul, et c'est l'ellipse qui le paie

Le rejet rapide par colonne testait un **disque** de rayon `reach()`. La forme
etant maintenant allongee, ce disque vaut `stretch²` fois l'aire de l'ellipse —
a 1,55, c'est deux fois trop de colonnes qui paient trois echantillons de bruit
pour rien. `near` teste donc **l'ellipse**, marge de warp comprise.

Mesure amortie sur 590 000 colonnes autour du depart, fenetre de massifs prise
une fois par cellule comme le fait le generateur :

| | avant | apres |
|---|---|---|
| champ seul | 74,6 us/colonne | 74,6 us/colonne |
| champ + massifs | 107,2 us/colonne | **104,3 us/colonne** |
| couche de massifs | 32,6 us/colonne | **29,7 us/colonne** |

La forme est plus riche et la couche ne coute pas plus cher : l'ellipse a paye
le troisieme echantillon.

#### Deux corrections que seule cette forme pouvait reveler

**1. Les sondages radiaux partaient de l'interieur de la masse.** Les trois
lectures du contour — le seuil d'une galerie, la verification de debouche, la
recherche de la face — balayaient de `1,15 x rayon` vers le centre. C'etait juste
tant que le contour etait un cercle a peine bosselle ; le contour va maintenant
jusqu'a `2,3 x rayon`, donc le sondage **commencait dans la masse**, ne voyait
jamais le dehors, et **aucune galerie n'etait plus posee**. Les sondages partent
desormais de `reach()`, en distance absolue. C'est le genre de regression qui ne
casse aucune verification de forme et vide le monde de ses grottes.

**2. Le seuil d'une galerie pouvait tomber dans un golfe.** La recherche de la
face ne s'arrete pas a la premiere colonne pleine — une colonne trop mince ne
peut pas porter de galerie —, et elle continuait a **deplacer le seuil** a chaque
colonne vide rencontree ensuite. Entre deux bras il y a un golfe : le seuil
finissait dedans, la galerie s'y ouvrait sur un couloir ferme par le bras d'a
cote, pendant que la verification de debouche avait valide le contour
*exterieur* et l'avait trouve degage. Les trois lectures gardent maintenant la
**premiere** rencontre.

Et une troisieme, qui ne devait rien a la forme mais que la forme a mise au
jour : **la condition de debouche se testait en flottants**. Elle comparait
l'altitude du terrain a `h0 + 0,5` alors que le plancher d'une galerie vaut
`plancher(h0) + 1` et que le sol occupe le bloc `plancher(altitude)`. Un terrain
a `h0 + 0,45` passait le test et **bouchait** la sortie. Le decalage etait de
quelques dixiemes de bloc, donc il ne se voyait qu'a une bouche sur quatre — et
pas du tout tant que les bouches tombaient loin des ressauts. La condition est
maintenant celle que la verification exerce, mot pour mot.

Cette condition etant plus severe, le monde perdait un cinquieme de ses
galeries. Le nombre de directions essayees pour percer une bouche passe donc de
huit a **douze** : avec des bras et des golfes, un cote sur trois ne mene nulle
part.

#### Ce que ca rend, mesure sur la graine 1337

| | avant | apres |
|---|---|---|
| hauteur mediane | 32 blocs | **43 blocs** |
| massifs rabattus par le contrat | 24 sur 99 | **aucun contrat** |
| marche maximale, par massif | 2 blocs pour les 99 | **7 blocs** sur le massif temoin |
| rapport du contour (le plus loin / le plus pres) | — | **2,34** |
| massifs a dessus plat (profil < 1) | — | **21 sur 74** |
| massifs a gradins | — | **36 sur 74** |
| galeries | 75 | 67 |
| terres sous un massif | 1,37 % | 1,51 % |

#### Et la verification a change de nature avec la forme

Elle mesurait **la marche** et exigeait qu'elle tienne le contrat. Le contrat
n'existe plus, et une marche de dix blocs n'est plus un defaut mais le but. Ce
qui la remplace mesure la chose demandee : **la silhouette n'est plus un
cercle**. On balaie la masse sur vingt-quatre rayons, on releve la distance a
laquelle son contour se trouve dans chacun, et on compare la plus grande a la
plus petite — un dome rendrait 1, on exige 1,5. La marche reste **relevee et
imprimee**, bornee par la seule chose qui reste vraie : *une masse ne fait pas
une marche plus haute qu'elle*.

Et l'eventail se verifie sur l'echantillon, sur les trois leviers qui repondent
au mot « dome » : il faut des massifs a paroi, des massifs a gradins, et de
l'allongement. Sans eux, le tirage par massif ne sert a rien.

---
