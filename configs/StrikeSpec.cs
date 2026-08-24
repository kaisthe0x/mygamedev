using Godot;
using System.Collections.Generic;
using GDict = Godot.Collections.Dictionary;
using GArr = Godot.Collections.Array;

namespace MyGame;

/// <summary>
/// The "Strike" component of an <see cref="Action"/>: HOW a hit is delivered + its per-SEGMENT hitbox numbers.
/// Numbers stay as tuning DICTS (the combat resolve seam's shape). C# port of <c>configs/strike_spec.gd</c>.
/// Snake public members so consumers can address them via <c>.Get("type")</c> / <c>.Call("segment", seg)</c>.
/// </summary>
public partial class StrikeSpec : RefCounted
{
    /// <summary>Delivery type — descriptive taxonomy for the build UI; does NOT drive behaviour.</summary>
    public enum Type { MELEE, PROJECTILE, DELAYED_PROJECTILE, AOE, DELAYED_AOE, BLAST, TRAP }

    private static readonly Dictionary<string, int> TypeMap = new()
    {
        { "melee", 0 }, { "projectile", 1 }, { "delayed_projectile", 2 },
        { "aoe", 3 }, { "delayed_aoe", 4 }, { "blast", 5 }, { "trap", 6 },
    };

    public int type = (int)Type.MELEE;
    /// <summary>Per combo-SEGMENT hitbox tuning dicts (a shorter list reuses its last entry; empty = the scene's own numbers).</summary>
    public GArr segments = new();

    /// <summary>Build from a `hit` dict: { type, segments (a dict for one hit, OR an array per segment) }. `tuning` aliases `segments`.</summary>
    public static StrikeSpec Make(GDict d)
    {
        var s = new StrikeSpec
        {
            type = TypeMap.GetValueOrDefault(d.ContainsKey("type") ? d["type"].AsString() : "melee", (int)Type.MELEE),
        };
        Variant t = d.ContainsKey("segments") ? d["segments"] : (d.ContainsKey("tuning") ? d["tuning"] : new GArr());
        if (t.VariantType == Variant.Type.Array)
            s.segments = (GArr)t.As<GArr>().Duplicate();
        else if (t.VariantType == Variant.Type.Dictionary && t.As<GDict>().Count > 0)
            s.segments = new GArr { t };
        return s;
    }

    /// <summary>The tuning dict for combo segment `seg` (a shorter list reuses its last entry; empty list = {}).</summary>
    public GDict segment(int seg) =>
        segments.Count == 0 ? new GDict() : segments[Mathf.Min(seg, segments.Count - 1)].As<GDict>();
}
