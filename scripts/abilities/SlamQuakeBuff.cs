using Godot;

namespace MyGame;

/// <summary>
/// Slam Quake: on a slam landing, stun every enemy within <see cref="QuakeRadius"/> for a per-tier duration
/// (<c>Player.stun_nearby</c>, the surge's stun-sweep pattern). Radius is a fixed tunable. Built by <see cref="BuffCatalog"/>.
/// </summary>
public partial class SlamQuakeBuff : Buff
{
    private const float QuakeRadius = 140.0f;  // stun reach around the slam point (tunable)

    private readonly float[] _secs;  // per-tier stun seconds, indexed Common..Epic

    public SlamQuakeBuff(string id, float[] secs)
    {
        Id = id;
        Trigger = Trigger.OnSlamLand;
        _secs = secs;
    }

    public override void OnSlamLand(Player p, float fallDistance, float fallSpeed) =>
        p.stun_nearby(QuakeRadius, _secs[Mathf.Clamp((int)Tier, 0, _secs.Length - 1)]);
}
