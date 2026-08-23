extends Node

## Central SOUND-EFFECTS service (autoload `Sfx`) -- the runtime that PLAYS sounds; the catalog of
## which sounds exist lives in the pure-DATA configs (SfxCharacters / SfxEnemies / SfxWorld), one per
## area, which this aggregates. Every sound is a stable `key` -> path there; code + the presentation
## driver reference sounds by key only. An unregistered key is a silent no-op (a cue can be listed
## before its file lands, or intentionally left unwired). See configs/sfx_*.gd for the master lists.
##
##   Sfx.play("key")        -- non-positional one-shot (UI / player-centric feedback, e.g. a pickup).
##   Sfx.play_at("key", p)  -- positional 2D one-shot at world point `p` (an enemy hit, an explosion).
##   Sfx.make_loop("key")   -- a dedicated looping player the CALLER owns (footsteps, a channel hum).
## Both one-shots round-robin a small pool so overlaps don't cut each other off. Optional volume_db /
## pitch vary a cue without a second file.

## Bus these play on -- lets you set an SFX volume separately from music. Falls back to Master until
## you add an "SFX" bus in the editor's Audio panel (the code then uses it automatically).
const BUS := &"SFX"
const POOL := 12 ## simultaneous one-shots of each kind before the oldest player is reused
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
var _cues := {} # key -> path, merged from the per-area configs (SfxCharacters/Enemies/World)
var _bus: StringName = &"Master" # resolved in _ready (SFX bus if present, else Master)


func _ready() -> void:
	# Merge the per-area cue catalogs into one lookup. Keys are globally unique across areas.
	for table in [SfxCharacters.CUES, SfxEnemies.CUES, SfxWorld.CUES]:
		_cues.merge(table)
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
func set_volume(v: float) -> void: # 0..1
	AudioBus.set_volume_linear(BUS, v)


func get_volume() -> float: # 0..1
	return AudioBus.get_volume_linear(BUS)


func set_muted(on: bool) -> void:
	AudioBus.set_muted(BUS, on)


## The stream for a cue key (cached), or null. An UNREGISTERED key (not in any config) is a silent
## no-op -- so an <enemy>.<type> the code composes but that has no sound just plays nothing. A
## REGISTERED key whose file is missing warns (a wired cue whose audio hasn't landed / moved).
func _stream(key: String) -> AudioStream:
	if _cache.has(key):
		return _cache[key]
	var s: AudioStream = null
	if _cues.has(key):
		var path: String = _cues[key]
		if ResourceLoader.exists(path):
			s = load(path)
		else:
			push_warning("Sfx: cue '%s' -> %s not found (playing nothing)" % [key, path])
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


## Fire ONE random variant from `keys` -- so a repeated event (a hurt grunt) doesn't make the same
## noise every time. Skips unregistered / missing-file keys, so dropping only 2 of 3 variant files
## still works cleanly (the missing one is never picked). No-op if none resolve.
func play_random(keys: Array, volume_db := 0.0, pitch := 1.0) -> void:
	var valid: Array = []
	for k in keys:
		if _stream(String(k)) != null:
			valid.append(k)
	if valid.is_empty():
		return
	play(String(valid[randi() % valid.size()]), volume_db, pitch)


## The stream for `key` forced to LOOP (a duplicate, so the shared one-shot stream is never flipped),
## or null. For a WAV, setting loop_mode ALONE isn't enough: loop_end defaults to 0, giving a
## ZERO-LENGTH loop region that "finishes" instantly every frame (a stuttering restart, not a loop) --
## so span loop_begin/end across the whole sample.
func _looped_stream(key: String) -> AudioStream:
	var s := _stream(key)
	if s == null:
		return null
	if s is AudioStreamWAV and (s as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED:
		var w: AudioStreamWAV = (s as AudioStreamWAV).duplicate()
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(round(w.get_length() * w.mix_rate)) # whole sample, in frames
		s = w
	elif s is AudioStreamMP3 and not (s as AudioStreamMP3).loop:
		var m: AudioStreamMP3 = (s as AudioStreamMP3).duplicate()
		m.loop = true
		s = m
	elif s is AudioStreamOggVorbis and not (s as AudioStreamOggVorbis).loop:
		var o: AudioStreamOggVorbis = (s as AudioStreamOggVorbis).duplicate()
		o.loop = true
		s = o
	return s


## Create a dedicated LOOPING player for `key` (stream forced to loop, on the SFX bus). It is NOT
## added to the tree -- the CALLER parents it (so it frees with its owner, never orphaned as a
## stuck sound) and drives play()/stop() by state, e.g. a footstep loop while grounded + moving.
## Returns null if the key is unregistered or its file is missing, so callers must null-check.
func make_loop(key: String) -> AudioStreamPlayer:
	var s := _looped_stream(key)
	if s == null:
		return null
	var pl := AudioStreamPlayer.new()
	pl.bus = _bus
	pl.stream = s
	return pl


## A dedicated ONE-SHOT player for `key` the CALLER owns (not looped, not pooled) -- for a sound you
## need to be able to STOP early, e.g. a slam-descent whoosh cut short by the ground impact. The caller
## parents it (so it frees with its owner) and drives play()/stop(). Null if the key is missing.
func make_oneshot(key: String) -> AudioStreamPlayer:
	var s := _stream(key)
	if s == null:
		return null
	var pl := AudioStreamPlayer.new()
	pl.bus = _bus
	pl.stream = s
	return pl


## Positional twin of make_oneshot(): a one-shot AudioStreamPlayer2D the caller parents at/on a world
## object -- for a sound that PANS with the emitter AND may need to STOP early (an enemy's channelled
## blast cut short by a stun). The caller parents it (frees with its owner) and drives play()/stop().
## Null if the key is unregistered or its file is missing.
func make_oneshot_2d(key: String) -> AudioStreamPlayer2D:
	var s := _stream(key)
	if s == null:
		return null
	var pl := AudioStreamPlayer2D.new()
	pl.bus = _bus
	pl.stream = s
	return pl


## Positional twin of make_loop(): a looping AudioStreamPlayer2D the caller parents at a world spot --
## for a sound an object EMITS on loop (a launch orb's hum), which then pans/attenuates with distance.
func make_loop_2d(key: String) -> AudioStreamPlayer2D:
	var s := _looped_stream(key)
	if s == null:
		return null
	var pl := AudioStreamPlayer2D.new()
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
