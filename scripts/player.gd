@tool
extends Combatant
class_name Player

## A character-agnostic player.
##
## Every character shares the same animation set and the same normalised sprite
## canvas (see tools/gen_spriteframes.py), so switching is just swapping the
## SpriteFrames resource -- no per-character offsets or colliders needed.
## Pick one in the inspector, or call set_character(). The played character is chosen in
## RunManager (START_CHARACTER); in-game switching is gone.

## Emitted on every health change, and once on ready so UI can seed itself.
signal health_changed(current: float, maximum: float)
## Emitted on every Ruh (special-meter) change, and once on ready so the HUD can seed itself.
signal ruh_changed(current: float, maximum: float)
## Emitted when the active character changes, for portrait/name displays.
signal character_changed(id: String)

## Character roster + resource-path templates live in CharacterConfig; per-character
## attacks + specials in the Actions catalog (configs/actions_<char>.gd).

@export_enum("khalid")
var character: String = "khalid":
	set(value):
		character = value
		_apply_character()

@export_group("Health")
@export var max_health: float = 100.0:
	set(value):
		max_health = maxf(value, 1.0)
		health = minf(health, max_health)

var health: float = 100.0:
	set(value):
		var clamped := clampf(value, 0.0, max_health)
		if is_equal_approx(clamped, health):
			return
		health = clamped
		health_changed.emit(health, max_health)

@export_group("Ruh (surge meter)")
## Ruh is the "spirit" you spend on SURGES (each surge use costs its SurgeSpec.cost; specials are FREE).
## You START a run with 3 charges and refill by landing HITS (RUH_PER_HIT each -- not kills); it never
## decays, and is measured in CHARGES/BLOCKS (RUH_PER_BLOCK each). `ruh_cap` (raised by rewards) is the
## ceiling; consumables will top it up later.
const RUH_PER_BLOCK := 100.0 ## one HUD "block" = one charge (the default surge cost)
const RUH_PER_HIT := 20.0 ## Ruh gained per HIT landed (5 hits = 1 charge); collected by fighting, not killing
const MAX_RUH_CAP := 500.0 ## hard ceiling: 5 charges (rewards raise ruh_cap up to here)
## Short lag between special casts so a free special can't fire every single frame (a tiny anti-spam,
## not a real limiter -- specials cost no Ruh).
const SPECIAL_COOLDOWN := 0.6
@export var ruh_cap: float = 300.0: # 3 charges/blocks to start; rewards raise it toward MAX_RUH_CAP (5)
	set(value):
		ruh_cap = clampf(value, 0.0, MAX_RUH_CAP)
		ruh = minf(ruh, ruh_cap)

var ruh: float = 0.0:
	set(value):
		var clamped := clampf(value, 0.0, ruh_cap)
		if is_equal_approx(clamped, ruh):
			return
		ruh = clamped
		ruh_changed.emit(ruh, ruh_cap)

## Run-reward buffs applied on top of the character's base. `damage_mult` scales every hit
## (see resolve_tuning). All reset by begin_run() when a fresh run starts.
const BASE_RUH_CAP := 300.0 # start a run with 3 special charges (rewards raise the cap toward MAX)
const BASE_MAX_HEALTH := 100.0
## Where Khalid's own floating damage number spawns (local, feet at y=0 -> above his head). Tunable.
const HURT_NUMBER_OFFSET := Vector2(0, -40)
## Low-HP warning thresholds (fraction of max). A hit that drops health DOWN through one plays its cue
## once (`health_half` / `health_low`); the lower one wins if a single hit crosses both. Re-arms on heal.
const HEALTH_WARN_HALF := 0.5
const HEALTH_WARN_LOW := 0.2
var damage_mult: float = 1.0
## Run-speed multiplier from rewards (Fleetfoot), applied OVER the equipped run option's base so a
## loadout swap doesn't wipe the buff. Reset by begin_run().
var run_mult: float = 1.0
## Extra air jumps from rewards (Second Wind), added OVER the jump Locomotion's base air_jumps so a
## loadout swap doesn't wipe the buff -- same pattern as run_mult. Reset by begin_run().
var air_jump_bonus: int = 0
## --- reward buffs (all per-run, reset by begin_run). Placeholders: some fully wired, some just
## stored for now (marked WIP) so the reward is selectable + tunable later. ---
var damage_taken_mult: float = 1.0 ## Thick Hide: < 1 = take less damage (applied in take_damage)
var slam_damage_mult: float = 1.0 ## Meteor: > 1 = harder slams (applied in _slam_release)
var attack_reach_mult: float = 1.0 ## Long Arm: scales attack hitbox reach (resolve_tuning)
var attack_projectile_bonus: int = 0 ## Split Shot: +N projectiles -- WIP (stored, not yet spawned)
var impervious_until_hit: bool = false ## Last Stand: invuln until hit -- WIP (stored)
var special_radius_mult: float = 1.0 ## Wide Impact: scales special hit radius -- WIP for scene boxes
## Ids of the rewards taken THIS run (in pick order), the raw material for the queryable Build that
## conditional rewards predicate over (Build.of). Reset by begin_run; appended by record_reward().
var _rewards_taken: Array[String] = []
## The character's STARTING dash effect (the Emitters-config key fired on each dash). Every dash IS
## this effect; a reward swaps it for another. Its "Trail" node follows the player, its other nodes
## linger/etc (per-node, see ParticleDirector). >>> Flip this to "dash_crimson_vortex" to START with
## the vortex and test it without earning it. <<<
const STARTING_DASH_EFFECT := "dash_default"
## The active dash effect this run (swapped by a reward). Reset to STARTING_DASH_EFFECT by begin_run.
var _dash_effect: String = STARTING_DASH_EFFECT


## Start a BRAND-NEW run: clear every run-reward buff back to base, re-apply the character's base
## stats, refill to 100 HP / 0 Ruh, and play the spawn-in. Called by RunManager on death-restart
## and on run completion. (Per-level transitions do NOT call this -- life carries over there.)
func begin_run() -> void:
	_dead = false
	_death_finished = false
	_end_surge() # drop any active surge effect + aura on run restart
	_shake_left = 0.0
	if _sprite != null:
		_sprite.position = Vector2.ZERO
	_parry_left = 0.0
	damage_mult = 1.0
	run_mult = 1.0
	damage_taken_mult = 1.0
	slam_damage_mult = 1.0
	attack_reach_mult = 1.0
	attack_projectile_bonus = 0
	impervious_until_hit = false
	special_radius_mult = 1.0
	_dash_effect = STARTING_DASH_EFFECT # back to the starting dash; upgrades are re-earned each run
	special_invuln_bonus = 0.0
	ruh_cap = BASE_RUH_CAP
	air_jump_bonus = 0 # _apply_character below re-seeds max_air_jumps from the jump Locomotion
	_rewards_taken.clear() # fresh build for the new run
	max_health = BASE_MAX_HEALTH
	_loadout.clear() # back to the character's default (Typical) moves + movement
	_apply_character() # re-applies moves + run/jump/dash/slam/surge from the (now default) loadout
	health = max_health
	ruh = ruh_cap # START a run with a full meter -- 3 charges (BASE_RUH_CAP)
	velocity = Vector2.ZERO
	spawn()

# --- Movement runtime state -- SEEDED FROM CONFIG; do NOT set values here ---
# Every movement/physics value lives in typed config: the shared baseline in configs/locomotion.gd, with
# per-character deviations in each character's MOVEMENTS catalog (configs/actions_<char>.gd). On character
# change / swap, Player._apply_movement copies the equipped run/jump/dash/slam Locomotion INTO these vars
# (buffs then layer on top: run_mult, air_jump_bonus). They are declared with NO initial value on purpose
# -- they default to 0 and are overwritten before the first physics step, so a literal written here would
# be dead (this is the trap that made someone edit max_air_jumps in vain). To RETUNE, edit the Locomotion
# baseline or the character catalog -- never here. The trailing comments document what each value MEANS.
# run
var run_speed: float
var acceleration: float
var friction: float
var run_anim_speed: float ## run-cycle cadence vs ground speed (visual; >1 = busier legs)
# jump / vertical arc
var jump_velocity: float
var max_air_jumps: int ## the jump Locomotion's air_jumps + air_jump_bonus (buff); each air jump spawns particles
var gravity: float
var fall_gravity_scale: float ## >1 = falls faster than it rises (less floaty)
# dash
var dash_speed: float
var dash_time: float
var dash_cooldown: float
var dash_anim_time: float ## dash ANIMATION length, decoupled from the lunge (dash_time)
var dash_gravity_scale: float ## gravity kept during an air dash (0 = hang, 1 = fall normally)
# slam
var slam_speed: float
var slam_min_clearance: float ## min clear space below the feet to allow a slam (0 = always)
var slam_hold_frame: int ## slam frame to LOCK on during a tall plunge (sheet-relative)
var slam_impact_distance: float ## px above ground a held slam releases its impact frames
var slam_min_drop: float ## slam damage scales from mult 1.0 at this drop...
var slam_max_drop: float ## ...up to slam_max_damage_mult at this drop (lerped between)
var slam_max_damage_mult: float
# landing
var land_min_fall_speed: float ## min touchdown speed to play the landing squash
var land_predict_distance: float ## px above ground the LAND anim starts (plays through touchdown)

@export_group("Attack")
## How long the sprite holds on a hit frame before returning to idle, if the
## combo isn't continued. Short -- just enough to read the hit.
@export var attack_recovery: float = 0.12
## Grace period after a hit lands in which another press continues the combo
## instead of restarting it. Ticks on through idle, so you can chain after
## control returns; keep it >= attack_recovery.
@export var combo_reset_time: float = 0.45

## Max radians the double-jump exhaust tilts away from straight-down at full run speed
## (~34°). The puff leans opposite to horizontal travel; 0 = straight down. Tune to taste.
const DOUBLE_JUMP_LEAN := 0.6

enum State {IDLE, RUN, JUMP, DASH, ATTACK, SPECIAL, LAND, SLAM, FALL, DEATH, SPAWN, HURT, SURGE, LAUNCH}

# --- launch orbs (magnet traversal) -----------------------------------------
## A launch orb is a MAGNET, not a swing: while DASHING into an orb's pull area, Khalid is sucked to it
## and flung out the far side with the orb's OWN set impulse (a strong up + forward). Fully automatic --
## no aiming, no timing a press: any dash that enters the area triggers it. He keeps brief dash i-frames
## and can air-dash on. Detection is checked every dash frame over a generous body radius, so it's
## reliable (the old "press dash within a tiny hand range" was inconsistent).
const LAUNCH_PULL_RANGE := 96.0    ## dash within this of an orb (body centre -> orb) to be captured
const LAUNCH_BODY := Vector2(0.0, -20.0) ## his body centre relative to feet, for the range test + magnet
const LAUNCH_MAGNET_TIME := 0.08   ## seconds the magnet takes to suck him to the orb before the fling
const LAUNCH_CD := 0.45            ## no re-capture for a beat after a launch (or he'd re-trigger midair)

var _launch_orb: Node2D = null     ## the orb currently launching him (null = not launching)
var _launch_from := Vector2.ZERO   ## his position when captured (magnet lerps from here to the orb)
var _launch_t := 0.0               ## magnet timer
var _launch_vel := Vector2.ZERO    ## the orb's set fling velocity, resolved at capture (up + forward)
var _launch_cd := 0.0              ## counts down after a launch; blocks an instant re-capture
var _near_orb: Node2D = null       ## the orb currently lit as "in range" (drives its shine cue)

