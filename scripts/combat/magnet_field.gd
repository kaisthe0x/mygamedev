class_name MagnetField
extends Node2D

## The Come Closer special's effect: on spawn, MAGNETIZE every enemy within `pull_range` toward Khalid
## -- each is dragged in (Enemy.magnetize) and STUNNED on arrival for `stun_time` (no damage). Spawned
## in FRONT of Khalid by the EmittersCharacters row for `special_come_closer` on the beckon frame; it
## self-frees after `life` (its particles play out). The enemies keep homing on Khalid even after the
## field frees, until they arrive. All feel is the exports below -- edit + re-run to tune.

@export var pull_range: float = 260.0   ## HORIZONTAL grab distance (from the field, which sits in front of Khalid)
@export var pull_y_band: float = 48.0   ## only grab enemies within this vertical band of Khalid -- SAME LEVEL, not platforms above/below
@export var arrive_dist: float = 64.0   ## enemies stop + get stunned once this close to Khalid (kept out of sprite overlap)
@export var pull_speed: float = 340.0   ## magnet drag speed, px/s
@export var stun_time: float = 1.5      ## seconds each grabbed enemy is stunned on arrival
@export var life: float = 1.6           ## how long the field lingers before self-freeing (visual)


func _ready() -> void:
	var khalid := get_tree().get_first_node_in_group("player") as Node2D
	if khalid != null:
		for e in get_tree().get_nodes_in_group("enemies"):
			var enemy := e as Enemy
			if enemy == null:
				continue
			# Horizontal reach from the field + SAME LEVEL as Khalid (vertical band) -- skip anything on a
			# platform above/below, so the pull only grabs enemies sharing his floor.
			if absf(enemy.global_position.x - global_position.x) <= pull_range \
					and absf(enemy.global_position.y - khalid.global_position.y) <= pull_y_band:
				enemy.magnetize(khalid, arrive_dist, pull_speed, stun_time)
	get_tree().create_timer(life).timeout.connect(queue_free)
