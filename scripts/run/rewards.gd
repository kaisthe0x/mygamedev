class_name Rewards
extends RefCounted

## Reward OFFER + EFFECT logic over the typed catalog (RewardsCatalog / Reward) -- build-aware (Phase 4).
## The DATA lives in configs/rewards_catalog.gd; this service filters/weights the offer by the queryable
## Build (conditional rewards) and applies the chosen reward's effect. Buffs are per-RUN (reset by
## Player.begin_run). Effects are one of: equip a move (upgrade), grant a Passive (ability), or a stat
## buff keyed by id below.
##
## Door types: HEALTH / ATHLETIC / ATTACK / SPECIAL. The SPECIAL door also mixes in CHANGE-SPECIAL swap
## cards (built from the character's other specials). Attacks are run-locked -- buffed or UPGRADED
## (a conditional swap, e.g. Dual Executioner), never freely swapped.


## `n` rewards for a `door_type`, build-aware: only OFFERABLE rewards (requires + unique gates), sampled
## without replacement weighted by synergy. The SPECIAL door also mixes in change-special swap cards.
static func offer_for(door_type: String, player: Player, n: int) -> Array:
	var build := Build.of(player)
	var weighted := []  # [{card, weight}]
	for d: Dictionary in RewardsCatalog.POOLS.get(door_type, []):
		var r := Reward.make(door_type, d)
		if r.offerable(build):
			weighted.append({"card": r.to_card(), "weight": r.weight(build)})
	if door_type == "special" and player != null:
		for choice: Dictionary in player.loadout_choices():
			if String(choice["category"]) != "special":
				continue
			var o: Dictionary = choice["option"]
			weighted.append({"card": {
				"id": "swap:special:%s" % o["id"], "name": o["name"],
				"desc": "Change special · %s" % Loadout.tier_label(o["tier"]),
				"tier": o["tier"], "icon": o["icon"],
			}, "weight": 1.0})
	return _sample(weighted, n)


## Sample up to `n` cards from `[{card, weight}]` WITHOUT replacement, weighted (roulette).
static func _sample(entries: Array, n: int) -> Array:
	var pool := entries.duplicate()
	var out := []
	while not pool.is_empty() and out.size() < n:
		var total := 0.0
		for e: Dictionary in pool:
			total += e["weight"]
		var pick := randf() * total
		var idx := 0
		for i in pool.size():
			pick -= pool[i]["weight"]
			if pick <= 0.0:
				idx = i
				break
		out.append(pool[idx]["card"])
		pool.remove_at(idx)
	return out


## Apply reward `id` to the player -- the single place a reward's EFFECT lives. Records it on the build.
static func apply(id: String, player: Player) -> void:
	if id.begins_with("swap:"):
		var parts := id.split(":")  # swap:<category>:<option_id>
		if parts.size() == 3:
			player.equip(parts[1], parts[2])
		player.record_reward(id)
		return
	var r := _find(id)
	if r == null:
		push_warning("Rewards: unknown reward id '%s'" % id)
		return
	player.record_reward(id)
	if not r.equip.is_empty():                                  # a move swap / upgrade
		player.equip(String(r.equip["category"]), String(r.equip["id"]))
		return
	if not r.passive.is_empty():                                # a behavioral passive (ability)
		var p := _make_passive(r.passive)
		if p != null:
			player.add_passive(p)
		return
	_buff(id, player)                                           # a stat buff


## The Reward with this id, searching every door pool (null if none).
static func _find(id: String) -> Reward:
	for door: String in RewardsCatalog.POOLS:
		for d: Dictionary in RewardsCatalog.POOLS[door]:
			if String(d["id"]) == id:
				return Reward.make(door, d)
	return null


## Instantiate a reward-granted Passive by id (scripts/abilities/<id>.gd). Null (with a warning) if
## missing or not a Passive.
static func _make_passive(passive_id: String) -> Passive:
	var path := "res://scripts/abilities/%s.gd" % passive_id
	if ResourceLoader.exists(path):
		var p: Variant = load(path).new()
		if p is Passive:
			return p
	push_warning("Rewards: no Passive script for '%s' at %s" % [passive_id, path])
	return null


## Stat-buff effects, keyed by reward id (the ones that just tweak a Player stat).
static func _buff(id: String, player: Player) -> void:
	match id:
		# health
		"mend":          player.heal(40.0)
		"max_hp":        player.max_health += 25.0; player.heal(25.0)
		# athletic
		"air_jump":      player.air_jump_bonus += 1; player.equip("jump", player.loadout_id("jump"))
		"run":           player.run_mult *= 1.1; player.equip("run", player.loadout_id("run"))
		"tough":         player.damage_taken_mult *= 0.9
		"slam_dmg":      player.slam_damage_mult *= 1.25
		"crimson_vortex": player.set_dash_effect("dash_crimson_vortex")
		# attack
		"reach":         player.attack_reach_mult *= 1.15
		"atk_dmg":       player.damage_mult += 0.12
		"multishot":     player.attack_projectile_bonus += 1
		# special
		"ruh_cap":       player.ruh_cap += Player.RUH_PER_BLOCK
		"longer_imp":    player.special_invuln_bonus += 3.0
		"imp_until_hit": player.impervious_until_hit = true
		"bigger_blast":  player.special_radius_mult *= 1.2
		_: push_warning("Rewards: unhandled buff id '%s'" % id)
