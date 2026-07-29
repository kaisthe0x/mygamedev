@tool
extends Combatant
class_name Player

## A character-agnostic player.
##
## Every character shares the same animation set and the same normalised sprite
## canvas (see tools/gen_spriteframes.py), so switching is just swapping the
## SpriteFrames resource -- no per-character offsets or colliders needed.
## Pick one in the inspector, or call set_character() / cycle_character().

## Emitted on every health change, and once on ready so UI can seed itself.
signal health_changed(current: float, maximum: float)
## Emitted when the active character changes, for portrait/name displays.
signal character_changed(id: String)

## Character roster + resource-path templates live in CharacterConfig; per-character
## moves + tuning in the Moves catalog (configs/moves.gd).

@export_enum("feyke", "katalyst", "khalid", "lenbondosen", "wayna")
var character: String = "khalid":
	set(value):
		character = value
		_apply_character()

@export_group("Health")
@export var max_health: float = 100.0:
	set(value):
		max_health = maxf(value, 1.0)
		health = minf(health, max_health)

var health: float = 100.0:
	set(value):
		var clamped := clampf(value, 0.0, max_health)
		if is_equal_approx(clamped, health):
			return
		health = clamped
		health_changed.emit(health, max_health)

@export_group("Movement")
## The current character's run speed (px/s). Seeded per character on every character
## change from CharacterConfig.RUN_SPEEDS -- edit per-character values THERE, not here
## (this is overwritten on swap). The inspector value only applies before a character
## is equipped.
@export var run_speed: float = 160.0
@export var acceleration: float = 1200.0
@export var friction: float = 1400.0
## Run-cycle cadence relative to ground speed. Playback = speed/run_speed ×
## run_anim_speed, so the legs keep pace with actual movement (busier when
## sprinting, slower when starting) instead of foot-sliding -- a slide reads as a
## smeary "blurry" run. >1 = busier legs. Purely visual; tune to taste.
@export var run_anim_speed: float = 1.5
## The current character's jump velocity (negative = up). Seeded per character on every
## character change from CharacterConfig.JUMP_VELOCITIES -- edit per-character values
## THERE, not here (this is overwritten on swap). More negative = higher jump.
@export var jump_velocity: float = -330.0
## Extra mid-air jumps after the ground jump (1 = a double jump). The ground jump is
## silent; each air jump re-boosts AND spawns the character's jump particles (a
## combat-capable burst -- see emitters.json "double_jump").
@export var max_air_jumps: int = 10
@export var gravity: float = 900.0
## Falling faster than rising makes the arc feel less floaty.
@export var fall_gravity_scale: float = 1.35

@export_group("Dash")
## The current character's dash (lunge) speed. Seeded per character on every character
## change from CharacterConfig.DASH_SPEEDS -- edit per-character values THERE, not here
## (this is overwritten on swap). Higher = a faster, farther dash.
@export var dash_speed: float = 420.0
@export var dash_time: float = 0.18
@export var dash_cooldown: float = 0.45
## How long the dash ANIMATION plays, decoupled from the lunge. The lunge stays
## fast (`dash_time`); when this is longer, the character settles to a stop over the
## extra time while the remaining dash frames play out -- so you see the animation
## instead of a fast-forward. Set it to <= `dash_time` for the old squeezed look.
@export var dash_anim_time: float = 0.30
## Gravity kept during an air dash. 0 hangs in place, 1 falls normally.
@export_range(0.0, 1.0) var dash_gravity_scale: float = 0.35

@export_group("Slam")
## Downward plunge speed of an air-down ground slam (much faster than a normal
## fall, so it reads as a committed slam). Universal move; only characters with a
## `slam` sheet can do it. Particles are authored per character in emitters.json.
@export var slam_speed: float = 1200.0
## Minimum clear space (px) directly below the feet before an air slam is allowed --
## if the nearest platform straight down is closer than this, the slam press does
## nothing (no room to build a real plunge). Set 0 to always allow.
@export var slam_min_clearance: float = 50.0
## The slam animation frame to LOCK on during a tall plunge -- the last descent frame,
## just before the impact frames. Sheet-relative (same numbering as emitters.json), so
## with the wind streaks on 0-2 and the impact on 3-4, this is 2. While locked the
## sprite is hidden (only the wind-streak particles show).
@export var slam_hold_frame: int = 2
## How far above the ground (px) a held slam releases its impact frames, so they play
## into the ground instead of in mid-air (like land_predict_distance for the slam).
@export var slam_impact_distance: float = 30.0

@export_group("Juice")
## Minimum falling speed on touchdown to play the landing squash (characters
## that have a `land` animation). Below it -- little hops, walking off a lip --
## you snap straight to idle/run with no squash.
@export var land_min_fall_speed: float = 140.0
## How far above the ground (px) the LAND animation starts, so it plays THROUGH the
## touchdown instead of after it. A downward ray this long, while falling at least
## land_min_fall_speed; keep it small (an anticipation, not an early snap). 0 = land
## only on touchdown. Only matters for characters with a `land` sheet.
@export var land_predict_distance: float = 22.0

