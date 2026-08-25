using Godot;

namespace MyGame;

/// <summary>
/// A glowing "soul" that pops off a dying enemy and floats to the player — the visual receipt for a Ruh pickup.
/// It flies a CURVED (quadratic Bezier) path bowed by <see cref="arc_height"/>, always arriving at the end of
/// <see cref="flight_time"/> (unless the player is gone). On contact it shrinks into the chest + fires the absorb
/// reaction. C# port of <c>vfx/script/ruh_orb.gd</c>. RunManager instantiates the scene + calls <see cref="launch"/>.
/// </summary>
public partial class RuhOrb : Node2D
{
    private enum Phase { Fly, Absorb }

    private Node2D _target = null;
    private bool _completedCharge;
    private Vector2 _p0 = Vector2.Zero;
    private float _t = 0.0f;
    private Phase _phase = Phase.Fly;

    [Export] public float flight_time { get; set; } = 1.1f;
    [Export] public float arc_height { get; set; } = 90.0f;
    [Export] public Vector2 target_offset { get; set; } = new(0, -18);
    [Export] public float absorb_time { get; set; } = 0.12f;

    /// <summary>Send this orb curving toward `target` (the player). `completedCharge` = the soul that topped off a full charge.</summary>
    public void launch(Node2D target, bool completedCharge)
    {
        _target = target;
        _completedCharge = completedCharge;
        _p0 = GlobalPosition;
        _t = 0.0f;
        _phase = Phase.Fly;
    }

    public override void _Process(double delta)
    {
        if (_phase == Phase.Absorb)
            return; // the absorb tween owns motion + its own free
        if (_target == null || !IsInstanceValid(_target))
        {
            QueueFree();
            return;
        }

        Vector2 dest = _target.GlobalPosition + target_offset;
        _t += (float)delta / Mathf.Max(flight_time, 0.01f);
        if (_t >= 1.0f)
        {
            GlobalPosition = dest;
            Absorb(dest);
            return;
        }

        // Quadratic Bezier p0 -> control -> dest, the control bowed perpendicular (upward-biased) by arc_height.
        Vector2 mid = _p0.Lerp(dest, 0.5f);
        Vector2 line = dest - _p0;
        Vector2 perp = new Vector2(-line.Y, line.X).Normalized(); // 90deg; zero-safe if line ~ 0
        if (perp.Y > 0.0f)
            perp = -perp; // bow upward
        Vector2 control = mid + perp * arc_height;
        GlobalPosition = Bezier(_p0, control, dest, _t);
    }

    private static Vector2 Bezier(Vector2 a, Vector2 b, Vector2 c, float t)
    {
        float u = 1.0f - t;
        return u * u * a + 2.0f * u * t * b + t * t * c;
    }

    /// <summary>The pickup beat: fire the player's absorb reaction, then shrink the orb into the chest + free.</summary>
    private void Absorb(Vector2 dest)
    {
        _phase = Phase.Absorb;
        if (_target != null && IsInstanceValid(_target) && _target.HasMethod("on_ruh_absorbed"))
            _target.Call("on_ruh_absorbed", _completedCharge);
        var tw = CreateTween();
        tw.SetParallel(true);
        tw.TweenProperty(this, "global_position", dest, absorb_time);
        tw.TweenProperty(this, "scale", Vector2.Zero, absorb_time).SetEase(Tween.EaseType.In);
        tw.Chain().TweenCallback(Callable.From(QueueFree));
    }
}
