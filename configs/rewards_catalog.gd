class_name RewardsCatalog

## The reward catalog -- PURE DATA (the `Rewards` service turns these into Reward objects, applies the
## build conditions, and runs the effects). `door_type -> [ reward dicts ]`; each level rolls ONE door
## type (RunManager), clearing the arena opens it, and the player picks one offered reward.
##
## Each row is a `Reward.make` dict (see configs/reward.gd). Most are plain buffs (effect keyed by `id`
## in Rewards._buff). A few are build-aware (Phase 4): `requires` gates the offer, `synergy` nudges the
## roll weight, `equip` upgrades a move, `passive` grants a behavioral ability. Numbers are placeholders.
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
		{"id": "crimson_vortex", "name": "Crimson Vortex", "desc": "Your dash leaves a damaging vortex"},
	],
	"attack": [
		# SYNERGY: a charm special (frenemy) equipped makes reach ~3x likelier to roll -- crowds you charm
		# are easier to reach into. Still just a nudge; it can roll without the synergy too.
		{"id": "reach",     "name": "Long Arm",  "desc": "+15% attack reach",
			"synergy": {"when": {"tag": "charm"}, "weight": 3.0}},
		{"id": "atk_dmg",   "name": "Bloodlust", "desc": "+12% attack damage"},
		# PASSIVE reward: grants the Leech behavioral passive (on_hit_dealt lifesteal).
		{"id": "lifesteal", "name": "Leech",     "desc": "Heal 8% of damage dealt", "passive": "leech"},
		{"id": "multishot", "name": "Split Shot", "desc": "+1 projectile (WIP)"},
		# PER-MOVE BUFF: +25% damage on Twin Reaper only (the modify_tuning path). Offered once Twin
		# Reaper is equipped; unique so it can't double up. Grants scripts/abilities/reaper_edge.gd.
		{"id": "reaper_edge", "name": "Reaper's Edge", "desc": "+25% Twin Reaper damage", "unique": true,
			"requires": {"equipped": "twin_reaper"}, "passive": "reaper_edge"},
		# INDEPENDENT MOVE (was an upgrade of Twin Reaper): now a standalone attack you can swap to, no
		# longer gated on owning Twin Reaper. It upgrades via its OWN buffs, not by superseding another move.
		{"id": "dual_executioner", "name": "Dual Executioner",
			"desc": "A bigger, deadlier twin-blade spin",
			"icon": "res://vfx/shared/textures/blast1.png", "tier": "broken", "unique": true,
			"equip": {"category": "attack", "id": "dual_executioner"}},
	],
	"special": [
		{"id": "ruh_cap",       "name": "Deeper Ruh",  "desc": "+1 Ruh charge (max 5)"},
		{"id": "longer_imp",    "name": "Fortitude",   "desc": "+3s Aegis (invuln) duration"}, # special_invuln_bonus stacks onto the surge window
		{"id": "imp_until_hit", "name": "Last Stand",  "desc": "Aegis lasts until you're hit (WIP)"},
		{"id": "bigger_blast",  "name": "Wide Impact", "desc": "+20% special hit radius (WIP)"},
		# PER-MOVE BUFF: a perfect parry with Redere Shield also heals. Offered once the Shield is equipped.
		{"id": "parry_mend", "name": "Guardian's Mend", "unique": true,
			"desc": "Perfect parry also heals you", "requires": {"equipped": "redere_shield"},
			"passive": "parry_mend"},
		# NOTE: no explicit "swap to Redere Frisbee" card here on purpose. Specials are freely swappable, so
		# Rewards.offer_for already mixes in a change-special swap card for EVERY special option (built from
		# the character's catalog) -- an explicit equip reward would double it up (the "Redere Frisbee" +
		# "Frisbee" pair). Attacks differ: they're NOT swap-carded, so Dual Executioner's equip reward in the
		# attack pool IS its only acquisition and stays.
	],
}
