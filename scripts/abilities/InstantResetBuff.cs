using Godot;

namespace MyGame;

/// <summary>
/// Zahluq Instant Reset: whiffing the attack (a zero-victim swing) fully clears its cooldown, so a missed lunge can
/// be re-thrown at once. Fires off <see cref="Trigger.OnMiss"/> (emitted by <see cref="Hitbox.deactivate"/> when a
/// player attack box connects with nobody). Offer-gated to Zahluq (<see cref="Buff.AppliesTo"/>), which fires a
/// single hitbox per swing so one whiff = one reset. Built by <see cref="BuffCatalog"/>.
/// </summary>
public partial class InstantResetBuff : Buff
{
    private const float FullReset = 9999.0f; // huge subtraction → cooldown clamps to zero (reduce_attack_cooldown)

    public InstantResetBuff(string id)
    {
        Id = id;
        Trigger = Trigger.OnMiss;
    }

    public override void OnMiss(Player p) => p.reduce_attack_cooldown(FullReset);
}
