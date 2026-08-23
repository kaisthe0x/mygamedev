using Godot;
using GDict = Godot.Collections.Dictionary;

namespace MyGame;

/// <summary>
/// Per-move buff for Twin Reaper: +25% damage on that attack ONLY. The worked example of the NUMBERS path — it
/// overrides <see cref="Passive.ModifyTuning"/> and gates it with <see cref="Buff.AppliesToAction"/>, so unlike
/// the global "+12% attack damage" reward this touches a single move. C# port of <c>scripts/abilities/reaper_edge.gd</c>.
/// </summary>
[GlobalClass]
public partial class ReaperEdge : Buff
{
    private const float DamageMult = 1.25f;

    public ReaperEdge()
    {
        Id = "reaper_edge";
        AppliesTo = new Godot.Collections.Array { "twin_reaper" };
    }

    public override GDict ModifyTuning(Player player, GodotObject action, int seg, GDict tuning)
    {
        if (AppliesToAction(action) && tuning.ContainsKey("damage"))
            tuning["damage"] = tuning["damage"].As<float>() * DamageMult;
        return tuning;
    }
}