@export_group("Attack")
## How long the sprite holds on a hit frame before returning to idle, if the
## combo isn't continued. Short -- just enough to read the hit.
@export var attack_recovery: float = 0.12
## Grace period after a hit lands in which another press continues the combo
## instead of restarting it. Ticks on through idle, so you can chain after
## control returns; keep it >= attack_recovery.
@export var combo_reset_time: float = 0.45

## Max radians the double-jump exhaust tilts away from straight-down at full run speed
## (~34°). The puff leans opposite to horizontal travel; 0 = straight down. Tune to taste.
const DOUBLE_JUMP_LEAN := 0.6

enum State {IDLE, RUN, JUMP, DASH, ATTACK, SPECIAL, LAND, SLAM, FALL}

var _state: State = State.IDLE
var _facing: int = 1
## The active attack + special for this character (from the Moves catalog). They
## decide which animation plays and its hit tuning; swap them with set_move() (a
## future UI hook). Seeded to the character's defaults on every character change.
var _current_attack: Move
var _current_special: Move
## The resolved per-hit tuning of the attack/special currently swinging -- damage,
## knockback, stun, reach, and the lunge / super-armor / multi-hit knobs. Set at
## segment/special start via resolve_tuning() (the buff seam), and read by the
## ParticleDirector when it arms that attack's Hitbox -- so combat numbers live in
## configs/moves.gd, not baked in the effect scene. Empty = no attack in progress (or a
## move that deliberately carries its own scene numbers, like the two finger-gun shots).
var _active_hit: Dictionary = {}
var _dash_left: float = 0.0
## Counts down the whole dash state (lunge + the animation's tail), so the frames
## finish playing after the lunge is over.
var _dash_anim_left: float = 0.0
var _dash_cd: float = 0.0
## Airborne tracking, so a touchdown can trigger the landing squash.
var _was_on_floor: bool = true
var _fall_peak: float = 0.0 # fastest downward speed reached this airborne stretch
## Highest point (min y) reached this airborne stretch, so a touchdown can report how far
## he DROPPED (landing y - apex y) to the ability's on_land -- e.g. Katalyst's fall damage.
var _apex_y: float = 0.0
## Air jumps spent since leaving the ground; reset on touchdown (see _physics_process).
var _air_jumps_used: int = 0
## True only when a jump was actually triggered, so the jump animation replays its
## launch. Entering JUMP just by being airborne (after a dash, walking off a ledge)
## leaves it false -- the anim then holds its last (fall) frame instead of relaunching.
var _jump_launch: bool = false
## True once a slam has released its impact frames (near the ground), so the held
## descent doesn't re-lock and the sprite stays shown while the impact plays out.
var _slam_impacting: bool = false
var _just_landed: bool = false
## Which combo segment we're on (index into the attack's hit-frame list).
var _combo_step: int = 0
## Emitted frame the current segment ends on (the hit).
var _seg_end: int = 0
## True while a segment is animating; false while holding on its hit frame.
var _combo_playing: bool = false
## Time left to chain into the next segment (ticks through the hold and idle).
var _combo_window: float = 0.0
## Time left holding the current hit frame before control returns to idle.
var _recovery_left: float = 0.0
## A special press during a light swing, held until the current hit lands so a fast
## light->special cancels into the special instead of being swallowed by recovery.
var _buffered_special: bool = false
## Time left frozen from a stun-carrying hit (input ignored).
var _stun_left: float = 0.0
## Time left of super-armor: while > 0, hits still hurt but don't stagger/interrupt.
## Granted by a Strike's tuning via set_armor() (a future buff/heavy-attack property).
var _armor_left: float = 0.0
## Time left the sprite is FROZEN on its current frame -- an attack/special holding its
## pose while a timed effect plays (Wayna held on the inferno cast frame while the fire
## emits). Set by hold_animation(); the sprite resumes when it hits 0.
var _hold_left: float = 0.0
## The active held/channeled effect (Wayna's inferno) while its emission plays, so a hit
## can break it (see _on_hurt). Null when nothing is being channeled.
var _channel: Strike = null
## The current character's unique ability, or null if they have none.
var _ability: CharacterAbility
## Drives frame-indexed 2D particle effects; created at runtime (not in editor).
var _particles: ParticleDirector
## Combat boxes, built in code (like the particle director) to avoid a scene edit.
var _hurtbox: Hurtbox
var _status: StatusOverlay

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	health = max_health
	_apply_character()
	if Engine.is_editor_hint():
		return
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.animation_looped.connect(_on_animation_looped)

	_particles = ParticleDirector.new()
	add_child(_particles)
	_particles.setup(_sprite)
	_particles.set_character(character)

	_build_combat()
	_sprite.frame_changed.connect(_on_frame_changed)

	# Seed listeners that connected before _ready (the setters stay silent when
	# the value doesn't actually change, so the HUD would otherwise start blank).
	health_changed.emit(health, max_health)
	character_changed.emit(character)


