class_name CWLightTest
extends RefCounted

## Verifications de l'eclairage voxel (jalon 1.9), porte de
## `VoxelChunk_propagateSunlight` @0059a0e0. Analyse : `docs/systems/04`.
##
## Pilote par tests/worldgen_test.gd, qui tient le compte des verifications :
##   CWLightTest.new().run(self)
##
## Ce qui est verrouille ici, c'est ce qui distingue cet eclairage de celui,
## familier, de Minecraft — et que quelqu'un « corrigerait » de bonne foi :
## l'attenuation multiplicative, le plancher d'ambiante, et le fait que la
## diffusion ne monte ni ne descend.

var _runner: Object


func run(runner: Object) -> void:
	_runner = runner
	_test_constants()
	_test_sun_descent()
	_test_spread()
	_test_shading()
	_test_shaded_cells()
	_bench()


func _ok(label: String, condition: bool, detail: String = "") -> void:
	_runner._ok(label, condition, detail)


## Pave de types, plein de `fill`.
func _box(size: Vector3i, fill: int) -> PackedByteArray:
	var t := PackedByteArray()
	t.resize(size.x * size.y * size.z)
	t.fill(fill)
	return t


## Indice d'une case, dans l'ordre natif de `VoxelBuffer` : Y d'abord.
## Voir l'en-tete de `CWLight.compute` — s'en ecarter, c'est se condamner a
## recopier le canal case par case.
static func _at(size: Vector3i, x: int, y: int, z: int) -> int:
	return y + size.y * (x + size.x * z)


# -- 1. Les constantes --------------------------------------------------------

func _test_constants() -> void:
	print("[eclairage : les constantes]")

	# L'attenuation est multiplicative — 85/100 par bloc — et non le moins-un par
	# bloc auquel tout le monde pense. C'est la difference la plus visible entre
	# cet eclairage et celui de Minecraft : la lumiere decroit en exponentielle,
	# pas en rampe.
	_ok("l'attenuation vaut 85/100",
			CWLight.ATTENUATION_NUM == 85 and CWLight.ATTENUATION_DEN == 100)
	_ok("attenuer la pleine lumiere donne 216",
			CWLight.attenuate(CWLight.FULL) == 216,
			str(CWLight.attenuate(CWLight.FULL)))
	# Seize pas laissent environ 7 % : c'est ce qui fixe la portee utile.
	var l: int = CWLight.FULL
	for _i in CWLight.ITERATIONS:
		l = CWLight.attenuate(l)
	_ok("seize pas laissent entre 5 et 10 %% de la pleine lumiere",
			l > 12 and l < 26, "%d / 255" % l)
	_ok("seize iterations", CWLight.ITERATIONS == 16)

	# Le plancher : un voisin transparent apporte au moins 5, meme noir. C'est
	# l'ambiante, et elle est dans l'algorithme et non dans le rendu.
	_ok("un voisin transparent et noir apporte quand meme le plancher",
			CWLight.contribution(CWPalette.AIR, 0) == CWLight.FLOOR)
	_ok("un voisin transparent et clair apporte sa propre valeur",
			CWLight.contribution(CWPalette.AIR, 200) == 200)
	_ok("un voisin opaque n'apporte rien",
			CWLight.contribution(CWPalette.STONE, 255) == 0)

	# Ce qui est transparent : l'air et les deux eaux. L'original teste
	# `type == 0 || type == 2`, son second type etant tres probablement l'eau.
	_ok("l'air et les deux eaux laissent passer la lumiere",
			CWLight.is_transparent(CWPalette.AIR)
			and CWLight.is_transparent(CWPalette.WATER)
			and CWLight.is_transparent(CWPalette.WATER_DEEP))
	var leaky: Array = []
	for i in [CWPalette.STONE, CWPalette.DIRT, CWPalette.GRASS, CWPalette.SAND,
			CWPalette.SNOW, CWPalette.ICE, CWPalette.GRAVEL, CWPalette.TUNDRA]:
		if CWLight.is_transparent(i):
			leaky.append(CWPalette.name_of(i))
	_ok("aucune matiere ne laisse passer la lumiere", leaky.is_empty(), str(leaky))


# -- 2. La descente du soleil -------------------------------------------------

