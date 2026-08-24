using Godot;
using GDict = Godot.Collections.Dictionary;

namespace MyGame;

/// <summary>
/// A global floating-text emitter (Risk of Rain style): pops a label above a host and floats it up, then frees
/// itself. ONE call does it: <see cref="Emit"/>. The LOOK + the in/out transition come entirely from the TYPE
/// preset (<c>configs/floating_text_types.gd</c>), so damage numbers and a "perfect!" callout animate differently
/// with zero code change. Parented to the host and animated in its LOCAL space (rides a moving enemy, immune to
/// the camera). C# port of <c>scripts/combat/floating_text.gd</c>; only C# emits it (plain class).
/// </summary>
public partial class FloatingText : Node2D
{
    private static readonly Vector2 Box = new(220, 60);

    private float _elapsed = 0.0f;
    private Vector2 _start = Vector2.Zero;
    private Vector2 _targetPos = Vector2.Zero;
    private float _life = 0.8f;
    private float _hold = 0.4f;
    private float _popScale = 0.7f;
    private float _popTime = 0.14f;
    private bool _fadeIn = false;

    /// <summary>Emit a `type` label reading `text` at `localPos` on `host` (parented to it). `magnitude` drives the
    /// size/colour ramp; `overrides` patches the preset for THIS call (e.g. a fixed colour). No-op on unknown type.</summary>
    public static void Emit(string type, Node2D host, Vector2 localPos, string text, float magnitude = 0.0f, GDict overrides = null)
    {
        var cfg = FloatingTextTypes.TYPES.ContainsKey(type) ? FloatingTextTypes.TYPES[type].As<GDict>() : new GDict();
        if (cfg.Count == 0)
        {
            GD.PushWarning($"FloatingText: unknown type '{type}'");
            return;
        }
        if (overrides != null && overrides.Count > 0)
        {
            cfg = (GDict)cfg.Duplicate();
            cfg.Merge(overrides, true); // per-call overrides win
        }
        var n = new FloatingText();
        host.AddChild(n);
        n.SetupText(cfg, localPos, text, magnitude);
    }

    private static float F(GDict c, string k, float def) => c.ContainsKey(k) ? c[k].As<float>() : def;
    private static Color Col(GDict c, string k, Color def) => c.ContainsKey(k) ? c[k].As<Color>() : def;
    private static bool B(GDict c, string k, bool def) => c.ContainsKey(k) ? c[k].As<bool>() : def;

    private void SetupText(GDict cfg, Vector2 localPos, string text, float magnitude)
    {
        float f = 0.0f;
        if (cfg.ContainsKey("mag_lo"))
        {
            float lo = F(cfg, "mag_lo", 0.0f);
            float hi = F(cfg, "mag_hi", lo + 1.0f);
            f = Mathf.Clamp(hi > lo ? (magnitude - lo) / (hi - lo) : 0.0f, 0.0f, 1.0f);
        }
        int size = cfg.ContainsKey("size")
            ? cfg["size"].As<int>()
            : Mathf.RoundToInt(Mathf.Lerp(F(cfg, "size_lo", 18), F(cfg, "size_hi", 18), f));
        Color col = cfg.ContainsKey("color")
            ? cfg["color"].As<Color>()
            : Col(cfg, "color_lo", Colors.White).Lerp(Col(cfg, "color_hi", Colors.White), f);

        var label = new Label
        {
            Text = text,
            Size = Box,
            Position = -Box * 0.5f,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
        };
        label.AddThemeFontSizeOverride("font_size", size);
        label.AddThemeColorOverride("font_color", col);
        label.AddThemeColorOverride("font_outline_color", Col(cfg, "outline_color", new Color(0, 0, 0, 0.85f)));
        label.AddThemeConstantOverride("outline_size", cfg.ContainsKey("outline_size") ? cfg["outline_size"].As<int>() : 5);
        string fontPath = cfg.ContainsKey("font") ? cfg["font"].AsString() : "";
        if (fontPath != "" && ResourceLoader.Exists(fontPath))
            label.AddThemeFontOverride("font", GD.Load<Font>(fontPath));
        AddChild(label);

        // Fake ITALIC: a Label has no italic flag, so slant the whole node (shear).
        if (B(cfg, "italic", false))
            Skew = Mathf.DegToRad(F(cfg, "italic_deg", 12.0f));

        _life = F(cfg, "life", 0.8f);
        _hold = F(cfg, "hold", 0.4f);
        _popScale = F(cfg, "pop_scale", 0.7f);
        _popTime = Mathf.Max(F(cfg, "pop_time", 0.14f), 0.001f);
        _fadeIn = B(cfg, "fade_in", false);
        float jitter = F(cfg, "jitter", 8.0f);
        Position = localPos + new Vector2((float)GD.RandRange(-jitter, jitter), (float)GD.RandRange(-jitter, jitter) * 0.5f);
        _start = Position;
        float drift = F(cfg, "drift", 12.0f);
        _targetPos = _start + new Vector2((float)GD.RandRange(-drift, drift), -F(cfg, "rise", 26.0f));
        Scale = new Vector2(_popScale, _popScale);
    }

    public override void _Process(double delta)
    {
        _elapsed += (float)delta;
        float u = _elapsed / _life;
        if (u >= 1.0f)
        {
            QueueFree();
            return;
        }
        float easeOut = 1.0f - (1.0f - u) * (1.0f - u);
        Position = _start.Lerp(_targetPos, easeOut);
        Scale = Vector2.One * Mathf.Min(_popScale + (1.0f - _popScale) * (_elapsed / _popTime), 1.0f);
        var m = Modulate;
        if (_fadeIn && _elapsed < _popTime)
            m.A = _elapsed / _popTime;
        else if (u > _hold)
            m.A = Mathf.Clamp(1.0f - (u - _hold) / (1.0f - _hold), 0.0f, 1.0f);
        else
            m.A = 1.0f;
        Modulate = m;
    }
}
