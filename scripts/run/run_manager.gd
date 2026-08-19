class_name RunManager
extends Node2D

## The roguelite run driver + the level.tscn root. Builds each arena level from Levels data,
## drops in start enemies, refills finite escalating BATCHES as the arena is cleared, banks Ruh on
## kills, opens the exit once every batch is dead, runs the reward pick, advances levels, and restarts the whole
## run on death. Also owns the player spawn, camera follow, and death/spawn flair. See
## docs/game-design.md and scripts/run/README.md.

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const SPAWN_FX := preload("res://vfx/spawn/enemy_spawn.tscn")
## How far to LIFT the spawn puff off the enemy's feet (its spawn `pos` is feet-anchored, so at 0 the
## puff sits on the ground). More negative = higher up the body. Tune this one number to taste.
const SPAWN_FX_OFFSET := Vector2(0, -22)
const REWARDS_OFFERED := 3
## Local position a floating damage number is parented at above an enemy's origin (feet) -- upper
## body-ish. It rides along with the enemy from here; nudge it if a taller/shorter enemy reads off.
const DAMAGE_NUMBER_OFFSET := Vector2(0, -42)
## Fall below this (well under the floor) -> reposition to the level spawn (NOT a life loss).
const DEATH_Y := 320.0

## ── Which character you play (in-game switching is gone; pick here). ────────────────
const START_CHARACTER := "khalid"

# Camera follow (speed-adaptive) — carried over from the old switcher.
const CAM_FOLLOW_BASE := 0.002
const CAM_TIGHTEN_START := 600.0
const CAM_TIGHTEN_FULL := 1200.0
const CAM_TIGHT_K := 0.9
const CAM_ZOOM_NORMAL := Vector2(1.5, 1.5)
const CAM_ZOOM_DEATH := Vector2(3.0, 3.0) ## punch in hard on the death -- the dramatic close-up
const CAM_ZOOM_SPAWN := Vector2(2, 2)
const DEATH_HOLD := 0.7
# Death cinematic: the world blacks out behind Khalid while his death anim plays on the void, then clears
# on respawn. He's lifted above a full-screen black overlay (world z <= 0, so ANYTHING below DEATH_OVERLAY_Z
# is hidden; only Khalid at DEATH_PLAYER_Z stays lit).
const DEATH_PLAYER_Z := 500
const DEATH_OVERLAY_Z := 400
const DEATH_FADE_IN := 0.55  ## seconds the world takes to fall to black
const DEATH_FADE_OUT := 0.6  ## seconds the black takes to clear, revealing the fresh spawn
const DEATH_FREEZE := 0.5    ## hold on the FIRST death frame this long (while zooming/blacking) before it plays out
## "You did it!" clear beat: a brief slow-motion the moment the LAST REQUIRED enemy falls and the
## exit opens (optional enemies never trigger it). Slam time down, hold, ramp back to normal.
const CLEAR_SLOWMO_SCALE := 0.3 ## time scale at the peak of the beat
const CLEAR_SLOWMO_HOLD := 0.7 ## REAL seconds held slow before ramping back
const CLEAR_SLOWMO_RAMP := 0.55 ## REAL seconds ramping time back to 1.0
## The "soul" that floats from a dead enemy to the player on a Ruh-granting kill (see _spawn_ruh_orb).
const RUH_ORB := preload("res://vfx/character/khalid/ruh_orb/ruh_orb.tscn")

@export var player_path: NodePath = ^"Player"

@onready var _player: Player = get_node_or_null(player_path) as Player
@onready var _camera: Camera2D = get_node_or_null("Camera2D") as Camera2D

var _level_index := 0
var _cleared_this_run := 0 ## levels cleared (exits paid) so far this run -> HUD + the SaveData record
var _wave_index := 0 ## next enemy BATCH to spawn on clear (finite -- past the last, none)
var _alive := 0 ## REQUIRED enemies alive (optional ones don't count); 0 spawns next batch / clears
var _cleared := false ## true once every batch is spawned AND dead -> the exit opens
var _door_type := "health" ## this level's reward-door type, rolled in _build_level
var _transitioning := false ## true while the reward/level-change is mid-flight

