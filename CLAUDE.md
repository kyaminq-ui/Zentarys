# Zentarys

Reconstruction sous Godot 4.7 du générateur de monde de **Cube World alpha
(2013)**, par rétro-ingénierie du binaire. Rendu en cubes colorés, monde de
~8,4 millions d'unités de côté, double précision.

**Une session doit pouvoir commencer sur ce fichier seul.** Pour toucher au
monde, lire ensuite `nextsteps.md` (invariants, pièges, décisions ouvertes).
Le récit des sessions passées est en annexe de `docs/ROADMAP.md` — on l'ouvre
pour comprendre *pourquoi* une chose a été faite ou défaite, jamais pour
démarrer.

| quoi | où |
|---|---|
| ce qui reste à faire | `nextsteps.md` §0 |
| les invariants, les pièges | `nextsteps.md` §4, §5 |
| l'histoire, jalon par jalon | `docs/ROADMAP.md` |
| l'analyse de la source | `docs/systems/01` à `05` |
| l'authoring des modèles | `docs/ASSETS.md`, `assets/models/MODELS.md` |

## Environnement

Godot **4.7.2 stable, double précision**, module Voxel Tools 1.7 compilé dedans.
Le binaire est à la racine du dépôt **et** sur le Bureau (190 Mo, versionné) :

```
./godot.windows.editor.double.x86_64.exe
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe
```

Le greffon `addons/godot_ai` est actif et versionné : sans lui le projet ne
s'ouvre pas proprement. Il permet de piloter l'éditeur par MCP.

## Les quatre commandes qui servent tous les jours

```bash
# La suite de validation — 407 vérifications, ~25 s. À lancer après toute
# modification du monde. C'est le filet, et il tient tous les contrats
# inter-fichiers que rien d'autre ne tient.
./godot.windows.editor.double.x86_64.exe --headless --path . -s tests/worldgen_test.gd

# Une capture en jeu, sans piloter la fenêtre. C'est le SEUL moyen de voir une
# couche de rendu : un test headless n'a pas de rastériseur.
# --biome : 0 Greenlands, 1 Snowlands, 2 Deserts, 3 Jungles, 4 Lava Lands,
# 5 Oceans. --shot est le délai avant la capture, le temps que le terrain
# charge ; la session se ferme ensuite. Le PNG sort dans user://shots.
# --regard d pose l'assiette de la caméra en degrés : c'est la seule option qui
# sache regarder en l'air, et donc la seule qui cadre une couche du ciel.
./godot.windows.editor.double.x86_64.exe --path . scenes/terrain_demo.tscn \
    --resolution 1600x900 -- --biome 0 --shot 34 --vue 256

# Réimport, obligatoire après l'ajout d'un class_name.
./godot.windows.editor.double.x86_64.exe --headless --path . --import

# La démo, au clavier. Clic pour capturer la souris, ZQSD, Maj = rapide,
# Espace/Ctrl = monter/descendre, F1 détails, clic gauche creuser, clic droit
# poser, F12 capture, Page haut/bas distance de vue, M carte, 1-6 téléportation
# vers un biome, F2 fige l'heure, F3/F4 reculent ou avancent d'une heure,
# Échap pour rendre la souris puis quitter.
./godot.windows.editor.double.x86_64.exe --path . scenes/terrain_demo.tscn

# Trois bascules qui servent souvent, et qui n'existent que pour la capture :
#   --heure h   se pose à une heure du cycle (0 minuit, 0,5 midi) et le fige
#   --regard d  l'assiette de la caméra, en degrés au-dessus de l'horizon
#   --fils n    force le nombre de fils de génération — le réglage le plus
#               rentable du projet, et son optimum est propre à la machine
```

Le reste de l'outillage — statistiques de biomes, planches de validation
d'assets, aperçus de carte, générateurs de modèles — est en `nextsteps.md` §2.

## Les cinq invariants qui coûtent le plus cher

La liste complète est en `nextsteps.md` §4, et elle compte cinquante-deux
entrées. Ces cinq-là sont ceux dont l'oubli coûte une session entière.

1. **Les constantes du bruit et du LCG sont porteuses** (n° 1). Les valeurs
   attendues dans `_test_value_noise` et la séquence MSVC `41, 18467, 6334…`
   fixent l'identité de **tous** les mondes déjà engendrés. Si elles bougent,
   chaque monde déjà exploré change. Ne jamais « corriger » ces tests pour les
   faire passer : c'est le code qui a régressé.

