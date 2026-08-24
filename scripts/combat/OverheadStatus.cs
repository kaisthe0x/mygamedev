using Godot;
using System.Collections.Generic;
using GDict = Godot.Collections.Dictionary;
using GArr = Godot.Collections.Array;

namespace MyGame;

/// <summary>
/// A looping animation hovering over an enemy's head while a status is active — e.g. the swirling "halo" of a
/// STUN. Built in code; the over-head twin of <see cref="StatusIcons"/>. Shows the highest-PRIORITY active
/// status that has an over-head anim (StatusTypes.OVERHEAD), bobs it, hides when none. C# port of
/// <c>scripts/combat/overhead_status.gd</c>. C#-only consumer (Enemy); bridges the GDScript StatusTypes config.
/// </summary>
public partial class OverheadStatus : Node2D
{
    private const float BobAmpl = 1.5f;
    private const float BobSpeed = 2.2f;

    private AnimatedSprite2D _sprite;
    private float _yOff = 0.0f;
    private string _shown = "";
    private float _phase = 0.0f;

    // SpriteFrames are sliced ONCE per sheet and shared across every enemy (the art is identical).
    private static readonly Dictionary<string, SpriteFrames> SfCache = new();

    public override void _Ready()
    {
        _sprite = new AnimatedSprite2D
        {
            Centered = true,
            TextureFilter = CanvasItem.TextureFilterEnum.Nearest,
            ZIndex = 2,
            Visible = false,
        };
        AddChild(_sprite);
        SetProcess(false);
    }

    /// <summary>Anchor the halo at `headY` (feet are y=0, so the head line is negative).</summary>
    public void Setup(float headY) => Position = new Vector2(0.0f, headY);

    /// <summary>Show the highest-priority active status that HAS an over-head anim; hide if none do.</summary>
    public void SetActive(GArr ids)
    {
        string pick = "";
        foreach (string id in StatusTypes.ORDER)
        {
            if (ids.Contains(id) && StatusTypes.OVERHEAD.ContainsKey(id))
            {
                pick = id;
                break;
            }
        }
        if (pick == _shown)
            return;
        _shown = pick;
        if (pick == "")
        {
            _sprite.Visible = false;
            SetProcess(false);
            return;
        }
        var spec = StatusTypes.OVERHEAD[pick].As<GDict>();
        _sprite.SpriteFrames = FramesFor(spec);
        _sprite.Scale = Vector2.One * (spec.ContainsKey("scale") ? spec["scale"].As<float>() : 1.0f);
        _yOff = spec.ContainsKey("y_off") ? spec["y_off"].As<float>() : 0.0f;
        _phase = 0.0f;
        _sprite.Position = new Vector2(_sprite.Position.X, _yOff);
        _sprite.Play("default");
        _sprite.Visible = true;
        SetProcess(true);
    }

    public override void _Process(double delta)
    {
        _phase += (float)delta;
        _sprite.Position = new Vector2(_sprite.Position.X, _yOff + Mathf.Sin(_phase * Mathf.Tau * BobSpeed) * BobAmpl);
    }

    /// <summary>Build (and cache) a looping SpriteFrames from a horizontal sheet: `hframes` cells of equal width.</summary>
    private static SpriteFrames FramesFor(GDict spec)
    {
        string path = spec["sheet"].AsString();
        if (SfCache.TryGetValue(path, out var cached))
            return cached;
        var tex = GD.Load<Texture2D>(path);
        int hframes = spec.ContainsKey("hframes") ? spec["hframes"].As<int>() : 1;
        int fw = tex.GetWidth() / Mathf.Max(hframes, 1);
        int fh = tex.GetHeight();
        var sf = new SpriteFrames();
        sf.SetAnimationLoop("default", true);
        sf.SetAnimationSpeed("default", spec.ContainsKey("fps") ? spec["fps"].As<double>() : 10.0);
        for (int i = 0; i < hframes; i++)
        {
            var at = new AtlasTexture { Atlas = tex, Region = new Rect2(i * fw, 0, fw, fh) };
            sf.AddFrame("default", at);
        }
        SfCache[path] = sf;
        return sf;
    }
}
