shader_type canvas_item;

// Full-screen LOW-HEALTH post effect: washes the WHOLE screen with a red hue, scaled by `intensity`
// (0 = identity, driven from the player's HP by the HUD in hud.gd). A gentle edge darken adds depth
// WITHOUT a hard bright frame. Lives on a CanvasLayer BELOW the HUD, so the UI stays crisp; it samples
// the screen, so it must draw AFTER the world (its layer > the world's) -- see HUD._build_low_health.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;    // overall strength (HP ramp x heartbeat pulse)
uniform float desaturate : hint_range(0.0, 1.0) = 0.4;   // pull colour out a touch before the red tint
uniform vec3 red_tint = vec3(1.25, 0.30, 0.32);          // the whole screen multiplies toward this red
uniform float vignette : hint_range(0.0, 1.0) = 0.3;     // subtle edge darken (0 = flat, even wash)
uniform float vignette_reach : hint_range(0.0, 1.0) = 0.6; // how far in the edge darken starts

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));

	// Whole-screen red wash: desaturate slightly, tint toward red, then blend over the original by
	// intensity (identity at 0). Applied EVERYWHERE evenly -- no untouched centre rectangle.
	vec3 washed = mix(col, vec3(lum), desaturate) * red_tint;
	vec3 outc = mix(col, washed, intensity);

	// Subtle radial vignette -- just darkens the far edges for depth. Multiplicative, so it never adds
	// a glowing red border; soft falloff so there's no visible frame line.
	float r = length(SCREEN_UV - vec2(0.5)) * 1.42;   // 0 centre -> ~1 corners
	float v = smoothstep(vignette_reach, 1.2, r) * vignette * intensity;
	outc *= 1.0 - v;

	COLOR = vec4(outc, 1.0);
}
