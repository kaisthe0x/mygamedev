# vfx — visual effects

Everything that draws an effect over the gameplay lives here: the **frame-indexed
particle system** (data-driven emitters layered on the sprites), the drawn
**`FlashEffect`** slashes, and the per-enemy attack VFX. One folder owns the look,
the config, the code, and the build tools.

Combat lives elsewhere on purpose: `Hitbox`/`Hurtbox`/`Combatant` are in
`scripts/combat/`, and the abilities that *trigger* effects are in
`scripts/abilities/`. This folder is the effects themselves, not the damage model
or who fires them.

## Folder layout

```
vfx/
  config/
    emitters.json          Frame-indexed particle config (hand-edited)
  script/
    particle_director.gd   ParticleDirector — watches the sprite, emits per frame
    flash_effect.gd        FlashEffect — a drawn slash that mirrors + frees itself
    build_particles.gd     Scaffold particle-type scenes (skips existing)
    gen_particle_textures.py  Regenerate the shared particle textures
  character/<id>/          Per-character effects, grouped by category:
    attack/<move>/           a named attack + the art ONLY it uses
                             (wayna/attack/chainsaw/{attack_chainsaw.tscn, slash_*.png})
    special/<move>/          a named special (lenbondosen/special/mouth_blast/…)
    dash/default/            movement effects, nested under a variant folder
    jump/default/            (default today; room for alt variants later)
    run/default/
    slam/default/
    other/                   shared per-character bits (general_wind_streaks,
                             slam_wind_streaks, special_ready) — flat, not nested
    shared/textures/         static textures reused across THIS character's effects
                             (smoke, poison, sparks)
  enemy/<id>/attack/        Per-enemy attack scenes (baghel/attack/attack_ground_wave.tscn,
                            kebus/attack/attack_bolt.tscn). Loaded by PATH via the
                            enemy's `ranged_particle`, not the director index.
  shared/textures/          Cross-entity building blocks: pixel_ember.png, soft_dot.png
                            (used by enemies and several characters)
  stage/                    Ambient / background stage effects
```

**Naming rule.** A scene's basename is what `emitters.json` refers to, so keep it
unique per character and role-named: `attack_chainsaw`, `run_default`,
`special_ready`. **Art that only one attack uses lives in that attack's folder**
(the chainsaw slashes sit in `wayna/attack/chainsaw/`); art reused across a
character's effects goes in that character's `shared/textures/`; art reused across
*entities* goes in the top-level `vfx/shared/textures/`.

## Particles (frame-indexed VFX)

Extra 2D particles layered over the drawn sprites — e.g. soft embers on top of
Wayna's flame — driven entirely by data. `script/particle_director.gd` is a child of
the player; it watches the sprite and emits at authored positions during authored
frames. Adding an effect is a scene + a JSON line, no code.

**Three pieces:**

1. **Particle types** — scenes under `vfx/character/<id>/…`. A type's root may be a
   single `CPUParticles2D`/`GPUParticles2D`, a `Node2D` bundling several as one
   composite attack, a `Shot` (drawn projectile), or a `FlashEffect` (drawn slash).

   **How a `type` resolves.** On character swap the director recursively indexes
   `vfx/character/<character>/` (**any** nesting — `attack/chainsaw/`, `dash/default/`,
   `other/`, …) plus the global `vfx/shared/`, building a *basename → scene path* map.
   A `type` in the JSON is just a scene's basename, so **it resolves wherever it's
   filed** — there's no folder list to keep in sync as the layout grows. Names must be
   unique within a character (the director warns on a collision and keeps the first).

   | `type` | Resolves to |
   |---|---|
   | `attack_chainsaw` | `character/wayna/attack/chainsaw/attack_chainsaw.tscn` |
   | `run_default` | `character/<char>/run/default/run_default.tscn` |
   | `special_ready` | `character/<char>/other/special_ready.tscn` |
   | `pixel_ember`-based scene in `vfx/shared/` | found via the shared fallback |

   `script/build_particles.gd` scaffolds a starter scene (it **skips files that
   already exist**, so it never clobbers editor tweaks); shared textures come from
   `script/gen_particle_textures.py`.