var _state: State = State.IDLE
var _facing: int = 1
## The active attack + special for this character (from the Actions catalog). They
## decide which animation plays and its hit tuning; swap them with equip(category, id).
## Seeded to the character's defaults on every character change.
var _current_attack: Action
var _current_special: Action
## The equipped SURGE (an ability on the `surge` button -- Aegis by default). Gated by Ruh, not a timer
## (each use spends its `cost`); seeded on character change / begin_run. See _try_surge.
var _current_surge: Action
## The equipped loadout: {category -> option_id} for attack/special/run/jump/dash/slam. Empty =
## every category on its default (Typical). Rewards call equip() to swap one; begin_run() clears
## it back to defaults. See configs/loadout.gd.
var _loadout: Dictionary = {}
## The resolved per-hit tuning of the attack/special currently swinging -- damage,
## knockback, stun, reach, and the lunge / super-armor / multi-hit knobs. Set at
## segment/special start via resolve_tuning() (the buff seam), and read by the
## ParticleDirector when it arms that attack's Hitbox -- so combat numbers live in
## the Actions catalog, not baked in the effect scene. Empty = no attack in progress (or a
## move that deliberately carries its own scene numbers, like the two finger-gun shots).
var _active_hit: Dictionary = {}
var _dash_left: float = 0.0
## Counts down the whole dash state (lunge + the animation's tail), so the frames
## finish playing after the lunge is over.
var _dash_anim_left: float = 0.0
var _dash_cd: float = 0.0
## True when this dash is a blink (teleport) instead of the glide-lunge -- seeded from the equipped
## dash Action's Locomotion (`move.blink`) on every character change / swap. When set, the lunge is
## skipped (the blink does the displacement); the dash animation + i-frames + cooldown still run as
## the "materialize".
var _dash_custom: bool = false
var _blink_dash: bool = false
## Blink stops at walls (move_and_collide). Flip true for a future "phase through walls"
## buff -- same buff-seam idea as a per-character behavior flag.
var _blink_phase_walls: bool = false
## Airborne tracking, so a touchdown can trigger the landing squash.
var _was_on_floor: bool = true
var _fall_peak: float = 0.0 # fastest downward speed reached this airborne stretch
## Highest point (min y) reached this airborne stretch, so a touchdown can report how far
## he DROPPED (landing y - apex y) to the ability's on_land -- e.g. a fall-damage ability.
var _apex_y: float = 0.0
## Air jumps spent since leaving the ground; reset on touchdown (see _physics_process).
var _air_jumps_used: int = 0
## True only when a jump was actually triggered, so the jump animation replays its
## launch. Entering JUMP just by being airborne (after a dash, walking off a ledge)
## leaves it false -- the anim then holds its last (fall) frame instead of relaunching.
var _jump_launch: bool = false
## True once a slam has released its impact frames (near the ground), so the held
## descent doesn't re-lock and the sprite stays shown while the impact plays out.
## True from the killing blow until begin_run(): input is frozen, the hurtbox is off, and the
## death animation plays. `_death_finished` flips once that animation reaches its end (it
## then holds the last frame) -- the level waits for death_complete() before respawning.
var _dead: bool = false
var _death_finished: bool = false
## The death anim is PAUSED on its first frame while the camera zooms + the world blacks out (the death
## cinematic in RunManager); `release_death()` unpauses it to play the rest out. See _enter(State.DEATH).
var _death_frozen: bool = false
var _slam_impacting: bool = false
## Feet-y at the moment the slam began, so the impact can scale damage by the plunge
## distance (global_position.y - _slam_start_y at release). See _slam_release.
var _slam_start_y: float = 0.0
var _just_landed: bool = false
## Which combo segment we're on (index into the attack's hit-frame list).
var _combo_step: int = 0
## Emitted frame the current segment ends on (the hit).
var _seg_end: int = 0
## True while a segment is animating; false while holding on its hit frame.
var _combo_playing: bool = false
## Time left to chain into the next segment (ticks through the hold and idle).
var _combo_window: float = 0.0
## Time left holding the current hit frame before control returns to idle.
var _recovery_left: float = 0.0
## A special press during a light swing, held until the current hit lands so a fast
## light->special cancels into the special instead of being swallowed by recovery.
var _buffered_special: bool = false
## An attack press during a DASH, held until the lunge finishes so dash->attack cancels the dash's
## recovery tail instead of the press being swallowed by the dash animation. See _process_dash.
var _buffered_attack: bool = false
## True while a "flurry" attack (Khalid's ora-ora) is held: the animation loops and its
## punch frames fire the hit every pass; releasing the button ends it. See _process_attack.
var _flurry: bool = false
## Time left frozen from a stun-carrying hit (input ignored).
var _stun_left: float = 0.0
## Time left of super-armor: while > 0, hits still hurt but don't stagger/interrupt.
## Granted by a Strike's tuning via set_armor() (a future buff/heavy-attack property).
var _armor_left: float = 0.0
## Time left the sprite is FROZEN on its current frame -- an attack/special holding its
## pose while a timed effect plays (the caster held on the cast frame while the effect
## emits). Set by hold_animation(); the sprite resumes when it hits 0.
var _hold_left: float = 0.0
## The active held/channeled effect while its emission plays, so a hit
## can break it (see _on_hurt). Null when nothing is being channeled.
var _channel: Strike = null
## Active PASSIVES -- the character's intrinsic ability (seeded first, if any) plus reward-granted
## passives added during the run (Player.add_passive). Each hook is dispatched to every entry. Reset to
## just the character ability on character change / run restart (see _seed_passives).
var _passives: Array[Passive] = []
## Active SURGE window: seconds left of the currently-triggered surge's effect (Player._begin_surge).
## While > 0 its effect flags below apply and its aura is shown; ticked down each physics frame.
var _surge_left: float = 0.0
## The active surge's effects (set on trigger, cleared at 0). Aegis -> invuln; Jnoon -> the two mults.
var _surge_invuln: bool = false            ## hurtbox off (untouchable) while the surge runs
var _surge_dmg_mult: float = 1.0           ## OUTGOING damage x this while the surge runs (Jnoon 2.0)
var _surge_dmg_taken_mult: float = 1.0     ## INCOMING damage x this while the surge runs (Jnoon 0.5)
var _surge_speed_mult: float = 1.0         ## MOVEMENT speed x this while the surge runs (Asra 2.0)
## Nem CHANNEL: a locking sleep/heal. `_surge_channel` marks it active; the anim winds up to the sleep
## frame then `_surge_asleep` flips (paused + healing for the window). Heal rises toward `_surge_heal_target`
## at `_surge_heal_rate` HP/s; a hit cancels it (keeps the health already gained). See _process_surge.
var _surge_channel: bool = false
var _surge_asleep: bool = false
var _surge_heal_target: float = 0.0
var _surge_heal_rate: float = 0.0
var _surge_sleep_frame: int = 0
## Wara REACTIVE surge: armed and waiting for an enemy hit (aura orbits, no timer). The hit that lands
## fires _trigger_wara (negate it, AoE-stun, burst) and consumes the surge. `_armed_surge` holds its spec.
var _surge_armed: bool = false
var _armed_surge: SurgeSpec = null
## Extra surge seconds from rewards (Fortitude: "+3s"). Reset by begin_run. Extends any surge's window.
var special_invuln_bonus: float = 0.0
## The aura VFX shown for the surge window (freed on expiry), or null.
var _special_aura: Node2D = null
## SHIELD (Redere Shield special): the player BLOCKS all front-side damage WHILE the shield special is
## up (see _is_shielding -- no lingering timer, so a hit after it drops lands normally). `_parry_left`
## is a SHORT window opened ONLY at the raise (cast): a hit blocked while it's still > 0 is a PERFECT
## PARRY and gets reflected. So just HOLDING the guard blocks; timing the raise right before a hit
## reflects. The hurtbox stays ACTIVE (unlike the pass-through invuln) so hits reach _on_hurt.
var _parry_left: float = 0.0
@export var parry_window: float = 0.25 ## seconds after RAISING the shield in which a block also REFLECTS (perfect parry)
@export var shield_reflect_mult: float = 1.0 ## reflected (parried) damage = incoming × this (0 = never reflect)
## Sprite VIBRATE when the shield takes a hit (a blocked/parried impact): a quick decaying jitter of
## _sprite.position. `_shake_left`/`_shake_dur` drive it in _physics_process; reset by begin_run.
var _shake_left: float = 0.0
var _shake_dur: float = 0.0
var _shake_amp: float = 0.0 ## amplitude of the CURRENT shake (set by _shake())
@export var shield_shake_amp: float = 4.0 ## px the sprite jitters on a shield hit
@export var shield_shake_time: float = 0.18 ## seconds the shield vibration lasts (decays to 0)
## FLINCH POLICY. true = Khalid plays the HURT flinch on ANY hit that lands. false = he only flinches on
## hits that STAGGER him (knockback > 0, e.g. mazab/ein/nasen) -- chip/ranged hits with no knockback
## (baghel, kebus) then just deal damage + a grunt, no anim interrupt. Toggle in the inspector or here.
@export var flinch_on_all_damage: bool = true
## Countdown until the next special can fire (SPECIAL_COOLDOWN), so specials can't be spammed.
var _special_cd: float = 0.0
## Countdown until the CURRENT attack can fire again -- only for a cooldown attack (Action.cooldown
## > 0, e.g. bakshen). While > 0 the attack press is ignored and the overhead bar fills; 0 = ready.
var _attack_cd: float = 0.0
## Small world-space bar over the head that fills as a cooldown attack recharges (hidden otherwise).
var _cooldown_bar: FloatingHealthBar = null
## Looping run footsteps -- a dedicated player we OWN (frees with the player, never orphaned as a
## stuck sound), toggled by the RUN state in _update_animation. Null in-editor / if the file's
## missing. Created via Sfx.make_loop.
var _run_sfx: AudioStreamPlayer = null
## Slam-descent whoosh (owned one-shot): played when the plunge starts, STOPPED when the ground impact
## fires so the impact "slam" overrides it. Null if the cue/file is missing. Created via Sfx.make_oneshot.
var _slam_down_sfx: AudioStreamPlayer = null
## Anti-strobe timer for the Ruh-absorb reaction: a cluster of souls arriving together folds into
## ONE surge instead of restacking (a full-charge soul surges anyway). See on_ruh_absorbed.
const RUH_FLASH_REFRACTORY := 0.2
var _ruh_flash_cd: float = 0.0
var _hair_tween: Tween = null
## Per-instance DUPLICATE of the tint material (so absorb tweens stay local and never write back to
## the shared .tres), plus the resting hair colours captured from it.
var _tint_mat: ShaderMaterial = null
var _body_is_lut := false  ## true when _tint_mat is the palette LUT (Khalid) vs the legacy hue-key tint
var _hair_base := {}
# Hair "absorb surge" palette -- the flowing hair gradient (base_red / accent_a / accent_b) smoothly
# lerps toward these as a Ruh soul lands, then eases back to rest. Play with the gradient here.
const HAIR_ABSORB_BASE := Color(2.6, 1.7, 0.5)
const HAIR_ABSORB_A := Color(2.3, 1.0, 0.35)
const HAIR_ABSORB_B := Color(1.9, 0.6, 0.25)
## Drives frame-indexed 2D particle effects; created at runtime (not in editor).
var _particles: ParticleDirector
## Combat boxes, built in code (like the particle director) to avoid a scene edit.
var _hurtbox: Hurtbox
var _status: StatusOverlay

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	health = max_health
	_apply_character()
	if Engine.is_editor_hint():
		return
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.animation_looped.connect(_on_animation_looped)

	_particles = ParticleDirector.new()
	add_child(_particles)
	_particles.setup(_sprite)
	_particles.set_character(character)

	_build_combat()
	_sprite.frame_changed.connect(_on_frame_changed)

	# Seed listeners that connected before _ready (the setters stay silent when
	# the value doesn't actually change, so the HUD would otherwise start blank).
	health_changed.emit(health, max_health)
	ruh_changed.emit(ruh, ruh_cap)
	character_changed.emit(character)


func _apply_character() -> void:
	# The setter can fire before the node tree exists (and again in the editor).
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return
	var path := CharacterConfig.FRAMES_PATH % character
	if not ResourceLoader.exists(path):
		push_warning("No SpriteFrames for character '%s' at %s" % [character, path])
		return
	sprite.sprite_frames = load(path)
	# Optional per-character sprite tint material -- e.g. Khalid's living-hair/metal shader. Convention:
	# res://resources/<id>_tint.tres. Missing file = no material (plain sprite).
	var mat_path := "res://resources/%s_tint.tres" % character
	# Duplicate the tint material so the hair-colour surge on a Ruh pickup stays instance-local and
	# never writes back to the shared .tres; capture the resting hair gradient to lerp from.
	if character == "khalid":
		# Khalid's sprite is repaletted to PaletteConfig's 36 shades, so he wears the material-aware
		# PALETTE LUT: it recolours from the run's chosen picks (PaletteConfig.picks, set at the picker
		# screen; empty = default look) AND carries the glow / hair-flow effects. Its hair_surge uniform
		# replaces the old base_red/accent lerp for the Ruh-absorb flare (see _set_hair_mix).
		_tint_mat = PaletteConfig.make_material()
		_body_is_lut = true
		sprite.material = _tint_mat
		_hair_base = {}
	else:
		# Other characters (legacy): optional res://resources/<id>_tint.tres hue-key tint, or plain.
		var mat: Material = load(mat_path) if ResourceLoader.exists(mat_path) else null
		_body_is_lut = false
		if mat is ShaderMaterial:
			_tint_mat = (mat as ShaderMaterial).duplicate()
			sprite.material = _tint_mat
			var br: Variant = _tint_mat.get_shader_parameter("base_red")
			var aa: Variant = _tint_mat.get_shader_parameter("accent_a")
			var ab: Variant = _tint_mat.get_shader_parameter("accent_b")
			_hair_base = {"base_red": br, "accent_a": aa, "accent_b": ab} if (br is Color and aa is Color and ab is Color) else {}
		else:
			_tint_mat = null
			_hair_base = {}
			sprite.material = mat
	# Seed the attack/special + movement stats from the current LOADOUT (defaults until a
	# reward swaps one in). This is the per-character feel + which moves are equipped.
	_apply_loadout()
	# The generator's canvas size changes whenever the art does, so derive the
	# offset from the frames rather than baking it into the scene.
	anchor_to_feet(sprite)
	# Attack frame counts differ per character, so a half-finished combo would
	# point at a frame the new character may not have.
	_combo_step = 0
	_combo_window = 0.0
	_combo_playing = false
	_buffered_special = false
	_buffered_attack = false
	_flurry = false
	_attack_cd = 0.0 # a fresh run/swap starts every attack ready (no leftover cooldown)
	# Drop back to idle: a state-specific animation (e.g. slam) may not exist on the
	# new character, and a swap is a clean slate anyway. Skip in the editor so a
	# preview character keeps whatever pose the scene is set to show.
	if not Engine.is_editor_hint():
		_state = State.IDLE
	sprite.speed_scale = 1.0
	sprite.play(_animation_for(_state))
	_seed_passives()
	if _particles != null: # null during the initial _ready pass; set up just after
		_particles.set_character(character)
	character_changed.emit(character)


