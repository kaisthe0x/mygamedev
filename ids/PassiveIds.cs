namespace MyGame;

/// <summary>
/// Stable string IDs for reward-granted Passives — the value ties three places together: the passive's own
/// <c>Id</c> (its ctor), the <c>Rewards.MakePassive</c> dispatch, and the <c>passive</c> field of a catalog reward.
/// `const string` (see <see cref="AttackIds"/>).
/// </summary>
public static class PassiveIds
{
    public const string Leech = "leech";
    public const string ReaperEdge = "reaper_edge";
    public const string ParryMend = "parry_mend";
}
