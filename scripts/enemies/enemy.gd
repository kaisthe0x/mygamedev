class_name Enemy
extends Combatant

## Reusable ground enemy. Shares the character sprite pipeline (idle / patrol /
## attack / attack_projectile) but each enemy only needs the animations it has: the
## strike (`attack`) and projectile (`attack_projectile`) are enabled automatically from
## whichever attack animations exist in its SpriteFrames, so an enemy with just one attack
## (or no patrol, like a stationary sleeper) works with no changes.
##
## Behaviour: patrol between its spawn point and spawn+patrol_distance, pausing
## to idle at each end; if the player comes within ranged_range it attacks
## (melee when very close, ranged otherwise). It carries its own hurtbox, melee
## hitbox, floating health bar and hit-flash. Bosses get their own scene/script
## instead of shoehorning extra move-sets in here.
##
## Everything visual/physical is built in code, so an enemy is just this script
## configured via exports (or subclassed) -- no scene to keep in sync.

const FRAMES_PATH := "res://resources/enemies/%s.tres"
## Shared accent-glow material for every enemy sprite (dark body + a blooming bright accent). Tweak the
## look on this resource: res://resources/enemy_glow.tres -> vfx/shaders/enemy_glow.gdshader.
const GLOW_MATERIAL := "res://resources/enemy_glow.tres"

## Emitted once when this enemy dies, carrying the lahm it pays out (its HP value). The run
## manager awards it to the player and counts the kill toward clearing the wave.
signal died ## this enemy died -- RunManager counts it toward clearing the arena (wave refill)
## Emitted every time this enemy takes damage: (actual HP removed, the attacker). RunManager
## pays the player lahm = damage they dealt (the harvest is per-hit now, not a lump on kill).
signal damaged(amount: float, source: Node)

@export var enemy_id: String = "kebus"
@export var display_name: String = "Kebus"
## Optional enemies do NOT have to be killed to clear the level -- the exit opens once every
## REQUIRED enemy is dead, even if optional ones are still roaming. Set per-kit (see EnemyKits).
@export var optional := false
## This enemy's attack STRIKE TYPE (configs/strike_spec.gd: aoe / delayed_projectile / blast / ...) --
## the shared key its SFX + emitters use (`<id>.<attack_type>`). Empty = fall back to the coarse
## melee/projectile split from the attack anim (fine for a plain melee or straight shot; set it for a
## typed attack like Matat's `aoe` or Mazab's `delayed_projectile`). Set per-kit (see EnemyKits).
@export var attack_type := ""

@export_group("Stats")
@export var max_health: float = 60.0
@export var gravity: float = 900.0
## Collider full-sizes, so differently-proportioned enemies fit their sprite. The
## body is what stands on the floor; the hurtbox is what attacks land on (also
## used for the contact-damage box). Each sits centred, resting on the feet.
@export var body_size := Vector2(18, 30)
@export var hurtbox_size := Vector2(20, 34)

@export_group("Patrol")
@export var move_speed: float = 40.0
## How far it patrols from its spawn point before turning back.
@export var patrol_distance: float = 90.0
@export var idle_time_min: float = 2.0
@export var idle_time_max: float = 3.0
## Won't step past an edge: how far ahead of the feet ground is probed for.
@export var edge_check_x: float = 14.0
## Optional resting-idle flourish: while idling, loop emitted frames
## [idle_loop_from..idle_loop_to] (e.g. a back-scratch) for idle_loop_time
## seconds, then play one full idle cycle, and repeat. Disabled when to <= from.
@export var idle_loop_from := 0
@export var idle_loop_to := 0
@export var idle_loop_time := 2.5

@export_group("Combat ranges")
## Player within this horizontal distance -> melee. Small = must be adjacent.
@export var melee_range: float = 30.0
## Player within this -> ranged attack (when melee doesn't apply).
@export var ranged_range: float = 300.0
## Max vertical gap (px, feet-to-feet) for an attack to trigger. Both boxes are
## horizontal, so a player on a different platform can never be hit -- without this the
## enemy still swings/fires at someone directly below and just looks silly. Keep it under
## the platform spacing so "roughly the same height" means "same ledge / jumping past".
@export var attack_align_y: float = 40.0
@export var attack_cooldown: float = 1.1
## When true the melee `attack` LOOPS while the player stays in melee reach (a channel /
## flurry) instead of one swing per cooldown. It re-plays from the anim's `loop_from`
## (gen_spriteframes), so a wind-up lead-in plays once and only the strike cycle repeats.
@export var attack_loops := false
@export var melee_damage: float = 12.0
@export var ranged_damage: float = 8.0
## On-hit effects this enemy's attacks carry (0 = none).
@export var melee_knockback: float = 90.0
@export var melee_stun: float = 0.0
@export var ranged_knockback: float = 0.0
@export var ranged_stun: float = 0.0
## Melee hitbox placement in front of the body, and its half-size. For an AoE swing set
## `melee_hitbox_x` to 0 (centred on the body) and the extents wide.
@export var melee_hitbox_x: float = 20.0
@export var melee_hitbox_extents := Vector2(16, 16)
## How long the melee strike (hitbox + its VFX) stays active, in seconds. A quick jab is brief; a wide
## AoE sweep wants it longer so the box is live across the swing frames (hits once -- Hitbox dedups).
@export var melee_strike_lifetime: float = 0.15
## Where a projectile leaves the enemy (forward, up), before facing mirror -- fallback when
## the Emitters config gives no `projectile` pos for this enemy (that config IS the muzzle now).
const DEFAULT_MUZZLE := Vector2(20, -46)
@export var projectile_speed: float = 260.0
## "aimed": projectile flies toward the player (Kebus' staff bolt).
## "forward": it surges straight ahead along the ground for `ranged_travel` px
## then fizzles, hitting whatever it passes (Baghel's ground energy).
## "lob": THROW a bomb in an arc that lands next to the player, dwells, then explodes
## (Mazab). A LobProjectile, not a straight-line Projectile -- see the lob_* exports below;
## the blast reuses ranged_damage/knockback/stun. Dodge by clearing the landing spot.
@export_enum("aimed", "forward", "lob") var ranged_mode := "aimed"
@export var ranged_travel: float = 100.0
## The projectile's visual scene (Baghel's wave, Kebus' bolt, Mazab's rock) is NOT set here --
## it comes from the Emitters config (`<id> -> projectile -> scene`); empty there = the built-in
## orb. Same for the lob blast (`<id> -> explosion -> scene`). One place for every enemy emitter.
## Projectile collider half-size + offset from its spawn point.
@export var ranged_hitbox_extents := Vector2(5, 5)
@export var ranged_hitbox_offset := Vector2.ZERO

