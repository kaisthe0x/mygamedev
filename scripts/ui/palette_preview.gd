extends Control

## Character colour-customisation preview + SCHEME manager. Runs Khalid's `idle` cycle on a black
## (adjustable) backdrop with a live-recoloured portrait, a colour picker per body part + per power
## family, and up to SaveData.MAX_SCHEMES saved schemes you switch between, Save, and Start a run with.
##
## BODY recolour uses the MATERIAL-AWARE PALETTE LUT (vfx/shaders/sprite_palette.gdshader + PaletteConfig):
## every pixel maps to one of the 36 baked shades and remaps to the picked ramp -- all of a part recolours,
## the pick lands on its natural shade (anchor-by-value, PaletteConfig.derive), and the hair flow + HDR
## glow are layered back on. POWERS recolour via VfxPalette (families labelled Power 1/2/3), shown on a
## looping sample. The PORTRAIT follows the body picks by hue (PaletteConfig.make_portrait_material).
##
## SCHEMES: the 5 slots + the active index persist via SaveData. Selecting a slot loads + makes it active
## (so it applies on next startup). "Save" writes the current picks into the active slot. "Start run" only
## applies the current picks to the run -- it does NOT save (Save is the explicit commit).
##
## Run standalone:  godot res://scenes/palette_preview.tscn

const FRAMES_PATH := "res://resources/characters/khalid.tres"
const PORTRAIT_PATH := "res://assets/portraits/Khalid.png"
const PREVIEW_ANIM := &"idle"
const RUN_SCENE := "res://scenes/level.tscn"
const SPRITE_SCALE := 5.0

## Body pickers, in MATERIALS order -> a friendly label. All six recolour (pants included -- the LUT has
## no hue-key gap). `metal` still covers gauntlets + boots together; splitting them is a TODO.
const BODY_LABELS := {
	"hair": "Hair (red)", "skin": "Skin (teal)", "jacket": "Coat (brown)",
	"trim": "Trim (yellow)", "pants": "Pants (green)", "metal": "Metal (grey)",
}

## Power/VFX families (dedicated, independent of the body). Labelled Power 1/2/3 in the UI; internal keys
## stay red/gold/teal to match VfxPalette's classifier. Values are the family default swatches.
const POWER_FAMILIES := {"red": Color(0.77, 0.04, 0.04), "gold": Color(0.82, 0.75, 0.08),
	"teal": Color(0.08, 0.53, 0.49)}
const POWER_LABELS := {"red": "Power 1", "gold": "Power 2", "teal": "Power 3"}
const SAMPLE_FX := "res://vfx/character/khalid/run/default/run_default.tscn"

# --- theme (matches the HUD's dark panel + gold trim) -------------------------------------------------
const GOLD := Color(0.85, 0.72, 0.18)
const GOLD_DIM := Color(0.55, 0.47, 0.16)
const CRIMSON := Color(0.62, 0.12, 0.12)
const PANEL_BG := Color(0.09, 0.08, 0.11, 0.96)
const ROW_BG := Color(1, 1, 1, 0.035)
const INK := Color(0.90, 0.88, 0.82)
const INK_DIM := Color(0.62, 0.60, 0.56)

