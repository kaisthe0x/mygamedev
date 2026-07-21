class_name Hit
extends RefCounted

## Everything an attack delivers to a hurtbox, in one object so new effects can
## be added without changing every signature. A Hitbox / Projectile fills one in
## and hands it to Hurtbox.take_hit(); the victim reads what it needs.

var amount: float = 0.0        ## damage
var knockback: float = 0.0     ## px/s shove away from the source (0 = none)
var stun: float = 0.0          ## seconds frozen / staggered (0 = none)
var source: Node = null        ## who dealt it (for knockback direction)

## Optional visual status: an engulfing overlay tint on the victim. `a > 0`
## enables it; it lasts `status_time` seconds (defaults to the stun duration).
var status_color: Color = Color(0, 0, 0, 0)
var status_time: float = 0.0
