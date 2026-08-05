class_name Rewards
extends RefCounted

## The reward pool offered at every exit gate. After paying an exit's toll, the player is shown
## a few of these to pick ONE (RewardUI); apply() mutates the player. Two kinds:
##  - STAT rewards (heal, +damage, +block, ...): a row in `pool()` + a case in `apply()`.
##  - LOADOUT SWAPS: generated from the character's Loadout (configs/loadout.gd) -- offered
##    whenever a category (attack/special/run/jump/dash/slam) has more than one option, so the
##    player can trade up to an Elite/Broken move as they progress. Their id is "swap:<cat>:<opt>".
##
## Buffs are per-RUN: they reset when a new run starts (Player.begin_run). Numbers are starting
## points -- tune freely.
##
## NOTE since the lahm rework: HP heals ONLY through rewards, so keep a heal in the mix.


## Stat rewards: { id, name, desc }. Loadout swaps are added on top in offer().
static func pool() -> Array:
	return [
		{"id": "mend",      "name": "Mend",       "desc": "Heal +40 HP now"},
		{"id": "max_hp",    "name": "Second Skin", "desc": "+25 max HP (and heal it)"},
		{"id": "damage",    "name": "Bloodlust",  "desc": "+12% damage (harvest lahm faster)"},
		{"id": "block_cap", "name": "Deeper Gut", "desc": "+2 lahm blocks (hold more)"},
		{"id": "air_jump",  "name": "Extra Wind", "desc": "+1 air jump"},
		{"id": "run",       "name": "Fleetfoot",  "desc": "+10% run speed"},
	]


## `n` rewards to present at a gate (shuffled): the stat pool + any loadout-swap cards this
## character currently qualifies for (trade up to an Elite/Broken move). Fewer if the pool is small.
static func offer(n: int, player: Player = null) -> Array:
	var p := pool()
	if player != null:
		for choice: Dictionary in player.loadout_choices():
			var o: Dictionary = choice["option"]
			p.append({
				"id": "swap:%s:%s" % [choice["category"], o["id"]],
				"name": o["name"],
				"desc": "New %s · %s" % [String(choice["category"]).capitalize(), Loadout.tier_label(o["tier"])],
				"tier": o["tier"],  # RewardUI colours the card by this
			})
	p.shuffle()
	return p.slice(0, mini(n, p.size()))


## Apply reward `id` to the player. The single place a reward's EFFECT lives.
static func apply(id: String, player: Player) -> void:
	if id.begins_with("swap:"):
		var parts := id.split(":")  # swap:<category>:<option_id>
		if parts.size() == 3:
			player.equip(parts[1], parts[2])
		return
	match id:
		"mend":      player.heal(40.0)
		"max_hp":    player.max_health += 25.0; player.heal(25.0)
		"damage":    player.damage_mult += 0.12
		"block_cap": player.lahm_cap += 2.0 * Player.LAHM_PER_BLOCK  # +2 blocks
		"air_jump":  player.max_air_jumps += 1
		"run":       player.run_mult *= 1.1; player.equip("run", player.loadout_id("run"))  # re-seed w/ buff
		_: push_warning("Rewards: unknown reward id '%s'" % id)
