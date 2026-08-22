---
name: mygamedev
description: >
  Orient in the mygamedev Godot 4.7 GDScript game (a Khalid-only roguelite arena crawler,
  working title "Way of All Flesh") before changing it. Covers the premise, the config-driven
  architecture, naming standards, the character/enemy roster, the in-engine verification workflow,
  and the gotchas that bite fresh agents. Load at the start of any task that edits this repo.
---

# mygamedev — working in this repo

A **Godot 4.7 / GDScript** 2D pixel-art **roguelite arena crawler**. You play **Khalid** (only shipped
character; others parked in `playground/`). Drop into a level, **clear every enemy batch** and the exit
opens; each exit is a **random reward door** (Health / Athletic / Attack / Special) that buffs the run.
**Permadeath.** `scenes/level.tscn`'s root **is** `RunManager` — press F5 to play.

**Two pools** (`scripts/player.gd`): **HP** (damage hits this only; heals ONLY from reward doors; 0 = run
over) and **Ruh** (the SURGE meter, in charges/blocks of 100; fills by *landing hits*, never decays; start
with 3). **Specials are free + unlimited** (0.6s anti-spam only). **Surges spend Ruh** (Aegis = 5s
invincibility, 1 charge). A special's own hits grant no Ruh (`last_hit_from_special` flag).

The authoritative deep reference is **`README.md`** (~1700 lines, kept current) + **`docs/game-design.md`**.
This skill is the map + the workflow; go to those for detail.

## Golden rules (do these every task)

1. **Verify in-engine, headless — never assume.** See the workflow below. This codebase is verified by
   *running Godot*, not by reading alone.
2. **Update `README.md` in the SAME pass as any behaviour/control/tunable/pipeline change.** It's a
   standing rule (`README.md` § "Maintaining this file"). Update the affected section, don't append.
3. **`playground/` is OFF-LIMITS** — parked experiments, not live code. Don't read it for patterns or edit it.
4. **Data goes in `configs/` (or `scripts/run/`), behaviour in scripts.** Retune by editing a `const`
   table, not by hunting through logic. Presentation (particles, sounds) is keyed off an Action's
   `animation` name, never hard-coded in the action.

## Verify like this (highest-value section)

- **Run a real scene headless** (autoloads load, so `Sfx`/`Music`/`HUD` exist):
  `godot --headless res://scenes/<scene>.tscn` — or a throwaway `.tscn` whose root script sets up the
  case and `get_tree().quit()`s. **Do NOT use `godot --headless --script foo.gd`** for anything touching
  game classes — autoloads are absent there, so `projectile.gd` etc. fail with `Identifier "Sfx" not
  found`. Always go through a scene.
- **Reimport after touching any art or `.tscn`/`.tres`:** `godot --headless --import` (registers new
  `class_name`s + assets; catches malformed scenes). Do this before testing scene/sprite changes.
- **Clean-boot smoke test:** `godot --headless --quit-after 150` (boots the main scene ~150 frames);
  grep the output for `error`/`SCRIPT ERROR`/`failed` — empty = clean.
- **Sprite regen check:** `godot --headless --script tools/verify_frames.gd` after regenerating
  SpriteFrames; a mismatched canvas size means the editor clobbered a `.tres` (see gotchas).
- Headless physics can be finicky (irregular deltas; `set_physics_process(false)` can suppress Area2D
  overlaps) — treat weird timing/overlap results as test artifacts, confirm the *logic*, and trust a
  clean boot.

## Architecture in one screen

**Config-driven data + separate readers.** `configs/` files are `class_name X` holding only `const`
tables (no logic), referenced globally as `X.MEMBER`. The reader is a *different* file:
- **Actions** — an `Action` (attack/special/movement) = identity + `animation` + optional `hit`
  (a `StrikeSpec`: `type` + per-segment `damage/knockback/stun/...`). Data: `ActionsKhalid.{ATTACKS,
  SPECIALS,MOVEMENTS}`. Reader: `Actions.get_action(char, kind, id)`. **`hit`'s `segments` are the SINGLE
  source of an attack's numbers** — edit there, nothing baked in a `.tscn`.
- **Movement** lives in `Locomotion` (run/jump/dash/slam) — NOT Player `@export`s. Per-char `MOVEMENTS`
  overlays the baseline.
- **Presentation keyed by `animation`:** particles in `vfx/config/emitters_*.gd` (the `ParticleDirector`
  watches the sprite + fires bursts on frames), sounds in `configs/sfx_*.gd` (the `Sfx` service).
- **Combat components** (`scripts/combat/`): `Hitbox` (deals dmg, dedupes victims per activation) /
  `Hurtbox` (takes it) / `Hit` (the on-hit payload) / `Strike` (melee slash/blast) / `Projectile` +
  `LobProjectile` (shots) / `Combatant` / `MagnetField`. Layers/feel in `configs/combat.gd` (`Combat.L_*`).
