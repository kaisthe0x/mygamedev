class_name EnemyMarkers
extends RefCounted

## Per-enemy MARKER colour for the off-screen enemy arrows (scripts/ui/offscreen_markers.gd). Bright,
## distinguishable takes on each enemy's identity hue, so you can tell WHICH enemy is where when it's
## off-screen (e.g. after an orb launch). Keyed by enemy_id; an unknown id falls back to a threat red.
## >>> Tune the colours here; add a line when a new enemy lands. <<<

const COLORS := {
	"kebus": Color(0.90, 0.68, 0.24),   # tan / gold
	"baghel": Color(0.72, 0.48, 0.98),  # purple
	"nasen": Color(0.36, 0.66, 1.00),   # steel blue
	"mazab": Color(1.00, 0.32, 0.30),   # crimson
	"ein": Color(1.00, 0.56, 0.20),     # orange
	"matat": Color(1.00, 0.42, 0.12),   # deep orange-red (his repalette body)
	"tarri": Color(1.00, 0.87, 0.10),   # yellow-gold (his repalette body)
}
const FALLBACK := Color(1.0, 0.30, 0.30)  # a neutral threat red for any unmapped enemy


static func color_for(enemy_id: String) -> Color:
	return COLORS.get(enemy_id, FALLBACK)
