shader_type canvas_item;

// PORTRAIT recolour -- makes the HUD portrait follow the body colour scheme. The portrait is painted in
// the same stylised palette as the sprite (red hair, teal skin, yellow collar+eyes, brown coat), so we
// classify each pixel by HUE into a body family and adopt that family's picked HUE + SATURATION, keeping
// the pixel's own VALUE so the painted shading/gradients survive -- the same recolour rule the body's
// palette LUT uses. (Hue-ONLY was too weak on dark regions like the coat: swapping the hue of a near-black
// pixel is invisible, so we take the pick's saturation too, giving a clearly-hued dark colour.)
//
// Only families with a pick recolour (target alpha < 0 = leave alone), so an un-customised portrait
// renders untouched. The yellow eyes share the collar's band on purpose -- they track the trim pick.

// Target COLOURS per family (only hue+sat used); alpha < 0 = no pick, leave those pixels. Set from
// PaletteConfig.apply_portrait_hues.
uniform vec4 hair_col = vec4(0.0, 0.0, 0.0, -1.0);   // red band
uniform vec4 coat_col = vec4(0.0, 0.0, 0.0, -1.0);   // brown band (jacket pick)
uniform vec4 trim_col = vec4(0.0, 0.0, 0.0, -1.0);   // yellow band (collar + eyes)
uniform vec4 skin_col = vec4(0.0, 0.0, 0.0, -1.0);   // teal band
uniform float sat_floor : hint_range(0.0, 1.0) = 0.10;  // greys/near-neutrals below this never recolour

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
	vec4 target = vec4(0.0, 0.0, 0.0, -1.0);
	if (hsv.y >= sat_floor) {
		if (h < 0.035 || h > 0.95) target = hair_col;        // red
		else if (h < 0.11) target = coat_col;                // brown
		else if (h < 0.22) target = trim_col;                // yellow
		else if (h > 0.42 && h < 0.58) target = skin_col;    // teal
	}
	if (target.a >= 0.0) {
		vec3 thsv = rgb2hsv(target.rgb);
		hsv.x = thsv.x;            // adopt the picked hue
		hsv.y = thsv.y;            // ...and its saturation, so dark regions still read as the new colour
		tex.rgb = hsv2rgb(hsv);    // keep the pixel's own value (its painted shading)
	}
	COLOR = vec4(tex.rgb, tex.a);
}
