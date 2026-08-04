# run — the roguelite loop

Everything that makes the game a *run* lives here: the level flow, the wave spawner, the lahm
economy plumbing, the exit toll, and the reward pick. One folder, driven by data you can tune in
one place each. The premise it implements is in [`docs/game-design.md`](../../docs/game-design.md).

`scenes/level.tscn`'s root **is** `RunManager` — press F5 and you're in a run.

## The pieces

| File | What it is |
|---|---|
| `run_manager.gd` (`RunManager`) | The brain + the level root. Builds each level, spawns start enemies + waves, awards lahm on kills, runs the exit→reward→next-level flow, restarts the run on death, and owns the camera/death/spawn flair. |
| `levels.gd` (`Levels`) | **The 5 levels, as data** — per level: look (`bg`), `platforms`, `player_spawn`, `exit_pos`, `exit_cost`, `start` enemies, and escalating `waves`. Edit here to change *what a level is*. |
| `enemies.gd` (`EnemyKits`) | **The enemy roster** — one named kit per type (combat tuning + which scene), plus a `Tier` for wave-building. Levels reference these by name. Edit here to change *who* the enemies are. |
| `rewards.gd` (`Rewards`) | **The reward pool** — `pool()` (id/name/desc) + `apply(id, player)` (the effect). Add a row + a case to add a reward. |
| `exit_gate.gd` (`ExitGate`) | The exit door (an `Area2D`): detects the player, shows/greens/reds by affordability, reports `touched`. RunManager owns the decision. |
| `reward_ui.gd` (`RewardUI`) | The pick-a-reward popup (pauses the game, emits `chosen(id)`). |

Related, but not in this folder:
- **Player life/lahm** lives on the `Player` (`scripts/player.gd`): one `life` value, shown as HP
  (`min(life,100)`) + `lahm` (overflow, capped by `lahm_cap`). `gain_life` / `spend_life` /
  `can_afford` / `take_damage` (lahm-first) / `begin_run`. Rewards buff it (`damage_mult`, etc.).
- **The lahm bar** is built in `scripts/hud.gd` next to the HP bar (flesh-crimson).
- **Enemies** emit `died(lahm_value)` (their HP) in `Enemy._die` — RunManager awards it.
- **Spawn puff**: `vfx/spawn/enemy_spawn.tscn` (fired at each wave spawn spot).

## The loop (per level)

1. `RunManager._build_level(i)` sets the `bg`, builds `platforms` + the `ExitGate`, and spawns the
   `start` enemies. Player is placed at `player_spawn`.
2. Every enemy killed → `died` → `gain_life(its HP)` as lahm, and `_alive--`.
3. When `_alive` hits 0 the arena is clear → **the next wave spawns** (with a puff at each spot).
   Past the last defined wave, the **last one repeats** — pressure never stops. The level does
   *not* end by clearing.
4. Walk into the exit with `life ≥ cost` → pay the toll → **pick a reward** → next level (life
   **carries over**). Can't afford it? The door is red; keep farming.
5. **Death** (life hits 0) → the whole run restarts at level 1 via `Player.begin_run` (buffs
   cleared, 100 HP / 0 lahm). Finishing level 5 loops back for now (a win screen is a TODO).

## Tuning cheatsheet

- **Make a level harder/easier** → its `start`/`waves` in `levels.gd` (more strong-tier enemies,
  more per wave) and its `exit_cost`.
- **Change an enemy's stats** → its kit in `enemies.gd` (combat) — its lahm payout is just its HP.
- **Add/'change a reward** → `rewards.gd` (`pool()` + `apply()`).
- **Balance invariant** (from the design doc): a gate's `exit_cost` must stay **below** the
  player's max life (`100 + lahm_cap`, base 500), or it's unpassable. Raise `lahm_cap` via the
  `Deeper Gut` reward to keep deeper gates affordable.

## Known template gaps (deliberate, for later)

- Levels currently reuse a similar platform style; "different look" is just the `bg` tint so far.
- Reward `apply` covers a handful of buffs; the special-vs-normal damage split is one `damage_mult`.
- No win screen / meta-progression yet (finishing loops back to level 1).
- Spawn cadence is "refill on full clear," not the timed/pressure spawner from the design doc §7.
