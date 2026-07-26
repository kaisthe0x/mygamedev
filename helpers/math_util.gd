class_name MathUtil
extends RefCounted

## Small pure-math / value helpers with no node or scene dependency.


## Intersect a horizontal band (world `center` +/- `half`) with [left, right].
## Returns [new_center, new_half], or [] if none of it lies in range. Used to clip
## a ground blast's emission/hitbox to the platform edges under it.
static func clip_band(center: float, half: float, left: float, right: float) -> Array:
	var lo := maxf(center - half, left)
	var hi := minf(center + half, right)
	if lo >= hi:
		return []
	return [(lo + hi) * 0.5, (hi - lo) * 0.5]


## Multiply an object's min/max property pair (e.g. a particle's
## initial_velocity_min/max) by `f`.
##
## Godot clamps these pairs against each other on assign, so multiplying each in
## turn would double-apply the factor to one end (setting min above max drags max
## up, then max gets multiplied again). Writing whichever end moves outward first
## avoids the transient invalid state.
static func scale_min_max_pair(obj: Object, min_prop: StringName, max_prop: StringName,
		f: float) -> void:
	if is_equal_approx(f, 1.0):
		return
	var lo := float(obj.get(min_prop)) * f
	var hi := float(obj.get(max_prop)) * f
	if f >= 1.0:
		obj.set(max_prop, hi)
		obj.set(min_prop, lo)
	else:
		obj.set(min_prop, lo)
		obj.set(max_prop, hi)
