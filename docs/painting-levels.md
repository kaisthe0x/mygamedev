# Hand-painting terrain with the TileMapLayer

You now have a real TileSet + a paint scene. This is the editor workflow for picking tiles yourself.

## What's set up for you

- **`resources/terrain/stage1_terrain.tres`** — the TileSet (32px). Two sources:
  - **Source 0 = terrain** (the 12 tileset1 tiles) — **solid** (collision baked in, so painted
    tiles are walkable).
  - **Source 1 = plants** (the 3 ground plants) — **no collision** (decoration).
- **`scenes/tile_paint.tscn`** — a sandbox: a `Terrain` TileMapLayer using that TileSet (with a
  starter ground strip + a floating platform + plants already painted), a Player, a Camera, and the
  glow. Open it and paint.

## Paint (the core loop)

1. Open **`scenes/tile_paint.tscn`** (double-click it in the FileSystem dock).
2. In the **Scene** dock, click the **`Terrain`** node (the TileMapLayer). A **TileMap** panel opens
   at the **bottom** of the editor with the tile palette on the right.
3. Above the palette, pick the **source** — the terrain atlas or the plants atlas (a small
   dropdown / the source list on the left of the panel).
4. **Click a tile** in the palette to select it, then **left-click / drag in the viewport** to
   place it. **Right-click** erases.
5. Tools along the top of the panel: **Paint** (pencil), **Line**, **Rect**, **Bucket fill**.
   Rect is fastest for a ground strip; Bucket fills an area.
6. **Playtest what you painted:** press **F6** (Run Current Scene). The player drops in and walks on
   the tiles — terrain is solid, plants aren't. Iterate.

Tiles snap to the 32px grid automatically. Zoom the 2D view with the scroll wheel; pan with middle-
mouse.

## Handy extras

- **Two layers for depth:** keep terrain on `Terrain`, and add a **second TileMapLayer** above it
  for plants/decorations (right-click the root → Add Child → TileMapLayer, set its `tile_set` to the
  same `.tres`, `texture_filter = Nearest`). Decorations then sort in front and never collide.
- **One-way platforms (drop-through):** select the `Terrain` node → **TileSet** tab (bottom panel) →
  pick a tile → the **Physics** section → tick **One Way** on its collision. Those tiles you can
  jump up through and drop down from (down-key), like the current ledges. Leave it off for solid
  ground/walls.
- **Edit the TileSet** (collision shapes, add tiles): select the node → **TileSet** tab, or double-
  click `stage1_terrain.tres`. Everything about the tiles lives there.
- **Autotiling (Terrains)** — when you want edges/corners to auto-pick as you paint: TileSet tab →
  add a **Terrain Set** → assign each tile its terrain "peering bits", then paint with the Terrain
  tool. This is the big "hand-crafted look" upgrade; do it once the basic painting feels good.

## If the art changes

Re-run the generator to rebuild the TileSet with fresh collision (it's a throwaway script; ask me to
regenerate, or keep a copy): it rebuilds `stage1_terrain.tres` from the sheets in
`assets/terrain/stage1/`. Adding a whole new stage = a new sheet + a new `.tres` the same way.

## Getting painted levels into the actual run

The sandbox is standalone (no enemies/lahm/exit yet). Wiring hand-painted level **scenes** into the
run — so `RunManager` loads your painted level, spawns waves on it, and runs the exit/lahm loop — is
the next step. It means: each level becomes a scene like this one (TileMapLayer + marker nodes for
the player spawn, exit, and enemy spawns), and `RunManager` instantiates it instead of building from
`Levels` data. Say the word and I'll build that seam; then everything you paint plays as a real
level. (The current code-tiled look in `RunManager` stays as the fallback until then.)
