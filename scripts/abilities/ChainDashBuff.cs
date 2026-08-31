using Godot;

namespace MyGame;

/// <summary>
/// Chain Dash: on every dash, zero the dash cooldown so the follow-up dash is free. MINIMAL build — the catalog's
/// per-tier riders (+N re-dashes, timed windows, "unlimited for 2 s") are NOT modelled yet, so every tier currently
/// grants an uncapped re-dash. Built by <see cref="BuffCatalog"/>.
/// TODO(chain_dash): cap re-dashes per airtime + add the tiered count/window riders once a dash-charge model exists.
/// </summary>
public partial class ChainDashBuff : Buff
{
    public ChainDashBuff(string id)
    {
        Id = id;
        Trigger = Trigger.OnDash;
    }

    public override void OnDash(Player p) => p.reset_dash_cooldown();
}
