shader_type canvas_item;

// Living sprite tint (recolours parts of a character by colour-keying, not by masks/regions).
// TWO independent channels, each keyed on colour so they only touch the parts you mean:
//   1. HAIR  -- the bright, saturated RED hair pixels (his coat is a dull reddish-brown, keyed out
//      by brightness + saturation). Driven by a moving palette: a base colour with two accents
//      flowing through it. Each pixel keeps its own drawn shading, so the hair looks the same shape
//      -- just alive. Bright bits are pushed past 1.0 so the WorldEnvironment bloom gives it an aura.
//   2. METAL -- the grey-ish metal (shoes + gauntlets): LOW-saturation, mid-brightness pixels,
//      recoloured toward a tint. OFF by default (metal_amount = 0), so it changes nothing until you
//      raise it. Everything not caught by either key is untouched. All uniforms are tunable.

// --- hair channel ---
uniform float intensity : hint_range(0.0, 1.5) = 1.0;   // overall hair strength (0 = off)
uniform float vibrancy  : hint_range(0.8, 2.5) = 1.45;  // how punchy the hair colour is
uniform float flow_speed = 0.9;                          // how fast the colour moves
uniform float flow_amount : hint_range(0.0, 1.0) = 0.5;  // how much the accents bleed through the base
uniform float glow : hint_range(0.0, 1.5) = 0.45;        // brightness push -> bloom aura
uniform vec3 base_red  : source_color = vec3(1.7, 0.28, 0.26);   // hair base colour
uniform vec3 accent_a  : source_color = vec3(1.3, 0.0, 0.25);    // first colour that flows through
uniform vec3 accent_b  : source_color = vec3(0.82, 0.0, 0.25);   // second colour that flows through
// hair colour key -- these are LOW thresholds: a pixel must be brighter than key_val, more
// saturated than key_sat, and within key_hue of red to count as hair. Higher = MORE restrictive
// (selects fewer pixels); set them too high and NOTHING is affected. Ranges are clamped so you
// can't accidentally kill the mask.
uniform float key_val : hint_range(0.0, 0.8) = 0.16;   // min brightness (raise if the coat leaks)
uniform float key_sat : hint_range(0.0, 1.0) = 0.45;   // min saturation
uniform float key_hue : hint_range(0.0, 0.3) = 0.06;   // max hue distance from pure red

// --- metal channel (shoes + gauntlets) ---
uniform float metal_amount : hint_range(0.0, 1.0) = 0.0;   // 0 = untouched; raise to tint the metal
uniform vec3  metal_tint : source_color = vec3(0.6, 0.66, 0.85);  // colour to push the grey metal toward
uniform float metal_glow : hint_range(0.0, 1.5) = 0.0;     // brightness push on the metal -> bloom
uniform float metal_sat_max : hint_range(0.0, 0.6) = 0.25; // metal is GREY: only pixels LESS saturated than this
uniform float metal_val_min : hint_range(0.0, 1.0) = 0.22; // ignore dark outlines below this brightness
uniform float metal_val_max : hint_range(0.0, 1.0) = 0.92; // ignore near-white highlights above this brightness

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 hsv = rgb2hsv(tex.rgb);
	vec3 col = tex.rgb;

	// ---- HAIR ----
	float hue_d = min(hsv.x, 1.0 - hsv.x);  // distance from red (hue wraps at 0/1)
	float mask = smoothstep(key_val - 0.06, key_val + 0.06, hsv.z)
		* smoothstep(key_sat - 0.10, key_sat + 0.10, hsv.y)
		* (1.0 - smoothstep(key_hue, key_hue + 0.05, hue_d))
		* tex.a;

	// two travelling waves over the hair -> the accents flow through the base colour
	float t = TIME * flow_speed;
	float wg = 0.5 + 0.5 * sin((UV.x * 11.0 + UV.y * 7.0) + t * 6.2831);
	float wt = 0.5 + 0.5 * sin((UV.x * 7.0 - UV.y * 10.0) - t * 4.1 + 2.1);

	vec3 pal = base_red;
	pal = mix(pal, accent_a, flow_amount * smoothstep(0.5, 1.0, wg));
	pal = mix(pal, accent_b, flow_amount * 0.6 * smoothstep(0.78, 1.0, wt));

	// reuse the pixel's drawn brightness so the hair keeps its shape -- but LIFT the shadows so it
	// stays vivid. The palette is HDR (>1.0), so once multiplied the whole hair sits above the
	// bloom's 1.0 threshold and glows like his particles; the bright strands glow hardest.
	vec3 hair = pal * mix(0.7, 1.2, pow(hsv.z, 0.9)) * vibrancy;
	hair += hair * glow * smoothstep(0.3, 1.0, max(wg, wt));  // extra aura where colour flows
	col = mix(col, hair, clamp(mask * intensity, 0.0, 1.0));

	// ---- METAL (shoes + gauntlets) ----
	float m_sat = 1.0 - smoothstep(metal_sat_max, metal_sat_max + 0.08, hsv.y);  // grey = low saturation
	float m_val = smoothstep(metal_val_min - 0.04, metal_val_min + 0.04, hsv.z)
		* (1.0 - smoothstep(metal_val_max - 0.04, metal_val_max + 0.04, hsv.z));
	float mm = clamp(m_sat * m_val * tex.a * metal_amount, 0.0, 1.0);
	vec3 metal = metal_tint * mix(0.5, 1.35, pow(hsv.z, 0.9));  // keep the metal's own light/shade
	col = mix(col, metal, mm);
	col += metal * metal_glow * mm;  // additive HDR aura -> real bloom, NOT diluted by the blend amount

	COLOR.rgb = col;
	COLOR.a = tex.a;
}
