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
