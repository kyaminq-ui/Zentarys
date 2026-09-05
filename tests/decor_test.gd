class_name CWDecorTest
extends RefCounted

## Verifications de la regle de selection du decor (`CWDecorRules`, jalons 1.7
## et 1.12).
##
## Ce que ces verifications tiennent, et pourquoi elles ne sont pas dans
## `flora_test.gd` : celui-ci mesure la dispersion — combien, ou, a quelle
## taille. Celui-la mesure le *choix* — quel role, dans quel biome, a quelle
## rarete. Les deux se cassent independamment, et le second casse en silence :
## un role selectionne dans un biome qui n'a pas de modele pour lui ne leve
## rien, il fait juste disparaitre une plante sur quatre sans que la densite
## moyenne bouge assez pour se voir.
##
## Depuis le jalon 1.12 la cle est le **biome** et non la matiere de surface, et
## deux verifications de plus en decoulent : les deux exceptions par matiere
## doivent trouver leurs modeles dans le biome qui les produit, et le filtre de
## matiere doit refuser la roche nue sans refuser la neige de Snowlands.

var _t: Object


func run(harness: Object) -> void:
	_t = harness
	_test_tables()
	_test_selection()
	_test_matiere()
	_test_composition()


func _ok(label: String, condition: bool, detail: String = "") -> void:
	_t._ok(label, condition, detail)


# -- 1. Les tables se repondent -----------------------------------------------

