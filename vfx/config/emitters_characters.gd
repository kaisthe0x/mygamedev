class_name EmittersCharacters

## Per-CHARACTER particle emitters, driven by ParticleDirector on animation frames.
## Keyed id -> animation -> [ rows ]. Row: { scene (preloaded), mode ('sustained'|
## 'burst'), frames (sheet-relative ints or "all"), pos, and optional node /
## clip_to_ground }. Scenes are preload()ed -> a bad path is a PARSE error, and
## everything is resident before the game runs (no lazy load). Hand-edit freely --
## this IS the source of truth (ParticleDirector reads it via Emitters).
const TABLE := {
	"khalid": {
		"spawn": [ {"scene": preload("res://vfx/character/khalid/spawn/default/spawn_default.tscn"), "mode": "burst", "frames": [1], "pos": Vector2(0, -16)}],
		"death": [ {"scene": preload("res://vfx/character/khalid/death/default/death_default.tscn"), "mode": "burst", "frames": [7], "pos": Vector2(0, -16)}],
		"run": [ {"scene": preload("res://vfx/character/khalid/run/default/run_default.tscn"), "mode": "sustained", "frames": "all", "pos": Vector2(-17, -17)}],
		"jump": [ {"scene": preload("res://vfx/character/khalid/other/general_wind_streaks.tscn"), "mode": "burst", "frames": [0, 1], "pos": Vector2(0, 0)}],
		"fall": [ {"scene": preload("res://vfx/character/khalid/other/general_wind_streaks.tscn"), "mode": "sustained", "frames": "all", "pos": Vector2(0, 0)}],
		# DASH EFFECTS ("dash_*"): the dash has ONE active effect (Player._dash_effect), fired on
		# dash-start. Each is a code-fired EVENT scene -- its "Trail" node FOLLOWS the player, every
		# other node LINGERS at the drop point (see ParticleDirector._spawn_followers). A reward swaps
		# the active effect; the STARTING one is Player.STARTING_DASH_EFFECT. Add a "dash_<name>" key
		# for a new variant -- give it a Trail (follows) + whatever else (a lingering hazard, etc).
		"dash_default": [ {"scene": preload("res://vfx/character/khalid/dash/default/dash_default.tscn"), "mode": "burst", "pos": Vector2(0, -3)}],
		"dash_crimson_vortex": [ {"scene": preload("res://vfx/character/khalid/dash/crimson_vortex/dash_crimson_vortex.tscn"), "mode": "burst", "pos": Vector2(0, -16)}],
		"double_jump": [ {"scene": preload("res://vfx/character/khalid/jump/default/jump_default.tscn"), "mode": "burst", "pos": Vector2(0, -3)}],
		"blink_out": [ {"scene": preload("res://vfx/character/khalid/other/blink_out.tscn"), "mode": "burst", "pos": Vector2(0, -18)}],
		"blink_in": [ {"scene": preload("res://vfx/character/khalid/other/blink_in.tscn"), "mode": "burst", "pos": Vector2(0, -18)}],
		"attack_ora_ora": [ {"scene": preload("res://vfx/character/khalid/attack/ora_ora/attack_ora_ora.tscn"), "mode": "burst", "frames": [2, 4], "pos": Vector2(23, -22)}],
		# Bakshen: one big charged slash -- the Strike (its hitbox + red burst) fires on the last frame.
		"attack_bakshen": [ {"scene": preload("res://vfx/character/khalid/attack/bakshen/attack_bakshen.tscn"), "mode": "burst", "frames": [3], "pos": Vector2(15, -18)}],
		# Twin Reaper: a 5-hit spinning combo -- one DISTINCT Strike node (hitbox + particles) fires per
		# hit frame (3/4/6/7/9). Same damage each (moves.gd). Tweak each node's particles in the scene.
		"attack_twin_reaper": [
			{"scene": preload("res://vfx/character/khalid/attack/twin_reaper/attack_twin_reaper.tscn"), "node": "Slash1", "mode": "burst", "frames": [3], "pos": Vector2(14, -18)},
			{"scene": preload("res://vfx/character/khalid/attack/twin_reaper/attack_twin_reaper.tscn"), "node": "Slash2", "mode": "burst", "frames": [4], "pos": Vector2(14, -18)},
			{"scene": preload("res://vfx/character/khalid/attack/twin_reaper/attack_twin_reaper.tscn"), "node": "Slash3", "mode": "burst", "frames": [6], "pos": Vector2(14, -18)},
			{"scene": preload("res://vfx/character/khalid/attack/twin_reaper/attack_twin_reaper.tscn"), "node": "Slash4", "mode": "burst", "frames": [7], "pos": Vector2(14, -18)},
			{"scene": preload("res://vfx/character/khalid/attack/twin_reaper/attack_twin_reaper.tscn"), "node": "Slash5", "mode": "burst", "frames": [9], "pos": Vector2(14, -18)},
		],
		# Cherry Shots: two laser Projectiles -- the small bolt launches on frame 3, the big one on frame 7.
		"attack_cherry_shots": [
			{"scene": preload("res://vfx/character/khalid/attack/cherry_shots/attack_cherry_shots.tscn"), "node": "ShotSmall", "mode": "burst", "frames": [3], "pos": Vector2(16, -22)},
			{"scene": preload("res://vfx/character/khalid/attack/cherry_shots/attack_cherry_shots.tscn"), "node": "ShotBig", "mode": "burst", "frames": [7], "pos": Vector2(16, -22)},
		],
		# Spear: one DISTINCT hit-node per frame (thrust, thrust, big finisher). Each row fires one by name.
		"attack_spear": [
			{"scene": preload("res://vfx/character/khalid/attack/spear/attack_spear.tscn"), "node": "Thrust1", "mode": "burst", "frames": [6], "pos": Vector2(20, -18)},
			{"scene": preload("res://vfx/character/khalid/attack/spear/attack_spear.tscn"), "node": "Thrust2", "mode": "burst", "frames": [9], "pos": Vector2(22, -18)},
			{"scene": preload("res://vfx/character/khalid/attack/spear/attack_spear.tscn"), "node": "Finisher", "mode": "burst", "frames": [13], "pos": Vector2(10, -18)},
		],
		"special_ground_breaker": [ {"scene": preload("res://vfx/character/khalid/special/ground_breaker/special_ground_breaker.tscn"), "mode": "burst", "frames": [6], "pos": Vector2(0, 0), "clip_to_ground": true}],
		"special_frenemy": [ {"scene": preload("res://vfx/character/khalid/special/frenemy/special_frenemy.tscn"), "mode": "burst", "frames": [3], "pos": Vector2(40, -20)}], # the frenemy blast fires on the forward-thrust frame
		"slam": [
			{"scene": preload("res://vfx/character/khalid/other/slam_wind_streaks.tscn"), "mode": "sustained", "frames": [0, 1, 2], "pos": Vector2(0, -12)},
			{"scene": preload("res://vfx/character/khalid/slam/default/slam_default.tscn"), "mode": "burst", "frames": [3, 4], "pos": Vector2(0, 0), "clip_to_ground": true},
		],
	},
}