func _test_sun_descent() -> void:
	print("[eclairage : la descente du soleil]")

	# Un champ de hauteurs : de la roche jusqu'a `top`, de l'air au-dessus. C'est
	# exactement la forme du terrain genere, et le resultat attendu est ce qui
	# **justifie que le generateur n'appelle jamais la diffusion** : tout ce qui
	# est au-dessus du sol est deja a pleine lumiere.
	var size := Vector3i(6, 12, 6)
	var types: PackedByteArray = _box(size, CWPalette.AIR)
	var top: int = 5
	for z in size.z:
		for x in size.x:
			for y in range(0, top + 1):
				types[_at(size, x, y, z)] = CWPalette.STONE
	var level: PackedByteArray = CWLight.compute(types, size)

	var lit: bool = true
	var dark: bool = true
	for z in size.z:
		for x in size.x:
			for y in range(top + 1, size.y):
				if level[_at(size, x, y, z)] != CWLight.FULL:
					lit = false
			for y in range(0, top + 1):
				if level[_at(size, x, y, z)] != 0:
					dark = false
	_ok("sur un champ de hauteurs, tout l'air est a pleine lumiere", lit)
	_ok("et la matiere est a zero", dark)

	# La transition est franche : pas d'attenuation verticale. Un bloc d'air
	# juste sous un surplomb est noir, pas « un peu moins clair ».
	var s2 := Vector3i(1, 6, 1)
	var t2: PackedByteArray = _box(s2, CWPalette.AIR)
	t2[_at(s2, 0, 3, 0)] = CWPalette.STONE
	var l2: PackedByteArray = CWLight.compute(t2, s2)
	_ok("au-dessus du surplomb, pleine lumiere",
			l2[_at(s2, 0, 4, 0)] == CWLight.FULL, str(l2[_at(s2, 0, 4, 0)]))
	# Sous le surplomb, une colonne isolee n'a que ses propres voisins
	# horizontaux — il n'y en a pas dans un pave de 1x1 — donc elle reste noire.
	# C'est la passe A seule, et elle ne degrade pas : elle coupe.
	_ok("sous le surplomb, la passe A coupe net",
			l2[_at(s2, 0, 2, 0)] == 0, str(l2[_at(s2, 0, 2, 0)]))


# -- 3. La diffusion ----------------------------------------------------------

func _test_spread() -> void:
	print("[eclairage : la diffusion]")

	# Une galerie horizontale sous un toit de roche, ouverte a une extremite.
	# C'est le cas qui justifie tout le systeme : la lumiere doit entrer par
	# l'ouverture et s'eteindre en s'enfoncant.
	var size := Vector3i(24, 5, 3)
	var types: PackedByteArray = _box(size, CWPalette.STONE)
	var y: int = 2
	var z: int = 1
	for x in range(1, size.x - 1):
		types[_at(size, x, y, z)] = CWPalette.AIR
	# L'ouverture : une cheminee au-dessus de x = 1.
	for yy in range(y, size.y):
		types[_at(size, 1, yy, z)] = CWPalette.AIR

	var level: PackedByteArray = CWLight.compute(types, size)
	var mouth: int = level[_at(size, 1, y, z)]
	var near: int = level[_at(size, 3, y, z)]
	var far: int = level[_at(size, 12, y, z)]
	var deepest: int = level[_at(size, 22, y, z)]
	print("     galerie : bouche %d, x+2 %d, x+11 %d, fond %d"
			% [mouth, near, far, deepest])

	_ok("la bouche de la galerie est en pleine lumiere", mouth == CWLight.FULL,
			str(mouth))
	_ok("la lumiere entre dans la galerie", near > 0 and near < CWLight.FULL,
			str(near))
	_ok("elle decroit en s'enfoncant", far < near, "%d puis %d" % [near, far])
	# Le plancher d'ambiante : le fond ne tombe jamais a zero, meme a vingt
	# blocs de l'ouverture et apres seize iterations.
	_ok("le fond garde l'ambiante, il ne tombe pas au noir",
			deepest >= CWLight.attenuate(CWLight.FLOOR) and deepest > 0,
			str(deepest))

	# La decroissance est multiplicative : le rapport entre deux points espaces
	# doit etre une puissance de 0,85, pas une difference constante. On mesure
	# sur deux ecarts egaux — une rampe donnerait le meme ecart, une
	# exponentielle le meme rapport.
	var a: int = level[_at(size, 3, y, z)]
	var b: int = level[_at(size, 6, y, z)]
	var c: int = level[_at(size, 9, y, z)]
	if b > 0 and c > 0 and a > b and b > c:
		var d1: int = a - b
		var d2: int = b - c
		_ok("la decroissance est multiplicative, pas une rampe", d1 > d2,
				"ecarts %d puis %d pour un meme espacement" % [d1, d2])
	else:
		_ok("la decroissance est multiplicative, pas une rampe", false,
				"profil inattendu : %d, %d, %d" % [a, b, c])

	# La diffusion ne monte ni ne descend. Une poche d'air isolee, posee juste
	# sous une galerie eclairee, ne doit rien recevoir d'elle : le vertical
	# n'est traite que par la passe A, qui la laisse noire.
	var pocket: int = level[_at(size, 12, y - 1, z)]
	_ok("la diffusion ne se propage pas verticalement",
			pocket == 0 or types[_at(size, 12, y - 1, z)] != CWPalette.AIR,
			"poche a %d" % pocket)


