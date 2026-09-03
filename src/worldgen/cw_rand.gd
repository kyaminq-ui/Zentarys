class_name CWRand
extends RefCounted

## Générateur congruentiel linéaire compatible `rand()` de la CRT Microsoft.
##
## Traçabilité : le placement des sites de région d'origine
## (`World_generateRegionSite`, server/world/World.cpp) fait `srand(graine)`
## puis consomme une séquence de `rand()`. Reproduire la disposition du monde
## impose donc de reproduire ce LCG précis. Les constantes 214013 / 2531011 et
## la troncature `(state >> 16) & 0x7fff` sont l'algorithme publié de la CRT
## MSVC ; il est réécrit ici, aucun code n'en est copié.

const RAND_MAX_CW: int = 32767

var _state: int = 1


func _init(initial_seed: int = 1) -> void:
	seed_with(initial_seed)


func seed_with(initial_seed: int) -> void:
	_state = initial_seed & 0xFFFFFFFF


## Entier dans [0, 32767].
func next() -> int:
	_state = (_state * 214013 + 2531011) & 0xFFFFFFFF
	return (_state >> 16) & 0x7FFF


## Flottant dans [0, 1]. Correspond à `rand() / 32767.0` dans l'original.
func unit() -> float:
	return float(next()) / 32767.0


## `rand() % n`, en conservant le biais de l'original (il est observable dans la
## disposition du monde, donc on ne le « corrige » pas).
func mod(n: int) -> int:
	return next() % n


func coin() -> bool:
	return next() % 2 == 0
