class_name Shot
extends Node2D

## A homing player projectile for a "shooting" attack (e.g. Lenny's finger guns).
## The ParticleDirector spawns it as a burst on the attack's fire frames; from there
## it flies in the character's facing (which tracks the mouse) and curves toward the
## nearest enemy ahead of it, carrying its Hitbox + single particle as it travels.
## Frees on a hit or at max range. Because it manages its own life, the director does
## NOT free it when its particle finishes (see ParticleDirector._fire_burst).

## Travel speed (px/s).
@export var speed: float = 420.0
## Steer rate toward the tracked enemy -- higher turns tighter, 0 flies straight.
@export var homing: float = 6.0
## How far it flies before fizzling out.
@export var max_range: float = 320.0
## Only locks onto an enemy this close (at spawn) in the aim direction.
@export var acquire_range: float = 420.0

var _dir := Vector2.RIGHT
var _traveled := 0.0
var _target: Node2D


func _ready() -> void:
	# The director mirrors the composite by scale.x for facing; read forward from it,
	# then normalise the transform since we move in world space from here.
	_dir = Vector2(-1.0 if scale.x < 0.0 else 1.0, 0.0)
	scale.x = 1.0
	rotation = _dir.angle()
	_target = _nearest_enemy_ahead()
	var hb := get_node_or_null("Hitbox") as Hitbox
	if hb != null:
		hb.struck.connect(func(_v: Hurtbox) -> void: queue_free())


func _physics_process(delta: float) -> void:
	if is_instance_valid(_target):
		var want := (_target.global_position - global_position).normalized()
		_dir = _dir.slerp(want, clampf(homing * delta, 0.0, 1.0))
	global_position += _dir * speed * delta
	rotation = _dir.angle()
	_traveled += speed * delta
	if _traveled >= max_range:
		queue_free()


## The nearest enemy roughly ahead of the shot (positive dot with the aim) within
## acquire_range, or null -- then it just flies straight.
func _nearest_enemy_ahead() -> Node2D:
	var best: Node2D
	var best_d := acquire_range
	for e in get_tree().get_nodes_in_group("enemies"):
		var n := e as Node2D
		if n == null:
			continue
		var to := n.global_position - global_position
		if to.dot(_dir) <= 0.0:
			continue  # behind the shot
		var d := to.length()
		if d < best_d:
			best_d = d
			best = n
	return best
