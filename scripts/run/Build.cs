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
    public GDict Equipped = new();  // category key -> equipped Action id (only the VALUES are queried)
    public GArr Rewards = new();     // reward ids taken this run
    public GDict Tags = new();       // tag -> true, unioned from every equipped Action's tags

    // category -> Actions pool kind. Only attack/special pluralise; the rest pass through, so surge stays "surge"
    // and its get_action returns null — a faithful quirk of the original (surge tags stay OUT of the build union).
    private static string Kind(LoadoutCategory category) => category switch
    {
        LoadoutCategory.Attack => "attacks",
        LoadoutCategory.Special => "specials",
        _ => category.Key(),
    };

    public static Build Of(Player player)
    {
        var b = new Build();
        foreach (var cat in LoadoutCategories.All)
        {
            string id = player.loadout_id(cat);
            b.Equipped[cat.Key()] = id;
            var a = Actions.GetAction(player.character, Kind(cat), id);
            if (a != null)
                foreach (string t in a.Tags)
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
