class_name Actions

## Accessor over the per-character ACTION catalogs (configs/actions_<char>.gd) -- the typed successor
## to `Moves`. Turns catalog rows into Action objects on demand; the Player seeds its current
## attack/special from the equipped loadout (defaults until a gate SWAP reward trades one in -- see
## configs/loadout.gd + scripts/run/rewards.gd).
##
## `kind` is one of the six action pools: "attacks", "specials" (combat), or "run" / "jump" / "dash" /
## "slam" (movement). Repo ships Khalid only; add a character by writing its actions_<char>.gd and a
## case in _tables()/_default_id().

## A character's pools keyed by `kind`. Referenced at runtime (not via a const dict) so the
## per-character catalog classes stay decoupled. The four movement pools live under ActionsKhalid.MOVEMENTS.
static func _tables(character: String) -> Dictionary:
	match character:
		"khalid":
			var mv: Dictionary = ActionsKhalid.MOVEMENTS
			return {
				"attacks": ActionsKhalid.ATTACKS, "specials": ActionsKhalid.SPECIALS,
				"surges": ActionsKhalid.SURGES,
				"run": mv["run"], "jump": mv["jump"], "dash": mv["dash"], "slam": mv["slam"],
			}
	return {}


## The default (starting) option id for a pool.
static func _default_id(character: String, kind: String) -> String:
	match character:
		"khalid":
			match kind:
				"attacks": return ActionsKhalid.DEFAULT_ATTACK
				"specials": return ActionsKhalid.DEFAULT_SPECIAL
				"surges": return ActionsKhalid.DEFAULT_SURGE
				_: return ActionsKhalid.DEFAULT_MOVEMENTS.get(kind, "")
	return ""


## The Category for a pool `kind`.
static func _category(kind: String) -> Action.Category:
	match kind:
		"attacks": return Action.Category.ATTACK
		"specials": return Action.Category.SPECIAL
		"surges": return Action.Category.SURGE
		"run": return Action.Category.RUN
		"jump": return Action.Category.JUMP
		"dash": return Action.Category.DASH
		"slam": return Action.Category.SLAM
	return Action.Category.OTHER


## The Action for a character's pool by id, or the default when `id` is empty / unknown. Returns null
## when the pool is empty (a character lacking that kind) -- callers must tolerate that.
static func get_action(character: String, kind: String, id := "") -> Action:
	var pool: Dictionary = _tables(character).get(kind, {})
	if pool.is_empty():
		return null
	if id.is_empty() or not pool.has(id):
		id = _default_id(character, kind)
	if not pool.has(id):
		return null
	return Action.make(_category(kind), id, pool[id])


## Ids of a character's actions in a pool (Loadout builds swap options from these).
static func ids(character: String, kind: String) -> Array:
	return _tables(character).get(kind, {}).keys()
