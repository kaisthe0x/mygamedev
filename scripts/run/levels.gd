class_name Levels
extends RefCounted

## The 5 arena levels of a run, as data. RunManager builds and runs each one.
##
## Per level:
##   name         display name
##   bg           background tint -- gives each level a different LOOK
##   platforms    [[center_x, top_y, width], ...] one-way ledges (the Floor is always there)
##   player_spawn where the player drops in
##   exit_pos     where the exit gate sits; walk into it (with enough life) to leave
##   exit_cost    LIFE (HP + lahm) the gate charges to pass -- rises each level (see game-design.md)
##   start        enemies present on arrival -- [{kit, pos}, ...] (kit = an EnemyKits.* dict)
##   waves        escalating refills: when EVERY enemy is dead, the next wave spawns. Each wave is
##                [{kit, pos}, ...]. Past the last wave the LAST one repeats, so pressure never stops
##                -- the level ends only when you pay the exit, never by clearing.
##
## Design the waves by tier (EnemyKits.Tier): open soft, ramp up. "3 strong" is brutal; prefer
## "some chip + one strong" early, more strong later. All tunable here, one place.

static var _cache: Array  ## built once from _build() (can't be a const -- refs EnemyKits consts)


static func count() -> int:
	return _all().size()


static func get_level(i: int) -> Dictionary:
	var a := _all()
	return a[clampi(i, 0, a.size() - 1)]


static func _all() -> Array:
	if _cache.is_empty():
		_cache = _build()
	return _cache


