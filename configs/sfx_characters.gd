class_name SfxCharacters

## CHARACTER sounds -- PURE DATA (the `Sfx` service reads this; no logic here). Two tables:
##
##   CUES   -- the master list: a stable `key` -> file path. Add one line per sound. Reference it by
##             key everywhere (`Sfx.play("dash")`), or from FRAMES below for frame-synced hits. Paths
##             live ONLY here -- nothing hardcodes a res://sfx path.
##   FRAMES -- character -> animation -> { sheet_frame: cue_key }. The presentation driver
##             (ParticleDirector) plays the cue when that animation reaches that frame. Frames are
##             SHEET-relative (same numbering as the Emitters config / HIT_FRAMES).
##
## Key convention: `<name>` for a whole cue, `<name>.<frame>` for a frame-specific hit (dot before
## the frame number -- matches the enemy `<id>.<type>.<frame>` keys). Files live under sfx/character/.

const CUES := {
	# --- movement / feedback (played by code on an event) ---
	"dash": "res://sfx/character/dash.wav",
	"jump": "res://sfx/character/jump.wav",
	"slam": "res://sfx/character/slam.wav",
	"run": "res://sfx/character/run.wav", # looping footsteps (Sfx.make_loop)
	"ruh_absorb": "res://sfx/character/ruh_absorb.wav", # a Ruh soul lands on Khalid
	# Hurt grunts -- one is picked at RANDOM per hit (Sfx.play_random in Player.take_damage) so he doesn't
	# repeat. Drop 2-3 files here; a missing one is just never picked (so 2 works fine, 3 gives more variety).
	"hurt.1": "res://sfx/character/hurt/hurt_1.wav",
	"hurt.2": "res://sfx/character/hurt/hurt_2.wav",
	"hurt.3": "res://sfx/character/hurt/hurt_3.wav",
	# --- attack / special HITS (played by the director on the FRAMES below) ---
	"twin_reaper.3": "res://sfx/character/attack/twin_reaper/twin_reaper_3.wav",
	"twin_reaper.4": "res://sfx/character/attack/twin_reaper/twin_reaper_4.wav",
	"twin_reaper.6": "res://sfx/character/attack/twin_reaper/twin_reaper_6.wav",
	"twin_reaper.7": "res://sfx/character/attack/twin_reaper/twin_reaper_7.wav",
	"twin_reaper.9": "res://sfx/character/attack/twin_reaper/twin_reaper_9.wav",
	"ora_ora.2": "res://sfx/character/attack/ora_ora/ora_ora_2.wav",
	"ora_ora.4": "res://sfx/character/attack/ora_ora/ora_ora_4.wav",
	"cherry_shots.3": "res://sfx/character/attack/cherry_shots/cherry_shots_3.wav",
	"cherry_shots.7": "res://sfx/character/attack/cherry_shots/cherry_shots_7.wav",
	"spear.6": "res://sfx/character/attack/spear/spear_6.wav",
	"spear.9": "res://sfx/character/attack/spear/spear_9.wav",
	"spear.13": "res://sfx/character/attack/spear/spear_13.wav",
	"bakshen": "res://sfx/character/attack/bakshen/bakshen.wav", # one big charged slash (no per-frame hits)
	# Dual Executioner (upgraded Twin Reaper) -- hit frames 6/9/14/16. Drop the .wav files at these paths
	# (or trim to the frames you actually want a sound on; a missing/omitted cue is just silent).
	"dual_executioner.6": "res://sfx/character/attack/dual_executioner/dual_executioner_6.wav",
	"dual_executioner.9": "res://sfx/character/attack/dual_executioner/dual_executioner_9.wav",
	"dual_executioner.14": "res://sfx/character/attack/dual_executioner/dual_executioner_14.wav",
	"dual_executioner.16": "res://sfx/character/attack/dual_executioner/dual_executioner_16.wav",
	"frenemy": "res://sfx/character/special/frenemy/frenemy.wav",
	"ground_breaker.3": "res://sfx/character/special/ground_breaker/ground_breaker_3.wav",
	"ground_breaker": "res://sfx/character/special/ground_breaker/ground_breaker.wav",
	"special_default": "res://sfx/character/special/default/special_default.wav",
	# New specials -- cast cues on the strike frame. Drop the .wav files at these paths (silent until then).
	"come_closer": "res://sfx/character/special/come_closer/come_closer.wav",
	"redere_shield": "res://sfx/character/special/redere_shield/redere_shield.wav",
	# Shield BLOCK events -- played by CODE in Player._on_hurt when a hit lands on the guard (not frame-synced):
	# a bright PERFECT-PARRY cue vs a duller plain-BLOCK cue. Generic (any shield-tagged special). Drop the files.
	"redere_shield_parry": "res://sfx/character/special/redere_shield/redere_shield_parry.wav",
	"redere_shield_block": "res://sfx/character/special/redere_shield/redere_shield_block.wav",
	"redere_frisbee.1": "res://sfx/character/special/redere_frisbee/redere_frisbee_1.wav",
	"redere_frisbee.impact": "res://sfx/character/special/redere_frisbee/redere_frisbee_impact.wav",
}

const FRAMES := {
	"khalid": {
		"attack_twin_reaper": {3: "twin_reaper.3", 4: "twin_reaper.4", 6: "twin_reaper.6", 7: "twin_reaper.7", 9: "twin_reaper.9"},
		"attack_dual_executioner": {6: "dual_executioner.6", 9: "dual_executioner.9", 14: "dual_executioner.14", 16: "dual_executioner.16"},
		"attack_ora_ora": {2: "ora_ora.2", 4: "ora_ora.4"},
		"attack_cherry_shots": {3: "cherry_shots.3", 7: "cherry_shots.7"},
		"attack_spear": {6: "spear.6", 9: "spear.9", 13: "spear.13"},
		"attack_bakshen": {1: "bakshen"},
		"special_ground_breaker": {1: "ground_breaker", 3: "ground_breaker.3"},
		"special_frenemy": {3: "frenemy"},
		"special_default": {2: "special_default"},
		"special_come_closer": {3: "come_closer"},
		"special_redere_shield": {3: "redere_shield"},
		"special_redere_frisbee": {1: "redere_frisbee.1"},
	},
}
