# mygamedev

A 2D pixel-art action platformer in **Godot 4.7**. One player controller drives
any of five characters, which share an animation set and can be swapped at
runtime.


Main scene: `scenes/level.tscn`. Press F5 to run.

> Potential names for the game:
> - Index32
> - Way of All Flesh

---

## Layout

```
assets/portraits/     Painted 1080x1080 character portraits (HUD art)
configs/              Tuning DATA -- attack table, layers, feel, rosters (see configs/README.md)
helpers/              Shared static utilities -- boxes, node lookup, anim meta (see helpers/README.md)
vfx/                  All visual effects -- particles + drawn slashes (see vfx/README.md)
resources/characters/ GENERATED SpriteFrames -- do not hand-edit
resources/enemies/    GENERATED enemy SpriteFrames -- do not hand-edit
scenes/               player, level, hud
scripts/              player, hud, character_switcher
scripts/abilities/    Per-character abilities, named <character_id>.gd
scripts/combat/       Hurtbox, hitbox, combatant base, health bar (constants -> configs/combat.gd)
scripts/enemies/      Enemy base + projectile
sprites/characters/   Source pixel-art sheets, one folder per character
sprites/enemies/      Source enemy sheets, one folder per enemy
tools/                Generator + verification scripts (not shipped)
```

## Controls

| Input | Action | Notes |
|---|---|---|
| A / D | `move_left` / `move_right` | |
| S / ↓ | `drop` | Tap to fall through the one-way platform you're on (ground only; a no-op on solid floor). Controller: D-pad down / left-stick down; remappable in the Input Map |
| Space | `jump` | Press again in the air to **double jump** (`max_air_jumps`) — the air jump re-boosts and spawns the character's jump particles; the ground jump is silent |
| Shift | `dash` | Has a cooldown |
| Left mouse | `attack` | The current *attack* — each press advances the combo (or, for a `"flurry"` attack like Khalid's, **hold** to keep punching). **Ground only** (no air attacks) |
| Right mouse | `special` | On the ground: the current *special* (committed full-animation move). **In the air: performs the ground slam instead** (characters with a `slam` sheet) |
| Q / E | `prev_character` / `next_character` | Dev only |
| Z / X | `debug_damage` / `debug_heal` | Dev only |
| 0 | `debug_respawn` | Dev only — clear + respawn all enemies |

Bound to **physical** keycodes, so they stay in the same place on AZERTY/Dvorak.
Rebind under `Project > Project Settings > Input Map`.

**Facing follows movement.** The character faces the direction it last moved
(A/D or the stick), and **attacks/specials strike that way** — where the character
is actually facing, controller-friendly. Standing still keeps the last facing; the
mouse cursor does **not** steer facing or aim (a previous mouse-look experiment was
removed). If you want cursor-aim back for keyboard+mouse without breaking controller
play, the clean way is "last input device wins" — ask and I'll wire it.

Q/E/Z/X live in `scripts/character_switcher.gd` — all the dev scaffolding is in
that one file so it can be deleted in one go.

**The test level is vertical.** `configs/level_config.gd` holds it as data —
`PLATFORMS` (a tall zigzag tower of one-way platforms, each `[center_x, top_y,
width]`) and `ROSTER` (the enemy spawn list). `character_switcher.gd` builds both in
code (the `.tscn` stays minimal because the editor clobbers it) and its camera
follows the player up, so there's **no height limit — add `PLATFORMS` rows to go
higher**. Steps are ~70–95px apart, cleared with the jump + the generous air jumps.
Fall off and you drop back to the ground floor (only leaving the world past the
floor edges past `DEATH_Y` respawns you). The tower is capped by an **extra-long
summit platform** (the last, very wide `PLATFORMS` row) packed with a ~40-enemy
horde — so a handful contest the climb and the crowd waits at the top.

---

## The sprite pipeline

This is the part worth understanding, because the source sheets are irregular.

### The problem

Each character has up to several sheets (`idle`, `run`, `jump`, `fall`, `land`,
`dash`, `slam`, `attack`, `special`, `death`) — `fall`, `land`, `slam`, and `death` are
optional, so a character without that sheet just can't do it (the mechanic no-ops for
them; a character with no `death` sheet just respawns instantly — see below). They are single-row grids, but nothing else is consistent:

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
- Anything tied to a specific played frame — e.g. katalyst's double_pierce `WIND_UP` —
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
| fall | 10 | yes |
| land | 12 | no |
| slam | 12 | no |
| dash | 12 | no |
| attack | 12 | no |
| special | 10 | no |