@export_subgroup("Lob (ranged_mode = lob)")
## Seconds the thrown bomb is airborne (the arc). Its launch speed is solved to land on the
## mark, so this shapes the arc height, not the distance.
@export var lob_arc_time: float = 0.9
## Downward accel on the thrown bomb (px/s^2) -- higher = tighter arc.
@export var lob_gravity: float = 900.0
## Seconds the landed bomb sits (blinking) before it explodes: the dodge window.
@export var lob_dwell: float = 1.0
## Seconds a thrown bomb stays airborne before it detonates MID-AIR if it never finds a
## surface (thrown over a ledge). Otherwise it lands + dwells as normal.
@export var lob_max_life: float = 3.0
## Half-size of the explosion (a wide, short ground blast). Damage/knockback/stun reuse the
## ranged_* values above.
@export var lob_explosion_extents := Vector2(48, 26)
## How far to the side of the player the bomb lands (px), biased toward the thrower so it
## drops at their feet, not behind them.
@export var lob_land_offset: float = 22.0

@export_group("Behaviour")
## When true, CHASES the player up to `aggro_range` (the give-up leash: get farther and it drops back to
## patrol), instead of only fighting whoever wanders into its line. ON by default -- enemies are hunters;
## it chases to its ATTACK reach (firing range for a ranged mob, melee range for a melee one) then attacks.
## Set per-kit to false for a mob that should just guard a spot.
@export var aggro := true
@export var aggro_range: float = 480.0
## Get alerted when hurt: taking a hit makes this enemy detect + pursue the attacker for
## `alert_duration` seconds even if it was outside its normal range (re-hits refresh it).
## So a shot from off-screen won't go unanswered. 0 = never alerts.
@export var alert_duration: float = 5.0
## When true, THIS enemy's attacks can hit OTHER enemies too, not just the player (it
## still never hits itself). Per-instance -- flag a single mob for chaos, not the whole
## roster. The seam for enemies fighting each other.
@export var friendly_fire := false
## Damage dealt by simply touching the player (0 = off), applied on an interval.
@export var contact_damage: float = 0.0
@export var contact_knockback: float = 120.0
@export var contact_interval: float = 0.6

@export_group("Attack feel")
## Freeze the attack on its impact frame for this long, then let it finish -- a
## hit-stop that gives the blow weight. 0 = off.
@export var attack_hitstop: float = 0.18
## Peak jitter (px) of the shake during the hit-stop; decays to 0 over it.
@export var attack_shake: float = 2.5

enum State {IDLE, PATROL, MELEE, RANGE, STUN, DEAD, RAGE, CHARGE} # RAGE: nasen; CHARGE: ein's dive

var health: float
var _state: State = State.IDLE
var _facing: int = -1 # enemies commonly face left toward a right-approaching player
var _has_melee := false
var _has_ranged := false
var _has_death := false
var _has_patrol := false
var _frame_sfx := {} ## anim -> {emitted_frame: sound path}, built at spawn from the enemy's sound folder
var _attack_cd := 0.0
var _attack_fired := false
var _point_a := 0.0
var _point_b := 0.0
var _patrol_target := 0.0
var _idle_timer := 0.0
var _stun_left := 0.0
## REAP (damage-over-time, e.g. Twin Reaper): while `_dot_left` > 0 the enemy keeps losing health in
## discrete 1-second bites of `_dot_tick` HP (= max_health x the move's `reap` fraction, snapshot when
## the mark lands). `_dot_accum` is the sub-second timer; `_dot_source` credits the attacker for the
## tick's damage/Ruh. The mark is ONE-AND-DONE: `_reaped` latches on the FIRST reap hit so it plays out
## its fixed window once -- later hits only deal their normal damage, never re-arm/extend it. See
## _tick_dot / _on_hurt.
var _dot_left := 0.0
var _dot_tick := 0.0
var _dot_accum := 0.0
var _dot_source: Node = null
var _reaped := false
## MAGNET pull (Come Closer special): while `_magnet_anchor` is valid, AI is overridden and this enemy
## is dragged toward the anchor at `_magnet_speed`; on arriving within `_magnet_arrive` it stuns for
## `_magnet_stun` and releases. Set by Enemy.magnetize() (called by the magnet field scene). No damage.
var _magnet_anchor: Node2D = null
var _magnet_arrive := 60.0
var _magnet_speed := 320.0
var _magnet_stun := 3.0
## Seconds left CHARMED as a "frenemy": while > 0 this enemy fights FOR the player -- it targets the
## other enemies, its attacks hit them (not the player), and its contact damage is off. See
## become_frenemy / _end_frenemy. Set by the frenemy special (Hit.frenemy_time).
var _frenemy_left := 0.0
var _contact_cd := 0.0
var _contact_hitbox: Hitbox
var _scratch_timer := 0.0
var _scratch_full_cycle := false
## Player is in reach (attacking distance) -> we're in combat, so the idle
## between attacks holds a tense ready-stance instead of the patrol flourish.
var _engaged := false
## Seconds of "alerted" left after being hurt: while > 0 the enemy pursues the player
## regardless of its normal detection range (see _act / _on_hurt).
var _alert_left := 0.0
var _hitstop_left := 0.0
var _hitstop_dur := 0.0
var _impacted := false # this attack already fired its hit-stop

