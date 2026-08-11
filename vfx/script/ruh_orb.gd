class_name RuhOrb
extends Node2D

## A glowing "soul" that pops off a dying enemy and floats to the player -- the visual receipt for
## a Ruh pickup. It flies a CURVED (parabolic) path straight toward the player: a quadratic Bezier
## from the death spot to the player's live position, bowed to the side by `arc_height`, so it
## swoops in on an arc rather than tracking a straight line. It ALWAYS reaches the player (arrival
## at the end of `flight_time` -- that's arrival time, not a give-up cap); it only bails if the
## player is gone. On contact it shrinks into the chest and fires the absorb reaction
## (Player.on_ruh_absorbed). Pure feedback: the Ruh is already banked when this spawns.

enum Phase {FLY, ABSORB}

var _target: Node2D = null
var _completed_charge := false
var _p0 := Vector2.ZERO # launch point -- the fixed anchor the arc is drawn from
var _t := 0.0 # 0..1 progress along the arc
var _phase := Phase.FLY

## Seconds from launch to the player. The soul always arrives at the end -- arrival time, not a cap.
@export var flight_time: float = 1.1
## How far the path bows off the straight line (px) -- the curviness. 0 = straight; bigger = curvier;
## negative flips the bow to the other side.
@export var arc_height: float = 90.0
## Aim at the player's chest, not the feet-origin, so it reads as landing on the character.
@export var target_offset := Vector2(0, -18)
## Seconds of the shrink-into-body absorb on arrival (drawn in, not vanished in a frame).
@export var absorb_time: float = 0.12


## Send this orb curving toward `target` (the player). `completed_charge` marks the soul that topped
## off a full Ruh charge (a bigger arrival flash). Call once, right after adding it to the world.
func launch(target: Node2D, completed_charge := false) -> void:
	_target = target
	_completed_charge = completed_charge
	_p0 = global_position
	_t = 0.0
	_phase = Phase.FLY


func _process(delta: float) -> void:
	if _phase == Phase.ABSORB:
		return # the absorb tween owns motion + its own free
	# A soul with nowhere to go (the player's gone) can't land -- drop it.
	if _target == null or not is_instance_valid(_target):
		queue_free()
		return

	var dest := _target.global_position + target_offset
	_t += delta / maxf(flight_time, 0.01)
	if _t >= 1.0:
		global_position = dest
		_absorb(dest) # arrived -- shrink into the body + flash the player
		return

	# Quadratic Bezier p0 -> control -> dest, the control bowed perpendicular to the straight line
	# (upward-biased) by arc_height. `dest` is re-read each frame so the arc tracks the moving player.
	var mid := _p0.lerp(dest, 0.5)
	var line := dest - _p0
	var perp := Vector2(-line.y, line.x).normalized() # 90deg; zero-safe if line ~ 0
	if perp.y > 0.0:
		perp = - perp # bow upward -- the soul arcs over, then curves down into him
	var control := mid + perp * arc_height
	global_position = _bezier(_p0, control, dest, _t)


func _bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return u * u * a + 2.0 * u * t * b + t * t * c


## The pickup beat: flash the player (its HUD Ruh meter already ticked up at the kill), then shrink
## the orb into the chest over `absorb_time` and free -- so it's drawn IN, not vanished.
func _absorb(dest: Vector2) -> void:
	_phase = Phase.ABSORB
	if _target != null and is_instance_valid(_target) and _target.has_method("on_ruh_absorbed"):
		_target.on_ruh_absorbed(_completed_charge)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "global_position", dest, absorb_time)
	tw.tween_property(self, "scale", Vector2.ZERO, absorb_time).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)
