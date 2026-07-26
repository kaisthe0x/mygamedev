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


## Where a `type` can live, most specific first. A type containing "/" is taken as
## an explicit path under particles/ (e.g. "environment/water"). Otherwise: move
## effects are grouped into the character's attacks/ or specials/ subfolder (matched
## by the type's `attack`/`special` prefix); everything else (auras, boosts) sits in
## the character's own folder, then shared/, then the flat particles/ fallback.
func _candidates(type: String) -> Array[String]:
	if "/" in type:
		return ["%s/%s.tscn" % [PARTICLE_DIR, type]]
	var out: Array[String] = []
	if type.begins_with("attack"):
		out.append("%s/characters/%s/attacks/%s.tscn" % [PARTICLE_DIR, _character, type])
	elif type.begins_with("special"):
		out.append("%s/characters/%s/specials/%s.tscn" % [PARTICLE_DIR, _character, type])
	out.append("%s/characters/%s/%s.tscn" % [PARTICLE_DIR, _character, type])
	out.append("%s/shared/%s.tscn" % [PARTICLE_DIR, type])
	out.append("%s/%s.tscn" % [PARTICLE_DIR, type])
	return out


## Spawn an effect scene. Its root may be a single CPUParticles2D/GPUParticles2D,
## OR a Node2D grouping several of them (a composite attack).
##
## `node_name` addresses ONE named child of a "palette" scene -- a scene that bundles
## several independently-scheduled emitters (e.g. attack_finger_guns holds a `Shot`
## and a `ShotLast`, each fired on its own frames). We instantiate the palette, lift
## the named child out on its own, and drop the rest -- so listing the same palette
## `type` with different `node`s fires different children at different frames. Empty
## node_name = the whole scene (single or composite), as before.
##
## Rejected only if it holds no particle emitters AND isn't a LaserBeam (whose look
## is Line2D-based, not particles, but which the director still fires like a burst).
func _spawn(type: String, node_name := "") -> Node2D:
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
	if _emitters_of(node).is_empty() and not (node is LaserBeam):
		var where := path if node_name == "" else "%s -> %s" % [path, node_name]
		push_warning("ParticleDirector: %s has no CPUParticles2D/GPUParticles2D " % where
			+ "(as its root or a child) and is not a LaserBeam, got %s" % node.get_class())
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


func _fire_burst(b: Dictionary, m: float) -> void:
	var node := _spawn(b.type, b.get("node", ""))
	if node == null:
		return
	_apply_overrides(node, b.get("set", {}))
	var emitters := _emitters_of(node)
	# A LaserBeam orients itself from the fire() direction, so DON'T mirror its scale
	# here (that would double-flip); every other burst mirrors direction/scale now,
	# world position below.
	if not (node is LaserBeam):
		_face(node, _capture(node), b.pos, m)
	for em in emitters:
		_boost(em, b.get("boost", {}))
		em.one_shot = true
	# A burst is a one-shot blast that belongs at the spot it fires -- NOT stuck to
	# the player. Parented under him, the emitter and its hitbox would follow as he
	# walks and hit enemies away from the blast. Anchor it in the world at the strike
	# point instead (like the laser), so it stays put once fired.
	var target := global_position + Vector2(b.pos.x * m, b.pos.y)
	var world := _world()
	if world != null:
		world.add_child(node)
	else:
		add_child(node)
	Nodes.place_at(node, target)  # snap to the strike point without interpolation smear
	# A laser fires and forgets: it arms its own hitbox, flashes, and frees itself.
	# The director just aims it down the facing and credits the attacker.
	if node is LaserBeam:
		var beam := node as LaserBeam
		beam.source = _attacker()
		beam.fire(Vector2(m, 0.0))
		return
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
	# A Shot flies off and manages its own life (frees on hit / at range); everything
	# else is freed once its one-shot emitters finish and their particles die.
	if not (node is Shot):
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
