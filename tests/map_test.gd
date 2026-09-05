class_name CWMapTest
extends RefCounted

## Verifications de la carte du monde (jalon 1.10) : `CWWorldMap` et
## `CWRegionName`. Analyse : `docs/systems/05`.
##
## Pilote par tests/worldgen_test.gd, qui tient le compte des verifications :
##   CWMapTest.new().run(self)
##
## Ce qui est verrouille ici :
##   * l'echelle de la carte — une case vaut 256 unites, 64 par zone, 65 536 de
##     cote. C'est la troisieme lecture independante de la meme echelle, et si
##     elle bouge, la carte cesse de decrire le monde qu'on genere ;
##   * les trois clartes 200 / 220 / 255, relevees verbatim ;
##   * la geometrie du puzzle : une case appartient a la region dont le site est
##     le plus proche **dans le domaine deforme**. C'est ce qui distingue cette
##     carte d'un quadrillage de zones, et c'est invisible sur une image ;
##   * la formule de nom, y compris son croisement.

const SEED: int = 2024

var _runner: Object
var _params: CWWorldParams
var _field: CWTerrainField
var _map: CWWorldMap


func run(runner: Object) -> void:
	_runner = runner
	_params = CWWorldParams.new()
	_params.world_seed = SEED
	_field = CWTerrainField.new(_params)
	_map = CWWorldMap.new(_field)
	_test_scale()
	_test_discovery()
	_test_persistence()
	_test_slab()
	_test_render()
	_test_names()
	_bench()


func _ok(label: String, condition: bool, detail: String = "") -> void:
	_runner._ok(label, condition, detail)


# -- 1. L'echelle -------------------------------------------------------------

func _test_scale() -> void:
	print("[carte : l'echelle]")

	# `WorldMap::getTile` borne ses deux coordonnees a [0, 0x10000) pour un monde
	# de 0x1000000 unites : une case vaut 256 unites, soit un chunk.
	_ok("une case vaut 256 unites", CWWorldMap.CHUNK_SIZE == 256)
	_ok("64 cases par zone", CWWorldMap.CHUNKS_PER_ZONE == 64)
	_ok("grille de cases de 0x10000 de cote", CWWorldMap.CHUNK_GRID == 0x10000)
	_ok("la grille de cases couvre le monde entier",
			CWWorldMap.CHUNK_GRID * CWWorldMap.CHUNK_SIZE == CWWorldParams.WORLD_SIZE,
			str(CWWorldMap.CHUNK_GRID * CWWorldMap.CHUNK_SIZE))
	_ok("une zone fait bien 64 cases",
			CWWorldMap.CHUNKS_PER_ZONE * CWWorldMap.CHUNK_SIZE == CWWorldParams.ZONE_SIZE)

	# Les trois clartes de `loadLandscapeTile`, relevees verbatim. Elles ne sont
	# pas un choix d'affichage : ce sont les seules valeurs que l'image d'origine
	# porte, et elle n'en porte aucune autre.
	_ok("clarte inconnue = 200", CWWorldMap.SHADE_UNKNOWN == 200)
	_ok("clarte connue = 220", CWWorldMap.SHADE_KNOWN == 220)
	_ok("clarte decouverte = 255", CWWorldMap.SHADE_DISCOVERED == 255)

	var x: int = 8_398_000
	_ok("chunk_of coincide avec un decalage de 8",
			CWWorldMap.chunk_of(x) == x >> 8)
	_ok("la case retombe dans sa zone",
			CWWorldMap.zone_of_chunk(CWWorldMap.chunk_of(x)) == CWWorldParams.zone_of(x),
			"%d contre %d" % [CWWorldMap.zone_of_chunk(CWWorldMap.chunk_of(x)),
					CWWorldParams.zone_of(x)])
	_ok("les cases hors monde sont refusees",
			not CWWorldMap.in_world(-1, 0)
			and not CWWorldMap.in_world(0, CWWorldMap.CHUNK_GRID)
			and CWWorldMap.in_world(0, 0))


# -- 2. La decouverte ---------------------------------------------------------