static func _build() -> Array:
	return [
	# ── 1 · The Shallows ── ease-in: chip fodder, one strong. Cheap gate. ──────────────
	{
		"name": "The Shallows",
		"bg": Color(0.06, 0.10, 0.13),
		"platforms": [[-300.0, -95.0, 170.0], [40.0, -150.0, 160.0], [330.0, -110.0, 180.0]],
		"player_spawn": Vector2(-470.0, 0.0),
		"exit_pos": Vector2(520.0, -20.0),
		"exit_cost": 120.0,
		"start": [
			{"kit": EnemyKits.BAGHEL, "pos": Vector2(120.0, 0.0)},
			{"kit": EnemyKits.BAGHEL, "pos": Vector2(-40.0, -150.0)},
			{"kit": EnemyKits.KEBUS, "pos": Vector2(330.0, -110.0)},
		],
		"waves": [
			[{"kit": EnemyKits.BAGHEL, "pos": Vector2(-300.0, -95.0)}, {"kit": EnemyKits.EIN, "pos": Vector2(200.0, -180.0)}],
			[{"kit": EnemyKits.BAGHEL, "pos": Vector2(0.0, 0.0)}, {"kit": EnemyKits.BAGHEL, "pos": Vector2(300.0, 0.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(-300.0, -95.0)}],
		],
	},
	# ── 2 · Redward ── more mid enemies, a lob thrower. ────────────────────────────────
	{
		"name": "Redward",
		"bg": Color(0.13, 0.05, 0.06),
		"platforms": [[-350.0, -120.0, 150.0], [-40.0, -190.0, 170.0], [280.0, -140.0, 160.0], [430.0, -240.0, 140.0]],
		"player_spawn": Vector2(-470.0, 0.0),
		"exit_pos": Vector2(520.0, -20.0),
		"exit_cost": 180.0,
		"start": [
			{"kit": EnemyKits.KEBUS, "pos": Vector2(-150.0, 0.0)},
			{"kit": EnemyKits.MAZAB, "pos": Vector2(280.0, -140.0)},
			{"kit": EnemyKits.BAGHEL, "pos": Vector2(150.0, 0.0)},
		],
		"waves": [
			[{"kit": EnemyKits.EIN, "pos": Vector2(-100.0, -200.0)}, {"kit": EnemyKits.EIN, "pos": Vector2(300.0, -220.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(0.0, 0.0)}],
			[{"kit": EnemyKits.MAZAB, "pos": Vector2(-40.0, -190.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(-350.0, -120.0)}, {"kit": EnemyKits.BAGHEL, "pos": Vector2(400.0, 0.0)}],
		],
	},
	# ── 3 · The Gullet ── nasen sleepers guarding, tighter. ────────────────────────────
	{
		"name": "The Gullet",
		"bg": Color(0.09, 0.05, 0.12),
		"platforms": [[-280.0, -110.0, 160.0], [80.0, -160.0, 200.0], [360.0, -120.0, 150.0], [-120.0, -250.0, 150.0]],
		"player_spawn": Vector2(-470.0, 0.0),
		"exit_pos": Vector2(520.0, -20.0),
		"exit_cost": 260.0,
		"start": [
			{"kit": EnemyKits.NASEN, "pos": Vector2(80.0, -160.0)},
			{"kit": EnemyKits.KEBUS, "pos": Vector2(-200.0, 0.0)},
			{"kit": EnemyKits.MAZAB, "pos": Vector2(300.0, 0.0)},
		],
		"waves": [
			[{"kit": EnemyKits.EIN, "pos": Vector2(0.0, -220.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(-280.0, -110.0)}, {"kit": EnemyKits.BAGHEL, "pos": Vector2(200.0, 0.0)}],
			[{"kit": EnemyKits.NASEN, "pos": Vector2(-120.0, -250.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(360.0, -120.0)}, {"kit": EnemyKits.MAZAB, "pos": Vector2(-100.0, 0.0)}],
		],
	},
	# ── 4 · Ossuary ── strong-heavy, orbs everywhere. ──────────────────────────────────
	{
		"name": "Ossuary",
		"bg": Color(0.05, 0.11, 0.08),
		"platforms": [[-330.0, -100.0, 150.0], [-60.0, -170.0, 160.0], [220.0, -130.0, 170.0], [420.0, -220.0, 150.0], [60.0, -270.0, 160.0]],
		"player_spawn": Vector2(-470.0, 0.0),
		"exit_pos": Vector2(520.0, -20.0),
		"exit_cost": 350.0,
		"start": [
			{"kit": EnemyKits.KEBUS, "pos": Vector2(-180.0, 0.0)},
			{"kit": EnemyKits.NASEN, "pos": Vector2(60.0, -270.0)},
			{"kit": EnemyKits.EIN, "pos": Vector2(150.0, -200.0)},
			{"kit": EnemyKits.MAZAB, "pos": Vector2(300.0, 0.0)},
		],
		"waves": [
			[{"kit": EnemyKits.KEBUS, "pos": Vector2(-330.0, -100.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(220.0, -130.0)}, {"kit": EnemyKits.EIN, "pos": Vector2(0.0, -230.0)}],
			[{"kit": EnemyKits.NASEN, "pos": Vector2(-60.0, -170.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(420.0, -220.0)}, {"kit": EnemyKits.MAZAB, "pos": Vector2(-200.0, 0.0)}, {"kit": EnemyKits.EIN, "pos": Vector2(250.0, -250.0)}],
		],
	},
	# ── 5 · Way of All Flesh ── the culmination: everything, expensive gate. ───────────
	{
		"name": "Way of All Flesh",
		"bg": Color(0.13, 0.08, 0.03),
		"platforms": [[-350.0, -110.0, 150.0], [-80.0, -180.0, 170.0], [200.0, -140.0, 160.0], [420.0, -230.0, 150.0], [-200.0, -260.0, 150.0]],
		"player_spawn": Vector2(-470.0, 0.0),
		"exit_pos": Vector2(520.0, -20.0),
		"exit_cost": 450.0,
		"start": [
			{"kit": EnemyKits.NASEN, "pos": Vector2(-200.0, -260.0)},
			{"kit": EnemyKits.KEBUS, "pos": Vector2(-150.0, 0.0)},
			{"kit": EnemyKits.KEBUS, "pos": Vector2(200.0, -140.0)},
			{"kit": EnemyKits.MAZAB, "pos": Vector2(320.0, 0.0)},
		],
		"waves": [
			[{"kit": EnemyKits.KEBUS, "pos": Vector2(-350.0, -110.0)}, {"kit": EnemyKits.NASEN, "pos": Vector2(-80.0, -180.0)}, {"kit": EnemyKits.EIN, "pos": Vector2(100.0, -240.0)}, {"kit": EnemyKits.EIN, "pos": Vector2(300.0, -240.0)}],
			[{"kit": EnemyKits.KEBUS, "pos": Vector2(0.0, 0.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(420.0, -230.0)}, {"kit": EnemyKits.NASEN, "pos": Vector2(200.0, -140.0)}, {"kit": EnemyKits.MAZAB, "pos": Vector2(-250.0, 0.0)}],
		],
	},
]
