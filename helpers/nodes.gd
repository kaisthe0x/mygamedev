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
