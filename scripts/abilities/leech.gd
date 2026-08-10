class_name LeechPassive
extends Passive

## Reward-granted passive (the "Leech" attack reward): heal a fraction of the damage the player deals,
## via the on_hit_dealt hook. Taking it again stacks (each grant is its own passive instance). This is
## the worked example of the Phase 4 passive framework -- a behavioral ability that arrives as a reward.

const FRACTION := 0.08


func _init() -> void:
	id = "leech"


func on_hit_dealt(player: Player, amount: float, _target: Node) -> void:
	if amount > 0.0:
		player.heal(amount * FRACTION)
