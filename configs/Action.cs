using Godot;
using System.Collections.Generic;
using GDict = Godot.Collections.Dictionary;
using GArr = Godot.Collections.Array;

namespace MyGame;

/// <summary>
/// One thing a character PERFORMS — an attack / special / movement / surge. Identity + cadence + OPTIONALLY a
/// `hit` (StrikeSpec), `move` (Locomotion), or `surge` (SurgeSpec). Presentation is keyed off <c>animation</c>.
/// C# port of <c>configs/action.gd</c>. Snake public members so the Player/HUD/etc. address them via
/// <c>.Get("animation")</c> / <c>.Call("segment", seg)</c> exactly as before.
/// </summary>
public partial class Action : RefCounted
{
    public enum Category { ATTACK, SPECIAL, RUN, JUMP, DASH, SLAM, SURGE, OTHER }
    public enum Style { STANDARD, FLURRY, CHARGED, COOLDOWN }

    private static readonly Dictionary<string, int> StyleMap = new()
    {
        { "standard", 0 }, { "flurry", 1 }, { "charged", 2 }, { "cooldown", 3 },
    };

    public string id;
    public string name;
    public string icon = "";
    public int category = (int)Category.ATTACK;
    public int style = (int)Style.STANDARD;
    public string tier = "typical";
    public GArr tags = new();
    public StringName animation;
    public float cooldown = 0.0f;
    public StrikeSpec hit = null;
    public Locomotion move = null;
    public SurgeSpec surge = null;

    /// <summary>Build an Action from a catalog entry (see ActionsKhalid). Defaults `animation` by category.</summary>
    public static Action Make(Category cat, string actionId, GDict d)
    {
        var a = new Action
        {
            id = actionId,
            category = (int)cat,
            icon = d.ContainsKey("icon") ? d["icon"].AsString() : "",
            style = StyleMap.GetValueOrDefault(d.ContainsKey("style") ? d["style"].AsString() : "standard", (int)Style.STANDARD),
            tier = d.ContainsKey("tier") ? d["tier"].AsString() : "typical",
            tags = d.ContainsKey("tags") ? d["tags"].As<GArr>() : new GArr(),
            cooldown = d.ContainsKey("cooldown") ? d["cooldown"].As<float>() : 0.0f,
        };
        a.name = d.ContainsKey("name") ? d["name"].AsString() : Capitalize(actionId);
        if (cat is Category.ATTACK or Category.SPECIAL)
        {
            string prefix = cat == Category.ATTACK ? "attack" : "special";
            a.animation = d.ContainsKey("animation") ? d["animation"].AsString() : $"{prefix}_{actionId}";
        }
        else if (cat == Category.SURGE)
            a.animation = d.ContainsKey("animation") ? d["animation"].AsString() : $"surge_{actionId}";
        else
            a.animation = d.ContainsKey("animation") ? d["animation"].AsString() : "";
        if (d.ContainsKey("hit"))
            a.hit = StrikeSpec.Make(d["hit"].As<GDict>());
        if (d.ContainsKey("move"))
            a.move = Locomotion.Make(d["move"].As<GDict>());
        if (d.ContainsKey("surge"))
            a.surge = SurgeSpec.Make(d["surge"].As<GDict>());
        return a;
    }

    /// <summary>The hitbox tuning for combo segment `seg` (delegates to the hit), or {} when this action has no hitbox.</summary>
    public GDict segment(int seg) => hit != null ? hit.segment(seg) : new GDict();

    public bool is_flurry() => style == (int)Style.FLURRY;

    // GDScript String.capitalize(): "twin_reaper" -> "Twin Reaper".
    private static string Capitalize(string id)
    {
        var parts = id.Split('_');
        for (int i = 0; i < parts.Length; i++)
            if (parts[i].Length > 0)
                parts[i] = char.ToUpper(parts[i][0]) + parts[i].Substring(1);
        return string.Join(" ", parts);
    }
}
