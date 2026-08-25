namespace MyGame;

/// <summary>
/// The kind of reward an exit door offers — a closed set. The snake form (via <see cref="DoorTypes.Key"/>) indexes
/// the <see cref="RewardsCatalog"/> pools + the <see cref="Icons"/> registry (<c>door:&lt;type&gt;</c>).
/// </summary>
public enum DoorType
{
    Health,
    Athletic,
    Attack,
    Special,
}

/// <summary>Helpers for <see cref="DoorType"/> (the full set for random pick + the snake config key).</summary>
public static class DoorTypes
{
    /// <summary>Every door type — RunManager picks one at random per level.</summary>
    public static readonly DoorType[] All = { DoorType.Health, DoorType.Athletic, DoorType.Attack, DoorType.Special };

    /// <summary>The snake config key (indexes RewardsCatalog.POOLS + <c>Icons.Door</c>).</summary>
    public static string Key(this DoorType t) => t.ToString().ToLowerInvariant();
}
