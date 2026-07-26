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
