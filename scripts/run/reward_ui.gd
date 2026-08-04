class_name RewardUI
extends CanvasLayer

## The pick-a-reward popup shown after passing an exit gate. RunManager creates one, calls
## open(rewards), and awaits `chosen(id)`; the player clicks a card, we un-pause and report it.
## Built in code, pauses the game while up (process_mode = ALWAYS so its buttons still work).

signal chosen(id: String)


func _init() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep working while the tree is paused


## Show a card per reward ({id, name, desc}) and pause the game until one is picked.
func open(rewards: Array) -> void:
	get_tree().paused = true

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP  # eat clicks behind the popup
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	center.add_child(col)

	var title := Label.new()
	title.text = "CHOOSE A REWARD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	col.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)

	var first: Button = null
	for r: Dictionary in rewards:
		var card := Button.new()
		card.custom_minimum_size = Vector2(190, 130)
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.text = "%s\n\n%s" % [r["name"], r["desc"]]
		var id: String = r["id"]
		card.pressed.connect(func() -> void: _pick(id))
		row.add_child(card)
		if first == null:
			first = card
	if first != null:
		first.grab_focus()  # so keyboard/controller can pick without a mouse


func _pick(id: String) -> void:
	get_tree().paused = false
	chosen.emit(id)
	queue_free()
