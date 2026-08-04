extends CharacterAbility

## Lenny: no special ability hook right now. His special is a close-range burst --
## damage comes from the melee box (ATTACKS "special" in player.gd) and the look
## from a particle burst (the Emitters config -> lenbondosen -> special_poison_raiser),
## so nothing extra needs to fire on the strike frame.


func on_special_strike(_player: Player) -> void:
	pass
