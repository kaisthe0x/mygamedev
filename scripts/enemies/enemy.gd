class_name Enemy
extends Combatant

## Reusable ground enemy. Shares the character sprite pipeline (idle / stroll /
## attack / attack_projectile) but each enemy only needs the animations it has: the
## strike (`attack`) and projectile (`attack_projectile`) are enabled automatically from
## whichever attack animations exist in its SpriteFrames, so an enemy with just one attack
## (or no stroll, like a stationary sleeper) works with no changes.
##
## Behaviour: patrol between its spawn point and spawn+patrol_distance, pausing
## to idle at each end; if the player comes within ranged_range it attacks
## (melee when very close, ranged otherwise). It carries its own hurtbox, melee
## hitbox, floating health bar and hit-flash. Bosses get their own scene/script
## instead of shoehorning extra move-sets in here.
##
## Everything visual/physical is built in code, so an enemy is just this script
## configured via exports (or subclassed) -- no scene to keep in sync.

const FRAMES_PATH := "res://resources/enemies/%s.tres"

@export var enemy_id: String = "kebus"
@export var display_name: String = "Kebus"

@export_group("Stats")
@export var max_health: float = 60.0
@export var gravity: float = 900.0
## Collider full-sizes, so differently-proportioned enemies fit their sprite. The
## body is what stands on the floor; the hurtbox is what attacks land on (also
## used for the contact-damage box). Each sits centred, resting on the feet.
@export var body_size := Vector2(18, 30)
@export var hurtbox_size := Vector2(20, 34)

@export_group("Patrol")
@export var move_speed: float = 40.0
## How far it strolls from its spawn point before turning back.
@export var patrol_distance: float = 90.0
@export var idle_time_min: float = 2.0
@export var idle_time_max: float = 3.0
## Won't step past an edge: how far ahead of the feet ground is probed for.
@export var edge_check_x: float = 14.0
## Optional resting-idle flourish: while idling, loop emitted frames
## [idle_loop_from..idle_loop_to] (e.g. a back-scratch) for idle_loop_time
## seconds, then play one full idle cycle, and repeat. Disabled when to <= from.
@export var idle_loop_from := 0
@export var idle_loop_to := 0
@export var idle_loop_time := 2.5

@export_group("Combat ranges")
## Player within this horizontal distance -> melee. Small = must be adjacent.
@export var melee_range: float = 30.0
## Player within this -> ranged attack (when melee doesn't apply).
@export var ranged_range: float = 300.0
## Max vertical gap (px, feet-to-feet) for an attack to trigger. Both boxes are
## horizontal, so a player on a different platform can never be hit -- without this the
## enemy still swings/fires at someone directly below and just looks silly. Keep it under
## the platform spacing so "roughly the same height" means "same ledge / jumping past".
@export var attack_align_y: float = 40.0
@export var attack_cooldown: float = 1.1
## When true the melee `attack` LOOPS while the player stays in melee reach (a channel /
## flurry) instead of one swing per cooldown. It re-plays from the anim's `loop_from`
## (gen_spriteframes), so a wind-up lead-in plays once and only the strike cycle repeats.
@export var attack_loops := false
@export var melee_damage: float = 12.0
@export var ranged_damage: float = 8.0
## On-hit effects this enemy's attacks carry (0 = none).
@export var melee_knockback: float = 90.0
@export var melee_stun: float = 0.0
@export var ranged_knockback: float = 0.0
@export var ranged_stun: float = 0.0
## Melee hitbox placement in front of the body, and its half-size.
@export var melee_hitbox_x: float = 20.0
@export var melee_hitbox_extents := Vector2(16, 16)
## Where a projectile leaves the enemy (forward, up), before facing mirror.
@export var muzzle_offset := Vector2(20, -46)
@export var projectile_speed: float = 260.0
## "aimed": projectile flies toward the player (Kebus' staff bolt).
## "forward": it surges straight ahead along the ground for `ranged_travel` px
## then fizzles, hitting whatever it passes (Baghel's ground energy).
@export_enum("aimed", "forward") var ranged_mode := "aimed"
@export var ranged_travel: float = 100.0
@export var ranged_color := Color(0.55, 1.0, 0.45)  # tints the built-in orb
## Optional particle scene for the projectile's look (e.g. Baghel's ground wave).
## Empty = the built-in orb. Edit these in the editor like any particle scene.
@export_file("*.tscn") var ranged_particle := ""
## Projectile collider half-size + offset from its spawn point.
@export var ranged_hitbox_extents := Vector2(5, 5)
@export var ranged_hitbox_offset := Vector2.ZERO

