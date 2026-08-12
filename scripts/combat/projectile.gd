class_name Projectile
extends Node2D

## A flying attack -- for a player OR an enemy (team-agnostic). Merges what used to be
## the player `Shot` and the enemy projectile into one component: it travels (straight,
## or homing toward a target), carries a `Hitbox` that damages the opposing team, and
## frees itself on a hit or when it runs out of range/life.
##
## Team is `hostile`: false = a friendly (player) shot that hits enemies; true = a
## hostile (enemy) shot that hits the player. The trigger is NOT the projectile's
## concern -- a player input, a director frame, or enemy AI can all fire the same class.
##
## Spawned two ways:
##  - As a SCENE (player): the .tscn root is a Projectile with a `Hitbox` child + a
##    drawn AnimatedSprite2D or particle body. The ParticleDirector fires it as a burst
##    and reads facing from scale.x, with `homing` > 0 so it curves toward an enemy.
##    (a homing shot, a straight bolt.)
##  - In CODE (enemy): enemy.gd instantiates one, adds a `Hitbox` + a `visual` scene,
##    and sets `velocity`/params (`homing` 0 = straight line). (baghel wave, kebus bolt.)

## false = player shot (lives on L_PLAYER_HIT, scans enemy hurtboxes); true = enemy shot.
@export var hostile: bool = false
## When true the shot also hits its OWN team (allies), not just the opposing one -- e.g.
## an enemy shot that can catch other enemies. Off by default; never hits its own source.
@export var friendly_fire: bool = false

@export_group("Motion")
## Travel speed (px/s). Used when homing; a straight shot moves by `velocity` instead.
@export var speed: float = 420.0
## Steer rate toward the tracked target -- higher turns tighter, 0 = flies straight.
## Defaults to a gentle home (matches the old player Shot); enemies set 0 for a straight shot.
@export var homing: float = 6.0
## Distance flown before it fizzles (0 = unlimited; then use max_life).
@export var max_range: float = 0.0
## Seconds before it fizzles (0 = unlimited). Whichever of range/life hits first.
@export var max_life: float = 0.0
## Only locks onto a target this close (at spawn) in the aim direction.
@export var acquire_range: float = 420.0
## Let it arc upward. Default false: flies horizontally, only ever tracking level or
## down, and won't target something overhead.
@export var can_fly_up: bool = false
## How far above the shot a target's torso can sit and still be targetable (px).
## Beyond it it's "overhead" and ignored. Unused when can_fly_up.
@export var vertical_reach: float = 40.0
## A homing shot rotates its body to its heading (a drawn arrow/kiss). A straight shot
## authored blasting +x should MIRROR (scale.x) for a left shot, not rotate 180 (which
## would also flip it upside-down) -- so a straight shot never rotates.
@export var rotate_to_heading: bool = true

@export_group("Look / lifecycle")
## Optional one-shot effect spawned at the point of contact when it hits (a spark/puff).
@export var impact_effect: PackedScene
## Optional Sfx CUE KEY played POSITIONALLY at the point of contact on hit (an impact/clang). "" = silent.
## Same pattern as LobProjectile.explosion_sfx -- the sound of the shot LANDING, separate from the frame-
## synced firing sound. E.g. the frisbee sets "redere_frisbee.impact" (see SfxCharacters.CUES).
@export var impact_sfx: String = ""
## Optional drawn END animation (SpriteFrames, its "default" anim) played in place when
## it reaches max_range/max_life WITHOUT hitting -- so it dissolves rather than blinking
## out. Empty = fade any particle trail, else just vanish.
@export var end_frames: SpriteFrames
## Lay red embers along the floor as it rolls past (a ground surge's scorch trail); the
## colour is sampled from the visual's gradient so it matches whatever it's tinted.
@export var ground_trail: bool = false

## Who fired it (knockback credit); set by the spawner.
var source: Node = null
## A straight (homing == 0) shot moves by this. Set by the spawner (enemy). A homing
## shot ignores it and derives its own direction.
var velocity: Vector2 = Vector2.ZERO

var _dir := Vector2.RIGHT
var _traveled := 0.0
var _life := 0.0
var _target: Node2D
var _acquired := false
var _dying := false  # true while the end animation plays out; travel + hits are off
## The heading the shot launched with (its facing). A homing shot falls back to this and
## flies straight if its target dies mid-flight, instead of drifting off on a stale curve.
var _launch_dir := Vector2.RIGHT


