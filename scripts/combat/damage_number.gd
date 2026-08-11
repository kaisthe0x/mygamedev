class_name DamageNumber
extends Node2D

## A floating combat-damage number (Risk of Rain style): pops in above the hit, floats straight up,
## fades, and frees itself. ONE per hit, so a flurry throws up a rising cascade. All feel is in the exports.
##
## Parented to the ENEMY and animated in the enemy's LOCAL space: it rides above the enemy's head, so
## it's immune to BOTH the camera chasing the player AND the enemy moving (knockback/patrol) -- the two
## things that dragged earlier world-space / screen-space versions across the screen. (The enemy node
## itself is never scaled/flipped -- only its sprite -- so the text never mirrors.) Motion is an
## explicit per-frame lerp toward a point fixed ABOVE the start, so it can only ever rise. The enemy's
## death fade runs ~1s, longer than this number's life, so a killing-blow number plays out before the
## body frees; if the body frees first, this child frees with it (no orphan).

@export var rise: float = 26.0         ## px it floats UP over its life
@export var drift: float = 12.0        ## max random horizontal drift (px) -- fans stacked hits apart
@export var jitter: float = 8.0        ## random spawn offset (px) so rapid hits don't land exactly atop each other
@export var life: float = 0.8          ## seconds from spawn to freed
@export_range(0.0, 1.0) var hold: float = 0.4  ## fraction of life fully opaque before it starts fading
@export var pop_time: float = 0.14     ## seconds to grow from `pop_scale` to full size

@export_group("Scale + colour by damage")
@export var pop_scale: float = 0.7     ## starting scale of the pop-in
@export var small_dmg: float = 8.0     ## <= this rolls the small/cool end of the ramp
@export var big_dmg: float = 45.0      ## >= this rolls the big/hot end
@export var small_size: int = 16
@export var big_size: int = 30
@export var small_color: Color = Color(1, 1, 1)           ## light hits -- white
@export var big_color: Color = Color(1.4, 0.55, 0.15)     ## heavy hits -- hot gold (HDR >1 blooms on the HDR canvas)
@export var special_color: Color = Color(1.5, 0.35, 1.2)  ## a special's hit -- magenta
@export var outline_color: Color = Color(0, 0, 0, 0.85)   ## keeps it legible over busy VFX
@export var outline_size: int = 5

## Fixed label box: the text is CENTER-aligned inside it, so the number sits dead-centre on our origin
## no matter how the font measures -- centring never depends on a first-frame size guess.
const BOX := Vector2(140, 48)

var _elapsed: float = 0.0
var _start: Vector2 = Vector2.ZERO   ## local spawn position (captured once)
var _target: Vector2 = Vector2.ZERO  ## local end position -- ALWAYS above _start


## Spawn a number for `amount` on `host` (the ENEMY) at `local_pos` above its origin. No-op for <= 0.
static func spawn(host: Node2D, local_pos: Vector2, amount: float, from_special := false) -> void:
	if amount <= 0.0:
		return
	var n := DamageNumber.new()
	host.add_child(n)
	n._setup(local_pos, amount, from_special)


func _setup(local_pos: Vector2, amount: float, from_special: bool) -> void:
	var f := clampf(inverse_lerp(small_dmg, big_dmg, amount), 0.0, 1.0)  # 0 = small hit, 1 = big hit
	var col := special_color if from_special else small_color.lerp(big_color, f)
	var font_size := int(round(lerpf(small_size, big_size, f)))

	var label := Label.new()
	label.text = str(roundi(amount))
	label.size = BOX
	label.position = -BOX * 0.5  # centre the fixed box on our origin
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", col)
	label.add_theme_color_override("font_outline_color", outline_color)
	label.add_theme_constant_override("outline_size", outline_size)
	add_child(label)

	position = local_pos + Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter) * 0.5)
	_start = position
	_target = _start + Vector2(randf_range(-drift, drift), -rise)  # -rise => straight up (local)
	scale = Vector2(pop_scale, pop_scale)


func _process(delta: float) -> void:
	_elapsed += delta
	var u := _elapsed / life
	if u >= 1.0:
		queue_free()
		return
	# Position: explicit lerp start -> target (ease-out). _target is fixed ABOVE _start, so up-only,
	# and it's LOCAL to the enemy -- the enemy carries it, so the camera / knockback can't drag it.
	var ease_out := 1.0 - (1.0 - u) * (1.0 - u)
	position = _start.lerp(_target, ease_out)
	# Quick grow-in, then hold at full size.
	scale = Vector2.ONE * minf(pop_scale + (1.0 - pop_scale) * (_elapsed / pop_time), 1.0)
	# Fully opaque until `hold` of the life, then fade to 0.
	modulate.a = 1.0 if u <= hold else clampf(1.0 - (u - hold) / (1.0 - hold), 0.0, 1.0)
