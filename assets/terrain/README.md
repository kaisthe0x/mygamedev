# assets/terrain — drop your terrain art here

These PNGs replace the placeholder rectangles (floor, platforms, background). **Just drop a file
with the exact name below and it renders automatically** — no code changes. Leave one out and that
surface stays its flat placeholder colour. Wiring lives in [`configs/terrain.gd`](../../configs/terrain.gd)
+ `RunManager._terrain_visual`.

| File | Replaces | Guidance |
|---|---|---|
| `platform.png` | the one-way ledges | short horizontal strip, **seamless left↔right**, ~16 px tall (platforms are 14). Any length — it **tiles** across each platform's width. |
| `floor.png` | the ground band | same idea; taller ok (floor band is 40 px). Tiles across the whole floor. |
| `background.png` | the level backdrop | one image, **stretched** to fill. The per-level colour becomes a translucent tint over it (keeps levels distinct). |

**Notes**
- Pixel-art is kept crisp (NEAREST filtering).
- Want **end-caps** (a grass lip, rounded corners) instead of a plain tile? Author the texture with
  a border and set that border's px thickness in `configs/terrain.gd` → the surface's `margins`
  `[left, top, right, bottom]` (9-slice: edges stay fixed, the middle tiles).
- Per-level terrain variants (different biome per level) are an easy later add — ask when you want it.
