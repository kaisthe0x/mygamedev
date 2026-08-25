using Godot;
using System.Collections.Generic;
using GDict = Godot.Collections.Dictionary;
using GArr = Godot.Collections.Array;

namespace MyGame;

/// <summary>
/// The player's swappable LOADOUT layer: per <see cref="LoadoutCategory"/> a character has one or more OPTIONS.
/// Reads each Action's id/name/icon. C# port of <c>configs/loadout.gd</c>. The `category` stored in the option /
/// swap dicts is the enum as an int (Godot Variant), read back with <c>(LoadoutCategory)v.As&lt;int&gt;()</c>.
/// </summary>
public static class Loadout
{
    /// <summary>Every option for a character in a category: [{id, name, icon, category}].</summary>
    public static GArr Options(string character, LoadoutCategory category)
    {
        string kind = category.Kind();
        var outArr = new GArr();
        foreach (string id in Actions.Ids(character, kind))
        {
            var a = Actions.GetAction(character, kind, id);
            if (a != null)
                outArr.Add(new GDict { { "id", a.Id }, { "name", a.Name }, { "icon", a.Icon }, { "category", (int)category } });
        }
        return outArr;
    }

    /// <summary>The default (starting) option id for a category.</summary>
    public static string DefaultId(string character, LoadoutCategory category)
    {
        var a = Actions.GetAction(character, category.Kind());
        return a != null ? a.Id : "";
    }

    /// <summary>Categories with a real choice (&gt;1 option) + the options NOT currently equipped — the swap-reward material. Returns [{category, option}].</summary>
    public static GArr SwapChoices(string character, Dictionary<LoadoutCategory, string> current)
    {
        var outArr = new GArr();
        foreach (var cat in LoadoutCategories.All)
        {
            var opts = Options(character, cat);
            if (opts.Count < 2)
                continue;
            string cur = current.GetValueOrDefault(cat, DefaultId(character, cat));
            foreach (Variant oV in opts)
            {
                var o = oV.As<GDict>();
                if (o["id"].AsString() != cur)
                    outArr.Add(new GDict { { "category", (int)cat }, { "option", o } });
            }
        }
        return outArr;
    }
}
