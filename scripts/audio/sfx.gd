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
	"level_cleared": "res://sfx/level_cleared.wav",  # last required enemy down, exit opens (RunManager clear beat)
	# --- combat / enemies ---
	"enemy_death": "res://sfx/enemy_death.wav",  # any enemy dies (Enemy._die, positional)
	# --- player movement ---
	"dash": "res://sfx/dash.wav",  # Khalid dashes (Player _enter State.DASH)
	"jump": "res://sfx/jump.wav",  # ground + air jump (Player jump input / _air_jump)
	"player_run": "res://sfx/player_run.wav",  # looping footsteps while running (Sfx.make_loop, owned by Player)
	"slam": "res://sfx/slam.wav",  # ground-slam impact (Player._slam_release)
}

## Bus these play on -- lets you set an SFX volume separately from music. Falls back to Master until
## you add an "SFX" bus in the editor's Audio panel (the code then uses it automatically).
const BUS := &"SFX"
const POOL := 12  ## simultaneous one-shots of each kind before the oldest player is reused
## Pin Godot's audio OUTPUT to a specific device, for when the system "Default" routes to a silent
## sink (this machine has several). Must be one of the names from `AudioServer.get_output_device_list()`
## (or `pactl list short sinks`). "" = follow the system default. Currently the Pebble USB speakers --
## change it if your output moves. (Machine-specific; safe to blank once the OS default is correct.)
const PREFERRED_OUTPUT := "alsa_output.usb-ACTIONS_Pebble_V3-00.analog-stereo"

var _flat: Array[AudioStreamPlayer] = []
var _pos: Array[AudioStreamPlayer2D] = []
var _fi := 0
var _pi := 0
var _cache := {}
var _bus: StringName = &"Master"  # resolved in _ready (SFX bus if present, else Master)


func _ready() -> void:
	# Force the output device if pinned + available, else leave it on the system default.
	if PREFERRED_OUTPUT != "" and PREFERRED_OUTPUT in AudioServer.get_output_device_list():
		AudioServer.output_device = PREFERRED_OUTPUT
	_bus = BUS if AudioServer.get_bus_index(BUS) != -1 else &"Master"
	for i in POOL:
		var f := AudioStreamPlayer.new()
		f.bus = _bus
		add_child(f)
		_flat.append(f)
		var p := AudioStreamPlayer2D.new()
		p.bus = _bus
		add_child(p)
		_pos.append(p)


## --- user-facing SFX volume (bind a settings slider to these; controls the whole SFX bus) ---
func set_volume(v: float) -> void:  # 0..1
	AudioBus.set_volume_linear(BUS, v)


func get_volume() -> float:  # 0..1
	return AudioBus.get_volume_linear(BUS)


func set_muted(on: bool) -> void:
	AudioBus.set_muted(BUS, on)


## The stream for a key (cached), or null if unregistered / missing. `key` is either a name in
## LIBRARY, OR a direct `res://` path -- so organized per-attack sounds (mirroring the vfx folders,
## e.g. the Emitters `sfx` field) can be played without a flat LIBRARY entry.
func _stream(key: String) -> AudioStream:
	if _cache.has(key):
		return _cache[key]
	var path: String = key if key.begins_with("res://") else String(LIBRARY.get(key, ""))
	var s: AudioStream = null
	if path != "" and ResourceLoader.exists(path):
		s = load(path)
	elif key != "":
		push_warning("Sfx: '%s' not found (playing nothing)" % key)
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


## Create a dedicated LOOPING player for `key` (stream forced to loop, on the SFX bus). It is NOT
## added to the tree -- the CALLER parents it (so it frees with its owner, never orphaned as a
## stuck sound) and drives play()/stop() by state, e.g. a footstep loop while grounded + moving.
## Returns null if the key is unregistered or its file is missing, so callers must null-check.
func make_loop(key: String) -> AudioStreamPlayer:
	var s := _stream(key)
	if s == null:
		return null
	# Force the stream to loop if it wasn't imported looping. Duplicate first so we never flip the
	# shared cached stream that one-shot users share. For a WAV, setting loop_mode ALONE isn't enough:
	# loop_end defaults to 0, giving a ZERO-LENGTH loop region that "finishes" instantly every frame
	# (the stuttering restart, not a loop) -- so span loop_begin/end across the whole sample.
	if s is AudioStreamWAV and (s as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED:
		var w: AudioStreamWAV = (s as AudioStreamWAV).duplicate()
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(round(w.get_length() * w.mix_rate))  # whole sample, in frames
		s = w
	elif s is AudioStreamMP3 and not (s as AudioStreamMP3).loop:
		var m: AudioStreamMP3 = (s as AudioStreamMP3).duplicate()
		m.loop = true
		s = m
	elif s is AudioStreamOggVorbis and not (s as AudioStreamOggVorbis).loop:
		var o: AudioStreamOggVorbis = (s as AudioStreamOggVorbis).duplicate()
		o.loop = true
		s = o
	var pl := AudioStreamPlayer.new()
	pl.bus = _bus
	pl.stream = s
	return pl


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