# --- loadout (equipped moves + movement options) ----------------------------

## Seed the current attack/special + movement stats from `_loadout` (defaults where unset). Called
## on character change and after every equip(). Movement stats mirror the old per-character seeding
## when the loadout is empty, so nothing changes until a reward swaps something.
func _apply_loadout() -> void:
	_current_attack = Actions.get_action(character, "attacks", _loadout.get("attack", ""))
	_current_special = Actions.get_action(character, "specials", _loadout.get("special", ""))
	_current_surge = Actions.get_action(character, "surges", _loadout.get("surge", ""))
	for cat in Loadout.MOVEMENT_CATS:
		_apply_movement(cat, _loadout.get(cat, "default"))


## Seed the runtime movement vars for one category from its equipped movement Action's Locomotion.
## `category` is "run"/"jump"/"dash"/"slam"; `option_id` picks the option (default when unknown). Each
## category copies only its own fields; the run/air-jump buffs (run_mult, air_jump_bonus) layer on top
## so a swap doesn't wipe them.
func _apply_movement(category: String, option_id: String) -> void:
	var a := Actions.get_action(character, category, option_id)
	if a == null or a.move == null:
		return
	var m := a.move
	match category:
		"run":
			run_speed = m.run_speed * run_mult # buff survives a swap
			acceleration = m.acceleration
			friction = m.friction
			run_anim_speed = m.run_anim_speed
		"jump":
			jump_velocity = m.jump_velocity
			max_air_jumps = m.air_jumps + air_jump_bonus # buff survives a swap
			gravity = m.gravity
			fall_gravity_scale = m.fall_gravity_scale
			land_min_fall_speed = m.land_min_fall_speed
			land_predict_distance = m.land_predict_distance
		"dash":
			dash_speed = m.dash_speed
			dash_time = m.dash_time
			dash_cooldown = m.dash_cooldown
			dash_anim_time = m.dash_anim_time
			dash_gravity_scale = m.dash_gravity_scale
			_blink_dash = m.blink
		"slam":
			slam_speed = m.slam_speed
			slam_min_clearance = m.slam_min_clearance
			slam_hold_frame = m.slam_hold_frame
			slam_impact_distance = m.slam_impact_distance
			slam_min_drop = m.slam_min_drop
			slam_max_drop = m.slam_max_drop
			slam_max_damage_mult = m.slam_max_damage_mult


## Equip a loadout option in `category` (a reward swap). Re-seeds without a full character reset.
func equip(category: String, option_id: String) -> void:
	_loadout[category] = option_id
	_apply_loadout()
	if category == "attack" or category == "special":
		character_changed.emit(character) # nudge the HUD stats to redraw the new move/tier


## The equipped option id in a category (default when unset), for the HUD / rewards.
func loadout_id(category: String) -> String:
	return _loadout.get(category, Loadout.default_id(character, category))


## Swap options this character could be offered right now ([{category, option}]) -- categories with
## more than one option, minus what's already equipped. Rewards builds swap cards from this.
func loadout_choices() -> Array:
	return Loadout.swap_choices(character, _loadout)


## Rebuild the passive list for the current character: tear down any existing passives (run restart /
## character change drops reward passives), then seed the character's intrinsic ability FIRST if it has
## one (scripts/abilities/<id>.gd). Reward passives are re-added during the run via add_passive().
func _seed_passives() -> void:
	for p in _passives:
		p.teardown(self)
	_passives.clear()
	if Engine.is_editor_hint():
		return
	var path := CharacterConfig.ABILITY_PATH % character
	if not ResourceLoader.exists(path):
		return
	var ability: Variant = load(path).new()
	if ability is CharacterAbility:
		add_passive(ability)
	else:
		push_warning("%s must extend CharacterAbility" % path)


## Add a passive (a reward grant, or the character ability) and run its setup(). See Passive.
## REPLACE-IN-PLACE: if the new passive is a Buff with a non-empty `family`, any existing buff of that
## same family is torn down and removed first -- so a tiered upgrade supersedes its predecessor (Ricochet
## I -> II -> III) instead of stacking. Buffs with no family (and plain passives) never auto-replace.
func add_passive(p: Passive) -> void:
	if p is Buff and not (p as Buff).family.is_empty():
		var fam := (p as Buff).family
		for existing in _passives.duplicate():
			if existing is Buff and (existing as Buff).family == fam:
				existing.teardown(self)
				_passives.erase(existing)
	_passives.append(p)
	p.setup(self)


## Dispatched by RunManager when the player deals `amount` damage to `target` -- feeds the passive
## on_hit_dealt hook (lifesteal, on-hit procs, stacks). See Passive.on_hit_dealt.
func notify_hit_dealt(amount: float, target: Node) -> void:
	for p in _passives:
		p.on_hit_dealt(self, amount, target)


## Record that reward `id` was taken this run (feeds the Build). Rewards.apply calls this.
func record_reward(id: String) -> void:
	_rewards_taken.append(id)


## Rewards taken this run, in pick order (read by Build.of). A copy -- callers can't mutate the log.
func rewards_taken() -> Array:
	return _rewards_taken.duplicate()


## Read-only access to the state machine, for abilities and other systems.
func get_state() -> State:
	return _state


## The active attack / special Action (or null for a special-less character),
## for the HUD / debug panel / a future move-select UI.
func current_attack() -> Action:
	return _current_attack


func current_special() -> Action:
	return _current_special


## Does the current character's SpriteFrames have this animation (slam / fall / land)?
func has_anim(anim: StringName) -> bool:
	return _sprite != null and _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(anim)


## Attacks are grounded-only by default (no air attacks). The EXCEPTION is an attack tagged "air" -- it
## may be triggered mid-air (e.g. Zahluq, an air dash-attack). This is the air-attack allow-list: opt an
## attack in by giving its Action a "air" tag (configs/actions_<char>.gd). Checked at every attack gate.
func _air_attack_ok() -> bool:
	return _current_attack != null and _current_attack.tags.has("air")


## Total play time (seconds) of a one-shot animation -- the sum of each frame's real duration (frames
## carry a relative length, so hold_last / FRAME_DURATIONS are honoured), or 0 if it doesn't exist.
func _anim_duration(anim: StringName) -> float:
	if not has_anim(anim):
		return 0.0
	var sf := _sprite.sprite_frames
	var fps := sf.get_animation_speed(anim)
	if fps <= 0.0:
		return 0.0
	var total := 0.0
	for i in sf.get_frame_count(anim):
		total += sf.get_frame_duration(anim, i) / fps
	return total


## Fire a code-triggered particle burst by its the Emitters config key (a key that isn't a
## real sprite animation, so it only ever fires from code -- e.g. "double_jump",
## Khalid's "blink_out"/"blink_in"). Anchored in the world at the player's current spot.
func fire_effect(anim: String, tilt: float = 0.0) -> void:
	if _particles != null:
		_particles.fire_effect(anim, tilt)


## The blink (teleport) dash, used when the equipped dash is a blink (`move.blink`). Vanish and
## reappear `dash_speed * dash_time` ahead -- the SAME reach the glide-dash would cover,
## just instant -- with a blink-out poof where we leave and a blink-in poof where we land,
## plus a quick over-white flash. move_and_collide stops us at walls (enemies aren't on
## our body mask, so we pass through them); _blink_phase_walls flips that for a future buff.
## Called from _enter(State.DASH); _process_dash then skips the lunge and plays the tail.
func _do_blink() -> void:
	var motion := Vector2(dash_speed * dash_time * _facing, 0.0)
	fire_effect("blink_out") # poof at the spot we're leaving
	if _blink_phase_walls:
		global_position += motion
	else:
		move_and_collide(motion)
	velocity.x = 0.0 # a teleport carries no momentum; the dash tail re-derives it
	fire_effect("blink_in") # poof where we arrive
	# Brief over-white the world bloom picks up; cascades from the player to the sprite.
	modulate = Color(2.2, 2.2, 2.2)
	create_tween().tween_property(self, "modulate", Color(1, 1, 1), 0.18)


## Path to the current character's portrait, for HUD / character-select art.
func portrait_path() -> String:
	return CharacterConfig.PORTRAIT_PATH % (character.substr(0, 1).to_upper() + character.substr(1))


## Damage hits HP ONLY -- Ruh is not a shield (that's the whole point of the rework). Flash the
## hit tell; death when HP hits 0. The setter clamps and emits for the HUD.
func take_damage(amount: float) -> void:
	var dealt := amount * damage_taken_mult * _surge_dmg_taken_mult # Thick Hide reward + Jnoon surge (0.5x) reduce this
	var before := health
	health -= dealt
	_warn_low_health(before, health) # low-HP cue when this hit crosses a threshold downward
	# Pop a floating damage number over Khalid, tinted with his chosen PRIMARY (hair) colour so his own
	# HP loss reads like the enemy numbers but coloured to him. PaletteConfig.picks is the same source
	# that recolours his hair (default red when unpicked). Skip a non-damaging tick (0 / a heal).
	if dealt > 0.0:
		var hair: Color = PaletteConfig.picks.get("hair", Color(PaletteConfig.DEFAULT["hair"][0]))
		FloatingText.emit("player_damage", self, HURT_NUMBER_OFFSET, str(roundi(dealt)), dealt, {"color": hair})
	# Damage feedback: one of a few random hurt grunts (so he doesn't make the same noise every time),
	# pitch-wobbled for variety. The visible flinch is the HURT animation, played from _on_hurt when a
	# hit actually staggers him (a bare HP tick -- e.g. a future DoT -- just grunts, no anim interrupt).
	Sfx.play_random(["hurt.1", "hurt.2", "hurt.3"], 0.0, randf_range(0.95, 1.06))
	if health <= 0.0 and not _dead:
		_die()


## Play a low-HP warning when THIS hit dropped health down through a threshold (`old` -> `new` HP).
## Stateless: it fires only on the crossing, so it won't spam while you stay low, and re-arms on its
## own once a heal lifts you back above the line. The more urgent (lower) cue wins if a single big hit
## crosses both at once, so they never overlap. Death (HP 0) is its own sting, handled in _die.
func _warn_low_health(old_hp: float, new_hp: float) -> void:
	if max_health <= 0.0 or new_hp >= old_hp:
		return
	var old_r := old_hp / max_health
	var new_r := new_hp / max_health
	if old_r > HEALTH_WARN_LOW and new_r <= HEALTH_WARN_LOW:
		Sfx.play("health_low")
	elif old_r > HEALTH_WARN_HALF and new_r <= HEALTH_WARN_HALF:
		Sfx.play("health_half")


## Start a sprite SHAKE: `amp` px of decaying random jitter over `time` seconds (applied in
## _physics_process, snapped back to centre when done). A non-colour hit tell -- reused by the hurt
## flinch and the shield-hit vibrate. A stronger/fresh shake overrides a weaker one still in progress.
func _shake(amp: float, time: float) -> void:
	if time <= 0.0:
		return
	_shake_amp = amp
	_shake_dur = time
	_shake_left = time


## Restore HP (capped at max_health). The ONLY way to heal -- rewards call this. Never from Ruh.
func heal(amount: float) -> void:
	health = minf(health + amount, max_health)


## Bank Ruh for landing a HIT (not a kill). RunManager calls this on every hit the player deals. The
## setter caps at ruh_cap. Returns true if this hit completed a fresh charge (crossed a RUH_PER_BLOCK
## boundary), so the caller can play the soul-orb feedback only then instead of on every hit.
func gain_ruh_on_hit() -> bool:
	var before := ruh
	ruh += RUH_PER_HIT
	return floori(ruh / RUH_PER_BLOCK) > floori(before / RUH_PER_BLOCK)


## A Ruh soul just reached the body (RuhOrb on arrival): pulse a crimson flash on Khalid.
## `completed_charge` = this soul is the one that topped off a full charge, so it flashes brighter +
## longer (the meaningful beat). Rate-limited -- a plain soul is skipped while a pulse is still fresh
## (RUH_FLASH_REFRACTORY), so a cluster of simultaneous arrivals folds into one flash instead of
## strobing; a full-charge soul flashes regardless. (A future absorb SFX cue would fire here too.)
func on_ruh_absorbed(completed_charge: bool) -> void:
	if not completed_charge and _ruh_flash_cd > 0.0:
		return
	_ruh_flash_cd = RUH_FLASH_REFRACTORY
	# Surge Khalid's hair toward the absorb palette and smoothly back -- stronger + longer for the
	# soul that completes a full charge -- and play the absorb cue (pitched up a touch on a charge).
	_hair_surge(1.0 if completed_charge else 0.6, 0.6 if completed_charge else 0.35)
	Sfx.play("ruh_absorb", 0.0, 1.12 if completed_charge else 1.0)


