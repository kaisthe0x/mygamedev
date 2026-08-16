class_name VfxPalette

## POWER / VFX recolour -- the emitter-side counterpart to PaletteConfig (which recolours the body).
##
## Khalid's effects collapse to three well-separated hue FAMILIES (a colour audit of every gradient):
##   red  ~0°  (the signature crimson + all its HDR/pink/brown variants -- the vast majority)
##   gold ~50° (dash-triad gold, collar sparks)
##   teal ~176° (dash-triad teal, frenemy/blink cyan)
## plus NEUTRALS (white/grey/black highlights + cores) and rare outliers (come_closer's purple).
##
## Because the families are far apart in hue, we DON'T need to pre-bake the 37 effect scenes to a fixed
## palette. Instead we recolour at SPAWN time: classify each gradient stop by hue, and swap ONLY its hue
## to the player's picked colour while keeping the stop's own saturation, brightness (incl. HDR >1 for
## bloom) and alpha. So "blue attacks" is the exact same effect as today's red, rotated in hue -- the
## glow, the fade, the HDR bloom all survive. Neutrals and unmatched hues (the purple) are left alone, so
## white-hot cores and smoke stay neutral. This mirrors the body recolour philosophy: only colour moves.
##
## `picks` (family -> Color) is set once per run from the colour-picker screen; empty == identity (the
## default red/gold/teal look). ParticleDirector._spawn calls recolor_tree() on every effect it makes.

## Family hue centres, Godot hue units (0..1 == 0..360°). Kept far apart so classify() is unambiguous.
const FAMILIES := {
	"red": 0.0,
	"gold": 0.14,   # ~50°
	"teal": 0.49,   # ~176°
}
const SAT_FLOOR := 0.28    ## below this a pixel is a NEUTRAL (white/grey core, smoke) -- never recoloured
const HUE_TOL := 0.11      ## a stop must sit within this of a family centre, else it's left untouched

## The player's picks: family name -> chosen Color. Empty == no change (identity). Static so any spawn
## path can honour it without threading state; set from the picker / run profile at run start.
static var picks := {}


static func set_picks(new_picks: Dictionary) -> void:
	picks = new_picks.duplicate()


## Which family a colour belongs to ("" = neutral/unmatched -> leave as-is). Hue-based, with a saturation
## floor so near-grey cores and a hue tolerance so true outliers (purple) don't get grabbed.
static func classify(c: Color) -> String:
	if c.s < SAT_FLOOR:
		return ""
	var best := ""
	var bestd := 999.0
	for fam in FAMILIES:
		var d := _hue_dist(c.h, FAMILIES[fam])
		if d < bestd:
			bestd = d
			best = fam
	return best if bestd <= HUE_TOL else ""


static func _hue_dist(a: float, b: float) -> float:
	var d: float = absf(a - b)
	return minf(d, 1.0 - d)


## The picked HUE (0..1) for the family `sample` belongs to, or -1 if there's no pick / no match.
## For recolouring a "thing" whose colour is BAKED INTO ITS TEXTURE (a sprite, not a modulate/ramp),
## which recolor_tree can't touch: feed this hue to a hue-replace shader (see vfx/shaders/thing_recolor)
## so the sprite follows the same family pick the rope/effects do. Sample a representative pixel colour.
static func hue_for(sample: Color) -> float:
	if picks.is_empty():
		return -1.0
	var fam := classify(sample)
	if fam == "" or not picks.has(fam):
		return -1.0
	return (picks[fam] as Color).h


## Recolour ONE colour by the current picks: adopt the picked family's HUE, keep this stop's own
## saturation + value (HDR preserved) + alpha. No pick for the family, or unmatched -> returned unchanged.
static func recolor(c: Color) -> Color:
	if picks.is_empty():
		return c
	var fam := classify(c)
	if fam == "" or not picks.has(fam):
		return c
	var target: Color = picks[fam]
	return Color.from_hsv(target.h, c.s, c.v, c.a)


## Recolour an entire freshly-instantiated effect subtree in place: every particle colour / ramp /
## modulate on the node and its descendants. Safe to call once on spawn (mutates this instance's own
## sub-resources; gradients are duplicated first so a shared resource is never clobbered).
static func recolor_tree(root: Node) -> void:
	if picks.is_empty():
		return
	_recolor_node(root)
	for child in root.get_children():
		recolor_tree(child)


static func _recolor_node(n: Node) -> void:
	# Node-level tints most 2D visuals carry.
	if n is CanvasItem:
		n.self_modulate = recolor(n.self_modulate)
	# Line2D outline/trail colour.
	if n is Line2D:
		n.default_color = recolor(n.default_color)
	# CPUParticles2D: flat colour + the two ramps.
	if n is CPUParticles2D:
		n.color = recolor(n.color)
		n.color_ramp = _recolored_gradient(n.color_ramp)
		n.color_initial_ramp = _recolored_gradient(n.color_initial_ramp)
	# GPUParticles2D: colour lives on the ParticleProcessMaterial (duplicated so instances don't share).
	if n is GPUParticles2D:
		var pm: Material = n.process_material
		if pm is ParticleProcessMaterial:
			var dup := pm.duplicate() as ParticleProcessMaterial
			dup.color = recolor(dup.color)
			dup.color_ramp = _recolored_gradient_tex(dup.color_ramp)
			dup.color_initial_ramp = _recolored_gradient_tex(dup.color_initial_ramp)
			n.process_material = dup
	# Gradient-as-texture trick: MANY effects colour their particles by assigning a GradientTexture to
	# `texture` (e.g. the dash Trail), not to `color`/`color_ramp` -- recolour that too. A normal sprite
	# texture is returned untouched.
	if "texture" in n:
		n.texture = _recolored_gradient_tex(n.texture)


## A recoloured COPY of a Gradient (never mutates the original -- scene sub-resources are shared across
## instances, so in-place edits would compound the one-way hue swap across spawns). Null-safe.
static func _recolored_gradient(g: Gradient) -> Gradient:
	if g == null:
		return null
	var dup := g.duplicate() as Gradient
	for i in dup.get_point_count():
		dup.set_color(i, recolor(dup.get_color(i)))
	return dup


## A recoloured COPY of a GradientTexture1D/2D (with a fresh recoloured gradient). Any other texture
## (a normal sprite) is returned unchanged, so this is safe to call on every `texture` property.
static func _recolored_gradient_tex(t: Texture2D) -> Texture2D:
	if t is GradientTexture1D or t is GradientTexture2D:
		var dt := t.duplicate() as Texture2D
		dt.gradient = _recolored_gradient(t.gradient)
		return dt
	return t
