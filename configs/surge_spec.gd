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
## Nem is a CHANNEL, not a passive buff: Khalid locks in place, the anim plays to its second-to-last
## frame (head down, asleep) and PAUSES there, and he heals `heal_frac` of MAX hp over `duration`. A hit
## from an enemy WAKES him -- the channel cancels, keeping whatever health he already gained.
var channel: bool = false           ## true = a movement-locking sleep/heal channel (Nem)
var heal_frac: float = 0.0          ## heal this fraction of MAX health over the channel (Nem 0.5 = +50%)
## Trigger type: "cast" (default) applies the effect immediately for `duration`; "hit" ARMS the surge --
## it stays active (aura orbiting) with no timer until an enemy hit lands, which fires the effect below
## and consumes it. Wara is a "hit" surge: negate that hit + AoE-stun nearby enemies + a burst.
var trigger: String = "cast"
var stun_radius: float = 0.0        ## Wara: enemies within this range are stunned when the surge triggers
var stun_time: float = 0.0          ## Wara: seconds they're stunned
var aura: String = ""               ## the orbit aura VFX scene shown while active (res:// path)
var burst: String = ""              ## Wara: the AoE burst VFX played once WHEN triggered (res:// path)


static func make(d: Dictionary) -> SurgeSpec:
	var s := SurgeSpec.new()
	s.cost = float(d.get("cost", s.cost))
	s.duration = float(d.get("duration", s.duration))
	s.invuln = bool(d.get("invuln", s.invuln))
	s.damage_mult = float(d.get("damage_mult", s.damage_mult))
	s.damage_taken_mult = float(d.get("damage_taken_mult", s.damage_taken_mult))
	s.speed_mult = float(d.get("speed_mult", s.speed_mult))
	s.channel = bool(d.get("channel", s.channel))
	s.heal_frac = float(d.get("heal_frac", s.heal_frac))
	s.trigger = String(d.get("trigger", s.trigger))
	s.stun_radius = float(d.get("stun_radius", s.stun_radius))
	s.stun_time = float(d.get("stun_time", s.stun_time))
	s.aura = String(d.get("aura", s.aura))
	s.burst = String(d.get("burst", s.burst))
	return s