func _test_discovery() -> void:
	print("[carte : la decouverte]")
	var m := CWWorldMap.new(_field)
	var x: int = _params.start_point.x
	var z: int = _params.start_point.y
	var cx: int = CWWorldMap.chunk_of(x)
	var cz: int = CWWorldMap.chunk_of(z)

	_ok("une case vierge est inconnue",
			m.shade_at(cx, cz) == CWWorldMap.SHADE_UNKNOWN)
	_ok("la premiere decouverte compte", m.discover(x, z))
	_ok("la seconde ne compte pas", not m.discover(x, z))
	_ok("le compteur suit", m.discovered_count == 1, str(m.discovered_count))
	_ok("la case est decouverte",
			m.shade_at(cx, cz) == CWWorldMap.SHADE_DISCOVERED)

	# Une case seulement connue reste au gris clair : c'est le second bit de
	# drapeau, celui que pose le chargement et non le passage du joueur.
	_ok("une case connue n'est pas decouverte", m.mark_known_chunk(cx + 4, cz))
	_ok("connue mais pas decouverte",
			m.shade_at(cx + 4, cz) == CWWorldMap.SHADE_KNOWN
			and not m.is_discovered(cx + 4, cz))
	_ok("le compteur ne bouge pas pour une case connue", m.discovered_count == 1)

	# `visit` : on decouvre la ou on est, on connait ce qu'on voit.
	m.visit(x, z, 1024)
	_ok("visiter connait le voisinage",
			m.is_known(cx + 4, cz) and m.is_known(cx - 4, cz + 4)
			and not m.is_known(cx + 5, cz))
	_ok("visiter ne decouvre que la case du joueur",
			m.discovered_count == 1, str(m.discovered_count))
	_ok("une case hors monde est refusee sans compter",
			not m.discover_chunk(-1, 0) and m.discovered_count == 1)


func _test_persistence() -> void:
	print("[carte : la persistance]")
	var m := CWWorldMap.new(_field)
	for i in 200:
		m.discover_chunk(32768 + i, 32768 + i * 3)
	m.mark_known_chunk(1, 1)
	var path: String = "user://test_map_discovery.dat"
	var t0: int = Time.get_ticks_usec()
	_ok("ecriture", m.save_discovery(path) == OK)
	var write_us: int = Time.get_ticks_usec() - t0

	var back := CWWorldMap.new(_field)
	_ok("relecture", back.load_discovery(path) == OK)
	_ok("le compteur revient", back.discovered_count == 200,
			str(back.discovered_count))
	_ok("les cases reviennent",
			back.is_discovered(32768, 32768) and back.is_discovered(32967, 33365)
			and not back.is_discovered(32767, 32768))
	_ok("les cases seulement connues reviennent aussi",
			back.is_known(1, 1) and not back.is_discovered(1, 1))
	print("     201 cases ecrites en %.2f ms, fichier de %d o" % [
			float(write_us) / 1000.0, FileAccess.get_file_as_bytes(path).size()])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	var empty := CWWorldMap.new(_field)
	_ok("un fichier absent se signale",
			empty.load_discovery("user://pas_de_carte.dat") == ERR_FILE_NOT_FOUND)


# -- 3. La geometrie du puzzle ------------------------------------------------

func _test_slab() -> void:
	print("[carte : le puzzle]")
	var zx: int = CWWorldParams.zone_of(_params.start_point.x)
	var zz: int = CWWorldParams.zone_of(_params.start_point.y)
	var s: CWWorldMap.Slab = _map.slab(zx, zz)

	_ok("la dalle porte 64 x 64 cases",
			s.owners.size() == 64 * 64, str(s.owners.size()))
	_ok("la dalle est memoisee", _map.slab(zx, zz) == s)

	# Chaque case doit citer la region dont le site est le plus proche du point
	# **deforme** — pas la zone qui la contient. Verification par le chemin long,
	# celui du champ de terrain.
	var mismatches: int = 0
	for i in 64:
		var cx: int = zx * 64 + (i * 7) % 64
		var cz: int = zz * 64 + (i * 11) % 64
		var site: CWRegionSite = _field.nearest_site(cx << 8, cz << 8)
		var want: int = (CWWorldParams.zone_of(site.x) * CWWorldParams.ZONE_GRID
				+ CWWorldParams.zone_of(site.z))
		if s.owner_at(cx - zx * 64, cz - zz * 64) != want:
			mismatches += 1
	_ok("chaque case cite le site le plus proche du point deforme",
			mismatches == 0, "%d ecarts" % mismatches)

	# Le point qui vaut la peine : la dalle d'une zone n'appartient pas entiere
	# a cette zone. Si elle l'etait, la carte serait un quadrillage et toute la
	# geometrie de l'original serait perdue sans qu'aucun test ne bronche.
	var own_key: int = zx * CWWorldParams.ZONE_GRID + zz
	var own_zone: int = 0
	var foreign: int = 0
	for o: int in s.owners:
		if o == own_key:
			own_zone += 1
		elif o != CWWorldMap.NO_OWNER:
			foreign += 1
	_ok("la dalle deborde sur d'autres regions",
			foreign > 0, "%d cases sur 4096 hors de la zone" % foreign)
	_ok("la dalle appartient surtout a sa propre region",
			own_zone > foreign, "%d contre %d" % [own_zone, foreign])

	var zones_seen: int = s.zones.size()
	_ok("la dalle recense les regions qu'elle touche",
			zones_seen >= 1 and zones_seen <= 9, str(zones_seen))

	# Les pieces pavent le plan : deux dalles voisines s'accordent sur leur
	# frontiere commune, puisque le proprietaire ne depend que de la case.
	var right: CWWorldMap.Slab = _map.slab(zx + 1, zz)
	var seam: int = 0
	for cz in 64:
		var site: CWRegionSite = _field.nearest_site(((zx + 1) * 64) << 8,
				(zz * 64 + cz) << 8)
		var want: int = (CWWorldParams.zone_of(site.x) * CWWorldParams.ZONE_GRID
				+ CWWorldParams.zone_of(site.z))
		if right.owner_at(0, cz) != want:
			seam += 1
	_ok("deux dalles voisines s'accordent sur la couture", seam == 0,
			"%d desaccords" % seam)


