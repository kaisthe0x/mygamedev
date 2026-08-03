class_name Emitters
extends RefCounted

## The single entry point for particle-emitter config, characters AND enemies. The tables
## themselves are split by group for editability (EmittersCharacters / EmittersEnemies), and
## this aggregates them so callers have one place to look. All scenes in those tables are
## preload()ed, so everything is resident before the game runs and a bad path is a PARSE error
## -- there is no runtime load() in the VFX path.
##
## Characters are keyed id -> animation -> [rows] and driven by ParticleDirector on animation
## frames (mode/frames). Enemies are keyed id -> effect -> row and attached in code by
## state/event (no frame scheduling). Same row vocabulary otherwise (scene, pos, ...).


## Every animation's rows for a character id, or {} if the character has none.
static func character(id: String) -> Dictionary:
	return EmittersCharacters.TABLE.get(id, {})


## Every effect's row for an enemy id, or {} if the enemy has none.
static func enemy(id: String) -> Dictionary:
	return EmittersEnemies.TABLE.get(id, {})


## One enemy effect's row ({scene, pos, ...}), or {} if unlisted. The config is authoritative
## for presence -- an absent row means the enemy simply doesn't emit that effect.
static func enemy_effect(id: String, effect: String) -> Dictionary:
	return enemy(id).get(effect, {})
