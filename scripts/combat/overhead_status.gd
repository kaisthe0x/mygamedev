class_name OverheadStatus
extends Node2D

## A looping animation that hovers over an enemy's head while a status is active -- e.g. the swirling
## stars "halo" of a STUN. Built in code (no scene), so any enemy/boss gets one for free -- it's the
## over-head twin of StatusIcons (the pips beside the health bar). The enemy reports its active status
## ids each frame; we show the highest-PRIORITY one that has an over-head anim (StatusTypes.OVERHEAD),
## bob it gently like a floating halo, and hide when none is active. Only ONE halo shows at a time.
## Adding art to another status is a config line in StatusTypes.OVERHEAD -- no change here.

const BOB_AMPL := 1.5   ## px of vertical hover
const BOB_SPEED := 2.2  ## hover cycles/sec

var _sprite: AnimatedSprite2D
var _y_off := 0.0        ## the active status's own vertical offset from the head line
var _shown := ""         ## id currently drawn ("" = nothing), so we only rebuild on a real change
var _phase := 0.0

## SpriteFrames are sliced ONCE per sheet and shared across every enemy (the art is identical).
static var _sf_cache: Dictionary = {}


func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # pixel art -- no blur
	_sprite.z_index = 2 # over the body + its status tint
	_sprite.visible = false
	add_child(_sprite)
	set_process(false)


## Anchor the halo at `head_y` (feet are y=0, so the head line is negative). Per-status vertical
## nudges layer on top of this in set_active().
func setup(head_y: float) -> void:
	position = Vector2(0.0, head_y)


## Show the highest-priority active status that HAS an over-head anim; hide if none do. `ids` is the
## same active-status list the enemy feeds StatusIcons.
func set_active(ids: Array) -> void:
	var pick := ""
	for id in StatusTypes.ORDER:
		if id in ids and StatusTypes.OVERHEAD.has(id):
			pick = id
			break
	if pick == _shown:
		return
	_shown = pick
	if pick == "":
		_sprite.visible = false
		set_process(false)
		return
	var spec: Dictionary = StatusTypes.OVERHEAD[pick]
	_sprite.sprite_frames = _frames_for(spec)
	_sprite.scale = Vector2.ONE * float(spec.get("scale", 1.0))
	_y_off = float(spec.get("y_off", 0.0))
	_phase = 0.0
	_sprite.position.y = _y_off
	_sprite.play(&"default")
	_sprite.visible = true
	set_process(true)


func _process(delta: float) -> void:
	# Float the halo up and down so it reads as hovering rather than pinned to the skull.
	_phase += delta
	_sprite.position.y = _y_off + sin(_phase * TAU * BOB_SPEED) * BOB_AMPL


## Build (and cache) a looping SpriteFrames from a horizontal sheet: `hframes` cells of equal width.
static func _frames_for(spec: Dictionary) -> SpriteFrames:
	var path: String = spec["sheet"]
	if _sf_cache.has(path):
		return _sf_cache[path]
	var tex: Texture2D = load(path)
	var hframes: int = int(spec.get("hframes", 1))
	var fw: int = tex.get_width() / maxi(hframes, 1)
	var fh: int = tex.get_height()
	var sf := SpriteFrames.new()
	sf.set_animation_loop(&"default", true)
	sf.set_animation_speed(&"default", float(spec.get("fps", 10.0)))
	for i in hframes:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fw, 0, fw, fh)
		sf.add_frame(&"default", at)
	_sf_cache[path] = sf
	return sf