# -- 4. Le rendu --------------------------------------------------------------

func _test_render() -> void:
	print("[carte : le rendu]")
	var zx: int = CWWorldParams.zone_of(_params.start_point.x) - 1
	var zz: int = CWWorldParams.zone_of(_params.start_point.y) - 1
	var t0: int = Time.get_ticks_usec()
	var img: Image = _map.render(zx, zz, 3, 3)
	var us: int = Time.get_ticks_usec() - t0

	_ok("l'image fait une case par pixel",
			img.get_width() == 3 * 64 and img.get_height() == 3 * 64,
			"%d x %d" % [img.get_width(), img.get_height()])

	# Une carte entierement vierge doit etre sombre et sans trou : les trois
	# clartes s'appliquent a la teinte, elles ne la remplacent pas.
	var opaque: int = 0
	var distinct: Dictionary = {}
	for py in img.get_height():
		for px in img.get_width():
			var c: Color = img.get_pixel(px, py)
			if c.a > 0.5:
				opaque += 1
				distinct[c.to_rgba32()] = true
	_ok("toutes les cases du monde sont peintes",
			opaque == 3 * 64 * 3 * 64, str(opaque))
	_ok("plusieurs regions se distinguent a l'oeil",
			distinct.size() >= 3, "%d couleurs" % distinct.size())

	# La decouverte doit se voir : la meme case, decouverte, s'eclaircit.
	var probe := Vector2i(96, 96)
	var before: Color = img.get_pixel(probe.x, probe.y)
	_map.visit((zx * 64 + probe.x) << 8, (zz * 64 + probe.y) << 8, 0)
	var after: Color = _map.render(zx, zz, 3, 3).get_pixel(probe.x, probe.y)
	_ok("une case decouverte s'eclaircit",
			after.get_luminance() > before.get_luminance(),
			"%.3f -> %.3f" % [before.get_luminance(), after.get_luminance()])
	_ok("le rapport des clartes est celui de l'original",
			absf(after.get_luminance() / maxf(before.get_luminance(), 1e-6)
					- 255.0 / 200.0) < 0.02,
			"%.4f" % (after.get_luminance() / maxf(before.get_luminance(), 1e-6)))

	print("     vue de 3 x 3 zones (192^2 cases) rendue en %.1f ms, %d dalles" % [
			float(us) / 1000.0, _map.slab_count()])

	# Marqueurs : ils viennent des elements de tuile du jalon 1.6, et chaque
	# region porte au moins son icone de relief.
	var marks: Array = _map.render_markers(zx, zz, 3, 3)
	var icons: Dictionary = {}
	var out_of_frame: int = 0
	for m: Dictionary in marks:
		icons[m["icon"]] = int(icons.get(m["icon"], 0)) + 1
		var p: Vector2i = m["pixel"]
		if p.x < -64 or p.y < -64 or p.x > 256 or p.y > 256:
			out_of_frame += 1
	_ok("chaque region pose son icone de relief",
			marks.size() >= 9, "%d marqueurs" % marks.size())
	_ok("les marqueurs tombent dans le cadre", out_of_frame == 0,
			"%d hors cadre" % out_of_frame)
	_ok("les villages viennent des elements de tuile",
			icons.has(CWWorldMap.ICON_VILLAGE),
			str(icons))


# -- 5. Les noms --------------------------------------------------------------