2. **Config** — `config/emitters.json`, keyed
   `character -> animation -> [ { type, node?, set?, mode, frames, pos } ]`:
   - `type` — a scene whose root is a single `CPUParticles2D`/`GPUParticles2D`,
     **or a `Node2D` bundling several** as one composite attack (the director drives
     all of them, and mirrors the composite by flipping `scale.x`, so its child
     positions flip too; a single-particle root mirrors `direction`/`gravity` instead,
     keeping its texture). Note: a `CPUParticles2D`'s individual particle **textures**
     do not reliably h-flip under a node scale flip — a directional *drawn* slash
     reads cleanest as a **`FlashEffect`** (`vfx/script/flash_effect.gd`): a `Node2D`
     bundling a `Sprite2D`/`AnimatedSprite2D` (which *do* mirror texture + rotation
     under the scale flip) + a `Hitbox`. It briefly grows+fades its visuals and frees
     itself, and the director accepts it and arms its hitbox like any burst (see
     Wayna's `attack_chainsaw`). Layering separate scenes (several `{…}`) still works.
   - `node` — *optional* **palette addressing**. A "palette" scene bundles several
     *independently-scheduled* emitters as named children; `node` names the one this
     row fires. List the **same `type`** with different `node`s to fire different
     children on different frames — e.g. `attack_finger_guns` holds a `Shot` (fired
     on `[2,4]`) and a `ShotLast` (a different-textured projectile, fired on `[7]`),
     each its own self-contained `Shot`/`Hitbox`. Omit `node` for the whole scene
     (single or composite). Note: `node` **lifts one child out and drops the rest**
     (including sibling hitboxes) — to just reskin a shared scene per hit, use `set`,
     not `node`.
   - `set` — *optional* **property overrides** applied on spawn, so one shared scene
     covers several variants without a clone per tweak. Keys are `"ChildPath:property"`
     (an empty path targets the spawned node itself); a `"res://…"` value is loaded
     as a `Resource`. E.g. `"set": { "Slash:texture": "res://…/slash_down.png" }`
     shows a different crescent on one combo hit — no second scene. (Values are scalars
     or `res://` resources; a JSON `[x,y]` is **not** a `Vector2`, so per-hit
     position/scale offsets need a separate scene.)
   - **Composite child positions** — in a `Node2D` composite, the director only
     positions the *root* (at `pos`); each child particle keeps the local position
     you authored inside the scene. So lay one child at the feet `(0,0)`, another
     at the head `(0,-42)`, a hand-spark at `(14,-20)`, and `pos` anchors the whole
     cluster. `x` offsets mirror with facing; `y` (head/feet height) does not —
     author facing right.
   - `mode` — **sustained** (emit while any listed frame is on screen; the fire
     trail) or **burst** (one-shot each time a listed frame is entered; impacts,
     footfall dust). A **sustained** effect stays parented to the player, so it
     (and any hitbox) **follows** him — right for a body-attached aura/jet. A
     **burst** is **anchored in the world** at the spot it fires and stays put as
     he moves on — right for a blast/detonation.
     - **Code-triggered bursts** — a `burst` keyed under an animation name the sprite
       never plays won't auto-fire on a frame; call `ParticleDirector.fire_effect(key)`
       to spawn it on a game event instead. That's how the **double jump** works: its
       effect lives under `double_jump` and `player.gd` fires it only on the air jump
       (so the ground jump stays silent). See the double-jump note in the root README.
   - `frames` — **sheet-relative** indices (same numbering as `loop_from` /
     `hit_frames`; the idle-reference frame counts). Converted to emitted indices
     via the `sheet_start` SpriteFrames metadata. Or the string **`"all"`** —
     expands to *every* frame of that animation, so a whole-animation effect (an
     idle aura, say) needs no frame list and never breaks when the frame count
     changes.
   - Multiple emitters can share an `animation` — list several `{...}` and they all
     play together (that's how you layer several particle scenes at once).
   - `pos` — `[x, y]` pixel offset from the sprite origin (the feet), for facing
     right; auto-mirrored when facing left.
   - `boost` — *optional* intensity, so one type can be reused at different
     power levels instead of duplicating the scene:

     | Key | Meaning |
     |---|---|
     | `amount` | particle count **multiplier** |
     | `speed` | initial-velocity **multiplier** |
     | `scale` | particle-size **multiplier** |
     | `lifetime` | lifetime **multiplier** |
     | `explosiveness` | absolute `0..1` (multiplying the usual 0 would do nothing) |

     They're multipliers *on the scene's own values*, so they keep tracking the
     base as you tune it. One scene owns the *look*, the JSON owns *how hard it
     hits*. Fork a separate scene only when an effect needs a genuinely different
     look (direction, spread, colour, gravity, rotation), not just more power.

   **Author every effect facing right.** The director mirrors the whole thing
   when the character turns: `pos.x`, and for `CPUParticles2D` also `direction.x`
   and `gravity.x`. (`GPUParticles2D` keeps those on a shared
   `ParticleProcessMaterial` which must not be mutated, so it — and a `FlashEffect`
   slash — falls back to flipping the node's `scale.x`, which mirrors a drawn
   texture cleanly.)
3. **Director** — instantiated by `player.gd` at runtime (not in the editor).
   Rebuilds its emitters (and its scene index) on character swap, so switching away
   from Wayna removes her fire cleanly.

### Making a particle attack deal damage — add a `Hitbox`

A particle/flash effect can carry its **own hand-authored hitbox**, so an attack's
reach is whatever box you draw — no reach formula, no code per attack.

1. In the effect scene, make the root a **`Node2D`** (or `FlashEffect`) and add a
   **`Hitbox`** child (`Area2D` + `scripts/combat/hitbox.gd`, `collision_layer = 32`
   → `mask = 16` for a player attack) with a `CollisionShape2D` under it.
   `special_mouth_blast.tscn` and `attack_chainsaw.tscn` are worked examples.
2. In the inspector, set the **Shape** *and* the **Damage / Knockback / Stun**
   right on the `Hitbox`. Shape and numbers live together on the node.
3. The **`ParticleDirector` arms it for you**: on spawn it sets the box's `source`
   to the player and switches it **on exactly while the effect is emitting** — the
   listed frames for a `sustained` effect, the burst's life for a `burst`. One
   activation = one hit per enemy (the `Hitbox` dedupes), re-armed fresh each strike.
   Because the box lives under the composite it **auto-mirrors** with facing.
4. **Avoid double-hits:** zero the melee `tuning` for that move so the particle's box
   is the only thing that hits (Wayna's `chainsaw` and Lenny's specials use
   `{"damage": 0}` for exactly this reason).

An effect with no `Hitbox` (an aura, a run trail) is unaffected — the director only
arms boxes it finds.

**Keep a ground blast on its platform** — add `"clip_to_ground": true` to a `burst`
entry and, at spawn, the director rays straight down through `L_WORLD`, finds the
platform's edges, and clamps the blast's **rectangular emission band and its
hitbox** to them. The clip is asymmetric — only the side hanging over the ledge is
cut. Rectangle emission + rectangle hitbox only; off the edge of everything it just
isn't clipped. Lenny's `special_poison_raiser` and the slams use it.

### `Local Coords` — the one setting that surprises people

Per particle scene, it decides whether the effect **trails** or stays **attached**:

- **Off** (world space) — particles are released into the world and left behind.
  Good for embers/smoke trails. But the emitter is moving with the player, so a
  low-velocity plume smears backwards into a diagonal. This does *not* show in the
  editor preview, where the emitter is stationary.
- **On** (local space) — particles keep the shape you authored and move with the
  player. Matches the editor preview exactly. Good for attached jets/auras.

To get a trail *and* a straight plume, keep it off and give the particles enough
`initial_velocity` that their own motion dominates the player's ~160 px/s.

> **`Local Coords` also gates texture mirroring.** A world-space (`Local Coords` off)
> particle renders decoupled from its node, so a `scale.x` flip never reaches it and
> an **angled texture won't mirror**. If a particle's texture must flip with facing,
> either turn `Local Coords` **on**, or (for a directional drawn effect) use a
> **`FlashEffect`** `Sprite2D` — which mirrors cleanly under the flip — instead of a
> particle. A world-space particle can only ever mirror its *motion*, never its
> texture.

> Soft glowy particles clash with crisp pixel art. Prefer a hard-edged texture,
> **nearest** filtering, **normal** blend, and colours sampled from the drawn art,
> so effects read as pixel art. Keep new types in that style unless a soft glow is
> genuinely wanted.

### Adding a new attack effect — where things plug in

Pick the layer by *what the effect is*:

| Goal | Add it to | Code? |
|---|---|---|
| A **visual** on chosen animation frames (spark, trail, drawn slash) | `vfx/config/emitters.json` (+ a scene under `vfx/character/<id>/…`) | none |
| A hit's **damage / knockback / reach** | the move's `tuning` in `configs/moves.gd` | none |
| A **thing spawned** on a hit, or custom behavior | a `CharacterAbility` script (`scripts/abilities/`) | small |

1. **Frame-indexed particle (no code).** Make/obtain a scene under
   `vfx/character/<id>/<category>/<name>/<name>.tscn`, then register it in
   `emitters.json`: `<id> → <animation> → [{type, mode ("sustained"|"burst"),
   frames (sheet-relative), pos ([x,y] from feet, auto-mirrored)}]`. Done.
2. **Tune the hit (no code).** The move's `tuning` in `configs/moves.gd` — `damage`,
   `knockback`, `stun`, and hitbox `x`/`extents` (an array = one entry per combo
   segment). The effect keys off the move's `animation` name in `emitters.json`.
3. **Spawn something / new behavior (a `CharacterAbility`).** Create
   `scripts/abilities/<id>.gd` extending `CharacterAbility` (auto-equipped) and
   override a hook: `on_special_strike(player)` (the moment the special connects),
   `physics(player, delta)` (per-frame override, Katalyst's special), or
   `setup(player)` (one-time on equip).

## Enemy attack VFX

Enemy effects live under `vfx/enemy/<id>/attack/` and are loaded **by path**, not the
director index: an enemy's `ranged_particle` (`configs/level_config.gd` roster, or an
`enemy.tscn` inspector field) points at the scene, and `scripts/enemies/projectile.gd`
instances it as the shot's `visual`. Two examples:

- **Baghel** `attack/attack_ground_wave.tscn` — a `CPUParticles2D` ground surge (the
  `forward` ranged mode, with a scorched `ground_trail`).
- **Kebus** `attack/attack_bolt.tscn` — an aimed staff bolt: an ember-trail
  `CPUParticles2D` + a soft glow `Core`. (This was drawn procedurally in
  `projectile.gd`'s `visual == null` fallback; it's now an editable scene. That
  code fallback still exists for any enemy without a `ranged_particle`.)

## Build tools

Run from the project root. All are idempotent scaffolds — they never clobber
hand-tuned scenes.

| Command | Purpose |
|---|---|
| `python3 vfx/script/gen_particle_textures.py` | Regenerate the shared textures (`vfx/shared/textures/*.png`) |
| `godot --headless --script vfx/script/build_particles.gd` | Scaffold particle-type scenes (skips existing) |
| `godot --headless --script tools/gen_effect_frames.gd` | Slice drawn effect strips → SpriteFrames (below) |

### Drawn projectile animations (an `AnimatedSprite2D`, not particles)

When you want a projectile to play a **hand-drawn frame animation** (a ring forming
and flying, say) instead of a particle emitter repeating one texture, build it as a
`Shot` that carries an `AnimatedSprite2D`:

1. Export the projectile as a **horizontal strip** named `<name>_anim.png` into the
   attack's folder (e.g. `character/feyke/attack/ring_kiss/ring_kiss_anim.png`).
   These drawn effect sheets are authored in the art repo.
2. Run `godot --headless --script tools/gen_effect_frames.gd` — it finds every
   `*_anim.png` under `vfx/` and slices it (128px frames by default, or set a count
   in the tool's `OVERRIDES`) into `<name>_anim.tres`, a `SpriteFrames` with one
   `default` animation.
3. In the projectile scene, make the root a `Node2D` with **`shot.gd`**, and give it
   an `AnimatedSprite2D` child (`sprite_frames` = the `.tres`, `autoplay = "default"`)
   plus a `Hitbox` (anywhere — `shot.gd` finds it by search, not a fixed path).

The `ParticleDirector` fires it like any other `burst` — it accepts a `Shot` even
with **no particle emitters**, since it carries its own visual and manages its own
life. Facing is by travel direction: the shot rotates to its heading, so author the
strip pointing **right**.

**`Shot` exports** (`scripts/combat/shot.gd`): `speed`, `homing` (steer rate; 0 = fly
straight), `max_range`, `acquire_range`. Targeting is **x-axis only**: it locks the
nearest enemy *ahead in the facing/mouse direction*, ignores enemies overhead
(`vertical_reach`), and **never steers upward**. Set `can_fly_up = true` to lift those
limits. `impact_effect` (a `PackedScene`) spawns a one-shot effect at the point of
contact when it hits, then self-frees; leave empty for none.

**End / dissolve animation (`end_frames`).** So a shot that reaches `max_range`
*without hitting anything* dissolves instead of blinking out, give it an `end_frames`
`SpriteFrames`. On expiry the shot freezes, switches off its hitbox + any particle
trail, swaps its `AnimatedSprite2D` to `end_frames`, and frees when that animation
finishes. To make one:

1. Draw the dissolve as a horizontal strip named `<base>_end_anim.png` (the `_end_anim`
   suffix makes `gen_effect_frames.gd` slice it **non-looping** — a dissolve plays
   once). Drop it in the attack's folder beside the fly strip.
2. Run `gen_effect_frames.gd` → `<base>_end_anim.tres`.
3. Point the projectile scene's `Shot.end_frames` at that `.tres`
   (`attack_ring_kiss.tscn` is the worked example).

This is expiry-only — a hit still uses `impact_effect`. Leave `end_frames` empty to
keep the old blink-out.
