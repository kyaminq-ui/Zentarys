class_name CWRegionSite
extends RefCounted

## Un « site de région » : le point d'ancrage climatique d'une zone de 16384
## unités monde.
##
## Traçabilité : structure de 0x1c octets allouée par `World_generateRegionSite`
## (server/world/World.cpp). Champs reconstruits à partir des motifs d'accès :
##   +0x00 int   x            position monde (calée au centre d'une tuile)
##   +0x04 int   z
##   +0x08 byte  drapeau « humide » (marais)
##   +0x0c float température   lue par le mélange de température
##   +0x10 float humidité      lue par le mélange d'humidité
##   +0x14 int   graine dérivée de la région
##   +0x18 int   altitude de base   lue par le champ d'altitude
##
## Ghidra type +0x0c et +0x10 comme des int (artefact classique : un `movss`
## vers un champ non typé). Les valeurs écrites (0.3, 0.4, 0.9 ...) prouvent
## qu'il s'agit de flottants.

var x: int = 0
var z: int = 0
var wet: bool = false
var temperature: float = 0.0
var humidity: float = 0.0
var site_seed: int = 0
var base_height: int = 0

## Vrai si le site est sous le niveau de la mer (fond océanique).
func is_ocean() -> bool:
	return base_height < 1
