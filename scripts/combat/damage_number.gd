class_name DamageNumber
extends Node2D

## A floating combat-damage number (Risk of Rain style): pops from a hit, drifts up, fades, and frees
## itself. World-space -- spawn one into the level's content layer at the victim's position via
## DamageNumber.spawn(). ONE per hit, so a flurry throws up a rising cascade. All feel is in the
## exports below; edit + re-run to tune. Sibling of FloatingHealthBar (both world-space combat feedback).

@export var rise: float = 30.0         ## px it floats UP over its life
@export var drift: float = 14.0        ## max random horizontal drift (px) -- fans stacked hits apart
@export var jitter: float = 10.0       ## random spawn offset (px) so rapid hits don't land exactly atop each other
@export var life: float = 0.75         ## seconds from spawn to freed

@export_group("Scale + colour by damage")
@export var small_dmg: float = 8.0     ## <= this rolls the small/cool end of the ramp
@export var big_dmg: float = 45.0      ## >= this rolls the big/hot end
@export var small_size: int = 14
@export var big_size: int = 28
@export var small_color: Color = Color(1, 1, 1)           ## light hits -- white
@export var big_color: Color = Color(1.4, 0.55, 0.15)     ## heavy hits -- hot gold (HDR >1 blooms on the HDR canvas)
@export var special_color: Color = Color(1.5, 0.35, 1.2)  ## a special's hit -- magenta
@export var outline_color: Color = Color(0, 0, 0, 0.85)   ## keeps it legible over busy VFX
@export var outline_size: int = 5


## Spawn a number for `amount` at `world_pos` under `parent` -- the WORLD/content layer, NOT the enemy
## (so it rises independently and outlives the enemy on an overkill hit). No-op for 0 / negative.
static func spawn(parent: Node, world_pos: Vector2, amount: float, from_special := false) -> void:
	if amount <= 0.0:
		return
	var n := DamageNumber.new()
	parent.add_child(n)
	n.global_position = world_pos
	n._play(amount, from_special)


func _play(amount: float, from_special: bool) -> void:
	var f := clampf(inverse_lerp(small_dmg, big_dmg, amount), 0.0, 1.0)  # 0 = small hit, 1 = big hit
	var col := special_color if from_special else small_color.lerp(big_color, f)
	var font_size := int(round(lerpf(small_size, big_size, f)))

	var label := Label.new()
	label.text = str(roundi(amount))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", col)
	label.add_theme_color_override("font_outline_color", outline_color)
	label.add_theme_constant_override("outline_size", outline_size)
	add_child(label)
	label.reset_size()
	label.position = -label.size * 0.5  # centre the text on our origin

	# Scatter the spawn a touch, then pop in + rise + fade. modulate/scale on the Node2D carry the Label.
	position += Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter) * 0.5)
	scale = Vector2(0.55, 0.55)
	var target := position + Vector2(randf_range(-drift, drift), -rise)
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position", target, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 0.0, life * 0.5).set_delay(life * 0.5)
	t.finished.connect(queue_free)
