# run — the roguelite loop

Everything that makes the game a *run* lives here: the level flow, the wave spawner, the Ruh
economy plumbing, the exit toll, and the reward pick. One folder, driven by data you can tune in
one place each. The premise it implements is in [`docs/game-design.md`](../../docs/game-design.md).

`scenes/level.tscn`'s root **is** `RunManager` — press F5 and you're in a run.

## The pieces

| File | What it is |
|---|---|
| `run_manager.gd` (`RunManager`) | The brain + the level root. Builds each level, spawns start enemies + waves, **awards Ruh per damaging hit landed** (via `gain_ruh_on_hit`, skipping a special's own hits — not per kill), runs the exit→reward→next-level flow, restarts the run on death, and owns the camera/death/spawn flair. |
| `levels.gd` (`Levels`) | **The 5 levels, as data** — per level: look (`bg`), `platforms`, `player_spawn`, `exit_pos`, `exit_cost`, `start` enemies, and escalating `waves`. Edit here to change *what a level is*. |
| `enemies.gd` (`EnemyKits`) | **The enemy roster** — one named kit per type (combat tuning + which scene), plus a `Tier` for wave-building. Levels reference these by name. Edit here to change *who* the enemies are. |
| `rewards.gd` (`Rewards`) | **The reward OFFER + EFFECT service** over the typed catalog (`configs/rewards_catalog.gd` data → `Reward` objects), **build-aware** (Phase 4): `offer_for()` filters by each reward's `requires` and weights by `synergy` against the queryable `Build`, then samples; `apply()` runs the effect — a stat buff, a granted **`Passive`**, or an **`equip`** (move upgrade). Still mixes in **loadout-swap cards** from `Loadout` (id `swap:<cat>:<opt>`) for a category with >1 option. |
| `build.gd` (`Build`) | A **queryable snapshot of the player's build** — equipped Action ids per category + rewards taken + their tags — that conditional rewards predicate over. `Build.of(player)`; `matches(cond)` evaluates a condition dict (`equipped`/`tag`/`reward`). |
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
- **Player HP + Ruh** live on the `Player` (`scripts/player.gd`) as **two independent pools**:
  `health` (damage hits this only; heals ONLY via rewards) and `ruh` — the **surge meter**, in
  charges/blocks of `RUH_PER_BLOCK` (100), capped by `ruh_cap`. You **start a run with 3 charges**
  (`BASE_RUH_CAP` = 300 — `begin_run` sets it full) and **refill by landing HITS** (`RUH_PER_HIT` = 20,
  so ~5 hits = 1 charge) — **not kills** — and it **never decays**. API: `gain_ruh_on_hit` /
  `take_damage` (HP only) / `heal` / `begin_run`. **Specials are free** now; **surges spend Ruh** (each
  use costs its `SurgeSpec.cost`, 100 = one charge). Rewards raise `ruh_cap` (toward `MAX_RUH_CAP` = 500, 5 charges).
- **The Ruh block meter** is built in `scripts/hud.gd` next to the HP bar (crimson cells) — one cell
  per charge; each surge empties one.
- **The Aegis surge grants a timed invulnerability window + aura** (`Player.grant_special_invuln(duration)`,
  fired by `Player._try_surge` on the dedicated `surge` button) — no longer tied to casting a special.
- **Enemies** emit `damaged` (→ RunManager awards Ruh via `gain_ruh_on_hit`, skipping a special's own
  hits) and `died` in `Enemy._die` (→ counts toward clearing the batch; no longer banks Ruh).
- **Spawn puff**: `vfx/spawn/enemy_spawn.tscn` (fired at each batch spawn spot).

## The loop (per level)

1. `RunManager._build_level(i)` sets the `bg`, builds `platforms` + the `ExitGate` (LOCKED), and
   spawns the `start` enemy batch. Player is placed at `player_spawn`.
2. **Hitting** an enemy → `damaged` → `gain_ruh_on_hit()` charges the surge meter (a special's own
   hits are skipped). Killing an enemy → `died` → `_alive--` (counts toward clearing; grants no Ruh).
   Specials are **free**; a **surge** fires only when you have the Ruh → `_try_surge()` spends its `cost`.
3. When `_alive` hits 0 the current batch is clear → **the next batch spawns** (puff at each spot).
   Batches are **finite**: once the last one is cleared the level is **done** and the exit **opens**.
4. Walk into the open exit → **pick a reward** → next level (HP, Ruh, and Ruh cap all carry over — no reset).
   Until cleared the door is red/`LOCKED` and does nothing.
5. **Death** (HP hits 0) → the whole run restarts at level 1 via `Player.begin_run` (buffs cleared,
   100 HP / a full 3-charge Ruh meter). Finishing level 5 loops back for now (a win screen is a TODO).

> Note: reward **doors** (one random typed door per level: Health / Athletic / Attack / Special,
> each with an icon) and the **run-start attack picker** are the next phase — see the top-level
> chat plan. Today the exit still opens a simple 3-card reward pick.

## Tuning cheatsheet

- **Make a level harder/easier** → its `start`/`waves` (batches) in `levels.gd` — more strong-tier
  enemies, more per batch, or more batches. The level ends when they're all dead.
- **Change an enemy's stats** → its kit in `enemies.gd` (combat).
- **Change the Ruh / surge economy** → `Player.RUH_PER_HIT` (fill rate per hit), `RUH_PER_BLOCK`
  (charge size), `BASE_RUH_CAP` (starting charges), and the Aegis surge's `cost` / `duration` in
  `configs/actions_khalid.gd` (`SURGES`) for its Ruh price + invuln window. (Specials are free — no cost knob.)
- **Add/change a reward** → add a row to `configs/rewards_catalog.gd` (pure data); wire its effect in
  `rewards.gd` `_buff()` unless it's a `passive`/`equip` reward (those are handled generically). Keep a
  heal in the pool — it's the only way to mend HP.
- **Make a reward build-aware** → on its catalog row: `requires` (a `Build` condition dict — only offer
  when it holds, e.g. `{"equipped":"twin_reaper"}`), `synergy` (`{"when":<cond>,"weight":N}` — nudge the
  roll odds), `unique` (once-only), `upgrades`/`equip` (a move upgrade), `passive` (grant a `Passive`).
- **Add a reward passive** → a `scripts/abilities/<id>.gd` `extends Passive` (hooks: on_hit_dealt,
  on_hurt, on_land, physics, …); reference it from a reward's `passive: "<id>"`. See `leech.gd`.

## Known template gaps (deliberate, for later)

- Levels currently reuse a similar platform style; "different look" is just the `bg` tint so far.
- Reward `apply` covers a handful of buffs; the special-vs-normal damage split is one `damage_mult`.
- No win screen / meta-progression yet (finishing loops back to level 1).
- Spawn cadence is "refill on full clear." The timed pressure the design doc wanted is now the
  **lahm decay** (a race against the rot) rather than a spawn-rate ramp.
