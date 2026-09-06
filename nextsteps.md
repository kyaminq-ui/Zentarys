# Zentarys — reprise de session

Fichier de reprise après un `/clear`. À lire en entier avant de toucher au code :
il contient des décisions qui coûtent cher à redécouvrir.

---

## 0. Demain, la première chose à faire

> **Six points relevés en jeu le 2026-09-08 au soir. Les six sont traités**
> — §7octies pour les cinq premiers, §7octies.6 pour le sixième —, et une
> seconde session de jeu, le 2026-09-09 au soir, en a ajouté trois autres qui
> sont traités aussi : la chaussée creusée jusqu'en son milieu, les ponts
> remplacés par des levées, et la forme des massifs refaite sans contrat
> d'escalade (**§7nonies**). L'ordre ci-dessous est celui de ce qui se voyait le
> plus, pas celui de la difficulté ; il est gardé tel quel comme trace.

**1. Une matière de surface déborde dans le biome voisin.** *De l'herbe se
retrouve dans le désert, et du sable de désert dans les Lava Lands.* C'est
l'écotone du 2026-09-07 (`CWBiome.at_dithered`) qui va trop loin : son amplitude
est en **unités de climat** — 0,07 en température, 0,09 en humidité — et la
distance géographique que cela représente dépend de la **pente du champ de
climat**, qui n'est pas la même partout. Là où le climat varie lentement, la
frange fait des centaines de blocs et l'herbe traverse tout le désert. Deux
pistes, à peser avant d'écrire :

* borner la frange **en blocs** et non en unités de climat — ce qui demande un
  gradient du champ de climat, donc des échantillons voisins ;
* ou refuser purement le tramage entre certains couples : *Lava Lands ne se
  mélange à rien*, c'est un cœur de région (jalon 1.12), et une frange de sable
  y contredit ce que le biome raconte.

`tools/biome_stats.gd` mesure la répartition des matières : c'est lui qui dira si
la correction a mangé la frange au lieu de la borner.

**2. Le pas maximum d'un massif doit varier d'un massif à l'autre.** Aujourd'hui
tous ont la même borne — deux blocs — parce qu'elle sort de trois constantes
partagées (`CWMesa.SHAPE_AMP_*`, `HEIGHT_PER_RADIUS_*`). Les tirer **par massif**
donnerait des masses lisses et des masses abruptes dans le même paysage. La
vérification d'escalade de `tests/relief_test.gd` doit alors mesurer contre la
borne **de ce massif-là** et non contre une constante : c'est elle qui garde le
contrat, et elle devient paramétrée.

**3. Les grottes : deux bouches en entonnoir, et un creusement plus libre.**
Aujourd'hui une galerie a une **entrée** évasée et un **fond** fermé. Il faut :

* une **sortie** aussi, évasée comme l'entrée — donc une galerie **traversante**,
  et les deux bouches choisies par la règle des huit directions qui garantit
  déjà qu'on débouche à l'air libre ;
* un creusement **plus aléatoire**, « un peu comme Minecraft » : section et
  hauteur qui varient le long de l'axe, embranchements courts, plafond qui monte
  et descend ;
* **sans cesser d'être praticable.** C'est la contrainte qui coûte : une section
  variable peut se pincer jusqu'à boucher la galerie. Il faudra un plancher de
  section, et une vérification qui parcoure l'axe et exige un passage libre
  d'un bout à l'autre — le pendant de la vérification d'accès actuelle, qui ne
  regarde que l'entrée.

**4. Un chemin doit contourner un massif, pas le percer tout droit.** *Creusé de
façon orbitale, avec un diamètre proportionnel à celui de la montagne, sans la
couper en deux.*

> ⚠️ **Deux lectures, et elles ne demandent pas le même travail. À trancher avec
> l'auteur de la demande avant d'écrire une ligne.**
>
> * **le tracé tourne autour du massif** : le chemin cesse de traverser et
>   décrit un arc dont le rayon suit celui de la masse — un chemin de corniche.
>   C'est du travail dans `CWPathNetwork._relaxe`, dont la fonction de coût
>   ignore aujourd'hui totalement cette couche (c'est déjà listé plus bas comme
>   ouvert) ;
> * **la section du tunnel devient circulaire** — un « diamètre » et non une
>   tranche rectangulaire — proportionnel à la masse traversée. C'est du travail
>   dans `CWVoxelGenerator.tunnel_height`, qui rend aujourd'hui une hauteur et
>   devrait rendre un profil.
>
> La formulation du 2026-09-07 — *« augmente le dégagement, proportionnel au
> surplomb, sans le couper en deux »* — penche pour la seconde ; le mot
> « orbitale » penche pour la première. Les deux se défendent, et faire la
> mauvaise coûte une journée.

**5. Le pont : un modèle simple, d'une seule teinte de bois, et posé sur ses deux
rives.** Deux choses distinctes :

* **il flotte d'un bloc.** La travée est instanciée à `tablier + 1` et le tablier
  de matière est à `deck_y` : aux culées, le terrain est plus bas que le tablier,
  donc l'ouvrage ne rejoint pas la rive. Il faut que le tablier **descende
  rejoindre le sol** aux deux extrémités du franchissement — c'est-à-dire que
  `_releve_ponts` et `road_shape` s'accordent sur une rampe, pas sur un palier ;
* **une seule couleur de bois.** `generer_ponts.py` emploie aujourd'hui neuf
  index de la rampe des planches plus un de pierre pour les chapeaux : le
  résultat est bruyant à six voxels par bloc. Un seul index, et la forme fait le
  reste.

**6. Tous les voxels d'un asset doivent porter sur le sol.** *(fait le
2026-09-09, §7octies.6.)* Un modèle est posé
sur la hauteur de **sa colonne d'ancrage**, mais son empreinte fait plusieurs
blocs de large : dès que le terrain descend sous un de ses bords, ce bord
flotte. Le remède demande de connaître le sol **sous toute l'empreinte** —
`CWScatter` ne lit qu'une colonne aujourd'hui —, puis de poser sur le **minimum**
de cette empreinte (l'objet s'enterre un peu plutôt que de flotter), ou d'écarter
le candidat quand l'écart dépasse un ou deux blocs. Attention au coût : une
empreinte de 5 × 5 blocs, c'est vingt-cinq colonnes là où on en paie une, et la
dispersion est déjà le second poste du chargement. La piste bon marché est de
sonder les **quatre coins** de l'empreinte et rien d'autre.

---

**Le jalon 1 a été clos le 2026-09-06 et rouvert le 2026-09-07** pour trois
systèmes demandés en regardant le jeu d'origine à côté du nôtre : les
**surplombs** et leurs **grottes**, la **falaise** qui revient — cette fois
tramée —, et le **réseau de chemins** avec ses **ponts**. Tout est en §7sexies.
Aucun des trois n'est dans la source, et les trois en-têtes le disent.

**Les six reproches de la seconde passe sont traités** (§7septies, 2026-09-08) :
plusieurs teintes par matière — c'est ce qui manquait au dégradé —, les
surplombs devenus des **massifs arrondis et escaladables**, des grottes plus
profondes et sinueuses à l'entrée visible, des chemins toujours creusés d'un
bloc et plus larges, un dégagement de tunnel proportionnel à la masse, et un
**lot d'ouvrages** qui redessine les ponts à six voxels par bloc.

> Deux de ces six ont été **défaits le lendemain soir**, et c'est écrit ici pour
> qu'on ne les redécouvre pas : les massifs escaladables sont devenus des masses
> délibérément infranchissables (§7nonies.3), et le lot d'ouvrages est retiré
> avec les ponts (§7nonies.2). *Une décision juste le jour où elle est prise
> peut être exactement ce qu'il faut retirer le lendemain.*

