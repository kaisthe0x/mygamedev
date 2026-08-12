class_name Build
extends RefCounted

## A queryable snapshot of the player's BUILD -- what's equipped (attack/special/movement) plus the
## rewards taken this run -- for CONDITIONAL rewards to predicate over (see Rewards.offer_for). Built
## cheaply and fresh on each offer via `Build.of(player)`, so it always reflects the current state.
##
## Conditions are plain dicts evaluated by `matches()`: `{"equipped": "twin_reaper"}` (an Action id
## equipped in any slot), `{"tag": "charm"}` (a tag any equipped Action carries), `{"reward": "leech"}`
## (a reward already taken). An empty `{}` is always true. A reward's `requires` gates whether it's
## offered; its `synergy` condition boosts its roll weight when it holds.

var equipped: Dictionary = {} ## category -> equipped Action id (attack/special/run/jump/dash/slam)
var rewards: Array = [] ## reward ids taken this run, in pick order
var tags: Dictionary = {} ## tag -> true, unioned from every equipped Action's `tags`


## category ("attack"/"special") -> Actions pool kind (plural); movement categories map 1:1.
static func _kind(category: String) -> String:
	if category == "attack":
		return "attacks"
	if category == "special":
		return "specials"
	return category


## Snapshot the player's current build.
static func of(player: Player) -> Build:
	var b := Build.new()
	for cat: String in Loadout.CATEGORIES:
		var id: String = player.loadout_id(cat)
		b.equipped[cat] = id
		var a := Actions.get_action(player.character, _kind(cat), id)
		if a != null:
			for t: String in a.tags:
				b.tags[t] = true
	b.rewards = player.rewards_taken()
	return b


## Is `id` the equipped Action in ANY slot?
func has_action(id: String) -> bool:
	return id in equipped.values()


func has_tag(tag: String) -> bool:
	return tags.get(tag, false)


func has_reward(id: String) -> bool:
	return id in rewards


## Does this build satisfy a condition dict? ALL present keys must hold (AND). Supported: `equipped`
## (an Action id equipped anywhere), `tag` (a build tag present), `reward` (a reward already taken).
## An empty / null condition is always true.
func matches(cond: Dictionary) -> bool:
	if cond.is_empty():
		return true
	if cond.has("equipped") and not has_action(cond["equipped"]):
		return false
	if cond.has("tag") and not has_tag(cond["tag"]):
		return false
	if cond.has("reward") and not has_reward(cond["reward"]):
		return false
	return true
