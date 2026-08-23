using Godot;
using GArr = Godot.Collections.Array;

namespace MyGame;

/// <summary>
/// A MOVE-SCOPED build capability — the item/build layer. A Buff IS a <see cref="Passive"/> (granted the same
/// way: a reward's passive → <c>Player.add_passive</c>, torn down on run restart), plus the reward doc's extras.
/// C# port of <c>scripts/abilities/buff.gd</c>, extended to the doc's model. See docs/rewards-design.md.
///
/// <list type="bullet">
/// <item><see cref="AppliesTo"/> — WHICH move(s) this touches: a move id ("twin_reaper"), a family keyword
///   ("attack"/"special", matched on Action.category), a tag ("shield"/"charm", matched on Action.tags), or "*"
///   for everything (empty = "*"). One field expresses a tailor-made per-move buff AND a shared/general one.</item>
/// <item><see cref="Family"/> — a REPLACE-IN-PLACE group. Granting a buff whose family is already held removes the
///   old one first, so a TIER upgrade supersedes its predecessor instead of stacking. "" = independent. The doc's
///   rule: same buff, different tier → replace (by family); a DIFFERENT buff → stacks.</item>
/// <item><see cref="Tier"/> — the doc's rarity (Common→Epic). Carries the badge colour; the per-tier magnitude
///   lives in the concrete buff (it reads its own Tier to scale). Higher tier replaces lower within a family.</item>
/// <item><see cref="DurationLevels"/> — the doc's lifetime: <c>null</c> = permanent (whole run), <c>N</c> = lasts N
///   levels. Player ticks it down on level advance and tears the buff out when it expires.</item>
/// <item><see cref="Trigger"/> — the primary hook this buff binds to (data/display; the working mechanism is still
///   overriding the Passive hook). Lets a future data-driven buff declare its moment without a subclass.</item>
/// </list>
///
/// <para>Two ways a buff takes effect (either or both): NUMBERS — override <see cref="Passive.ModifyTuning"/>,
/// gated with <see cref="AppliesToAction"/>; BEHAVIOUR — override an event hook (self-scoping). Concrete buffs
/// live at <c>scripts/abilities/*.cs</c> and set these in their constructor.</para>
/// </summary>
[GlobalClass]
public partial class Buff : Passive
{
    /// <summary>Move ids / family keywords / tags this buff modifies ("" or "*" = all).</summary>
    public GArr AppliesTo = new();

    /// <summary>Replace-in-place group ("" = never auto-replaced). Tiers of one buff share a family.</summary>
    public string Family = "";

    /// <summary>Rarity tier (doc: Common→Epic). Drives the badge colour + the concrete buff's per-tier scaling.</summary>
    public Tier Tier = Tier.Common;

    /// <summary>Lifetime in LEVELS: <c>null</c> = permanent (whole run); a value N = expires after N level advances.</summary>
    public int? DurationLevels = null;

    /// <summary>The primary event hook this buff binds to (data/display; see <see cref="MyGame.Trigger"/>).</summary>
    public Trigger Trigger = Trigger.None;

    /// <summary>
    /// True if this buff should act on <paramref name="action"/> — by id, by category keyword ("attack"/"special"),
    /// by a tag, or unconditionally ("*"/empty). Gate <see cref="Passive.ModifyTuning"/> (and move-specific work) with it.
    /// <paramref name="action"/> is the GDScript Action object (bridged fields).
    /// </summary>
    public bool AppliesToAction(GodotObject action)
    {
        if (action == null)
            return false;
        if (AppliesTo.Count == 0 || AppliesTo.Contains("*"))
            return true;
        if (AppliesTo.Contains(action.Get("id")))
            return true;
        // Action.Category: ATTACK = 0, SPECIAL = 1 (see configs/action.gd).
        int cat = action.Get("category").As<int>();
        string catKw = cat == 0 ? "attack" : cat == 1 ? "special" : "";
        if (catKw != "" && AppliesTo.Contains(catKw))
            return true;
        foreach (Variant t in action.Get("tags").As<GArr>())
            if (AppliesTo.Contains(t))
                return true;
        return false;
    }

    /// <summary>Decrement a level-scoped lifetime; true once it has run out (permanent buffs never expire).</summary>
    public bool TickLevelAndExpired()
    {
        if (DurationLevels is not int left)
            return false; // permanent
        DurationLevels = left - 1;
        return DurationLevels <= 0;
    }
}
