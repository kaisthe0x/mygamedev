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
	"idle_time_min": 5.0, "idle_time_max": 7.0, # idle bounces frame 1..last by default (settle then breathe)
}
const MAZAB := {
	"id": "mazab", "tier": Tier.MID, "attack_type": "delayed_projectile",
	"ranged_mode": "lob", "ranged_range": 260.0, "attack_align_y": 120.0, "attack_cooldown": 2.2,
	"ranged_damage": 16.0, "ranged_knockback": 160.0, "ranged_stun": 0.25,
	"lob_arc_time": 0.9, "lob_dwell": 1.0, "lob_explosion_extents": Vector2(48, 26),
}
# Nasen: a stationary SLEEPER (the SleeperEnemy archetype). Dozes until the player is near, then rage-loops an
# AoE; melee stuns him, ranged only chips. Now a pure KIT -- identity + tuning here, behaviour in SleeperEnemy.cs.
const NASEN := {
	"scene": "res://scenes/sleeper_enemy.tscn", "id": "nasen", "display_name": "Nasen",
	"max_health": 90.0, "tier": Tier.STRONG, "optional": true, "attack_type": "aoe", # optional: needn't be killed to clear
}
# Ein: a floating kamikaze dive-bomber (the DiverEnemy archetype). Floats + bobs, locks the player's position
# and dive-bombs it, erupting an AoE on arrival/contact. Now a pure KIT -- behaviour in DiverEnemy.cs.
const EIN := {
	"scene": "res://scenes/diver_enemy.tscn", "id": "ein", "display_name": "Ein", "max_health": 28.0,
	"body_size": Vector2(22, 22), "hurtbox_size": Vector2(26, 26), "move_speed": 34.0, "patrol_distance": 70.0,
	"tier": Tier.MID,
}
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
# Tarri: a lit-yellow BLAST caster -- his own take on Bakshen's charged strike, just with more REACH. Being
# pure-MELEE he WALKS into his line (aligned + within melee_range), then on the LAST attack frame ERUPTS a
# wide STATIONARY forward blast in front (a melee Strike, NOT a travelling shot) while he HOLDS + vibrates
# for ~2s (`attack_hitstop` + `attack_shake`). The blast's hitbox reaches forward (melee_hitbox_x + extents)
# and stays live `melee_strike_lifetime` (~2s) so its particles sustain. `attack_type "blast"` keys the SFX
# (`tarri.blast` at the start + `tarri.blast.3` on the frame) and the strike VFX (EmittersEnemies `tarri ->
# blast`, which rides the strike), plus a passive `patrol_trail`.
const TARRI := {
	"id": "tarri", "display_name": "Tarri", "tier": Tier.MID, "attack_type": "blast",
	"max_health": 70.0, "body_size": Vector2(18, 24), "hurtbox_size": Vector2(22, 28),
	"move_speed": 34.0, "patrol_distance": 100.0,
	"melee_range": 140.0, "attack_align_y": 52.0, "attack_cooldown": 2.6,
	"melee_hitbox_x": 70.0, "melee_hitbox_extents": Vector2(70, 22), "melee_strike_lifetime": 2.0,
	"melee_damage": 16.0, "melee_knockback": 120.0, "melee_stun": 0.3,
	"attack_hitstop": 2.0, "attack_shake": 1.5, # hold + vibrate on the attack frame for the ~2s blast
}
# Breski: a blood-red BRUISER with a 2-hit melee COMBO. Being pure-melee (anim `attack`, no projectile) he
# WALKS into range (melee_range is DERIVED from his 1st-hit scene's hitbox reach) and swings twice -- a jab
# on frame 4, a heavier follow-up on frame 9 (HIT_FRAMES). Each hit spawns its OWN self-contained Strike
# scene (own hitbox + VFX), keyed by FRAME: `breski -> melee_4` (jab) / `melee_9` (heavy) in EmittersEnemies, and
# gets its own light hit-stop (attack_hitstop re-arms per hit). `attack_type "melee"` keys the start SFX
# (`breski.melee`) + the per-hit SFX (`breski.melee.4` / `.9`, from SfxEnemies.FRAMES). No hitbox exports --
# the scenes author their own reach (the current standard).
const BRESKI := {
	"id": "breski", "display_name": "Breski", "tier": Tier.STRONG, "attack_type": "melee",
	"max_health": 110.0, "body_size": Vector2(18, 28), "hurtbox_size": Vector2(22, 34),
	"move_speed": 46.0, "patrol_distance": 90.0,
	"melee_range": 56.0, "attack_align_y": 44.0, "attack_cooldown": 1.8, # melee_range is a fallback (derived on _ready)
	"melee_damage": 10.0, "melee_knockback": 130.0, "melee_stun": 0.2, # per hit; both combo hits share this tuning
	"attack_hitstop": 0.12, "attack_shake": 1.0, # a light freeze + shake on EACH of the two hits
}
