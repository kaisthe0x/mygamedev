using Godot;
using GArr = Godot.Collections.Array;

namespace MyGame;

/// <summary>
/// A horizontal row of small status icons (reap / stun / charm / …) shown next to an enemy's floating health
/// bar. Built in code. The enemy recomputes its active-status set each frame and calls <see cref="SetActive"/>
/// (gated so we only redraw on a real change). Icons + tints come from the GDScript StatusTypes / Icons configs
/// (bridged). C# port of <c>scripts/combat/status_icons.gd</c>. C#-only consumer (Enemy).
/// </summary>
public partial class StatusIcons : Node2D
{
    private const float Icon = 7.0f;
    private const float Gap = 1.0f;

    private GArr _ids = new();

    /// <summary>Replace the shown set. `ids` is a list of status id Strings (already ordered by the caller).</summary>
    public void SetActive(GArr ids)
    {
        _ids = ids;
        QueueRedraw();
    }

    public override void _Draw()
    {
        float x = 0.0f;
        foreach (Variant idV in _ids)
        {
            string id = idV.AsString();
            var tex = Icons.Texture($"status:{id}");
            if (tex != null)
                DrawTextureRect(tex, new Rect2(x, -Icon / 2.0f, Icon, Icon), false, StatusTypes.ColorOf(id));
            x += Icon + Gap;
        }
    }
}
