extends SceneTree

## Builds particle-type scenes under vfx/ from code, so the many CPUParticles2D
## properties are set correctly and the .tscn stays valid. Each saved scene is a
## normal CPUParticles2D you can then tweak in the editor.
##
##   godot --headless --script vfx/script/build_particles.gd
##
## Add a new type by adding a builder function here and listing it in _init().
## The path arg is relative to vfx/ -- see the layout in vfx/README.md.

const OUT := "res://vfx/%s.tscn"
const PIXEL_EMBER := "res://vfx/shared/textures/pixel_ember.png"


# Grow-to-a-crest then shrink, so mid-arc chunks are biggest -> reads as a swell.
func _crest_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.45))
	c.add_point(Vector2(0.4, 1.0))
	c.add_point(Vector2(1.0, 0.15))
	return c


# Baghel's ground shockwave. A crest: chunks kick UP and slightly FORWARD out of
# the ground and arc back down under gravity, and because the projectile outruns
# them (and local_coords is off) they trail into a curling wave that rolls the
# way it travels. Authored leaning +x; the projectile mirrors scale.x for facing.
# `emitting = true` so it plays on spawn AND previews in the editor. Tune freely.
func ground_wave() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "GroundWave"
	p.texture = load(PIXEL_EMBER)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.emitting = true
	p.amount = 64
	p.lifetime = 0.4
	p.lifetime_randomness = 0.25
	p.local_coords = false          # stays in world -> trails into a rolling wave
	p.explosiveness = 0.05
	# Emit from a short line hugging the ground so the crest has a base, not a point.
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(5, 2)
	p.direction = Vector2(0.45, -1)  # up + forward -> the crest leans as it rolls
	p.spread = 24.0
	p.gravity = Vector2(0, 560)      # yanked back down -> the arc/curl
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 205.0   # varied crest height
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.7
	p.scale_amount_curve = _crest_curve()
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 0.65, 1.0])
	ramp.colors = PackedColorArray([
		Color8(255, 255, 255, 255),  # hot white core
		Color8(255, 130, 55, 255),   # orange
		Color8(214, 44, 26, 255),    # red
		Color8(110, 20, 14, 0),      # fades out
	])
	p.color_ramp = ramp
	return p


## Scaffold only: never clobbers an existing scene, because these get hand-tuned
## in the editor afterwards. Delete the file first if you want it regenerated.
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
	# Path is relative to vfx/ -- see the layout in vfx/README.md.
	_save(ground_wave(), "enemy/baghel/attack/attack_ground_wave")
	quit()
