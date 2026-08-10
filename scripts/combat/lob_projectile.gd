class_name LobProjectile
extends Node2D

## A LOBBED / mortar projectile: it is THROWN in a ballistic arc so it rises, falls, and
## lands on a chosen spot (next to the player), sits there as a live-but-telegraphed bomb
## for `dwell_time`, then ERUPTS into an AoE explosion. Unlike Projectile (a linear tracer
## that hits on contact mid-flight), a lob deals NO damage in the air or on landing -- only
## the explosion hurts, so it is DODGEABLE: clear the blast before the timer runs out.
##
## Phases: ARC (ballistic, no hitbox) -> DWELL (grounded, blinks faster as it counts down) ->
## EXPLODE (spawns a hostile Strike -- the same AoE component nasen's rage and the
## ground-breaker use -- then frees itself).
##
## Reusable "throw a bomb at your feet" pattern: an enemy fires one via ranged_mode = "lob"
## (enemy.gd::_fire_lob), which sets the team + tuning + landing spot. The thrown-object look
## is any Node2D child (a particle scene passed as `ranged_particle`); the blast look is the
## `explosion_effect` scene, instanced inside the Strike.

@export var hostile := false
## When true the blast also catches the thrower's own team (never its own source).
@export var friendly_fire := false

@export_group("Arc")
## Seconds used to SOLVE the launch velocity toward the aim point -- it shapes the arc's
## height/angle (aims it AT the player at any distance), NOT when it lands. The bomb then
## flies BALLISTICALLY past that point; it lands only when it hits a real surface (below), so
## a player who steps out from under it never leaves it hanging in the air.
@export var arc_time := 0.9
## Downward accel during the arc (px/s^2). Higher = a snappier, tighter arc.
@export var gravity := 900.0
## Spin of the tumbling object in flight (deg/s), flavour only. 0 = no spin.
@export var spin := 480.0
## Seconds airborne before it gives up finding a surface and detonates MID-AIR (no dwell) --
## the safety net for a bomb thrown over a ledge with nothing below, so it never falls forever.
@export var max_life := 3.0

@export_group("Dwell + explosion")
## Seconds the landed bomb sits (blinking) before it blows -- the player's dodge window.
@export var dwell_time := 1.0
## Half-size of the explosion hitbox: a wide, short ground blast centred on the bomb.
@export var explosion_extents := Vector2(48, 26)
@export var explosion_damage := 16.0
@export var explosion_knockback := 160.0
@export var explosion_stun := 0.25
## Particle-only scene for the blast look, instanced inside the explosion Strike. null = the
## Strike's own default flash.
@export var explosion_effect: PackedScene
## Offset of the blast look within the explosion (from the Emitters config). Not facing-mirrored:
## the bomb has left its thrower, so its facing is irrelevant here.
@export var explosion_effect_pos := Vector2.ZERO
## Sound played (positionally, at the detonation point) when the bomb POPS -- the delayed blast, so
## it can't ride an attack-animation frame. A res:// path; "" = none. The thrower sets it from its
## sound folder (`<id>/attack/projectile_pop.wav`).
@export var explosion_sfx: String = ""

## Where to AIM the arc (world space). Set by the spawner (enemy: next to the player). It only
## shapes the toss -- the bomb lands on a real surface, not here. Vector2.INF = a short toss
## down-ahead as a fallback.
var target: Vector2 = Vector2.INF
## Who threw it (knockback credit + friendly-fire exemption); set by the spawner.
var source: Node = null

enum Phase { ARC, DWELL, SPENT }
var _phase := Phase.ARC
var _vel := Vector2.ZERO
var _t := 0.0
var _life := 0.0
var _launched := false
var _visual: Node2D


func _ready() -> void:
	add_to_group("projectiles")  # so a respawn can clear bombs in mid-air
	_visual = _find_visual()


