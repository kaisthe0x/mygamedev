shader_type canvas_item;

// PORTRAIT recolour -- makes the HUD portrait follow the body colour scheme. The portrait is painted in
// the same stylised palette as the sprite (red hair, teal skin, yellow collar+eyes, brown coat), so we
// classify each pixel by HUE into a body family and swap it to that family's picked hue, keeping the
// pixel's own saturation + value so the painted shading/gradients survive. Only families with a pick
// recolour (target hue < 0 = leave alone), so an un-customised portrait renders untouched. The yellow
// eyes share the collar's band on purpose -- they track the trim pick, as intended.
//
// Hue-only swap -> nearly gamma-invariant, so it works whether TEXTURE is sampled in sRGB or (under
// HDR 2D) linear, without a colour-space conversion.

// Target HUES (0..1) per family; -1 = no pick, leave those pixels unchanged. Set from PaletteConfig.picks.
uniform float hair_hue = -1.0;   // red band
uniform float coat_hue = -1.0;   // brown band (jacket pick)
uniform float trim_hue = -1.0;   // yellow band (collar + eyes)
uniform float skin_hue = -1.0;   // teal band
uniform float sat_floor : hint_range(0.0, 1.0) = 0.15;  // greys/near-neutrals below this never recolour

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 hsv = rgb2hsv(tex.rgb);
	float h = hsv.x;
	float target = -1.0;
	if (hsv.y >= sat_floor) {
		if (h < 0.035 || h > 0.95) target = hair_hue;        // red
		else if (h < 0.11) target = coat_hue;                // brown
		else if (h < 0.22) target = trim_hue;                // yellow
		else if (h > 0.42 && h < 0.58) target = skin_hue;    // teal
	}
	if (target >= 0.0) {
		hsv.x = target;
		tex.rgb = hsv2rgb(hsv);
	}
	COLOR = vec4(tex.rgb, tex.a);
}
