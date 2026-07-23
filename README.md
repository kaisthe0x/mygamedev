# mygamedev

A 2D pixel-art action platformer in **Godot 4.7**. One player controller drives
any of five characters, which share an animation set and can be swapped at
runtime.

Main scene: `scenes/level.tscn`. Press F5 to run.

---

## Layout

```
assets/portraits/     Painted 1080x1080 character portraits (HUD art)
particles/            Particle-type scenes, organised (see Particles section)
resources/characters/ GENERATED SpriteFrames -- do not hand-edit
resources/enemies/    GENERATED enemy SpriteFrames -- do not hand-edit
resources/particles/  emitters.json -- frame-indexed VFX config (hand-edited)
scenes/               player, level, hud
scripts/              player, hud, character_switcher, particle_director
scripts/abilities/    Per-character abilities, named <character_id>.gd
scripts/combat/       Combat layers, hurtbox, hitbox, floating health bar
scripts/enemies/      Enemy base + projectile
sprites/characters/   Source pixel-art sheets, one folder per character
sprites/enemies/      Source enemy sheets, one folder per enemy
tools/                Generator + verification scripts (not shipped)
```

## Controls

| Input | Action | Notes |
|---|---|---|
| A / D | `move_left` / `move_right` | |
| S / ↓ | `move_down` | Hold + jump to drop through a one-way platform |
| Space | `jump` | |
| Shift | `dash` | Has a cooldown |
| Left mouse | `attack` | Light — each press advances the combo |
| Right mouse | `heavy_attack` | Committed full-animation swing |
| Q / E | `prev_character` / `next_character` | Dev only |
| Z / X | `debug_damage` / `debug_heal` | Dev only |
| 0 | `debug_respawn` | Dev only — clear + respawn all enemies |

Bound to **physical** keycodes, so they stay in the same place on AZERTY/Dvorak.
Rebind under `Project > Project Settings > Input Map`.

Q/E/Z/X live in `scripts/character_switcher.gd` — all the dev scaffolding is in
that one file so it can be deleted in one go.

---

## The sprite pipeline

This is the part worth understanding, because the source sheets are irregular.

### The problem

Each character has up to seven sheets (`idle`, `run`, `jump`, `land`, `dash`,
`attack`, `heavy_attack`) — `land` is newer, so a character without one is just
skipped (see below). They are single-row grids, but nothing else is consistent:

- Frame counts vary (2-13+) between animations *and* between characters — the
  slicer (`frame_count`) auto-detects the count, up to a generous cap, so long
  combo/dash sheets (Katalyst's 13-frame dash) work without configuration
- Frame sizes vary wildly — khalid's idle is 32x32, his attack is 143x48
- Some sheets have a constant horizontal padding bias (lenbondosen's dash sits
  ~24px left of centre)

Slicing them naively makes the character jump sideways and change height every
time the animation changes.

### The fix

`tools/gen_spriteframes.py` analyses each sheet and normalises every frame onto
one shared canvas (**currently 130x80**):

- **Vertically** — the frame bottom becomes the canvas bottom. The sheets are
  foot-anchored, so this puts feet on a fixed line.
- **Horizontally** — anchored on **frame 0**, the static idle-reference pose
  present at the start of every sheet (see "Frame 0" below). Its bounding box
  matches the idle pose, so anchoring on it aligns every animation to idle.
  Anchoring on the average instead would let wayna's dash fire trail or an
  attack's swing arc drag the body off-centre. Later frames keep their own
  offsets, so lunges still lunge.

### Frame 0 is the idle reference

The **first frame of every sheet is a static idle pose**, included so the art
lines up with idle and giving the generator its alignment anchor. It is *not*
part of the action: for every animation except `idle`, the generator **drops
frame 0** and playback starts on the real first frame. `idle` keeps all its
frames (frame 0 belongs to it).

Consequences worth knowing:
- Frame indices in `OVERRIDES` / `HIT_FRAMES` are **sheet-relative** (they count
  frame 0); the generator subtracts 1 to get the emitted index the player sees.
- An action sheet needs at least 2 frames (idle-ref + one real frame).
- Anything tied to a specific played frame — e.g. katalyst's stomp `WIND_UP` —
  is expressed in emitted indices and must be retimed if the layout changes.

Normalisation is stored as `AtlasTexture.margin`, so **no images are rewritten
and no extra VRAM is used** — the atlases still point at the original PNGs.

Because every character lands on the same canvas, swapping is a one-line
`sprite_frames` swap. No per-character offsets or colliders.

**The canvas size is derived, not fixed** — it grows to fit the widest padded
frame, so art changes can move it (156x71 -> 164x80 -> 130x80 so far).
`player.gd` reads the frame size on load and sets the sprite offset from it
(origin at the feet), so nothing has to be updated by hand when it moves.

### Target frame size: 128x80

All 30 sheets are now **128x80**. The generator doesn't require uniformity (it
still handles mixed sizes), but standardising means every sheet shares a grid.

