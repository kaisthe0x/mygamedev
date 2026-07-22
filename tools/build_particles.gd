extends SceneTree

## Builds the particle-type scenes under particles/ from code, so the many
## CPUParticles2D properties are set correctly and the .tscn stays valid. Each
## saved scene is a normal CPUParticles2D you can then tweak in the editor.
##
##   godot --headless --script tools/build_particles.gd
##
## Add a new type by adding a builder function here and listing it in _run().

const OUT := "res://particles/%s.tscn"
const PIXEL_EMBER := "res://particles/textures/pixel_ember.png"


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


# Baghel's ground shockwave: a fast horizontal streak that fans out at the
# leading edge. Authored blasting +x (forward); the projectile mirrors scale.x
# for facing. `emitting = true` so it plays the moment it spawns AND previews in
# the editor. Recolour/tune it freely -- it's a normal scene.
func ground_wave() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "GroundWave"
	p.texture = load(PIXEL_EMBER)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.emitting = true
	p.amount = 80
	p.lifetime = 0.32
	p.lifetime_randomness = 0.35
	p.local_coords = false          # stays in world -> streaks as the wave surges
	p.explosiveness = 0.1
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 2.0
	p.direction = Vector2(1, 0)     # forward; projectile flips for facing
	p.spread = 34.0                 # the fan
	p.gravity = Vector2(0, 60)      # a touch of settle
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 260.0  # wide range: fast tips streak, slow ones fan
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	p.scale_amount_curve = _step_curve()
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	ramp.colors = PackedColorArray([
		Color8(255, 255, 255, 255),  # hot white core
		Color8(255, 115, 64, 255),   # bright red-orange
		Color8(199, 41, 26, 200),    # deep red
		Color8(115, 20, 13, 0),      # fades out
	])
	p.color_ramp = ramp
	return p


## Scaffold only: never clobbers an existing scene, because these get hand-tuned
## in the editor afterwards. Delete the file first if you want it regenerated.
# Wayna's dash exhaust. Deliberately NOT a scaled-up run flame: the run fire is
# a short downward jet under her feet, while the dash is a horizontal burst, so
# this blasts REARWARD (negative x = behind her; the director mirrors it when she
# turns), with wider velocity/size variance and a hotter core to read as violent.
func fire_dash() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "FireDash"
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.emitting = false
	p.amount = 55
	p.lifetime = 0.18
	p.lifetime_randomness = 0.25
	p.local_coords = false          # exhaust is left behind as she tears away
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 3.0
	p.direction = Vector2(-1.0, 0.35)   # backward + slightly down
	p.spread = 32.0
	p.gravity = Vector2(0, 520)     # lighter than the run: thrust dominates
	p.initial_velocity_min = 180.0
	p.initial_velocity_max = 320.0  # variance = ragged, not a uniform stream
	p.scale_amount_min = 5.0
	p.scale_amount_max = 8.0
	p.angle_min = -45.0             # tumbling squares read as debris/sparks
	p.angle_max = 45.0

	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	ramp.colors = PackedColorArray([
		Color8(255, 255, 235, 255),  # white-hot core
		Color8(255, 218, 70, 255),   # yellow
		Color8(240, 112, 20, 255),   # orange
		Color8(150, 30, 8, 0),       # deep red, snaps out
	])
	p.color_ramp = ramp
	return p


func _save(node: CPUParticles2D, path_in_particles: String) -> void:
	var path := OUT % path_in_particles
	if ResourceLoader.exists(path):
		print("  skip (exists, keeping your edits) -> %s" % path)
		node.queue_free()
		return
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var scene := PackedScene.new()
	scene.pack(node)
	var err := ResourceSaver.save(scene, path)
	print("  %s -> %s" % ["created" if err == OK else "ERR %d" % err, path])


func _init() -> void:
	# Path is relative to particles/ -- see the layout in the README.
	_save(fire_spark(), "characters/wayna/fire_spark")
	_save(fire_dash(), "characters/wayna/fire_dash")
	_save(ground_wave(), "enemies/baghel/ground_wave")
	quit()