var _sprite: AnimatedSprite2D
var _hurtbox: Hurtbox
var _bar: FloatingHealthBar
var _status: StatusOverlay
var _status_icons: StatusIcons
var _shown_status := "" ## joined key of the currently-drawn status ids, so icons only redraw on change
var _edge_ray_left: RayCast2D
var _edge_ray_right: RayCast2D


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = Combat.L_ENEMY_BODY
	collision_mask = Combat.L_WORLD

	_build_sprite()
	_build_body()
	_build_hurtbox()
	_build_contact_hitbox()
	_build_health_bar()
	_build_edge_rays()

	_status = StatusOverlay.new()
	add_child(_status)
	_status.setup(_sprite)

	# Status pips (stun / reap / charm) sit just to the RIGHT of the health bar, centred on its row.
	_status_icons = StatusIcons.new()
	add_child(_status_icons)
	_status_icons.position = _bar.position + Vector2(_bar.bar_width / 2.0 + 3.0, -_bar.bar_height / 2.0)

	_has_melee = _sprite.sprite_frames.has_animation(&"attack")
	_has_ranged = _sprite.sprite_frames.has_animation(&"attack_projectile")
	_has_death = _sprite.sprite_frames.has_animation(&"death")
	_has_patrol = _sprite.sprite_frames.has_animation(&"patrol")
	_build_frame_sfx()

	health = max_health
	_bar.set_ratio(1.0)

	_point_a = global_position.x
	_point_b = global_position.x + patrol_distance
	_patrol_target = _point_b

	_sprite.frame_changed.connect(_on_frame_changed)
	_sprite.animation_finished.connect(_on_anim_finished)
	_sprite.animation_looped.connect(_on_anim_looped)
	_face(_facing)
	_play(&"patrol" if _has_patrol else &"idle") # a patrolless enemy (sleeper) just idles


# --- construction -----------------------------------------------------------

func _build_sprite() -> void:
	_sprite = AnimatedSprite2D.new()
	var path := FRAMES_PATH % enemy_id
	if not ResourceLoader.exists(path):
		push_error("Enemy '%s': no SpriteFrames at %s" % [enemy_id, path])
		return
	_sprite.sprite_frames = load(path)
	# Subtle accent glow: the enemies are repaletted to a dark body + a bright accent (eyes/orb/iris),
	# and this material blooms just the accent so it reads as alive in the dark. Shared across all enemies;
	# tweak the look on resources/enemy_glow.tres (glow / sat_min / val_min) or the shader.
	if ResourceLoader.exists(GLOW_MATERIAL):
		_sprite.material = load(GLOW_MATERIAL)
	anchor_to_feet(_sprite)
	add_child(_sprite)


func _build_body() -> void:
	add_child(Shapes.make_box(body_size, Vector2(0, -body_size.y / 2.0)))


func _build_hurtbox() -> void:
	_hurtbox = Hurtbox.new()
	_hurtbox.collision_layer = Combat.L_ENEMY_HURT
	_hurtbox.collision_mask = 0
	_hurtbox.add_child(Shapes.make_box(hurtbox_size, Vector2(0, -hurtbox_size.y / 2.0)))
	add_child(_hurtbox)
	_hurtbox.hurt.connect(_on_hurt)


func _build_contact_hitbox() -> void:
	if contact_damage <= 0.0:
		return
	_contact_hitbox = Hitbox.new()
	_contact_hitbox.collision_layer = Combat.L_ENEMY_HIT
	_contact_hitbox.collision_mask = Combat.L_PLAYER_HURT
	_contact_hitbox.damage = contact_damage
	_contact_hitbox.knockback = contact_knockback
	_contact_hitbox.source = self
	_contact_hitbox.add_child(Shapes.make_box(hurtbox_size, Vector2(0, -hurtbox_size.y / 2.0)))
	add_child(_contact_hitbox)


func _build_edge_rays() -> void:
	# A downward probe just ahead of each foot; if it finds no ground, that side
	# is an edge and we won't step off it.
	_edge_ray_left = _make_edge_ray(-edge_check_x)
	_edge_ray_right = _make_edge_ray(edge_check_x)


func _make_edge_ray(x: float) -> RayCast2D:
	var ray := RayCast2D.new()
	ray.position = Vector2(x, -4)
	ray.target_position = Vector2(0, 16)
	ray.collision_mask = Combat.L_WORLD
	add_child(ray)
	return ray


## Is there ground just ahead in movement direction `dir` (-1/+1)?
func _floor_ahead(dir: int) -> bool:
	var ray := _edge_ray_left if dir < 0 else _edge_ray_right
	ray.force_raycast_update()
	return ray.is_colliding()


func _build_health_bar() -> void:
	_bar = FloatingHealthBar.new()
	_bar.ratio_colors = true # health: green (full) -> orange -> red (low)
	add_child(_bar)
	_bar.setup(display_name)
	# Just above the head (sprite is drawn from feet at y=0 upward).
	var frame := _sprite.sprite_frames.get_frame_texture(&"idle", 0)
	var head_y := - (frame.get_height() if frame else 70) + 8
	_bar.position = Vector2(0, head_y)


