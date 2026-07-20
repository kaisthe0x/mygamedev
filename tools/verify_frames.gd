extends SceneTree

## Headless check that every generated SpriteFrames resource loads, exposes the
## full animation set, and normalises to one shared canvas.
##   godot --headless --script tools/verify_frames.gd

const EXPECTED := ["idle", "run", "jump", "dash", "attack", "heavy_attack"]


func _init() -> void:
	var canvases := {}
	var failures := 0

	for id in Player.CHARACTERS:
		var path := Player.FRAMES_PATH % id
		var frames := load(path) as SpriteFrames
		if frames == null:
			print("FAIL %s: could not load %s" % [id, path])
			failures += 1
			continue

		for anim in EXPECTED:
			if not frames.has_animation(anim):
				print("FAIL %s: missing animation '%s'" % [id, anim])
				failures += 1
				continue
			var count := frames.get_frame_count(anim)
			for i in count:
				var tex := frames.get_frame_texture(anim, i)
				if tex == null:
					print("FAIL %s/%s frame %d: null texture" % [id, anim, i])
					failures += 1
					continue
				canvases[tex.get_size()] = true
			print("  %-12s %-7s %d frames  loop=%s  %.0f fps" % [
				id, anim, count, frames.get_animation_loop(anim),
				frames.get_animation_speed(anim),
			])

	if canvases.size() != 1:
		print("FAIL: frames are not a uniform canvas -> %s" % [canvases.keys()])
		failures += 1
	else:
		print("\nuniform canvas: %s" % [canvases.keys()[0]])

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
