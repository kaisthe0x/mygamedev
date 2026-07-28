extends SceneTree

## Slice drawn EFFECT / PROJECTILE sprite strips into standalone SpriteFrames, so a
## Shot (or any scene) can play a hand-drawn frame animation via an AnimatedSprite2D
## instead of a particle emitter repeating one texture.
##
## Convention: any horizontal strip named "<name>_anim.png" anywhere under
## vfx/ is sliced on a UNIFORM grid into "<name>_anim.tres" beside it, as a
## single looping animation called "default". Unlike the character pipeline
## (tools/gen_spriteframes.py) there's no feet-anchoring and no idle-reference frame
## -- a projectile just plays its frames.
##
## Frame count is inferred as SQUARE (width / height) unless OVERRIDES says otherwise.
## Point an AnimatedSprite2D's `sprite_frames` at the generated .tres, set
## autoplay = "default", and you're done.
##
## Run:  godot --headless --script tools/gen_effect_frames.gd

const ROOT := "res://vfx"
const DEFAULT_FPS := 12.0
## Project standard: every sprite/animation frame is 128px wide, so a strip's frame
## count is width / 128. (Override per-strip below if a one-off differs.)
const FRAME_WIDTH := 128

## Per-strip tuning, keyed by the file stem (e.g. "ring_kiss_anim"):
##   frames -- explicit frame count (omit to infer from FRAME_WIDTH)
##   fps    -- playback speed (default DEFAULT_FPS)
##   loop   -- defaults true, EXCEPT strips ending in "_end_anim" (a dissolve/expiry
##             animation) default to false so they play once and don't repeat. Set
##             explicitly here to override either default.
const OVERRIDES := {
	# Feyke's ring kiss FORMS (blob -> ring) then holds the ring as it flies.
	"ring_kiss_anim": {"fps": 14.0, "loop": false},
	"ring_kiss_end_anim": {"fps": 14.0},  # dissolve on expiry; loop defaults off (_end_anim)
}


func _init() -> void:
	var strips: Array[String] = []
	_collect(ROOT, strips)
	if strips.is_empty():
		print("gen_effect_frames: no '*_anim.png' strips found under %s" % ROOT)
	for p in strips:
		_build(p)
	quit()


## Recurse `dir_path`, appending every "*_anim.png" to `out`.
func _collect(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := dir_path.path_join(entry)
			if d.current_is_dir():
				_collect(full, out)
			elif entry.ends_with("_anim.png"):
				out.append(full)
		entry = d.get_next()
	d.list_dir_end()


func _build(png_path: String) -> void:
	var tex := load(png_path) as Texture2D
	if tex == null:
		push_warning("gen_effect_frames: could not load %s" % png_path)
		return
	var w := tex.get_width()
	var h := tex.get_height()
	var stem := png_path.get_file().trim_suffix(".png")
	var cfg: Dictionary = OVERRIDES.get(stem, {})

	var frames := int(cfg.get("frames", maxi(1, roundi(float(w) / FRAME_WIDTH))))
	var fps := float(cfg.get("fps", DEFAULT_FPS))
	# "_end_anim" strips are one-shot dissolves -- default them to non-looping.
	var loop: bool = cfg.get("loop", not stem.ends_with("_end_anim"))

	@warning_ignore("integer_division")
	var fw := w / frames
	if w % frames != 0:
		push_warning("gen_effect_frames: %s width %d isn't divisible by %d frames; "
			% [stem, w, frames] + "frames will be %dpx and the remainder is ignored" % fw)

	var sf := SpriteFrames.new()  # comes with an empty "default" animation
	sf.set_animation_loop(&"default", loop)
	sf.set_animation_speed(&"default", fps)
	for i in frames:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fw, 0, fw, h)
		sf.add_frame(&"default", at)

	var out_path := png_path.trim_suffix(".png") + ".tres"
	var err := ResourceSaver.save(sf, out_path)
	if err != OK:
		push_warning("gen_effect_frames: failed to save %s (err %d)" % [out_path, err])
		return
	print("  %s -> %s  (%d frames @ %.0f fps, %dx%d each, loop=%s)"
		% [png_path.get_file(), out_path.get_file(), frames, fps, fw, h, loop])
