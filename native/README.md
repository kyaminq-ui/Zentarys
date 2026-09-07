# La GDExtension de Zentarys

Une seule chose est portée en C++ : **le bruit de valeur**. C'est la cible que
la mesure désigne, et elle est unique — `CWValueNoise.sample` coûtait 3,31 µs
l'échantillon, une quinzaine par colonne, soit **la moitié du temps de
génération** du monde.

Rien d'autre n'a de raison d'y passer. Porter la dispersion, la palette ou la
carte n'achèterait rien, et chaque classe portée est une frontière de plus à
tenir d'accord avec sa moitié GDScript.

## Construire

Il faut MSVC (ou GCC/Clang), Python, et SCons (`pip install scons`).

```bash
# 1. godot-cpp, à côté de ce fichier. Il n'est pas dans le dépôt : c'est une
#    dépendance, pas du code de ce projet.
git clone --depth 1 https://github.com/godotengine/godot-cpp.git native/godot-cpp

# 2. Le vidage d'API du moteur **de ce dépôt**. Voir plus bas pourquoi il ne
#    suffit pas de prendre celui qu'embarque godot-cpp.
./godot.windows.editor.double.x86_64.exe --headless \
    --dump-extension-api --dump-gdextension-interface --path native/api

# 3. La bibliothèque.
native/build.bat template_release
#   ou, hors Windows :
#   cd native && scons target=template_release precision=double \
#       custom_api_file=api/extension_api.json
```

Le résultat va dans `native/bin/`, et `native/zentarys.gdextension` l'y trouve.

## Trois choses qui ne se devinent pas

* ⚠️ **`precision=double` est obligatoire.** Le moteur du dépôt est un build
  personnalisé en double précision (Voxel Tools 1.7 compilé dedans). Une
  extension compilée en simple précision n'a pas la même taille de `Vector3` ni
  de `float` : elle ne s'aligne plus sur les structures du moteur. Le
  `.gdextension` ne déclare **que** des bibliothèques `.double`, ce qui fait que
  Godot refuse de charger une simple au lieu de la charger et de mentir ;
* ⚠️ **on compile contre le vidage d'API de *ce* moteur**, et non contre celui
  qu'embarque godot-cpp. Le binaire est un build maison : son API est celle de
  4.7.2 plus ce que le module Voxel Tools ajoute, et c'est `--dump-extension-api`
  qui la donne. `native/api/` est ignoré par git — il se regénère en une
  seconde, et le commiter figerait sept mégaoctets qui décrivent un binaire qui
  n'est lui-même pas dans le dépôt ;
* ⚠️ **l'exactitude au bit près est un invariant, pas une préférence**
  (`nextsteps.md` n° 1). Les constantes de ce bruit fixent l'identité de tous
  les mondes déjà engendrés : une dérive d'un ulp les change tous. D'où
  `/fp:precise` (pas de contraction FMA, pas de réciproque approchée), l'ordre
  des opérations recopié du GDScript jusqu'aux parenthèses, et l'arithmétique en
  `uint32_t` — où le débordement *est* le masquage que le GDScript émule à la
  main.

## Ce qui se passe si la bibliothèque n'est pas là

**Rien de visible : le monde est le même, il se charge plus lentement.**
`CWValueNoise` garde son implémentation GDScript et s'en sert quand la classe
native n'est pas enregistrée. C'est ce qui permet d'ouvrir le dépôt sans chaîne
de compilation, et c'est aussi ce qui rend la vérification d'exactitude
possible : les deux implémentations coexistent, et
`tests/worldgen_test.gd` les compare point par point.
