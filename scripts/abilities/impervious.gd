class_name ImperviousBuff
extends Buff

## SHARED special buff -- "become Impervious after triggering a special". This USED TO BE a hardcoded
## default in Player._start_special; now it's a buff, so specials only grant the invuln window if it's
## equipped. Fires on the special cast (on_special_cast), covering the whole animation.
##
## It keeps the original Ruh coupling: the window is BOUGHT with a Ruh charge (spend_special), so it only
## fires when you have Ruh -- Impervious is still the payoff for the Ruh meter. (When the economy gets its
## own redesign we can decouple the two; for now behaviour matches the old default, minus being free.)
## Shield specials are skipped: they run their own block/parry defense instead.

func _init() -> void:
	id = "impervious"
	applies_to = ["special"]  # shared across every special (metadata / reward gating)


func on_special_cast(player: Player, action: Action) -> void:
	if action != null and action.tags.has("shield"):
		return  # the shield guards itself; no pass-through invuln
	if player.can_special():
		player.spend_special()  # a Ruh charge buys the window
		player.grant_special_invuln()
