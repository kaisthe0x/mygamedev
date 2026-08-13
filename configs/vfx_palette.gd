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
		_recolor_gradient(n.color_ramp)
		_recolor_gradient(n.color_initial_ramp)
	# GPUParticles2D: colour lives on the ParticleProcessMaterial.
	if n is GPUParticles2D:
		var pm: Material = n.process_material
		if pm is ParticleProcessMaterial:
			pm.color = recolor(pm.color)
			_recolor_gradient_tex(pm.color_ramp)
			_recolor_gradient_tex(pm.color_initial_ramp)


## Recolour a Gradient's stops in place (duplicating so a resource shared across instances is untouched).
static func _recolor_gradient(g: Gradient) -> void:
	if g == null:
		return
	for i in g.get_point_count():
		g.set_color(i, recolor(g.get_color(i)))


## Same, for a GradientTexture1D/2D wrapping a Gradient.
static func _recolor_gradient_tex(t: Texture2D) -> void:
	if t is GradientTexture1D or t is GradientTexture2D:
		_recolor_gradient(t.gradient)
