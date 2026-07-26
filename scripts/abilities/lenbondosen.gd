extends CharacterAbility

## Lenny: Energy Beam -- currently DISABLED. His special used to fire a short forward
## laser on the strike frame; now his special is a close-range burst instead. Damage
## comes from the melee box (ATTACKS "special" in player.gd) and the look from a
## particle burst (emitters.json -> lenbondosen -> special_poison_raiser).
##
## The beam is kept for later, not deleted: the LaserBeam component and his
## vfx/laser/laser_beam_lenny.tscn scene still exist. Flip USE_BEAM to true to
## bring it back (and re-zero his ATTACKS "special" so the melee box doesn't
## double-hit alongside the beam).

## Flip to true to restore the energy beam on Lenny's special.
const USE_BEAM := false

## Lenny's own beam: an Inherited Scene of the base with his drawn sprite
## (vfx/particles/characters/lenbondosen/textures/lenbondosen_beam.png) on the Core.
const BEAM := preload("res://vfx/laser/laser_beam_lenny.tscn")
## Short reach (it stops sooner on a wall/enemy).
const RANGE := 150.0
## Where it leaves him (forward, up to the weapon), before the facing mirror.
const MUZZLE := Vector2(22, -20)


func on_special_strike(player: Player) -> void:
	if not USE_BEAM:
		return  # beam disabled -- special is a melee burst now (see the header)
	var facing := player.get_facing()
	var beam: LaserBeam = BEAM.instantiate()
	beam.damage = 30.0
	beam.knockback = 150.0
	beam.beam_range = RANGE
	beam.source = player
	# Live in the level, not under the player, so it stays put as he moves on.
	# Nodes.place_at snaps it to the muzzle without physics-interpolation smear.
	player.get_parent().add_child(beam)
	Nodes.place_at(beam, player.global_position + Vector2(MUZZLE.x * facing, MUZZLE.y))
	beam.fire(Vector2(facing, 0))
