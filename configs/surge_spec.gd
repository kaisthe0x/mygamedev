class_name SurgeSpec
extends RefCounted

## The timed self-buff a SURGE applies -- the "surge" component of a SURGE Action, the sibling of
## StrikeSpec (a hit) and Locomotion (movement). A Surge is triggered on the `surge` button and applies
## this for `duration` seconds. There is NO cooldown timer -- **RUH is the only gate**: each use spends
## `cost` Ruh (100 = one charge), so you surge as long as you have Ruh. (Specials, by contrast, are free.)
##
## Deliberately a small, growing set of effect flags (like the strike tuning dicts) so new surges are a
## data row, not a new class. Effects stack for the duration (Player._begin_surge): `invuln` (Aegis),
## `damage_mult` / `damage_taken_mult` (Jnoon: hit twice as hard, take half). `aura` is the per-surge
## orbit-aura scene spawned for the window.

var cost: float = 100.0             ## Ruh spent per use (RUH_PER_BLOCK = 100 = one charge). No Ruh -> no surge.
var duration: float = 5.0           ## seconds the effect lasts once triggered
var invuln: bool = false            ## grant full damage immunity for the duration (Aegis)
var damage_mult: float = 1.0        ## scale OUTGOING damage for the duration (Jnoon: 2.0 = double)
var damage_taken_mult: float = 1.0  ## scale INCOMING damage for the duration (Jnoon: 0.5 = half)
var speed_mult: float = 1.0         ## scale MOVEMENT (run) speed for the duration (Asra: 2.0 = twice as fast)
var aura: String = ""               ## the aura VFX scene spawned for the window (res:// path)


static func make(d: Dictionary) -> SurgeSpec:
	var s := SurgeSpec.new()
	s.cost = float(d.get("cost", s.cost))
	s.duration = float(d.get("duration", s.duration))
	s.invuln = bool(d.get("invuln", s.invuln))
	s.damage_mult = float(d.get("damage_mult", s.damage_mult))
	s.damage_taken_mult = float(d.get("damage_taken_mult", s.damage_taken_mult))
	s.speed_mult = float(d.get("speed_mult", s.speed_mult))
	s.aura = String(d.get("aura", s.aura))
	return s
