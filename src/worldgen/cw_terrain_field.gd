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
##   6. la couche « elements de tuile » (jalon 1.6) : un element par tuile de
##      2048 unites attenue les masques de detail autour d'un bourg, puis
##      remplace localement l'altitude pour les crateres, caldeiras et pitons.
##      Voir CWTileFeatureGrid et la section « Elements de tuile » plus bas.
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

## Deformation du domaine des poids d'element (World_objectFalloffWeight
## @0052c820) : deux echantillons de bruit a 2,5e-3, d'amplitude 100 unites
## monde, appliques avant la mesure de distance.
##
## Les graines sont lisibles en virgule fixe dans le binaire (0x1617D0000 pour
## 90493, 0xD5F0000 pour 3423, 0x700000 pour 112) et se recoupent avec le terme
## de relevement oceanique de World_baseHeightField, lui ecrit en clair. Seule
## la graine X differe entre les deux emplacements, de 512 exactement : ce n'est
## pas une erreur de lecture, les deux champs sont distincts.
const FALLOFF_WARP_FREQ: float = 0.0025
const FALLOFF_WARP_AMPLITUDE: float = 100.0
const FALLOFF_SEED_X: float = 8433496.0
const LIFT_SEED_X: float = 8432984.0
const FALLOFF_SEED_XZ: float = 90493.0
const FALLOFF_SEED_ZX: float = 3423.0
const FALLOFF_SEED_Z: float = 112.0

## Marge ajoutee au rayon d'un element pour le relevement oceanique.
const LIFT_RADIUS_MARGIN: float = 256.0

var _p: CWWorldParams
var _sites: CWRegionSiteGrid
var _features: CWTileFeatureGrid


func _init(world_params: CWWorldParams, site_grid: CWRegionSiteGrid = null) -> void:
	_p = world_params
	_sites = site_grid if site_grid != null else CWRegionSiteGrid.new(world_params)
	_features = CWTileFeatureGrid.new(world_params)


func sites() -> CWRegionSiteGrid:
	return _sites


func features() -> CWTileFeatureGrid:
	return _features


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
##
## **C'est l'altitude du champ, etangs non compris.** Qui a besoin du sol
## reellement genere — la dispersion, le generateur — passe par
## `sample_column_full` puis `column_profile` : un etang creuse sa colonne, et
## un objet pose a l'altitude rendue ici y flotterait au-dessus de l'eau.
func sample_column(x: int, z: int) -> Vector3:
	var c: Vector4 = sample_column_full(x, z)
	return Vector3(c.x, c.y, c.z)


## Altitude, climat **et champ de chenaux** d'une colonne, en un seul passage.
##
## Le quatrieme terme est la porte des etangs (jalon 1.14) : il est deja calcule
## par `_height_from`, qui s'en sert pour eteindre le detail dans les vallees.
## Le sortir ici ne coute donc pas un echantillon de bruit de plus — c'est ce qui
## permet a la dispersion de savoir si elle seme dans une mare sans payer une
## seconde descente dans le champ.
func sample_column_full(x: int, z: int) -> Vector4:
	var c: Vector4 = _sample_raw4(x, z)
	c.x *= _p.height_scale
	return c


## Idem, mais dans le domaine d'altitude d'origine : sans `height_scale`.
##
## C'est ce domaine que manipule la couche d'elements de tuile, parce que
## l'altitude figee dans un element est comparee au terrain qui l'entoure.
## Passer par la sortie mise a l'echelle melangerait les deux domaines des que
## `height_scale` s'ecarte de 1.
##
## **Les etangs ne s'y appliquent pas non plus**, et pour une raison plus forte
## que l'echelle : la couche d'elements de tuile lit cette altitude pour figer
## celle d'un element, et un etang qui se creuserait dans cette lecture
## deplacerait l'element, qui deplacerait le terrain, qui deplacerait l'etang.
func sample_column_raw(x: int, z: int) -> Vector3:
	var c: Vector4 = _sample_raw4(x, z)
	return Vector3(c.x, c.y, c.z)


