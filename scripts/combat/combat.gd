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

# --- combat feel (shared by Player and Enemy hit reactions) -------------------
## Upward pop on a knockback, as a fraction of the horizontal shove, so a hit
## lifts the victim a little and reads.
const KNOCKBACK_POP := 0.25
## A knockback always freezes the victim at least this long, otherwise the AI /
## input would overwrite the shove velocity next frame and nothing would move.
const MIN_STAGGER := 0.18
## How long a discrete melee strike's hitbox stays live for one swing.
const STRIKE_ACTIVE := 0.12
