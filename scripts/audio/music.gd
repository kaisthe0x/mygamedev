extends Node

## Background MUSIC service (autoload `Music`) -- a CROSSFADING bed. Two AudioStreamPlayers ping-pong:
## `play(key)` fades the current track OUT while the new one fades IN on the other player, always
## (re)started from the top -- so switching tracks (level <-> rest bed) is smooth and re-entering a
## level starts its music fresh. Sibling of `Sfx` (fire-and-forget one-shots). As an autoload it
## survives scene reloads.
##
## >>> Add a track: drop the file in res://music/ and add ONE line to TRACKS, then Music.play("key").
##     A missing file is a silent no-op (wire it before the audio lands). <<<
##
##   Music.play("key")  -- crossfade to a track, from the top.
##   Music.stop()       -- fade the current track out to silence.
##   Music.pause()/resume() -- freeze/continue the current track at its position (e.g. a menu).

## key -> res:// path. ONE line per track. >>> ADD TRACKS HERE <<<
const TRACKS := {
	"level": "res://music/the_omnific_the_stoic.mp3",  # main gameplay loop (The Omnific - The Stoic)
	"base_rest": "res://music/base_rest.mp3",  # calmer bed while a cleared level's exit/reward is open
}

const BUS := &"Music"            ## own volume, separate from SFX; falls back to Master if absent
const DEFAULT_VOLUME_DB := -17.0 ## the "full" music level once faded in (sits under the SFX)
const SILENCE_DB := -60.0        ## treated as silence at the ends of a fade
const FADE := 1.5                ## default crossfade / fade seconds

var _players: Array[AudioStreamPlayer] = []
var _tweens: Array = [null, null]
var _active := 0    ## index of the player holding the CURRENT track
var _current := ""  ## key of the current track ("" = none)
var _cache := {}


func _ready() -> void:
	var bus: StringName = BUS if AudioServer.get_bus_index(BUS) != -1 else &"Master"
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		p.volume_db = SILENCE_DB
		p.process_mode = Node.PROCESS_MODE_ALWAYS  # keep music going if the game pauses
		add_child(p)
		_players.append(p)


## The looping stream for a key (cached), or null if unregistered / missing.
func _stream(key: String) -> AudioStream:
	if _cache.has(key):
		return _cache[key]
	var path: String = TRACKS.get(key, "")
	var s: AudioStream = null
	if path != "" and ResourceLoader.exists(path):
		s = load(path)
		# Force looping so a bed never just ends. Duplicate so we don't mutate the cached import.
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


## Crossfade to `key`, started FROM THE TOP, over `fade` seconds: the current track fades out + stops
## on one player while the new one fades in on the other. Always restarts. No-op only if `key` is
## unregistered / its file is missing.
func play(key: String, fade := FADE, volume_db := DEFAULT_VOLUME_DB) -> void:
	var s := _stream(key)
	if s == null:
		return
	_current = key
	var out_i := _active
	var in_i := 1 - _active
	_active = in_i
	_fade_to(out_i, SILENCE_DB, fade, true)  # old track: fade out, then stop
	var p := _players[in_i]
	p.stream = s
	p.volume_db = SILENCE_DB
	p.stream_paused = false
	p.play()
	_fade_to(in_i, volume_db, fade, false)  # new track: fade in from silence


## Fade the current track out to silence over `fade` seconds, then stop -- leaving nothing playing.
func stop(fade := FADE) -> void:
	_current = ""
	_fade_to(_active, SILENCE_DB, fade, true)


## Freeze / continue the current track at its position (a menu, a cutscene). Not a fade.
func pause() -> void:
	_players[_active].stream_paused = true


func resume() -> void:
	_players[_active].stream_paused = false


## Tween player `i`'s volume to `to_db` over `dur`; optionally stop it at the end. Kills any fade
## already running on that player so crossfades never fight.
func _fade_to(i: int, to_db: float, dur: float, stop_after: bool) -> void:
	var p := _players[i]
	if _tweens[i] != null and (_tweens[i] as Tween).is_valid():
		(_tweens[i] as Tween).kill()
	var t := create_tween()
	t.tween_property(p, "volume_db", to_db, dur)
	if stop_after:
		t.tween_callback(p.stop)
	_tweens[i] = t


## --- user-facing MUSIC volume (bind a settings slider to these; controls the whole Music bus,
## independent of the per-track fade envelope on the players) ---
func set_volume(v: float) -> void:  # 0..1
	AudioBus.set_volume_linear(BUS, v)


func get_volume() -> float:  # 0..1
	return AudioBus.get_volume_linear(BUS)


func set_muted(on: bool) -> void:
	AudioBus.set_muted(BUS, on)
