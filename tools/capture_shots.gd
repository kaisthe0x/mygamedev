extends SceneTree

## Dev-only: render every character in every animation through the real player
## scene and save PNGs, so alignment can be eyeballed in an actual engine
## render rather than trusted from arithmetic.
##   godot --script tools/capture_shots.gd
## Output goes to the project's user:// dir (printed on exit).

const ANIMS := ["idle", "run", "jump", "dash", "attack"]
const OUT_DIR := "user://shots"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var cam := Camera2D.new()
	cam.position = Vector2(0, -36)
	cam.zoom = Vector2(4, 4)
	root.add_child(cam)
	cam.make_current()

	var player: Player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")

	# A ground line at y=0 so foot placement is obvious in the render.
	var line := ColorRect.new()
	line.color = Color(1, 0, 0.3)
	line.position = Vector2(-200, 0)
	line.size = Vector2(400, 1)
	root.add_child(line)

	await process_frame

	for id in Player.CHARACTERS:
		player.character = id
		for anim in ANIMS:
			var count := sprite.sprite_frames.get_frame_count(anim)
			sprite.play(anim)
			sprite.set_frame_and_progress(floori(count / 2.0), 0.0)
			sprite.pause()
			await process_frame
			await process_frame
			var img := root.get_texture().get_image()
			img.save_png("%s/%s_%s.png" % [OUT_DIR, id, anim])

	print("saved to ", ProjectSettings.globalize_path(OUT_DIR))
	quit()
