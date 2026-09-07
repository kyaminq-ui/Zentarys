extends SceneTree

## Ce que coute le **maillage** du terrain, en sommets et en octets
## (2026-09-11).
##
##   godot --headless --path . -s tools/profile_mesh.gd
##   godot --headless --path . -s tools/profile_mesh.gd -- 12 2024
##
## Arguments optionnels : cote de l'empreinte en paves de 16, graine.
## **Fermer l'editeur d'abord** : une autre instance de Godot en fond fausse les
## temps d'un facteur un et demi (elle ne fausse pas les comptes de sommets).
##
## -- La question a laquelle ce fichier repond ---------------------------------
##
## Le maillage glouton ne fusionne que des faces **de meme couleur**. Or
## l'invariant n. 45 donne deliberement des **teintes differentes a deux blocs de
## la meme matiere** : trois tons pour une prairie, cinq marches de fondu au bord
## d'une plage, et le degrade adouci du 2026-09-08 par-dessus. *Le tramage
## travaille donc contre le maillage glouton*, et personne n'avait mesure ce
## qu'il lui coute.
##
## C'est un arbitrage **rendu contre memoire**, et il ne se tranche qu'avec le
## chiffre en main — d'ou cet outil.
##
## -- Comment on mesure « sans tramage » sans toucher au generateur -----------
##
## `SHADE_STEPS` et `SHADE_TONE_STEPS` sont des constantes, et les rendre
## reglables mettrait une branche sur le chemin chaud pour une mesure. On fait
## donc autrement : on genere le pave **normalement**, puis on repeint son canal
## de rendu avec la couleur **plate** de chaque type (`CWPalette.raw_of`) avant
## de le mailler. C'est exactement le monde d'avant le 2026-09-07, et ca ne
## demande pas une ligne dans le generateur.
##
## Le troisieme point de comparaison est le maillage **non glouton**, qui dit ce
## que la fusion achete aujourd'hui — sans lui, on ne sait pas si le tramage
## coute peu parce qu'il est inoffensif ou parce que la fusion ne marchait deja
## pas.

