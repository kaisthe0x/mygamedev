extends Node

## Central SOUND-EFFECTS service (autoload `Sfx`) -- ONE place to register every game sound and fire
## it as a fire-and-forget one-shot. The audio counterpart to `Icons` (textures) and the `Emitters`
## config (particles): a namespaced key maps to a file under res://sfx/, loaded lazily + cached, and
## a MISSING file is a silent no-op -- so a cue can be wired in code before the actual audio lands.
##
## >>> To add a sound: drop the file in res://sfx/ and add ONE line to LIBRARY below. Then call
##     Sfx.play("your_key") anywhere. That's it. <<<
##
##   Sfx.play("key")        -- non-positional one-shot (UI / player-centric feedback, e.g. a pickup).
##   Sfx.play_at("key", p)  -- positional 2D one-shot at world point `p` (an enemy hit, an explosion).
## Both round-robin a small pool of players so overlapping sounds don't cut each other off. Optional
## volume_db / pitch args vary a cue without a second file.

## key -> res:// path. ONE line per sound, grouped by area. >>> ADD SOUNDS HERE <<<
const LIBRARY := {
	# --- feedback / pickups ---
	"ruh_absorb": "res://sfx/ruh_absorb.wav",  # a Ruh soul lands on Khalid (placeholder -- replace freely)
}

## Bus these play on -- lets you set an SFX volume separately from music. Falls back to Master until
## you add an "SFX" bus in the editor's Audio panel (the code then uses it automatically).
const BUS := &"SFX"
const POOL := 12  ## simultaneous one-shots of each kind before the oldest player is reused

var _flat: Array[AudioStreamPlayer] = []
var _pos: Array[AudioStreamPlayer2D] = []
var _fi := 0
var _pi := 0
var _cache := {}


func _ready() -> void:
	var bus: StringName = BUS if AudioServer.get_bus_index(BUS) != -1 else &"Master"
	for i in POOL:
		var f := AudioStreamPlayer.new()
		f.bus = bus
		add_child(f)
		_flat.append(f)
		var p := AudioStreamPlayer2D.new()
		p.bus = bus
		add_child(p)
		_pos.append(p)


## The stream for a key (cached), or null if the key is unregistered or its file is missing.
func _stream(key: String) -> AudioStream:
	if _cache.has(key):
		return _cache[key]
	var path: String = LIBRARY.get(key, "")
	var s: AudioStream = null
	if path != "" and ResourceLoader.exists(path):
		s = load(path)
	elif path != "":
		push_warning("Sfx: '%s' -> %s not found (playing nothing)" % [key, path])
	_cache[key] = s
	return s


## Fire a one-shot (non-positional). No-op if the key is unregistered or its file is missing.
func play(key: String, volume_db := 0.0, pitch := 1.0) -> void:
	var s := _stream(key)
	if s == null or _flat.is_empty():
		return
	var pl := _flat[_fi]
	_fi = (_fi + 1) % _flat.size()
	pl.stream = s
	pl.volume_db = volume_db
	pl.pitch_scale = pitch
	pl.play()


## Fire a one-shot at a world position (2D panning relative to the camera/listener). No-op if missing.
func play_at(key: String, world_pos: Vector2, volume_db := 0.0, pitch := 1.0) -> void:
	var s := _stream(key)
	if s == null or _pos.is_empty():
		return
	var pl := _pos[_pi]
	_pi = (_pi + 1) % _pos.size()
	pl.stream = s
	pl.global_position = world_pos
	pl.volume_db = volume_db
	pl.pitch_scale = pitch
	pl.play()