var _mat: ShaderMaterial
var _portrait_mat: ShaderMaterial
var _backdrop: ColorRect
var _sprite: AnimatedSprite2D
var _portrait: TextureRect
var _portrait_frame: PanelContainer
var _scroll: ScrollContainer
var _col: VBoxContainer
var _sample: Node2D
var _body_picks := {}   ## material -> picked Color (missing = default shade ramp)
var _power_picks := {}  ## family -> picked Color (missing = family default)
var _body_pickers := {} ## material -> ColorPickerButton (to refresh on scheme load)
var _power_pickers := {}
var _slot_buttons: Array = []
var _active_slot := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Open on the active saved scheme (applies on startup).
	_active_slot = SaveData.active_scheme()
	_read_scheme_into_working(SaveData.color_schemes()[_active_slot])

	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.04, 0.045, 0.06)  # near-black, faintly cool (adjustable)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	# Material-aware palette LUT (recolour + effects) -- the SAME builder the in-game player uses, so the
	# preview matches the run exactly.
	_mat = PaletteConfig.make_material(_body_picks)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = load(FRAMES_PATH)
	_sprite.material = _mat
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(PREVIEW_ANIM):
		_sprite.play(PREVIEW_ANIM)
	add_child(_sprite)

	# Portrait, recoloured to follow the body picks by hue -- in a framed panel, scaled to fit.
	_portrait_mat = PaletteConfig.make_portrait_material(_body_picks)
	_portrait = TextureRect.new()
	_portrait.texture = load(PORTRAIT_PATH)
	_portrait.material = _portrait_mat
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # scale the 1080px art down to the frame
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.custom_minimum_size = Vector2(240, 240)
	_portrait_frame = _framed_box()
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 6)
	pv.add_child(_portrait)
	var cap := Label.new()
	cap.text = "PORTRAIT"
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_font_size_override("font_size", 12)
	cap.add_theme_color_override("font_color", INK_DIM)
	pv.add_child(cap)
	_portrait_frame.add_child(pv)
	add_child(_portrait_frame)

	_build_controls()
	_push_statics()
	_rebuild_sample()
	resized.connect(_reposition)
	_reposition()
	call_deferred("_reposition")  # recompute once children have their real sizes (scroll cap needs them)


func _reposition() -> void:
	if _sprite != null:
		_sprite.position = Vector2(size.x * 0.56, size.y * 0.56)
	if _portrait_frame != null:
		_portrait_frame.position = Vector2(size.x - _portrait_frame.size.x - 28, 28)
	if _scroll != null and _col != null:
		# Cap the scrollable area to the screen height (minus the panel's top/bottom margins + border);
		# shrink to the content when it fits, so short panels don't leave dead space.
		var cap: float = size.y - 100.0
		_scroll.custom_minimum_size.y = minf(_col.get_combined_minimum_size().y, cap)


# --- scheme <-> working picks -------------------------------------------------------------------------

## Load a scheme {"body":{}, "power":{}} into the working picks (defaults fill the gaps).
func _read_scheme_into_working(scheme: Dictionary) -> void:
	_body_picks.clear()
	for m in scheme.get("body", {}):
		_body_picks[m] = scheme["body"][m]
	_power_picks.clear()
	var saved_power: Dictionary = scheme.get("power", {})
	for fam in POWER_FAMILIES:
		_power_picks[fam] = saved_power[fam] if saved_power.has(fam) else POWER_FAMILIES[fam]


## Push the current working picks to every live view (material, portrait, swatches, sample, statics).
func _refresh_all() -> void:
	_apply_body_dst()
	PaletteConfig.apply_portrait_hues(_portrait_mat, _body_picks)
	for m in _body_pickers:
		_body_pickers[m].color = _body_picks[m] if _body_picks.has(m) else Color(PaletteConfig.DEFAULT[m][1])
	for fam in _power_pickers:
		_power_pickers[fam].color = _power_picks[fam]
	_push_statics()
	_rebuild_sample()


## Mirror the working picks into the run-time statics (so the sample + a launched run use them).
func _push_statics() -> void:
	PaletteConfig.set_picks(_body_picks)
	VfxPalette.set_picks(_power_picks)


## Rebuild the LUT `dst` from the current body picks (each material's ramp, or its default if unpicked).
func _apply_body_dst() -> void:
	_mat.set_shader_parameter("dst", PaletteConfig.to_linear_vec3(PaletteConfig.build_targets(_body_picks)))


# --- UI ----------------------------------------------------------------------------------------------

