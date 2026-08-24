using Godot;
using GDict = Godot.Collections.Dictionary;

namespace MyGame;

/// <summary>
/// Per-enemy MARKER colour for the off-screen enemy arrows (<see cref="OffscreenMarkers"/>). Keyed by enemy_id;
/// an unknown id falls back to a threat red. C# port of <c>configs/enemy_markers.gd</c> (pure data).
/// </summary>
public static class EnemyMarkers
{
    private static readonly GDict COLORS = new()
    {
        { "kebus", new Color(0.90f, 0.68f, 0.24f) },   // tan / gold
        { "baghel", new Color(0.72f, 0.48f, 0.98f) },  // purple
        { "nasen", new Color(0.36f, 0.66f, 1.00f) },   // steel blue
        { "mazab", new Color(1.00f, 0.32f, 0.30f) },   // crimson
        { "ein", new Color(1.00f, 0.56f, 0.20f) },     // orange
        { "matat", new Color(1.00f, 0.42f, 0.12f) },   // deep orange-red
        { "tarri", new Color(1.00f, 0.87f, 0.10f) },   // yellow-gold
        { "breski", new Color(0.92f, 0.32f, 0.16f) },  // blood-red
    };
    private static readonly Color Fallback = new(1.0f, 0.30f, 0.30f);

    public static Color ColorFor(string enemyId) => COLORS.ContainsKey(enemyId) ? COLORS[enemyId].As<Color>() : Fallback;
}
