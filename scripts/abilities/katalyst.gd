extends CharacterAbility

## Katalyst: Double Pierce -- a mid-air slam.
##
## A special attack started in mid-air turns into a ground slam. He hangs for the
## wind-up, then drives straight down until he lands.
##
## His special sheet (after the idle-reference frame 0 is dropped) is: wind-up,
## lunge, ground-energy blast -- emitted frames 0, 1, 2. He hangs for the wind-up
## frame, then the drop begins on the lunge; the blast (emitted 2) is his authored
## hit frame, so the hitbox lands as he connects.

## Seconds suspended before dropping. At 10 fps the lunge (emitted frame 1) begins
## at 0.1s, so the drop starts exactly then -- retune if the special's fps or frame
## layout changes.
const WIND_UP := 0.1
## Downward speed of the slam. Well above normal fall speed so it reads as a
## deliberate slam and not just gravity.
const SLAM_SPEED := 1100.0

## Weak knees: he takes damage on EVERY landing that drops him farther than this, scaled
## by drop distance AND landing speed, so a hard/high fall can kill him (it's also why he
## has no slam). A future "knee transplant" item would flip `_weak_knees` off.
const SAFE_FALL := 400.0            # px he can drop unharmed
const FALL_DAMAGE_PER_PX := 0.12    # damage per px beyond SAFE_FALL (before the speed factor)
const REF_FALL_SPEED := 986.0       # ~landing speed of a SAFE_FALL passive drop; scales "how fast"

var _slamming := false
var _was_special := false
var _wind_up_left := 0.0
## Off = no fall damage (and he could slam) -- the hook a knee-transplant pickup flips.
var _weak_knees := true


func setup(_player: Player) -> void:
	_slamming = false
	_was_special = false
	_wind_up_left = 0.0


## Fall damage on landing: nothing up to SAFE_FALL, then proportional to how far past it
## he dropped, amplified by how fast he hit (a driven plunge hurts more than a lazy drop).
func on_land(player: Player, fall_distance: float, fall_speed: float) -> void:
	if not _weak_knees or fall_distance <= SAFE_FALL:
		return
	var over := fall_distance - SAFE_FALL
	var speed_factor := clampf(fall_speed / REF_FALL_SPEED, 1.0, 2.0)
	player.take_damage(over * FALL_DAMAGE_PER_PX * speed_factor)


func physics(player: Player, delta: float) -> void:
	var special: bool = player.get_state() == Player.State.SPECIAL

	# Latch on the frame the special *starts*, and only if he was airborne then.
	# Checking the state alone would also trigger for a grounded special that
	# happens to walk off a ledge mid-swing.
	if special and not _was_special and not player.is_on_floor():
		_slamming = true
		_wind_up_left = WIND_UP
	_was_special = special

	if not _slamming:
		return

	# Landing or cancelling ends it; the rest of the animation plays out grounded.
	if not special or player.is_on_floor():
		_slamming = false
		return

	if _wind_up_left > 0.0:
		_wind_up_left -= delta
		player.velocity.y = 0.0
	else:
		player.velocity.y = SLAM_SPEED
