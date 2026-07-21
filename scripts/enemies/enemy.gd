class_name Enemy
extends CharacterBody2D

## Reusable ground enemy. Shares the character sprite pipeline (idle / stroll /
## melee_attack / range_attack) but each enemy only needs the animations it has:
## melee/ranged are enabled automatically from whichever attack animations exist
## in its SpriteFrames, so an enemy with just one attack works with no changes.
##
## Behaviour: patrol between its spawn point and spawn+patrol_distance, pausing
## to idle at each end; if the player comes within ranged_range it attacks
## (melee when very close, ranged otherwise). It carries its own hurtbox, melee
## hitbox, floating health bar and hit-flash. Bosses get their own scene/script
## instead of shoehorning extra move-sets in here.
##
## Everything visual/physical is built in code, so an enemy is just this script
## configured via exports (or subclassed) -- no scene to keep in sync.

const PROJECTILE := preload("res://scripts/enemies/projectile.gd")
const FRAMES_PATH := "res://resources/enemies/%s.tres"

@export var enemy_id: String = "kebus"
@export var display_name: String = "Kebus"

@export_group("Stats")
@export var max_health: float = 60.0
@export var gravity: float = 900.0

@export_group("Patrol")
@export var move_speed: float = 40.0
## How far it strolls from its spawn point before turning back.
@export var patrol_distance: float = 90.0
@export var idle_time_min: float = 2.0
@export var idle_time_max: float = 3.0

@export_group("Combat ranges")
## Player within this horizontal distance -> melee. Small = must be adjacent.
@export var melee_range: float = 30.0
## Player within this -> ranged attack (when melee doesn't apply).
@export var ranged_range: float = 300.0
@export var attack_cooldown: float = 1.1
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
## Where a projectile leaves the staff (forward, up), before facing mirror.
@export var muzzle_offset := Vector2(20, -46)
@export var projectile_speed: float = 260.0

@export_group("Behaviour")
## When true, chases the player (up to aggro_range) instead of only attacking
## whoever wanders into range. Off by default -- most mobs just guard a spot.
@export var aggro := false
@export var aggro_range: float = 480.0
## Damage dealt by simply touching the player (0 = off), applied on an interval.
@export var contact_damage: float = 0.0
@export var contact_knockback: float = 120.0
@export var contact_interval: float = 0.6

enum State { IDLE, STROLL, MELEE, RANGE, STUN, DEAD }

var health: float
var _state: State = State.IDLE
var _facing: int = -1  # enemies commonly face left toward a right-approaching player
var _has_melee := false
var _has_ranged := false
var _attack_cd := 0.0
var _attack_fired := false
var _point_a := 0.0
var _point_b := 0.0
var _patrol_target := 0.0
var _idle_timer := 0.0
var _stun_left := 0.0
var _contact_cd := 0.0
var _contact_hitbox: Hitbox

var _sprite: AnimatedSprite2D
var _hurtbox: Hurtbox
var _melee_hitbox: Hitbox
var _bar: FloatingHealthBar
var _status: StatusOverlay


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = Combat.L_ENEMY_BODY
	collision_mask = Combat.L_WORLD

	_build_sprite()
	_build_body()
	_build_hurtbox()
	_build_melee_hitbox()
	_build_contact_hitbox()
	_build_health_bar()

	_status = StatusOverlay.new()
	add_child(_status)
	_status.setup(_sprite)

	_has_melee = _sprite.sprite_frames.has_animation(&"melee_attack")
	_has_ranged = _sprite.sprite_frames.has_animation(&"range_attack")

	health = max_health
	_bar.set_ratio(1.0)

	_point_a = global_position.x
	_point_b = global_position.x + patrol_distance
	_patrol_target = _point_b

	_sprite.frame_changed.connect(_on_frame_changed)
	_sprite.animation_finished.connect(_on_anim_finished)
	_face(_facing)
	_play(&"stroll")


# --- construction -----------------------------------------------------------

