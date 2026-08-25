namespace MyGame;

/// <summary>
/// A preset kind of floating combat text (its look + in/out transition live in <see cref="FloatingTextTypes"/>).
/// Closed set — the callers pick one when they <see cref="FloatingText.Emit"/>.
/// </summary>
public enum FloatingTextType
{
    /// <summary>Damage dealt to an enemy (white → hot-gold ramp by magnitude).</summary>
    Damage,
    /// <summary>Damage dealt by a SPECIAL (magenta, so special hits read distinctly).</summary>
    DamageSpecial,
    /// <summary>Damage the PLAYER takes (colour overridden per-call with the run's hair pick).</summary>
    PlayerDamage,
}
