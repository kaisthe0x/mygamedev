using Godot;
using GDict = Godot.Collections.Dictionary;
using GArr = Godot.Collections.Array;

namespace MyGame;

/// <summary>
/// A queryable snapshot of the player's BUILD — what's equipped (per category) plus the rewards taken this run —
/// for CONDITIONAL rewards to predicate over (see <see cref="Rewards.offer_for"/>). Built fresh on each offer via
/// <see cref="Of"/>. C# port of <c>scripts/run/build.gd</c>. Only the C# reward service uses it (plain class).
///
/// Conditions are plain dicts evaluated by <see cref="Matches"/>: <c>{"equipped": id}</c>, <c>{"tag": t}</c>,
/// <c>{"reward": id}</c>; an empty <c>{}</c> is always true.
/// </summary>
public sealed class Build
{
    // Mirror of Loadout.CATEGORIES (a GDScript const — hardcoded so C# needn't read it).
    private static readonly string[] Categories = { "attack", "special", "surge", "run", "jump", "dash", "slam" };

    public GDict Equipped = new();  // category -> equipped Action id
    public GArr Rewards = new();     // reward ids taken this run
    public GDict Tags = new();       // tag -> true, unioned from every equipped Action's tags

    // category -> Actions pool kind (as in build.gd: only attack/special pluralise; the rest pass through,
    // so "surge" stays "surge" and its get_action returns null — a faithful quirk of the original).
    private static string Kind(string category) => category switch
    {
        "attack" => "attacks",
        "special" => "specials",
        _ => category,
    };

    public static Build Of(Player player)
    {
        var b = new Build();
        foreach (string cat in Categories)
        {
            string id = player.loadout_id(cat);
            b.Equipped[cat] = id;
            var a = Actions.GetAction(player.character, Kind(cat), id);
            if (a != null)
                foreach (Variant t in a.tags)
                    b.Tags[t] = true;
        }
        b.Rewards = player.rewards_taken();
        return b;
    }

    public bool HasAction(string id) => Equipped.Values.Contains(id);
    public bool HasTag(string tag) => Tags.ContainsKey(tag) && Tags[tag].AsBool();
    public bool HasReward(string id) => Rewards.Contains(id);

    /// <summary>Does this build satisfy a condition dict? ALL present keys must hold (AND). Empty = always true.</summary>
    public bool Matches(GDict cond)
    {
        if (cond.Count == 0)
            return true;
        if (cond.ContainsKey("equipped") && !HasAction(cond["equipped"].AsString()))
            return false;
        if (cond.ContainsKey("tag") && !HasTag(cond["tag"].AsString()))
            return false;
        if (cond.ContainsKey("reward") && !HasReward(cond["reward"].AsString()))
            return false;
        return true;
    }
}