@export_group("Behaviour")
## When true, chases the player (up to aggro_range) instead of only attacking
## whoever wanders into range. Off by default -- most mobs just guard a spot.
@export var aggro := false
@export var aggro_range: float = 480.0
## Get alerted when hurt: taking a hit makes this enemy detect + pursue the attacker for
## `alert_duration` seconds even if it was outside its normal range (re-hits refresh it).
## So a shot from off-screen won't go unanswered. 0 = never alerts.
@export var alert_duration: float = 5.0
## When true, THIS enemy's attacks can hit OTHER enemies too, not just the player (it
## still never hits itself). Per-instance -- flag a single mob for chaos, not the whole
## roster. The seam for enemies fighting each other.
@export var friendly_fire := false
## Damage dealt by simply touching the player (0 = off), applied on an interval.
@export var contact_damage: float = 0.0
@export var contact_knockback: float = 120.0
@export var contact_interval: float = 0.6

@export_group("Attack feel")
## Freeze the attack on its impact frame for this long, then let it finish -- a
## hit-stop that gives the blow weight. 0 = off.
@export var attack_hitstop: float = 0.18
## Peak jitter (px) of the shake during the hit-stop; decays to 0 over it.
@export var attack_shake: float = 2.5

enum State { IDLE, STROLL, MELEE, RANGE, STUN, DEAD, RAGE }  # RAGE: nasen's sleeper AoE

var health: float
var _state: State = State.IDLE
var _facing: int = -1  # enemies commonly face left toward a right-approaching player
var _has_melee := false
var _has_ranged := false
var _has_death := false
var _has_stroll := false
var _attack_cd := 0.0
var _attack_fired := false
var _point_a := 0.0
var _point_b := 0.0
var _patrol_target := 0.0
var _idle_timer := 0.0
var _stun_left := 0.0
var _contact_cd := 0.0
var _contact_hitbox: Hitbox
var _scratch_timer := 0.0
var _scratch_full_cycle := false
## Player is in reach (attacking distance) -> we're in combat, so the idle
## between attacks holds a tense ready-stance instead of the patrol flourish.
var _engaged := false
## Seconds of "alerted" left after being hurt: while > 0 the enemy pursues the player
## regardless of its normal detection range (see _act / _on_hurt).
var _alert_left := 0.0
var _hitstop_left := 0.0
var _hitstop_dur := 0.0
var _impacted := false  # this attack already fired its hit-stop

var _sprite: AnimatedSprite2D
var _hurtbox: Hurtbox
var _bar: FloatingHealthBar
var _status: StatusOverlay
var _edge_ray_left: RayCast2D
var _edge_ray_right: RayCast2D


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = Combat.L_ENEMY_BODY
	collision_mask = Combat.L_WORLD

	_build_sprite()
	_build_body()
	_build_hurtbox()
	_build_contact_hitbox()
	_build_health_bar()
	_build_edge_rays()

	_status = StatusOverlay.new()
	add_child(_status)
	_status.setup(_sprite)

	_has_melee = _sprite.sprite_frames.has_animation(&"attack")
	_has_ranged = _sprite.sprite_frames.has_animation(&"attack_projectile")
	_has_death = _sprite.sprite_frames.has_animation(&"death")
	_has_stroll = _sprite.sprite_frames.has_animation(&"stroll")

	health = max_health
	_bar.set_ratio(1.0)

	_point_a = global_position.x
	_point_b = global_position.x + patrol_distance
	_patrol_target = _point_b

	_sprite.frame_changed.connect(_on_frame_changed)
	_sprite.animation_finished.connect(_on_anim_finished)
	_sprite.animation_looped.connect(_on_anim_looped)
	_face(_facing)
	_play(&"stroll" if _has_stroll else &"idle")  # a strollless enemy (sleeper) just idles


# --- construction -----------------------------------------------------------

func _build_sprite() -> void:
	_sprite = AnimatedSprite2D.new()
	var path := FRAMES_PATH % enemy_id
	if not ResourceLoader.exists(path):
		push_error("Enemy '%s': no SpriteFrames at %s" % [enemy_id, path])
		return
	_sprite.sprite_frames = load(path)
	anchor_to_feet(_sprite)
	add_child(_sprite)


func _build_body() -> void:
	add_child(Shapes.make_box(body_size, Vector2(0, -body_size.y / 2.0)))


