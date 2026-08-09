extends CanvasLayer

## Portrait + HP bar + ruh BLOCK meter (+ a debug stats panel) for the active character.
##
## Registered as an autoload, so it exists in every scene without being placed in one. It binds
## to whatever Player enters the tree and hides when there's none. The whole HUD is **built in
## code** (no scene containers) and anchored top-left, so it renders reliably regardless of
## window size / Godot scene-layout quirks.
##
## Ruh shows as discrete BLOCKS (one per Player.RUH_PER_BLOCK), not a raw number: N cells that
## fill/drain partially. It updates straight from ruh_changed (fires when a kill banks Ruh or a
## cast spends it), so no smoothing tween needed.

## How quickly the HP bar slides toward a new value, in units per second.
@export var drain_speed: float = 70.0

var _player: Player
var _target: float = 0.0

# Built-in-code widgets (direct children of this CanvasLayer, explicit positions).
var _root: Control            ## a plain container we show/hide as one
var _portrait: TextureRect
var _name_label: Label
var _bar: ProgressBar         ## HP
var _value_label: Label
var _ruh_area: Control       ## holds the block cells
var _ruh_cells: Array = []   ## [{bg, fill}] -- one per ruh block, rebuilt when the cap changes
var _ruh_cell_w: float = 0.0
var _ruh_label: Label
var _levels_label: Label      ## levels cleared this run + the best-ever record
var _controls: Label
var _stats: PanelContainer
var _stats_label: Label

const RUH_METER_SIZE := Vector2(248, 16)
const RUH_CELL_GAP := 3.0
const RUH_FILL := Color(0.80, 0.16, 0.20)    ## filled block: crimson
const RUH_EMPTY := Color(0.16, 0.08, 0.10, 0.9)  ## empty block slot


func _ready() -> void:
	layer = 100  # keep the HUD above every other CanvasLayer
	_build_hud()
	_build_stats()
	_set_shown(false)
	get_tree().node_added.connect(_on_node_added)
	set_process(true)  # always process: the safety net in _process re-binds if we miss one
	var existing := _find_player()
	if existing != null:
		_bind(existing)


# --- construction (all in code, no scene layout) ----------------------------

func _build_hud() -> void:
	_root = Control.new()  # holds the top-left cluster; toggled by _set_shown
	_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var frame := Panel.new()
	frame.position = Vector2(16, 16)
	frame.size = Vector2(112, 112)
	frame.add_theme_stylebox_override("panel", _framed(Color(0.07, 0.07, 0.09, 0.85), Color(0.85, 0.72, 0.18)))
	_root.add_child(frame)

	_portrait = TextureRect.new()
	_portrait.position = Vector2(4, 4)
	_portrait.size = Vector2(104, 104)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(_portrait)

	var info_x := 140.0
	_name_label = _mk_label(Vector2(info_x, 14), 20, Color(0.93, 0.87, 0.62))
	_name_label.text = "CHARACTER"

	_bar = _mk_bar(Vector2(info_x, 48), Vector2(248, 20), Color(0.78, 0.13, 0.18))  # HP: red
	_value_label = _mk_label(Vector2(info_x, 48), 13, Color(0.9, 0.9, 0.95))
	_value_label.size = Vector2(248, 20)
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_ruh_area = Control.new()  # the block cells live here; rebuilt on cap change
	_ruh_area.position = Vector2(info_x, 76)
	_ruh_area.size = RUH_METER_SIZE
	_ruh_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_ruh_area)

	_ruh_label = _mk_label(Vector2(info_x + RUH_METER_SIZE.x + 8, 74), 12, Color(0.95, 0.75, 0.8))
	_ruh_label.size = Vector2(120, 18)
	_ruh_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_levels_label = _mk_label(Vector2(info_x, 100), 15, Color(0.85, 0.72, 0.18))  # gold, like the frame

	_controls = _mk_label(Vector2(16, 140), 12, Color(0.62, 0.62, 0.68))
	_controls.text = "A/D move   Space jump   Shift dash   LMB attack   RMB special/slam   Z hurt   X +ruh   0 rebuild"


func _mk_label(pos: Vector2, font_size: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	_root.add_child(l)
	return l


func _mk_bar(pos: Vector2, sz: Vector2, fill: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.position = pos
	b.size = sz
	b.custom_minimum_size = sz
	b.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.09, 0.09, 0.11, 0.9)
	bg.set_corner_radius_all(2)
	var fs := StyleBoxFlat.new()
	fs.bg_color = fill
	fs.set_corner_radius_all(2)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fs)
	_root.add_child(b)
	return b


