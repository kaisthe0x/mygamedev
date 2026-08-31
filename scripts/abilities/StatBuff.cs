using Godot;

namespace MyGame;

/// <summary>
/// The workhorse buff: data-driven, it scales ONE <see cref="SegmentData"/> stat by a per-tier multiplier through
/// <see cref="Passive.ModifyTuning"/>, gated by <see cref="Buff.AppliesTo"/>. Covers the catalog's plain
/// tuning buffs (attack reach, slam force, a flat damage %, …) without a bespoke subclass each. Constructed by
/// <see cref="BuffCatalog"/> with its id + which stat + the per-tier factors (Common..Epic); the granted instance's
/// <see cref="Buff.Tier"/> picks the row. Not <c>[GlobalClass]</c> — it's instantiated from C#, never the editor.
/// </summary>
public partial class StatBuff : Buff
{
    public enum Stat { Damage, Reach, Knockback, Stun }

    private readonly Stat _stat;
    private readonly float[] _mult;  // per-tier MULTIPLIER, indexed Common..Epic (e.g. { 1.25f, 1.5f, ... })

    public StatBuff(string id, Stat stat, float[] mult)
    {
        Id = id;
        _stat = stat;
        _mult = mult;
    }

    public override SegmentData ModifyTuning(Player player, Action action, int seg, SegmentData t)
    {
        if (!AppliesToAction(action))
            return t;
        float m = _mult[Mathf.Clamp((int)Tier, 0, _mult.Length - 1)];
        switch (_stat)
        {
            case Stat.Damage when t.Damage.HasValue: t.Damage = t.Damage.Value * m; break;
            case Stat.Reach when t.Extents.HasValue: t.Extents = t.Extents.Value * m; break;
            case Stat.Knockback when t.Knockback.HasValue: t.Knockback = t.Knockback.Value * m; break;
            case Stat.Stun when t.Stun.HasValue: t.Stun = t.Stun.Value * m; break;
        }
        return t;
    }
}