func _build_controls() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(32, 32)
	panel.add_theme_stylebox_override("panel", _panel_box(PANEL_BG, GOLD, 2, 12))
	add_child(panel)

	var pad := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + s, 18)
	panel.add_child(pad)

	# The panel can be taller than the screen at high resolutions, so its content scrolls vertically.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pad.add_child(_scroll)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	col.custom_minimum_size = Vector2(300, 0)
	_scroll.add_child(col)
	_col = col

	var title := Label.new()
	title.text = "KHALID"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", GOLD)
	col.add_child(title)
	var sub := Label.new()
	sub.text = "COLOUR SCHEMES"
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", INK_DIM)
	col.add_child(sub)

	# Scheme slots: radio toggles. Selecting a slot loads + activates it.
	col.add_child(_header("SCHEME"))
	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 6)
	var group := ButtonGroup.new()
	for i in SaveData.MAX_SCHEMES:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(46, 34)
		b.button_pressed = (i == _active_slot)
		_style_slot(b)
		b.pressed.connect(_on_slot.bind(i))
		_slot_buttons.append(b)
		slot_row.add_child(b)
	col.add_child(slot_row)
	_refresh_slot_labels()

	col.add_child(_header("BODY"))
	for m in PaletteConfig.MATERIALS:
		col.add_child(_swatch_row(BODY_LABELS[m], _body_pick_for(m), _on_body_colour.bind(m), _body_pickers, m))

	col.add_child(_header("POWERS / VFX"))
	for fam in ["red", "gold", "teal"]:
		col.add_child(_swatch_row(POWER_LABELS[fam], _power_picks[fam], _on_power_colour.bind(fam), _power_pickers, fam))

	col.add_child(_header("BACKDROP"))
	var bg_pick := ColorPickerButton.new()
	bg_pick.color = _backdrop.color
	bg_pick.color_changed.connect(func(c: Color) -> void: _backdrop.color = c)
	col.add_child(_swatch_row("Background", _backdrop.color, Callable(), {}, "", bg_pick))

	col.add_child(_spacer(6))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	var save := Button.new()
	save.text = "Save scheme"
	save.custom_minimum_size = Vector2(150, 42)
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(save, false)
	save.pressed.connect(_on_save)
	buttons.add_child(save)
	var start := Button.new()
	start.text = "Start run  ▶"
	start.custom_minimum_size = Vector2(150, 42)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(start, true)
	start.pressed.connect(_on_start)
	buttons.add_child(start)
	col.add_child(buttons)


func _body_pick_for(mat_name: String) -> Color:
	return _body_picks[mat_name] if _body_picks.has(mat_name) else Color(PaletteConfig.DEFAULT[mat_name][1])


## One labelled row inside a subtle rounded strip. If `swatch` is given it's used (backdrop); otherwise a
## ColorPickerButton is made, seeded to `col`, wired to `cb`, and stored in `store[key]`.
func _swatch_row(label_text: String, col: Color, cb: Callable, store: Dictionary, key: String,
		swatch: Control = null) -> PanelContainer:
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", _panel_box(ROW_BG, Color(0, 0, 0, 0), 0, 6))
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 8); pad.add_theme_constant_override("margin_right", 6)
	pad.add_theme_constant_override("margin_top", 3); pad.add_theme_constant_override("margin_bottom", 3)
	strip.add_child(pad)
	var row := HBoxContainer.new()
	pad.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_color_override("font_color", INK)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var pick := swatch
	if pick == null:
		var cpb := ColorPickerButton.new()
		cpb.color = col
		cpb.color_changed.connect(cb)
		store[key] = cpb
		pick = cpb
	pick.custom_minimum_size = Vector2(116, 30)
	row.add_child(pick)
	return strip


# --- styling helpers ---------------------------------------------------------------------------------

