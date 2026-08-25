namespace MyGame;

/// <summary>
/// Design-shorthand difficulty of an enemy kit, for wave-building in <see cref="Levels"/>. Advisory metadata
/// only — RunManager skips it when applying a kit (it's not an Enemy property).
/// </summary>
public enum EnemyTier
{
    Chip,
    Mid,
    Strong,
}
