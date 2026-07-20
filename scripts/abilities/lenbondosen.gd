extends CharacterAbility

## Lenny: Hangtime.
##
## A heavy swing started in mid-air suspends him until it finishes, so the whole
## animation plays out instead of being cut short by the fall. His heavy attack
## is 7 frames, the second longest, which makes it the one most worth hanging on.

func physics(player: Player, _delta: float) -> void:
	if player.get_state() == Player.State.HEAVY_ATTACK and not player.is_on_floor():
		velocity_freeze(player)


## Cancel the fall outright rather than just zeroing the acceleration, so he
## holds the pose instead of drifting on whatever momentum he arrived with.
func velocity_freeze(player: Player) -> void:
	player.velocity.y = 0.0