# --- loop -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return

	# Reap DoT + status pips tick FIRST, before the stun/hit-stop/magnet early-returns below, so a
	# marked enemy keeps bleeding (and its icons stay current) even while frozen. A reap can kill here.
	_tick_dot(delta)
	if _state == State.DEAD:
		return
	_refresh_status_icons()

	if _frenemy_left > 0.0: # count down the charm; revert to hostile when it runs out
		_frenemy_left -= delta
		if _frenemy_left <= 0.0:
			_end_frenemy()

	if not is_on_floor():
		velocity.y += gravity * delta

	# Hit-stop: frozen on the impact frame, shaking, dealing no new actions. Still
	# settle vertically so it doesn't hang in the air, but no horizontal drift.
	if _hitstop_left > 0.0:
		_hitstop_left -= delta
		velocity.x = 0.0
		_apply_shake()
		if _hitstop_left <= 0.0:
			_end_hitstop()
		move_and_slide()
		return

	# MAGNET (Come Closer): drag toward the anchor, overriding AI; stun + release on arrival.
	if _magnet_anchor != null:
		if not is_instance_valid(_magnet_anchor):
			_magnet_anchor = null
		else:
			# Horizontal only -- same-level pull (the field already filtered to Khalid's floor).
			var dx: float = _magnet_anchor.global_position.x - global_position.x
			if absf(dx) <= _magnet_arrive:
				velocity.x = 0.0 # STOP dead -- no momentum, or it slides past Khalid during the stun
				_stun_left = maxf(_stun_left, _magnet_stun)
				_set_state(State.STUN)
				_status.show_for(Color(0.6, 0.4, 1.0, 0.6), _magnet_stun) # a faint pull/stun tint
				_magnet_anchor = null
			else:
				# Ease down over the last stretch so a strong pull doesn't rocket past the arrive point.
				var speed: float = _magnet_speed * clampf(absf(dx) / (_magnet_arrive * 2.0), 0.25, 1.0)
				velocity.x = signf(dx) * speed
				_face(int(signf(dx)))
				move_and_slide()
				return

	if _state == State.STUN:
		# Frozen: keep sliding on knockback momentum, but take no actions.
		_stun_left -= delta
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		if _stun_left <= 0.0:
			_set_state(State.IDLE)
	elif _state == State.MELEE or _state == State.RANGE:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta) # rooted while attacking
	else:
		_act(delta)

	if _state == State.IDLE:
		_idle_scratch(delta)
	_tick_contact(delta)
	move_and_slide()


## Resting-idle flourish: hold the sub-loop for a while, then a full cycle.
func _idle_scratch(delta: float) -> void:
	# In combat, play a LIVE idle loop (a ready-stance that breathes) rather than freezing on one
	# frame -- a paused sprite reads as a bug. Reverts to the patrol flourish once the player leaves
	# reach (_engaged clears). Just ensure idle is playing; don't restart it every frame.
	if _engaged:
		if _sprite.animation != &"idle" or not _sprite.is_playing():
			_sprite.play(&"idle")
		return
	if idle_loop_to <= idle_loop_from or _scratch_full_cycle:
		return # not configured, or letting a full idle play (_on_anim_looped ends it)
	_scratch_timer -= delta
	if _scratch_timer <= 0.0:
		_scratch_full_cycle = true
		_sprite.set_frame_and_progress(0, 0.0) # play one full idle from the top


## The sub-range loop is clamped here (on the render frame it changes) rather
## than in physics, so the past-the-range frame never flashes.
func _clamp_scratch() -> void:
	if _state != State.IDLE or _scratch_full_cycle or _sprite.animation != &"idle":
		return
	if idle_loop_to <= idle_loop_from:
		return
	if _sprite.frame > idle_loop_to or _sprite.frame < idle_loop_from:
		_sprite.set_frame_and_progress(idle_loop_from, 0.0)


func _on_anim_looped() -> void:
	if _sprite.animation == &"idle" and _scratch_full_cycle:
		_scratch_full_cycle = false
		_scratch_timer = idle_loop_time


func _tick_contact(delta: float) -> void:
	if _contact_hitbox == null or is_frenemy():
		return # a charmed frenemy doesn't touch-damage the player
	_contact_cd = maxf(_contact_cd - delta, 0.0)
	if _contact_cd <= 0.0:
		_contact_hitbox.activate() # re-arm; hits the player if still overlapping
		_contact_cd = contact_interval


func _act(delta: float) -> void:
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_alert_left = maxf(_alert_left - delta, 0.0)

	var player := _target() # the player normally; the nearest OTHER enemy while charmed (frenemy)
	if player != null:
		var to_player := player.global_position.x - global_position.x
		var dist: float = absf(to_player)
		# Attacks are horizontal, so we can only land one when the target is roughly at our
		# height (see attack_align_y) -- otherwise don't swing/fire at all.
		var aligned := absf(player.global_position.y - global_position.y) <= attack_align_y
		if aligned and _attack_cd <= 0.0:
			if _has_melee and dist <= melee_range:
				_start_attack(State.MELEE, &"attack", player)
				return
			if _has_ranged and dist <= ranged_range:
				_start_attack(State.RANGE, &"attack_projectile", player)
				return
		# Are we in combat? PURSUE = close in on the player from any height/range -- when
		# aggressive by nature (aggro) or freshly hurt (alerted). HOLD = stand and face when
		# they're on our level and in ranged reach. Neither -> fall through to patrol, so an
		# enemy on a different platform keeps patrolling instead of freezing.
		var dir := int(sign(to_player))
		var pursue := _alert_left > 0.0 or (aggro and dist <= aggro_range)
		var hold := aligned and dist <= ranged_range
		# A PURE-MELEE enemy (no ranged option) must CLOSE the gap to attack -- so when the target is in
		# its line (aligned + in reach) it walks in, not just when it's aggro. A ranged (or mixed) enemy
		# stands and fires from range instead. Both still refuse to step off a ledge (_floor_ahead).
		var close_in := pursue or (hold and _has_melee and not _has_ranged)
		# Chase to our ATTACK REACH, not always melee: a ranged mob closes only to firing range and holds
		# (it shouldn't run its bow into your face), a pure-melee mob closes to melee. A hair inside so the
		# attack check above fires (stopping just outside left a melee enemy hovering out of range, staring).
		var reach: float = (ranged_range if _has_ranged else melee_range) - 4.0
		if pursue or hold:
			_engaged = true
			# Approach toward the target (never off a ledge) unless we're already within reach.
			if close_in and dist > reach and _floor_ahead(dir):
				velocity.x = dir * move_speed
				_face(dir)
				_set_state(State.PATROL)
			else:
				velocity.x = 0.0
				_face(dir)
				_set_state(State.IDLE)
			return

	_engaged = false # nobody in reach -> back to normal patrol/idle
	_patrol(delta)


