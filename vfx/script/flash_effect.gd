class_name FlashEffect
extends Node2D

## A one-shot DRAWN burst effect -- a slash, a spark -- that briefly grows + fades its
## Sprite2D / AnimatedSprite2D visuals, then frees itself.
##
## Use this instead of a CPUParticles2D when the effect is a DIRECTIONAL drawn texture:
## a Sprite2D h-flips cleanly under the director's facing scale flip (texture + rotation
## and all), whereas a CPUParticles2D does NOT reliably mirror its particle sprites. The
## ParticleDirector fires it as a burst -- it mirrors the root (scale.x), arms any child
## Hitbox, and lets this manage its own life (like a Shot).

## Time on screen before it frees itself.
@export var lifetime: float = 0.4
## Visuals pop from this scale multiple to their authored scale over the first bit (a
## quick swing snap). 1.0 = no grow.
@export var grow_from: float = 0.7


func _ready() -> void:
	var vis := _visuals()
	if not vis.is_empty():
		var tw := create_tween().set_parallel(true)
		for v in vis:
			var target: Vector2 = v.scale
			v.scale = target * grow_from
			tw.tween_property(v, "scale", target, lifetime * 0.45) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(v, "modulate:a", 0.0, lifetime).set_ease(Tween.EASE_IN)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)


## Every Sprite2D / AnimatedSprite2D under this effect -- the drawn visuals to animate.
func _visuals() -> Array:
	var out: Array = []
	out.append_array(find_children("*", "Sprite2D", true, false))
	out.append_array(find_children("*", "AnimatedSprite2D", true, false))
	return out
