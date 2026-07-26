class_name Attacks
extends RefCounted

## Per-character player attack data, one place per (character, attack). Read by
## Player._attack(); the melee Hitbox is sized/tuned from the matched entry.
##
## Each entry is a dict of fields that default to 0 / the character's exported
## defaults when unset:
##   damage, knockback (px/s), stun (s), color (engulfing overlay), color_time (s),
##   x (hitbox forward offset from the feet), extents (hitbox half-size)
## `heavy` is one entry. `light` is EITHER one entry (all combo hits share it) OR
## an ARRAY, one per combo segment -- so a specific hit can differ (Lenny's first
## jab freezes; Katalyst's spin is a wide x=0 AoE). Unset fields fall back to the
## Player's exported attack_damage/heavy_damage and attack_hitbox_x/_extents, so an
## entry only lists what's special.

## Engulfing green cast used by Lenny's freezing jab.
const STATUS_GREEN := Color(0.2, 1.0, 0.35, 1.0)

const TABLE := {
	"khalid": {"light": {"damage": 16}, "heavy": {"damage": 46, "knockback": 220}},
	"katalyst": {
		"light": [
			{"damage": 16, "x": 24.0, "extents": Vector2(22, 18)},  # whip-reach thrust
			{"damage": 16, "x": 0.0, "extents": Vector2(32, 20)},   # spin: AoE around the body
			{"damage": 16, "x": 28.0, "extents": Vector2(24, 18)},  # finishing lunge
		],
		"heavy": {"damage": 44, "knockback": 160, "stun": 0.18,
			"x": 30.0, "extents": Vector2(34, 16)},  # long ground blast
	},
	"wayna": {"light": {"damage": 13, "stun": 0.1}, "heavy": {"damage": 32, "knockback": 90}},
	"feyke": {"light": {"damage": 15, "knockback": 45}, "heavy": {"damage": 38, "knockback": 150}},
	"lenbondosen": {
		"light": [
			# Hammer thrust at full impact -- freezes the enemy 5s with a green cast.
			{"damage": 14, "stun": 5.0, "color": STATUS_GREEN, "x": 30.0, "extents": Vector2(26, 18)},
			# Energy burst forming -- AoE around the body (x=0, wide).
			{"damage": 12, "x": 0.0, "extents": Vector2(34, 20)},
			# Burst bloom -- bigger AoE finisher.
			{"damage": 18, "x": 0.0, "extents": Vector2(42, 26)},
		],
		# Heavy's hit is carried by the heavy particle's OWN Hitbox now (authored in
		# heavy.tscn, armed by the ParticleDirector on the burst). The melee box
		# stands down -- 0 so it can't double-hit alongside the particle.
		"heavy": {"damage": 0},
	},
}
