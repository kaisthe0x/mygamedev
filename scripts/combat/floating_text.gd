class_name FloatingText
extends Node2D

## A global floating-text emitter (Risk of Rain style): pops a label above a host and floats it up, then
## frees itself. ONE call does it: `FloatingText.emit(type, host, local_pos, text, magnitude)`. The LOOK
## and the IN/OUT transition come entirely from the TYPE preset (configs/floating_text_types.gd) -- so
## damage numbers and a "perfect!" callout animate differently with zero code changes here.
##
## Parented to the `host` and animated in its LOCAL space, so it rides along with a moving enemy/player
## and is immune to the camera (see the damage-number history). Motion is an explicit per-frame lerp
## toward a point fixed ABOVE the start, so it can only rise. Config-driven; all feel lives in the preset.

## Fixed label box -- text is CENTER-aligned inside it, so a label sits dead-centre on our origin no
## matter how the font measures (no first-frame size guess). Wide enough for a short word like "Perfect!".
const BOX := Vector2(220, 60)

var _elapsed: float = 0.0
var _start: Vector2 = Vector2.ZERO
var _target: Vector2 = Vector2.ZERO
var _life: float = 0.8
var _hold: float = 0.4
var _pop_scale: float = 0.7
var _pop_time: float = 0.14
var _fade_in: bool = false


## Emit a `type` label reading `text` at `local_pos` on `host` (parented to it). `magnitude` drives the
## size/colour ramp for types that define one (e.g. damage). No-op on an unknown type.
static func emit(type: String, host: Node2D, local_pos: Vector2, text: String, magnitude: float = 0.0) -> void:
	var cfg: Dictionary = FloatingTextTypes.TYPES.get(type, {})
	if cfg.is_empty():
		push_warning("FloatingText: unknown type '%s'" % type)
		return
	var n := FloatingText.new()
	host.add_child(n)
	n._setup(cfg, local_pos, text, magnitude)


func _setup(cfg: Dictionary, local_pos: Vector2, text: String, magnitude: float) -> void:
	# Size + colour: fixed, or ramped by magnitude when the preset defines a range.
	var f := 0.0
	if cfg.has("mag_lo"):
		f = clampf(inverse_lerp(cfg["mag_lo"], cfg.get("mag_hi", cfg["mag_lo"] + 1.0), magnitude), 0.0, 1.0)
	var size := int(cfg.get("size", roundi(lerpf(cfg.get("size_lo", 18), cfg.get("size_hi", 18), f))))
	var col: Color = cfg.get("color", (cfg.get("color_lo", Color.WHITE) as Color).lerp(cfg.get("color_hi", Color.WHITE), f))

	var label := Label.new()
	label.text = text
	label.size = BOX
	label.position = -BOX * 0.5
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", col)
	label.add_theme_color_override("font_outline_color", cfg.get("outline_color", Color(0, 0, 0, 0.85)))
	label.add_theme_constant_override("outline_size", int(cfg.get("outline_size", 5)))
	var font_path: String = cfg.get("font", "")
	if font_path != "" and ResourceLoader.exists(font_path):
		label.add_theme_font_override("font", load(font_path))
	add_child(label)

	# Fake ITALIC: a Label has no italic flag, so slant the whole node (shear). The label is centred on
	# our origin, so it leans symmetrically. `italic` = on at a default lean; `italic_deg` sets the angle.
	if cfg.get("italic", false):
		skew = deg_to_rad(cfg.get("italic_deg", 12.0))

	_life = cfg.get("life", 0.8)
	_hold = cfg.get("hold", 0.4)
	_pop_scale = cfg.get("pop_scale", 0.7)
	_pop_time = maxf(cfg.get("pop_time", 0.14), 0.001)
	_fade_in = cfg.get("fade_in", false)
	var jitter: float = cfg.get("jitter", 8.0)
	position = local_pos + Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter) * 0.5)
	_start = position
	_target = _start + Vector2(randf_range(-cfg.get("drift", 12.0), cfg.get("drift", 12.0)), -cfg.get("rise", 26.0))
	scale = Vector2(_pop_scale, _pop_scale)


func _process(delta: float) -> void:
	_elapsed += delta
	var u := _elapsed / _life
	if u >= 1.0:
		queue_free()
		return
	# Position: explicit lerp start -> target (ease-out), fixed ABOVE start -> up-only, immune to camera.
	var ease_out := 1.0 - (1.0 - u) * (1.0 - u)
	position = _start.lerp(_target, ease_out)
	# TRANSITION IN: grow pop_scale -> 1.0 over pop_time.
	scale = Vector2.ONE * minf(_pop_scale + (1.0 - _pop_scale) * (_elapsed / _pop_time), 1.0)
	# Alpha: optional fade-IN over pop_time, then opaque until `hold`, then fade OUT over the remainder.
	if _fade_in and _elapsed < _pop_time:
		modulate.a = _elapsed / _pop_time
	elif u > _hold:
		modulate.a = clampf(1.0 - (u - _hold) / (1.0 - _hold), 0.0, 1.0)
	else:
		modulate.a = 1.0
