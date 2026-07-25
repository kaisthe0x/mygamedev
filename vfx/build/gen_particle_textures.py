#!/usr/bin/env python3
"""Generate the soft particle textures under particles/.

Soft additive glow needs a smooth radial-alpha dot (white, so a particle colour
ramp can tint it). Kept re-runnable so new shapes are easy to add.

    python3 tools/gen_particle_textures.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "particles" / "textures"


def soft_dot(size: int = 32, falloff: float = 2.2) -> Image.Image:
    """White dot with a smooth radial alpha falloff (for soft/glow effects)."""
    img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    px = img.load()
    c = (size - 1) / 2.0
    r = c
    for y in range(size):
        for x in range(size):
            d = ((x - c) ** 2 + (y - c) ** 2) ** 0.5 / r
            a = max(0.0, 1.0 - d) ** falloff
            px[x, y] = (255, 255, 255, round(a * 255))
    return img


def pixel_ember(size: int = 5) -> Image.Image:
    """Small hard-edged blob (binary alpha) -- stays chunky under nearest filter,
    so particles read as pixel art rather than a soft glow. White, tinted by the
    particle colour ramp."""
    img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    px = img.load()
    c = (size - 1) / 2.0
    r = size / 2.0
    for y in range(size):
        for x in range(size):
            # Fuller rounded blob (reads as an ember chunk, not a 4-point spark).
            inside = ((x - c) ** 2 + (y - c) ** 2) ** 0.5 <= r - 0.15
            px[x, y] = (255, 255, 255, 255 if inside else 0)
    return img


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, img in [("soft_dot", soft_dot()), ("pixel_ember", pixel_ember())]:
        p = OUT / f"{name}.png"
        img.save(p)
        print(f"  wrote {p.relative_to(OUT.parent.parent)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
