using Godot;

namespace MyGame;

/// <summary>
/// Per-move buff for Redere Shield: a PERFECT PARRY also HEALS (on top of the reflect). Behavioural, via the
/// <see cref="Passive.OnParry"/> hook (fires only on the reflect branch, so it's self-scoped to the shield;
/// <see cref="Buff.AppliesTo"/> is here for reward gating / display). C# port of <c>scripts/abilities/parry_mend.gd</c>.
/// </summary>
[GlobalClass]
public partial class ParryMend : Buff
{
    private const float HealFraction = 0.5f;
    private const float HealMin = 8.0f;

    public ParryMend()
    {
        Id = PassiveIds.ParryMend;
        AppliesTo = [SpecialIds.RedereShield];
    }

    public override void OnParry(Player player, Hit hit)
    {
        player.heal(Mathf.Max(hit.Amount * HealFraction, HealMin));
    }
}
