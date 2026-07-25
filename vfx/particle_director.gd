class_name ParticleDirector
extends Node2D

## Spawns 2D particle effects at authored positions during authored animation
## frames, so VFX can be layered over the drawn sprites (e.g. embers on Wayna's
## flame) without baking them in.
##
## Config: res://vfx/emitters.json, keyed
##   character -> animation -> [ { type, mode, frames, pos } ]
## - type   : a scene name under particles/<type>.tscn. Its root may be a single
##            CPUParticles2D/GPUParticles2D, OR a Node2D bundling several of them
##            as one attack (all are driven together). List several {…} to layer
##            separate scenes instead.
## - mode   : "sustained" (emit while any listed frame is showing) or
##            "burst" (spawn a one-shot each time a listed frame is entered)
## - frames : SHEET-relative indices (same numbering as loop_from / hit_frames;
##            the idle-reference frame counts). Converted to emitted indices via
##            the SpriteFrames `sheet_start` metadata. Or the string "all" ->
##            every frame of the animation.
## - pos    : [x, y] pixel offset from the sprite origin (the feet), for facing
##            right; mirrored automatically when facing left. A composite (Node2D)
##            root mirrors by flipping scale.x, so its child textures flip too;
##            a single particle root mirrors direction/gravity, keeping its texture.
##
## The director is a child of the player; emitter scenes use local_coords=false
## so their particles trail in world space as the player moves. Add a new effect
## by dropping a scene in particles/ and an entry in the JSON -- no code changes.

const CONFIG_PATH := "res://vfx/emitters.json"
const PARTICLE_DIR := "res://vfx/particles"

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
			var frames := _frames_for(anim, row.get("frames", []), start)
			var pos := Vector2(row["pos"][0], row["pos"][1])
			var type: String = row["type"]
			var boost: Dictionary = row.get("boost", {})
			if row.get("mode", "burst") == "sustained":
				var node := _spawn(type)
				if node != null:
					var emitters := _emitters_of(node)
					for em in emitters:
						_boost(em, boost)
						em.emitting = false
					add_child(node)
					_sustained.append({
						"node": node, "emitters": emitters, "anim": anim,
						"frames": frames, "pos": pos, "base": _capture(node),
					})
			else:
				_bursts.append({
					"anim": anim, "frames": frames, "pos": pos, "type": type,
					"boost": boost,
				})
	_refresh()


## Emitted frame indices an emitter listens on. `raw` is either an array of
## sheet-relative indices (converted to emitted by subtracting `start`), or the
## string "all" -> every emitted frame of the animation, so you don't have to list
## them or track the frame count.
func _frames_for(anim: String, raw: Variant, start: int) -> Array[int]:
	var out: Array[int] = []
	if raw is String and String(raw) == "all":
		var sf := _sprite.sprite_frames
		var anim_name := StringName(anim)
		if sf != null and sf.has_animation(anim_name):
			for e in sf.get_frame_count(anim_name):
				out.append(e)
	else:
		for f in raw:
			out.append(int(f) - start)
	return out


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


## Spawn an effect scene. Its root may be a single CPUParticles2D/GPUParticles2D,
## OR a Node2D grouping several of them (a composite attack). Rejected only if it
## holds no particle emitters at all.
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
	if _emitters_of(node).is_empty():
		push_warning("ParticleDirector: %s has no CPUParticles2D/GPUParticles2D " % path
			+ "(as its root or a child), got %s" % node.get_class())
		node.queue_free()
		return null
	return node


## Every particle emitter in a spawned effect: the node itself if it is one, plus
## any under it -- so a Node2D can bundle several particles as one attack, and the
## director drives them all together.
func _emitters_of(root: Node) -> Array:
	var out: Array = []
	if root is CPUParticles2D or root is GPUParticles2D:
		out.append(root)
	out.append_array(root.find_children("*", "CPUParticles2D", true, false))
	out.append_array(root.find_children("*", "GPUParticles2D", true, false))
	return out


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
		for em in entry.emitters:
			em.emitting = on

	# A frame_changed into a burst frame fires one shot; a looping burst frame
	# re-fires each pass, which is the intent.
	for b in _bursts:
		if b.anim == anim and b.frames.has(frame):
			_fire_burst(b, m)


func _fire_burst(b: Dictionary, m: float) -> void:
	var node := _spawn(b.type)
	if node == null:
		return
	var emitters := _emitters_of(node)
	_face(node, _capture(node), b.pos, m)
	for em in emitters:
		_boost(em, b.get("boost", {}))
		em.one_shot = true
		em.emitting = true
	add_child(node)
	# Free the effect once every emitter has finished (a composite has several).
	_free_when_done(node, emitters)


## Free `root` once all its one-shot emitters have emitted and their particles
## have died.
func _free_when_done(root: Node, emitters: Array) -> void:
	var left := [emitters.size()]  # boxed so the bound handler can count down
	for em in emitters:
		em.finished.connect(_on_emitter_finished.bind(left, root))


func _on_emitter_finished(left: Array, root: Node) -> void:
	left[0] -= 1
	if left[0] <= 0 and is_instance_valid(root):
		root.queue_free()


func _process(_delta: float) -> void:
	# Keep sustained emitters mirrored as facing flips mid-animation.
	if _sustained.is_empty():
		return
	var m := _mirror()
	for entry in _sustained:
		_face(entry.node, entry.base, entry.pos, m)
