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
## How long a single combo frame is held before dropping back to idle.
@export var attack_frame_time: float = 0.14
## Grace period after a hit in which another press continues the combo
## instead of restarting it.
@export var combo_reset_time: float = 0.6

enum State { IDLE, RUN, JUMP, DASH, ATTACK }

var _state: State = State.IDLE
var _facing: int = 1
var _dash_left: float = 0.0
var _dash_cd: float = 0.0
## Index of the attack frame currently being shown; 0 means "not combo-ing".
var _combo_step: int = 0
var _attack_left: float = 0.0
var _combo_window: float = 0.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	health = max_health
	_apply_character()
	if Engine.is_editor_hint():
		return
	_sprite.animation_finished.connect(_on_animation_finished)
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
	# Attack frame counts differ per character, so a half-finished combo would
	# point at a frame the new character may not have.
	_combo_step = 0
	_combo_window = 0.0
	sprite.speed_scale = 1.0
	sprite.play(_animation_for(_state))
	character_changed.emit(character)


## Path to the current character's portrait, for HUD / character-select art.
func portrait_path() -> String:
	return PORTRAIT_PATH % (character.substr(0, 1).to_upper() + character.substr(1))


func take_damage(amount: float) -> void:
	health -= amount


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

	if _state == State.DASH:
		_process_dash(delta)
	elif _state == State.ATTACK:
		_process_attack(delta)
	else:
		# The combo only decays while you're not mid-swing.
		_combo_window = maxf(_combo_window - delta, 0.0)
		_process_normal(delta)

	move_and_slide()
	_update_animation(delta)


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

	# Pressing again mid-swing chains straight into the next hit.
	if Input.is_action_just_pressed("attack"):
		_advance_combo()
		return

	_attack_left -= delta
	if _attack_left <= 0.0:
		_combo_window = combo_reset_time
		_enter(State.IDLE)


## One press = one attack frame. Consecutive presses walk through the frames;
## letting `combo_reset_time` lapse drops you back to the first hit.
func _advance_combo() -> void:
	var total := _sprite.sprite_frames.get_frame_count(&"attack")
	# Frame 0 is the neutral pose shared with idle (it would read as "nothing
	# happened"), so the actual hits are frames 1..total-1.
	var last_step := maxi(total - 1, 1)

	if _combo_window <= 0.0 or _combo_step >= last_step:
		_combo_step = 1  # cold start, or wrap after the finisher
	else:
		_combo_step += 1

	_attack_left = attack_frame_time
	_combo_window = combo_reset_time
	_enter(State.ATTACK)

	# Hold a single frame rather than letting the animation run.
	_sprite.speed_scale = 1.0
	_sprite.play(&"attack")
	_sprite.set_frame_and_progress(_combo_step, 0.0)
	_sprite.pause()


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


func _on_animation_finished() -> void:
	# Attack is a paused single frame and jump holds its last frame, so dash is
	# the only state that ends on playback finishing.
	if _state == State.DASH:
		_enter(State.IDLE)