func _physics_process(delta: float) -> void:
	# Solve the launch velocity on the FIRST tick, not in _ready: the spawner snaps us to the
	# muzzle (Nodes.place_at) AFTER add_child, so global_position is only correct now.
	if not _launched:
		_launch()
		_launched = true

	match _phase:
		Phase.ARC:
			_life += delta
			var from := global_position
			_vel.y += gravity * delta
			var to := from + _vel * delta
			if _visual != null and spin != 0.0:
				_visual.rotation += deg_to_rad(spin) * delta
			# Land only when DESCENDING onto a surface (respects one-way platforms: while
			# rising we pass up through them). A ray over this frame's step so a fast bomb
			# can't tunnel through a thin ledge.
			var surface := _surface_between(from, to) if _vel.y > 0.0 else Vector2.INF
			if surface != Vector2.INF:
				global_position = surface  # rest on the surface it actually hit
				_land()
			else:
				global_position = to
				if _life >= max_life:
					_explode()  # never found ground (thrown over a ledge) -> blow mid-air
		Phase.DWELL:
			_t += delta
			if _t >= dwell_time:
				_explode()
		Phase.SPENT:
			pass


## Solve the launch velocity so the arc is AIMED at `target` (reaching it at ~arc_time under
## gravity): vx = dx/T, vy = dy/T - 0.5*g*T (negative -> up). This only shapes the toss; the
## bomb then flies ballistically until it hits a surface or `max_life` elapses.
func _launch() -> void:
	if target == Vector2.INF:
		target = global_position + Vector2(60.0, 40.0)
	var to := target - global_position
	_vel = Vector2(to.x / arc_time, to.y / arc_time - 0.5 * gravity * arc_time)


## First L_WORLD surface crossed by the segment from -> to, or Vector2.INF. A physics ray
## query (ignores one-way direction, so the caller gates on descending). Points nudged apart
## when coincident so a zero-length step still queries.
func _surface_between(from: Vector2, to: Vector2) -> Vector2:
	if to == from:
		to = from + Vector2(0.0, 0.5)
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(from, to, Combat.L_WORLD)
	q.hit_from_inside = true  # catch a ledge we start the step already inside
	var r := space.intersect_ray(q)
	return r.position if not r.is_empty() else Vector2.INF


func _land() -> void:
	_phase = Phase.DWELL
	_t = 0.0
	if _visual != null:
		_visual.rotation = 0.0
	# Telegraph: pulse alpha so the player reads "move!" before it blows. The loop keeps
	# running for the whole dwell; _explode() frees us, ending it.
	var tw := create_tween().set_loops()
	tw.tween_property(self, "modulate:a", 0.35, 0.11)
	tw.tween_property(self, "modulate:a", 1.0, 0.11)


## Erupt: a hostile Strike with a wide ground hitbox (built from this bomb's tuning) plus the
## `explosion_effect` look. Same activation pattern as the enemy melee strike / nasen's rage.
func _explode() -> void:
	_phase = Phase.SPENT
	if explosion_sfx != "":
		Sfx.play_at(explosion_sfx, global_position)  # the delayed POP, at the detonation point
	var parent := get_parent()
	if parent == null:
		queue_free()
		return
	# The thrower may have DIED while the bomb flew/dwelled (a lob outlives its owner), leaving
	# `source` a freed reference -- assigning that to a Node property errors. Drop it to null
	# (knockback credit is just lost); the blast still fires.
	var src: Node = source if is_instance_valid(source) else null
	var strike := Strike.new()
	strike.hostile = hostile
	strike.friendly_fire = friendly_fire
	strike.lifetime = 0.4
	strike.source = src
	var hb := Hitbox.new()
	hb.damage = explosion_damage
	hb.knockback = explosion_knockback
	hb.stun = explosion_stun
	hb.ranged = true  # a thrown-bomb blast reads as ranged (nasen etc. react by hit type)
	hb.source = src
	hb.add_child(Shapes.make_box(explosion_extents * 2.0, Vector2(0, -explosion_extents.y)))
	strike.add_child(hb)
	if explosion_effect != null:
		var fx := explosion_effect.instantiate()
		if fx is Node2D:
			(fx as Node2D).position = explosion_effect_pos
		strike.add_child(fx)
	parent.add_child(strike)  # _ready: team layers + self-free timer
	Nodes.place_at(strike, global_position)
	hb.activate()
	queue_free()


## The thrown-object body (the first Node2D child, e.g. a particle scene). null = no visual.
func _find_visual() -> Node2D:
	for c in get_children():
		if c is Node2D:
			return c as Node2D
	return null