func _build_sprite() -> void:
	_sprite = AnimatedSprite2D.new()
	var path := FRAMES_PATH % enemy_id
	if not ResourceLoader.exists(path):
		push_error("Enemy '%s': no SpriteFrames at %s" % [enemy_id, path])
		return
	_sprite.sprite_frames = load(path)
	var frame := _sprite.sprite_frames.get_frame_texture(&"idle", 0)
	if frame != null:
		_sprite.centered = false
		_sprite.offset = Vector2(-frame.get_width() / 2.0, -frame.get_height())
	add_child(_sprite)


func _build_body() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(18, 30)
	shape.shape = rect
	shape.position = Vector2(0, -15)
	add_child(shape)


func _build_hurtbox() -> void:
	_hurtbox = Hurtbox.new()
	_hurtbox.collision_layer = Combat.L_ENEMY_HURT
	_hurtbox.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 34)
	shape.shape = rect
	shape.position = Vector2(0, -17)
	_hurtbox.add_child(shape)
	add_child(_hurtbox)
	_hurtbox.hurt.connect(_on_hurt)


func _build_melee_hitbox() -> void:
	_melee_hitbox = Hitbox.new()
	_melee_hitbox.collision_layer = Combat.L_ENEMY_HIT
	_melee_hitbox.collision_mask = Combat.L_PLAYER_HURT
	_melee_hitbox.damage = melee_damage
	_melee_hitbox.source = self
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = melee_hitbox_extents * 2.0
	shape.shape = rect
	shape.position = Vector2(0, -melee_hitbox_extents.y)
	_melee_hitbox.knockback = melee_knockback
	_melee_hitbox.stun = melee_stun
	_melee_hitbox.add_child(shape)
	add_child(_melee_hitbox)


func _build_contact_hitbox() -> void:
	if contact_damage <= 0.0:
		return
	_contact_hitbox = Hitbox.new()
	_contact_hitbox.collision_layer = Combat.L_ENEMY_HIT
	_contact_hitbox.collision_mask = Combat.L_PLAYER_HURT
	_contact_hitbox.damage = contact_damage
	_contact_hitbox.knockback = contact_knockback
	_contact_hitbox.source = self
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(22, 34)
	shape.shape = rect
	shape.position = Vector2(0, -17)
	_contact_hitbox.add_child(shape)
	add_child(_contact_hitbox)


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

	_tick_contact(delta)
	move_and_slide()


func _tick_contact(delta: float) -> void:
	if _contact_hitbox == null:
		return
	_contact_cd = maxf(_contact_cd - delta, 0.0)
	if _contact_cd <= 0.0:
		_contact_hitbox.activate()  # re-arm; hits the player if still overlapping
		_contact_cd = contact_interval


func _act(delta: float) -> void:
	_attack_cd = maxf(_attack_cd - delta, 0.0)

	var player := _player()
	if player != null:
		var to_player := player.global_position.x - global_position.x
		var dist: float = absf(to_player)
		if _attack_cd <= 0.0:
			if _has_melee and dist <= melee_range:
				_start_attack(State.MELEE, &"melee_attack", player)
				return
			if _has_ranged and dist <= ranged_range:
				_start_attack(State.RANGE, &"range_attack", player)
				return
		# Aggro: pursue until close enough to attack. Otherwise just hold ground
		# and face the player when they're already in reach.
		if aggro and dist <= aggro_range:
			if dist > melee_range + 4.0:
				var dir := int(sign(to_player))
				velocity.x = dir * move_speed
				_face(dir)
				_set_state(State.STROLL)
			else:
				velocity.x = 0.0
				_face(int(sign(to_player)))
				_set_state(State.IDLE)
			return
		if dist <= ranged_range:
			velocity.x = 0.0
			_face(int(sign(to_player)))
			_set_state(State.IDLE)
			return

	_patrol(delta)


func _patrol(delta: float) -> void:
	if _idle_timer > 0.0:
		_idle_timer -= delta
		velocity.x = 0.0
		_set_state(State.IDLE)
		if _idle_timer <= 0.0:
			# Turn around: aim for the other end of the patrol.
			_patrol_target = _point_a if is_equal_approx(_patrol_target, _point_b) else _point_b
		return

	if absf(_patrol_target - global_position.x) <= 2.0:
		velocity.x = 0.0
		_idle_timer = randf_range(idle_time_min, idle_time_max)
		_set_state(State.IDLE)
		return

	var dir := int(sign(_patrol_target - global_position.x))
	velocity.x = dir * move_speed
	_face(dir)
	_set_state(State.STROLL)


