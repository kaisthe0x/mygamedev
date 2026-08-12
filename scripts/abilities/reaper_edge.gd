class_name ReaperEdgeBuff
extends Buff

## Per-move buff for Twin Reaper: +25% damage on that attack ONLY. The worked example of the NUMBERS
## path -- it overrides modify_tuning and gates it with applies_to_action, so unlike the global "+12%
## attack damage" reward this touches a single move. `damage` is already a tuning key, so no consumer
## change is needed; any move whose segment carries `damage` would buff the same way.

const DAMAGE_MULT := 1.25


func _init() -> void:
	id = "reaper_edge"
	applies_to = ["twin_reaper"]


func modify_tuning(_player: Player, action: Action, _seg: int, tuning: Dictionary) -> Dictionary:
	if applies_to_action(action) and tuning.has("damage"):
		tuning["damage"] = float(tuning["damage"]) * DAMAGE_MULT
	return tuning