**Frame size alone doesn't shrink the canvas — centring does.** The canvas must
be wide enough to hold every animation once frame 0 is aligned, so a sheet whose
character sits off-centre in frame 0 forces padding on *every* character. After
re-centring wayna and khalid the canvas is down to **130** — the last 2px is
lenbondosen's frame 0 sitting 1px left, which is negligible.

So the rule for new art is both halves:

1. 128x80 frames
2. **In frame 0, the character horizontally centred in the frame.** Later frames
   can lunge or trail VFX freely — only frame 0 is the anchor.

The generator prints the worst offenders whenever the canvas exceeds the widest
frame, so it's obvious which sheets still need re-centring.

### Regenerating

> **Replacing a PNG is not enough — you must regenerate.** The `.tres` files
> store hardcoded `region` rectangles (`Rect2(0, 0, 32, 32)` and so on). Swap in
> a sheet with different frame sizes and those rectangles now slice the wrong
> part of the image, so frames render blank or clipped. **Symptom: frames
> "disappear" on some actions after an art update.** Fix: re-run the generator.

```bash
python3 tools/gen_spriteframes.py                    # rewrites resources/characters/*.tres
godot --headless --script tools/verify_frames.gd     # asserts it all loads
```

Run the generator after adding a character or re-exporting any sheet. Frame
counts, sizes and canvas are all re-derived — nothing is hardcoded.

Animation speed and looping live in the `ANIMS` dict at the top of the
generator:

| Animation | FPS | Loops |
|---|---|---|
| idle | 6 | yes |
| run | 10 | yes |
| jump | 10 | no |
| dash | 12 | no |
| attack | 12 | no |
| heavy_attack | 10 | no |

### Per-character timing

Frame counts vary enough that one fps makes some swings drag and others snap, so
`OVERRIDES` (just below `ANIMS`) layers per-character tweaks on top:

- **`fps`** — retime that one animation
- **`hold_last`** — multiply the final frame's duration, letting a pose land
  before the character retracts
- **`loop_from`** — for a looping animation, the sheet frame the cycle restarts
  at. Frames before it play once as an intro; the tail repeats forever.
- **`loop_to`** — optional end of that loop (sheet frame, inclusive). Without it
  the cycle runs to the last frame; with it the loop is `loop_from..loop_to` and
  any frames past `loop_to` show only in the one-time intro pass. Lets a character
  loop a **mid-sheet range** — e.g. Katalyst's idle plays 0-1 to settle in, then
  loops his 2-8 raise-a-flame flourish forever until you press something.

`loop_from` / `loop_to` exist because Godot's `loop` flag is all-or-nothing. The
generator writes the (emitted) indices as resource metadata; `player.gd` jumps
back to `loop_from` when the anim wraps (`_on_animation_looped`) or when it steps
past `loop_to` (`_on_frame_changed`, on the render frame so nothing flashes).
Wayna's run uses `loop_from`; Katalyst's idle uses both. They're sheet-relative
(count the idle-ref frame 0), same numbering as `HIT_FRAMES`. Each character's
idle can loop a different range — just author `loop_from`/`loop_to` per sheet.

Heavy attacks are tuned toward a ~0.5s feel: khalid `hold_last` 2.5 (few frames,
so the last pose sits rather than the whole swing slowing), lenbondosen 13 fps
and wayna 16 fps (too slow at 10). The generator prints resulting durations,
marks overridden entries with `*`, notes loop ranges as `[loop N-M]` and hit
frames as `[hits...]`.

### Attack hit frames — `HIT_FRAMES`

A separate config next to `OVERRIDES` maps `(character, "attack")` to the
**sheet-relative** frames that are combo hits. An attack plays one *segment* per
click, each segment ending on a hit frame, with the frames between hits animating
for smoothness (see **Player → Attack combo**). Any attack not listed defaults to
"every frame is a hit" — one frame per click, the older snap feel. Emitted as
`metadata/hit_frames`, read by `player.gd`.

Configured so far — both give three hits with wind-up / in-between frames:

| Character | `HIT_FRAMES` (sheet indices) |
|---|---|
| feyke | `[2, 3, 7]` |
| lenbondosen | `[1, 2, 6]` — two energy jabs, then the beam finisher |

