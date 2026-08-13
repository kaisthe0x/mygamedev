extends Control

## Character colour-customisation preview. Runs Khalid's `run` cycle on a black (adjustable) backdrop
## with a colour picker per body part + per power-colour family.
##
## BODY recolour uses the MATERIAL-AWARE PALETTE LUT (vfx/shaders/sprite_palette.gdshader + PaletteConfig):
## every pixel is matched to one of the 36 baked shades and remapped to the picked ramp -- so ALL of a
## part recolours (not just the bright pixels the old hue-key caught), the exact colour you pick lands on
## the band that covers most of the part (anchor-by-value, PaletteConfig.derive), AND the living-hair
## flow + HDR glow are layered back on per material. Same effects, accurate + complete recolour.
##
## POWERS recolour via VfxPalette (dedicated red/gold/teal families) -- shown live on a looping sample.
##
## Run standalone:  godot res://scenes/palette_preview.tscn
##
## WHERE TO TWEAK:
##   * Glow / vibrance / hair-flow -> _apply_body_effects() below + PaletteConfig.MATERIAL_GLOW defaults;
##     the flow maths lives in vfx/shaders/sprite_palette.gdshader.
##   * "Colour chosen == colour shown" (accuracy) -> PaletteConfig.derive() (anchor-by-value).
##   * Powers/VFX -> configs/vfx_palette.gd.

const FRAMES_PATH := "res://resources/characters/khalid.tres"
const PREVIEW_ANIM := &"idle"
const RUN_SCENE := "res://scenes/level.tscn"
const SPRITE_SCALE := 5.0

## Body pickers, in MATERIALS order -> a friendly label. All six recolour now (pants included -- the LUT
## has no hue-key gap). `metal` still covers gauntlets + boots together; splitting them is a TODO.
const BODY_LABELS := {
	"hair": "Hair (red)", "skin": "Skin (teal)", "jacket": "Coat (brown)",
	"trim": "Trim (yellow)", "pants": "Pants (green)", "metal": "Metal (grey)",
}

## Power/VFX pickers are DEDICATED (independent of the body): three hue families -> the picked colour.
## They drive VfxPalette.picks, which every spawned effect honours (see VfxPalette + ParticleDirector).
const POWER_FAMILIES := {"red": Color(0.77, 0.04, 0.04), "gold": Color(0.82, 0.75, 0.08),
	"teal": Color(0.08, 0.53, 0.49)}
const SAMPLE_FX := "res://vfx/character/khalid/run/default/run_default.tscn"

var _mat: ShaderMaterial
var _backdrop: ColorRect
var _sprite: AnimatedSprite2D
var _body_picks := {}   ## material -> picked Color (missing = default shade ramp)
var _power_picks := {}
var _sample: Node2D


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color.BLACK
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	# Material-aware palette LUT (recolour + effects) -- the SAME builder the in-game player uses, so the
	# preview matches the run exactly. Starts on the default palette; body picks update `dst` live.
	_mat = PaletteConfig.make_material(_body_picks)

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = load(FRAMES_PATH)
	_sprite.material = _mat
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(PREVIEW_ANIM):
		_sprite.play(PREVIEW_ANIM)
	add_child(_sprite)

	_build_controls()
	VfxPalette.set_picks(_power_picks)
	_rebuild_sample()
	resized.connect(_center_sprite)
	_center_sprite()


func _center_sprite() -> void:
	if _sprite != null:
		_sprite.position = Vector2(size.x * 0.62, size.y * 0.55)


## Rebuild the LUT `dst` from the current body picks (each material's ramp, or its default if unpicked).
func _apply_body_dst() -> void:
	var targets := PaletteConfig.build_targets(_body_picks)
	_mat.set_shader_parameter("dst", PaletteConfig.to_linear_vec3(targets))


func _build_controls() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 24)
	panel.custom_minimum_size = Vector2(280, 0)
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)

	var title := Label.new()
	title.text = "Khalid — colours (effects preserved)"
	col.add_child(title)

	for m in PaletteConfig.MATERIALS:
		col.add_child(_body_row(BODY_LABELS[m], m))

	col.add_child(HSeparator.new())
	var pwr_title := Label.new()
	pwr_title.text = "Powers / VFX (dedicated)"
	col.add_child(pwr_title)
	var pwr_names := {"red": "Red powers", "gold": "Gold powers", "teal": "Teal powers"}
	for fam in ["red", "gold", "teal"]:
		col.add_child(_power_row(pwr_names[fam], fam))

	col.add_child(HSeparator.new())
	var bg_row := HBoxContainer.new()
	var bg_lbl := Label.new(); bg_lbl.text = "Backdrop"; bg_lbl.custom_minimum_size = Vector2(120, 0)
	var bg_pick := ColorPickerButton.new(); bg_pick.custom_minimum_size = Vector2(120, 28)
	bg_pick.color = Color.BLACK
	bg_pick.color_changed.connect(func(c: Color) -> void: _backdrop.color = c)
	bg_row.add_child(bg_lbl); bg_row.add_child(bg_pick)
	col.add_child(bg_row)

	col.add_child(HSeparator.new())
	var start := Button.new()
	start.text = "Start run  ▶"
	start.custom_minimum_size = Vector2(0, 40)
	start.pressed.connect(_on_start)
	col.add_child(start)


## Lock in the chosen colours (body + powers persist via statics across the scene change) and enter the
## run. The player rebuilds its body material from PaletteConfig.picks in _apply_character; every spawned
## effect honours VfxPalette.picks.
func _on_start() -> void:
	PaletteConfig.set_picks(_body_picks)
	VfxPalette.set_picks(_power_picks)
	get_tree().change_scene_to_file(RUN_SCENE)


func _body_row(label_text: String, mat_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(120, 0)
	var pick := ColorPickerButton.new()
	pick.custom_minimum_size = Vector2(120, 28)
	# Seed the swatch from the material's representative (light) default shade.
	pick.color = Color(PaletteConfig.DEFAULT[mat_name][1])
	pick.color_changed.connect(_on_body_colour.bind(mat_name))
	row.add_child(lbl)
	row.add_child(pick)
	return row


func _on_body_colour(colour: Color, mat_name: String) -> void:
	_body_picks[mat_name] = colour
	_apply_body_dst()


func _power_row(label_text: String, fam: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(120, 0)
	var pick := ColorPickerButton.new()
	pick.custom_minimum_size = Vector2(120, 28)
	pick.color = POWER_FAMILIES[fam]
	_power_picks[fam] = POWER_FAMILIES[fam]
	pick.color_changed.connect(_on_power_colour.bind(fam))
	row.add_child(lbl)
	row.add_child(pick)
	return row


func _on_power_colour(colour: Color, fam: String) -> void:
	_power_picks[fam] = colour
	VfxPalette.set_picks(_power_picks)
	_rebuild_sample()


## Spawn a fresh copy of the sample effect and recolour it with the current picks. Rebuilt on every pick
## because recolor_tree mutates colours one-way (hue swap) -- re-applying to already-swapped colours would
## compound, so we always start from a clean instance.
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
	_sample.position = Vector2(size.x * 0.62, size.y * 0.72)
