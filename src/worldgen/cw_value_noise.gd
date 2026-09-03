class_name CWValueNoise
extends RefCounted

## Bruit de valeur 2D à interpolation cosinus — le générateur de bruit unique
## dont dépend toute la génération de monde de l'alpha.
##
## Traçabilité : système d'origine `valueNoise2D` (server/world/World.cpp).
## L'analyse du pseudo-code montre l'algorithme public dit « Hugo Elias value
## noise » : hachage entier du réseau (lattice) `n = x + y*57`, brouillage
## `n ^= n << 13`, polynôme `((n*n*P1 + P2)*n + P3) & 0x7fffffff` normalisé sur
## 2^30, puis interpolation cosinus bilinéaire. Le binaire utilise le second
## triplet de nombres premiers publié avec cet algorithme (60493 / 19990303 /
## 3521384707) et non le premier (15731 / 789221 / 1376312589).
##
## Réimplémentation originale : l'arithmétique 32 bits non signée du binaire
## est émulée explicitement, car les entiers GDScript sont des int64 signés.

const U32: int = 0xFFFFFFFF
const P1: int = 60493          ## 0xEC4D dans le binaire
const P2: int = 19990303       ## 0x131071F
const P3: int = 3521384707     ## 0xD208DD0D
const INV_2P30: float = 9.31322574615478515625e-10   ## 2^-30
const ROW_STRIDE: int = 57     ## 0x39

## Multiplication modulo 2^32 sans jamais dépasser 2^63 (pas de dépendance à un
## comportement de débordement non spécifié). a et b doivent déjà être masqués.
static func mul32(a: int, b: int) -> int:
	return ((a & 0xFFFF) * b + (((a >> 16) * (b & 0xFFFF)) << 16)) & U32


## Valeur pseudo-aléatoire d'un nœud du réseau, dans [-1, 1).
static func lattice(n: int) -> float:
	n = n & U32
	n = (n ^ ((n << 13) & U32)) & U32
	var m: int = mul32(n, n)
	m = (mul32(m, P1) + P2) & U32
	m = (mul32(m, n) + P3) & U32
	return 1.0 - float(m & 0x7FFFFFFF) * INV_2P30


## Échantillon de bruit en (x, z), dans [-1, 1).
##
## Écart assumé vs l'original : le binaire indexe le réseau par troncature vers
## zéro (`(int)x`), ce qui replie le bruit autour de x = 0 et z = 0. On utilise
## `floori` (mathématiquement correct). Les deux coïncident sur tout le domaine
## réellement échantillonné par le jeu, où les coordonnées de réseau sont
## rendues positives par de grands décalages de graine.
static func sample(x: float, z: float) -> float:
	var ix: int = floori(x)
	var iz: int = floori(z)
	var r0: int = iz * ROW_STRIDE
	var r1: int = r0 + ROW_STRIDE
	var tx: float = (1.0 - cos((x - float(ix)) * PI)) * 0.5
	var tz: float = (1.0 - cos((z - float(iz)) * PI)) * 0.5
	# Chemin chaud : le hachage est déplié ici plutôt qu'appelé quatre fois.
	# `sample` tourne une vingtaine de fois par colonne de terrain, donc ce sont
	# quatre-vingts appels de fonction par colonne qu'on économise. `lattice`
	# reste la référence lisible et testée du même calcul.
	var n: int = (ix + r0) & U32
	n = (n ^ ((n << 13) & U32)) & U32
	var m: int = mul32(n, n)
	m = (mul32(m, P1) + P2) & U32
	var a: float = 1.0 - float((mul32(m, n) + P3) & 0x7FFFFFFF) * INV_2P30

	n = (ix + 1 + r0) & U32
	n = (n ^ ((n << 13) & U32)) & U32
	m = mul32(n, n)
	m = (mul32(m, P1) + P2) & U32
	var b: float = 1.0 - float((mul32(m, n) + P3) & 0x7FFFFFFF) * INV_2P30

	n = (ix + r1) & U32
	n = (n ^ ((n << 13) & U32)) & U32
	m = mul32(n, n)
	m = (mul32(m, P1) + P2) & U32
	var c: float = 1.0 - float((mul32(m, n) + P3) & 0x7FFFFFFF) * INV_2P30

	n = (ix + 1 + r1) & U32
	n = (n ^ ((n << 13) & U32)) & U32
	m = mul32(n, n)
	m = (mul32(m, P1) + P2) & U32
	var d: float = 1.0 - float((mul32(m, n) + P3) & 0x7FFFFFFF) * INV_2P30

	var lo: float = a + (b - a) * tx
	var hi: float = c + (d - c) * tx
	return lo + (hi - lo) * tz


## Échantillon ramené dans [0, 1].
static func sample01(x: float, z: float) -> float:
	return (sample(x, z) + 1.0) * 0.5
