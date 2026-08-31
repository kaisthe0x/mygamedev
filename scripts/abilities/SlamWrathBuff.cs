using Godot;

namespace MyGame;

/// <summary>
/// Slam Wrath: a slam landing opens a per-tier timed window during which the equipped ATTACK deals bonus damage.
/// Self-contained — the window ticks in <see cref="Physics"/> and the boost lands through <see cref="ModifyTuning"/>
/// (gated to attacks by <see cref="Buff.AppliesTo"/>), so no Player API is needed. Built by <see cref="BuffCatalog"/>.
/// </summary>
public partial class SlamWrathBuff : Buff
{
    private readonly float[] _mult;  // per-tier attack-damage multiplier, indexed Common..Epic
    private readonly float[] _secs;  // per-tier window seconds, indexed Common..Epic
    private float _left = 0.0f;

    public SlamWrathBuff(string id, float[] mult, float[] secs)
    {
        Id = id;
        Trigger = Trigger.OnSlamLand;
        _mult = mult;
        _secs = secs;
    }

    public override void OnSlamLand(Player p, float fallDistance, float fallSpeed) =>
        _left = _secs[Mathf.Clamp((int)Tier, 0, _secs.Length - 1)];

    public override void Physics(Player p, double delta)
    {
        if (_left > 0.0f)
            _left = Mathf.Max(_left - (float)delta, 0.0f);
    }

    public override SegmentData ModifyTuning(Player p, Action action, int seg, SegmentData t)
    {
        if (_left > 0.0f && AppliesToAction(action) && t.Damage.HasValue)
            t.Damage = t.Damage.Value * _mult[Mathf.Clamp((int)Tier, 0, _mult.Length - 1)];
        return t;
    }
}
