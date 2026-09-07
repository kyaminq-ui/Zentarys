class_name CWSkyTest
extends RefCounted

## Verifications de la couche de ciel : le lot de nuages et sa pose
## (`CWClouds`, 2026-09-11).
##
## Pilote par tests/worldgen_test.gd, qui tient le compte des verifications.
##
## **Ce que cette suite peut voir, et ce qu'elle ne peut pas.** Elle verifie le
## lot — plages de palette, enveloppe, un seul tenant —, la **purete** du
## tirage, et deux accords entre constantes que rien d'autre ne tient : les
## nuages passent au-dessus du plus haut sommet, et ils ne sont ecrits nulle
## part dans les donnees voxels. Elle ne peut rien dire de leur allure : les
## deux defauts qui ont demande une reprise le jour meme — des soucoupes bleu
## marine, puis des meduses turquoise — etaient l'un un materiau, l'autre une
## rampe, et **aucun des deux n'aurait fait tomber une seule ligne d'ici**. La
## capture reste le juge.

var _runner: Object

## Le lot, charge une fois : `CWVoxelModel.mesh()` construit un maillage, et le
## refaire par verification couterait plus que tout le reste de la suite.
var _modeles: Array[CWVoxelModel] = []
var _tirage: PackedInt32Array = PackedInt32Array()


func run(runner: Object) -> void:
	_runner = runner
	print("[ciel]")
	var lot: Dictionary = CWClouds.charge_lot()
	_modeles = lot["modeles"]
	_tirage = lot["tirage"]
	_test_lot()
	_test_pose()
	_test_accords()


func _ok(label: String, condition: bool, detail: String = "") -> void:
	_runner._ok(label, condition, detail)


# -- Le lot -------------------------------------------------------------------

func _test_lot() -> void:
	_ok("les trois nuages sont sur le disque et se chargent",
			_modeles.size() == CWClouds.LOT.size(),
			"%d modele(s) sur %d" % [_modeles.size(), CWClouds.LOT.size()])
	if _modeles.is_empty():
		return

	# La grille : un nuage est dessine **a la taille du terrain**, comme un arbre
	# et un filon. La lire depuis le modele et non depuis la constante est
	# l'invariant n. 28 ; un nuage charge a 40/3 sortirait treize fois trop
	# petit, ce qui donnerait des mouettes.
	var grille_juste: bool = true
	for m in _modeles:
		if m.voxels_per_block != CWVoxelModel.VOXELS_PER_BLOCK_TERRAIN:
			grille_juste = false
	_ok("le lot est a 1 voxel = 1 bloc", grille_juste)

	# La plage de palette. Un index hors plage ne leve rien a l'execution : il
	# ressort peint avec la couleur d'un autre lot le jour ou la palette bougera.
	# Les nuages n'ont droit qu'au **haut de la plage effets** — ni la neige, ni
	# la glace, ni la roche claire, qui sont des matieres de terrain.
	var hors: Array = []
	for m in _modeles:
		for i in m.values(0):
			var dedans: bool = i >= CWPalette.RANGE_FX_BEGIN and i <= CWPalette.RANGE_FX_BEGIN + 7
			if not dedans and not hors.has(i):
				hors.append(i)
	_ok("indices dans la rampe blanche de la plage effets", hors.is_empty(), str(hors))

	# Le degrade doit **atteindre le blanc**. Ce n'est pas de la coquetterie :
	# la premiere version du generateur rapportait la teinte a une hauteur
	# calculee et non mesuree, et sortait un lot qui ne montait qu'a l'index 242
	# — un ciel entierement bleute, sans que rien ne le signale.
	var atteint_blanc: bool = true
	for m in _modeles:
		if not m.values(0).has(CWPalette.RANGE_FX_BEGIN):
			atteint_blanc = false
	_ok("chaque nuage atteint le blanc a son sommet", atteint_blanc)

	# Un seul tenant (invariant n. 34). Un morceau detache flotterait a cote du
	# nuage, ce qui, dans le ciel, est le seul endroit du monde ou l'on ne
	# remarquerait pas tout de suite que c'est un defaut.
	for m in _modeles:
		var n: int = _morceaux(m)
		_ok("%s est d'un seul tenant" % m.name, n == 1, "%d morceaux" % n)

	# L'enveloppe, dite en blocs puisque la grille vaut 1. Au-dela, un nuage
	# cesse d'etre un objet du ciel et devient un plafond.
	#
	# Elle a grandi avec le lot le 2026-09-12 (24 h, 32 r auparavant), et la
	# borne qui compte n'est pas celle-ci : c'est `CWClouds.MAILLE`, verifiee
	# juste apres. Une enveloppe seule ne dit rien d'un plafond — deux nuages de
	# vingt blocs poses a dix l'un de l'autre en font un.
	for m in _modeles:
		_ok("%s tient dans l'enveloppe (40 h, 56 r)" % m.name,
				m.height <= 40 and m.radius <= 56,
				"h %d, r %d" % [m.height, m.radius])

	# **Le plus grand nuage doit tenir dans sa cellule de ciel**, gigue
	# d'instance comprise. C'est ce qui separe un ciel d'un plafond, et c'est le
	# seul rapport du lot que la capture ne rattrape pas : un plafond de nuages
	# reste joli sur une image et devient une chape des qu'on avance.
	var plus_large: int = 0
	for m in _modeles:
		plus_large = maxi(plus_large, m.radius * 2)
	var etendu: float = float(plus_large) * CWClouds.ECHELLE_MAX
	_ok("le plus large nuage tient dans une cellule de ciel",
			etendu < float(CWClouds.MAILLE),
			"%.0f blocs pour une maille de %d" % [etendu, CWClouds.MAILLE])