### Per-character timing

Frame counts vary enough that one fps makes some swings drag and others snap, so
`OVERRIDES` (just below `ANIMS`) layers per-character tweaks on top:

- **`fps`** — retime that one animation
- **`hold_last`** — multiply the final frame's duration, letting a pose land
  before the character retracts
- **`FRAME_DURATIONS`** (a separate config below `HIT_FRAMES`) — multiply the
  duration of *any individual frame*, `(char, anim) -> {sheet_frame: multiplier}`.
  Each frame normally shows for `1/fps`; `2.0` holds it twice as long, `0.5` half —
  so you can make a wind-up snap or a key pose linger without retiming the whole
  animation. Sheet-relative indices (idle-ref frame 0 counts), same numbering as
  `HIT_FRAMES`/`loop_from`. It's the general form of `hold_last` (which only
  targets the last frame); a value here wins over `hold_last` for that frame. Out-
  of-range indices are rejected. Godot stores it as each frame's `duration` in the
  `.tres`, so it survives regeneration.
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

Special attacks are tuned toward a ~0.5s feel: khalid `hold_last` 2.5 (few frames,
so the last pose sits rather than the whole swing slowing) and lenbondosen 13 fps
(too slow at 10). The generator prints resulting durations,
marks overridden entries with `*`, notes loop ranges as `[loop N-M]` and hit
frames as `[hits...]`.

### Attack hit frames — `HIT_FRAMES`

A separate config next to `OVERRIDES` maps `(character, "attack")` to the
**sheet-relative** frames that are combo hits. An attack plays one *segment* per
click, each segment ending on a hit frame, with the frames between hits animating
for smoothness (see **Player → Attack combo**). Any attack not listed defaults to
"every frame is a hit" — one frame per click, the older snap feel. Emitted as
`metadata/hit_frames`, read by `player.gd`.