## The reward-door types one is rolled from per level (more coming: money, ally meeting point...).
const DOOR_TYPES := ["health", "athletic", "attack", "special"]
var _content: Node2D ## per-level nodes (platforms, gate, enemies); freed on level change
var _gate: ExitGate
var _bg: ColorRect
var _player_spawn := Vector2.ZERO

# death / camera flair state
var _dead_prev := false
var _death_hold := 0.0
var _spawning := false
var _cam_tween: Tween
var _death_overlay: Polygon2D  ## the black world-cover during the death cinematic
var _death_tune_left := 0.0    ## seconds left of the death TUNE -- respawn waits for it to finish


func _ready() -> void:
	Engine.time_scale = 1.0 # safety: never inherit a slowed clock (e.g. from a clear-beat mid-reload)
	_add_glow()
	_build_bg()
	_build_floor()
	if _player != null:
		_player.set_character(START_CHARACTER)
	_build_level(0)
	if _player != null:
		_player.spawn()
	if _camera != null:
		Nodes.place_at(_camera, _player_spawn + Vector2(0, -30))
	_choose_attack() # run start: pick the attack that's locked in for this run
	# (level music is started from _build_level -- fresh from the top on every level, incl. the first)


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	# The exit is locked until the arena is cleared, then it opens.
	if _gate != null and is_instance_valid(_gate):
		_gate.reflect(_cleared)

	if _player.is_dead():
		_handle_death(delta)
		return
	if _player.get_state() == Player.State.SPAWN:
		_handle_spawn(delta)
		return
	if _player.global_position.y > DEATH_Y: # fell off -> reposition, no life lost
		Nodes.place_at(_player, _player_spawn)
		if _camera != null:
			Nodes.place_at(_camera, _player_spawn + Vector2(0, -30))
		return
	if _spawning:
		_spawning = false
		_zoom_to(CAM_ZOOM_NORMAL, 0.4)
	_follow_camera(delta)


# --- level building ---------------------------------------------------------

func _build_level(index: int) -> void:
	Music.play("level") # every level starts its music FRESH from the top (crossfades out the rest bed)
	_level_index = clampi(index, 0, Levels.count() - 1)
	_wave_index = 0
	_alive = 0
	_cleared = false
	_transitioning = false
	if _content != null and is_instance_valid(_content):
		_content.queue_free()
	_content = Node2D.new()
	add_child(_content)

	var lv := Levels.get_level(_level_index)
	# Opaque tint normally; a translucent mood tint when a background image is showing under it.
	var tint: Color = lv["bg"]
	if Terrain.background_texture() != null:
		tint.a = Terrain.BACKGROUND.get("tint_alpha", 0.4)
	_bg.color = tint
	_player_spawn = lv["player_spawn"]

	_place_trees() # background tree props (behind the terrain), varied per level
	for p in lv["platforms"]:
		_build_platform(p[0], p[1], p[2], 14.0)
	# Launch orbs: dash into one and it flings Khalid up + forward (see LaunchOrb / Player State.LAUNCH),
	# authored per level as world positions (above/between platforms). Optional key -> default none.
	for pos: Vector2 in lv.get("orbs", []):
		var orb := LaunchOrb.new()
		orb.position = pos
		_content.add_child(orb)

	_door_type = DOOR_TYPES[randi() % DOOR_TYPES.size()] # one random reward door per level
	_gate = ExitGate.new()
	_gate.setup(_door_type)
	_gate.position = lv["exit_pos"]
	_gate.touched.connect(_on_gate_touched)
	_content.add_child(_gate)

	_spawn_group(lv["start"], false) # start enemies just exist -- no spawn puff
	if _alive <= 0: # start batch had ONLY optional enemies -> advance to a real one (see _advance_batch)
		_advance_batch.call_deferred()

	if _player != null:
		Nodes.place_at(_player, _player_spawn)


