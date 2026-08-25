using Godot;

namespace MyGame;

/// <summary>Presentation for a <see cref="StatusType"/>: the pip/halo tint + a human-readable label.</summary>
public sealed record StatusDef(Color Color, string Label);
