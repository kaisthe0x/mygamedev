using Godot;
using GDict = Godot.Collections.Dictionary;
using GArr = Godot.Collections.Array;

namespace MyGame;

/// <summary>
/// Accessor over the per-character ACTION catalogs — turns catalog rows into <see cref="Action"/> objects on
/// demand. `kind` is one of the six pools: "attacks"/"specials"/"surges" (combat) or "run"/"jump"/"dash"/"slam"
/// (movement). C# port of <c>configs/actions.gd</c>. Repo ships Khalid only.
/// </summary>
public static class Actions
{
    private static GDict Tables(string character)
    {
        if (character == "khalid")
        {
            var mv = ActionsKhalid.MOVEMENTS;
            return new GDict
            {
                { "attacks", ActionsKhalid.ATTACKS }, { "specials", ActionsKhalid.SPECIALS }, { "surges", ActionsKhalid.SURGES },
                { "run", mv["run"] }, { "jump", mv["jump"] }, { "dash", mv["dash"] }, { "slam", mv["slam"] },
            };
        }
        return new GDict();
    }

    private static string DefaultId(string character, string kind)
    {
        if (character == "khalid")
            return kind switch
            {
                "attacks" => ActionsKhalid.DEFAULT_ATTACK,
                "specials" => ActionsKhalid.DEFAULT_SPECIAL,
                "surges" => ActionsKhalid.DEFAULT_SURGE,
                _ => ActionsKhalid.DEFAULT_MOVEMENTS.ContainsKey(kind) ? ActionsKhalid.DEFAULT_MOVEMENTS[kind].AsString() : "",
            };
        return "";
    }

    private static Action.Category CategoryOf(string kind) => kind switch
    {
        "attacks" => Action.Category.ATTACK,
        "specials" => Action.Category.SPECIAL,
        "surges" => Action.Category.SURGE,
        "run" => Action.Category.RUN,
        "jump" => Action.Category.JUMP,
        "dash" => Action.Category.DASH,
        "slam" => Action.Category.SLAM,
        _ => Action.Category.OTHER,
    };

    /// <summary>The Action for a character's pool by id (or the default when id is empty/unknown). Null if the pool is empty.</summary>
    public static Action GetAction(string character, string kind, string id = "")
    {
        var tables = Tables(character);
        if (!tables.ContainsKey(kind))
            return null;
        var pool = tables[kind].As<GDict>();
        if (pool.Count == 0)
            return null;
        if (id == "" || !pool.ContainsKey(id))
            id = DefaultId(character, kind);
        if (!pool.ContainsKey(id))
            return null;
        return Action.Make(CategoryOf(kind), id, pool[id].As<GDict>());
    }

    /// <summary>Ids of a character's actions in a pool (Loadout builds swap options from these).</summary>
    public static GArr Ids(string character, string kind)
    {
        var tables = Tables(character);
        var outArr = new GArr();
        if (tables.ContainsKey(kind))
            foreach (Variant k in tables[kind].As<GDict>().Keys)
                outArr.Add(k);
        return outArr;
    }
}
