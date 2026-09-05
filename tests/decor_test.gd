class_name CWDecorTest
extends RefCounted

## Verifications de la regle de selection du decor (jalon 1.7, `CWDecorRules`).
##
## Ce que ces verifications tiennent, et pourquoi elles ne sont pas dans
## `flora_test.gd` : celui-ci mesure la dispersion — combien, ou, a quelle
## taille. Celui-la mesure le *choix* — quel role, sur quelle surface, a quelle
## rarete. Les deux se cassent independamment, et le second casse en silence :
## un role selectionne sur une surface qui n'a pas de modele pour lui ne leve
## rien, il fait juste disparaitre une plante sur quatre sans que la densite
## moyenne bouge assez pour se voir.

var _t: Object


func run(harness: Object) -> void:
	_t = harness
	_test_tables()
	_test_selection()
	_test_composition()


func _ok(label: String, condition: bool, detail: String = "") -> void:
	_t._ok(label, condition, detail)


# -- 1. Les tables se repondent -----------------------------------------------

func _test_tables() -> void:
	print("[decor : les tables]")

	# Toute surface qui sait choisir doit savoir poser, et inversement. Une
	# surface presente d'un seul cote est une entree morte : soit un role sans
	# modele (une plante sur quatre qui disparait), soit des modeles charges que
	# rien ne selectionnera jamais.
	var only_families: Array = []
	for surface in CWDecorRules.FAMILIES:
		if not CWModelLibrary.ROLES.has(surface):
			only_families.append(CWPalette.name_of(surface))
	_ok("chaque surface qui choisit sait poser", only_families.is_empty(),
			str(only_families))

	var only_roles: Array = []
	for surface in CWModelLibrary.ROLES:
		if not CWDecorRules.FAMILIES.has(surface):
			only_roles.append(CWPalette.name_of(surface))
	_ok("chaque surface qui pose sait choisir", only_roles.is_empty(),
			str(only_roles))

	# Le point qui casse en silence : un role atteignable par les deux cretes
	# mais sans modele sur cette surface.
	var orphans: Array = []
	for surface in CWDecorRules.FAMILIES:
		for role in _reachable_roles(surface):
			var models: Array = CWModelLibrary.ROLES.get(surface, {}).get(role, [])
			if models.is_empty():
				orphans.append("%s/%s" % [CWPalette.name_of(surface),
						CWDecorRules.name_of(role)])
	_ok("chaque role atteignable a un modele sur sa surface", orphans.is_empty(),
			str(orphans))

	# Et l'inverse : un modele range sous un role que les cretes n'atteignent
	# pas ne sortira jamais. Le lot des 39 est clos ; aucun ne doit dormir.
	var unreachable: Array = []
	for surface in CWModelLibrary.ROLES:
		var reachable: Array = _reachable_roles(surface)
		for role in CWModelLibrary.ROLES[surface]:
			if not reachable.has(role):
				for path in CWModelLibrary.ROLES[surface][role]:
					unreachable.append(path)
	_ok("aucun modele n'est range sous un role inatteignable",
			unreachable.is_empty(), str(unreachable))

	# Chaque surface garnie a une densite, sinon elle ne recoit aucun candidat
	# et toute sa table est inerte.
	var no_density: Array = []
	for surface in CWDecorRules.FAMILIES:
		if CWModelLibrary.density_of(surface) <= 0.0:
			no_density.append(CWPalette.name_of(surface))
	_ok("chaque surface qui choisit a une densite", no_density.is_empty(),
			str(no_density))

	# Le rapport de taille est lu par role sans defaut utile : un role oublie
	# sortirait a 1,0 et sa taille d'origine serait perdue sans bruit.
	var no_ratio: Array = []
	for role in CWDecorRules.Role.values():
		if role == CWDecorRules.Role.AUCUN:
			continue
		if not CWDecorRules.SCALE_RATIO.has(role):
			no_ratio.append(CWDecorRules.name_of(role))
	_ok("chaque role a un rapport de taille", no_ratio.is_empty(), str(no_ratio))

	var lot: int = 0
	for surface in CWModelLibrary.flora():
		lot += CWModelLibrary.flora()[surface].size()
	print("     %d surfaces, %d roles, %d entrees de modele"
			% [CWModelLibrary.ROLES.size(), CWDecorRules.Role.size() - 1, lot])


# -- 2. La selection ----------------------------------------------------------

