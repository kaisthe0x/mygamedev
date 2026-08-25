using Godot;

namespace MyGame;

/// <summary>
/// A telegraphed AoE: the hitbox stays DISARMED for <see cref="telegraph_delay"/> seconds (a wind-up the
/// player can read + dodge), then arms + erupts. Extends <see cref="AoeStrike"/>. No scene uses it yet — the
/// type is ready for delayed ground attacks (today Ein's dive runs its own delay in code); verified by a unit
/// test that the box is off during the telegraph and on after.
/// </summary>
[GlobalClass]
public partial class TimedAoeStrike : AoeStrike
{
    /// <summary>Seconds the hitbox stays off before it arms (the telegraph window).</summary>
    [Export] public float telegraph_delay { get; set; } = 0.5f;

    public override void _Ready()
    {
        base._Ready();
        if (telegraph_delay > 0.0f && Box != null)
        {
            // The spawner arms every hitbox with a synchronous activate() right after apply_tuning; beat that
            // with a DEFERRED deactivate (runs after it, this frame), then arm once the telegraph elapses.
            // Method group, NOT a lambda: a capturing lambda connected to a SceneTreeTimer can be GC'd before
            // it fires; a method group keeps `this` alive.
            Box.CallDeferred("deactivate");
            GetTree().CreateTimer(telegraph_delay).Timeout += ArmHitbox;
        }
    }

    private void ArmHitbox()
    {
        if (IsInstanceValid(Box)) Box!.activate();
    }
}
