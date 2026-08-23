# GDScript → C# migration

Tracking doc for porting mygamedev from GDScript to C#. **The game systems (everything shipped) become C#;
throwaway test/QA harnesses stay GDScript.** Motivation: a typed attack hierarchy (`Strike` as a base, with
`Melee`/`Blast`/`Aoe`/`TimedAoe` as real types), a typed reward/item system, and compile-time bug-catching
as the project scales.

Branch: `feature/csharp-migration`.

## Toolchain (verified)

- **`godot-mono` 4.7.2.stable.mono** (the .NET build; the plain GDScript `godot` is gone from PATH). Patch-
  newer than the old 4.7.1 build — fine within 4.7.x; the game boots clean under it.
- **.NET SDK + runtime 10** only. So the C# project targets **`net10.0`** (matching the sole installed
  runtime — avoids net8 roll-forward issues).
- Build: `dotnet build mygamedev.csproj` (fast) or `godot-mono --headless --build-solutions` (also registers
  `[GlobalClass]` types). NuGet is reachable, so `Godot.NET.Sdk/4.7.2` restores.
- **Run/verify** with `godot-mono` (NOT `godot`): `godot-mono --headless res://scenes/<scene>.tscn`,
  `godot-mono --headless --quit-after 150` for a boot smoke test. Same real-scene discipline as before.

## Scaffolding (done)

- `mygamedev.csproj` — `Godot.NET.Sdk/4.7.2`, `net10.0`, `Nullable=enable`, `ImplicitUsings=enable`,
  `RootNamespace=MyGame`, `EnableDynamicLoading=true`.
- `mygamedev.sln` (classic format; `dotnet new sln --format sln`).
- `project.godot` → `[dotnet] project/assembly_name="mygamedev"`.

## Interop findings — THE constraint that governs order (verified empirically)

| Boundary crossing | Works? |
|---|---|
| GDScript instantiates a C# `[GlobalClass]` (`X.new()`) and calls its **instance methods** | ✅ |
| GDScript **reads/writes a C# instance property or field** by dot-access | ✅ (see naming) |
| C# **signals** (`[Signal]`) → GDScript `connect` | ✅ |
| GDScript **`var x := csharpObj.Member`** (type inference on a C# member read) | ❌ **parse error** — needs an explicit type: `var x: float = csharpObj.Member` |
| GDScript reads a C# **`static` / `const`** member | ❌ **parse error** |
| GDScript **`extends` a C# class** (and the reverse, C# extends GDScript) | ❌ **not supported** — "Could not resolve script" |

**THE structural constraint (verified):** an **`extends` chain must be a single language.** GDScript can *use* a
C# class (`new`, `is`, typed var, call methods, connect signals) but cannot **inherit** from one — and C#
can't inherit from GDScript. **Consequence:** a base class with GDScript subclasses can only move to C# when
its whole subtree moves with it. Here that ties **`Combatant` + `Player` + `Enemy` + `Nasen` + `Ein`** into
**one atomic phase** — they can't be ported one at a time. (Cross-language calls between *unrelated* classes
are fine via instances/signals/dynamic `Call`; only `extends` is language-locked.)

More boundary facts (all verified):
- **Names are exact and case-sensitive.** GDScript addresses a C# member by its literal C# name — `hit.Amount`,
  never `hit.amount`. `[Export]` is **not** required for GDScript access (plain public props/fields work).
- **`:=` inference fails on ANY C# member** (property, field, or computed — not an alias quirk). So a GDScript
  line reading a ported member must annotate the type. There are few of these; the parse error names each.
- **snake_case alias pattern for data objects that cross into GDScript** (e.g. `Hit`): give the C# class
  idiomatic `PascalCase` properties **plus** transition-only `snake_case` alias properties that forward
  (`public float amount { get => Amount; set => Amount = value; }`). Then the still-GDScript consumers keep
  their `hit.amount` reads/writes UNCHANGED — only their rare `:=` reads need an explicit type. Delete the
  alias block once no `.gd` touches that object. The Godot source generator accepts `Amount`/`amount` together.
- **GDScript does NOT honour C# default parameters.** A C# `void activate(float d = 0)` makes GDScript demand
  the arg (`activate()` → "Too few arguments"). Expose a **parameterless** method for the common call + a
  separately-named method for the variant (`ActivateTimed(float)`). No overloading by arity for GDScript.
- **C# lambda on a Godot signal can be GC'd before it fires** — a capturing `() => …` connected to
  `SceneTreeTimer.Timeout` (or any signal) may be collected, so the callback silently never runs. Use a
  **method group** (`timer.Timeout += ArmHitbox;`) — it keeps `this` alive. (This bit the TimedAoe telegraph
  and would have bitten DoT-tick / multi-hit; all converted to method groups.)
