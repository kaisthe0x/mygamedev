class_name CharacterAbility
extends RefCounted

## Base class for a character's unique ability.
##
## Drop a script at `res://scripts/abilities/<character_id>.gd` that extends
## this, and the Player picks it up automatically when that character is
## selected. No registration, no scene edits. Characters without a file simply
## have no ability.
##
## Override only the hooks you need.


## Called once, right after this character is equipped. Use it for one-off
## changes such as raising `player.run_speed`, or to reset per-character state.
func setup(_player: Player) -> void:
	pass


## Called every physics frame, after the state machine has decided this frame's
## velocity but before `move_and_slide()` applies it. That makes it the place to
## override movement: whatever you set here wins.
func physics(_player: Player, _delta: float) -> void:
	pass
