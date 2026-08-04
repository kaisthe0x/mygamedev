class_name Rewards
extends RefCounted

## The reward pool offered at every exit gate. After paying an exit's toll, the player is shown
## a few of these to pick ONE (RewardUI); apply() mutates the player. Data-driven: add a row to
## `pool()` and a case to `apply()` to add a reward -- one place, no other code to touch.
##
## Buffs are per-RUN: they stack across a run and reset when a new run starts (Player.set_character
## + Player.reset_run_buffs, driven by RunManager). Numbers are starting points -- tune freely.


## Every reward: { id, name, desc }. Order/contents free to edit.
static func pool() -> Array:
	return [
		{"id": "air_jump", "name": "Extra Wind",  "desc": "+1 air jump"},
		{"id": "damage",   "name": "Bloodlust",   "desc": "+12% damage"},
		{"id": "lahm_cap", "name": "Deeper Gut",  "desc": "+100 max lahm (bank more life)"},
		{"id": "max_hp",   "name": "Second Skin", "desc": "+25 max HP"},
		{"id": "run",      "name": "Fleetfoot",   "desc": "+10% run speed"},
		{"id": "gorge",    "name": "Gorge",       "desc": "Heal +80 life now"},
	]


## `n` distinct rewards to present at a gate (shuffled). Fewer if the pool is smaller.
static func offer(n: int) -> Array:
	var p := pool()
	p.shuffle()
	return p.slice(0, mini(n, p.size()))


## Apply reward `id` to the player. The single place a reward's EFFECT lives.
static func apply(id: String, player: Player) -> void:
	match id:
		"air_jump": player.max_air_jumps += 1
		"damage":   player.damage_mult += 0.12
		"lahm_cap": player.lahm_cap += 100.0
		"max_hp":   player.max_health += 25.0
		"run":      player.run_speed *= 1.1
		"gorge":    player.gain_life(80.0)
		_: push_warning("Rewards: unknown reward id '%s'" % id)
