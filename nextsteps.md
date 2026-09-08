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

## 0. La prochaine session

*Rien n'est demandé pour l'instant.* Le jalon 3.1 (contrôleur, caméra,
physique) a sa troisième tranche depuis le 2026-09-17 : nouveau modèle de
personnage, bascule de mode en jeu, franchissement de marche, caméra lissée ;
son compte rendu suit celui de la deuxième tranche, qu'il rend caduque sur le
personnage (quatre pièces `.vox` → six pièces `.obj`) sans y toucher — le
récit reste celui de ce qui s'est passé alors. Le jalon 2.6 (l'apparition) a
été ouvert le 2026-09-15 pour les filons ; son compte rendu vient ensuite. Le
programme du 2026-09-12 au soir — le LOD natif, et rien d'autre — est traité ;
son compte rendu est en §0bis.

### 3.1, troisième tranche — nouveau personnage, marche et caméra (fait le 2026-09-17)

**Reprise demandée en session : remplacer le personnage par un nouvel export,
puis quatre ajouts au contrôleur.**

* **le personnage vient desormais de `assets/models/personnage/human/`**, six
  pièces `.obj` exportées de MagicaVoxel (tête, torse, bras et jambes gauche
  et droite separés) plutôt que quatre `.vox` repeints dans la palette du
  projet. Les six partagent un seul repère (un dixième d'unité par voxel,
  mesuré sur les sommets) : plus d'offset à calculer entre les pièces, plus de
  reflet de nœud pour le côté manquant. `CWPlayerBody` (`src/demo/cw_player_body.gd`)
  est réécrit en consequence — voir son en-tête pour la derivation des pivots
  et `TEXTURE_FILTER_NEAREST` (la texture est une bande de palette 256×1, pas
  une photo) ;
