class_name Shot
extends Node2D

## A player projectile for a "shooting" attack (Lenny's finger guns, Feyke's ring
## kiss). The ParticleDirector spawns it as a burst on the attack's fire frames; from
## there it flies in the character's facing (which tracks the mouse) and homes toward
## the nearest enemy AHEAD on the x-axis. Its look is its own -- a particle emitter OR
## an AnimatedSprite2D playing drawn frames -- and it carries a Hitbox (anywhere in the
## scene, not just the root). Frees on a hit or at max range. Because it manages its own
## life, the director does NOT free it when its particle finishes (see
## ParticleDirector._fire_burst).
##
## Horizontal by design: projectiles never steer upward (they may track level or DOWN
## toward a lower enemy) and ignore enemies overhead -- set `can_fly_up` for an exception.

## Travel speed (px/s).
@export var speed: float = 420.0
## Steer rate toward the tracked enemy -- higher turns tighter, 0 flies straight.
@export var homing: float = 6.0
## How far it flies before fizzling out.
@export var max_range: float = 320.0
## Only locks onto an enemy this close (at spawn) in the aim direction.
@export var acquire_range: float = 420.0
## Let this shot arc upward. Default false: it flies horizontally, only ever tracking
## level or downward (never rising), and won't target enemies overhead.
@export var can_fly_up: bool = false
## How far above the shot an enemy's torso can sit and still be targetable (px). Beyond
## this it's "overhead" and ignored. Unused when can_fly_up is true.
@export var vertical_reach: float = 40.0
## Optional one-shot effect spawned at the point of contact when the shot hits an enemy
## (a hit spark / puff). It's parented into the world and self-frees. Empty = none.
@export var impact_effect: PackedScene
## Optional drawn END animation, played in place when the shot reaches max range WITHOUT
## hitting anything -- so it dissolves instead of blinking out. A SpriteFrames (its
## "default" animation, non-looping); on expiry the shot freezes, stops its hitbox, swaps
## its AnimatedSprite2D to this, and frees when it finishes. Empty = just vanish. (Only
## the natural-expiry case -- a hit uses impact_effect above.)
@export var end_frames: SpriteFrames

var _dir := Vector2.RIGHT
var _traveled := 0.0
var _target: Node2D
var _acquired := false
var _dying := false  # true while the end animation plays out; movement + hits are off


func _ready() -> void:
	# The director mirrors the composite by scale.x for facing; read forward from it,
	# then normalise the transform since we move in world space from here.
	_dir = Vector2(-1.0 if scale.x < 0.0 else 1.0, 0.0)
	scale.x = 1.0
	rotation = _dir.angle()
	# Target is acquired on the first physics tick, NOT here: the director calls
	# place_at AFTER add_child, so at _ready our global_position is still the spawn
	# origin (~world 0,0), not the muzzle -- acquiring now would think every enemy near
	# the player is "ahead" and pick the closest, even the one behind us.
	var hb := _find_hitbox()
	if hb != null:
		hb.struck.connect(_on_struck)


func _physics_process(delta: float) -> void:
	if _dying:
		return  # dissolving in place -- no more travel or homing
	if not _acquired:
		_target = _nearest_enemy_ahead()
		_acquired = true
	if is_instance_valid(_target):
		var want := _target.global_position - global_position
		if not can_fly_up and want.y < 0.0:
			want.y = 0.0  # track a level/lower enemy, never steer upward
		if want.length() > 0.01:
			_dir = _dir.slerp(want.normalized(), clampf(homing * delta, 0.0, 1.0))
	if not can_fly_up and _dir.y < 0.0:
		_dir = Vector2(_dir.x, 0.0)  # hard floor: a projectile never travels upward
		_dir = _dir.normalized() if _dir.length() > 0.01 else Vector2.RIGHT
	global_position += _dir * speed * delta
	rotation = _dir.angle()
	_traveled += speed * delta
	if _traveled >= max_range:
		_expire()


