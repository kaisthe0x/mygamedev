extends Node

## Background MUSIC service (autoload `Music`) -- a SINGLE looping track with smooth fade in/out.
## Sibling of `Sfx` (that's fire-and-forget one-shots; this is the persistent musical bed). As an
## autoload it survives scene reloads, so the track keeps playing seamlessly across level restarts.
##
## >>> Add a track: drop the file in res://music/ and add ONE line to TRACKS below, then
##     Music.play("your_key"). A missing file is a silent no-op (wire it before the audio lands). <<<
##
##   Music.play("key")  -- fade the track in; NO-OP if it's already the current one (so re-entering a
##                         level never restarts the bed). Switching keys hard-swaps then fades in.
##   Music.stop()       -- fade the current track out, then stop.

## key -> res:// path. ONE line per track. >>> ADD TRACKS HERE <<<
const TRACKS := {
	"level": "res://music/the_omnific_the_stoic.mp3", # main gameplay loop (The Omnific - The Stoic)
}

const BUS := &"Music" ## own volume, separate from SFX; falls back to Master if absent
const DEFAULT_VOLUME_DB := -17.0 ## the "full" music level once faded in (sits under the SFX)
const SILENCE_DB := -60.0 ## treated as silence at the ends of a fade

var _player: AudioStreamPlayer
var _current := ""
var _tween: Tween
var _cache := {}


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = BUS if AudioServer.get_bus_index(BUS) != -1 else &"Master"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS # keep the bed going if the game pauses
	add_child(_player)


## --- user-facing MUSIC volume (bind a settings slider to these; controls the whole Music bus,
## independent of the per-track fade envelope on the player) ---
func set_volume(v: float) -> void:  # 0..1
	AudioBus.set_volume_linear(BUS, v)


func get_volume() -> float:  # 0..1
	return AudioBus.get_volume_linear(BUS)


func set_muted(on: bool) -> void:
	AudioBus.set_muted(BUS, on)


## The looping stream for a key (cached), or null if unregistered / missing.
func _stream(key: String) -> AudioStream:
	if _cache.has(key):
		return _cache[key]
	var path: String = TRACKS.get(key, "")
	var s: AudioStream = null
	if path != "" and ResourceLoader.exists(path):
		s = load(path)
		# Force looping so the bed never just ends. Duplicate so we don't mutate the cached import.
		if s is AudioStreamMP3 and not (s as AudioStreamMP3).loop:
			s = (s as AudioStreamMP3).duplicate()
			(s as AudioStreamMP3).loop = true
		elif s is AudioStreamOggVorbis and not (s as AudioStreamOggVorbis).loop:
			s = (s as AudioStreamOggVorbis).duplicate()
			(s as AudioStreamOggVorbis).loop = true
		elif s is AudioStreamWAV and (s as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED:
			var w: AudioStreamWAV = (s as AudioStreamWAV).duplicate()
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(round(w.get_length() * w.mix_rate))
			s = w
	elif path != "":
		push_warning("Music: '%s' -> %s not found (playing nothing)" % [key, path])
	_cache[key] = s
	return s


## Fade `key` in over `fade_in` seconds to `volume_db`. No-op if it's already the current track (so
## re-entering / restarting a level doesn't restart the bed). Unregistered / missing key = no-op.
func play(key: String, fade_in := 1.5, volume_db := DEFAULT_VOLUME_DB) -> void:
	if key == _current and _player.playing:
		return
	var s := _stream(key)
	if s == null:
		return
	_current = key
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_player.stream = s
	_player.volume_db = SILENCE_DB
	_player.play()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", volume_db, fade_in)


## Fade the current track out over `fade_out` seconds, then stop.
func stop(fade_out := 1.0) -> void:
	if not _player.playing:
		return
	_current = ""
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", SILENCE_DB, fade_out)
	_tween.tween_callback(_player.stop)