func _patrol(delta: float) -> void:
	if _idle_timer > 0.0:
		# Pausing at the end of a leg; the target was already flipped on arrival.
		_idle_timer -= delta
		velocity.x = 0.0
		_set_state(State.IDLE)
		return

	var dir := int(sign(_patrol_target - global_position.x))
	var arrived := dir == 0 or absf(_patrol_target - global_position.x) <= 2.0
	# Turn around at the patrol end OR at a real ledge, whichever comes first.
	if arrived or not _floor_ahead(dir):
		velocity.x = 0.0
		_idle_timer = randf_range(idle_time_min, idle_time_max)
		_patrol_target = _point_a if is_equal_approx(_patrol_target, _point_b) else _point_b
		_set_state(State.IDLE)
		return

	velocity.x = dir * move_speed
	_face(dir)
	_set_state(State.PATROL)


# --- attacks ----------------------------------------------------------------

func _start_attack(state: State, anim: StringName, player: Node2D) -> void:
	_set_state(state)
	_play_attack_start_sfx(anim)
	velocity.x = 0.0
	_attack_fired = false
	_impacted = false
	_engaged = true # attacking means we're in combat, so the idle stays a stance
	_face(int(sign(player.global_position.x - global_position.x)))
	_play(anim)


## Build this enemy's per-frame HIT sound cues from SfxEnemies.FRAMES[enemy_id], converting the
## config's SHEET-relative frames to the EMITTED indices the sprite reports. Keyed anim -> {emitted:
## cue_key}, played in _on_frame_changed. Done once at spawn.
func _build_frame_sfx() -> void:
	_frame_sfx = {}
	var by_anim: Dictionary = SfxEnemies.FRAMES.get(enemy_id, {})
	var sf := _sprite.sprite_frames
	for anim in by_anim:
		var a := StringName(anim)
		if not sf.has_animation(a):
			continue
		var start := AnimMeta.sheet_start(sf, a)
		var map := {}
		for sheet_frame in by_anim[anim]:
			map[int(sheet_frame) - start] = by_anim[anim][sheet_frame]
		_frame_sfx[a] = map


## Play this enemy's attack-START cue for `anim` -- key `<enemy_id>.<type>` (type = melee / projectile),
## resolved by the Sfx service (silent no-op if that enemy has no such cue). Shared by the base attack
## and by subclasses with their own trigger (Nasen's rage).
func _play_attack_start_sfx(anim: StringName) -> void:
	# The strike TYPE keys the cue (`<id>.<type>`). Prefer the enemy's declared `attack_type`; else the
	# coarse melee/projectile from the anim (so a plain melee / straight shot needs no attack_type set).
	var kind := attack_type if attack_type != "" else ("melee" if anim == &"attack" else "projectile")
	Sfx.play_at("%s.%s" % [enemy_id, kind], global_position)


## Play the per-frame HIT cue for the attack anim currently PLAYING, if this frame has one. Keyed by
## `_sprite.animation`, so it covers melee/ranged AND Nasen's rage (the attack anim under RAGE state).
func _play_frame_sfx() -> void:
	if _frame_sfx.is_empty():
		return
	var cue: String = (_frame_sfx.get(_sprite.animation, {}) as Dictionary).get(_sprite.frame, "")
	if cue != "":
		Sfx.play_at(cue, global_position)


func _on_frame_changed() -> void:
	_play_frame_sfx()
	if _state == State.MELEE and _sprite.frame in _hit_frames(&"attack"):
		_spawn_melee_strike()
		_begin_hitstop()
	elif _state == State.RANGE and not _attack_fired and _sprite.frame >= _fire_frame():
		_attack_fired = true
		_fire_projectile()
		_begin_hitstop()
	elif _state == State.IDLE:
		_clamp_scratch()


## Freeze the attack on this impact frame for a beat and shake the sprite, so the
## blow lands with weight. Once per attack; the physics loop resumes it.
func _begin_hitstop() -> void:
	if _impacted or attack_hitstop <= 0.0:
		return
	_impacted = true
	_hitstop_dur = attack_hitstop
	_hitstop_left = attack_hitstop
	_sprite.pause() # hold the impact frame; resumes in _end_hitstop


func _end_hitstop() -> void:
	_hitstop_left = 0.0
	_sprite.position = Vector2.ZERO # undo the shake
	if _state == State.MELEE or _state == State.RANGE or _state == State.RAGE:
		_sprite.play() # let the swing (or nasen's rage) follow through to its finish


## Decaying jitter over the hit-stop: strongest on impact, settling to nothing.
func _apply_shake() -> void:
	if attack_shake <= 0.0 or _hitstop_dur <= 0.0:
		_sprite.position = Vector2.ZERO
		return
	var amp := attack_shake * (_hitstop_left / _hitstop_dur)
	_sprite.position = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))


func _on_anim_finished() -> void:
	if _state == State.DEAD:
		queue_free() # death anim played out in full -> vanish immediately (no lingering hold/fade)
		return
	# A looping melee keeps swinging while the player stays in reach, re-playing from its
	# loop_from frame so the wind-up only plays once. Otherwise it's one-and-done.
	if _state == State.MELEE and attack_loops and _in_melee_reach():
		_attack_fired = false
		_impacted = false
		_replay_from(&"attack", _loop_from(&"attack"))
		return
	if _state == State.MELEE or _state == State.RANGE:
		_attack_cd = attack_cooldown
		_set_state(State.IDLE)


## Emit offset for one of this enemy's particle effects, from vfx/config/the Emitters config
## (keyed by enemy_id -> `effect`), MIRRORED by facing. `fallback` is the value hardcoded in the
## script, used when the config has no `pos` for it. The enemy counterpart to the character
## emitters `pos`; enemy effects are attached in code (a trail, a spawned blast), so there's no
## frame scheduling -- just the position.
func _vfx_pos(effect: String, fallback := Vector2.ZERO) -> Vector2:
	var p: Vector2 = Emitters.enemy_effect(enemy_id, effect).get("pos", fallback)
	return Vector2(p.x * _facing, p.y)


## Preloaded scene this enemy emits for `effect` (Emitters), or null if none listed -- the
## config is authoritative, so no entry = no emitter.
func _vfx_scene(effect: String) -> PackedScene:
	return Emitters.enemy_effect(enemy_id, effect).get("scene", null)


