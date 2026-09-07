shader_type sky;

// Le ciel de Zentarys : un degrade a trois bandes et le disque du soleil.
//
// -- Ce que ce fichier ne fait plus, et pourquoi ------------------------------
//
// Il a porte une couche de **nuages en bruit fractal**, projetee sur un plan a
// hauteur constante. Elle marchait, elle ne coutait rien, et elle a ete retiree
// le 2026-09-11 : un nuage sans position ne peut ni se depasser, ni porter une
// ombre, ni prendre le soleil sur son flanc. Les nuages sont maintenant des
// **modeles voxels instancies** (`src/demo/cw_clouds.gd`), a la maille du
// terrain — et la couleur que ce shader calculait a la main (`cloud_lit`,
// `cloud_shade`, le relief pris sur un second echantillon du meme bruit), le
// soleil de la scene la donne desormais gratuitement et juste.
//
// Ce qui reste ici est le ciel **nu** : trois bandes et un disque. C'est aussi
// ce qui rend le fichier lisible — il ne decide plus que du fond.

group_uniforms degrade;
uniform vec3 zenith_color : source_color = vec3(0.25, 0.45, 0.80);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.80, 0.90);
uniform vec3 ground_color : source_color = vec3(0.30, 0.31, 0.33);
// Duretes des deux raccords. Le sol est net, le zenith est doux.
uniform float horizon_falloff : hint_range(0.5, 8.0) = 3.0;

group_uniforms soleil;
// Rayon angulaire du disque, en cosinus. 0.9995 fait un disque d'environ deux
// degres, la taille d'un soleil qu'on regarde sans y penser.
uniform float sun_disc : hint_range(0.99, 0.99999) = 0.9992;
uniform float sun_glow : hint_range(1.0, 256.0) = 48.0;
// Force du halo. Descend a l'aube et au crepuscule avec l'energie du soleil.
uniform float sun_strength : hint_range(0.0, 4.0) = 1.0;


void sky() {
	float h = EYEDIR.y;

	// -- Le degrade ----------------------------------------------------------
	// Au-dessus de l'horizon : de la teinte d'horizon au zenith. En dessous :
	// la teinte de sol, qui n'est vue que par les reflets et le bord bas du
	// champ, mais dont l'absence fait une bande noire.
	float t = pow(clamp(h, 0.0, 1.0), 1.0 / horizon_falloff);
	vec3 col = mix(horizon_color, zenith_color, t);
	col = mix(col, ground_color, smoothstep(0.0, -0.08, h));

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
