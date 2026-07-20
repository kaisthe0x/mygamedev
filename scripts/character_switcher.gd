extends Node2D

## Dev helper: cycle the player through the available characters at runtime,
## so you can eyeball that every animation set lines up. The HUD shows which
## character is active. Also fakes damage/heal so the health bar can be tested.

@export var player_path: NodePath = ^"Player"

@onready var _player: Player = get_node_or_null(player_path) as Player


func _unhandled_input(event: InputEvent) -> void:
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
