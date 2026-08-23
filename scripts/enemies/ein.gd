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
## The AoE hitbox that erupts on arrival: half-size (centred on the orb via `explosion_offset`)
## + damage/knockback/stun. The blast's LOOK is a particle scene from the Emitters config
## (`ein -> delayed_aoe`), like every enemy emitter -- not an export here.
@export var explosion_extents := Vector2(38, 32)
## Nudge the blast HITBOX up onto the orb's body (the sprite is feet-anchored, so origin is
## below it). The particle look has its own offset in the Emitters config.
@export var explosion_offset := Vector2(0, -16)
@export var explosion_damage: float = 18.0
@export var explosion_knockback: float = 170.0
@export var explosion_stun: float = 0.2

# Trails + blast LOOK live in the Emitters config (ein -> patrol_trail / delayed_aoe_trail /
# explosion): which scene, where it emits, and whether it exists at all. Delete a row there and
# Ein stops wearing that trail -- no code change. (No patrol_trail row today = no patrol trail.)

var _home_y := 0.0 ## the y he bobs around on patrol
var _bob_t := 0.0
var _charge_target := Vector2.ZERO ## the LOCKED point he dives at (player's pos at detection)
var _trail: Node
var _contact: Area2D ## body-sized detector; touching the player erupts him (see _build_contact_detector)


func _ready() -> void:
	super._ready()
	collision_mask = 0 # float freely -- ignore terrain (we move by global_position, not slide)
	_home_y = global_position.y
	_build_contact_detector()
	_set_trail("patrol_trail")
	_set_state(State.PATROL)


## A body-sized detector that erupts him the instant the player TOUCHES him -- patrolling or
## charging, any contact sets him off. It's a bare Area2D (not a Hitbox): it deals no hit
## itself, just triggers the eruption whose AoE does the damage, so there's no double-hit and
## no spurious 0-damage flash. Dash i-frames turn the player's hurtbox off, so a dashing player
## isn't detected here (nor caught by the blast) -- dashing through him is safe, as intended.
func _build_contact_detector() -> void:
	_contact = Area2D.new()
	_contact.collision_layer = 0 # nothing needs to detect US; we only scan
	_contact.collision_mask = Combat.L_PLAYER_HURT # the player's hurtbox (off during a dash)
	_contact.add_child(Shapes.make_box(hurtbox_size, Vector2(0, -hurtbox_size.y / 2.0)))
	add_child(_contact)
	_contact.area_entered.connect(_on_contact)


func _on_contact(area: Area2D) -> void:
	if _state == State.DEAD:
		return # already erupting -- don't double-fire
	if area is Hurtbox:
		# Touched the player (who can't be dashing -- their hurtbox is off then) -> erupt here.
		# Deferred: we're inside the physics area-flush, where spawning the blast's hitbox
		# (activate() flips monitoring) is illegal; run it right after the flush instead.
		_arrive.call_deferred()


## Floating AI -- replaces Enemy's grounded loop entirely (no gravity, floor, or edge patrol).
func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return
	if _state == State.CHARGE:
		_charge(delta)
	else:
		_float_patrol(delta) # PATROL / IDLE: drift + bob, watch for the player


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
	_set_trail("delayed_aoe_trail")
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


## Erupt: AoE explosion + death burst. Fired by reaching the locked point OR by contact.
func _arrive() -> void:
	if _state == State.DEAD:
		return # guard: contact + arrival could both land the same frame
	_spawn_explosion()
	_die() # DEAD state + the death burst; our _die override frees the trail + detector first


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
	_set_trail("") # stop trailing before the death burst
	if _contact != null:
		_contact.set_deferred("monitoring", false) # stop detecting contact while the corpse fades
	super._die()


## Build the arrival blast: a hostile Strike with a box hitbox (from this orb's tuning) plus the
## particle-only explosion look, centred on the orb. Same pattern as Nasen's rage / the lob blast.
func _spawn_explosion() -> void:
	Sfx.play_at("ein.delayed_aoe", global_position) # the eruption is a code event, not a sprite frame
	# Player pattern: spawn the `delayed_aoe` Strike SCENE (its own Hitbox + visual) into the LEVEL so it
	# outlives our death, centred where we arrived; our explosion numbers injected. The blast's shape (+ its
	# `ranged` flag) + lifetime are authored in ein_delayed_aoe.tscn.
	var strike := _spawn_attack(_vfx_scene("delayed_aoe"),
		{"damage": explosion_damage, "knockback": explosion_knockback, "stun": explosion_stun}, true)
	if strike != null:
		Nodes.place_at(strike, global_position)


## Wear the trail for `effect` (the Emitters config key: "patrol_trail" / "delayed_aoe_trail"), or ""
## to clear it. The scene + emit offset both come from the config, so a deleted config row = no
## trail, no code change. The old trail is re-parented into the level and left to dissipate
## (Nodes.retire_particles) rather than freed outright -- otherwise, when Ein dies and frees, his
## trail (a child) and its still-airborne wisps would vanish with him instead of fading.
func _set_trail(effect: String) -> void:
	if _trail != null and is_instance_valid(_trail):
		Nodes.retire_particles(_trail as Node2D, get_parent())
	_trail = null
	if effect.is_empty():
		return
	_trail = _make_vfx(effect) # null when the config lists no scene for this effect
	if _trail != null:
		add_child(_trail)
