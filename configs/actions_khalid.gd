class_name ActionsKhalid

## Khalid's ACTION catalog -- PURE DATA (no logic; the `Actions` accessor turns these rows into typed
## Action objects). One table per category; each row is an Action.make() dict:
##   name    -- UI label (id, the dict key, is the code reference)
##   icon    -- res:// picker / reward-card art (embedded per action; retires configs/icons.gd's attack/special rows)
##   tier    -- typical / elite / broken (loadout rarity + swap filtering)
##   style   -- standard (default) / flurry / cooldown  (see Action.Style)
##   cooldown-- seconds between uses (0 = none)          (COOLDOWN cadence, e.g. bakshen)
##   animation - only when it differs from "<attack|special>_<id>" (particles + sounds key off it)
##   hit     -- the StrikeSpec: { type, segments }. OMIT when the effect scene carries its own numbers.
##             segments = one dict (single hit) OR an array (one per combo segment). Numbers here are
##             the SINGLE source of the hit -- the director feeds them into the effect's own Hitbox at
##             spawn (Player.resolve_tuning -> ParticleDirector._inject_tuning), nothing baked in a .tscn.
##
## Presentation lives elsewhere, keyed by `animation`: particles in vfx/config/emitters_characters.gd,
## sounds in configs/sfx_characters.gd. To retune a hit, edit its `segments` here and nowhere else.

const ATTACKS := {
	# Ora Ora: a rapid punch FLURRY -- hold attack and the anim loops fast, each punch frame firing the
	# attack_ora_ora Strike (its fist Hitbox carries the hit). Low per-punch damage -- DPS = the rate.
	"ora_ora": {
		"name": "Ora Ora", "icon": "res://vfx/shared/textures/pixel_ember.png", "style": "flurry",
		"hit": {"type": "melee", "segments": {"damage": 15, "knockback": 0, "stun": 0.1, "extents": Vector2(32, 22)}},
	},
	# Spear: a committed 3-hit combo -- thrust, thrust, big spinning finisher (strongest). Each hit fires
	# its own particle burst; damage per segment below.
	"spear": {
		"name": "Spear", "icon": "res://vfx/shared/textures/blast1.png", "tier": "elite",
		"hit": {"type": "melee", "segments": [
			{"damage": 10, "knockback": 40}, # thrust
			{"damage": 20, "knockback": 60}, # thrust
			{"damage": 35, "knockback": 140}, # finisher (strongest)
		]},
	},
	# Bakshen: a charged slash -- ~1s wind-up then one heavy hit on the last frame. COOLDOWN cadence
	# (can't be spammed; shows the overhead recharge bar). Big single payoff.
	"bakshen": {
		"name": "Bakshen", "icon": "res://vfx/shared/impervious/bolt.png", "tier": "elite",
		"style": "cooldown", "cooldown": 3.0,
		"hit": {"type": "melee", "segments": {"damage": 65, "knockback": 0, "stun": 0.0}},
	},
	# Zahluq: a burst-forward DASH-ATTACK -- Khalid slides forward at great speed for a set distance,
	# damaging everything he passes (its Strike + hitbox FOLLOW him during the slide -- see the emitter
	# row's `follow`). COOLDOWN cadence (3s, overhead recharge bar); a big single hit, but LESS than
	# bakshen. The `lunge` tuning IS the slide (friction bleeds it off into a decelerating dash);
	# `super_armor` commits the dash so a hit mid-slide won't stagger him out of it. Tune to taste.
	"zahluq": {
		"name": "Zahluq", "icon": "res://vfx/shared/impervious/bolt.png", "tier": "elite",
		"style": "cooldown", "cooldown": 3.0, "tags": ["air"], # "air" -> usable mid-air (see Player._air_attack_ok)
		"hit": {"type": "melee", "segments": {
			"damage": 45, "knockback": 90, "stun": 0.2,
			# lunge = burst speed; hold = seconds the burst pose is held while the hitbox rides ON him.
			# Constant-velocity dash, so distance ~= lunge x hold (~1100 x 0.4 = ~440px). super_armor
			# commits it. extents are wide + tall so the box surrounds him as he slides through enemies.
			"lunge": 1100.0, "hold": 0.4, "super_armor": 0.4, "extents": Vector2(40, 28),
		}},
	},
	# Cherry Shots: a two-shot laser volley -- a small bolt then a bigger/stronger one (2-segment combo,
	# one press each). The director spawns the per-frame Projectile scenes; damage per shot below.
	"cherry_shots": {
		"name": "Cherry Shots", "icon": "res://vfx/shared/textures/soft_dot.png", "tier": "elite",
		"hit": {"type": "projectile", "segments": [
			{"damage": 4, "knockback": 0}, # small bolt
			{"damage": 7, "knockback": 0}, # big bolt (stronger)
		]},
	},
	# Twin Reaper: a spinning FLURRY -- hold attack and the spin loops, each pass firing its Slash nodes.
	# Like ora_ora a flurry feeds ONE tuning to every hit (knockback 0 keeps them caught in the spin).
	"twin_reaper": {
		"name": "Twin Reaper", "icon": "res://vfx/shared/textures/blast1.png", "tier": "elite", "style": "flurry",
		"tags": ["reaper"], "hit": {"type": "melee", "segments": {"damage": 12, "knockback": 0}},
	},
	# Dual Executioner: an INDEPENDENT attack (no longer an upgrade of Twin Reaper) -- selectable at run
	# start and as an attack reward (configs/rewards_catalog.gd), upgraded via its OWN buffs. Its OWN
	# animation (attack_dual_executioner, default for this id), so it carries its own particles
	# (EmittersCharacters) + sounds (SfxCharacters) -- a beefier spin, deadlier per hit. The sprite sheet
	# stands in on Twin Reaper's spin until reskinned.
	"dual_executioner": {
		"name": "Dual Executioner", "icon": "res://vfx/shared/textures/blast1.png", "tier": "broken",
		"style": "flurry", "tags": ["reaper"],
		"hit": {"type": "melee", "segments": {"damage": 22, "knockback": 0, "stun": 0.3}},
	},
}

