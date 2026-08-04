# configs — tuning data, one file per domain

Pure **data** pulled out of the scripts that use it: constant lookup tables,
rosters, collision-layer bits, feel/balance numbers. The goal is that when you
want to retune the game you open `configs/`, not hunt through behavior code.

Each file is a `class_name X extends RefCounted` holding only `const`s, referenced
globally as `X.MEMBER` (e.g. `Combat.L_WORLD`, `Moves.CATALOG`). Nothing here runs
— no `_process`, no state — so it's safe to read from anywhere and cheap to change.

> The roguelite **run** data (the 5 levels, the enemy roster/kits, the reward pool) is
> *not* here — it lives with the run logic in [`scripts/run/`](../scripts/run/README.md)
> (`Levels`, `EnemyKits`, `Rewards`). This folder is the player/combat tuning tables.

## What's here

| File | Class | Holds |
|---|---|---|
| `combat.gd` | `Combat` | Collision-layer bitmask table (`L_*`, mirrors project.godot) + shared hit-reaction feel (`KNOCKBACK_POP`, `MIN_STAGGER`, `STRIKE_ACTIVE`, `HIT_FLASH`, `HIT_FLASH_TIME`) |
| `move.gd` | `Move` | One attack/special: its animation, effect, hit `tuning`, and `attack_kind` (the `Combat.AttackKind` taxonomy label for the future build UI). A tiny data class built from the catalog. |
| `moves.gd` | `Moves` | `CATALOG` — every character's named **attacks + specials** and the **default** of each. The `tuning` numbers are the SINGLE source of an attack's hit (the director feeds them into the effect's own Hitbox — see the root README's *Player attacks* section). **Edit `default_attack` / `default_special` here to change what a character uses.** A character with an empty pool (Wayna's specials) has none yet; `get_move` returns null. |
| `character_config.gd` | `CharacterConfig` | The player roster `IDS` + the per-id resource path templates (`FRAMES_PATH`, `PORTRAIT_PATH`, `ABILITY_PATH`) + per-character `RUN_SPEEDS` / `JUMP_VELOCITIES` / `DASH_SPEEDS` / `BLINK_DASH` / `GLOW_COLORS` |
| `terrain.gd` | `Terrain` | The level **art skin**: the 32px tileset sheet + which atlas cells are surface vs fill tiles, ground-plant + tree props, and the background image. `RunManager` stamps these as sprites over the colliders (`_paint_surface`) — see [`scripts/run/`](../scripts/run/README.md). Drop art in `assets/terrain/`. |

## What deliberately stays OUT of here

**`@export` fields on nodes** — `Player`'s `dash_speed`/movement/juice/lahm, `Enemy`'s
per-enemy stats, `FloatingHealthBar`'s styling. Godot
surfaces those in the **inspector per node**, which is how you tune them; relocating
them into a const file would lose that. The rule of thumb: **a constant table or
roster → here; an `@export` you tune per-node in the inspector → stays on the node.**

## Adding / changing config

- **Retune an existing value** — edit the const here; every reader picks it up (it's
  referenced by class, not copied).
- **Add a new table** — new `configs/<name>.gd` with `class_name <Name> extends
  RefCounted` and your `const`s; reference it as `<Name>.MEMBER`. Pick a class name
  that doesn't collide with an existing one (Player, Enemy, Combat, Moves, …).
- **`@export_enum` caveat** — the character list is duplicated as a literal in
  `Player.character`'s `@export_enum(...)` because that hint needs literal strings
  (it can't reference `CharacterConfig.IDS`). Keep the two in sync by hand.
