class_name LaunchOrb
extends Node2D

# TODO: Update SFX for LaunchOrb

## A levitating LAUNCH orb: dash into (or near) it and it magnets Khalid through and flings him up +
## forward out the far side (see Player._process_launch). Placed by RunManager from a level's `orbs`
## list (see Levels). Detection is PLAYER-side: the orb bobs and joins the "orbs" group; the Player
## scans it, drives which one is "near" (Player._update_orb_proximity -> set_near), and owns the launch.
## So the orb is dumb -- adding one to a level is a single data entry.
##
## Colour: the orb's baked art is DARK, so it wears a tint+GLOW shader (thing_recolor.gdshader) that
## paints it a bright bloom in the chosen power-family colour (VfxPalette). In range it SHINES brighter.
##
## Sound: it emits a LOOPING hum while it exists (launch_orb, positional) and a one-shot on use
## (launch_orb_use) -- both live under sfx/things/traversal/launch_orb/ (SfxWorld, not a character cue).
##
## Launch: each orb defines the SET impulse it gives -- a strong UP + a good FORWARD -- so it's fully
## automatic (dash through it and you're flung), far enough (with air-dashes) to reach the next platform.

const FRAMES := "res://resources/things/launch_orb.tres"
const RECOLOR_SHADER := "res://vfx/shaders/thing_recolor.gdshader"
const SAMPLE := Color(1.0, 0.22, 0.26)  ## bright orb red -> which palette family it follows + its tint
const BOB_AMPLITUDE := 4.0  ## px of gentle vertical levitation
const BOB_SPEED := 2.2      ## rad/s of the bob
const SHINE_NEAR := 1.4     ## extra emissive lift while Khalid is in range (0 = none)
const SHINE_TWEEN := 0.14   ## s to ramp the shine in/out
const HUM_VOLUME_DB := -8.0 ## the ambient loop sits quiet under the mix

## The SET launch this orb gives (px/s): a strong UP + a good FORWARD along Khalid's facing. Tune per
## orb to reach the next platform; the Player reads these on capture (Player._begin_launch).
@export var launch_up := 950.0
@export var launch_forward := 650.0

var _sprite: AnimatedSprite2D
var _mat: ShaderMaterial
var _hum: AudioStreamPlayer2D
var _base_y := 0.0
var _phase := 0.0
var _near := false
var _shine := 0.0


func _ready() -> void:
	add_to_group("orbs")
	_base_y = position.y
	_phase = global_position.x * 0.05 # desync neighbouring orbs so a row doesn't bob in lockstep
	_sprite = AnimatedSprite2D.new()
	_sprite.centered = true # the orb pivots on its centre -- that's the magnet target
	if ResourceLoader.exists(FRAMES):
		_sprite.sprite_frames = load(FRAMES)
		_sprite.play(&"bob")
	_apply_recolor()
	add_child(_sprite)
	# The ambient hum it emits on loop (positional; caller owns the looping player, so it frees with us).
	_hum = Sfx.make_loop_2d("launch_orb")
	if _hum != null:
		_hum.volume_db = HUM_VOLUME_DB
		add_child(_hum)
		_hum.play()


## Wear the tint+glow material and paint it the chosen power-family colour (VfxPalette.recolor swaps the
## sample's hue to the pick, or leaves it bright red if there's no pick). glow/shine keep it a bright bloom.
func _apply_recolor() -> void:
	if not ResourceLoader.exists(RECOLOR_SHADER):
		return
	_mat = ShaderMaterial.new()
	_mat.shader = load(RECOLOR_SHADER)
	_mat.set_shader_parameter("tint", VfxPalette.recolor(SAMPLE))
	_mat.set_shader_parameter("shine", 0.0)
	_sprite.material = _mat


func _process(delta: float) -> void:
	_phase += delta * BOB_SPEED
	position.y = _base_y + sin(_phase) * BOB_AMPLITUDE
	# Ease the shine toward its target (near = lit) so it fades in/out instead of popping.
	var target := SHINE_NEAR if _near else 0.0
	if not is_equal_approx(_shine, target):
		_shine = move_toward(_shine, target, delta / maxf(SHINE_TWEEN, 0.001) * SHINE_NEAR)
		if _mat != null:
			_mat.set_shader_parameter("shine", _shine)


## Called by the Player each frame: is Khalid close enough to launch off this orb? Drives the SHINE only
## (the sound is the always-on hum + the use one-shot). The Player owns the range test.
func set_near(value: bool) -> void:
	_near = value


## Play the one-shot "used it" cue at the orb (called by the Player when it captures/launches him).
func play_use() -> void:
	Sfx.play_at("launch_orb_use", global_position)
