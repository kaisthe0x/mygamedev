extends Node2D

## Dev helper: cycle the player through characters, fake damage/heal, and spawn
## enemies. Spawning happens in code so the level scene stays untouched (the
## editor keeps clobbering it); move enemies into the level scene proper when
## ready. Press debug_respawn (0) to bring a killed enemy back and keep fighting.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

@export var player_path: NodePath = ^"Player"
@export var spawn_enemies := true

## Each entry: { id, name, pos, and any Enemy export to override }. Overrides are
## per-instance, so aggro / contact_damage / stats differ per enemy. (In a real
## level you'd instead drop enemy.tscn in and set these in the inspector.)
var _roster := [
	{"id": "kebus", "name": "Kebus", "pos": Vector2(140, 0)},
	# Example of a second, aggressive enemy -- uncomment to try:
	# {"id": "kebus", "name": "Hunter", "pos": Vector2(360, 0), "aggro": true, "contact_damage": 6.0},
]

@onready var _player: Player = get_node_or_null(player_path) as Player


func _ready() -> void:
	if _player != null:
		_player.global_position = Vector2(-120, 0)
	if spawn_enemies:
		_spawn_all()


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
	add_child(enemy)
	enemy.global_position = entry.get("pos", Vector2.ZERO)


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