const TERRAIN_Z := -5 ## terrain tiles: behind the player/enemies (z 0)
const PLANT_Z := -4 ## plants sit just in front of the terrain, still behind actors
const TREE_Z := -15 ## trees: background props, behind the terrain

func _build_platform(center_x: float, top_y: float, width: float, height: float) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Combat.L_WORLD
	body.collision_mask = 0
	body.position = Vector2(center_x, top_y)
	body.add_to_group("oneway_platform")
	var col := Shapes.make_box(Vector2(width, height), Vector2(0, height / 2.0))
	col.one_way_collision = true
	body.add_child(col)
	# Visual only (collision is the thin collider above): one row of surface tiles, top-aligned,
	# hanging a full 32px below for depth. Plus a plant or two along the ledge.
	_paint_surface(body, Vector2(-width / 2.0, 0), width, 0)
	_scatter_plants(body, Vector2(-width / 2.0, 0), width, 0.35)
	_content.add_child(body)


# --- terrain painting (visual skin over the colliders) ----------------------

## Stamp 32px tiles across a surface `width` px wide from local `origin` (its TOP-LEFT). The top
## row is surface tiles; `fill_rows` extra rows below use body tiles (depth / ground mass). Visual
## only. Exact fit: the last column is a clipped partial so terrain never overhangs the ledge.
## Falls back to a flat ColorRect if the sheet is missing.
func _paint_surface(parent: Node, origin: Vector2, width: float, fill_rows: int) -> void:
	var sheet := Terrain.sheet()
	if sheet == null:
		var r := ColorRect.new()
		r.color = Terrain.PLATFORM_FALLBACK
		r.position = origin
		r.size = Vector2(width, maxf(Terrain.TILE, (fill_rows + 1) * Terrain.TILE))
		r.z_index = TERRAIN_Z
		parent.add_child(r)
		return
	var t := Terrain.TILE
	var full := int(width / t)
	var rem := width - full * t
	var cols := full + (1 if rem > 2.0 else 0)
	for row in fill_rows + 1:
		var cells: Array[Vector2i] = Terrain.TOP_CELLS if row == 0 else Terrain.FILL_CELLS
		for col in cols:
			var cell: Vector2i = cells[(col + row) % cells.size()] # vary the art across the run
			var w: float = t if col < full else rem
			var spr := Sprite2D.new()
			var at := Terrain.cell_texture(sheet, cell)
			if w < t:
				at.region = Rect2(at.region.position, Vector2(w, t)) # clip the partial edge column
			spr.texture = at
			spr.centered = false
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.position = origin + Vector2(col * t, row * t)
			spr.z_index = TERRAIN_Z
			parent.add_child(spr)


## Sprinkle ground plants along a surface top (`origin` top-left, `width` wide). `density` ~ plants
## per tile. Deterministic-ish variety; mushrooms are rarer. No-op without the plants sheet.
func _scatter_plants(parent: Node, origin: Vector2, width: float, density: float) -> void:
	var ps := Terrain.plants_sheet()
	if ps == null:
		return
	var slots := int(width / Terrain.TILE)
	for i in slots:
		if randf() > density:
			continue
		var cell: Vector2i = Terrain.MUSHROOM_CELL if randf() < 0.2 \
			else Terrain.PLANT_CELLS[randi() % Terrain.PLANT_CELLS.size()]
		var spr := Sprite2D.new()
		spr.texture = Terrain.cell_texture(ps, cell)
		spr.centered = false
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# bottom of the plant sits on the surface top (origin.y); jitter x within its tile slot.
		spr.position = origin + Vector2(i * Terrain.TILE + randf() * 6.0, -Terrain.TILE)
		spr.z_index = PLANT_Z
		parent.add_child(spr)


