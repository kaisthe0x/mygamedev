class_name Terrain
extends RefCounted

## The terrain SKIN -- the art that dresses each level: a 32px tileset for the ground/platforms, a
## few ground plants, big tree props, and an optional background image. Everything here is data +
## helpers; RunManager does the placing (it paints tiles as positioned sprites over the level's
## colliders -- see RunManager._paint_surface). Drop-in art lives in assets/terrain/<stage>/.
##
## Why sprites and not a TileMapLayer (yet): the current levels sit at free-form float positions,
## not a 32px grid, so a grid-locked TileMapLayer would fight the layout. We stamp 32px tiles along
## each collider instead -- identical art, exact fit. When levels become hand-painted grid scenes,
## the same sheets slot straight into a real TileSet. Missing sheet -> flat-colour fallback, so the
## game always builds.
##
## Tiles are 32x32. tileset1-Sheet is a 4x3 grid: ROW 0 = surface/top tiles (neon growth on top),
## ROWS 1-2 = fill/body tiles (rock + glowing cracks). Plants are 32x32 decorations; trees are
## 128x128 props placed in the background.

const TILE := 32

## --- Stage 1 art set (assets/terrain/stage1/). Per-stage sets are an easy later add. ---
const SHEET := "res://assets/terrain/stage1/tileset1-Sheet.png"
const PLANTS_SHEET := "res://assets/terrain/stage1/ground_plants-Sheet.png"
const TREES := [
	"res://assets/terrain/stage1/neon-tree1.png",
	"res://assets/terrain/stage1/neon-tree2.png",
]

## Atlas cells (col,row) by role. TOP = walkable surface; FILL = body below.
const TOP_CELLS: Array[Vector2i] = [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(3,0)]
const FILL_CELLS: Array[Vector2i] = [
	Vector2i(0,1), Vector2i(1,1), Vector2i(2,1), Vector2i(3,1),
	Vector2i(0,2), Vector2i(1,2), Vector2i(2,2), Vector2i(3,2),
]
## Ground plants: the two coral bushes read as "grass"; the mushroom is rarer. Cells in the 2x2
## plants sheet.
const PLANT_CELLS: Array[Vector2i] = [Vector2i(0,0), Vector2i(1,0)]
const MUSHROOM_CELL := Vector2i(0,1)

## Fallback flat colours (used only if a sheet is missing).
const PLATFORM_FALLBACK := Color(0.22, 0.23, 0.30)
const FLOOR_FALLBACK := Color(0.16, 0.17, 0.22)

## --- Background: an optional full-screen image behind the per-level colour tint (kept from the
## earlier pass -- the tint goes translucent over an image so levels stay distinct). ---
const BACKGROUND := {
	"texture": "res://assets/terrain/background.png",
	"tint_alpha": 0.4,
}


static func _load(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


static func sheet() -> Texture2D: return _load(SHEET)
static func plants_sheet() -> Texture2D: return _load(PLANTS_SHEET)
static func background_texture() -> Texture2D: return _load(BACKGROUND["texture"])


## An AtlasTexture for one 32px cell of `tex`. Cached by the caller if it likes; cheap either way.
static func cell_texture(tex: Texture2D, cell: Vector2i) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(cell.x * TILE, cell.y * TILE, TILE, TILE)
	return at


## A tree prop texture by index (wraps), or null if none are present.
static func tree_texture(i: int) -> Texture2D:
	if TREES.is_empty():
		return null
	return _load(TREES[i % TREES.size()])
