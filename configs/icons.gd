class_name Icons
extends RefCounted

## Central ICON registry -- ONE place mapping every attack / special / reward-door / buff to a
## texture. Everything UI (reward cards, doors, the attack picker, the HUD) asks HERE for its icon,
## so when real art lands you swap a PATH below and nothing else changes -- no UI refactor.
##
## Keys are NAMESPACED: "attack:<id>", "special:<id>", "door:<type>", "buff:<id>". Look them up with
## `Icons.texture(key)` or the typed helpers (`Icons.attack("spear")`, `Icons.door("health")`, ...).
## Textures load lazily + cache, so unmapped/unused icons cost nothing and adding one is a single
## line. Anything missing falls back to FALLBACK (so a new move/buff is never iconless).
##
## >>> TODO(art): every path below is a TEMPORARY placeholder (reused existing pngs). Replace with
## real icons as they're drawn -- one line each, no code changes elsewhere. <<<

const FALLBACK := "res://vfx/shared/textures/soft_dot.png"

const PATHS := {
	# --- attacks (run-locked; shown in the attack picker) ---
	"attack:ora_ora":      "res://vfx/shared/textures/pixel_ember.png",
	"attack:spear":        "res://vfx/shared/textures/blast1.png",
	"attack:bakshen":      "res://vfx/shared/impervious/bolt.png",
	"attack:cherry_shots": "res://vfx/shared/textures/soft_dot.png",
	"attack:twin_reaper":  "res://vfx/shared/textures/blast1.png",

	# --- specials ---
	"special:special_default":   "res://vfx/shared/impervious/shield.png",
	"special:ground_breaker":    "res://vfx/shared/textures/blast1.png",
	"special:frenemy":              "res://vfx/shared/textures/pixel_ember.png",

	# --- reward DOOR types (one random door per level) ---
	"door:health":   "res://vfx/shared/textures/soft_dot.png",
	"door:athletic": "res://vfx/shared/textures/pixel_ember.png",
	"door:attack":   "res://vfx/shared/textures/blast1.png",
	"door:special":  "res://vfx/shared/impervious/shield.png",

	# --- buffs (by reward id; keep in sync as pools grow in rewards.gd) ---
	"buff:mend":     "res://vfx/shared/textures/soft_dot.png",
	"buff:max_hp":   "res://vfx/shared/textures/soft_dot.png",
	"buff:damage":   "res://vfx/shared/textures/blast1.png",
	"buff:ruh_cap":  "res://vfx/shared/impervious/shield.png",
	"buff:air_jump": "res://vfx/shared/textures/pixel_ember.png",
	"buff:run":      "res://vfx/shared/textures/pixel_ember.png",
	"buff:crimson_vortex": "res://vfx/shared/textures/soft_dot.png",
}

static var _cache := {}


## The texture for a namespaced key ("attack:spear", "door:health", "buff:mend", ...), cached.
## Unknown keys return the FALLBACK icon, so nothing is ever iconless.
static func texture(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var path: String = PATHS.get(key, FALLBACK)
	if not ResourceLoader.exists(path):
		path = FALLBACK
	var tex: Texture2D = load(path)
	_cache[key] = tex
	return tex


static func attack(id: String) -> Texture2D:
	return texture("attack:" + id)


static func special(id: String) -> Texture2D:
	return texture("special:" + id)


static func door(door_type: String) -> Texture2D:
	return texture("door:" + door_type)


static func buff(id: String) -> Texture2D:
	return texture("buff:" + id)
