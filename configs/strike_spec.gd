class_name StrikeSpec
extends RefCounted

## The "Strike" component of an Action: HOW a hit is delivered + its per-SEGMENT hitbox numbers.
## Built from an Action catalog entry's `hit` dict (see configs/actions_khalid.gd). Held by Action.hit;
## null there means the action deals no damage.
##
## The numbers stay as tuning DICTS (damage / knockback / stun / extents / x + effect tags like
## victim_effect / frenemy / lunge) rather than typed fields -- that keeps the combat resolve seam
## (Player.resolve_tuning -> ParticleDirector._inject_tuning -> the effect scene's own Hitbox)
## the same shape the resolve seam always used, and the effect tags are an open, evolving set
## that a dict models better than a fixed schema. Fully typing them is a future refinement.

## Delivery type -- descriptive taxonomy for the build UI (labels the move); does NOT drive behavior,
## which comes from the effect scene the animation fires. Successor to Move.attack_kind.
enum Type { MELEE, PROJECTILE, DELAYED_PROJECTILE, AOE, DELAYED_AOE, BLAST, TRAP }

const _TYPE := {
	"melee": Type.MELEE, "projectile": Type.PROJECTILE, "delayed_projectile": Type.DELAYED_PROJECTILE,
	"aoe": Type.AOE, "delayed_aoe": Type.DELAYED_AOE, "blast": Type.BLAST, "trap": Type.TRAP,
}

var type: Type = Type.MELEE
## Per combo-SEGMENT hitbox tuning dicts -- one entry per hit of a multi-hit combo (spear's 3), a
## single-element list for a one-hit attack. A shorter list reuses its last entry; EMPTY means the
## effect scene carries its own numbers.
var segments: Array = []


## Build from a `hit` dict: { type (string), segments (a dict for one hit, OR an array per segment) }.
## `tuning` is accepted as an alias for `segments`.
static func make(d: Dictionary) -> StrikeSpec:
	var s := StrikeSpec.new()
	s.type = _TYPE.get(String(d.get("type", "melee")), Type.MELEE)
	var t: Variant = d.get("segments", d.get("tuning", []))
	if t is Array:
		s.segments = (t as Array).duplicate()
	elif t is Dictionary and not (t as Dictionary).is_empty():
		s.segments = [t]
	return s


## The tuning dict for combo segment `seg` (a shorter list reuses its last entry; empty list = {}).
func segment(seg: int) -> Dictionary:
	return {} if segments.is_empty() else segments[mini(seg, segments.size() - 1)]
