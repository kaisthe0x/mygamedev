class_name ParticleDirector
extends Node2D

## Spawns 2D particle effects at authored positions during authored animation
## frames, so VFX can be layered over the drawn sprites (e.g. embers over a character's
## flame) without baking them in.
##
## Config: Emitters (vfx/config/emitters*.gd -- GDScript, not JSON), the CHARACTER table keyed
##   id -> animation -> [ { scene, mode, frames, pos } ]
## - scene  : the PACKED SCENE to emit, preload()ed in the table -- so a bad path is a PARSE
##            error and every effect is resident before the game runs (no runtime load). Its
##            root may be a single CPUParticles2D/GPUParticles2D, a Node2D bundling several as
##            one attack, a Projectile, or a FlashEffect (a drawn slash).
## - mode   : "sustained" (emit while any listed frame is showing) or
##            "burst" (spawn a one-shot each time a listed frame is entered)
## - frames : SHEET-relative indices (same numbering as loop_from / hit_frames;
##            the idle-reference frame counts). Converted to emitted indices via
##            the SpriteFrames `sheet_start` metadata. Or the string "all" ->
##            every frame of the animation.
## - pos    : an offset (Vector2) from the sprite origin (the feet), for facing right; mirrored
##            automatically when facing left. A composite (Node2D) root mirrors by flipping
##            scale.x, so its child textures flip too; a single particle root mirrors
##            direction/gravity, keeping its texture.
## - node/set/boost/clip_to_ground : optional (see Emitters + the row handlers below).
##
## The director is a child of the player; emitter scenes use local_coords=false so their
## particles trail in world space as the player moves. Add a new effect by dropping a scene
## under vfx/character/<id>/ and a preload row in EmittersCharacters -- no code changes.

var _sprite: AnimatedSprite2D
## One entry per sustained config row: {node, anim, frames: Array[int], pos}.
var _sustained: Array[Dictionary] = []
## One entry per burst config row: {anim, frames: Array[int], pos, scene}.
var _bursts: Array[Dictionary] = []


## Wire the director to a player sprite: watch the sprite's frame/animation changes to drive
## effects. Call once, then set_character(). The emitter config is Emitters (preloaded GDScript,
## no JSON, no runtime load) -- see vfx/config/emitters*.gd.
func setup(sprite: AnimatedSprite2D) -> void:
	_sprite = sprite
	_sprite.frame_changed.connect(_refresh)
	_sprite.animation_changed.connect(_refresh)


## Rebuild the emitter set for a character. Called when the player swaps.
func set_character(id: String) -> void:
	for entry in _sustained:
		entry.node.queue_free()
	_sustained.clear()
	_bursts.clear()

	var by_anim := Emitters.character(id)
	for anim in by_anim:
		if not (by_anim[anim] is Array):
			continue
		var start := _sheet_start(anim)
		for row: Dictionary in by_anim[anim]:
			var frames := _frames_for(anim, row.get("frames", []), start)
			var pos := row["pos"] as Vector2
			var scene: PackedScene = row["scene"]
			var boost: Dictionary = row.get("boost", {})
			if row.get("mode", "burst") == "sustained":
				var node := _spawn(scene, row.get("node", ""))
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
					"anim": anim, "frames": frames, "pos": pos, "scene": scene,
					"node": row.get("node", ""), "set": row.get("set", {}),
					"boost": boost, "clip_to_ground": row.get("clip_to_ground", false),
					"sfx": row.get("sfx", ""),  # optional per-frame sound, played in sync with the burst
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


## Instantiate an effect from its preloaded scene (from Emitters). Its root may be a single
## CPUParticles2D/GPUParticles2D, OR a Node2D grouping several of them (a composite attack).
##
## `node_name` addresses ONE named child of a "palette" scene -- a scene that bundles several
## independently-scheduled emitters (e.g. attack_finger_guns holds a `Shot` and a `ShotLast`,
## each fired on its own frames). We instantiate the palette, lift the named child out on its
## own, and drop the rest -- so listing the same palette `scene` with different `node`s fires
## different children at different frames. Empty node_name = the whole scene.
##
## Rejected only if it holds no particle emitters AND isn't a self-visual object: a Projectile
## (which can carry an AnimatedSprite2D playing a drawn frame animation) or a FlashEffect (a
## drawn slash that mirrors + frees itself). Those manage their own look.
func _spawn(scene: PackedScene, node_name := "") -> Node2D:
	if scene == null:
		return null
	var root := scene.instantiate()
	var node := root as Node2D
	if node_name != "":
		var child := root.get_node_or_null(NodePath(node_name)) as Node2D
		if child == null:
			push_warning("ParticleDirector: palette %s has no child '%s'" % [scene.resource_path, node_name])
			root.queue_free()
			return null
		root.remove_child(child)
		child.owner = null  # was owned by the palette root we're about to drop
		root.queue_free()
		node = child
	if _emitters_of(node).is_empty() and not (node is Projectile) and not (node is Strike):
		var where := scene.resource_path if node_name == "" else "%s -> %s" % [scene.resource_path, node_name]
		push_warning("ParticleDirector: %s has no CPUParticles2D/GPUParticles2D " % where
			+ "(as its root or a child) and is not a Projectile/Strike, got %s" % node.get_class())
		node.queue_free()
		return null
	return node