func _build_hurtbox() -> void:
	_hurtbox = Hurtbox.new()
	_hurtbox.collision_layer = Combat.L_ENEMY_HURT
	_hurtbox.collision_mask = 0
	_hurtbox.add_child(Shapes.make_box(hurtbox_size, Vector2(0, -hurtbox_size.y / 2.0)))
	add_child(_hurtbox)
	_hurtbox.hurt.connect(_on_hurt)


func _build_contact_hitbox() -> void:
	if contact_damage <= 0.0:
		return
	_contact_hitbox = Hitbox.new()
	_contact_hitbox.collision_layer = Combat.L_ENEMY_HIT
	_contact_hitbox.collision_mask = Combat.L_PLAYER_HURT
	_contact_hitbox.damage = contact_damage
	_contact_hitbox.knockback = contact_knockback
	_contact_hitbox.source = self
	_contact_hitbox.add_child(Shapes.make_box(hurtbox_size, Vector2(0, -hurtbox_size.y / 2.0)))
	add_child(_contact_hitbox)


func _build_edge_rays() -> void:
	# A downward probe just ahead of each foot; if it finds no ground, that side
	# is an edge and we won't step off it.
	_edge_ray_left = _make_edge_ray(-edge_check_x)
	_edge_ray_right = _make_edge_ray(edge_check_x)


func _make_edge_ray(x: float) -> RayCast2D:
	var ray := RayCast2D.new()
	ray.position = Vector2(x, -4)
	ray.target_position = Vector2(0, 16)
	ray.collision_mask = Combat.L_WORLD
	add_child(ray)
	return ray


## Is there ground just ahead in movement direction `dir` (-1/+1)?
func _floor_ahead(dir: int) -> bool:
	var ray := _edge_ray_left if dir < 0 else _edge_ray_right
	ray.force_raycast_update()
	return ray.is_colliding()


func _build_health_bar() -> void:
	_bar = FloatingHealthBar.new()
	add_child(_bar)
	_bar.setup(display_name)
	# Just above the head (sprite is drawn from feet at y=0 upward).
	var frame := _sprite.sprite_frames.get_frame_texture(&"idle", 0)
	var head_y := -(frame.get_height() if frame else 70) + 8
	_bar.position = Vector2(0, head_y)


# --- loop -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return

	if not is_on_floor():
		velocity.y += gravity * delta

	# Hit-stop: frozen on the impact frame, shaking, dealing no new actions. Still
	# settle vertically so it doesn't hang in the air, but no horizontal drift.
	if _hitstop_left > 0.0:
		_hitstop_left -= delta
		velocity.x = 0.0
		_apply_shake()
		if _hitstop_left <= 0.0:
			_end_hitstop()
		move_and_slide()
		return

	if _state == State.STUN:
		# Frozen: keep sliding on knockback momentum, but take no actions.
		_stun_left -= delta
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		if _stun_left <= 0.0:
			_set_state(State.IDLE)
	elif _state == State.MELEE or _state == State.RANGE:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)  # rooted while attacking
	else:
		_act(delta)

	if _state == State.IDLE:
		_idle_scratch(delta)
	_tick_contact(delta)
	move_and_slide()


## Resting-idle flourish: hold the sub-loop for a while, then a full cycle.
func _idle_scratch(delta: float) -> void:
	# In combat, don't loaf: hold the first idle frame as a tense ready-stance.
	# Reverts automatically once the player leaves reach (_engaged clears).
	if _engaged:
		if _sprite.animation != &"idle":
			_sprite.play(&"idle")
		if _sprite.frame != 0 or _sprite.is_playing():
			_sprite.set_frame_and_progress(0, 0.0)
			_sprite.pause()
		return
	if idle_loop_to <= idle_loop_from or _scratch_full_cycle:
		return  # not configured, or letting a full idle play (_on_anim_looped ends it)
	_scratch_timer -= delta
	if _scratch_timer <= 0.0:
		_scratch_full_cycle = true
		_sprite.set_frame_and_progress(0, 0.0)  # play one full idle from the top


## The sub-range loop is clamped here (on the render frame it changes) rather
## than in physics, so the past-the-range frame never flashes.
func _clamp_scratch() -> void:
	if _state != State.IDLE or _scratch_full_cycle or _sprite.animation != &"idle":
		return
	if idle_loop_to <= idle_loop_from:
		return
	if _sprite.frame > idle_loop_to or _sprite.frame < idle_loop_from:
		_sprite.set_frame_and_progress(idle_loop_from, 0.0)


