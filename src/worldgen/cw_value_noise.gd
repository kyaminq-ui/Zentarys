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
##
## -- Depuis le 2026-09-11, ce calcul a deux corps -----------------------------
##
## `CWNoiseNative`, une GDExtension (`native/`), fait le même calcul en C++.
## C'est la seule chose du projet qui soit portée, et la mesure le justifiait
## seule : **3,31 µs l'échantillon, une quinzaine par colonne, la moitié du
## temps de génération du monde**, dans une fonction de vingt lignes qui émule
## de l'arithmétique 32 bits que GDScript n'a pas.
##
## **Le corps GDScript ne disparaît pas, et ce n'est pas de la prudence de
## principe.** Il sert trois choses :
##
##   * le dépôt s'ouvre et tourne **sans chaîne de compilation**. La bibliothèque
##     absente, le monde est le même et se charge plus lentement ;
##   * il est la **référence** contre laquelle la version native se vérifie —
##     voir `_natif_accorde`, qui est ce qui décide si on s'en sert ;
##   * il reste lisible. L'invariant n° 1 dit que ces constantes fixent
##     l'identité de tous les mondes engendrés ; un algorithme qui porte ça doit
##     rester lisible quelque part.

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


## L'implémentation native, ou `null`.
##
## -- Elle n'est adoptée qu'après avoir prouvé qu'elle dit la même chose -------
##
## L'exactitude au bit près est un invariant (n° 1) : une dérive d'un ulp change
## **tous les mondes déjà explorés**. Une bibliothèque compilée ailleurs, par un
## autre compilateur, avec une autre `libm`, peut différer sur le dernier bit du
## cosinus sans que rien ne le signale — et le défaut ne se verrait que le jour
## où quelqu'un comparerait deux captures du même endroit prises sur deux
## machines.
##
## On ne fait donc pas confiance à la bibliothèque parce qu'elle est là : on la
## **fait passer un examen** au chargement, et on ne l'adopte que si elle rend
## exactement les mêmes bits sur un balayage de points choisis pour traverser
## les cas qui fâchent — coordonnées négatives, entières, très grandes, et le
## domaine réellement échantillonné par le jeu.
static var _natif: Object = _adopte_natif()


static func _adopte_natif() -> Object:
	if not ClassDB.class_exists("CWNoiseNative"):
		return null
	var n: Object = ClassDB.instantiate("CWNoiseNative")
	if n == null:
		return null
	if not _natif_accorde(n):
		push_warning("[bruit] CWNoiseNative n'est pas d'accord avec le GDScript"
				+ " au bit pres : on garde le GDScript.")
		return null
	return n


## La version native rend-elle **exactement** les mêmes bits ?
##
## Elle appelle `sample_gd` et non `sample`, et ce n'est pas indifférent :
## `sample` passe par le dispatcheur, qui à ce moment-là ne pointe encore sur
## rien — l'examen marcherait par accident, et cesserait de marcher le jour où
## l'ordre d'initialisation changerait. On nomme donc la référence.
##
## `is_equal_approx` ne conviendrait pas et ce n'est pas de la pédanterie : le
## champ d'altitude somme une quinzaine d'octaves et les compare à des seuils,
## donc un écart d'un ulp sur un échantillon déplace une frontière de biome
## quelque part dans le monde. La comparaison est donc `==`, sur des doubles.
static func _natif_accorde(n: Object) -> bool:
	# Les points de la référence du test, puis un balayage. Les grands décalages
	# sont ceux que le jeu emploie réellement (les graines de `noise_offsets`),
	# et les négatifs sont là parce que le repli du réseau autour de zéro est le
	# seul écart assumé vis-à-vis du binaire d'origine.
	for i in 512:
		var x: float = float(i) * 0.37 - 64.0
		var z: float = float(i) * -0.19 + 12345.5
		if n.sample(x, z) != sample_gd(x, z):
			return false
		var bx: float = 1000000.0 + float(i) * 3.25
		var bz: float = -500000.5 - float(i) * 7.5
		if n.sample(bx, bz) != sample_gd(bx, bz):
			return false
	# Les entiers pile, où l'interpolation vaut zéro et où un `floor` mal porté
	# se voit.
	for i in 64:
		if n.sample(float(i - 32), float(i - 32)) != sample_gd(float(i - 32), float(i - 32)):
			return false
	return true


## Vrai si le calcul passe par la GDExtension. Pour l'ATH et les tests.
static func natif() -> bool:
	return _natif != null


## Échantillon de bruit en (x, z), dans [-1, 1).
##
## Écart assumé vs l'original : le binaire indexe le réseau par troncature vers
## zéro (`(int)x`), ce qui replie le bruit autour de x = 0 et z = 0. On utilise
## `floori` (mathématiquement correct). Les deux coïncident sur tout le domaine
## réellement échantillonné par le jeu, où les coordonnées de réseau sont
## rendues positives par de grands décalages de graine.
static func sample(x: float, z: float) -> float:
	if _natif != null:
		return _natif.sample(x, z)
	return sample_gd(x, z)


## Le corps GDScript, toujours accessible sous son nom propre.
##
## Il est appelé directement par `_natif_accorde` — qui doit comparer les deux
## implémentations et ne peut donc pas passer par le dispatcheur — et par le
## banc de `tools/profile_worldgen.gd`, qui mesure ce que le portage a gagné.
static func sample_gd(x: float, z: float) -> float:
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
