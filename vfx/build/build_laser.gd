extends SceneTree

## Builds the base laser-beam scene from code, so the multi-node tree + script
## wiring is correct, then it's a normal scene to open and tweak. Skips the file
## if it already exists (so your edits stick); delete it to regenerate.
##
##   godot --headless --script vfx/build/build_laser.gd
##
## Per-character beams: right-click laser_beam.tscn -> New Inherited Scene, swap
## the Core texture/colours, save as laser_beam_<id>.tscn, point the ability at it.

const OUT := "res://vfx/laser/laser_beam.tscn"
const SCRIPT := "res://vfx/laser_beam.gd"
const HITBOX := "res://scripts/combat/hitbox.gd"
const SAMPLE_LEN := 180.0  # a visible resting beam so the scene isn't blank in the editor


func _init() -> void:
	if ResourceLoader.exists(OUT):
		print("skip (exists, keeping edits) -> ", OUT)
		quit()
		return

	var laser := Node2D.new()
	laser.name = "LaserBeam"
	laser.set_script(load(SCRIPT))

	var ray := RayCast2D.new()
	ray.name = "Ray"
	ray.enabled = false
	ray.collision_mask = Combat.L_WORLD  # stop the beam at walls; pierce through enemies
	ray.target_position = Vector2(SAMPLE_LEN, 0)
	laser.add_child(ray)

	# Halo (wide, under) then Core (thin, on top). Core is textured-stretch so a
	# drawn beam sprite dropped on it becomes the beam.
	var halo := _line("Halo", 12.0, Color(0.2, 0.9, 2.6, 0.75))
	laser.add_child(halo)
	var core := _line("Core", 4.0, Color(1.4, 2.6, 3.4))
	core.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	laser.add_child(core)

	var hitbox := Area2D.new()
	hitbox.name = "Hitbox"
	hitbox.set_script(load(HITBOX))
	hitbox.collision_layer = Combat.L_PLAYER_HIT   # player's beam; enemy variants flip this
	hitbox.collision_mask = Combat.L_ENEMY_HURT
	laser.add_child(hitbox)
	var shape := Shapes.make_box(Vector2(SAMPLE_LEN, 8), Vector2(SAMPLE_LEN / 2.0, 0))
	shape.name = "Shape"
	hitbox.add_child(shape)

	# Every packed node needs its owner set to the scene laser.
	for n in [ray, halo, core, hitbox, shape]:
		n.owner = laser

	var scene := PackedScene.new()
	var err := scene.pack(laser)
	if err == OK:
		DirAccess.make_dir_recursive_absolute(OUT.get_base_dir())
		err = ResourceSaver.save(scene, OUT)
	print(("created -> " if err == OK else "ERR %d -> " % err), OUT)
	quit()


func _line(n: String, w: float, c: Color) -> Line2D:
	var l := Line2D.new()
	l.name = n
	l.points = PackedVector2Array([Vector2.ZERO, Vector2(SAMPLE_LEN, 0)])
	l.width = w
	l.default_color = c
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	return l