## (Re)build the block cells so there's one per ruh block (cap / RUH_PER_BLOCK). Called when the
## cap changes (a reward can raise it). Cells are laid out evenly across RUH_METER_SIZE.
func _build_ruh_meter(block_count: int) -> void:
	for c in _ruh_area.get_children():
		c.queue_free()
	_ruh_cells.clear()
	block_count = maxi(block_count, 1)
	_ruh_cell_w = (RUH_METER_SIZE.x - RUH_CELL_GAP * (block_count - 1)) / block_count
	for i in block_count:
		var x := i * (_ruh_cell_w + RUH_CELL_GAP)
		var bg := ColorRect.new()
		bg.position = Vector2(x, 0)
		bg.size = Vector2(_ruh_cell_w, RUH_METER_SIZE.y)
		bg.color = RUH_EMPTY
		_ruh_area.add_child(bg)
		var fill := ColorRect.new()
		fill.position = Vector2(x, 0)
		fill.size = Vector2(0, RUH_METER_SIZE.y)  # width set per-frame from the ruh value
		fill.color = RUH_FILL
		_ruh_area.add_child(fill)
		_ruh_cells.append(fill)


## Fill each cell 0..1 by how much of its block the current ruh covers.
func _update_ruh_meter(current: float) -> void:
	var per := _player.RUH_PER_BLOCK if _player != null else 50.0
	for i in _ruh_cells.size():
		var ratio: float = clampf(current / per - float(i), 0.0, 1.0)
		(_ruh_cells[i] as ColorRect).size.x = _ruh_cell_w * ratio


func _framed(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(2)
	s.border_color = border
	s.set_corner_radius_all(3)
	return s


# --- binding ----------------------------------------------------------------

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
	_player.ruh_changed.connect(_on_ruh_changed)
	_player.tree_exiting.connect(_unbind)
	_on_character_changed(_player.character)
	_on_health_changed(_player.health, _player.max_health)
	_on_ruh_changed(_player.ruh, _player.ruh_cap)
	_bar.value = _target
	_recolor_hp()  # colour the full bar green now that _bar.value is seeded (see _on_health_changed)
	_set_shown(true)


func _unbind() -> void:
	if _player != null and is_instance_valid(_player):
		_player.character_changed.disconnect(_on_character_changed)
		_player.health_changed.disconnect(_on_health_changed)
		_player.ruh_changed.disconnect(_on_ruh_changed)
		_player.tree_exiting.disconnect(_unbind)
	_player = null
	_set_shown(false)


func _set_shown(shown: bool) -> void:
	_root.visible = shown
	_stats.visible = shown
	# processing stays ON even when hidden, so _process can re-bind (see below).


func _process(delta: float) -> void:
	# Safety net: if unbound but a player exists, bind now (covers any missed node_added).
	if _player == null:
		var p := _find_player()
		if p != null:
			_bind(p)
		return
	if not is_equal_approx(_bar.value, _target):
		_bar.value = move_toward(_bar.value, _target, drain_speed * delta)
		_recolor_hp()  # shift the fill green->orange->red as the animated drain crosses thresholds
	_levels_label.text = "LEVELS  %d   ·   BEST %d" % [SaveData.current_cleared, SaveData.levels_record()]
	_stats_label.text = _stats_text()


func _on_character_changed(id: String) -> void:
	_name_label.text = id.to_upper()
	var path := _player.portrait_path()
	_portrait.texture = load(path) if ResourceLoader.exists(path) else null
	_stats_label.text = _stats_text()


func _on_health_changed(current: float, maximum: float) -> void:
	_bar.max_value = maximum
	_target = current
	_value_label.text = "%d / %d" % [roundi(current), roundi(maximum)]
	_recolor_hp()


## Tint the HP fill by how full it is -- green / orange / red -- from the SAME bands the floating
## enemy bars use (FloatingHealthBar.color_for_ratio), so player and enemies read consistently.
func _recolor_hp() -> void:
	if _bar == null or _bar.max_value <= 0.0:
		return
	var fs := _bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fs != null:
		fs.bg_color = FloatingHealthBar.color_for_ratio(_bar.value / _bar.max_value)


func _on_ruh_changed(current: float, maximum: float) -> void:
	var per := _player.RUH_PER_BLOCK if _player != null else 50.0
	var blocks := maxi(roundi(maximum / per), 1)
	if blocks != _ruh_cells.size():
		_build_ruh_meter(blocks)
	_update_ruh_meter(current)
	_ruh_label.text = "RUH  %d ▮" % floori(current / per)


# --- debug stats panel (top-right) ------------------------------------------

func _build_stats() -> void:
	_stats = PanelContainer.new()
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	add_child(_stats)


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
	return "%s: %s [%s] %s  dmg %s" % [label, m.id, kind_name, Loadout.tier_label(m.tier), _dmg(m)]


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
