class_name OrbitAura
extends Node2D

## Moons orbiting the player like a little planet system -- a REAL orbit with DEPTH: each moon passes
## BEHIND the sprite at the far side of the (tilted) ellipse and IN FRONT at the near side. A single
## particle emitter can't do this -- all its particles share ONE z_index, so they'd stay flatly in
## front (or behind) the whole time. So we drive N Sprite2D "moons" in code and flip each moon's
## z_index across the crossover. `radius_y < radius_x` tilts the ring for perspective; near moons are
## bigger + brighter, far ones smaller + dimmer (the depth cue). Reusable -- any aura scene can use it.

@export var count: int = 6
@export var moon_texture: Texture2D
@export var moon_color: Color = Color(1.7, 1.35, 0.4)  ## HDR gold -> blooms; alpha is set per-frame by depth
@export var radius_x: float = 28.0
@export var radius_y: float = 11.0                     ## < radius_x -> a tilted (perspective) ring, not flat
@export var center: Vector2 = Vector2(0, -26)          ## orbit the torso (the sprite origin is the feet)
@export var speed: float = 2.6                         ## radians / second
@export var near_scale: float = 1.6                    ## moon scale at the FRONT (nearest the viewer)
@export var far_scale: float = 0.55                    ## moon scale at the BACK (farthest away)
@export var far_alpha: float = 0.4                     ## moon alpha at the back
@export var behind_z: int = -1                         ## z_index while behind the player sprite (< the sprite's 0)
@export var front_z: int = 1                           ## z_index while in front (> 0)

var _moons: Array[Sprite2D] = []
var _t: float = 0.0


func _ready() -> void:
	for i in count:
		var m := Sprite2D.new()
		m.texture = moon_texture
		add_child(m)
		_moons.append(m)
	_layout()  # seed positions so there's no one-frame pop from the origin


func _process(delta: float) -> void:
	_t += delta
	_layout()


## Place every moon on the tilted ellipse for the current time, flipping z + scaling/dimming by depth.
func _layout() -> void:
	var n := _moons.size()
	for i in n:
		var m := _moons[i]
		var ang := _t * speed + TAU * float(i) / float(n)
		var s := sin(ang)             # -1 at the far back .. +1 at the near front
		var depth := (s + 1.0) * 0.5  # 0 = back, 1 = front
		m.position = center + Vector2(cos(ang) * radius_x, s * radius_y)
		m.z_index = behind_z if s < 0.0 else front_z
		var sc := lerpf(far_scale, near_scale, depth)
		m.scale = Vector2(sc, sc)
		m.modulate = Color(moon_color.r, moon_color.g, moon_color.b, lerpf(far_alpha, 1.0, depth))
