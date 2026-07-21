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
## Who fired this, passed along so the victim knocks back away from them.
var source: Node = null

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


func deactivate() -> void:
	monitoring = false


func _on_area_entered(area: Area2D) -> void:
	var box := area as Hurtbox
	if box == null or box in _already_hit:
		return
	_already_hit.append(box)
	var hit := Hit.new()
	hit.amount = damage
	hit.knockback = knockback
	hit.stun = stun
	hit.status_color = status_color
	hit.status_time = status_time if status_time > 0.0 else stun
	hit.source = source if source != null else owner
	box.take_hit(hit)
