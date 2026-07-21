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
const PARTICLE_DIR := "res://particles"

var _sprite: AnimatedSprite2D
var _config: Dictionary = {}
## Current character id; scopes where a particle `type` is looked up.
var _character: String = ""
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
	_character = id
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
			var boost: Dictionary = row.get("boost", {})
			if row.get("mode", "burst") == "sustained":
				var node := _spawn(type)
				if node != null:
					_boost(node, boost)
					add_child(node)
					node.emitting = false
					_sustained.append({
						"node": node, "anim": anim, "frames": frames, "pos": pos,
						"base": _capture(node),
					})
			else:
				_bursts.append({
					"anim": anim, "frames": frames, "pos": pos, "type": type,
					"boost": boost,
				})
	_refresh()


func _sheet_start(anim: String) -> int:
	var sf := _sprite.sprite_frames
	if sf != null and sf.has_meta("sheet_start"):
		return int(sf.get_meta("sheet_start").get(anim, 0))
	return 0


## Where a `type` can live, most specific first. A type containing "/" is taken
## as an explicit path under particles/ (e.g. "environment/water"); otherwise we
## look in the character's own folder, then the shared one. The bare
## particles/<type>.tscn is a legacy fallback from the flat layout.
func _candidates(type: String) -> Array[String]:
	if "/" in type:
		return ["%s/%s.tscn" % [PARTICLE_DIR, type]]
	return [
		"%s/characters/%s/%s.tscn" % [PARTICLE_DIR, _character, type],
		"%s/shared/%s.tscn" % [PARTICLE_DIR, type],
		"%s/%s.tscn" % [PARTICLE_DIR, type],
	]


## Accepts either particle node type -- both expose emitting / one_shot /
## finished, which is all the director drives.
func _spawn(type: String) -> Node2D:
	var path := ""
	var tried := _candidates(type)
	for c in tried:
		if ResourceLoader.exists(c):
			path = c
			break
	if path.is_empty():
		push_warning("ParticleDirector: no scene for type '%s'; looked in %s"
			% [type, ", ".join(tried)])
		return null
	var node := (load(path) as PackedScene).instantiate()
	if not (node is CPUParticles2D or node is GPUParticles2D):
		push_warning("ParticleDirector: %s must have a CPUParticles2D or " % path
			+ "GPUParticles2D root, got %s" % node.get_class())
		node.queue_free()
		return null
	return node


# Facing right -> +1, left -> -1. flip_h is set from facing in the player.
func _mirror() -> float:
	return -1.0 if _sprite.flip_h else 1.0


## Multiply a min/max property pair by `f`.
##
## Godot clamps these pairs against each other on assign, so multiplying each in
## turn double-applies the factor to one end (setting min above max drags max up,
## then max gets multiplied again). Writing whichever end moves outward first
## avoids the transient invalid state.
func _scale_range(node: Node2D, min_prop: StringName, max_prop: StringName,
		f: float) -> void:
	if is_equal_approx(f, 1.0):
		return
	var lo: float = float(node.get(min_prop)) * f
	var hi: float = float(node.get(max_prop)) * f
	if f >= 1.0:
		node.set(max_prop, hi)
		node.set(min_prop, lo)
	else:
		node.set(min_prop, lo)
		node.set(max_prop, hi)


## Per-entry intensity, layered on top of the shared scene, so several
## animations can reuse one particle type at different power levels without
## duplicating a scene that would then have to be re-tuned in two places.
##
## These are MULTIPLIERS on whatever the scene says, so they keep tracking the
## base as you tune it -- a dash at "speed": 1.6 stays 1.6x fiercer than the run
## no matter how the base fire changes. `explosiveness` is the exception: it's
## absolute, because multiplying the usual 0 would do nothing.
func _boost(node: Node2D, boost: Dictionary) -> void:
	if boost.is_empty():
		return
	node.amount = maxi(1, roundi(node.amount * float(boost.get("amount", 1.0))))
	node.lifetime *= float(boost.get("lifetime", 1.0))
	if boost.has("explosiveness"):
		node.explosiveness = float(boost["explosiveness"])
	if node is CPUParticles2D:
		_scale_range(node, &"initial_velocity_min", &"initial_velocity_max",
			float(boost.get("speed", 1.0)))
		_scale_range(node, &"scale_amount_min", &"scale_amount_max",
			float(boost.get("scale", 1.0)))
	elif boost.has("speed") or boost.has("scale"):
		push_warning("ParticleDirector: 'speed'/'scale' boost needs a "
			+ "CPUParticles2D (GPUParticles2D keeps those on a shared material)")


## Remember the authored direction/gravity so facing can mirror them without
## drifting (mirroring in place would accumulate).
func _capture(node: Node2D) -> Dictionary:
	if node is CPUParticles2D:
		return {"dir": node.direction, "grav": node.gravity}
	return {}


## Mirror the whole effect horizontally, not just its position: emission
## direction and gravity are authored pointing one way and would otherwise keep
## pointing that way when the character turns around.
func _face(node: Node2D, base: Dictionary, pos: Vector2, m: float) -> void:
	node.position = Vector2(pos.x * m, pos.y)
	if node is CPUParticles2D:
		node.direction = Vector2(base.dir.x * m, base.dir.y)
		node.gravity = Vector2(base.grav.x * m, base.grav.y)
	else:
		# GPUParticles2D keeps these on a shared ParticleProcessMaterial, which we
		# must not mutate; flipping the node is the safe approximation.
		node.scale.x = m


func _refresh() -> void:
	var anim := String(_sprite.animation)
	var frame := _sprite.frame
	var m := _mirror()

	for entry in _sustained:
		var on: bool = entry.anim == anim and entry.frames.has(frame)
		_face(entry.node, entry.base, entry.pos, m)
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
	_boost(node, b.get("boost", {}))
	_face(node, _capture(node), b.pos, m)
	node.one_shot = true
	node.emitting = true
	add_child(node)
	# Free once the burst has finished emitting and its particles have died.
	node.finished.connect(node.queue_free)


func _process(_delta: float) -> void:
	# Keep sustained emitters mirrored as facing flips mid-animation.
	if _sustained.is_empty():
		return
	var m := _mirror()
	for entry in _sustained:
		_face(entry.node, entry.base, entry.pos, m)