func _test_tables() -> void:
	print("[decor : les tables]")

	# Tout biome qui sait choisir doit savoir poser, et inversement. Un biome
	# present d'un seul cote est une entree morte : soit un role sans modele
	# (une plante sur quatre qui disparait), soit des modeles charges que rien
	# ne selectionnera jamais.
	var only_families: Array = []
	for biome in CWDecorRules.FAMILIES:
		if not CWModelLibrary.ROLES.has(biome):
			only_families.append(CWBiome.name_of(biome))
	_ok("chaque biome qui choisit sait poser", only_families.is_empty(),
			str(only_families))

	var only_roles: Array = []
	for biome in CWModelLibrary.ROLES:
		if not CWDecorRules.FAMILIES.has(biome):
			only_roles.append(CWBiome.name_of(biome))
	_ok("chaque biome qui pose sait choisir", only_roles.is_empty(),
			str(only_roles))

	# Les six biomes sont couverts : un biome oublie de la table serait un
	# sixieme du monde sans une plante, et la seule chose qui le dirait serait
	# une capture.
	var missing: Array = []
	for biome in CWBiome.all():
		if not CWDecorRules.FAMILIES.has(biome):
			missing.append(CWBiome.name_of(biome))
	_ok("les six biomes ont une table", missing.is_empty(), str(missing))

	# Le point qui casse en silence : un role atteignable par les deux cretes
	# mais sans modele dans ce biome.
	var orphans: Array = []
	for biome in CWDecorRules.FAMILIES:
		for role in _reachable_roles(CWDecorRules.FAMILIES[biome]):
			var models: Array = CWModelLibrary.ROLES.get(biome, {}).get(role, [])
			if models.is_empty():
				orphans.append("%s/%s" % [CWBiome.name_of(biome),
						CWDecorRules.name_of(role)])
	_ok("chaque role atteignable a un modele dans son biome", orphans.is_empty(),
			str(orphans))

	# Les deux exceptions par matiere : leurs roles doivent avoir un modele dans
	# le biome qui produit la matiere. C'est le meme trou que ci-dessus, deplace
	# d'un cran — et il serait plus discret encore, une rive de jungle nue ne se
	# voyant que de pres.
	var orphans_surface: Array = []
	for surface in CWDecorRules.FAMILIES_SURFACE:
		var biome: int = int(CWDecorRules.FAMILIES_SURFACE_BIOME.get(surface, -1))
		_ok("la matiere %s declare son biome" % CWPalette.name_of(surface),
				biome >= 0)
		for role in _reachable_roles(CWDecorRules.FAMILIES_SURFACE[surface]):
			var models: Array = CWModelLibrary.ROLES.get(biome, {}).get(role, [])
			if models.is_empty():
				orphans_surface.append("%s/%s" % [CWPalette.name_of(surface),
						CWDecorRules.name_of(role)])
	_ok("chaque exception de matiere trouve ses modeles",
			orphans_surface.is_empty(), str(orphans_surface))

	# Et l'inverse : un modele range sous un role que les cretes n'atteignent
	# pas ne sortira jamais. Les roles d'une exception comptent comme
	# atteignables dans le biome qui la produit.
	var unreachable: Array = []
	for biome in CWModelLibrary.ROLES:
		var reachable: Array = _reachable_roles(CWDecorRules.FAMILIES.get(biome, []))
		for surface in CWDecorRules.FAMILIES_SURFACE:
			if int(CWDecorRules.FAMILIES_SURFACE_BIOME.get(surface, -1)) != biome:
				continue
			for role in _reachable_roles(CWDecorRules.FAMILIES_SURFACE[surface]):
				if not reachable.has(role):
					reachable.append(role)
		for role in CWModelLibrary.ROLES[biome]:
			if not reachable.has(role):
				for path in CWModelLibrary.ROLES[biome][role]:
					unreachable.append(path)
	_ok("aucun modele n'est range sous un role inatteignable",
			unreachable.is_empty(), str(unreachable))

	# Chaque biome garni a une densite, sinon il ne recoit aucun candidat et
	# toute sa table est inerte.
	var no_density: Array = []
	for biome in CWDecorRules.FAMILIES:
		if CWModelLibrary.density_of(biome) <= 0.0:
			no_density.append(CWBiome.name_of(biome))
	_ok("chaque biome qui choisit a une densite", no_density.is_empty(),
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
	for biome in CWModelLibrary.flora():
		lot += CWModelLibrary.flora()[biome].size()
	print("     %d biomes, %d roles, %d entrees de modele"
			% [CWModelLibrary.ROLES.size(), CWDecorRules.Role.size() - 1, lot])


# -- 2. La selection ----------------------------------------------------------

func _test_selection() -> void:
	print("[decor : la selection]")

	# Purete : la regle ne lit que le biome, la matiere et le point. Elle est
	# appelee depuis huit fils a la fois, sans verrou, et un etat cache la
	# rendrait dependante de l'ordre de visite — le monde ne se regenererait
	# plus a l'identique, et rien ne le signalerait.
	var stable: bool = true
	for i in 200:
		var x: int = 8397830 + i * 37
		var a: int = CWDecorRules.role_at(CWBiome.GREENLANDS, CWPalette.GRASS,
				x, 8399776)
		CWDecorRules.role_at(CWBiome.JUNGLES, CWPalette.SWAMP, x + 11, 12345)
		var b: int = CWDecorRules.role_at(CWBiome.GREENLANDS, CWPalette.GRASS,
				x, 8399776)
		if a != b:
			stable = false
			break
	_ok("la regle est pure : deux appels au meme point s'accordent", stable)

	# Un biome sans table ne doit pas se rabattre sur un autre.
	_ok("un biome inconnu ne recoit rien",
			CWDecorRules.role_at(999, CWPalette.GRASS, 8397830, 8399776)
					== CWDecorRules.Role.AUCUN)

	# L'exception de matiere passe **avant** le biome : sur le sol humide d'une
	# jungle, c'est la table du sol humide qui parle, et elle est la seule a
	# porter le roseau. Verifie en cherchant le roseau, qu'aucune table de biome
	# ne peut rendre.
	var reed_seen: bool = false
	var reed_elsewhere: bool = false
	for i in 400:
		var x: int = 1000 + i * 911
		var z: int = 2000 + i * 613
		if CWDecorRules.role_at(CWBiome.JUNGLES, CWPalette.SWAMP, x, z) \
				== CWDecorRules.Role.ROSEAU:
			reed_seen = true
		if CWDecorRules.role_at(CWBiome.JUNGLES, CWPalette.GRASS_JUNGLE, x, z) \
				== CWDecorRules.Role.ROSEAU:
			reed_elsewhere = true
	_ok("le sol humide porte le roseau", reed_seen)
	_ok("le roseau ne sort pas ailleurs qu'au sol humide", not reed_elsewhere)

	# La regle ne doit jamais sortir un role hors de la table qui l'a decide.
	var strays: Array = []
	for biome in CWDecorRules.FAMILIES:
		var reachable: Array = _reachable_roles(CWDecorRules.FAMILIES[biome])
		for i in 500:
			# Une matiere neutre : celle du biome, sans exception attachee.
			var role: int = CWDecorRules.role_at(biome, CWPalette.STONE,
					1000 + i * 911, 2000 + i * 613)
			if not reachable.has(role):
				strays.append("%s/%s" % [CWBiome.name_of(biome),
						CWDecorRules.name_of(role)])
				break
	_ok("aucun role hors de la table de son biome", strays.is_empty(), str(strays))

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


# -- 3. Le filtre de matiere --------------------------------------------------

func _test_matiere() -> void:
	print("[decor : la matiere]")

	# Ce filtre est ce qui remplace l'ancienne table par matiere. Il doit
	# refuser ce qui est nu par nature et laisser passer le reste.
	var nues: Array = [CWPalette.STONE, CWPalette.MAGMA, CWPalette.WATER,
			CWPalette.WATER_DEEP]
	var laisse_passer: Array = []
	for surface in nues:
		for biome in CWBiome.all():
			if CWDecorRules.decor_allowed(biome, surface):
				laisse_passer.append("%s/%s" % [CWBiome.name_of(biome),
						CWPalette.name_of(surface)])
	_ok("rien ne pousse sur la roche, le magma ni l'eau",
			laisse_passer.is_empty(), str(laisse_passer))

	# La neige est le cas a deux sens : sol de Snowlands, calotte de sommet
	# partout ailleurs. Confondre les deux couvrirait les cretes de Greenlands
	# de bleuets, ce qu'aucun test headless ne verrait autrement.
	_ok("la neige de Snowlands porte du decor",
			CWDecorRules.decor_allowed(CWBiome.SNOWLANDS, CWPalette.SNOW))
	var cimes_nues: bool = true
	for biome in CWBiome.all():
		if biome == CWBiome.SNOWLANDS:
			continue
		if CWDecorRules.decor_allowed(biome, CWPalette.SNOW):
			cimes_nues = false
	_ok("la calotte de sommet des autres biomes reste nue", cimes_nues)

	# Les matieres de plaine passent, sans quoi le monde entier serait nu.
	var plaines: Array = [CWPalette.GRASS, CWPalette.GRASS_DRY,
			CWPalette.GRASS_JUNGLE, CWPalette.SWAMP, CWPalette.SAND,
			CWPalette.TUNDRA, CWPalette.GRAVEL, CWPalette.SCORIA]
	var refusees: Array = []
	for surface in plaines:
		if not CWDecorRules.decor_allowed(CWBiome.GREENLANDS, surface):
			refusees.append(CWPalette.name_of(surface))
	_ok("les matieres de plaine portent du decor", refusees.is_empty(),
			str(refusees))


# -- 4. La composition regionale ----------------------------------------------

func _test_composition() -> void:
	print("[decor : la composition]")

	# Une region entiere partage sa dominante — c'est la longueur d'onde 1/0,01,
	# soit une centaine de blocs — mais le monde entier ne doit pas etre d'un
	# seul role. On balaie assez loin pour changer de region plusieurs fois.
	var counts: Dictionary = {}
	var samples: int = 0
	for i in 4000:
		var role: int = CWDecorRules.role_at(CWBiome.GREENLANDS, CWPalette.GRASS,
				8397830 + i * 53, 8399776 + i * 29)
		counts[role] = int(counts.get(role, 0)) + 1
		samples += 1
	var names: Array = []
	for role in counts:
		names.append("%s %.1f %%" % [CWDecorRules.name_of(role),
				100.0 * float(counts[role]) / float(samples)])
	names.sort()
	print("     Greenlands sur 4 000 points : ", ", ".join(names))
	_ok("Greenlands n'est pas d'un seul role", counts.size() >= 3,
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


## Les roles que les deux cretes peuvent atteindre dans une table de familles.
func _reachable_roles(families: Array) -> Array:
	var out: Array = []
	for branch in families:
		for role in branch:
			if not out.has(role):
				out.append(role)
	return out