const SPECIALS := {
	# Ground Breaker: an overhead slam that cracks the ground -- an AOE Strike whose hitbox SHAPE is
	# authored in special_ground_breaker.tscn, fed these numbers.
	"ground_breaker": {
		"name": "Ground Breaker", "icon": "res://vfx/shared/textures/blast1.png",
		"hit": {"type": "aoe", "segments": {"damage": 40, "knockback": 160, "stun": 1.0,
			"victim_effect": "res://vfx/status/ground_breaker_stun.tscn"}},
	},
	# Frenemy: a short blast that CHARMS the enemy -- for `frenemy` seconds it becomes a temporary ALLY,
	# stops targeting the player, and fights the OTHER enemies instead (not stunned). A red aura
	# (victim_effect) surrounds it while charmed. A control/utility special.
	"frenemy": {
		"name": "Frenemy", "icon": "res://vfx/shared/textures/pixel_ember.png", "tier": "elite",
		"tags": ["charm"], # build tag -- reward synergies key off it (e.g. reach ×3, see rewards_catalog)
		"hit": {"type": "blast", "segments": {"damage": 4, "knockback": 0, "frenemy": 8.0,
			"victim_effect": "res://vfx/status/frenemy_stun.tscn", "victim_time": 8.0}},
	},
	# Come Closer: a magnet pull -- drags nearby enemies in front of Khalid and STUNS them on arrival
	# (no damage). No `hit`; the magnet FIELD scene (EmittersCharacters -> scripts/combat/magnet_field.gd)
	# + Enemy.magnetize() do the work. Tune range/stun/speed on that field scene.
	"come_closer": {
		"name": "Come Closer", "icon": "res://vfx/shared/textures/pixel_ember.png", "tags": ["control"],
	},
	# Redere Shield: a HELD guard -- hold the special button to keep it up. BLOCKS all front-side damage
	# (open from behind); a hit taken in the brief PARRY window right after RAISING it is reflected (a
	# perfect parry), but just holding only blocks. No `hit`; player-side (the "shield"/"held" tags drive
	# _start_special / _process_special / _on_hurt). Tune on the Player (parry_window / shield_reflect_mult).
	"redere_shield": {
		"name": "Redere Shield", "icon": "res://vfx/shared/impervious/shield.png", "tier": "elite", "tags": ["shield", "held"],
	},
	# Redere Frisbee: an INDEPENDENT special (no longer an upgrade of Redere Shield) -- throws the shield as
	# a PROJECTILE (EmittersCharacters fires a shot on the release frame, fed this `hit`). Selectable as a
	# special swap (configs/rewards_catalog.gd), upgraded via its own buffs.
	"redere_frisbee": {
		"name": "Redere Frisbee", "icon": "res://vfx/shared/textures/blast1.png", "tier": "broken", "tags": ["shield"],
		"hit": {"type": "projectile", "segments": {"damage": 15, "knockback": 120}},
	},
}

