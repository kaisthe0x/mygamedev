class_name Moves
extends RefCounted

## The move catalog: every character's attacks + specials, each with a `tier`
## (typical/elite/broken), and which of each is the DEFAULT. The Player seeds its current
## attack/special from the equipped loadout (defaults until a gate SWAP reward trades one in --
## see configs/loadout.gd + scripts/run/rewards.gd). Tag a move `"tier": "elite"` to rank it.
##
## === TO CHANGE A CHARACTER'S DEFAULT ATTACK / SPECIAL, edit `default_attack` /
## `default_special` in that character's entry below. ===
##
## Each move entry: { animation (the SpriteFrames anim), effect (label of the particle it fires via
## the Emitters config, keyed by that animation), tuning (the melee-hitbox ATTACKS-style dict, or an
## array per combo segment; 0 damage when the effect carries the hit) }.
##
## `kind` is the descriptive Combat.AttackKind taxonomy. `tuning` numbers are the SINGLE source of an
## attack's hit -- the director feeds them into the effect scene's own Hitbox at spawn (see
## Player.resolve_tuning / ParticleDirector._inject_tuning), so nothing is baked in a .tscn. An EMPTY
## `tuning` means "the effect scene carries its own numbers".
##
## Repo ships Khalid only; a character is just its assets + these data rows (parked chars: playground/).
const CATALOG := {
	"khalid": {
		# Ora ora: a rapid punch FLURRY -- hold attack and the animation loops fast, each punch frame
		# firing the attack_ora_ora Strike (its fist Hitbox carries the hit, fed these numbers). Low
		# per-punch damage/knockback -- the DPS comes from the rate.
		"attacks": {
			"ora_ora": {"animation": "attack_ora_ora", "effect": "attack_ora_ora", "kind": Combat.AttackKind.MELEE,
				"style": "flurry", "tuning": {"damage": 15, "knockback": 0, "stun": 0.1, "extents": Vector2(32, 22)}},
			# Spear: a committed 3-hit combo (hits 6/9/13) -- thrust, thrust, big spinning finisher
			# (strongest). Each hit fires its own particle burst; damage per segment below.
			"spear": {"animation": "attack_spear", "effect": "attack_spear", "kind": Combat.AttackKind.MELEE, "tier": "elite", "tuning": [
				{"damage": 10, "knockback": 40}, # thrust
				{"damage": 20, "knockback": 60}, # thrust
				{"damage": 35, "knockback": 140}, # finisher (strongest)
			]},
			# Bakshen: a charged slash -- ~1s wind-up (see FRAME_DURATIONS), then one heavy hit on the
			# last frame. Big single payoff; numbers below feed the attack_bakshen Strike's hitbox.
			"bakshen": {"animation": "attack_bakshen", "effect": "attack_bakshen", "kind": Combat.AttackKind.MELEE, "tier": "elite",
				"tuning": {"damage": 65, "knockback": 0, "stun": 0.0}},
			# Cherry Shots: a two-shot laser volley -- a small bolt on frame 3, a bigger/stronger one on
			# frame 7 (a 2-segment combo, one press each). PROJECTILE kind: the director spawns the
			# ShotSmall / ShotBig Projectile nodes from attack_cherry_shots.tscn; damage per shot below.
			"cherry_shots": {"animation": "attack_cherry_shots", "effect": "attack_cherry_shots", "kind": Combat.AttackKind.PROJECTILE, "tier": "elite", "tuning": [
				{"damage": 22, "knockback": 40}, # small bolt (frame 3)
				{"damage": 42, "knockback": 90}, # big bolt (frame 7, stronger)
			]},
		},
		# Ground breaker: an overhead slam that cracks the ground -- a GROUND-type Strike
		# (special_ground_breaker.tscn) whose hitbox SHAPE is authored in the scene, fed these numbers.
		"specials": {
			"ground_breaker": {"animation": "special_ground_breaker", "effect": "special_ground_breaker", "kind": Combat.AttackKind.GROUND,
				"tuning": {"damage": 40, "knockback": 160, "stun": 1.0, "victim_effect": "res://vfx/status/ground_breaker_stun.tscn"}},
			# Stay: a short blast -- little damage, but a long 5s STUN (knockback 0 so the enemy just
			# freezes in place). Instead of a flat tint, `victim_effect` engulfs the frozen enemy in a
			# bubbling red stun effect (the stay pulse texture) for the stun. A control/utility special.
			"stay": {"animation": "special_stay", "effect": "special_stay", "kind": Combat.AttackKind.BLAST, "tier": "elite",
				"tuning": {"damage": 4, "knockback": 0, "stun": 5.0, "victim_effect": "res://vfx/status/stay_stun.tscn"}},
			# special_default: the BASELINE special the player always starts with -- no damage, no extra
			# effect. Its only job is the invincibility (Impervious) window + aura, which EVERY special
			# now grants (Player.grant_special_invuln, fired on any cast). Others add THEIR effect on top.
			"special_default": {"animation": "special_default", "effect": "special_default", "kind": Combat.AttackKind.BLAST, "tier": "typical",
				"tuning": {}},
		},
		"default_attack": "bakshen", "default_special": "special_default",
	},
}


static func _entry(character: String) -> Dictionary:
	return CATALOG.get(character, {})


## The Move object for a character's attack/special by id, or the default when `id`
## is empty / unknown. `kind` is "attacks" or "specials". Returns null when the pool is
## empty (a character with no attacks/specials of that kind) -- callers must tolerate that.
static func get_move(character: String, kind: String, id := "") -> Move:
	var entry := _entry(character)
	var pool: Dictionary = entry.get(kind, {})
	if pool.is_empty():
		return null
	if id.is_empty() or not pool.has(id):
		id = entry["default_attack"] if kind == "attacks" else entry["default_special"]
	if not pool.has(id):
		return null
	return Move.make("attack" if kind == "attacks" else "special", id, pool[id])


## Ids of a character's available attacks / specials (Loadout builds swap options from these).
static func ids(character: String, kind: String) -> Array:
	return _entry(character).get(kind, {}).keys()
