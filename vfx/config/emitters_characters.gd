class_name EmittersCharacters

## Per-CHARACTER particle emitters, driven by ParticleDirector on animation frames.
## Keyed id -> animation -> [ rows ]. Row: { scene (preloaded), mode ('sustained'|
## 'burst'), frames (sheet-relative ints or "all"), pos, and optional node /
## clip_to_ground }. Scenes are preload()ed -> a bad path is a PARSE error, and
## everything is resident before the game runs (no lazy load). Hand-edit freely --
## this IS the source of truth (ParticleDirector reads it via Emitters).
const TABLE := {
	"wayna": {
		"spawn": [{"scene": preload("res://vfx/character/wayna/spawn/default/spawn_default.tscn"), "mode": "burst", "frames": [1], "pos": Vector2(0, -16)}],
		"blink_out": [{"scene": preload("res://vfx/character/wayna/other/blink_out.tscn"), "mode": "burst", "pos": Vector2(0, -18)}],
		"blink_in": [{"scene": preload("res://vfx/character/wayna/other/blink_in.tscn"), "mode": "burst", "pos": Vector2(0, -18)}],
		"death": [{"scene": preload("res://vfx/character/wayna/death/default/death_default.tscn"), "mode": "burst", "frames": [4], "pos": Vector2(0, -16)}],
		"run": [
			{"scene": preload("res://vfx/character/wayna/run/default/run_default.tscn"), "node": "WindStreaks", "mode": "sustained", "frames": "all", "pos": Vector2(-17, -17)},
			{"scene": preload("res://vfx/character/wayna/run/default/run_default.tscn"), "node": "Fire", "mode": "sustained", "frames": "all", "pos": Vector2(0, -23)},
		],
		"jump": [{"scene": preload("res://vfx/character/wayna/other/general_wind_streaks.tscn"), "mode": "burst", "frames": [0, 1], "pos": Vector2(0, 0)}],
		"fall": [{"scene": preload("res://vfx/character/wayna/other/general_wind_streaks.tscn"), "mode": "sustained", "frames": "all", "pos": Vector2(0, 0)}],
		"dash": [{"scene": preload("res://vfx/character/wayna/dash/default/dash_default.tscn"), "mode": "sustained", "frames": "all", "pos": Vector2(-12, -5)}],
		"double_jump": [{"scene": preload("res://vfx/character/wayna/jump/default/jump_default.tscn"), "mode": "burst", "pos": Vector2(0, -3)}],
		"attack_chainsaw": [{"scene": preload("res://vfx/character/wayna/attack/chainsaw/attack_chainsaw.tscn"), "mode": "burst", "frames": [3, 4], "pos": Vector2(3, -18)}],
		"special_inferno": [{"scene": preload("res://vfx/character/wayna/special/inferno/special_inferno.tscn"), "mode": "burst", "frames": [3], "pos": Vector2(0, 0)}],
		"slam": [
			{"scene": preload("res://vfx/character/wayna/other/slam_wind_streaks.tscn"), "mode": "sustained", "frames": [0, 1, 2], "pos": Vector2(0, -12)},
			{"scene": preload("res://vfx/character/wayna/slam/default/slam_default.tscn"), "mode": "burst", "frames": [3, 4], "pos": Vector2(0, 0), "clip_to_ground": true},
		],
	},
	"lenbondosen": {
		"spawn": [{"scene": preload("res://vfx/character/lenbondosen/spawn/default/spawn_default.tscn"), "mode": "burst", "frames": [1], "pos": Vector2(0, -16)}],
		"blink_out": [{"scene": preload("res://vfx/character/lenbondosen/other/blink_out.tscn"), "mode": "burst", "pos": Vector2(0, -18)}],
		"blink_in": [{"scene": preload("res://vfx/character/lenbondosen/other/blink_in.tscn"), "mode": "burst", "pos": Vector2(0, -18)}],
		"death": [{"scene": preload("res://vfx/character/lenbondosen/death/default/death_default.tscn"), "mode": "burst", "frames": [7], "pos": Vector2(0, -16)}],
		"idle": [{"scene": preload("res://vfx/character/lenbondosen/other/special_ready.tscn"), "mode": "sustained", "frames": "all", "pos": Vector2(0, -1)}],
		"jump": [{"scene": preload("res://vfx/character/lenbondosen/other/general_wind_streaks.tscn"), "mode": "burst", "frames": [0, 1], "pos": Vector2(0, 0)}],
		"fall": [{"scene": preload("res://vfx/character/lenbondosen/other/general_wind_streaks.tscn"), "mode": "sustained", "frames": "all", "pos": Vector2(0, 0)}],
		"attack_finger_guns": [
			{"scene": preload("res://vfx/character/lenbondosen/attack/finger_guns/attack_finger_guns.tscn"), "node": "ShotSmall", "mode": "burst", "frames": [2], "pos": Vector2(14, -23)},
			{"scene": preload("res://vfx/character/lenbondosen/attack/finger_guns/attack_finger_guns.tscn"), "node": "ShotMid", "mode": "burst", "frames": [4], "pos": Vector2(14, -23)},
			{"scene": preload("res://vfx/character/lenbondosen/attack/finger_guns/attack_finger_guns.tscn"), "node": "ShotBig", "mode": "burst", "frames": [7], "pos": Vector2(20, -23)},
		],
		"special_mouth_blast": [{"scene": preload("res://vfx/character/lenbondosen/special/mouth_blast/special_mouth_blast.tscn"), "mode": "burst", "frames": [6], "pos": Vector2(9, -26)}],
		"special_poison_raiser": [{"scene": preload("res://vfx/character/lenbondosen/special/poison_raiser/special_poison_raiser.tscn"), "mode": "burst", "frames": [4], "pos": Vector2(0, 0), "clip_to_ground": true}],
		"run": [{"scene": preload("res://vfx/character/lenbondosen/run/default/run_default.tscn"), "mode": "sustained", "frames": "all", "pos": Vector2(-17, -17)}],
		"dash": [{"scene": preload("res://vfx/character/lenbondosen/dash/default/dash_default.tscn"), "mode": "sustained", "frames": "all", "pos": Vector2(0, -3)}],
		"double_jump": [{"scene": preload("res://vfx/character/lenbondosen/jump/default/jump_default.tscn"), "mode": "burst", "pos": Vector2(0, 0)}],
		"slam": [
			{"scene": preload("res://vfx/character/lenbondosen/other/slam_wind_streaks.tscn"), "mode": "sustained", "frames": [0, 1, 2], "pos": Vector2(0, -12)},
			{"scene": preload("res://vfx/character/lenbondosen/slam/default/slam_default.tscn"), "mode": "burst", "frames": [3, 4], "pos": Vector2(0, 0), "clip_to_ground": true},
		],
	},
	"katalyst": {
		"spawn": [{"scene": preload("res://vfx/character/katalyst/spawn/default/spawn_default.tscn"), "mode": "burst", "frames": [1], "pos": Vector2(0, -16)}],
		"blink_out": [{"scene": preload("res://vfx/character/katalyst/other/blink_out.tscn"), "mode": "burst", "pos": Vector2(0, -18)}],
		"blink_in": [{"scene": preload("res://vfx/character/katalyst/other/blink_in.tscn"), "mode": "burst", "pos": Vector2(0, -18)}],
		"death": [{"scene": preload("res://vfx/character/katalyst/death/default/death_default.tscn"), "mode": "burst", "frames": [8], "pos": Vector2(0, -16)}],
		"idle": [{"scene": preload("res://vfx/character/katalyst/other/special_ready.tscn"), "mode": "sustained", "frames": "all", "pos": Vector2(0, 0)}],
		"run": [{"scene": preload("res://vfx/character/katalyst/run/default/run_default.tscn"), "mode": "sustained", "frames": "all", "pos": Vector2(-17, -17)}],
		"jump": [{"scene": preload("res://vfx/character/katalyst/other/general_wind_streaks.tscn"), "mode": "burst", "frames": [0, 1], "pos": Vector2(0, 0)}],
		"fall": [{"scene": preload("res://vfx/character/katalyst/other/general_wind_streaks.tscn"), "mode": "sustained", "frames": "all", "pos": Vector2(0, 0)}],
		"dash": [{"scene": preload("res://vfx/character/katalyst/dash/default/dash_default.tscn"), "mode": "sustained", "frames": "all", "pos": Vector2(0, -3)}],
		"double_jump": [{"scene": preload("res://vfx/character/katalyst/jump/default/jump_default.tscn"), "mode": "burst", "pos": Vector2(0, 0)}],
		"attack_rope_dart_dance": [{"scene": preload("res://vfx/character/katalyst/attack/rope_dart_dance/attack_rope_dart_dance.tscn"), "mode": "burst", "frames": [2, 6, 10], "pos": Vector2(9, -22)}],
		"special_double_pierce": [{"scene": preload("res://vfx/character/katalyst/special/double_pierce/special_double_pierce.tscn"), "mode": "burst", "frames": [3], "pos": Vector2(0, 0), "clip_to_ground": true}],
	},
	"feyke": {
		"spawn": [{"scene": preload("res://vfx/character/feyke/spawn/default/spawn_default.tscn"), "mode": "burst", "frames": [0, 1, 2, 3, 4, 5, 6, 7], "pos": Vector2(0, -2)}],
		"blink_out": [{"scene": preload("res://vfx/character/feyke/other/blink_out.tscn"), "mode": "burst", "pos": Vector2(0, -18)}],
		"blink_in": [{"scene": preload("res://vfx/character/feyke/other/blink_in.tscn"), "mode": "burst", "pos": Vector2(0, -18)}],
		"death": [{"scene": preload("res://vfx/character/feyke/death/default/death_default.tscn"), "mode": "burst", "frames": [9], "pos": Vector2(0, -16)}],
		"idle": [{"scene": preload("res://vfx/character/feyke/other/special_ready.tscn"), "mode": "sustained", "frames": "all", "pos": Vector2(0, 0)}],
		"run": [{"scene": preload("res://vfx/character/feyke/run/default/run_default.tscn"), "mode": "sustained", "frames": "all", "pos": Vector2(-17, -17)}],
		"jump": [{"scene": preload("res://vfx/character/feyke/other/general_wind_streaks.tscn"), "mode": "burst", "frames": [0, 1], "pos": Vector2(0, 0)}],
		"fall": [{"scene": preload("res://vfx/character/feyke/other/general_wind_streaks.tscn"), "mode": "sustained", "frames": "all", "pos": Vector2(0, 0)}],
		"dash": [{"scene": preload("res://vfx/character/feyke/dash/default/dash_default.tscn"), "mode": "sustained", "frames": "all", "pos": Vector2(0, -3)}],
		"double_jump": [{"scene": preload("res://vfx/character/feyke/jump/default/jump_default.tscn"), "mode": "burst", "pos": Vector2(0, -3)}],
		"attack_ring_kiss": [{"scene": preload("res://vfx/character/feyke/attack/ring_kiss/attack_ring_kiss.tscn"), "mode": "burst", "frames": [2], "pos": Vector2(16, -26)}],
		"special_f_you": [{"scene": preload("res://vfx/character/feyke/special/f_you/special_f_you.tscn"), "mode": "burst", "frames": [3], "pos": Vector2(0, 0), "clip_to_ground": true}],
		"slam": [
			{"scene": preload("res://vfx/character/feyke/other/slam_wind_streaks.tscn"), "mode": "sustained", "frames": [0, 1, 2], "pos": Vector2(0, -12)},
			{"scene": preload("res://vfx/character/feyke/slam/default/slam_default.tscn"), "mode": "burst", "frames": [3, 4], "pos": Vector2(0, 0), "clip_to_ground": true},
		],
	},
	"khalid": {
		"spawn": [{"scene": preload("res://vfx/character/khalid/spawn/default/spawn_default.tscn"), "mode": "burst", "frames": [1], "pos": Vector2(0, -16)}],
		"death": [{"scene": preload("res://vfx/character/khalid/death/default/death_default.tscn"), "mode": "burst", "frames": [7], "pos": Vector2(0, -16)}],
		"run": [{"scene": preload("res://vfx/character/khalid/run/default/run_default.tscn"), "mode": "sustained", "frames": "all", "pos": Vector2(-17, -17)}],
		"jump": [{"scene": preload("res://vfx/character/khalid/other/general_wind_streaks.tscn"), "mode": "burst", "frames": [0, 1], "pos": Vector2(0, 0)}],
		"fall": [{"scene": preload("res://vfx/character/khalid/other/general_wind_streaks.tscn"), "mode": "sustained", "frames": "all", "pos": Vector2(0, 0)}],
		"dash": [{"scene": preload("res://vfx/character/khalid/dash/default/dash_default.tscn"), "mode": "sustained", "frames": "all", "pos": Vector2(0, -3)}],
		"double_jump": [{"scene": preload("res://vfx/character/khalid/jump/default/jump_default.tscn"), "mode": "burst", "pos": Vector2(0, -3)}],
		"blink_out": [{"scene": preload("res://vfx/character/khalid/other/blink_out.tscn"), "mode": "burst", "pos": Vector2(0, -18)}],
		"blink_in": [{"scene": preload("res://vfx/character/khalid/other/blink_in.tscn"), "mode": "burst", "pos": Vector2(0, -18)}],
		"attack_ora_ora": [{"scene": preload("res://vfx/character/khalid/attack/ora_ora/attack_ora_ora.tscn"), "mode": "burst", "frames": [2, 4], "pos": Vector2(20, -24)}],
		"special_ground_breaker": [{"scene": preload("res://vfx/character/khalid/special/ground_breaker/special_ground_breaker.tscn"), "mode": "burst", "frames": [6], "pos": Vector2(0, 0), "clip_to_ground": true}],
		"slam": [
			{"scene": preload("res://vfx/character/khalid/other/slam_wind_streaks.tscn"), "mode": "sustained", "frames": [0, 1, 2], "pos": Vector2(0, -12)},
			{"scene": preload("res://vfx/character/khalid/slam/default/slam_default.tscn"), "mode": "burst", "frames": [3, 4], "pos": Vector2(0, 0), "clip_to_ground": true},
		],
	},
}
