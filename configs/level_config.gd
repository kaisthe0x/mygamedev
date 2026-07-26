class_name LevelConfig
extends RefCounted

## Data for the test level that character_switcher.gd builds in code (the level
## scene stays minimal because the editor keeps clobbering it). Move these into a
## real level scene's inspector when the dev harness is retired.

## Player start, kept well left of every enemy so you spawn in the clear. Also the
## respawn point on death / falling out.
const SPAWN := Vector2(-450, 0)
## Fall below this (far under the ground) and you respawn instead of dropping forever.
const DEATH_Y := 300.0

## Jump-up platforms, each [center_x, top_y, width]. A rising staircase where each
## step is within one jump of the one below, so you can hop ground -> P1 -> P2 -> P3.
## One-way, so you jump up through and land on top.
const PLATFORMS := [
	[-40.0, -44.0, 160.0],   # P1
	[130.0, -80.0, 160.0],   # P2 (overlaps P1 -> forgiving hop up)
	[300.0, -114.0, 150.0],  # P3 (overlaps P2)
]

## Enemy spawn roster. Each entry: { id, name, pos, and any Enemy @export to
## override per-instance }. One of each for now, so you can learn a matchup without
## being swarmed. (In a real level you'd drop enemy.tscn in and set these in the
## inspector instead.)
const ROSTER := [
	{"id": "kebus", "name": "Kebus", "pos": Vector2(150, 0)},      # ground stroller
	# Baghel: ranged-only, short-range ground surge, scratches his back at rest.
	{
		"id": "baghel", "name": "Baghel", "pos": Vector2(470, 0),
		"ranged_mode": "forward", "ranged_range": 130.0, "ranged_travel": 100.0,
		"projectile_speed": 200.0,
		"ranged_particle": "res://vfx/particles/enemies/baghel/ground_wave.tscn",
		"ranged_hitbox_extents": Vector2(4, 15), "ranged_hitbox_offset": Vector2(0, -9),
		"muzzle_offset": Vector2(16, 1), "ranged_damage": 7.0,  # y~ground so the wave touches it
		"idle_loop_from": 1, "idle_loop_to": 3, "idle_loop_time": 2.0,
		"idle_time_min": 5.0, "idle_time_max": 7.0,  # long rests so he lingers, scratching
	},
]