Ce qu'ils laissent ouvert, par ordre de ce qui se verra le plus vite :

- **le pied d'un massif rencontre l'herbe sans transition.** Moins qu'avant — le
  raccord est tangentiel — mais un éboulis lui donnerait son assise ;
- **le réseau de chemins ne connaît pas les massifs quand il se trace.** Le
  tunnel qui en sort est joli ; ce n'est pas une raison pour le laisser au
  hasard ;
- **massifs et chemins ignorent les biomes** : même roche d'affleurement et même
  gravier de chaussée partout. Une ligne dans `CWPalette` chacun ;
- ~~**un pont n'a pas de piles.**~~ Sans objet : il n'y a plus de pont
  (§7nonies.2).

Et les deux portes d'avant, inchangées :

1. **La collision, objet par objet** (§7bis.3) — c'est la fin du jalon 1 côté
   finition. Le tableau y est fait : cinq modèles entiers à passer en matière
   (le morceau facile, une ligne chacun), le branchage et les filons déjà réglés,
   et **un seul vrai arbitrage**, le feuillage — matière (×12 sur ce qu'un arbre
   écrit, soit ~+25 % de chargement) ou volume approché au jalon 3.1. Rien de
   tout cela ne se voit tant que `generate_collisions` est à faux sur le terrain
   de la démo.
2. **2.6, l'apparition** — l'autre porte, et elle mène au jalon 2. Elle n'attend
   rien : la fonction est lue, les constantes de pose extraites, la couche
   d'éléments existe depuis 1.6 et la carte sait les afficher.

> **Les deux « non-portes » de la veille ont été franchies le lendemain, et la
> leçon vaut d'être gardée.** Ce fichier disait : les chemins sont *hors
> périmètre* parce que la source n'en a pas, et la falaise attend *un terme de
> relief*. Le premier était une erreur de raisonnement — **une chose absente de
> la source n'est pas hors périmètre, elle est à décider** —, le second était
> juste, et c'est exactement ce qui a été fait : la couche de surplombs taille
> les parois, et la roche vient les habiller.

**Trois petites choses laissées ouvertes**, aucune bloquante :

- **la rive n'est humide qu'en Jungles**, faute d'un roseau par biome (§7quater,
  la réserve). C'est un besoin d'assets, pas de code — et c'est aussi le seul
  endroit du monde où le marais subsiste depuis §7quinquies ;
- **deux termes du champ de chenaux ne sont pas portés** : les bosses par type
  de cellule de région, qui *interdisent* l'eau près d'un bourg
  (`docs/systems/02` §10.2.1). Les porter déplacerait le lit des vallées
  existantes, donc c'est un travail à faire d'un bloc, avec une capture avant et
  après ;
- **les provinces climatiques ont trois constantes réglées à l'œil sur une seule
  graine** (§7quinquies.2) : fréquence, largeur du cœur, décalages de graine.
  `tools/biome_stats.gd` mesure ce qu'elles rendent — répartition et voisinage —,
  donc les bouger est cheap et vérifiable. Elles n'ont pas été balayées.

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
# Suite de validation (346 vérifications, ~20 s)
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
# tout déplacement de seuil dans `CWBiome` — voir §6. Son histogramme de pente,
# ajouté avec la falaise, est reparti avec elle ; les chiffres qu'il a produits
# sont gardés en §7ter.4, et le rétablir est de la mesure, pas de la conception.
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
#   options : --sans-arbres, --sans-flore, --sans-surplombs,
#   --sans-chemins,
#   --sans-falaise, pour isoler une couche. Les trois dernieres servent aussi a
#   mesurer ce qu'elle coute au chargement — voir Sec. 7sexies.8.
#   --vers x z oriente la camera vers un point, --altitude n la leve : sans les
#   deux, une capture d'un objet pose a cent blocs est une capture de ce qui se
#   trouvait dans l'autre sens.
#
# Mesure de la couche de surplombs et de la falaise : part des terres sous un
# chapeau, en porte-a-faux, en grotte, en roche de pente, plus l'histogramme des
# pentes (zones echantillonnees, pas de sondage, graine).
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path . -s tools/mesa_stats.gd

# Reperer un surplomb (deux points de vue : l'objet de loin, sa grotte de pres),
# un pays de canyons, ou un chemin (chaussee, levee, tranchee dans un surplomb).
# Les trois rendent des lignes pretes a coller derriere `--`, **sur la graine
# 2024** — celle de la demo, invariant n. 37.
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path . -s tools/find_mesa.gd -- 4
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path . -s tools/find_canyon.gd
C:/Users/Admin/Desktop/godot.windows.editor.double.x86_64.exe --headless --path . -s tools/find_path.gd

# Reperer une mare, pour viser une capture dessus. Rend des coordonnees pretes
# a passer a `--ici`, **sur la graine 2024** — celle de la demo, invariant n. 37.
./godot.windows.editor.double.x86_64.exe --headless --path . -s tools/find_pond.gd

# Se poser a un point **nomme** plutot qu'au premier endroit qui convient : les
# coordonnees sont celles de l'ATH, donc celles qu'on lit sur une capture
# precedente. C'est ce qu'il faut pour viser un objet local — un element de
# tuile, un bosquet — au lieu de relancer --biome jusqu'a tomber dessus. Ajoutee
# pour la falaise, elle lui a survecu.
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
# Carte ouverte au démarrage, pour une capture sans piloter la fenêtre :
# auto_open_map = true, auto_shot_delay = 30.
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

> **Trois couches se sont ajoutées le 2026-09-07** (§7sexies), et c'est le plus
> gros changement de paysage depuis les biomes : les **surplombs**, qui posent
> par-dessus le champ des mesas à dessus plat et à paroi verticale — jusqu'à
> 64 blocs de vide sous un chapeau, 2,0 % des terres ; leurs **grottes**, des
> tubes qui percent la paroi du socle et débouchent sous le surplomb, donc
> accessibles sans creuser **par construction** ; et le **réseau de chemins**,
> qui relie les jalons d'une zone, tranche la colonne, perce les surplombs et
> jette un tablier de bois sur les rivières. La **falaise** revient avec eux,
> tramée cette fois. `sample_column` n'a pas bougé — rien de tout cela n'est un
> terme du champ d'altitude.
>
> **Le jalon 1 avait été clos la veille.** Les lacs (§7quater) sont portés, et
> c'était le dernier système du monde au périmètre *de la source*. L'eau suit les fonds de vallée en rubans
> ramifiés **continus**, qui s'élargissent en descendant : **2,77 % des terres en
> eau, 0,58 % en rive**, profondeur 1 à 4 blocs, et rien dans les Deserts ni les
> Lava Lands. Sa porte était le champ de chenaux du jalon 1.4 — il ne manquait
> pas un champ, il manquait un seuil.
>
> **Cinq corrections vues en jeu ont suivi le portage** (§7quinquies), dont deux
> qui touchent au monde entier : le **marais** n'est plus une matière de biome
> mais la rive des cours d'eau, et le climat est passé en **provinces** — la
> source tire l'extrême d'une zone indépendamment de ses voisines, d'où une
> Snowlands contre un désert. Le relief, lui, n'a pas bougé d'un bloc.
>
> **La falaise, elle, a été portée puis retirée le même jour** (§7ter.4) : le
> portage était fidèle et les tests verts, mais peindre de la roche sur un flanc
> à vingt-sept degrés fait une tache, pas une paroi. **Une falaise ne se peint
> pas, elle se taille** — elle attend un terme de relief, pas une règle de
> surface. Les mesures sont gardées.
>
> **Restent la collision, objet par objet (§7bis.3), et 2.6, l'apparition.**
> Les deux portes sont décrites en §0, en tête de ce fichier.

