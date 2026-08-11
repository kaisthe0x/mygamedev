extends SceneTree
func _init() -> void:
	_strip("res://assets/terrain/platform.png", 32, 16, Color(0.4, 0.42, 0.5), Color(0.28, 0.3, 0.38))
	_strip("res://assets/terrain/floor.png", 32, 40, Color(0.3, 0.31, 0.4), Color(0.18, 0.19, 0.26))
	_grad("res://assets/terrain/background.png", 64, 64, Color(0.1, 0.13, 0.2), Color(0.03, 0.04, 0.08))
	print("generated 3 placeholder terrain PNGs")
	quit()
func _strip(path, w, h, a, b) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for x in w: for y in h:
		img.set_pixel(x, y, a if ((x / 4 + y / 4) % 2 == 0) else b) # checker so tiling is visible
	img.save_png(ProjectSettings.globalize_path(path))
func _grad(path, w, h, top, bot) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h: for x in w:
		img.set_pixel(x, y, top.lerp(bot, float(y) / h))
	img.save_png(ProjectSettings.globalize_path(path))