## Place a couple of tree props in the background, standing on the floor. Varied per level so the
## worlds don't look identical. No-op without tree art.
func _place_trees() -> void:
	if Terrain.tree_texture(0) == null:
		return
	var spots := [-360.0, 240.0, -80.0]
	for i in mini(2, spots.size()):
		var tex := Terrain.tree_texture(_level_index + i)
		if tex == null:
			continue
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.centered = false
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.position = Vector2(spots[i] - tex.get_width() / 2.0, -tex.get_height()) # base on the floor (y=0)
		spr.z_index = TREE_Z
		_content.add_child(spr)


# --- spawning + waves -------------------------------------------------------

## Spawn a group of {kit, pos} specs. `with_fx` fires the materialize puff at each spot (waves
## use it; start enemies don't). Each enemy's death is tracked toward clearing the arena.
func _spawn_group(specs: Array, with_fx: bool) -> void:
	for spec: Dictionary in specs:
		var pos: Vector2 = spec["pos"]
		if with_fx:
			_spawn_fx(pos)
		var enemy := _spawn_enemy(spec["kit"], pos)
		if enemy != null:
			enemy.died.connect(_on_enemy_died.bind(enemy))
			enemy.damaged.connect(_on_enemy_damaged.bind(enemy)) # feeds player passive on_hit_dealt (Leech, on-hit procs)
			if not enemy.optional:
				_alive += 1 # only required enemies gate the level clear


func _spawn_enemy(kit: Dictionary, pos: Vector2) -> Enemy:
	var scene: PackedScene = load(kit["scene"]) if kit.has("scene") else ENEMY_SCENE
	var enemy: Enemy = scene.instantiate()
	for key in kit:
		if key in ["scene", "tier", "pos"]:
			continue
		if key == "id":
			enemy.enemy_id = kit[key]
		else:
			enemy.set(key, kit[key])
	enemy.position = pos # before add_child so Enemy._ready anchors patrol on the real spot
	_content.add_child(enemy)
	return enemy


func _spawn_fx(pos: Vector2) -> void:
	var fx := SPAWN_FX.instantiate()
	_content.add_child(fx)
	Nodes.place_at(fx, pos + SPAWN_FX_OFFSET) # lift off the feet (SPAWN_FX_OFFSET) so it reads on the body
	Sfx.play_at("enemy_spawn", pos) # the spawn puff's cue -- positional, at the spawn point
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if is_instance_valid(fx):
			fx.queue_free())


## An enemy died: advance the batch or CLEAR the arena. (Ruh is earned by landing HITS now -- see
## _on_enemy_damaged -- not by kills, so nothing to bank here.)
func _on_enemy_died(enemy: Enemy) -> void:
	if enemy.optional:
		return # optional enemies don't gate the level clear
	_alive -= 1
	if _alive <= 0 and not _transitioning and not _cleared:
		# This fires INSIDE a physics flush (a hit or the vortex's DoT tick killed the enemy).
		# Spawning the next batch builds new bodies/hurtboxes, and their collision/monitoring state
		# can't change mid-flush ("Can't change state while flushing queries"). Defer to next idle.
		_advance_batch.call_deferred()


## Pop a glowing soul off the dead enemy and send it homing to the player -- the visual receipt for
## the Ruh just banked. Added to the world (this node is the level root) so it outlives the enemy
## freeing, and self-frees on arrival. Pure VFX (no Area2D), so it's safe to spawn mid-physics-flush.
func _spawn_ruh_orb(at: Vector2, completed_charge: bool) -> void:
	if _player == null:
		return
	var orb := RUH_ORB.instantiate() as RuhOrb
	VfxPalette.recolor_tree(orb) # honour the run's power-colour picks like every other character effect
	add_child(orb)
	Nodes.place_at(orb, at + Vector2(0, -18)) # lift off the body's centre, not the feet
	orb.launch(_player, completed_charge)


