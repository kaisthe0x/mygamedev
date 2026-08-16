class_name Hit
extends RefCounted

## Everything an attack delivers to a hurtbox, in one object so new effects can
## be added without changing every signature. A Hitbox / Projectile fills one in
## and hands it to Hurtbox.take_hit(); the victim reads what it needs.

var amount: float = 0.0 ## damage
var knockback: float = 0.0 ## px/s shove away from the source (0 = none)
var stun: float = 0.0 ## seconds frozen / staggered (0 = none)
var source: Node = null ## who dealt it (for knockback direction)
## True if this came from a Projectile (a ranged shot), false for a melee/Strike box. Lets
## a victim react differently to ranged vs melee -- e.g. nasen is only stunned by melee.
var ranged: bool = false
## True if this hit came from the player's SPECIAL. A kill by a special doesn't refill the Ruh
## meter (RunManager checks this) -- so the special can't self-loop its own Impervious window.
var from_special: bool = false

## Seconds to CHARM the victim into a temporary ally (0 = none). An enemy hit with this becomes a
## "frenemy": it stops targeting the player and fights the other enemies for the duration, then
## reverts. See Enemy.become_frenemy. (The frenemy special uses this instead of a stun.)
var frenemy_time: float = 0.0

## Optional visual status: an engulfing overlay tint on the victim. `a > 0`
## enables it; it lasts `status_time` seconds (defaults to the stun duration).
var status_color: Color = Color(0, 0, 0, 0)
var status_time: float = 0.0

## Optional custom VFX scene spawned ON the victim when this hit lands -- the dynamic,
## per-attack hurt reaction (a stun effect, a slam shock, a burn, ...). Null = none. It's
## parented to the victim and freed after `victim_vfx_time` seconds (0 = the scene frees
## itself, i.e. a one-shot burst). Set per attack via the move's `victim_effect` tuning.
var victim_vfx: PackedScene = null
var victim_vfx_time: float = 0.0

## Optional damage-over-time ("reap"): the victim keeps losing health after the hit. `dot_percent`
## is the fraction of the victim's MAX health drained per 1-second tick; `dot_time` is how long the
## reap lasts (re-applying refreshes the window, never shortens it). Both 0 = no DoT. Twin Reaper
## marks enemies with this so they slowly die even after the spin moves off them.
var dot_percent: float = 0.0
var dot_time: float = 0.0
