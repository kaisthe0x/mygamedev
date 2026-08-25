namespace MyGame;

/// <summary>
/// An enemy STATUS effect shown next to the health bar (and optionally as an over-head halo). Closed taxonomy —
/// the enemy computes its active set each frame (see <c>Enemy.RefreshStatusIcons</c>). The snake form (via
/// <see cref="StatusTypes.Key"/>) indexes the <see cref="Icons"/> registry (<c>status:&lt;id&gt;</c>).
/// </summary>
public enum StatusType
{
    Reap,
    Stun,
    Slow,
    Charm,
}
