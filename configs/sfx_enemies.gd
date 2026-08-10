class_name SfxEnemies

## ENEMY sounds -- PURE DATA (read by the `Sfx` service + Enemy). Same shape as SfxCharacters:
##
##   CUES   -- `key` -> path. Conventions the code relies on:
##             * `enemy_death`            -- the shared death cue (Enemy._die).
##             * `<enemy_id>.<type>`      -- an attack START sound, type = `melee` / `projectile`
##                                           (Enemy._play_attack_start_sfx composes this key).
##             * `<enemy_id>.pop`         -- a lobbed bomb's delayed explosion (LobProjectile._explode).
##             * `<enemy_id>.<type>.<frame>` -- a per-frame HIT (referenced from FRAMES).
##   FRAMES -- enemy_id -> animation -> { sheet_frame: cue_key } (Enemy._on_frame_changed). Sheet-relative.
##
## Add a line per sound. A key with no entry = that enemy simply makes no sound there (silent no-op).
## Files live under sfx/enemy/<id>/attack/ (+ the shared sfx/enemy/death.wav).

const CUES := {
	"enemy_death":         "res://sfx/enemy/death.wav",  # any enemy dies (positional)
	# --- attack starts (<id>.<type>) ---
	"kebus.melee":         "res://sfx/enemy/kebus/attack/melee.wav",
	"kebus.projectile":    "res://sfx/enemy/kebus/attack/projectile.wav",
	"baghel.projectile":   "res://sfx/enemy/baghel/attack/projectile.wav",
	"mazab.projectile":    "res://sfx/enemy/mazab/attack/projectile.wav",
	"nasen.melee":         "res://sfx/enemy/nasen/attack/melee.wav",
	# --- lob explosions (<id>.pop) ---
	"mazab.pop":           "res://sfx/enemy/mazab/attack/projectile_pop.wav",
	# --- per-frame hit cues (referenced from FRAMES) ---
	"baghel.projectile.4": "res://sfx/enemy/baghel/attack/projectile_4.wav",
	"kebus.projectile.3":  "res://sfx/enemy/kebus/attack/projectile_3.wav",
	"nasen.melee.2":       "res://sfx/enemy/nasen/attack/melee_2.wav",
}

const FRAMES := {
	"baghel": {"attack_projectile": {4: "baghel.projectile.4"}},
	"kebus":  {"attack_projectile": {3: "kebus.projectile.3"}},
	"nasen":  {"attack": {2: "nasen.melee.2"}},  # the rage AoE erupts on this frame
}
