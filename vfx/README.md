# vfx — visual effects

Everything that draws an effect over the gameplay lives here: the **frame-indexed
particle system** (data-driven emitters layered on the sprites) and the
**`LaserBeam`** component (raycast + line beams). Both were scattered across
`scripts/`, `scenes/`, `resources/`, and `particles/` before; they're consolidated
here so one folder owns the look, the config, the code, and the build tools.

Combat lives elsewhere on purpose: the laser's `Hitbox`/`Hurtbox`/`Combatant` are
in `scripts/combat/`, and abilities that *fire* effects are in
`scripts/abilities/`. This folder is the effects themselves, not the damage model
or who triggers them.

## Folder layout

```
vfx/
  particle_director.gd     ParticleDirector — watches the sprite, emits per frame
  laser_beam.gd            LaserBeam — raycast + line beam behaviour
  emitters.json            Frame-indexed particle config (hand-edited)
  laser/
    laser_beam.tscn          Base beam scene (open it and tweak the look)
    laser_beam_<id>.tscn     Per-character inherited beams (laser_beam_lenny.tscn)
    laser_beam_<id>.gdshader Per-character beam shaders (swirl, etc.)
  particles/
    characters/<id>/           Per-character effects — organised into category
      runs/ jumps/ dashes/       subfolders (a character's default run/jump/dash/
      slams/ attacks/ specials/  slam + its named attacks/specials), plus other/
      other/                     for shared bits. A type is found in ANY of these,
                                 so its name needn't match the folder. Characters
                                 not yet reorganised (Katalyst, Wayna) keep flat
                                 scenes in the character root — still resolved.
    characters/<id>/effect_sheets/ Hand-drawn effect ANIMATION strips + their sliced
                                 SpriteFrames (ring_kiss_anim.png/.tres) — see
                                 gen_effect_frames.gd. Authored in the art repo.
    characters/<id>/textures/  Per-character static textures (smoke, beam, sparks)
    enemies/<id>/              Per-enemy effects (baghel/ground_wave.tscn)
    enemies/<id>/textures/     Per-enemy drawn sprites
    shared/                    Reusable across characters (explosions, hits, dust)
    environment/               Ambient / background (water, drifting motes)
    textures/                  Shared particle textures (pixel_ember.png, white.png)
  build/
    build_particles.gd       Scaffold particle-type scenes (skips existing)
    build_laser.gd           Build the base laser scene (skips if it exists)
    gen_particle_textures.py Regenerate the shared particle textures
```

## Particles (frame-indexed VFX)

Extra 2D particles layered over the drawn sprites — e.g. soft embers on top of
Wayna's flame — driven entirely by data. `particle_director.gd` is a child of the
player; it watches the sprite and emits at authored positions during authored
frames. Adding an effect is a texture/scene + a JSON line, no code.

**Three pieces:**

