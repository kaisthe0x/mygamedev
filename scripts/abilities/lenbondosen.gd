extends CharacterAbility

## Lenny: no special ability hook right now. His special is a close-range burst --
## damage comes from the melee box (ATTACKS "special" in player.gd) and the look
## from a particle burst (emitters.json -> lenbondosen -> special_poison_raiser),
## so nothing extra needs to fire on the strike frame.
##
## (He used to fire a forward energy beam here; the laser was removed project-wide.
## If beams come back later, re-add a scene + fire it from on_special_strike.)


func on_special_strike(_player: Player) -> void:
	pass
