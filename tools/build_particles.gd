extends SceneTree

## Builds the particle-type scenes under particles/ from code, so the many
## CPUParticles2D properties are set correctly and the .tscn stays valid. Each
## saved scene is a normal CPUParticles2D you can then tweak in the editor.
##
##   godot --headless --script tools/build_particles.gd
##
## Add a new type by adding a builder function here and listing it in _run().

const OUT := "res://particles/%s.tscn"
const PIXEL_EMBER := "res://particles/pixel_ember.png"


func _step_curve() -> Curve:
	# Chunky size steps rather than a smooth taper, so embers stay pixel-crisp.
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(0.6, 1.0))
	c.add_point(Vector2(1.0, 0.5))
	return c


# Chunky pixel embers, palette-matched to Wayna's drawn flame (yellow -> orange
# -> red). Hard-edged texture + nearest filter + normal blend so they read as
# pixel art, not a soft glow. Drift upward and trail in world space.
func fire_spark() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "FireSpark"
	p.texture = load(PIXEL_EMBER)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # keep it blocky
	# No material == normal (mix) blend: solid pixels rather than additive glow.
	p.emitting = false          # the director turns this on
	p.amount = 16
	p.lifetime = 0.55
	p.local_coords = false      # embers linger in world space so they trail
	p.explosiveness = 0.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 3.0
	p.direction = Vector2(0, -1)
	p.spread = 34.0
	p.gravity = Vector2(0, -30)  # negative Y = up: embers rise
	p.initial_velocity_min = 14.0
	p.initial_velocity_max = 40.0
	p.scale_amount_min = 0.5     # ~2-4 game px given the 5px texture
	p.scale_amount_max = 0.9
	p.scale_amount_curve = _step_curve()

	# Palette matched to her flame yellow (#f2d01d), cooling to orange/red.
	# Alpha stays solid until the end, then pops out -- no soft ghosting.
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	ramp.colors = PackedColorArray([
		Color8(255, 244, 176, 255),   # hot yellow-white
		Color8(242, 208, 29, 255),    # flame yellow
		Color8(232, 138, 26, 255),    # orange
		Color8(192, 53, 10, 0),       # red, snaps out
	])
	p.color_ramp = ramp
	return p


func _save(node: CPUParticles2D, name: String) -> void:
	var scene := PackedScene.new()
	scene.pack(node)
	var path := OUT % name
	var err := ResourceSaver.save(scene, path)
	print("  %s -> %s" % ["ok" if err == OK else "ERR %d" % err, path])


func _init() -> void:
	_save(fire_spark(), "fire_spark")
	quit()