Configured so far (keyed by the move's animation, since a character has several),
with wind-up / in-between frames between the hits:

| Character | Animation | `HIT_FRAMES` (sheet indices) |
|---|---|---|
| feyke | `attack_ring_kiss` | `[3]` — single-burst "kiss" shot |
| feyke | `special_f_you` | `[2]` |
| katalyst | `attack_rope_dart_dance` | `[2, 6, 10]` — whip-reach, spin-AoE, finisher |
| katalyst | `special_double_pierce` | `[3]` |
| lenbondosen | `attack_finger_guns` | `[2, 4, 7]` — three shots |
| lenbondosen | `special_mouth_blast` | `[3, 6, 9]` |
| lenbondosen | `special_poison_raiser` | `[4]` |

Specials list a strike frame the same way (keyed by the special's animation);
without one the special lands on its middle frame.

> **Indices, not frame numbers.** These are 0-based sheet indices, where index 0
> is the idle-reference frame. If you're counting frames 1-N in an image editor,
> subtract one. The generator errors if an index is out of range, which usually
> means the numbering slipped (or the sheet's frame count changed).

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
4. **Up to ~32 frames** (the `frame_count` cap), and the naming above.

Adding a new *animation type* (`hurt`, `death`, ...) means one line in `ANIMS`
and a matching case in `_animation_for()` in `player.gd`.

---

## Player

`scripts/player.gd` — a `CharacterBody2D` with a small state machine
(`IDLE / RUN / JUMP / FALL / DASH / ATTACK / SPECIAL / LAND / SLAM`). Everything is tunable
in the inspector.

| Group | Key values |
|---|---|
| Health | `max_health` 100 |
| Movement | `run_speed` 160 & `jump_velocity` -330 (both **per character** — see below), `max_air_jumps` 1, `gravity` 900, `fall_gravity_scale` 1.35, `run_anim_speed` 1.5 |
| Dash | `dash_speed` 420 (**per character** — see below), `dash_time` 0.18, `dash_anim_time` 0.30, `dash_cooldown` 0.45, `dash_gravity_scale` 0.35 |
| Slam | `slam_speed` 1200, `slam_min_clearance` 50, `slam_hold_frame` 2, `slam_impact_distance` 30, `slam_min_drop` 120 / `slam_max_drop` 700 / `slam_max_damage_mult` 2.5 (drop-scaled damage) |
| Attack | `attack_recovery` 0.12, `combo_reset_time` 0.45 |
| Juice | `land_min_fall_speed` 140, `land_predict_distance` 22 |

**Per-character movement feel.** `run_speed`, `jump_velocity`, and `dash_speed` are
seeded on every character change from `CharacterConfig.RUN_SPEEDS` /
`JUMP_VELOCITIES` / `DASH_SPEEDS` (in `configs/character_config.gd`) — edit per-character
values there, not on the Player node (the inspector value is overwritten on swap).
Characters not listed use the `DEFAULT_*` values (`run` 160, `jump` -330 with negative =
up, `dash` 420); **Katalyst runs a touch faster (250), jumps a touch higher (-370), and
dashes a touch faster (500)**. The run *animation* cadence auto-scales to each
character's speed, so faster runners don't foot-slide.

**Blink dash (per character).** A character's dash can be a **blink** (instant teleport)
instead of the glide-lunge — toggled per character in `CharacterConfig.BLINK_DASH`
(`{"khalid": true}` today; anyone unlisted glides). When on, `_enter(State.DASH)` calls
`Player._do_blink()`: it displaces `dash_speed × dash_time` ahead (the *same* reach the
glide would cover, just instant) via `move_and_collide` so it **stops at walls** and
**passes through enemies**, fires the character's own `other/blink_out.tscn` /
`blink_in.tscn` poofs (`fire_effect`, tinted to their dash palette) and a brief bright
flash. The lunge is skipped (`_dash_custom`) but the dash i-frames, cooldown, and
animation still run as the "materialize". `_blink_phase_walls` (default off) is the buff
seam to blink *through* walls. Every character has blink poofs ready, so flipping the
flag is all it takes. (This was Khalid's ability hook; it's now this universal config so
it works for characters that have no ability file.)

**Dash lunge vs. animation.** The lunge (`dash_speed` for `dash_time`) is decoupled
from the dash *animation*, which plays over `dash_anim_time`. When that's longer
than the lunge, the character keeps its full snappy dash then settles to a stop
over the extra time while the remaining frames play out — so you see the dash
instead of a fast-forward. The reach is unchanged (the settle decelerates to a stop
within the window) and the i-frames still last only the lunge. Set
`dash_anim_time <= dash_time` for the old squeezed-into-the-lunge look; raise it to
see the frames more.

**Airborne arc: `JUMP → FALL → LAND`.** The full sequence when a character has the
sheets for it:
- **`JUMP`** plays the launch/rise once (its launch only replays on a *real* jump —
  see the fall-pose note above).
- **`FALL`** (looping) takes over the moment the jump animation finishes while still
  airborne, or whenever you enter the air any other way (walk off a ledge, an air
  action ends). A character with no `fall` sheet just holds the last jump frame, as
  before.
- **`LAND`** starts **predictively** — a downward ray (`land_predict_distance`, 22px,
  against the body's `collision_mask` so it catches solid ground *and* one-way
  platforms) fires it while falling at ≥ `land_min_fall_speed`, so the squash plays
  *through* touchdown instead of after it. It also still triggers on touchdown
  (`_just_landed`) as a fallback. It's **fully cancelable** — any action breaks out
  (air-rules during the brief pre-land: specials become the slam, attacks are
  grounded-only); left alone it plays once and hands back to idle/run. A character
  with no `land` sheet skips straight to idle/run.

Each phase is **opt-in per character** by the presence of the `fall` / `land` sheet.
**All five characters now have both.** (Khalid's full kit — movement VFX
(run/jump/fall/dash/double-jump), a **ground slam** (`slam_default` + `slam_wind_streaks`),
and his **Ground Breaker** special (an overhead-slam GROUND `Strike`, damage from
`moves.gd`) — is wired in `emitters.json`, all in his red-teal-gold palette. Only his
light **attack** still lacks an effect scene, so it deals no damage for now.)

**Ground slam (`SLAM`).** A universal air move on the **`special` button**: in the
air, press `special` to plunge straight down at `slam_speed` (1200 — far faster than
a normal fall, so it reads as committed). Like a special it's committed (no cancel
mid-plunge), and the `special` button is context-sensitive: **on the ground it does
the character's special, in the air it slams** (attacks and specials are both
grounded-only). Characters without a `slam` sheet can't slam (the air press no-ops);
**Lenny and Feyke have `slam` sheets so far**.

*Tall-plunge handling* — a long drop would finish the `slam` animation (firing its
impact frames) **before** touchdown, so the impact particles would emit in mid-air.
So while high, the animation **locks on its last descent frame** (`slam_hold_frame`,
sheet-relative to match `emitters.json`) and the **sprite is hidden** — only the
sustained wind-streak particles show, reading as a fast blur. Once the ground is
within `slam_impact_distance` (a downward ray, like the predictive land) it **releases**:
the sprite reappears and the remaining impact frames play into the ground, so the
`burst` fires where it lands. A short slam never locks — it just plays through.
Ends via `_on_animation_finished` → idle.

*Damage scales with the plunge.* On release the player measures the drop (from the y
where `SLAM` began to impact) and sets `_active_hit = {"damage_scale": mult}` —
**1.0×** up to `slam_min_drop` (120px), lerping to `slam_max_damage_mult` (**2.5×**) at
`slam_max_drop` (700px). The director *multiplies* the slam hitboxes' baked damage by it
(a new `damage_scale` path in `_inject_tuning`, applied over `damage`), so **both**
boxes scale while keeping their reach/impact ratio. It's the offensive mirror of
Katalyst's fall-damage curve — slam from higher, hit harder.

Slam **particles** are authored per character in `vfx/config/emitters.json` under the `slam`
animation: a `sustained` wind-streak trail on the descent frames (`0–2`) and a `burst`
on the impact frames (`3–4`). Keep those frame ranges consistent so `slam_hold_frame`
(the last descent frame) lines up.

**Slam needs room below (`slam_min_clearance`, 50px).** The air press only slams when
the nearest platform *straight down* is at least `slam_min_clearance` away — a ray from
the feet down that distance (against the body's own `collision_mask`, so it catches
solid ground **and** one-way platforms; no floor below = clear). Too close to the
ground and the press just no-ops, so you can't slam with no room to build a plunge. Set
`slam_min_clearance` to 0 to always allow.

**Double jump.** After the ground jump, `max_air_jumps` (default 1) extra jumps are
allowed in mid-air; the counter refreshes on every touchdown. The **ground jump is
silent**; each **air jump** re-boosts *and* spawns the character's jump particles.
Because the particle director is frame-indexed and can't tell a first jump from a
second, the jump effect is a **code-triggered burst**: it's configured under a
`double_jump` key in `emitters.json` (deliberately *not* a real sprite-animation
name, so it never auto-fires on a frame), and `_air_jump()` fires it via
`ParticleDirector.fire_effect("double_jump")`. That burst is combat-capable — give
its scene a `Hitbox` and the air jump deals damage / applies a buff, same as any
other burst.

**Jump vs. fall pose.** The `jump` animation doubles as the airborne/fall pose, but
its *launch* only replays when a jump is actually triggered (`_jump_launch`). Entering
the airborne state without jumping — a dash ending mid-air, or walking off a ledge —
holds the animation's last (fall) frame instead of re-launching, so you don't get a
phantom second jump before landing.

**Attack combo (LMB).** One press plays one *segment* — the frames up to the
next hit animate, then the sprite holds the hit frame for a short
`attack_recovery` and hands control back to idle. Hit frames come from the
`HIT_FRAMES` config via SpriteFrames metadata (`_attack_hits()`); an attack with
no entry treats every frame as a hit, so each click advances one frame.
Lenbondosen and katalyst have authored multi-hit combos (three hits with smooth
wind-up/in-between frames — katalyst's are whip-reach / spin-AoE / finisher);
Wayna's `chainsaw` is a 3-hit combo too. Feyke's `ring_kiss` is a single-hit shot
(one burst).

**Attack styles (`Move.style`).** Most attacks are `"combo"` (the click-per-segment
swing above). Khalid's `ora_ora` is a `"flurry"`: **hold** the attack button and the
animation loops fast (marked `loop: true` in the generator `OVERRIDES`), its punch
frames (2, 4 in `emitters.json`) firing the `attack_ora_ora` `Strike` on every pass —
so the hits come at the loop's rate, not per click. Releasing ends it back to idle; a
buffered special still cancels it. `_advance_combo()` routes the first press to
`_start_flurry()`, and `_process_attack()` holds it while `attack` is pressed. Per-punch
damage/knockback are low (`moves.gd`) since the DPS comes from the cadence.

Two separate timers, which matters — coupling them once made the hit frame
freeze for the whole chain window:
- **`attack_recovery`** — how long the hit frame holds before idle resumes. Keep
  it short; it's just enough to read the hit.
- **`combo_reset_time`** — how long a follow-up press still *continues* the combo
  rather than restarting it. It keeps ticking after control returns to idle, so
  you can chain even once you're moving again. Lapsing it (or pressing past the
  finisher) restarts at segment one.

Clicks mid-segment are dropped (keeps the rhythm) — change `_process_attack` if
you want light-attack input buffering. A **special** press *is* buffered, though:
pressing RMB any time during a light swing is remembered and fires the instant
that hit lands (`_buffered_special`), so a fast light→special always cancels into the
special instead of the press being swallowed by the recovery frames.

**Special attack (RMB).** Deliberately *not* a combo — one press plays the entire
animation, roots the player, and ignores all input until it finishes. It also
clears any light combo in progress (all three entry points go through
`_start_special()`). The strike lands on the frame given by the
`special` entry in `hit_frames` metadata (`_special_strike_frame()`) — e.g.
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
    if player.get_state() == Player.State.SPECIAL and not player.is_on_floor():
        player.velocity.y = 0.0
```

Two hooks, both optional:

| Hook | When | Use for |
|---|---|---|
| `setup(player)` | Once, on equip | One-off changes (`player.run_speed = 200`), resetting state |
| `physics(player, delta)` | Every physics frame, **after** the state machine sets velocity and **before** `move_and_slide()` | Movement overrides — whatever you set here wins |
| `on_special_strike(player)` | The special's strike frame | Spawn a code-driven effect/projectile on connect |
| `on_hurt(player, hit)` | Player takes a combat hit | React to damage — retaliation, defensive buff |
| `on_land(player, fall_distance, fall_speed)` | Every touchdown | Fall damage, landing shockwaves (`fall_distance` = px dropped from the apex) |

`physics` runs last on purpose, so an ability can override anything the state
machine decided. `player.get_state()` exposes the current state
(`Player.State.SPECIAL`, etc.), and the whole Player API — `take_damage()`,
`velocity`, `is_on_floor()`, every exported tunable — is available.

This is the **per-character rule engine**: each rule is "on EVENT, if CONDITION,
do ACTION," and each character's file overrides only the hooks it cares about
(base = no-ops, so existing abilities keep working). Add new event hooks to
`character_ability.gd` + fire them from the player as more are needed.

### Current abilities

| Character | Ability | Effect |
|---|---|---|
| Lenbondosen ("Lenny") | **Energy Burst** | His special is a close-range ground blast: the `special_poison_raiser` `Strike` (`emitters.json`) carries the hit, fed its damage from `configs/moves.gd`. His `on_special_strike` hook is a no-op. (He previously had an *Energy Beam*, plus *Hangtime* and *Sprint* — all removed; the laser system is gone project-wide.) |
| Katalyst | **Stomp** + **Weak knees** | A mid-air special becomes a downward drive (hangs for the wind-up, then plunges at `SLAM_SPEED`). And via `on_land`, **every** landing past `SAFE_FALL` (400px) deals fall damage scaled by drop distance × landing speed — a high enough fall can kill him (it's why he can't slam). A `_weak_knees` flag gates it, ready for a future "knee transplant" pickup to switch off. |
| Wayna | **Inferno interrupt** | Not an ability script — her `special_inferno` is a channeled `Strike` (`emit_duration`) with `interrupt_on_hurt = true`, so taking a hit **cancels the fire** (stops emission + damage ticks, releases her held pose). The `on_hurt` ability hook stays free for any *other* reaction she gets later. |
Khalid used to carry the blink as an ability; it's now a **universal, per-character dash
option** — see **Blink dash** below.

Both latch on the frame the special *starts* and only if the character was
airborne then — checking the state alone would also fire for a grounded special
that walks off a ledge mid-swing.

Katalyst's `WIND_UP` (0.1s) is timed to his animation: after the idle-ref frame
is dropped the downward strike is emitted frame 1, which at 10 fps begins at
0.1s, so the drop starts exactly as he swings. **Retime `WIND_UP` if his
special fps or frame layout changes.**

Known edge: the slam lasts only as long as the special animation, so it covers
about 330px of fall (0.30s at 1100px/s after the wind-up). From higher than that
the swing ends mid-air and he finishes the drop as a normal fall. Fine for
typical platform heights; if it ever matters, have the ability keep driving
`velocity.y` until `is_on_floor()` instead of stopping when the state ends.

---

## Visual effects (particles + drawn slashes)

All VFX — the frame-indexed particle system and the drawn `Strike` slashes —
live in **`vfx/`**, documented in **[vfx/README.md](vfx/README.md)**. In short:

- **Particles:** data-driven emitters layered on the sprites. A `ParticleDirector`
  (`vfx/script/particle_director.gd`, a child of the player) watches the sprite and
  emits authored types at authored frames. It resolves a type by recursively
  indexing `vfx/character/<char>/` + `vfx/shared/`, so a scene resolves wherever it's
  filed. Adding one = a scene under `vfx/character/<id>/…` + a line in
  `vfx/config/emitters.json`, no code.
- **Drawn slashes:** a directional crescent that must mirror with facing is a
  **`Strike`** (`scripts/combat/strike.gd`) — a `Sprite2D`/`AnimatedSprite2D` + a
  `Hitbox` that grows/fades and self-frees, and covers melee slashes, blasts, and ground
  AoEs. Use it instead of a `CPUParticles2D` when the texture itself must h-flip (Wayna's
  chainsaw). Its projectile sibling is **`Projectile`** (`scripts/combat/projectile.gd`).
- **Where to add an attack effect:** a visual → `vfx/config/emitters.json`; a hit's
  numbers → the move's `tuning` in `configs/moves.gd`; a spawned thing/behavior → a
  `scripts/abilities/<id>.gd` hook. Full walkthrough (composites, `boost`,
  `Local Coords`, per-child positioning) in [vfx/README.md](vfx/README.md).

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
- **Height-aware engagement (`attack_align_y`, default 40px):** both boxes are
  horizontal, so an enemy only *engages* — attacks, holds, or (with `aggro`) chases —
  when the player is roughly at its own height (feet-to-feet within the band). A
  player on a platform above/below is treated as out of reach: the enemy **keeps
  patrolling/strolling** instead of freezing to face someone it can't fight. Keep the
  band under the platform spacing.
- **Edge-aware:** a downward probe `edge_check_x` ahead of each foot stops it
  walking off ledges — it turns around on patrol and won't chase off a platform.
  So enemies can stroll on platforms safely.
- **`aggro`** (default **off**): when on, it *chases* the player up to
  `aggro_range` instead of only fighting whoever wanders into range. It's an
  export, so it's **per instance** — one enemy can be aggressive while another of
  the same type isn't (set it in the inspector on a placed `enemy.tscn`, or per
  entry in the spawner roster).
- **`alert_duration`** (default **5s**): getting hit **alerts** the enemy — it then
  detects and *pursues* the attacker for that long **regardless of its normal range**
  (re-hits refresh it), so a shot from off-screen doesn't go unanswered. It still only
  *lands* an attack when it's at your height (`attack_align_y`); alert just gets it
  moving toward you. 0 = never alerts.
- **`friendly_fire`** (default **off**): when on, **this** enemy's attacks also hit
  *other* enemies, not just the player (it never hits itself — the Hitbox skips its own
  `source`, and `Combat.hurt_mask` ORs in the ally hurt layer). **Per instance** — flag
  one mob for chaos, not the roster. The seam for enemies fighting each other.
- **`contact_damage`** (default **0 = off**): when set, touching the player
  deals it on `contact_interval`. Also per-instance.
- **Ranged** fires a `projectile.gd` from `muzzle_offset` on the animation's
  hit frame (`hit_frames` metadata). Two `ranged_mode`s:
  - `"aimed"` — points at the player's torso **the moment it fires** (Kebus' staff
    bolt). The shot doesn't steer after that (`homing = 0` for enemies), but that
    fire-time aim is what reads as "homing." **To stop enemies tracking you, set
    `ranged_mode = "forward"`** (per instance / roster entry). Separately, `aggro`
    (default off) is what makes an enemy *chase* — leave it off to have them guard.
  - `"forward"` — surges straight ahead in the enemy's facing for `ranged_travel` px
    then fizzles, hitting whatever it passes — ignores where you are (Baghel's red
    energy). Tint via `ranged_color`.
  - **Look** — `ranged_particle` points at a particle scene (e.g.
    `vfx/enemy/baghel/attack/attack_ground_wave.tscn`, or Kebus'
    `vfx/enemy/kebus/attack/attack_bolt.tscn`) that the projectile instances as
    its visual, so you edit/preview it in the editor like any particle scene
    (they're built `emitting = true`). Empty = a simple orb trail built in code (the
    `projectile.gd` fallback). `ranged_hitbox_extents` / `ranged_hitbox_offset` size the collider
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
    you tint `attack_ground_wave.tscn` to in the editor — no second gradient to keep in
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
`[layer_names]` in project.godot and `combat.gd`), so by default there's no friendly
fire and no group checks — a box scans only the opposing team's hurt layer. (Opt in
per attacker with `friendly_fire`: `Combat.hurt_mask(hostile, true)` also scans its own
team's layer, and the Hitbox skips its own `source` so it never hits itself. Used for
the enemy `friendly_fire` flag above.)

- **`Hurtbox`** (Area2D) receives hits and relays them via a `hurt` signal; the
  owner (player/enemy) turns that into `take_damage`.
- **`Hitbox`** (Area2D) deals damage while active, once per activation, and
  carries optional **`knockback`** (px/s shove away from the source) and
  **`stun`** (seconds frozen). Melee boxes toggle on for their active frames;
  projectiles stay on for their life.
- The **player's** hurtbox + attack hitbox are built in code (`_build_combat`),
  like the particle director, to avoid touching `player.tscn`. Light-attack
  hits fire on each combo hit frame; the special lands on its authored
  `special` hit frame (or the middle frame if none). Whoever is hit applies
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

### Player attacks — `moves.gd` tuning + a spawned `Strike` / `Projectile`

There's **no built-in attack box** any more. Every attack is a **spawned node** that
carries its own `Hitbox`: a **`Strike`** (`scripts/combat/strike.gd` — a melee slash /
blast / ground AoE that stays at the body) or a **`Projectile`**
(`scripts/combat/projectile.gd` — a shot that leaves the body, used by players *and*
enemies via a `hostile` flag). The `ParticleDirector` fires it on the attack's authored
frames and feeds it the hit's numbers from **`configs/moves.gd`** — so combat numbers
live in one place, in code, never baked in a `.tscn`.

Each move's `tuning` (a dict, or an ARRAY one-per-combo-segment):

| field | meaning |
|---|---|
| `damage` | hit damage |
| `knockback` | px/s shove away from the attacker |
| `stun` | seconds frozen |
| `color` / `color_time` | engulfing status overlay + duration |
| `x` | hitbox forward reach (mirrors with facing) |
| `extents` | hitbox half-size |
| `lunge` / `super_armor` / `multi_hit` | `Strike` wielder-effects — dormant hooks the buff system will use |

**How a hit reaches the box (and the buff seam):** on each segment/special start the
player resolves the effective tuning via **`resolve_tuning(move, seg)`** into
`_active_hit` — *this is where the future item/build system layers its modifiers*
(damage ×1.3, +reach, hits twice). When the director arms the attack's `Hitbox` it calls
`_inject_tuning`, passing `_active_hit` to the node's `apply_tuning()` — which sets
damage/knockback/stun and, for a `Strike`, resizes the box from `extents`/`x` and fires
lunge/armor. An **empty** `tuning` means "the effect scene carries its own numbers"
(finger_guns, whose two shots have different damage one dict can't express).

- `light` combos stay segment-per-click; each segment resolves its own tuning, so the
  three rope-dart hits keep different reach + damage. A combo's emitters.json frames must
  match its `HIT_FRAMES` (one effect spawn per segment).
- The move's **`kind`** (`Combat.AttackKind`: MELEE / BLAST / GROUND / PROJECTILE) is
  descriptive metadata for the future move-select / build UI — it does **not** drive
  behavior.
- A character with **no effect scene** for an attack deals no damage (Khalid, for now);
  a character with an **empty specials pool** (`get_move` returns null) simply can't
  special — the button no-ops.

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
  `ranged_mode: "forward"`, etc). Currently **one of each** so you can learn a
  matchup without being swarmed: Kebus (melee + aimed ranged) strolls the ground,
  and Baghel (ranged-only, forward ground surge, scratches his back at rest) waits
  on the far-right ground. Add more rows to `_roster` to repopulate.
- **Camera** follows the player in **`_physics_process`** with a smoothed `lerp`,
  so it tracks at the same rhythm as the player (see below) — you can traverse
  across.
- **Drop through a platform** — tap **`drop` (S / ↓ by default)** while standing on
  a one-way platform to fall through it; on the solid floor it's a no-op. `drop` is
  its own remappable action (controller: D-pad down / left-stick down), so jump is
  now purely jump. `_drop_through_platform()` finds the platform under the feet via
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
  > **Gotcha:** anything `add_child`'d and *then* moved to a spawn point (enemy
  > projectiles / the ground wave, a world-anchored particle burst) must call
  > `reset_physics_interpolation()` after positioning — otherwise it interpolates
  > from the level origin to the spawn spot on the first frame, flashing the
  > effect (and its world-space particles) scattered across the level.
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
- **Death (0 HP)** — a lethal hit puts the player in the **`DEATH`** state (via
  `_die()` from `take_damage`): input is frozen, the hurtbox turns **off**, any
  swing/channel is cancelled, and the `death` animation plays once. It auto-fires the
  character's own `death/default/` particle (tinted to their dash palette) from
  `emitters.json` on the **last** death frame; then the **sprite hides**
  (`_death_finished`) so the character *vanishes into that poof* instead of the dead
  frame sitting there until respawn (`revive()`/`_enter` restores it). **Enemies stop
  attacking**: `Enemy._player()` returns
  `null` for a dead player, so the zone goes quiet. The character_switcher waits for
  `death_complete()` (+ a short `DEATH_HOLD`) before respawning via `revive()`.
- **Death flair** — on death the camera **punches in** (`CAM_ZOOM_DEATH` 2.25 vs the
  1.5 rest zoom, tweened) and centres tight on the collapsing character so the animation
  reads; respawn zooms back out. Purely in `character_switcher` — tune/disable there.
- **Respawn** — after the death plays out, or on falling below `DEATH_Y` (into the void,
  which is an *instant* reset — no death anim), the player is back at `SPAWN` with full
  health, in-flight projectiles cleared so you're not hit on reappear.
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
| VFX build tools (particle textures/scenes) | Under `vfx/script/` — see [vfx/README.md](vfx/README.md#build-tools) |

---

## Maintaining this file

Keep this README current. When behaviour, controls, tunables, project settings,
or the art pipeline change, update the affected section in the same pass as the
code change.