Jalon 1 (le monde) : **1.1 à 1.16 sont portés, testés et vus en jeu** ; 1.13, la
falaise, a été portée, retirée (§7ter.4), puis **rétablie** avec 1.15. Suite de
validation : **377 vérifications, 0 échec**, ~30 s.

**1.11 — le tronc en matière, fait** (2026-09-06, §7). Un feuillu se pose en
deux temps : un tronc **écrit dans les données du monde** par
`CWVoxelGenerator._stamp_trunks` — donc il se creuse, il portera la collision et
l'éclairage voxel le voit — et un à trois houppiers instanciés au-dessus. C'est
le premier objet du projet à traverser la matière et l'instance, et les deux
moitiés sortent du **même tirage, dans la même liste** : `Placement.matiere`
marque la pièce que le générateur estampe et que le rendu ignore. Le type de
bloc est `CWPalette.WOOD`, l'index 4 recyclé le jour même ; la teinte reste
celle du modèle, ce qui donne quatre écorces pour un seul type. Coût mesuré :
**+2 % sur le chargement** (18,1 → 18,4 s à 384 blocs de vue).

Ce que la capture a attrapé au passage, et qui datait du jalon 1.7 : **le
terrain charge une boîte, la végétation garnissait un disque** — les quatre
coins portaient du terrain sans porter de cellules. Invisible tant que l'arbre
entier était instancié, un fût nu depuis que le tronc est de la matière.

**Trois remaniements de rendu, le 2026-09-06 au soir, tous décidés en regardant
le jeu** — le détail est en §6ter :

* **la flore est passée à 4 voxels par bloc**, puis ses **petits props —
  herbes et fleurs — à 6**. C'est le seul de ces points qui touche une valeur
  mesurée, et il s'en écarte délibérément : voir §8.1 ;
* **les bandes d'altitude sont retirées** : plus de roche nue ni de calotte de
  neige hors des biomes dont c'est la matière. Elles ne portaient aucun décor,
  donc chaque sommet rendait un plateau nu ;
* **le rôle `CAILLOU` est supprimé**, et les quatre blocs erratiques avec lui.
  Le minéral posé du monde est le seul `rocher_geant`, qui passe par la couche
  des arbres ;
* **un biome n'a plus qu'une matière de plaine.** `GRASS_DRY` et `TUNDRA` sont
  retirées : c'étaient les deux franges d'humidité héritées d'avant 1.12, et
  elles faisaient dire au sol le contraire de ce que disait le nom du biome.

**1.12 — les six biomes, fait** (2026-09-06). C'est le plus gros remaniement
depuis 1.7, et il tient en une phrase : **un biome est une zone climatique, une
matière de surface est ce dont le sol est fait, et ce n'étaient pas deux noms
pour la même chose.**

* `CWBiome.at` rend l'un des **six** biomes de l'alpha 2013 — Greenlands,
  Snowlands, Deserts, Jungles, Lava Lands, Oceans — à partir du climat et de
  l'altitude. `CWPalette.surface_of` en déduit la matière : les trois bandes
  d'altitude (plage, roche nue, neige de sommet) traversent presque tous les
  biomes, et c'est la matière de plaine qui change ;
* `CWDecorRules.decor_allowed` filtre ce qui est nu par nature — roche, magma,
  eau — avec un cas à deux sens : **la neige est le sol d'une Snowlands et une
  calotte de sommet partout ailleurs** ;
* `DENSITY`, `ROLES` et `SPECIES` sont indexés par biome ; les dossiers d'assets
  aussi (`greenlands/`, `snowlands/`, `deserts/`, `jungles/`, `lavalands/`,
  `oceans/`) ;
* **Lava Lands** apporte deux types de bloc, `MAGMA` et `SCORIA`, logés aux
  entrées 30 et 31 de la réserve terrain — les deux seules qu'aucun modèle
  n'employait, donc sans déplacer une frontière. Ses coulées sont une crête de
  bruit, la seule règle de surface qui ait besoin de la position ;
* `CWFloraDrops` porte la table des drops et les trois chaînes d'artisanat de
  l'alpha. **Rien ne la consomme** avant le jalon 3.2 ; elle est écrite
  maintenant parce que c'est maintenant qu'on connaît l'information.

**Et les deux lots d'assets sont refaits** — c'était la tâche que §6 posait en
premier, et elle tombait au bon moment : on ne regénère qu'une fois. **24
arbres** à 1 voxel = 1 bloc, **42 modèles de flore** à 3/40 — ce lot-là a été
refait depuis, à 4 voxels par bloc et à 38 modèles (§6ter) — mais deux fois et
demie plus grands et deux fois moins denses. Détail en §6.

**1.11 — arbres et grande végétation, aux trois quarts** (2026-09-05, lot refait
le 2026-09-06). Le **lot d'assets** : 24 arbres sous `assets/models/arbres/` et
9 filons sous `assets/models/filons/`, produits par script, déterministes. La
**couche de dispersion** : `CWTreeScatter`, cellule de 64 blocs, bibliothèque à
part, espacement minimum de **14** blocs qui tient au travers des frontières de
cellule. Les arbres **sont en jeu**, cinq biomes vérifiés en capture. Ce qui
reste : le tronc en matière (donc la collision), et la pose des filons, qui
appartient à la voie des entités du jalon 2.6.

**1.7 — contenu de biome, fait** (2026-09-05, au soir). La mécanique de
dispersion était en place depuis le 2026-09-04 ; ce qui manquait était le
*quoi*. **La table type de décor → modèle est trouvée**, et elle n'était dans
aucune fonction : elle est dans le **tableau des slots de chargement** de
`GameController`, qui range 2 449 modèles `.cub` à des indices qui ne suivent
pas l'ordre de chargement. La relation est `slot = 2418 + type`, tenue par cinq
recoupements pris dans trois fonctions — le roseau sur sol humide, les deux
nénuphars sur l'eau, les huit enseignes pour les huit genres de bâtiment, le
lierre et les rosiers de mur, l'art incan. La réserve est dite en clair dans
`docs/systems/02`, §8.5 : la même base ne tient pas sous le type 22.

Portée dans `CWDecorRules`. Trois choses en sont sorties : **il y a deux crêtes
de sélection à 0,01 et non une** (décalages `(9843, 8437)` et
`(34234, 234234)`, famille puis variante — leurs signes ne s'accordent que
50,8 % du temps, donc la seconde porte bien une information propre) ; **le
second seuil est biaisé** (`n2 <= 0,5`), ce qui garde le minoritaire à une fois
sur quatre ; **les échelles disent la taille du rôle**, 0,075 étant la référence
— soit exactement `3/40`, le rapport de ce projet. `CWScatter._choose` et sa
parité d'indice, qui étaient une invention de ce projet, sont retirés.
`CWModelLibrary` passe d'une table par biome à une table **par rôle**.

**1.8 — édition et persistance, fait.** Creuser, poser, interroger, et le seul
diff sur le disque.

**1.9 — éclairage voxel, fait** (2026-09-05). `CWLight` porte les deux passes, et
le rendu est passé en **`COLOR_RAW`** : un voxel porte son type dans
`CHANNEL_TYPE` et sa couleur dans `CHANNEL_COLOR`, comme dans l'original. Le
terrain généré n'appelle pas l'éclairage — un champ de hauteurs est éclairé
partout où on le voit — donc il ne sert que là où le joueur a creusé. Un coup de
pioche isolé coûte 30 ms. Le même jour, le **chargement a doublé de vitesse**
(vue de 384 blocs : 39 s → 16,4 s) : l'index de clés du flux SQLite, et le pool
ramené des quatorze fils logiques à la moitié — voir « la falaise des fils » dans
`docs/ROADMAP.md`.