func _test_selection() -> void:
	print("[decor : la selection]")

	# Purete : la regle ne lit que la surface et le point. Elle est appelee
	# depuis huit fils a la fois, sans verrou, et un etat cache la rendrait
	# dependante de l'ordre de visite — le monde ne se regenererait plus a
	# l'identique, et rien ne le signalerait.
	var stable: bool = true
	for i in 200:
		var x: int = 8397830 + i * 37
		var a: int = CWDecorRules.role_at(CWPalette.GRASS, x, 8399776)
		CWDecorRules.role_at(CWPalette.SWAMP, x + 11, 12345)
		var b: int = CWDecorRules.role_at(CWPalette.GRASS, x, 8399776)
		if a != b:
			stable = false
			break
	_ok("la regle est pure : deux appels au meme point s'accordent", stable)

	# Une surface sans table ne doit pas se rabattre sur une autre : de l'eau,
	# de la glace ou de la terre nue restent nues.
	var silent: Array = []
	for surface in [CWPalette.AIR, CWPalette.WATER, CWPalette.WATER_DEEP,
			CWPalette.ICE, CWPalette.DIRT]:
		if CWDecorRules.role_at(surface, 8397830, 8399776) != CWDecorRules.Role.AUCUN:
			silent.append(CWPalette.name_of(surface))
	_ok("une surface sans table ne recoit rien", silent.is_empty(), str(silent))

	# La regle ne doit jamais sortir un role hors de la table de sa surface.
	var strays: Array = []
	for surface in CWDecorRules.FAMILIES:
		var reachable: Array = _reachable_roles(surface)
		for i in 500:
			var role: int = CWDecorRules.role_at(surface, 1000 + i * 911, 2000 + i * 613)
			if not reachable.has(role):
				strays.append("%s/%s" % [CWPalette.name_of(surface),
						CWDecorRules.name_of(role)])
				break
	_ok("aucun role hors de la table de sa surface", strays.is_empty(), str(strays))

	# Les deux cretes doivent etre deux champs, pas deux fois le meme : leurs
	# decalages different dans le binaire, et c'est ce qui fait que la seconde
	# dit quelque chose. Au meme decalage, elles seraient identiques et une
	# famille sur deux disparaitrait.
	var agree: int = 0
	var total: int = 0
	for i in 2000:
		var x: float = float(1000 + i * 97)
		var z: float = float(2000 + i * 131)
		var a: float = CWValueNoise.sample(x * CWDecorRules.SELECT_FREQ + CWDecorRules.SELECT_A_X,
				z * CWDecorRules.SELECT_FREQ + CWDecorRules.SELECT_A_Z)
		var b: float = CWValueNoise.sample(x * CWDecorRules.SELECT_FREQ + CWDecorRules.SELECT_B_X,
				z * CWDecorRules.SELECT_FREQ + CWDecorRules.SELECT_B_Z)
		total += 1
		if (a <= 0.0) == (b <= 0.0):
			agree += 1
	var rate: float = float(agree) / float(total)
	print("     les deux cretes s'accordent %.1f %% du temps (hasard : 50 %%)"
			% (rate * 100.0))
	_ok("les deux cretes sont deux champs distincts, pas deux fois le meme",
			rate > 0.35 and rate < 0.65, "%.3f" % rate)


# -- 3. La composition regionale ----------------------------------------------

func _test_composition() -> void:
	print("[decor : la composition]")

	# Une region entiere partage sa dominante — c'est la longueur d'onde 1/0,01,
	# soit une centaine de blocs — mais le monde entier ne doit pas etre d'un
	# seul role. On balaie assez loin pour changer de region plusieurs fois.
	var counts: Dictionary = {}
	var samples: int = 0
	for i in 4000:
		var role: int = CWDecorRules.role_at(CWPalette.GRASS,
				8397830 + i * 53, 8399776 + i * 29)
		counts[role] = int(counts.get(role, 0)) + 1
		samples += 1
	var names: Array = []
	for role in counts:
		names.append("%s %.1f %%" % [CWDecorRules.name_of(role),
				100.0 * float(counts[role]) / float(samples)])
	names.sort()
	print("     prairie sur 4 000 points : ", ", ".join(names))
	_ok("la prairie n'est pas d'un seul role", counts.size() >= 3,
			str(counts.size()))
	# Le role minoritaire de la seconde crete doit rester minoritaire : le seuil
	# biaise de la source (0,5) est ce qui garde les cailloux et les buissons
	# rares au milieu de l'herbe. Un seuil remis a zero les mettrait a parite.
	var biggest: float = 0.0
	for role in counts:
		biggest = maxf(biggest, float(counts[role]) / float(samples))
	_ok("un role domine, les autres l'accompagnent", biggest > 0.3,
			"le plus frequent fait %.1f %%" % (biggest * 100.0))

	# La rarete du role rare : elle est empilee sur la crete de placement dans
	# la source, et c'est la seule fois. Verifie sur la regle elle-meme, pas sur
	# la flore posee — une plante rare ne sort pas assez souvent pour se mesurer
	# sur quelques centaines de cellules.
	_ok("le role rare est a 1 sur 100",
			CWDecorRules.rarity_of(CWDecorRules.Role.RARE) == CWDecorRules.RARITY_RARE)
	var others_free: bool = true
	for role in CWDecorRules.Role.values():
		if role == CWDecorRules.Role.RARE or role == CWDecorRules.Role.AUCUN:
			continue
		if CWDecorRules.rarity_of(role) != 1:
			others_free = false
	_ok("les autres roles n'empilent pas de seconde rarete", others_free)


## Les roles que les deux cretes peuvent atteindre sur une surface.
func _reachable_roles(surface: int) -> Array:
	var out: Array = []
	for branch in CWDecorRules.FAMILIES.get(surface, []):
		for role in branch:
			if not out.has(role):
				out.append(role)
	return out
