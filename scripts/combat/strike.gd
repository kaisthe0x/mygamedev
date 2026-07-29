class_name Strike
extends Node2D

## A non-projectile attack that plants a hitbox at/near the body -- a melee slash, a
## short blast, or a ground AoE. The Strike counterpart to Projectile (which leaves the
## body). It carries a Hitbox + a drawn or particle visual, mirrors with facing (a
## Sprite2D h-flips cleanly under a scale flip, which a CPUParticles2D can't), and frees
## itself when its visual is done. Fired by the ParticleDirector as a burst, or (future)
## attached to the player for a dash-through hitbox. Team-agnostic via `hostile`.
##
## Combat NUMBERS (damage / knockback / stun / reach, plus the lunge / super-armor /
## multi-hit knobs) come from configs/moves.gd via the player's resolve seam and are
## applied through apply_tuning() at spawn -- they are NOT baked here. This class owns
## the LOOK and the strike BEHAVIOR (grow/fade, multi-hit re-arm, lunge/armor callbacks).

## false = a player strike (hits enemies); true = an enemy strike (hits the player).
@export var hostile: bool = false

@export_group("Visual")
## Seconds the strike stays on screen before it frees itself (a drawn slash's life). A
## particle strike also waits for its emitters' particles to finish, so it isn't cut off.
@export var lifetime: float = 0.4
## Drawn visuals pop from this scale multiple to their authored scale over the first bit
## (a quick swing snap). 1.0 = no grow.
@export var grow_from: float = 0.7

## Who struck (knockback credit + lunge/armor target); set by the spawner.
var source: Node = null

var _hitbox: Hitbox


func _ready() -> void:
	_hitbox = _find_hitbox()
	if _hitbox != null:
		_hitbox.collision_layer = Combat.hit_layer(hostile)
		_hitbox.collision_mask = Combat.hurt_mask(hostile)

	var vis := _visuals()
	if not vis.is_empty():
		var tw := create_tween().set_parallel(true)
		for v in vis:
			var target: Vector2 = v.scale
			v.scale = target * grow_from
			tw.tween_property(v, "scale", target, lifetime * 0.45) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(v, "modulate:a", 0.0, lifetime).set_ease(Tween.EASE_IN)

	# Free once the visual is done: the slash lifetime OR the longest particle life,
	# whichever outlasts the other, so a particle burst isn't cut short.
	var free_delay := lifetime
	for em in _emitters():
		free_delay = maxf(free_delay, em.lifetime * (1.0 + em.lifetime_randomness))
	get_tree().create_timer(free_delay).timeout.connect(queue_free)


## Configure this strike from a resolved tuning dict (moves.gd via the player's resolve
## seam, or an enemy's exports): set the hitbox's numbers + reach, and trigger the
## wielder-effects (lunge, super-armor) on `source`. Called by the spawner after
## add_child, before the hitbox is armed. Absent fields keep the hitbox's authored
## values, so a bare Strike still works with no tuning at all.
func apply_tuning(t: Dictionary, striker: Node = null) -> void:
	if striker != null:
		source = striker
	if _hitbox == null:
		_hitbox = _find_hitbox()
	if _hitbox != null and not t.is_empty():
		if t.has("damage"):
			_hitbox.damage = t["damage"]
		if t.has("knockback"):
			_hitbox.knockback = t["knockback"]
		if t.has("stun"):
			_hitbox.stun = t["stun"]
		if t.has("color"):
			_hitbox.status_color = t["color"]
		if t.has("color") or t.has("stun"):
			_hitbox.status_time = t.get("color_time", t.get("stun", 0.0))
		_resize_hitbox(t)
	# Wielder-effects act on the striker (option A): lunge shoves them forward, armor
	# lets them shrug off stagger during the swing. No-op when the field/method is absent.
	if source != null:
		var lunge: float = t.get("lunge", 0.0)
		if lunge != 0.0 and source.has_method("apply_lunge"):
			source.apply_lunge(lunge)
		var armor: float = t.get("super_armor", 0.0)
		if armor > 0.0 and source.has_method("set_armor"):
			source.set_armor(armor)
	var hits: int = int(t.get("multi_hit", 1))
	if hits > 1 and _hitbox != null:
		_setup_multi_hit(hits)


## Re-arm the hitbox `hits` times across the strike's life, so it can connect more than
## once (a buff). Each activation clears the box's per-hit memory, so something standing
## in it is struck once per pulse.
func _setup_multi_hit(hits: int) -> void:
	var interval := lifetime / float(hits)
	for i in range(1, hits):
		get_tree().create_timer(interval * i).timeout.connect(func() -> void:
			if is_instance_valid(_hitbox):
				_hitbox.activate())


## Resize / reposition the hitbox from tuning `extents` (half-size) and `x` (forward
## reach). `x` is the right-facing value -- our node's scale.x mirror handles left. Only
## the box's own shape is duplicated, never the shared resource.
func _resize_hitbox(t: Dictionary) -> void:
	if _hitbox == null or not (t.has("extents") or t.has("x")):
		return
	for cs in _hitbox.find_children("*", "CollisionShape2D", true, false):
		if cs.shape is RectangleShape2D:
			var rect: RectangleShape2D = cs.shape.duplicate()
			cs.shape = rect
			if t.has("extents"):
				rect.size = (t["extents"] as Vector2) * 2.0
			if t.has("x"):
				cs.position.x = float(t["x"])
			return


func _find_hitbox() -> Hitbox:
	for a in find_children("*", "Area2D", true, false):
		if a is Hitbox:
			return a as Hitbox
	return null


func _visuals() -> Array:
	var out: Array = []
	out.append_array(find_children("*", "Sprite2D", true, false))
	out.append_array(find_children("*", "AnimatedSprite2D", true, false))
	return out


func _emitters() -> Array:
	var out: Array = []
	out.append_array(find_children("*", "CPUParticles2D", true, false))
	out.append_array(find_children("*", "GPUParticles2D", true, false))
	return out
