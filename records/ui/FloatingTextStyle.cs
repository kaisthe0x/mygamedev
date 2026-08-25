using Godot;

namespace MyGame;

/// <summary>
/// The look + motion of a <see cref="FloatingTextType"/> preset (replaces the old floating-text config dict).
/// Size + colour can either be FIXED (<see cref="Size"/>/<see cref="Color"/>) or RAMP by hit magnitude between
/// the lo/hi pair over [<see cref="MagLo"/>, <see cref="MagHi"/>]. Defaults match <see cref="FloatingText"/>'s
/// own fallbacks, so a preset only sets what it deviates on.
/// </summary>
public sealed record FloatingTextStyle
{
    public string Font { get; init; } = "";
    /// <summary>Fixed font size; when null the size ramps <see cref="SizeLo"/>→<see cref="SizeHi"/> by magnitude.</summary>
    public int? Size { get; init; }
    public int SizeLo { get; init; } = 18;
    public int SizeHi { get; init; } = 18;
    public float MagLo { get; init; } = 0.0f;
    public float MagHi { get; init; } = 0.0f;
    /// <summary>Fixed colour; when null the colour ramps <see cref="ColorLo"/>→<see cref="ColorHi"/> by magnitude.</summary>
    public Color? Color { get; init; }
    public Color ColorLo { get; init; } = Colors.White;
    public Color ColorHi { get; init; } = Colors.White;
    public Color OutlineColor { get; init; } = new(0, 0, 0, 0.85f);
    public int OutlineSize { get; init; } = 5;
    public float Rise { get; init; } = 26.0f;
    public float Drift { get; init; } = 12.0f;
    public float Jitter { get; init; } = 8.0f;
    public float Life { get; init; } = 0.8f;
    public float PopScale { get; init; } = 0.7f;
    public float PopTime { get; init; } = 0.14f;
    public float Hold { get; init; } = 0.4f;
    public bool Italic { get; init; }
    public float ItalicDeg { get; init; } = 12.0f;
    public bool FadeIn { get; init; }
}
