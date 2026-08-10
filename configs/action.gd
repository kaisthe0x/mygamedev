class_name Action
extends RefCounted

## One thing a character PERFORMS -- an attack or special (Phase 2 scope; dash / jump / abilities
## follow in later phases). The typed successor to `Move`: pure code-config data, built from a
## per-character catalog (configs/actions_<char>.gd, reached through `Actions`).
##
## Composition, not inheritance -- an Action is identity + cadence, and OPTIONALLY a `hit`
## (a StrikeSpec, the "Strike" component) when it deals damage. PRESENTATION is deliberately NOT
## stored here: `animation` is the key its particles (vfx/config/emitters_characters.gd) and sounds
## (configs/sfx_characters.gd) hang off -- change the anim and both follow. The Player holds a current
## attack + current special and drives them (Player.resolve_tuning / _start_special / _advance_combo).

## The slot / kind of thing this is. Maps 1:1 to a loadout category. ATTACK/SPECIAL carry a `hit`;
## RUN/JUMP/DASH/SLAM carry a `move` (Locomotion). OTHER is a catch-all.
enum Category { ATTACK, SPECIAL, RUN, JUMP, DASH, SLAM, OTHER }
## How input drives the action:
##  STANDARD -- one click per combo segment, freezing on each hit frame (the default swing).
##  FLURRY   -- hold the button; the anim loops fast and its punch frames fire the hit every pass.
##  COOLDOWN -- a heavy one-shot gated by `cooldown` (e.g. bakshen); shows the overhead recharge bar.
##  CHARGED  -- reserved (wind-up then release); treated as STANDARD until wired.
enum Style { STANDARD, FLURRY, CHARGED, COOLDOWN }

const _STYLE := {"standard": Style.STANDARD, "flurry": Style.FLURRY, "charged": Style.CHARGED, "cooldown": Style.COOLDOWN}

var id: String                    ## stable code reference (catalog key + save data); NOT shown to the player
var name: String                  ## UI display label ("Twin Reaper")
var icon: String = ""             ## res:// icon path for the picker / reward card ("" = fallback)
var category: Category = Category.ATTACK
var style: Style = Style.STANDARD
var tier: String = "typical"      ## loadout rarity: typical / elite / broken (Loadout.TIER_*)
var tags: Array = []              ## descriptive tags for build queries / reward synergies (e.g. ["charm"] on frenemy)
var animation: StringName         ## SpriteFrames anim -> particles + sounds follow it
var cooldown: float = 0.0         ## per-attack recharge in seconds (0 = none); drives the overhead bar (Player._attack_cd)
var hit: StrikeSpec = null        ## the damage component (ATTACK/SPECIAL); null = no hitbox (e.g. special_default's Impervious flex)
var move: Locomotion = null       ## the movement component (RUN/JUMP/DASH/SLAM); null for a combat action


## Build an Action from a catalog entry (see configs/actions_khalid.gd). For ATTACK/SPECIAL,
## `animation` defaults to "<attack|special>_<id>" and a `hit` becomes a StrikeSpec; for a movement
## category, a `move` dict becomes a Locomotion (movement anims are driven by the Player, not this).
static func make(cat: Category, action_id: String, d: Dictionary) -> Action:
	var a := Action.new()
	a.id = action_id
	a.category = cat
	a.name = String(d.get("name", action_id.capitalize()))
	a.icon = String(d.get("icon", ""))
	a.style = _STYLE.get(String(d.get("style", "standard")), Style.STANDARD)
	a.tier = String(d.get("tier", "typical"))
	a.tags = d.get("tags", [])
	if cat == Category.ATTACK or cat == Category.SPECIAL:
		var prefix := "attack" if cat == Category.ATTACK else "special"
		a.animation = StringName(d.get("animation", "%s_%s" % [prefix, action_id]))
	else:
		a.animation = StringName(d.get("animation", ""))
	a.cooldown = float(d.get("cooldown", 0.0))
	if d.has("hit"):
		a.hit = StrikeSpec.make(d["hit"])
	if d.has("move"):
		a.move = Locomotion.make(d["move"])
	return a


## The hitbox tuning for combo segment `seg` (delegates to the hit), or {} when this action has no
## hitbox -- the effect scene then carries its own numbers. See Player.resolve_tuning.
func segment(seg: int) -> Dictionary:
	return hit.segment(seg) if hit != null else {}


func is_flurry() -> bool:
	return style == Style.FLURRY