func _apply_character() -> void:
	# The setter can fire before the node tree exists (and again in the editor).
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return
	var path := CharacterConfig.FRAMES_PATH % character
	if not ResourceLoader.exists(path):
		push_warning("No SpriteFrames for character '%s' at %s" % [character, path])
		return
	sprite.sprite_frames = load(path)
	# Seed this character's default attack + special from the Moves catalog (they
	# drive which animation ATTACK/SPECIAL play and its hit tuning).
	_current_attack = Moves.get_move(character, "attacks")
	_current_special = Moves.get_move(character, "specials")
	# Per-character movement feel (Katalyst runs a touch faster, jumps a touch higher,
	# dashes a touch faster, etc.).
	run_speed = CharacterConfig.run_speed(character)
	jump_velocity = CharacterConfig.jump_velocity(character)
	dash_speed = CharacterConfig.dash_speed(character)
	# The generator's canvas size changes whenever the art does, so derive the
	# offset from the frames rather than baking it into the scene.
	anchor_to_feet(sprite)
	# Attack frame counts differ per character, so a half-finished combo would
	# point at a frame the new character may not have.
	_combo_step = 0
	_combo_window = 0.0
	_combo_playing = false
	_buffered_special = false
	# Drop back to idle: a state-specific animation (e.g. slam) may not exist on the
	# new character, and a swap is a clean slate anyway. Skip in the editor so a
	# preview character keeps whatever pose the scene is set to show.
	if not Engine.is_editor_hint():
		_state = State.IDLE
	sprite.speed_scale = 1.0
	sprite.play(_animation_for(_state))
	_equip_ability()
	if _particles != null: # null during the initial _ready pass; set up just after
		_particles.set_character(character)
	character_changed.emit(character)


## Swap in the ability script named after this character, if one exists.
func _equip_ability() -> void:
	_ability = null
	if Engine.is_editor_hint():
		return
	var path := CharacterConfig.ABILITY_PATH % character
	if not ResourceLoader.exists(path):
		return
	var script: GDScript = load(path)
	_ability = script.new() as CharacterAbility
	if _ability == null:
		push_warning("%s must extend CharacterAbility" % path)
		return
	_ability.setup(self)


## Read-only access to the state machine, for abilities and other systems.
func get_state() -> State:
	return _state


## Switch the active attack or special to `id` -- one of Moves.ids(character, kind).
## `kind` is "attacks" or "specials". This is the hook a future move-select UI calls;
## until then the character's catalog defaults are used. An unknown id falls back to
## the default. (To change the *default*, edit configs/moves.gd.)
func set_move(kind: String, id: String) -> void:
	if kind == "attacks":
		_current_attack = Moves.get_move(character, "attacks", id)
	elif kind == "specials":
		_current_special = Moves.get_move(character, "specials", id)


## Which way the character faces (+1 right, -1 left) -- for abilities that spawn
## directional effects.
func get_facing() -> int:
	return _facing


## Turn to face the mouse cursor. Used when standing still and on every attack, so
## you look and strike toward the pointer; a small dead zone around his own x stops
## flip jitter when the cursor sits right on top of him. (Walking still faces the
## movement direction -- that wins over the mouse.)
const MOUSE_FACE_DEADZONE := 4.0

func _face_mouse() -> void:
	var dx := get_global_mouse_position().x - global_position.x
	if absf(dx) > MOUSE_FACE_DEADZONE:
		_facing = 1 if dx > 0.0 else -1


## Path to the current character's portrait, for HUD / character-select art.
func portrait_path() -> String:
	return CharacterConfig.PORTRAIT_PATH % (character.substr(0, 1).to_upper() + character.substr(1))


## Subtract `amount` from health and flash the hit tell. The health setter clamps
## and emits health_changed for the HUD.
func take_damage(amount: float) -> void:
	health -= amount
	flash(_sprite)


## Build the combat boxes and register on the "player" group so enemies find us.
func _build_combat() -> void:
	add_to_group("player")
	collision_layer = Combat.L_PLAYER_BODY
	collision_mask = Combat.L_WORLD

	_hurtbox = Hurtbox.new()
	_hurtbox.collision_layer = Combat.L_PLAYER_HURT
	_hurtbox.collision_mask = 0
	_hurtbox.add_child(Shapes.make_box(Vector2(16, 30), Vector2(0, -15)))
	add_child(_hurtbox)
	_hurtbox.hurt.connect(_on_hurt)

	# No built-in attack box any more: every attack is a spawned Strike/Projectile whose
	# own Hitbox carries the hit, fed from moves.gd via the director (see _active_hit).

	_status = StatusOverlay.new()
	add_child(_status)
	_status.setup(_sprite)


## THE BUFF SEAM. Resolve the effective per-hit tuning of `move`'s combo segment `seg`
## -- the numbers the attack's Hitbox is configured with. Today it's the base straight
## from configs/moves.gd; the item/build system will later layer its modifiers here
## (damage x1.3, +reach, hits twice, ...) so every attack becomes buffable without
## re-plumbing. Set into _active_hit at segment/special start; read by the director.
func resolve_tuning(move: Move, seg: int = 0) -> Dictionary:
	var base: Dictionary = move.segment(seg)
	# <-- buff/item/event modifiers fold in here later (base is copied so nothing mutates
	# the catalog). For now the effective hit IS the base.
	return base.duplicate()


