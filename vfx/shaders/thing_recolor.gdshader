shader_type canvas_item;

// Recolour + GLOW a "thing" whose colour is baked into its (dark) texture -- the launch orb. Rather than
// a hue-shift (which kept the art's darkness and rendered near-black, and leaned on hsv helpers that a
// straight canvas shader compiles more fragilely), this paints every pixel a single `tint` scaled by how
// BRIGHT the baked pixel is -- so the orb's shading gradient is preserved but its colour + brightness come
// from here. `tint` is set to the chosen power-family colour (VfxPalette), so the orb follows the palette;
// `glow` lifts it past 1.0 so it BLOOMS through the 2D HDR background (the fix for the dark-art black orb);
// `shine` is the extra proximity lift. Mirrors the proven enemy_glow.gdshader shape (no hsv, no COLOR mul).

uniform vec4 tint : source_color = vec4(1.0, 0.22, 0.26, 1.0); // orb colour (set to the power hue)
uniform float glow : hint_range(0.0, 8.0) = 3.0;  // base brightness lift (blooms via HDR)
uniform float shine : hint_range(0.0, 4.0) = 0.0; // extra lift while Khalid is in range (proximity)

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float b = max(t.r, max(t.g, t.b)); // brightness of the baked pixel -> keeps the orb's shading
	COLOR = vec4(tint.rgb * b * (glow + shine), t.a);
}
