class_name MagnetField
extends Node2D

## The Come Closer special's effect: on spawn, MAGNETIZE the `max_targets` NEAREST enemies within
## `pull_range` toward Khalid -- each is dragged in (Enemy.magnetize) and STUNNED on arrival for
## `stun_time` (no damage). Spawned in FRONT of Khalid by the EmittersCharacters row for
## `special_come_closer` on the beckon frame; it self-frees after `life` (its particles play out). The
## enemies keep homing on Khalid even after the field frees, until they arrive. All feel is the exports below.

@export var pull_range: float = 260.0   ## HORIZONTAL grab distance, measured from KHALID (reaches enemies on either side of him)
@export var pull_y_band: float = 48.0   ## only grab enemies within this vertical band of Khalid -- SAME LEVEL, not platforms above/below
@export var max_targets: int = 1        ## how many enemies to grab -- the NEAREST this-many. Buff to 3 later for a bigger yank.
@export var arrive_dist: float = 64.0   ## enemies stop + get stunned once this close to Khalid (kept out of sprite overlap)
@export var pull_speed: float = 340.0   ## magnet drag speed, px/s
@export var stun_time: float = 1.5      ## seconds each grabbed enemy is stunned on arrival
@export var life: float = 1.6           ## how long the field lingers before self-freeing (visual)


func _ready() -> void:
	var khalid := get_tree().get_first_node_in_group("player") as Node2D
	if khalid != null:
		# Measure the grab from KHALID, NOT `self` -- the director spawns us via add_child() (which runs
		# THIS _ready) and only sets our world position with Nodes.place_at() AFTERWARDS, so our own
		# global_position isn't final here yet. Reading it gave a stale transform -> the scan grabbed
		# enemies only intermittently ("works once, then hit-or-miss"). Khalid's position is always valid.
		var origin := khalid.global_position
		# Collect every in-range, same-level enemy with its horizontal distance, then grab only the
		# NEAREST `max_targets` (sorted closest-first). max_targets = 1 today; bump it for a wider yank.
		var in_reach: Array = []
		for e in get_tree().get_nodes_in_group("enemies"):
			var enemy := e as Enemy
			if enemy == null:
				continue
			# Horizontal reach around Khalid + SAME LEVEL (vertical band) -- skip anything on a platform
			# above/below, so the pull only grabs enemies sharing his floor.
			var dx: float = absf(enemy.global_position.x - origin.x)
			if dx <= pull_range and absf(enemy.global_position.y - origin.y) <= pull_y_band:
				in_reach.append({"enemy": enemy, "dist": dx})
		in_reach.sort_custom(func(a, b): return a.dist < b.dist)
		for i in mini(max_targets, in_reach.size()):
			in_reach[i].enemy.magnetize(khalid, arrive_dist, pull_speed, stun_time)
	get_tree().create_timer(life).timeout.connect(queue_free)