## Spawn the next batch, or clear the level if none remain. Deferred from _on_enemy_died so enemy
## bodies are built outside the physics flush. Re-checks state (it may have changed since queued).
func _advance_batch() -> void:
	if _alive > 0 or _transitioning or _cleared:
		return
	if not _spawn_next_wave():
		_cleared = true # no more batches -> level cleared; the exit opens (see _physics_process)
		_celebrate_clear() # brief slow-mo "you did it" beat -- ONLY the last required kill reaches here
		Sfx.play("level_cleared") # the clear cue
		Music.play("base_rest") # swap to the calm rest bed; it crossfades back out when the next level builds
	elif _alive <= 0:
		_advance_batch.call_deferred() # that batch had only optional enemies -> straight to the next


## The "you did it!" clear beat: slam time down, hold, then ramp back to normal. The tween is set to
## IGNORE time_scale so it advances in REAL time (otherwise slowing time would slow its own ramp).
## time_scale is reset to 1.0 on _ready / _restart_run so a slowed frame can never leak into a run.
func _celebrate_clear() -> void:
	Engine.time_scale = CLEAR_SLOWMO_SCALE
	# tween_method (a function call), NOT tween_property on the Engine singleton -- the latter
	# silently does nothing. set_ignore_time_scale so the ramp runs in real, not slowed, time.
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_interval(CLEAR_SLOWMO_HOLD)
	t.tween_method(_set_time_scale, CLEAR_SLOWMO_SCALE, 1.0, CLEAR_SLOWMO_RAMP) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_time_scale(v: float) -> void:
	Engine.time_scale = v


## Spawn the next enemy batch if one remains. Returns false when they're all spent (finite now --
## no infinite refill), which is how a level ends: clear every batch and the exit opens.
## When the player deals damage: feed their passives' on_hit_dealt hook (Leech lifesteal, on-hit procs)
## and pop a floating damage number over the enemy (a FloatingText label, parented to the enemy).
func _on_enemy_damaged(amount: float, source: Node, enemy: Enemy) -> void:
	if _player != null and source == _player:
		_player.notify_hit_dealt(amount, enemy)
		# Ruh is charged by landing HITS now (not kills) -- except the special's own hits, so a special
		# can't partly pay for itself. Only spawn the soul-orb when a hit COMPLETES a fresh charge (so it
		# isn't a stream of orbs on every hit); the meter itself fills on every qualifying hit.
		if amount > 0.0 and not enemy.last_hit_from_special and _player.gain_ruh_on_hit():
			_spawn_ruh_orb(enemy.global_position, true)
		var kind := "damage_special" if enemy.last_hit_from_special else "damage"
		FloatingText.emit(kind, enemy, DAMAGE_NUMBER_OFFSET, str(roundi(amount)), amount)


func _spawn_next_wave() -> bool:
	var waves: Array = Levels.get_level(_level_index)["waves"]
	if _wave_index >= waves.size():
		return false
	_spawn_group(waves[_wave_index], true)
	_wave_index += 1
	return true


# --- exit gate -> reward -> next level --------------------------------------

func _on_gate_touched() -> void:
	# The door only works once the arena is cleared (all enemies dead). No toll.
	if _transitioning or _player == null or not _cleared:
		return
	_transitioning = true
	_offer_reward()


func _offer_reward() -> void:
	var ui := RewardUI.new()
	add_child(ui)
	ui.chosen.connect(_on_reward_chosen)
	ui.open(Rewards.offer_for(_door_type, _player, REWARDS_OFFERED), _door_type)


func _on_reward_chosen(id: String) -> void:
	Rewards.apply(id, _player)
	# Paying the exit + taking the reward = this level is CLEARED. Count it (drives the HUD +
	# feeds the best-ever record on run end).
	_cleared_this_run += 1
	SaveData.current_cleared = _cleared_this_run
	if _level_index >= Levels.count() - 1:
		_restart_run() # run complete -> loop back to level 1 (template; a win screen later)
	else:
		_build_level(_level_index + 1) # carry life forward -- no reset


