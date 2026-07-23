extends Area2D

## A hostile projectile fired by an enemy's ranged attack. Flies in a straight
## line, damages the first player hurtbox it hits, and frees itself on impact or
## when its life runs out. Team is enforced by layers: it lives on ENEMY_HIT and
## only scans PLAYER_HURT, so it can never hit another enemy.
##
## Kept deliberately generic -- an enemy whose "ranged" attack is really a lunge
## can ignore this and just move its own body instead.

var damage: float = 8.0
var knockback: float = 0.0
var stun: float = 0.0
var velocity: Vector2 = Vector2.ZERO
var life: float = 3.0
@export var color := Color(0.55, 1.0, 0.45)  # tints the built-in orb trail
## The look. If set (e.g. Baghel's ground_wave.tscn), it is instanced as the
## visual -- edit/preview it as a normal particle scene. If null, a simple orb
## trail is built in code (Kebus' bolt).
var visual: PackedScene = null
## Collider half-size + offset from the projectile's spawn point. A small box for
## a bolt; a tall slab (rising from the ground) for a wave.
var hitbox_extents := Vector2(5, 5)
var hitbox_offset := Vector2.ZERO
## When set (ground-surge shots), lay down red embers along the floor that stay
## put in world space as the shot rolls on, so it scorches a trail behind it. The
## colour is sampled from the `visual`, so it always matches whatever red you tint
## the wave in the editor.
var ground_trail := false

var _expiring := false


func _ready() -> void:
	add_to_group("projectiles")  # so a respawn can clear in-flight shots
	collision_layer = Combat.L_ENEMY_HIT
	collision_mask = Combat.L_PLAYER_HURT
	monitoring = true

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = hitbox_extents * 2.0
	shape.shape = rect
	shape.position = hitbox_offset
	add_child(shape)

	if visual != null:
		var v := visual.instantiate() as Node2D
		if velocity.x < 0.0:
			v.scale.x = -1.0  # authored blasting +x; mirror for a left-facing shot
		add_child(v)
		if ground_trail:
			add_child(_make_ground_trail(_sample_visual_color(v)))
	else:
		add_child(_make_trail())
	area_entered.connect(_on_area_entered)


## Pull the wave's headline colour out of its gradient so the trail matches it,
## whatever red it's been tinted to in the editor. Falls back to `color`.
func _sample_visual_color(v: Node) -> Color:
	var p := v as CPUParticles2D
	if p == null:
		p = v.find_children("*", "CPUParticles2D", true, false).front()
	if p != null and p.color_ramp != null:
		return p.color_ramp.sample(0.0)
	return color


## Red embers laid along the floor. `local_coords = false` pins them in world
## space, so as the shot rolls forward they're left behind as a scorched trail
## that lingers and fades (longer life than the crest) rather than following it.
func _make_ground_trail(tint: Color) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = load("res://particles/textures/pixel_ember.png")
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.local_coords = false
	p.amount = 40
	p.lifetime = 0.75          # outlives the crest -> the trail lingers behind
	p.lifetime_randomness = 0.3
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(4, 1)  # a thin strip hugging the ground
	p.direction = Vector2(0, -1)
	p.spread = 40.0
	p.gravity = Vector2(0, 90)  # small settle so they hold to the floor
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 26.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.1
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	ramp.colors = PackedColorArray([
		Color(tint.r, tint.g, tint.b, 1.0),
		Color(tint.r * 0.7, tint.g * 0.6, tint.b * 0.6, 0.6),
		Color(tint.r * 0.5, tint.g * 0.4, tint.b * 0.4, 0.0),  # fades to nothing
	])
	p.color_ramp = ramp
	return p


func _make_trail() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = load("res://particles/textures/pixel_ember.png")
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.local_coords = false          # embers stay put so they trail behind
	p.amount = 18
	p.lifetime = 0.35
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 2.0
	p.spread = 25.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 24.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 0.8
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	ramp.colors = PackedColorArray([color, Color(color.r, color.g, color.b, 0.0)])
	p.color_ramp = ramp
	return p


func _physics_process(delta: float) -> void:
	if _expiring:
		return  # done dealing damage; just letting the last particles fade out
	global_position += velocity * delta
	life -= delta
	if life <= 0.0:
		_expire()


func _on_area_entered(area: Area2D) -> void:
	if _expiring:
		return
	var box := area as Hurtbox
	if box == null:
		return
	var hit := Hit.new()
	hit.amount = damage
	hit.knockback = knockback
	hit.stun = stun
	hit.source = self
	box.take_hit(hit)
	_expire()


## Stop dealing damage and moving, cut off emission, and free once the last
## particles have lived out their lifetime -- so the wave fades away instead of
## popping out of existence the instant its life or a hit ends it.
func _expire() -> void:
	if _expiring:
		return
	_expiring = true
	monitoring = false
	collision_layer = 0
	velocity = Vector2.ZERO  # world-space particles stay where they were emitted
	var linger := 0.0
	for p in find_children("*", "CPUParticles2D", true, false):
		p.emitting = false
		linger = maxf(linger, p.lifetime * (1.0 + p.lifetime_randomness))
	if linger <= 0.0:
		queue_free()
		return
	get_tree().create_timer(linger).timeout.connect(queue_free)


func _draw() -> void:
	# Only the built-in orb needs a drawn core; a `visual` scene draws itself.
	if visual != null:
		return
	draw_circle(Vector2.ZERO, 4.0, color)
	draw_circle(Vector2.ZERO, 2.0, Color(1, 1, 1))
