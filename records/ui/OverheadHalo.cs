namespace MyGame;

/// <summary>
/// The optional over-head looping halo for a <see cref="StatusType"/> (e.g. the swirl of a stun) — a horizontal
/// sprite sheet of <see cref="HFrames"/> equal cells, played at <see cref="Fps"/>, scaled + nudged up by <see cref="YOff"/>.
/// </summary>
public sealed record OverheadHalo(string Sheet, int HFrames, double Fps, float Scale, float YOff);
