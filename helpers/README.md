# helpers — shared static utilities

Small, dependency-free utilities that several unrelated scripts would otherwise
reimplement. Each file is a `class_name X extends RefCounted` of **`static`**
functions, called as `X.fn(...)` (e.g. `Shapes.make_box(...)`, `Nodes.find_all(...)`).

Being static + RefCounted means any node can use them **without inheriting a base
class** — that's the whole point: a projectile (`Area2D`), the laser (`Node2D`), the
build tools, and the `Combatant` bodies all share the same box/find/place logic.

## What's here

| File | Class | Functions |
|---|---|---|
| `shapes.gd` | `Shapes` | `make_box(size, offset)` — a centered `RectangleShape2D` `CollisionShape2D`. The one box builder for combat boxes, hurtboxes, projectiles, platforms, the laser hitbox |
| `nodes.gd` | `Nodes` | `find_all(root, type, include_root)` / `find_first(root, type)` — descendants of a native class (particles, hitboxes, colliders, lines); `place_at(node, pos)` — snap to a world position **and** `reset_physics_interpolation()` so it doesn't smear in from the origin |
| `anim_meta.gd` | `AnimMeta` | `hit_frames(frames, anim)` / `loop_bound(frames, anim, key)` — read the per-animation metadata the sprite generator writes into each `SpriteFrames` (combo/strike frames, loop range) |
| `math_util.gd` | `MathUtil` | `clip_band(center, half, left, right)` — intersect a 1D band with a range (ground-clip); `scale_min_max_pair(obj, min, max, f)` — multiply a Godot min/max property pair without tripping its mutual clamp |

## Why these exist (the duplication they replaced)

Each unified a pattern the codebase had copied several times:
- **`Shapes.make_box`** ← inline `CollisionShape2D`+`RectangleShape2D` building in 5+
  places (player/enemy boxes, projectile, platform, laser).
- **`Nodes.find_all`/`find_first`** ← `find_children("*", "<Type>", true, false)` in 7
  places (particle director emitters/hitboxes/colliders, projectile, laser lines).
- **`Nodes.place_at`** ← `global_position = x; reset_physics_interpolation()` in 4
  places (respawn/camera, projectile spawn, burst spawn, beam spawn).
- **`AnimMeta.hit_frames`** ← three near-identical `has_meta("hit_frames")` reads
  (player combo + heavy strike, enemy attack timing).
- **`MathUtil.clip_band` / `scale_min_max_pair`** ← moved out of the particle director
  so they're reusable and testable in isolation.

## Adding a helper

New `helpers/<domain>.gd`, `class_name <Name> extends RefCounted`, `static func`s
with a `##` docstring each. Keep them **pure** (no scene/singleton reliance) so they
stay callable from anywhere. If a "helper" needs per-instance state or the scene
tree, it probably belongs on a node, not here.

Combat *reactions* (`apply_knockback`, `flash`, `anchor_to_feet`) still live on
`Combatant` (scripts/combat/) because only the two bodies that extend it use them.
