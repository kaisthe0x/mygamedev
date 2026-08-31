using Godot;

namespace MyGame;

/// <summary>
/// Bakshen Overcharge: each landed hit shaves a per-tier chunk off the attack cooldown (Epic = full reset via a
/// huge value), so rapid Bakshen chaining ramps damage. Offer-gated to the Bakshen attack (<see cref="Buff.AppliesTo"/>);
/// the attack is locked for the run, so in practice only Bakshen hits feed it. Built by <see cref="BuffCatalog"/>.
/// </summary>
public partial class OverchargeBuff : Buff
{
    private readonly float[] _secs;  // per-tier cooldown reduction seconds, indexed Common..Epic (Epic = huge = full)

    public OverchargeBuff(string id, float[] secs)
    {
        Id = id;
        Trigger = Trigger.OnHitDealt;
        _secs = secs;
    }

    public override void OnHitDealt(Player p, float amount, Node target) =>
        p.reduce_attack_cooldown(_secs[Mathf.Clamp((int)Tier, 0, _secs.Length - 1)]);
}
