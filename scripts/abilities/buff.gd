class_name Buff
extends Passive

## A MOVE-SCOPED build capability -- the item/build layer. A Buff IS a Passive (so it grants through the
## exact same path: a reward's `passive:` field -> Player.add_passive, cleared on run restart), but it
## adds two things a bare Passive lacks:
##
##   applies_to -- WHICH move(s) this buff touches. Any of: a move id ("twin_reaper"), a family keyword
##                 ("attack" / "special", matched on Action.category), a descriptive tag (matched on
##                 Action.tags, e.g. "shield"/"charm"), or "*" for everything. Empty = "*". This is how
##                 ONE field expresses both a tailor-made per-attack buff AND a shared one.
##   family     -- a REPLACE-IN-PLACE group. Granting a buff whose family is already held removes the old
##                 one first (Player.add_passive), so tiered upgrades supersede (Ricochet I -> II -> III)
##                 instead of stacking. "" = independent (never auto-replaced).
##
## Two ways a buff takes effect (a buff can use either or both):
##   1. NUMBERS  -- override `modify_tuning` (from Passive) to change a move's damage/knockback/etc. Gate
##                  it with `applies_to_action(action)` so it only touches the right move(s).
##   2. BEHAVIOUR -- override an event hook (on_parry, on_special_cast, on_hit_dealt, ...). Those hooks
##                  fire at a specific site (a parry, a special cast), so they self-scope; `applies_to`
##                  is then mostly for reward gating / display.
##
## Concrete buffs live at scripts/abilities/<id>.gd and set id / applies_to / family in _init.

var applies_to: Array = []  ## move ids / family keywords / tags this buff modifies ("" or "*" = all)
var family: String = ""  ## replace-in-place group ("" = never auto-replaced)


## True if this buff should act on `action` -- by id, by category keyword ("attack"/"special"), by a tag,
## or unconditionally ("*"/empty). Use this to gate `modify_tuning` (and any move-specific event work).
func applies_to_action(action: Action) -> bool:
	if action == null:
		return false
	if applies_to.is_empty() or applies_to.has("*"):
		return true
	if applies_to.has(action.id):
		return true
	var cat := ""
	if action.category == Action.Category.ATTACK:
		cat = "attack"
	elif action.category == Action.Category.SPECIAL:
		cat = "special"
	if cat != "" and applies_to.has(cat):
		return true
	for t in action.tags:
		if applies_to.has(t):
			return true
	return false
