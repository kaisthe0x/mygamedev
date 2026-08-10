class_name Locomotion
extends RefCounted

## The "Locomotion" component of a movement Action (run / jump / dash / slam) -- the third composable
## capability beside `StrikeSpec` (a hit) and abilities. Pure typed code-config: it holds every
## movement/physics knob, so NOTHING movement-related lives on the Player as an inspector `@export`
## anymore. The Player seeds its runtime movement vars from the equipped movement Actions' Locomotions
## (Player._apply_movement), one category at a time -- each category reads only its own fields.
##
## The values below are the shared BASELINE (what every character gets by default). A character's
## catalog (configs/actions_<char>.gd `MOVEMENTS`) lists only the fields it DEVIATES on -- e.g. Khalid
## runs faster and blink-dashes -- via each movement Action's `move` dict; `make()` overlays those.

# --- run (ground locomotion) ---
var run_speed: float = 160.0          ## top ground speed, px/s
var acceleration: float = 1200.0      ## px/s^2 ramp up to run_speed
var friction: float = 1400.0          ## px/s^2 decel to a stop
var run_anim_speed: float = 1.5       ## run-cycle cadence relative to ground speed (visual; >1 = busier legs)

# --- jump / vertical arc / landing ---
var jump_velocity: float = -330.0     ## launch velocity, px/s (negative = up)
var air_jumps: int = 2                ## extra mid-air jumps after the ground jump (1 = a double jump)
var gravity: float = 900.0            ## downward accel, px/s^2
var fall_gravity_scale: float = 1.35  ## gravity multiplier while falling (>1 = less floaty arc)
var land_min_fall_speed: float = 140.0    ## min touchdown speed to play the landing squash
var land_predict_distance: float = 22.0   ## px above ground the LAND anim starts, so it plays through touchdown

# --- dash ---
var dash_speed: float = 420.0         ## lunge speed, px/s
var dash_time: float = 0.18           ## lunge duration, s
var dash_cooldown: float = 0.45       ## s before the next dash
var dash_anim_time: float = 0.30      ## how long the dash ANIMATION plays (decoupled from the lunge)
var dash_gravity_scale: float = 0.35  ## gravity kept during an air dash (0 = hang, 1 = fall normally)
var blink: bool = false               ## true = the dash is an instant teleport (blink_out/in poofs), not a glide-lunge

# --- slam (air-down ground pound) ---
var slam_speed: float = 1200.0        ## downward plunge speed, px/s
var slam_min_clearance: float = 50.0  ## min clear space below the feet to allow a slam (0 = always)
var slam_hold_frame: int = 2          ## slam anim frame to lock on during a tall plunge (sheet-relative)
var slam_impact_distance: float = 30.0    ## px above ground a held slam releases its impact frames
var slam_min_drop: float = 120.0      ## drop <= this deals base slam damage (mult 1.0)
var slam_max_drop: float = 700.0      ## drop >= this reaches slam_max_damage_mult
var slam_max_damage_mult: float = 2.5 ## slam damage multiplier at slam_max_drop (lerped from 1.0)


## Build a Locomotion, overlaying only the fields a catalog `move` dict specifies (the rest keep the
## baseline above). Grouped by category so a movement Action lists just its own knobs.
static func make(d: Dictionary) -> Locomotion:
	var m := Locomotion.new()
	# run
	m.run_speed = float(d.get("run_speed", m.run_speed))
	m.acceleration = float(d.get("acceleration", m.acceleration))
	m.friction = float(d.get("friction", m.friction))
	m.run_anim_speed = float(d.get("run_anim_speed", m.run_anim_speed))
	# jump / arc / land
	m.jump_velocity = float(d.get("jump_velocity", m.jump_velocity))
	m.air_jumps = int(d.get("air_jumps", m.air_jumps))
	m.gravity = float(d.get("gravity", m.gravity))
	m.fall_gravity_scale = float(d.get("fall_gravity_scale", m.fall_gravity_scale))
	m.land_min_fall_speed = float(d.get("land_min_fall_speed", m.land_min_fall_speed))
	m.land_predict_distance = float(d.get("land_predict_distance", m.land_predict_distance))
	# dash
	m.dash_speed = float(d.get("dash_speed", m.dash_speed))
	m.dash_time = float(d.get("dash_time", m.dash_time))
	m.dash_cooldown = float(d.get("dash_cooldown", m.dash_cooldown))
	m.dash_anim_time = float(d.get("dash_anim_time", m.dash_anim_time))
	m.dash_gravity_scale = float(d.get("dash_gravity_scale", m.dash_gravity_scale))
	m.blink = bool(d.get("blink", m.blink))
	# slam
	m.slam_speed = float(d.get("slam_speed", m.slam_speed))
	m.slam_min_clearance = float(d.get("slam_min_clearance", m.slam_min_clearance))
	m.slam_hold_frame = int(d.get("slam_hold_frame", m.slam_hold_frame))
	m.slam_impact_distance = float(d.get("slam_impact_distance", m.slam_impact_distance))
	m.slam_min_drop = float(d.get("slam_min_drop", m.slam_min_drop))
	m.slam_max_drop = float(d.get("slam_max_drop", m.slam_max_drop))
	m.slam_max_damage_mult = float(d.get("slam_max_damage_mult", m.slam_max_damage_mult))
	return m