# -- 4. L'assombrissement -----------------------------------------------------

func _test_shading() -> void:
	print("[eclairage : l'assombrissement]")

	var full: int = CWLight.shade(CWPalette.GRASS, CWLight.FULL)
	_ok("a pleine lumiere, la couleur est celle de la palette",
			full == CWPalette.raw_of(CWPalette.GRASS),
			"0x%08X contre 0x%08X" % [full, CWPalette.raw_of(CWPalette.GRASS)])
	var half: int = CWLight.shade(CWPalette.GRASS, 128)
	_ok("a mi-lumiere, chaque composante est environ divisee par deux",
			((half >> 24) & 0xFF) * 2 <= ((full >> 24) & 0xFF) + 2
			and ((half >> 16) & 0xFF) * 2 <= ((full >> 16) & 0xFF) + 2,
			"0x%08X" % half)
	var dark: int = CWLight.shade(CWPalette.GRASS, 0)
	_ok("au noir, il ne reste que l'alpha",
			(dark >> 8) == 0, "0x%08X" % dark)

	# L'alpha ne bouge jamais : c'est lui qui range l'eau dans la surface
	# transparente du mailleur. Une eau qui deviendrait opaque en profondeur
	# serait un defaut bien plus visible que son assombrissement.
	var water_full: int = CWPalette.raw_of(CWPalette.WATER)
	var kept: bool = true
	for lvl in [0, 5, 64, 128, 200, 255]:
		if (CWLight.shade(CWPalette.WATER, lvl) & 0xFF) != (water_full & 0xFF):
			kept = false
	_ok("l'assombrissement ne touche pas l'alpha de l'eau", kept)

	# Un bloc opaque prend le maximum de ses six voisins : c'est
	# l'approximation qu'impose un mailleur qui ne pose qu'une couleur par
	# voxel. Une dalle avec de l'air eclaire au-dessus doit s'eclairer.
	var size := Vector3i(3, 3, 3)
	var types: PackedByteArray = _box(size, CWPalette.STONE)
	types[_at(size, 1, 2, 1)] = CWPalette.AIR
	var level: PackedByteArray = CWLight.compute(types, size)
	_ok("un bloc opaque prend la lumiere de l'air qui le surplombe",
			CWLight.opaque_level(types, level, size, 1, 1, 1) == CWLight.FULL,
			str(CWLight.opaque_level(types, level, size, 1, 1, 1)))
	# Et un bloc entierement enterre rend `BURIED`, qui n'est **pas** zero. La
	# distinction est ce qui separe « ce bloc est noir » de « ce bloc n'a aucune
	# face visible, sa couleur n'a aucune importance » : sans elle, reeclairer une
	# galerie reecrivait quarante-huit mille blocs de roche que personne ne voit.
	var buried: PackedByteArray = _box(size, CWPalette.STONE)
	var lvl2: PackedByteArray = CWLight.compute(buried, size)
	_ok("un bloc entierement enterre rend BURIED, et non zero",
			CWLight.opaque_level(buried, lvl2, size, 1, 1, 1) == CWLight.BURIED,
			str(CWLight.opaque_level(buried, lvl2, size, 1, 1, 1)))


# -- 5. La liste des cases a repeindre ----------------------------------------

