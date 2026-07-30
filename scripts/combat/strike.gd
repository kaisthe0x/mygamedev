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
## When true this box also hits its OWN team (allies), not just the opposing one -- e.g.
## an enemy whose attacks can catch other enemies. Off by default; the box still never
## hits its own source. See Combat.hurt_mask.
@export var friendly_fire: bool = false

@export_group("Visual")
## Seconds the strike stays on screen before it frees itself (a drawn slash's life). A
## particle strike also waits for its emitters' particles to finish, so it isn't cut off.
@export var lifetime: float = 0.4
## Drawn visuals pop from this scale multiple to their authored scale over the first bit
## (a quick swing snap). 1.0 = no grow.
@export var grow_from: float = 0.7
## Continuous emission window (seconds). 0 = a one-shot burst (the default). > 0 = the
## effect's particles keep emitting CONTINUOUSLY for this long, then stop -- so the emit
## DURATION is set independently of particle lifetime/velocity (which set how FAR each
## particle travels, not how long they keep spawning). While a timed emission plays, the
## striker's animation is HELD on its current frame (see apply_tuning -> hold_animation).
@export var emit_duration: float = 0.0
## For a held/channeled effect (emit_duration > 0): whether the caster being HIT cancels
## it -- the channel breaks (Wayna's inferno stops when she's damaged). Default true (the
## norm). Set false for an uninterruptible channel. Ignored by non-channel strikes.
@export var interrupt_on_hurt: bool = true

## Who struck (knockback credit + lunge/armor target); set by the spawner.
var source: Node = null

var _hitbox: Hitbox
var _tick_timer: Timer  # the DoT re-pulse timer, if any (see _start_ticking)


func _ready() -> void:
	_hitbox = _find_hitbox()
	if _hitbox != null:
		_hitbox.collision_layer = Combat.hit_layer(hostile)
		_hitbox.collision_mask = Combat.hurt_mask(hostile, friendly_fire)

	var vis := _visuals()
	if not vis.is_empty():
		var tw := create_tween().set_parallel(true)
		for v in vis:
			var target: Vector2 = v.scale
			v.scale = target * grow_from
			tw.tween_property(v, "scale", target, lifetime * 0.45) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(v, "modulate:a", 0.0, lifetime).set_ease(Tween.EASE_IN)

	# Free once everything's done. One-shot burst: max(slash lifetime, longest particle
	# life). Timed emission (emit_duration > 0): the emission WINDOW plus the last
	# particle's life, so a continuous stream isn't cut off mid-emit.
	var emit_window := maxf(emit_duration, 0.0)
	var free_delay := maxf(lifetime, emit_window)
	for em in _emitters():
		free_delay = maxf(free_delay, emit_window + em.lifetime * (1.0 + em.lifetime_randomness))
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
	# Hold the striker's pose while a timed emission plays out (Wayna frozen on the
	# inferno cast frame until the fire finishes) -- option A: the strike drives its wielder.
	if emit_duration > 0.0 and source != null and source.has_method("hold_animation"):
		source.hold_animation(emit_duration, self)  # pass self so the caster can cancel us
	# Damage-over-time: re-hit everyone in the box every `tick` seconds for the strike's
	# life (inferno = 10 dmg every 0.25s). tick 0 = a single hit (the default).
	var tick: float = t.get("tick", 0.0)
	if tick > 0.0 and _hitbox != null:
		_start_ticking(tick)


## Hit `hits` times across the strike's life -- a fixed COUNT of pulses (a buff: "hits
## three times"). For a steady interval instead (a burning field), use `tick`.
func _setup_multi_hit(hits: int) -> void:
	var interval := lifetime / float(hits)
	for i in range(1, hits):
		get_tree().create_timer(interval * i).timeout.connect(func() -> void:
			if is_instance_valid(_hitbox):
				_hitbox.pulse())


## Re-pulse the hitbox every `interval` seconds for the strike's whole life -- a
## damage-over-time field. A repeating Timer (freed with this node, so it stops when the
## strike does). The pulse hits whoever is standing in the box at that instant.
func _start_ticking(interval: float) -> void:
	var timer := Timer.new()
	timer.wait_time = interval
	timer.timeout.connect(func() -> void:
		if is_instance_valid(_hitbox):
			_hitbox.pulse())
	add_child(timer)
	timer.start()
	_tick_timer = timer


## Stop this effect NOW -- the caster's channel was interrupted (e.g. Wayna hit mid-
## inferno). Halt emission, damage ticks, and the hitbox, then free once the live
## particles fade so it dissipates instead of popping.
func cancel() -> void:
	if is_instance_valid(_tick_timer):
		_tick_timer.stop()
	if _hitbox != null:
		_hitbox.deactivate()
	var linger := 0.0
	for em in _emitters():
		em.emitting = false
		linger = maxf(linger, em.lifetime * (1.0 + em.lifetime_randomness))
	if linger <= 0.0:
		queue_free()
	else:
		get_tree().create_timer(linger).timeout.connect(queue_free)


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
