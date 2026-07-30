extends CharacterAbility

## Khalid: Blink Dash -- his dash is an instant teleport instead of a glide.
##
## On dash he vanishes and reappears a fixed distance ahead -- the SAME distance his
## normal dash would have covered (dash_speed * dash_time), so it reuses his existing
## per-character dash tuning. The player skips the lunge but keeps the dash i-frames,
## cooldown, and animation, which plays at the destination as a "materialize". A
## blink-out poof marks where he left, a blink-in poof where he arrives, and a brief
## bright flash sells the reappearance.

## Stop at walls for now -- he blinks UP TO a wall, not through it. Flipping this to
## true is a future BUFF (phase straight through solid geometry). The mechanic lives
## here; a pickup just flips the flag -- same idea as Katalyst's `_weak_knees`.
var _phase_walls := false


func dash(player: Player) -> bool:
	var facing := player.get_facing()
	# Same reach as his normal dash, just instant.
	var motion := Vector2(player.dash_speed * player.dash_time * facing, 0.0)

	player.fire_effect("blink_out")  # poof at the spot he's leaving
	if _phase_walls:
		player.global_position += motion
	else:
		# move_and_collide stops him at the first wall on his collision mask, so he
		# blinks up to a wall, not through it. Enemies aren't on that mask, so he passes
		# through them -- the whole point of a repositioning blink.
		player.move_and_collide(motion)
	player.velocity.x = 0.0  # a teleport carries no momentum; the dash tail re-derives it

	player.fire_effect("blink_in")  # poof where he arrives
	_flash(player)
	return true


## A brief over-white the world bloom picks up, easing back to normal. Cascades from the
## player node down to the sprite (and the just-fired poofs), so the whole blink glows.
func _flash(player: Player) -> void:
	player.modulate = Color(2.2, 2.2, 2.2)
	var tw := player.create_tween()
	tw.tween_property(player, "modulate", Color(1, 1, 1), 0.18)
