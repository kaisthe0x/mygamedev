class_name Icons
extends RefCounted

## Central ICON registry for things WITHOUT their own icon field -- reward doors + buffs. (Attacks
## and specials now embed their `icon` PATH on the Action itself; load those with `Icons.load_path`.)
## Everything UI (reward cards, doors, the HUD) asks HERE for its icon, so when real art lands you swap
## a PATH below and nothing else changes -- no UI refactor.
##
## Keys are NAMESPACED: "door:<type>", "buff:<id>". Look them up with `Icons.texture(key)` or the typed
## helpers (`Icons.door("health")`, `Icons.buff("mend")`); an explicit res:// path via `load_path`.
## Textures load lazily + cache, so unmapped/unused icons cost nothing and adding one is a single
## line. Anything missing falls back to FALLBACK (so a door/buff is never iconless).
##
## >>> TODO(art): every path below is a TEMPORARY placeholder (reused existing pngs). Replace with
## real icons as they're drawn -- one line each, no code changes elsewhere. <<<

const FALLBACK := "res://vfx/shared/textures/soft_dot.png"

const PATHS := {
	# --- reward DOOR types (one random door per level) ---
	"door:health":   "res://vfx/shared/textures/soft_dot.png",
	"door:athletic": "res://vfx/shared/textures/pixel_ember.png",
	"door:attack":   "res://vfx/shared/textures/blast1.png",
	"door:special":  "res://vfx/shared/impervious/shield.png",

	# --- buffs (by reward id; keep in sync as pools grow in rewards.gd) ---
	"buff:mend":     "res://vfx/shared/textures/soft_dot.png",
	"buff:max_hp":   "res://vfx/shared/textures/soft_dot.png",
	"buff:ruh_cap":  "res://vfx/shared/impervious/shield.png",
	"buff:air_jump": "res://vfx/shared/textures/pixel_ember.png",
	"buff:run":      "res://vfx/shared/textures/pixel_ember.png",
	"buff:crimson_vortex": "res://vfx/shared/textures/soft_dot.png",

	# --- enemy STATUS icons (shown next to the floating health bar; see StatusTypes) ---
	# >>> TODO(art): all TEMP placeholders (reused pngs). Draw proper little status pips + swap here. <<<
	"status:reap":  "res://vfx/shared/textures/skull_texture.png",   # dying / DoT -- a skull
	"status:stun":  "res://vfx/shared/textures/z_texture.png",       # dazed -- "Zzz"
	"status:slow":  "res://vfx/shared/textures/forward_arrow_texture.png",  # slowed (future)
	"status:charm": "res://vfx/shared/textures/pixel_ember.png",     # charmed frenemy -- an ember heart
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


## The texture at an explicit res:// PATH (e.g. an Action's embedded `icon`), cached, with the same
## missing-file FALLBACK as texture(). Empty / missing path -> FALLBACK, so nothing is ever iconless.
static func load_path(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		path = FALLBACK
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = load(path)
	_cache[path] = tex
	return tex


static func door(door_type: String) -> Texture2D:
	return texture("door:" + door_type)


static func buff(id: String) -> Texture2D:
	return texture("buff:" + id)
