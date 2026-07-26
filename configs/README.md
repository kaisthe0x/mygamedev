# configs — tuning data, one file per domain

Pure **data** pulled out of the scripts that use it: constant lookup tables,
rosters, collision-layer bits, feel/balance numbers. The goal is that when you
want to retune the game you open `configs/`, not hunt through behavior code.

Each file is a `class_name X extends RefCounted` holding only `const`s, referenced
globally as `X.MEMBER` (e.g. `Combat.L_WORLD`, `Attacks.TABLE`). Nothing here runs
— no `_process`, no state — so it's safe to read from anywhere and cheap to change.

## What's here

| File | Class | Holds |
|---|---|---|
| `combat.gd` | `Combat` | Collision-layer bitmask table (`L_*`, mirrors project.godot) + shared hit-reaction feel (`KNOCKBACK_POP`, `MIN_STAGGER`, `STRIKE_ACTIVE`, `HIT_FLASH`, `HIT_FLASH_TIME`) |
| `move.gd` | `Move` | One attack/special: its animation, effect, and hit tuning. A tiny data class built from the catalog. |
| `moves.gd` | `Moves` | `CATALOG` — every character's named **attacks + specials** and the **default** of each. **Edit `default_attack` / `default_special` here to change what a character uses.** Characters not listed fall back to a legacy `attack` + `special` pair. |
| `character_config.gd` | `CharacterConfig` | The player roster `IDS` + the per-id resource path templates (`FRAMES_PATH`, `PORTRAIT_PATH`, `ABILITY_PATH`) |
| `level_config.gd` | `LevelConfig` | The dev test level: `SPAWN`, `DEATH_Y`, `PLATFORMS`, and the enemy `ROSTER` (per-instance Enemy `@export` overrides) |

## What deliberately stays OUT of here

**`@export` fields on nodes** — `Player`'s `dash_speed`/movement/juice, `Enemy`'s
per-enemy stats, `FloatingHealthBar`'s styling, `LaserBeam`'s beam params. Godot
surfaces those in the **inspector per node**, which is how you tune them; relocating
them into a const file would lose that. The rule of thumb: **a constant table or
roster → here; an `@export` you tune per-node in the inspector → stays on the node.**

## Adding / changing config

- **Retune an existing value** — edit the const here; every reader picks it up (it's
  referenced by class, not copied).
- **Add a new table** — new `configs/<name>.gd` with `class_name <Name> extends
  RefCounted` and your `const`s; reference it as `<Name>.MEMBER`. Pick a class name
  that doesn't collide with an existing one (Player, Enemy, Combat, Attacks, …).
- **`@export_enum` caveat** — the character list is duplicated as a literal in
  `Player.character`'s `@export_enum(...)` because that hint needs literal strings
  (it can't reference `CharacterConfig.IDS`). Keep the two in sync by hand.
