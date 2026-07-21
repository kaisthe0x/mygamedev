class_name Hurtbox
extends Area2D

## A region that RECEIVES hits. It doesn't scan for anything; opposing Hitboxes
## scan for it (their mask includes this box's layer). On a hit it just relays
## the Hit via a signal -- the owning body decides what to do.
##
## Set `collision_layer` to the team's hurt layer (Combat.L_*_HURT) and leave
## `collision_mask` at 0. `monitorable` must stay true (default) so hitboxes see it.

signal hurt(hit: Hit)


func take_hit(hit: Hit) -> void:
	hurt.emit(hit)