## Wipe the run and start over at level 1 (death or completion). Resets buffs + refills to
## 100 HP / empty Ruh via Player.begin_run.
func _restart_run() -> void:
	Engine.time_scale = 1.0 # never carry a clear-beat slowdown into the next run
	# The run is ending (death or completion): bank its cleared count into the record, then reset.
	SaveData.report_run(_cleared_this_run)
	_cleared_this_run = 0
	SaveData.current_cleared = 0
	_dead_prev = false
	_build_level(0)
	if _player != null:
		_player.begin_run()
		_choose_attack() # every fresh run: re-pick the run-locked attack
	_end_death_cinematic() # fade the black out over the fresh spawn, then drop his z back to normal


## Open the run-start attack picker; equip whatever the player chooses (locked for the run).
func _choose_attack() -> void:
	if _player == null:
		return
	var ui := AttackSelect.new()
	add_child(ui)
	ui.chosen.connect(func(id: String) -> void: _player.equip("attack", id))
	ui.open(_player.character)


# --- death / spawn / camera flair (from the old switcher) --------------------

func _handle_death(delta: float) -> void:
	if not _dead_prev:
		_dead_prev = true
		_death_hold = DEATH_HOLD
		_zoom_to(CAM_ZOOM_DEATH, 0.45)
		_begin_death_cinematic() # black out the world behind him as the death anim plays
	_death_tune_left = maxf(_death_tune_left - delta, 0.0)
	if _camera != null:
		_camera.global_position = _camera.global_position.lerp(_player.global_position + Vector2(0, -18), 0.12)
	# Respawn only once BOTH the collapse anim AND the whole death tune have played out.
	if _player.death_complete() and _death_tune_left <= 0.0:
		_death_hold -= delta
		if _death_hold <= 0.0:
			_restart_run() # DEATH = whole run over, start from scratch (roguelite)


## Dramatic death: lift Khalid above everything and black out the world behind him, so his death anim
## plays on a void. A huge black quad parented to the CAMERA (so it covers the view through the zoom) sits
## at DEATH_OVERLAY_Z -- above every world node (z <= 0), below Khalid (DEATH_PLAYER_Z). Cleared by
## _end_death_cinematic on respawn. The camera zoom is handled in _handle_death.
func _begin_death_cinematic() -> void:
	# The death SFX is a TUNE, not a blip -- hold the whole cinematic until it finishes (respawn waits on
	# _death_tune_left in _handle_death). Duck the level bed out so the tune plays clear; it fades back in
	# when _build_level restarts it on respawn. (Player._die plays the tune itself, on the SFX bus.)
	_death_tune_left = _death_tune_length()
	Music.stop()
	if _player != null:
		_player.z_index = DEATH_PLAYER_Z
		_player.z_as_relative = false
	if _death_overlay != null and is_instance_valid(_death_overlay):
		_death_overlay.queue_free()
	_death_overlay = Polygon2D.new()
	var s := 20000.0 # far larger than any view, so it covers the screen at any zoom/pan
	_death_overlay.polygon = PackedVector2Array([Vector2(-s, -s), Vector2(s, -s), Vector2(s, s), Vector2(-s, s)])
	_death_overlay.color = Color.BLACK
	_death_overlay.modulate = Color(1, 1, 1, 0.0) # fades in via modulate alpha
	_death_overlay.z_index = DEATH_OVERLAY_Z
	_death_overlay.z_as_relative = false
	var host: Node = self # parent to the camera so it follows the view (fall back to the world root)
	if _camera != null:
		host = _camera
	host.add_child(_death_overlay)
	var tw := create_tween()
	tw.tween_property(_death_overlay, "modulate:a", 1.0, DEATH_FADE_IN)
	# The death anim is paused on frame 0 (Player._enter(State.DEATH)); let the zoom + black settle, then
	# release it so the collapse plays out on the void.
	get_tree().create_timer(DEATH_FREEZE).timeout.connect(func() -> void:
		if _player != null and _player.is_dead():
			_player.release_death())


