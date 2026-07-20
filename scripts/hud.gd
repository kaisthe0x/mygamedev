extends CanvasLayer

## Portrait + health bar for the active character.
##
## Registered as an autoload, so it exists in every scene without having to be
## placed in one. It binds to whatever Player enters the tree and hides itself
## when there is none (menus, character select, etc), which also means no scene
## file has to hold a reference to it.

## How quickly the bar slides toward a new value, in health per second.
@export var drain_speed: float = 70.0

@onready var _root: Control = $Root
@onready var _portrait: TextureRect = %Portrait
@onready var _name_label: Label = %CharacterName
@onready var _bar: ProgressBar = %HealthBar
@onready var _value_label: Label = %HealthValue
@onready var _controls: Label = $Controls

var _player: Player
var _target: float = 0.0


func _ready() -> void:
	_set_shown(false)
	# Catch the Player whenever a scene brings one in, including scene changes.
	get_tree().node_added.connect(_on_node_added)
	var existing := _find_player()
	if existing != null:
		_bind(existing)


func _on_node_added(node: Node) -> void:
	if node is Player:
		_bind(node)


func _find_player() -> Player:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	if scene is Player:
		return scene
	for child in scene.get_children():
		if child is Player:
			return child
	return null


func _bind(player: Player) -> void:
	if player == _player:
		return
	_unbind()
	_player = player

	_player.character_changed.connect(_on_character_changed)
	_player.health_changed.connect(_on_health_changed)
	_player.tree_exiting.connect(_unbind)

	# The Player may already be ready, in which case its seeding signals have
	# fired; pull current values so the HUD isn't blank until something moves.
	_on_character_changed(_player.character)
	_on_health_changed(_player.health, _player.max_health)
	_bar.value = _target
	_set_shown(true)


func _unbind() -> void:
	if _player != null and is_instance_valid(_player):
		_player.character_changed.disconnect(_on_character_changed)
		_player.health_changed.disconnect(_on_health_changed)
		_player.tree_exiting.disconnect(_unbind)
	_player = null
	_set_shown(false)


func _set_shown(shown: bool) -> void:
	_root.visible = shown
	_controls.visible = shown
	set_process(shown)


func _process(delta: float) -> void:
	# Chip away toward the real value so a hit reads as a visible drain.
	if not is_equal_approx(_bar.value, _target):
		_bar.value = move_toward(_bar.value, _target, drain_speed * delta)


func _on_character_changed(id: String) -> void:
	_name_label.text = id.to_upper()
	var path := _player.portrait_path()
	if ResourceLoader.exists(path):
		_portrait.texture = load(path)
	else:
		push_warning("HUD: no portrait at %s" % path)
		_portrait.texture = null


func _on_health_changed(current: float, maximum: float) -> void:
	_bar.max_value = maximum
	_target = current
	_value_label.text = "%d / %d" % [roundi(current), roundi(maximum)]
