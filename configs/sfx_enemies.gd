class_name SfxEnemies

## ENEMY sounds -- PURE DATA (read by the `Sfx` service + Enemy). Same shape as SfxCharacters.
##
## NAMING mirrors the emitters (EmittersEnemies): keys are the attack's STRIKE TYPE from
## configs/strike_spec.gd -- `melee`, `projectile`, `delayed_projectile`, `aoe`, `delayed_aoe`, ...
##   CUES   -- `key` -> path. Conventions the code relies on:
##             * `enemy_death`               -- the shared death cue (Enemy._die).
##             * `enemy_spawn`               -- the shared spawn cue (RunManager._spawn_fx, with the puff).
##             * `<enemy_id>.<type>`         -- an attack START sound. `type` = the enemy's `attack_type`
##                                              (set per kit), else melee/projectile from the anim
##                                              (Enemy._play_attack_start_sfx).
##             * `<enemy_id>.<type>.<frame>` -- a per-frame HIT (referenced from FRAMES).
##             * `<enemy_id>.delayed_projectile_burst` -- a lob's delayed explosion (Enemy._fire_lob).
##   FRAMES -- enemy_id -> animation -> { sheet_frame: cue_key } (Enemy._on_frame_changed). Sheet-relative.
##
## Files live under sfx/enemy/<id>/attack/<type>[...].wav (+ the shared sfx/enemy/enemy_death.wav /
## enemy_spawn.wav). A key with no entry = that enemy makes no sound there (silent no-op).

const CUES := {
	"enemy_death": "res://sfx/enemy/enemy_death.wav",  # any enemy dies (positional)
	"enemy_spawn": "res://sfx/enemy/enemy_spawn.wav",  # a batch enemy spawns w/ the puff (positional) -- PLACEHOLDER
	# --- attack starts (<id>.<type>) ---
	"kebus.melee": "res://sfx/enemy/kebus/attack/melee.wav",
	"kebus.projectile": "res://sfx/enemy/kebus/attack/projectile.wav",
	"baghel.projectile": "res://sfx/enemy/baghel/attack/projectile.wav",
	"mazab.delayed_projectile": "res://sfx/enemy/mazab/attack/delayed_projectile.wav",
	"nasen.aoe": "res://sfx/enemy/nasen/attack/aoe.wav",
	"matat.aoe": "res://sfx/enemy/matat/attack/aoe.wav",  # PLACEHOLDER -- AoE wind-up/roar
	"tarri.blast": "res://sfx/enemy/tarri/attack/blast.wav",  # PLACEHOLDER -- blast channel wind-up (attack start)
	"ein.delayed_aoe": "res://sfx/enemy/ein/attack/delayed_aoe.wav",  # ein's arrival blast (ein.gd)
	# --- delayed_projectile bursts (<id>.delayed_projectile_burst) ---
	"mazab.delayed_projectile_burst": "res://sfx/enemy/mazab/attack/delayed_projectile_burst.wav",
	# --- per-frame hit cues (referenced from FRAMES) ---
	"baghel.projectile.4": "res://sfx/enemy/baghel/attack/projectile_4.wav",
	"kebus.projectile.3": "res://sfx/enemy/kebus/attack/projectile_3.wav",
	"nasen.aoe.2": "res://sfx/enemy/nasen/attack/aoe_2.wav",
	"matat.aoe.4": "res://sfx/enemy/matat/attack/aoe_4.wav",  # PLACEHOLDER -- the AoE erupt/impact
	"tarri.blast.3": "res://sfx/enemy/tarri/attack/blast_3.wav",  # PLACEHOLDER -- the blast FIRES (last frame)
}

const FRAMES := {
	"baghel": {"attack_projectile": {4: "baghel.projectile.4"}},
	"kebus": {"attack_projectile": {3: "kebus.projectile.3"}},
	"nasen": {"attack": {2: "nasen.aoe.2"}},  # the rage AoE erupts on this frame
	"matat": {"attack": {4: "matat.aoe.4"}},  # the AoE erupts on this frame (sheet-relative)
	"tarri": {"attack": {3: "tarri.blast.3"}},  # the blast erupts on the last frame (sheet-relative)
	# (ein's arrival blast is a CODE event, not a sprite frame -- played from ein.gd via "ein.delayed_aoe".)
}
