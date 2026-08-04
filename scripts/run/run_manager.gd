class_name RunManager
extends Node2D

## The roguelite run driver + the level.tscn root. Builds each arena level from Levels data,
## drops in start enemies, refills an escalating WAVE every time the arena is cleared, awards
## lahm on kills, runs the exit-gate toll + reward pick, advances levels, and restarts the whole
## run on death. Also owns the player spawn, camera follow, and death/spawn flair. See
## docs/game-design.md and scripts/run/README.md.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const SPAWN_FX := preload("res://vfx/spawn/enemy_spawn.tscn")
const REWARDS_OFFERED := 3
## Fall below this (well under the floor) -> reposition to the level spawn (NOT a life loss).
const DEATH_Y := 320.0

## ── Which character you play (in-game switching is gone; pick here). ────────────────
const START_CHARACTER := "wayna"

# Camera follow (speed-adaptive) — carried over from the old switcher.
const CAM_FOLLOW_BASE := 0.002
const CAM_TIGHTEN_START := 600.0
const CAM_TIGHTEN_FULL := 1200.0
const CAM_TIGHT_K := 0.9
const CAM_ZOOM_NORMAL := Vector2(1.5, 1.5)
const CAM_ZOOM_DEATH := Vector2(2.25, 2.25)
const CAM_ZOOM_SPAWN := Vector2(2.25, 2.25)
const DEATH_HOLD := 0.7

@export var player_path: NodePath = ^"Player"

@onready var _player: Player = get_node_or_null(player_path) as Player
@onready var _camera: Camera2D = get_node_or_null("Camera2D") as Camera2D

var _level_index := 0
var _wave_index := 0        ## next wave to spawn on clear (past the last -> repeats the last)
var _alive := 0             ## enemies currently alive; hitting 0 spawns the next wave
var _transitioning := false ## true while the reward/level-change is mid-flight
var _content: Node2D        ## per-level nodes (platforms, gate, enemies); freed on level change
var _gate: ExitGate
var _bg: ColorRect
var _player_spawn := Vector2.ZERO

# death / camera flair state
var _dead_prev := false
var _death_hold := 0.0
var _spawning := false
var _cam_tween: Tween


func _ready() -> void:
	_add_glow()
	_build_bg()
	if _player != null:
		_player.set_character(START_CHARACTER)
	_build_level(0)
	if _player != null:
		_player.spawn()
	if _camera != null:
		Nodes.place_at(_camera, _player_spawn + Vector2(0, -30))


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	# Recolour the exit so the player can see at a glance whether they can afford it now.
	if _gate != null and is_instance_valid(_gate):
		_gate.reflect(_player.can_afford(_gate.cost))

	if _player.is_dead():
		_handle_death(delta)
		return
	if _player.get_state() == Player.State.SPAWN:
		_handle_spawn(delta)
		return
	if _player.global_position.y > DEATH_Y:  # fell off -> reposition, no life lost
		Nodes.place_at(_player, _player_spawn)
		if _camera != null:
			Nodes.place_at(_camera, _player_spawn + Vector2(0, -30))
		return
	if _spawning:
		_spawning = false
		_zoom_to(CAM_ZOOM_NORMAL, 0.4)
	_follow_camera(delta)


# --- level building ---------------------------------------------------------

func _build_level(index: int) -> void:
	_level_index = clampi(index, 0, Levels.count() - 1)
	_wave_index = 0
	_alive = 0
	_transitioning = false
	if _content != null and is_instance_valid(_content):
		_content.queue_free()
	_content = Node2D.new()
	add_child(_content)

	var lv := Levels.get_level(_level_index)
	_bg.color = lv["bg"]
	_player_spawn = lv["player_spawn"]

	for p in lv["platforms"]:
		_build_platform(p[0], p[1], p[2], 14.0)

	_gate = ExitGate.new()
	_gate.setup(lv["exit_cost"])
	_gate.position = lv["exit_pos"]
	_gate.touched.connect(_on_gate_touched)
	_content.add_child(_gate)

	_spawn_group(lv["start"], false)  # start enemies just exist -- no spawn puff

	if _player != null:
		Nodes.place_at(_player, _player_spawn)


func _build_platform(center_x: float, top_y: float, width: float, height: float) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Combat.L_WORLD
	body.collision_mask = 0
	body.position = Vector2(center_x, top_y)
	body.add_to_group("oneway_platform")
	var col := Shapes.make_box(Vector2(width, height), Vector2(0, height / 2.0))
	col.one_way_collision = true
	body.add_child(col)
	var vis := ColorRect.new()
	vis.color = Color(0.22, 0.23, 0.30)
	vis.position = Vector2(-width / 2.0, 0)
	vis.size = Vector2(width, height)
	body.add_child(vis)
	_content.add_child(body)


# --- spawning + waves -------------------------------------------------------