**1.10 — carte du monde, fait** (2026-09-05). `CWWorldMap` et `CWRegionName` :
pièces de Voronoï dans le domaine déformé, une case par chunk de 256 unités,
trois clartés `200 / 220 / 255`, découverte persistée par graine, marqueurs pris
aux éléments de tuile, noms de région à deux syllabes. Touche **M** en jeu,
`tools/preview_map.gd` hors du jeu. Analyse : `docs/systems/05`.

Détail et sources analysées dans `docs/ROADMAP.md`. Analyses :
`docs/systems/01_generation_terrain.md` (terrain),
`docs/systems/02_contenu_de_biome.md` (contenu de biome, éléments de tuile,
apparitions), `docs/systems/03_colonnes_et_edition.md` (colonnes, blocs,
édition, persistance), `docs/systems/04_eclairage.md` (éclairage voxel),
`docs/systems/05_carte_du_monde.md` (carte, découverte, noms).

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
  cw_mesa.gd               un surplomb : chapeau, socle, grottes (1.15)
  cw_mesa_grid.gd          la grille de surplombs, et les pays de canyons (1.15)
  cw_path_network.gd       le réseau de chemins, ses portes et ses levées (1.16)
  cw_palette.gd            palette, matières de surface, coulées de lave (1.12)
  cw_voxel_generator.gd    VoxelGeneratorScript, cache de colonnes, troncs estampes
  cw_voxel_model.gd        modèle .vox préparé : deux grilles de dessin (1.12)
  cw_model_library.gd      chargement des modèles + tables par biome et par rôle
  cw_scatter.gd            grille de dispersion 16², cellules en cache
  cw_decor_rules.gd        rôles du décor : deux crêtes, rareté, taille, filtre
  cw_flora_drops.gd        ce que rend une plante, et les chaînes d'artisanat (1.12)
  cw_flora_renderer.gd     instanciation de la flore (MultiMesh par cellule)
  cw_tree_rules.gd         les espèces d'arbres et leurs trois montages (1.11)
  cw_tree_scatter.gd       la couche jumelle : cellule de 64, espacement de 14,
                           et le tronc en matiere (1.11)
  cw_world_edits.gd        creuser, poser, interroger un bloc (jalon 1.8)
  cw_light.gd              éclairage voxel : deux passes, cases à repeindre (1.9)
  cw_world_map.gd          carte : dalles de Voronoï, découverte, teintes (1.10)
  cw_region_name.gd        noms de région : deux tables de vingt syllabes (1.10)