func _on_anim_looped() -> void:
	if _sprite.animation == &"idle" and _scratch_full_cycle:
		_scratch_full_cycle = false
		_scratch_timer = idle_loop_time


func _tick_contact(delta: float) -> void:
	if _contact_hitbox == null:
		return
	_contact_cd = maxf(_contact_cd - delta, 0.0)
	if _contact_cd <= 0.0:
		_contact_hitbox.activate()  # re-arm; hits the player if still overlapping
		_contact_cd = contact_interval


func _act(delta: float) -> void:
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_alert_left = maxf(_alert_left - delta, 0.0)

	var player := _player()
	if player != null:
		var to_player := player.global_position.x - global_position.x
		var dist: float = absf(to_player)
		# Attacks are horizontal, so we can only land one when the player is roughly at our
		# height (see attack_align_y) -- otherwise don't swing/fire at all.
		var aligned := absf(player.global_position.y - global_position.y) <= attack_align_y
		if aligned and _attack_cd <= 0.0:
			if _has_melee and dist <= melee_range:
				_start_attack(State.MELEE, &"attack", player)
				return
			if _has_ranged and dist <= ranged_range:
				_start_attack(State.RANGE, &"attack_projectile", player)
				return
		# Are we in combat? PURSUE = close in on the player from any height/range -- when
		# aggressive by nature (aggro) or freshly hurt (alerted). HOLD = stand and face when
		# they're on our level and in ranged reach. Neither -> fall through to patrol, so an
		# enemy on a different platform keeps strolling instead of freezing.
		var dir := int(sign(to_player))
		var pursue := _alert_left > 0.0 or (aggro and dist <= aggro_range)
		var hold := aligned and dist <= ranged_range
		if pursue or hold:
			_engaged = true
			# Chase toward the player (never off a ledge) unless we're already adjacent.
			if pursue and dist > melee_range + 4.0 and _floor_ahead(dir):
				velocity.x = dir * move_speed
				_face(dir)
				_set_state(State.STROLL)
			else:
				velocity.x = 0.0
				_face(dir)
				_set_state(State.IDLE)
			return

	_engaged = false  # nobody in reach -> back to normal patrol/idle
	_patrol(delta)


func _patrol(delta: float) -> void:
	if _idle_timer > 0.0:
		# Pausing at the end of a leg; the target was already flipped on arrival.
		_idle_timer -= delta
		velocity.x = 0.0
		_set_state(State.IDLE)
		return

	var dir := int(sign(_patrol_target - global_position.x))
	var arrived := dir == 0 or absf(_patrol_target - global_position.x) <= 2.0
	# Turn around at the patrol end OR at a real ledge, whichever comes first.
	if arrived or not _floor_ahead(dir):
		velocity.x = 0.0
		_idle_timer = randf_range(idle_time_min, idle_time_max)
		_patrol_target = _point_a if is_equal_approx(_patrol_target, _point_b) else _point_b
		_set_state(State.IDLE)
		return

	velocity.x = dir * move_speed
	_face(dir)
	_set_state(State.STROLL)


# --- attacks ----------------------------------------------------------------

func _start_attack(state: State, anim: StringName, player: Node2D) -> void:
	_set_state(state)
	velocity.x = 0.0
	_attack_fired = false
	_impacted = false
	_engaged = true  # attacking means we're in combat, so the idle stays a stance
	_face(int(sign(player.global_position.x - global_position.x)))
	_play(anim)


func _on_frame_changed() -> void:
	if _state == State.MELEE and _sprite.frame in _hit_frames(&"attack"):
		_spawn_melee_strike()
		_begin_hitstop()
	elif _state == State.RANGE and not _attack_fired and _sprite.frame >= _fire_frame():
		_attack_fired = true
		_fire_projectile()
		_begin_hitstop()
	elif _state == State.IDLE:
		_clamp_scratch()


## Freeze the attack on this impact frame for a beat and shake the sprite, so the
## blow lands with weight. Once per attack; the physics loop resumes it.
func _begin_hitstop() -> void:
	if _impacted or attack_hitstop <= 0.0:
		return
	_impacted = true
	_hitstop_dur = attack_hitstop
	_hitstop_left = attack_hitstop
	_sprite.pause()  # hold the impact frame; resumes in _end_hitstop


func _end_hitstop() -> void:
	_hitstop_left = 0.0
	_sprite.position = Vector2.ZERO  # undo the shake
	if _state == State.MELEE or _state == State.RANGE or _state == State.RAGE:
		_sprite.play()  # let the swing (or nasen's rage) follow through to its finish


