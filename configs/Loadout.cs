using Godot;
using GDict = Godot.Collections.Dictionary;
using GArr = Godot.Collections.Array;

namespace MyGame;

/// <summary>
/// The player's swappable LOADOUT layer: per category (attack/special/surge/run/jump/dash/slam) a character has
/// one or more OPTIONS with a TIER. Reads each Action's id/name/tier/icon. C# port of <c>configs/loadout.gd</c>.
/// </summary>
public static class Loadout
{
    public static readonly string[] CATEGORIES = { "attack", "special", "surge", "run", "jump", "dash", "slam" };
    public static readonly string[] MOVEMENT_CATS = { "run", "jump", "dash", "slam" };

    private static readonly GDict TierLabels = new() { { "typical", "Typical" }, { "elite", "Elite" }, { "broken", "Broken" } };
    private static readonly GDict TierColors = new()
    {
        { "typical", new Color(0.75f, 0.78f, 0.85f) },
        { "elite", new Color(0.45f, 0.82f, 1.0f) },
        { "broken", new Color(1.0f, 0.55f, 0.95f) },
    };

    public static string TierLabel(string tier) => TierLabels.ContainsKey(tier) ? TierLabels[tier].AsString() : "Typical";
    public static Color TierColor(string tier) => TierColors.ContainsKey(tier) ? TierColors[tier].As<Color>() : TierColors["typical"].As<Color>();

    /// <summary>The Actions pool `kind` for a loadout `category` ("attack"/"special"/"surge" pluralise; movement 1:1).</summary>
    private static string Kind(string category) => category switch
    {
        "attack" => "attacks",
        "special" => "specials",
        "surge" => "surges",
        _ => category,
    };

    /// <summary>Every option for a character in a category: [{id, name, tier, icon, category}].</summary>
    public static GArr Options(string character, string category)
    {
        string kind = Kind(category);
        var outArr = new GArr();
        foreach (Variant idV in Actions.Ids(character, kind))
        {
            var a = Actions.GetAction(character, kind, idV.AsString());
            if (a != null)
                outArr.Add(new GDict { { "id", a.id }, { "name", a.name }, { "tier", a.tier }, { "icon", a.icon }, { "category", category } });
        }
        return outArr;
    }

    /// <summary>The default (starting) option id for a category.</summary>
    public static string DefaultId(string character, string category)
    {
        var a = Actions.GetAction(character, Kind(category));
        return a != null ? a.id : "";
    }

    /// <summary>Categories with a real choice (&gt;1 option) + the options NOT currently equipped — the swap-reward material. Returns [{category, option}].</summary>
    public static GArr SwapChoices(string character, GDict current)
    {
        var outArr = new GArr();
        foreach (string cat in CATEGORIES)
        {
            var opts = Options(character, cat);
            if (opts.Count < 2)
                continue;
            string cur = current.ContainsKey(cat) ? current[cat].AsString() : DefaultId(character, cat);
            foreach (Variant oV in opts)
            {
                var o = oV.As<GDict>();
                if (o["id"].AsString() != cur)
                    outArr.Add(new GDict { { "category", cat }, { "option", o } });
            }
        }
        return outArr;
    }
}
