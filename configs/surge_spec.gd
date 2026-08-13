class_name SurgeSpec
extends RefCounted

## The timed self-buff a SURGE applies -- the "surge" component of a SURGE Action, the sibling of
## StrikeSpec (a hit) and Locomotion (movement). A Surge is a PASSIVE ability: one button press
## (`surge`) applies this for `duration` seconds without locking the player's state, then the Action's
## `cooldown` is the RESET wait *after* it expires before it can fire again.
##
## Deliberately a small, growing set of effect flags (like the strike tuning dicts) so new surges are a
## data row, not a new class. Today only Aegis exists (invuln); speed/damage/etc. buffs slot in later.

var duration: float = 5.0  ## seconds the effect lasts once triggered
var invuln: bool = false   ## grant full damage immunity for the duration (Aegis)


static func make(d: Dictionary) -> SurgeSpec:
	var s := SurgeSpec.new()
	s.duration = float(d.get("duration", s.duration))
	s.invuln = bool(d.get("invuln", s.invuln))
	return s