src/demo/terrain_demo.gd   scène de démonstration, touches 1-6 par biome
src/demo/scale_board.gd    gabarit d'échelle : mires, silhouette, modèles
src/demo/model_portraits.gd  planche de validation : un modèle par capture (§6quater)
src/demo/map_overlay.gd    affichage de la carte (touche M)
tests/worldgen_test.gd     suite headless, 312 vérifications
tests/tile_features_test.gd  la moitié qui concerne les éléments de tuile
tests/decor_test.gd        rôles, tables croisées, filtre de matière, composition
tests/flora_test.gd        modèles, dispersion, maillage et pose
tests/tree_test.gd         lot, enveloppes, grille, dispersion, espacement, montage
tests/edit_test.gd         règles d'édition, requête ponctuelle, persistance (1.8)
tests/light_test.gd        les deux passes, l'atténuation, les cases à repeindre (1.9)
tests/map_test.gd          échelle, découverte, puzzle, rendu, noms (1.10)
tests/relief_test.gd       surplombs, grottes, chemins, levées, tramage (1.15-1.16)
tools/export_palette.gd    régénère assets/palette/* depuis CWPalette
tools/biome_stats.gd       répartition des biomes et des matières, mesurée (1.12)
tools/preview_features.gd  gros plan ombré, avec et sans la couche d'éléments
tools/inspect_model.gd     inventaire d'un .vox : gabarit, index, plages, morceaux
tools/repaint_models.gd    remet un .vox dans la palette de projet
tools/preview_map.gd       aperçu de la carte, vierge et après une diagonale
tools/mesa_stats.gd        surplombs, grottes, roche de pente, pentes (1.15)
tools/find_mesa.gd         un surplomb et sa grotte, en points de vue (1.15)
tools/find_canyon.gd       le pays de canyons le plus dense à portée (1.15)
tools/find_path.gd         une chaussée, une levée, une tranchée (1.16)
tools/blender/             générateurs des lots de modèles
  flore_vox.py               palette verbatim, écriture .vox, garde-fous
  flore_formes.py            brins, tiges, feuilles, corolles, cailloux
  flore_blender.py           courbes, métaballes, échantillonnage sur grille
  flore_blocs.py             formes de flore a la maille de 4 voxels par bloc
  generer_flore.py           le catalogue des 38 modèles de flore, à 4 vox/bloc
  arbres_formes.py           formes à la grille fine — plus employé par les arbres
  arbres_blocs.py            formes à la maille du bloc : disques, dômes, palmes
  generer_arbres.py          le catalogue des 24 arbres, à 1 voxel = 1 bloc
  generer_filons.py          les 9 filons, à 1 voxel = 1 bloc
docs/prompt_generation_flore.md   la commande du lot de flore
docs/prompt_generation_arbres.md  la commande du lot d'arbres
assets/palette/            palette de projet + PALETTE.md
assets/models/flore/<biome>/  38 modèles, un dossier par biome (six)
assets/models/arbres/<biome>/ 39 modèles d'arbres, à la maille du bloc
assets/models/filons/      9 filons, estampables (1 voxel = 1 bloc)
assets/models/             MODELS.md (échelle, palette et conventions)
docs/images/               gabarit, carte et composition de flore, en jeu
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
    à 4 voxels par bloc (§6ter.1, §8.1), et c'est le premier écart assumé entre
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
    rôle a fini supprimé (§6ter.2). L'espacement des arbres, lui, a été doublé
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

38. **Les trois couches du 2026-09-07 sont posées *au-dessus* du champ, jamais
    dedans.** Surplombs, grottes et chemins lisent l'altitude du terrain ; le
    terrain ne les lit pas. C'est ce qui les dispense de la garde de réentrance,
    des trois verrous et de l'attente entre fils que `CWTileFeatureGrid` doit
    porter — ses éléments, eux, déforment le champ dont ils lisent l'altitude.
    Le jour où un terme de `_height_from` consulterait un surplomb ou un chemin,
    tout cet appareil redeviendrait nécessaire, et rien ne le signalerait avant
    qu'un monde cesse de se régénérer à l'identique.
39. **L'ordre des recouvrements est un contrat entre deux fonctions écrites à
    l'envers l'une de l'autre.** `_generate_block` pose ses intervalles du plus
    profond au plus superficiel et les laisse s'écraser ; `voxel_of` les teste
    dans l'ordre **inverse** et sort au premier. L'ordre complet est désormais :
    *grotte et chemin creusent, le surplomb remplit, l'étang mouille, le terrain
    porte*, et le tablier d'un pont passe avant tout puisqu'il est bâti sur du
    vide. Une couche ajoutée d'un seul côté donne un monde dont les collisions
    et l'édition décrivent autre chose que ce qu'on voit — c'est l'invariant
    n° 18, et `tests/relief_test.gd` l'exerce maintenant **là où il y a quelque
    chose au-dessus du sol**, ce que le balayage du jalon 1.8 ne faisait pas.
40. **Les deux intervalles d'air ne se réunissent jamais en un seul.** La grotte
    et le dégagement d'un chemin sont deux intervalles distincts dans
    `ColumnPatch`, et c'est délibéré : les réunir en `[min, max]` creuserait tout
    ce qui les sépare, c'est-à-dire un puits de plusieurs dizaines de blocs le
    jour où un chemin passe au-dessus d'une grotte. Deux `_fill_run`, deux tests
    dans `voxel_of`, et rien à additionner.
41. **Une déformation de bord se règle en nombre de lobes par tour, pas en
    amplitude.** Ce nombre vaut `2π × rayon × fréquence`. Le premier réglage des
    surplombs, 0,01 sur un rayon de 76, donnait **un lobe et demi sur tout le
    contour** : la déformation déplaçait le disque au lieu de le découper, et la
    capture montrait une soucoupe volante. La fréquence se calcule contre le
    rayon de l'objet déformé, jamais contre l'échelle du monde. Corollaire : un
    objet et son sous-objet — ici le chapeau et son socle — ont besoin de
    **deux déformations différentes**, sinon leurs silhouettes se superposent et
    l'ensemble se lit comme tourné au tour.
42. **Le dessus *praticable* d'une colonne a un point unique, et quatre
    consommateurs.** `CWVoxelGenerator.standing_top` dit où est le sol quand un
    surplomb couvre la colonne, `CWPathNetwork.shaped_top` dit où il est quand un
    chemin la traverse. Le générateur, la requête ponctuelle, `CWScatter` et
    `CWTreeScatter` doivent tous les quatre passer par là. C'est exactement le
    piège du creusement des étangs au jalon 1.14, repris deux fois : une plante
    posée à la hauteur brute du champ **flotte ou s'enterre**, et le défaut ne
    se voit que sur une capture.
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
46. **Un massif doit s'escalader, et ça se mesure.** Le contrat est : jamais plus
    de **deux blocs** de marche d'une colonne à la suivante, en tout point d'un
    massif et sur tous ses rayons. Deux, et pas un, parce que le dessus vaut
    `plancher(sol) + plancher(hauteur × f²)` et que chacun des deux termes a le
    droit de changer d'une unité. Trois choses tiennent cette borne, et en
    retirer une la fait sauter : la hauteur se mesure **depuis le sol de la
    colonne** et non du centre du massif ; le profil est **au carré**, ce qui
    annule la pente sur le contour ; et les fréquences des deux bruits de forme
    sont **relatives au rayon**. `tests/relief_test.gd` balaie vingt-quatre
    rayons et relève la plus grande marche — c'est une mesure, pas un calcul.
47. **Une déformation se règle en nombre de lobes par tour, jamais en fréquence
    absolue.** Ce nombre vaut `2π × rayon × fréquence`. À fréquence fixe, une
    grosse masse prend dix lobes et une petite un demi — deux formes qui n'ont
    rien à voir —, et la pente de la grosse croît avec sa hauteur jusqu'à
    dépasser le bloc par bloc. C'est vrai de la couche de massifs, et ce sera
    vrai de tout ce qui déforme un objet de taille variable.
48. **La galerie d'une grotte part du *seuil* du massif, pas de sa première
    colonne épaisse.** Sinon le tube est emmuré derrière quelques blocs de flanc
    et la grotte n'est accessible qu'à la pioche. Et le seuil ne suffit pas :
    un massif posé au pied d'un versant a des côtés où le terrain **remonte**
    dès qu'on le quitte, donc la direction se **choisit** parmi huit plutôt que
    de s'espérer. Les deux défauts ont été attrapés par la même vérification, qui
    s'éloigne de l'entrée à la hauteur du plancher et exige de l'air tout du
    long — et qui, elle, regarde le **monde généré** et non la règle qui l'a
    posé.
49. **Un relevé grossier d'une chose fine ne s'affine pas partout.** Le profil
    d'un chemin pose un jalon tous les 32 blocs ; une rivière en fait six de
    large, donc elle passe entre deux jalons neuf fois sur dix, et le premier
    relevé des ponts n'en a trouvé aucun de ceux qu'on voyait en jeu. Le remède
    n'est pas de descendre le profil à 4 blocs — ce serait huit fois le coût
    d'un réseau — mais de **raffiner là où la chose peut être** : le champ de
    chenaux est lisse, un jalon à trente blocs d'une rivière a déjà une valeur
    basse, et moins d'un segment sur dix est sondé de près.
50. **Une travée de pont a sa longueur sur X, et son instance porte une échelle.**
    `Basis(UP, yaw)` envoie X local sur `(cos, 0, −sin)`, donc l'angle qui aligne
    la travée sur le tracé est `atan2(−dz, dx)` — avec `atan2(dx, dz)` elle est
    en travers du pont. Et sans le facteur `1 / voxels_par_bloc`, le modèle sort
    **six fois trop grand** : sur un pont de neuf blocs de large, une plate-forme
    de cinquante. Les deux fautes se voient d'un coup d'œil, aucune ne lève quoi
    que ce soit.

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
- **Coût actuel : ~62 µs par colonne hors influence d'un élément, ~75 µs
  dedans**, soit ~16 à 19 ms par bloc 16³ à froid. C'est le plafond de tout.
  Stabilisation mesurée avant la couche d'éléments : 27 s à 384 blocs de vue,
  120 s à 768 ; la couche n'ajoute rien mesurable sur le chemin de streaming,
  qui passe par `sample_patch` et sort la consultation de la grille de la boucle
  de colonnes.
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
  (§6quater), et invisible dans les nombres — la boîte englobante, le compte de
  voxels et les plages de palette étaient tous justes.
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

| objet | aujourd'hui | voxels | ce qu'il faut |
|---|---|---|---|
| tronc d'un feuillu, d'un palmier, d'un grand arbre | **matière** | 406 (charpente) | rien — c'est fait (§7) |
| **branchage d'un grand arbre** | **matière** | compris dans les 406 | rien : les branches sont **dans le modèle de tronc**, donc estampées avec lui |
| houppier, dôme | instancié | 983 le dôme, ×5 par grand arbre ; 2 316 le houppier de chêne | à décider — voir plus bas |
| arbre entier (`pin`, `sapin_enneige`, `pin_enneige`) | instancié | 692 – 809 | **à passer en matière** |
| `arbre_epineux` | instancié | 186 | **à passer en matière** |
| `rocher_geant` | instancié | 1 907 | **à passer en matière** — c'est un rocher, il est déjà de la roche |
| les neuf filons | pas encore posés | 13 – 32 | rien de plus : ils sont dessinés à **1 voxel = 1 bloc** pour être estampés, et se minent. Il ne leur manque que leur *pose* (2.6) |
| cactus de flore (`cactus_01`, `cactus_02`) | instancié | 181 et 176 | ils sont à **4 voxels par bloc** : inestampables tels quels. Volume approché, ou rien |

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

## 8. Assets voxels

### 8.1 L'échelle — fixée le 2026-09-04, alignée sur l'original le 2026-09-05

**Il y a quatre grilles depuis le 2026-09-06, et les quatre servent à
dessiner.**

* **la grille fine, 40/3 voxels par bloc** — trois blocs valent exactement
  40 voxels, et le personnage de référence mesure 32 voxels, soit 2,4 blocs.
  Elle porte le personnage, les créatures, le mobilier, les objets. C'est **la
  valeur mesurée** : les échelles d'instanciation du décor de l'original sont
  0,075 / 0,09 / 0,1, et 0,075 = 3/40 exactement ;
* **les petits props de flore, 6 voxels par bloc** — herbes et fleurs. La liste
  est `CWModelLibrary.GRILLE_FINE`, et elle doit dire la même chose que la
  colonne `FIN` du catalogue de `generer_flore.py` ;
* **le reste de la flore, 4 voxels par bloc** — buissons, cactus, champignons,
  fougères, coraux : ce qui a du volume ;
* **la grille du terrain, 1 voxel = 1 bloc.** Elle porte **les arbres et les
  filons**. C'est un champ de `CWVoxelModel` (`voxels_per_block`) et non une
  constante — voir l'invariant n° 28.

**Pourquoi la flore en a deux et pas une.** Quatre voxels par bloc va bien à ce
qui est une *masse* : un buisson, un cactus, un champignon se lisent à n'importe
quelle résolution parce que leur forme est leur volume. Ce qui s'y perd, ce sont
les objets **dont toute la forme tient dans un trait** — une touffe d'herbe est
cinq lignes, une fleur est une tige et une corolle. À quatre voxels par bloc,
une corolle est une croix de cinq voxels et une touffe un paquet de bâtonnets :
le grain est juste, la silhouette ne l'est plus. Six voxels par bloc rend à ces
objets de quoi dire leur forme — une touffe passe de sept à onze voxels de haut
— **sans revenir au cheveu**, un brin faisant un sixième de bloc et non un
treizième.

**Pourquoi la flore a quitté la valeur mesurée, et il faut le dire dans ce
sens-là.** 3/40 n'est pas contesté : c'est bien l'échelle du décor de
l'original, et elle implique qu'une touffe d'herbe y est dessinée treize fois
plus fin qu'un bloc de terrain. Ce projet l'a portée fidèlement jusqu'au lot du
2026-09-06. C'est **le rendu qui l'a refusée** : vu en jeu, un brin de
0,08 bloc à côté d'un cube de terrain d'un bloc ne lit pas comme un cube, il lit
comme un cheveu, et une prairie entière comme une fourrure. Le lot d'arbres
avait montré l'autre moitié de l'argument trois jours plus tôt — ce qui lit
juste, c'est ce qui partage le grain du terrain.

Quatre voxels par bloc est le compromis : assez gros pour que le grain se voie,
assez fin pour qu'une fleur reste une fleur à deux ou trois voxels. **La taille
des plantes en blocs n'a pas bougé** — une touffe fait toujours 1,75 bloc, avec
sept voxels au lieu de vingt-trois. C'est une résolution de dessin qu'on change,
pas une enveloppe, et c'est pour ça que le plafond de `tests/flora_test.gd`, qui
est dit **en blocs**, a survécu au changement sans qu'on y touche.

Cette entrée relève donc de l'expression et non de l'algorithme, au sens de la
note de périmètre du `README` — elle est signalée comme telle dans
`CWVoxelModel.VOXELS_PER_BLOCK_FLORE`, qui porte la note complète.

Le détail par catégorie d'objet est dans `assets/models/MODELS.md`, le fichier à
donner à qui modélise.

**D'où sort le nombre.** D'une mesure au pixel sur une capture du jeu d'origine,
pas d'un jugement à l'œil : brin d'herbe 7 px de large, pupille du personnage
6 px, écart entre les yeux 28 px, hauteur du personnage 205 px, face verticale
d'une marche de terrain 90 px. Le brin d'herbe et la pupille font la même
largeur — **la flore et le personnage sont sur la même grille fine**. Rapport
mesuré : ~13 voxels par bloc. On avait d'abord retenu 16, la puissance de deux la
plus proche ; le 2026-09-05 le binaire a rendu la valeur exacte — ses échelles
d'instanciation du décor sont 0,075, 0,09 et 0,1, et **0,075 = 3/40** — et le
projet a suivi. Ce qu'on perd : les réductions de LOD ne tombent plus sur une
puissance de deux. Ce qu'on gagne : un modèle de 32 voxels fait 2,4 blocs, ce qui
recoupe les 2,3 blocs mesurés sur la capture. Détail dans
`docs/systems/02_contenu_de_biome.md`, §8.3.

**À revoir au jalon 3.1**, quand le contrôleur donnera la taille réelle du
personnage. Si elle s'écarte de 2 blocs, c'est ce seul nombre qui change. Le
rapport de 40/3, lui, est un contrat d'authoring : le changer redimensionne tous
les modèles déjà dessinés, et il est verrouillé par un test.

**Ce que ça a changé dans le code** (2026-09-04) :

- la flore n'est **plus estampée** dans les données voxels du monde — elle y
  serait treize fois trop grosse. `CWVoxelGenerator` ne la consulte plus du tout,
  et le surcoût de +14 % par bloc a disparu du chemin de génération ;
- `CWVoxelModel.mesh()` maille le modèle une fois, avec **le même mailleur, la
  même palette et le même matériau que le terrain** — c'est la condition pour
  que les deux grilles lisent comme un seul monde ;
- `CWFloraRenderer` instancie : un `MultiMeshInstance3D` par modèle et par
  cellule de dispersion, construit par lots sur un fil du pool, détruit au-delà
  de `view_distance` (128 blocs par défaut) ;
- les plantes se posent **sous le bloc** (`Placement.fx`, `fz`, au pas d'un
  voxel) : sans ça toute la flore s'alignerait sur la grille du terrain ;
- les densités de `CWModelLibrary` sont doublées — à nombre égal, des plantes
  huit fois plus courtes laissent le sol nu.

Conséquences à connaître : la flore ne se creuse pas, ne porte pas de collision,
et ne participera pas à l'éclairage voxel du jalon 1.9.

**Pour revoir l'échelle soi-même** : mettre `scale_board = true` sur le nœud
racine de `scenes/terrain_demo.tscn` et lancer la démo. Le gabarit pose des mires
de 1 à 16 blocs, la silhouette du personnage à la grille fine, puis chaque modèle
chargé ; deux captures partent dans `user://shots`. Un `.vox` déposé dans
`assets/models/flore/` y apparaît sans qu'il y ait rien à déclarer.

Pour regarder autre chose que le gabarit sans piloter la fenêtre :
`auto_shot_delay` sur le même nœud, puis `--quit-after`.

### 8.2 Ce qu'il faut produire, par biome

**Rien pour le jalon 1.6** : il ne fait que déformer l'altitude, rendue avec la
palette existante. Le jalon 1.7 (dispersion sur le terrain) est le premier qui
demande des modèles — et la mécanique qui les pose est en place : déposer un
`.vox` dans `assets/models/flore/` suffit à le voir dans le monde, dès lors que
son nom figure dans la table de `CWModelLibrary`.

La liste des *rôles* n'est plus une estimation : le binaire d'origine charge
**2 550 modèles voxels nommés** (`.cub`) — le chiffre de 154 retenu jusqu'au
2026-09-05 était une énumération partielle. On n'en reprend aucun — ce sont des
créations originales — mais ce dont un monde comme celui-là a besoin est établi.

**Les rôles produits sont tous confirmés** par ce relevé, nom pour nom :
`cornflower` = bleuet, `sunflower` = tournesol, `heartflower` = fleur_coeur,
`soulflower` = fleur_ame, `ginseng-root` = ginseng, `reed` = roseau,
`ivy` = lierre, `tendril` = vrille, `alga` = algue, `coral` = corail. Le lot du
jalon 1.12 en ajoute une dizaine pris à la même liste et jusque-là non produits :
`snow-berry`, `snow-bush`, `heartflower-frozen` (notre `fleur_de_glace`),
`shimmer-mushroom`, `lava-grass`, `lava-flower`, plus le coton et le habanero du
désert. Restent non produits : `berry-bush`, `thorn-plant`, `desert-flower01/02`,
`water-lily01/02`, `underwater-plant`, `plant-fiber`, `runestone`, `stone2`,
`sandstone`.

**Les arbres sont des assets — correction du 2026-09-05.** Le corpus charge
`fir-tree.cub`, `thorn-tree.cub`, `christmas-tree.cub`, `tree-leaves.cub`,
`palm-leaf.cub`, `palm-leaf-diagonal.cub`, `wood-log.cub`. Il n'y a **pas**
d'algorithme d'arbre à porter : `World_generateTreeRecursive` est nommée d'après
les arbres rouge-noir de la STL. **Tranché** : le feuillu est une composition
tronc + houppiers instanciés — `tree-leaves` porte son propre code d'entité,
loin des deux arbres, et le corpus n'a aucun modèle de tronc.

**Les maisons, elles, ne sont pas des assets.** `cube::House::ctor_0(3, 3, 4)` :
une grille de 3 × 3 × 4 cellules remplie procéduralement (jalon 4.3). Ce sont les
*meubles* qui sont des modèles, pas le bâtiment.

**Rôles relevés que le projet n'a pas produits** (`docs/systems/02`, §7) :
`berry-bush`, `snow-berry`, `snow-bush`, `thorn-plant`, `shimmer-mushroom`,
`desert-flower01/02`, `flowers`, `flowers2`, `heartflower-frozen`,
`water-lily01/02`, `underwater-plant`, `plant-fiber`, `lava-grass`,
`lava-flower`, `runestone`, `stone2`, `sandstone` — plus une catégorie
entièrement absente et pourtant jouable, les **filons** (`gold-`, `iron-`,
`silver-`, `sandstone-`, `emerald-`, `diamond-`, `ruby-`, `sapphire-`,
`ice-crystal-deposit`). Les variantes `lava-*` supposent une surface volcanique
que `CWPalette.surface_index` ne produit pas.

#### Convention de nommage

**Un dossier par biome** sous `assets/models/flore/`, un fichier `.vox` par
entrée. Noms en minuscules sans accent, souligné pour séparer, variante numérotée
sur deux chiffres quand les modèles sont interchangeables ; rien d'autre dans le
nom — ni le biome, qui est le dossier, ni la taille du gabarit, qui est libre.
Les couleurs viennent de la plage **Végétation, indices 128 – 175** de la palette
de projet — sauf ce qui est minéral, qui prend la plage **Terrain, 1 – 31**.
Charger la palette en **ouvrant `assets/palette/zentarys_palette.vox`** ; le
détail et le piège sont dans `assets/palette/PALETTE.md`.

#### Les six biomes, et ce que chacun porte

Ce sont les biomes de l'alpha 2013, décidés par `CWBiome.at`. Touches **1** à
**6** de la démo pour s'y téléporter, `-- --biome 0..5` pour une capture.

| biome | flore | arbres |
|---|---|---|
| **greenlands** | `herbe_01` `herbe_02` `herbe_03` `herbe_seche` `fleur_bleuet` `fleur_tournesol` `fleur_coeur` `ginseng` `buisson` `scrub` `broussaille` `fougere` | `chene_tronc` + 2 houppiers, `bouleau_tronc` + houppier, `pin`, `rocher_geant`, `arbre_geant_tronc` + houppier |
| **snowlands** | `herbe_gelee` `fleur_de_glace` `buisson_neige` `snowberry` `cotonnier` | `pin_enneige`, `sapin_enneige`, `bouleau_givre_tronc` + houppier — **pas de grand arbre**, §7ter.2 |
| **deserts** | `cactus_01` `cactus_02` `broussaille_seche` `cotonnier` `habanero` | `palmier_tronc` + `palme` + `palme_diagonale` — **plus de `cactus_geant`**, §7ter.3 |
| **jungles** | `feuille_large` `fougere_geante` `liane` `vrille` `lierre` `fleur_coeur` `fleur_ame` `roseau` `champignon` | `tropical_tronc` + 2 houppiers, `palmier_tronc` + 2 palmes |
| **lavalands** | `fire_shrub` `herbe_de_lave` `fleur_de_lave` `champignon_luisant` | `arbre_epineux` |
| **oceans** | `algue` `corail` `etoile_de_mer` | — |

**38 modèles de flore, 24 d'arbres, 9 filons.** Oceans n'a pas d'arbre : une île
émergée n'est pas Oceans, c'est son climat qui la nomme, et elle porte les
arbres qui vont avec.

**Aucun fichier n'est partagé entre deux biomes**, et un test refuse qu'un
chemin traverse. Rien ne l'interdit techniquement — le cache est indexé par
chemin — mais un modèle partagé porte les teintes d'un seul biome. Le
champignon luisant est dessiné deux fois pour cette raison.

Quelques matières de surface ont leur propre composition, indépendamment du
biome : le **sol humide** (roseau, dans Jungles) et l'**herbe sèche** (dans
Greenlands). Ce sont les deux seules, elles vivent dans
`CWDecorRules.FAMILIES_SURFACE`, et chacune déclare le biome qui la produit —
voir l'invariant n° 27.

#### Plus cinq cultures, pour les champs des villages

`ble` `mais` `carotte` `coton` `citrouille` — mêmes conventions, dossier
`assets/models/culture/`. Elles ne sont pas dispersées par biome mais posées en
rangées par le système de champs (`Field.cpp`, jalon 4.3). À faire après les 28.

#### Une réserve d'honnêteté sur l'affectation

Quels modèles vont dans quel biome **n'est pas lu dans le binaire** : la table de
correspondance est dans `WorldInfo_generateBiomeContent` (@005e4850), 3 100
lignes, pas encore analysée. La répartition ci-dessus vient de la **liste de
contenu par biome de l'alpha 2013**, relevée à part, et du bon sens pour le
reste. Les *noms de biomes* et les *rôles* sont sûrs ; l'affectation d'un modèle
donné peut bouger, et coûte une ligne de code.

Ça ne change rien à ce qu'il faut produire — la *liste* des 28 est sûre, elle
vient des noms de modèles du binaire. Seule l'affectation peut bouger, et
réaffecter un modèle existant coûte une ligne de code.

#### Ce que les lots mesurent réellement

Relevé par `tools/inspect_model.gd` sur les lots du 2026-09-06. L'outil connaît
les **deux grilles** depuis ce jalon : il annonçait le pin à 1,65 bloc de haut là
où il en fait 22, et c'est justement l'outil qu'on consulte pour vérifier une
échelle.

**La flore**, en voxels de modèle (40/3 = un bloc), et en hauteurs de personnage
(2,4 blocs) :

| rôle | hauteur | × personnage |
|---|---|---|
| `etoile_de_mer` | 6 | 0,22 |
| `fleur_bleuet` | 10 | 0,38 |
| `champignon_luisant`, `champignon` | 13 – 15 | 0,49 – 0,56 |
| `snowberry`, `habanero` | 15 | 0,56 |
| `scrub`, `broussaille`, `ginseng`, `feuille_large` | 16 – 17 | 0,60 – 0,64 |
| `buisson`, `fleur_coeur`, `fire_shrub`, `herbe_gelee` | 20 – 21 | 0,75 – 0,79 |
| `cotonnier`, `corail`, `lierre`, `herbe_01` | 23 | 0,86 – 0,90 |
| `herbe_seche`, `herbe_02`, `fleur_tournesol`, `cactus_02` | 26 – 27 | 0,97 – 1,01 |
| `algue`, `caillou_basalte`, `caillou_01` | 28 – 31 | 1,05 – 1,16 |
| `roseau`, `vrille`, `liane`, `gres` | 31 – 35 | 1,16 – 1,31 |
| `fougere_geante` | 40 | 1,50 |
| `fougere`, `cactus_01` | 43 | **1,61** |

Tout tient largement dans l'enveloppe dure vérifiée par le test (53 de haut,
26 de rayon), et le rayon maximum du lot est de **2 blocs** — c'est lui qui
dimensionne la marge de `placements_in` pour toute la flore.

**Les arbres**, en blocs, un voxel valant un bloc :

| modèle | largeur × hauteur | × personnage |
|---|---|---|
| `palme`, `palme_diagonale` | 13 – 19 × 3 – 4 | 1,25 – 1,67 |
| `chene_tronc`, `bouleau_givre_tronc` | 3 – 4 × 12 | 5,0 |
| `arbre_epineux`, `tropical_tronc` | 6 × 13 | 5,4 |
| `bouleau_tronc`, `palmier_tronc` | 3 – 4 × 14 – 15 | 5,8 – 6,3 |
| `rocher_geant` | 12 × 12 | 5,0 |
| `sapin_enneige` | 9 × 19 | 7,9 |
| `pin`, `pin_enneige`, `arbre_geant_tronc` | 9 – 11 × 22 | **9,2** |
| houppiers | **11 – 22 de large × 5 – 8 de haut** | — |

**Les houppiers sont tous plus larges que hauts**, d'un facteur 2 à 3, et un
test le vérifie. C'est la forme qu'ils ont sur les captures du jeu d'origine, et
c'est ce qui fait une canopée plutôt qu'une brochette de boules.

#### Les lots suivants, pour information

- ~~**Jalon 1.11, arbres et grande végétation (14)**~~ **livré le 2026-09-05,
  puis entièrement refait le 2026-09-06** : 24 modèles à **1 voxel = 1 bloc**,
  sous `assets/models/arbres/`. Deux choses le distinguent du lot de flore, et
  elles se retrouvent dans le code : la **grille**, imposée par la bibliothèque
  au chargement (invariant n° 28), et le fait qu'un **houppier n'a pas de
  tronc** — il se pose au sommet d'un fût, ce qui en fait le premier objet du
  projet à traverser les deux mondes.
- ~~**Jalon 1.11, les neuf filons** : bloqués sur une décision de palette.~~
  **Tranché et dessiné le 2026-09-05** : `RANGE_TERRAIN_END` est passé de 31 à
  40 et rien d'autre n'a bougé. Ce qui reste est leur **pose**, qui appartient à
  la voie des entités du jalon 2.6.
- **Jalon 4, décor bâti (~50)** : mobilier (table, tabouret, banc, lit, table de
  chevet, buffet, 3 étagères, comptoir, 3 tapis, 2 tableaux, 4 vases, lustre,
  3 bougies), artisanat (enclume, four, établi, scie, métier à tisser, rouet,
  fourche), extérieur (4 clôtures, portail, porte, fenêtre, torche, lanterne,
  feu de camp, tente, abri, épouvantail, tonneau, caisse, sac, obélisque, pierre
  runique), donjon (toiles d'araignée, crâne, dépouille).
- **Jalon 3.2, objets d'inventaire (~40)** : nourriture, armes, équipement.
- **Jalon 2, créatures et poissons.** L'apparence des créatures est
  explicitement hors périmètre : c'est le gréement et l'animation procédurale
  qui sont portés, pas les modèles.

### 8.3 Décision d'authoring — prise, et confirmée

**MagicaVoxel, pas d'éditeur maison.** `VoxelVoxLoader` est intégré au build : un
`.vox` se charge en un appel, avec sa palette, directement dans le modèle de
rendu déjà utilisé. Un éditeur maison représenterait des semaines pour zéro
gameplay, et c'est l'auteur des assets qui en subirait chaque manque.

**La seule objection sérieuse est levée.** On ne peut pas réduire le pinceau de
MagicaVoxel sous un voxel — et il n'y en a pas besoin : sa grille est *sans
unité*. On ne descend pas sous le voxel, on agrandit la boîte, et c'est le moteur
qui applique le 3/40 à l'import. Un personnage détaillé se dessine dans un
gabarit de 32 de haut, une touffe d'herbe dans 12.

Pour garder l'œil juste en modélisant, poser dans la scène MagicaVoxel un cube de
**40³** (= trois blocs de terrain ; un bloc seul ne tombe pas sur un nombre
entier de voxels) et une silhouette de 32 de haut (= le personnage). C'est ça qui
remplace le réglage de taille du pinceau.

**La flore, elle, est générée.** Depuis le 2026-09-05 les 39 `.vox` de flore
sortent de `tools/blender/generer_flore.py` — Python pour les brins, les fleurs
et les cailloux, `bpy` pour ce qui y gagne (buissons, cactus, coraux, lianes),
une graine en dur par fichier. Ça ne remet pas en cause la décision ci-dessus :
MagicaVoxel reste l'outil pour tout ce qui se dessine — personnages, mobilier,
objets — et le générateur sert ce qui se répète et se mesure. Ce qu'il apporte
et qu'une main n'apporte pas : le lot se regénère à l'identique après un
changement d'échelle ou de palette, ce qui vient de servir deux fois en deux
jours.

**L'établi de personnalisation façon Cube World reste au programme** — il est
d'ailleurs dans la liste du mobilier du jalon 4. Mais c'est une *fonctionnalité
de jeu*, pas un outil d'authoring : grille fixe et petite, palette contrainte par
le matériau, sortie = un objet d'inventaire et ses statistiques. Il se pose sur
l'inventaire (3.2), qui se pose sur le contrôleur (3.1). Il réutilisera
`CWVoxelModel` et son maillage tels quels — le travail est déjà fait.

La palette de projet est en place : **ouvrir `assets/palette/zentarys_palette.vox`
dans MagicaVoxel** — pas glisser un PNG sur le nuancier, c'est ce qui a faussé
les index du premier lot. Plages réservées documentées dans
`assets/palette/PALETTE.md`, source unique dans `CWPalette`, sept vérifications
qui empêchent une plage de bouger ou de se vider en silence.

Trois faits mesurés sur l'import et le maillage, à ne pas redécouvrir :
- les index de palette se conservent exactement (le décalage d'un cran du format
  est absorbé par le chargeur) ;
- les axes sont permutés : `vox(x, y, z) -> godot(y, z, x)`. Le haut reste le
  haut, le plan horizontal est échangé ;
- **le mailleur consomme sa marge** : l'origine du maillage tombe sur le premier
  voxel utile, pas sur le coin du tampon. Sans retrancher
  `CWVoxelModel.mesher_padding()`, tout ce qui est instancié est enterré d'un
  voxel — assez peu pour rester plausible à l'œil, ce qui est exactement la
  raison pour laquelle un test le mesure.

Gabarits mesurés en sortie du générateur d'éléments de tuile, utiles pour situer
les échelles — le rayon est un rayon d'*influence*, pas l'encombrement du modèle :

| type | par zone | rayon | position |
|---|---|---|---|
| 14 | ~16 | 150 u | calée sur la grille de 256 |
| 11, 12 | ~2 chacun | 128 u | calée sur la grille de 256 |
| 10 (donjon) | ≤ 5 | 512–767 u | libre dans la tuile |
| 2, 3 | ~2 chacun | 512–767 u | libre dans la tuile |
| 5 | ~2 | 256–511 u | libre dans la tuile |

Outillage Godot à écrire plus tard, et seulement là où MagicaVoxel ne peut pas
aider : placement et prévisualisation **en contexte** (une structure posée sur le
terrain réellement généré), au jalon 4. Pas un éditeur généraliste.

## 9. Décisions ouvertes

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
  c'est écrit dans l'en-tête du fichier, et §6.3 dit pourquoi.
- **La bande d'herbe sèche de Greenlands est large.** `DRY_GRASS_H` est à 0,46,
  ce qui donne 5,1 % du monde ; l'alpha place Greenlands entre 30 et 70 %
  d'humidité, ce qui la mettrait plus bas. La raison est mesurée : le champ
  d'humidité n'a presque rien entre 0,10 et 0,40, donc le seuil ne peut pas se
  poser au milieu — il attrape ou non l'amas 0,40-0,45 tout entier. À 0,42 la
  steppe disparaîtrait du monde.
- **Oceans n'a été vu que d'au-dessus.** Voir §6.5.
