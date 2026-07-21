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
resources/particles/  emitters.json -- frame-indexed VFX config (hand-edited)
scenes/               player, level, hud
scripts/              player, hud, character_switcher, particle_director
scripts/abilities/    Per-character abilities, named <character_id>.gd
sprites/characters/   Source pixel-art sheets, one folder per character
tools/                Generator + verification scripts (not shipped)
```

## Controls

| Input | Action | Notes |
|---|---|---|
| A / D | `move_left` / `move_right` | |
| Space | `jump` | |
| Shift | `dash` | Has a cooldown |
| Left mouse | `attack` | Light — each press advances the combo |
| Right mouse | `heavy_attack` | Committed full-animation swing |
| Q / E | `prev_character` / `next_character` | Dev only |
| Z / X | `debug_damage` / `debug_heal` | Dev only |

Bound to **physical** keycodes, so they stay in the same place on AZERTY/Dvorak.
Rebind under `Project > Project Settings > Input Map`.

Q/E/Z/X live in `scripts/character_switcher.gd` — all the dev scaffolding is in
that one file so it can be deleted in one go.

---

## The sprite pipeline

This is the part worth understanding, because the source sheets are irregular.

### The problem

Each character has six sheets (`idle`, `run`, `jump`, `dash`, `attack`,
`heavy_attack`). They are single-row grids, but nothing else is consistent:

- Frame counts vary (3-9) between animations *and* between characters
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

`loop_from` exists because Godot's `loop` flag is all-or-nothing. The generator
writes the (emitted) frame index as resource metadata and `player.gd` jumps back
to it on each wrap (`_on_animation_looped`). Wayna's run uses it: after the
idle-ref frame, the lean/ignite frames play once and the flight tail cycles for
as long as you hold the input.

Heavy attacks are tuned toward a ~0.5s feel: khalid `hold_last` 2.5 (few frames,
so the last pose sits rather than the whole swing slowing), lenbondosen 13 fps
and wayna 16 fps (too slow at 10). The generator prints resulting durations,
marks overridden entries with `*`, notes loop points as `[loop@N]` and hit
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
(`IDLE / RUN / JUMP / DASH / ATTACK / HEAVY_ATTACK`). Everything is tunable in
the inspector.

| Group | Key values |
|---|---|
| Health | `max_health` 100 |
| Movement | `run_speed` 160, `jump_velocity` -330, `gravity` 900, `fall_gravity_scale` 1.35 |
| Dash | `dash_speed` 420, `dash_time` 0.18, `dash_cooldown` 0.45, `dash_gravity_scale` 0.35 |
| Attack | `attack_recovery` 0.12, `combo_reset_time` 0.45 |
| Juice | `fall_tilt_degrees` 8, `fall_tilt_at_speed` 600 |

**Attack combo (LMB).** One press plays one *segment* — the frames up to the
next hit animate, then the sprite holds the hit frame for a short
`attack_recovery` and hands control back to idle. Hit frames come from the
`HIT_FRAMES` config via SpriteFrames metadata (`_attack_hits()`); an attack with
no entry treats every frame as a hit, so each click advances one frame. Feyke and
lenbondosen have authored hit frames (three hits with smooth wind-up/in-between
frames); katalyst, khalid and wayna still step one frame per click.

Two separate timers, which matters — coupling them once made the hit frame
freeze for the whole chain window:
- **`attack_recovery`** — how long the hit frame holds before idle resumes. Keep
  it short; it's just enough to read the hit.
- **`combo_reset_time`** — how long a follow-up press still *continues* the combo
  rather than restarting it. It keeps ticking after control returns to idle, so
  you can chain even once you're moving again. Lapsing it (or pressing past the
  finisher) restarts at segment one.

Clicks mid-segment are dropped (keeps the rhythm) — change `_process_attack` if
you want input buffering.

**Heavy attack (RMB).** Deliberately *not* a combo — one press plays the entire
animation, roots the player, and ignores all input until it finishes. It also
clears any light combo in progress. Durations are hand-tuned per character to
land around 0.50-0.60s despite frame counts ranging 4-9 — see **Per-character
timing** above.

**Dash.** Frame counts differ per character (4-6), so a fixed `dash_time` would
clip the longer ones. Playback is stretched to fit instead (`speed_scale`
1.85-2.78), which keeps dash *distance* identical for every character while
always playing the full animation. Grounded dashes stay level; air dashes keep
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
| Lenbondosen ("Lenny") | **Hangtime** | A heavy attack started mid-air suspends him until it finishes, so the full swing plays instead of being cut short by the fall. Falls resume normally afterwards. |
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