## Decaying jitter over the hit-stop: strongest on impact, settling to nothing.
func _apply_shake() -> void:
	if attack_shake <= 0.0 or _hitstop_dur <= 0.0:
		_sprite.position = Vector2.ZERO
		return
	var amp := attack_shake * (_hitstop_left / _hitstop_dur)
	_sprite.position = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))


func _on_anim_finished() -> void:
	if _state == State.DEAD:
		_fade_and_free()  # death anim played out -> fade the corpse and remove it
		return
	# A looping melee keeps swinging while the player stays in reach, re-playing from its
	# loop_from frame so the wind-up only plays once. Otherwise it's one-and-done.
	if _state == State.MELEE and attack_loops and _in_melee_reach():
		_attack_fired = false
		_impacted = false
		_replay_from(&"attack", _loop_from(&"attack"))
		return
	if _state == State.MELEE or _state == State.RANGE:
		_attack_cd = attack_cooldown
		_set_state(State.IDLE)


## Emitted frame an animation's loop restarts at (from the generator's `loop_from`
## metadata), or 0 if unset. Used by _replay_from so a re-played attack skips its lead-in.
func _loop_from(anim: StringName) -> int:
	return maxi(AnimMeta.loop_bound(_sprite.sprite_frames, anim, "loop_from"), 0)


## Re-play `anim` from emitted frame `from`, skipping its lead-in, and resume to the end (so
## _on_anim_finished can loop it again). The reusable half of a looping/channeled attack --
## the caller decides WHEN to loop (Enemy: player in reach; Nasen: still raging).
func _replay_from(anim: StringName, from: int) -> void:
	if _sprite.animation != anim:
		_sprite.play(anim)
	var last := _sprite.sprite_frames.get_frame_count(anim) - 1
	_sprite.set_frame_and_progress(clampi(from, 0, last), 0.0)
	_sprite.play()


## Is the player still within melee reach + on our level (the condition a looping melee
## keeps swinging on)?
func _in_melee_reach() -> bool:
	var player := _player()
	if player == null:
		return false
	var to := player.global_position - global_position
	return absf(to.y) <= attack_align_y and absf(to.x) <= melee_range


## Spawn a hostile Strike for one melee swing -- the enemy counterpart to a player's
## melee. Its Hitbox is built from this enemy's melee tuning; Strike sets the team layers
## from `hostile` and frees itself after a brief flash. Attached to the enemy so it sits
## in front of the body for the swing.
func _spawn_melee_strike() -> void:
	var strike := Strike.new()
	strike.hostile = true
	strike.friendly_fire = friendly_fire  # also catch other enemies, if flagged
	strike.lifetime = 0.15
	strike.source = self
	var hb := Hitbox.new()
	hb.damage = melee_damage
	hb.knockback = melee_knockback
	hb.stun = melee_stun
	hb.source = self
	hb.add_child(Shapes.make_box(melee_hitbox_extents * 2.0, Vector2(0, -melee_hitbox_extents.y)))
	strike.add_child(hb)
	add_child(strike)                                  # _ready: team layers + free timer
	strike.position = Vector2(melee_hitbox_x * _facing, 0)
	hb.activate()


func _fire_projectile() -> void:
	var muzzle := global_position + Vector2(muzzle_offset.x * _facing, muzzle_offset.y)
	# One shared Projectile class for players AND enemies -- hostile = true puts it on
	# the enemy-hit layer scanning player hurtboxes, homing = 0 flies straight, and the
	# look/damage are the `ranged_particle` scene + a Hitbox built from this enemy's tuning.
	var proj := Projectile.new()
	proj.hostile = true
	proj.friendly_fire = friendly_fire  # also catch other enemies, if flagged
	proj.homing = 0.0                # aim once / surge forward -- no steering
	proj.rotate_to_heading = false   # visual authored blasting +x -> mirror, don't rotate
	proj.source = self
	if not ranged_particle.is_empty():
		proj.add_child((load(ranged_particle) as PackedScene).instantiate())

	# The shot's damage box, sized from this enemy's ranged hitbox exports. The
	# Projectile arms it and sets its team layers from `hostile` on _ready.
	var hb := Hitbox.new()
	hb.damage = ranged_damage
	hb.knockback = ranged_knockback
	hb.stun = ranged_stun
	hb.add_child(Shapes.make_box(ranged_hitbox_extents * 2.0, ranged_hitbox_offset))
	proj.add_child(hb)

	if ranged_mode == "forward":
		# Surge straight ahead along the ground; capped distance via max_range.
		proj.velocity = Vector2(projectile_speed * _facing, 0.0)
		proj.max_range = ranged_travel
		proj.ground_trail = true  # scorch the floor red as it rolls past
	else:
		# Aim at the player's torso so a high muzzle still connects with a short body;
		# fall back to straight ahead if the player vanished mid-cast. Fizzle after a
		# few seconds if it misses everything.
		var player := _player()
		var target := (player.global_position + Vector2(0, -15)) if player != null \
			else muzzle + Vector2(_facing, 0)
		proj.velocity = (target - muzzle).normalized() * projectile_speed
		proj.max_life = 3.0

	# Live in the level, not under the enemy, so it keeps going if the enemy dies.
	# Nodes.place_at snaps it to the muzzle without physics-interpolation smear.
	get_parent().add_child(proj)
	Nodes.place_at(proj, muzzle)


