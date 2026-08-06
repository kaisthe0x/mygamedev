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


## Called once when this character's special reaches its strike frame (right
## as the melee hitbox fires). Use it for an on-strike special -- e.g. spawning an
## effect or projectile from code.
func on_special_strike(_player: Player) -> void:
	pass


## Called when this character takes a combat hit (right as it lands). React to being
## hurt -- a retaliation, a defensive buff, whatever. `hit` carries amount/knockback/
## stun/source. A held/channeled effect is interrupted SEPARATELY via
## the Strike's `interrupt_on_hurt`, so this hook stays free for anything else.
func on_hurt(_player: Player, _hit: Hit) -> void:
	pass


## Called on every touchdown, with how far he DROPPED from his highest point this
## airborne stretch (`fall_distance`, px) and the speed he hit at (`fall_speed`, px/s).
## For fall damage, landing shockwaves, etc.
func on_land(_player: Player, _fall_distance: float, _fall_speed: float) -> void:
	pass
