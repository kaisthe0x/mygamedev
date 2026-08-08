class_name AttackSelect
extends CanvasLayer

## The run-start "choose your attack" screen. The player picks ONE attack and it's LOCKED for the
## whole run (attacks never change mid-run -- only get buffed, via the Attack door). RunManager
## opens this at the start of every run and awaits `chosen(id)`, then equips it.
##
## Built in code, pauses the game (process_mode = ALWAYS so its buttons still work). The cards live
## in a GridContainer inside a ScrollContainer, so it scales cleanly to a LARGE roster (12+): extra
## attacks wrap to new rows and scroll -- no layout changes needed as attacks are added.

signal chosen(id: String)

const COLUMNS := 4
const CARD := Vector2(150, 150)
const VIEW := Vector2(660, 470)  ## scroll viewport max size; grid overflows -> scrollbar


func _init() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS


## Show a card per attack in `character`'s roster and pause until one is picked.
func open(character: String) -> void:
	get_tree().paused = true

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	var title := Label.new()
	title.text = "CHOOSE YOUR ATTACK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	col.add_child(title)

	var sub := Label.new()
	sub.text = "Locked in for the whole run — buff it at Attack doors."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	col.add_child(sub)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = VIEW
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)

	var first: Button = null
	for id in Moves.ids(character, "attacks"):
		var move: Move = Moves.get_move(character, "attacks", id)
		if move == null:
			continue
		grid.add_child(_make_card(id, move))
		if first == null:
			first = grid.get_child(grid.get_child_count() - 1)
	if first != null:
		first.grab_focus()  # keyboard/controller can pick without a mouse


func _make_card(id: String, move: Move) -> Button:
	var card := Button.new()
	card.custom_minimum_size = CARD
	card.clip_contents = true
	var tcol: Color = Loadout.tier_color(move.tier)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.15, 0.96)
	sb.set_border_width_all(2)
	sb.border_color = tcol
	sb.set_corner_radius_all(4)
	card.add_theme_stylebox_override("normal", sb)
	card.add_theme_stylebox_override("hover", sb)
	# Icon (fixed size, so a huge placeholder png can't balloon the card) + label, click passes through.
	card.add_child(card_body(Icons.attack(id),
		"%s\n[%s]  dmg %s" % [id.capitalize(), Loadout.tier_label(move.tier), _dmg(move)], CARD.x))
	card.pressed.connect(func() -> void: _pick(id))
	return card


## A centered fixed-size icon over a wrapped label, filling a card and transparent to the mouse
## (so the parent Button gets the click). Shared card content -- `card_w` bounds the label width.
static func card_body(tex: Texture2D, text: String, card_w: float) -> Control:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 6)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = tex
	icon.custom_minimum_size = Vector2(46, 46)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(card_w - 14, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	return box


## Damage summary for a card: an array-tuned combo shows "a/b/c", a dict shows its damage,
## an empty tuning means the effect scene carries its own numbers.
func _dmg(move: Move) -> String:
	var t: Variant = move.tuning
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


func _pick(id: String) -> void:
	get_tree().paused = false
	chosen.emit(id)
	queue_free()
