extends SceneTree

## Dev tool: generate a TileSet resource from a terrain sheet, with collision baked onto the SOLID tiles,
## so a level can be hand-painted in the editor (paint = collision). Re-run after editing the sheet.
##   godot-mono --headless --script tools/gen_terrain_tileset.gd
##
## Every non-empty 32px cell becomes a paintable tile; cells that are mostly-opaque also get a full-box
## collider on physics layer 0 (collision_layer = World). Solid by default — flip ONE_WAY below for
## jump-through platforms. Partial/decor cells are paintable but pass-through (no collision).

const SHEET := "res://assets/terrain/stage1/tileset1-Sheet.png"
const OUT := "res://assets/terrain/stage1/terrain_tileset.tres"
const TILE := 32
const WORLD_LAYER := 1        # Combat.Layer.World = 1 << 0
const SOLID_COVERAGE := 0.85  # >= this opaque fraction -> gets collision
const EMPTY_COVERAGE := 0.05  # < this -> not even a tile (skip)
const ONE_WAY := false        # true = jump-through platforms (block from top only)

func _init() -> void:
	var tex: Texture2D = load(SHEET)
	if tex == null:
		push_error("gen_terrain_tileset: sheet not found: " + SHEET); quit(); return
	var img := tex.get_image()
	var cols := img.get_width() / TILE
	var rows := img.get_height() / TILE

	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, WORLD_LAYER)
	ts.set_physics_layer_collision_mask(0, 0) # terrain is static; it detects nothing

	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)

	var box := PackedVector2Array([
		Vector2(-TILE / 2.0, -TILE / 2.0), Vector2(TILE / 2.0, -TILE / 2.0),
		Vector2(TILE / 2.0, TILE / 2.0), Vector2(-TILE / 2.0, TILE / 2.0)])

	var tiles := 0; var solids := 0
	for cy in rows:
		for cx in cols:
			var cov := _coverage(img, cx, cy)
			if cov < EMPTY_COVERAGE:
				continue
			var cell := Vector2i(cx, cy)
			src.create_tile(cell)
			tiles += 1
			if cov >= SOLID_COVERAGE:
				var td := src.get_tile_data(cell, 0)
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, box)
				if ONE_WAY:
					td.set_collision_polygon_one_way(0, 0, true)
				solids += 1

	var err := ResourceSaver.save(ts, OUT)
	print("gen_terrain_tileset: %s  tiles=%d solid(collide)=%d  -> %s" %
		["OK" if err == OK else "ERR %d" % err, tiles, solids, OUT])
	quit()

func _coverage(img: Image, cx: int, cy: int) -> float:
	var op := 0
	for y in TILE:
		for x in TILE:
			if img.get_pixel(cx * TILE + x, cy * TILE + y).a >= 0.08:
				op += 1
	return float(op) / float(TILE * TILE)
