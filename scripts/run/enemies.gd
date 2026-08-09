class_name EnemyKits
extends RefCounted

## The enemy roster for the run — one named kit per enemy TYPE, referenced by the level/wave
## tables in run/levels.gd. A kit is a spawn spec: either an `id` (built from the generic
## scenes/enemy.tscn with that enemy_id) or a custom `scene`, plus any Enemy @export overrides
## (combat tuning). The particle LOOK for each lives in the Emitters config, not here.
##
## `tier` is design shorthand for wave-building (how many of each to throw): STRONG enemies are
## dangerous/high-HP (and pay the most lahm, since lahm = HP); CHIP enemies are fodder. Use it
## to keep waves fair — e.g. "3 strong" vs "5 chip + 1 strong". It's advisory, not enforced.

enum Tier { CHIP, MID, STRONG }

# --- the types --------------------------------------------------------------

const KEBUS := {
	"id": "kebus", "tier": Tier.STRONG,
	"ranged_mode": "forward", "ranged_hitbox_extents": Vector2(7, 10),
	"ranged_travel": 180.0, "projectile_speed": 200.0,
}
const BAGHEL := {
	"id": "baghel", "tier": Tier.CHIP,
	"ranged_mode": "forward", "ranged_range": 130.0, "ranged_travel": 100.0, "projectile_speed": 200.0,
	"ranged_hitbox_extents": Vector2(4, 15), "ranged_hitbox_offset": Vector2(0, -9), "ranged_damage": 7.0,
	"idle_loop_from": 1, "idle_loop_to": 3, "idle_loop_time": 2.0, "idle_time_min": 5.0, "idle_time_max": 7.0,
}
const MAZAB := {
	"id": "mazab", "tier": Tier.MID,
	"ranged_mode": "lob", "ranged_range": 260.0, "attack_align_y": 120.0, "attack_cooldown": 2.2,
	"ranged_damage": 16.0, "ranged_knockback": 160.0, "ranged_stun": 0.25,
	"lob_arc_time": 0.9, "lob_dwell": 1.0, "lob_explosion_extents": Vector2(48, 26),
}
const NASEN := {"scene": "res://scenes/nasen.tscn", "tier": Tier.STRONG, "optional": true}  # optional: needn't be killed to clear
const EIN := {"scene": "res://scenes/ein.tscn", "tier": Tier.MID}