func _panel_box(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if width > 0:
		sb.set_border_width_all(width)
		sb.border_color = border
	return sb


## A framed dark box (used for the portrait); its content margins give the frame padding.
func _framed_box() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _panel_box(PANEL_BG, GOLD, 2, 12)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	return p


## A gold section header with a thin rule under it.
func _header(text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var top := Control.new(); top.custom_minimum_size = Vector2(0, 6)
	box.add_child(top)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", GOLD)
	box.add_child(lbl)
	var rule := PanelContainer.new()
	rule.custom_minimum_size = Vector2(0, 2)
	rule.add_theme_stylebox_override("panel", _panel_box(GOLD_DIM, Color(0, 0, 0, 0), 0, 1))
	box.add_child(rule)
	return box


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _style_slot(b: Button) -> void:
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", INK_DIM)
	b.add_theme_color_override("font_pressed_color", Color.BLACK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_stylebox_override("normal", _panel_box(Color(1, 1, 1, 0.05), GOLD_DIM, 1, 7))
	b.add_theme_stylebox_override("hover", _panel_box(Color(1, 1, 1, 0.10), GOLD, 1, 7))
	b.add_theme_stylebox_override("pressed", _panel_box(GOLD, GOLD, 1, 7))
	# A toggle stays in "pressed" look while active:
	b.add_theme_stylebox_override("focus", _panel_box(GOLD, GOLD, 1, 7))


func _style_button(b: Button, primary: bool) -> void:
	b.add_theme_font_size_override("font_size", 16)
	var base := GOLD if primary else Color(0.16, 0.15, 0.18)
	var hov := Color(1.0, 0.86, 0.28) if primary else Color(0.22, 0.21, 0.25)
	b.add_theme_color_override("font_color", Color.BLACK if primary else INK)
	b.add_theme_color_override("font_hover_color", Color.BLACK if primary else GOLD)
	b.add_theme_stylebox_override("normal", _btn_box(base, primary))
	b.add_theme_stylebox_override("hover", _btn_box(hov, primary))
	b.add_theme_stylebox_override("pressed", _btn_box(base.darkened(0.15), primary))
	b.add_theme_stylebox_override("focus", _btn_box(base, primary))


func _btn_box(bg: Color, primary: bool) -> StyleBoxFlat:
	var sb := _panel_box(bg, GOLD if primary else GOLD_DIM, 0 if primary else 1, 8)
	sb.set_content_margin_all(8)
	return sb


## Mark each slot button with its number + a dot if it holds a saved scheme.
func _refresh_slot_labels() -> void:
	for i in _slot_buttons.size():
		_slot_buttons[i].text = "%d%s" % [i + 1, "•" if SaveData.scheme_used(i) else ""]


# --- handlers ----------------------------------------------------------------------------------------

func _on_body_colour(colour: Color, mat_name: String) -> void:
	_body_picks[mat_name] = colour
	_apply_body_dst()
	PaletteConfig.apply_portrait_hues(_portrait_mat, _body_picks)
	PaletteConfig.set_picks(_body_picks)


func _on_power_colour(colour: Color, fam: String) -> void:
	_power_picks[fam] = colour
	VfxPalette.set_picks(_power_picks)
	_rebuild_sample()


## Select a slot: make it active (persist so it applies on startup) and load its colours into the pickers.
func _on_slot(i: int) -> void:
	_active_slot = i
	SaveData.set_active(i)
	_read_scheme_into_working(SaveData.color_schemes()[i])
	_refresh_all()


## Write the current picks into the active slot (and keep it active). Explicit commit -- Start does not.
func _on_save() -> void:
	SaveData.save_scheme(_active_slot, _body_picks, _power_picks)
	_refresh_slot_labels()


## Apply the current picks to the run (statics already mirror them) and enter the game. Does NOT save.
func _on_start() -> void:
	_push_statics()
	get_tree().change_scene_to_file(RUN_SCENE)


## Spawn a fresh copy of the sample effect and recolour it with the current picks. Rebuilt on every change
## because recolor_tree mutates colours one-way (hue swap) -- re-applying would compound.
func _rebuild_sample() -> void:
	if _sample != null and is_instance_valid(_sample):
		_sample.queue_free()
	var scn: PackedScene = load(SAMPLE_FX)
	if scn == null:
		return
	_sample = scn.instantiate() as Node2D
	if _sample == null:
		return
	VfxPalette.recolor_tree(_sample)
	add_child(_sample)
	_sample.position = Vector2(size.x * 0.55, size.y * 0.74)
