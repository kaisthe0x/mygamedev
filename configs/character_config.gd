class_name CharacterConfig
extends RefCounted

## The player character registry: the roster of ids and the path templates for each character's
## generated resources. The engine is character-agnostic (one animation set + canvas; a character is
## just its per-id files + data), but this repo ships **Khalid only** -- the other characters live in
## the gitignored `playground/` for a future separate repo.

## The selectable characters. Just Khalid for now; add an id here (plus its assets + data) to add one.
const IDS: PackedStringArray = ["khalid"]
## Generated SpriteFrames, keyed by id (see tools/gen_spriteframes.py).
const FRAMES_PATH := "res://resources/characters/%s.tres"
## Portrait files are capitalised while character ids are lower case.
const PORTRAIT_PATH := "res://assets/portraits/%s.png"
## Optional per-character ability script; a missing file means no ability.
const ABILITY_PATH := "res://scripts/abilities/%s.gd"

## Per-character run speed in px/s -- the Player seeds `run_speed` from this on character change;
## anyone not listed falls back to DEFAULT_RUN_SPEED.
const DEFAULT_RUN_SPEED := 160.0
const RUN_SPEEDS := {
	"khalid": 230.0,
}


## This character's run speed, or DEFAULT_RUN_SPEED when it has no override.
static func run_speed(character: String) -> float:
	return RUN_SPEEDS.get(character, DEFAULT_RUN_SPEED)


## Per-character jump velocity in px/s (NEGATIVE = up). Seeds `jump_velocity`; falls back to default.
const DEFAULT_JUMP_VELOCITY := -330.0
const JUMP_VELOCITIES := {}


## This character's jump velocity, or DEFAULT_JUMP_VELOCITY when it has no override.
static func jump_velocity(character: String) -> float:
	return JUMP_VELOCITIES.get(character, DEFAULT_JUMP_VELOCITY)


## Per-character dash (lunge) speed in px/s. Seeds `dash_speed`; falls back to default.
const DEFAULT_DASH_SPEED := 420.0
const DASH_SPEEDS := {}


## This character's dash speed, or DEFAULT_DASH_SPEED when it has no override.
static func dash_speed(character: String) -> float:
	return DASH_SPEEDS.get(character, DEFAULT_DASH_SPEED)


## Per-character BLINK dash: true = the dash is an instant teleport (vanish + reappear
## `dash_speed * dash_time` ahead, with blink_out/blink_in poofs) instead of the glide-lunge. Each
## blinker needs its own other/blink_in.tscn + blink_out.tscn (fired via the Emitters config).
const BLINK_DASH := {
	"khalid": true,
}


## Whether this character's dash is a blink (teleport), or DEFAULT (false = glide) when unlisted.
static func blink_dash(character: String) -> bool:
	return BLINK_DASH.get(character, false)
