class_name EmittersEnemies

## Per-ENEMY particle emitters. Same { scene (preloaded), pos } schema as EmittersCharacters, but enemy
## effects are attached in code by state/event (not fired on animation frames), so rows carry no frames/mode.
##
## NAMING -- keep it tight and standardised. A row's key is the attack's STRIKE TYPE, straight from the
## taxonomy in configs/strike_spec.gd: `melee`, `projectile`, `delayed_projectile`, `aoe`, `delayed_aoe`,
## `blast`, `trap`. Never an ad-hoc name ("rage", "explosion"). A COMPONENT of an attack appends a role:
##   * `<type>_burst`  -- the explosion/payload of a projectile (mazab's `delayed_projectile_burst`)
##   * `<type>_trail`  -- the motion trail leading into it (ein's `delayed_aoe_trail`)
## A passive, non-attack trail (worn by movement, not a strike) is `<state>_trail` (e.g. `patrol_trail`).
## So: `nasen -> aoe`, `matat -> aoe`, `mazab -> delayed_projectile (+_burst)`, `ein -> delayed_aoe (+_trail)`.
##
## AUTHORITATIVE for presence: no row = no emitter (combat still runs). For a projectile, `pos` is the
## muzzle. Hand-edit freely -- this IS the source of truth.
const TABLE := {
	# --- projectile (a straight/aimed shot) ---
	"kebus": {
		"projectile": {"scene": preload("res://vfx/enemy/kebus/attack/kebus_projectile.tscn"), "pos": Vector2(18, -22)},
	},
	"baghel": {
		"projectile": {"scene": preload("res://vfx/enemy/baghel/attack/baghel_projectile.tscn"), "pos": Vector2(16, 1)},
	},
	# --- delayed_projectile (a lobbed bomb that dwells, then bursts) ---
	"mazab": {
		"delayed_projectile": {"scene": preload("res://vfx/enemy/mazab/attack/mazab_delayed_projectile.tscn"), "pos": Vector2(18, -40)},
		"delayed_projectile_burst": {"scene": preload("res://vfx/enemy/mazab/attack/mazab_delayed_projectile_burst.tscn"), "pos": Vector2(0, 0)},
	},
	# --- aoe (a shockwave erupting in place) ---
	"nasen": {
		"aoe": {"scene": preload("res://vfx/enemy/nasen/attack/nasen_aoe.tscn"), "pos": Vector2(0, 0)},
	},
	"matat": {
		"aoe": {"scene": preload("res://vfx/enemy/matat/attack/matat_aoe.tscn"), "pos": Vector2(0, -10)},
	},
	# --- delayed_aoe (a charge/dive that AoE-blasts on arrival) + its dive trail ---
	"ein": {
		"delayed_aoe": {"scene": preload("res://vfx/enemy/ein/attack/ein_delayed_aoe.tscn"), "pos": Vector2(0, -16)},
		"delayed_aoe_trail": {"scene": preload("res://vfx/enemy/ein/attack/ein_delayed_aoe_trail.tscn"), "pos": Vector2(0, -12)},
	},
	# --- blast (a wide STATIONARY forward blast -- a melee strike, like Bakshen with more reach) + patrol trail.
	# The blast VFX rides the strike (already placed at melee_hitbox_x forward), so `pos` is just a body-height nudge.
	"tarri": {
		"blast": {"scene": preload("res://vfx/enemy/tarri/attack/tarri_blast.tscn"), "pos": Vector2(15, -17)},
		"patrol_trail": {"scene": preload("res://vfx/enemy/tarri/patrol/tarri_patrol_trail.tscn"), "pos": Vector2(0, -6)},
	},
	# --- melee (a 2-hit COMBO -- each hit is its own self-contained Strike scene, keyed by the SHEET FRAME it
	# fires on (`melee_<frame>`, matching HIT_FRAMES + the `breski.melee.<frame>` SFX): `melee_4` = the jab
	# (frame 4), `melee_9` = the heavier follow-up (frame 9). `pos` places the whole strike (burst + hitbox).
	"breski": {
		"melee_4": {"scene": preload("res://vfx/enemy/breski/attack/breski_melee_4.tscn"), "pos": Vector2(26, -18)},
		"melee_9": {"scene": preload("res://vfx/enemy/breski/attack/breski_melee_9.tscn"), "pos": Vector2(32, -20)},
	},
}
