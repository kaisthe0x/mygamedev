using Godot;

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
        Id = PassiveIds.ReaperEdge;
        AppliesTo = [AttackIds.TwinReaper];
    }

    public override SegmentData ModifyTuning(Player player, Action action, int seg, SegmentData tuning)
    {
        if (AppliesToAction(action) && tuning.Damage.HasValue)
            tuning.Damage *= DamageMult;
        return tuning;
    }
}
