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

## Movement stats used to live here (run/jump/dash speeds + blink dash). They moved to the typed
## movement Actions -- the shared baseline in configs/locomotion.gd, per-character deviations in each
## character's MOVEMENTS catalog (configs/actions_<char>.gd), applied by Player._apply_movement. This
## registry now holds only IDENTITY: the roster + the resource-path templates above.