> **Indices, not frame numbers.** These are 0-based sheet indices, where index 0
> is the idle-reference frame. If you're counting frames 1-N in an image editor,
> subtract one (Lenny's "frames 2, 3, 7" → `[1, 2, 6]`). The generator errors if
> an index is out of range, which usually means the numbering slipped.

---

## Adding a character

1. Drop the six sheets in `sprites/characters/<name>/` named
   `<name>_<anim>_frames.png` (lower case).
2. Add a 1080x1080 portrait at `assets/portraits/<Name>.png`
   (**capitalised** — the lookup expects it).
3. Add the name to `CHARACTERS` and the `@export_enum` list in
   `scripts/player.gd`.
4. Import in Godot (`godot --headless --import`) so the PNGs get UIDs, then run
   the generator and the verifier.
5. Optionally add `scripts/abilities/<name>.gd` — see **Character abilities**.

### Rules the art must follow

The generator adapts to any frame count (1-12), size, and padding. These four
things it assumes — and they **fail silently as misalignment, not as an error**:

1. **Frame 0 is the static idle-reference pose, no VFX.** It is the horizontal
   anchor *and* is dropped from action playback. If a dash's frame 0 already has
   the fire lit, that whole animation sits off-centre and the drop eats a real
   frame.
2. **Feet touch the bottom edge.** Trailing transparent rows make the character
   float.
3. **Single row.** Frame detection only divides horizontally.
4. **12 frames max**, and the naming above.

Adding a new *animation type* (`hurt`, `death`, ...) means one line in `ANIMS`
and a matching case in `_animation_for()` in `player.gd`.

---

## Player

`scripts/player.gd` — a `CharacterBody2D` with a small state machine
(`IDLE / RUN / JUMP / DASH / ATTACK / HEAVY_ATTACK / LAND`). Everything is tunable
in the inspector.

| Group | Key values |
|---|---|
| Health | `max_health` 100 |
| Movement | `run_speed` 160, `jump_velocity` -330, `gravity` 900, `fall_gravity_scale` 1.35, `run_anim_speed` 1.5 |
| Dash | `dash_speed` 420, `dash_time` 0.18, `dash_cooldown` 0.45, `dash_gravity_scale` 0.35 |
| Attack | `attack_recovery` 0.12, `combo_reset_time` 0.45 |
| Juice | `fall_tilt_degrees` 8, `fall_tilt_at_speed` 600, `land_min_fall_speed` 140 |

**Landing squash (`LAND`).** On touchdown from a real fall (peak downward speed
≥ `land_min_fall_speed`, so little hops and walking off a lip don't trigger it),
a character that *has* a `land` animation plays a brief squash. It's **fully
cancelable** — any action (attack / heavy / dash / jump) or a movement input
breaks out instantly, so it never eats inputs; left alone it plays once and hands
back to idle. Characters without a `land` sheet skip straight to idle/run as
before. Only Katalyst has one so far.

**Attack combo (LMB).** One press plays one *segment* — the frames up to the
next hit animate, then the sprite holds the hit frame for a short
`attack_recovery` and hands control back to idle. Hit frames come from the
`HIT_FRAMES` config via SpriteFrames metadata (`_attack_hits()`); an attack with
no entry treats every frame as a hit, so each click advances one frame. Feyke,
lenbondosen and katalyst have authored hit frames (three hits with smooth
wind-up/in-between frames — katalyst's are whip-reach / spin-AoE / finisher);
khalid and wayna still step one frame per click.

Two separate timers, which matters — coupling them once made the hit frame
freeze for the whole chain window:
- **`attack_recovery`** — how long the hit frame holds before idle resumes. Keep
  it short; it's just enough to read the hit.
- **`combo_reset_time`** — how long a follow-up press still *continues* the combo
  rather than restarting it. It keeps ticking after control returns to idle, so
  you can chain even once you're moving again. Lapsing it (or pressing past the
  finisher) restarts at segment one.

Clicks mid-segment are dropped (keeps the rhythm) — change `_process_attack` if
you want light-attack input buffering. A **heavy** press *is* buffered, though:
pressing RMB any time during a light swing is remembered and fires the instant
that hit lands (`_buffered_heavy`), so a fast light→heavy always cancels into the
heavy instead of the press being swallowed by the recovery frames.

**Heavy attack (RMB).** Deliberately *not* a combo — one press plays the entire
animation, roots the player, and ignores all input until it finishes. It also
clears any light combo in progress (all three entry points go through
`_start_heavy()`). The strike lands on the frame given by the
`heavy_attack` entry in `hit_frames` metadata (`_heavy_strike_frame()`) — e.g.
Katalyst's lands on his blast frame — or, if a character didn't author one, on
the middle frame as a default. Durations are hand-tuned per character — see
**Per-character timing** above.

**Dash.** Frame counts differ per character (3-13+), so a fixed `dash_time` would
clip the longer ones. Playback is stretched to fit instead (`speed_scale`
derived from the anim length ÷ `dash_time`), which keeps dash *distance*
identical for every character while always playing the full animation — so even
Katalyst's 13-frame transform-dash plays fully inside the 0.18s window. Grounded dashes stay level; air dashes keep
falling at `dash_gravity_scale` so they arc instead of hanging on an invisible
floor.

**Fall tilt.** The sprite leans forward proportional to falling speed, up to
`fall_tilt_degrees` (about 5 degrees on a normal jump, 8 on a long drop). Set it
to 0 to disable. Rotation pivots on the node origin, which sits at the feet.

**API for other systems:** `take_damage()`, `heal()`, `is_alive()`,
`set_character()`, `cycle_character()`, `portrait_path()`, and the
`health_changed` / `character_changed` signals.

> Health is deliberately bare — no damage sources, i-frames, or death handling
> yet, because nothing can hurt you.

---

## Character abilities

Each character can have a unique ability. **This is the place to add
character-specific behaviour** — the Player itself stays generic, with no
per-character branching.

Drop a script at `scripts/abilities/<character_id>.gd` extending
`CharacterAbility`. The Player finds it by filename when that character is
equipped — no registration, no scene edits. A character with no file simply has
no ability.

```gdscript
extends CharacterAbility

func physics(player: Player, _delta: float) -> void:
    if player.get_state() == Player.State.HEAVY_ATTACK and not player.is_on_floor():
        player.velocity.y = 0.0
```

Two hooks, both optional:

| Hook | When | Use for |
|---|---|---|
| `setup(player)` | Once, on equip | One-off changes (`player.run_speed = 200`), resetting state |
| `physics(player, delta)` | Every physics frame, **after** the state machine sets velocity and **before** `move_and_slide()` | Movement overrides — whatever you set here wins |

`physics` runs last on purpose, so an ability can override anything the state
machine decided. `player.get_state()` exposes the current state
(`Player.State.HEAVY_ATTACK`, etc.), and the whole Player API — `take_damage()`,
`velocity`, `is_on_floor()`, every exported tunable — is available.

Add event hooks (on-hit, on-land) to `character_ability.gd` as they're needed;
existing abilities keep working because the base class no-ops every hook.

### Current abilities

| Character | Ability | Effect |
|---|---|---|
| Lenbondosen ("Lenny") | **Hangtime** + **Sprint** | Hangtime: a heavy attack started mid-air suspends him until it finishes. Sprint: once his run reaches its sustained loop (past `loop_from`), his speed surges to `run_speed × 1.8` — reward for keeping the run going. Uses `player.run_loop_reached()`. |
| Katalyst | **Stomp** | A heavy attack started mid-air becomes a ground slam: he hangs for the wind-up, then drives straight down at `SLAM_SPEED` until he lands. |

Both latch on the frame the heavy *starts* and only if the character was
airborne then — checking the state alone would also fire for a grounded heavy
that walks off a ledge mid-swing.

Katalyst's `WIND_UP` (0.1s) is timed to his animation: after the idle-ref frame
is dropped the downward strike is emitted frame 1, which at 10 fps begins at
0.1s, so the drop starts exactly as he swings. **Retime `WIND_UP` if his
heavy_attack fps or frame layout changes.**

Known edge: the slam lasts only as long as the heavy animation, so it covers
about 330px of fall (0.30s at 1100px/s after the wind-up). From higher than that
the swing ends mid-air and he finishes the drop as a normal fall. Fine for
typical platform heights; if it ever matters, have the ability keep driving
`velocity.y` until `is_on_floor()` instead of stopping when the state ends.

---

## Particles (frame-indexed VFX)

Extra 2D particles layered over the drawn sprites — e.g. soft embers on top of
Wayna's flame — driven entirely by data. `scripts/particle_director.gd` is a
child of the player; it watches the sprite and emits at authored positions
during authored frames. Adding an effect is a texture/scene + a JSON line, no
code.

**Three pieces:**

1. **Particle types** — scenes with a `CPUParticles2D` or `GPUParticles2D` root,
   referenced by name. Laid out to scale as characters and effects are added:

   ```
   particles/
     characters/<id>/   Per-character effects (wayna/fire_spark.tscn)
     enemies/<id>/      Per-enemy effects (baghel/ground_wave.tscn)
     shared/            Reusable across characters (explosions, hits, dust)
     environment/       Ambient / background (water, drifting motes)
     textures/          Particle textures (pixel_ember.png, soft_dot.png)
   ```

   A `type` in the JSON resolves **most specific first**:

   | `type` | Resolves to |
   |---|---|
   | `fire_spark` | `characters/<current character>/fire_spark.tscn`, else `shared/fire_spark.tscn` |
   | `environment/water` | `particles/environment/water.tscn` (any `type` containing `/` is an explicit path) |

   So character effects stay short in the JSON and can't collide between
   characters, while shared and environment effects are addressed directly. A
   bare `particles/<type>.tscn` still works as a legacy fallback.

   `tools/build_particles.gd` scaffolds a starter scene (it **skips files that
   already exist**, so it never clobbers editor tweaks); textures come from
   `tools/gen_particle_textures.py`.
2. **Config** — `resources/particles/emitters.json`, keyed
   `character -> animation -> [ { type, mode, frames, pos } ]`:
   - `mode` — **sustained** (emit while any listed frame is on screen; the fire
     trail) or **burst** (one-shot each time a listed frame is entered; impacts,
     footfall dust).
   - `frames` — **sheet-relative** indices (same numbering as `loop_from` /
     `hit_frames`; the idle-reference frame counts). Converted to emitted indices
     via the `sheet_start` SpriteFrames metadata.
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

Wayna is the worked example, with one scene per effect:

| Animation | Type | Frames | `pos` | Character |
|---|---|---|---|---|
| run | `fire_spark` | 5-9 (flight loop) | `[-1, -10]` | Short downward jet under her feet |
| dash | `fire_dash` | 3-6 (horizontal burst) | `[-1, -9]` | Rearward blast: hotter core, wider size/speed variance, tumbling debris |

**Reuse vs. fork.** Start by reusing a type with a `boost` — that's cheapest and
keeps one source for the look. Fork a separate scene once the effect needs a
different *character*, not just more power: `boost` can only scale quantity
(amount/speed/size/lifetime), so direction, spread, colour, gravity and rotation
all require their own scene. The dash needed exactly that — it blasts backward
rather than down, which no multiplier can express.

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

Related: `direction` and `spread` do nothing while `initial_velocity` is 0 —
gravity is then the only force acting.

> Soft glowy particles clash with crisp pixel art (we tried — it read as an
> engine effect bolted on). `fire_spark` instead uses a hard-edged texture,
> **nearest** filtering, **normal** blend, and colours sampled from the drawn
> flame, so it reads as pixel art. Keep new types in that style unless a soft
> glow is genuinely wanted.

---

## Enemies & combat

### Enemy sprites

Enemies use the **same pipeline** as characters, just a different group and
animation set (`idle`, `stroll`, `melee_attack`, `range_attack`). Source sheets
live in `sprites/enemies/<id>/`; `gen_spriteframes.py` processes both groups (see
`GROUPS` at the top) and writes `resources/enemies/<id>.tres`. Enemies share their
own normalised canvas, independent of the character canvas. Same 128x80 + frame-0
idle-reference rules apply.

### The `Enemy` node (`scripts/enemies/enemy.gd`, `scenes/enemy.tscn`)

One reusable ground enemy. `enemy.tscn` is a thin wrapper (root + script) so it
can be dropped into a level and tuned in the inspector; the sprite, hurtbox,
hitboxes and health bar are still built in code, so the scene has nothing fragile
to hand-wire. Key traits:

- **Capabilities are inferred from the art.** `melee_attack` / `range_attack`
  animations present → that attack is enabled. An enemy with only one attack
  just works; missing animations are simply never used.
- **Behaviour:** patrols between its spawn point and `spawn + patrol_distance`,
  pausing `idle_time_min..max` seconds at each end. If the player enters
  `ranged_range` it engages — **melee** within `melee_range`, else **ranged**.
- **Edge-aware:** a downward probe `edge_check_x` ahead of each foot stops it
  walking off ledges — it turns around on patrol and won't chase off a platform.
  So enemies can stroll on platforms safely.
- **`aggro`** (default **off**): when on, it *chases* the player up to
  `aggro_range` instead of only fighting whoever wanders into range. It's an
  export, so it's **per instance** — one enemy can be aggressive while another of
  the same type isn't (set it in the inspector on a placed `enemy.tscn`, or per
  entry in the spawner roster).
- **`contact_damage`** (default **0 = off**): when set, touching the player
  deals it on `contact_interval`. Also per-instance.
- **Ranged** fires a `projectile.gd` from `muzzle_offset` on the animation's
  hit frame (`hit_frames` metadata). Two `ranged_mode`s:
  - `"aimed"` — flies toward the player's torso (Kebus' staff bolt).
  - `"forward"` — surges straight ahead along the ground for `ranged_travel` px
    then fizzles, hitting whatever it passes (Baghel's red energy). Tint via
    `ranged_color`.
  - **Look** — `ranged_particle` points at a particle scene (e.g.
    `particles/enemies/baghel/ground_wave.tscn`) that the projectile instances as
    its visual, so you edit/preview it in the editor like any particle scene
    (they're built `emitting = true`). Empty = a simple orb trail built in code
    (Kebus). `ranged_hitbox_extents` / `ranged_hitbox_offset` size the collider
    (a small box for a bolt, a tall slab rising from the ground for a wave).
    Baghel's wave is a **crest**: chunks kick up-and-forward out of a
    ground-hugging emission strip and arc back down under gravity while the
    projectile outruns them (`local_coords = off`), so they trail into a rolling
    swell. Keep his `muzzle_offset.y` near 0 so the emission base sits on the
    ground — a negative y lifts the whole wave off it.
  - **Ground trail** — a `"forward"` shot sets `proj.ground_trail`, so
    `projectile.gd` adds a second, code-built emitter that lays longer-lived red
    embers along the floor (`local_coords = off`, so they stay put as the shot
    rolls on) that linger and fade behind it. Its colour is **sampled from the
    wave's gradient** (`_sample_visual_color`), so it always matches whatever red
    you tint `ground_wave.tscn` to in the editor — no second gradient to keep in
    sync.
  - **Graceful fade** — on impact or when `life` runs out, a projectile doesn't
    `queue_free` instantly (which would vaporise every live particle). It
    `_expire()`s: stops damaging/moving, sets `emitting = false` on all its
    emitters, and frees only after the longest particle lifetime, so the wave and
    its trail fade out instead of popping.
- **Melee** enables a hitbox in front on the animation's hit frame (from the
  `hit_frames` metadata — Kebus: sheet frame 3).
- **`idle_loop_from..idle_loop_to`** (optional): a resting-idle flourish — loops
  those emitted frames for `idle_loop_time` seconds, then plays one full idle
  cycle, and repeats (Baghel scratches his back). Disabled when `to <= from`.
- **Combat vs resting idle.** An `_engaged` flag tracks whether the player is in
  reach (attacking distance). While engaged, the between-attacks idle **holds the
  first idle frame** as a tense ready-stance — no strolling or scratch flourish.
  The moment the player leaves reach `_engaged` clears and normal patrol/idle
  (and the flourish) resume on their own.
- **Attack feel — hit-stop + shake.** On the impact frame (melee contact / the
  ranged smash), `_begin_hitstop()` freezes the sprite on that pose for
  `attack_hitstop` s and jitters it by up to `attack_shake` px (decaying to 0),
  giving the blow weight; the physics loop resumes the swing afterward. Both
  default on (0.18 s / 2.5 px); set either to 0 to disable.
- Carries its own **hurtbox**, **floating health bar + name**, and a **red
  hit-flash**. Attacks carry `*_knockback` / `*_stun` (see below).
- Exposed knobs: health, speed, patrol, ranges, cooldown, damages, knockback,
  stun, hitbox sizes/offsets, aggro, contact damage, and **`body_size` /
  `hurtbox_size`** (per-enemy colliders, so a bigger or smaller enemy fits its
  own sprite instead of a shared hardcoded box). Tune per enemy.

> **Bosses are not Enemies.** They get their own scene/script so their move-sets
> aren't constrained to melee/ranged. `Enemy` is for regular mobs.

### Combat model (`scripts/combat/`)

Damage flows **Hitbox → Hurtbox**, with teams enforced by physics layers (see
`[layer_names]` in project.godot and `combat.gd`), so there's no friendly fire
and no group checks:

- **`Hurtbox`** (Area2D) receives hits and relays them via a `hurt` signal; the
  owner (player/enemy) turns that into `take_damage`.
- **`Hitbox`** (Area2D) deals damage while active, once per activation, and
  carries optional **`knockback`** (px/s shove away from the source) and
  **`stun`** (seconds frozen). Melee boxes toggle on for their active frames;
  projectiles stay on for their life.
- The **player's** hurtbox + attack hitbox are built in code (`_build_combat`),
  like the particle director, to avoid touching `player.tscn`. Light-attack
  hits fire on each combo hit frame; the heavy lands on its authored
  `heavy_attack` hit frame (or the middle frame if none). Whoever is hit applies
  the knockback/stun and takes a brief stagger.
- **`Combatant`** (`scripts/combat/combatant.gd`) is the shared base for `Player`
  and `Enemy` (both `extends Combatant`, itself a `CharacterBody2D`). It holds the
  pieces they'd otherwise each reimplement: `anchor_to_feet` (sprite offset),
  `make_box` (rect collider), `flash` (the red hit-tell), and `apply_knockback`
  (turns a `Hit`'s knockback into a shove + returns the stagger time; the caller
  applies its own stun state). Feel constants live on `Combat`: `KNOCKBACK_POP`,
  `MIN_STAGGER`, `STRIKE_ACTIVE`.

### On-hit effects — the `Hit` object

An attack delivers a `Hit` (`scripts/combat/hit.gd`) — `amount`, `knockback`,
`stun`, `source`, and an optional status overlay (`status_color` / `status_time`).
A `Hitbox`/`Projectile` fills one in; the victim's `_on_hurt(hit)` applies it. Add
a new effect field here and nothing else's signature changes.

- **Enemy attacks** set their fields via exports: `melee_knockback/stun`,
  `ranged_knockback/stun`.
- A knockback always carries a short stagger, or the AI/input would overwrite the
  shove velocity the next frame and nothing would move.
- **Freeze + overlay:** a `stun` of several seconds *is* a freeze; pair it with a
  `status_color` and the victim is engulfed in that colour (`StatusOverlay`, an
  additive tinted copy synced to the sprite) and its pose is paused for the
  duration.

### Player attacks — `ATTACKS` (`player.gd`)

One table per `(character, attack)`, holding both the on-hit effects **and** the
hitbox geometry so they can't drift apart. Each entry is a **dict** where unset
fields fall back to the exported defaults:

| field | meaning | fallback |
|---|---|---|
| `damage` | hit damage | `attack_damage` / `heavy_damage` |
| `knockback` | px/s shove away from the player | 0 |
| `stun` | seconds frozen | 0 |
| `color` / `color_time` | engulfing status overlay + duration | none |
| `x` | hitbox forward offset from the feet | `attack_hitbox_x` |
| `extents` | hitbox half-size | `attack_hitbox_extents` |

```gdscript
"katalyst": {
    "light": [                                                  # ARRAY = per combo segment
        {"damage": 16, "x": 24, "extents": Vector2(22, 18)},    # whip-reach thrust
        {"damage": 16, "x": 0,  "extents": Vector2(32, 20)},    # spin: AoE around the body (x=0)
        {"damage": 16, "x": 28, "extents": Vector2(24, 18)},    # finishing lunge
    ],
    "heavy": {"damage": 44, "knockback": 160, "stun": 0.18, "x": 30, "extents": Vector2(34, 16)},
}
```

- `heavy` is one entry. `light` is **either** one entry (all combo hits share it)
  **or an array**, one per combo segment — that's how a *specific* hit differs
  (Lenny's first jab freezes 5s + green; Katalyst's middle hit is a wide `x = 0`
  around-the-body AoE). A shorter array reuses its last entry.
- `_strike(kind, seg)` reads the entry, sets the effects, and resizes/repositions
  the **one** hitbox shape (`_attack_shape` / `_attack_rect`) — no extra nodes. A
  box at **`x` = 0 with wide extents** hits both sides; `x` flips with facing.
- Unlisted characters/attacks fall back entirely to the exported damage + box.

### Dash i-frames

Dashing is **invulnerable** — the player's hurtbox stops being detectable for the
dash's duration (`_hurtbox.monitorable` is off while in `DASH`), so you can dash
through projectiles and attacks unharmed.

### Spawning & the test level

`character_switcher.gd` (the level script) builds everything in code, to avoid
clobbering `level.tscn` while the editor holds it open:

- **Platforms** — `_platforms` `[center_x, top_y, width]`, one-way `StaticBody2D`s
  on the world layer, arranged as a rising staircase within one jump of each
  other (jump peak ~60px). One-way means you jump up *through* them and land on
  top. Overlapping steps make the hops forgiving.
- **Enemies** — `_roster`, each a `{id, name, pos, ...overrides}` instanced from
  `enemy.tscn`; any extra key sets an Enemy export (so one can be `aggro`, another
  `ranged_mode: "forward"`, etc). Kebus (melee + aimed ranged) strolls each
  platform and the ground; Baghel (ranged-only, forward ground surge, scratches
  his back at rest) waits on the far-right ground. They're
  placed **far from `SPAWN`** (nearest ~400px, beyond `ranged_range`) so you
  start in the clear and can watch them stroll before approaching — not swarmed.
- **Camera** follows the player in **`_physics_process`** with a smoothed `lerp`,
  so it tracks at the same rhythm as the player (see below) — you can traverse
  across.
- **Drop through a platform** — hold **`move_down` (S / ↓) + jump** while standing
  on a one-way platform to fall through it instead of jumping; on the solid floor
  it just jumps. `_drop_through_platform()` finds the platform under the feet via
  the slide collisions (only bodies in the `oneway_platform` group qualify, so you
  can't fall through the ground), adds a brief collision exception, and removes it
  after `DROP_THROUGH_TIME`.

#### Pixel-crisp motion (why running isn't blurry)

The real culprit on a high-refresh monitor (144/240Hz) is the **physics tick
(60Hz) vs refresh-rate mismatch**: without interpolation the character's position
only updates 60×/sec, so it judders/smears no matter how crisp each frame is.
Fixes, all in `project.godot`:
- **`physics/common/physics_interpolation`** — renders nodes smoothly *between*
  physics ticks. This is the main fix. Camera + follow run in `_physics_process`
  so both interpolate together; teleports (spawn, respawn) call
  `reset_physics_interpolation()` (`_place()`) so they snap instead of smearing.
- **`snap_2d_transforms_to_pixel` + `snap_2d_vertices_to_pixel`** — render on
  whole pixels so the interpolated positions stay crisp pixel art.
- **`default_texture_filter = Nearest`** — no linear blur when scaled.

Separate from rendering: a run can still *read* as smeary if the character glides
faster than its legs cycle (**foot-sliding**). `_update_animation` ties the run's
playback to ground speed (`speed / run_speed × run_anim_speed`, clamped), so the
legs keep pace — busier sprinting, slower starting. `run_anim_speed` (default
1.5) is the knob.

> If it *still* looks smeared while moving but each single frame is sharp when you
> pause a screen recording, that's **sample-and-hold display blur** (LCD + eye
> tracking), not a game bug — only higher framerate or lower background contrast
> reduces it.

Separately from rendering sharpness, a run can *read* as smeary if the character
glides faster than its legs cycle (**foot-sliding**). `_update_animation` ties the
run's playback speed to actual ground speed (`speed / run_speed × run_anim_speed`,
clamped), so the legs keep pace — busier when sprinting, slower when starting —
instead of a fixed fps that desyncs the moment speed changes. `run_anim_speed`
(default 1.5) is the tuning knob.
- **Respawn** — falling below `DEATH_Y` (into the void) or dropping to 0 health
  puts the player back at `SPAWN` with full health, and clears in-flight
  projectiles so you're not hit on reappear. No more force-restarting after a
  fall.
