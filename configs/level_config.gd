class_name LevelConfig
extends RefCounted

## Data for the test level that character_switcher.gd builds in code (the level
## scene stays minimal because the editor keeps clobbering it). Move these into a
## real level scene's inspector when the dev harness is retired.
##
## A small, mostly-horizontal arena on the ground floor (level.tscn's `Floor`) with a
## handful of LOW platforms for light verticality -- the tall vertical-tower idea is
## retired. Real world art is coming; this is a sparring ground, not a climb.

## Player start on the ground floor, left of the cluster so you spawn in the clear.
## Also the respawn point on death / falling out.
const SPAWN := Vector2(-450, 0)
## Fall below this (well under the ground floor at y~0) and you respawn instead of
## dropping forever -- only reachable by leaving the world past the floor's edges.
const DEATH_Y := 300.0

## Jump-up platforms, each [center_x, top_y, width]. A rising zigzag tower: the player
## jump up through each and land on top (press down+jump to drop back through). A low,
## spread-out cluster -- light verticality, nothing to climb. Highest top ~-270.
const PLATFORMS := [
	[-330.0, -95.0, 170.0],
	[-40.0, -150.0, 160.0],
	[250.0, -110.0, 180.0],
	[430.0, -205.0, 150.0],
	[-300.0, -235.0, 150.0],
	[70.0, -270.0, 200.0],
]

## Enemy spawn roster. Each entry: { id, name, pos, and any Enemy @export to override
## per-instance }. ~11 enemies across the ground floor + the low platforms -- a mixed
## sparring pack, not a horde. Ground ranged mobs fire "forward" (straight ahead, no
## homing); see `ranged_mode` to change that. `aggro` stays off (they guard their spot).
##
## Roster: Kebus (melee + straight bolt), Baghel (ground surge), Mazab (lobbed bomb),
## Nasen (sleeper AoE, custom scene), Ein (floating kamikaze orb, custom scene).
const KEBUS := {
	"ranged_mode": "forward",  # straight-ahead bolt, not tracked at the player
	"muzzle_offset": Vector2(18, -22),  # bolt at body height (aimed default -46 sits above his head)
	"ranged_hitbox_extents": Vector2(7, 10),
	"ranged_particle": "res://vfx/enemy/kebus/attack/attack_bolt.tscn",
}
const BAGHEL := {
	"ranged_mode": "forward", "ranged_range": 130.0, "ranged_travel": 100.0, "projectile_speed": 200.0,
	"ranged_particle": "res://vfx/enemy/baghel/attack/attack_ground_wave.tscn",
	"ranged_hitbox_extents": Vector2(4, 15), "ranged_hitbox_offset": Vector2(0, -9),
	"muzzle_offset": Vector2(16, 1), "ranged_damage": 7.0,
	"idle_loop_from": 1, "idle_loop_to": 3, "idle_loop_time": 2.0,
	"idle_time_min": 5.0, "idle_time_max": 7.0,
}
const MAZAB := {
	"ranged_mode": "lob", "ranged_range": 260.0, "attack_align_y": 120.0, "attack_cooldown": 2.2,
	"muzzle_offset": Vector2(18, -40),  # bomb leaves his raised hand
	"ranged_damage": 16.0, "ranged_knockback": 160.0, "ranged_stun": 0.25,
	"lob_arc_time": 0.9, "lob_dwell": 1.0, "lob_explosion_extents": Vector2(48, 26),
	"ranged_particle": "res://vfx/enemy/mazab/attack/mazab_rock.tscn",
	"lob_explosion_effect": "res://vfx/enemy/mazab/attack/mazab_explosion.tscn",
}


## Merge a base kit (KEBUS/BAGHEL/MAZAB) with the per-spawn bits (name + pos + any tweak).
static func _mob(kit: Dictionary, extra: Dictionary) -> Dictionary:
	var out := kit.duplicate(true)
	out.merge(extra, true)
	return out


static func roster() -> Array:
	return [
		# --- Ground floor (y=0, level.tscn Floor) ---
		_mob(KEBUS, {"id": "kebus", "name": "Kebus", "pos": Vector2(-220.0, 0.0)}),
		_mob(BAGHEL, {"id": "baghel", "name": "Baghel", "pos": Vector2(200.0, 0.0)}),
		_mob(MAZAB, {"id": "mazab", "name": "Mazab", "pos": Vector2(360.0, 0.0)}),
		# --- Low platforms ---
		_mob(KEBUS, {"id": "kebus", "name": "Kebus", "pos": Vector2(-330.0, -95.0)}),
		{"scene": "res://scenes/nasen.tscn", "name": "Nasen", "pos": Vector2(-40.0, -150.0)},
		_mob(BAGHEL, {"id": "baghel", "name": "Baghel", "pos": Vector2(250.0, -110.0)}),
		_mob(MAZAB, {"id": "mazab", "name": "Mazab", "pos": Vector2(430.0, -205.0)}),
		_mob(KEBUS, {"id": "kebus", "name": "Kebus", "pos": Vector2(-300.0, -235.0)}),
		_mob(BAGHEL, {"id": "baghel", "name": "Baghel", "pos": Vector2(70.0, -270.0)}),
		# --- Floating kamikaze orbs (spawn in open air; they dive when you get close) ---
		{"scene": "res://scenes/ein.tscn", "name": "Ein", "pos": Vector2(-150.0, -175.0)},
		{"scene": "res://scenes/ein.tscn", "name": "Ein", "pos": Vector2(320.0, -250.0)},
	]
