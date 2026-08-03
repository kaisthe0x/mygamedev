extends Node2D

## Dev helper: cycle the player through characters, fake damage/heal, and spawn
## enemies. Spawning happens in code so the level scene stays untouched (the
## editor keeps clobbering it); move enemies into the level scene proper when
## ready. Press debug_respawn (0) to bring a killed enemy back and keep fighting.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

# --- Camera follow (TEMPORARY: speed-adaptive experiment) -------------------------
## Loose/cinematic smoothing base at rest (lower = snappier). Frame-rate independent.
const CAM_FOLLOW_BASE := 0.002
## Below this vertical speed (px/s) the camera stays fully loose.
const CAM_TIGHTEN_START := 600.0
## At/above this vertical speed the camera is fully tight (≈ slam_speed, so a slam
## keeps the character centred). Ramps linearly between START and FULL.
const CAM_TIGHTEN_FULL := 1200.0
## The near-snap lerp weight the follow reaches at full tightness (1.0 = hard snap).
const CAM_TIGHT_K := 0.9
## Death flair: zoom (Camera2D.zoom -- bigger = more zoomed IN) at rest vs punched in on
## death so the death animation reads, and how long the corpse holds (zoomed) after the
## animation finishes before we respawn.
const CAM_ZOOM_NORMAL := Vector2(1.5, 1.5)
const CAM_ZOOM_DEATH := Vector2(2.25, 2.25)
const DEATH_HOLD := 0.7
## Spawn flair: zoom in on the character while the spawn (materialize) animation plays,
## then pull back to CAM_ZOOM_NORMAL the moment it finishes. Same value as the death punch-
## in so a death -> respawn -> spawn stays smoothly zoomed the whole way through.
const CAM_ZOOM_SPAWN := Vector2(2.25, 2.25)
# ---------------------------------------------------------------------------------

## ── WHICH CHARACTER YOU PLAY ──────────────────────────────────────────────────────
## The game spawns this one character. Change this string to play a different one; valid
## ids are in CharacterConfig.IDS ("feyke", "katalyst", "khalid", "lenbondosen", "wayna").
## (In-game Q/E switching is gone -- pick here in code.)
const START_CHARACTER := "khalid"
# ──────────────────────────────────────────────────────────────────────────────────

@export var player_path: NodePath = ^"Player"
@export var spawn_enemies := true

## Player start, fall-death line, platform layout, and the enemy roster all live in
## LevelConfig (configs/level_config.gd).

@onready var _player: Player = get_node_or_null(player_path) as Player
@onready var _camera: Camera2D = get_node_or_null("Camera2D") as Camera2D

var _dead_prev := false ## edge-detect the death so the zoom-in fires once
var _death_hold := 0.0 ## time the finished death pose holds (zoomed) before respawn
var _spawning := false ## true while the spawn anim plays -- camera zoomed in until it ends
var _cam_tween: Tween


func _ready() -> void:
	_add_glow()
	_build_platforms()
	if _player != null:
		_player.set_character(START_CHARACTER)
		Nodes.place_at(_player, LevelConfig.SPAWN)
		if _camera != null:
			Nodes.place_at(_camera, LevelConfig.SPAWN + Vector2(0, -30)) # start framed on spawn
		_player.spawn() # play the materialize animation on the initial spawn too
	if spawn_enemies:
		_spawn_all()


## Follow + respawn run in physics so, with physics interpolation on, the camera
## tracks at the same rhythm as the player and both render smoothly between the
## 60Hz physics ticks (the fix for stutter/blur on high-refresh monitors).
func _physics_process(delta: float) -> void:
	if _player == null:
		return
	# Died (HP hit 0): let the death animation play out, zoomed in, THEN respawn.
	if _player.is_dead():
		_handle_death(delta)
		return
	# Spawning (initial + every respawn): stay zoomed in on the materialize animation.
	if _player.get_state() == Player.State.SPAWN:
		_handle_spawn(delta)
		return
	# Fell into the void (alive) -> instant reset at the safe start, no death anim.
	if _player.global_position.y > LevelConfig.DEATH_Y:
		_respawn_player()
		return
	# Spawn just finished (any non-spawn state) -> pull the camera back out to normal, once.
	if _spawning:
		_spawning = false
		_zoom_to(CAM_ZOOM_NORMAL, 0.4)
	# Follow the player so you can traverse across the platforms. Speed-adaptive: loose
	# and cinematic normally, but tightens toward a near-snap as vertical speed rises,
	# so a fast fall / slam (~slam_speed) stays centred instead of trailing far behind.
	if _camera != null:
		# Aim where the player WILL be after its move this frame (we run before it),
		# so a fast slam doesn't sit a constant frame behind.
		var target := Vector2(_player.global_position.x, _player.global_position.y - 30.0) \
			+ _player.velocity * delta
		var vy := absf(_player.velocity.y)
		var t := clampf((vy - CAM_TIGHTEN_START) / (CAM_TIGHTEN_FULL - CAM_TIGHTEN_START), 0.0, 1.0)
		var k := lerpf(1.0 - pow(CAM_FOLLOW_BASE, delta), CAM_TIGHT_K, t)
		_camera.global_position = _camera.global_position.lerp(target, k)