## Smoothly lerp the hair gradient toward the absorb palette (0 -> `strength`) then ease it back to
## rest (-> 0) over `dur` via a mix factor. No-op if this character has no tint material.
func _hair_surge(strength: float, dur: float) -> void:
	if _tint_mat == null or (not _body_is_lut and _hair_base.is_empty()):
		return
	if _hair_tween != null and _hair_tween.is_valid():
		_hair_tween.kill()
	_hair_tween = create_tween()
	_hair_tween.tween_method(_set_hair_mix, 0.0, strength, dur * 0.35).set_ease(Tween.EASE_OUT)
	_hair_tween.tween_method(_set_hair_mix, strength, 0.0, dur * 0.65).set_ease(Tween.EASE_IN)


## Blend each hair colour `f` of the way from its resting value toward the absorb palette.
func _set_hair_mix(f: float) -> void:
	if _tint_mat == null:
		return
	if _body_is_lut:
		# The LUT flares the hair toward its baked hair_surge_color; one uniform drives the whole mix.
		_tint_mat.set_shader_parameter("hair_surge", f)
		return
	_tint_mat.set_shader_parameter("base_red", (_hair_base["base_red"] as Color).lerp(HAIR_ABSORB_BASE, f))
	_tint_mat.set_shader_parameter("accent_a", (_hair_base["accent_a"] as Color).lerp(HAIR_ABSORB_A, f))
	_tint_mat.set_shader_parameter("accent_b", (_hair_base["accent_b"] as Color).lerp(HAIR_ABSORB_B, f))


## Build the combat boxes and register on the "player" group so enemies find us.
func _build_combat() -> void:
	add_to_group("player")
	collision_layer = Combat.L_PLAYER_BODY
	collision_mask = Combat.L_WORLD

	_hurtbox = Hurtbox.new()
	_hurtbox.collision_layer = Combat.L_PLAYER_HURT
	_hurtbox.collision_mask = 0
	_hurtbox.add_child(Shapes.make_box(Vector2(16, 30), Vector2(0, -15)))
	add_child(_hurtbox)
	_hurtbox.hurt.connect(_on_hurt)

	# No built-in attack box any more: every attack is a spawned Strike/Projectile whose
	# own Hitbox carries the hit, fed from the Actions catalog via the director (see _active_hit).

	_status = StatusOverlay.new()
	add_child(_status)
	_status.setup(_sprite)

	# Overhead cooldown bar for a cooldown attack (bakshen). Same world-space FloatingHealthBar the
	# enemies use, tinted gold ("charge"); hidden until an attack is actually recharging.
	_cooldown_bar = FloatingHealthBar.new()
	_cooldown_bar.fill_color = Color(1.0, 0.08, 0.08)
	_cooldown_bar.position = Vector2(0, -52)
	_cooldown_bar.visible = false
	add_child(_cooldown_bar)

	# Looping run footsteps -- owned by us so it frees cleanly and never gets stuck playing. Runtime
	# only (autoloads/audio don't exist while editing the scene). Toggled in _update_animation.
	if not Engine.is_editor_hint():
		_run_sfx = Sfx.make_loop("run")
		if _run_sfx != null:
			add_child(_run_sfx)
		# Slam-descent whoosh -- owned so we can STOP it the instant the ground impact plays.
		_slam_down_sfx = Sfx.make_oneshot("slam_down")
		if _slam_down_sfx != null:
			add_child(_slam_down_sfx)


## THE BUFF SEAM. Resolve the effective per-hit tuning of `action`'s combo segment `seg`
## -- the numbers the attack's Hitbox is configured with. Today it's the base straight
## from the Actions catalog; the item/build system will later layer its modifiers here
## (damage x1.3, +reach, hits twice, ...) so every attack becomes buffable without
## re-plumbing. Set into _active_hit at segment/special start; read by the director.
func resolve_tuning(action: Action, seg: int = 0) -> Dictionary:
	var base: Dictionary = action.segment(seg).duplicate() # copy: never mutate the catalog
	# Buff/item/event modifiers fold in here. `damage_mult` is a run reward ("+X% damage").
	# `damage_mult` is a run reward; `_surge_dmg_mult` is the Jnoon surge (2x) -- they stack.
	var dmg_mult := damage_mult * _surge_dmg_mult
	if not is_equal_approx(dmg_mult, 1.0) and base.has("damage"):
		base["damage"] = float(base["damage"]) * dmg_mult
	# Long Arm reward scales reach for attacks that carry their hitbox size in tuning (ora_ora/bakshen);
	# scene-authored boxes (spear/ground_breaker) are unaffected for now.
	if not is_equal_approx(attack_reach_mult, 1.0):
		if base.has("extents"):
			base["extents"] = (base["extents"] as Vector2) * attack_reach_mult
		if base.has("x"):
			base["x"] = float(base["x"]) * attack_reach_mult
	# Per-move / shared BUFFS layer on last -- each passive gets to alter this move's numbers (a Buff
	# gates on action.id/.category/.tags via applies_to_action; a bare Passive no-ops). See Buff.
	for p in _passives:
		base = p.modify_tuning(self, action, seg, base)
	return base


## The resolved tuning of the attack currently swinging, for the ParticleDirector to
## feed into that attack's Hitbox. Empty when no attack is in progress.
func active_hit() -> Dictionary:
	return _active_hit


## True only while a shield-tagged special is actually up -- i.e. we're IN the SPECIAL state running
## that special. State-based (not a timer), so the guard drops the instant the state exits: releasing
## the button (-> IDLE) or being staggered from behind. A hit AFTER that lands as a normal hit, so the
## block cue never plays with the shield down. `_parry_left` (the reflect window) is only checked
## inside this gate, so it can't fire outside a shield either.
func _is_shielding() -> bool:
	return _state == State.SPECIAL and _current_special != null and _current_special.tags.has("shield")


## Take a hit: damage, optional shove, optional freeze/overlay.
## A dash grants i-frames (the hurtbox is off), so this only fires when vulnerable.
func _on_hurt(hit: Hit) -> void:
	# SHIELD (Redere Shield): block hits from the FRONT (the facing side) entirely and reflect them at
	# the attacker (a parry) -- but it's OPEN from behind, so a hit from the back side lands normally.
	if _is_shielding():
		var from_behind := hit.source is Node2D \
			and int(signf((hit.source as Node2D).global_position.x - global_position.x)) == -_facing
		if not from_behind:
			# PERFECT PARRY (parry window still open at the moment of the hit): reflect + a bright cue.
			# A plain hold just blocks with a duller cue -- neither takes damage.
			if _parry_left > 0.0:
				if shield_reflect_mult > 0.0 and hit.source is Enemy and hit.amount > 0.0:
					var back := Hit.new()
					back.amount = hit.amount * shield_reflect_mult
					back.knockback = 120.0
					back.source = self # credited to the player, so a reflect kill still banks Ruh
					(hit.source as Enemy).apply_hit(back)
				Sfx.play("redere_shield_parry") # perfect-parry cue (missing file = silent)
				for p in _passives:
					p.on_parry(self, hit) # parry-payoff buffs (e.g. heal-on-parry)
			else:
				Sfx.play("redere_shield_block") # standard block cue
			flash(_sprite) # block flash -- no damage taken (reflected or not)
			_shake(shield_shake_amp, shield_shake_time) # VIBRATE: the guard rattles from the impact
			return
		# hit from behind -> falls through and lands as a normal hit
	# Wara REACTIVE surge: the first enemy hit to land consumes it -- this hit deals NO damage, and it
	# fires the AoE stun + burst. Checked before take_damage so the triggering hit is fully negated.
	if _surge_armed and hit.source is Enemy:
		_trigger_wara()
		return
	take_damage(hit.amount)
	if _dead:
		return # the killing blow: death takes over -- no knockback/stun/reactions
	# Passives reacting to being hurt (retaliation, defensive buff, ...).
	for p in _passives:
		p.on_hurt(self, hit)
	# A hit mid-launch drops the magnet: cancel it so the knockback/flinch below apply as a normal
	# airborne stagger. (The i-frames during LAUNCH mean this is rare -- only a non-blocked source.)
	if _state == State.LAUNCH:
		_launch_orb = null
		_launch_cd = LAUNCH_CD
	# A held/channeled effect breaks when the caster is hit, if it opts in --
	# stop it and release the pose-hold. Independent of the ability hook above.
	if _channel != null and is_instance_valid(_channel) and _channel.interrupt_on_hurt:
		_channel.cancel()
		_hold_left = 0.0
		_sprite.play()
	_channel = null
	# A Nem sleep/heal channel is CANCELLED when hit -- he wakes, keeping the health already gained. The
	# flinch below (or idle, on a 0-stagger hit) takes over from the paused sleep pose.
	if _surge_channel:
		_end_surge()
		if _state == State.SURGE:
			_enter(State.IDLE)
	# Super-armor: the hit still hurts, but no knockback/stagger and the swing isn't
	# interrupted (a Strike granted it via set_armor from its tuning).
	if _armor_left > 0.0:
		return
	var stagger := apply_knockback(hit, _facing) # shove (may be 0 -- e.g. a ranged hit with no knockback)
	# FLINCH policy (see the flinch_on_all_damage export): react to EVERY hit, or only staggering ones.
	# Ranged enemy hits (baghel, kebus) carry knockback 0 + stun 0, so a stagger-only gate showed no
	# reaction at all on those (just damage + a grunt). Hold HURT for at least the whole flinch anim so a
	# tiny (or zero) stagger doesn't cut it short.
	if flinch_on_all_damage or stagger > 0.0:
		var flinch := maxf(stagger, _anim_duration(&"hurt"))
		if _state == State.HURT:
			# Already flinching (a barrage / multiple enemies): just extend it. Do NOT re-enter -- that
			# restarts the anim at frame 0 every hit, so it never plays through (looks frozen). One smooth
			# flinch plays and holds while he's pummelled.
			_stun_left = maxf(_stun_left, flinch)
		else:
			_stun_left = flinch
			_enter(State.HURT) # play the flinch anim (falls back to idle if he has no hurt sheet)
		# A stagger interrupts any swing -- clear ALL of its flags, or they leak into the new state.
		# `_flurry` especially: left true, it never gets cleared (that only happens inside _process_attack,
		# which no longer runs), so _advance_combo's `if not _flurry` guard blocks ora-ora forever after.
		_combo_playing = false
		_flurry = false
		_buffered_special = false
	if hit.status_color.a > 0.0:
		_status.show_for(hit.status_color, hit.status_time)
	# Dynamic per-attack hurt VFX, same channel enemies use (a stun effect, a slam shock, ...).
	# Placed by its own scene, relative to the player's feet (our origin).
	if hit.victim_vfx != null:
		spawn_victim_vfx(hit.victim_vfx, hit.victim_vfx_time)


## Shove the player forward along its facing -- a Strike's lunge (option A: the strike
## reaches back to its wielder). A brief burst; friction bleeds it off. Dormant until a
## move/buff sets a `lunge` in its tuning.
func apply_lunge(impulse: float) -> void:
	velocity.x = impulse * _facing


## Grant super-armor for `duration` seconds (see _on_hurt). Stacks by taking the longer.
func set_armor(duration: float) -> void:
	_armor_left = maxf(_armor_left, duration)


## Swap the active dash effect (an Emitters-config key fired on each dash -- see _enter). The seam a
## reward uses to UPGRADE the dash, e.g. "dash_crimson_vortex".
func set_dash_effect(effect: String) -> void:
	_dash_effect = effect


## Effective run/movement speed with the active surge's speed multiplier (Asra x2). The anim-rate + lean
## calcs keep using the BASE `run_speed`, so the run animation naturally plays faster (no moonwalk slide).
func _run_speed() -> float:
	return run_speed * _surge_speed_mult


