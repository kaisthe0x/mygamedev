extends CharacterAbility

## Lenny: Hangtime + Sprint.
##
## Hangtime: a heavy swing started in mid-air suspends him until it finishes, so
## the whole animation plays instead of being cut short by the fall.
##
## Sprint: his run has a long wind-up (frames 1-8) then a sustained energised
## loop (last 3). Once he reaches that loop his run surges to SPRINT_SPEED --
## reward for keeping the run going, and a second specialty.

## Multiplier on run_speed once the sustained run kicks in.
const SPRINT_MULT := 1.8


func physics(player: Player, _delta: float) -> void:
	if player.get_state() == Player.State.HEAVY_ATTACK and not player.is_on_floor():
		# Cancel the fall outright so he holds the pose instead of drifting.
		player.velocity.y = 0.0
	elif player.get_state() == Player.State.RUN and player.is_on_floor() \
			and player.run_loop_reached():
		# Surge only while actively running the way he's already moving. Basing
		# this on INPUT (not velocity's own sign) is essential: otherwise it pins
		# velocity to its current direction every frame, so you could never turn
		# around or even stop -- it'd drag you the way you were going.
		var input := Input.get_axis(&"move_left", &"move_right")
		if input != 0.0 and signf(input) == signf(player.velocity.x):
			player.velocity.x = signf(input) * player.run_speed * SPRINT_MULT
