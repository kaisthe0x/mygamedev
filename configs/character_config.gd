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
	"katalyst": 190.0,  # a little faster than the others
}


## This character's run speed, or DEFAULT_RUN_SPEED when it has no override.
static func run_speed(character: String) -> float:
	return RUN_SPEEDS.get(character, DEFAULT_RUN_SPEED)
