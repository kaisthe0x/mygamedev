class_name AudioBus
extends RefCounted

## Runtime control of the audio buses (Master / SFX / Music) -- volume, mute, and EFFECTS (EQ,
## low/high-pass filters, reverb, compressor, distortion, ... anything in AudioEffect*). The visual
## counterpart is the editor's **Audio panel** (bottom dock): drag faders and add/tweak effects
## there and it saves to `default_bus_layout.tres`. These helpers reach the SAME live buses from
## code -- for a settings menu (volume sliders) or for scripted mix changes (duck the music, muffle
## SFX under water, etc.). Bus names: &"Master", &"SFX", &"Music".

# --- volume ---------------------------------------------------------------

## Set a bus volume from a friendly 0..1 slider value (bind a settings slider straight to this).
static func set_volume_linear(bus: StringName, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i != -1:
		AudioServer.set_bus_volume_db(i, linear_to_db(clampf(v, 0.0, 1.0)))


## The bus volume as a 0..1 value (what a slider should show). 1.0 if the bus doesn't exist.
static func get_volume_linear(bus: StringName) -> float:
	var i := AudioServer.get_bus_index(bus)
	return 1.0 if i == -1 else clampf(db_to_linear(AudioServer.get_bus_volume_db(i)), 0.0, 1.0)


## Set a bus volume directly in decibels (0 = unchanged, negative = quieter).
static func set_volume_db(bus: StringName, db: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i != -1:
		AudioServer.set_bus_volume_db(i, db)


static func set_muted(bus: StringName, on: bool) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i != -1:
		AudioServer.set_bus_mute(i, on)


static func is_muted(bus: StringName) -> bool:
	var i := AudioServer.get_bus_index(bus)
	return i != -1 and AudioServer.is_bus_mute(i)


# --- effects (EQ / filters / reverb / ...) --------------------------------

## Add an effect to a bus at runtime and RETURN it so you can tweak its params inline, or null if
## the bus is missing. e.g.  AudioBus.add_effect(&"SFX", AudioEffectLowPassFilter.new()).cutoff_hz = 900
## Prefer authoring effects in the editor Audio panel for anything permanent; use this for dynamic,
## gameplay-driven changes (an underwater muffle, a boss-room reverb).
static func add_effect(bus: StringName, effect: AudioEffect) -> AudioEffect:
	var i := AudioServer.get_bus_index(bus)
	if i == -1:
		return null
	AudioServer.add_bus_effect(i, effect)
	return effect


## The idx-th effect on a bus (to tweak an effect authored in the panel from code), or null.
static func get_effect(bus: StringName, idx := 0) -> AudioEffect:
	var i := AudioServer.get_bus_index(bus)
	if i == -1 or idx < 0 or idx >= AudioServer.get_bus_effect_count(i):
		return null
	return AudioServer.get_bus_effect(i, idx)


## Enable / bypass an effect on a bus (e.g. toggle a reverb without removing it).
static func set_effect_enabled(bus: StringName, idx: int, on: bool) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i != -1 and idx >= 0 and idx < AudioServer.get_bus_effect_count(i):
		AudioServer.set_bus_effect_enabled(i, idx, on)
