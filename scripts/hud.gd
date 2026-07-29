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

## Debug stats panel (built in code, top-right) -- every buffable number for the active
## character, refreshed live so it reflects changes as buffs/items land later.
var _stats: PanelContainer
var _stats_label: Label


func _ready() -> void:
	_build_stats()
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
	# Rebuild the debug stats every frame so live tweaks/buffs show at once (cheap).
	if _player != null:
		_stats_label.text = _stats_text()


func _on_character_changed(id: String) -> void:
	_name_label.text = id.to_upper()
	var path := _player.portrait_path()
	if ResourceLoader.exists(path):
		_portrait.texture = load(path)
	else:
		push_warning("HUD: no portrait at %s" % path)
		_portrait.texture = null
	if _player != null:
		_stats_label.text = _stats_text()  # refresh immediately on swap


# --- debug stats panel -------------------------------------------------------

func _build_stats() -> void:
	_stats = PanelContainer.new()
	_stats.name = "DebugStats"
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Pin to the top-right corner, growing leftward/downward to fit its text.
	_stats.anchor_left = 1.0
	_stats.anchor_right = 1.0
	_stats.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_stats.grow_vertical = Control.GROW_DIRECTION_END
	_stats.offset_left = -10.0
	_stats.offset_right = -10.0
	_stats.offset_top = 10.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.set_content_margin_all(8.0)
	sb.set_corner_radius_all(4)
	_stats.add_theme_stylebox_override("panel", sb)
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 12)
	_stats.add_child(_stats_label)
	_root.add_child(_stats)  # under Root, so it shows/hides with the rest of the HUD


func _stats_text() -> String:
	var p := _player
	var lines: Array[String] = [
		"── STATS (debug) ──",
		"%s      HP %d" % [p.character.to_upper(), roundi(p.max_health)],
		"Run %d   Jump %d   Dash %d" % [roundi(p.run_speed), roundi(p.jump_velocity), roundi(p.dash_speed)],
		"Air jumps %d   Gravity %d" % [p.max_air_jumps, roundi(p.gravity)],
		"Slam %d  (slam:%s fall:%s land:%s)" % [
			roundi(p.slam_speed), _yn(p.has_anim(&"slam")), _yn(p.has_anim(&"fall")), _yn(p.has_anim(&"land"))],
		"",
		_move_line("Attack ", p.current_attack()),
		_move_line("Special", p.current_special()),
	]
	return "\n".join(lines)


func _move_line(label: String, m: Move) -> String:
	if m == null:
		return "%s: none" % label
	var kind_name: String = Combat.AttackKind.keys()[m.attack_kind]
	return "%s: %s [%s]  dmg %s" % [label, m.id, kind_name, _dmg(m)]


## Damage summary from a move's tuning: a single number, "/"-joined per combo segment,
## or "scene" when the move carries its numbers on its effect scene (empty tuning).
func _dmg(m: Move) -> String:
	var t: Variant = m.tuning
	if t is Array:
		if (t as Array).is_empty():
			return "scene"
		var parts: Array[String] = []
		for seg: Dictionary in t:
			parts.append(str(seg.get("damage", 0)))
		return "/".join(parts)
	if t is Dictionary:
		if (t as Dictionary).is_empty():
			return "scene"
		return str((t as Dictionary).get("damage", 0))
	return "?"


func _yn(b: bool) -> String:
	return "y" if b else "n"


func _on_health_changed(current: float, maximum: float) -> void:
	_bar.max_value = maximum
	_target = current
	_value_label.text = "%d / %d" % [roundi(current), roundi(maximum)]
