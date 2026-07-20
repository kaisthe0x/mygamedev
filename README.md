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
sprites/characters/   Source pixel-art sheets, one folder per character
tools/                Generator + verification scripts (not shipped)
```

## Controls

| Input | Action | Notes |
|---|---|---|
| A / D | `move_left` / `move_right` | |
| Space | `jump` | |
| Shift | `dash` | Has a cooldown |
| Left mouse | `attack` | Each press advances the combo |
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

Each character has five sheets (`idle`, `run`, `jump`, `dash`, `attack`). They
are single-row grids, but nothing else is consistent:

- Frame counts vary (3-6) between animations *and* between characters
- Frame sizes vary wildly — khalid's idle is 32x32, his attack is 143x48
- Some sheets have a constant horizontal padding bias (lenbondosen's dash sits
  ~24px left of centre)

Slicing them naively makes the character jump sideways and change height every
time the animation changes.

### The fix

`tools/gen_spriteframes.py` analyses each sheet and normalises every frame onto
one shared **156x71 canvas**:

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

---

## Adding a character

1. Drop the five sheets in `sprites/characters/<name>/` named
   `<name>_<anim>_frames.png` (lower case).
2. Add a 1080x1080 portrait at `assets/portraits/<Name>.png`
   (**capitalised** — the lookup expects it).
3. Add the name to `CHARACTERS` and the `@export_enum` list in
   `scripts/player.gd`.
4. Run the generator, then the verifier.

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
(`IDLE / RUN / JUMP / DASH / ATTACK`). Everything is tunable in the inspector.

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

**If you edit scenes outside the editor, close the tab first**, or use
`Project > Reload Current Project` afterwards. This is why the HUD is an
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
