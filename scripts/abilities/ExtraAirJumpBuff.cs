using Godot;

namespace MyGame;

/// <summary>
/// +N air jumps for the run — the catalog's Extra Air Jump (a threshold buff: no effect at Common). Setup bumps
/// the player's air-jump count by a per-tier amount; Teardown restores it on run restart. Built by
/// <see cref="BuffCatalog"/>.
/// </summary>
public partial class ExtraAirJumpBuff : Buff
{
    private readonly int[] _bonus;  // per-tier extra air jumps, indexed Common..Epic (Common = 0 = not offered)

    private int Amount => _bonus[Mathf.Clamp((int)Tier, 0, _bonus.Length - 1)];

    public ExtraAirJumpBuff(string id, int[] bonus)
    {
        Id = id;
        _bonus = bonus;
    }

    public override void Setup(Player p) => p.add_air_jumps(Amount);
    public override void Teardown(Player p) => p.add_air_jumps(-Amount);
}
