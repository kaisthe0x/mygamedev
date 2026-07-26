class_name Shapes
extends RefCounted

## Collision-shape builders shared by everything that assembles colliders in code
## (player/enemy combat boxes, projectiles, platforms, the laser). Kept static and
## dependency-free so non-Combatant nodes can use them too.


## A rectangular CollisionShape2D of full `size`, centred at `offset`.
static func make_box(size: Vector2, offset := Vector2.ZERO) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = offset
	return shape
