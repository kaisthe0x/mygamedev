using Godot;

namespace MyGame;

/// <summary>
/// Reward-granted passive (the "Leech" attack reward): heal a fraction of the damage the player deals, via the
/// <see cref="Passive.OnHitDealt"/> hook. Taking it again stacks (each grant is its own instance). The worked
/// example of a behavioural ability that arrives as a reward. C# port of <c>scripts/abilities/leech.gd</c>.
/// [GlobalClass] so the GDScript Rewards service can <c>Leech.new()</c> it by name.
/// </summary>
[GlobalClass]
public partial class Leech : Passive
{
    private const float Fraction = 0.08f;

    public Leech() => Id = "leech";

    public override void OnHitDealt(Player player, float amount, Node target)
    {
        if (amount > 0.0f)
            player.heal(amount * Fraction);
    }
}