## Pull any node named "Trail" out of a dropped effect and parent it onto the DIRECTOR (a child of
## the player), so it FOLLOWS him -- a dash trail/aura -- instead of lingering at the drop point like
## the rest of the effect. Each is mirrored to facing, emitted as a brief one-shot, and freed once its
## particles finish. Convention: name a node "Trail" to make it follow; everything else lingers. This
## is per-node behaviour, so one effect scene can mix a following trail with a lingering hazard.
func _spawn_followers(root: Node2D, m: float) -> void:
	for child in root.get_children():
		if String(child.name) != "Trail":
			continue
		var f := child as Node2D
		if f == null:
			continue
		var authored := f.position  # its offset relative to the body
		root.remove_child(f)
		f.owner = null
		add_child(f)  # onto the director -> it tracks the player
		_face(f, _capture(f), authored, m)
		var ems := _emitters_of(f)
		for em in ems:
			em.one_shot = true  # a brief trail: emit the pool once as the dash moves, then stop + free
			em.emitting = true
		_free_when_done(f, ems)


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


## Feed the player's currently-resolved hit tuning (from moves.gd via resolve_tuning)
## into an attack effect's Hitbox(es), so combat numbers live in code, not baked in the
## scene. A Strike/Projectile takes the whole dict via apply_tuning (a Strike also does
## lunge/armor/multi-hit); a plain composite gets its box fields set directly. Empty
## tuning (no attack in progress, or a move that carries its own scene numbers) = no-op,
## so the box keeps its authored values.
func _inject_tuning(node: Node2D, hitboxes: Array) -> void:
	var atk := _attacker()
	if atk == null or not atk.has_method("active_hit"):
		return
	var hit: Dictionary = atk.active_hit()
	if hit.is_empty():
		return
	if node.has_method("apply_tuning"):
		node.apply_tuning(hit, atk)
		return
	for hb in hitboxes:
		if hit.has("damage"):
			hb.damage = hit["damage"]
		# Multiplier applied over the hitbox's own baked damage (the slam scales BOTH its
		# boxes by plunge height this way, keeping their reach/impact ratio -- see
		# Player._slam_release). Runs after `damage` so an explicit value can still be set.
		if hit.has("damage_scale"):
			hb.damage *= hit["damage_scale"]
		if hit.has("knockback"):
			hb.knockback = hit["knockback"]
		if hit.has("stun"):
			hb.stun = hit["stun"]
		if hit.has("color"):
			hb.status_color = hit["color"]
			hb.status_time = hit.get("color_time", hit.get("stun", 0.0))


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
	# The authored (right-facing) root rotation, so the scale.x mirror below can also
	# mirror the rotation. Without it, flipping scale.x reflects across the node's OWN
	# tilted axis instead of world-vertical, so any child rotation stops cancelling and
	# the whole effect skews (e.g. a rotated hitbox angling down when facing left).
	return {"rot": node.rotation}


## Mirror the whole effect horizontally, not just its position: emission
## direction and gravity are authored pointing one way and would otherwise keep
## pointing that way when the character turns around.
func _face(node: Node2D, base: Dictionary, pos: Vector2, m: float) -> void:
	node.position = Vector2(pos.x * m, pos.y)
	if node is Projectile:
		# A Projectile reads scale.x in _ready to pick its travel direction, then normalises
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
		# emission velocity. Mirror the authored rotation too (negate for a left flip) so
		# the reflection is across world-vertical, not the node's own tilted axis --
		# otherwise a rotated root skews when flipped (idempotent: base.rot is authored).
		node.scale.x = m
		node.rotation = float(base.get("rot", node.rotation)) * m


func _refresh() -> void:
	var anim := String(_sprite.animation)
	var frame := _sprite.frame
	var m := _mirror()

	for entry in _sustained:
		if not is_instance_valid(entry.node):
			continue  # a self-freeing effect (Strike/Projectile) shouldn't be sustained,
			# but guard anyway so a freed node never reaches _face
		var on: bool = entry.anim == anim and entry.frames.has(frame)
		_face(entry.node, entry.base, entry.pos, m)
		for em in entry.emitters:
			em.emitting = on
		# Switch any damage hitbox on/off with the emit window -- once per entry so
		# the box arms fresh each strike (a Hitbox dedupes hits per activation).
		if on != entry.active:
			if on:
				_inject_tuning(entry.node, entry.hitboxes)  # feed moves.gd numbers on arm
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
## `tilt` (radians) rotates the spawned burst so its emission leans -- e.g. the double
## jump tilts its exhaust opposite to horizontal travel. 0 = no tilt (the default).
func fire_effect(anim: String, tilt: float = 0.0) -> void:
	var m := _mirror()
	for b in _bursts:
		if b.anim == anim:
			_fire_burst(b, m, tilt)