# --- attacks ----------------------------------------------------------------

func _start_attack(state: State, anim: StringName, player: Node2D) -> void:
	_set_state(state)
	velocity.x = 0.0
	_attack_fired = false
	_face(int(sign(player.global_position.x - global_position.x)))
	_play(anim)


func _on_frame_changed() -> void:
	if _state == State.MELEE and _sprite.frame in _hit_frames(&"melee_attack"):
		_position_melee_hitbox()
		_melee_hitbox.activate()
	elif _state == State.RANGE and not _attack_fired and _sprite.frame >= _fire_frame():
		_attack_fired = true
		_fire_projectile()


func _on_anim_finished() -> void:
	if _state == State.MELEE or _state == State.RANGE:
		_melee_hitbox.deactivate()
		_attack_cd = attack_cooldown
		_set_state(State.IDLE)


func _position_melee_hitbox() -> void:
	_melee_hitbox.position.x = melee_hitbox_x * _facing


func _fire_projectile() -> void:
	var muzzle := global_position + Vector2(muzzle_offset.x * _facing, muzzle_offset.y)
	# Aim at the player's torso so a high staff still connects with a short body;
	# fall back to straight ahead if the player vanished mid-cast.
	var player := _player()
	var target := (player.global_position + Vector2(0, -15)) if player != null \
		else muzzle + Vector2(_facing, 0)
	var proj := Area2D.new()
	proj.set_script(PROJECTILE)
	proj.damage = ranged_damage
	proj.knockback = ranged_knockback
	proj.stun = ranged_stun
	proj.velocity = (target - muzzle).normalized() * projectile_speed
	# Live in the level, not under the enemy, so it keeps flying if the enemy dies.
	get_parent().add_child(proj)
	proj.global_position = muzzle


func _fire_frame() -> int:
	# Fire near the middle of the ranged animation (staff thrust).
	return maxi(1, _sprite.sprite_frames.get_frame_count(&"range_attack") / 2)


func _hit_frames(anim: StringName) -> Array:
	var frames := _sprite.sprite_frames
	if frames.has_meta("hit_frames"):
		var by_anim: Dictionary = frames.get_meta("hit_frames")
		if by_anim.has(String(anim)):
			return by_anim[String(anim)]
	return []


# --- damage / death ---------------------------------------------------------

func _on_hurt(hit: Hit) -> void:
	if _state == State.DEAD:
		return
	health = maxf(health - hit.amount, 0.0)
	_bar.set_ratio(health / max_health)
	_flash()
	if health <= 0.0:
		_die()
		return
	if hit.knockback > 0.0 and hit.source != null:
		var dir := signi(int(sign(global_position.x - (hit.source as Node2D).global_position.x)))
		if dir == 0:
			dir = -_facing
		velocity.x = dir * hit.knockback
		velocity.y = -hit.knockback * 0.25  # a small pop so it reads
	# A knockback needs a brief stagger, or the AI overwrites the shove velocity
	# next frame and nothing moves. Pure stun freezes for longer.
	var stagger := hit.stun
	if hit.knockback > 0.0:
		stagger = maxf(stagger, 0.2)
	if stagger > 0.0:
		_melee_hitbox.deactivate()
		_stun_left = stagger
		_set_state(State.STUN)
		# A tagged freeze holds the current pose (not idle) + shows the overlay.
		if hit.status_color.a > 0.0:
			_sprite.pause()
			_status.show_for(hit.status_color, hit.status_time)


func _flash() -> void:
	_sprite.modulate = Color(1.0, 0.35, 0.35)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color.WHITE, 0.18)


func _die() -> void:
	_set_state(State.DEAD)
	_hurtbox.set_deferred("monitorable", false)
	_melee_hitbox.deactivate()
	set_deferred("collision_layer", 0)
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)


# --- helpers ----------------------------------------------------------------

func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


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
		State.IDLE, State.STUN: _play(&"idle")
		State.STROLL: _play(&"stroll")


func _play(anim: StringName) -> void:
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)
