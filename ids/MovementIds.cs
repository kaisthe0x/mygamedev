namespace MyGame;

/// <summary>
/// Stable string IDs for movement-Action variants (run/jump/dash/slam), plus the pool keys themselves.
/// See <see cref="AttackIds"/> for why const string, not enum.
/// </summary>
public static class MovementIds
{
    // Pool keys (the movement categories).
    public const string Run = "run";
    public const string Jump = "jump";
    public const string Dash = "dash";
    public const string Slam = "slam";

    // Variant ids.
    public const string StandardStride = "standard_stride";
    public const string StandardLeap = "standard_leap";
    public const string BlinkDash = "blink_dash";
    public const string StandardSlam = "standard_slam";
}
