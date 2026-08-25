using Godot;

namespace MyGame;

/// <summary>
/// A character's INTRINSIC ability — the <see cref="Passive"/> that's always on for that character (vs a
/// reward-granted one). The <see cref="Player"/> seeds it FIRST when that character is equipped
/// (see <c>Player.SeedPassives</c>). Same hooks as <see cref="Passive"/>; this subclass exists purely to name
/// the "character-intrinsic" role. Khalid currently ships without one. C# port of
/// <c>scripts/abilities/character_ability.gd</c>.
/// </summary>
[GlobalClass]
public partial class CharacterAbility : Passive
{
}
