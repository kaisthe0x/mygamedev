class_name StatusOverlay
extends Node2D

## Engulfs a sprite in a coloured overlay for a duration -- e.g. the green cast
## of a freeze. It mirrors the target AnimatedSprite2D (frame, flip, offset) with
## an additive tint drawn on top, so the character shape glows in that colour
## whether it's animating or frozen on a pose. Reusable for any status.

var _target: AnimatedSprite2D
var _overlay: AnimatedSprite2D
var _time: float = 0.0


func setup(target: AnimatedSprite2D) -> void:
	_target = target
	_overlay = AnimatedSprite2D.new()
	_overlay.z_index = 1  # above the base sprite
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
	_sync()


func _sync() -> void:
	_overlay.sprite_frames = _target.sprite_frames
	_overlay.animation = _target.animation
	_overlay.frame = _target.frame
	_overlay.flip_h = _target.flip_h
	_overlay.centered = _target.centered
	_overlay.offset = _target.offset
