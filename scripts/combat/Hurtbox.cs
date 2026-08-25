using Godot;

namespace MyGame;

/// <summary>
/// A region that RECEIVES hits. It doesn't scan for anything; opposing Hitboxes scan for it (their mask
/// includes this box's layer). On a hit it just relays the <see cref="Hit"/> via a signal — the owning body
/// decides what to do. C# port of <c>scripts/combat/hurtbox.gd</c>.
///
/// Set <c>CollisionLayer</c> to the team's hurt layer (Combat.*Hurt) and leave <c>CollisionMask</c> at 0;
/// <c>Monitorable</c> must stay true (default) so hitboxes see it. Public surface kept <c>snake_case</c>
/// (<c>take_hit</c>, <c>hurt</c>) for the still-GDScript owners until they're ported (see Hitbox.cs note).
/// </summary>
[GlobalClass]
public partial class Hurtbox : Area2D
{
    [Signal]
    public delegate void hurtEventHandler(Hit hit);

    public void take_hit(Hit hit) => EmitSignal(SignalName.hurt, hit);
}
