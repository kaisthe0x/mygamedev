class_name Move
extends RefCounted

## One attack or special a character can use. It knows the animation it plays, the
## effect it fires, and its melee-hitbox tuning. Built from the catalog in
## configs/moves.gd (see Moves); the Player holds a current attack + current special
## and drives them through this.
##
## Effects are frame-indexed: the ParticleDirector fires whatever emitters.json lists
## under this move's `animation` name (a particle -- optionally carrying its own
## Hitbox). `effect` here is just the human label of what it uses.

var id: String              ## short name, e.g. "finger_guns"
var kind: String            ## "attack" or "special" (the slot it fills)
## Player-facing taxonomy (Combat.AttackKind: MELEE / BLAST / GROUND / PROJECTILE), for
## the future move-select / build UI to label the move. Descriptive only -- it does NOT
## drive behavior. Defaults to MELEE.
var attack_kind: int = Combat.AttackKind.MELEE
var animation: StringName   ## SpriteFrames animation, e.g. &"attack_finger_guns"
var effect: String          ## what it fires (for reference); "" = none
## Attack cadence. "combo" (default) = one click per segment, freezing on each hit frame
## (the click-chained swing everyone else uses). "flurry" = hold the attack button and
## the animation loops rapidly, its punch frames firing the effect (hit) every pass;
## releasing ends it. Specials ignore this. See Player._advance_combo / _process_attack.
var style: String = "combo"
## Melee-hitbox tuning, same shape as an ATTACKS entry: damage / knockback / stun /
## color / x (forward reach) / extents (half-size). Unset fields fall back to the
## Player's exported defaults. May be a single dict, OR an ARRAY (one per combo
## segment) for a multi-hit attack. Leave damage 0 when the effect carries the hit.
var tuning: Variant = {}


## Build a Move from a catalog entry. `animation` defaults to "<kind>_<id>".
static func make(move_kind: String, move_id: String, d: Dictionary) -> Move:
	var m := Move.new()
	m.kind = move_kind
	m.id = move_id
	m.attack_kind = int(d.get("kind", Combat.AttackKind.MELEE))
	m.animation = StringName(d.get("animation", "%s_%s" % [move_kind, move_id]))
	m.effect = String(d.get("effect", ""))
	m.style = String(d.get("style", "combo"))
	m.tuning = d.get("tuning", {})
	return m


## Tuning for combo segment `seg`. An array indexes by segment (a shorter array
## reuses its last entry); a single dict is shared by every hit.
func segment(seg: int) -> Dictionary:
	if tuning is Array:
		return {} if tuning.is_empty() else tuning[mini(seg, tuning.size() - 1)]
	return tuning
