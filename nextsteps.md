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

> **Programme du 2026-09-09 au soir, quatre demandes.** La première est faite, la
> quatrième l'est à moitié. Ce qui reste est ci-dessous, dans l'ordre d'exécution
> recommandé — qui n'est pas celui où elles ont été formulées.

### Ce qui a été fait le 2026-09-10

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

### 1. Ce qui reste du n° 4 — le code

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
| `src/demo/terrain_demo.gd` | 928 | arguments, terrain, ATH, caméra, captures, persistance |
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

### 2. Optimisation, et peut-être du C++

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

**L'étape 1 est faite le 2026-09-10** — `tools/profile_worldgen.gd`, écrit pour
ça et à relancer après toute modification du champ. Chargement d'une vue de
384 blocs : **55,4 s**. Le profil, sur la graine de la démo, éditeur fermé :

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
   désactivant. Elle sonde quatre colonnes par plante posée, une par une, là où
   le générateur passe par `sample_patch` pour exactement la même raison. C'est
   le gain le moins cher du lot, et il ne demande pas de C++.

À faire ensuite, dans cet ordre :

1. ~~**Mesurer par poste.**~~ Fait — `tools/profile_worldgen.gd` ;
2. **Les gains qui ne demandent pas de C++**, et il y en a deux que la mesure
   désigne : **l'assiette de la flore** (point 3 ci-dessus), et le nombre de fils
   (`generation_threads`, auto aujourd'hui). Voir aussi le plafond du cache de
   pavés (16 384) et `generate_collisions`, déjà à faux.

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
   **93,7 → ~50 µs/colonne** et un chargement de 384 blocs autour de **30 s** au
   lieu de 55. Porter `_height_from` entier irait plus loin. C'est donc un
   facteur deux, pas un facteur dix : *à décider en sachant ce qu'une chaîne de
   compilation coûte au dépôt.*

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

### 3. Un ciel, des nuages, et un cycle jour/nuit

*Ajouter des nuages et un ciel, système basique jour/nuit, et adapter en
conséquence le brouillard et l'éclairage déjà implémentés.*

**L'existant tient en vingt-cinq lignes**, `_build_environment()` dans
`src/demo/terrain_demo.gd` : un `DirectionalLight3D` à un angle fixe, un
`ProceduralSkyMaterial` nu, l'ambiante prise du ciel à 0,45, un tonemap
filmique, et un brouillard **constant** — `fog_light_color` gris-bleu,
`fog_density` 0,0016. Rien n'y varie dans le temps.

Ce qu'il faut écrire :

* **un scalaire d'heure** dans `[0, 1)`, et une seule fonction qui en déduit
  *tout* : rotation, énergie et couleur du soleil ; couleurs de zénith,
  d'horizon et de sol du ciel ; énergie de l'ambiante ; **couleur et densité du
  brouillard**. Un seul point d'entrée, sinon l'aube aura un ciel rose et un
  brouillard bleu ;
* **les nuages.** `ProceduralSkyMaterial` n'en a pas. Deux routes : un
  `ShaderMaterial` de ciel avec un bruit fractal en coordonnées de direction —
  pas de géométrie, pas de limite de couverture, et le projet a déjà toute sa
  culture de bruit —, ou un dôme texturé qui défile. **La première**, et c'est
  aussi celle qui donnera les ombres de nuages plus tard si on les veut ;
* **une vitesse**, et une touche pour la forcer. Regarder une aube en temps réel
  n'est pas une méthode de réglage.

> ⚠️ **Le piège, et il est structurel : `CWLight` est un éclairage *cuit*.** La
> passe A descend le soleil colonne par colonne, la passe B diffuse seize fois à
> l'horizontale, et le résultat est écrit **dans le canal de couleur du voxel** à
> la génération. Il ne suit pas le `DirectionalLight3D`. Tourner le soleil ne
> rallume donc rien, et un recuit est hors de question (7 ms pour un pavé
> de 33³).
>
> La lecture qui marche : **le voxel cuit devient un terme d'occlusion**, pas une
> heure — il dit *ce recoin est abrité*, ce qui reste vrai la nuit — et c'est la
> lumière directionnelle de la scène qui porte le cycle. À vérifier en jeu, parce
> que l'éclairage cuit a une composante « ciel » à 255 qui pourrait rester trop
> claire de nuit ; si c'est le cas, c'est un facteur global à l'affichage, pas un
> recuit.

> ⚠️ **Le brouillard et le n° 2 sont couplés.** La densité actuelle est réglée
> pour cacher le bord d'une vue de 384 blocs. Le n° 2 veut augmenter cette
> distance : la même densité rendra alors le lointain laiteux bien avant le bord.
> **Ne pas régler le brouillard avant de savoir quelle distance de vue on vise**,
> ou le faire deux fois.

**Où ça vit : `src/demo/cw_daylight.gd`, qui existe depuis le 2026-09-10.** Le
nœud est déjà sorti de `terrain_demo.gd` et son en-tête porte la forme visée et
les deux pièges ci-dessus. Il ne reste qu'à y écrire le scalaire d'heure et le
shader de ciel.

> **Pourquoi cet ordre.** Le rangement du code rend les sessions suivantes moins
> chères et bénéficie du retrait qui vient d'avoir lieu ; l'optimisation se
> mesure sur du code déjà allégé ; le ciel vient en dernier parce que le réglage
> du brouillard dépend de la distance de vue que l'optimisation aura fixée. Il
> est aussi le plus visible et le plus court : **si le moral demande un résultat
> visible tout de suite, c'est celui-là qu'il faut prendre en premier**, en
> acceptant de régler le brouillard deux fois.

---

### Les portes déjà ouvertes, inchangées

1. **La collision, objet par objet** — la fin du jalon 1 côté finition. Le
   tableau est fait dans l'annexe de `docs/ROADMAP.md` : cinq modèles entiers à
   passer en matière (une ligne chacun), le branchage et les filons déjà réglés,
   et **un seul vrai arbitrage**, le feuillage — matière (×12 sur ce qu'un arbre
   écrit, soit ~+25 % de chargement) ou volume approché au jalon 3.1. Rien ne se
   voit tant que `generate_collisions` est à faux sur le terrain de la démo.
2. **2.6, l'apparition** — l'autre porte, et elle mène au jalon 2. Elle n'attend
   rien : la fonction est lue, les constantes de pose extraites, la couche
   d'éléments existe depuis 1.6 et la carte sait les afficher.

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
  donc les bouger est cheap et vérifiable. Elles n'ont pas été balayées ;
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
#   pour isoler une couche. Les deux dernieres servent aussi a mesurer ce
#   qu'elle coute au chargement. --carte ouvre la carte du monde au demarrage.
#   --vers x z oriente la camera vers un point, --altitude n la leve : sans les
#   deux, une capture d'un objet pose a cent blocs est une capture de ce qui se
#   trouvait dans l'autre sens.

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
biome, **Échap** rend la souris puis quitte.

## 3. État

**Jalon 1 (le monde) : 1.1 à 1.16 sont portés, testés et vus en jeu.** Suite de
validation : **379 vérifications, 0 échec**, ~25 s. Le détail de chaque jalon est
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

Par-dessus : la **flore** (1.7) et les **arbres** (1.11) instanciés par deux
couches de dispersion jumelles, l'**édition** et sa persistance (1.8),
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
   **le tronc d'un arbre, si** (jalon 1.11) — et les deux moitiés d'un arbre
   sortent du même tirage, dans la même liste (invariant n° 35).

### La carte des fichiers

```
src/worldgen/
  cw_value_noise.gd        bruit de valeur (Hugo Elias), arithmétique 32 bits émulée
  cw_rand.gd               LCG de la CRT MSVC
  cw_region_site.gd        structure d'un site de zone
  cw_region_site_grid.gd   grille 1024² paresseuse, caches sous mutex
  cw_tile_feature.gd       structure d'un élément de tuile
  cw_tile_feature_grid.gd  grille 8x8 par zone, paresseuse, garde de réentrance
  cw_terrain_field.gd      climat + altitude + chenaux + éléments  ← le cœur
  cw_biome.gd              les six biomes et la règle qui les décide (1.12)
  cw_path_network.gd       le réseau de chemins, ses portes et ses levées (1.16)
  cw_palette.gd            palette, matières de surface, coulées de lave (1.12)
  cw_voxel_generator.gd    VoxelGeneratorScript, cache de colonnes, troncs estampés
  cw_voxel_model.gd        modèle .vox préparé : deux grilles de dessin (1.12)
  cw_model_library.gd      chargement des modèles + tables par biome et par rôle
  cw_scatter.gd            grille de dispersion 16², cellules en cache
  cw_decor_rules.gd        rôles du décor : deux crêtes, rareté, taille, filtre
  cw_flora_drops.gd        ce que rend une plante, et les chaînes d'artisanat (1.12)
  cw_flora_renderer.gd     instanciation de la flore (MultiMesh par cellule)
  cw_tree_rules.gd         les espèces d'arbres et leurs trois montages (1.11)
  cw_tree_scatter.gd       la couche jumelle : cellule de 64, espacement de 14,
                           et le tronc en matière (1.11)
  cw_world_edits.gd        creuser, poser, interroger un bloc (1.8)
  cw_light.gd              éclairage voxel : deux passes, cases à repeindre (1.9)
  cw_world_map.gd          carte : dalles de Voronoï, découverte, teintes (1.10)
  cw_region_name.gd        noms de région : deux tables de vingt syllabes (1.10)
src/demo/terrain_demo.gd     scène de démonstration, touches 1-6 par biome
src/demo/cw_daylight.gd      le ciel, le soleil et le brouillard — et le futur
                             cycle jour/nuit
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
tools/export_palette.gd      régénère assets/palette/* depuis CWPalette
tools/biome_stats.gd         répartition des biomes et des matières, mesurée (1.12)
tools/preview_features.gd    gros plan ombré, avec et sans la couche d'éléments
tools/inspect_model.gd       inventaire d'un .vox : gabarit, index, plages, morceaux
tools/repaint_models.gd      remet un .vox dans la palette de projet
tools/preview_map.gd         aperçu de la carte, vierge et après une diagonale
tools/find_path.gd           une chaussée, une levée (1.16)
tools/profile_worldgen.gd    le profil du chargement, poste par poste
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
docs/ROADMAP.md              la feuille de route, le journal, et le récit des sessions
docs/ASSETS.md               l'échelle d'authoring et ce qu'il faut produire par biome
docs/systems/01..05          les analyses de rétro-ingénierie
assets/palette/              palette de projet + PALETTE.md
assets/models/flore/<biome>/   38 modèles, un dossier par biome (six)
assets/models/arbres/<biome>/  39 modèles d'arbres, à la maille du bloc
assets/models/filons/          9 filons, estampables (1 voxel = 1 bloc)
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
    chemin creuse, l'étang mouille, le terrain porte* — et le **tronc estampé**
    passe avant tout, puisque `_stamp_trunks` écrit après tous les
    remplissages. Une couche ajoutée d'un seul côté donne un monde dont les
    collisions et l'édition décrivent autre chose que ce qu'on voit — c'est
    l'invariant n° 18, et le tronc en a été l'exemple : il a manqué du côté de
    la requête ponctuelle du jalon 1.11 au 2026-09-10, sans qu'aucune
    vérification tombe.
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
    ramené à **55,4 s** le 2026-09-10. Toute mesure de coût citée ici porte donc
    sa date, et une date qui a plus d'une session vaut comme ordre de grandeur,
    pas comme référence.

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
- **Coût mesuré le 2026-09-10 : 75,8 µs par colonne**, soit ~19 ms par bloc 16³
  à froid, et **55,4 s** pour stabiliser une vue de 384 blocs. C'est le plafond
  de tout. Ces deux chiffres portent leur date, et c'est délibéré — voir
  l'invariant n° 51 : le précédent a dérivé de 28,5 s à 107,7 s en deux jours
  sans que personne le refasse. La couche d'éléments n'ajoute rien de mesurable
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
  vient de l'alpha 2013 et les fourchettes de climat aussi, mais la conversion
  entre le champ normalisé de `CWTerrainField` et les degrés Celsius est une
  convention (`CWBiome.TEMP_MIN_C` / `TEMP_MAX_C`), et les seuils ont été
  **recalés sur la répartition mesurée** plutôt que sur les degrés. Ils sont donc
  ajustables sans rien casser, à condition de relancer `tools/biome_stats.gd` —
  c'est écrit dans l'en-tête du fichier, et l'annexe de `docs/ROADMAP.md` (§6.3)
  dit pourquoi.
- **La bande d'herbe sèche de Greenlands est large.** `DRY_GRASS_H` est à 0,46,
  ce qui donne 5,1 % du monde ; l'alpha place Greenlands entre 30 et 70 %
  d'humidité, ce qui la mettrait plus bas. La raison est mesurée : le champ
  d'humidité n'a presque rien entre 0,10 et 0,40, donc le seuil ne peut pas se
  poser au milieu — il attrape ou non l'amas 0,40-0,45 tout entier. À 0,42 la
  steppe disparaîtrait du monde.
- **Oceans n'a été vu que d'au-dessus.** Voir l'annexe de `docs/ROADMAP.md`,
  §6.5.
