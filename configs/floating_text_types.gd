class_name FloatingTextTypes

## Presets for `FloatingText.emit(type, ...)` -- PURE DATA, one entry per label TYPE. Each type controls
## its own LOOK and its own IN/OUT transition, independently, so a "damage" number and a "perfect!" pop
## can read and animate completely differently. Add a type = add a row here (no code change).
##
## Every key is OPTIONAL (FloatingText fills sensible defaults). Keys:
##   font          -- res:// Font path ("" / omit = the engine default font)
##   size          -- fixed font size; OR `size_lo`/`size_hi` + `mag_lo`/`mag_hi` to RAMP by the
##                    `magnitude` passed to emit() (how damage numbers grow with the hit)
##   color         -- fixed colour;    OR `color_lo`/`color_hi` to ramp by magnitude (HDR >1 blooms)
##   outline_color / outline_size
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
		"size_lo": 6, "size_hi": 8, "mag_lo": 8.0, "mag_hi": 45.0,
		"color_lo": Color(1, 1, 1), "color_hi": Color(1.4, 0.55, 0.15),
		"outline_color": Color(0, 0, 0, 0.85), "outline_size": 5,
		"rise": 26.0, "drift": 12.0, "jitter": 8.0, "life": 0.8,
		"pop_scale": 0.7, "pop_time": 0.14, "hold": 0.4,
	},
	# Damage dealt by a SPECIAL -- same motion, magenta so special hits read distinctly.
	"damage_special": {
		"size_lo": 6, "size_hi": 8, "mag_lo": 8.0, "mag_hi": 45.0,
		"color_lo": Color(1.2, 0.7, 1.3), "color_hi": Color(1.5, 0.35, 1.2),
		"outline_color": Color(0, 0, 0, 0.85), "outline_size": 5,
		"rise": 26.0, "drift": 12.0, "jitter": 8.0, "life": 0.8,
		"pop_scale": 0.7, "pop_time": 0.14, "hold": 0.4,
	},
	# "Perfect!" parry callout -- a bigger, gold word that fades IN (a softer entrance than the damage
	# pop), rises higher/slower, and lingers longer. A deliberately different transition from damage.
	"perfect": {
		"size": 8, "color": Color(1.7, 1.25, 0.2),
		"outline_color": Color(0.25, 0.08, 0.0, 0.95), "outline_size": 6,
		"rise": 46.0, "drift": 0.0, "jitter": 3.0, "life": 1.1,
		"pop_scale": 0.4, "pop_time": 0.22, "fade_in": true, "hold": 0.55,
	},
}
