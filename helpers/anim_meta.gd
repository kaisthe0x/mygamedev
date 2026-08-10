class_name AnimMeta
extends RefCounted

## Readers for the per-animation metadata the sprite generator writes into each
## SpriteFrames (see tools/gen_spriteframes.py). Both the player combo/strike logic
## and the enemy attack timing read the same `hit_frames` map, so it lives here
## once instead of three near-identical copies.


## The authored hit frames (EMITTED indices) for `anim`, or [] if none. Each is a
## segment boundary for a combo / the frame a strike or projectile fires on.
static func hit_frames(frames: SpriteFrames, anim: StringName) -> Array:
	if frames == null or not frames.has_meta("hit_frames"):
		return []
	return frames.get_meta("hit_frames").get(String(anim), [])


## How many leading sheet frames were dropped for `anim` (the idle-reference frame 0), or 0. Add it
## to an EMITTED index to get the SHEET index; subtract to go the other way. Lets code that speaks
## in emitted frames map a SHEET-relative number (as used in configs/filenames) onto playback.
static func sheet_start(frames: SpriteFrames, anim: StringName) -> int:
	if frames == null or not frames.has_meta("sheet_start"):
		return 0
	return int(frames.get_meta("sheet_start").get(String(anim), 0))


## The `loop_from` / `loop_to` bound (EMITTED index) for `anim`, or -1 if unset.
## `key` is "loop_from" or "loop_to"; used to loop a mid-sheet range.
static func loop_bound(frames: SpriteFrames, anim: StringName, key: String) -> int:
	if frames == null or not frames.has_meta(key):
		return -1
	return int(frames.get_meta(key).get(String(anim), -1))
