extends CharacterAbility

## Katalyst: Stomp.
##
## A heavy attack started in mid-air turns into a ground slam. He hangs for the
## wind-up, then drives straight down until he lands.
##
## His heavy animation is 5 frames at 10 fps: neutral, wind-up, downward strike
## with impact particles, follow-through, recover. WIND_UP is timed so the drop
## begins exactly on the strike frame, rather than before he has swung.

## Seconds suspended before dropping. Frame 2 (the strike) starts at 0.2s.
const WIND_UP := 0.2
## Downward speed of the slam. Well above normal fall speed so it reads as a
## deliberate slam and not just gravity.
const SLAM_SPEED := 1100.0

var _stomping := false
var _was_heavy := false
var _wind_up_left := 0.0


func setup(_player: Player) -> void:
	_stomping = false
	_was_heavy = false
	_wind_up_left = 0.0


func physics(player: Player, delta: float) -> void:
	var heavy: bool = player.get_state() == Player.State.HEAVY_ATTACK

	# Latch on the frame the heavy *starts*, and only if he was airborne then.
	# Checking the state alone would also trigger for a grounded heavy that
	# happens to walk off a ledge mid-swing.
	if heavy and not _was_heavy and not player.is_on_floor():
		_stomping = true
		_wind_up_left = WIND_UP
	_was_heavy = heavy

	if not _stomping:
		return

	# Landing or cancelling ends it; the rest of the animation plays out grounded.
	if not heavy or player.is_on_floor():
		_stomping = false
		return

	if _wind_up_left > 0.0:
		_wind_up_left -= delta
		player.velocity.y = 0.0
	else:
		player.velocity.y = SLAM_SPEED