## The resolved tuning of the attack currently swinging, for the ParticleDirector to
## feed into that attack's Hitbox. Empty when no attack is in progress.
func active_hit() -> Dictionary:
	return _active_hit


## Take a hit: damage, optional shove, optional freeze/overlay.
## A dash grants i-frames (the hurtbox is off), so this only fires when vulnerable.
func _on_hurt(hit: Hit) -> void:
	take_damage(hit.amount)
	# Per-character reaction to being hurt (retaliation, defensive buff, ...).
	if _ability != null:
		_ability.on_hurt(self, hit)
	# A held/channeled effect (Wayna's inferno) breaks when she's hit, if it opts in --
	# stop it and release the pose-hold. Independent of the ability hook above.
	if _channel != null and is_instance_valid(_channel) and _channel.interrupt_on_hurt:
		_channel.cancel()
		_hold_left = 0.0
		_sprite.play()
	_channel = null
	# Super-armor: the hit still hurts, but no knockback/stagger and the swing isn't
	# interrupted (a Strike granted it via set_armor from its tuning).
	if _armor_left > 0.0:
		return
	var stagger := apply_knockback(hit, _facing) # shove + how long to stagger
	if stagger > 0.0:
		_stun_left = stagger
		_combo_playing = false
		_state = State.IDLE
	if hit.status_color.a > 0.0:
		_status.show_for(hit.status_color, hit.status_time)


## Shove the player forward along its facing -- a Strike's lunge (option A: the strike
## reaches back to its wielder). A brief burst; friction bleeds it off. Dormant until a
## move/buff sets a `lunge` in its tuning.
func apply_lunge(impulse: float) -> void:
	velocity.x = impulse * _facing


## Grant super-armor for `duration` seconds (see _on_hurt). Stacks by taking the longer.
func set_armor(duration: float) -> void:
	_armor_left = maxf(_armor_left, duration)


## Freeze the sprite on its current frame for `duration` seconds, then resume -- so an
## attack/special can HOLD its pose while a timed effect plays out (a Strike with
## emit_duration calls this: Wayna stays on the inferno cast frame until the fire ends).
## The state machine keeps running (movement, gravity); only playback is paused, and the
## committed special won't end until its animation resumes and finishes.
func hold_animation(duration: float, effect: Strike = null) -> void:
	if duration <= 0.0 or _sprite == null:
		return
	_hold_left = maxf(_hold_left, duration)
	_channel = effect  # remember it so a hit can break the channel (see _on_hurt)
	_sprite.pause()


# Land the special on its authored strike frame (hit_frames metadata), or, if the
# character didn't author one, on the middle frame as a sensible default.
func _on_frame_changed() -> void:
	if _state == State.SPECIAL:
		if _sprite.frame == _special_strike_frame():
			if _ability != null:
				_ability.on_special_strike(self)
		return
	# Bounded loop: when a looping animation has a `loop_to`, snap back to
	# `loop_from` the moment playback steps past it, so the cycle stays inside the
	# range (e.g. Katalyst's idle loops 2-8). Done here on the render frame it
	# changes -- not in physics -- so the past-the-range frame never flashes.
	var loop_to := _loop_meta(&"loop_to")
	if loop_to >= 0 and _sprite.frame > loop_to:
		_sprite.set_frame_and_progress(maxi(_loop_meta(&"loop_from"), 0), 0.0)


func _special_strike_frame() -> int:
	var hits := AnimMeta.hit_frames(_sprite.sprite_frames, _current_special.animation)
	if not hits.is_empty():
		return int(hits[0])
	@warning_ignore("integer_division")
	return _sprite.sprite_frames.get_frame_count(_current_special.animation) / 2


## Add `amount` to health (setter clamps to max_health).
func heal(amount: float) -> void:
	health += amount


## Switch to character `id` if it's a known one (swaps SpriteFrames + ability).
func set_character(id: String) -> void:
	if id in CharacterConfig.IDS:
		character = id


