class_name Ein
extends Enemy

## Ein: a floating orb with a dagger in its eye -- a KAMIKAZE. He drifts and bobs on patrol
## (trailing wisps). The moment the player enters `detect_range` he LOCKS the player's current
## position as a fixed target, then flies straight at it (dagger-first, the attack anim looping,
## a hard charge trail) -- committing fully: he does NOT re-track, so dodging makes him miss.
## On arrival at that locked point (whether he stabbed the player or not) he ERUPTS: a one-shot
## AoE explosion + his death burst, and he's gone. Killed before he arrives -- even before he
## ever detects you -- the same death burst plays; he just doesn't explode.
##
## Floats freely: overrides Enemy's grounded `_physics_process` (no gravity / floor / edge
## patrol), but reuses everything else (sprite / hurtbox / health-bar / hit-flash / death).

@export_group("Ein")
## Radius (px) at which the player disturbs him and he commits to a charge.
@export var detect_range: float = 220.0
## Flight speed of the charge (px/s). His gentle drift on patrol is the base `move_speed`.
@export var charge_speed: float = 230.0
## How close to the locked target counts as "arrived" -> erupt.
@export var arrival_radius: float = 12.0
## Gentle vertical bob while patrolling: amplitude (px) and speed (rad/s).
@export var bob_amplitude: float = 6.0
@export var bob_speed: float = 3.0

@export_subgroup("Explosion")
## The AoE that erupts on arrival: half-size (centred on the orb via `explosion_offset`),
## damage/knockback/stun, and a particle-only scene for the blast look.
@export var explosion_extents := Vector2(38, 32)
## Nudge the blast up onto the orb's body (the sprite is feet-anchored, so origin is below it).
@export var explosion_offset := Vector2(0, -16)
@export var explosion_damage: float = 18.0
@export var explosion_knockback: float = 170.0
@export var explosion_stun: float = 0.2
@export_file("*.tscn") var explosion_effect := "res://vfx/enemy/ein/attack/ein_explosion.tscn"

@export_subgroup("Trails")
## Particle trail worn while patrolling (gentle) vs while charging (aggressive). Swapped by
## state; freed on death.
@export_file("*.tscn") var patrol_trail := "res://vfx/enemy/ein/other/ein_patrol_trail.tscn"
@export_file("*.tscn") var attack_trail := "res://vfx/enemy/ein/attack/ein_attack_trail.tscn"

var _home_y := 0.0  ## the y he bobs around on patrol
var _bob_t := 0.0
var _charge_target := Vector2.ZERO  ## the LOCKED point he dives at (player's pos at detection)
var _trail: Node


func _ready() -> void:
	super._ready()
	collision_mask = 0  # float freely -- ignore terrain (we move by global_position, not slide)
	_home_y = global_position.y
	_set_trail(patrol_trail)
	_set_state(State.PATROL)


## Floating AI -- replaces Enemy's grounded loop entirely (no gravity, floor, or edge patrol).
func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return
	if _state == State.CHARGE:
		_charge(delta)
	else:
		_float_patrol(delta)  # PATROL / IDLE: drift + bob, watch for the player


## Drift + bob in place until the player enters detect_range, then lock his position and charge.
func _float_patrol(delta: float) -> void:
	var player := _player()
	if player != null and global_position.distance_to(player.global_position) <= detect_range:
		_begin_charge(player.global_position)
		return
	var dir := signf(_patrol_target - global_position.x)
	global_position.x += dir * move_speed * delta
	if absf(_patrol_target - global_position.x) <= 2.0:
		_patrol_target = _point_a if is_equal_approx(_patrol_target, _point_b) else _point_b
	_bob_t += delta
	global_position.y = _home_y + sin(_bob_t * bob_speed) * bob_amplitude
	if dir != 0.0:
		_face(int(dir))


## Lock the target and commit: attack anim (looping stab), aggressive trail, CHARGE state.
func _begin_charge(target: Vector2) -> void:
	_charge_target = target
	_set_trail(attack_trail)
	_set_state(State.CHARGE)
	_play(&"attack")
	_face(int(signf(target.x - global_position.x)))


## Fly straight at the locked point; erupt on arrival. No re-tracking -- he commits.
func _charge(delta: float) -> void:
	var to := _charge_target - global_position
	if to.length() <= arrival_radius:
		_arrive()
		return
	var step := to.normalized() * charge_speed
	global_position += step * delta
	if not is_zero_approx(step.x):
		_face(int(signf(step.x)))


## Reached the locked point: AoE explosion + death burst.
func _arrive() -> void:
	_spawn_explosion()
	_die()  # DEAD state + the death burst; our _die override frees the trail first


## A hit chips + flashes him; lethal -> death burst. No stun/knockback: once he's diving he
## commits, and even on patrol he's a relentless orb, never staggered.
func _on_hurt(hit: Hit) -> void:
	if _state == State.DEAD:
		return
	health = maxf(health - hit.amount, 0.0)
	_bar.set_ratio(health / max_health)
	flash(_sprite)
	if health <= 0.0:
		_die()


func _die() -> void:
	_set_trail("")  # stop trailing before the death burst
	super._die()


## Build the arrival blast: a hostile Strike with a box hitbox (from this orb's tuning) plus the
## particle-only explosion look, centred on the orb. Same pattern as Nasen's rage / the lob blast.
func _spawn_explosion() -> void:
	var strike := Strike.new()
	strike.hostile = true
	strike.friendly_fire = friendly_fire
	strike.lifetime = 0.4
	strike.source = self
	var hb := Hitbox.new()
	hb.damage = explosion_damage
	hb.knockback = explosion_knockback
	hb.stun = explosion_stun
	hb.ranged = true  # an AoE blast, not a melee stab (nasen-style reactions read this)
	hb.source = self
	hb.add_child(Shapes.make_box(explosion_extents * 2.0, explosion_offset))
	strike.add_child(hb)
	if not explosion_effect.is_empty():
		var scn := load(explosion_effect) as PackedScene
		if scn != null:
			var fx := scn.instantiate()
			if fx is Node2D:
				(fx as Node2D).position = explosion_offset
			strike.add_child(fx)
	get_parent().add_child(strike)  # live in the level, centred where the orb arrived
	Nodes.place_at(strike, global_position)
	hb.activate()


## Swap the worn trail node: free the current one, instance `scene_path` (empty = none).
func _set_trail(scene_path: String) -> void:
	if _trail != null and is_instance_valid(_trail):
		_trail.queue_free()
	_trail = null
	if scene_path.is_empty():
		return
	var scn := load(scene_path) as PackedScene
	if scn != null:
		_trail = scn.instantiate()
		add_child(_trail)
