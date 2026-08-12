class_name Passive
extends RefCounted

## Base class for a BEHAVIORAL build capability -- a character's intrinsic ability OR a reward-granted
## passive (Phase 4). The Player holds a LIST of active passives (`_passives`) and dispatches these
## hooks to each at the right moment; a passive overrides only the hooks it needs.
##
## Two flavours, same interface:
##  - a character's INTRINSIC ability -- `scripts/abilities/<character_id>.gd` (still `extends
##    CharacterAbility`, which IS a Passive); seeded first on character equip.
##  - a REWARD-granted passive -- `scripts/abilities/<passive_id>.gd` (`extends Passive`), added at
##    runtime via `Player.add_passive()` when its reward is taken (see Rewards), and cleared on run
##    restart (each passive's `teardown` runs so it can undo lingering effects).
##
## Override only the hooks you need.

var id: String = "" ## stable id (for Build queries / dedup / debug); reward passives set it in _init


## Called once, right after this passive is added (character equip or reward grant). One-off setup --
## e.g. bump a stat, cache state, spawn a persistent node.
func setup(_player: Player) -> void:
	pass


## Called once when this passive is removed (run restart / character change). UNDO anything `setup`
## left behind (a stat bump, a spawned node) so it doesn't leak across runs.
func teardown(_player: Player) -> void:
	pass


## Called every physics frame, after the state machine has decided this frame's velocity but before
## `move_and_slide()`. The place to override movement: whatever you set here wins.
func physics(_player: Player, _delta: float) -> void:
	pass


## Called once when the special reaches its strike frame (as the melee hitbox fires). For an on-strike
## effect -- spawning an effect/projectile from code.
func on_special_strike(_player: Player) -> void:
	pass


## Called the instant a special is CAST (in _start_special), with the special Action. The place for a
## cast-triggered effect -- e.g. the Impervious buff grants its invuln window here. Fires at cast, before
## the wind-up plays, so effects cover the whole animation (unlike on_special_strike, mid-animation).
func on_special_cast(_player: Player, _action: Action) -> void:
	pass


## Called on a PERFECT PARRY with the Redere Shield (the reflect branch of _on_hurt), with the parried
## `hit`. For a parry payoff -- heal, a counter buff, etc. (A plain block does NOT fire this.)
func on_parry(_player: Player, _hit: Hit) -> void:
	pass


## THE OUTGOING-TUNING HOOK. Called from Player.resolve_tuning for EVERY attack/special swing, letting a
## passive/buff alter that move's per-hit numbers (damage, knockback, extents, or a new key a consumer
## reads). `tuning` is a private copy -- mutate + return it (or return it untouched). `action` is the move
## being resolved, `seg` its combo segment, so a per-move buff can gate on action.id / .category / .tags.
func modify_tuning(_player: Player, _action: Action, _seg: int, tuning: Dictionary) -> Dictionary:
	return tuning


## Called when the player takes a combat hit (as it lands). `hit` carries amount/knockback/stun/source.
## For a retaliation, a defensive reaction, etc.
func on_hurt(_player: Player, _hit: Hit) -> void:
	pass


## Called on every touchdown, with how far the player DROPPED this airborne stretch (px) and the speed
## they hit at (px/s). For fall damage, landing shockwaves, etc.
func on_land(_player: Player, _fall_distance: float, _fall_speed: float) -> void:
	pass


## Called when the player DEALS damage to an enemy (`amount` HP removed, `target` the enemy). For
## lifesteal, on-hit procs, stacks, etc. Dispatched from RunManager's damage-dealt signal.
func on_hit_dealt(_player: Player, _amount: float, _target: Node) -> void:
	pass
