class_name ParticleDirector
extends Node2D

## Spawns 2D particle effects at authored positions during authored animation
## frames, so VFX can be layered over the drawn sprites (e.g. embers on Wayna's
## flame) without baking them in.
##
## Config: res://vfx/config/emitters.json, keyed
##   character -> animation -> [ { type, mode, frames, pos } ]
## - type   : a scene's BASENAME (without .tscn). It's resolved by recursively
##            indexing vfx/character/<character>/ (any nesting -- attack/chainsaw/,
##            dash/default/, other/, ...) plus the global vfx/shared/, so a type
##            resolves wherever it's filed with no hardcoded folder list. Its root
##            may be a single CPUParticles2D/GPUParticles2D, a Node2D bundling
##            several as one attack, a Shot, or a FlashEffect (a drawn slash).
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
## by dropping a scene anywhere under vfx/character/<character>/ and an entry in
## the JSON -- no code changes.

const CONFIG_PATH := "res://vfx/config/emitters.json"
## Roots the scene index. A character's own effects live under CHARACTER_DIR/<id>/;
## cross-character building blocks live under SHARED_DIR.
const CHARACTER_DIR := "res://vfx/character"
const SHARED_DIR := "res://vfx/shared"

var _sprite: AnimatedSprite2D
var _config: Dictionary = {}
## Current character id; scopes where a particle `type` is looked up.
var _character: String = ""
## Effect basename -> scene res:// path, rebuilt per character (see _build_index).
var _index: Dictionary = {}
## One entry per sustained config row: {node, anim, frames: Array[int], pos}.
var _sustained: Array[Dictionary] = []
## One entry per burst config row: {anim, frames: Array[int], pos, type}.
var _bursts: Array[Dictionary] = []


