using Godot;

namespace MyGame;

/// <summary>
/// Heal a per-tier fraction of the damage the player deals, via <see cref="Passive.OnHitDealt"/> — the tiered,
/// data-driven cousin of <see cref="Leech"/>. Covers the catalog's sustain buffs (Zahluq Bloodrush, Ora Ora Skim,
/// Dash Leech, …). Per-attack ones are gated at OFFER time (only shown when that attack is equipped, and the
/// attack is locked for the run), so no per-hit move gating is needed here. Built by <see cref="BuffCatalog"/>.
/// </summary>
public partial class LifestealBuff : Buff
{
    private readonly float[] _frac;  // per-tier fraction of damage healed, indexed Common..Epic

    public LifestealBuff(string id, float[] frac)
    {
        Id = id;
        _frac = frac;
    }

    public override void OnHitDealt(Player player, float amount, Node target)
    {
        if (amount > 0.0f)
            player.heal(amount * _frac[Mathf.Clamp((int)Tier, 0, _frac.Length - 1)]);
    }
}