## Spawn a group of {kit, pos} specs. `with_fx` fires the materialize puff at each spot (waves
## use it; start enemies don't). Each enemy's death is tracked toward clearing the arena.
func _spawn_group(specs: Array, with_fx: bool) -> void:
	for spec: Dictionary in specs:
		var pos: Vector2 = spec["pos"]
		if with_fx:
			_spawn_fx(pos)
		var enemy := _spawn_enemy(spec["kit"], pos)
		if enemy != null:
			enemy.died.connect(_on_enemy_died)
			_alive += 1


func _spawn_enemy(kit: Dictionary, pos: Vector2) -> Enemy:
	var scene: PackedScene = load(kit["scene"]) if kit.has("scene") else ENEMY_SCENE
	var enemy: Enemy = scene.instantiate()
	for key in kit:
		if key in ["scene", "tier", "pos"]:
			continue
		if key == "id":
			enemy.enemy_id = kit[key]
		else:
			enemy.set(key, kit[key])
	enemy.position = pos  # before add_child so Enemy._ready anchors patrol on the real spot
	_content.add_child(enemy)
	return enemy


func _spawn_fx(pos: Vector2) -> void:
	var fx := SPAWN_FX.instantiate()
	_content.add_child(fx)
	Nodes.place_at(fx, pos)
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if is_instance_valid(fx):
			fx.queue_free())


## An enemy died: pay out its lahm and, once the arena is empty, refill the next wave.
func _on_enemy_died(lahm_value: float) -> void:
	if _player != null:
		_player.gain_life(lahm_value)
	_alive -= 1
	if _alive <= 0 and not _transitioning:
		_spawn_next_wave()


func _spawn_next_wave() -> void:
	var waves: Array = Levels.get_level(_level_index)["waves"]
	if waves.is_empty():
		return
	var wave: Array = waves[mini(_wave_index, waves.size() - 1)]  # past the last -> repeat it
	_wave_index += 1
	_spawn_group(wave, true)


# --- exit gate -> reward -> next level --------------------------------------

func _on_gate_touched() -> void:
	if _transitioning or _player == null:
		return
	if _player.can_afford(_gate.cost):
		_transitioning = true
		_player.spend_life(_gate.cost)
		_offer_reward()
	# else: not enough life -- the gate stays red; keep farming.


func _offer_reward() -> void:
	var ui := RewardUI.new()
	add_child(ui)
	ui.chosen.connect(_on_reward_chosen)
	ui.open(Rewards.offer(REWARDS_OFFERED))


func _on_reward_chosen(id: String) -> void:
	Rewards.apply(id, _player)
	if _level_index >= Levels.count() - 1:
		_restart_run()  # run complete -> loop back to level 1 (template; a win screen later)
	else:
		_build_level(_level_index + 1)  # carry life forward -- no reset


## Wipe the run and start over at level 1 (death or completion). Resets buffs + refills to
## 100 HP / 0 lahm via Player.begin_run.
func _restart_run() -> void:
	_dead_prev = false
	_build_level(0)
	if _player != null:
		_player.begin_run()


# --- death / spawn / camera flair (from the old switcher) --------------------

func _handle_death(delta: float) -> void:
	if not _dead_prev:
		_dead_prev = true
		_death_hold = DEATH_HOLD
		_zoom_to(CAM_ZOOM_DEATH, 0.45)
	if _camera != null:
		_camera.global_position = _camera.global_position.lerp(_player.global_position + Vector2(0, -18), 0.12)
	if _player.death_complete():
		_death_hold -= delta
		if _death_hold <= 0.0:
			_restart_run()  # DEATH = whole run over, start from scratch (roguelite)


func _handle_spawn(delta: float) -> void:
	if not _spawning:
		_spawning = true
		_zoom_to(CAM_ZOOM_SPAWN, 0.35)
	if _camera != null:
		_camera.global_position = _camera.global_position.lerp(_player.global_position + Vector2(0, -18), 0.12)


func _follow_camera(delta: float) -> void:
	if _camera == null:
		return
	var target := Vector2(_player.global_position.x, _player.global_position.y - 30.0) \
		+ _player.velocity * delta
	var vy := absf(_player.velocity.y)
	var t := clampf((vy - CAM_TIGHTEN_START) / (CAM_TIGHTEN_FULL - CAM_TIGHTEN_START), 0.0, 1.0)
	var k := lerpf(1.0 - pow(CAM_FOLLOW_BASE, delta), CAM_TIGHT_K, t)
	_camera.global_position = _camera.global_position.lerp(target, k)


func _zoom_to(z: Vector2, dur: float) -> void:
	if _camera == null:
		return
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	_cam_tween = _camera.create_tween()
	_cam_tween.tween_property(_camera, "zoom", z, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# --- scaffolding ------------------------------------------------------------

func _build_bg() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -100  # behind everything
	add_child(layer)
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_bg)


func _add_glow() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_respawn"):
		_build_level(_level_index)  # rebuild the current level fresh
		return
	if _player == null:
		return
	if event.is_action_pressed("debug_damage"):
		_player.take_damage(12.0)
	elif event.is_action_pressed("debug_heal"):
		_player.gain_life(20.0)
