class_name PaletteConfig

## The character's canonical BODY palette -- 6 MATERIALS, each 5 shades + 1 rim (the dark outline tint),
## ordered LIGHT -> DARK. These hex values are the EXACT colours baked into Khalid's repaletted sprite
## sheets (from tools/repalette; source of truth = repalette.py PALETTE). The 36 colours (6x6) map 1:1
## to the sprite's pixels, so a palette-swap shader (vfx/shaders/sprite_palette.gdshader) can remap them
## LIVE: match each pixel to its `src` slot, output the chosen `dst` slot.
##
## Materials map 1:1 to the game's colour families:
##   hair = RED · skin = TEAL · jacket = BROWN (coat) · trim = YELLOW · pants = GREEN · metal = GREY
##   (metal covers both gauntlets + boots -- one material today; see the design notes to split them.)
##
## A colour picker / profile recolours a material by supplying ONE base colour; `derive()` keeps that
## material's light->dark VALUE ramp (its shading) and adopts the base's HUE + SATURATION, so the player
## picks a single swatch per part and all 5 shades + rim follow.

const MATERIALS := ["hair", "skin", "jacket", "trim", "pants", "metal"]
const SHADES_PER := 6  ## 5 shades + 1 rim, light -> dark
const COUNT := 36  ## MATERIALS.size() * SHADES_PER -- the shader LUT length

## Default per-material HDR glow push for the material-aware LUT shader (sprite_palette.gdshader `glow`),
## index-aligned to MATERIALS. Hair blooms strongly (his signature living red); trim (gold) + metal get
## a soft sheen; skin/jacket/pants are flat cloth. Tune these to change how much each part glows.
const MATERIAL_GLOW := [3.2, 0.0, 0.0, 0.8, 0.0, 0.4]  # hair, skin, jacket, trim, pants, metal


## The default glow array as a PackedFloat32Array, ready for set_shader_parameter("glow", ...).
static func glow_floats() -> PackedFloat32Array:
	return PackedFloat32Array(MATERIAL_GLOW)


const BODY_SHADER := "res://vfx/shaders/sprite_palette.gdshader"

## Effect params for the material-aware LUT -- the ONE source of truth shared by the preview and the
## in-game player, so what you tune in the picker is exactly what the run shows. Tune the look here.
const VIBRANCY := 0.4
const FLOW_SPEED := 1.1
const FLOW_AMOUNT := 0.6
const FLOW_FREQ := 8.0
const FLOW_SHIFT := 2
const HAIR_SURGE_COLOR := Color(2.6, 1.7, 0.5)  ## Ruh-absorb flare target (HDR gold); player drives the mix

## The player's chosen BODY picks {material -> Color}, set once at run start from the picker screen;
## empty == the default palette. Static so it survives the pre-game screen -> run scene change.
static var picks := {}


static func set_picks(new_picks: Dictionary) -> void:
	picks = new_picks.duplicate()


## Build a ready-to-use body ShaderMaterial: the LUT recolour (from `body_picks`, default = default look)
## plus every effect param. Used by BOTH the preview and player._apply_character, so they always match.
static func make_material(body_picks: Dictionary = picks) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(BODY_SHADER)
	m.set_shader_parameter("src", to_linear_vec3(default_flat()))
	m.set_shader_parameter("dst", to_linear_vec3(build_targets(body_picks)))
	m.set_shader_parameter("glow", glow_floats())
	m.set_shader_parameter("vibrancy", VIBRANCY)
	m.set_shader_parameter("flow_speed", FLOW_SPEED)
	m.set_shader_parameter("flow_amount", FLOW_AMOUNT)
	m.set_shader_parameter("flow_freq", FLOW_FREQ)
	m.set_shader_parameter("flow_shift", FLOW_SHIFT)
	# HAIR_SURGE_COLOR is already a linear working-space HDR value (like the old base_red), so it is fed
	# straight through -- NOT srgb_to_linear'd (that would double-convert and over-brighten it).
	m.set_shader_parameter("hair_surge_color", Vector3(HAIR_SURGE_COLOR.r, HAIR_SURGE_COLOR.g, HAIR_SURGE_COLOR.b))
	return m

## material -> [5 shades + rim], hex, LIGHT -> DARK. From repalette.py PALETTE (keep in sync if the
## masters are ever re-swatched). Human-readable families noted above.
const DEFAULT := {
	"hair": ["#941E1E", "#811A1A", "#721717", "#651414", "#531111", "#330A0A"],
	"skin": ["#0DA29B", "#0B8B84", "#086863", "#064946", "#021F1E", "#021312"],
	"jacket": ["#52382B", "#4B3328", "#37261D", "#271B15", "#160F0C", "#0E0907"],
	"trim": ["#EBE123", "#D1C81F", "#A7A019", "#797412", "#3B3809", "#242305"],
	"pants": ["#34432F", "#2F3D2B", "#293525", "#1D251A", "#161C14", "#0E120C"],
	"metal": ["#8E969E", "#60656A", "#43474B", "#2A2C2E", "#141516", "#0D0D0E"],
}


## The default 36 colours flattened in MATERIALS order (each material's 6 shades in turn). This IS the
## shader's `src` array; a `dst` list built in the SAME order recolours the sprite.
static func default_flat() -> Array[Color]:
	var out: Array[Color] = []
	for m in MATERIALS:
		for hex in DEFAULT[m]:
			out.append(Color(hex))
	return out


## Recolour one material from a single `base`, ANCHORED BY VALUE. The picked colour lands verbatim on
## the shade whose lightness is closest to it (its "natural" slot), and every other shade shifts by the
## same delta -- so the light->dark spacing (the shading) is preserved, but the exact colour you picked
## appears on the band that covers most of the part. This fixes "I picked a bright colour but it showed
## up deeper": a bright pick lifts the whole ramp, a dark pick lowers it, without collapsing contrast
## (the anchor is the NEAREST shade, so the shift is small even at the extremes). Adopts `base`'s hue +
## saturation for all shades. Returns the 6 shades (5 + rim).
static func derive(material: String, base: Color) -> Array[Color]:
	var shades: Array = DEFAULT[material]
	# Anchor = the default shade whose value is nearest the pick's value; shift the ramp onto it.
	var anchor_v: float = Color(shades[0]).v
	var best_diff := 999.0
	for hex in shades:
		var v: float = Color(hex).v
		if absf(v - base.v) < best_diff:
			best_diff = absf(v - base.v)
			anchor_v = v
	var delta: float = base.v - anchor_v
	var out: Array[Color] = []
	for hex in shades:
		var d := Color(hex)
		out.append(Color.from_hsv(base.h, base.s, clampf(d.v + delta, 0.0, 1.0), d.a))
	return out


## A full 36-colour target list from a {material -> base Color} pick set (missing materials keep their
## default). Feed this (converted to linear) into the shader's `dst`.
static func build_targets(body_picks: Dictionary) -> Array[Color]:
	var out: Array[Color] = []
	for m in MATERIALS:
		if body_picks.has(m):
			out.append_array(derive(m, body_picks[m]))
		else:
			for hex in DEFAULT[m]:
				out.append(Color(hex))
	return out


## Colours -> a PackedVector3Array in LINEAR space (HDR 2D samples linear, so the shader's src/dst must
## be linear for the per-pixel match to be exact). Pass the result straight to set_shader_parameter.
static func to_linear_vec3(colors: Array[Color]) -> PackedVector3Array:
	var out := PackedVector3Array()
	for c in colors:
		var l := c.srgb_to_linear()
		out.append(Vector3(l.r, l.g, l.b))
	return out