## Step to the next/previous character in the roster, wrapping around.
func cycle_character(step: int = 1) -> void:
	var i := CharacterConfig.IDS.find(character)
	set_character(CharacterConfig.IDS[wrapi(i + step, 0, CharacterConfig.IDS.size())])


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_dash_cd = maxf(_dash_cd - delta, 0.0)
	_armor_left = maxf(_armor_left - delta, 0.0)
	if _hold_left > 0.0:
		_hold_left = maxf(_hold_left - delta, 0.0)
		if _hold_left <= 0.0 and _sprite != null:
			_sprite.play()  # resume the held animation where it left off
			_channel = null  # channel finished on its own

	# Track the fall so a touchdown from a real drop (not a tiny hop) can squash, and so
	# the ability's on_land learns how far/fast he fell.
	var on_floor := is_on_floor()
	if not on_floor:
		if _was_on_floor:
			_apex_y = global_position.y  # just left the ground -- start measuring the drop
		_fall_peak = maxf(_fall_peak, velocity.y) # +y is downward
		_apex_y = minf(_apex_y, global_position.y) # highest point reached (min y)
	_just_landed = on_floor and not _was_on_floor and _fall_peak >= land_min_fall_speed
	if on_floor and not _was_on_floor and _ability != null:
		_ability.on_land(self, maxf(global_position.y - _apex_y, 0.0), _fall_peak)
	if on_floor:
		_fall_peak = 0.0
		_air_jumps_used = 0 # refresh the double jump on every touchdown
	_was_on_floor = on_floor

	if _stun_left > 0.0:
		_process_stun(delta)
	elif _state == State.DASH:
		_process_dash(delta)
	elif _state == State.ATTACK:
		_process_attack(delta)
	elif _state == State.SPECIAL:
		_process_special(delta)
	elif _state == State.SLAM:
		_process_slam(delta)
	elif _state == State.LAND:
		_process_land(delta)
	else:
		# The combo only decays while you're not mid-swing.
		_combo_window = maxf(_combo_window - delta, 0.0)
		_process_normal(delta)

	# Runs after the state machine has set this frame's velocity but before it is
	# applied, so an ability can override any of it.
	if _ability != null:
		_ability.physics(self, delta)

	# Dash grants invulnerability: hitboxes/projectiles can't detect the hurtbox.
	# Only during the lunge (dash_time), not the animation's tail recovery, so the
	# i-frame window is unchanged by a longer dash_anim_time.
	if _hurtbox != null:
		_hurtbox.monitorable = not (_state == State.DASH and _dash_left > 0.0)

	move_and_slide()
	_update_animation(delta)


## Stunned: no input, just ride out gravity and knockback momentum.
func _process_stun(delta: float) -> void:
	_stun_left -= delta
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = move_toward(velocity.x, 0.0, friction * 0.5 * delta)
	_state = State.IDLE


func _process_dash(delta: float) -> void:
	_dash_anim_left -= delta
	if _dash_left > 0.0:
		_dash_left -= delta
		velocity.x = dash_speed * _facing # the lunge -- unchanged, still snappy
	else:
		# Lunge done: settle to a stop over the rest of the window while the dash
		# frames finish, so the animation plays out without the dash reaching farther.
		var recovery := maxf(dash_anim_time - dash_time, 0.001)
		velocity.x = move_toward(velocity.x, 0.0, (dash_speed / recovery) * delta)
	if is_on_floor():
		velocity.y = 0.0
	else:
		# Keep falling through an air dash, just lighter, so it arcs instead of
		# hanging in place on an invisible floor.
		velocity.y += gravity * dash_gravity_scale * delta
	if _dash_anim_left <= 0.0:
		_enter(State.IDLE)


func _process_normal(delta: float) -> void:
	var input := Input.get_axis("move_left", "move_right")

	if not is_on_floor():
		var g_scale := fall_gravity_scale if velocity.y > 0.0 else 1.0
		velocity.y += gravity * g_scale * delta

	if input != 0.0:
		_facing = 1 if input > 0.0 else -1
		velocity.x = move_toward(velocity.x, input * run_speed, acceleration * delta)
	else:
		_face_mouse() # standing still: turn to look toward the cursor
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	# Special: on the ground it's the character's special; in the AIR it becomes the
	# ground slam instead (specials are grounded-only). A character with no slam sheet
	# simply can't act on the special button while airborne.
	if Input.is_action_just_pressed("special"):
		if is_on_floor() and _current_special != null:
			_start_special() # supersedes any light chain in progress
			return
		elif not is_on_floor() and _has_slam() and _slam_has_clearance():
			_enter(State.SLAM) # air special = ground slam (only with room below)
			return
	# Attacks are grounded-only -- no air attacks.
	if Input.is_action_just_pressed("attack") and is_on_floor():
		_advance_combo()
		return
	if Input.is_action_just_pressed("dash") and _dash_cd <= 0.0:
		_enter(State.DASH)
		return
	# `drop` (down by default): on the ground, fall through the one-way platform you're
	# standing on (a no-op on the solid floor). The slam is on the special button now
	# (see above), so drop does nothing in the air. Jump is just jump.
	if Input.is_action_just_pressed("drop") and is_on_floor():
		_drop_through_platform()
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = jump_velocity # ground jump -- silent, no particles
			_jump_launch = true
		elif _air_jumps_used < max_air_jumps:
			_air_jump()

	if not is_on_floor():
		_set_airborne_state()
	elif _just_landed and _has_land():
		_enter(State.LAND)
	elif absf(velocity.x) > 5.0:
		_state = State.RUN
	else:
		_state = State.IDLE


## Pick the airborne animation state. Predictive LAND wins when we're dropping into
## the ground; otherwise JUMP while the launch/rise plays (then FALL, via
## _on_animation_finished), and FALL for any other way of leaving the ground.
func _set_airborne_state() -> void:
	if velocity.y >= land_min_fall_speed and _has_land() and _near_ground():
		_enter(State.LAND) # start the land early so it plays through touchdown
		return
	if _state == State.JUMP or _state == State.FALL:
		return # already airborne -- keep it (JUMP hands off to FALL when its anim ends)
	_state = State.JUMP if _jump_launch else _airborne_default()


## The passive airborne state: FALL if the character has a fall sheet, else JUMP (which
## just holds its last frame as a fall pose -- the old behaviour).
func _airborne_default() -> State:
	return State.FALL if _has_fall() else State.JUMP