* ⚠️ **defaut trouve a la capture, pas a la lecture** (meme famille que les
  deux du 2026-09-16) : la tete et le torse sortent de l'export tournes de 180°
  sur le lacet, seuls parmi les six pieces — un visage qui regardait vers +Z
  alors que `CWPlayerController` avance vers -Z. Verifie en posant deux
  cameras de part et d'autre du personnage instancie seul (`_attache(...,
  flip = true)` corrige, chacune autour de son propre pivot) ;
* **F5 fait entrer ou sortir de `player_mode` en jeu**, sans relancer avec
  `--joueur` (`TerrainDemo._toggle_player_mode`). Ça oblige `flat.generate_collisions`
  à rester **toujours vrai** desormais, meme en camera libre : `VoxelTerrain`
  n'expose aucun remaillage a la demande, donc rien ne peut donner
  retroactivement une collision aux blocs deja charges au moment ou on entre
  dans le corps. Cout mesure negligeable (~150 ms sur 17 s de chargement a 384
  blocs de vue). Deux couches qui gardent leur propre reference a la camera
  plutot que de lire `TerrainDemo.camera` a chaque image — `CWFloraRenderer`,
  `CWClouds` — doivent etre reprevenues explicitement au changement
  (`_relink_camera`) ;
* **`CWPlayerController._step_up`** franchit un rebord d'un bloc sans sauter :
  souleve le corps de `STEP_HEIGHT` seulement quand c'est ce qui manque pour
  avancer (bloque au ras du sol, degage plus haut, le mouvement passe
  la-haut), puis laisse `move_and_slide` raccrocher seul au sol retrouve ;
* **`_smooth_camera_height`** fait suivre la camera en hauteur avec un retard
  exponentiel plutot que rigidement, pour que `_step_up` (et une pente prise
  en marchant) ne se voient plus comme un bond sec — sauf ecart enorme
  (teleportation de biome), cale au lieu de rattrape sur plusieurs secondes ;
* **l'amble et le repos se fondent** (`_walk_blend`) au lieu de basculer d'une
  image sur l'autre, et le torse rebondit legerement a chaque appui
  (`BOB_AMPLITUDE`, deux fois par foulee). Verifie en jeu par teleoperation
  (MCP `godot-ai`) : marche, arret en cours de foulee, F5 dans les deux sens,
  aucune erreur au journal. Suite : **449 verifications, 0 echec**.
* **hors perimetre pour cette tranche** : le franchissement de marche n'a pas
  ete essaye contre une vraie marche du monde genere (seulement verifie sans
  obstacle et par lecture de code) ; aucune pose d'animation en l'air
  (chute, saut) ; l'evitement de mur de la camera reste absent.

### 3.1, première tranche — le corps physique (fait le 2026-09-16)

**Un `CharacterBody3D`, invente plutôt que porté, et c'est assumé.** La
fonction qui ferait autorité pour le mouvement du joueur dans la source,
`GameController::vfunc_10`, est la plus grosse fonction du binaire entier
(77 Ko de pseudo-code Ghidra) et mélange indissociablement le déplacement, les
menus, l'inventaire et l'artisanat en une seule mise à jour par image — il n'y
a pas de sous-bloc « physique du joueur » à en extraire, c'est un agrégat, pas
une fonction. Comme le réseau de chemins au jalon 1.16 : *une chose absente
d'une source exploitable n'est pas hors périmètre, elle est à décider.*

* `CWPlayerController` (`src/demo/cw_player_controller.gd`) : gravité, marche
  (ZQSD), saut, capsule de collision a la hauteur de reference du personnage
  (2,4 blocs, `docs/ASSETS.md`), lacet sur le corps et tangage sur la seule
  camera — un corps qui tanguerait coucherait sa capsule. Les constantes de
  vitesse, de gravite et de hauteur de saut n'ont pas de source a citer : ce
  sont des choix de sensation de jeu, a revoir au clavier plutot qu'au banc ;
* activé par `--joueur`, et il **s'ajoute** à la caméra libre plutôt que de la
  remplacer — décision prise avant de coder, voir la question posée en
  session. Tous les outils de capture (`--ici`, `--vers`, `--regard`, la
  téléportation de biome) continuent de piloter la caméra libre par défaut ;
  `TerrainDemo.camera` pointe simplement vers l'enfant `camera` du contrôleur
  quand `player_mode` est vrai, et le reste de la démo (ATH, flore, nuages,
  raycast d'édition) ne voit jamais la différence ;
* ⚠️ **un vrai défaut trouvé à la première capture, pas au code.** Le joueur
  apparaissait en l'air (quatre blocs au-dessus du sol, comme un saut) et
  tombait **indéfiniment** — `y -1262` pour un sol à `120`, dix secondes après
  le lancement. Cause : le terrain n'a pas fini de charger la collision de la
  colonne de départ au moment où la gravité commence à s'appliquer ; la chute
  démarre dans ce vide de chargement, et l'observateur de vue (`VoxelViewer`,
  posé sur la caméra donc sur le joueur) suit la chute au lieu de rester sur
  place — le terrain se met alors à charger la colonne *d'arrivée* plutôt que
  celle de départ, et la chute s'auto-alimente jusqu'à ce qu'un bloc déjà
  chargé, bien plus bas, l'arrête enfin. `_floor_within_reach()` sonde toute la
  hauteur jouable (1 100 blocs) avant d'appliquer la gravité : si la sonde ne
  trouve **rien du tout**, ce n'est pas une chute, c'est un chargement, et le
  corps reste immobile le temps qu'il finisse. Vérifié en jeu
  (`--joueur --shot 10`) : le joueur atterrit et se stabilise à `y 123` pour un
  sol à `120`, conforme à la hauteur d'œil de la capsule ;
* les fonctions de placement de la démo (`place_at`, `look_at_world`,
  `_world_position`, `--altitude`, `--regard`) lisent et écrivent maintenant
  `camera.global_position`/`global_rotation` plutôt que la position locale —
  sans quoi elles se seraient trompées dès que la caméra est devenue l'enfant
  d'un corps plutôt que de la démo elle-même. Elles marchent donc identiquement
  dans les deux modes, y compris `--joueur --ici x z --regard d` ;
* **collisions du terrain, activées seulement en `player_mode`**
  (`flat.generate_collisions`) : la caméra libre creuse et se déplace sur les
  *données* (`VoxelTool.raycast`) sans jamais y toucher par la physique, et n'a
  donc jamais eu besoin de collisions. `--joueur --lod` ensemble laisse le
  joueur traverser le sol : les collisions du mode LOD ne sont toujours pas
  vérifiées (voir plus bas) ;
* ⚠️ **hors périmètre pour cette tranche, et à faire avant de rouvrir 3.1** :
  aucune vérification manette en main du saut ou du sprint au-delà de la
  lecture de code, aucune interaction avec l'édition du terrain (creuser en
  étant debout dessus n'a pas été essayé), et la collision du mode LOD reste
  hors sujet. Suite : **449 vérifications, 0 échec**, aucune régression — cette
  tranche ne touche à rien de la génération.

### 3.1, deuxième tranche — le personnage visible et la troisième personne (fait le 2026-09-16)

**Demandée en session, à partir de deux images de référence.** Un personnage
chibi — cheveux blonds hérissés, yeux bleus, tunique sombre, boucle de
ceinture claire — décomposé en quatre pièces articulées (tête, torse, bras,
jambe) et animées proceduralement, plutôt qu'un modèle unique et figé.

* **pas de MCP Blender connecté** ; la convention du dépôt pour la flore, les
  arbres et les filons est déjà du **Python pur** sans `bpy`
  (`tools/blender/generer_*.py`, malgré le nom du dossier) — suffisant pour des
  pièces faites de boîtes, et c'est la voie prise
  (`tools/blender/generer_personnage.py`) ;
* **la plage de palette « créatures » (41-95), ouverte depuis le 2026-09-05 et
  jamais peinte** (l'apparence des créatures étant hors périmètre du jalon 2),
  reçoit son premier contenu réel : `CWPalette.PLAYER_*`. La tunique n'avait
  pas de rampe à elle nulle part dans la palette — ni les rampes de peau, de
  fourrure, d'écailles ou de chitine de la plage créatures, ni les métaux,
  manches, cuir ou gemmes de la plage équipement ne sont du tissu porté.
  **Décision de ce projet, comme `gres`/`cristal_de_glace` pour les filons** :
  les deux pas les plus sombres de « tissus, bannières » (220-227, plage
  structures, jalon 4, elle aussi jamais peinte) sont repeints en tunique
  plutôt que d'ouvrir une neuvième rampe dans une plage déjà pleine ;
* `CWPlayerBody` (`src/demo/cw_player_body.gd`) : quatre pivots (deux hanches,
  deux épaules, plus un pivot de torse et un de tête) sous lesquels chaque
  pièce se pose. Un seul bras et une seule jambe existent sur le disque —
  l'autre côté est un reflet de nœud (`scale.x = -1`), pas un second fichier.
  L'amble avance avec la **distance parcourue** et non le temps, pour que
  l'appui au sol ne patine pas quand on accélère ;
* le joueur passe donc en **troisième personne** — décision prise en session,
  puisqu'on ne peut pas voir son propre personnage en vue subjective sans
  modèle de mains/bras dédié, qui n'existe pas. La caméra est un enfant du
  pivot de tangage, décalée en arrière ; ⚠️ **pas encore d'évitement de mur**
  (un `SpringArm3D` le ferait), donc elle peut traverser le relief près d'une
  paroi — défaut connu, pas un oubli ;
* ⚠️ **deux défauts de repère trouvés à la capture, aucun à la lecture du
  code.** (1) `VoxelVoxLoader` permute les axes en chargeant un `.vox`
  (`vox(x,y,z) -> godot(y,z,x)`) : écrire largeur et profondeur d'auteur
  directement dans le fichier les échange à l'arrivée, et le torse (9 de
  large, 5 de profond) ressortait large de 0,375 bloc vu de face — un fil
  qui semblait manquer entre la tête et les jambes. (2) Une fois les axes
  redressés, le visage regardait **vers l'arrière** : la permutation ne
  retourne pas le signe de la profondeur, et le personnage avance vers -Z
  (`CWPlayerController`) — sans le correctif, marcher en avant l'aurait fait
  reculer face à la caméra. Les deux sont corrigés dans `_pose`, au même
  endroit, avec la mesure qui les a montrés en commentaire ;
* vérifié en jeu sous trois angles (`--joueur`, caméra arrière puis avancée et
  retournée manuellement pour l'inspection) : dos cohérent (cheveux, pas
  d'yeux), face cohérente (yeux bleus, boucle au col), silhouette debout sans
  interpénétration visible. Suite : **449 vérifications, 0 échec**, aucune
  régression — ni la palette ni le pipeline de génération de modèles n'ont
  bougé pour personne d'autre ;
* **hors périmètre pour cette tranche** : animation du saut (accord explicite
  en session, idle + marche seulement), vérification manette en main de
  l'amble (la lecture de code et les captures fixes ne montrent pas le
  mouvement), et tout évitement de mur pour la caméra.

### 2.1 essayée puis abandonnée cette session — la source ne dit pas ce que sont les stats

**Avant de se tourner vers 3.1**, cette session a cherché le modèle de
statistiques de créature (jalon 2.1, `entity/Creature.cpp` selon
`docs/ROADMAP.md`) et a dû rebrousser chemin — à savoir avant de recommencer.

* `entity/Creature.cpp` (client **et** serveur) ne contient **que** de la
  plomberie de conteneurs STL (constructeurs, destructeurs, érasion de
  std::map/std::list en arbre rouge-noir) : aucun champ n'y est nommé
  sémantiquement, tout est en offsets opaques. Ce n'est pas le bon fichier ;
* les vraies fonctions de statistiques (`calc_attack_power`, `calc_stat_variant`,
  `roll_random_level`, `calc_regen_total`...) sont mal attribuées dans
  `server/_library/crt_stl.cpp` — même défaut que `GAP_ANALYSIS.md` signale
  ailleurs (« misattributed »). Elles y sont, et une **vraie courbe de niveau à
  rendements décroissants** (`niveauFacteur = 2^((1-1/((niveau-1)·0,05+1))·3)`)
  y est réutilisée verbatim cinq fois — c'est portable tel quel ;
* ⚠️ **mais aucune table espèce/race → stats de base n'a été trouvée**, et
  l'hypothèse de départ (un commentaire de `GAP_ANALYSIS.md` disant
  `generate_entity_appearance` fixerait un « stat block by race ») était
  **fausse** : cette fonction fait du gréement de squelette, pas des stats.
  Les neuf emplacements de stats/compétences repérés géométriquement (un même
  bloc de 0x118 octets recyclé, niveau roulable à +0x18 de chacun) **n'ont
  aucun nom retrouvable** dans le binaire — on sait qu'ils existent, pas ce
  qu'ils représentent (force, vie, mana, une compétence ?) ;
* **décision prise en session** : plutôt que d'inventer neuf stats sans rien à
  quoi les accorder, la session a changé de phase pour 3.1. `get_value_range_a`
  /`get_value_range_b` (@0040efc0/@0040f0a0, `crt_stl.cpp:4912,4964`) sont les
  candidats les plus proches d'une table par contexte, **non lus** — c'est par
  là qu'il faudra commencer si 2.1 est rouvert, plutôt que par relire
  `entity/Creature.cpp`, qui ne mène nulle part.

### 2.6, l'apparition — les filons affleurent (fait le 2026-09-15)

**La porte du jalon 2 est ouverte, pour sa seule moitié qui n'attendait rien.**
Les neuf modèles, le tirage de rareté (`CWPalette.roll_ore`) et la plage de
palette existaient depuis le jalon 1.11 ; il manquait « la couche qui les
pose », comme `tools/blender/generer_filons.py` le disait en toutes lettres.
`docs/ROADMAP.md`, journal du 2026-09-15, porte le récit complet — ce qui suit
en est le résultat.

* **où un filon affleure n'est écrit nulle part dans la source.** La réponse
  est venue du modèle : chaque `.vox` de `assets/models/filons/` porte sa
  propre gangue de roche (index 1) autour de sa veine, pour se fondre dans le
  terrain plutôt que de dessiner un caillou posé dessus. Un filon n'a donc de
  sens que là où il y a de la roche à fondre — et la falaise est la seule
  matière du monde qui en soit (invariant n° 27). C'est la décision qui cadre
  toute la couche, et ce n'est ni une extraction ni un pari : c'est une lecture
  du seul fichier qui restait à lire ;
* `CWOreScatter` (`src/worldgen/cw_ore_scatter.gd`) reprend l'architecture des
  arbres — cellule de 64 blocs, voisinage 3×3 sans récursion (invariant n° 25)
  — et porte **verbatim** trois constantes de `docs/systems/02` §6 :
  l'espacement minimum (20 blocs), le rejet près d'un élément de tuile sauf le
  donjon, l'abandon à une chance sur quatre sous 0,2 d'humidité ou de
  température. Le raster de la source (pas de 85, décalage +24) n'est **pas**
  porté : c'est la géométrie d'une boucle qui parcourt une tuile entière, pas
  celle d'une cellule mise en cache — voir l'en-tête du fichier ;
* ⚠️ **`gres` et `cristal_de_glace` ne sortent jamais de `roll_ore`** — la
  source ne dit pas qui les pose (`docs/systems/02` §5.4). Décision de ce
  projet, notée comme telle dans `CWOreScatter.ESPECE_PAR_BIOME` : Deserts et
  Snowlands les forcent, parce que ce sont les deux seuls biomes qui leur
  donnent un sens sans inventer un troisième axe ;
* ⚠️ **`tests/lod_test.gd` a viré au rouge**, et c'est la couche existante qui
  l'a vu, pas la nouvelle. Un filon affleure jusqu'à quatre blocs au-dessus du
  sol et ne survit pas au-delà de `CWVoxelGenerator.ORE_MAX_LOD` (zéro) — sans
  le couper, la suite disait « le sol a disparu » là où seul un affleurement
  manquait, exactement comme un houppier non coupé l'aurait fait. `tests/
  lod_test.gd` coupe maintenant `p.ores` comme il coupe déjà `p.trees` ;
* **hors périmètre, et ça le reste** : le choix d'une créature contre un filon
  en un point donné n'est dit nulle part dans la source, et l'apparence des
  créatures est explicitement hors périmètre du jalon 2 (`docs/ROADMAP.md`).
  Cette session ne pose que des filons — `tools/find_ore.gd` les repère,
  `tests/ore_test.gd` les vérifie (16 vérifications, dont l'accord entre le
  bloc généré et la requête ponctuelle, invariant n° 18). Suite : **449
  vérifications, 0 échec**.

### Le mode LOD reste éteint par défaut — décision de rendu, pas de mesure

En jeu, manette en main : **le rendu à plat l'emporte**. Le LOD tenait ses 433
vérifications et personne n'y avait trouvé de défaut de composition, mais vu en
jeu la scène plate est jugée plus lisible que la pyramide à six niveaux.
`TerrainDemo.use_lod` reste à **faux** — et cette fois ce n'est plus faute
d'avoir testé l'édition et la persistance en LOD, c'est que la question ne se
pose plus tant que ce choix de rendu tient : voir la scène de plus loin ne vaut
pas la qualité perdue.

**Rien n'est retiré.** Contrairement à la falaise v1, aux ponts, aux surplombs
et à la plage/au haut-fond/au marais (tableau du §3, « ce qui a été retiré ») —
quatre systèmes qui avaient chacun échoué à une capture — le LOD n'a rien
d'invalide : il n'a simplement pas été choisi. Le code
(`VoxelLodTerrain`, `--lod`, `--lod-vue`, `tests/lod_test.gd`,
`CWVoxelGenerator.TREE_MAX_LOD`) reste dans le dépôt, pilotable en ligne de
commande, pour qui voudrait le rejuger un jour avec un autre réglage. Ce qui
suit reste vrai tant qu'on ne l'utilise pas :

* **l'édition, la persistance et les collisions en mode LOD ne sont toujours
  pas vérifiées** — ni par un test, ni manette en main. Ce n'est plus un
  blocage puisque le mode n'est plus candidat au défaut, mais ça resterait à
  faire le jour où on le rouvrirait ;
* **l'invariant n° 5 — le plafond du cache de colonnes borne la vue à
  1 024 blocs — ne s'applique qu'au mode plat**, celui qu'on garde : sans objet
  tant qu'on y reste, mais ça revient si `use_lod` repasse à vrai ;
* **ce que le LOD ne sait toujours pas faire, pour mémoire** : les arbres
  s'arrêtent au LOD 2 (`CWVoxelGenerator.TREE_MAX_LOD`), la flore ne dépasse
  pas le LOD 0 (`CWFloraRenderer` suit `view_distance`, pas la distance
  rendue), et le réseau de chemins est consulté sur une cellule d'index de 256
  unités qui ne couvre qu'un quart de l'emprise d'un bloc de LOD 5.

---

### Ce qui traîne par ailleurs

**Rien n'y est bloquant, rien n'y est urgent**, et l'ordre n'engage personne.
La plupart de ces points ont une raison de ne pas être faits, et la redécouvrir
coûte une demi-session.

| ce qui traîne | où | pourquoi ça n'est pas fait |
|---|---|---|
| **compiler la GDExtension** | §0ter, en fin | le SDK Windows n'est pas installé sur cette machine. C'est une modification de la machine, pas du projet |
| **la collision des cactus** | §0ter, en fin | ils sont à 4 voxels par bloc : inestampables. Ils veulent une forme de physique, et c'est le jalon 3.1 |
| **la saccade au chargement** | §0ter, en fin | affaire de latence, pas de débit. Aucune mesure ne la voit ; elle se juge manette en main |
| **la gigue de taille des cinq arbres entiers** | §0ter, en fin | perdue en passant en matière. La variété devra venir de variantes de modèles |
| **les fichiers de `worldgen` à mille lignes** | ci-dessous | c'est la dette de découpe, et elle ne fait mal à personne aujourd'hui |
| **le plafond du cache de colonnes** | invariant n° 5 | il borne la vue à 1 024 blocs **en mode plat**. Le LOD l'a rencontré le 2026-09-13 et l'a rendu sans objet : la pyramide n'en garde qu'un anneau |

---

### Les quatre points de fond, et ce qu'il faut savoir avant d'y toucher

**1. Les gros fichiers.** `cw_terrain_field.gd` (1 040 lignes),
`cw_palette.gd` (1 040), `terrain_demo.gd` (1 080), `cw_path_network.gd` (946)
et `cw_voxel_generator.gd` (900) font chacun plusieurs métiers. La démo a déjà
été rangée une fois — 1 147 → 962 lignes, puis remontée — et l'exercice a donné
sa propre leçon : *l'ATH ne sortira pas de `terrain_demo.gd`, il lit dix-sept
morceaux d'état de la démo, et un affichage qui est une vue sur tout n'est pas
une couche.* Le générateur, lui, se découpe : le chemin en masse, la requête
ponctuelle et l'estampage d'arbres sont trois métiers distincts qui ne
partagent que `pond_surface`.

**2. La falaise vaut-elle 12 % du chargement ?** Depuis le retrait des massifs,
elle n'a plus de paroi à raconter — le plus grand dénivelé d'un bloc au suivant
est de 0,65 bloc. Elle coûte une colonne de plus sur chaque axe du pochoir, soit
+12,9 % d'échantillonnage, **payé partout**. Ça se tranche à l'œil sur une
capture, pas au banc. ⚠️ Et depuis le 2026-09-12 elle est **la seule matière du
monde qui ne soit pas celle d'un biome** : la retirer retirerait la roche de la
surface entièrement.

**3. ~~Le plafond du cache de colonnes borne la distance de vue.~~** Vrai du
mode plat, et de lui seul, depuis le 2026-09-13. L'invariant n° 5 demande
`(2 × distance / 16)²` entrées, et à 1 024 blocs on est **exactement** au plafond
de 16 384 ; au-delà le cache s'auto-évince en boucle et le chargement s'effondre
**sans rien signaler**. Le prix est chiffré : **6,4 Ko l'entrée**, 105 Mo au
plafond (`CWVoxelGenerator.PATCH_BYTES`). Mais **en mode LOD la question ne se
pose plus** : 740 entrées suffisent à 2 048 blocs de vue, contre 2 500 pour 384 à
plat. Ce n'était pas un mur, c'était le mur du mauvais mode.

**4. 2.6, l'apparition** — la porte du jalon 2. Elle n'attend rien.

---

### Trois choses que la session du 2026-09-12 a laissées ouvertes

Elles ne sont pas des défauts, ce sont des conséquences assumées de ses cinq
réponses. Chacune se referme en une demi-heure le jour où elle gêne.

* **la carte peint des pays de mer, pas une ligne de rivage.** Une région dont
  le site est noyé est bleue en entier, îles comprises — et une région terrestre
  reste peinte en terre même si un tiers de sa surface est sous l'eau. Peindre
  le rivage demande une case par chunk au lieu d'une par région, soit **4 096
  fois le coût** ; la dalle passerait de 46 ms à trois minutes. La route, si on
  la prend un jour, est de peindre à la case *l'altitude* et non le biome, et de
  ne garder la teinte de région que pour la terre ;
* **la couverture nuageuse est toujours une constante** (`CWClouds.cover`,
  0,45), et les nuages ne portent pas d'ombre (`cast_shadows`, à faux — une
  tache dure de quarante blocs lit comme un défaut de rendu). La dérive est une
  translation d'ensemble : deux nuages ne se croisent jamais. Ça ne se voit pas,
  et le jour où ça se verra, ce sera une vitesse par altitude ;
* ⚠️ **le climat affiché par l'ATH ne décide plus rien**, et c'est un piège de
  lecture pour qui reprend le projet. Depuis que le biome se classe au site,
  `climate_blend` est une aiguille d'instrument : on peut lire « 12 °C » à un
  endroit dont le biome a été décidé sur un tout autre chiffre, celui du site.
  Les deux ne se contredisent pas — l'un est le climat du lieu, l'autre celui
  du pays — mais un réglage de seuil fait en regardant l'ATH serait faux.

---

## 0bis. Le LOD natif — compte rendu du 2026-09-13

**Le programme était : « la configuration et l'intégration de `VoxelLodTerrain`
au projet », et rien d'autre.** C'est fait. Le récit complet, avec les impasses,
est dans le journal de `docs/ROADMAP.md` et dans la section « Vue lointaine » du
même fichier ; ce qui suit est le résultat.

### L'hypothèse qui bloquait le sujet depuis dix jours était fausse

Le fichier posait deux questions à trancher avant toute décision. **La première a
répondu à la seconde.**

> *Où la réduction a lieu ?* — Nulle part. **Le générateur est appelé une fois par
> niveau**, avec `lod` en argument et un pas de `1 << lod` : LOD 0 à 5, blocs de
> 18³, origines alignées sur `16 × pas`. Une sonde d'une ligne dans
> `_generate_block` l'a montré en une exécution.

Donc **rien n'est jamais moyenné**, et l'index de palette qui ne survit pas à une
moyenne n'a jamais été le sujet. L'hypothèse n'avait jamais été vérifiée : elle
avait été écrite le 2026-09-03, puis relue comme un acquis.

### Les deux vrais défauts, et pourquoi aucun test ne les voyait

Ils étaient tous les deux dans `CWVoxelGenerator`, et **tous les deux invisibles
au pas de un** — c'est-à-dire dans les 407 vérifications qui existaient.

1. **le bloc ne couvrait pas ce qu'il prétendait.** `y_max` valait
   `origine + (taille − 1) × pas`, soit le *plancher* de la dernière cellule et
   non la dernière unité de monde qu'elle couvre. Tout ce qui vivait dans les
   `pas − 1` unités au-dessus était rogné, bloc de surface compris : au LOD 4,
   **72 % des colonnes rendaient de la roche nue** ;
2. **l'eau démarrait à `sol + 1`, donc dans la cellule du sol.** Au pas de seize,
   une mare de deux blocs de fond devenait une dalle bleue de seize de côté,
   debout de toute la hauteur de la cellule. **C'était la dalle.**

La correction du second est `_cell_above(w, stride)` : la première unité de monde
de la cellule *suivant* celle qui porte `w`. Au pas de un elle rend `w + 1`, donc
le LOD 0 ne bouge pas d'un voxel — et c'est vérifié pour tout `w`.

### Deux corollaires, et chacun a demandé sa mesure

* ⚠️ **la mer a le droit d'occuper la cellule du sol**, et c'est la seule des
  trois couches d'eau. La règle du dessus vise une couche *mince et locale* qui
  se gonflerait ; la mer est un plan à altitude unique qui n'existe que là où le
  terrain passe dessous, donc elle ne peut pas faire de dalle en pleine plaine.
  Lui appliquer la même règle faisait tomber la part d'eau de **54,6 % à 35,2 %**
  sur une emprise à 41 % de mer : c'est l'eau qui cache le débordement vers le
  haut de la cellule d'un fond marin, et l'en priver fait reculer le rivage
  partout ;
* ⚠️ **l'arbre ne doit pas manger le sol au LOD.** La règle « le feuillage ne
  recouvre que le vide » ne visait que la couronne, parce qu'au pas de un un fût
  se pose sur le sol sans l'occuper. Au pas de quatre, la cellule du sol porte
  aussi le premier mètre du fût.

### Ce que ça vaut

Même machine, même point de vue, mesure du 2026-09-13 :

| | vue | chargement | pic de tâches | cache de colonnes | vidéo |
|---|---|---|---|---|---|
| `VoxelTerrain` | 384 blocs | 23,1 s | 35 000 | 2 500 entrées, 15 Mo | 181 Mo |
| `VoxelLodTerrain` ×6 | **2 048 blocs** | **16,1 s** | **782** | **740, 5 Mo** | 305 Mo |

### Ce qui a dû suivre pour que le mode soit seulement jugeable

* **le brouillard était réglé pour 384 blocs et pour eux seuls.** La première
  capture ne montrait qu'un mur laiteux. `CWDaylight.view_distance` met la
  densité à l'échelle, à profondeur optique constante au bord de la vue ;
* **le plan lointain de la caméra** était en dur à 2 048 ;
* **les arbres montent jusqu'au LOD 2** (`TREE_MAX_LOD`) ;
* `TerrainDemo.rendered_distance()` est le point unique qui dit jusqu'où on rend,
  et il nourrit l'observateur, la caméra, le brouillard et l'ATH. Les avoir
  choisis chacun de son côté est ce qui avait rendu la première capture
  illisible.

### Et la suite qui tient tout ça : `tests/lod_test.gd`

**26 vérifications, et il a fallu s'y reprendre à trois fois pour qu'elle mesure
quelque chose.** Les deux essais ratés valent d'être gardés :

* une première version comparait la **composition** des sommets de colonne. Elle
  attrape la roche nue, et **pas la dalle** — parce que la dalle ne change pas la
  matière du sommet, elle change *laquelle des deux couches occupe la cellule*.
  L'énoncé qui l'attrape est **« le sol ne se noie pas »** ;
* une seconde la mesurait sur l'emprise du point de départ. **Elle passait au
  vert avec le défaut remis en place** : cette emprise n'a ni mer ni mare.
  `CWLodTest.ORIGIN` vise donc un endroit choisi pour ce qu'il contient — 41 %
  de mer, 17 % de mares. *Un test qui ne peut pas échouer coûte plus cher que pas
  de test : il rassure.*

Les deux défauts corrigés ont été **remis en place un par un** pour vérifier que
la suite les voit : 5 échecs pour le premier, 3 pour le second à tous les
niveaux. C'est la seule preuve qu'un garde-fou en est un.

⚠️ **La suite passe de ~25 s à ~2 min**, et c'est la commande qu'on lance après
chaque modification. Le poste est la passe de LOD 0 sur l'emprise. La descente se
fait du haut vers le bas, saute les blocs uniformément vides et s'arrête dès que
toutes les colonnes ont leur sol — sans ces trois économies elle prenait 3 min 40.

---

## 0ter. Le programme des cinq demandes du 2026-09-11 au soir

Traité en entier le 2026-09-12. Ce qui suit n'est que le **résultat** ; le
raisonnement et les mesures sont dans le journal de `docs/ROADMAP.md`.

---

### 1. Un biome, une matière — et la roche seulement en falaise — **fait**

*Corriger les biomes et leurs surfaces : Greenlands/herbe, Deserts/sable,
Jungles/jungle (supprimer marais), Oceans/gravier, Lava Lands/scorie et magma.
La surface roche sert uniquement pour les falaises.*

**Fait, et pris à la lettre** — c'est la décision qui a été demandée avant de
commencer, et elle emporte plus que la liste : **la plage et le haut-fond
partent aussi**. Ils nommaient bien un endroit, ce qui les avait sauvés deux
fois, mais ils le nommaient de la même façon dans trois pays, et le rivage était
devenu le seul lieu du monde où les biomes se ressemblent. Une Snowlands se
termine maintenant dans l'eau **en neige**, une Jungles en herbe de jungle.

Mesure, en parts du monde :

| matière | avant | après | d'où elle vient maintenant |
|---|---|---|---|
| roche | 2,8 % | **0,4 %** | la falaise, et rien d'autre |
| marais | 0,1 % | **0** | plus rien ne la produit |
| terre | 1,0 % | 1,0 % | le lit des mares — c'est le sous-sol, pas une surface |
| sable | 18,1 % | **13,4 %** | Deserts, exactement |
| gravier | 15,3 % | **19,5 %** | Oceans, exactement |
| herbe / jungle / neige | — | 18,0 / 17,6 / 13,4 % | leurs biomes, exactement |
| magma + scorie | — | 2,9 + 13,8 % | Lava Lands, exactement |

**Trois retraits, et le troisième est celui qui coûtait le plus cher à voir
venir.**

* la **bande de roche de Lava Lands** part : c'est elle qui avait triplé toute
  seule quand la mer est descendue de soixante blocs, parce qu'elle était
  exprimée en altitude au-dessus de la mer. Ça ferme aussi l'effet de bord que
  la session du 2026-09-11 avait laissé ouvert ;
* le **haut-fond** part avec la plage : c'était la seule transition de matière
  qu'on voyait *à travers l'eau*, et elle mettait du sable de désert au pied
  d'une Snowlands ;
* ⚠️ le **marais** part, **et le roseau avec lui**. C'était le piège annoncé, et
  il s'est vérifié : le roseau ne poussait que sur cette matière, et la retirer
  seule aurait fait disparaître la plante sans qu'aucune densité ne bouge
  (invariant n° 22). Les deux tables par matière — `FAMILIES_SURFACE` et
  `FAMILIES_SURFACE_BIOME` — disparaissent avec, et `role_at` ne consulte plus
  qu'une table indexée par biome. Le jour où une matière méritera de nouveau sa
  propre composition, il faudra réécrire les deux tables **et** le garde-fou de
  `tests/decor_test.gd` : ce retrait le rend inutile plutôt qu'il ne le casse.

**Ce qui reste, et qu'il ne faut pas confondre avec une exception :**

* **la falaise**, seule matière hors biome. C'est une règle de *pente*, pas
  d'altitude, et c'est la seule qui survive à la question « qu'est-ce que cette
  bande ajoute que le biome ne dise déjà » ;
* **le lit d'une mare**, qui garde la couche meuble. Ce n'est pas une matière de
  surface : c'est le sous-sol vu en coupe, exactement ce qu'on voit en creusant
  soi-même, et `subsurface_index` est le point unique qui le dit dans les deux
  cas. **La rive**, elle, garde sa forme — une berge sèche entre l'eau et le
  terrain — et prend la couleur de son pays : ce qu'elle dessinait était de la
  géométrie, et la géométrie ne dépendait pas de la couleur.

---

### 2. Un biome a une taille minimum — **fait, en classant au site**

*Un biome doit faire une taille minimum, pour éviter des transitions trop
rapides.*

**Le diagnostic n'était pas celui que ce fichier annonçait.** Il disait qu'un
biome pouvait faire une colonne de large partout où le climat frôle un seuil.
La mesure dit autre chose : le champ de climat est un **plateau parfaitement
plat au cœur de chaque région** — le mélange n'y retient qu'un site —, coupé de
transitions **étroites**, deux cents blocs. Un biome faisait donc déjà la taille
d'une région sur l'immense majorité du monde. Ce qui n'allait pas était le
bord : deux cents blocs pour passer d'un climat à l'autre, et jusqu'à **quatre
seuils traversés** en chemin. Quatre pays en deux cents pas.

**La route prise est la garantie**, et elle a été choisie explicitement :
`CWBiome.of_site` classe sur le climat du **site de région le plus proche**. Un
biome est donc une cellule du diagramme de Voronoï des sites — 16 384 unités de
côté, par construction, et il n'y a plus rien à régler pour que ce soit vrai.
Les bandes intermédiaires ne se resserrent pas : elles n'existent plus.

**Ce que ça ne casse pas, et il fallait le vérifier.** Le voisinage reste
crédible parce que ce qui l'assurait n'était pas le mélange mais les
**provinces climatiques** de `CWRegionSiteGrid`, qui adoucissent un climat
extrême vers le tempéré au bord de sa province. Cette règle est au niveau du
site, donc elle survit telle quelle. Les six parts n'ont pas bougé d'un dixième
de point, et `tools/biome_balance.gd` relancé le confirme.

**L'écotone a changé de nature, et c'est le vrai gain de forme.** Il brouillait
le **climat**, ce qui ne dit rien de la largeur de la frange en blocs — celle-ci
valant l'amplitude divisée par la pente locale, et infinie là où le champ est
plat. Il fallait mesurer le gradient du champ, le mémoïser par cellule de 16, en
déduire une amplitude bornée, et sortir tôt là où elle tombait à zéro. Il
brouille maintenant **le point** : `CWTerrainField.fringe_point` déplace la
colonne d'au plus `FRINGE_BLOCKS` avant de chercher son site. *Une frontière
dans l'espace se brouille dans l'espace* — un déplacement se compte en blocs par
construction, il n'a ni pente à diviser ni plateau à redouter, et les trois
mécanismes qui bornaient l'ancien sont partis.

| | avant | après |
|---|---|---|
| colonnes en frange, fenêtre de frontière | 3,4 % | **4,4 %** |
| incursion moyenne | 7,6 blocs | **13,3 blocs** |
| fréquence fine du tramage | 0,10 | **0,34** — celle du reste du dépôt |

⚠️ **La fréquence fine a pu revenir à celle des autres tramages du dépôt**, et
c'est la conséquence la moins évidente : un brouillage de climat ne pouvait pas
se permettre une fréquence de bloc — au cœur d'une région il aurait tiré à pile
ou face sur chaque colonne d'un pays entier —, un déplacement de point le peut,
puisque loin d'une arête il ne change simplement pas de site.

**Le climat mélangé n'est plus qu'une aiguille.** `sample_column` rend
maintenant le climat **du site**, ce qui économise une passe sur neuf sites par
colonne — et paie la recherche tramée, si bien que la colonne ne coûte pas plus
cher. `climate_blend` reste, élargi à ~1 500 blocs
(`CLIMATE_WEIGHT_SCALE` : 5e-07 → 2e-08), et il ne sert plus qu'à l'ATH et aux
outils.

---

### 3. Les nuages : la moitié basse manque, et ils sont trop petits — **fait**

*Régénérer les nuages : il manque la moitié basse, et il faudrait aussi les
agrandir.*

**La cause n'était pas la coupe, c'était ce qu'il y avait dessous.** La rangée
basse des métaballes était posée à `0,02 h` avec un rayon de `0,34 h` : son
ventre descendait donc à `−0,32 h` quand le plan de coupe était à `+0,30 h`. La
coupe ne rasait pas le dessous du nuage, **elle tranchait la rangée basse
presque à son sommet** — il n'en restait qu'une couronne de six centièmes de
hauteur.

Le remède n'était donc pas `coupe = 0` — à zéro, un nuage est un galet, rond
partout, et il cesse de lire comme un nuage vu d'en dessous, qui est le seul
angle sous lequel on le voit. C'est **plus de masse sous le plus large lobe** :

* la rangée basse monte de `0,02 h` à **`0,34 h`** ;
* l'étage haut suit, de `0,46-0,68` à **`0,76-0,98`** — sinon il se noie dans la
  rangée basse et le chou-fleur disparaît avec les creux ;
* la coupe descend de `0,30` à **`0,12`**, et n'a plus qu'à raser.

**Pour agrandir**, c'est la géométrie qui a bougé et non la gigue d'instance :
34 → 48 blocs de large pour le cumulus, 56 → 78 pour le gros temps, 76 → 105
pour le voile. L'enveloppe vérifiée passe de `(24, 32)` à `(40, 56)`.

⚠️ **Et la maille du ciel a dû suivre**, ce qui n'était pas dans la demande :
`CWClouds.MAILLE` passe de 220 à **320**. Le voile fait 105 blocs, la gigue
d'instance le porte à 2,6 fois — 273 blocs —, et une cellule plus petite que le
nuage qu'elle porte fait un **plafond continu**. C'est le seul rapport du lot
qu'une capture ne rattrape pas : un plafond de nuages reste joli sur une image
et devient une chape dès qu'on avance. `tests/sky_test.gd` le vérifie
maintenant, en plus de l'enveloppe.

---

### 4. La carte ne nomme qu'une région sur deux — **fait**

*Corriger la carte, qui n'affiche le nom des régions que dans certaines zones.*

**Les deux causes annoncées étaient les bonnes, et chacune est corrigée sur son
propre plan.**

1. **le nom voyageait sur l'icône de relief**, qu'une région marine n'a pas :
   `markers` n'ajoutait une entrée que `if icon != ICON_NONE`. Un nom appartient
   à la région, pas à son relief ; c'est l'icône qui peut manquer. Un test
   vérifie maintenant qu'aucune région d'une vue n'est sans nom ;
2. **le seuil de zoom est remplacé par une mesure du chevauchement.** Il réglait
   un problème de collision par un seuil de densité, ce qui est en dire plus
   qu'on ne sait : à neuf zones, la moitié des noms tient très bien. Chaque nom
   demande donc sa boîte, on la pose si elle est libre, on saute le nom sinon.
   **L'ordre décide qui gagne** : les plus proches du curseur du joueur passent
   en premier, de sorte que la région où l'on se trouve est toujours nommée.

`--zones n` a été ajouté pour la capture : la carte dense est le seul cas qui se
juge, et rien ne savait l'ouvrir sans piloter la fenêtre.

---

### 5. La carte confond la neige et l'océan — **fait, et un défaut plus gros
trouvé en chemin**

*Revoir les couleurs pour différencier un biome neige d'un biome océan.*

**Le remède était bien celui qui était écrit** : la carte prend sa propre table,
indexée par **biome** et non par matière de surface — *une carte est une
légende, pas une photographie*. Six teintes franches, et un test qui vérifie
qu'elles se distinguent deux à deux dans un cube RVB pondéré comme l'œil.

⚠️ **C'est ce test qui a trouvé que le couple le plus proche n'était pas celui
qu'on croyait.** La neige et l'océan une fois séparés, le minimum est tombé sur
**la jungle et l'océan** — deux couleurs sombres, à 0,402 quand le seuil est à
0,45. Deux sombres se rapprochent bien plus vite que deux claires, et c'est
exactement le genre de chose que l'œil ne voit pas sur une palette mais voit sur
une carte.

**Et la carte ne montrait aucune mer**, ce qui n'était dans aucune des cinq
demandes. Elle échantillonnait une colonne au site et la peignait en eau si elle
tombait sous le niveau de la mer : sur les 81 régions autour du point de départ,
**28 sont océaniques et pas une ne rendait d'eau**. La raison est que le champ
d'altitude mélange neuf sites — au point même d'un site posé à −100, les voisins
et le bruit ramènent la colonne à +7, +25, +2, pour un niveau de mer à −60.
*Une colonne au site dit ce qu'il y a sous les pieds du site, et non ce qu'est
la région.* La carte lit maintenant le drapeau `is_ocean`, ce que
`icon_of_zone` faisait déjà — les deux disent enfin la même chose.

---

### Ce qui reste ouvert, et qui n'était dans aucune des cinq

- **compiler la GDExtension.** `native/` est complet et `CWValueNoise` a deux
  corps ; il manque le SDK Windows sur cette machine. La marche à suivre, la
  ligne de commande de l'installateur et les **quatre vérifications à faire dans
  l'ordre** le jour où elle compilera sont dans le journal de
  `docs/ROADMAP.md`, entrée du 2026-09-11. L'attente est un **facteur deux** sur
  le chargement, pas un facteur dix ;
- **la collision des cactus.** À 4 voxels par bloc, ils sont inestampables : les
  redessiner à la grille du terrain en ferait une pile de cubes, et en estamper
  un volume approché mettrait un pâté visible dans le modèle fin. Ce qu'un
  cactus veut est **une forme de physique** — un cylindre par instance, zéro
  voxel —, et ça se pose au jalon 3.1 avec le contrôleur ;
- **la saccade au chargement.** Affaire de latence et d'ordonnancement, pas de
  débit : un mailleur deux fois plus rapide qui rend ses pavés au même moment
  saccade toujours. Aucune des mesures du 2026-09-11 ne la voit ;
- **la gigue de taille des cinq arbres entiers**, perdue en passant en matière.
  Un modèle entier est estampé tel quel : le rééchantillonner étirerait une
  silhouette, et la flèche d'un conifère a déjà demandé trois reprises en trois
  jours. La variété devra venir de variantes de modèles.

---

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
# Suite de validation (449 vérifications, ~2 min)
# ⚠️ Elle prenait 25 s jusqu'au 2026-09-12. Ce qui coûte est `tests/lod_test.gd`,
# qui doit engendrer le monde à six niveaux de LOD pour les comparer — c'est la
# seule façon de tenir un contrat qui ne se voit pas au pas de un.
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path . -s tests/worldgen_test.gd

# Le mode LOD, en jeu. `--lod [n]` allume la pyramide (n niveaux, 6 par défaut),
# `--lod-vue d` sa distance de vue. Le brouillard et le plan lointain de la
# caméra suivent tout seuls depuis le 2026-09-13 : sans cela une capture de LOD
# ne montre qu'un mur laiteux à quatre cents blocs.
./godot.windows.editor.double.x86_64.exe --path . scenes/terrain_demo.tscn \
    --resolution 1600x900 -- --lod 6 --biome 0 --altitude 40 --regard -5 --shot 45

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

# La carte, DANS le jeu et a la densite qu'on veut : `--carte` l'ouvre au
# demarrage, `--zones n` la regle de 3 a 9. C'est le seul cas qui se juge —
# a neuf zones les noms se marchent dessus, et c'est la que l'evitement de
# collision se voit.
./godot.windows.editor.double.x86_64.exe --path . scenes/terrain_demo.tscn \
    --resolution 1600x900 -- --biome 1 --carte --zones 9 --shot 26

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
#   options : --sans-arbres, --sans-filons, --sans-flore, --sans-chemins,
#   --sans-falaise, --sans-nuages, pour isoler une couche. **--sans-arbres et
#   --sans-filons coupent une ecriture dans le terrain (le second depuis le
#   2026-09-15), pas seulement un rendu** : ils vident donc les caches, et ne
#   coupent **pas** la borne du chemin rapide, qui est une constante. C'est ce
#   qui a permis de separer les deux couts. Les deux dernieres servent aussi a
#   mesurer ce qu'elle coute au chargement. --carte ouvre la carte du monde au
#   demarrage.
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

# Reperer un filon (jalon 2.6), meme usage et meme graine que les deux
# precedents. Balaie les cellules de `CWOreScatter`, pas des colonnes : un
# filon se decide par cellule, pas par point.
./godot.windows.editor.double.x86_64.exe --headless --path . -s tools/find_ore.gd

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

**Jalon 1 (le monde) : 1.1 à 1.16 sont portés, testés et vus en jeu. Jalon 2.6
(l'apparition) est fait pour les filons**, seule moitié qui n'attendait rien du
reste du jalon 2 — voir §0. Suite de validation : **449 vérifications, 0
échec**, ~2 min (la suite de LOD, qui doit engendrer le monde à six niveaux pour
les comparer, en est le poste qui coûte). Le détail de chaque jalon est dans
`docs/ROADMAP.md` ; ce qui suit est ce qu'il faut savoir *avant de toucher au
code*.

### Ce que le monde contient aujourd'hui

Le champ d'altitude et son climat (1.1-1.5), les **éléments de tuile** qui le
déforment (1.6), les **six biomes** de l'alpha 2013 — Greenlands, Snowlands,
Deserts, Jungles, Lava Lands, Oceans —, décidés au **site de région** depuis le
2026-09-12 et donc grands comme une région (1.12), les **provinces climatiques**
qui font qu'une Snowlands peut toucher un désert (1.12bis), la **falaise** qui
habille de roche les flancs raides (1.13, retirée puis rétablie tramée), les
**lacs et rivières** qui suivent les fonds de vallée (1.14), le **réseau de
chemins** et ses levées (1.16).

**Il y a exactement huit matières de surface, et sept d'entre elles sont un
pays** : herbe, jungle, sable, neige, gravier, scorie et magma — Lava Lands est
le seul biome qui en porte deux, et c'est demandé. La huitième est la **roche**
de falaise, qui est une règle de pente. La terre ne se voit qu'au **lit d'une
mare** et en creusant : ce n'est pas une surface, c'est le sous-sol en coupe.

Par-dessus : la **flore** (1.7), instanciée ; les **arbres** (1.11), dont
toutes les pièces sont **écrites dans le terrain** depuis le 2026-09-11 —
la couche d'instances d'arbres n'existe plus, les **filons** (2.6, 2026-09-15),
neuf veines qui affleurent sur la falaise et s'estampent comme un arbre entier,
l'**édition** et sa persistance (1.8), l'**éclairage voxel** là où le joueur a
creusé (1.9), et la **carte du monde** (1.10).

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
| **la plage, le haut-fond et le marais** | 2026-09-12 | ils nommaient un endroit, ce qui les avait sauvés deux fois — mais **ils le nommaient de la même façon dans trois pays**. Le marais a emporté le roseau, seule plante qu'il portait |

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

**Et le climat n'est plus au milieu de cette chaîne.** Le biome se décide au
site de région (invariant n° 53), et l'écotone déplace le point plutôt qu'il ne
brouille le climat (n° 54) : le champ d'altitude et le champ de climat ne se
consultent plus l'un l'autre du tout.

L'ordre des recouvrements dans une colonne — **invariant n° 39** — est : *le
tronc estampé recouvre tout, le chemin creuse, l'étang mouille, le terrain
porte*. `_generate_block` les pose du plus profond au plus superficiel,
`voxel_of` les teste à l'envers.

### Les trois choses qu'un nouveau venu confond

1. **Un biome n'est pas une matière de surface** (invariant n° 27). `CWBiome.at`
   dit *où on est*, `CWPalette.surface_of` dit *de quoi c'est fait*. Depuis le
   2026-09-12, les deux se répondent presque un pour un — mais *presque* : la
   falaise et le lit d'une mare sont les deux endroits où ils divergent, et ce
   sont les seuls.
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
  cw_terrain_field.gd      climat + altitude + chenaux + éléments, et l'écotone
                           qui déplace le point  ← le cœur
  cw_biome.gd              les six biomes et la règle qui les décide, sur le
                           climat du site de région (1.12, 2026-09-12)
  cw_path_network.gd       le réseau de chemins, ses portes et ses levées (1.16)
  cw_palette.gd            palette, matières de surface — une par biome depuis
                           le 2026-09-12 —, coulées de lave (1.12)
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
  cw_ore_scatter.gd        les neuf filons : ou ils affleurent (la falaise) et
                           leur pose, memes cellules et memes principes que les
                           arbres (2.6, 2026-09-15)
  cw_world_edits.gd        creuser, poser, interroger un bloc (1.8)
  cw_light.gd              éclairage voxel : deux passes, cases à repeindre (1.9)
  cw_world_map.gd          carte : dalles de Voronoï, découverte, et sa propre
                           table de teintes par biome (1.10, 2026-09-12)
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
src/demo/map_overlay.gd      affichage de la carte (touche M), et l'évitement
                             de collision des noms (2026-09-12)
tests/worldgen_test.gd       suite headless, tient le compte des vérifications
tests/tile_features_test.gd  la moitié qui concerne les éléments de tuile
tests/decor_test.gd          rôles, tables croisées, filtre de matière, composition,
                             et le balayage qui refuse toute matière retirée
tests/flora_test.gd          modèles, dispersion, maillage et pose
tests/tree_test.gd           lot, enveloppes, grille, dispersion, espacement, montage
tests/ore_test.gd            lot, gangue et veine, dispersion, espacement,
                             accord bloc genere / requête ponctuelle (2.6)
tests/edit_test.gd           règles d'édition, requête ponctuelle, persistance (1.8)
tests/light_test.gd          les deux passes, l'atténuation, les cases à repeindre (1.9)
tests/map_test.gd            échelle, découverte, puzzle, rendu, teintes, noms (1.10)
tests/relief_test.gd         chemins, levées, tramage, écotone de Voronoï (1.16)
tests/lod_test.gd            la pyramide de LOD : la composition ne dépend pas du
                             niveau, et le sol ne se noie pas (2026-09-13)
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
tools/find_ore.gd            un filon, par cellule de `CWOreScatter` (2.6)
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
5. **Le plafond du cache de colonnes doit couvrir l'empreinte chargée —
   *en mode plat*.** `HEIGHTMAP_CACHE_CAP` ≥ `(2 × distance_de_vue / 16)²`, sinon
   le cache s'auto-évince en boucle et le chargement s'effondre sans rien
   signaler. C'est ce qui bornait la vue à 1 024 blocs.
   ⚠️ **En mode LOD, cet invariant ne mord plus** (2026-09-13) : la pyramide ne
   garde qu'un anneau mince par niveau, et l'empreinte cesse de croître avec le
   carré de la distance — 740 entrées pour 2 048 blocs de vue, contre 2 500 pour
   384 à plat. Ne pas régler `lod_view_distance` contre cette formule : elle ne
   décrit pas ce mode.
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
    exactement.** Un rôle qu'un biome sait *choisir* mais pas *poser* ne lève
    rien : la plante disparaît, et la densité moyenne ne bouge pas assez pour
    se voir — un quart des candidats d'un biome peut s'évaporer en silence.
    C'est **exactement ce qui serait arrivé au roseau** le 2026-09-12 si le
    marais était parti seul, et c'est pourquoi les deux sont partis ensemble.
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
    — `DENSITY`, `ROLES`, `SPECIES`, `FAMILIES` — sont indexées par **biome**, et
    depuis le 2026-09-12 **elles n'ont plus une seule exception** : les deux
    tables par matière (`FAMILIES_SURFACE`, `FAMILIES_SURFACE_BIOME`) sont
    parties avec le marais, et `role_at` ne prend plus la matière du tout.
    Confondre les deux ferait pousser des bleuets sur la roche nue d'une
    prairie de montagne — ce que `decor_allowed` empêche, et qu'aucun test de
    table ne verrait.

    ⚠️ **Et la lecture inverse est vraie depuis le même jour :** une matière ne
    dit plus rien qu'un biome ne dise déjà. Il n'en reste **qu'une** hors des
    six — la roche de falaise, qui est une règle de *pente* — et une qui n'est
    pas une surface : la couche meuble du lit d'une mare, qui est le sous-sol
    vu en coupe. Toute nouvelle matière devra passer cette question : *qu'est-ce
    qu'elle nomme que le biome ne nomme pas ?*
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

    ⚠️ **`pond_surface` a perdu son argument `biome` le 2026-09-12** : la rive
    d'une mare ne prend plus la matière du marais, donc la matière rendue ne
    dépend plus du pays. La **forme**, elle, n'a pas bougé — c'est la même
    fonction, au même endroit de la chaîne, et c'est elle qui creuse la berge.
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
    cinq marches de fondu au pied d'une falaise. Le seul endroit où les deux canaux
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
53. **Le biome se classe au site de région, et le climat mélangé ne décide
    plus rien.** Depuis le 2026-09-12, `sample_column` rend le climat **du site
    le plus proche** et `CWBiome.of_site` le classe : un biome est une cellule
    du diagramme de Voronoï des sites, seize mille blocs de côté par
    construction. `CWTerrainField.climate_blend` existe toujours et rend le
    mélange, **élargi et réservé à l'ATH et aux outils**.

    ⚠️ Les deux nombres ne se contredisent pas — l'un est le climat du lieu,
    l'autre celui du pays — mais **un seuil de `CWBiome` réglé en regardant
    l'ATH serait faux**. Le seul instrument qui mesure la bonne grandeur est
    `tools/biome_stats.gd`, et le seul qui résolve les seuils est
    `tools/biome_balance.gd` ; tous deux passent par `sample_column`, donc par
    le climat qui classe.
54. **L'écotone déplace le point, il ne brouille plus le climat.**
    `CWTerrainField.fringe_point` décale la colonne d'au plus `FRINGE_BLOCKS`
    avant de chercher son site ; c'est ce point-là qui décide la **matière** du
    sol, le point vrai décidant le biome **nommé** — celui qui choisit ce qui
    pousse, ce que l'ATH affiche et ce que la carte teinte. Les mêler ferait
    pousser un cactus tous les vingt blocs le long d'un désert.

    ⚠️ **Une amplitude en unités de climat ne se remet pas.** C'est ce qui a été
    retiré ce jour-là, avec les trois mécanismes qui la bornaient : une telle
    amplitude ne dit rien de la largeur de la frange **en blocs**, celle-ci
    valant l'amplitude divisée par la pente locale du champ — et infinie là où
    le champ est plat, c'est-à-dire au cœur de chaque région. *Une frontière
    dans l'espace se brouille dans l'espace.*

55. **Une cellule de LOD n'est pas un point, c'est une boîte de `pas` unités.**
    Tout le générateur est écrit comme si « juste au-dessus du sol » était
    `sol + 1` ; au LOD c'est **la cellule suivante**, et `_cell_above(w, pas)` est
    le point unique qui le dit. Au pas de un il rend `w + 1`, donc le LOD 0 ne
    bouge pas d'un voxel — et c'est vérifié pour tout `w`, négatifs compris (la
    division doit s'arrondir **vers le bas**, pas se tronquer : le niveau de la
    mer est à −60). Une couche mince et locale qui démarre à `sol + 1` occupe la
    cellule du sol et l'efface : c'est ce qui faisait la dalle d'eau.
56. **La mer est la seule couche d'eau qui ait le droit d'occuper la cellule du
    sol.** Elle est un plan à altitude unique et n'existe que là où le terrain
    passe dessous, donc elle ne peut pas faire de dalle en pleine plaine ; et
    c'est elle qui cache le débordement vers le haut de la cellule d'un fond
    marin. Lui appliquer la règle de l'étang faisait tomber la part d'eau de
    **54,6 % à 35,2 %** au LOD 5. L'étang et le dégagement d'un chemin, eux, sont
    minces et locaux : ils passent par `_cell_above`.
57. **Un bloc couvre `taille × pas` unités de monde, pas `(taille − 1) × pas`.**
    La borne haute d'un bloc est la dernière unité que sa dernière cellule
    couvre, jamais son plancher. Se tromper rogne la bande haute de chaque bloc,
    bloc de surface compris — 72 % des colonnes en roche nue au LOD 4 — et **ça
    ne se voit pas au pas de un**, où les deux formules coïncident.
58. **Un test de LOD doit porter sur une emprise qui contient ce qu'il vérifie.**
    La première version de `tests/lod_test.gd` mesurait autour du point de
    départ, qui n'a ni mer ni mare : elle passait au vert avec le défaut remis en
    place. `CWLodTest.ORIGIN` vise un endroit choisi — 41 % de mer, 17 % de
    mares. Et **un garde-fou se vérifie en remettant le défaut** : sans ça on ne
    sait pas s'il garde quoi que ce soit.
59. **Un filon n'affleure que sur la roche de pente, et rien d'autre.**
    `CWOreScatter` n'a de sens qu'à l'endroit où `CWPalette.surface_of` rend
    `STONE` : la falaise est la seule matière du monde qui ne soit pas celle
    d'un biome (invariant n° 27), et un modèle de filon porte sa propre gangue
    de roche pour s'y fondre (`generer_filons.py`, en-tête) — le poser ailleurs
    dessinerait un caillou peint sur de l'herbe. Comme la falaise, ce test
    demande la **pente** (`slope_at`), jamais la version sans pente que l'ATH
    utilise pour son affichage (`terrain_demo._update_hud`) : les deux
    répondent à des questions différentes, et régler le seuil de la couche en
    lisant l'ATH décrirait un monde qui n'est pas celui qui se génère.

    ⚠️ **Et un filon ne survit pas au LOD** (`CWVoxelGenerator.ORE_MAX_LOD`,
    zéro), pour la même raison qu'un houppier ne survit pas au-delà de
    `TREE_MAX_LOD` : un affleurement de quatre blocs de rayon disparaît d'un
    bloc à l'autre. `tests/lod_test.gd` doit couper `p.ores` comme il coupe déjà
    `p.trees`, sans quoi il confond un filon qui disparaît avec la dalle d'eau
    qu'il est fait pour attraper — c'est exactement ce qui est arrivé à
    l'écriture de cette couche, sur deux colonnes d'une emprise qui n'avait
    jamais vu de filon avant.

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

  ⚠️ **Et depuis le 2026-09-12, ils se lisent sur le climat du site**, non plus
  sur celui de la colonne. Le solveur relancé le confirme : les parts n'ont pas
  bougé d'un dixième de point, parce que le climat de la colonne était déjà un
  plateau par région. Ce que ça change n'est donc pas la composition du monde,
  c'est **où l'on a le droit de lire un climat** — voir l'invariant n° 53.

- **Une région d'océan est un pays, pas une ligne de rivage** (2026-09-12). La
  carte peint en bleu toute région dont le site est noyé, îles comprises, et
  peint en terre une région terrestre dont un tiers de la surface est sous
  l'eau. C'est cohérent avec l'icône, qui lit le même drapeau, et c'est le seul
  choix abordable : peindre le rivage demande une case par chunk au lieu d'une
  par région, soit **4 096 fois le coût**. La route, si on la prend un jour, est
  de peindre à la case *l'altitude* et de ne garder la teinte de région que pour
  la terre.

- **Combien de matières un biome a-t-il le droit d'avoir ?** La règle dit une, et
  Lava Lands en a deux — la scorie et le magma — parce que c'est ce qui a été
  demandé. La question se reposera au premier biome qui voudra une seconde
  matière : ce qui distingue le magma d'une frange d'humidité est qu'il **nomme
  un lieu** (une cuvette, une coulée) et non un gradient, et c'est le seul
  critère que ce dépôt ait trouvé qui tienne dans les deux sens.
- ~~**La bande d'herbe sèche de Greenlands est large.**~~ **Sans objet** :
  `DRY_GRASS_H` n'existe plus depuis le 2026-09-06, avec le retrait de l'herbe
  sèche et de la toundra. Ce qui reste vrai de cette note est la mesure qui la
  portait — *le champ d'humidité n'a presque rien entre 0,10 et 0,40* —, et
  c'est elle qui a décidé où poser `CWBiome.HUMID_H` le 2026-09-11.
- **Oceans n'a été vu que d'au-dessus.** Voir l'annexe de `docs/ROADMAP.md`,
  §6.5.
