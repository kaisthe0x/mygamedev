class_name SaveData
extends RefCounted

## Persistent run record + the current run's progress, shared between RunManager (which writes)
## and the HUD (which reads). The RECORD -- the most levels cleared in a single run, ever -- is
## saved to user://; the current run's cleared count is session-only, held in memory. All static:
## there's one record, no instance needed.

const PATH := "user://save.cfg"

## Lazy-loaded best-ever levels cleared (-1 = not read from disk yet).
static var _record := -1
## Levels cleared in the CURRENT run. RunManager sets it; the HUD shows it next to the record.
static var current_cleared := 0


## The record: most levels cleared in a single run, ever. Read from disk once, then cached.
static func levels_record() -> int:
	if _record < 0:
		var cfg := ConfigFile.new()
		_record = int(cfg.get_value("run", "levels_record", 0)) if cfg.load(PATH) == OK else 0
	return _record


## Report a finished run's cleared count; persist a new best if it beats the record.
## Returns true when a new record was set (so the caller could celebrate it later).
static func report_run(cleared: int) -> bool:
	if cleared <= levels_record():
		return false
	_record = cleared
	var cfg := ConfigFile.new()
	cfg.load(PATH) # keep any other keys already saved
	cfg.set_value("run", "levels_record", _record)
	cfg.save(PATH)
	return true


## Saved character COLOUR SCHEMES from the picker screen -- up to MAX_SCHEMES named slots plus an
## "active" index (the one applied on startup). Each scheme: {"body": {material -> Color}, "power":
## {family -> Color}}; empty dicts mean "defaults". ConfigFile serialises Color/Dictionary/Array natively.
const MAX_SCHEMES := 5
static var _schemes: Array = []
static var _active := 0
static var _colors_loaded := false


static func _load_colors() -> void:
	if _colors_loaded:
		return
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		_schemes = cfg.get_value("colors", "schemes", [])
		_active = int(cfg.get_value("colors", "active", 0))
	# Normalise to exactly MAX_SCHEMES slots so the UI can index them freely.
	_schemes = _schemes.slice(0, MAX_SCHEMES)
	while _schemes.size() < MAX_SCHEMES:
		_schemes.append({"body": {}, "power": {}})
	_active = clampi(_active, 0, MAX_SCHEMES - 1)
	_colors_loaded = true


## All MAX_SCHEMES slots (index 0..4); each {"body":{}, "power":{}}. Empty dicts = an unused slot.
static func color_schemes() -> Array:
	_load_colors()
	return _schemes


## The slot index applied on startup (and currently selected in the picker).
static func active_scheme() -> int:
	_load_colors()
	return _active


## Whether slot `i` has any saved picks (so the UI can mark used vs empty slots).
static func scheme_used(i: int) -> bool:
	_load_colors()
	var s: Dictionary = _schemes[i]
	return not (s.get("body", {}).is_empty() and s.get("power", {}).is_empty())


## Write slot `i` from the chosen picks and (by default) make it the active/startup scheme.
static func save_scheme(i: int, body: Dictionary, power: Dictionary, make_active := true) -> void:
	_load_colors()
	_schemes[i] = {"body": body.duplicate(), "power": power.duplicate()}
	if make_active:
		_active = i
	_persist_colors()


## Just change which slot applies on startup (no scheme edit).
static func set_active(i: int) -> void:
	_load_colors()
	_active = clampi(i, 0, MAX_SCHEMES - 1)
	_persist_colors()


static func _persist_colors() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH) # keep the run record + anything else already saved
	cfg.set_value("colors", "schemes", _schemes)
	cfg.set_value("colors", "active", _active)
	cfg.save(PATH)