## Drop through the one-way platform we're standing on: briefly ignore collisions
## with it so gravity pulls us down onto whatever's below. Only fires on an actual
## one-way platform (not the solid floor), so returns false there and a normal
## jump happens instead.
const DROP_THROUGH_TIME := 0.3

func _drop_through_platform() -> bool:
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider is Node and (collider as Node).is_in_group("oneway_platform"):
			add_collision_exception_with(collider)
			velocity.y = maxf(velocity.y, 60.0) # a nudge so we start dropping at once
			var body := collider
			get_tree().create_timer(DROP_THROUGH_TIME).timeout.connect(
				func() -> void:
					if is_instance_valid(body):
						remove_collision_exception_with(body))
			return true
	return false


## A mid-air jump (the double jump). Re-boosts upward, replays the launch pose, and
## -- unlike the silent ground jump -- spawns the character's jump particles: a
## code-triggered burst (combat-capable) under the "double_jump" key in emitters.json,
## fired here so only air jumps produce it. Guarded by _air_jumps_used < max_air_jumps.
func _air_jump() -> void:
	velocity.y = jump_velocity
	_air_jumps_used += 1
	# Go (back) to JUMP so the jump anim actually shows -- otherwise FALL/anim logic
	# reverts the sprite to `fall` the same frame. _jump_launch replays the launch.
	_jump_launch = true
	_enter(State.JUMP)
	_sprite.play(&"jump")
	_sprite.set_frame_and_progress(0, 0.0) # replay the launch from the top
	if _particles != null:
		# Tilt the exhaust OPPOSITE to horizontal travel (fling right -> puff kicks
		# down-left), scaled by how fast you're moving, so a sideways air-jump doesn't
		# spray straight down. 0 when moving straight up.
		var lean := clampf(velocity.x / maxf(run_speed, 1.0), -1.0, 1.0)
		_particles.fire_effect("double_jump", lean * DOUBLE_JUMP_LEAN)


## The landing animation -- it can start in the AIR (predictive, so it plays through
## touchdown) and finishes on the ground. Fully cancelable -- any action breaks out --
## so it never eats inputs; left alone it plays out and hands back to idle/run.
func _process_land(delta: float) -> void:
	if not is_on_floor():
		# Predictive pre-land: keep dropping while the anticipation plays. If we're no
		# longer heading into the ground (rose, or drifted off the edge), bail to the
		# air state so we don't "land" in mid-air.
		if velocity.y <= 0.0 or not _near_ground():
			_enter(_airborne_default())
			return
		velocity.y += gravity * fall_gravity_scale * delta
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		# Air-rule cancels (specials become the slam, attacks are grounded-only).
		if Input.is_action_just_pressed("special") and _has_slam() and _slam_has_clearance():
			_enter(State.SLAM)
			return
		if Input.is_action_just_pressed("dash") and _dash_cd <= 0.0:
			_enter(State.DASH)
			return
		if Input.is_action_just_pressed("jump") and _air_jumps_used < max_air_jumps:
			_air_jump()  # enters JUMP itself
		return

	# Grounded recovery.
	if Input.is_action_just_pressed("special") and _current_special != null:
		_start_special()
		return
	if Input.is_action_just_pressed("attack"):
		_advance_combo()
		return
	if Input.is_action_just_pressed("dash") and _dash_cd <= 0.0:
		_enter(State.DASH)
		return
	if Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
		_jump_launch = true
		_state = State.JUMP
		return

	var input := Input.get_axis("move_left", "move_right")
	if input != 0.0: # walk straight out of the landing
		_facing = 1 if input > 0.0 else -1
		velocity.x = move_toward(velocity.x, input * run_speed, acceleration * delta)
		_state = State.RUN
		return
	_face_mouse() # standing after landing: look toward the cursor
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)


func _has_land() -> bool:
	return _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(&"land")


func _has_fall() -> bool:
	return _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(&"fall")


## True when the ground is within `dist` px straight below -- used to start the LAND
## animation (and release the slam impact) just before touchdown. Same ray as the slam
## clearance check (our own collision_mask, so it catches solid ground AND one-way
## platforms). Defaults to `land_predict_distance`.
func _near_ground(dist := land_predict_distance) -> bool:
	if dist <= 0.0:
		return false
	var space := get_world_2d().direct_space_state
	if space == null:
		return false
	var q := PhysicsRayQueryParameters2D.create(
		global_position, global_position + Vector2(0.0, dist), collision_mask)
	q.exclude = [get_rid()]
	return not space.intersect_ray(q).is_empty()


