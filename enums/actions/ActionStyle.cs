namespace MyGame;

/// <summary>How an <see cref="Action"/> plays out — its cadence. Combat reads this to drive combo/charge/cooldown behaviour.</summary>
public enum ActionStyle
{
    /// <summary>A single committed swing.</summary>
    Standard,
    /// <summary>A held multi-hit flurry (mash to continue).</summary>
    Flurry,
    /// <summary>A wind-up/charged release.</summary>
    Charged,
    /// <summary>A single hit gated by its own cooldown.</summary>
    Cooldown,
}
