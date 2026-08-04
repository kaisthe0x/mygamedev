class_name ExitGate
extends Area2D

## The level exit — a "door" the player walks into to leave. It only DETECTS the player and
## reports contact (`touched`); RunManager owns the decision (can they afford the toll?) and the
## transition, so all the run logic stays in one place. Built entirely in code by RunManager.
##
## Cost is life (HP + lahm). See docs/game-design.md. The gate colours itself green when the
## player can afford it, red when they can't — a clear "is the door open?" read.

signal touched  ## the player body entered the gate

const SIZE := Vector2(44, 96)
var cost: float = 0.0

var _fill: ColorRect
var _cost_label: Label
var _affordable := false


func setup(gate_cost: float) -> void:
	cost = gate_cost
	collision_layer = 0
	collision_mask = Combat.L_PLAYER_BODY  # detect the player's body
	add_child(Shapes.make_box(SIZE, Vector2(0, -SIZE.y / 2.0)))

	_fill = ColorRect.new()
	_fill.size = SIZE
	_fill.position = Vector2(-SIZE.x / 2.0, -SIZE.y)
	_fill.color = Color(0.2, 0.7, 0.35, 0.5)
	add_child(_fill)

	_cost_label = Label.new()
	_cost_label.add_theme_font_size_override("font_size", 13)
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_label.position = Vector2(-60, -SIZE.y - 26)
	_cost_label.size = Vector2(120, 20)
	_cost_label.text = "EXIT · %d" % roundi(cost)
	add_child(_cost_label)

	body_entered.connect(func(_b: Node) -> void: touched.emit())


## Recolour to reflect whether `player` can currently afford the toll (called each frame by
## RunManager so the door reads open/closed live as lahm rises).
func reflect(can_afford: bool) -> void:
	if can_afford == _affordable:
		return
	_affordable = can_afford
	_fill.color = Color(0.2, 0.7, 0.35, 0.55) if can_afford else Color(0.7, 0.2, 0.2, 0.5)
	_cost_label.add_theme_color_override("font_color",
		Color(0.6, 1, 0.7) if can_afford else Color(1, 0.6, 0.6))