func _process_attack(delta: float) -> void:
	# Rooted in place, but gravity still applies so air attacks fall.
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	if not is_on_floor():
		velocity.y += gravity * delta

	# A special pressed any time during the swing is remembered and fires the moment
	# the current hit lands -- so a fast light->special always cancels into the special
	# instead of the press being swallowed by the recovery frames.
	if Input.is_action_just_pressed("special"):
		_buffered_special = true

	if _combo_playing:
		# Animate through the segment; freeze on the hit frame once reached.
		# Pin in case playback overshot the hit between physics ticks.
		if _sprite.frame >= _seg_end:
			_sprite.set_frame_and_progress(_seg_end, 0.0)
			_sprite.pause()
			_combo_playing = false
			_recovery_left = attack_recovery
			_combo_window = combo_reset_time
			if _buffered_special: # cancel straight into the buffered special
				_start_special()
		return

	# Briefly hold the hit frame, then hand control back to idle. The chain
	# window keeps ticking there (see _physics_process), so you can still combo
	# after recovering -- the freeze doesn't have to outlast the whole window.
	if _buffered_special:
		_start_special()
		return
	if Input.is_action_just_pressed("attack"):
		_advance_combo()
		return
	_combo_window = maxf(_combo_window - delta, 0.0)
	_recovery_left -= delta
	if _recovery_left <= 0.0:
		_enter(State.IDLE)


## Commit to a special swing, clearing any light combo in progress. Shared by the
## normal/land states and by a light-attack cancel (see _process_attack).
func _start_special() -> void:
	_face_mouse() # aim the special toward the cursor
	_combo_step = 0
	_combo_window = 0.0
	_combo_playing = false
	_buffered_special = false
	_active_hit = resolve_tuning(_current_special, 0)  # feed the special's Hitbox
	_enter(State.SPECIAL)


