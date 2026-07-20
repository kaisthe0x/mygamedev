#!/usr/bin/env python3
"""Generate SpriteFrames (.tres) resources from the character sprite sheets.

The source sheets are single-row uniform grids, but frame size varies per
animation (32x32 idle vs 143x48 attack) and some sheets carry a constant
horizontal padding bias. Slicing them as-is makes the character jump around
when the animation changes.

This script normalises every frame onto one shared canvas:
  - vertically   : frame bottom == canvas bottom (the sheets are foot-anchored)
  - horizontally : frame 0 of every animation is the neutral pre-action pose
                   (its bounding box matches idle frame 0 exactly), so we anchor
                   on that. Anchoring on the mean instead would let a dash's
                   fire trail or an attack's swing arc drag the body off-centre.
                   Later frames keep their own offsets, so lunges still lunge.

Normalisation is expressed with AtlasTexture.margin, so no images are rewritten
and no extra VRAM is used -- the atlases still point at the original PNGs.

Re-run after adding a character or re-exporting a sheet:
    python3 tools/gen_spriteframes.py
"""

from __future__ import annotations

import math
import re
import sys
from pathlib import Path

from PIL import Image

PROJECT = Path(__file__).resolve().parent.parent
CHARS_DIR = PROJECT / "sprites" / "characters"
OUT_DIR = PROJECT / "resources" / "characters"

# name -> (fps, loop). Ordered; "idle" first so it is the default animation.
ANIMS = {
    "idle": (6.0, True),
    "run": (10.0, True),
    "jump": (10.0, False),
    "dash": (12.0, False),
    "attack": (12.0, False),
    "heavy_attack": (10.0, False),
}

# Per-character timing tweaks, layered over ANIMS. Frame counts differ a lot
# between characters, so a single fps makes some swings drag and others snap.
#   fps       -- override playback speed for that one animation
#   hold_last -- multiply the final frame's duration, to let a pose land before
#                the character retracts
#   loop_from -- for a looping animation, the frame to restart from. Frames
#                before it play once as an intro; the tail cycles forever.
#                Emitted as resource metadata; player.gd honours it.
# Anything not listed here uses the ANIMS default.
OVERRIDES: dict[tuple[str, str], dict[str, float]] = {
    # 4 frames read as a snap; let the final pose sit instead of speeding up.
    ("khalid", "heavy_attack"): {"hold_last": 2.5},
    # 7 and 9 frames respectively -- too slow at 10 fps.
    ("lenbondosen", "heavy_attack"): {"fps": 13.0},
    ("wayna", "heavy_attack"): {"fps": 16.0},
    # Frames 0-3 are the launch (upright, lean, ignite); 4-6 are sustained
    # flight, so only the tail should cycle while she keeps running.
    ("wayna", "run"): {"loop_from": 4},
}


def uid_for(png: Path) -> str:
    """Read the Godot-assigned uid out of the sibling .import file."""
    imp = png.with_suffix(png.suffix + ".import")
    if not imp.exists():
        raise SystemExit(
            f"{png.name} has not been imported by Godot yet.\n"
            f"Run:  godot --headless --import\n"
            f"(or just open the project in the editor once), then re-run this."
        )
    m = re.search(r'^uid="(uid://[^"]+)"', imp.read_text(), re.M)
    if not m:
        raise SystemExit(f"no uid in {imp} -- try deleting it and re-importing")
    return m.group(1)


def content_columns(alpha, w: int, h: int) -> list[bool]:
    return [any(alpha[x, y] for y in range(h)) for x in range(w)]


def frame_count(cols: list[bool], w: int) -> int:
    """Largest N dividing w such that every slice has content and no content
    run straddles a slice boundary."""
    best = 1
    for n in range(1, 13):
        if w % n:
            continue
        fw = w // n
        if not all(any(cols[i * fw:(i + 1) * fw]) for i in range(n)):
            continue
        if any(cols[i * fw - 1] and cols[i * fw] for i in range(1, n)):
            continue
        best = n
    return best


class Sheet:
    def __init__(self, png: Path):
        self.png = png
        im = Image.open(png).convert("RGBA")
        self.w, self.h = im.size
        alpha = im.getchannel("A").load()
        cols = content_columns(alpha, self.w, self.h)
        self.n = frame_count(cols, self.w)
        self.fw = self.w // self.n
        # Offset of frame 0's content centre from its frame centre, in pixels.
        # Rounded to a whole pixel so the art stays on the pixel grid.
        xs = [x for x in range(self.fw) if cols[x]]
        self.bias = round((min(xs) + max(xs)) / 2 - self.fw / 2)

    # Half-widths needed either side of the desired centre.
    def half_left(self) -> float:
        return self.fw / 2 + self.bias

    def half_right(self) -> float:
        return self.fw / 2 - self.bias


