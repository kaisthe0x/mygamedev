class_name EnemyKits
extends RefCounted

## The enemy roster for the run — one named kit per enemy TYPE, referenced by the level/wave
## tables in run/levels.gd. A kit is a spawn spec: either an `id` (built from the generic
## scenes/enemy.tscn with that enemy_id) or a custom `scene`, plus any Enemy @export overrides
## (combat tuning). The particle LOOK lives in the Emitters config and the SOUNDS in `SfxEnemies`
## (keyed by enemy_id) -- neither is wired in the kit here.
##
## `tier` is design shorthand for wave-building (how many of each to throw): STRONG enemies are
## dangerous/high-HP (and pay the most lahm, since lahm = HP); CHIP enemies are fodder. Use it
## to keep waves fair — e.g. "3 strong" vs "5 chip + 1 strong". It's advisory, not enforced.

enum Tier {CHIP, MID, STRONG}

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
	"id": "mazab", "tier": Tier.MID, "attack_type": "delayed_projectile",
	"ranged_mode": "lob", "ranged_range": 260.0, "attack_align_y": 120.0, "attack_cooldown": 2.2,
	"ranged_damage": 16.0, "ranged_knockback": 160.0, "ranged_stun": 0.25,
	"lob_arc_time": 0.9, "lob_dwell": 1.0, "lob_explosion_extents": Vector2(48, 26),
}
const NASEN := {"scene": "res://scenes/nasen.tscn", "tier": Tier.STRONG, "optional": true, "attack_type": "aoe"} # optional: needn't be killed to clear
const EIN := {"scene": "res://scenes/ein.tscn", "tier": Tier.MID}
# Matat: a big MELEE AoE bruiser. Like the other enemies he PATROLS and only engages when the player is
# in his line (roughly his own height, within `ranged_range`) -- NOT aggro, so he doesn't relentlessly
# follow. Being pure-melee he then WALKS IN (Enemy._act closes the gap for a melee-only enemy) and sweeps
# his arms for a wide AoE centred on himself (a shockwave, hitbox + VFX). `attack_loops` keeps the WHOLE
# swing CYCLING (re-erupting the AoE each pass) while you stay in reach -- no one-swing-then-freeze; the
# loop ends (-> cooldown) when you leave. `attack_hitstop 0` keeps it smooth. Damage low since it repeats.
# `melee_hitbox_x 0` centres the AoE box; wide extents make it an AoE. VFX = EmittersEnemies `matat -> aoe`.
const MATAT := {
	"id": "matat", "display_name": "Matat", "tier": Tier.STRONG, "attack_type": "aoe",
	"max_health": 95.0, "body_size": Vector2(20, 34), "hurtbox_size": Vector2(24, 40),
	"move_speed": 40.0, "patrol_distance": 90.0, "ranged_range": 300.0,
	"melee_range": 52.0, "attack_align_y": 44.0, "attack_cooldown": 1.2,
	"attack_loops": true, "attack_hitstop": 0.0,
	"melee_damage": 11.0, "melee_knockback": 150.0, "melee_stun": 0.25,
	"melee_hitbox_x": 0.0, "melee_hitbox_extents": Vector2(46, 30), "melee_strike_lifetime": 0.35,
}
