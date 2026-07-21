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
@export var color := Color(0.55, 1.0, 0.45)  # Kebus' green staff energy


func _ready() -> void:
	collision_layer = Combat.L_ENEMY_HIT
	collision_mask = Combat.L_PLAYER_HURT
	monitoring = true

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	add_child(shape)

	add_child(_make_trail())
	area_entered.connect(_on_area_entered)


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
	global_position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	var box := area as Hurtbox
	if box == null:
		return
	var hit := Hit.new()
	hit.amount = damage
	hit.knockback = knockback
	hit.stun = stun
	hit.source = self
	box.take_hit(hit)
	queue_free()


func _draw() -> void:
	# Bright pixel core under the trail.
	draw_circle(Vector2.ZERO, 4.0, color)
	draw_circle(Vector2.ZERO, 2.0, Color(1, 1, 1))