## Begin a SURGE: apply its effect flags for `duration` (+ the Fortitude `special_invuln_bonus`) and
## engulf the player in its aura. Aegis grants invuln (hurtbox off, folded into _physics_process, same
## channel as dash i-frames); Jnoon sets the damage mults (hits land but hurt half, deal double). Effects
## run on the _surge_left timer and clear together in _end_surge. Re-triggering refreshes cleanly.
func _begin_surge(s: SurgeSpec) -> void:
	_end_surge() # clean refresh if re-triggered within the window
	_surge_invuln = s.invuln
	_surge_dmg_mult = s.damage_mult
	_surge_dmg_taken_mult = s.damage_taken_mult
	_surge_speed_mult = s.speed_mult
	_surge_channel = s.channel
	_surge_armed = (s.trigger == "hit")
	if _surge_armed:
		# A REACTIVE surge (Wara): arm it -- the aura orbits with NO timer until an enemy hit lands
		# (_on_hurt -> _trigger_wara). No immediate effect; the effect fires on that hit.
		_armed_surge = s
		_surge_left = 0.0
	elif s.channel:
		# A locking CHANNEL (Nem): don't start the window yet -- healing begins when the wind-up reaches
		# the sleep frame (see _process_surge). Heal pool = heal_frac of MAX hp, capped at max, so being
		# already >=50% hp reaches full ("restore the whole bar"). Interruptible -- health rises live.
		_surge_asleep = false
		_surge_left = 0.0
		_surge_heal_target = minf(health + s.heal_frac * max_health, max_health)
		_surge_heal_rate = (_surge_heal_target - health) / maxf(s.duration, 0.01)
		var anim := _current_surge.animation
		var fcount: int = _sprite.sprite_frames.get_frame_count(anim) if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(anim) else 0
		_surge_sleep_frame = maxi(fcount - 2, 0) # second-to-last emitted frame (head down, asleep)
	else:
		_surge_left = s.duration + special_invuln_bonus # passive buff runs immediately for the window
	if s.aura != "" and ResourceLoader.exists(s.aura):
		var scene := load(s.aura) as PackedScene
		_special_aura = scene.instantiate() as Node2D if scene != null else null
		if _special_aura != null:
			# Power-colour picks: the aura tints its moons from `moon_color` in code, so recolour that
			# property directly (the tree walk only catches baked particle colours). No-op without picks.
			if "moon_color" in _special_aura:
				_special_aura.moon_color = VfxPalette.recolor(_special_aura.moon_color)
			VfxPalette.recolor_tree(_special_aura)
			add_child(_special_aura)


## SURGE: an ability on the dedicated `surge` button (CTRL / RT). One press applies its timed self-buff
## (SurgeSpec). There is NO cooldown -- **RUH is the gate**: each use SPENDS `cost` Ruh, so you surge as
## long as you have Ruh (refilled by landing hits; specials are free). Aegis = invuln, Jnoon = 2x/half
## damage, both for `duration`. On trigger it plays a brief activation flex (State.SURGE, the "surge_<id>"
## sprite anim) + SFX. Fires in any state (checked in _physics_process); no-op while dead.
func _try_surge() -> void:
	if _dead or _current_surge == null or _current_surge.surge == null:
		return
	if _surge_channel or _surge_armed:
		return # can't re-surge while a channel (Nem) or a reactive surge (Wara) is already active
	if not Input.is_action_just_pressed("surge"):
		return
	var s := _current_surge.surge
	if ruh < s.cost:
		return # not enough Ruh -- the only gate; no cooldown
	ruh -= s.cost # spend it (the setter clamps + emits ruh_changed for the HUD)
	_begin_surge(s) # apply the effect flags + spawn the surge's aura for the duration
	flash(_sprite) # a quick activation pop on the sprite
	Sfx.play(String(_current_surge.animation)) # activation SFX ("surge_<id>"), silent until a file lands
	# Play the surge's activation flex (a brief committed state; the buff above runs on its own timer).
	# Skipped during death/spawn (materialize must finish) -- the buff still applied. No sheet -> no anim.
	if _state != State.SPAWN and has_anim(_current_surge.animation):
		_enter(State.SURGE)


## Tick down the active surge; end it (clear effects, drop the aura, re-enable the hurtbox) at 0.
## Called every physics frame.
func _tick_surge(delta: float) -> void:
	if _surge_left <= 0.0:
		return
	_surge_left -= delta
	if _surge_left <= 0.0:
		_end_surge()


## End the active surge: clear its effect flags and drop its aura. The hurtbox re-enables on its own next
## frame (_physics_process recomputes monitorable once _surge_invuln/_surge_left clear).
func _end_surge() -> void:
	_surge_left = 0.0
	_surge_invuln = false
	_surge_dmg_mult = 1.0
	_surge_dmg_taken_mult = 1.0
	_surge_speed_mult = 1.0
	_surge_armed = false
	_armed_surge = null
	if _surge_channel:
		_surge_channel = false
		_surge_asleep = false
		if _sprite != null:
			_sprite.play() # release the sleep-frame pause so normal playback resumes
	if is_instance_valid(_special_aura):
		var aura := _special_aura
		var tw := create_tween()
		tw.tween_property(aura, "modulate:a", 0.0, 0.3)
		tw.tween_callback(aura.queue_free)
	_special_aura = null


## Wara's payoff -- an armed enemy hit landed (the caller already negated its damage). AoE-stun every
## enemy within `stun_radius`, play the one-shot burst VFX where he stands, cue the trigger SFX, and
## consume the surge (which drops the orbit aura).
func _trigger_wara() -> void:
	var s := _armed_surge
	if s == null:
		_end_surge()
		return
	# Stun nearby enemies: a 0-damage Hit carrying only the stun (+ a faint tint), applied directly.
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Node2D
		if en == null or not en.has_method("apply_hit"):
			continue
		if global_position.distance_to(en.global_position) <= s.stun_radius:
			var h := Hit.new()
			h.stun = s.stun_time
			h.source = self
			h.status_color = Color(1.0, 0.85, 0.2, 0.6) # stun glint (placeholder)
			h.status_time = s.stun_time
			en.apply_hit(h)
	# Burst VFX: the AoE flash showing the affected area, at his feet, recoloured by the power picks.
	if s.burst != "" and ResourceLoader.exists(s.burst):
		var scene := load(s.burst) as PackedScene
		var burst := scene.instantiate() as Node2D if scene != null else null
		if burst != null:
			VfxPalette.recolor_tree(burst)
			add_child(burst)
			get_tree().create_timer(1.5).timeout.connect(burst.queue_free) # one-shot -> self-clean
	Sfx.play("surge_wara_trigger") # the "it fired" cue (missing file = silent)
	flash(_sprite)
	_end_surge() # drop the orbit aura + clear the armed state


## Freeze the sprite on its current frame for `duration` seconds, then resume -- so an
## attack/special can HOLD its pose while a timed effect plays out (a Strike with
## emit_duration calls this: the caster stays on the cast frame until the effect ends).
## The state machine keeps running (movement, gravity); only playback is paused, and the
## committed special won't end until its animation resumes and finishes.
func hold_animation(duration: float, effect: Strike = null) -> void:
	if duration <= 0.0 or _sprite == null:
		return
	_hold_left = maxf(_hold_left, duration)
	_channel = effect # remember it so a hit can break the channel (see _on_hurt)
	_sprite.pause()


# Land the special on its authored strike frame (hit_frames metadata), or, if the
# character didn't author one, on the middle frame as a sensible default.
func _on_frame_changed() -> void:
	if _state == State.SPECIAL:
		if _sprite.frame == _special_strike_frame():
			for p in _passives:
				p.on_special_strike(self)
		return
	# Bounded loop: when a looping animation has a `loop_to`, snap back to
	# `loop_from` the moment playback steps past it, so the cycle stays inside the
	# range (e.g. an idle that loops a mid-sheet range). Done here on the render frame it
	# changes -- not in physics -- so the past-the-range frame never flashes.
	var loop_to := _loop_meta(&"loop_to")
	if loop_to >= 0 and _sprite.frame > loop_to:
		_sprite.set_frame_and_progress(maxi(_loop_meta(&"loop_from"), 0), 0.0)


func _special_strike_frame() -> int:
	var hits := AnimMeta.hit_frames(_sprite.sprite_frames, _current_special.animation)
	if not hits.is_empty():
		return int(hits[0])
	@warning_ignore("integer_division")
	return _sprite.sprite_frames.get_frame_count(_current_special.animation) / 2


func is_dead() -> bool:
	return _dead


## True once the death animation has fully played out (and is now holding its last frame),
## so the level knows it can respawn. See run_manager (scripts/run/).
func death_complete() -> bool:
	return _dead and _death_finished


## Release the frozen death anim (paused on frame 0 by _enter(State.DEATH)) so it plays out. Called by
## RunManager once the camera has zoomed in + the world has blacked out. No-op if not frozen.
func release_death() -> void:
	if not _death_frozen:
		return
	_death_frozen = false
	if _sprite != null:
		_sprite.play() # resume from frame 0 -> plays through to the end (-> _death_finished)


## The killing blow landed. Freeze into the DEATH state: kill any swing/channel, turn the
## hurtbox off (no more hits), and play the death animation once -- the director fires the
## `death` particle from the Emitters config on its frames, like any other animation. The body
## still falls to the ground (see _process_death); begin_run() clears all this on a run restart.
func _die() -> void:
	if _dead:
		return
	_dead = true
	_death_finished = false
	Sfx.play("player_death") # death sting/tone (missing file = silent)
	_stun_left = 0.0
	_combo_playing = false
	_flurry = false
	_hold_left = 0.0
	_end_surge() # drop the surge effect + aura on death
	if _channel != null and is_instance_valid(_channel):
		_channel.cancel()
	_channel = null
	_launch_orb = null # cancel any in-progress orb launch on death
	if _hurtbox != null:
		_hurtbox.monitorable = false
	if has_anim(&"death"):
		_enter(State.DEATH)
	else:
		_death_finished = true # no death sheet -> nothing to play; respawn at once


