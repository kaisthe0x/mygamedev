class_name FloatingHealthBar
extends Node2D

## Small world-space health bar with an optional name, hovering above an enemy.
## Built in code so any enemy/boss can add one without a scene. Diegetic: it
## sits in the world and scales with the camera like everything else.

@export var bar_width: float = 26.0
@export var bar_height: float = 3.0
@export var bg_color := Color(0.09, 0.09, 0.11, 0.85)
@export var border_color := Color(0, 0, 0, 0.85)
@export var fill_color := Color(0.82, 0.24, 0.24)
## When true the fill is coloured by how full the bar is -- green high, orange mid, red low
## (see color_for_ratio) instead of the fixed `fill_color`. On for HEALTH bars (enemy + the HUD
## uses the same thresholds); off for a plain gauge like the player's gold cooldown bar.
@export var ratio_colors: bool = false
@export var name_size := 6

# Shared health-fill thresholds + colours, so every health bar (this one AND the HUD's ProgressBar)
# reads the SAME green/orange/red from one place. Tweak here to retune every health bar at once.
const LOW_RATIO := 0.25   ## at/below -> red (danger)
const MID_RATIO := 0.5    ## at/below (but above LOW) -> orange; above -> green
const COLOR_HIGH := Color(0.30, 0.80, 0.32)  ## green -- healthy
const COLOR_MID := Color(0.95, 0.62, 0.16)   ## orange -- getting low
const COLOR_LOW := Color(0.86, 0.22, 0.22)   ## red -- danger

var _ratio: float = 1.0
var _label: Label


## Green (high) / orange (mid) / red (low) for a 0..1 fill fraction. Static so the HUD health
## ProgressBar can tint itself from the exact same bands as the floating enemy bars.
static func color_for_ratio(r: float) -> Color:
	if r <= LOW_RATIO:
		return COLOR_LOW
	if r <= MID_RATIO:
		return COLOR_MID
	return COLOR_HIGH


## Add the floating name label above the bar. No name -> bar only.
func setup(display_name: String) -> void:
	if display_name.is_empty():
		return
	_label = Label.new()
	_label.text = display_name
	_label.add_theme_font_size_override("font_size", name_size)
	_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.96))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 3)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Bottom-align the text and sit the box just over the bar, so the name hugs it.
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.size = Vector2(80, name_size + 4)
	_label.position = Vector2(-40, -bar_height - name_size - 5)
	add_child(_label)


## Set the fill fraction (0..1, clamped) and redraw.
func set_ratio(value: float) -> void:
	_ratio = clampf(value, 0.0, 1.0)
	queue_redraw()


## Draw the border, background, then the fill bar (width scaled by the ratio).
func _draw() -> void:
	var w := bar_width
	var h := bar_height
	var origin := Vector2(-w / 2.0, -h)
	# Border + background, then the fill.
	draw_rect(Rect2(origin - Vector2.ONE, Vector2(w + 2, h + 2)), border_color)
	draw_rect(Rect2(origin, Vector2(w, h)), bg_color)
	if _ratio > 0.0:
		var fc := color_for_ratio(_ratio) if ratio_colors else fill_color
		draw_rect(Rect2(origin, Vector2(w * _ratio, h)), fc)
