class_name Combat
extends RefCounted

## Shared combat constants. Collision-layer bits mirror the names defined in
## project.godot ([layer_names]/2d_physics). Bodies stand on WORLD; damage is
## dealt by Hitboxes (which mask the opposing team's Hurtbox layer) landing on
## Hurtboxes -- teams never touch, so no friendly fire and no group checks.

const L_WORLD := 1 << 0        # 1   floor / terrain
const L_PLAYER_BODY := 1 << 1  # 2
const L_ENEMY_BODY := 1 << 2   # 4
const L_PLAYER_HURT := 1 << 3  # 8   player receives hits here
const L_ENEMY_HURT := 1 << 4   # 16  enemies receive hits here
const L_PLAYER_HIT := 1 << 5   # 32  player attack boxes / friendly projectiles
const L_ENEMY_HIT := 1 << 6    # 64  enemy attack boxes / hostile projectiles

## Player-facing taxonomy of an attack, for the (future) move-select / build UI so
## it can label each move -- "this is a Blast, that's a Ground attack". DESCRIPTIVE
## only: it does NOT drive behavior (clip_to_ground etc. are explicit params), so
## kind and behavior can never drift. Recorded per move in configs/moves.gd (and per
## enemy attack), and spans both node classes -- Strike covers MELEE/BLAST/GROUND,
## Projectile covers PROJECTILE. Room to grow (BEAM, TRAP, ...).
enum AttackKind { MELEE, BLAST, GROUND, PROJECTILE }

## Team helpers for an attack box / projectile: which layer it lives on and which
## hurt layer it scans. Friendly (player) boxes hit enemies; hostile boxes hit the
## player. Keeps the two presets in one place so Strike/Projectile just pass a bool.
static func hit_layer(hostile: bool) -> int:
	return L_ENEMY_HIT if hostile else L_PLAYER_HIT


## Which hurt layer(s) an attack box scans. Normally just the OPPOSING team's. With
## `friendly_fire`, it also scans its OWN team's hurt layer, so the box can hit allies
## too (the Hitbox still skips its own `source`, so the attacker never hits itself). Used
## per-attacker (e.g. an enemy flagged to hurt other enemies) -- not a global toggle.
static func hurt_mask(hostile: bool, friendly_fire := false) -> int:
	var mask := L_PLAYER_HURT if hostile else L_ENEMY_HURT
	if friendly_fire:
		mask |= L_ENEMY_HURT if hostile else L_PLAYER_HURT
	return mask


# --- combat feel (shared by Player and Enemy hit reactions) -------------------
## Upward pop on a knockback, as a fraction of the horizontal shove, so a hit
## lifts the victim a little and reads.
const KNOCKBACK_POP := 0.25
## A knockback always freezes the victim at least this long, otherwise the AI /
## input would overwrite the shove velocity next frame and nothing would move.
const MIN_STAGGER := 0.18
## How long a discrete melee strike's hitbox stays live for one swing.
const STRIKE_ACTIVE := 0.12
## A stun at least this long is a tagged CONTROL stun (e.g. special_stay): the victim
## freezes its pose instead of idling. Shorter stuns are just knockback staggers.
const CONTROL_STUN_MIN := 1.0
## Red tint a hit flashes, fading back over HIT_FLASH_TIME. Shared by every body's
## hit reaction (see Combatant.flash).
const HIT_FLASH := Color(1.0, 0.4, 0.4)
const HIT_FLASH_TIME := 0.16
