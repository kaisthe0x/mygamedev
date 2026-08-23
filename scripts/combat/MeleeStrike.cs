using Godot;

namespace MyGame;

/// <summary>
/// A forward melee slash box — the common single-hit strike (a directional swing). Behaviour is the shared
/// <see cref="Strike"/> base; the type marks intent and is where melee-specific behaviour would live.
/// </summary>
[GlobalClass]
public partial class MeleeStrike : Strike
{
}