const DEFAULT_COTE: int = 10
const BLOC: int = 16


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var cote: int = int(args[0]) if args.size() > 0 else DEFAULT_COTE
	var p := CWWorldParams.new()
	p.world_seed = int(args[1]) if args.size() > 1 else 2024

	var g := CWVoxelGenerator.new()
	g.params = p

	var glouton: VoxelMesherCubes = CWPalette.build_cubes_mesher()
	var brut: VoxelMesherCubes = CWPalette.build_cubes_mesher()
	brut.greedy_meshing_enabled = false
	var pad: int = glouton.get_minimum_padding()
	var n: int = BLOC + pad * 2

	print("=== le maillage, poste par poste ===")
	print("graine %d, empreinte de %d x %d paves de %d, marge de mailleur %d"
			% [p.world_seed, cote, cote, BLOC, pad])
	print("")

	var mat: Material = CWPalette.build_opaque_material()
	var somme_t: int = 0        # sommets, monde trame (celui du jeu)
	var somme_plat: int = 0     # sommets, couleur plate par type
	var somme_brut: int = 0     # sommets, sans fusion gloutonne
	var paves: int = 0
	var vides: int = 0
	var voxels_pleins: int = 0
	var t_mesh: int = 0

	# L'empreinte est centree sur le point de depart, et on prend la **pile
	# verticale qui traverse la surface** : un pave entierement enterre ou
	# entierement en l'air ne porte aucune face, donc il ne dit rien du
	# maillage. C'est la surface qui coute.
	var ox: int = -(cote / 2) * BLOC
	var oz: int = -(cote / 2) * BLOC
	for iz in cote:
		for ix in cote:
			var bx: int = ox + ix * BLOC
			var bz: int = oz + iz * BLOC
			var sol: float = g.field().sample_column(
					p.world_origin.x + bx + 8, p.world_origin.y + bz + 8).x
			@warning_ignore("integer_division")
			var by: int = (floori(sol) >> 4) << 4
			for k in range(-1, 2):
				var buf := VoxelBuffer.new()
				buf.set_channel_depth(CWPalette.CHANNEL_COLOR,
						CWPalette.COLOR_DEPTH)
				buf.create(n, n, n)
				g._generate_block(buf, Vector3i(bx - pad, by + k * BLOC - pad,
						bz - pad), 0)
				paves += 1

				var pleins: int = 0
				for y in n:
					for z in n:
						for x in n:
							if buf.get_voxel(x, y, z,
									CWPalette.CHANNEL_TYPE) != CWPalette.AIR:
								pleins += 1
				voxels_pleins += pleins

				var t0: int = Time.get_ticks_usec()
				var m: ArrayMesh = glouton.build_mesh(buf, [mat, mat], {}) as ArrayMesh
				t_mesh += Time.get_ticks_usec() - t0
				var v: int = _sommets(m)
				somme_t += v
				if v == 0:
					vides += 1

				somme_brut += _sommets(
						brut.build_mesh(buf, [mat, mat], {}) as ArrayMesh)

				_aplatis(buf, n)
				somme_plat += _sommets(
						glouton.build_mesh(buf, [mat, mat], {}) as ArrayMesh)

	var utiles: int = paves - vides
	print("[les paves]")
	print("  %d paves de 16^3, dont %d sans une face" % [paves, vides])
	print("  %d voxels pleins, soit %.1f %% du volume"
			% [voxels_pleins, 100.0 * float(voxels_pleins)
					/ float(paves * n * n * n)])
	print("")
	print("[les sommets, sur les %d paves qui portent une surface]" % utiles)
	_ligne("le monde tel qu'il est (trame, glouton)", somme_t, somme_t, utiles)
	_ligne("couleur plate par type (glouton)", somme_plat, somme_t, utiles)
	_ligne("trame, sans fusion gloutonne", somme_brut, somme_t, utiles)
	print("")

	# -- Ce que ca fait en memoire -------------------------------------------
	#
	# Un sommet de `VoxelMesherCubes` porte une position, une normale et une
	# couleur. Godot ne dit pas son format exact ici, et le compter serait le
	# deviner : on donne donc la **borne basse** — position en 3 x 4 octets,
	# normale en 4, couleur en 4 — plus l'index, qui est un entier de 4 octets
	# pour six par quad. C'est un ordre de grandeur, et il est annonce comme tel.
	var par_sommet: int = 12 + 4 + 4
	print("[l'ordre de grandeur en memoire]")
	print("  ~%d octets par sommet (position, normale, couleur)" % par_sommet)
	_memoire("le monde tel qu'il est", somme_t, par_sommet, utiles)
	_memoire("couleur plate par type", somme_plat, par_sommet, utiles)
	print("")
	print("  Pour une vue de 384 blocs : (2 x 384 / 16)^2 = 2 304 colonnes de")
	print("  paves. En comptant trois paves de surface par colonne, cela fait")
	print("  6 912 paves mailles.")
	var par_pave: float = float(somme_t) / float(maxi(1, utiles))
	print("  soit ~%.0f Mo de maillage a 384 blocs, tramage compris."
			% (par_pave * 6912.0 * float(par_sommet) / 1048576.0))
	print("")
	print("[le temps]")
	print("  %.2f ms par pave maille (glouton, monde trame)"
			% (float(t_mesh) / float(maxi(1, paves)) / 1000.0))
	print("")
	print("Lecture : si la ligne « couleur plate » est nettement sous celle du")
	print("monde tel qu'il est, le tramage coute ce que dit l'ecart, et")
	print("l'arbitrage rendu/memoire se tranche a l'oeil comme les autres.")
	quit()


## Repeint le canal de rendu avec la couleur **plate** du type de chaque voxel.
## C'est le monde d'avant le degrade adouci du 2026-09-07.
func _aplatis(buf: VoxelBuffer, n: int) -> void:
	for y in n:
		for z in n:
			for x in n:
				var t: int = buf.get_voxel(x, y, z, CWPalette.CHANNEL_TYPE)
				buf.set_voxel(CWPalette.raw_of(t), x, y, z,
						CWPalette.CHANNEL_COLOR)


func _sommets(m: ArrayMesh) -> int:
	if m == null:
		return 0
	var total: int = 0
	for i in m.get_surface_count():
		var arr: Array = m.surface_get_arrays(i)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		total += v.size()
	return total


func _ligne(nom: String, v: int, ref: int, paves: int) -> void:
	print("  %-40s %9d   %6.0f/pave   %+6.1f %%"
			% [nom, v, float(v) / float(maxi(1, paves)),
					100.0 * (float(v) / float(maxi(1, ref)) - 1.0)])


func _memoire(nom: String, v: int, par_sommet: int, paves: int) -> void:
	print("  %-40s %6.2f Mo pour %d paves"
			% [nom, float(v) * float(par_sommet) / 1048576.0, paves])