## Clear the death void: fade the black out to reveal the fresh spawn, then drop Khalid's z to normal once
## it's gone (so the spawn plays lit-on-black first, then the world returns). No-op if no cinematic ran.
func _end_death_cinematic() -> void:
	if _death_overlay == null or not is_instance_valid(_death_overlay):
		_reset_player_z()
		return
	var ov := _death_overlay
	_death_overlay = null
	var tw := create_tween()
	tw.tween_property(ov, "modulate:a", 0.0, DEATH_FADE_OUT)
	tw.tween_callback(func() -> void:
		if is_instance_valid(ov):
			ov.queue_free()
		_reset_player_z())


func _reset_player_z() -> void:
	if _player != null:
		_player.z_index = 0
		_player.z_as_relative = true


## Length (seconds) of the death tune, so the respawn can wait it out. 0 if the file is missing.
func _death_tune_length() -> float:
	var path: String = SfxCharacters.CUES.get("player_death", "")
	if path == "" or not ResourceLoader.exists(path):
		return 0.0
	var s := load(path) as AudioStream
	return s.get_length() if s != null else 0.0


func _handle_spawn(delta: float) -> void:
	if not _spawning:
		_spawning = true
		_zoom_to(CAM_ZOOM_SPAWN, 0.35)
	if _camera != null:
		_camera.global_position = _camera.global_position.lerp(_player.global_position + Vector2(0, -18), 0.12)


func _follow_camera(delta: float) -> void:
	if _camera == null:
		return
	var target := Vector2(_player.global_position.x, _player.global_position.y - 30.0) \
		+ _player.velocity * delta
	var vy := absf(_player.velocity.y)
	var t := clampf((vy - CAM_TIGHTEN_START) / (CAM_TIGHTEN_FULL - CAM_TIGHTEN_START), 0.0, 1.0)
	var k := lerpf(1.0 - pow(CAM_FOLLOW_BASE, delta), CAM_TIGHT_K, t)
	_camera.global_position = _camera.global_position.lerp(target, k)


func _zoom_to(z: Vector2, dur: float) -> void:
	if _camera == null:
		return
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	_cam_tween = _camera.create_tween()
	_cam_tween.tween_property(_camera, "zoom", z, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# --- scaffolding ------------------------------------------------------------

func _build_bg() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -100 # behind everything
	add_child(layer)
	# Optional background IMAGE, stretched to fill, behind the per-level colour tint. Drop
	# assets/terrain/background.png to use it; without it, the tint is just opaque (as before).
	var bg_tex := Terrain.background_texture()
	if bg_tex != null:
		var img := TextureRect.new()
		img.texture = bg_tex
		img.set_anchors_preset(Control.PRESET_FULL_RECT)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_SCALE
		img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(img)
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_bg) # per-level tint on top (translucent over an image -- see _build_level)


## Skin the floor (from level.tscn's Floor): hide the placeholder ColorRect and tile the surface,
## with a couple of fill rows below for a solid ground mass, plus plants along the top.
func _build_floor() -> void:
	var floor_body := get_node_or_null("Floor")
	if floor_body == null:
		return
	var shape := floor_body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape == null or not (shape.shape is RectangleShape2D):
		return
	var size: Vector2 = (shape.shape as RectangleShape2D).size
	var top_left := shape.position - size / 2.0 # collider centre -> top-left
	var old := floor_body.get_node_or_null("ColorRect")
	if old != null:
		old.visible = false # keep the node (scene-owned) but hand the look to the skin
	_paint_surface(floor_body, top_left, size.x, 2) # surface + 2 fill rows of ground
	_scatter_plants(floor_body, top_left, size.x, 0.4)


func _add_glow() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_respawn"):
		_build_level(_level_index) # rebuild the current level fresh
		return
	if _player == null:
		return
	if event.is_action_pressed("debug_damage"):
		_player.take_damage(12.0)
	elif event.is_action_pressed("debug_heal"):
		_player.ruh += Player.RUH_PER_BLOCK # +1 Ruh charge (test the surge meter)
