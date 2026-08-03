class_name Nodes
extends RefCounted

## Small node-tree utilities shared across the codebase: gathering children of a
## type (particles, hitboxes, lines, colliders) and snapping a node to a world
## position without physics-interpolation smear. Static and dependency-free.


## Every node of native class `type` under `root` (plus `root` itself when it
## matches and `include_root` is true). `type` must be a native class name
## (e.g. "CPUParticles2D", "Area2D", "Line2D", "CollisionShape2D") -- for a
## script class, pass its native base and filter the result with `is`.
static func find_all(root: Node, type: String, include_root := true) -> Array:
	var out: Array = []
	if include_root and root.is_class(type):
		out.append(root)
	out.append_array(root.find_children("*", type, true, false))
	return out


## The first node of native class `type` under `root`, or null. Searches
## descendants only (not `root` itself).
static func find_first(root: Node, type: String) -> Node:
	var hits := root.find_children("*", type, true, false)
	return hits[0] if not hits.is_empty() else null


## Move `node` to a world position and clear its interpolation, so it snaps there
## instead of smearing in from wherever it was (physics interpolation is on, so a
## freshly placed or teleported node would otherwise streak across the level).
static func place_at(node: Node2D, pos: Vector2) -> void:
	node.global_position = pos
	node.reset_physics_interpolation()


## Gracefully retire a particle node (e.g. an enemy's trail) so it DISSIPATES instead of
## popping. Re-parents it into `into` (keeping its world position) so it OUTLIVES its former
## owner -- otherwise, when the owner frees, the child emitter and its still-airborne particles
## vanish with it. Then stops emission and frees it once the live particles finish their
## lifetime. `node`'s own class counts, so a node that IS a CPUParticles2D works too. Frees
## immediately if there are no emitters (or no tree to time on).
static func retire_particles(node: Node2D, into: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var tree := node.get_tree()
	if into != null and is_instance_valid(into) and node.get_parent() != into:
		var gpos := node.global_position
		node.get_parent().remove_child(node)
		into.add_child(node)
		node.global_position = gpos
	var linger := 0.0
	for e in find_all(node, "CPUParticles2D", true):
		var em := e as CPUParticles2D
		em.emitting = false
		linger = maxf(linger, em.lifetime * (1.0 + em.lifetime_randomness))
	for e in find_all(node, "GPUParticles2D", true):
		var em := e as GPUParticles2D
		em.emitting = false
		linger = maxf(linger, em.lifetime)
	if linger <= 0.0 or tree == null:
		node.queue_free()
	else:
		tree.create_timer(linger).timeout.connect(node.queue_free)