## Nearest enemy AHEAD of the shot in its facing x-direction, within acquire_range
## (measured on the x-axis). Enemies overhead (more than vertical_reach above) are
## skipped unless can_fly_up. Returns the enemy's aim node (torso) or null -> fly straight.
func _nearest_enemy_ahead() -> Node2D:
	var facing := 1.0 if _dir.x >= 0.0 else -1.0
	var best: Node2D = null
	var best_d := acquire_range
	for e in get_tree().get_nodes_in_group("enemies"):
		var n := e as Node2D
		if n == null:
			continue
		var aim := _aim_point(n)
		if aim == null:
			continue
		var to := aim.global_position - global_position
		if to.x * facing <= 0.0:
			continue  # behind us in x (wrong side of the mouse direction)
		if not can_fly_up and to.y < -vertical_reach:
			continue  # overhead -- horizontal shots don't reach up
		var d := absf(to.x)  # closeness along the shot's line of travel
		if d < best_d:
			best_d = d
			best = aim
	return best


## What the shot homes to for `enemy`: its hurtbox's centre (the torso) so shots
## land on the body, not the node origin which sits at the enemy's feet. Falls back
## to the enemy itself. Returns a live node so homing tracks it as the enemy moves.
func _aim_point(enemy: Node2D) -> Node2D:
	if enemy == null:
		return null
	for a in enemy.find_children("*", "Area2D", true, false):
		if a is Hurtbox:
			var shape := (a as Node).find_children("*", "CollisionShape2D", true, false)
			if not shape.is_empty():
				return shape[0]
	return enemy


## The shot's Hitbox, found anywhere in its scene -- it may sit under an AnimatedSprite2D
## or a particle node, not just at the root.
func _find_hitbox() -> Hitbox:
	for a in find_children("*", "Area2D", true, false):
		if a is Hitbox:
			return a as Hitbox
	return null


## Hit an enemy: drop the impact effect (if any) at the point of contact, then die.
func _on_struck(_victim: Hurtbox) -> void:
	if impact_effect != null:
		_spawn_impact()
	queue_free()


## Reached max range without hitting anything. With no `end_frames`, just vanish (the
## old behaviour). Otherwise dissolve in place: freeze, switch off the hitbox + any
## particle trail, play the drawn end animation on the shot's own sprite (seamless --
## same position/scale/facing), and free when it finishes.
func _expire() -> void:
	if end_frames == null:
		queue_free()
		return
	_dying = true
	var hb := _find_hitbox()
	if hb != null:
		hb.deactivate()
	for em in find_children("*", "CPUParticles2D", true, false):
		em.emitting = false  # stop any trail so only the dissolve shows
	for em in find_children("*", "GPUParticles2D", true, false):
		em.emitting = false
	var spr := _find_sprite()
	if spr == null:  # a particle-only shot with no drawn sprite -- make one to play on
		spr = AnimatedSprite2D.new()
		add_child(spr)
	spr.sprite_frames = end_frames
	spr.play(&"default")
	spr.animation_finished.connect(queue_free)
	# Backstop so a mistakenly-looping end animation can't leave the shot alive forever.
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free())


## The shot's AnimatedSprite2D (its drawn body), found anywhere in the scene, or null
## for a particle-only shot.
func _find_sprite() -> AnimatedSprite2D:
	for a in find_children("*", "AnimatedSprite2D", true, false):
		return a as AnimatedSprite2D
	return null


## Spawn the impact effect in the world at the hit point and let it self-finish: its
## particle emitters fire one-shot and the node frees once they're done (or after a
## short fallback if it carries no emitters).
func _spawn_impact() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var fx := impact_effect.instantiate()
	parent.add_child(fx)
	if fx is Node2D:
		(fx as Node2D).global_position = global_position
	var emitters: Array = []
	if fx is CPUParticles2D or fx is GPUParticles2D:
		emitters.append(fx)
	emitters.append_array(fx.find_children("*", "CPUParticles2D", true, false))
	emitters.append_array(fx.find_children("*", "GPUParticles2D", true, false))
	for em in emitters:
		em.one_shot = true
		em.emitting = true
	if emitters.is_empty():
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			if is_instance_valid(fx):
				fx.queue_free())
	else:
		emitters[0].finished.connect(func() -> void:
			if is_instance_valid(fx):
				fx.queue_free())
