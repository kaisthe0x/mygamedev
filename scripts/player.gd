@tool
extends CharacterBody2D
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

const CHARACTERS: PackedStringArray = [
	"feyke", "katalyst", "khalid", "lenbondosen", "wayna",
]
const FRAMES_PATH := "res://resources/characters/%s.tres"
## Portrait files are capitalised while character ids are lower case.
const PORTRAIT_PATH := "res://assets/portraits/%s.png"
## Optional per-character ability script; missing file means no ability.
const ABILITY_PATH := "res://scripts/abilities/%s.gd"

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
@export var run_speed: float = 160.0
@export var acceleration: float = 1200.0
@export var friction: float = 1400.0
@export var jump_velocity: float = -330.0
@export var gravity: float = 900.0
## Falling faster than rising makes the arc feel less floaty.
@export var fall_gravity_scale: float = 1.35

@export_group("Dash")
@export var dash_speed: float = 420.0
@export var dash_time: float = 0.18
@export var dash_cooldown: float = 0.45
## Gravity kept during an air dash. 0 hangs in place, 1 falls normally.
@export_range(0.0, 1.0) var dash_gravity_scale: float = 0.35

@export_group("Juice")
## How far the sprite leans forward at full falling speed, in degrees.
@export var fall_tilt_degrees: float = 8.0
## Falling speed at which the lean reaches its maximum.
@export var fall_tilt_at_speed: float = 600.0

@export_group("Attack")
## How long the sprite holds on a hit frame before returning to idle, if the
## combo isn't continued. Short -- just enough to read the hit.
@export var attack_recovery: float = 0.12
## Grace period after a hit lands in which another press continues the combo
## instead of restarting it. Ticks on through idle, so you can chain after
## control returns; keep it >= attack_recovery.
@export var combo_reset_time: float = 0.45
## Damage a single light-attack hit deals; the heavy swing deals heavy_damage.
@export var attack_damage: float = 9.0
@export var heavy_damage: float = 22.0
## How far in front of the feet the attack reaches, and its half-size.
@export var attack_hitbox_x: float = 18.0
@export var attack_hitbox_extents := Vector2(15, 18)

enum State { IDLE, RUN, JUMP, DASH, ATTACK, HEAVY_ATTACK }

var _state: State = State.IDLE
var _facing: int = 1
var _dash_left: float = 0.0
var _dash_cd: float = 0.0
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
## Time left frozen from a stun-carrying hit (input ignored).
var _stun_left: float = 0.0
## The current character's unique ability, or null if they have none.
var _ability: CharacterAbility
## Drives frame-indexed 2D particle effects; created at runtime (not in editor).
var _particles: ParticleDirector
## Combat boxes, built in code (like the particle director) to avoid a scene edit.
var _hurtbox: Hurtbox
var _attack_hitbox: Hitbox
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
	var path := FRAMES_PATH % character
	if not ResourceLoader.exists(path):
		push_warning("No SpriteFrames for character '%s' at %s" % [character, path])
		return
	sprite.sprite_frames = load(path)
	# The generator's canvas size changes whenever the art does, so derive the
	# offset from the frames rather than baking it into the scene: origin at the
	# feet, horizontally centred.
	var frame := sprite.sprite_frames.get_frame_texture(&"idle", 0)
	if frame != null:
		sprite.centered = false
		sprite.offset = Vector2(-frame.get_width() / 2.0, -frame.get_height())
	# Attack frame counts differ per character, so a half-finished combo would
	# point at a frame the new character may not have.
	_combo_step = 0
	_combo_window = 0.0
	_combo_playing = false
	sprite.speed_scale = 1.0
	sprite.play(_animation_for(_state))
	_equip_ability()
	if _particles != null:  # null during the initial _ready pass; set up just after
		_particles.set_character(character)
	character_changed.emit(character)


## Swap in the ability script named after this character, if one exists.
func _equip_ability() -> void:
	_ability = null
	if Engine.is_editor_hint():
		return
	var path := ABILITY_PATH % character
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


## Path to the current character's portrait, for HUD / character-select art.
func portrait_path() -> String:
	return PORTRAIT_PATH % (character.substr(0, 1).to_upper() + character.substr(1))