- **Dev key `0`** clears and respawns the enemy roster to keep fighting.

Move platforms/enemies into the level scene proper (drag `enemy.tscn` in) when
convenient — this is scaffolding to test jump + attack + traversal.

---

## HUD

`scenes/hud.tscn` + `scripts/hud.gd` — portrait, name, and health bar.

Registered as an **autoload** (`project.godot > [autoload]`), not placed in a
scene. It finds whatever `Player` enters the tree via `get_tree().node_added`,
and hides itself when there is none, so menus and character-select screens stay
clean. This also means no scene file holds a reference to it.

It follows character swaps and health changes over signals — nothing polls.

---

## Gotchas

### Texture filtering: pixel art vs painted art

The project default is **nearest** (`default_texture_filter=0`) for crisp pixel
art. The portraits are 1080x1080 paintings shown at ~104px, and nearest-
filtering a 10x downscale looks terrible.

So the portrait node overrides `texture_filter = 4` (linear + mipmaps), and the
portrait imports have `mipmaps/generate=true`.

**Rule: pixel art inherits the project default; painted or hi-res art needs the
per-node override plus mipmaps.**

### The Godot editor overwrites scene files

The editor holds open scenes in memory and writes its copy over anything changed
on disk. If a scene is edited outside Godot while that scene is open, the editor
silently wins on its next save.

