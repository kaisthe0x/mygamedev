namespace MyGame;

/// <summary>
/// The delivery taxonomy for a hit (the vocabulary from the old <c>strike_spec.gd</c>). On the PLAYER side this is
/// descriptive (it labels the move); on the ENEMY side the snake form doubles as an emitter/SFX config key
/// (<c>&lt;id&gt;.&lt;type&gt;</c>) — use <see cref="StrikeTypes.Key"/> for that boundary.
/// </summary>
public enum StrikeType
{
    Melee,
    Projectile,
    DelayedProjectile,
    Aoe,
    DelayedAoe,   // stationary telegraphed area that erupts after a delay (enemy survives) — RESERVED, no user yet
    Kamikaze,     // enemy lunges at you, self-destructs in an AoE on arrival, dies (Ein) — evocative (approach+hit)
    Blast,
    Lunge,        // enemy lunges at you, body-checks on contact, SURVIVES — evocative (approach+hit); carries a Lunge impulse
    Trap,
}

/// <summary>Snake-case config-key mapping for <see cref="StrikeType"/> (emitter/SFX tables use the snake form).</summary>
public static class StrikeTypes
{
    private static readonly System.Collections.Generic.Dictionary<StrikeType, string> Keys = new()
    {
        { StrikeType.Melee, "melee" }, { StrikeType.Projectile, "projectile" },
        { StrikeType.DelayedProjectile, "delayed_projectile" }, { StrikeType.Aoe, "aoe" },
        { StrikeType.DelayedAoe, "delayed_aoe" }, { StrikeType.Kamikaze, "kamikaze" },
        { StrikeType.Blast, "blast" }, { StrikeType.Lunge, "lunge" }, { StrikeType.Trap, "trap" },
    };

    private static readonly System.Collections.Generic.Dictionary<string, StrikeType> ByKey = new();

    static StrikeTypes()
    {
        foreach (var (t, k) in Keys)
            ByKey[k] = t;
    }

    /// <summary>The snake-case config key for this type (e.g. <see cref="StrikeType.DelayedProjectile"/> → "delayed_projectile").</summary>
    public static string Key(this StrikeType t) => Keys[t];

    /// <summary>Parse a snake-case config key back to a <see cref="StrikeType"/> (defaults to Melee if unknown).</summary>
    public static StrikeType From(string key) => ByKey.GetValueOrDefault(key, StrikeType.Melee);
}
