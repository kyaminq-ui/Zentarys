shader_type sky;

// Le ciel de Zentarys : un degrade a trois bandes, une couche de nuages en
// bruit fractal, et le disque du soleil.
//
// -- Pourquoi un shader et pas un dome texture --------------------------------
//
// `ProceduralSkyMaterial` n'a pas de nuages, et il fallait choisir entre deux
// routes. Un dome texture qui defile demande une texture, une geometrie, et il
// plafonne : la couverture nuageuse ne peut pas varier au-dela de ce que
// l'image contient. Un bruit fractal en coordonnees de direction ne demande
// rien — pas de geometrie, pas de limite de couverture —, il coute une poignee
// d'instructions par pixel de ciel, et le projet a deja toute sa culture de
// bruit. C'est aussi la route qui donnera les ombres de nuages si on les veut :
// la meme fonction, echantillonnee au sol.
//
// -- La projection, et le seul piege de ce fichier ----------------------------
//
// Les nuages ne vivent pas sur la sphere du ciel mais sur un **plan** a hauteur
// constante, comme de vrais nuages. On projette donc la direction du regard sur
// ce plan : `EYEDIR.xz / EYEDIR.y`.
//
// **Mais pas exactement, et c'est tout l'ajustement de ce fichier.** Le quotient
// exact explose au ras de l'horizon : les nuages s'y ecrasent en filaments d'un
// pixel, ce qui est juste physiquement et illisible a l'ecran — d'autant qu'une
// vue a la premiere personne regarde surtout *la*. La premiere version rendait
// deux voiles et rien d'autre. On ajoute donc un **decalage au denominateur**,
// `EYEDIR.y + HORIZON_BIAS` : la perspective reste — les masses s'aplatissent en
// s'eloignant — mais elle sature au lieu de diverger, et la couche garde des
// nuages jusqu'au bord. C'est un mensonge assume, et le seul de ce fichier.

group_uniforms degrade;
uniform vec3 zenith_color : source_color = vec3(0.25, 0.45, 0.80);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.80, 0.90);
uniform vec3 ground_color : source_color = vec3(0.30, 0.31, 0.33);
// Duretes des deux raccords. Le sol est net, le zenith est doux.
uniform float horizon_falloff : hint_range(0.5, 8.0) = 3.0;

group_uniforms nuages;
uniform vec3 cloud_lit : source_color = vec3(1.00, 0.98, 0.95);
uniform vec3 cloud_shade : source_color = vec3(0.55, 0.60, 0.70);
// Part du ciel couverte, de 0 (degage) a 1 (bouche).
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.45;
// Taille des nuages : petit = grosses masses. Se lit contre le denominateur
// borne ci-dessous, pas contre un angle.
uniform float cloud_scale : hint_range(0.2, 8.0) = 2.0;
// Derive, en unites de plan par seconde.
uniform float cloud_drift = 0.004;
uniform float cloud_opacity : hint_range(0.0, 1.0) = 0.90;
// Decalage du denominateur de la projection. Voir l'en-tete : c'est lui qui
// empeche les nuages de s'ecraser en filaments au ras de l'horizon.
const float HORIZON_BIAS = 0.30;

group_uniforms soleil;
// Rayon angulaire du disque, en cosinus. 0.9995 fait un disque d'environ deux
// degres, la taille d'un soleil qu'on regarde sans y penser.
uniform float sun_disc : hint_range(0.99, 0.99999) = 0.9992;
uniform float sun_glow : hint_range(1.0, 256.0) = 48.0;
// Force du halo. Descend a l'aube et au crepuscule avec l'energie du soleil.
uniform float sun_strength : hint_range(0.0, 4.0) = 1.0;


// -- Le bruit ------------------------------------------------------------------
//
// Un bruit de valeur classique, **et non celui de `CWValueNoise`** : celui-la
// porte l'identite de tous les mondes engendres (invariant n. 1) et n'a rien a
// faire dans un shader, ou il ne serait ni le meme ni verifiable. Le ciel n'a
// pas besoin d'etre reproductible au bit pres, il a besoin d'etre continu.
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	// Interpolation en smoothstep : la lineaire laisse voir la grille.
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Cinq octaves : en dessous les masses n'ont pas de bord, au-dessus on paie du
// detail que la couche de brume avale.
float fbm(vec2 p) {
	float somme = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		somme += amp * value_noise(p);
		p = p * 2.03 + vec2(17.3, 9.1);
		amp *= 0.5;
	}
	return somme;
}


void sky() {
	float h = EYEDIR.y;

	// -- Le degrade ----------------------------------------------------------
	// Au-dessus de l'horizon : de la teinte d'horizon au zenith. En dessous :
	// la teinte de sol, qui n'est vue que par les reflets et le bord bas du
	// champ, mais dont l'absence fait une bande noire.
	float t = pow(clamp(h, 0.0, 1.0), 1.0 / horizon_falloff);
	vec3 col = mix(horizon_color, zenith_color, t);
	col = mix(col, ground_color, smoothstep(0.0, -0.08, h));

	// -- Les nuages ----------------------------------------------------------
	// Voir l'en-tete : le decalage borne la projection au lieu de la laisser
	// diverger, sans quoi la couche ne rend que des filaments a l'horizon.
	float voile = smoothstep(-0.01, 0.09, h);
	if (voile > 0.001) {
		vec2 plan = EYEDIR.xz / (max(h, 0.0) + HORIZON_BIAS);
		vec2 p = plan * cloud_scale + vec2(TIME * cloud_drift, TIME * cloud_drift * 0.6);
		float n = fbm(p);
		// `cloud_cover` deplace le seuil, il ne multiplie pas la densite : a
		// couverture nulle le ciel doit etre **vide**, pas pale.
		float seuil = mix(0.66, 0.30, cloud_cover);
		// > ⚠️ **Les deux bandes se lisent contre l'etendue reelle du fbm, pas
		// > contre [0, 1].** Cinq octaves d'un bruit de valeur centre sur 0,5
		// > ne montent guere au-dessus de 0,72 : une bande de 0,18 laisse donc
		// > *tout* le nuage dans son fondu, et une bande de relief de 0,30 le
		// > laisse tout entier dans sa teinte d'ombre. La premiere version
		// > rendait des masses grises et delavees pour cette seule raison, et
		// > ca ressemblait a un probleme d'eclairage.
		float masse = smoothstep(seuil, seuil + 0.09, n);
		// Le relief : la meme fonction, decalee, sert d'eclairement. C'est
		// gratuit et ca suffit a ce que les masses ne soient pas des aplats.
		float relief = smoothstep(seuil - 0.03, seuil + 0.12, fbm(p + vec2(1.7, 0.9)));
		vec3 nuage = mix(cloud_shade, cloud_lit, relief);
		col = mix(col, nuage, masse * voile * cloud_opacity);
	}

	// -- Le soleil -----------------------------------------------------------
	// `LIGHT0_DIRECTION` pointe **du soleil vers la scene** : la direction du
	// regard vers l'astre est donc son oppose. Se tromper de signe met le
	// disque a l'antipode, ce qui ne se voit qu'en tournant la tete.
	if (LIGHT0_ENABLED) {
		float d = dot(EYEDIR, -LIGHT0_DIRECTION);
		float halo = pow(max(d, 0.0), sun_glow) * 0.35;
		float disque = smoothstep(sun_disc, sun_disc + 0.0002, d);
		col += LIGHT0_COLOR * sun_strength * (halo + disque * 3.0);
	}

	COLOR = col;
}
