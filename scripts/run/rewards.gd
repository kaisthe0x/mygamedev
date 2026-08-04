class_name Rewards
extends RefCounted

## The reward pool offered at every exit gate. After paying an exit's toll, the player is shown
## a few of these to pick ONE (RewardUI); apply() mutates the player. Data-driven: add a row to
## `pool()` and a case to `apply()` to add a reward -- one place, no other code to touch.
##
## Buffs are per-RUN: they stack across a run and reset when a new run starts (Player.begin_run,
## driven by RunManager). Numbers are starting points -- tune freely.
##
## NOTE since the lahm rework: HP heals ONLY through rewards (damage no longer has a lahm shield),
## so `mend` / `max_hp` are the lifeline -- keep a healing option in every offer's odds in mind.


## Every reward: { id, name, desc }. Order/contents free to edit.
static func pool() -> Array:
	return [
		{"id": "mend",      "name": "Mend",       "desc": "Heal +40 HP now"},
		{"id": "max_hp",    "name": "Second Skin", "desc": "+25 max HP (and heal it)"},
		{"id": "damage",    "name": "Bloodlust",  "desc": "+12% damage (harvest lahm faster)"},
		{"id": "block_cap", "name": "Deeper Gut", "desc": "+2 lahm blocks (hold more)"},
		{"id": "air_jump",  "name": "Extra Wind", "desc": "+1 air jump"},
		{"id": "run",       "name": "Fleetfoot",  "desc": "+10% run speed"},
	]


## `n` distinct rewards to present at a gate (shuffled). Fewer if the pool is smaller.
static func offer(n: int) -> Array:
	var p := pool()
	p.shuffle()
	return p.slice(0, mini(n, p.size()))


## Apply reward `id` to the player. The single place a reward's EFFECT lives.
static func apply(id: String, player: Player) -> void:
	match id:
		"mend":      player.heal(40.0)
		"max_hp":    player.max_health += 25.0; player.heal(25.0)
		"damage":    player.damage_mult += 0.12
		"block_cap": player.lahm_cap += 2.0 * Player.LAHM_PER_BLOCK  # +2 blocks
		"air_jump":  player.max_air_jumps += 1
		"run":       player.run_speed *= 1.1
		_: push_warning("Rewards: unknown reward id '%s'" % id)