## Dead: no input, just let the body settle to the ground while the death anim plays out.
func _process_death(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y += gravity * delta


## Spawning: no input, just settle onto the ground while the spawn (materialize) anim plays.
func _process_spawn(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y += gravity * delta


## Play the spawn (materialize) animation, then hand off to idle -- input is frozen and the
## hurtbox is off (spawn protection) until it finishes, so it always plays all the way out.
## Used on the initial spawn and every run restart (RunManager -> begin_run). A
## character with no `spawn` sheet just drops straight to idle.
func spawn() -> void:
	velocity = Vector2.ZERO
	if has_anim(&"spawn"):
		_enter(State.SPAWN)
	else:
		if _hurtbox != null:
			_hurtbox.monitorable = true
		_enter(State.IDLE)


## Switch to character `id` if it's a known one (swaps SpriteFrames + ability).
func set_character(id: String) -> void:
	if id in CharacterConfig.IDS:
		character = id


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_dash_cd = maxf(_dash_cd - delta, 0.0)
	_special_cd = maxf(_special_cd - delta, 0.0)
	_launch_cd = maxf(_launch_cd - delta, 0.0)
	_update_orb_proximity() # light up whichever launch orb is in range (its shine + cue)
	_try_surge() # SURGE: fires in ANY state on the `surge` button if you have the Ruh (no cooldown)
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_update_cooldown_bar()
	_ruh_flash_cd = maxf(_ruh_flash_cd - delta, 0.0)
	_armor_left = maxf(_armor_left - delta, 0.0)
	if _hold_left > 0.0:
		_hold_left = maxf(_hold_left - delta, 0.0)
		if _hold_left <= 0.0 and _sprite != null:
			_sprite.play() # resume the held animation where it left off
			_channel = null # channel finished on its own

	# Track the fall so a touchdown from a real drop (not a tiny hop) can squash, and so
	# the ability's on_land learns how far/fast he fell.
	var on_floor := is_on_floor()
	if not on_floor:
		if _was_on_floor:
			_apex_y = global_position.y # just left the ground -- start measuring the drop
		_fall_peak = maxf(_fall_peak, velocity.y) # +y is downward
		_apex_y = minf(_apex_y, global_position.y) # highest point reached (min y)
	_just_landed = on_floor and not _was_on_floor and _fall_peak >= land_min_fall_speed
	if on_floor and not _was_on_floor and not _passives.is_empty():
		var drop := maxf(global_position.y - _apex_y, 0.0)
		for p in _passives:
			p.on_land(self, drop, _fall_peak)
	if on_floor:
		_fall_peak = 0.0
		_air_jumps_used = 0 # refresh the double jump on every touchdown
	_was_on_floor = on_floor

	if _state == State.DEATH:
		_process_death(delta) # highest priority: death overrides stun and everything else
	elif _state == State.SPAWN:
		_process_spawn(delta) # materializing: frozen input until the spawn anim finishes
	elif _stun_left > 0.0:
		_process_stun(delta)
	elif _state == State.DASH:
		_process_dash(delta)
	elif _state == State.ATTACK:
		_process_attack(delta)
	elif _state == State.SPECIAL:
		_process_special(delta)
	elif _state == State.SURGE:
		_process_surge(delta)
	elif _state == State.SLAM:
		_process_slam(delta)
	elif _state == State.LAND:
		_process_land(delta)
	elif _state == State.LAUNCH:
		_process_launch(delta)
	else:
		# The combo only decays while you're not mid-swing.
		_combo_window = maxf(_combo_window - delta, 0.0)
		_process_normal(delta)

	# Runs after the state machine has set this frame's velocity but before it is
	# applied, so a passive can override any of it.
	for p in _passives:
		p.physics(self, delta)

	_tick_surge(delta) # count down the active surge; end it cleanly (clears effects + aura)
	_parry_left = maxf(_parry_left - delta, 0.0) # count down the perfect-parry (reflect) window -- NOT refreshed while held
	if _shake_left > 0.0: # sprite shake (hurt flinch / shield vibrate): decaying jitter, then snap home
		_shake_left = maxf(_shake_left - delta, 0.0)
		var amp := _shake_amp * (_shake_left / _shake_dur)
		_sprite.position = Vector2(randf_range(-amp, amp), randf_range(-amp, amp)) if _shake_left > 0.0 else Vector2.ZERO

	# Dash grants invulnerability: hitboxes/projectiles can't detect the hurtbox.
	# Only during the lunge (dash_time), not the animation's tail recovery, so the
	# i-frame window is unchanged by a longer dash_anim_time.
	if _hurtbox != null:
		# Off while dead, while spawning (protection so the materialize plays out), during the
		# dash i-frame window, and while an invuln SURGE (Aegis) is active.
		_hurtbox.monitorable = not _dead and _state != State.SPAWN and _state != State.LAUNCH \
			and not (_state == State.DASH and _dash_left > 0.0) \
			and not (_surge_invuln and _surge_left > 0.0)

	move_and_slide()
	_update_animation(delta)


## Stunned: no input, just ride out gravity and knockback momentum.
func _process_stun(delta: float) -> void:
	_stun_left -= delta
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = move_toward(velocity.x, 0.0, friction * 0.5 * delta)
	# Hold the HURT flinch for the whole stagger; any other stun just reads as idle. Either way, when
	# the timer lapses the dispatch falls through to _process_normal, which re-enters the right state.
	if _state != State.HURT:
		_state = State.IDLE


func _process_dash(delta: float) -> void:
	# LAUNCH ORB: a dash that enters an orb's pull area is captured -> magnet + fling (up/forward). Checked
	# every dash frame over a generous body radius, so dashing near/through an orb reliably triggers it.
	if _launch_cd <= 0.0:
		var orb := _orb_in_pull_range()
		if orb != null:
			_begin_launch(orb)
			return
	_dash_anim_left -= delta
	# Are we still holding the direction we dashed? Then the dash should blend into a
	# run, not brake to a stop and re-accelerate.
	var input := Input.get_axis("move_left", "move_right")
	var holding_dash_dir := input != 0.0 and signf(input) == float(_facing)

	# Dash-cancel into attack: an attack pressed any time during the dash is buffered and fires the
	# instant the lunge/i-frame window (_dash_left, = dash_time) finishes -- cancelling the recovery tail
	# -- so "dash then attack" is responsive instead of the press being swallowed by the dash animation.
	# Gated on _dash_left (NOT _dash_custom): a blink dash teleports instantly but still holds i-frames for
	# dash_time, so we wait those out before attacking rather than cancelling the dodge on frame one.
	if Input.is_action_just_pressed("attack"):
		_buffered_attack = true
	if _buffered_attack and _dash_left <= 0.0 and (is_on_floor() or _air_attack_ok()):
		_buffered_attack = false
		_advance_combo()
		if _state != State.DASH:
			return # an attack actually started -- leave the dash

	if _dash_custom:
		# The ability already displaced us (teleport). No lunge -- keep the i-frame
		# window ticking, and settle horizontal velocity toward a run (if held) or a
		# stop, so the exit flows the same as a normal dash.
		_dash_left = maxf(_dash_left - delta, 0.0)
		var target := _run_speed() * _facing if holding_dash_dir else 0.0
		velocity.x = move_toward(velocity.x, target, (dash_speed / dash_time) * delta)
	elif _dash_left > 0.0:
		_dash_left -= delta
		velocity.x = dash_speed * _facing # the lunge -- unchanged, still snappy
	else:
		# Lunge done: over the rest of the window, settle toward run speed if the player
		# is still holding this direction (so it flows straight into a run), otherwise
		# toward a stop -- while the dash frames finish either way.
		var target := _run_speed() * _facing if holding_dash_dir else 0.0
		var recovery := maxf(dash_anim_time - dash_time, 0.001)
		velocity.x = move_toward(velocity.x, target, (dash_speed / recovery) * delta)
	if is_on_floor():
		velocity.y = 0.0
	else:
		# Keep falling through an air dash, just lighter, so it arcs instead of
		# hanging in place on an invisible floor.
		velocity.y += gravity * dash_gravity_scale * delta
	if _dash_anim_left <= 0.0:
		# Exit straight into RUN when still holding the dash direction (velocity is
		# already at run speed) so there's no one-frame stop; otherwise IDLE.
		_enter(State.RUN if holding_dash_dir and is_on_floor() else State.IDLE)


func _process_normal(delta: float) -> void:
	var input := Input.get_axis("move_left", "move_right")

	if not is_on_floor():
		var g_scale := fall_gravity_scale if velocity.y > 0.0 else 1.0
		velocity.y += gravity * g_scale * delta

	if input != 0.0:
		_facing = 1 if input > 0.0 else -1
		velocity.x = move_toward(velocity.x, input * _run_speed(), acceleration * delta)
	else:
		# Standing still: keep facing the way we last moved (movement/controller drives
		# facing, not the mouse), so an attack goes where the character is actually facing.
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	# Special: on the ground it's the character's special; in the AIR it becomes the
	# ground slam instead (specials are grounded-only). A character with no slam sheet
	# simply can't act on the special button while airborne.
	if Input.is_action_just_pressed("special"):
		if is_on_floor() and _current_special != null:
			_start_special() # supersedes any light chain in progress
			return
		elif not is_on_floor() and _has_slam() and _slam_has_clearance():
			_enter(State.SLAM) # air special = ground slam (only with room below)
			return
	# Attacks are grounded-only, EXCEPT an "air"-tagged attack (the exception list -- see _air_attack_ok).
	if Input.is_action_just_pressed("attack") and (is_on_floor() or _air_attack_ok()):
		_advance_combo()
		return
	if Input.is_action_just_pressed("dash"):
		# Near a launch orb, dash captures it -> magnet + fling (checked here at the PRESS because Khalid's
		# dash is a blink/teleport that could skip past the area; _process_dash re-checks for a glide dash).
		if _launch_cd <= 0.0:
			var orb := _orb_in_pull_range()
			if orb != null:
				_begin_launch(orb)
				return
		if _dash_cd <= 0.0:
			_enter(State.DASH)
			return
	# `drop` (down by default): on the ground, fall through the one-way platform you're
	# standing on (a no-op on the solid floor). The slam is on the special button now
	# (see above), so drop does nothing in the air. Jump is just jump.
	if Input.is_action_just_pressed("drop") and is_on_floor():
		_drop_through_platform()
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = jump_velocity # ground jump -- no particles (air jump gets those)
			_jump_launch = true
			Sfx.play("jump")
		elif _air_jumps_used < max_air_jumps:
			_air_jump()

	if not is_on_floor():
		_set_airborne_state()
	elif _just_landed and _has_land():
		_enter(State.LAND)
	elif input != 0.0 and absf(velocity.x) > 5.0:
		# RUN only when the player is actually holding a move key -- residual velocity from a
		# dash-attack slide / knockback decelerates in IDLE instead of reading as a phantom run.
		_state = State.RUN
	else:
		_state = State.IDLE


## Pick the airborne animation state. Predictive LAND wins when we're dropping into
## the ground; otherwise JUMP while the launch/rise plays (then FALL, via
## _on_animation_finished), and FALL for any other way of leaving the ground.
func _set_airborne_state() -> void:
	if velocity.y >= land_min_fall_speed and _has_land() and _near_ground():
		_enter(State.LAND) # start the land early so it plays through touchdown
		return
	if _state == State.JUMP or _state == State.FALL:
		return # already airborne -- keep it (JUMP hands off to FALL when its anim ends)
	_state = State.JUMP if _jump_launch else _airborne_default()


## The passive airborne state: FALL if the character has a fall sheet, else JUMP (which
## just holds its last frame as a fall pose -- the old behaviour).
func _airborne_default() -> State:
	return State.FALL if _has_fall() else State.JUMP


# --- launch orbs (magnet traversal) -----------------------------------------

## The nearest orb whose centre is within `LAUNCH_PULL_RANGE` of Khalid's body, or null. Player-side
## detection: orbs live in the "orbs" group (see LaunchOrb); we pick the closest, like we scan "enemies".
func _orb_in_pull_range() -> Node2D:
	var body := global_position + LAUNCH_BODY
	var best: Node2D = null
	var best_d := LAUNCH_PULL_RANGE * LAUNCH_PULL_RANGE
	for o: Node in get_tree().get_nodes_in_group("orbs"):
		if not (o is Node2D):
			continue
		var d := body.distance_squared_to((o as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = o as Node2D
	return best


## Drive which orb is lit as "in range" this frame (its shine + proximity cue). Single source of the
## range test, so the orb stays dumb. Skipped while dead/spawning/launching.
func _update_orb_proximity() -> void:
	var near: Node2D = null
	if not _dead and _state != State.SPAWN and _state != State.LAUNCH:
		near = _orb_in_pull_range()
	if near == _near_orb:
		return
	if _near_orb != null and is_instance_valid(_near_orb) and _near_orb.has_method("set_near"):
		_near_orb.set_near(false)
	if near != null and near.has_method("set_near"):
		near.set_near(true)
	_near_orb = near


## Captured by a launch `orb`: enter the brief magnet phase (sucked to the orb) and resolve the orb's
## SET fling (a strong up + forward along his facing), applied when the magnet completes (_process_launch).
func _begin_launch(orb: Node2D) -> void:
	_launch_orb = orb
	_launch_from = global_position
	_launch_t = 0.0
	var up: float = orb.launch_up if "launch_up" in orb else 950.0
	var fwd: float = orb.launch_forward if "launch_forward" in orb else 650.0
	_launch_vel = Vector2(_facing * fwd, -up)
	velocity = Vector2.ZERO
	_enter(State.LAUNCH)
	if orb.has_method("play_use"):
		orb.play_use() # the orb's "used it" cue, at the orb (positional)


## Magnet phase: suck him to the orb over LAUNCH_MAGNET_TIME (position-driven, i-frames on), then FLING
## him out with the orb's set impulse and hand back to the airborne state (he keeps brief dash i-frames
## and can air-dash on). If the orb vanished (level torn down), just drop.
func _process_launch(delta: float) -> void:
	if not is_instance_valid(_launch_orb):
		_launch_orb = null
		_enter(_airborne_default())
		return
	_launch_t += delta
	var t := clampf(_launch_t / LAUNCH_MAGNET_TIME, 0.0, 1.0)
	# Suck his BODY centre onto the orb (so he passes through it), easing in.
	var target: Vector2 = (_launch_orb as Node2D).global_position - LAUNCH_BODY
	global_position = _launch_from.lerp(target, ease(t, 0.35))
	_update_animation(delta)
	if t >= 1.0:
		_launch_orb = null
		_launch_cd = LAUNCH_CD
		velocity = _launch_vel # the orb's set impulse: strong up + forward, out the far side
		if absf(velocity.x) > 5.0:
			_facing = 1 if velocity.x > 0.0 else -1
		_dash_left = maxf(_dash_left, 0.12) # keep brief i-frames -- "the rest of his dash" carries through
		_jump_launch = true # the JUMP/rise anim plays out of the fling
		_enter(_airborne_default())


## Drop through the one-way platform we're standing on: briefly ignore collisions
## with it so gravity pulls us down onto whatever's below. Only fires on an actual
## one-way platform (not the solid floor), so returns false there and a normal
## jump happens instead.
const DROP_THROUGH_TIME := 0.3

func _drop_through_platform() -> bool:
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider is Node and (collider as Node).is_in_group("oneway_platform"):
			add_collision_exception_with(collider)
			velocity.y = maxf(velocity.y, 60.0) # a nudge so we start dropping at once
			var body := collider
			get_tree().create_timer(DROP_THROUGH_TIME).timeout.connect(
				func() -> void:
					if is_instance_valid(body):
						remove_collision_exception_with(body))
			return true
	return false


## A mid-air jump (the double jump). Re-boosts upward, replays the launch pose, and
## -- unlike the silent ground jump -- spawns the character's jump particles: a
## code-triggered burst (combat-capable) under the "double_jump" key in the Emitters config,
## fired here so only air jumps produce it. Guarded by _air_jumps_used < max_air_jumps.
func _air_jump() -> void:
	velocity.y = jump_velocity
	_air_jumps_used += 1
	Sfx.play("jump")
	# The jump arrests the descent, so fall damage / the land squash should measure only
	# the NEW fall from here -- not the whole drop since he left the ground. Re-anchor the
	# apex and clear the peak speed; the rise after this re-raises the apex.
	_apex_y = global_position.y
	_fall_peak = 0.0
	# Go (back) to JUMP so the jump anim actually shows -- otherwise FALL/anim logic
	# reverts the sprite to `fall` the same frame. _jump_launch replays the launch.
	_jump_launch = true
	_enter(State.JUMP)
	_sprite.play(&"jump")
	_sprite.set_frame_and_progress(0, 0.0) # replay the launch from the top
	if _particles != null:
		# Tilt the exhaust OPPOSITE to horizontal travel (fling right -> puff kicks
		# down-left), scaled by how fast you're moving, so a sideways air-jump doesn't
		# spray straight down. 0 when moving straight up.
		var lean := clampf(velocity.x / maxf(run_speed, 1.0), -1.0, 1.0)
		_particles.fire_effect("double_jump", lean * DOUBLE_JUMP_LEAN)


## The landing animation -- it can start in the AIR (predictive, so it plays through
## touchdown) and finishes on the ground. Fully cancelable -- any action breaks out --
## so it never eats inputs; left alone it plays out and hands back to idle/run.
func _process_land(delta: float) -> void:
	if not is_on_floor():
		# Predictive pre-land: keep dropping while the anticipation plays. If we're no
		# longer heading into the ground (rose, or drifted off the edge), bail to the
		# air state so we don't "land" in mid-air.
		if velocity.y <= 0.0 or not _near_ground():
			_enter(_airborne_default())
			return
		velocity.y += gravity * fall_gravity_scale * delta
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		# Air-rule cancels (specials become the slam; attacks are grounded-only unless "air"-tagged).
		if Input.is_action_just_pressed("special") and _has_slam() and _slam_has_clearance():
			_enter(State.SLAM)
			return
		if Input.is_action_just_pressed("attack") and _air_attack_ok():
			_advance_combo()
			return
		if Input.is_action_just_pressed("dash"):
			if _launch_cd <= 0.0:
				var orb := _orb_in_pull_range()
				if orb != null:
					_begin_launch(orb) # near a launch orb -> magnet + fling instead of the dash
					return
			if _dash_cd <= 0.0:
				_enter(State.DASH)
				return
		if Input.is_action_just_pressed("jump") and _air_jumps_used < max_air_jumps:
			_air_jump() # enters JUMP itself
		return

	# Grounded recovery.
	if Input.is_action_just_pressed("special") and _current_special != null:
		_start_special()
		return
	if Input.is_action_just_pressed("attack"):
		_advance_combo()
		return
	if Input.is_action_just_pressed("dash") and _dash_cd <= 0.0:
		_enter(State.DASH)
		return
	if Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
		_jump_launch = true
		_state = State.JUMP
		return

	var input := Input.get_axis("move_left", "move_right")
	if input != 0.0: # walk straight out of the landing
		_facing = 1 if input > 0.0 else -1
		velocity.x = move_toward(velocity.x, input * _run_speed(), acceleration * delta)
		_state = State.RUN
		return
	velocity.x = move_toward(velocity.x, 0.0, friction * delta) # keep last facing when idle


func _has_land() -> bool:
	return _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(&"land")


func _has_fall() -> bool:
	return _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(&"fall")


## True when the ground is within `dist` px straight below -- used to start the LAND
## animation (and release the slam impact) just before touchdown. Same ray as the slam
## clearance check (our own collision_mask, so it catches solid ground AND one-way
## platforms). Defaults to `land_predict_distance`.
func _near_ground(dist := land_predict_distance) -> bool:
	if dist <= 0.0:
		return false
	var space := get_world_2d().direct_space_state
	if space == null:
		return false
	var q := PhysicsRayQueryParameters2D.create(
		global_position, global_position + Vector2(0.0, dist), collision_mask)
	q.exclude = [get_rid()]
	return not space.intersect_ray(q).is_empty()


func _process_attack(delta: float) -> void:
	# A DASH-ATTACK (a `lunge` in its tuning, e.g. Zahluq) flies STRAIGHT while it holds the strike frame:
	# its burst velocity stays CONSTANT (skip friction) so it covers a predictable distance (lunge x hold)
	# with the hitbox on him, and vertical is PINNED to 0 -- no gravity arc mid-air, so a slide triggered in
	# the air goes level. Gravity resumes the instant the dash ends. Every other attack is rooted: friction
	# bleeds any residual to a stop while gravity keeps air attacks falling.
	var dashing := _active_hit.has("lunge") and _recovery_left > 0.0
	if dashing:
		velocity.y = 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		if not is_on_floor():
			velocity.y += gravity * delta

	# A special pressed any time during the swing is remembered and fires the moment
	# the current hit lands -- so a fast light->special always cancels into the special
	# instead of the press being swallowed by the recovery frames.
	if Input.is_action_just_pressed("special"):
		_buffered_special = true

	# Flurry (Khalid's ora-ora): the animation loops on its own and its punch frames fire
	# the hit every pass; we just hold it while the button is down. A special still cancels
	# it; releasing attack ends it back to idle.
	if _flurry:
		if _buffered_special:
			_flurry = false
			_start_special()
		elif not Input.is_action_pressed("attack"):
			_flurry = false
			_enter(State.IDLE)
		return

	if _combo_playing:
		# Animate through the segment; freeze on the hit frame once reached.
		# Pin in case playback overshot the hit between physics ticks.
		if _sprite.frame >= _seg_end:
			_sprite.set_frame_and_progress(_seg_end, 0.0)
			_sprite.pause()
			_combo_playing = false
			# Hold the strike frame for `hold` s if the attack asks (a dash-attack holds the burst pose
			# for its whole slide); otherwise the short global recovery. Per-attack via the tuning.
			_recovery_left = maxf(attack_recovery, float(_active_hit.get("hold", 0.0)))
			_combo_window = combo_reset_time
			if _buffered_special: # cancel straight into the buffered special
				_start_special()
		return

	# Briefly hold the hit frame, then hand control back to idle. The chain
	# window keeps ticking there (see _physics_process), so you can still combo
	# after recovering -- the freeze doesn't have to outlast the whole window.
	if _buffered_special:
		_start_special()
		return
	if Input.is_action_just_pressed("attack"):
		_advance_combo()
		return
	_combo_window = maxf(_combo_window - delta, 0.0)
	_recovery_left -= delta
	if _recovery_left <= 0.0:
		if _active_hit.has("lunge"):
			velocity.x = 0.0 # a dash-attack stops crisply where its slide ends -- no run-off into idle
		_enter(State.IDLE)


## Commit to a special swing, clearing any light combo in progress. Shared by the
## normal/land states and by a light-attack cancel (see _process_attack).
func _start_special() -> void:
	if _special_cd > 0.0:
		return # still recharging (this special's cooldown, or the short anti-spam lag)
	# Specials are FREE (no Ruh -- that's Surges). Most just have the short anti-spam lag; a special can
	# set its OWN `cooldown` in the catalog (e.g. Come Closer's 3s) for a real gate -- take the larger.
	_special_cd = maxf(SPECIAL_COOLDOWN, _current_special.cooldown if _current_special != null else 0.0)
	# A "shield"-tagged special (Redere Shield) runs its OWN block+reflect window instead of the
	# pass-through invuln -- the hurtbox must stay active so incoming hits reach _on_hurt to be parried.
	var is_shield := _current_special != null and _current_special.tags.has("shield")
	# Cast-triggered passives react here (the hook stays for extensibility; Impervious is a Surge now).
	for p in _passives:
		p.on_special_cast(self, _current_special)
	if is_shield:
		# The guard is active for as long as we STAY in the shield special (see _is_shielding) -- no
		# lingering timer, so a hit after it drops lands normally. Only the perfect-parry (reflect)
		# window is timed: it opens NOW, at the raise, and is NOT refreshed while the guard is held.
		_parry_left = parry_window
	_combo_step = 0
	_combo_window = 0.0
	_combo_playing = false
	_buffered_special = false
	_active_hit = resolve_tuning(_current_special, 0) # feed the special's Hitbox
	# Hits dealt BY the special don't refill Ruh -- else a special would partly pay for itself and spam.
	# Attack hits fill it; see RunManager._on_enemy_damaged, which skips from_special hits.
	_active_hit["from_special"] = true
	_enter(State.SPECIAL)
	# Force-restart the special animation from frame 0. Mashing special re-enters SPECIAL the
	# same frame the previous one ended -- before _update_animation swaps the anim -- so the
	# sprite is already ON this animation but STOPPED on its finished last frame. The
	# name-equality check in _update_animation would then skip play() and we'd hang there
	# forever (animation_finished never re-fires, so the committed state never exits). Restart
	# explicitly so playback always runs and finishes.
	if _sprite != null and _current_special != null and has_anim(_current_special.animation):
		_sprite.play(_current_special.animation)
		_sprite.set_frame_and_progress(0, 0.0)


## Unlike the light combo, a special swing is committed: it plays the whole
## animation, ignores input, and ends via _on_animation_finished().
func _process_special(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	if not is_on_floor():
		velocity.y += gravity * delta
	# HELD guard (Redere Shield): while the special button is still held, FREEZE on the last frame
	# (shield up) instead of finishing the cast. The guard blocks the whole time we're in this state
	# (see _is_shielding), so there's no window to refresh here. Release -> drop it back to IDLE.
	if _current_special != null and _current_special.tags.has("held"):
		var last := _sprite.sprite_frames.get_frame_count(_current_special.animation) - 1
		if _sprite.frame >= last:
			if Input.is_action_pressed("special"):
				if _sprite.is_playing():
					_sprite.pause() # hold the guard pose -- the block stays up until release
			else:
				_active_hit = {} # released: end the special now -> IDLE drops the guard immediately
				_enter(State.IDLE)


## A SURGE activation: hold the flex pose, rooted, while gravity still applies (an air surge falls).
## Ends via _on_animation_finished -> idle. The surge's buff was applied on trigger and runs on its
## own timer, so this is purely the activation animation.
func _process_surge(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta) # rooted -- surges don't move
	if not is_on_floor():
		velocity.y += gravity * delta
	# Nem CHANNEL: wind up to the sleep frame, PAUSE there, then heal for the window. A hit cancels it
	# via _on_hurt (he wakes, keeps the health gained). Passive surges skip this and end on anim-finish.
	if _surge_channel:
		if not _surge_asleep:
			if _sprite.frame >= _surge_sleep_frame: # reached the head-down pose -> fall asleep
				_surge_asleep = true
				_sprite.set_frame_and_progress(_surge_sleep_frame, 0.0)
				_sprite.pause()
				_surge_left = _current_surge.surge.duration # the sleep/heal window starts NOW
		else:
			health = minf(health + _surge_heal_rate * delta, _surge_heal_target) # rise toward the target
			_surge_left -= delta
			if _surge_left <= 0.0: # slept the full window -> wake, fully healed
				_end_surge()
				_enter(State.IDLE)
		return


## An air-down ground slam: committed like a special. Horizontal drift bleeds off
## while the character plunges straight down at `slam_speed`.
##
## The catch is a TALL plunge: the slam animation would finish (firing its impact
## frames) long before touchdown, so the impact particles would emit in mid-air. So
## while high, we LOCK the animation on its last descent frame (`slam_hold_frame`) and
## HIDE the sprite -- only the sustained wind-streak particles show, reading as a fast
## blur. Then, once the ground is within `slam_impact_distance` (like the predictive
## land), we release: show the sprite and let the remaining impact frames play into the
## ground, so the impact burst fires where it lands. _on_animation_finished -> idle.
func _process_slam(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	# Once released, just let the impact frames play out (through touchdown -> idle).
	if _slam_impacting:
		velocity.y = 0.0 if is_on_floor() else maxf(velocity.y, slam_speed)
		return
	if is_on_floor() or _near_ground(slam_impact_distance):
		_slam_release() # close enough -- play the impact into the ground
		return
	# Still high: keep the fast plunge, and once the anim reaches the last descent
	# frame, lock it there so the impact can't fire yet, and hide the sprite.
	velocity.y = maxf(velocity.y, slam_speed)
	var hold := maxi(0, slam_hold_frame - _sheet_start(&"slam"))
	if _sprite.frame >= hold:
		_sprite.set_frame_and_progress(hold, 0.0)
		_sprite.speed_scale = 0.0
		_sprite.visible = false


## Release a held slam: show the sprite and resume playback so the impact frames run.
## The impact is imminent, so lock in the plunge-scaled damage now -- the director reads
## _active_hit when it fires the slam effect on the next frames and multiplies its
## hitboxes by our `damage_scale`.
func _slam_release() -> void:
	_slam_impacting = true
	_sprite.visible = true
	_sprite.speed_scale = 1.0
	if _slam_down_sfx != null:
		_slam_down_sfx.stop() # cut the descent whoosh -- the impact overrides it
	Sfx.play("slam") # ground-impact hit
	var drop := global_position.y - _slam_start_y # how far we plunged (px)
	var t := clampf((drop - slam_min_drop) / maxf(slam_max_drop - slam_min_drop, 1.0), 0.0, 1.0)
	_active_hit = {"damage_scale": lerpf(1.0, slam_max_damage_mult, t) * slam_damage_mult} # Meteor reward


## Sheet-relative -> emitted frame offset for `anim` (the generator drops the
## idle-reference frame 0 from action anims). Matches the numbering in the Emitters config.
func _sheet_start(anim: StringName) -> int:
	var sf := _sprite.sprite_frames
	if sf != null and sf.has_meta("sheet_start"):
		return int(sf.get_meta("sheet_start").get(String(anim), 0))
	return 0


func _has_slam() -> bool:
	return _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(&"slam")


## True when there's at least `slam_min_clearance` of clear space straight down before
## the nearest platform -- so a slam has room to build a real plunge. A ray from the
## feet down that distance (against whatever the body lands on -- solid ground AND
## one-way platforms, via our own collision_mask); no hit = clear. 0 clearance = always.
func _slam_has_clearance() -> bool:
	if slam_min_clearance <= 0.0:
		return true
	var space := get_world_2d().direct_space_state
	if space == null:
		return true
	var q := PhysicsRayQueryParameters2D.create(
		global_position, global_position + Vector2(0.0, slam_min_clearance), collision_mask)
	q.exclude = [get_rid()] # ignore our own body
	return space.intersect_ray(q).is_empty()


## One press = one combo segment: play the frames up to the next hit, then hold
## there. Each hit frame is a segment boundary (see the generator's HIT_FRAMES).
## Letting `combo_reset_time` lapse drops you back to the first segment; pressing
## past the finisher wraps to the start.
func _advance_combo() -> void:
	# A flurry attack doesn't chain segments -- the first press starts the held loop and
	# _process_attack runs it. Ignore re-presses once it's going.
	if _current_attack != null and _current_attack.is_flurry():
		if not _flurry:
			_start_flurry()
		return

	# A cooldown attack (Action.cooldown > 0, e.g. bakshen) can't be spammed: swallow the press
	# while it's still recharging. The overhead bar shows the fill; _attack_cd is set on fire below.
	if _current_attack != null and _current_attack.cooldown > 0.0 and _attack_cd > 0.0:
		return

	var hits := _attack_hits()
	if hits.is_empty():
		return
	_buffered_special = false # each swing starts with a clean buffer

	if _combo_window <= 0.0 or _combo_step >= hits.size():
		_combo_step = 0 # cold start, or wrap after the finisher
	var seg_start := 0 if _combo_step == 0 else int(hits[_combo_step - 1]) + 1
	_seg_end = int(hits[_combo_step])
	_combo_step += 1
	# Resolve THIS segment's hit now (before its frames play), so the director feeds the
	# right damage/reach into the Strike/Projectile it fires for this segment.
	_active_hit = resolve_tuning(_current_attack, _combo_step - 1)

	_combo_window = combo_reset_time
	_combo_playing = true
	_enter(State.ATTACK)
	_sprite.speed_scale = 1.0
	_sprite.play(_current_attack.animation)
	_sprite.set_frame_and_progress(seg_start, 0.0)
	# Start the recharge on a cooldown attack (bakshen): further presses are swallowed by the
	# gate above until _attack_cd hits 0. A cooldown attack is effectively a single-hit heavy.
	if _current_attack.cooldown > 0.0:
		_attack_cd = _current_attack.cooldown


## Start a held "flurry" attack: play the (looping) animation once and let it cycle. The
## director fires the punch effect on its punch frames every pass, so the hits come from
## the rate of the loop; _process_attack ends it when the button is released. Resolve the
## tuning once up front so each punch the director fires gets fed the same numbers.
func _start_flurry() -> void:
	_buffered_special = false
	_flurry = true
	_active_hit = resolve_tuning(_current_attack, 0)
	_enter(State.ATTACK)
	_sprite.speed_scale = 1.0
	_sprite.play(_current_attack.animation)


## Show + fill the overhead cooldown bar for a cooldown attack: empty the instant it fires,
## filling to full as `_attack_cd` counts down, then hidden once ready (or for any attack with no
## cooldown). Driven every physics frame from _physics_process.
func _update_cooldown_bar() -> void:
	if _cooldown_bar == null:
		return
	# Overhead recharge bar for whatever's currently on a real cooldown -- a cooldown SPECIAL (Come Closer)
	# takes it while it recharges, else a cooldown ATTACK (bakshen/zahluq). The short anti-spam lag on a
	# plain special (cooldown 0) never shows -- gated on `.cooldown > 0`.
	var cd := 0.0
	var left := 0.0
	if _current_special != null and _current_special.cooldown > 0.0 and _special_cd > 0.0:
		cd = _current_special.cooldown
		left = _special_cd
	elif _current_attack != null and _current_attack.cooldown > 0.0 and _attack_cd > 0.0:
		cd = _current_attack.cooldown
		left = _attack_cd
	if cd <= 0.0 or left <= 0.0:
		if _cooldown_bar.visible:
			_cooldown_bar.visible = false
		return
	_cooldown_bar.visible = true
	_cooldown_bar.set_ratio(1.0 - left / cd)


## Emitted frame indices that end each combo segment. From the SpriteFrames
## `hit_frames` metadata (written by the generator); falls back to every frame.
func _attack_hits() -> Array:
	var hits := AnimMeta.hit_frames(_sprite.sprite_frames, _current_attack.animation)
	if not hits.is_empty():
		return hits
	return range(_sprite.sprite_frames.get_frame_count(_current_attack.animation))


func _enter(state: State) -> void:
	_state = state
	_sprite.speed_scale = 1.0
	_sprite.visible = true # defensive: a held slam hides it; always restore on any entry
	match state:
		State.DASH:
			_dash_left = dash_time
			_dash_anim_left = maxf(dash_anim_time, dash_time)
			_dash_cd = dash_cooldown
			_buffered_attack = false # a fresh dash starts with no held attack
			Sfx.play("dash") # player-centric -- non-positional
			# Fire this dash's effect at the spot we're leaving (before the lunge/blink moves us). Its
			# "Trail" follows the player, the rest lingers here (see ParticleDirector). Clear _active_hit
			# first so a dropped Strike uses its OWN authored damage, not a stale attack's tuning.
			if _dash_effect != "":
				_active_hit = {}
				fire_effect(_dash_effect)
			# Play the dash animation over the (longer) visible window rather than
			# squeezing it into the brief lunge, so the frames are seen, not
			# fast-forwarded. Frame counts differ per character (4-6); stretching to
			# fit keeps every dash the same length.
			var frames := _sprite.sprite_frames
			var fps := frames.get_animation_speed(&"dash")
			if fps > 0.0:
				var anim_time := frames.get_frame_count(&"dash") / fps
				_sprite.speed_scale = anim_time / maxf(dash_anim_time, dash_time)
			# Blink characters teleport instead of gliding: do the displacement now, then
			# _process_dash skips the lunge and just plays the animation tail.
			_dash_custom = _blink_dash
			if _dash_custom:
				_do_blink()
		State.ATTACK:
			velocity.x = 0.0
		State.HURT:
			# A flinch: KEEP the knockback velocity (already applied), just (re)start the hurt anim from
			# frame 0 so a fresh hit re-flinches. No hurt sheet -> fall back to idle (the old behaviour).
			if has_anim(&"hurt"):
				_sprite.play(&"hurt")
				_sprite.set_frame_and_progress(0, 0.0)
			else:
				_state = State.IDLE
		State.SURGE:
			# A SURGE activation: play the surge's flex pose once (rooted), then _on_animation_finished
			# hands back to idle. The invuln/effect is already applied and runs on its own timer.
			velocity.x = 0.0
			if _current_surge != null and has_anim(_current_surge.animation):
				_sprite.play(_current_surge.animation)
				_sprite.set_frame_and_progress(0, 0.0)
			else:
				_state = State.IDLE # no flex sheet -> stay put, the buff still applied
		State.DEATH:
			velocity.x = 0.0 # collapse in place; _process_death lets the body fall
			# Freeze on the FIRST death frame while the camera zooms + the world blacks out (RunManager's
			# death cinematic); release_death() then plays the rest out. Setting the animation to "death"
			# here means _update_animation won't re-play it (already current), so the pause holds.
			_death_frozen = true
			_sprite.play(&"death")
			_sprite.set_frame_and_progress(0, 0.0)
			_sprite.pause()
		State.SPAWN:
			velocity.x = 0.0 # materialize in place; _process_spawn lets the body settle
		State.SLAM:
			# Commit: kill horizontal drift and start the downward plunge now.
			velocity = Vector2(0.0, slam_speed)
			_slam_impacting = false # fresh slam: not yet released into the impact
			_slam_start_y = global_position.y # measure the plunge from here for damage
			if _slam_down_sfx != null: # air oomph -- the descent whoosh (cut by the impact in _slam_release)
				_slam_down_sfx.play()
		State.LAUNCH:
			# Captured by a launch orb: keep the dash pose while the magnet sucks him through (_process_launch).
			_sprite.play(&"dash")


func _animation_for(state: State) -> StringName:
	match state:
		State.RUN: return &"run"
		State.JUMP: return &"jump"
		State.FALL: return &"fall"
		State.DASH: return &"dash"
		State.ATTACK: return _current_attack.animation
		State.SPECIAL: return _current_special.animation
		State.LAND: return &"land"
		State.SLAM: return &"slam"
		State.DEATH: return &"death"
		State.SPAWN: return &"spawn"
		State.HURT: return &"hurt"
		State.SURGE: return _current_surge.animation if _current_surge != null else &"idle"
		State.LAUNCH: return &"dash" # he's mid-dash being magneted through the orb
		_: return &"idle"


func _update_animation(_delta: float) -> void:
	_sprite.flip_h = _facing < 0
	# Run-loop footsteps: playing only while the RUN state shows (attacks, dashes, airborne, idle all
	# silence it). Owned player -> this just gates playback. Null in-editor, so it no-ops there.
	if _run_sfx != null:
		var running := _state == State.RUN
		if running != _run_sfx.playing:
			if running:
				_run_sfx.play()
			else:
				_run_sfx.stop()
	var next := _animation_for(_state)
	if _sprite.animation != next:
		_sprite.play(next)
		# `jump` doubles as the fall pose. Only replay its launch when a jump was
		# actually triggered; entering JUMP just by being airborne (a dash ended, or
		# you walked off a ledge) snaps to the last frame so it doesn't look like a
		# fresh jump you never asked for.
		if next == &"jump" and not _jump_launch:
			var jn := _sprite.sprite_frames.get_frame_count(&"jump")
			if jn > 0:
				_sprite.set_frame_and_progress(jn - 1, 0.0)
	if next == &"jump":
		_jump_launch = false # spent once the jump anim is showing

	# Keep the run cadence matched to actual ground speed so the legs don't
	# foot-slide (which reads as a smeary run). Other states keep their own rate:
	# dash sets a stretch in _enter, attacks stay 1x, so only touch these.
	match _state:
		State.RUN:
			# `run_speed` here is the BASE (unscaled by a surge), so a speed SURGE (Asra x2) lifts
			# velocity above it -> speed_ratio rises. The legs quicken (speed_scale), and the looping
			# footsteps pitch UP by the same speed_ratio so their tempo tracks how fast he's actually
			# moving (normal run == 1.0, unchanged; Asra ~2.0). Kept off run_anim_speed so the baseline
			# footstep sound is untouched.
			var speed_ratio := absf(velocity.x) / maxf(run_speed, 1.0)
			_sprite.speed_scale = clampf(speed_ratio * run_anim_speed, 0.4, 3.0)
			if _run_sfx != null:
				_run_sfx.pitch_scale = clampf(speed_ratio, 0.6, 3.0)
		State.IDLE, State.JUMP, State.FALL, State.LAND:
			_sprite.speed_scale = 1.0


## A looping animation can have an intro: `loop_from` metadata (written by the
## generator) marks the frame the cycle restarts at, so the lead-in plays once
## and only the tail repeats. e.g. a run that ignites over frames 0-3 then cycles 4-6.
## (A bounded `loop_to` is enforced in _on_frame_changed; this catches the case
## where the loop runs all the way to the last frame and wraps naturally.)
func _on_animation_looped() -> void:
	var start := _loop_meta(&"loop_from")
	if start > 0:
		_sprite.set_frame_and_progress(start, 0.0)


## Emitted-frame value from a loop metadata dict (`loop_from` / `loop_to`) for the
## animation currently playing, or -1 if unset.
func _loop_meta(key: StringName) -> int:
	return AnimMeta.loop_bound(_sprite.sprite_frames, _sprite.animation, String(key))


func _on_animation_finished() -> void:
	# Death played out: HIDE the sprite (the death particle just fired on this last frame,
	# so the character vanishes into the poof rather than the dead frame sitting there),
	# and tell the level it can respawn. begin_run()/_enter restores visibility.
	if _state == State.DEATH:
		_sprite.visible = false
		_death_finished = true
		return
	# Spawn (materialize) finished: hand control back to idle (hurtbox re-arms via the gate).
	if _state == State.SPAWN:
		_enter(State.IDLE)
		return
	# Jump's launch/rise is over: if we're still airborne, hand off to FALL (characters
	# with a fall sheet; others just hold the last jump frame -- no fall state).
	if _state == State.JUMP and not is_on_floor() and _has_fall():
		_enter(State.FALL)
		return
	# The land anim finished while still airborne (predicted too early / very slow fall):
	# drop back to the air state rather than snapping to idle in mid-air.
	if _state == State.LAND and not is_on_floor():
		_enter(_airborne_default())
		return
	# Light attack is a paused single frame; jump/fall loop or hold, so only dash, the
	# special swing, and the (grounded) landing end on playback finishing.
	if _state == State.DASH or _state == State.SPECIAL or _state == State.LAND or _state == State.SLAM:
		_active_hit = {} # the swing/slam already fired; don't let its tuning bleed onward
		_enter(State.IDLE)
	# The surge activation flex played out -> hand back to idle (or the air state if airborne).
	if _state == State.SURGE:
		_enter(_airborne_default() if not is_on_floor() else State.IDLE)