2. **`voxel_of` a deux consommateurs qui doivent s'accorder** (n° 18, n° 39).
   `_generate_block` déroule la règle par intervalles pour remplir un bloc vite ;
   `generated_voxel` l'évalue en un point pour répondre à une requête. Rien dans
   le code ne les y oblige — ce sont les balayages de `tests/edit_test.gd`, de
   `tests/relief_test.gd` et de `tests/tree_test.gd` qui tiennent le contrat.
   **Une couche ajoutée d'un seul côté donne un monde dont les collisions et
   l'édition décrivent autre chose que ce qu'on voit.** C'est arrivé deux fois :
   le tronc estampé a manqué du côté de la requête ponctuelle du jalon 1.11 au
   2026-09-10, et le feuillage a fait rendre deux réponses différentes aux deux
   chemins le 2026-09-11. L'ordre est *arbre, chemin, étang, terrain*, et
   `voxel_of` le teste à l'envers — avec une exception, **le feuillage ne
   recouvre que le vide**.

3. **Le dessus praticable d'une colonne a un point unique** (n° 42).
   `CWPathNetwork.shaped_top` dit où est le sol quand un chemin traverse la
   colonne. Le générateur, la requête ponctuelle, `CWScatter` et `CWTreeScatter`
   doivent tous les quatre passer par là. Un objet posé à la hauteur brute du
   champ **flotte ou s'enterre**, et ça ne se voit que sur une capture.

4. **Un biome n'est pas une matière de surface** (n° 27). `CWBiome.at` dit *où on
   est* ; `CWPalette.surface_of` dit *de quoi c'est fait*. Les tables de contenu
   — `DENSITY`, `ROLES`, `SPECIES`, `FAMILIES` — sont indexées par **biome**.
   Les confondre fait pousser des bleuets sur la roche nue.

5. **Il y a quatre grilles de dessin, et le modèle porte la sienne** (n° 28).
   Arbres et filons à **1** voxel par bloc, flore à **4 ou 6**, personnage et
   créatures à **40/3**. Tout ce qui convertit des voxels en blocs doit lire
   `model.voxels_per_block`, jamais la constante. S'ils divergent, la plante sort
   à une taille fausse d'un facteur un et demi — assez pour se voir, pas assez
   pour qu'on remonte à la cause.

## Trois règles de style, et ce sont des règles de découpe

* **Un fichier, une décision.** Les cinq gros fichiers du dépôt font chacun
  plusieurs métiers, et c'est la dette nommée dans `nextsteps.md` §0.
* **Une couche ne connaît que celle du dessous.** La chaîne va `chemins → champ`
  et ne revient pas. Le jour où un terme du champ d'altitude consulterait un
  chemin, il faudrait la garde de réentrance, les verrous et l'attente entre fils
  que `CWTileFeatureGrid` doit porter — et rien ne le signalerait avant qu'un
  monde cesse de se régénérer à l'identique.
* **Un commentaire dit *pourquoi*, jamais *quoi*.** Le code du dépôt est
  abondamment commenté en français, et ce qu'il explique est toujours la raison
  d'un choix, la mesure qui l'a justifié, ou le piège qu'il évite. Écrire dans
  ce registre-là, ou ne rien écrire.

## Ce qu'il faut savoir avant de proposer une idée

**Quatre systèmes ont été portés puis retirés** — la falaise (revenue depuis,
tramée), les ponts, le lot d'ouvrages, les surplombs et leurs grottes. **Les
quatre passaient tous leurs tests.** C'est écrit en tête de
`tests/relief_test.gd` : *cette suite vérifie de la géométrie, jamais du rendu ;
la capture reste le juge.*

Deux corollaires :

* **une chose qui compile, passe ses tests et se mesure bien peut être mauvaise**,
  et le seul moyen de le savoir est de la regarder en jeu ;
* **une chose absente de la source n'est pas hors périmètre, elle est à
  décider.** C'est ce qui a justifié le réseau de chemins, qui n'est dans aucune
  fonction de l'original et qui, lui, est resté.

## Git

Dépôt : <https://github.com/kyaminq-ui/Zentarys.git>, branche `main`. Les
messages de commit du dépôt sont en français, à l'infinitif ou au présent, et
disent **ce qui change dans le monde**, pas ce qui change dans le code —
« Le chemin est creusé jusqu'en son milieu », « Les massifs cessent d'être
escaladables ». Suivre ce registre.
