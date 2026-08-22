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

# TODO: Think of more possible effects

const DEFS := {
	"reap": {"color": Color(0.55, 0.95, 0.45), "label": "Reaped"}, # dying / DoT (Twin Reaper)
	"stun": {"color": Color(1.0, 0.86, 0.28), "label": "Stunned"}, # frozen / staggered
	"slow": {"color": Color(0.45, 0.7, 1.0), "label": "Slowed"}, # reserved for a future slow effect
	"charm": {"color": Color(1.0, 0.5, 0.75), "label": "Charmed"}, # frenemy (fighting for the player)
}

## Fixed draw order (left -> right). Ids not listed fall to the end in DEFS order.
const ORDER := ["reap", "stun", "slow", "charm"]

# TODO: Add the rest of the overhead effects

## Optional OVER-HEAD animation for a status -- a looping sheet that hovers over the enemy's head like a
## halo (drawn by scripts/combat/overhead_status.gd; ONE shows at a time, picked by ORDER priority). Only
## STUN has one today: the swirling-stars "dazed halo". Give another status one by dropping in art + an
## entry here. Fields: sheet (horizontal strip), hframes (cells), fps, scale, y_off (px below the head line,
## + = lower, to sit the halo on the crown just under the health bar).
const OVERHEAD := {
	# reap sits FIRST in ORDER, so a dying enemy shows the skull even if it's also stunned.
	"reap": {
		"sheet": "res://sprites/things/state/dying.png", # 12x pulsing red/grey skull-in-a-ring (768x64 -> 64x64 cells)
		"hframes": 12, "fps": 12.0, "scale": 0.3, "y_off": 22.0,
	},
	"stun": {
		"sheet": "res://sprites/things/state/stunned.png", # 4x swirling yellow stars (256x64 -> 64x64 cells)
		"hframes": 4, "fps": 12.0, "scale": 0.3, "y_off": 20.0,
	},
}


## The tint for a status id (white if unknown), so StatusIcons can colour a placeholder pip.
static func color_of(id: StringName) -> Color:
	var d: Dictionary = DEFS.get(String(id), {})
	return d.get("color", Color.WHITE)
