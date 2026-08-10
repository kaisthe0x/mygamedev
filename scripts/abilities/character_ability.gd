class_name CharacterAbility
extends Passive

## A character's INTRINSIC ability -- the Passive that's always on for that character (as opposed to a
## reward-granted one). Drop a script at `res://scripts/abilities/<character_id>.gd` extending this and
## the Player seeds it FIRST in its passive list when that character is equipped. No registration, no
## scene edits; characters without a file simply have no intrinsic ability.
##
## Same hooks as `Passive` (setup / physics / on_special_strike / on_hurt / on_land / on_hit_dealt) --
## override only the ones you need. This subclass exists purely to name the "character-intrinsic" role;
## reward passives extend `Passive` directly. See scripts/abilities/passive.gd for the hook docs.
