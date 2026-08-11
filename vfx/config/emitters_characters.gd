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
		# Ora ora: the flurry fires its fist burst on the two punch frames (sheet 2 & 4). Per-punch
		# SOUNDS live in SfxCharacters.FRAMES, not here (this config is particles only).
		"attack_ora_ora": [ {"scene": preload("res://vfx/character/khalid/attack/ora_ora/attack_ora_ora.tscn"), "mode": "burst", "frames": [2, 4], "pos": Vector2(23, -22)}],
		# Bakshen: one big charged slash -- the Strike (its hitbox + red burst) fires on the last frame.
		"attack_bakshen": [ {"scene": preload("res://vfx/character/khalid/attack/bakshen/attack_bakshen.tscn"), "mode": "burst", "frames": [3], "pos": Vector2(15, -18)}],
		# Twin Reaper: a 5-hit spinning flurry -- each hit is its OWN scene file (Strike + hitbox +
		# particles), named attack_twin_reaper_<sheetframe>.tscn so the filename tells you which frame it
		# fires on. One row per file, no "node" key -> the whole file fires. This split (vs one bundled
		# palette) means each hit's particles edit in isolation -- open the _N file alone, no soup. Frames
		# still live here in Phase 1; a later generator can infer them from the filenames. Per-hit SOUNDS
		# live in SfxCharacters.FRAMES (same frames), not here -- this config is particles only.
		"attack_twin_reaper": [
			{"scene": preload("res://vfx/character/khalid/attack/twin_reaper/attack_twin_reaper_3.tscn"), "mode": "burst", "frames": [3], "pos": Vector2(14, -18)},
			{"scene": preload("res://vfx/character/khalid/attack/twin_reaper/attack_twin_reaper_4.tscn"), "mode": "burst", "frames": [4], "pos": Vector2(14, -18)},
			{"scene": preload("res://vfx/character/khalid/attack/twin_reaper/attack_twin_reaper_6.tscn"), "mode": "burst", "frames": [6], "pos": Vector2(14, -18)},
			{"scene": preload("res://vfx/character/khalid/attack/twin_reaper/attack_twin_reaper_7.tscn"), "mode": "burst", "frames": [7], "pos": Vector2(14, -18)},
			{"scene": preload("res://vfx/character/khalid/attack/twin_reaper/attack_twin_reaper_9.tscn"), "mode": "burst", "frames": [9], "pos": Vector2(14, -18)},
		],
		# Dual Executioner: the upgraded Twin Reaper -- its own 17-frame spin sheet. Hit frames 6/9/14/16
		# (sheet-relative), each its OWN scene file (Strike + hitbox + particles), named _<sheetframe> so
		# the filename tells you which frame it fires on -- edit each hit in isolation.
		"attack_dual_executioner": [
			{"scene": preload("res://vfx/character/khalid/attack/dual_executioner/attack_dual_executioner_6.tscn"), "mode": "burst", "frames": [6], "pos": Vector2(14, -18)},
			{"scene": preload("res://vfx/character/khalid/attack/dual_executioner/attack_dual_executioner_9.tscn"), "mode": "burst", "frames": [9], "pos": Vector2(10, -18)},
			{"scene": preload("res://vfx/character/khalid/attack/dual_executioner/attack_dual_executioner_14.tscn"), "mode": "burst", "frames": [14], "pos": Vector2(4, -27)},
			{"scene": preload("res://vfx/character/khalid/attack/dual_executioner/attack_dual_executioner_16.tscn"), "mode": "burst", "frames": [16], "pos": Vector2(14, -18)},
		],
		# Cherry Shots: two laser Projectiles, each its own file (see the twin_reaper split note) --
		# attack_cherry_shots_3.tscn launches the small bolt on frame 3, _7 the big one on frame 7.
		"attack_cherry_shots": [
			{"scene": preload("res://vfx/character/khalid/attack/cherry_shots/attack_cherry_shots_3.tscn"), "mode": "burst", "frames": [3], "pos": Vector2(16, -22)},
			{"scene": preload("res://vfx/character/khalid/attack/cherry_shots/attack_cherry_shots_7.tscn"), "mode": "burst", "frames": [7], "pos": Vector2(16, -22)},
		],
		# Spear: a 3-hit combo -- one file per hit (thrust, thrust, big finisher), named by frame.
		"attack_spear": [
			{"scene": preload("res://vfx/character/khalid/attack/spear/attack_spear_6.tscn"), "mode": "burst", "frames": [6], "pos": Vector2(20, -18)},
			{"scene": preload("res://vfx/character/khalid/attack/spear/attack_spear_9.tscn"), "mode": "burst", "frames": [9], "pos": Vector2(22, -18)},
			{"scene": preload("res://vfx/character/khalid/attack/spear/attack_spear_13.tscn"), "mode": "burst", "frames": [13], "pos": Vector2(10, -18)},
		],
		"special_ground_breaker": [ {"scene": preload("res://vfx/character/khalid/special/ground_breaker/special_ground_breaker.tscn"), "mode": "burst", "frames": [6], "pos": Vector2(0, 0), "clip_to_ground": true}],
		"special_frenemy": [ {"scene": preload("res://vfx/character/khalid/special/frenemy/special_frenemy.tscn"), "mode": "burst", "frames": [3], "pos": Vector2(40, -20)}], # the frenemy blast fires on the forward-thrust frame (its sound: SfxCharacters.FRAMES)
		# special_default: the baseline "flex" has NO particles -- so no emitter row. Its cast sound lives
		# in SfxCharacters.FRAMES (played by the director on the flex frame, independent of any particle).
		"slam": [
			{"scene": preload("res://vfx/character/khalid/other/slam_wind_streaks.tscn"), "mode": "sustained", "frames": [0, 1, 2], "pos": Vector2(0, -12)},
			{"scene": preload("res://vfx/character/khalid/slam/default/slam_default.tscn"), "mode": "burst", "frames": [3, 4], "pos": Vector2(0, 0), "clip_to_ground": true},
		],
	},
}
