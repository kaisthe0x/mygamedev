extends CharacterAbility

## Lenny: Energy Beam. His heavy fires a short forward laser on the strike frame
## (scenes/effects/laser_beam.tscn). The beam carries the hit -- damage, knockback
## and range are set here and its Hitbox damages everything along the beam -- so
## his melee heavy box is left a no-op (ATTACKS "heavy" damage is 0).
##
## To give the beam its own drawn look, make an Inherited Scene of the base, drop
## your beam sprite on the Core's texture, and point BEAM at that scene.

## Lenny's own beam: an Inherited Scene of the base with his drawn sprite
## (vfx/particles/characters/lenbondosen/textures/lenbondosen_beam.png) on the Core.
const BEAM := preload("res://vfx/laser/laser_beam_lenny.tscn")
## Short reach (it stops sooner on a wall/enemy).
const RANGE := 150.0
## Where it leaves him (forward, up to the weapon), before the facing mirror.
const MUZZLE := Vector2(22, -20)


func on_heavy_strike(player: Player) -> void:
	var facing := player.get_facing()
	var beam: LaserBeam = BEAM.instantiate()
	beam.damage = 30.0
	beam.knockback = 150.0
	beam.beam_range = RANGE
	beam.source = player
	# Live in the level, not under the player, so it stays put as he moves on.
	player.get_parent().add_child(beam)
	beam.global_position = player.global_position + Vector2(MUZZLE.x * facing, MUZZLE.y)
	# Snap to the spawn spot instead of interpolating there from the level origin
	# (physics interpolation is on), which would smear it across the level.
	beam.reset_physics_interpolation()
	beam.fire(Vector2(facing, 0))