# -- La pose ------------------------------------------------------------------

func _test_pose() -> void:
	if _modeles.is_empty():
		return
	var origine := Vector2i(0, 0)

	# **Une fonction pure.** Deux appels sur la meme cellule rendent la meme
	# chose, et rien d'autre que l'indice et la graine n'entre dedans. C'est ce
	# qui permet de refaire tout le champ a chaque franchissement de frontiere
	# plutot que de tenir un etat, donc c'est ce qui rend la couche sans etat.
	var stable: bool = true
	for k in 64:
		var a: Array = CWClouds.nuage_de(k * 3 - 40, 17 - k, 2024, origine,
				_modeles, _tirage, 0.5)
		var b: Array = CWClouds.nuage_de(k * 3 - 40, 17 - k, 2024, origine,
				_modeles, _tirage, 0.5)
		if a.size() != b.size():
			stable = false
		elif not a.is_empty() and (a[0] != b[0] or a[1] != b[1]):
			stable = false
	_ok("le tirage d'une cellule est une fonction pure de son indice", stable)

	# Deux graines ne font pas le meme ciel.
	var differe: int = 0
	for k in 200:
		var a: Array = CWClouds.nuage_de(k, k * 7, 2024, origine, _modeles, _tirage, 0.5)
		var b: Array = CWClouds.nuage_de(k, k * 7, 1337, origine, _modeles, _tirage, 0.5)
		if a.size() != b.size() or (not a.is_empty() and a[1] != b[1]):
			differe += 1
	_ok("deux graines ne rendent pas le meme ciel", differe > 120, "%d / 200" % differe)

	# -- Ce que la couverture fait, et ce qu'elle ne doit pas faire -----------
	#
	# **Baisser la couverture doit eclaircir le ciel, pas le redessiner.** C'est
	# l'invariant n. 23 applique ici : les six tirages sont pris ensemble, avant
	# le test de couverture, donc le nuage d'une cellule ne depend pas du
	# reglage. Si un seul tirage passait apres le test, deux captures du meme
	# endroit a deux couvertures ne seraient plus comparables — et c'est
	# exactement le genre de defaut qu'on attribuerait au terrain.
	var sous_ensemble: bool = true
	var identiques: bool = true
	for cz in range(-8, 8):
		for cx in range(-8, 8):
			var basse: Array = CWClouds.nuage_de(cx, cz, 2024, origine,
					_modeles, _tirage, 0.30)
			var haute: Array = CWClouds.nuage_de(cx, cz, 2024, origine,
					_modeles, _tirage, 0.70)
			if not basse.is_empty():
				if haute.is_empty():
					sous_ensemble = false
				elif basse[0] != haute[0] or basse[1] != haute[1]:
					identiques = false
	_ok("un ciel peu couvert est un sous-ensemble d'un ciel couvert", sous_ensemble)
	_ok("les nuages qui restent sont exactement les memes", identiques)

	# Les deux bornes, et la proportion entre elles.
	var vides: int = 0
	var pleines: int = 0
	var moitie: int = 0
	var total: int = 0
	for cz in range(-24, 24):
		for cx in range(-24, 24):
			total += 1
			if CWClouds.nuage_de(cx, cz, 2024, origine, _modeles, _tirage, 0.0).is_empty():
				vides += 1
			if not CWClouds.nuage_de(cx, cz, 2024, origine, _modeles, _tirage, 1.0).is_empty():
				pleines += 1
			if not CWClouds.nuage_de(cx, cz, 2024, origine, _modeles, _tirage, 0.5).is_empty():
				moitie += 1
	_ok("a couverture nulle le ciel est vide", vides == total)
	_ok("a couverture pleine chaque cellule porte un nuage", pleines == total)
	var part: float = float(moitie) / float(total)
	_ok("a 0,5 la moitie des cellules portent un nuage", absf(part - 0.5) < 0.06,
			"%.3f" % part)

	# Les trois variantes sortent, et dans l'ordre de grandeur de leurs poids.
	# Un modele range dans le lot mais jamais tire serait charge, maille, et ne
	# se poserait pas une seule fois — le defaut le plus discret de la table
	# (invariant n. 22, meme forme).
	var comptes: PackedInt32Array = PackedInt32Array()
	comptes.resize(_modeles.size())
	for cz in range(-30, 30):
		for cx in range(-30, 30):
			var p: Array = CWClouds.nuage_de(cx, cz, 2024, origine,
					_modeles, _tirage, 1.0)
			comptes[int(p[0])] += 1
	var tous: bool = true
	for c in comptes:
		if c == 0:
			tous = false
	_ok("les trois variantes se posent", tous, str(comptes))