## Death flair: on the first frame of death, punch the camera in and start the hold; keep
## the camera centred on the collapsing character; once the animation has fully played and
## the hold elapses, respawn. Enemies already ignore a dead player (Enemy._player), so the
## kill zone goes quiet while this plays.
func _handle_death(delta: float) -> void:
	if not _dead_prev:
		_dead_prev = true
		_death_hold = DEATH_HOLD
		_zoom_to(CAM_ZOOM_DEATH, 0.45)
	if _camera != null:
		var target := _player.global_position + Vector2(0, -18)
		_camera.global_position = _camera.global_position.lerp(target, 0.12)
	if _player.death_complete():
		_death_hold -= delta
		if _death_hold <= 0.0:
			_respawn_player()


## Spawn flair: punch the camera in on the first frame of the spawn and keep it centred on
## the materializing character. The zoom-OUT fires from _physics_process the moment the
## player leaves the SPAWN state (spawn anim done). A death -> respawn -> spawn stays zoomed
## the whole way (CAM_ZOOM_SPAWN == CAM_ZOOM_DEATH), then pulls out here.
func _handle_spawn(delta: float) -> void:
	if not _spawning:
		_spawning = true
		_zoom_to(CAM_ZOOM_SPAWN, 0.35)
	if _camera != null:
		var target := _player.global_position + Vector2(0, -18)
		_camera.global_position = _camera.global_position.lerp(target, 0.12)


## Tween the camera zoom to `z` over `dur`, cancelling any in-flight zoom tween.
func _zoom_to(z: Vector2, dur: float) -> void:
	if _camera == null:
		return
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	_cam_tween = _camera.create_tween()
	_cam_tween.tween_property(_camera, "zoom", z, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Reset the player to the safe start, full health, and clear any bolts still in
## the air so you aren't hit the instant you reappear. Also zooms back out (undoing the
## death punch-in) and clears the death edge so the next death re-triggers the flair.
func _respawn_player() -> void:
	_player.revive() # full health, hurtbox back on -> SPAWN (materialize) or idle (undoes _die)
	_dead_prev = false
	Nodes.place_at(_player, LevelConfig.SPAWN)
	for proj in get_tree().get_nodes_in_group("projectiles"):
		proj.queue_free()
	# The spawn animation (if any) keeps us zoomed and pulls out when it ends. A character
	# with no spawn sheet skips straight to idle, so pull the camera back out here instead.
	if _player.get_state() != Player.State.SPAWN:
		_spawning = false
		_zoom_to(CAM_ZOOM_NORMAL, 0.3)
	if _camera != null:
		Nodes.place_at(_camera, LevelConfig.SPAWN + Vector2(0, -30))


## A subtle additive glow so bright HDR effects bloom, and little
## else -- the threshold sits at 1.0, above where the LDR pixel-art sprites live.
## Tune intensity/bloom/threshold here, or delete this to drop the bloom entirely.
func _add_glow() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 1.0 # only pixels brighter than 1.0 (HDR) bloom
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _build_platforms() -> void:
	for p in LevelConfig.PLATFORMS:
		_build_platform(p[0], p[1], p[2], 14.0)


func _build_platform(center_x: float, top_y: float, width: float, height: float) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Combat.L_WORLD
	body.collision_mask = 0
	body.position = Vector2(center_x, top_y)
	body.add_to_group("oneway_platform") # so the player can drop through it (down+jump)

	var col := Shapes.make_box(Vector2(width, height), Vector2(0, height / 2.0)) # top sits at top_y
	col.one_way_collision = true # jump up through it, land on top
	body.add_child(col)

	var vis := ColorRect.new()
	vis.color = Color(0.22, 0.23, 0.30)
	vis.position = Vector2(-width / 2.0, 0)
	vis.size = Vector2(width, height)
	body.add_child(vis)

	add_child(body)


func _spawn_all() -> void:
	for entry in LevelConfig.roster():
		_spawn_enemy(entry)


func _spawn_enemy(entry: Dictionary) -> void:
	# `scene` picks a custom enemy scene/script (e.g. res://scenes/nasen.tscn); default is
	# the generic enemy.tscn. Its own exports (enemy_id, etc.) stand unless the entry overrides.
	var scene: PackedScene = load(entry["scene"]) if entry.has("scene") else ENEMY_SCENE
	var enemy: Enemy = scene.instantiate()
	# Apply every key except the spawner-only ones as an Enemy export.
	for key in entry:
		if key in ["pos", "name", "scene"]:
			continue
		if key == "id":
			enemy.enemy_id = entry[key]
		else:
			enemy.set(key, entry[key])
	enemy.display_name = entry.get("name", entry.get("id", enemy.display_name))
	# Position BEFORE add_child so Enemy._ready() anchors its patrol on the real
	# spawn point (the level sits at the origin, so local == global here).
	enemy.position = entry.get("pos", Vector2.ZERO)
	add_child(enemy)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_respawn"):
		# Clear any survivors, then respawn the full roster fresh.
		for e in get_tree().get_nodes_in_group("enemies"):
			e.queue_free()
		_spawn_all()
		return
	if _player == null:
		return
	# Q/E character switching is intentionally gone -- the played character is chosen in
	# code via START_CHARACTER (top of this file). Debug damage/heal stay.
	if event.is_action_pressed("debug_damage"):
		_player.take_damage(12.0)
	elif event.is_action_pressed("debug_heal"):
		_player.heal(20.0)
