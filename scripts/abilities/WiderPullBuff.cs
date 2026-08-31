using Godot;

namespace MyGame;

/// <summary>
/// Wider Pull (Come Closer): the special's magnet grabs a per-tier number of EXTRA enemies. <see cref="Setup"/>
/// bumps <c>Player.magnet_target_bonus</c> (read by <see cref="MagnetField"/> on spawn), <see cref="Teardown"/>
/// restores it. Offer-gated to the come_closer special (<see cref="Buff.AppliesTo"/>). Built by <see cref="BuffCatalog"/>.
/// </summary>
public partial class WiderPullBuff : Buff
{
    private readonly int[] _bonus;  // per-tier extra magnet targets, indexed Common..Epic

    private int Amount => _bonus[Mathf.Clamp((int)Tier, 0, _bonus.Length - 1)];

    public WiderPullBuff(string id, int[] bonus)
    {
        Id = id;
        _bonus = bonus;
    }

    public override void Setup(Player p) => p.magnet_target_bonus += Amount;
    public override void Teardown(Player p) => p.magnet_target_bonus -= Amount;
}