func _ready() -> void:
	add_to_group("projectiles")  # so a respawn can clear in-flight shots
	if velocity.length() > 0.01:
		# The spawner (enemy) gave an explicit velocity: derive heading + speed from it.
		_dir = velocity.normalized()
		speed = velocity.length()
	else:
		# Director-fired (player): facing came in as scale.x. Read forward, then normalise
		# the sign -- _orient() re-applies a mirror below if this shot mirrors rather than
		# rotates.
		_dir = Vector2(-1.0 if scale.x < 0.0 else 1.0, 0.0)
	_launch_dir = _dir  # the straight-ahead heading a homing shot resumes if its target dies
	scale.x = absf(scale.x) if not is_zero_approx(scale.x) else 1.0
	_orient()

	var hb := _hitbox()
	if hb != null:
		hb.collision_layer = Combat.hit_layer(hostile)
		hb.collision_mask = Combat.hurt_mask(hostile, friendly_fire)
		hb.ranged = true  # flag every projectile hit as ranged (nasen etc. react by type)
		hb.source = source
		hb.struck.connect(_on_struck)
		hb.activate()  # a projectile leaves its box live for its whole flight

	if ground_trail:
		add_child(_make_ground_trail(_sample_visual_color()))
	# Target is acquired on the first physics tick, NOT here: the spawner places us at
	# the muzzle AFTER add_child, so at _ready global_position is still the spawn origin.


## Face the current heading: a drawn shot ROTATES its body to _dir; a shot authored
## blasting +x (a ground wave) MIRRORS via scale.x instead, so a left shot isn't turned
## upside-down by a 180 rotation.
func _orient() -> void:
	if rotate_to_heading:
		rotation = _dir.angle()
	else:
		scale.x = -absf(scale.x) if _dir.x < 0.0 else absf(scale.x)


func _physics_process(delta: float) -> void:
	if _dying:
		return  # dissolving / fading in place -- no more travel or hits
	if homing > 0.0:
		if not _acquired:
			_target = _nearest_target_ahead()
			_acquired = true
		if _target_alive():
			var aim := _aim_point(_target)
			var want := (aim if aim != null else _target).global_position - global_position
			if not can_fly_up and want.y < 0.0:
				want.y = 0.0  # track a level/lower target, never steer upward
			if want.length() > 0.01:
				_dir = _dir.slerp(want.normalized(), clampf(homing * delta, 0.0, 1.0))
		else:
			# No target ahead (none found, or the one we were tracking just died) -> stop
			# homing and fly straight along the launch heading. A trailing shot then keeps
			# going and can hit an enemy behind the dead one, or expires -- instead of
			# veering off on the stale mid-turn heading it had when the target vanished.
			homing = 0.0
			_dir = _launch_dir
	if not can_fly_up and _dir.y < 0.0:
		_dir = Vector2(_dir.x, 0.0)  # hard floor: never travel upward
		_dir = _dir.normalized() if _dir.length() > 0.01 else Vector2.RIGHT
	global_position += _dir * speed * delta
	_orient()
	_traveled += speed * delta

	_life += delta
	if (max_range > 0.0 and _traveled >= max_range) or (max_life > 0.0 and _life >= max_life):
		_expire()


## Configure this shot's hitbox from a resolved tuning dict (the Actions catalog via the
## player's resolve seam), so combat numbers live in code, not baked in the scene. Called by
## the spawner (director) after add_child. Absent fields keep the hitbox's authored values,
## so a shot whose move leaves `tuning` empty keeps its scene-authored per-shot damage
## (the cherry_shots case, where two shots differ and one tuning dict can't express both).
func apply_tuning(t: Dictionary, striker: Node = null) -> void:
	if striker != null:
		source = striker
	var hb := _hitbox()
	if hb == null or t.is_empty():
		return
	if t.has("damage"):
		hb.damage = t["damage"]
	if t.has("knockback"):
		hb.knockback = t["knockback"]
	if t.has("stun"):
		hb.stun = t["stun"]
	if t.has("color"):
		hb.status_color = t["color"]
		hb.status_time = t.get("color_time", t.get("stun", 0.0))
	if t.has("source"):
		hb.source = t["source"]
	if t.has("from_special"):
		hb.from_special = t["from_special"]  # a special-kill doesn't refill Ruh


## Nearest target AHEAD in the facing x-direction, within acquire_range (measured on
## the x-axis). Targets overhead (more than vertical_reach above) are skipped unless
## can_fly_up. Returns the target's aim node (torso) or null -> fly straight. The group
## is the OPPOSING team's: a friendly shot hunts "enemies", a hostile one hunts "player".
func _nearest_target_ahead() -> Node2D:
	var facing := 1.0 if _dir.x >= 0.0 else -1.0
	var group := "player" if hostile else "enemies"
	var best: Node2D = null
	var best_d := acquire_range
	for e in get_tree().get_nodes_in_group(group):
		var n := e as Node2D
		if n == null:
			continue
		var aim := _aim_point(n)
		if aim == null:
			continue
		var to := aim.global_position - global_position
		if to.x * facing <= 0.0:
			continue  # behind us in x (wrong side of the aim direction)
		if not can_fly_up and absf(to.y) > vertical_reach:
			continue  # off our level (above OR below) -- a horizontal shot stays on its row,
			# so it won't lock onto someone a platform down just because they're closer in x
		var d := absf(to.x)
		if d < best_d:
			best_d = d
			best = n  # the enemy itself (a group member), so _target_alive() can re-check it each frame
	return best