## Wire the director to a player sprite: load emitters.json and watch the sprite's
## frame/animation changes to drive effects. Call once, then set_character().
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
	_build_index()
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
				var node := _spawn(type, row.get("node", ""))
				if node != null:
					_apply_overrides(node, row.get("set", {}))
					var emitters := _emitters_of(node)
					for em in emitters:
						_boost(em, boost)
						em.emitting = false
					add_child(node)
					var hitboxes := _hitboxes_of(node)
					for hb in hitboxes:
						hb.source = _attacker()
					_sustained.append({
						"node": node, "emitters": emitters, "anim": anim,
						"frames": frames, "pos": pos, "base": _capture(node),
						"hitboxes": hitboxes, "active": false,
					})
			else:
				_bursts.append({
					"anim": anim, "frames": frames, "pos": pos, "type": type,
					"node": row.get("node", ""), "set": row.get("set", {}),
					"boost": boost, "clip_to_ground": row.get("clip_to_ground", false),
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


## Build a basename -> scene-path index for the current character by recursively
## walking vfx/character/<id>/ (any nesting: attack/chainsaw/, dash/default/,
## other/, ...) plus the global vfx/shared/. An emitters.json `type` is just a
## scene's basename, so it resolves wherever it's filed -- there's no folder list
## to keep in sync as the layout grows.
func _build_index() -> void:
	_index.clear()
	_index_dir("%s/%s" % [CHARACTER_DIR, _character])
	_index_dir(SHARED_DIR)


func _index_dir(dir_path: String) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := dir_path.path_join(entry)
			if d.current_is_dir():
				_index_dir(full)
			elif entry.ends_with(".tscn") or entry.ends_with(".tscn.remap"):
				# Exported builds ship "<name>.tscn.remap" instead of the raw .tscn.
				var scene := entry.trim_suffix(".remap")
				var stem := scene.trim_suffix(".tscn")
				var res_path := dir_path.path_join(scene)
				if _index.has(stem) and _index[stem] != res_path:
					push_warning("ParticleDirector: two effects named '%s' (%s and %s); using the first"
						% [stem, _index[stem], res_path])
				else:
					_index[stem] = res_path
		entry = d.get_next()
	d.list_dir_end()


## Spawn an effect scene by its indexed basename. Its root may be a single
## CPUParticles2D/GPUParticles2D, OR a Node2D grouping several of them (a composite
## attack).
##
## `node_name` addresses ONE named child of a "palette" scene -- a scene that bundles
## several independently-scheduled emitters (e.g. attack_finger_guns holds a `Shot`
## and a `ShotLast`, each fired on its own frames). We instantiate the palette, lift
## the named child out on its own, and drop the rest -- so listing the same palette
## `type` with different `node`s fires different children at different frames. Empty
## node_name = the whole scene (single or composite), as before.
##
## Rejected only if it holds no particle emitters AND isn't a self-visual object:
## a Shot (which can carry an AnimatedSprite2D playing a drawn frame animation) or a
## FlashEffect (a drawn slash that mirrors + frees itself). Those manage their own look.
func _spawn(type: String, node_name := "") -> Node2D:
	var path: String = _index.get(type, "")
	if path.is_empty():
		push_warning("ParticleDirector: no scene named '%s.tscn' under %s/%s or %s"
			% [type, CHARACTER_DIR, _character, SHARED_DIR])
		return null
	var root := (load(path) as PackedScene).instantiate()
	var node := root as Node2D
	if node_name != "":
		var child := root.get_node_or_null(NodePath(node_name)) as Node2D
		if child == null:
			push_warning("ParticleDirector: palette %s has no child '%s'" % [path, node_name])
			root.queue_free()
			return null
		root.remove_child(child)
		child.owner = null  # was owned by the palette root we're about to drop
		root.queue_free()
		node = child
	if _emitters_of(node).is_empty() and not (node is Shot) and not (node is FlashEffect):
		var where := path if node_name == "" else "%s -> %s" % [path, node_name]
		push_warning("ParticleDirector: %s has no CPUParticles2D/GPUParticles2D " % where
			+ "(as its root or a child) and is not a Shot/FlashEffect, got %s" % node.get_class())
		node.queue_free()
		return null
	return node


## Every particle emitter in a spawned effect: the node itself if it is one, plus
## any under it -- so a Node2D can bundle several particles as one attack, and the
## director drives them all together.
func _emitters_of(root: Node) -> Array:
	var out := Nodes.find_all(root, "CPUParticles2D")
	out.append_array(Nodes.find_all(root, "GPUParticles2D"))
	return out


## Every damage Hitbox in a spawned effect (its root if it is one, plus any under
## it). Lets an attack effect carry its own hand-authored hitbox -- shape and
## damage are set in the editor; the director just arms it in sync with the emit.
func _hitboxes_of(root: Node) -> Array:
	var out: Array = []
	if root is Hitbox:
		out.append(root)
	for a in Nodes.find_all(root, "Area2D", false):
		if a is Hitbox:
			out.append(a)
	return out


## The node effects credit as the attacker (so knockback shoves away from it). The
## director is a child of the player, so that's our parent.
func _attacker() -> Node:
	return get_parent()


## Where world-anchored bursts are parented so they stay put instead of following
## the player. The director is the player's child, so this is the level above him.
func _world() -> Node:
	var p := get_parent()
	return p.get_parent() if p != null else null


# Facing right -> +1, left -> -1. flip_h is set from facing in the player.
func _mirror() -> float:
	return -1.0 if _sprite.flip_h else 1.0


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
		MathUtil.scale_min_max_pair(node, &"initial_velocity_min", &"initial_velocity_max",
			float(boost.get("speed", 1.0)))
		MathUtil.scale_min_max_pair(node, &"scale_amount_min", &"scale_amount_max",
			float(boost.get("scale", 1.0)))
	elif boost.has("speed") or boost.has("scale"):
		push_warning("ParticleDirector: 'speed'/'scale' boost needs a "
			+ "CPUParticles2D (GPUParticles2D keeps those on a shared material)")


## Per-row property overrides, so one shared scene covers several variants without a
## clone per tweak (e.g. a different projectile texture on the last shot). Keys are
## "ChildPath:property" -- an empty path targets the spawned node itself -- and a
## "res://..." string value is loaded as a Resource (a texture, curve, etc.). Applied
## once on spawn, before the effect is faced/placed/armed.
func _apply_overrides(node: Node2D, overrides: Dictionary) -> void:
	for key in overrides:
		var parts := String(key).rsplit(":", true, 1)
		var prop: String = parts[-1]
		var target: Node = node
		if parts.size() == 2 and parts[0] != "":
			target = node.get_node_or_null(NodePath(parts[0]))
		if target == null:
			push_warning("ParticleDirector: override '%s' -- no such child" % key)
			continue
		var value: Variant = overrides[key]
		if value is String and (value as String).begins_with("res://"):
			value = load(value)
		target.set(prop, value)


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
	if node is Shot:
		# A Shot reads scale.x in _ready to pick its travel direction, then normalises
		# it -- so facing is scale.x even when the shot's body is itself a CPUParticles2D
		# (it rotates to _dir, so the particle direction/gravity mirror below is moot).
		node.scale.x = m
	elif node is CPUParticles2D:
		node.direction = Vector2(base.dir.x * m, base.dir.y)
		node.gravity = Vector2(base.grav.x * m, base.grav.y)
	else:
		# GPUParticles2D keeps these on a shared ParticleProcessMaterial, which we
		# must not mutate; flipping the node's scale is the safe approximation, and for
		# a composite (or a FlashEffect slash) it mirrors child positions/textures + the
		# emission velocity.
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
		# Switch any damage hitbox on/off with the emit window -- once per entry so
		# the box arms fresh each strike (a Hitbox dedupes hits per activation).
		if on != entry.active:
			for hb in entry.hitboxes:
				if on:
					hb.activate()
				else:
					hb.deactivate()
			entry.active = on

	# A frame_changed into a burst frame fires one shot; a looping burst frame
	# re-fires each pass, which is the intent.
	for b in _bursts:
		if b.anim == anim and b.frames.has(frame):
			_fire_burst(b, m)


## Fire the burst emitters configured under `anim` right now, as a code-driven
## one-shot -- for an effect tied to an event rather than an animation frame. Give
## the effect an `anim` key that is NOT a real sprite animation (e.g. "double_jump")
## so _refresh never auto-fires it on a frame, then call this at the moment it should
## go off. Used by the double jump: only the second, airborne jump spawns particles.
func fire_effect(anim: String) -> void:
	var m := _mirror()
	for b in _bursts:
		if b.anim == anim:
			_fire_burst(b, m)


func _fire_burst(b: Dictionary, m: float) -> void:
	var node := _spawn(b.type, b.get("node", ""))
	if node == null:
		return
	_apply_overrides(node, b.get("set", {}))
	var emitters := _emitters_of(node)
	_face(node, _capture(node), b.pos, m)
	for em in emitters:
		_boost(em, b.get("boost", {}))
		em.one_shot = true
	# A burst is a one-shot blast that belongs at the spot it fires -- NOT stuck to
	# the player. Parented under him, the emitter and its hitbox would follow as he
	# walks and hit enemies away from the blast. Anchor it in the world at the strike
	# point instead, so it stays put once fired.
	var target := global_position + Vector2(b.pos.x * m, b.pos.y)
	var world := _world()
	if world != null:
		world.add_child(node)
	else:
		add_child(node)
	Nodes.place_at(node, target)  # snap to the strike point without interpolation smear
	var hitboxes := _hitboxes_of(node)
	# Keep a ground blast from spilling past the platform edge into open air: clip
	# its emission band and hitbox to the surface underfoot before it fires.
	if b.get("clip_to_ground", false):
		_clip_to_ground(node, emitters, hitboxes)
	# Emit + arm now that the geometry is final. Arming is after add_child so
	# Hitbox._ready() (which starts it disabled) has already run.
	for em in emitters:
		em.emitting = true
	for hb in hitboxes:
		hb.source = _attacker()
		hb.activate()
	# A Shot flies off and a FlashEffect fades itself out -- both manage their own life;
	# everything else is freed once its one-shot emitters finish and their particles die.
	if not (node is Shot) and not (node is FlashEffect):
		_free_when_done(node, emitters)


## The left/right world x of the surface directly under `world_pos` -- a ray down
## through L_WORLD, then the collider's rectangle bounds. Returns a fully-open
## range if there's no ground there, so a blast fired off a ledge just isn't clipped.
func _ground_edges_at(world_pos: Vector2) -> Vector2:
	if not is_inside_tree():
		return Vector2(-INF, INF)
	var space := get_world_2d().direct_space_state
	if space == null:
		return Vector2(-INF, INF)  # physics space not ready -> skip clipping
	var q := PhysicsRayQueryParameters2D.create(
		world_pos + Vector2(0, -30), world_pos + Vector2(0, 60), Combat.L_WORLD)
	var hit := space.intersect_ray(q)
	if hit.is_empty() or not (hit.collider is Node2D):
		return Vector2(-INF, INF)
	var left := INF
	var right := -INF
	for cs in Nodes.find_all(hit.collider as Node, "CollisionShape2D", false):
		if cs.shape is RectangleShape2D:
			var hw: float = (cs.shape as RectangleShape2D).size.x * 0.5 * absf(cs.global_scale.x)
			left = minf(left, cs.global_position.x - hw)
			right = maxf(right, cs.global_position.x + hw)
	return Vector2(left, right) if left <= right else Vector2(-INF, INF)


## Clip a ground blast's rectangular emission bands and hitboxes to the platform
## edges under it, so neither particles nor hits cross the ledge into open air. The
## clip is asymmetric: only the side hanging over the edge is cut, the inner side
## keeps its full reach.
func _clip_to_ground(node: Node2D, emitters: Array, hitboxes: Array) -> void:
	var edges := _ground_edges_at(node.global_position)
	if edges.x == -INF:
		return  # no ground underfoot -> leave the blast at full reach
	for em in emitters:
		if em is CPUParticles2D and em.emission_shape == CPUParticles2D.EMISSION_SHAPE_RECTANGLE:
			var sx: float = maxf(absf(em.global_scale.x), 0.001)
			var r := MathUtil.clip_band(em.global_position.x, em.emission_rect_extents.x * sx, edges.x, edges.y)
			if r.is_empty():
				em.emitting = false
				continue
			em.global_position = Vector2(r[0], em.global_position.y)
			em.emission_rect_extents = Vector2(r[1] / sx, em.emission_rect_extents.y)
	for hb in hitboxes:
		for cs in Nodes.find_all(hb, "CollisionShape2D", false):
			if cs.shape is RectangleShape2D:
				var rect: RectangleShape2D = cs.shape.duplicate()  # per-instance, don't touch the shared resource
				cs.shape = rect
				var sx: float = maxf(absf(cs.global_scale.x), 0.001)
				var r := MathUtil.clip_band(cs.global_position.x, rect.size.x * 0.5 * sx, edges.x, edges.y)
				if r.is_empty():
					hb.deactivate()
					continue
				cs.global_position = Vector2(r[0], cs.global_position.y)
				rect.size = Vector2(r[1] * 2.0 / sx, rect.size.y)


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