# -- Les accords que rien d'autre ne tient ------------------------------------

func _test_accords() -> void:
	# **Les nuages passent au-dessus du plus haut sommet.** Un nuage n'a pas de
	# collision : un sommet qui le traverse ne se refuse pas, il se voit — et il
	# ne se voit que la ou le relief est haut, donc rarement et tard. Les deux
	# constantes vivent dans deux fichiers, et rien d'autre ne les rapproche.
	#
	# Le maximum est mesure sur l'apercu de la suite : 376,9 blocs. On le refait
	# ici sur un balayage grossier plutot que de recopier le chiffre, l'invariant
	# n. 51 valant aussi pour les altitudes.
	var p := CWWorldParams.new()
	p.world_seed = 2024
	var f := CWTerrainField.new(p)
	var haut: float = -1e9
	for i in 900:
		var wx: int = p.world_origin.x + (i % 30) * 4096 - 61440
		var wz: int = p.world_origin.y + (i / 30) * 4096 - 61440
		haut = maxf(haut, f.sample_column(wx, wz).x)
	_ok("la base des nuages passe au-dessus du relief", CWClouds.ALTITUDE > haut,
			"base %.0f, sommet releve %.1f" % [CWClouds.ALTITUDE, haut])

	# **Rien n'est ecrit dans les donnees voxels a la hauteur des nuages.**
	# C'est l'invariant n. 39 vu du bon cote : un nuage estampe serait creusable,
	# il casserait le chemin rapide « bloc entierement vide » sur toute la
	# hauteur du ciel, et il faudrait le faire connaitre a `generated_voxel`.
	# La verification est bete et c'est voulu — elle tombera le jour ou quelqu'un
	# aura l'idee d'estamper le ciel.
	var g := CWVoxelGenerator.new()
	g.params = p
	var vide: bool = true
	for i in 64:
		var lx: int = (i % 8) * 137 - 548
		var lz: int = (i / 8) * 137 - 548
		for dy in 6:
			var y: int = int(CWClouds.ALTITUDE) + dy * 24
			if g.generated_voxel(lx, y, lz) != CWPalette.AIR:
				vide = false
	_ok("le ciel reste de l'air dans les donnees voxels", vide)

	# **Le materiau des nuages ignore le brouillard, et lui seul.** C'est le
	# seul reglage de rendu du depot qui diverge de celui du terrain ; il a une
	# raison mecanique (le brouillard est regle pour 384 blocs au sol) et il ne
	# doit pas en appeler d'autres.
	var nuage: StandardMaterial3D = CWPalette.build_cloud_material()
	var sol: StandardMaterial3D = CWPalette.build_opaque_material()
	_ok("le materiau des nuages ignore le brouillard", nuage.disable_fog)
	_ok("celui du terrain ne l'ignore pas", not sol.disable_fog)
	_ok("le nuage porte un contre-jour, le terrain non",
			nuage.backlight_enabled and not sol.backlight_enabled)
	_ok("tout le reste est celui du terrain",
			nuage.vertex_color_use_as_albedo == sol.vertex_color_use_as_albedo
			and nuage.roughness == sol.roughness
			and nuage.specular_mode == sol.specular_mode)


## Nombre de morceaux d'un modele, en 26-voisinage. Meme calcul que dans
## `tests/flora_test.gd` : ecrit sur les offsets du modele charge, parce que
## relire le fichier reviendrait a verifier autre chose que ce que le jeu pose.
func _morceaux(m: CWVoxelModel) -> int:
	var dx: PackedInt32Array = m.offsets_x(0)
	var dy: PackedInt32Array = m.offsets_y(0)
	var dz: PackedInt32Array = m.offsets_z(0)
	var reste: Dictionary = {}
	for i in m.voxel_count:
		reste[Vector3i(dx[i], dy[i], dz[i])] = true
	var morceaux: int = 0
	while not reste.is_empty():
		var depart: Vector3i = reste.keys()[0]
		reste.erase(depart)
		var pile: Array[Vector3i] = [depart]
		while not pile.is_empty():
			var c: Vector3i = pile.pop_back()
			for ax in [-1, 0, 1]:
				for ay in [-1, 0, 1]:
					for az in [-1, 0, 1]:
						var q: Vector3i = c + Vector3i(ax, ay, az)
						if reste.has(q):
							reste.erase(q)
							pile.append(q)
		morceaux += 1
	return morceaux
