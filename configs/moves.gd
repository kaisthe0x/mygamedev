class_name Moves
extends RefCounted

## The move catalog: every character's attacks + specials, and which of each is the
## DEFAULT (until an in-game UI lets the player switch). The Player seeds its current
## attack/special from these defaults on character change -- see Player.set_move().
##
## === TO CHANGE A CHARACTER'S DEFAULT ATTACK / SPECIAL, edit `default_attack` /
## `default_special` in that character's entry below. ===
##
## Each move entry: { animation (the SpriteFrames anim), effect (label of the
## particle it fires via emitters.json, keyed by that animation), tuning (the
## melee-hitbox ATTACKS-style dict, or an array per combo segment; 0 damage when the
## effect carries the hit). Characters not listed fall back to LEGACY -- one "attack"
## + one "special" from their generic attack/special sheets -- so they keep
## working until they get named sheets.

const CATALOG := {
	"khalid": {
		"attacks": {"strike": {"animation": "attack", "tuning": {"damage": 16}}},
		"specials": {"smash": {"animation": "special_smash", "tuning": {"damage": 46, "knockback": 220}}},
		"default_attack": "strike", "default_special": "smash",
	},
	"katalyst": {
		"attacks": {"rope_dart_dance": {"animation": "attack_rope_dart_dance", "tuning": [
			{"damage": 16, "x": 24.0, "extents": Vector2(22, 18)}, # whip-reach thrust
			{"damage": 16, "x": 0.0, "extents": Vector2(32, 20)}, # spin: AoE around the body
			{"damage": 16, "x": 28.0, "extents": Vector2(24, 18)}, # finishing lunge
		]}},
		"specials": {"double_pierce": {"animation": "special_double_pierce", "tuning":
			{"damage": 44, "knockback": 160, "stun": 0.18, "x": 30.0, "extents": Vector2(34, 16)}}},
		"default_attack": "rope_dart_dance", "default_special": "double_pierce",
	},
	"wayna": {
		# Chainsaw: a forward energy-slash swing. Its particle (emitters.json ->
		# attack_chainsaw) carries the hit via its OWN Hitbox, so the melee box stands
		# down (damage 0) -- tune the actual damage on that particle scene's Hitbox.
		"attacks": {"chainsaw": {"animation": "attack_chainsaw", "effect": "attack_chainsaw",
			"tuning": {"damage": 0}}},
		"specials": {"burst": {"animation": "special_burst", "tuning": {"damage": 32, "knockback": 90}}},
		"default_attack": "chainsaw", "default_special": "burst",
	},
	"feyke": {
		# Ring kiss: a homing "kiss" shot (like Lenny's finger guns) -- one burst of
		# three particles. Its projectile carries the hit (attacks/attack_ring_kiss.tscn),
		# so the melee box stands down (damage 0).
		"attacks": {"ring_kiss": {"animation": "attack_ring_kiss", "effect": "attack_ring_kiss",
			"tuning": {"damage": 0}}},
		"specials": {"f_you": {"animation": "special_f_you",
			"tuning": {"damage": 38, "knockback": 150, "x": 20.0, "extents": Vector2(34, 22)}}},
		"default_attack": "ring_kiss", "default_special": "f_you",
	},
	"lenbondosen": {
		"attacks": {
			# A forward shot. Its particle carries the hit (attacks/attack_finger_guns.tscn),
			# so the melee box stands down (damage 0).
			"finger_guns": {"animation": "attack_finger_guns", "effect": "attack_finger_guns",
				"tuning": {"damage": 0}},
		},
		"specials": {
			"poison_raiser": {"animation": "special_poison_raiser", "effect": "special_poison_raiser",
				"tuning": {"damage": 30, "knockback": 150, "x": 0.0, "extents": Vector2(38, 24)}},
			# Was an attack combo; now a single-strike special.
			"mouth_blast": {"animation": "special_mouth_blast", "effect": "special_mouth_blast",
				"tuning": {"damage": 20, "x": 0.0, "extents": Vector2(40, 26)}},
		},
		"default_attack": "finger_guns", # <- Lenny's default attack
		"default_special": "poison_raiser", # <- Lenny's default special
	},
}

## Fallback for any character not in CATALOG: their generic attack + special
## sheets as a single attack and a single special (damage from the Player's exports).
const LEGACY := {
	"attacks": {"attack": {"animation": "attack", "tuning": {}}},
	"specials": {"special": {"animation": "special", "tuning": {}}},
	"default_attack": "attack", "default_special": "special",
}


static func _entry(character: String) -> Dictionary:
	return CATALOG.get(character, LEGACY)


## The Move object for a character's attack/special by id, or the default when `id`
## is empty / unknown. `kind` is "attacks" or "specials".
static func get_move(character: String, kind: String, id := "") -> Move:
	var entry := _entry(character)
	var pool: Dictionary = entry[kind]
	if id.is_empty() or not pool.has(id):
		id = entry["default_attack"] if kind == "attacks" else entry["default_special"]
	return Move.make("attack" if kind == "attacks" else "special", id, pool[id])


## Ids of a character's available attacks / specials (for a future switch UI).
static func ids(character: String, kind: String) -> Array:
	return _entry(character)[kind].keys()
