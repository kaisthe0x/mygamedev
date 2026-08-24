using Godot;

namespace MyGame;

/// <summary>
/// The level exit — a REWARD DOOR the player walks into to leave. It only DETECTS the player and reports
/// contact (<c>touched</c>); RunManager owns the transition. Built entirely in code. Each level's door has a
/// random TYPE (health/athletic/attack/special) shown by its icon + label; LOCKED (red) until the arena is
/// CLEARED, then it OPENS. C# port of <c>scripts/run/exit_gate.gd</c>.
/// </summary>
[GlobalClass]
public partial class ExitGate : Area2D
{
    [Signal] public delegate void touchedEventHandler();

    private static readonly Vector2 Size = new(44, 96);

    public string door_type = "health";

    private ColorRect _fill;
    private TextureRect _icon;
    private Label _label;
    private bool _open;

    private static bool Known(string t) => t is "health" or "athletic" or "attack" or "special";

    // door type -> (label, accent colour).
    private static (string Label, Color Color) Info(string t) => t switch
    {
        "athletic" => ("ATHLETIC", new Color(0.45f, 0.75f, 1.0f)),
        "attack" => ("ATTACK", new Color(1.0f, 0.55f, 0.35f)),
        "special" => ("SPECIAL", new Color(0.9f, 0.5f, 1.0f)),
        _ => ("HEALTH", new Color(0.35f, 0.85f, 0.45f)),
    };

    public void Setup(string type)
    {
        door_type = Known(type) ? type : "health";
        CollisionLayer = 0;
        CollisionMask = (uint)Combat.Layer.PlayerBody; // detect the player's body
        AddChild(new CollisionShape2D
        {
            Shape = new RectangleShape2D { Size = Size },
            Position = new Vector2(0, -Size.Y / 2.0f),
        });

        _fill = new ColorRect
        {
            Size = Size,
            Position = new Vector2(-Size.X / 2.0f, -Size.Y),
            Color = new Color(0.7f, 0.2f, 0.2f, 0.5f), // locked (red) until cleared
        };
        AddChild(_fill);

        _icon = new TextureRect
        {
            Texture = Icons.Door(door_type),
            ExpandMode = TextureRect.ExpandModeEnum.IgnoreSize,
            StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered,
            Size = new Vector2(36, 36),
            Position = new Vector2(-18, -Size.Y / 2.0f - 18),
        };
        AddChild(_icon);

        var (label, _) = Info(door_type);
        _label = new Label
        {
            HorizontalAlignment = HorizontalAlignment.Center,
            Position = new Vector2(-70, -Size.Y - 26),
            Size = new Vector2(140, 20),
            Text = $"{label} · LOCKED",
        };
        _label.AddThemeFontSizeOverride("font_size", 13);
        _label.AddThemeColorOverride("font_color", new Color(1, 0.6f, 0.6f));
        AddChild(_label);

        BodyEntered += OnBodyEntered;
    }

    private void OnBodyEntered(Node body) => EmitSignal(SignalName.touched);

    /// <summary>Open (cleared) → the type's accent colour + label; locked → red + "… · LOCKED". Called each frame.</summary>
    public void Reflect(bool open)
    {
        if (open == _open)
            return;
        _open = open;
        var (label, accent) = Info(door_type);
        _fill.Color = open ? new Color(accent.R, accent.G, accent.B, 0.5f) : new Color(0.7f, 0.2f, 0.2f, 0.5f);
        _label.Text = open ? label : $"{label} · LOCKED";
        _label.AddThemeColorOverride("font_color", open ? accent : new Color(1, 0.6f, 0.6f));
    }
}
