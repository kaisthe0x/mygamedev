# run — the roguelite loop

Everything that makes the game a *run* lives here: the level flow, the wave spawner, the lahm
economy plumbing, the exit toll, and the reward pick. One folder, driven by data you can tune in
one place each. The premise it implements is in [`docs/game-design.md`](../../docs/game-design.md).

`scenes/level.tscn`'s root **is** `RunManager` — press F5 and you're in a run.

## The pieces

| File | What it is |
|---|---|
| `run_manager.gd` (`RunManager`) | The brain + the level root. Builds each level, spawns start enemies + waves, **awards lahm per point of damage dealt**, runs the exit→reward→next-level flow, restarts the run on death, and owns the camera/death/spawn flair. |
| `levels.gd` (`Levels`) | **The 5 levels, as data** — per level: look (`bg`), `platforms`, `player_spawn`, `exit_pos`, `exit_cost`, `start` enemies, and escalating `waves`. Edit here to change *what a level is*. |
| `enemies.gd` (`EnemyKits`) | **The enemy roster** — one named kit per type (combat tuning + which scene), plus a `Tier` for wave-building. Levels reference these by name. Edit here to change *who* the enemies are. |
| `rewards.gd` (`Rewards`) | **The reward pool** — stat rewards (`pool()` + `apply()`) **plus loadout-swap cards** generated from the character's `Loadout`: whenever a category (attack/special/movement) has >1 option, an "equip this (Tier)" card is offered (id `swap:<cat>:<opt>`). Tiers: Typical/Elite/Broken. |
| `exit_gate.gd` (`ExitGate`) | The exit door (an `Area2D`): detects the player, shows/greens/reds by affordability, reports `touched`. RunManager owns the decision. |
| `reward_ui.gd` (`RewardUI`) | The pick-a-reward popup (pauses the game, emits `chosen(id)`). |

**Terrain look** (the tiled art skin): `RunManager` paints the floor + platforms with the 32px
tileset as positioned sprites over the (unchanged) colliders — `_paint_surface` stamps a surface
row + optional fill rows, `_scatter_plants` sprinkles ground plants, `_place_trees` drops tree
props behind. Art + cell roles live in [`configs/terrain.gd`](../../configs/terrain.gd) (`Terrain`),
files in `assets/terrain/`. Missing sheet → flat-colour fallback. This is the **visual-only** first
pass (collision/feel identical); grid-aligned hand-painted level scenes are the natural next phase.
To hand-paint tiles yourself there's a real TileSet (`resources/terrain/stage1_terrain.tres`) + a
sandbox scene (`scenes/tile_paint.tscn`) — see [`docs/painting-levels.md`](../../docs/painting-levels.md).

Related, but not in this folder:
- **Player HP + lahm** live on the `Player` (`scripts/player.gd`) as **two independent pools**:
  `health` (damage hits this only; heals ONLY via rewards) and `lahm` (a currency in blocks of 50,
  capped by `lahm_cap`, that **rots at `LAHM_DECAY` 15/sec**). API: `gain_lahm` (per damage dealt) /
  `spend_lahm` / `can_afford` / `take_damage` (HP only) / `heal` / `begin_run`. Rewards buff it.
- **The lahm block meter** is built in `scripts/hud.gd` next to the HP bar (crimson cells).
- **Enemies** emit `damaged(amount, source)` on every hit (→ RunManager pays lahm) and a bare
  `died` in `Enemy._die` (→ wave counting only). See `scripts/enemies/enemy.gd`.
- **Spawn puff**: `vfx/spawn/enemy_spawn.tscn` (fired at each wave spawn spot).

## The loop (per level)

1. `RunManager._build_level(i)` sets the `bg`, builds `platforms` + the `ExitGate`, and spawns the
   `start` enemies. Player is placed at `player_spawn`.
2. Damaging an enemy → `damaged(amount, source)` → `gain_lahm(amount)` (per point dealt). Meanwhile
   lahm **rots at 15/sec**, so building blocks is a race. Killing an enemy → `died` → `_alive--`.
3. When `_alive` hits 0 the arena is clear → **the next wave spawns** (with a puff at each spot).
   Past the last defined wave, the **last one repeats** — pressure never stops. The level does
   *not* end by clearing.
4. Walk into the exit with `lahm ≥ cost` → pay the toll (lahm only, HP untouched) → **pick a reward**
   (the only heal source) → next level (lahm **carries over**, still rotting). Can't afford it? The
   door is red; keep farming. Affordability flickers as lahm decays — buffer up and rush it.
5. **Death** (HP hits 0) → the whole run restarts at level 1 via `Player.begin_run` (buffs cleared,
   100 HP / 0 lahm). Finishing level 5 loops back for now (a win screen is a TODO).

## Tuning cheatsheet

- **Make a level harder/easier** → its `start`/`waves` in `levels.gd` (more strong-tier enemies,
  more per wave) and its `exit_cost` (in lahm; blocks = cost/50).
- **Change an enemy's stats** → its kit in `enemies.gd` (combat) — its total lahm payout is just its
  HP (delivered as you damage it).
- **Change the decay / block size** → `Player.LAHM_DECAY` (15/sec) and `LAHM_PER_BLOCK` (50).
- **Add/change a reward** → `rewards.gd` (`pool()` + `apply()`). Keep a heal in the pool — it's the
  only way to mend HP.
- **Balance invariant**: `exit_cost` must stay **below** `lahm_cap` (base 500 = 10 blocks) with
  headroom to build a buffer while it rots. Raise `lahm_cap` via the `Deeper Gut` (+2 blocks)
  reward. And the real gate: player **damage/sec must beat 15 lahm/sec**, or no toll is reachable.

## Known template gaps (deliberate, for later)

- Levels currently reuse a similar platform style; "different look" is just the `bg` tint so far.
- Reward `apply` covers a handful of buffs; the special-vs-normal damage split is one `damage_mult`.
- No win screen / meta-progression yet (finishing loops back to level 1).
- Spawn cadence is "refill on full clear." The timed pressure the design doc wanted is now the
  **lahm decay** (a race against the rot) rather than a spawn-rate ramp.