1. **Particle types** — scenes with a `CPUParticles2D` or `GPUParticles2D` root,
   referenced by name, under `vfx/particles/` (see the layout above).

   **Drawn attack sprites** (exported from the art repo's `Particles` layer — see
   that repo's README) live under `vfx/particles/<group>/<id>/textures/`, keeping
   the export's filename for traceability, then renamed by role where used (Lenny's
   `lenbondosen_attack_particles_07.png` → `lenbondosen_beam.png`). They feed
   things like the laser Core texture below.

   A `type` in the JSON resolves by searching, in order: the current character's
   category subfolders (`runs/ jumps/ dashes/ slams/ attacks/ specials/ other/`),
   then the character's own root, then `shared/`, then the flat `particles/`:

   | `type` | Resolves to |
   |---|---|
   | `run_default` | first hit among `characters/<char>/{runs,jumps,…,other}/run_default.tscn`, else `characters/<char>/run_default.tscn`, else `shared/…`, else `particles/…` |
   | `fire_spark` | (Wayna isn't reorganised) falls through the subfolders to `characters/wayna/fire_spark.tscn` |
   | `environment/water` | `vfx/particles/environment/water.tscn` (any `type` containing `/` is an explicit path) |

   Searching every subfolder means a type's **name doesn't have to match its folder**
   — the slam's `fall_wind_streaks` trail sits in `other/` and still resolves under
   the `slam` animation. Character effects stay short in the JSON and can't collide
   between characters; shared/environment effects are addressed directly. A bare
   `vfx/particles/<type>.tscn` still works as a legacy fallback. (`SUBFOLDERS` in
   `particle_director.gd` is the searched list.)

   `build/build_particles.gd` scaffolds a starter scene (it **skips files that
   already exist**, so it never clobbers editor tweaks); textures come from
   `build/gen_particle_textures.py`.
2. **Config** — `emitters.json`, keyed
   `character -> animation -> [ { type, node?, set?, mode, frames, pos } ]`:
   - `type` — a scene whose root is a single `CPUParticles2D`/`GPUParticles2D`,
     **or a `Node2D` bundling several** as one composite attack (the director
     drives all of them, and mirrors the composite by flipping `scale.x`, so its
     child textures flip too; a single-particle root mirrors `direction`/`gravity`
     instead, keeping its texture). Layering separate scenes (several `{…}`) still
     works too.
   - `node` — *optional* **palette addressing**. A "palette" scene bundles several
     *independently-scheduled* emitters as named children; `node` names the one this
     row fires. List the **same `type`** with different `node`s to fire different
     children on different frames — e.g. `attack_finger_guns` holds a `Shot` (fired
     on `[2,4]`) and a `ShotLast` (a different-textured projectile, fired on `[7]`),
     each its own self-contained `Shot`/`Hitbox`/beam. Omit `node` for the whole
     scene (single or composite), as before. This is why a per-frame variant no
     longer needs a whole cloned scene file.
   - `set` — *optional* **property overrides** applied on spawn, so one shared scene
     covers several variants without a clone per tweak. Keys are `"ChildPath:property"`
     (an empty path targets the spawned node itself); a `"res://…"` value is loaded
     as a `Resource`. E.g. `"set": { "Trail:texture": "res://…/last.png" }` reskins
     just the last shot — no second node needed.
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
     he moves on — right for a blast/detonation, and it keeps the burst's hitbox
     where you see the blast instead of dragging it along behind the player.
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
     base as you tune it — the dash stays proportionally fiercer no matter how
     the base fire changes. That's the point: one scene owns the *look*, the JSON
     owns *how hard it hits*. Fork a separate scene only when an effect needs a
     genuinely different look, not just more power.

   **Author every effect facing right.** The director mirrors the whole thing
   when the character turns: `pos.x`, and for `CPUParticles2D` also
   `direction.x` and `gravity.x`. Without that, a jet authored pointing right
   keeps pointing right when the character runs left. (`GPUParticles2D` keeps
   those on a shared `ParticleProcessMaterial` which must not be mutated, so it
   falls back to flipping the node's `scale.x`.)
3. **Director** — instantiated by `player.gd` at runtime (not in the editor).
   Rebuilds its emitters on character swap, so switching away from Wayna removes
   her fire cleanly.

Worked examples, one scene per effect:

| Animation | Type | Frames | `pos` | Character |
|---|---|---|---|---|
| wayna run | `fire_spark` | 5-9 (flight loop) | `[-1, -10]` | Short downward jet under her feet (`sustained`) |
| wayna dash | `fire_dash` | 3-6 (horizontal burst) | `[-1, -9]` | Rearward blast: hotter core, wider size/speed variance, tumbling debris (`sustained`) |

**Reuse vs. fork.** Start by reusing a type with a `boost` — that's cheapest and
keeps one source for the look. Fork a separate scene once the effect needs a
different *character*, not just more power: `boost` can only scale quantity
(amount/speed/size/lifetime), so direction, spread, colour, gravity and rotation
all require their own scene. The dash needed exactly that — it blasts backward
rather than down, which no multiplier can express.

### Making a particle attack deal damage — add a `Hitbox`

A particle effect can carry its **own hand-authored hitbox**, so an attack's reach
is whatever box you draw — no reach formula, no code per attack.

1. In the effect scene, make the root a **`Node2D`** and add a **`Hitbox`** child
   (`Area2D` + `scripts/combat/hitbox.gd`, `collision_layer = 32` → `mask = 16` for
   a player attack) with a `CollisionShape2D` under it. `mouth_blast.tscn` and
   `poison_raiser.tscn` are the worked examples.
2. In the inspector, set the **Shape** *and* the **Damage / Knockback / Stun**
   right on the `Hitbox`. That's the whole authoring step — shape and numbers live
   together on the node.
3. The **`ParticleDirector` arms it for you**: on spawn it sets the box's `source`
   to the player and switches it **on exactly while the effect is emitting** — the
   listed frames for a `sustained` effect, the burst's life for a `burst`. One
   activation = one hit per enemy (the `Hitbox` dedupes), and it re-arms fresh each
   strike. Because the box lives under the composite it **auto-mirrors** with
   facing.
4. **Avoid double-hits:** zero the melee `ATTACKS` entry for that attack so the
   particle's box is the only thing that hits (Lenny's `"special"` is `{"damage": 0}`
   for exactly this reason — his `poison_raiser.tscn` Hitbox carries the hit).

An effect with no `Hitbox` (an aura, a run trail) is unaffected — the director only
arms boxes it finds.

**Keep a ground blast on its platform** — add `"clip_to_ground": true` to a `burst`
entry and, at spawn, the director rays straight down through `L_WORLD`, finds the
platform's edges, and clamps the blast's **rectangular emission band and its
hitbox** to them. The clip is asymmetric — only the side hanging over the ledge is
cut; the inner side keeps full reach — so a wide special fired at the lip looks like
it slammed into the edge instead of spilling into open air. Rectangle emission +
rectangle hitbox only (a radial blast can't be clipped to a rectangular platform by
emission shape); off the edge of everything (no ground under the strike point) it
just isn't clipped. Lenny's `special` uses it.

### `Local Coords` — the one setting that surprises people

Per particle scene, and it decides whether the effect **trails** or stays
**attached**:

- **Off** (world space) — particles are released into the world and left behind.
  Good for embers/smoke trails. But the emitter is moving with the player, so a
  low-velocity plume gets smeared backwards into a diagonal: the faster the
  player, the more angled it looks. This does *not* show in the editor preview,
  where the emitter is stationary.
- **On** (local space) — particles keep the shape you authored and move with the
  player. Matches the editor preview exactly. Good for attached jets/auras.

If an effect looks right in the editor but angled in game, this is why. To get a
trail *and* a straight plume, keep it off and give the particles enough
`initial_velocity` that their own motion dominates the player's ~160 px/s.

> **`Local Coords` also gates texture mirroring.** The director mirrors a composite
> by flipping the root's `scale.x` — but a world-space (`Local Coords` off) particle
> renders decoupled from its node, so the flip never reaches it and an **angled
> texture won't mirror** when the character turns. If a particle's texture must flip
> with facing (drawn to fit one side of the body), turn **`Local Coords` on** so the
> node's transform reaches it. A world-space particle can only ever mirror its
> *motion* (a single root's `direction`/`gravity`), never its texture — so for a
> directional world-space effect, use a texture that reads the same flipped.

Related: `direction` and `spread` do nothing while `initial_velocity` is 0 —
gravity is then the only force acting.

> Soft glowy particles clash with crisp pixel art (we tried — it read as an
> engine effect bolted on). `fire_spark` instead uses a hard-edged texture,
> **nearest** filtering, **normal** blend, and colours sampled from the drawn
> flame, so it reads as pixel art. Keep new types in that style unless a soft
> glow is genuinely wanted.

### Laser beams — `LaserBeam` (`vfx/laser/laser_beam.tscn`)

Particles scatter, so they make a poor *beam*. A laser wants a coherent line that
snaps to its hit point — `RayCast2D` + `Line2D`, not particles. It's a **scene**
(so you open it and tweak the look), with `laser_beam.gd` driving behaviour only.
The tree:

```
LaserBeam (Node2D)
├─ Ray            RayCast2D (masks world) → stops the beam at a wall (pierces enemies)
├─ Halo           Line2D  → wide coloured underlay
├─ Core           Line2D  → the beam; texture_mode = STRETCH, so a drawn sprite dropped
│                           on its `texture` *becomes* the beam
└─ Hitbox         Area2D (Hitbox) → Shape → damages every enemy along the beam
```

Every `Line2D` child is length-matched and width-flashed, so you can add more
lines (a `SwirlLine` with a shader, etc.) and they just work. (Muzzle/impact spark
particles were removed for now — re-add `CPUParticles2D` children when wanted.)

`fire(dir)` orients the whole node (everything's authored along local +x), casts
the ray, sizes the hitbox to the full length, then **extends** every line out from
the muzzle to the hit length over `shoot_time` (so the beam *and any swirl lines
shoot out together*), holds, and fades the **width** to nothing before freeing
itself. Build the base scene with `godot --headless --script vfx/build/build_laser.gd`
(skips the file if it exists, so edits stick).

- **Look = the scene.** Open it and tweak Core/Halo colour + width, or **drop your
  drawn beam sprite on the Core's `texture`**. Two stacked lines (halo under core)
  give the beam depth a single flat gradient can't.
- **Per character (hybrid).** For a distinct beam, right-click the base → *New
  Inherited Scene*, swap the Core texture/colours, save as `laser/laser_beam_<id>.tscn`,
  and point the ability's `BEAM` at it. `laser/laser_beam_lenny.tscn` is the worked
  example: it puts Lenny's drawn sprite
  (`vfx/particles/characters/lenbondosen/textures/lenbondosen_beam.png`) on the Core,
  and `lenbondosen.gd` preloads it instead of the base.
- **Gameplay = passed by the character.** `damage`, `knockback`, `stun`,
  `beam_range`, `source` are fields the ability sets before `fire()`. The Hitbox
  (`L_PLAYER_HIT` → `L_ENEMY_HURT`) damages everything along the beam.
- **Glow.** Core/muzzle colours are **HDR** (> 1) so the `WorldEnvironment` bloom
  (`character_switcher._add_glow()`, `glow_hdr_threshold = 1.0`, +
  `rendering/viewport/hdr_2d`) lights the beam and not the LDR sprites. Tune or
  delete `_add_glow()`; the halo+core still read without it.

**Two ways to fire a beam:**

1. **Frame-scheduled from `emitters.json`** (same timeline as particles). The
   `ParticleDirector` fires any spawned node that is a `LaserBeam` like a `burst`:
   it anchors it at `pos`, sets `source`, and calls `fire()` down the facing — the
   beam then self-orients, self-arms, and self-frees. Drop a `LaserBeam` (or an
   inherited `laser_beam_<id>.tscn`) into a move's **palette** scene as a named
   child and schedule it with `node`:
   ```json
   "special_beam": [
     { "type": "special_beam", "node": "Beam", "mode": "burst", "frames": [4], "pos": [22, -20] }
   ]
   ```
   Gameplay numbers (`damage`, `beam_range`, …) come from the beam scene's own
   exports; tweak per-move with `set` (e.g. `"set": { "Beam:beam_range": 200 }`).
   This is the preferred path now — one frame-indexed config drives particles *and*
   lasers together, editable from code or a future UI.

2. **From ability code** — the hook `CharacterAbility.on_special_strike()`, called
   the instant the special's strike frame lands. `lenbondosen.gd` is the worked
   example — a short (`RANGE = 150`) beam that carries the hit — but it's **currently
   disabled** (`USE_BEAM = false`): Lenny's special is a melee burst now (damage from
   `ATTACKS` "special", look from the `special` particle in `emitters.json`). Flip
   `USE_BEAM` back on (and re-zero his `ATTACKS` special so the box doesn't
   double-hit) to restore it. Use this path when the beam needs code decisions the
   config can't express; otherwise prefer the scheduled path above.

### Adding a new attack effect — where things plug in

Pick the layer by *what the effect is*:

| Goal | Add it to | Code? |
|---|---|---|
| A **visual** on chosen animation frames (spark, trail, drawn sprite) | `vfx/emitters.json` (+ a scene in `vfx/particles/`) | none |
| A hit's **damage / knockback / reach** | the move's `tuning` in `configs/moves.gd` (per character/move/segment) | none |
| A **thing spawned** on a hit, or custom behavior | a `CharacterAbility` script (`scripts/abilities/`) | small |

1. **Frame-indexed particle (no code).** Make/obtain a particle scene under
   `vfx/particles/characters/<id>/<name>.tscn` (code-build via `build/build_particles.gd`,
   hand-make one, or use a drawn `Particles`-layer texture), then register it in
   `emitters.json`: `<id> → <animation> → [{type, mode ("sustained"|"burst"),
   frames (sheet-relative), pos ([x,y] from feet, auto-mirrored)}]`. Done — the
   `ParticleDirector` emits it.
2. **Tune the hit (no code).** The move's `tuning` in `configs/moves.gd` — `damage`,
   `knockback`, `stun`, `color`, and hitbox `x`/`extents` (an array = one entry per
   combo segment). The effect keys off the move's `animation` name in `emitters.json`.
3. **Spawn something / new behavior (a `CharacterAbility`).** Create
   `scripts/abilities/<id>.gd` extending `CharacterAbility` (auto-equipped, no
   registration) and override a hook:
   - `on_special_strike(player)` — the moment the special connects; spawn a beam /
     projectile / shockwave here (`add_child` → position → **`reset_physics_interpolation()`**
     → `fire()`).
   - `physics(player, delta)` — per-frame movement/state override (Katalyst's special).
   - `setup(player)` — one-time on equip.
   - **New laser:** inherit `vfx/laser/laser_beam.tscn` → `vfx/laser/laser_beam_<id>.tscn`,
     swap Core texture/colours/swirls, then `preload` + `fire(dir)` from the ability.

> Only the **special** has an on-stArike ability hook today; light-attack VFX go
> through `emitters.json` (frame-indexed). Want an `on_light_strike` (or a generic
> `on_strike(kind, seg)`) hook for light-attack specials? It's a one-line add to
> `player._on_frame_changed` / `_process_attack` — ask and I'll wire it.

## Build tools

Run from the project root. All three are idempotent scaffolds — they never clobber
hand-tuned scenes.

| Command | Purpose |
|---|---|
| `python3 vfx/build/gen_particle_textures.py` | Regenerate the shared particle textures (`vfx/particles/textures/*.png`) |
| `godot --headless --script vfx/build/build_particles.gd` | Scaffold particle-type scenes (`vfx/particles/*.tscn`; skips existing) |
| `godot --headless --script vfx/build/build_laser.gd` | Build the base laser scene (`vfx/laser/laser_beam.tscn`; skips if it exists) |
| `godot --headless --script tools/gen_effect_frames.gd` | Slice drawn effect strips → SpriteFrames (see **Drawn projectile animations** below) |

### Drawn projectile animations (an `AnimatedSprite2D`, not particles)

When you want a projectile to play a **hand-drawn frame animation** (a ring forming
and flying, say) instead of a particle emitter repeating one texture, build it as a
`Shot` that carries an `AnimatedSprite2D`:

1. Export the projectile as a **horizontal strip** named `<name>_anim.png` into the
   character's **`effect_sheets/`** folder (e.g.
   `characters/feyke/effect_sheets/ring_kiss_anim.png`). These drawn effect sheets are
   authored in the art repo under `art/characters/<char>/effect_sheets/`; keep static
   emitter textures (smoke, sparks) in `textures/` instead.
2. Run `godot --headless --script tools/gen_effect_frames.gd` — it finds every
   `*_anim.png` under `vfx/particles/` and slices it (128px frames by default, or set
   a count in the tool's `OVERRIDES`) into `<name>_anim.tres`, a `SpriteFrames` with
   one `default` animation.
3. In the projectile scene, make the root a `Node2D` with **`shot.gd`**, and give it
   an `AnimatedSprite2D` child (`sprite_frames` = the `.tres`, `autoplay = "default"`)
   plus a `Hitbox`. The `Shot` handles travel/homing/hit; the sprite is just its look.
   The `Hitbox` can sit **anywhere** in the scene (e.g. under the `AnimatedSprite2D`) —
   `shot.gd` finds it by search, not a fixed path.

The `ParticleDirector` fires it like any other `burst` — it accepts a `Shot` (or a
`LaserBeam`) even with **no particle emitters**, since those carry their own visual
and manage their own life. Facing is by travel direction: the shot rotates to its
heading, so author the strip pointing **right**.

**`Shot` exports** (`scripts/combat/shot.gd`): `speed`, `homing` (steer rate; 0 = fly
straight), `max_range`, `acquire_range`. Targeting is **x-axis only**: it locks the
nearest enemy *ahead in the facing/mouse direction*, ignores enemies overhead
(`vertical_reach`), and **never steers upward** — it can only track level or *down*
toward a lower enemy. Set `can_fly_up = true` to lift those limits (e.g. a future
Wayna shot). `impact_effect` (a `PackedScene`) spawns a one-shot effect at the point
of contact when it hits — a hit spark/puff — and self-frees; leave empty for none.
