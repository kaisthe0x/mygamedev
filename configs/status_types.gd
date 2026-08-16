class_name StatusTypes
extends RefCounted

## Registry of enemy STATUS effects that show as a small icon next to the floating health bar
## (see scripts/combat/status_icons.gd). Each entry pairs a tint + a human label; the icon TEXTURE
## comes from the shared Icons registry under the "status:<id>" key, so swapping in real art is a
## one-line change in configs/icons.gd with no code touch here.
##
## ORDER fixes the left-to-right icon layout so a given status always sits in the same slot
## (readable at a glance). An enemy reports which ids are active each frame; StatusIcons draws them
## in this order. Add a new status by (1) an entry here, (2) a "status:<id>" path in Icons.PATHS,
## and (3) reporting it from Enemy._refresh_status_icons.
##
## >>> TODO(art): the icons are TEMP placeholders (reused pngs) -- see the TODO in configs/icons.gd. <<<

const DEFS := {
	"reap":  {"color": Color(0.55, 0.95, 0.45), "label": "Reaped"},   # dying / DoT (Twin Reaper)
	"stun":  {"color": Color(1.0, 0.86, 0.28),  "label": "Stunned"},  # frozen / staggered
	"slow":  {"color": Color(0.45, 0.7, 1.0),   "label": "Slowed"},   # reserved for a future slow effect
	"charm": {"color": Color(1.0, 0.5, 0.75),   "label": "Charmed"},  # frenemy (fighting for the player)
}

## Fixed draw order (left -> right). Ids not listed fall to the end in DEFS order.
const ORDER := ["reap", "stun", "slow", "charm"]


## The tint for a status id (white if unknown), so StatusIcons can colour a placeholder pip.
static func color_of(id: StringName) -> Color:
	var d: Dictionary = DEFS.get(String(id), {})
	return d.get("color", Color.WHITE)