## Instantiate this enemy's `effect` emitter (from config), positioned at its config offset
## (mirrored by facing). Returns null when the config lists no scene for it -- so a deleted
## config row simply produces no effect. The caller parents it (to the body, or a spawned Strike).
func _make_vfx(effect: String) -> Node2D:
	var scene := _vfx_scene(effect)
	if scene == null:
		return null
	var node := scene.instantiate()
	if node is Node2D:
		(node as Node2D).position = _vfx_pos(effect)
	return node as Node2D


## Emitted frame an animation's loop restarts at (from the generator's `loop_from`
## metadata), or 0 if unset. Used by _replay_from so a re-played attack skips its lead-in.
func _loop_from(anim: StringName) -> int:
	return maxi(AnimMeta.loop_bound(_sprite.sprite_frames, anim, "loop_from"), 0)


## Re-play `anim` from emitted frame `from`, skipping its lead-in, and resume to the end (so
## _on_anim_finished can loop it again). The reusable half of a looping/channeled attack --
## the caller decides WHEN to loop (Enemy: player in reach; Nasen: still raging).
func _replay_from(anim: StringName, from: int) -> void:
	if _sprite.animation != anim:
		_sprite.play(anim)
	var last := _sprite.sprite_frames.get_frame_count(anim) - 1
	_sprite.set_frame_and_progress(clampi(from, 0, last), 0.0)
	_sprite.play()


## Is the player still within melee reach + on our level (the condition a looping melee
## keeps swinging on)?
func _in_melee_reach() -> bool:
	var t := _target() # frenemy-aware: the enemy it's fighting while charmed, else the player
	if t == null:
		return false
	var to := t.global_position - global_position
	return absf(to.y) <= attack_align_y and absf(to.x) <= melee_range


## Spawn a hostile Strike for one melee swing -- the enemy counterpart to a player's
## melee. Its Hitbox is built from this enemy's melee tuning; Strike sets the team layers
## from `hostile` and frees itself after a brief flash. Attached to the enemy so it sits
## in front of the body for the swing.
func _spawn_melee_strike() -> void:
	var strike := Strike.new()
	strike.hostile = not is_frenemy() # a charmed frenemy's swing hits enemies, not the player
	strike.friendly_fire = friendly_fire # also catch other enemies, if flagged
	strike.lifetime = melee_strike_lifetime
	strike.source = self
	var hb := Hitbox.new()
	hb.damage = melee_damage
	hb.knockback = melee_knockback
	hb.stun = melee_stun
	hb.source = self
	hb.add_child(Shapes.make_box(melee_hitbox_extents * 2.0, Vector2(0, -melee_hitbox_extents.y)))
	strike.add_child(hb)
	# Optional melee/AoE LOOK: the `aoe` effect from the Emitters config (null if none), attached to the
	# strike so it rides the swing and frees with it -- e.g. Matat's shockwave. Same pattern as nasen's rage.
	var fx := _make_vfx("aoe")
	if fx != null:
		strike.add_child(fx)
	add_child(strike) # _ready: team layers + free timer
	strike.position = Vector2(melee_hitbox_x * _facing, 0)
	hb.activate()


func _fire_projectile() -> void:
	if ranged_mode == "lob":
		_fire_lob() # a thrown bomb (LobProjectile), not a straight-line shot
		return
	var muzzle := global_position + _vfx_pos("projectile", DEFAULT_MUZZLE) # config-driven launch point
	# One shared Projectile class for players AND enemies -- hostile = true puts it on the
	# enemy-hit layer scanning player hurtboxes, homing = 0 flies straight, and the look/damage
	# are the `projectile` scene (the Emitters config) + a Hitbox built from this enemy's tuning.
	var proj := Projectile.new()
	proj.hostile = not is_frenemy() # a charmed frenemy's shot hits enemies, not the player
	proj.friendly_fire = friendly_fire # also catch other enemies, if flagged
	proj.homing = 0.0 # aim once / surge forward -- no steering
	proj.rotate_to_heading = false # visual authored blasting +x -> mirror, don't rotate
	proj.source = self
	var vis := _vfx_scene("projectile") # null -> the projectile's built-in orb fallback
	if vis != null:
		proj.add_child(vis.instantiate())

	# The shot's damage box, sized from this enemy's ranged hitbox exports. The
	# Projectile arms it and sets its team layers from `hostile` on _ready.
	var hb := Hitbox.new()
	hb.damage = ranged_damage
	hb.knockback = ranged_knockback
	hb.stun = ranged_stun
	hb.add_child(Shapes.make_box(ranged_hitbox_extents * 2.0, ranged_hitbox_offset))
	proj.add_child(hb)

	if ranged_mode == "forward":
		# Surge straight ahead along the ground; capped distance via max_range.
		proj.velocity = Vector2(projectile_speed * _facing, 0.0)
		proj.max_range = ranged_travel
		proj.ground_trail = true # scorch the floor red as it rolls past
	else:
		# Aim at the TARGET's torso (the player, or the nearest enemy while charmed) so a high
		# muzzle still connects with a short body; fall back to straight ahead if the target
		# vanished mid-cast. Fizzle after a few seconds if it misses everything.
		var aim := _target() # frenemy-aware: nearest enemy while charmed, else the player
		var target := (aim.global_position + Vector2(0, -15)) if aim != null \
			else muzzle + Vector2(_facing, 0)
		proj.velocity = (target - muzzle).normalized() * projectile_speed
		proj.max_life = 3.0

	# Live in the level, not under the enemy, so it keeps going if the enemy dies.
	# Nodes.place_at snaps it to the muzzle without physics-interpolation smear.
	get_parent().add_child(proj)
	Nodes.place_at(proj, muzzle)