- **C#→GDScript callbacks are dynamic `Call`.** When ported C# must call a still-GDScript method on a body it
  holds as `Node` (lunge/armor/`hold_animation`), use `node.HasMethod("x")` + `node.Call("x", args…)`. It's
  the stringly-typed direction; unavoidable until the body is C# too.
- **Cpu/GpuParticles2D share property *names* but not a C# base** — no common type exposes `Emitting`/
  `Lifetime`/`Restart`; use a small typed `switch` per kind. `Lifetime` is `double`; `LifetimeRandomness` is
  CPU-only. Also `Timer` is ambiguous under ImplicitUsings — qualify `Godot.Timer`.
- **A C# property `foo` reserves the accessor name `set_foo`/`get_foo`** — so a C# **method** named `set_foo`
  collides with a `foo` property (`CS0082`). The GDScript `player.gd` had both a `character` property AND a
  `set_character()` method; in C# only one can exist. Drop the method and route callers through the property
  (`_player.character = id` runs the same setter) — GDScript writing a C# property triggers its setter.
- **Exposing a C# `const` to GDScript:** GDScript can't read a C# static/const, but a GDScript consumer that
  needs the value (HUD reading `RUH_PER_BLOCK` to size the Ruh meter) can read a C# **instance property**
  mirroring it (`public float RUH_PER_BLOCK => 100f;`). Class-qualified reads (`Player.RUH_PER_BLOCK`) still
  fail and must switch to the instance (`player.RUH_PER_BLOCK`).
