class_name ExitGate
extends Area2D

## The level exit — a REWARD DOOR the player walks into to leave. It only DETECTS the player and
## reports contact (`touched`); RunManager owns the transition, so all run logic stays in one place.
## Built entirely in code by RunManager.
##
## Each level's door has a random TYPE (health / athletic / attack / special) — shown by its icon +
## label — telling the player what reward they'll pick. The door is LOCKED (red) until the arena is
## CLEARED (every enemy dead), then it OPENS (its type colour) and walking in ends the level.

signal touched ## the player body entered the gate

const SIZE := Vector2(44, 96)

## door type -> label + accent colour (also used to tint the door when open).
const TYPES := {
	"health": {"label": "HEALTH", "color": Color(0.35, 0.85, 0.45)},
	"athletic": {"label": "ATHLETIC", "color": Color(0.45, 0.75, 1.0)},
	"attack": {"label": "ATTACK", "color": Color(1.0, 0.55, 0.35)},
	"special": {"label": "SPECIAL", "color": Color(0.9, 0.5, 1.0)},
}

var door_type := "health"

var _fill: ColorRect
var _icon: TextureRect
var _label: Label
var _open := false


func setup(type: String) -> void:
	door_type = type if TYPES.has(type) else "health"
	collision_layer = 0
	collision_mask = Combat.L_PLAYER_BODY # detect the player's body
	add_child(Shapes.make_box(SIZE, Vector2(0, -SIZE.y / 2.0)))

	_fill = ColorRect.new()
	_fill.size = SIZE
	_fill.position = Vector2(-SIZE.x / 2.0, -SIZE.y)
	_fill.color = Color(0.7, 0.2, 0.2, 0.5) # locked (red) until the arena is cleared
	add_child(_fill)

	# The reward-type icon, centred on the door (from the Icons registry — temp art for now).
	_icon = TextureRect.new()
	_icon.texture = Icons.door(door_type)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size = Vector2(36, 36)
	_icon.position = Vector2(-18, -SIZE.y / 2.0 - 18)
	add_child(_icon)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(-70, -SIZE.y - 26)
	_label.size = Vector2(140, 20)
	_label.text = "%s · LOCKED" % TYPES[door_type]["label"]
	_label.add_theme_color_override("font_color", Color(1, 0.6, 0.6))
	add_child(_label)

	body_entered.connect(func(_b: Node) -> void: touched.emit())


## Open (cleared) → the type's accent colour + "<TYPE>"; locked → red + "<TYPE> · LOCKED".
## Called each frame by RunManager.
func reflect(open: bool) -> void:
	if open == _open:
		return
	_open = open
	var accent: Color = TYPES[door_type]["color"]
	_fill.color = Color(accent.r, accent.g, accent.b, 0.5) if open else Color(0.7, 0.2, 0.2, 0.5)
	_label.text = TYPES[door_type]["label"] if open else "%s · LOCKED" % TYPES[door_type]["label"]
	_label.add_theme_color_override("font_color", accent if open else Color(1, 0.6, 0.6))
