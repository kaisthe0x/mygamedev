class_name Hitbox
extends Area2D

## A region that DEALS damage. While active it scans for Hurtboxes (its
## `collision_mask` = the opposing team's hurt layer) and damages each one once
## per activation. Re-activating (a new swing) clears the memory so it can hit
## again.
##
## Melee-style boxes are toggled on for their active frames via activate()/
## deactivate(); a projectile can just leave it active for its whole life.

@export var damage: float = 10.0
## Optional on-hit effects this box carries (0 = none). Set per attack.
@export var knockback: float = 0.0
@export var stun: float = 0.0
## Optional engulfing status overlay on the victim (a > 0 enables it).
@export var status_color: Color = Color(0, 0, 0, 0)
@export var status_time: float = 0.0
## Optional custom VFX scene spawned on the victim on hit (a stun effect, a slam shock, ...).
## Null = none. Lives for victim_vfx_time seconds (0 -> defaults to the status/stun duration).
@export var victim_vfx: PackedScene = null
@export var victim_vfx_time: float = 0.0
## Marks hits from this box as ranged (a projectile). Projectile sets it on its box; melee
## Strikes leave it false. Carried into the Hit so a victim can react by attack type.
@export var ranged: bool = false
## Marks hits from this box as coming from the player's SPECIAL (set via tuning). Carried into
## the Hit so a special-kill doesn't refill Ruh (see Player / RunManager).
@export var from_special: bool = false
## Seconds to CHARM an enemy victim into a temporary ally (0 = none). Set via a move's `frenemy`
## tuning; carried into the Hit -> Enemy.become_frenemy.
@export var frenemy_time: float = 0.0
## Optional damage-over-time ("reap"): dot_percent = fraction of the victim's MAX health drained
## per 1s tick, dot_time = how long it lasts. Set via a move's `reap`/`reap_time` tuning; carried
## into the Hit -> Enemy arms a ticking reap (see Enemy._tick_dot). Both 0 = no DoT.
@export var dot_percent: float = 0.0
@export var dot_time: float = 0.0
## Who fired this, passed along so the victim knocks back away from them.
var source: Node = null

## Emitted when this box connects with a Hurtbox -- lets a projectile free on impact.
signal struck(victim: Hurtbox)

var _already_hit: Array[Hurtbox] = []


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	# Off until explicitly activated; scanning a stale overlap on spawn is a
	# common source of phantom hits.
	monitoring = false


## Turn the box on. `duration` > 0 auto-deactivates after that many seconds
## (a discrete strike); 0 leaves it on until deactivate() (an attack's active
## frames, or a projectile's whole life).
func activate(duration: float = 0.0) -> void:
	_already_hit.clear()
	monitoring = true
	if duration > 0.0:
		var t := get_tree().create_timer(duration)
		t.timeout.connect(deactivate)


## Turn the box off -- the end of a swing's active frames, or a projectile expiring.
func deactivate() -> void:
	monitoring = false


## Re-deal to every Hurtbox CURRENTLY inside the box -- one pulse of a ticking / DoT
## field (a burning field: e.g. 10 dmg every 0.25s while it burns). `area_entered` only fires
## on ENTER, so a target standing still in the box would never be hit again; this clears
## the per-hit memory and re-delivers to whoever's overlapping right now. Walk out and you
## stop taking it. No-op while the box is off.
func pulse() -> void:
	if not monitoring:
		return
	_already_hit.clear()
	for area in get_overlapping_areas():
		_on_area_entered(area)


## On first overlap with a Hurtbox this activation, build a Hit from this box's
## fields (damage/knockback/stun/status + source) and deliver it.
func _on_area_entered(area: Area2D) -> void:
	var box := area as Hurtbox
	if box == null or box in _already_hit:
		return
	# Never hit our own source's hurtbox. Harmless normally (teams don't overlap), but
	# with friendly fire an ally-scanning box would otherwise damage the attacker itself.
	# is_instance_valid, not != null: a shot outlives its firer, so `source` may be FREED --
	# a freed ref isn't null, and assigning/dereferencing it later errors.
	if is_instance_valid(source) and box.get_parent() == source:
		return
	_already_hit.append(box)
	var hit := Hit.new()
	hit.amount = damage
	hit.knockback = knockback
	hit.stun = stun
	hit.status_color = status_color
	hit.status_time = status_time if status_time > 0.0 else stun
	hit.victim_vfx = victim_vfx
	# Default the VFX lifetime to the status/stun window so e.g. a stun effect lasts the whole stun.
	hit.victim_vfx_time = victim_vfx_time if victim_vfx_time > 0.0 else hit.status_time
	hit.ranged = ranged
	hit.from_special = from_special
	hit.frenemy_time = frenemy_time
	hit.dot_percent = dot_percent
	hit.dot_time = dot_time
	var credit: Node = source if is_instance_valid(source) else owner
	hit.source = credit if is_instance_valid(credit) else null
	box.take_hit(hit)
	struck.emit(box)
