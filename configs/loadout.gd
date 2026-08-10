class_name Loadout
extends RefCounted

## The player's swappable LOADOUT. Per category (attack, special, run, jump, dash, slam) a character has
## one or more OPTIONS, each with a TIER: typical / elite / broken. Characters START on their defaults
## (Typical) and can trade up as they progress -- a gate reward offers a swap whenever a category has
## more than one option (see Rewards.offer). The Player equips the chosen option (Player.equip).
## See docs/game-design.md.
##
## Every option in every category is now an **Action** (configs/actions_<char>.gd): attacks/specials
## carry a `hit`, run/jump/dash/slam carry a `move` (Locomotion). This layer just reads each Action's
## id/name/tier/icon -- so a movement variant is added exactly like an attack variant: a new catalog
## row. To make a category swappable, give it >1 option in the catalog.

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


static func tier_label(tier: String) -> String:
	return TIER_LABEL.get(tier, "Typical")


static func tier_color(tier: String) -> Color:
	return TIER_COLOR.get(tier, TIER_COLOR["typical"])


## The Actions pool `kind` for a loadout `category` ("attack"/"special" -> plural; movement is 1:1).
static func _kind(category: String) -> String:
	if category == "attack":
		return "attacks"
	if category == "special":
		return "specials"
	return category  # run / jump / dash / slam


## Every option for a character in a category: [{id, name, tier, icon, category}], sourced from the
## Actions catalog.
static func options(character: String, category: String) -> Array:
	var kind := _kind(category)
	var out := []
	for id: String in Actions.ids(character, kind):
		var a := Actions.get_action(character, kind, id)
		if a != null:
			out.append({"id": id, "name": a.name, "tier": a.tier, "icon": a.icon, "category": category})
	return out


## The default (starting) option id for a category.
static func default_id(character: String, category: String) -> String:
	var a := Actions.get_action(character, _kind(category))
	return a.id if a != null else ""


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