Related: adding a new `@export` to a script while a scene is open makes the
editor serialise the unknown property as `null` on the instance
(`max_health = null`), which overrides the script default.

**This applies to generated `.tres` files too.** If a character resource is open
in the editor's inspector when `gen_spriteframes.py` runs, the editor writes its
stale copy back and that one character silently keeps the old animation set.
`verify_frames.gd` catches it — a mismatched canvas size in its output means
exactly this.

**If you edit scenes or resources outside the editor, close the tab first**, or
use `Project > Reload Current Project` afterwards. This is why the HUD is an
autoload rather than a node in `level.tscn`.

### GDScript LSP warnings in VS Code

`godot-tools` talks to the language server inside the running Godot editor, so
it can only serve one project accurately and warns defensively. Stale indexes
show bogus errors like `Could not find type "Player"` on code that compiles
fine. **Trust the actual run over the squiggles.**

---

## Tools

| Command | Purpose |
|---|---|
| `python3 tools/gen_spriteframes.py` | Regenerate SpriteFrames from the sheets |
| `godot --headless --script tools/verify_frames.gd` | Assert all animations load on a uniform canvas |
| `godot --script tools/capture_shots.gd` | Render every character/animation to PNGs for eyeballing alignment |
| `python3 tools/gen_particle_textures.py` | Regenerate particle textures (particles/*.png) |
| `godot --headless --script tools/build_particles.gd` | Rebuild particle-type scenes (particles/*.tscn) |

---

## Maintaining this file

Keep this README current. When behaviour, controls, tunables, project settings,
or the art pipeline change, update the affected section in the same pass as the
code change.