## Throw a lobbed bomb (ranged_mode = "lob"): a LobProjectile that arcs from the muzzle to a
## spot NEXT TO the player, dwells, then explodes. The blast reuses this enemy's ranged_* tuning;
## the thrown-object look + blast look both come from the Emitters config (`projectile` /
## `explosion`), like every enemy emitter.
func _fire_lob() -> void:
	# A lob is a DELAYED_PROJECTILE in the taxonomy: the thrown bomb + its `_burst` explosion.
	var muzzle := global_position + _vfx_pos("delayed_projectile", DEFAULT_MUZZLE)
	var lob := LobProjectile.new()
	lob.hostile = not is_frenemy() # a charmed frenemy's lob hits enemies, not the player
	lob.friendly_fire = friendly_fire
	lob.source = self
	lob.arc_time = lob_arc_time
	lob.gravity = lob_gravity
	lob.dwell_time = lob_dwell
	lob.max_life = lob_max_life
	lob.explosion_extents = lob_explosion_extents
	lob.explosion_damage = ranged_damage
	lob.explosion_knockback = ranged_knockback
	lob.explosion_stun = ranged_stun
	lob.explosion_effect = _vfx_scene("delayed_projectile_burst") # blast look (config); null -> Strike's own flash
	# detached from us at detonation, so raw pos (no facing mirror)
	lob.explosion_effect_pos = Emitters.enemy_effect(enemy_id, "delayed_projectile_burst").get("pos", Vector2.ZERO)
	# The delayed BURST cue -- the lob plays it at the detonation point (see LobProjectile). Key
	# `<id>.delayed_projectile_burst` (declare it in SfxEnemies); the Sfx service no-ops if unregistered.
	lob.explosion_sfx = "%s.delayed_projectile_burst" % enemy_id
	var vis := _vfx_scene("delayed_projectile") # the thrown-bomb look
	if vis != null:
		lob.add_child(vis.instantiate())

	# Land it next to the TARGET (the player, or the nearest enemy while charmed), biased toward
	# us so it drops at their feet, not behind. Fall back to a short toss ahead if none.
	var aim := _target() # frenemy-aware: nearest enemy while charmed, else the player
	var land := muzzle + Vector2(_facing * 90.0, 30.0)
	if aim != null:
		var side := -signf(aim.global_position.x - global_position.x)
		land = aim.global_position + Vector2(side * lob_land_offset, 0.0)
	lob.target = land

	get_parent().add_child(lob)
	Nodes.place_at(lob, muzzle)


func _fire_frame() -> int:
	# Fire on the authored hit frame (hit_frames metadata), else mid-animation.
	var hits := _hit_frames(&"attack_projectile")
	if not hits.is_empty():
		return int(hits[0])
	@warning_ignore("integer_division")
	return maxi(1, _sprite.sprite_frames.get_frame_count(&"attack_projectile") / 2)


func _hit_frames(anim: StringName) -> Array:
	return AnimMeta.hit_frames(_sprite.sprite_frames, anim)


# --- damage / death ---------------------------------------------------------

## True if the LAST hit taken came from the player's special -- RunManager reads it on death to
## decide whether the kill refills Ruh (a special-kill does not).
var last_hit_from_special := false


func _on_hurt(hit: Hit) -> void:
	if _state == State.DEAD:
		return
	last_hit_from_special = hit.from_special
	var before := health
	health = maxf(health - hit.amount, 0.0)
	damaged.emit(before - health, hit.source) # harvest = actual HP removed (overkill isn't paid)
	_bar.set_ratio(health / max_health)
	hit_react(_sprite, hit.amount)
	# Getting hit alerts us: pursue the attacker for a while even if it struck from beyond
	# our normal detection range, and snap to face where the blow came from.
	if alert_duration > 0.0:
		_alert_left = alert_duration
		if hit.source is Node2D:
			_face(int(sign((hit.source as Node2D).global_position.x - global_position.x)))
	if health <= 0.0:
		_die()
		return
	# Dynamic per-attack hurt VFX (a stun effect, a slam shock, ...), placed by its own scene
	# relative to our feet. fit_h scales it to this enemy's size.
	if hit.victim_vfx != null:
		# The victim is an enemy -> the effect is one of Khalid's powers (his stun overlay), so recolour it
		# to his power picks. (The player-victim path in player.gd stays un-recoloured -- that's enemy VFX.)
		spawn_victim_vfx(hit.victim_vfx, hit.victim_vfx_time, hurtbox_size.y, true)
	# The frenemy special charms us into a temporary ally (it carries no stun, so we keep fighting --
	# just for the player now).
	if hit.frenemy_time > 0.0:
		become_frenemy(hit.frenemy_time)
	# REAP: mark us to slowly die -- but only ONCE. `_reaped` latches on the first reap hit, so the
	# spin's later hits just deal their normal damage and never re-arm or extend the drain. The mark
	# plays out its fixed window (see _tick_dot) from this snapshot of the per-tick HP.
	if hit.dot_percent > 0.0 and hit.dot_time > 0.0 and not _reaped:
		_reaped = true
		_dot_tick = max_health * hit.dot_percent
		_dot_left = hit.dot_time
		_dot_source = hit.source
	# Knockback needs a brief stagger, or the AI overwrites the shove velocity next
	# frame and nothing moves; a pure stun freezes for longer.
	var stagger := apply_knockback(hit, _facing)
	if stagger > 0.0:
		# Never SHORTEN an existing stun: a follow-up jab on a long-stunned enemy would otherwise
		# overwrite a long control stun with its own 0.18s stagger and wake them early. Take the max,
		# so a hit can EXTEND a stun but never cut it short.
		_stun_left = maxf(_stun_left, stagger)
		_set_state(State.STUN) # freezes the sprite on whatever frame it was on (see _set_state)
		if hit.status_color.a > 0.0:
			_status.show_for(hit.status_color, hit.status_time)


## Enter the DEAD state and stop receiving hits. The body stays for the death
## animation; debug_respawn clears and re-spawns the roster.
func _die() -> void:
	_set_state(State.DEAD) # _physics_process bails on DEAD, so the AI stops here
	Sfx.play_at("enemy_death", global_position) # positional -- pans with where it fell
	died.emit() # count the kill (RunManager banks Ruh + tracks arena clear)
	remove_from_group("enemies") # stop being a homing target NOW -- the death anim/fade below
	# keeps this node alive ~2s, and a tracking projectile would otherwise curve into the corpse
	_hurtbox.set_deferred("monitorable", false)
	set_deferred("collision_layer", 0)
	if _has_death:
		_play(&"death") # play it out; _on_anim_finished frees it the instant the anim ends
	else:
		_fade_and_free() # no death sheet -> a straight alpha-fade (there's no anim to play out)


