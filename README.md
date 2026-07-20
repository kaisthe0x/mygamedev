# mygamedev

A 2D pixel-art action platformer in **Godot 4.7**. One player controller drives
any of five characters, which share an animation set and can be swapped at
runtime.

Main scene: `scenes/level.tscn`. Press F5 to run.

---

## Layout

```
assets/portraits/     Painted 1080x1080 character portraits (HUD art)
resources/characters/ GENERATED SpriteFrames -- do not hand-edit
scenes/               player, level, hud
scripts/              player, hud, character_switcher
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
one shared canvas (**currently 156x80**):

- **Vertically** — the frame bottom becomes the canvas bottom. The sheets are
  foot-anchored, so this puts feet on a fixed line.
- **Horizontally** — anchored on **frame 0**, which is the neutral pre-action
  pose in every action sheet (its bounding box matches idle frame 0 exactly).
  Anchoring on the average instead would let wayna's dash fire trail or an
  attack's swing arc drag the body off-centre. Later frames keep their own
  offsets, so lunges still lunge.

Normalisation is stored as `AtlasTexture.margin`, so **no images are rewritten
and no extra VRAM is used** — the atlases still point at the original PNGs.

Because every character lands on the same canvas, swapping is a one-line
`sprite_frames` swap. No per-character offsets or colliders.

**The canvas size is derived, not fixed** — it grows to fit the largest frame,
so adding art can change it (heavy attacks took it from 156x71 to 156x80).
`player.gd` reads the frame size on load and sets the sprite offset from it
(origin at the feet), so nothing has to be updated by hand when it moves.

### Regenerating

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

Current tweaks are all on `heavy_attack`, bringing every character into the
0.50-0.60s band: khalid `hold_last` 2.5 (4 frames read as a snap, so the last
pose sits rather than the whole swing slowing), lenbondosen 13 fps and wayna
16 fps (7 and 9 frames were too slow at 10). The generator prints resulting
durations and marks overridden entries with `*`.

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

1. **Frame 0 is the neutral standing pose, no VFX.** This is the horizontal
   anchor. If a dash's frame 0 already has the fire lit, that whole animation
   sits off-centre.
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
| Attack | `attack_frame_time` 0.14, `combo_reset_time` 0.6 |
| Juice | `fall_tilt_degrees` 8, `fall_tilt_at_speed` 600 |

**Attack combo.** One press shows one attack frame; consecutive presses walk
through them and wrap at the end. Letting `combo_reset_time` lapse restarts at
the first hit. Pressing again mid-swing chains immediately. The combo starts at
frame **1**, not 0, because frame 0 is the neutral pose and would read as
"nothing happened" — so a 4-frame attack sheet gives 3 hits.

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
| Lenbondosen ("Lenny") | **Hangtime** | A heavy attack started mid-air suspends him until it finishes, so the full 7-frame swing plays instead of being cut short by the fall. Falls resume normally afterwards. |
| Katalyst | **Stomp** | A heavy attack started mid-air becomes a ground slam: he hangs for the wind-up, then drives straight down at `SLAM_SPEED` until he lands. |

Both latch on the frame the heavy *starts* and only if the character was
airborne then — checking the state alone would also fire for a grounded heavy
that walks off a ledge mid-swing.

Katalyst's `WIND_UP` (0.2s) is timed to his animation: 5 frames at 10 fps means
the downward strike is frame 2, so the drop begins exactly as he swings rather
than before. **Retime `WIND_UP` if his heavy_attack fps or frame count changes.**

Known edge: the slam lasts only as long as the heavy animation, so it covers
about 330px of fall (0.30s at 1100px/s after the wind-up). From higher than that
the swing ends mid-air and he finishes the drop as a normal fall. Fine for
typical platform heights; if it ever matters, have the ability keep driving
`velocity.y` until `is_on_floor()` instead of stopping when the state ends.

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

---

## Maintaining this file

Keep this README current. When behaviour, controls, tunables, project settings,
or the art pipeline change, update the affected section in the same pass as the
code change.
