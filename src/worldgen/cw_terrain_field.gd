class_name CWTerrainField
extends RefCounted

## Champ de terrain continu : altitude, temperature, humidite en tout point du
## monde. C'est le coeur de la generation ; le generateur voxel se contente de
## le discretiser.
##
## -- Resume du systeme -------------------------------------------------------
## L'altitude est une somme de cinq octaves de bruit de valeur dont l'amplitude
## est elle-meme pilotee par cinq autres champs de bruit basse frequence. Ce
## sont ces masques d'amplitude qui produisent la signature visuelle de
## l'original : de vastes plaines presque plates que viennent trancher des
## massifs tres abrupts, plutot qu'un relief uniformement bossele. Par-dessus,
## un champ de « chenaux » en bruit rectifie aplatit des vallees, et un melange
## de sites de region pose l'ossature continentale et le climat.
##
## -- Analyse du pseudo-code --------------------------------------------------
## World_baseHeightField (@004f9b70) chaine, dans cet ordre :
##   1. cinq masques d'amplitude ((bruit+1)/2)^2 aux frequences 1e-4 (x2),
##      1e-3 (x2) et 2e-3 ;
##   2. le champ de chenaux, passe dans min(1, e*4) puis un smoothstep cubique
##      eleve au carre - c'est lui qui eteint le detail dans les vallees ;
##   3. le melange de sites sur la fenetre 3x3 deformee : altitude de base
##      moyenne et « part de terre ferme » (fraction de poids des sites dont
##      l'altitude est positive), poids (1 - min(1, (d2-d2min)*5e-8))^2 ;
##   4. deux octaves continentaux a 2e-4, amplitude 200, mis a l'echelle par les
##      masques basse frequence puis par la part de terre ferme, plus l'altitude
##      de base ;
##   5. deux octaves medians a 2e-3, amplitude 100, et un octave de detail a
##      1e-2, amplitude 40, chacun sous son masque.
## Deux attenuations supplementaires (voisinage des agglomerations, jalons de
## tuile de types 1/4/6/7/13) appartiennent a la couche « elements de tuile »,
## non portee dans cette premiere tranche : voir les notes plus bas.
##
## World_temperatureBlend (@004f8570) et World_humidityBlend (@004f8b40)
## partagent exactement la meme fenetre et la meme deformation, avec un poids
## lineaire 1 - min(1, (d2-d2min)*5e-7) : une ponderation dix fois plus serree
## que celle du relief, donc des frontieres climatiques plus franches.
##
## Entrees : coordonnees monde entieres. Sorties : altitude en blocs,
## temperature et humidite dans [0, 1]. Aucun effet de bord hors memoisation
## des sites. Complexite : O(1) par colonne, dominee par ~15 evaluations de
## bruit et deux passes sur 9 sites.

const ZONE_SIZE: int = CWWorldParams.ZONE_SIZE

## Deformation du domaine appliquee avant tout melange de sites : +-768 unites,
## pilotee par du bruit a 5e-4. Noter le croisement des axes : le decalage en X
## est tire de Z et reciproquement (World_terrainOffset2D @00522d80).
const WARP_AMPLITUDE: float = 3.0 * 256.0
const WARP_FREQ: float = 0.0005
const WARP_SEED_X: float = 3423.0
const WARP_SEED_Z: float = 23421.0

## Deformation, plus large, utilisee pour la distance aux aretes du graphe de
## sites (World_sampleTerrainGradient @004d5a80).
const EDGE_WARP_AMPLITUDE: float = 500.0

## Echelles de poids des deux melanges. Elles different d'un facteur dix, et
## c'est deliberé dans l'original : le climat change plus vite que le relief.
const CLIMATE_WEIGHT_SCALE: float = 5e-07
const HEIGHT_WEIGHT_SCALE: float = 5e-08

const _NEIGHBOURS: Array[Vector2i] = [
	Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)
]

var _p: CWWorldParams
var _sites: CWRegionSiteGrid


func _init(world_params: CWWorldParams, site_grid: CWRegionSiteGrid = null) -> void:
	_p = world_params
	_sites = site_grid if site_grid != null else CWRegionSiteGrid.new(world_params)


func sites() -> CWRegionSiteGrid:
	return _sites


func params() -> CWWorldParams:
	return _p


# -- Primitives ---------------------------------------------------------------

