class_name Loadout
extends RefCounted

## The player's swappable LOADOUT. Per category (attack, special, run, jump, dash, slam) a
## character has one or more OPTIONS, each with a TIER: typical / elite / broken. Characters
## START on their defaults (Typical) and can trade up as they progress -- a gate reward offers a
## swap whenever a category has more than one option (see Rewards.offer). The Player equips the
## chosen option (Player.equip). See docs/game-design.md.
##
## Where the options come from:
##  - attack / special : the Moves catalog (each move's `tier`).
##  - run/jump/dash/slam: the character's CharacterConfig stats as the Typical BASELINE, plus any
##    MOVEMENT_EXTRAS below. Movements have just their baseline for now, so nothing to swap yet --
##    add an extra to make one swappable; the whole system is already wired for it.

const CATEGORIES := ["attack", "special", "run", "jump", "dash", "slam"]
const MOVEMENT_CATS := ["run", "jump", "dash", "slam"]

## Tier display, ordering, and colour (broken = rarest/strongest).
const TIER_LABEL := {"typical": "Typical", "elite": "Elite", "broken": "Broken"}
const TIER_RANK := {"typical": 0, "elite": 1, "broken": 2}
const TIER_COLOR := {
	"typical": Color(0.75, 0.78, 0.85),
	"elite": Color(0.45, 0.82, 1.0),
	"broken": Color(1.0, 0.55, 0.95),
}

## ALTERNATE movement options beyond each character's Typical baseline. Empty for now. Shape:
##   "<character>": { "<cat>": [ {"id","tier","name", <stats>}, ... ] }
## stats by category -- run/slam: "speed"; jump: "velocity"; dash: "speed" + "blink" (bool).
## Example: "wayna": {"dash": [{"id":"emberstep","tier":"elite","name":"Emberstep","speed":560.0,"blink":true}]}
const MOVEMENT_EXTRAS := {}


static func tier_label(tier: String) -> String:
	return TIER_LABEL.get(tier, "Typical")


static func tier_color(tier: String) -> Color:
	return TIER_COLOR.get(tier, TIER_COLOR["typical"])


## "ring_kiss" -> "Ring Kiss".
static func pretty(id: String) -> String:
	return id.replace("_", " ").capitalize()


## Every option for a character in a category: [{id, name, tier, category, ...stats}].
static func options(character: String, category: String) -> Array:
	if category == "attack" or category == "special":
		return _move_options(character, category)
	return _movement_options(character, category)


## The specific option dict, or the first (baseline/default) when `id` isn't found.
static func option(character: String, category: String, id: String) -> Dictionary:
	var opts := options(character, category)
	for o: Dictionary in opts:
		if o["id"] == id:
			return o
	return opts[0] if not opts.is_empty() else {}


## The default (starting) option id for a category.
static func default_id(character: String, category: String) -> String:
	if category == "attack" or category == "special":
		var mv := Moves.get_move(character, "attacks" if category == "attack" else "specials")
		return mv.id if mv != null else ""
	return "default"


## Categories where this character has a real choice (>1 option) + the options the player is NOT
## currently on -- the raw material for swap rewards. Returns [{category, option}].
static func swap_choices(character: String, current: Dictionary) -> Array:
	var out := []
	for cat in CATEGORIES:
		var opts := options(character, cat)
		if opts.size() < 2:
			continue
		var cur: String = current.get(cat, default_id(character, cat))
		for o: Dictionary in opts:
			if o["id"] != cur:
				out.append({"category": cat, "option": o})
	return out


static func _move_options(character: String, category: String) -> Array:
	var kind := "attacks" if category == "attack" else "specials"
	var out := []
	for id: String in Moves.ids(character, kind):
		var mv := Moves.get_move(character, kind, id)
		if mv != null:
			out.append({"id": id, "name": pretty(id), "tier": mv.tier, "category": category})
	return out


static func _movement_options(character: String, category: String) -> Array:
	var out := [_baseline(character, category)]
	var extras: Array = MOVEMENT_EXTRAS.get(character, {}).get(category, [])
	for e: Dictionary in extras:
		var o := e.duplicate()
		o["category"] = category
		o["name"] = o.get("name", pretty(o["id"]))
		out.append(o)
	return out


## The Typical baseline option for a movement category, built from the character's current stats.
static func _baseline(character: String, category: String) -> Dictionary:
	var o := {"id": "default", "tier": "typical", "category": category}
	match category:
		"run":
			o["name"] = "Standard Stride"
			o["speed"] = CharacterConfig.run_speed(character)
		"jump":
			o["name"] = "Standard Leap"
			o["velocity"] = CharacterConfig.jump_velocity(character)
		"dash":
			o["name"] = "Blink Dash" if CharacterConfig.blink_dash(character) else "Standard Dash"
			o["speed"] = CharacterConfig.dash_speed(character)
			o["blink"] = CharacterConfig.blink_dash(character)
		"slam":
			o["name"] = "Standard Slam"
	return o