func _test_names() -> void:
	print("[carte : les noms]")
	var n: CWRegionName = _map.names()

	_ok("deux tables de vingt",
			CWRegionName.PREFIX.size() == CWRegionName.TABLE_SIZE
			and CWRegionName.SUFFIX.size() == CWRegionName.TABLE_SIZE)

	var x: int = _params.start_point.x
	var z: int = _params.start_point.y
	var name: String = n.at(x, z)
	_ok("un nom est produit", name.length() >= 4, name)
	_ok("il est capitalise", name[0] == name[0].to_upper(), name)
	_ok("le nom est deterministe", n.at(x, z) == name)

	# Deux mondes, deux jeux de graines de nom : la carte d'une autre partie ne
	# doit pas porter les memes noms aux memes endroits.
	var other := CWRegionName.new(CWTerrainField.new(_other_params()))
	_ok("les graines de nom dependent du monde", other.seeds() != n.seeds(),
			"%s contre %s" % [other.seeds(), n.seeds()])

	# La formule, verifiee a la main sur la cellule du point : c'est le
	# croisement des deux indices qui est porteur (a puis b, b puis a), et une
	# symetrisation par etourderie donnerait le meme nom aux deux diagonales.
	var cell: Vector2i = n.cell_of(x, z)
	var s: Vector2i = n.seeds()
	var i: int = posmod(cell.x * 3 + s.x + cell.y, 20)
	var j: int = posmod(cell.y * 3 + s.y + cell.x, 20)
	var want: String = CWRegionName.PREFIX[i] + CWRegionName.SUFFIX[j]
	_ok("le nom suit la formule d'origine",
			name.to_lower() == want, "%s contre %s" % [name.to_lower(), want])

	# Le nom est constant sur une cellule du domaine **deforme**, pas sur la
	# grille de zones : c'est tout l'interet de passer par la deformation.
	var same_cell: int = 0
	var same_name: int = 0
	var zone_x: int = CWWorldParams.zone_of(x)
	for k in 200:
		var px: int = zone_x * CWWorldParams.ZONE_SIZE + k * 80
		var pz: int = z
		if n.cell_of(px, pz) == cell:
			same_cell += 1
			if n.at(px, pz) == name:
				same_name += 1
	_ok("un nom couvre exactement une cellule deformee",
			same_cell == same_name and same_cell > 0,
			"%d / %d" % [same_name, same_cell])

	# Les frontieres de noms ondulent : sur une ligne droite de zone en zone, on
	# ne change pas de nom pile aux multiples de 16 384.
	var straight: bool = true
	for k in 40:
		var px: int = zone_x * CWWorldParams.ZONE_SIZE + k * 400
		if n.cell_of(px, z).x != CWWorldParams.zone_of(px):
			straight = false
			break
	_ok("la frontiere des noms n'est pas celle des zones", not straight)

	# Le nom d'une region est ancre a son site : une pièce entiere porte un nom.
	var zone: Vector2i = Vector2i(CWWorldParams.zone_of(x), CWWorldParams.zone_of(z))
	var zone_name: String = n.of_zone(zone.x, zone.y)
	var site: CWRegionSite = _field.sites().get_site(zone.x, zone.y)
	_ok("le nom d'une zone est celui de son site",
			zone_name == n.at(site.x, site.z), zone_name)
	_ok("une zone hors grille n'a pas de nom", n.of_zone(-1, 0) == "")

	# Diversite : 400 combinaisons possibles, on doit en voir beaucoup sur un
	# echantillon large. Un nom unique partout serait le symptome d'un indice
	# qui ne varie pas.
	var seen: Dictionary = {}
	for a in 20:
		for b in 20:
			seen[n.of_zone(zone.x + a * 3, zone.y + b * 3)] = true
	_ok("les noms se diversifient", seen.size() >= 80, "%d noms" % seen.size())


func _other_params() -> CWWorldParams:
	var p := CWWorldParams.new()
	p.world_seed = SEED + 1
	return p


# -- 6. Le cout ---------------------------------------------------------------

func _bench() -> void:
	print("[carte : le cout]")
	var m := CWWorldMap.new(_field)
	var zx: int = CWWorldParams.zone_of(_params.start_point.x) + 4
	var zz: int = CWWorldParams.zone_of(_params.start_point.y) + 4
	var t0: int = Time.get_ticks_usec()
	m.slab(zx, zz)
	var slab_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0

	t0 = Time.get_ticks_usec()
	for i in 5000:
		m.names().at(8_398_000 + i * 137, 8_399_000 + i * 71)
	var name_us: float = float(Time.get_ticks_usec() - t0) / 5000.0

	print("     dalle de 4 096 cases : %.1f ms   nom : %.2f us" % [slab_ms, name_us])
	# La dalle est construite sur un fil du pool ; le seuil ne verrouille qu'un
	# ordre de grandeur, pour attraper une regression qui la ferait exploser.
	_ok("une dalle reste sous 250 ms", slab_ms < 250.0, "%.1f ms" % slab_ms)
	_ok("un nom reste sous 50 us", name_us < 50.0, "%.2f us" % name_us)
