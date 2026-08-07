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
		"dash": [ {"scene": preload("res://vfx/character/khalid/dash/default/dash_default.tscn"), "mode": "sustained", "frames": "all", "pos": Vector2(0, -3)}],
		"double_jump": [ {"scene": preload("res://vfx/character/khalid/jump/default/jump_default.tscn"), "mode": "burst", "pos": Vector2(0, -3)}],
		"blink_out": [ {"scene": preload("res://vfx/character/khalid/other/blink_out.tscn"), "mode": "burst", "pos": Vector2(0, -18)}],
		"blink_in": [ {"scene": preload("res://vfx/character/khalid/other/blink_in.tscn"), "mode": "burst", "pos": Vector2(0, -18)}],
		"attack_ora_ora": [ {"scene": preload("res://vfx/character/khalid/attack/ora_ora/attack_ora_ora.tscn"), "mode": "burst", "frames": [2, 4], "pos": Vector2(23, -22)}],
		# Spear: one DISTINCT hit-node per frame (thrust, thrust, big finisher). Each row fires one by name.
		"attack_spear": [
			{"scene": preload("res://vfx/character/khalid/attack/spear/attack_spear.tscn"), "node": "Thrust1", "mode": "burst", "frames": [6], "pos": Vector2(20, -18)},
			{"scene": preload("res://vfx/character/khalid/attack/spear/attack_spear.tscn"), "node": "Thrust2", "mode": "burst", "frames": [9], "pos": Vector2(22, -18)},
			{"scene": preload("res://vfx/character/khalid/attack/spear/attack_spear.tscn"), "node": "Finisher", "mode": "burst", "frames": [13], "pos": Vector2(10, -18)},
		],
		"special_ground_breaker": [ {"scene": preload("res://vfx/character/khalid/special/ground_breaker/special_ground_breaker.tscn"), "mode": "burst", "frames": [6], "pos": Vector2(0, 0), "clip_to_ground": true}],
		"special_stay": [ {"scene": preload("res://vfx/character/khalid/special/stay/special_stay.tscn"), "mode": "burst", "frames": [3], "pos": Vector2(30, -20)}], # the stun blast fires on the forward-thrust frame
		"slam": [
			{"scene": preload("res://vfx/character/khalid/other/slam_wind_streaks.tscn"), "mode": "sustained", "frames": [0, 1, 2], "pos": Vector2(0, -12)},
			{"scene": preload("res://vfx/character/khalid/slam/default/slam_default.tscn"), "mode": "burst", "frames": [3, 4], "pos": Vector2(0, 0), "clip_to_ground": true},
		],
	},
}
