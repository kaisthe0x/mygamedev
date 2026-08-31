using Godot;

namespace MyGame;

/// <summary>
/// A run-scoped MULTIPLIER buff: <see cref="Setup"/> scales a Player mult-field by a per-tier factor,
/// <see cref="Teardown"/> restores it. For the catalog's stats the combat seam reads DIRECTLY (not via
/// <see cref="Passive.ModifyTuning"/>) — High Jump (<c>jump_velocity_bonus</c>, applied at the jump site) and
/// Slam Force (<c>slam_damage_mult</c>, applied in <c>Player.SlamRelease</c>). Routed by <see cref="Field"/>;
/// the granted instance's <see cref="Buff.Tier"/> picks the factor. Built by <see cref="BuffCatalog"/>.
/// </summary>
public partial class RunStatBuff : Buff
{
    public enum Field { JumpHeight, SlamDamage }

    private readonly Field _field;
    private readonly float[] _mult;  // per-tier multiplier, indexed Common..Epic

    private float Factor => _mult[Mathf.Clamp((int)Tier, 0, _mult.Length - 1)];

    public RunStatBuff(string id, Field field, float[] mult)
    {
        Id = id;
        _field = field;
        _mult = mult;
    }

    public override void Setup(Player p) => Scale(p, Factor);
    public override void Teardown(Player p) { if (!Mathf.IsZeroApprox(Factor)) Scale(p, 1.0f / Factor); }

    private void Scale(Player p, float f)
    {
        switch (_field)
        {
            case Field.JumpHeight: p.jump_velocity_bonus *= f; break;
            case Field.SlamDamage: p.slam_damage_mult *= f; break;
        }
    }
}
