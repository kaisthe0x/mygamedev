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
@export var name_size := 6

var _ratio: float = 1.0
var _label: Label


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


func set_ratio(value: float) -> void:
	_ratio = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var w := bar_width
	var h := bar_height
	var origin := Vector2(-w / 2.0, -h)
	# Border + background, then the fill.
	draw_rect(Rect2(origin - Vector2.ONE, Vector2(w + 2, h + 2)), border_color)
	draw_rect(Rect2(origin, Vector2(w, h)), bg_color)
	if _ratio > 0.0:
		draw_rect(Rect2(origin, Vector2(w * _ratio, h)), fill_color)
