extends CharacterAbility

## Katalyst: Stomp.
##
## A heavy attack started in mid-air turns into a ground slam. He hangs for the
## wind-up, then drives straight down until he lands.
##
## His heavy sheet (after the idle-reference frame 0 is dropped) is: wind-up,
## lunge, ground-energy blast -- emitted frames 0, 1, 2. He hangs for the wind-up
## frame, then the drop begins on the lunge; the blast (emitted 2) is his authored
## hit frame, so the hitbox lands as he connects.

## Seconds suspended before dropping. At 10 fps the lunge (emitted frame 1) begins
## at 0.1s, so the drop starts exactly then -- retune if the heavy's fps or frame
## layout changes.
const WIND_UP := 0.1
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