- **The run** (`scripts/run/`): `RunManager` (level root + brain), `Levels` (5 levels as data),
  `EnemyKits` (roster), `Rewards`+`Build` (build-aware offers), `ExitGate`, `RewardUI`.
- **Player** = a state machine (`enum State`) in `scripts/player.gd`. **Enemy** = one `Enemy` base
  (`scripts/enemies/enemy.gd`) built entirely in code, tuned by `@export`s a kit sets.
- **Autoloads:** `Sfx`, `Music`, `HUD` (HUD is an autoload on purpose — see the editor-clobber gotcha).

**Where things live:** `configs/` tuning data · `scripts/` behaviour · `vfx/` effects (particles +
`Strike`s) · `sfx/` sounds · `sprites/` source sheets · `resources/` GENERATED SpriteFrames (never
hand-edit) · `tools/` generators + verifiers · `helpers/` static utils · `assets/terrain/` level art.

## Naming standards

- **Strike-type taxonomy** (`configs/strike_spec.gd`) is the vocabulary everywhere: `melee`, `projectile`,
  `delayed_projectile`, `aoe`, `delayed_aoe`, `blast`, `trap`.
- **Enemy emitters + sfx keys** mirror it: `<enemy_id>.<type>` for a start cue (e.g. `kebus.projectile`,
  `matat.aoe`), `<enemy_id>.<type>.<frame>` for a per-frame hit, `<id>.<type>_burst` for a lob's payload.
  Shared cues: `enemy_death`, `enemy_spawn`. Files: `sfx/enemy/<id>/attack/<type>.wav`.
- **Character sfx keys:** `<name>` (e.g. `dash`, `slam`) or `<name>.<frame>` for a frame-synced hit.
  Files under `sfx/character/<name>/`.
- **VFX folders:** `vfx/character/<id>/<category>/<move>/…` (attack/special/dash/…), `vfx/enemy/<id>/attack/…`.
  Scene names match the move/anim: `attack_ora_ora.tscn`, `special_ground_breaker.tscn`, `kebus_projectile.tscn`.
- **Projectile impact vfx:** an **`Impact`** child node authored INSIDE the projectile's own scene
  (dormant `emitting=false`); on hit `Projectile._spawn_impact` duplicates it onto the struck target at
  `z_index 50`. No registry/convention file — just the node.
- **Config classes** are `class_name` + `const`s; pick a non-colliding name; reference by class.

## The roster

- **Character:** **Khalid** — living-hair/recolourable-outfit palette shader; attack chosen at run start
  and LOCKED (only buffed), special swappable + free, plus the Aegis surge.
- **Enemies** (`scripts/run/enemies.gd` `EnemyKits`, base `scripts/enemies/enemy.gd`, some with a subclass):
  `kebus` (forward bolt, STRONG), `baghel` (forward ground-wave, CHIP), `mazab` (lob / `delayed_projectile`,
  MID), `matat` (looping melee `aoe`, STRONG), `nasen` (sleeper, `aoe`, `scripts/enemies/nasen.gd`,
  *optional* — needn't be killed to clear), `ein` (floating kamikaze, `delayed_aoe`, `scripts/enemies/ein.gd`).
  Enemies aggro + chase on detection with a give-up leash.

## Gotchas

- **The Godot editor overwrites scene/`.tres` files on disk** if they're open in a running editor —
  it silently writes its stale copy back. Edit scenes/resources with the editor **closed** (or reload the
  project after). This also means: adding an `@export` while a scene is open serialises it as `null` on the
  instance, overriding the script default. (It's why the HUD is an autoload, not a node in `level.tscn`.)
- **Regenerating sprites** (`tools/gen_spriteframes.py`) needs a **reimport first**, and `resources/*`
  SpriteFrames are GENERATED — never hand-edit. Frame 0 of each action sheet is the **idle-reference pose**,
  skipped in action playback; hit frames come from `HIT_FRAMES`. Verify with `verify_frames.gd`.
- **Texture filtering:** project default is **nearest** (pixel art). Painted/hi-res art (portraits) needs a
  per-node `texture_filter = 4` (linear+mipmaps) override. Set `texture_filter` NEAREST on code-built pixel sprites.
- **VS Code GDScript squiggles are stale** (the LSP serves one project defensively): bogus `Could not find
  type "Player"` etc. on code that compiles. **Trust the actual headless run over the squiggles.**
- **HDR 2D is on** (`viewport/hdr_2d`); colour channels > 1.0 bloom where glow is enabled — intentional for
  effects, but keep UI/text channels ≤ 1.0 unless you want glow.
