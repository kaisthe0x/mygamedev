class_name CharacterConfig
extends RefCounted

## The player character registry: the roster of ids and the path templates for
## each character's generated resources. Every character shares one animation set
## and canvas, so switching is just swapping these per-id files (see Player).

## The selectable characters. Q/E cycle through them in order.
const IDS: PackedStringArray = [
	"feyke", "katalyst", "khalid", "lenbondosen", "wayna",
]
## Generated SpriteFrames, keyed by id (see tools/gen_spriteframes.py).
const FRAMES_PATH := "res://resources/characters/%s.tres"
## Portrait files are capitalised while character ids are lower case.
const PORTRAIT_PATH := "res://assets/portraits/%s.png"
## Optional per-character ability script; a missing file means no ability.
const ABILITY_PATH := "res://scripts/abilities/%s.gd"

## Per-character run speed in px/s -- tune how fast each character runs right here.
## The Player seeds `run_speed` from this on every character change; anyone not
## listed falls back to DEFAULT_RUN_SPEED. Add an entry to make a character distinct.
const DEFAULT_RUN_SPEED := 160.0
const RUN_SPEEDS := {
	"katalyst": 250.0, # a little faster than the others
}


## This character's run speed, or DEFAULT_RUN_SPEED when it has no override.
static func run_speed(character: String) -> float:
	return RUN_SPEEDS.get(character, DEFAULT_RUN_SPEED)


## Per-character jump velocity in px/s (NEGATIVE = up; more negative = higher jump).
## Same idea as RUN_SPEEDS -- the Player seeds `jump_velocity` from here on every
## character change; anyone not listed falls back to DEFAULT_JUMP_VELOCITY.
const DEFAULT_JUMP_VELOCITY := -330.0
const JUMP_VELOCITIES := {
	"katalyst": -370.0,  # jumps a little higher than the others
}


## This character's jump velocity, or DEFAULT_JUMP_VELOCITY when it has no override.
static func jump_velocity(character: String) -> float:
	return JUMP_VELOCITIES.get(character, DEFAULT_JUMP_VELOCITY)


## Per-character dash (lunge) speed in px/s. Same idea as RUN_SPEEDS -- the Player
## seeds `dash_speed` from here on every character change; anyone not listed falls
## back to DEFAULT_DASH_SPEED. Higher = a faster, farther dash (dash_time is fixed).
const DEFAULT_DASH_SPEED := 420.0
const DASH_SPEEDS := {
	"katalyst": 500.0,  # dashes a little faster than the others
}


## This character's dash speed, or DEFAULT_DASH_SPEED when it has no override.
static func dash_speed(character: String) -> float:
	return DASH_SPEEDS.get(character, DEFAULT_DASH_SPEED)
