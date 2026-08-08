class_name Rewards
extends RefCounted

## Reward pools, split by DOOR TYPE. Each level rolls ONE random door type (RunManager); clearing
## the arena opens that door, and the player picks ONE of that type's rewards. `apply()` mutates
## the player. Buffs are per-RUN (reset by Player.begin_run). Every reward has an icon via the
## `Icons` registry (`Icons.buff(id)`, or the `icon_key` a swap card carries).
##
## Door types: HEALTH / ATHLETIC / ATTACK / SPECIAL. The SPECIAL door also mixes in CHANGE-SPECIAL
## swap cards (built from the character's other specials). Attacks are RUN-LOCKED -- never swapped,
## only buffed (the ATTACK door).
##
## Numbers are placeholders -- tune freely. A few effects are WIP (stored on the player but not yet
## fully realised); they're marked in the desc and safe to pick.

## door_type -> [ {id, name, desc}, ... ]
const POOLS := {
	"health": [
		{"id": "mend",     "name": "Mend",        "desc": "Heal +40 HP now"},
		{"id": "max_hp",   "name": "Second Skin", "desc": "+25 max HP (and heal it)"},
	],
	"athletic": [
		{"id": "air_jump", "name": "Extra Wind",  "desc": "+1 air jump"},
		{"id": "run",      "name": "Fleetfoot",   "desc": "+10% run speed"},
		{"id": "tough",    "name": "Thick Hide",  "desc": "-10% damage taken"},
		{"id": "slam_dmg", "name": "Meteor",      "desc": "+25% slam damage"},
	],
	"attack": [
		{"id": "reach",     "name": "Long Arm",   "desc": "+15% attack reach"},
		{"id": "atk_dmg",   "name": "Bloodlust",  "desc": "+12% attack damage"},
		{"id": "lifesteal", "name": "Leech",      "desc": "Heal 8% of damage dealt"},
		{"id": "multishot", "name": "Split Shot", "desc": "+1 projectile (WIP)"},
	],
	"special": [
		{"id": "ruh_cap",       "name": "Deeper Ruh",  "desc": "+1 Ruh charge (max 5)"},
		{"id": "longer_imp",    "name": "Fortitude",   "desc": "+3s Impervious duration"},
		{"id": "imp_until_hit", "name": "Last Stand",  "desc": "Impervious until you're hit (WIP)"},
		{"id": "bigger_blast",  "name": "Wide Impact", "desc": "+20% special hit radius (WIP)"},
	],
}


## `n` rewards for a `door_type`, shuffled. The SPECIAL door also mixes in change-special swaps.
static func offer_for(door_type: String, player: Player, n: int) -> Array:
	var pool: Array = (POOLS.get(door_type, []) as Array).duplicate(true)
	if door_type == "special" and player != null:
		for choice: Dictionary in player.loadout_choices():
			if String(choice["category"]) != "special":
				continue
			var o: Dictionary = choice["option"]
			pool.append({
				"id": "swap:special:%s" % o["id"],
				"name": o["name"],
				"desc": "Change special · %s" % Loadout.tier_label(o["tier"]),
				"tier": o["tier"],                  # RewardUI badges/tints by this
				"icon_key": "special:%s" % o["id"], # the special's own icon
			})
	pool.shuffle()
	return pool.slice(0, mini(n, pool.size()))


## Apply reward `id` to the player -- the single place a reward's EFFECT lives.
static func apply(id: String, player: Player) -> void:
	if id.begins_with("swap:"):
		var parts := id.split(":")  # swap:<category>:<option_id>
		if parts.size() == 3:
			player.equip(parts[1], parts[2])
		return
	match id:
		# health
		"mend":          player.heal(40.0)
		"max_hp":        player.max_health += 25.0; player.heal(25.0)
		# athletic
		"air_jump":      player.max_air_jumps += 1
		"run":           player.run_mult *= 1.1; player.equip("run", player.loadout_id("run"))
		"tough":         player.damage_taken_mult *= 0.9
		"slam_dmg":      player.slam_damage_mult *= 1.25
		# attack
		"reach":         player.attack_reach_mult *= 1.15
		"atk_dmg":       player.damage_mult += 0.12
		"lifesteal":     player.lifesteal_frac += 0.08
		"multishot":     player.attack_projectile_bonus += 1
		# special
		"ruh_cap":       player.ruh_cap += Player.RUH_PER_BLOCK
		"longer_imp":    player.special_invuln_bonus += 3.0
		"imp_until_hit": player.impervious_until_hit = true
		"bigger_blast":  player.special_radius_mult *= 1.2
		_: push_warning("Rewards: unknown reward id '%s'" % id)
