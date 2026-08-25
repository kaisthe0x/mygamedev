namespace MyGame;

/// <summary>
/// A slot in the player's swappable loadout. Closed set: three combat slots (Attack/Special/Surge) + four
/// movement slots (Run/Jump/Dash/Slam). The snake form (<see cref="LoadoutCategories.Key"/>) is used at string
/// seams (the <c>swap:&lt;cat&gt;:&lt;id&gt;</c> reward-card id, the authored Equip dict).
/// </summary>
public enum LoadoutCategory
{
    Attack,
    Special,
    Surge,
    Run,
    Jump,
    Dash,
    Slam,
}

/// <summary>Helpers for <see cref="LoadoutCategory"/> — the full/movement sets, the snake key, the Actions pool kind, and parse.</summary>
public static class LoadoutCategories
{
    public static readonly LoadoutCategory[] All =
        { LoadoutCategory.Attack, LoadoutCategory.Special, LoadoutCategory.Surge, LoadoutCategory.Run, LoadoutCategory.Jump, LoadoutCategory.Dash, LoadoutCategory.Slam };

    public static readonly LoadoutCategory[] Movement =
        { LoadoutCategory.Run, LoadoutCategory.Jump, LoadoutCategory.Dash, LoadoutCategory.Slam };

    /// <summary>The snake key ("attack"/"special"/… ) — used at string seams + as the movement variant lookup.</summary>
    public static string Key(this LoadoutCategory c) => c.ToString().ToLowerInvariant();

    /// <summary>The <see cref="Actions"/> pool name: combat slots pluralise (attack→attacks); movement slots are 1:1.</summary>
    public static string Kind(this LoadoutCategory c) => c switch
    {
        LoadoutCategory.Attack => "attacks",
        LoadoutCategory.Special => "specials",
        LoadoutCategory.Surge => "surges",
        _ => c.Key(),
    };

    /// <summary>Parse a snake category key (from a swap-card id / Equip dict) back to the enum; null if unknown.</summary>
    public static LoadoutCategory? Parse(string s) =>
        System.Enum.TryParse<LoadoutCategory>(s, ignoreCase: true, out var c) ? c : null;
}