func _fire_burst(b: Dictionary, m: float, tilt: float = 0.0) -> void:
	var node := _spawn(b.scene, b.get("node", ""))
	if node == null:
		return
	_apply_overrides(node, b.get("set", {}))
	# A LobProjectile-rooted effect (a lobbed bomb) is thrown, not stamped: it arcs to the nearest
	# enemy and manages its own explosion. Launch it and bail out of the normal burst flow.
	if node is LobProjectile:
		_launch_lob(node as LobProjectile, b, m)
		return
	# Follow convention: any "Trail" node tracks the PLAYER (a dash trail) instead of lingering at
	# the drop point. Pulled out onto the director before the rest is stamped in the world.
	_spawn_followers(node, m)
	var emitters := _emitters_of(node)
	# A trail-ONLY effect (e.g. the default dash) has nothing left to stamp after its Trail followed --
	# its root is now empty, so free it instead of leaking an empty node.
	if emitters.is_empty() and _hitboxes_of(node).is_empty() and not (node is Projectile or node is Strike):
		node.queue_free()
		return
	_face(node, _capture(node), b.pos, m)
	# Optional lean: rotate the whole burst so its emission tilts (e.g. the double-jump
	# exhaust angling opposite to travel). World gravity still pulls particles down.
	if not is_zero_approx(tilt):
		node.rotation += tilt
	for em in emitters:
		_boost(em, b.get("boost", {}))
	# A Strike with emit_duration > 0 emits CONTINUOUSLY for that long (a held stream,
	# e.g. a burning field); anything else is a one-shot burst. Set below, after placement.
	var emit_dur: float = node.emit_duration if node is Strike else 0.0
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
	if b.get("sfx", "") != "":
		Sfx.play_at(b.sfx, target)  # optional per-frame hit sound, in sync with this burst
	var hitboxes := _hitboxes_of(node)
	# Keep a ground blast from spilling past the platform edge into open air: clip
	# its emission band and hitbox to the surface underfoot before it fires.
	if b.get("clip_to_ground", false):
		_clip_to_ground(node, emitters, hitboxes)
	# Emit + arm now that the geometry is final. Arming is after add_child so
	# Hitbox._ready() (which starts it disabled) has already run. A one-shot burst emits
	# its pool once; a timed emission keeps going and is switched off after emit_dur.
	for em in emitters:
		em.one_shot = emit_dur <= 0.0
		em.emitting = true
		if emit_dur > 0.0:
			get_tree().create_timer(emit_dur).timeout.connect(func() -> void:
				if is_instance_valid(em):
					em.emitting = false)
	_inject_tuning(node, hitboxes)  # feed moves.gd numbers before the box goes live
	for hb in hitboxes:
		hb.source = _attacker()
		hb.activate()
	# A Projectile flies off and a Strike fades itself out -- both manage their own
	# life; everything else is freed once its one-shot emitters finish and particles die.
	if not (node is Projectile) and not (node is Strike):
		_free_when_done(node, emitters)


## Throw a player LobProjectile: aim it at the nearest enemy (a short forward toss if none),
## feed its blast the move's damage (from moves.gd, like every other hitbox), and let it fly. The
## bomb self-manages arc -> dwell -> explode; hostile stays false so it hurts enemies, not us.
func _launch_lob(lob: LobProjectile, b: Dictionary, m: float) -> void:
	var atk := _attacker()
	lob.source = atk
	if atk != null and atk.has_method("active_hit"):
		var hit: Dictionary = atk.active_hit()
		if hit.has("damage"):
			lob.explosion_damage = hit["damage"]
		if hit.has("knockback"):
			lob.explosion_knockback = hit["knockback"]
		if hit.has("stun"):
			lob.explosion_stun = hit["stun"]
	var muzzle := global_position + Vector2(b.pos.x * m, b.pos.y)
	lob.target = _nearest_enemy_pos(muzzle, m)
	var world := _world()
	if world != null:
		world.add_child(lob)
	else:
		add_child(lob)
	Nodes.place_at(lob, muzzle)  # snap to the throwing point; _launch solves the arc next tick


## World position of the nearest enemy to `from`, or a short toss ahead (facing `m`) if there are
## none -- so bburn always goes somewhere sensible.
func _nearest_enemy_pos(from: Vector2, m: float) -> Vector2:
	var best := Vector2.INF
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node2D:
			var d := from.distance_squared_to((e as Node2D).global_position)
			if d < best_d:
				best_d = d
				best = (e as Node2D).global_position
	return best if best != Vector2.INF else from + Vector2(120.0 * m, 20.0)


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
		if is_instance_valid(entry.node):
			_face(entry.node, entry.base, entry.pos, m)
