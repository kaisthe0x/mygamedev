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
	# --- attack / special HITS (played by the director on the FRAMES below) ---
	"twin_reaper.3": "res://sfx/character/attack/twin_reaper/twin_reaper_3.wav",
	"twin_reaper.4": "res://sfx/character/attack/twin_reaper/twin_reaper_4.wav",
	"twin_reaper.6": "res://sfx/character/attack/twin_reaper/twin_reaper_6.wav",
	"twin_reaper.7": "res://sfx/character/attack/twin_reaper/twin_reaper_7.wav",
	"twin_reaper.9": "res://sfx/character/attack/twin_reaper/twin_reaper_9.wav",
	"ora_ora.2": "res://sfx/character/attack/ora_ora/ora_ora_2.wav",
	"ora_ora.4": "res://sfx/character/attack/ora_ora/ora_ora_4.wav",
	# Dual Executioner (upgraded Twin Reaper) -- hit frames 6/9/14/16. Drop the .wav files at these paths
	# (or trim to the frames you actually want a sound on; a missing/omitted cue is just silent).
	"dual_executioner.6": "res://sfx/character/attack/dual_executioner/dual_executioner_6.wav",
	"dual_executioner.9": "res://sfx/character/attack/dual_executioner/dual_executioner_9.wav",
	"dual_executioner.14": "res://sfx/character/attack/dual_executioner/dual_executioner_14.wav",
	"dual_executioner.16": "res://sfx/character/attack/dual_executioner/dual_executioner_16.wav",
	"frenemy": "res://sfx/character/special/frenemy/frenemy.wav",
	"special_ground_breaker.3": "res://sfx/character/special/ground_breaker/ground_breaker_3.wav",
	"special_ground_breaker": "res://sfx/character/special/ground_breaker/ground_breaker.wav",
	"special_default": "res://sfx/character/special/default/special_default.wav",
}

const FRAMES := {
	"khalid": {
		"attack_twin_reaper": {3: "twin_reaper.3", 4: "twin_reaper.4", 6: "twin_reaper.6", 7: "twin_reaper.7", 9: "twin_reaper.9"},
		"attack_dual_executioner": {6: "dual_executioner.6", 9: "dual_executioner.9", 14: "dual_executioner.14", 16: "dual_executioner.16"},
		"attack_ora_ora": {2: "ora_ora.2", 4: "ora_ora.4"},
		"special_ground_breaker": {1: "special_ground_breaker", 3: "special_ground_breaker.3"},
		"special_frenemy": {3: "frenemy"},
		"special_default": {2: "special_default"},
	},
}
