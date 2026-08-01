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
## Marks hits from this box as ranged (a projectile). Projectile sets it on its box; melee
## Strikes leave it false. Carried into the Hit so a victim can react by attack type.
@export var ranged: bool = false
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
## field (Wayna's inferno: 10 dmg every 0.25s while it burns). `area_entered` only fires
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
	if source != null and box.get_parent() == source:
		return
	_already_hit.append(box)
	var hit := Hit.new()
	hit.amount = damage
	hit.knockback = knockback
	hit.stun = stun
	hit.status_color = status_color
	hit.status_time = status_time if status_time > 0.0 else stun
	hit.ranged = ranged
	hit.source = source if source != null else owner
	box.take_hit(hit)
	struck.emit(box)
