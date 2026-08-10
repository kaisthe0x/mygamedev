class_name Reward
extends RefCounted

## One offerable reward -- typed data built from the catalog (configs/rewards_catalog.gd), read by the
## `Rewards` service. The DATA lives in the catalog; the OFFER logic + EFFECT logic live in Rewards --
## config kept separate from code, same as Actions.
##
## CONDITIONS make a reward build-aware (Phase 4), evaluated against the queryable Build (Build.matches):
##  - requires : offered ONLY when the Build matches this condition dict. {} = always offerable.
##  - synergy  : {"when": <cond>, "weight": <float>} -- MULTIPLIES this reward's roll weight when the
##               Build matches `when` (a soft nudge, not a gate). e.g. a charm special equipped -> reach ×3.
##  - unique   : true = never offer once it's already been taken (upgrades, one-shots).
##
## EFFECT is one of, applied in this order by Rewards.apply: `equip` (swap in an Action -> a move
## upgrade), `passive` (grant a behavioral Passive -> an ability reward), else a stat buff keyed by `id`.

var id: String
var name: String                   ## UI label
var desc: String                   ## UI one-liner
var icon: String = ""              ## res:// path; "" -> reward_ui falls back to the buff: icon registry (Icons.buff)
var tier: String = ""              ## "" = no tier badge (a plain buff); set for swap / upgrade cards
var door: String = ""              ## the door pool it came from (set by the loader)
var tags: Array = []
var requires: Dictionary = {}      ## Build.matches gate for being offered
var synergy: Dictionary = {}       ## {"when": <cond>, "weight": <float>} roll-weight nudge
var upgrades: String = ""          ## label: the Action id this upgrades (intent + card copy)
var unique: bool = false           ## once-only (don't re-offer if already taken)
var passive: String = ""           ## grant this Passive (scripts/abilities/<id>.gd) -- an ability reward
var equip: Dictionary = {}         ## {"category","id"} to equip -- a move swap / upgrade


static func make(door_type: String, d: Dictionary) -> Reward:
	var r := Reward.new()
	r.id = String(d["id"])
	r.name = String(d.get("name", r.id.capitalize()))
	r.desc = String(d.get("desc", ""))
	r.icon = String(d.get("icon", ""))
	r.tier = String(d.get("tier", ""))
	r.door = door_type
	r.tags = d.get("tags", [])
	r.requires = d.get("requires", {})
	r.synergy = d.get("synergy", {})
	r.upgrades = String(d.get("upgrades", ""))
	r.unique = bool(d.get("unique", false))
	r.passive = String(d.get("passive", ""))
	r.equip = d.get("equip", {})
	return r


## The card dict RewardUI consumes ({id, name, desc, + tier/icon when set}).
func to_card() -> Dictionary:
	var c := {"id": id, "name": name, "desc": desc}
	if not tier.is_empty():
		c["tier"] = tier
	if not icon.is_empty():
		c["icon"] = icon
	return c


## Should this reward be offered to `build`? (the requires gate + unique-not-already-taken).
func offerable(build: Build) -> bool:
	if unique and build.has_reward(id):
		return false
	return build.matches(requires)


## Roll weight given the current build: base 1.0, multiplied by `synergy.weight` when its condition holds.
func weight(build: Build) -> float:
	if synergy.is_empty():
		return 1.0
	return float(synergy.get("weight", 1.0)) if build.matches(synergy.get("when", {})) else 1.0