func _test_shaded_cells() -> void:
	print("[eclairage : les cases a repeindre]")

	# `shaded_cells` remplace un balayage qui appelait `opaque_level` sur chaque
	# bloc plein du pave. C'est la meme regle prise par l'autre bout — on pousse
	# depuis l'air au lieu de tirer depuis la roche — et deux implementations
	# d'une meme regle divergent toujours si personne ne les compare. D'ou ce
	# test croise, sur un pave irregulier plutot que sur une forme choisie.
	var size := Vector3i(9, 11, 7)
	var types: PackedByteArray = _box(size, CWPalette.STONE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240909
	# De l'air par paquets : des poches, des galeries, et de quoi ouvrir
	# quelques colonnes sur le ciel.
	for _i in 140:
		var x: int = rng.randi_range(0, size.x - 1)
		var y: int = rng.randi_range(0, size.y - 1)
		var z: int = rng.randi_range(0, size.z - 1)
		types[_at(size, x, y, z)] = CWPalette.AIR
	# Un peu d'eau, qui est transparente et coloree a la fois : elle doit se
	# retrouver dans la liste avec son propre niveau, pas avec celui d'un voisin.
	for _i in 12:
		var x: int = rng.randi_range(0, size.x - 1)
		var y: int = rng.randi_range(0, size.y - 1)
		var z: int = rng.randi_range(0, size.z - 1)
		types[_at(size, x, y, z)] = CWPalette.WATER

	var level: PackedByteArray = CWLight.compute(types, size)
	var cells: PackedInt32Array = CWLight.shaded_cells(types, level, size)

	# Ce que la liste dit, indice par indice.
	var listed: Dictionary = {}
	var duplicates: int = 0
	var k: int = 0
	while k < cells.size():
		if listed.has(cells[k]):
			duplicates += 1
		listed[cells[k]] = cells[k + 1]
		k += 2
	_ok("aucune case n'est listee deux fois", duplicates == 0, str(duplicates))

	var wrong_opaque: int = 0
	var missing: int = 0
	var extra: int = 0
	var wrong_water: int = 0
	for z in size.z:
		for x in size.x:
			for y in size.y:
				var i: int = _at(size, x, y, z)
				var t: int = types[i]
				if t == CWPalette.AIR:
					# L'air n'a pas de couleur a assombrir : il n'a rien a faire
					# dans la liste.
					if listed.has(i):
						extra += 1
					continue
				if CWLight.is_transparent(t):
					if not listed.has(i) or listed[i] != level[i]:
						wrong_water += 1
					continue
				var want: int = CWLight.opaque_level(types, level, size, x, y, z)
				if want == CWLight.BURIED:
					if listed.has(i):
						extra += 1
				elif not listed.has(i):
					missing += 1
				elif listed[i] != want:
					wrong_opaque += 1

	_ok("la liste donne le meme niveau que opaque_level", wrong_opaque == 0,
			str(wrong_opaque))
	_ok("aucun bloc visible n'est oublie", missing == 0, str(missing))
	_ok("aucun bloc enterre ni aucun air n'y figure", extra == 0, str(extra))
	_ok("l'eau y figure avec son propre niveau", wrong_water == 0,
			str(wrong_water))
	print("     pave de %d cases, %d a repeindre" % [types.size(), listed.size()])


# -- 6. Le cout ---------------------------------------------------------------

## Cout des deux passes sur le pave d'un coup de pioche isole.
##
## C'est le cas interactif, et le seul qui ait un budget : le reeclairage tourne
## sur le fil principal — `VoxelTool` ne se lit pas ailleurs — donc tout ce qui
## est compte ici est du temps ou le jeu ne dessine pas. Le pave est celui que
## `CWWorldEdits.relight` construit pour un bloc : `1 + 2 x ITERATIONS` de cote.
func _bench() -> void:
	print("[eclairage : le cout]")
	var side: int = 1 + 2 * CWLight.ITERATIONS
	var size := Vector3i(side, side, side)
	var types: PackedByteArray = _box(size, CWPalette.STONE)
	# Un terrain a mi-hauteur, et une galerie couverte dessous : la forme meme
	# du cas mesure. De l'air plein ciel au-dessus, de la roche en dessous.
	var ground: int = side / 2
	for z in size.z:
		for x in size.x:
			for y in range(ground + 1, size.y):
				types[_at(size, x, y, z)] = CWPalette.AIR
	for x in range(2, size.x - 2):
		for dy in 3:
			types[_at(size, x, ground - 4 + dy, side / 2)] = CWPalette.AIR

	var t0: int = Time.get_ticks_usec()
	var level: PackedByteArray = CWLight.compute(types, size)
	var t1: int = Time.get_ticks_usec()
	var cells: PackedInt32Array = CWLight.shaded_cells(types, level, size)
	var t2: int = Time.get_ticks_usec()

	var compute_ms: float = float(t1 - t0) / 1000.0
	var cells_ms: float = float(t2 - t1) / 1000.0
	print("     pave %d^3 (%d cases) : compute %.1f ms, shaded_cells %.1f ms, %d a repeindre"
			% [side, types.size(), compute_ms, cells_ms, cells.size() / 2])
	# Une borne large, qui n'attrape qu'une regression franche : la machine de
	# test n'est pas celle du joueur, et ce qui compte ici est l'ordre de
	# grandeur — quelques millisecondes, pas quelques dizaines.
	_ok("le reeclairage d'un coup de pioche reste sous 25 ms",
			compute_ms + cells_ms < 25.0,
			"%.1f ms" % (compute_ms + cells_ms))
