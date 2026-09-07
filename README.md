# Zentarys

Réimplémentation « clean room » des systèmes de jeu de l'alpha 2013 de
**Cube World**, sur Godot 4.7 et Voxel Tools 1.7.

L'objectif est de comprendre et de réécrire les **algorithmes** du jeu —
génération de terrain, climat, comportements, réseau — à partir d'une analyse
statique du binaire, puis d'en produire une implémentation originale en
GDScript idiomatique.

## État

**Le jalon 1 — le monde — est complet.** Bruit de valeur, LCG, sites de région,
mélanges climatiques, champ d'altitude, réseau de chenaux, éléments de tuile
(bourgs, cratères, caldeiras, pitons), générateur voxel et rendu en cubes
colorés. S'y ajoutent une couche de flore instanciée — dispersée selon les deux
fréquences de bruit de l'original, et **choisie par sa règle de sélection**,
deux crêtes de bruit qui donnent à chaque région sa composition —, l'édition du
terrain avec sauvegarde du seul diff, l'éclairage voxel, et la carte du monde :
un puzzle de régions, chacune la cellule de son site dans le domaine déformé,
avec ses noms et sa découverte.

**Le monde a six biomes** — Greenlands, Snowlands, Deserts, Jungles, Lava Lands,
Oceans. Un biome est une zone *climatique* : il décide ce qui pousse, tandis que
la matière du sol — herbe, sable, neige, jungle, magma — est une conséquence du
biome, **une seule par biome**, et une seule bande d'altitude la traverse encore :
la plage. La roche nue a été essayée deux fois hors de Lava Lands, sur l'altitude
puis sur la pente, et retirée les deux fois — `docs/ROADMAP.md` §1.13 dit
pourquoi. Les climats extrêmes sont regroupés en **provinces** qui s'adoucissent
vers le tempéré à leurs bords : on ne passe jamais d'une neige à un désert sans
traverser une prairie. Chacun porte son
propre lot de modèles : **38 pour la flore basse** — quatre voxels par bloc pour
ce qui a du volume, six pour les herbes et les fleurs, dont toute la forme tient
dans un trait — et **24 pour les arbres**, dessinés à la maille du bloc comme le
terrain lui-même.

**L'eau de surface est là** : des rivières continues le long des fonds de vallée,
posées par le même réseau de chenaux qui les creuse — il ne manquait pas un
champ, il manquait un seuil. Elles s'élargissent en descendant et finissent en
nappes dans les bas-fonds. 2,8 % des terres en eau, profondeur d'un à quatre
blocs, une berge un bloc au-dessus de la surface, et rien dans les déserts.

**Le relief a une couche de plus**, posée par-dessus le champ d'altitude et
jamais dedans : les **chemins**. Ils relient les jalons d'une zone, se
raccordent à ceux des voisines par des portes de frontière calculées des deux
côtés sans qu'aucune ne lise l'autre, se creusent d'un bloc **sur toute leur
largeur**, et franchissent les rivières sur une **levée** qui comble le lit
plutôt que de l'enjamber. Ils ne sont dans aucune fonction de la source, et
l'en-tête du fichier le dit — *une chose absente de la source n'est pas hors
périmètre, elle est à décider.*

> **Trois autres couches ont été portées puis retirées** : la falaise dans sa
> première version, les ponts, et les surplombs avec leurs grottes. Les trois
> passaient tous leurs tests. C'est la leçon centrale de ce dépôt, et elle est
> écrite en tête de `tests/relief_test.gd` : *la suite vérifie de la géométrie,
> jamais du rendu ; la capture reste le juge.*

La **falaise** est revenue dans une seconde version — c'est le premier système
que ce dépôt retire puis rétablit —, et avec elle le **dégradé adouci** entre
deux matières de
surface. Il tient à une propriété du rendu qu'on n'avait pas exploitée : un
voxel porte sa matière dans un canal et sa **couleur** dans l'autre, et rien
n'oblige deux blocs d'herbe à être de la même teinte. Une prairie prend donc
trois tons, une frontière cinq marches de fondu, et le sable et l'herbe
s'interpénètrent sur une dizaine de blocs au lieu d'être séparés par une courbe
de niveau.

Deux chantiers suivent : la **collision** des objets instanciés, qui reste due —
les chemins, eux, sont de la matière et l'ont gratuitement ; et le **jalon 2**,
créatures et comportements, en commençant par les points d'apparition, dont les
constantes sont déjà relevées.

- `CLAUDE.md` — l'amorçage : les commandes, les cinq invariants les plus chers,
  les trois règles de découpe
- `docs/ROADMAP.md` — les cinq jalons, leur avancement, les mesures, et en
  annexe le récit détaillé des sessions
- `docs/ASSETS.md` — l'échelle d'authoring et ce qu'il faut produire par biome
- `docs/systems/01_generation_terrain.md` — l'analyse du système de terrain
- `docs/systems/02_contenu_de_biome.md` — contenu de biome, dispersion, entités,
  table de sélection du décor
- `docs/systems/03_colonnes_et_edition.md` — colonnes, blocs, édition, sauvegarde
- `docs/systems/04_eclairage.md` — éclairage voxel : les deux passes
- `docs/systems/05_carte_du_monde.md` — carte, découverte, noms de région
- `docs/prompt_generation_flore.md` — la commande du lot de flore
- `docs/prompt_generation_arbres.md` — la commande du lot d'arbres
- `nextsteps.md` — reprise de session : ce qui reste à faire, les commandes, les
  cinquante et un invariants, les pièges connus

## Démarrer

```
godot --headless --path . -s tests/worldgen_test.gd   # 379 vérifications
```

Scène de démonstration : `scenes/terrain_demo.tscn`. Clic pour capturer la
souris, ZQSD/WASD, **clic gauche** creuser, **clic droit** poser, **F1**
détails, **Page haut/bas** distance de vue, **M** carte du monde, **1-6**
téléportation vers un biome, **Échap** rend la souris puis quitte. Les
modifications du terrain sont conservées dans `user://saves`, une base par
graine ; seuls les blocs édités y sont écrits, le reste du monde se régénère.
Les cases de carte parcourues y sont gardées de même.

![Greenlands : chênes, pins et sa frange d'herbe sèche](docs/images/biome_greenlands.png)

![Lava Lands : des coulées de magma dans la scorie](docs/images/biome_lavalands.png)

![La carte du monde en jeu](docs/images/carte_du_monde.png)

![La composition d'une prairie](docs/images/flore_composition.png)

## Périmètre et mention légale

**Cube World**, son code, ses assets, ses noms et ses marques appartiennent à
**Picroma et Wollay (Wolfram von Funck)**, ses créateurs. Ce dépôt n'est ni
affilié, ni approuvé, ni soutenu par eux.

Il s'agit d'un projet amateur non officiel, à but éducatif et de recherche
d'interopérabilité. Il ne contient **aucun binaire, asset ou fichier de données
du jeu d'origine** (`Cube.exe`, `data*.db`, `*.plx`, textures, sons, palette) —
uniquement du code écrit ici, à partir du comportement documenté des
algorithmes.

Ce qui relève de l'expression artistique plutôt que de l'algorithme — palettes
de couleurs, apparence des créatures, textes de quête, noms propres — est
remplacé par une création originale et signalé comme tel dans la note du
système concerné. La palette de ce projet (`assets/palette/`) est entièrement
originale.

Si vous détenez des droits sur Cube World et souhaitez qu'un élément soit
modifié ou retiré, ouvrez une issue.
