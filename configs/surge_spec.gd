class_name SurgeSpec
extends RefCounted

## The timed self-buff a SURGE applies -- the "surge" component of a SURGE Action, the sibling of
## StrikeSpec (a hit) and Locomotion (movement). A Surge is triggered on the `surge` button and applies
## this for `duration` seconds. There is NO cooldown timer -- **RUH is the only gate**: each use spends
## `cost` Ruh (100 = one charge), so you surge as long as you have Ruh. (Specials, by contrast, are free.)
##
## Deliberately a small, growing set of effect flags (like the strike tuning dicts) so new surges are a
## data row, not a new class. Today only Aegis exists (invuln); speed/damage/etc. buffs slot in later.

var cost: float = 100.0    ## Ruh spent per use (RUH_PER_BLOCK = 100 = one charge). No Ruh -> can't surge.
var duration: float = 5.0  ## seconds the effect lasts once triggered
var invuln: bool = false   ## grant full damage immunity for the duration (Aegis)


static func make(d: Dictionary) -> SurgeSpec:
	var s := SurgeSpec.new()
	s.cost = float(d.get("cost", s.cost))
	s.duration = float(d.get("duration", s.duration))
	s.invuln = bool(d.get("invuln", s.invuln))
	return s
