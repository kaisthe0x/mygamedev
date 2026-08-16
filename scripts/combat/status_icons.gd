class_name StatusIcons
extends Node2D

## A horizontal row of small status icons (reap / stun / charm / ...) shown NEXT TO an enemy's
## floating health bar. Built in code -- no scene -- so any enemy/boss gets one for free. The enemy
## recomputes its active-status set each frame and calls set_active(); we only redraw when the set
## actually changes (Enemy gates that). Icons + tints come from StatusTypes / the Icons registry, so
## dropping in real art is a config swap with no change here.

## Drawn icon edge length + the gap between icons, in world px (small so several fit beside the bar).
const ICON := 7.0
const GAP := 1.0

var _ids: Array = [] ## active status ids (Strings), already in StatusTypes.ORDER


## Replace the shown set. `ids` is a list of status id Strings (already ordered by the caller).
func set_active(ids: Array) -> void:
	_ids = ids
	queue_redraw()


## Draw each active status as a tinted placeholder pip, left to right from the node origin.
## The enemy positions this node just to the right of the health bar, vertically centred on it.
func _draw() -> void:
	var x := 0.0
	for id in _ids:
		var tex: Texture2D = Icons.texture("status:" + String(id))
		if tex != null:
			draw_texture_rect(tex, Rect2(x, -ICON / 2.0, ICON, ICON), false, StatusTypes.color_of(id))
		x += ICON + GAP