- **NODE ported from a `.gd` that scenes reference:** keep the **exact public surface names** the scenes/`.gd`
  callers use (snake_case fields/methods/signals — forced anyway because `.tscn` `[Export]` values serialize
  by name and GDScript calls by exact name). Internals stay idiomatic. **Reuse the uid**: put the old
  `<name>.gd.uid` value in a new `<Name>.cs.uid`, AND rewrite each scene's `ext_resource` `path=` to the
  `.cs` (keep the uid) — both resolve to the C# script, no other scene edits. snake_case C# `[Export]`
  properties load the existing `.tscn`-authored values correctly (verified: `damage = 18.0` → `18.0`).
  Final PascalCase polish is deferred to the cleanup phase (all callers C# by then → safe rename).

**Consequence:** a shared *static* config (e.g. `Combat`'s layer bits, the `const`-table configs) **cannot be
flipped to C# while any GDScript still reads it.** Two tactics:

1. **Duplication bridge** (for small, stable static data like collision layers): keep the GDScript copy AND add
   a C# copy; both live until the last GDScript consumer is ported, then delete the `.gd`. Drift risk is low
   for constants.
2. **Flip cohesive clusters together** so a static config and all its consumers become C# in one phase.

Nodes/Resources are the interop-friendly unit: ported C# nodes talk to un-ported GDScript via **instances +
signals**, never via statics.

## Conventions

- Namespace `MyGame`; `PascalCase` members; nullable reference types on.
- C# files mirror their GDScript origin folder during transition (e.g. `configs/Combat.cs` beside
  `configs/combat.gd`) so paired files stay together; the `.gd` is deleted when nothing references it.
- A C# type GDScript must use is `[GlobalClass]` + extends a Godot type. Pure C#-only helpers are plain
  classes (e.g. `Combat` is a `static class`, not a Godot type).

## Verification discipline

Port a unit → `dotnet build` (0 warnings, nullable clean) → run the relevant real scene under `godot-mono`
and confirm **behavioural parity** with the pre-port build → then move on. Keep the GDScript scene-test
harnesses (GDScript, per the carve-out).

## Known minor issues (from playtest, deferred — not blocking)

- **Enemy idle looks slightly buggy (esp. Mazab).** The idle "settle then ping-pong" bounce (GDScript, not yet
  ported) reads a touch off on Mazab's frames. Pre-existing tuning, not a migration regression. Revisit its
  `idle_loop_from/to` when the enemy tree lands.
- **Baghel's attack trail + Kebus's projectile render WHITE** (playtest). Almost certainly a `Projectile.cs`
  regression — those are the two enemy projectile scenes re-scripted in Phase 2. Suspect the particle-colour
  path: `SampleVisualColor()` (baghel's ground trail — likely returning the white fallback because the source
  emitter's colour is on `color`, not `ColorRamp`, or the C# read differs from GDScript), and/or the main
  visual's colour on kebus. Contained fix; deferred per user. Check the baghel/kebus `.tscn` emitter colour
  source vs the C# read.

## Phases

- [x] **0 · Toolchain** — godot-mono 4.7.2 + dotnet 10 verified; branch cut.
- [x] **1 · Scaffold + prove pipeline** — csproj/sln/`[dotnet]`; interop probe confirmed instance-calls +
  signals cross and statics don't. Probe removed.
- [x] **2 · Combat core + typed attack hierarchy** (every standalone combat component; `Combatant` deferred to
  Phase 4 with the body tree) — done: `Combat.cs`, `Hit.cs`, `Hitbox.cs`+`Hurtbox.cs`,
  and **the typed Strike hierarchy** (the marquee goal): `Strike` (base) + `MeleeStrike` / `AoeStrike` /
  `BlastStrike` / `TimedAoeStrike`. **Design:** the base owns all shared machinery; **`BlastStrike` carries the
  real channel behaviour** (`emit_duration` + hold-the-caster + interrupt) and Enemy/Player now detect a
  channel with `is BlastStrike`; `TimedAoeStrike` adds a telegraph delay (unused by scenes yet, unit-tested);
  Melee/Aoe are the box shapes (honest — this game's attack differences are shape/params + the channel). 25
  attack scenes re-scripted to their type (18 Melee / 5 Aoe / 2 Blast). Verified: each scene instantiates as
  the right type, `apply_tuning` works through the base, Tarri's channel is detected + cancels, Breski's combo
  lands 4 hits, TimedAoe box off-during/on-after telegraph, clean boot.
  ⚠ **Regression caught in playtest + fixed:** moving `emit_duration` off the base `Strike` onto `BlastStrike`
  broke `ParticleDirector._fire_burst` (`particle_director.gd:433`), which read `node.emit_duration if node
  is Strike` — a `MeleeStrike` IS a `Strike` but has no `emit_duration`, so every player melee (bakshen)
  crashed. Now guards on `is BlastStrike`. **Lesson:** when narrowing a base member to a subclass, grep
  EVERY `is <Base>` / member-access site — not just the obvious owners (I'd fixed enemy/player but missed the
  director). Headless scene tests don't exercise input-driven player attacks; playtesting found it.
  Also done: **`Projectile.cs`** (5 scenes re-scripted; verified — kebus straight shot lands, the frisbee homes
  then ricochets across 2 enemies) and **`LobProjectile.cs`** (code-built, no scenes; verified — mazab throws,
  arcs, dwells, explodes, AoE damages). NEXT: `Combatant` (⚠ base of Player/Enemy — porting it makes GDScript
  `extends` a C# class; verify that interop first) and `MagnetField`.
  Two more interop notes: **C#→GDScript autoload call** is `GetNodeOrNull("/root/Sfx")?.Call("play_at", …)`
  (the autoloads are still GDScript). And the payoff shows: a ported C# class calls another ported class
  **typed** — LobProjectile invokes `AoeStrike.apply_tuning(...)` directly instead of the old
  `has_method`/dynamic dance.
  Also done: **`MagnetField.cs`** (1 scene rewired; verified — magnetizes a GDScript enemy via dynamic
  `Call`). **Every standalone combat component is now C#.** `Combatant` is NOT standalone (base of the body
  tree) → it moves in Phase 4.

- [ ] **3 · Configs → typed data** — the `const`-table configs become typed C# as their consumers port. Many
  are consumed by the body tree, so they largely land with Phase 4.
- [~] **4 · The BODY TREE** — split into two atomic sub-phases, decoupled so the game stays runnable between
  them (Player keeps the GDScript `Combatant`; the enemy tree gets a **C# `Combatant`**).
  **Key enabler (verified):** a **non-`[GlobalClass]` C# class can share a name with a GDScript global class**
  — only C# subclasses extend the C# `Combatant`, so it needs no global registration and doesn't clash with
  the GDScript `class_name Combatant`. No rename needed.
  - [x] **Combatant.cs** — ported (idiomatic PascalCase; called only from the C# enemy tree). Verified:
    methods work, `SpawnVictimVfx(recolor:true)` bridges to the GDScript `VfxPalette.recolor_tree` via
    `GD.Load<GDScript>(…).Call(…)`, and it coexists with the GDScript Combatant (clean boot).
  - [x] **4a · Enemy tree — DONE & verified.** `Enemy.cs` (1225 lines) + **`SleeperEnemy.cs`** (was Nasen) +
    **`DiverEnemy.cs`** (was Ein), all C# extending C# `Combatant`. **Reframed by ARCHETYPE** (user's call):
    Nasen/Ein are now behaviour-type classes, and "Nasen"/"Ein" became **kits** (`EnemyKits.NASEN`/`.EIN`
    point at generic `sleeper_enemy.tscn`/`diver_enemy.tscn` + carry the identity/tuning) — a new sleeper or
    diver is now just a kit, no new script. `enemy.tscn` rewired to `Enemy.cs` (uid reuse); the three `.gd`
    files + `nasen.tscn`/`ein.tscn` deleted. Compiled clean on the FIRST pass; clean boot; parity verified —
    base Enemy (Breski melee combo 4 / Kebus projectile 5 / Mazab lob 2), SleeperEnemy (Nasen rage 13),
    DiverEnemy (Ein dive+self-destruct). The bridges held: UI helpers via dynamic Call/Get, config readers via
    `GD.Load<GDScript>().Call`, Sfx via `/root/Sfx`, Shapes/Nodes inlined. GDScript consumers (RunManager
    `var e: Enemy`, player `hit.source is Enemy`) work unchanged against the C# `Enemy`.
    (Bridge strategy used, as planned: combat deps typed C#; UI helpers held as `Node2D` + dynamic Call/Get;
    config readers `Emitters`/`SfxEnemies`/`AnimMeta` bridged via `GD.Load<GDScript>().Call`; Sfx via
    `/root/Sfx`; Shapes/Nodes inlined. This transitional dynamic-call cruft is removed when Player/HUD/configs
    port in 4b/5/6.) ⚠ Input-driven player-attack paths still need a **playtest** (headless can't drive input).
  - [x] **4b · Player — DONE & compile/boot-verified.** `Player.cs` (~1450 lines) extends the C# `Combatant`;
    the GDScript `player.gd` + `combatant.gd` deleted → the body tree is now ALL C#. `player.tscn` rewired to
    `Player.cs` (uid reuse `c7150pixjqvhw`). The whole passive/buff stack ported WITH it (forced atomic — see
    the extends-chain rule): `Passive.cs` / `Buff.cs` / `CharacterAbility.cs` + `Leech.cs` / `ParryMend.cs` /
    `ReaperEdge.cs`, all `[GlobalClass]` so the still-GDScript `Rewards` service can `Leech.new()` them.
    Bridges held: config objects (Action/Locomotion/SurgeSpec) carried as `GodotObject` via `.Get/.Call`;
    Actions/Loadout/AnimMeta/PaletteConfig/VfxPalette/FloatingText via `GD.Load<GDScript>().Call`; Sfx via
    `/root/Sfx`; ParticleDirector/StatusOverlay/FloatingHealthBar instantiated by GDScript-`.New()` and driven
    by dynamic Call/Get. GDScript touch-ups for the 3 static reads (`Player.State.SPAWN` → `is_spawning()`,
    `Player.RUH_PER_BLOCK` → an instance accessor) + the `:=` fix in `hud.gd`; `Rewards._make_passive` now
    `.new()`s the C# passives by name. **Verified:** clean boot of `level.tscn` (200 frames, no errors) + a
    throwaway QA scene exercising the reward path end-to-end (stat buff onto a C# field; a C# `Leech` granted
    by GDScript with its `OnHitDealt` hook firing + healing; `ReaperEdge` buff granted; `Build.of` querying the
    C# player; the level-duration tick) → **PASS**. ⚠ Input-driven movement/combat/surge FEEL still needs a
    **playtest** (headless can't drive input).
  - **Reward/buff FOUNDATION laid (per docs/rewards-design.md, the user's direction).** `Buff` now carries the
    doc's model: `Tier` (Common→Epic rarity + badge colour, `RewardTypes.cs`), `DurationLevels` (null =
    permanent / N = expires after N level advances, ticked by `Player.advance_level()`), the existing
    `AppliesTo` scope + `Family` replace-in-place, and a `Trigger` enum (the doc's growing hook vocabulary).
    Passive hooks extended with the doc's wired movement/attack moments (`OnDash`/`OnGroundJump`/`OnAirJump`/
    `OnSlamTrigger`/`OnSlamLand`); the harder triggers (OnMiss/OnPerfectDodge/level-timer) are reserved in
    `Trigger` until the player learns to emit them. This is the scalable base future buffs drop into as data.
- [ ] **C#→GDScript static bridge** pattern (recorded): to call a GDScript `class_name` static from C# during
  the transition, `GD.Load<GDScript>("res://…​.gd").Call("method", args…)` (used for `VfxPalette.recolor_tree`).
- [ ] **5 · Run system** — RunManager / Levels / EnemyKits / **Rewards** (designed typed) + UI.
- [ ] **6 · Autoloads** — Sfx / Music / HUD + remaining UI. (Removes the `GetNode("/root/Sfx").Call(…)` bridges.)
- [ ] **7 · Cleanup** — delete interop scaffolding + the GDScript duplication bridges (`Combat.gd`) + the
  snake_case aliases/naming; PascalCase the combat surface now every caller is C#; all-C# end state.