def main() -> int:
    if not CHARS_DIR.is_dir():
        raise SystemExit(f"missing {CHARS_DIR}")

    characters = sorted(p.name for p in CHARS_DIR.iterdir() if p.is_dir())
    sheets: dict[str, dict[str, Sheet]] = {}

    for char in characters:
        sheets[char] = {}
        for anim in ANIMS:
            png = CHARS_DIR / char / f"{char}_{anim}_frames.png"
            if not png.exists():
                print(f"  ! {char}: missing {anim} sheet, skipping", file=sys.stderr)
                continue
            sheets[char][anim] = Sheet(png)

    # One canvas shared by every character and animation, so the player scene
    # can swap SpriteFrames without touching the sprite offset or collider.
    all_sheets = [s for per_char in sheets.values() for s in per_char.values()]
    half = max(max(s.half_left(), s.half_right()) for s in all_sheets)
    canvas_w = 2 * math.ceil(half)
    canvas_h = max(s.h for s in all_sheets)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    print(f"canvas: {canvas_w}x{canvas_h} (feet on the bottom edge)")

    # The canvas only collapses to the frame size when frame 0's character is
    # centred in its frame. Anything off-centre has to be padded to line up with
    # the other animations, widening the canvas for every character. Call out
    # the worst offenders so they can be re-centred at the source.
    widest = max(s.fw for s in all_sheets)
    if canvas_w > widest:
        culprits = sorted(
            (s for s in all_sheets if abs(s.bias) > 2),
            key=lambda s: -abs(s.bias),
        )[:5]
        print(
            f"  note: canvas is {canvas_w - widest}px wider than the widest frame "
            f"({widest}px) because frame 0 is off-centre in:"
        )
        for s in culprits:
            print(f"        {s.png.parent.name}/{s.png.stem.replace('_frames', '')}"
                  f"  {s.bias:+d}px")

    for char in characters:
        per_char = sheets[char]
        if not per_char:
            continue

        ext, sub, anim_entries, timings = [], [], [], []
        loop_points: dict[str, int] = {}
        for idx, (anim, sheet) in enumerate(per_char.items(), start=1):
            fps, loop = ANIMS[anim]
            tweak = OVERRIDES.get((char, anim), {})
            fps = tweak.get("fps", fps)
            hold_last = tweak.get("hold_last", 1.0)
            res_id = f"{idx}_{anim}"
            rel = sheet.png.relative_to(PROJECT).as_posix()
            ext.append(
                f'[ext_resource type="Texture2D" uid="{uid_for(sheet.png)}" '
                f'path="res://{rel}" id="{res_id}"]'
            )

            # Left pad places the animation's content centre on the canvas centre;
            # top pad drops the frame onto the canvas bottom edge.
            pad_x = round(canvas_w / 2 - sheet.fw / 2 - sheet.bias)
            pad_y = canvas_h - sheet.h
            assert 0 <= pad_x <= canvas_w - sheet.fw, (char, anim, pad_x)

            frames = []
            for i in range(sheet.n):
                sid = f"{anim}_{i}"
                sub.append(
                    f'[sub_resource type="AtlasTexture" id="{sid}"]\n'
                    f'atlas = ExtResource("{res_id}")\n'
                    f"region = Rect2({i * sheet.fw}, 0, {sheet.fw}, {sheet.h})\n"
                    f"margin = Rect2({pad_x}, {pad_y}, "
                    f"{canvas_w - sheet.fw}, {canvas_h - sheet.h})"
                )
                duration = hold_last if i == sheet.n - 1 else 1.0
                frames.append(
                    f'{{\n"duration": {duration},\n"texture": SubResource("{sid}")\n}}'
                )

            loop_from = int(tweak.get("loop_from", 0))
            if loop_from:
                if not loop:
                    raise SystemExit(
                        f"{char}/{anim}: loop_from needs a looping animation; "
                        f"set loop=True for '{anim}' in ANIMS"
                    )
                if loop_from >= sheet.n:
                    raise SystemExit(
                        f"{char}/{anim}: loop_from={loop_from} but the sheet only "
                        f"has {sheet.n} frames (0-{sheet.n - 1})"
                    )
                loop_points[anim] = loop_from

            # Total frames counts the held last frame as `hold_last` frames.
            seconds = (sheet.n - 1 + hold_last) / fps
            note = f"[loop@{loop_from}]" if loop_from else ""
            timings.append(f"{anim}:{sheet.n}f/{seconds:.2f}s" + ("*" if tweak else "") + note)

            anim_entries.append(
                "{\n"
                '"frames": [' + ", ".join(frames) + "],\n"
                f'"loop": {str(loop).lower()},\n'
                f'"name": &"{anim}",\n'
                f'"speed": {fps}\n'
                "}"
            )

        load_steps = len(ext) + len(sub) + 1
        # Read back by player.gd to restart looping animations partway in.
        meta = ""
        if loop_points:
            pairs = ", ".join(f'"{a}": {i}' for a, i in loop_points.items())
            meta = f"metadata/loop_from = {{{pairs}}}\n"
        body = (
            f'[gd_resource type="SpriteFrames" load_steps={load_steps} format=3]\n\n'
            + "\n".join(ext)
            + "\n\n"
            + "\n\n".join(sub)
            + "\n\n[resource]\n"
            + meta
            + "animations = ["
            + ", ".join(anim_entries)
            + "]\n"
        )
        out = OUT_DIR / f"{char}.tres"
        out.write_text(body)
        print(f"  {out.relative_to(PROJECT)}")
        print(f"      {'  '.join(timings)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
