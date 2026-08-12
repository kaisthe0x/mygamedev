class_name ParryMendBuff
extends Buff

## Per-move buff for Redere Shield: a PERFECT PARRY also HEALS (on top of the reflect it already does).
## Behavioural, via the on_parry hook (fires only on the reflect branch, not a plain block), so it's
## self-scoped to the shield; `applies_to` is here for reward gating / display. Heals a fraction of the
## damage it just turned away, floored so a light hit still gives something back.

const HEAL_FRACTION := 0.5
const HEAL_MIN := 8.0


func _init() -> void:
	id = "parry_mend"
	applies_to = ["redere_shield"]


func on_parry(player: Player, hit: Hit) -> void:
	player.heal(maxf(hit.amount * HEAL_FRACTION, HEAL_MIN))
