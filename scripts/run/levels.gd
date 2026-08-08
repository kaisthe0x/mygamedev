class_name Levels
extends RefCounted

## The 5 arena levels of a run, as data. RunManager builds and runs each one.
##
## Per level:
##   name         display name
##   bg           background tint -- gives each level a different LOOK
##   platforms    [[center_x, top_y, width], ...] one-way ledges (the Floor is always there)
##   player_spawn where the player drops in
##   exit_pos     where the exit gate sits; it stays LOCKED until every enemy is dead, then opens
##   start        the first enemy BATCH, present on arrival -- [{kit, pos}, ...] (kit = an EnemyKits.* dict)
##   waves        the remaining batches (FINITE). When the current batch is wiped, the next spawns;
##                after the LAST batch is cleared the level is done and the exit opens. So the total
##                enemies of a level = start + every wave, introduced progressively.
##
## Design the batches by tier (EnemyKits.Tier): open soft (~4-5), ramp up each batch. "3 strong" is
## brutal; prefer "some chip + one strong" early, more strong later. All tunable here, one place.

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
	# ── 1 · The Shallows ── ease-in: chip fodder + a couple strong. Cheap gate (4 blocks). ──
	{
		"name": "The Shallows",
		"bg": Color(0.06, 0.10, 0.13),
		"platforms": [[-300.0, -95.0, 170.0], [40.0, -150.0, 160.0], [330.0, -110.0, 180.0]],
		"player_spawn": Vector2(-470.0, 0.0),
		"exit_pos": Vector2(520.0, -20.0),
		"start": [
			{"kit": EnemyKits.BAGHEL, "pos": Vector2(120.0, 0.0)},
			{"kit": EnemyKits.BAGHEL, "pos": Vector2(-40.0, -150.0)},
			{"kit": EnemyKits.BAGHEL, "pos": Vector2(-150.0, 0.0)},
			{"kit": EnemyKits.KEBUS, "pos": Vector2(330.0, -110.0)},
			{"kit": EnemyKits.KEBUS, "pos": Vector2(-300.0, -95.0)},
		],
		"waves": [
			[{"kit": EnemyKits.BAGHEL, "pos": Vector2(-300.0, -95.0)}, {"kit": EnemyKits.BAGHEL, "pos": Vector2(200.0, 0.0)}, {"kit": EnemyKits.EIN, "pos": Vector2(200.0, -180.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(40.0, -150.0)}],
			[{"kit": EnemyKits.BAGHEL, "pos": Vector2(0.0, 0.0)}, {"kit": EnemyKits.BAGHEL, "pos": Vector2(300.0, 0.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(-300.0, -95.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(330.0, -110.0)}, {"kit": EnemyKits.EIN, "pos": Vector2(-100.0, -180.0)}],
			[{"kit": EnemyKits.KEBUS, "pos": Vector2(-150.0, 0.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(150.0, 0.0)}, {"kit": EnemyKits.MAZAB, "pos": Vector2(330.0, -110.0)}, {"kit": EnemyKits.EIN, "pos": Vector2(0.0, -200.0)}, {"kit": EnemyKits.EIN, "pos": Vector2(250.0, -200.0)}],
		],
	},
	# ── 2 · Redward ── more mid enemies, lob throwers. Gate 5 blocks. ───────────────────────
	{
		"name": "Redward",
		"bg": Color(0.13, 0.05, 0.06),
		"platforms": [[-350.0, -120.0, 150.0], [-40.0, -190.0, 170.0], [280.0, -140.0, 160.0], [430.0, -240.0, 140.0]],
		"player_spawn": Vector2(-470.0, 0.0),
		"exit_pos": Vector2(520.0, -20.0),
		"start": [
			{"kit": EnemyKits.KEBUS, "pos": Vector2(-150.0, 0.0)},
			{"kit": EnemyKits.KEBUS, "pos": Vector2(150.0, 0.0)},
			{"kit": EnemyKits.MAZAB, "pos": Vector2(280.0, -140.0)},
			{"kit": EnemyKits.BAGHEL, "pos": Vector2(20.0, 0.0)},
			{"kit": EnemyKits.BAGHEL, "pos": Vector2(-350.0, -120.0)},
			{"kit": EnemyKits.EIN, "pos": Vector2(0.0, -220.0)},
		],
		"waves": [
			[{"kit": EnemyKits.EIN, "pos": Vector2(-100.0, -200.0)}, {"kit": EnemyKits.EIN, "pos": Vector2(300.0, -220.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(0.0, 0.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(280.0, -140.0)}, {"kit": EnemyKits.BAGHEL, "pos": Vector2(-200.0, 0.0)}],
			[{"kit": EnemyKits.MAZAB, "pos": Vector2(-40.0, -190.0)}, {"kit": EnemyKits.MAZAB, "pos": Vector2(430.0, -240.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(-350.0, -120.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(200.0, 0.0)}, {"kit": EnemyKits.BAGHEL, "pos": Vector2(400.0, 0.0)}],
			[{"kit": EnemyKits.NASEN, "pos": Vector2(-40.0, -190.0)}, {"kit": EnemyKits.MAZAB, "pos": Vector2(280.0, -140.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(-150.0, 0.0)}, {"kit": EnemyKits.EIN, "pos": Vector2(100.0, -240.0)}, {"kit": EnemyKits.EIN, "pos": Vector2(-250.0, -160.0)}],
		],
	},
	# ── 3 · The Gullet ── nasen sleepers guarding, tighter. Gate 6 blocks. ──────────────────
	{
		"name": "The Gullet",
		"bg": Color(0.09, 0.05, 0.12),
		"platforms": [[-280.0, -110.0, 160.0], [80.0, -160.0, 200.0], [360.0, -120.0, 150.0], [-120.0, -250.0, 150.0]],
		"player_spawn": Vector2(-470.0, 0.0),
		"exit_pos": Vector2(520.0, -20.0),
		"start": [
			{"kit": EnemyKits.NASEN, "pos": Vector2(80.0, -160.0)},
			{"kit": EnemyKits.KEBUS, "pos": Vector2(-200.0, 0.0)},
			{"kit": EnemyKits.KEBUS, "pos": Vector2(200.0, 0.0)},
			{"kit": EnemyKits.MAZAB, "pos": Vector2(300.0, 0.0)},
			{"kit": EnemyKits.BAGHEL, "pos": Vector2(-100.0, 0.0)},
			{"kit": EnemyKits.EIN, "pos": Vector2(0.0, -220.0)},
		],
		"waves": [
			[{"kit": EnemyKits.EIN, "pos": Vector2(0.0, -220.0)}, {"kit": EnemyKits.EIN, "pos": Vector2(-200.0, -180.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(-280.0, -110.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(360.0, -120.0)}, {"kit": EnemyKits.BAGHEL, "pos": Vector2(200.0, 0.0)}],
			[{"kit": EnemyKits.NASEN, "pos": Vector2(-120.0, -250.0)}, {"kit": EnemyKits.NASEN, "pos": Vector2(80.0, -160.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(360.0, -120.0)}, {"kit": EnemyKits.MAZAB, "pos": Vector2(-100.0, 0.0)}, {"kit": EnemyKits.MAZAB, "pos": Vector2(250.0, 0.0)}],
			[{"kit": EnemyKits.KEBUS, "pos": Vector2(-280.0, -110.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(80.0, -160.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(300.0, 0.0)}, {"kit": EnemyKits.NASEN, "pos": Vector2(-120.0, -250.0)}, {"kit": EnemyKits.EIN, "pos": Vector2(0.0, -230.0)}, {"kit": EnemyKits.EIN, "pos": Vector2(200.0, -200.0)}],
		],
	},
	# ── 4 · Ossuary ── strong-heavy, orbs everywhere. Gate 7 blocks. ────────────────────────
	{
		"name": "Ossuary",
		"bg": Color(0.05, 0.11, 0.08),
		"platforms": [[-330.0, -100.0, 150.0], [-60.0, -170.0, 160.0], [220.0, -130.0, 170.0], [420.0, -220.0, 150.0], [60.0, -270.0, 160.0]],
		"player_spawn": Vector2(-470.0, 0.0),
		"exit_pos": Vector2(520.0, -20.0),
		"start": [
			{"kit": EnemyKits.KEBUS, "pos": Vector2(-180.0, 0.0)},
			{"kit": EnemyKits.KEBUS, "pos": Vector2(120.0, 0.0)},
			{"kit": EnemyKits.NASEN, "pos": Vector2(60.0, -270.0)},
			{"kit": EnemyKits.EIN, "pos": Vector2(150.0, -200.0)},
			{"kit": EnemyKits.EIN, "pos": Vector2(-100.0, -180.0)},
			{"kit": EnemyKits.MAZAB, "pos": Vector2(300.0, 0.0)},
			{"kit": EnemyKits.MAZAB, "pos": Vector2(-330.0, -100.0)},
		],
		"waves": [
			[{"kit": EnemyKits.KEBUS, "pos": Vector2(-330.0, -100.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(220.0, -130.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(0.0, 0.0)}, {"kit": EnemyKits.EIN, "pos": Vector2(0.0, -230.0)}, {"kit": EnemyKits.EIN, "pos": Vector2(300.0, -230.0)}, {"kit": EnemyKits.MAZAB, "pos": Vector2(-200.0, 0.0)}],
			[{"kit": EnemyKits.NASEN, "pos": Vector2(-60.0, -170.0)}, {"kit": EnemyKits.NASEN, "pos": Vector2(60.0, -270.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(420.0, -220.0)}, {"kit": EnemyKits.MAZAB, "pos": Vector2(-200.0, 0.0)}, {"kit": EnemyKits.EIN, "pos": Vector2(250.0, -250.0)}, {"kit": EnemyKits.EIN, "pos": Vector2(-150.0, -200.0)}],
			[{"kit": EnemyKits.KEBUS, "pos": Vector2(-330.0, -100.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(-60.0, -170.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(220.0, -130.0)}, {"kit": EnemyKits.NASEN, "pos": Vector2(60.0, -270.0)}, {"kit": EnemyKits.MAZAB, "pos": Vector2(300.0, 0.0)}, {"kit": EnemyKits.MAZAB, "pos": Vector2(-180.0, 0.0)}],
		],
	},
	# ── 5 · Way of All Flesh ── the culmination: everything, expensive gate (8 blocks). ─────
	{
		"name": "Way of All Flesh",
		"bg": Color(0.13, 0.08, 0.03),
		"platforms": [[-350.0, -110.0, 150.0], [-80.0, -180.0, 170.0], [200.0, -140.0, 160.0], [420.0, -230.0, 150.0], [-200.0, -260.0, 150.0]],
		"player_spawn": Vector2(-470.0, 0.0),
		"exit_pos": Vector2(520.0, -20.0),
		"start": [
			{"kit": EnemyKits.NASEN, "pos": Vector2(-200.0, -260.0)},
			{"kit": EnemyKits.KEBUS, "pos": Vector2(-150.0, 0.0)},
			{"kit": EnemyKits.KEBUS, "pos": Vector2(200.0, -140.0)},
			{"kit": EnemyKits.KEBUS, "pos": Vector2(80.0, 0.0)},
			{"kit": EnemyKits.MAZAB, "pos": Vector2(320.0, 0.0)},
			{"kit": EnemyKits.EIN, "pos": Vector2(0.0, -220.0)},
			{"kit": EnemyKits.EIN, "pos": Vector2(-300.0, -160.0)},
		],
		"waves": [
			[{"kit": EnemyKits.KEBUS, "pos": Vector2(-350.0, -110.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(200.0, -140.0)}, {"kit": EnemyKits.NASEN, "pos": Vector2(-80.0, -180.0)}, {"kit": EnemyKits.EIN, "pos": Vector2(100.0, -240.0)}, {"kit": EnemyKits.EIN, "pos": Vector2(300.0, -240.0)}, {"kit": EnemyKits.MAZAB, "pos": Vector2(-250.0, 0.0)}],
			[{"kit": EnemyKits.KEBUS, "pos": Vector2(0.0, 0.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(420.0, -230.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(-200.0, 0.0)}, {"kit": EnemyKits.NASEN, "pos": Vector2(200.0, -140.0)}, {"kit": EnemyKits.MAZAB, "pos": Vector2(-350.0, -110.0)}, {"kit": EnemyKits.MAZAB, "pos": Vector2(250.0, 0.0)}],
			[{"kit": EnemyKits.NASEN, "pos": Vector2(-200.0, -260.0)}, {"kit": EnemyKits.NASEN, "pos": Vector2(-80.0, -180.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(-350.0, -110.0)}, {"kit": EnemyKits.KEBUS, "pos": Vector2(200.0, -140.0)}, {"kit": EnemyKits.MAZAB, "pos": Vector2(320.0, 0.0)}, {"kit": EnemyKits.EIN, "pos": Vector2(0.0, -240.0)}, {"kit": EnemyKits.EIN, "pos": Vector2(-300.0, -200.0)}],
		],
	},
]
