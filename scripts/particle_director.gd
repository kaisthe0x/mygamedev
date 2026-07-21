class_name ParticleDirector
extends Node2D

## Spawns 2D particle effects at authored positions during authored animation
## frames, so VFX can be layered over the drawn sprites (e.g. embers on Wayna's
## flame) without baking them in.
##
## Config: res://resources/particles/emitters.json, keyed
##   character -> animation -> [ { type, mode, frames, pos } ]
## - type   : a scene name under particles/<type>.tscn
## - mode   : "sustained" (emit while any listed frame is showing) or
##            "burst" (spawn a one-shot each time a listed frame is entered)
## - frames : SHEET-relative indices (same numbering as loop_from / hit_frames;
##            the idle-reference frame counts). Converted to emitted indices via
##            the SpriteFrames `sheet_start` metadata.
## - pos    : [x, y] pixel offset from the sprite origin (the feet), for facing
##            right; mirrored automatically when facing left.
##
## The director is a child of the player; emitter scenes use local_coords=false
## so their particles trail in world space as the player moves. Add a new effect
## by dropping a scene in particles/ and an entry in the JSON -- no code changes.

const CONFIG_PATH := "res://resources/particles/emitters.json"
const PARTICLE_PATH := "res://particles/%s.tscn"

var _sprite: AnimatedSprite2D
var _config: Dictionary = {}
## One entry per sustained config row: {node, anim, frames: Array[int], pos}.
var _sustained: Array[Dictionary] = []
## One entry per burst config row: {anim, frames: Array[int], pos, type}.
var _bursts: Array[Dictionary] = []


func setup(sprite: AnimatedSprite2D) -> void:
	_sprite = sprite
	_load_config()
	_sprite.frame_changed.connect(_refresh)
	_sprite.animation_changed.connect(_refresh)


func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if parsed is Dictionary:
		_config = parsed
	else:
		push_warning("ParticleDirector: could not parse %s" % CONFIG_PATH)


## Rebuild the emitter set for a character. Called when the player swaps.
func set_character(id: String) -> void:
	for entry in _sustained:
		entry.node.queue_free()
	_sustained.clear()
	_bursts.clear()

	var by_anim: Dictionary = _config.get(id, {})
	for anim in by_anim:
		if not (by_anim[anim] is Array):
			continue
		var start := _sheet_start(anim)
		for row: Dictionary in by_anim[anim]:
			var frames: Array[int] = []
			for f in row.get("frames", []):
				frames.append(int(f) - start)  # sheet -> emitted index
			var pos := Vector2(row["pos"][0], row["pos"][1])
			var type: String = row["type"]
			if row.get("mode", "burst") == "sustained":
				var node := _spawn(type)
				if node != null:
					add_child(node)
					node.emitting = false
					_sustained.append({
						"node": node, "anim": anim, "frames": frames, "pos": pos,
					})
			else:
				_bursts.append({
					"anim": anim, "frames": frames, "pos": pos, "type": type,
				})
	_refresh()


func _sheet_start(anim: String) -> int:
	var sf := _sprite.sprite_frames
	if sf != null and sf.has_meta("sheet_start"):
		return int(sf.get_meta("sheet_start").get(anim, 0))
	return 0


func _spawn(type: String) -> CPUParticles2D:
	var path := PARTICLE_PATH % type
	if not ResourceLoader.exists(path):
		push_warning("ParticleDirector: no particle scene at %s" % path)
		return null
	return (load(path) as PackedScene).instantiate() as CPUParticles2D


# Facing right -> +1, left -> -1. flip_h is set from facing in the player.
func _mirror() -> float:
	return -1.0 if _sprite.flip_h else 1.0


func _refresh() -> void:
	var anim := String(_sprite.animation)
	var frame := _sprite.frame
	var m := _mirror()

	for entry in _sustained:
		var on: bool = entry.anim == anim and entry.frames.has(frame)
		entry.node.position = Vector2(entry.pos.x * m, entry.pos.y)
		entry.node.emitting = on

	# A frame_changed into a burst frame fires one shot; a looping burst frame
	# re-fires each pass, which is the intent.
	for b in _bursts:
		if b.anim == anim and b.frames.has(frame):
			_fire_burst(b, m)


func _fire_burst(b: Dictionary, m: float) -> void:
	var node := _spawn(b.type)
	if node == null:
		return
	node.position = Vector2(b.pos.x * m, b.pos.y)
	node.one_shot = true
	node.emitting = true
	add_child(node)
	# Free once the burst has finished emitting and its particles have died.
	node.finished.connect(node.queue_free)


func _process(_delta: float) -> void:
	# Keep sustained emitters on the correct side as facing flips mid-animation.
	if _sustained.is_empty():
		return
	var m := _mirror()
	for entry in _sustained:
		entry.node.position = Vector2(entry.pos.x * m, entry.pos.y)