func take_damage(amount: float) -> void:
	health -= amount
	_flash()


## Build the combat boxes and register on the "player" group so enemies find us.
func _build_combat() -> void:
	add_to_group("player")
	collision_layer = Combat.L_PLAYER_BODY
	collision_mask = Combat.L_WORLD

	_hurtbox = Hurtbox.new()
	_hurtbox.collision_layer = Combat.L_PLAYER_HURT
	_hurtbox.collision_mask = 0
	_hurtbox.add_child(_box_shape(Vector2(16, 30), Vector2(0, -15)))
	add_child(_hurtbox)
	_hurtbox.hurt.connect(_on_hurt)

	_attack_hitbox = Hitbox.new()
	_attack_hitbox.collision_layer = Combat.L_PLAYER_HIT
	_attack_hitbox.collision_mask = Combat.L_ENEMY_HURT
	_attack_hitbox.source = self  # so knockback pushes enemies away from the player
	_attack_hitbox.add_child(_box_shape(attack_hitbox_extents * 2.0,
		Vector2(0, -attack_hitbox_extents.y)))
	add_child(_attack_hitbox)

	_status = StatusOverlay.new()
	add_child(_status)
	_status.setup(_sprite)


func _box_shape(size: Vector2, pos: Vector2) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = pos
	return shape


const STATUS_GREEN := Color(0.2, 1.0, 0.35, 1.0)

## Per-character on-hit effects. Each effect is a dict; unset keys default to 0:
##   damage, knockback (px/s), stun (s), color (engulfing overlay), color_time (s)
## `heavy` is one effect. `light` is EITHER one effect (all combo hits share it)
## OR an ARRAY of effects, one per combo segment -- so a specific hit can be
## special. Characters/attacks not listed fall back to the exported damage.
##
## Tune everything here: e.g. Lenny's heavy launches further than Feyke's, and
## Lenny's FIRST light hit freezes the enemy for 5s with a green overlay.
const ATTACK_EFFECTS := {
	"khalid": {"light": {"damage": 9}, "heavy": {"damage": 26, "knockback": 220}},
	"katalyst": {"light": {"damage": 9}, "heavy": {"damage": 24, "knockback": 160, "stun": 0.18}},
	"wayna": {"light": {"damage": 7, "stun": 0.1}, "heavy": {"damage": 18, "knockback": 90}},
	"feyke": {"light": {"damage": 8, "knockback": 45}, "heavy": {"damage": 20, "knockback": 150}},
	"lenbondosen": {
		"light": [
			{"damage": 8, "stun": 5.0, "color": STATUS_GREEN},  # 1st hit: 5s freeze + green
			{"damage": 8},
			{"damage": 8},
		],
		"heavy": {"damage": 22, "knockback": 300},  # launches much further than Feyke's 150
	},
}


## Effect dict for an attack. `seg` picks the combo segment for a per-segment
## `light` list; ignored otherwise.
func _attack_effect(kind: String, seg: int) -> Dictionary:
	var entry: Variant = ATTACK_EFFECTS.get(character, {}).get(kind, null)
	if entry is Array:
		if entry.is_empty():
			entry = {}
		else:
			entry = entry[mini(seg, entry.size() - 1)]
	if entry == null:
		entry = {"damage": attack_damage if kind == "light" else heavy_damage}
	return entry


## Enable the attack hitbox in front for one strike, carrying its effects.
func _strike(kind: String, seg: int = 0) -> void:
	if _attack_hitbox == null:
		return
	var e := _attack_effect(kind, seg)
	_attack_hitbox.damage = e.get("damage", attack_damage if kind == "light" else heavy_damage)
	_attack_hitbox.knockback = e.get("knockback", 0.0)
	_attack_hitbox.stun = e.get("stun", 0.0)
	_attack_hitbox.status_color = e.get("color", Color(0, 0, 0, 0))
	_attack_hitbox.status_time = e.get("color_time", e.get("stun", 0.0))
	_attack_hitbox.position.x = attack_hitbox_x * _facing
	_attack_hitbox.activate(0.12)


