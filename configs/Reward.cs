using Godot;
using GDict = Godot.Collections.Dictionary;
using GArr = Godot.Collections.Array;

namespace MyGame;

/// <summary>
/// One offerable reward — typed data built from the catalog (<see cref="RewardsCatalog"/>), read by the
/// <see cref="Rewards"/> service. C# port of <c>configs/reward.gd</c>. Only the C# reward service touches this,
/// so it's a plain class (not <c>[GlobalClass]</c>).
///
/// CONDITIONS make a reward build-aware, evaluated against the queryable <see cref="Build"/>:
/// <c>Requires</c> gates the offer (<c>{}</c> = always), <c>Synergy</c> = <c>{"when": cond, "weight": f}</c>
/// multiplies the roll weight when the Build matches, <c>Unique</c> = never re-offer once taken. EFFECT is one
/// of (applied in order by <see cref="Rewards.apply"/>): <c>Equip</c> (swap a move), <c>Passive</c> (grant a
/// behavioural passive), else a stat buff keyed by <c>Id</c>.
/// </summary>
public sealed class Reward
{
    public string Id;
    public string Name;
    public string Desc;
    public string Icon = "";
    public string TierLabel = "";       // "" = no tier badge (Reward.tier in GDScript)
    public string Door = "";
    public GArr Tags = new();
    public GDict Requires = new();
    public GDict Synergy = new();
    public string Upgrades = "";
    public bool Unique = false;
    public string Passive = "";
    public GDict Equip = new();

    private static string S(GDict d, string k, string def = "") => d.ContainsKey(k) ? d[k].AsString() : def;

    public static Reward Make(string doorType, GDict d)
    {
        var r = new Reward
        {
            Id = S(d, "id"),
            Door = doorType,
            Icon = S(d, "icon"),
            TierLabel = S(d, "tier"),
            Upgrades = S(d, "upgrades"),
            Passive = S(d, "passive"),
            Unique = d.ContainsKey("unique") && d["unique"].AsBool(),
            Tags = d.ContainsKey("tags") ? d["tags"].As<GArr>() : new GArr(),
            Requires = d.ContainsKey("requires") ? d["requires"].As<GDict>() : new GDict(),
            Synergy = d.ContainsKey("synergy") ? d["synergy"].As<GDict>() : new GDict(),
            Equip = d.ContainsKey("equip") ? d["equip"].As<GDict>() : new GDict(),
        };
        r.Name = S(d, "name", Capitalize(r.Id));
        r.Desc = S(d, "desc");
        return r;
    }

    /// <summary>The card dict RewardUI consumes ({id, name, desc, + tier/icon when set}).</summary>
    public GDict ToCard()
    {
        var c = new GDict { { "id", Id }, { "name", Name }, { "desc", Desc } };
        if (TierLabel != "")
            c["tier"] = TierLabel;
        if (Icon != "")
            c["icon"] = Icon;
        return c;
    }

    /// <summary>Should this reward be offered to `build`? (the requires gate + unique-not-already-taken).</summary>
    public bool Offerable(Build build)
    {
        if (Unique && build.HasReward(Id))
            return false;
        return build.Matches(Requires);
    }

    /// <summary>Roll weight given the build: base 1.0, ×`synergy.weight` when its condition holds.</summary>
    public float Weight(Build build)
    {
        if (Synergy.Count == 0)
            return 1.0f;
        float w = Synergy.ContainsKey("weight") ? Synergy["weight"].As<float>() : 1.0f;
        var when = Synergy.ContainsKey("when") ? Synergy["when"].As<GDict>() : new GDict();
        return build.Matches(when) ? w : 1.0f;
    }

    // GDScript String.capitalize(): "max_hp" -> "Max Hp". Mirror it for the default name.
    private static string Capitalize(string id)
    {
        var parts = id.Split('_');
        for (int i = 0; i < parts.Length; i++)
            if (parts[i].Length > 0)
                parts[i] = char.ToUpper(parts[i][0]) + parts[i].Substring(1);
        return string.Join(" ", parts);
    }
}
