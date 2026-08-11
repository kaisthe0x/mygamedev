class_name StatusOverlay
extends Node2D

## Engulfs a sprite in a coloured overlay for a duration -- e.g. the green cast
## of a freeze. It mirrors the target AnimatedSprite2D (frame, flip, offset) with
## an additive tint drawn on top, so the character shape glows in that colour
## whether it's animating or frozen on a pose. Reusable for any status.

var _target: AnimatedSprite2D
var _overlay: AnimatedSprite2D
var _time: float = 0.0
var _color: Color = Color.WHITE
var _phase: float = 0.0


## Build the additive overlay sprite that mirrors `target`, hidden until show_for().
func setup(target: AnimatedSprite2D) -> void:
	_target = target
	_overlay = AnimatedSprite2D.new()
	_overlay.z_index = 1 # above the base sprite
	_overlay.visible = false
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_overlay.material = mat
	add_child(_overlay)
	set_process(false)


## Show the overlay tinted `color` for `duration` seconds.
func show_for(color: Color, duration: float) -> void:
	if _target == null or duration <= 0.0:
		return
	_color = color
	_phase = 0.0
	_overlay.modulate = color
	_time = duration
	_overlay.visible = true
	_sync()
	set_process(true)


func _process(delta: float) -> void:
	_time -= delta
	if _time <= 0.0:
		_overlay.visible = false
		set_process(false)
		return
	# Throb the tint so an active status reads at a glance instead of a static wash.
	_phase += delta
	_overlay.modulate = _color * (0.68 + 0.32 * sin(_phase * 7.5))
	_sync()


## Copy the target sprite's frame/flip/offset onto the overlay so the tint tracks
## the exact pose, animating or frozen.
func _sync() -> void:
	_overlay.sprite_frames = _target.sprite_frames
	_overlay.animation = _target.animation
	_overlay.frame = _target.frame
	_overlay.flip_h = _target.flip_h
	_overlay.centered = _target.centered
	_overlay.offset = _target.offset
	_overlay.scale = _target.scale # track the hit-react squash so the tint deforms with the body