## Is the tracked target still a live target? It counts only while it's a valid node AND still
## a member of its group. An enemy leaves the "enemies" group the instant it dies -- BEFORE its
## death animation/fade frees the node (~2s later) -- so a tracking shot straightens the moment
## the target dies instead of curving into the fading corpse (which sits lower, so the shot dived).
func _target_alive() -> bool:
	if not is_instance_valid(_target):
		return false
	return _target.is_in_group("player" if hostile else "enemies")


## What the shot homes to for `target`: its hurtbox's centre (the torso) so shots land
## on the body, not the node origin at the feet. Falls back to the target itself.
func _aim_point(target: Node2D) -> Node2D:
	if target == null:
		return null
	for a in target.find_children("*", "Area2D", true, false):
		if a is Hurtbox:
			var shape := (a as Node).find_children("*", "CollisionShape2D", true, false)
			if not shape.is_empty():
				return shape[0]
	return target


## The projectile's Hitbox -- found anywhere in its scene (it may sit under an
## AnimatedSprite2D or a particle node, not just at the root).
func _hitbox() -> Hitbox:
	for a in find_children("*", "Area2D", true, false):
		if a is Hitbox:
			return a as Hitbox
	return null


## Hit something: drop the impact effect (if any) at the point of contact, then die.
func _on_struck(_victim: Hurtbox) -> void:
	if impact_effect != null:
		_spawn_impact()
	if impact_sfx != "":
		Sfx.play_at(impact_sfx, global_position) # positional -- the clang lands at the point of contact
	queue_free()


## Reached max range/life without hitting anything. With `end_frames`, dissolve in place
## (freeze, stop the box + any particle trail, play the drawn end anim on our own sprite,
## free when it finishes). Else fade any particle trail out over its lifetime, then free
## -- so a spent shot dissipates rather than popping. No particles + no end_frames = vanish.
func _expire() -> void:
	if _dying:
		return
	_dying = true
	var hb := _hitbox()
	if hb != null:
		hb.set_deferred("monitoring", false)
		hb.set_deferred("collision_layer", 0)
	velocity = Vector2.ZERO

	if end_frames != null:
		var spr := _find_sprite()
		if spr == null:  # a particle-only shot -- make a sprite to play the dissolve on
			spr = AnimatedSprite2D.new()
			add_child(spr)
		for em in _emitters():
			em.emitting = false
		spr.sprite_frames = end_frames
		spr.play(&"default")
		spr.animation_finished.connect(queue_free)
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			if is_instance_valid(self):
				queue_free())
		return

	var emitters := _emitters()
	if emitters.is_empty():
		queue_free()
		return
	var linger := 0.15
	for em in emitters:
		em.emitting = false
		linger = maxf(linger, em.lifetime * (1.0 + em.lifetime_randomness))
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, linger)
	tw.tween_callback(queue_free)


## The projectile's AnimatedSprite2D body (its drawn look), or null for a particle shot.
func _find_sprite() -> AnimatedSprite2D:
	for a in find_children("*", "AnimatedSprite2D", true, false):
		return a as AnimatedSprite2D
	return null


func _emitters() -> Array:
	var out: Array = []
	out.append_array(find_children("*", "CPUParticles2D", true, false))
	out.append_array(find_children("*", "GPUParticles2D", true, false))
	return out


## Spawn the impact effect in the world at the hit point and let it self-finish.
func _spawn_impact() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var fx := impact_effect.instantiate()
	parent.add_child(fx)
	if fx is Node2D:
		(fx as Node2D).global_position = global_position
	var emitters: Array = []
	if fx is CPUParticles2D or fx is GPUParticles2D:
		emitters.append(fx)
	emitters.append_array(fx.find_children("*", "CPUParticles2D", true, false))
	emitters.append_array(fx.find_children("*", "GPUParticles2D", true, false))
	for em in emitters:
		em.one_shot = true
		em.emitting = true
	if emitters.is_empty():
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			if is_instance_valid(fx):
				fx.queue_free())
	else:
		emitters[0].finished.connect(func() -> void:
			if is_instance_valid(fx):
				fx.queue_free())


## Pull the visual's headline colour out of its gradient so the ground trail matches
## whatever it's tinted to. Falls back to white.
func _sample_visual_color() -> Color:
	for em in _emitters():
		if em is CPUParticles2D and em.color_ramp != null:
			return em.color_ramp.sample(0.0)
	return Color(1, 1, 1)


## Red embers laid along the floor. local_coords = false pins them in world space, so as
## the shot rolls forward they're left behind as a scorched trail that lingers and fades.
func _make_ground_trail(tint: Color) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = load("res://vfx/shared/textures/pixel_ember.png")
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.local_coords = false
	p.amount = 40
	p.lifetime = 0.75
	p.lifetime_randomness = 0.3
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(4, 1)
	p.direction = Vector2(0, -1)
	p.spread = 40.0
	p.gravity = Vector2(0, 90)
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 26.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.1
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	ramp.colors = PackedColorArray([
		Color(tint.r, tint.g, tint.b, 1.0),
		Color(tint.r * 0.7, tint.g * 0.6, tint.b * 0.6, 0.6),
		Color(tint.r * 0.5, tint.g * 0.4, tint.b * 0.4, 0.0),
	])
	p.color_ramp = ramp
	return p
