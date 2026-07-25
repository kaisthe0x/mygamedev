class_name LaserBeam
extends Node2D

## A short-lived laser beam you fire and forget (it frees itself). A RayCast2D
## finds where the beam stops at a WALL -> its length (it pierces through enemies,
## not stops at them); a Hitbox spanning the whole length damages every enemy in
## it; and a width tween flashes it open then shut.
##
## EVERY Line2D child is drawn as the beam and stretched to the hit length -- the
## base has a wide HALO under a thin CORE, but you can add more (e.g. a SwirlLine
## with a shader), and they all length-match and width-flash automatically.
##
## This is the SCENE's behaviour -- the LOOK lives on the child nodes. Open
## scenes/effects/laser_beam.tscn and tweak the lines' colour/width, and drop your
## drawn beam sprite on the Core's `texture` (it's set to stretch). For a character
## with its own beam, make an Inherited Scene of the base and swap those; the
## firing ability just sets the gameplay numbers below and calls fire().

## Gameplay -- the firing character sets these before fire().
@export var damage := 20.0
@export var knockback := 0.0
@export var stun := 0.0
## Max reach before the beam fizzles; it stops sooner on a wall/enemy.
@export var beam_range := 260.0
## Timing: the beam extends ("shoots") from the muzzle to full length over
## shoot_time, holds bright, then its width fades to nothing.
@export var shoot_time := 0.06
@export var hold_time := 0.06
@export var fade_time := 0.18

## Who fired it, for knockback direction. Set by the character (not exported).
var source: Node = null

@onready var _ray: RayCast2D = $Ray
@onready var _core: Line2D = $Core
@onready var _hitbox: Hitbox = $Hitbox
@onready var _hit_shape: CollisionShape2D = $Hitbox/Shape

## EVERY Line2D child (Core, Halo, and any you add -- SwirlLine, etc.), with its
## authored width remembered. fire() stretches them all to the beam length and the
## tween scales their widths, so a new line just works.
var _lines: Array[Line2D] = []
var _widths: Array[float] = []
var _core_w := 0.0  # the Core's width, sizing the hitbox thickness


func _ready() -> void:
	_collect_lines()
	_ray.enabled = false


## Gather every Line2D child once, remembering its authored ("full") width and
## closing it to 0 (the tween opens it). Called from _ready, and again from fire()
## in case the beam was added and fired in the same frame before _ready ran.
func _collect_lines() -> void:
	if not _lines.is_empty():
		return
	for child in get_children():
		var line := child as Line2D
		if line == null:
			continue
		if line == _core:
			_core_w = line.width
		_lines.append(line)
		_widths.append(line.width)
		line.width = 0.0


## Fire the beam along `dir` (a facing vector). It orients itself, snaps to the
## first wall/enemy within `beam_range`, damages everything along that length, and
## flashes. Set damage/knockback/stun/beam_range/source first.
func fire(dir: Vector2) -> void:
	_collect_lines()  # no-op if _ready already ran
	rotation = dir.angle()  # everything below is authored along local +x
	_ray.target_position = Vector2(beam_range, 0)
	_ray.force_raycast_update()
	var length := beam_range
	if _ray.is_colliding():
		length = to_local(_ray.get_collision_point()).x

	# Hitbox spans the full length, live while the beam is out.
	var thickness := maxf(_core_w, 6.0)
	(_hit_shape.shape as RectangleShape2D).size = Vector2(length, thickness)
	_hit_shape.position = Vector2(length / 2.0, 0.0)
	_hitbox.damage = damage
	_hitbox.knockback = knockback
	_hitbox.stun = stun
	_hitbox.source = source if source != null else self
	_hitbox.activate(shoot_time + hold_time)

	# Start collapsed at the muzzle, full width; EXTEND the length out so the beam
	# and every line/swirl shoot together; hold, then fade the width to nothing.
	_extend(0.0, length)
	_set_width(1.0)
	var tw := create_tween()
	tw.tween_method(_extend.bind(length), 0.0, 1.0, shoot_time)
	tw.tween_interval(hold_time)
	tw.tween_method(_set_width, 1.0, 0.0, fade_time)
	tw.tween_callback(queue_free)


## Grow every line from the muzzle out to `full_length * f` (f: 0 -> 1).
func _extend(f: float, full_length: float) -> void:
	var pts := PackedVector2Array([Vector2.ZERO, Vector2(full_length * f, 0.0)])
	for line in _lines:
		line.points = pts


func _set_width(f: float) -> void:
	for i in _lines.size():
		_lines[i].width = _widths[i] * f