## Khalid's SURGES -- passive abilities on the dedicated `surge` button (CTRL / RT). One press applies a
## timed self-buff WITHOUT locking the player's state (keep attacking/moving), then `cooldown` is the
## RESET wait *after* the effect expires before it can fire again. `surge` = the SurgeSpec (effect +
## duration). On trigger it plays a brief activation flex (the "surge_<id>" sprite anim) + SFX; the aura
## VFX is the invuln aura (Player.SPECIAL_AURA) spawned for the effect's duration.
const SURGES := {
	# Aegis: full damage IMMUNITY for `duration` s, then an 8s reset. This is the old `special_default`
	# Impervious flex, promoted out of the specials into its own system. Reuses the invuln + aura machinery
	# (Player.grant_special_invuln); the "Fortitude" reward's +invuln bonus still stacks onto the duration.
	"aegis": {
		"name": "Aegis", "icon": "res://vfx/shared/impervious/shield.png", "tier": "typical",
		"cooldown": 8.0, "surge": {"duration": 5.0, "invuln": true},
	},
}

## Khalid's MOVEMENT actions -- run / jump / dash / slam, one pool per category, each a swappable
## OPTION (id -> Action.make row) with a `move` (Locomotion) dict. `move` lists only the fields Khalid
## DEVIATES on; everything else falls to the Locomotion baseline (configs/locomotion.gd). Movement anims
## are driven by the Player (not `animation`), so these rows are just identity + the Locomotion knobs.
## Add an option to a category to make it swappable (a gate reward then offers the trade).
const MOVEMENTS := {
	"run": {
		"standard_stride": {"name": "Standard Stride", "icon": "res://vfx/shared/textures/pixel_ember.png",
			"move": {"run_speed": 230.0}}, # Khalid runs faster than the 160 baseline
	},
	"jump": {
		"standard_leap": {"name": "Standard Leap", "icon": "res://vfx/shared/textures/soft_dot.png",
			"move": {"air_jumps": 1}}, # baseline arc (velocity -330); ONE air jump (ground + 1 = a double jump)
	},
	"dash": {
		"blink_dash": {"name": "Blink Dash", "icon": "res://vfx/shared/impervious/bolt.png",
			"move": {"blink": true}}, # Khalid teleports instead of the glide-lunge
	},
	"slam": {
		"standard_slam": {"name": "Standard Slam", "icon": "res://vfx/shared/textures/blast1.png",
			"move": {}}, # baseline plunge
	},
}

const DEFAULT_ATTACK := "bakshen"
const DEFAULT_SPECIAL := "redere_shield"
const DEFAULT_SURGE := "aegis"
const DEFAULT_MOVEMENTS := {"run": "standard_stride", "jump": "standard_leap", "dash": "blink_dash", "slam": "standard_slam"}
