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