## Let the final (dead) pose sit a beat, then fade the corpse out and free. The graceful
## tail of a death animation, or the whole thing for an enemy with no death sheet.
func _fade_and_free() -> void:
	var tw := create_tween()
	tw.tween_interval(0.4) # hold the dead pose so the death reads before it clears
	tw.tween_property(_sprite, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)


## --- reap (damage-over-time) ------------------------------------------------

## Bleed out a reap mark in discrete once-a-second bites (as authored: "N% of health every 1 second"),
## so it reads as ticks and doesn't spam per-frame Ruh/damage numbers. Ticks keep firing while stunned;
## a tick can be the killing blow. No-op when unmarked. Called at the very top of _physics_process.
func _tick_dot(delta: float) -> void:
	if _dot_left <= 0.0:
		return
	_dot_left -= delta
	_dot_accum += delta
	while _dot_accum >= 1.0 and _state != State.DEAD:
		_dot_accum -= 1.0
		_reap_tick()
	if _dot_left <= 0.0:
		_dot_accum = 0.0
		_dot_source = null


## One reap bite: drain `_dot_tick` HP, credit the source (Ruh/leech/damage numbers flow through the
## same `damaged` signal as a real hit, but only once a second), update the bar, and die if it empties.
func _reap_tick() -> void:
	var before := health
	health = maxf(health - _dot_tick, 0.0)
	var dealt := before - health
	if dealt <= 0.0:
		return
	last_hit_from_special = false # a reap tick is normal damage -> Ruh-eligible (see RunManager)
	damaged.emit(dealt, _dot_source if is_instance_valid(_dot_source) else null)
	_bar.set_ratio(health / max_health)
	if health <= 0.0:
		_dot_left = 0.0
		_die()


## --- status pips ------------------------------------------------------------

## Recompute which status icons are active this frame and push them to the pip row -- but only when the
## set actually changed (a joined-key compare), so we don't queue a redraw every frame. Order follows
## StatusTypes.ORDER so a given status always sits in the same slot.
func _refresh_status_icons() -> void:
	var ids: Array = []
	if _dot_left > 0.0:
		ids.append("reap")
	if _state == State.STUN or _stun_left > 0.0:
		ids.append("stun")
	if _frenemy_left > 0.0:
		ids.append("charm")
	var key := ",".join(ids)
	if key == _shown_status:
		return
	_shown_status = key
	_status_icons.set_active(ids)


# --- helpers ----------------------------------------------------------------

func _player() -> Node2D:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	# A dead player is no target: enemies stop detecting/attacking and go back to patrol
	# while the death anim + respawn play out.
	if p != null and p.has_method("is_dead") and p.is_dead():
		return null
	return p


## True while charmed into fighting for the player (see become_frenemy). Public so other enemies
## can tell (they don't attack a fellow frenemy) and a frenemy's attacks flip to hit enemies.
func is_frenemy() -> bool:
	return _frenemy_left > 0.0


## Who this enemy targets: the player normally, or -- while charmed -- the nearest OTHER (hostile)
## enemy, so a frenemy chases and attacks the mob instead of the player.
func _target() -> Node2D:
	if is_frenemy():
		return _nearest_hostile_enemy()
	return _player()


## The nearest live enemy that ISN'T us and ISN'T also a frenemy (so charmed allies don't fight
## each other). Null when there's nobody left to fight.
func _nearest_hostile_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if e == self or not (e is Node2D):
			continue
		if e.has_method("is_frenemy") and e.is_frenemy():
			continue
		var d := global_position.distance_squared_to((e as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = e as Node2D
	return best


## CHARM this enemy into a temporary ally for `duration` seconds: it fights the other enemies and
## its contact damage to the player switches off. Its attacks flip to hit enemies automatically
## (they read is_frenemy at spawn). Re-charming extends it. The frenemy special calls this.
func become_frenemy(duration: float) -> void:
	if duration <= 0.0 or _state == State.DEAD:
		return
	_frenemy_left = maxf(_frenemy_left, duration)
	if _contact_hitbox != null:
		_contact_hitbox.set_deferred("monitoring", false) # don't touch-hurt the player while allied


## The charm wore off -- back to a normal hostile enemy (re-arm contact next _tick_contact).
func _end_frenemy() -> void:
	_frenemy_left = 0.0


## MAGNET the enemy toward `anchor` (Come Closer special): AI is overridden and it's dragged in at
## `speed` px/s until within `arrive_dist`, then stunned for `stun_time`. No damage. See _physics_process.
func magnetize(anchor: Node2D, arrive_dist: float, speed: float, stun_time: float) -> void:
	if _state == State.DEAD or anchor == null:
		return
	_magnet_anchor = anchor
	_magnet_arrive = arrive_dist
	_magnet_speed = speed
	_magnet_stun = stun_time


## Apply a Hit directly (bypassing a physical hitbox) -- e.g. a shield's REFLECTED damage. Routes
## through the same hurt path as any attack.
func apply_hit(hit: Hit) -> void:
	if _hurtbox != null:
		_hurtbox.take_hit(hit)


func _face(dir: int) -> void:
	if dir == 0:
		return
	_facing = dir
	_sprite.flip_h = dir < 0 # sheets face right; flip when facing left


func _set_state(state: State) -> void:
	if _state == state:
		return
	_state = state
	match state:
		State.IDLE:
			_play(&"idle")
			_scratch_timer = idle_loop_time # fresh scratch loop each time he rests
			_scratch_full_cycle = false
			if _engaged: # combat: snap straight to the held ready-stance, no flicker
				_sprite.set_frame_and_progress(0, 0.0)
				_sprite.pause()
		State.STUN: _sprite.pause() # freeze on the current frame -- don't snap to idle
		State.PATROL: _play(&"patrol" if _has_patrol else &"idle")


func _play(anim: StringName) -> void:
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)
