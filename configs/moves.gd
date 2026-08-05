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
## Each move entry: { animation (the SpriteFrames anim), effect (label of the
## particle it fires via the Emitters config, keyed by that animation), tuning (the
## melee-hitbox ATTACKS-style dict, or an array per combo segment; 0 damage when the
## effect carries the hit). Characters not listed fall back to LEGACY -- one "attack"
## + one "special" from their generic attack/special sheets -- so they keep
## working until they get named sheets.

## `kind` is the descriptive Combat.AttackKind taxonomy (for the future move-select /
## build UI). `tuning` numbers are the SINGLE source of an attack's hit -- the director
## feeds them into the effect scene's own Hitbox at spawn (see Player.resolve_tuning /
## ParticleDirector._inject_tuning), so nothing is baked in a .tscn. An EMPTY `tuning`
## means "the effect scene carries its own numbers" -- used by finger_guns, whose two
## shots have different damage that one tuning dict can't express.
const CATALOG := {
	"khalid": {
		# No effect scene yet -> nothing spawns a Hitbox, so his swings deal 0 for now
		# (his new look + moveset are coming). The animations still play.
		# Ora ora: a rapid punch FLURRY -- hold attack and the animation loops fast, each
		# punch frame firing the attack_ora_ora Strike (its fist Hitbox carries the hit,
		# fed these numbers). Low per-punch damage/knockback -- the DPS comes from the rate.
		"attacks": {"ora_ora": {"animation": "attack_ora_ora", "effect": "attack_ora_ora", "kind": Combat.AttackKind.MELEE,
			"style": "flurry", "tuning": {"damage": 5, "knockback": 20}}},
		# Ground breaker: an overhead slam that cracks the ground -- a GROUND-type Strike
		# (special_ground_breaker.tscn) whose hitbox SHAPE is authored in the scene (no
		# extents/x here), fed these numbers at spawn. His attack has no effect scene yet.
		"specials": {"ground_breaker": {"animation": "special_ground_breaker", "effect": "special_ground_breaker", "kind": Combat.AttackKind.GROUND, "tier": "elite",
			"tuning": {"damage": 40, "knockback": 160, "stun": 0.2}}},
		"default_attack": "ora_ora", "default_special": "ground_breaker",
	},
	"katalyst": {
		"attacks": {"rope_dart_dance": {"animation": "attack_rope_dart_dance", "kind": Combat.AttackKind.MELEE, "tuning": [
			{"damage": 16, "x": 24.0, "extents": Vector2(22, 18)}, # whip-reach thrust
			{"damage": 16, "x": 0.0, "extents": Vector2(32, 20)}, # spin: AoE around the body
			{"damage": 16, "x": 28.0, "extents": Vector2(24, 18)}, # finishing lunge
		]}},
		# Numbers here; the hitbox SHAPE/position is authored in special_double_pierce.tscn
		# (no extents/x, so the director doesn't override the scene box).
		"specials": {"double_pierce": {"animation": "special_double_pierce", "kind": Combat.AttackKind.GROUND, "tier": "elite", "tuning":
			{"damage": 44, "knockback": 160, "stun": 0.18}}},
		"default_attack": "rope_dart_dance", "default_special": "double_pierce",
	},
	"wayna": {
		# Chainsaw: a forward energy-slash Strike (attack_chainsaw.tscn). Inferno: flames
		# erupt around her (special_inferno.tscn, a fire-burst Strike). Both Hitboxes are
		# fed these numbers at spawn; their shapes are authored in the scenes.
		# MULTI-HIT: the effect fires on "frames": all (6 frames) for the continuous chainsaw look,
		# so a full swing lands ~6 hits -> total ~= damage * 6. Keep per-hit small. (Fire on fewer
		# frames in emitters_characters.gd if you want fewer, chunkier hits instead.)
		"attacks": {
			"chainsaw": {"animation": "attack_chainsaw", "effect": "attack_chainsaw", "kind": Combat.AttackKind.MELEE,
				"tuning": {"damage": 7, "stun": 2.0, "color": Color(0.9068, 0, 0, 0.759)}},
			# Bburn: a lobbed missile that arcs to the nearest enemy, dwells, then erupts (a player
			# LobProjectile -- like Mazab's bomb, fed this damage; the director aims + launches it).
			"bburn": {"animation": "attack_bburn", "effect": "attack_bburn", "kind": Combat.AttackKind.PROJECTILE,
				"tier": "elite", "tuning": {"damage": 32, "knockback": 130, "stun": 0.3}},
			# Shotgun: a BROKEN point-blank blast -- a wide forward Strike, one huge hit.
			"shotgun": {"animation": "attack_shotgun", "effect": "attack_shotgun", "kind": Combat.AttackKind.BLAST,
				"tier": "broken", "tuning": {"damage": 75, "knockback": 200, "stun": 0.3}},
		},
		# A burning field: 10 damage every 0.25s to whoever stands in the semi-circle while
		# it emits (~2s). No per-tick knockback -- it's a burn, not a fling.
		"specials": {"inferno": {"animation": "special_inferno", "effect": "special_inferno", "kind": Combat.AttackKind.BLAST,
			"tuning": {"damage": 10, "tick": 0.25}}},
		"default_attack": "chainsaw", "default_special": "inferno",
	},
	"feyke": {
		# Slam & smoke: his DEFAULT 3-hit smoke combo (attack_slam_n_smoke.tscn) -- ground burst,
		# punch + smoke, bigger punch + more smoke (hits on frames 3/5/7; each segment's damage
		# feeds that hit's box). Ring kiss: a homing "kiss" Projectile, now an ELITE swap.
		"attacks": {
			"slam_n_smoke": {"animation": "attack_slam_n_smoke", "effect": "attack_slam_n_smoke", "kind": Combat.AttackKind.MELEE, "tuning": [
				{"damage": 12},  # ground burst
				{"damage": 14},  # punch + smoke
				{"damage": 45},  # bigger punch + more smoke
			]},
			"ring_kiss": {"animation": "attack_ring_kiss", "effect": "attack_ring_kiss", "kind": Combat.AttackKind.PROJECTILE,
				"tier": "elite", "tuning": {"damage": 14, "knockback": 60}},
		},
		"specials": {"f_you": {"animation": "special_f_you", "kind": Combat.AttackKind.BLAST, "tier": "elite",
			"tuning": {"damage": 38, "knockback": 150}}},  # shape authored in special_f_you.tscn
		"default_attack": "slam_n_smoke", "default_special": "f_you",
	},
	"lenbondosen": {
		"attacks": {
			# Three glowing laser BOLTS (small/bigger/biggest, 14/18/24 dmg) fired across the
			# combo's 3 clicks -- their different per-shot damage can't fit one tuning dict, so
			# each bolt carries its own on its Hitbox and finger_guns keeps an EMPTY tuning
			# (the director doesn't override the scene's numbers).
			"finger_guns": {"animation": "attack_finger_guns", "effect": "attack_finger_guns", "kind": Combat.AttackKind.PROJECTILE,
				"tuning": {}},
		},
		"specials": {
			# Shapes authored in the scenes; only numbers here.
			"poison_raiser": {"animation": "special_poison_raiser", "effect": "special_poison_raiser", "kind": Combat.AttackKind.GROUND,
				"tuning": {"damage": 30, "knockback": 150}},
			"mouth_blast": {"animation": "special_mouth_blast", "effect": "special_mouth_blast", "kind": Combat.AttackKind.BLAST, "tier": "elite",
				"tuning": {"damage": 20}},
		},
		"default_attack": "finger_guns", # <- Lenny's default attack
		"default_special": "poison_raiser", # <- Lenny's default special
	},
}


static func _entry(character: String) -> Dictionary:
	return CATALOG.get(character, {})


## The Move object for a character's attack/special by id, or the default when `id`
## is empty / unknown. `kind` is "attacks" or "specials". Returns null when the pool is
## empty (a character with no special yet, like Wayna) -- callers must tolerate that.
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
