using Godot;
using GDict = Godot.Collections.Dictionary;

namespace MyGame;

/// <summary>
/// Registry of enemy STATUS effects shown as a small icon next to the floating health bar (see StatusIcons).
/// Each entry pairs a tint + a human label; the icon TEXTURE comes from <see cref="Icons"/> under "status:&lt;id&gt;".
/// <see cref="ORDER"/> fixes the left-to-right layout; <see cref="OVERHEAD"/> is the optional hovering halo.
/// C# port of <c>configs/status_types.gd</c> (pure data). Add a status = a DEFS/ORDER entry + an Icons path.
/// </summary>
public static class StatusTypes
{
    public static readonly GDict DEFS = new()
    {
        { "reap", new GDict { { "color", new Color(0.55f, 0.95f, 0.45f) }, { "label", "Reaped" } } },
        { "stun", new GDict { { "color", new Color(1.0f, 0.86f, 0.28f) }, { "label", "Stunned" } } },
        { "slow", new GDict { { "color", new Color(0.45f, 0.7f, 1.0f) }, { "label", "Slowed" } } },
        { "charm", new GDict { { "color", new Color(1.0f, 0.5f, 0.75f) }, { "label", "Charmed" } } },
    };

    /// <summary>Fixed draw order (left → right).</summary>
    public static readonly string[] ORDER = { "reap", "stun", "slow", "charm" };

    /// <summary>Optional over-head halo per status: {sheet, hframes, fps, scale, y_off}. ONE shows at a time (ORDER priority).</summary>
    public static readonly GDict OVERHEAD = new()
    {
        { "reap", new GDict
            {
                { "sheet", "res://sprites/things/state/dying.png" },
                { "hframes", 12 }, { "fps", 12.0 }, { "scale", 0.3 }, { "y_off", 22.0 },
            }
        },
        { "stun", new GDict
            {
                { "sheet", "res://sprites/things/state/stunned.png" },
                { "hframes", 4 }, { "fps", 12.0 }, { "scale", 0.3 }, { "y_off", 20.0 },
            }
        },
    };

    /// <summary>The tint for a status id (white if unknown), so StatusIcons can colour a placeholder pip.</summary>
    public static Color ColorOf(string id)
    {
        if (DEFS.ContainsKey(id) && DEFS[id].As<GDict>() is { } d && d.ContainsKey("color"))
            return d["color"].As<Color>();
        return Colors.White;
    }
}
