class_name EmittersEnemies

## Per-ENEMY particle emitters. Same schema as EmittersCharacters, but enemy effects
## are attached in code by state/event (a trail worn by state, a blast on arrival, a
## projectile visual), so rows carry no frames/mode -- just { scene (preloaded), pos }.
## AUTHORITATIVE for presence: no row = no emitter (combat still runs). For a
## projectile, pos is the muzzle. Hand-edit freely -- this IS the source of truth.
const TABLE := {
	"ein": {
		"attack_trail": {"scene": preload("res://vfx/enemy/ein/attack/ein_attack_trail.tscn"), "pos": Vector2(0, -12)},
		"explosion": {"scene": preload("res://vfx/enemy/ein/attack/ein_explosion.tscn"), "pos": Vector2(0, -16)},
	},
	"nasen": {
		"rage": {"scene": preload("res://vfx/enemy/nasen/attack/nasen_rage.tscn"), "pos": Vector2(0, 0)},
	},
	"kebus": {
		"projectile": {"scene": preload("res://vfx/enemy/kebus/attack/attack_bolt.tscn"), "pos": Vector2(18, -22)},
	},
	"baghel": {
		"projectile": {"scene": preload("res://vfx/enemy/baghel/attack/attack_ground_wave.tscn"), "pos": Vector2(16, 1)},
	},
	"mazab": {
		"projectile": {"scene": preload("res://vfx/enemy/mazab/attack/mazab_rock.tscn"), "pos": Vector2(18, -40)},
		"explosion": {"scene": preload("res://vfx/enemy/mazab/attack/mazab_explosion.tscn"), "pos": Vector2(0, 0)},
	},
}
