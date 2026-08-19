class_name FloatingTextTypes

## Presets for `FloatingText.emit(type, ...)` -- PURE DATA, one entry per label TYPE. Each type controls
## its own LOOK and its own IN/OUT transition, independently, so a "damage" number and a "perfect!" pop
## can read and animate completely differently. Add a type = add a row here (no code change).
##
## Every key is OPTIONAL (FloatingText fills sensible defaults). Keys:
##   font          -- res:// Font path ("" / omit = the engine default font)
##   size          -- fixed font size; OR `size_lo`/`size_hi` + `mag_lo`/`mag_hi` to RAMP by the
##                    `magnitude` passed to emit() (how damage numbers grow with the hit)
##   color         -- fixed colour;    OR `color_lo`/`color_hi` to ramp by magnitude (HDR >1 blooms;
##                    keep every channel <= 1.0 to AVOID the WorldEnvironment glow on a colour)
##   outline_color / outline_size
##   italic        -- fake-italic slant (shears the whole label); `italic_deg` sets the angle (default 12)
##   -- motion (px), in the host's local space --
##   rise          -- floats UP this far over its life
##   drift         -- max random horizontal drift (fans stacked labels apart)
##   jitter        -- random spawn scatter so rapid labels don't land exactly atop each other
##   life          -- seconds alive
##   -- TRANSITION IN --
##   pop_scale     -- starts at this scale and grows to 1.0...
##   pop_time      -- ...over this many seconds
##   fade_in       -- also fade alpha 0->1 over pop_time (else it's instantly opaque)
##   -- TRANSITION OUT --
##   hold          -- fraction of life fully opaque before it fades to 0 over the remainder
const TYPES := {
	# Damage numbers: small white light hits -> big hot-gold heavy hits (ramped by `magnitude` = damage).
	"damage": {
		"font": "res://assets/fonts/Sixtyfour-Regular-VariableFont_BLED,SCAN.ttf",
		"size_lo": 6, "size_hi": 8, "mag_lo": 8.0, "mag_hi": 45.0,
		"color_lo": Color(1, 1, 1), "color_hi": Color(1.4, 0.55, 0.15),
		"outline_color": Color(0, 0, 0, 0.85), "outline_size": 5,
		"rise": 26.0, "drift": 12.0, "jitter": 8.0, "life": 0.8,
		"pop_scale": 0.7, "pop_time": 0.14, "hold": 0.4,
	},
	# Damage dealt by a SPECIAL -- same motion, magenta so special hits read distinctly.
	"damage_special": {
		"font": "res://assets/fonts/Sixtyfour-Regular-VariableFont_BLED,SCAN.ttf",
		"size_lo": 6, "size_hi": 8, "mag_lo": 8.0, "mag_hi": 45.0,
		"color_lo": Color(1.2, 0.7, 1.3), "color_hi": Color(1.5, 0.35, 1.2),
		"outline_color": Color(0, 0, 0, 0.85), "outline_size": 5,
		"rise": 26.0, "drift": 12.0, "jitter": 8.0, "life": 0.8,
		"pop_scale": 0.7, "pop_time": 0.14, "hold": 0.4,
	},
	# Damage the PLAYER takes -- floats over Khalid. Size ramps with the hit; the `color` here is a
	# placeholder that Player.take_damage OVERRIDES per-call with the run's chosen HAIR colour (so his
	# own damage numbers match his primary colour). Slightly bigger + a touch longer than enemy numbers.
	"player_damage": {
		"font": "res://assets/fonts/Sixtyfour-Regular-VariableFont_BLED,SCAN.ttf",
		"size_lo": 8, "size_hi": 12, "mag_lo": 5.0, "mag_hi": 40.0,
		"color": Color(0.58, 0.12, 0.12), # overridden with the hair pick (default red fallback)
		"outline_color": Color(0, 0, 0, 0.9), "outline_size": 5,
		"rise": 20.0, "drift": 7.0, "jitter": 8.0, "life": 0.95,
		"pop_scale": 0.7, "pop_time": 0.14, "hold": 0.4,
	}
}