## Unlike the light combo, a special swing is committed: it plays the whole
## animation, ignores input, and ends via _on_animation_finished().
func _process_special(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	if not is_on_floor():
		velocity.y += gravity * delta


## An air-down ground slam: committed like a special. Horizontal drift bleeds off
## while the character plunges straight down at `slam_speed`.
##
## The catch is a TALL plunge: the slam animation would finish (firing its impact
## frames) long before touchdown, so the impact particles would emit in mid-air. So
## while high, we LOCK the animation on its last descent frame (`slam_hold_frame`) and
## HIDE the sprite -- only the sustained wind-streak particles show, reading as a fast
## blur. Then, once the ground is within `slam_impact_distance` (like the predictive
## land), we release: show the sprite and let the remaining impact frames play into the
## ground, so the impact burst fires where it lands. _on_animation_finished -> idle.
func _process_slam(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	# Once released, just let the impact frames play out (through touchdown -> idle).
	if _slam_impacting:
		velocity.y = 0.0 if is_on_floor() else maxf(velocity.y, slam_speed)
		return
	if is_on_floor() or _near_ground(slam_impact_distance):
		_slam_release()  # close enough -- play the impact into the ground
		return
	# Still high: keep the fast plunge, and once the anim reaches the last descent
	# frame, lock it there so the impact can't fire yet, and hide the sprite.
	velocity.y = maxf(velocity.y, slam_speed)
	var hold := maxi(0, slam_hold_frame - _sheet_start(&"slam"))
	if _sprite.frame >= hold:
		_sprite.set_frame_and_progress(hold, 0.0)
		_sprite.speed_scale = 0.0
		_sprite.visible = false


## Release a held slam: show the sprite and resume playback so the impact frames run.
func _slam_release() -> void:
	_slam_impacting = true
	_sprite.visible = true
	_sprite.speed_scale = 1.0


## Sheet-relative -> emitted frame offset for `anim` (the generator drops the
## idle-reference frame 0 from action anims). Matches the numbering in emitters.json.
func _sheet_start(anim: StringName) -> int:
	var sf := _sprite.sprite_frames
	if sf != null and sf.has_meta("sheet_start"):
		return int(sf.get_meta("sheet_start").get(String(anim), 0))
	return 0


func _has_slam() -> bool:
	return _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(&"slam")


## True when there's at least `slam_min_clearance` of clear space straight down before
## the nearest platform -- so a slam has room to build a real plunge. A ray from the
## feet down that distance (against whatever the body lands on -- solid ground AND
## one-way platforms, via our own collision_mask); no hit = clear. 0 clearance = always.
func _slam_has_clearance() -> bool:
	if slam_min_clearance <= 0.0:
		return true
	var space := get_world_2d().direct_space_state
	if space == null:
		return true
	var q := PhysicsRayQueryParameters2D.create(
		global_position, global_position + Vector2(0.0, slam_min_clearance), collision_mask)
	q.exclude = [get_rid()] # ignore our own body
	return space.intersect_ray(q).is_empty()


## One press = one combo segment: play the frames up to the next hit, then hold
## there. Each hit frame is a segment boundary (see the generator's HIT_FRAMES).
## Letting `combo_reset_time` lapse drops you back to the first segment; pressing
## past the finisher wraps to the start.
func _advance_combo() -> void:
	_face_mouse() # aim the swing toward the cursor, even mid-combo
	var hits := _attack_hits()
	if hits.is_empty():
		return
	_buffered_special = false # each swing starts with a clean buffer

	if _combo_window <= 0.0 or _combo_step >= hits.size():
		_combo_step = 0 # cold start, or wrap after the finisher
	var seg_start := 0 if _combo_step == 0 else int(hits[_combo_step - 1]) + 1
	_seg_end = int(hits[_combo_step])
	_combo_step += 1
	# Resolve THIS segment's hit now (before its frames play), so the director feeds the
	# right damage/reach into the Strike/Projectile it fires for this segment.
	_active_hit = resolve_tuning(_current_attack, _combo_step - 1)

	_combo_window = combo_reset_time
	_combo_playing = true
	_enter(State.ATTACK)
	_sprite.speed_scale = 1.0
	_sprite.play(_current_attack.animation)
	_sprite.set_frame_and_progress(seg_start, 0.0)


## Emitted frame indices that end each combo segment. From the SpriteFrames
## `hit_frames` metadata (written by the generator); falls back to every frame.
func _attack_hits() -> Array:
	var hits := AnimMeta.hit_frames(_sprite.sprite_frames, _current_attack.animation)
	if not hits.is_empty():
		return hits
	return range(_sprite.sprite_frames.get_frame_count(_current_attack.animation))


func _enter(state: State) -> void:
	_state = state
	_sprite.speed_scale = 1.0
	_sprite.visible = true  # defensive: a held slam hides it; always restore on any entry
	match state:
		State.DASH:
			_dash_left = dash_time
			_dash_anim_left = maxf(dash_anim_time, dash_time)
			_dash_cd = dash_cooldown
			# Play the dash animation over the (longer) visible window rather than
			# squeezing it into the brief lunge, so the frames are seen, not
			# fast-forwarded. Frame counts differ per character (4-6); stretching to
			# fit keeps every dash the same length.
			var frames := _sprite.sprite_frames
			var fps := frames.get_animation_speed(&"dash")
			if fps > 0.0:
				var anim_time := frames.get_frame_count(&"dash") / fps
				_sprite.speed_scale = anim_time / maxf(dash_anim_time, dash_time)
		State.ATTACK:
			velocity.x = 0.0
		State.SLAM:
			# Commit: kill horizontal drift and start the downward plunge now.
			velocity = Vector2(0.0, slam_speed)
			_slam_impacting = false  # fresh slam: not yet released into the impact


func _animation_for(state: State) -> StringName:
	match state:
		State.RUN: return &"run"
		State.JUMP: return &"jump"
		State.FALL: return &"fall"
		State.DASH: return &"dash"
		State.ATTACK: return _current_attack.animation
		State.SPECIAL: return _current_special.animation
		State.LAND: return &"land"
		State.SLAM: return &"slam"
		_: return &"idle"


func _update_animation(_delta: float) -> void:
	_sprite.flip_h = _facing < 0
	var next := _animation_for(_state)
	if _sprite.animation != next:
		_sprite.play(next)
		# `jump` doubles as the fall pose. Only replay its launch when a jump was
		# actually triggered; entering JUMP just by being airborne (a dash ended, or
		# you walked off a ledge) snaps to the last frame so it doesn't look like a
		# fresh jump you never asked for.
		if next == &"jump" and not _jump_launch:
			var jn := _sprite.sprite_frames.get_frame_count(&"jump")
			if jn > 0:
				_sprite.set_frame_and_progress(jn - 1, 0.0)
	if next == &"jump":
		_jump_launch = false # spent once the jump anim is showing

	# Keep the run cadence matched to actual ground speed so the legs don't
	# foot-slide (which reads as a smeary run). Other states keep their own rate:
	# dash sets a stretch in _enter, attacks stay 1x, so only touch these.
	match _state:
		State.RUN:
			_sprite.speed_scale = clampf(
				absf(velocity.x) / maxf(run_speed, 1.0) * run_anim_speed, 0.4, 3.0)
		State.IDLE, State.JUMP, State.FALL, State.LAND:
			_sprite.speed_scale = 1.0


## A looping animation can have an intro: `loop_from` metadata (written by the
## generator) marks the frame the cycle restarts at, so the lead-in plays once
## and only the tail repeats. Wayna's run ignites over frames 0-3 then cycles 4-6.
## (A bounded `loop_to` is enforced in _on_frame_changed; this catches the case
## where the loop runs all the way to the last frame and wraps naturally.)
func _on_animation_looped() -> void:
	var start := _loop_meta(&"loop_from")
	if start > 0:
		_sprite.set_frame_and_progress(start, 0.0)


## Emitted-frame value from a loop metadata dict (`loop_from` / `loop_to`) for the
## animation currently playing, or -1 if unset.
func _loop_meta(key: StringName) -> int:
	return AnimMeta.loop_bound(_sprite.sprite_frames, _sprite.animation, String(key))


func _on_animation_finished() -> void:
	# Jump's launch/rise is over: if we're still airborne, hand off to FALL (characters
	# with a fall sheet; others just hold the last jump frame -- no fall state).
	if _state == State.JUMP and not is_on_floor() and _has_fall():
		_enter(State.FALL)
		return
	# The land anim finished while still airborne (predicted too early / very slow fall):
	# drop back to the air state rather than snapping to idle in mid-air.
	if _state == State.LAND and not is_on_floor():
		_enter(_airborne_default())
		return
	# Light attack is a paused single frame; jump/fall loop or hold, so only dash, the
	# special swing, and the (grounded) landing end on playback finishing.
	if _state == State.DASH or _state == State.SPECIAL or _state == State.LAND or _state == State.SLAM:
		_enter(State.IDLE)
