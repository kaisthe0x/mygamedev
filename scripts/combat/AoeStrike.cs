using Godot;

namespace MyGame;

/// <summary>
/// A centred ground AoE box (a shockwave / eruption). Shared <see cref="Strike"/> behaviour; the type marks a
/// centred, often-ground attack and is the base for <see cref="TimedAoeStrike"/>.
/// </summary>
[GlobalClass]
public partial class AoeStrike : Strike
{
}
