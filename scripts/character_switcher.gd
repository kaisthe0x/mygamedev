extends Node2D

## Dev helper: cycle the player through characters, fake damage/heal, and spawn
## enemies. Spawning happens in code so the level scene stays untouched (the
## editor keeps clobbering it); move enemies into the level scene proper when
## ready. Press debug_respawn (0) to bring a killed enemy back and keep fighting.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

@export var player_path: NodePath = ^"Player"
@export var spawn_enemies := true

## Player start. Kept well left of every enemy (nearest is ~400px away, beyond
## ranged_range) so you spawn in the clear, watch them stroll, then approach.
## Also the respawn point when you fall or die.
const SPAWN := Vector2(-450, 0)
## Fall below this (far under the ground) and you respawn instead of dropping
## forever.
const DEATH_Y := 300.0

## Jump-up platforms [center_x, top_y, width]. A rising staircase where each step
## is within one jump of the one below (jump peak ~60px), so you can hop up:
## ground -> P1 -> P2 -> P3. One-way, so you jump up through and land on top.
var _platforms := [
	[-40.0, -44.0, 160.0],   # P1
	[130.0, -80.0, 160.0],   # P2 (overlaps P1 -> forgiving hop up)
	[300.0, -114.0, 150.0],  # P3 (overlaps P2)
]

## Each entry: { id, name, pos, and any Enemy export to override }. Overrides are
## per-instance, so aggro / contact_damage / stats differ per enemy. (In a real
## level you'd instead drop enemy.tscn in and set these in the inspector.)
## Spread out and far from spawn: enemies stroll until you come to them.
var _roster := [
	{"id": "kebus", "name": "Kebus", "pos": Vector2(150, 0)},      # ground stroller
	{"id": "kebus", "name": "Kebus", "pos": Vector2(-40, -44)},    # on P1
	{"id": "kebus", "name": "Kebus", "pos": Vector2(130, -80)},    # on P2
	{"id": "kebus", "name": "Kebus", "pos": Vector2(300, -114)},   # on P3
	# Baghel: ranged-only, short-range ground surge, scratches his back at rest.
	{
		"id": "baghel", "name": "Baghel", "pos": Vector2(470, 0),
		"ranged_mode": "forward", "ranged_range": 130.0, "ranged_travel": 100.0,
		"projectile_speed": 200.0,
		"ranged_particle": "res://particles/enemies/baghel/ground_wave.tscn",
		"ranged_hitbox_extents": Vector2(4, 15), "ranged_hitbox_offset": Vector2(0, -9),
		"muzzle_offset": Vector2(16, 1), "ranged_damage": 7.0,  # y~ground so the wave touches it
		"idle_loop_from": 1, "idle_loop_to": 3, "idle_loop_time": 2.0,
		"idle_time_min": 5.0, "idle_time_max": 7.0,  # long rests so he lingers, scratching
	},
]

@onready var _player: Player = get_node_or_null(player_path) as Player
@onready var _camera: Camera2D = get_node_or_null("Camera2D") as Camera2D


func _ready() -> void:
	_build_platforms()
	if _player != null:
		# Katalyst is the newest redesign -- start on him for testing. Q/E still
		# cycle to the others (older art) if you want to compare.
		_player.set_character("katalyst")
		_place(_player, SPAWN)
		if _camera != null:
			_place(_camera, SPAWN + Vector2(0, -30))  # start framed on spawn
	if spawn_enemies:
		_spawn_all()


## Follow + respawn run in physics so, with physics interpolation on, the camera
## tracks at the same rhythm as the player and both render smoothly between the
## 60Hz physics ticks (the fix for stutter/blur on high-refresh monitors).
func _physics_process(delta: float) -> void:
	if _player == null:
		return
	# Fell into the void or was killed -> respawn at the safe start.
	if _player.global_position.y > DEATH_Y or _player.health <= 0.0:
		_respawn_player()
		return
	# Follow the player so you can traverse across the platforms.
	if _camera != null:
		var target := Vector2(_player.global_position.x, _player.global_position.y - 30.0)
		_camera.global_position = _camera.global_position.lerp(target, 1.0 - pow(0.002, delta))


## Reset the player to the safe start, full health, and clear any bolts still in
## the air so you aren't hit the instant you reappear.
func _respawn_player() -> void:
	_player.velocity = Vector2.ZERO
	_player.health = _player.max_health
	_place(_player, SPAWN)
	for proj in get_tree().get_nodes_in_group("projectiles"):
		proj.queue_free()
	if _camera != null:
		_place(_camera, SPAWN + Vector2(0, -30))


## Teleport a node and clear its interpolation, so it snaps to the new spot
## instead of smearing there from wherever it was (physics interpolation is on).
func _place(node: Node2D, pos: Vector2) -> void:
	node.global_position = pos
	node.reset_physics_interpolation()


func _build_platforms() -> void:
	for p in _platforms:
		_build_platform(p[0], p[1], p[2], 14.0)


func _build_platform(center_x: float, top_y: float, width: float, height: float) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Combat.L_WORLD
	body.collision_mask = 0
	body.position = Vector2(center_x, top_y)
	body.add_to_group("oneway_platform")  # so the player can drop through it (down+jump)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, height)
	col.shape = rect
	col.position = Vector2(0, height / 2.0)  # rectangle top sits at top_y
	col.one_way_collision = true  # jump up through it, land on top
	body.add_child(col)

	var vis := ColorRect.new()
	vis.color = Color(0.22, 0.23, 0.30)
	vis.position = Vector2(-width / 2.0, 0)
	vis.size = Vector2(width, height)
	body.add_child(vis)

	add_child(body)


func _spawn_all() -> void:
	for entry in _roster:
		_spawn_enemy(entry)


func _spawn_enemy(entry: Dictionary) -> void:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	# Apply every key except the spawner-only ones as an Enemy export.
	for key in entry:
		if key in ["pos", "name"]:
			continue
		if key == "id":
			enemy.enemy_id = entry[key]
		else:
			enemy.set(key, entry[key])
	enemy.display_name = entry.get("name", entry["id"])
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
	if event.is_action_pressed("prev_character"):
		_player.cycle_character(-1)
	elif event.is_action_pressed("next_character"):
		_player.cycle_character(1)
	elif event.is_action_pressed("debug_damage"):
		_player.take_damage(12.0)
	elif event.is_action_pressed("debug_heal"):
		_player.heal(20.0)
