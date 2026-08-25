namespace MyGame;

/// <summary>Which pool an <see cref="Action"/> belongs to. Drives the default animation prefix + how the Player equips it.</summary>
public enum ActionCategory
{
    Attack,
    Special,
    Run,
    Jump,
    Dash,
    Slam,
    Surge,
    Other,
}
