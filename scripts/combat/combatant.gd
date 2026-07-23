@tool
class_name Combatant
extends CharacterBody2D

## Shared base for the game's damageable, sprite-driven bodies (Player, Enemy).
## It holds the small pieces both would otherwise reimplement identically:
## feet-anchoring the sprite, the hit-flash, building box colliders, and turning
## an incoming Hit's knockback into a shove + stagger time. Subclasses keep their
## own state machines, health, and hurt reactions -- this is deliberately just
## helpers, no lifecycle of its own.

## Red tint a hit flashes, fading back over HIT_FLASH_TIME.
const HIT_FLASH := Color(1.0, 0.4, 0.4)
const HIT_FLASH_TIME := 0.16


## Anchor a sprite so its feet sit on the node origin, horizontally centred, using
## idle frame 0 -- the shared canvas anchor every animation lines up against.
static func anchor_to_feet(sprite: AnimatedSprite2D) -> void:
	var frame := sprite.sprite_frames.get_frame_texture(&"idle", 0)
	if frame == null:
		return
	sprite.centered = false
	sprite.offset = Vector2(-frame.get_width() / 2.0, -frame.get_height())


## A rectangular CollisionShape2D of full `size`, centred at `offset`.
static func make_box(size: Vector2, offset: Vector2) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = offset
	return shape


## Apply an incoming hit's knockback to this body and return how long to stagger
## (0 = none). The caller applies its own stun state with the returned time and
## passes its current facing, used as the shove direction when the source is
## exactly level with us.
func apply_knockback(hit: Hit, facing: int) -> float:
	var stagger := hit.stun
	if hit.knockback > 0.0 and hit.source != null:
		var dir := signi(int(sign(global_position.x - (hit.source as Node2D).global_position.x)))
		if dir == 0:
			dir = -facing
		velocity.x = dir * hit.knockback
		velocity.y = -hit.knockback * Combat.KNOCKBACK_POP
		stagger = maxf(stagger, Combat.MIN_STAGGER)
	return stagger


## Flash `sprite` red, fading back to white -- the shared "took a hit" tell.
func flash(sprite: AnimatedSprite2D) -> void:
	sprite.modulate = HIT_FLASH
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, HIT_FLASH_TIME)