## Take a hit: damage, optional shove, optional freeze/overlay.
## A dash grants i-frames (the hurtbox is off), so this only fires when vulnerable.
func _on_hurt(hit: Hit) -> void:
	take_damage(hit.amount)
	if hit.knockback > 0.0 and hit.source != null:
		var dir := signi(int(sign(global_position.x - (hit.source as Node2D).global_position.x)))
		if dir == 0:
			dir = -_facing
		velocity.x = dir * hit.knockback
		velocity.y = -hit.knockback * 0.25
	# Knockback carries a brief stagger so the shove reads before control returns.
	var stagger := hit.stun
	if hit.knockback > 0.0:
		stagger = maxf(stagger, 0.18)
	if stagger > 0.0:
		_stun_left = stagger
		_combo_playing = false
		_state = State.IDLE
	if hit.status_color.a > 0.0:
		_status.show_for(hit.status_color, hit.status_time)


func _flash() -> void:
	_sprite.modulate = Color(1.0, 0.5, 0.5)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color.WHITE, 0.15)


# The heavy swing has no per-frame combo data, so land it on its middle frame.
func _on_frame_changed() -> void:
	if _state != State.HEAVY_ATTACK:
		return
	var mid := _sprite.sprite_frames.get_frame_count(&"heavy_attack") / 2
	if _sprite.frame == mid:
		_strike("heavy")


func heal(amount: float) -> void:
	health += amount


func is_alive() -> bool:
	return health > 0.0


func set_character(id: String) -> void:
	if id in CHARACTERS:
		character = id


func cycle_character(step: int = 1) -> void:
	var i := CHARACTERS.find(character)
	set_character(CHARACTERS[wrapi(i + step, 0, CHARACTERS.size())])


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_dash_cd = maxf(_dash_cd - delta, 0.0)

	if _stun_left > 0.0:
		_process_stun(delta)
	elif _state == State.DASH:
		_process_dash(delta)
	elif _state == State.ATTACK:
		_process_attack(delta)
	elif _state == State.HEAVY_ATTACK:
		_process_heavy_attack(delta)
	else:
		# The combo only decays while you're not mid-swing.
		_combo_window = maxf(_combo_window - delta, 0.0)
		_process_normal(delta)

	# Runs after the state machine has set this frame's velocity but before it is
	# applied, so an ability can override any of it.
	if _ability != null:
		_ability.physics(self, delta)

	# Dash grants invulnerability: hitboxes/projectiles can't detect the hurtbox.
	if _hurtbox != null:
		_hurtbox.monitorable = _state != State.DASH

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
	_dash_left -= delta
	velocity.x = dash_speed * _facing
	if is_on_floor():
		velocity.y = 0.0
	else:
		# Keep falling through an air dash, just lighter, so it arcs instead of
		# hanging in place on an invisible floor.
		velocity.y += gravity * dash_gravity_scale * delta
	if _dash_left <= 0.0:
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
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if Input.is_action_just_pressed("heavy_attack"):
		# A heavy swing supersedes any light chain in progress.
		_combo_step = 0
		_combo_window = 0.0
		_combo_playing = false
		_enter(State.HEAVY_ATTACK)
		return
	if Input.is_action_just_pressed("attack"):
		_advance_combo()
		return
	if Input.is_action_just_pressed("dash") and _dash_cd <= 0.0:
		_enter(State.DASH)
		return
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	if not is_on_floor():
		_state = State.JUMP
	elif absf(velocity.x) > 5.0:
		_state = State.RUN
	else:
		_state = State.IDLE


func _process_attack(delta: float) -> void:
	# Rooted in place, but gravity still applies so air attacks fall.
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	if not is_on_floor():
		velocity.y += gravity * delta

	if _combo_playing:
		# Animate through the segment; freeze on the hit frame once reached.
		# Pin in case playback overshot the hit between physics ticks.
		if _sprite.frame >= _seg_end:
			_sprite.set_frame_and_progress(_seg_end, 0.0)
			_sprite.pause()
			_combo_playing = false
			_recovery_left = attack_recovery
			_combo_window = combo_reset_time
			_strike("light", _combo_step - 1)  # this segment connects (0-based)
		return

	# Briefly hold the hit frame, then hand control back to idle. The chain
	# window keeps ticking there (see _physics_process), so you can still combo
	# after recovering -- the freeze doesn't have to outlast the whole window.
	if Input.is_action_just_pressed("attack"):
		_advance_combo()
		return
	_combo_window = maxf(_combo_window - delta, 0.0)
	_recovery_left -= delta
	if _recovery_left <= 0.0:
		_enter(State.IDLE)