func _fire_frame() -> int:
	# Fire on the authored hit frame (hit_frames metadata), else mid-animation.
	var hits := _hit_frames(&"attack_projectile")
	if not hits.is_empty():
		return int(hits[0])
	@warning_ignore("integer_division")
	return maxi(1, _sprite.sprite_frames.get_frame_count(&"attack_projectile") / 2)


func _hit_frames(anim: StringName) -> Array:
	return AnimMeta.hit_frames(_sprite.sprite_frames, anim)


# --- damage / death ---------------------------------------------------------

func _on_hurt(hit: Hit) -> void:
	if _state == State.DEAD:
		return
	health = maxf(health - hit.amount, 0.0)
	_bar.set_ratio(health / max_health)
	flash(_sprite)
	# Getting hit alerts us: pursue the attacker for a while even if it struck from beyond
	# our normal detection range, and snap to face where the blow came from.
	if alert_duration > 0.0:
		_alert_left = alert_duration
		if hit.source is Node2D:
			_face(int(sign((hit.source as Node2D).global_position.x - global_position.x)))
	if health <= 0.0:
		_die()
		return
	# Knockback needs a brief stagger, or the AI overwrites the shove velocity next
	# frame and nothing moves; a pure stun freezes for longer.
	var stagger := apply_knockback(hit, _facing)
	if stagger > 0.0:
		_stun_left = stagger
		_set_state(State.STUN)
		# A tagged freeze holds the current pose (not idle) + shows the overlay.
		if hit.status_color.a > 0.0:
			_sprite.pause()
			_status.show_for(hit.status_color, hit.status_time)


## Enter the DEAD state and stop receiving hits. The body stays for the death
## animation; debug_respawn clears and re-spawns the roster.
func _die() -> void:
	_set_state(State.DEAD)  # _physics_process bails on DEAD, so the AI stops here
	_hurtbox.set_deferred("monitorable", false)
	set_deferred("collision_layer", 0)
	if _has_death:
		_play(&"death")  # play it out; _on_anim_finished fades + frees when it ends
	else:
		_fade_and_free()  # no death sheet -> the old straight alpha-fade


## Let the final (dead) pose sit a beat, then fade the corpse out and free. The graceful
## tail of a death animation, or the whole thing for an enemy with no death sheet.
func _fade_and_free() -> void:
	var tw := create_tween()
	tw.tween_interval(0.4)  # hold the dead pose so the death reads before it clears
	tw.tween_property(_sprite, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)


# --- helpers ----------------------------------------------------------------

func _player() -> Node2D:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	# A dead player is no target: enemies stop detecting/attacking and go back to patrol
	# while the death anim + respawn play out.
	if p != null and p.has_method("is_dead") and p.is_dead():
		return null
	return p


func _face(dir: int) -> void:
	if dir == 0:
		return
	_facing = dir
	_sprite.flip_h = dir < 0  # sheets face right; flip when facing left


func _set_state(state: State) -> void:
	if _state == state:
		return
	_state = state
	match state:
		State.IDLE:
			_play(&"idle")
			_scratch_timer = idle_loop_time  # fresh scratch loop each time he rests
			_scratch_full_cycle = false
			if _engaged:  # combat: snap straight to the held ready-stance, no flicker
				_sprite.set_frame_and_progress(0, 0.0)
				_sprite.pause()
		State.STUN: _play(&"idle")
		State.STROLL: _play(&"stroll" if _has_stroll else &"idle")


func _play(anim: StringName) -> void:
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)