func _sample_raw4(x: int, z: int) -> Vector4:
	var zx0: int = CWWorldParams.zone_of(x - ZONE_SIZE)
	var zz0: int = CWWorldParams.zone_of(z - ZONE_SIZE)
	return _sample(x, z, zx0, zz0, _sites.get_window(zx0, zz0), feature_at(x, z))


## Echantillonne d'un coup l'empreinte (x, z) d'un bloc.
##
## Rend un tableau de **4** x nx x nz flottants : altitude, temperature,
## humidite et **champ de chenaux** pour chaque colonne, en balayant z puis x.
## Le quatrieme terme est la porte des etangs (jalon 1.14) ; il est deja calcule
## par le champ d'altitude, donc il ne coute rien de plus ici.
##
## Interet : les 256 colonnes d'un bloc de 16 tombent presque toujours dans la
## meme zone de 16384 unites, donc dans la meme fenetre 3 x 3 de sites. En
## bouclant ici plutot que chez l'appelant, on ne consulte le cache de fenetres
## (verrouille par mutex) qu'une fois par zone traversee au lieu d'une fois par
## colonne.
func sample_patch(x0: int, z0: int, nx: int, nz: int, step: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(nx * nz * 4)
	var last_zx: int = 0x7FFFFFFF
	var last_zz: int = 0x7FFFFFFF
	var last_tx: int = 0x7FFFFFFF
	var last_tz: int = 0x7FFFFFFF
	var win: Array = []
	var feature: CWTileFeature = null
	var scale: float = _p.height_scale
	var i: int = 0
	for iz in nz:
		var z: int = z0 + iz * step
		var zz0: int = CWWorldParams.zone_of(z - ZONE_SIZE)
		var tz: int = CWWorldParams.tile_of(z)
		for ix in nx:
			var x: int = x0 + ix * step
			var zx0: int = CWWorldParams.zone_of(x - ZONE_SIZE)
			if zx0 != last_zx or zz0 != last_zz:
				win = _sites.get_window(zx0, zz0)
				last_zx = zx0
				last_zz = zz0
			# Meme raison que pour la fenetre de sites : une tuile fait 2048
			# unites, donc les 256 colonnes d'un bloc tombent presque toujours
			# dans la meme, et la grille d'elements est protegee par mutex.
			var tx: int = CWWorldParams.tile_of(x)
			if tx != last_tx or tz != last_tz:
				feature = feature_at(x, z)
				last_tx = tx
				last_tz = tz
			var c: Vector4 = _sample(x, z, zx0, zz0, win, feature)
			out[i] = c.x * scale
			out[i + 1] = c.y
			out[i + 2] = c.z
			out[i + 3] = c.w
			i += 4
	return out


func _sample(x: int, z: int, zx0: int, zz0: int, win: Array,
		feature: CWTileFeature) -> Vector4:
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
		# renvoie une valeur non initialisee ; on rend un fond oceanique. Le
		# chenal rendu est 1,0 — tres au-dessus de la porte des etangs — parce
		# qu'un bord de monde sans site n'a pas de vallee ou en poser un.
		return Vector4(float(_p.sea_level - 100), 0.5, 0.5, 1.0)

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
	var height: float = _height_from(x, z, base_height, land_ratio, chan, edge_d2,
			feature)
	return Vector4(height, temperature, humidity, chan)


## Site de region le plus proche du point deforme, ou null au bord du monde.
##
## Tracabilite : World_findNearestEntityInRegion (server/world/World.cpp) est
## exactement cette recherche — meme fenetre 3 x 3, meme deformation par
## World_terrainOffset2D. Le placement des elements de tuile s'en sert pour
## verifier qu'une tuile releve bien de sa propre zone.
func nearest_site(x: int, z: int) -> CWRegionSite:
	var zx0: int = CWWorldParams.zone_of(x - ZONE_SIZE)
	var zz0: int = CWWorldParams.zone_of(z - ZONE_SIZE)
	var win: Array = _sites.get_window(zx0, zz0)
	var wp: Vector2 = warped_point(x, z)
	var best: CWRegionSite = null
	var best_d2: float = INF
	for s: CWRegionSite in win:
		if s == null:
			continue
		var dx: float = float(s.x) - wp.x
		var dz: float = float(s.z) - wp.y
		var d2: float = dx * dx + dz * dz
		if d2 < best_d2:
			best_d2 = d2
			best = s
	return best


## Element de la tuile contenant (x, z), ou null.
func feature_at(x: int, z: int) -> CWTileFeature:
	if not _p.tile_features:
		return null
	return _features.get_feature(CWWorldParams.tile_of(x), CWWorldParams.tile_of(z), self)


## Altitude seule (recalcule le melange de sites : preferer sample_column).
func height_at(x: int, z: int) -> float:
	return sample_column(x, z).x


## Climat seul.
func climate_at(x: int, z: int) -> Vector2:
	var c: Vector3 = sample_column(x, z)
	return Vector2(c.y, c.z)


# -- Champ d'altitude ---------------------------------------------------------

func _height_from(x: int, z: int, base_height: float, land_ratio: float,
		chan: float, edge_d2: float, feature: CWTileFeature) -> float:
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

	# Couche « elements de tuile ». Le poids d'influence, une fois calcule, sert
	# a la fois au champ de routes, a l'aplanissement du bourg et aux reliefs
	# locaux : on ne paie ses deux echantillons de bruit qu'une fois.
	var active: bool = feature != null and feature.affects_height()
	var fw := Vector2.ZERO
	var weight: float = INF
	if active:
		fw = falloff_point(fx, fz)
		weight = _falloff_from(feature, fw)
		if feature.type == CWTileFeature.TYPE_TOWN:
			# World_roadField : (1 - w)^2 borne a zero, uniquement sur la tuile
			# du bourg. Le meme carre sert a l'aplanissement plus bas.
			var road: float = maxf(0.0, 1.0 - weight)
			road *= road
			if road > 0.5:
				var t: float = minf(1.0, (road - 0.5) * 2.0)
				mask_high *= 1.0 - _smoothstep_cubic(t)
			var flat: float = 1.0 - road * 0.5
			mask_mid_a *= flat
			mask_mid_b *= flat
			mask_high *= flat

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
	if active:
		h = _apply_feature(h, feature, weight, fw, fx, fz, base_height)
	return h


# -- Elements de tuile --------------------------------------------------------

## Point deforme servant aux poids d'element.
##
## Tracabilite : World_objectFalloffWeight (@0052c820). La deformation est
## desactivee pour les types 11, 12 et 14, qui comparent une distance nue.
func falloff_point(fx: float, fz: float) -> Vector2:
	return Vector2(
			fx + _falloff_warp(FALLOFF_SEED_X, FALLOFF_SEED_XZ, fx, fz),
			fz + _falloff_warp(FALLOFF_SEED_ZX, FALLOFF_SEED_Z, fx, fz))


func _falloff_warp(seed_x: float, seed_z: float, fx: float, fz: float) -> float:
	return CWValueNoise.sample(
			seed_x + fx * FALLOFF_WARP_FREQ,
			seed_z + fz * FALLOFF_WARP_FREQ) * FALLOFF_WARP_AMPLITUDE


## Poids d'influence d'un element : carre de la distance au centre, normalise
## par le rayon. 0 au centre, 1 au bord, au-dela ensuite.
func falloff_weight(feature: CWTileFeature, x: int, z: int) -> float:
	if feature.type in CWTileFeature.UNWARPED_TYPES:
		return _falloff_from(feature, Vector2(float(x), float(z)))
	return _falloff_from(feature, falloff_point(float(x), float(z)))


func _falloff_from(feature: CWTileFeature, p: Vector2) -> float:
	# L'original rend 0 pour un rayon nul, c'est-a-dire une influence maximale
	# partout. Aucun element produit par le generateur n'a un rayon nul ; on
	# neutralise plutot que de propager cette valeur de bord.
	if feature.radius < 0.001:
		return INF
	var dx: float = p.x - feature.x
	var dz: float = p.y - feature.z
	return (dx * dx + dz * dz) / (feature.radius * feature.radius)


## Champ de routes : influence du bourg de la tuile, nulle ailleurs.
##
## Tracabilite : World_roadField (@0052bfc0, cf. World.cpp) puis
## World_falloffSquared. Le nom d'origine est trompeur : le seul element de
## type 1 d'une zone est son bourg, donc ce champ n'existe que sur sa tuile.
func road_field(x: int, z: int) -> float:
	var f: CWTileFeature = feature_at(x, z)
	if f == null or f.type != CWTileFeature.TYPE_TOWN:
		return 0.0
	var road: float = maxf(0.0, 1.0 - falloff_weight(f, x, z))
	return road * road


## Reliefs locaux d'un element : relevement oceanique puis cratere, caldeira ou
## piton. Un element n'ayant qu'un type, une seule branche s'applique.
##
## Tracabilite : queue de World_baseHeightField (@004f9b70), dans cet ordre.
func _apply_feature(h: float, feature: CWTileFeature, weight: float,
		fw: Vector2, fx: float, fz: float, base_height: float) -> float:
	# Un element pose sur un site oceanique fait emerger son propre ilot : le
	# terrain est releve de l'altitude de base du site, qui est negative. Le
	# rayon est elargi de 256 et la deformation du domaine a sa propre graine.
	if feature.ocean_lift < 0.0 and feature.type != 0 and feature.type != 0x0b:
		var lx: float = fx + _falloff_warp(LIFT_SEED_X, FALLOFF_SEED_XZ, fx, fz)
		var dx: float = lx - feature.x
		var dz: float = fw.y - feature.z
		var r: float = feature.radius + LIFT_RADIUS_MARGIN
		var w: float = minf(1.0, (dx * dx + dz * dz) / (r * r))
		if w < 1.0:
			h -= _smoothstep_cubic(minf(1.0, (1.0 - w) * 1.1)) * feature.ocean_lift

	match feature.type:
		CWTileFeature.TYPE_CRATER:
			# Cuvette a hauteur - 50 au centre, remontant vers hauteur - 25 au
			# quart du rayon, puis raccordee au terrain jusqu'au bord.
			if weight > 0.25:
				if weight < 1.0:
					var t: float = (sqrt(weight) - 0.5) * 2.0
					var g: float = 1.0 - t * t
					h += ((feature.height - 25.0) - h) * g * g
			else:
				var g: float = 1.0 - weight * 4.0
				g *= g
				h = (1.0 - g) * (feature.height - 25.0) + (feature.height - 50.0) * g
		CWTileFeature.TYPE_CALDERA_A, CWTileFeature.TYPE_CALDERA_B:
			# Meme decoupage, mais relatif au terrain : bord releve de 10,
			# fond creuse de 30, sans jamais passer sous l'altitude du site.
			if weight > 0.25:
				if weight < 1.0:
					var t: float = (sqrt(weight) - 0.5) * 2.0
					var g: float = 1.0 - t * t
					h += g * g * 10.0
			else:
				var g: float = 1.0 - weight * 4.0
				g *= g
				h = (1.0 - g) * (h + 10.0) + (h - 30.0) * g
			h = maxf(h, base_height)
		CWTileFeature.TYPE_SPIRE:
			# Piton : +150 sur le centieme central du disque, puis une decrue
			# en puissance quatre. Le generateur de zone ne produit jamais ce
			# type ; l'effet est porte pour completude.
			if weight > 0.01:
				if weight < 1.0:
					var t: float = (sqrt(weight) - 0.1) / 0.9
					var g: float = 1.0 - t * t
					h += g * g * g * g * 150.0
			else:
				h += 150.0
	return h


# -- Les etangs (jalon 1.14) --------------------------------------------------
#
# L'eau de surface de l'original n'est ni un element de tuile ni un niveau
# global : c'est une seconde passe de `WorldInfo_generateBiomeContent`
# (@005e4850), colonne par colonne, dont **la porte est le champ de chenaux**
# porte au jalon 1.4. Il ne manquait pas un champ, il manquait un seuil.
# Analyse et pseudo-code : `docs/systems/02`, Sec. 10.
#
# -- Ce que la source fait, dans l'ordre --------------------------------------
#
#   1. porte : `chan <= 0,02` — 3,4 % des terres, mesure ;
#   2. le niveau est **quantifie au pas de 5** au-dessus du niveau de la mer ;
#   3. une **rampe triangulaire** `t` sur la position dans le palier decide s'il
#      y a de l'eau et quelle profondeur : nulle aux deux bouts du palier, 1 en
#      son milieu. C'est elle qui fait des **chapelets de mares** le long d'un
#      fond de vallee plutot qu'une riviere continue — l'eau apparait et
#      disparait a chaque fois que le terrain traverse un multiple de 5 ;
#   4. la colonne est **ouverte au-dessus** du plan d'eau : sans ce creusement,
#      l'eau serait une poche enterree sous le terrain d'origine.
#
# -- Deux ecarts avec la note du depot, releves en relisant la source ---------
#
# `docs/systems/02` Sec. 10.2 en donnait un pseudo-code juste dans les grandes
# lignes et faux sur deux points, tous deux corriges ici et dans la note :
#
#   * **le sol humide n'est pas le lit de l'etang, c'est sa rive.** La source
#     ecrit le type 3 a la hauteur `lit`, sous la garde « le bloc qui s'y trouve
#     n'est pas de l'eau » — garde qui echoue precisement quand il y a de l'eau.
#     Le sol humide n'apparait donc que sur les colonnes de la porte **ou l'eau
#     ne monte pas**, c'est-a-dire l'anneau autour de chaque mare. C'est
#     beaucoup mieux ainsi : `CWDecorRules.FAMILIES_SURFACE` fait pousser des
#     **roseaux** sur cette matiere, et un roseau se tient sur la rive, pas au
#     fond ;
#   * **le lit remonte au-dessus du palier dans le dernier quart.** Quand `t`
#     devient negatif — `frac > 0,75`, un quart des colonnes de la porte — la
#     source place le sol humide a `q + 5|t|` et non a `q`. C'est ce qui evite
#     une marche franche de cinq blocs a chaque bord de palier : la rive remonte
#     vers le terrain reel au lieu d'etre tranchee net.

## Seuil du champ de chenaux en **altitude**, ou l'eau est un ruisseau etroit.
## C'est la valeur de la source, relevee sous la forme `1 - 50 x chan >= 0`.
const POND_GATE_HAUT: float = 0.02

## Seuil du champ de chenaux **au ras du niveau de la mer**, ou l'eau s'etale.
##
## **Ce second seuil est une creation de ce projet**, et la seule de la regle
## d'eau. La source n'a qu'un seuil, donc des cours d'eau de largeur constante du
## sommet a la mer. Demande du 2026-09-06 : *les rivieres doivent se terminer
## dans des lacs.* Un reseau de chenaux ne dit pas ou est un bassin — il faudrait
## un voisinage, donc un cout par colonne qu'on ne peut pas payer —, mais il dit
## l'altitude, et une riviere qui s'elargit en descendant **est** ce qu'on voit
## d'un bassin : le ruisseau nait etroit en altitude et finit en nappe dans le
## fond de vallee. C'est un lac obtenu par ou il arrive, et non par sa forme.
const POND_GATE_BAS: float = 0.055

## Altitude au-dessus de la mer a laquelle la porte a fini de se refermer.
## Au-dessus, un ruisseau ; en dessous, l'elargissement progressif.
const POND_LAKE_SPAN: float = 90.0

## Pas de quantification du niveau d'eau, en blocs. C'est lui qui donne a l'eau
## sa surface plate.
const POND_STEP: int = 5

## Profondeur minimale d'un plan d'eau, en blocs.
##
## **La rampe triangulaire ne decide plus de la presence de l'eau, seulement de
## sa profondeur** — second ecart assume a la source, demande le meme jour :
## *les rivieres sont souvent decoupees en plusieurs morceaux a cause du
## terrain, il faudrait les relier entre elles.* Le decoupage etait la rampe :
## elle ne laissait passer l'eau que sur 60 % d'un palier, si bien qu'un cours
## d'eau s'interrompait chaque fois que le terrain traversait un multiple de 5.
## En gardant la rampe pour le **fond** et en posant toujours au moins un bloc
## d'eau, le trace redevient continu et la rampe garde son role : elle creuse
## les cuvettes et laisse les seuils peu profonds.
const POND_DEPTH_MIN: int = 1

## Part de la porte occupee par l'eau ; le reste est la **rive**.
##
## Depuis que la rampe ne decide plus de la presence de l'eau (voir
## `POND_DEPTH_MIN`), toute la porte serait mouillee et il n'y aurait plus de
## rive du tout — donc plus de sol humide, donc plus de roseau, le seul modele
## de la flore qui pousse sur cette matiere. La rive redevient ce qu'elle est
## dans le paysage : **la bande exterieure du lit**, celle ou le chenal est
## encore sous le seuil mais deja trop haut pour porter de l'eau.
##
## Elle a l'avantage d'etre continue le long du cours d'eau, la ou celle de la
## source apparaissait par plaques entre deux mares.
const POND_WATER_FRAC: float = 0.82

## Hauteur de la surface de l'eau sous la rive, en blocs.
##
## Demande du 2026-09-06 : *l'eau ne doit pas etre au niveau du sol, toujours un
## bloc en dessous minimum.* Dans la source, l'eau monte jusqu'au palier `q` et
## la rive est tranchee au meme `q` : les deux affleurent, et une nappe a ras
## bord ne se lit pas comme de l'eau — elle se lit comme une matiere bleue posee
## a plat. Un bloc d'ecart suffit a lui donner une berge.
const POND_BANK_DROP: int = 1


## Seuil du champ de chenaux a une altitude donnee, en blocs au-dessus de la mer.
##
## Etroit en altitude, large au ras de la mer : voir `POND_GATE_BAS`.
static func pond_gate_at(above: float) -> float:
	var t: float = clampf(above / POND_LAKE_SPAN, 0.0, 1.0)
	return POND_GATE_BAS + (POND_GATE_HAUT - POND_GATE_BAS) * t


## Profil d'etang d'une colonne, en blocs **au-dessus du niveau de la mer**.
##
## `above` est l'altitude de la colonne au-dessus du niveau de la mer.
## Rend `Vector3i(sol, eau_bas, eau_haut)` :
##
##   * `sol` est le dessus de la matiere apres creusement — la colonne est
##     tranchee a cette hauteur, ce qui est l'effet net des quatre dernieres
##     lignes de la source ;
##   * `[eau_bas, eau_haut]` est l'intervalle d'eau. Il n'est plus jamais vide
##     dans la porte : depuis le 2026-09-06 au soir, la rampe ne decide que de
##     la profondeur (voir `POND_DEPTH_MIN`).
##
## **Pure et sans etat**, ce qui est la condition pour que les quatre
## consommateurs s'accordent (invariant n. 18) — le bloc genere, la requete
## ponctuelle et les deux dispersions decrivent la meme mare.
##
## Les troncatures suivent celles de la source (`(int)` en C, vers zero) et non
## un arrondi vers le bas : `bas` passe par des valeurs negatives au ras du
## rivage, ou les deux ne donnent pas le meme bloc.
static func pond_span(above: float) -> Vector3i:
	var a: float = maxf(above, 0.0)
	@warning_ignore("integer_division")
	var q: int = (int(a) / POND_STEP) * POND_STEP
	var frac: float = (a - float(q)) / float(POND_STEP)

	# La rampe triangulaire. Au-dela du sommet elle redescend quatre fois plus
	# vite qu'elle n'est montee, puis **passe sous zero** dans le dernier quart
	# du palier, ou la source l'adoucit en `(t+1)^2 - 1`.
	var t: float
	if frac >= 0.5:
		t = 1.0 - (frac - 0.5) * 4.0
		if t < 0.0:
			t = (t + 1.0) * (t + 1.0) - 1.0
	else:
		t = frac * 2.0

	# Profondeur : celle de la source la ou elle en donne une, le minimum
	# ailleurs. `int(q - 5t + 2)` est le fond de la source ; sa distance au
	# palier est la profondeur, qui plafonne a quatre blocs.
	var fond_source: int = int(float(q) - t * 5.0 + 2.0)
	var creux: int = maxi(q - fond_source + 1, POND_DEPTH_MIN)

	# La surface est un bloc sous la rive, qui reste au palier.
	var haut: int = q - POND_BANK_DROP
	return Vector3i(haut - creux, haut - creux + 1, haut)


## Vrai si la colonne peut porter de l'eau de surface.
##
## Trois conditions, et les deux dernieres sont des ecarts assumes a la source :
##
##   * **le champ de chenaux passe sous le seuil de son altitude** — c'est la
##     regle de la source, avec la porte elargie vers le bas (`POND_GATE_BAS`) ;
##   * **la colonne est au-dessus du niveau de la mer.** La source travaille
##     dans un domaine ou la mer vaut zero et borne son niveau a zero ; ici la
##     borne devient ce test, sans quoi la porte trancherait le fond marin au
##     niveau de la mer et souleverait l'ocean entier ;
##   * **le biome accepte l'eau de surface.** Demande du 2026-09-06 : pas d'eau
##     dans les Deserts ni dans les Lava Lands. La source n'a pas de biomes —
##     c'est une couche de ce projet, jalon 1.12 — donc la regle non plus. Elle
##     se defend seule : un desert est defini par l'absence d'eau, et une nappe
##     d'eau au milieu des coulees de lave demanderait une vapeur qu'on n'a pas.
static func pond_gate(height: float, chan: float, sea: int, biome: int) -> bool:
	if biome == CWBiome.DESERTS or biome == CWBiome.LAVALANDS:
		return false
	var above: float = height - float(sea)
	return above > 0.0 and chan <= pond_gate_at(above)


## Profil complet d'une colonne, etang compris, en altitudes de bloc
## **absolues**. C'est le point unique ou la porte, le niveau de la mer et la
## rampe se rencontrent ; tout le reste du projet passe par ici.
##
## Hors de la porte, rend la colonne telle quelle et un intervalle d'eau vide.
##
## La porte est sortie en `pond_gate` parce que **deux decisions la lisent** :
## celle-ci et la matiere de rive (`CWVoxelGenerator.pond_surface`). Les avoir
## ecrites deux fois aurait donne une rive humide sur une colonne non creusee le
## jour ou l'une des deux bougerait.
static func column_profile(height: float, chan: float, sea: int,
		biome: int) -> Vector3i:
	if not pond_gate(height, chan, sea, biome):
		return Vector3i(floori(height), 1, 0)
	var above: float = height - float(sea)
	# La bande exterieure de la porte est la **rive** : tranchee au palier, mais
	# sans eau. C'est elle qui porte le sol humide, et elle est un bloc au-dessus
	# de la surface de l'eau — ce qui est exactement `POND_BANK_DROP`.
	if chan > pond_gate_at(above) * POND_WATER_FRAC:
		@warning_ignore("integer_division")
		var q: int = (int(maxf(above, 0.0)) / POND_STEP) * POND_STEP
		return Vector3i(q + sea, 1, 0)
	var p: Vector3i = pond_span(above)
	return Vector3i(p.x + sea, p.y + sea, p.z + sea)


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