## Unlike the light combo, a heavy swing is committed: it plays the whole
## animation, ignores input, and ends via _on_animation_finished().
func _process_heavy_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	if not is_on_floor():
		velocity.y += gravity * delta


## One press = one combo segment: play the frames up to the next hit, then hold
## there. Each hit frame is a segment boundary (see the generator's HIT_FRAMES).
## Letting `combo_reset_time` lapse drops you back to the first segment; pressing
## past the finisher wraps to the start.
func _advance_combo() -> void:
	var hits := _attack_hits()
	if hits.is_empty():
		return

	if _combo_window <= 0.0 or _combo_step >= hits.size():
		_combo_step = 0  # cold start, or wrap after the finisher
	var seg_start := 0 if _combo_step == 0 else int(hits[_combo_step - 1]) + 1
	_seg_end = int(hits[_combo_step])
	_combo_step += 1

	_combo_window = combo_reset_time
	_combo_playing = true
	_enter(State.ATTACK)
	_sprite.speed_scale = 1.0
	_sprite.play(&"attack")
	_sprite.set_frame_and_progress(seg_start, 0.0)


## Emitted frame indices that end each combo segment. From the SpriteFrames
## `hit_frames` metadata (written by the generator); falls back to every frame.
func _attack_hits() -> Array:
	var frames := _sprite.sprite_frames
	if frames.has_meta("hit_frames"):
		var by_anim: Dictionary = frames.get_meta("hit_frames")
		if by_anim.has("attack"):
			return by_anim["attack"]
	return range(frames.get_frame_count(&"attack"))


func _enter(state: State) -> void:
	_state = state
	_sprite.speed_scale = 1.0
	match state:
		State.DASH:
			_dash_left = dash_time
			_dash_cd = dash_cooldown
			# Frame counts differ per character (4-6), so a fixed dash_time
			# would clip the longer ones. Stretch playback to fit instead, which
			# keeps the dash distance identical for everyone.
			var frames := _sprite.sprite_frames
			var fps := frames.get_animation_speed(&"dash")
			if fps > 0.0 and dash_time > 0.0:
				var anim_time := frames.get_frame_count(&"dash") / fps
				_sprite.speed_scale = anim_time / dash_time
		State.ATTACK:
			velocity.x = 0.0


func _animation_for(state: State) -> StringName:
	match state:
		State.RUN: return &"run"
		State.JUMP: return &"jump"
		State.DASH: return &"dash"
		State.ATTACK: return &"attack"
		State.HEAVY_ATTACK: return &"heavy_attack"
		_: return &"idle"


func _update_animation(delta: float) -> void:
	_sprite.flip_h = _facing < 0
	var next := _animation_for(_state)
	if _sprite.animation != next:
		_sprite.play(next)

	# Lean into the fall, scaled by how fast you're dropping. Rotation is around
	# the node origin, which sits at the feet.
	var tilt := 0.0
	if not is_on_floor() and velocity.y > 0.0:
		var amount := minf(velocity.y / fall_tilt_at_speed, 1.0)
		tilt = deg_to_rad(fall_tilt_degrees) * amount * _facing
	_sprite.rotation = move_toward(_sprite.rotation, tilt, TAU * delta)


## A looping animation can have an intro: `loop_from` metadata (written by the
## generator) marks the frame the cycle restarts at, so the lead-in plays once
## and only the tail repeats. Wayna's run ignites over frames 0-3 then cycles 4-6.
func _on_animation_looped() -> void:
	var frames := _sprite.sprite_frames
	if frames == null or not frames.has_meta("loop_from"):
		return
	var start: int = frames.get_meta("loop_from").get(String(_sprite.animation), 0)
	if start > 0:
		_sprite.set_frame_and_progress(start, 0.0)


func _on_animation_finished() -> void:
	# Light attack is a paused single frame and jump holds its last frame, so
	# only dash and the heavy swing end on playback finishing.
	if _state == State.DASH or _state == State.HEAVY_ATTACK:
		_enter(State.IDLE)