func _noise(slot: int, x: float, z: float, freq: float) -> float:
	return CWValueNoise.sample(
			_p.noise_offsets[slot] + x * freq,
			_p.noise_offsets[slot + 1] + z * freq)


## ((bruit + 1) / 2)^2 : un masque d'amplitude dans [0, 1], biaise vers le bas,
## ce qui laisse la majorite du monde plat.
func _amp_mask(slot: int, x: float, z: float, freq: float) -> float:
	var v: float = (_noise(slot, x, z, freq) + 1.0) * 0.5
	return v * v


static func _smoothstep_cubic(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


# -- Melange de sites ---------------------------------------------------------

## Point deforme servant a tous les melanges de sites.
func warped_point(x: int, z: int) -> Vector2:
	var fx: float = float(x)
	var fz: float = float(z)
	return Vector2(
			fx + CWValueNoise.sample(fz * WARP_FREQ, WARP_SEED_X) * WARP_AMPLITUDE,
			fz + CWValueNoise.sample(fx * WARP_FREQ, WARP_SEED_Z) * WARP_AMPLITUDE)


func _window_of(x: int, z: int) -> Array:
	return _sites.get_window(
			CWWorldParams.zone_of(x - ZONE_SIZE),
			CWWorldParams.zone_of(z - ZONE_SIZE))


## Altitude, temperature et humidite d'une colonne, en un seul passage.
## Retour : Vector3(altitude, temperature, humidite).
func sample_column(x: int, z: int) -> Vector3:
	var zx0: int = CWWorldParams.zone_of(x - ZONE_SIZE)
	var zz0: int = CWWorldParams.zone_of(z - ZONE_SIZE)
	return _sample(x, z, zx0, zz0, _sites.get_window(zx0, zz0))


## Echantillonne d'un coup l'empreinte (x, z) d'un bloc.
##
## Rend un tableau de 3 x nx x nz flottants : altitude, temperature, humidite
## pour chaque colonne, en balayant z puis x.
##
## Interet : les 256 colonnes d'un bloc de 16 tombent presque toujours dans la
## meme zone de 16384 unites, donc dans la meme fenetre 3 x 3 de sites. En
## bouclant ici plutot que chez l'appelant, on ne consulte le cache de fenetres
## (verrouille par mutex) qu'une fois par zone traversee au lieu d'une fois par
## colonne.
func sample_patch(x0: int, z0: int, nx: int, nz: int, step: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(nx * nz * 3)
	var last_zx: int = 0x7FFFFFFF
	var last_zz: int = 0x7FFFFFFF
	var win: Array = []
	var i: int = 0
	for iz in nz:
		var z: int = z0 + iz * step
		var zz0: int = CWWorldParams.zone_of(z - ZONE_SIZE)
		for ix in nx:
			var x: int = x0 + ix * step
			var zx0: int = CWWorldParams.zone_of(x - ZONE_SIZE)
			if zx0 != last_zx or zz0 != last_zz:
				win = _sites.get_window(zx0, zz0)
				last_zx = zx0
				last_zz = zz0
			var c: Vector3 = _sample(x, z, zx0, zz0, win)
			out[i] = c.x
			out[i + 1] = c.y
			out[i + 2] = c.z
			i += 3
	return out


func _sample(x: int, z: int, zx0: int, zz0: int, win: Array) -> Vector3:
	var wp: Vector2 = warped_point(x, z)

	# Passe 1 : site le plus proche du point deforme. Ce meme site sert ensuite
	# au champ de chenaux et a la porte de detail : le trouver une seule fois
	# est ce qui rend une colonne assez bon marche pour le streaming.
	var best_d2: float = INF
	var best: CWRegionSite = null
	var best_i: int = 0
	var best_j: int = 0
	for i in 3:
		for j in 3:
			var s: CWRegionSite = win[i * 3 + j]
			if s == null:
				continue
			var dx: float = float(s.x) - wp.x
			var dz: float = float(s.z) - wp.y
			var d2: float = dx * dx + dz * dz
			if d2 < best_d2:
				best_d2 = d2
				best = s
				best_i = zx0 + i
				best_j = zz0 + j
	if is_inf(best_d2):
		# Uniquement possible au bord du monde. L'original abandonne ici et
		# renvoie une valeur non initialisee ; on rend un fond oceanique.
		return Vector3(float(_p.sea_level - 100), 0.5, 0.5)

	# Passe 2 : les deux ponderations, sur la meme fenetre.
	var cw_sum: float = 0.0
	var t_sum: float = 0.0
	var h_sum: float = 0.0
	var hw_sum: float = 0.0
	var base_sum: float = 0.0
	var land_sum: float = 0.0
	for s in win:
		if s == null:
			continue
		var dx: float = float(s.x) - wp.x
		var dz: float = float(s.z) - wp.y
		var d2: float = dx * dx + dz * dz

		var wc: float = 1.0 - minf(1.0, (d2 - best_d2) * CLIMATE_WEIGHT_SCALE)
		cw_sum += wc
		t_sum += s.temperature * wc
		h_sum += s.humidity * wc

		var uh: float = 1.0 - minf(1.0, (d2 - best_d2) * HEIGHT_WEIGHT_SCALE)
		var wh: float = uh * uh
		hw_sum += wh
		base_sum += float(s.base_height) * wh
		if s.base_height > 0:
			land_sum += wh

	var temperature: float = (t_sum / cw_sum) if cw_sum > 0.0 else 0.5
	var humidity: float = (h_sum / cw_sum) if cw_sum > 0.0 else 0.5
	var base_height: float = (base_sum / hw_sum) if hw_sum > 0.0 else 0.0
	var land_ratio: float = (land_sum / hw_sum) if hw_sum > 0.0 else 1.0

	# Depuis que les termes lies aux aretes sont desactives par defaut
	# (site_edge_radius = 0), leur distance ne sert plus a rien : ne pas la
	# calculer economise quatre echantillons de bruit, quatre consultations de
	# sites et quatre distances point-segment par colonne.
	var edge_d2: float = INF
	if _p.site_edge_radius > 0.0:
		edge_d2 = _edge_dist_sq(x, z, best, best_i, best_j)
	var chan: float = _channel(x, z, edge_d2, win, wp, best_d2)
	var height: float = _height_from(x, z, base_height, land_ratio, chan, edge_d2)
	return Vector3(height, temperature, humidity)


## Altitude seule (recalcule le melange de sites : preferer sample_column).
func height_at(x: int, z: int) -> float:
	return sample_column(x, z).x


## Climat seul.
func climate_at(x: int, z: int) -> Vector2:
	var c: Vector3 = sample_column(x, z)
	return Vector2(c.y, c.z)


# -- Champ d'altitude ---------------------------------------------------------

func _height_from(x: int, z: int, base_height: float, land_ratio: float,
		chan: float, edge_d2: float) -> float:
	var fx: float = float(x)
	var fz: float = float(z)

	var amp_low_a: float = _amp_mask(CWWorldParams.O_AMP_LOW_A, fx, fz, 0.0001)
	var amp_low_b: float = _amp_mask(CWWorldParams.O_AMP_LOW_B, fx, fz, 0.0001)
	var amp_mid_a: float = _amp_mask(CWWorldParams.O_AMP_MID_A, fx, fz, 0.001)
	var amp_mid_b: float = _amp_mask(CWWorldParams.O_AMP_MID_B, fx, fz, 0.001)
	var amp_high: float = _amp_mask(CWWorldParams.O_AMP_HIGH, fx, fz, 0.002)

	# Porte des chenaux : eteint le detail au fond des vallees.
	var gate: float = minf(1.0, chan * 4.0)
	var s: float = _smoothstep_cubic(gate)
	s = s * s
	var mask_mid_a: float = s * amp_mid_a
	var mask_mid_b: float = s * amp_mid_b
	var mask_high: float = s * amp_high

	# Ossature continentale.
	var cont: float = (_noise(CWWorldParams.O_CONT_B, fx, fz, 0.0002) + 1.0) * 100.0 * amp_low_b
	cont += (_noise(CWWorldParams.O_CONT_A, fx, fz, 0.0002) + 1.0) * 100.0 * amp_low_a
	cont = cont * land_ratio + base_height

	# NOTE (couche « elements de tuile », non portee) : l'original attenue ici
	# mask_high au voisinage des agglomerations (World_roadField) puis les trois
	# masques autour des jalons de type 1, et remplace localement l'altitude
	# autour des types 4, 6, 7 et 13 (crateres, calderas, pitons). Ces branches
	# dependent de la grille de tuiles 8x8 par zone : tranche suivante.

	var a: float = minf(1.0, maxf(_detail_gate_from(edge_d2), 0.02) * 2.0)
	var inv: float = 1.0 - a
	var k: float = 1.0 - inv * inv * inv * inv
	var detail_scale: float = k * 0.1 + 0.9
	mask_high *= k * 0.5 + 0.5
	mask_mid_a *= detail_scale
	mask_mid_b *= detail_scale

	var h: float = cont
	h += (_noise(CWWorldParams.O_MID_B, fx, fz, 0.002) + 1.0) * 50.0 * mask_mid_b
	h += (_noise(CWWorldParams.O_MID_A, fx, fz, 0.002) + 1.0) * 50.0 * mask_mid_a
	h += (_noise(CWWorldParams.O_HIGH, fx, fz, 0.01) + 1.0) * 20.0 * mask_high
	return h * _p.height_scale


# -- Reseau de chenaux --------------------------------------------------------

## Champ de chenaux : bruit rectifie (valeur absolue) dont les zeros dessinent
## un reseau de vallees ramifiees. Proche de 0 = fond de vallee.
##
## Tracabilite : World_riverClimateGate (@0052cd50). La valeur absolue d'un
## bruit signe est la construction classique dite « ridged » ; c'est elle qui
## produit des lignes continues plutot que des taches.
func channel_field(x: int, z: int) -> float:
	var zx0: int = CWWorldParams.zone_of(x - ZONE_SIZE)
	var zz0: int = CWWorldParams.zone_of(z - ZONE_SIZE)
	var win: Array = _sites.get_window(zx0, zz0)
	var wp: Vector2 = warped_point(x, z)
	return _channel(x, z, site_edge_distance_sq(x, z), win, wp, _best_d2(win, wp))


func _channel(x: int, z: int, edge_d2: float, win: Array, wp: Vector2,
		best_d2: float) -> float:
	var fx: float = float(x)
	var fz: float = float(z)
	var base: float = _noise(CWWorldParams.O_CHAN_BASE, fx, fz, 0.001)
	var detail: float = _noise(CWWorldParams.O_CHAN_DETAIL, fx, fz, 0.01)
	var e: float = absf(base + detail * 0.1)
	# Modulation sans graine dans l'original : identique dans tous les mondes.
	# Reproduite telle quelle.
	var m: float = CWValueNoise.sample(fx * 0.001, fz * 0.001)
	e *= (m + 1.0) * 0.1 + 0.8

	var d_edge: float = _normalised_edge(edge_d2)
	if not is_inf(d_edge):
		var ridge: float = 1.0 - d_edge * 0.75
		if ridge > 0.0:
			e += ridge * ridge * 0.05

	if _p.swamp_channel_weight > 0.0:
		e += _swamp_from(win, wp, best_d2) * _p.swamp_channel_weight
	return e


## Point deforme de +-500 unites servant aux mesures sur le graphe de sites.
func edge_warped_point(x: int, z: int) -> Vector2:
	var fx: float = float(x)
	var fz: float = float(z)
	var wx: float = (_noise(CWWorldParams.O_WARP_X_DETAIL, fx, fz, 0.01) * 0.1
			+ _noise(CWWorldParams.O_WARP_X_BASE, fx, fz, 0.0005))
	var wz: float = (_noise(CWWorldParams.O_WARP_Z_DETAIL, fx, fz, 0.01) * 0.1
			+ _noise(CWWorldParams.O_WARP_Z_BASE, fx, fz, 0.0005))
	return Vector2(fx + wx * EDGE_WARP_AMPLITUDE, fz + wz * EDGE_WARP_AMPLITUDE)


## Distance au carre entre le point deforme et l'arete la plus proche du graphe
## reliant le site courant a ses quatre voisins cardinaux.
##
## Tracabilite : World_biomeBorderDistance (@00522840). L'unite est bien un
## carre d'unites monde : voir CWWorldParams.site_edge_radius pour la
## consequence sur le terme de crete du champ de chenaux.
func site_edge_distance_sq(x: int, z: int) -> float:
	var zx: int = CWWorldParams.zone_of(x - ZONE_SIZE)
	var zz: int = CWWorldParams.zone_of(z - ZONE_SIZE)
	var win: Array = _sites.get_window(zx, zz)
	var wp: Vector2 = warped_point(x, z)

	var best: CWRegionSite = null
	var best_d2: float = INF
	var best_i: int = 0
	var best_j: int = 0
	for i in 3:
		for j in 3:
			var s: CWRegionSite = win[i * 3 + j]
			if s == null:
				continue
			var dx: float = float(s.x) - wp.x
			var dz: float = float(s.z) - wp.y
			var d2: float = dx * dx + dz * dz
			if d2 < best_d2:
				best_d2 = d2
				best = s
				best_i = zx + i
				best_j = zz + j
	return _edge_dist_sq(x, z, best, best_i, best_j)


func _edge_dist_sq(x: int, z: int, best: CWRegionSite, best_i: int,
		best_j: int) -> float:
	if best == null:
		return INF
	var p: Vector2 = edge_warped_point(x, z)
	var a: Vector2 = Vector2(float(best.x), float(best.z))
	var out: float = INF
	for d in _NEIGHBOURS:
		var n: CWRegionSite = _sites.get_site(best_i + d.x, best_j + d.y)
		if n == null:
			continue
		out = minf(out, _point_segment_dist_sq(a, Vector2(float(n.x), float(n.z)), p))
	return out


static func _point_segment_dist_sq(a: Vector2, b: Vector2, p: Vector2) -> float:
	var ab: Vector2 = b - a
	var ap: Vector2 = p - a
	var len2: float = ab.length_squared()
	if len2 < 1e-20:
		return ap.length_squared()
	var t: float = ap.dot(ab) / len2
	if t <= 0.0:
		return ap.length_squared()
	if t >= 1.0:
		return (p - b).length_squared()
	return (ap - ab * t).length_squared()


## Facteur d'aplanissement du detail.
##
## Tracabilite : World_waterDepthField (@0052d990). Hors influence des elements
## de tuile - la seule chose qui puisse en reduire la valeur - il rend la
## distance aux aretes telle quelle, donc une valeur tres grande, donc un detail
## a pleine amplitude. C'est exactement le comportement obtenu ici ; la
## modulation par les agglomerations viendra avec la couche de tuiles.
func detail_gate(x: int, z: int) -> float:
	return _detail_gate_from(site_edge_distance_sq(x, z))


func _detail_gate_from(edge_d2: float) -> float:
	return _normalised_edge(edge_d2)


## Distance aux aretes ramenee a [0, 1] sur le rayon d'influence configure.
## Rend INF quand le rayon est nul, ce qui neutralise proprement les deux termes
## qui l'utilisent : `1 - INF * 0.75` reste negatif, et `min(1, INF * 2)` vaut 1,
## soit aucune attenuation du detail.
func _normalised_edge(edge_d2: float) -> float:
	var r: float = _p.site_edge_radius
	if r <= 0.0 or is_inf(edge_d2):
		return INF
	return edge_d2 / (r * r)


## Fraction de « marais » melangee sur la fenetre 3x3.
##
## Tracabilite : World_waterProximityInfluence (@00522e20). La structure du
## melange est claire ; le champ effectivement somme au numerateur est perdu
## (retour flottant en xmm0, non modelise par Ghidra). On somme le drapeau
## marais du site, ce qui donne un scalaire dans [0, 1], et le poids reste a
## zero par defaut plutot que d'inventer un comportement.
func swamp_blend(x: int, z: int) -> float:
	var win: Array = _window_of(x, z)
	var wp: Vector2 = warped_point(x, z)
	return _swamp_from(win, wp, _best_d2(win, wp))


func _best_d2(win: Array, wp: Vector2) -> float:
	var best: float = INF
	for s in win:
		if s == null:
			continue
		var dx: float = float(s.x) - wp.x
		var dz: float = float(s.z) - wp.y
		best = minf(best, dx * dx + dz * dz)
	return best


func _swamp_from(win: Array, wp: Vector2, best_d2: float) -> float:
	if is_inf(best_d2):
		return 0.0
	var any_wet: bool = false
	for s in win:
		if s != null and s.wet:
			any_wet = true
			break
	if not any_wet:
		return 0.0

	var w_sum: float = 0.0
	var v_sum: float = 0.0
	for s in win:
		if s == null:
			continue
		var dx: float = float(s.x) - wp.x
		var dz: float = float(s.z) - wp.y
		var d2: float = dx * dx + dz * dz
		var w: float = 1.0 - minf(1.0, (d2 - best_d2) * CLIMATE_WEIGHT_SCALE)
		w_sum += w
		if s.wet:
			v_sum += w
	return (v_sum / w_sum) if w_sum > 0.0 else 0.0
