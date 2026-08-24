using Godot;
using GDict = Godot.Collections.Dictionary;
using GArr = Godot.Collections.Array;

namespace MyGame;

/// <summary>
/// The reward catalog — PURE DATA (the <see cref="Rewards"/> service turns these into <see cref="Reward"/>
/// objects, applies the build conditions, and runs the effects). <c>door_type → [reward dicts]</c>; each level
/// rolls ONE door type (RunManager), clearing the arena opens it, and the player picks one offered reward.
/// C# port of <c>configs/rewards_catalog.gd</c> — the rows keep the same shape (<see cref="Reward.Make"/> dicts).
/// Numbers are placeholders; the typed reward foundation (docs/rewards-design.md) supersedes these as the real
/// set lands.
/// </summary>
public static class RewardsCatalog
{
    public static readonly GDict POOLS = Build();

    // Terse reward-row builder: id/name/desc + an optional extras dict merged on top.
    private static GDict R(string id, string name, string desc, GDict extra = null)
    {
        var d = new GDict { { "id", id }, { "name", name }, { "desc", desc } };
        if (extra != null)
            foreach (var k in extra.Keys)
                d[k] = extra[k];
        return d;
    }

    private static GDict Build() => new()
    {
        ["health"] = new GArr
        {
            R("mend", "Mend", "Heal +40 HP now"),
            R("max_hp", "Second Skin", "+25 max HP (and heal it)"),
        },
        ["athletic"] = new GArr
        {
            R("air_jump", "Extra Wind", "+1 air jump"),
            R("run", "Fleetfoot", "+10% run speed"),
            R("tough", "Thick Hide", "-10% damage taken"),
            R("slam_dmg", "Meteor", "+25% slam damage"),
            R("crimson_vortex", "Crimson Vortex", "Your dash leaves a damaging vortex"),
        },
        ["attack"] = new GArr
        {
            // SYNERGY: a charm special equipped makes reach ~3x likelier to roll (still just a nudge).
            R("reach", "Long Arm", "+15% attack reach", new GDict
            {
                { "synergy", new GDict { { "when", new GDict { { "tag", "charm" } } }, { "weight", 3.0 } } },
            }),
            R("atk_dmg", "Bloodlust", "+12% attack damage"),
            R("lifesteal", "Leech", "Heal 8% of damage dealt", new GDict { { "passive", "leech" } }),
            R("multishot", "Split Shot", "+1 projectile (WIP)"),
            // PER-MOVE BUFF: +25% Twin Reaper only; offered once it's equipped; unique.
            R("reaper_edge", "Reaper's Edge", "+25% Twin Reaper damage", new GDict
            {
                { "unique", true },
                { "requires", new GDict { { "equipped", "twin_reaper" } } },
                { "passive", "reaper_edge" },
            }),
            // INDEPENDENT MOVE: a standalone attack you can swap to (upgrades via its own buffs).
            R("dual_executioner", "Dual Executioner", "A bigger, deadlier twin-blade spin", new GDict
            {
                { "icon", "res://vfx/shared/textures/blast1.png" },
                { "tier", "broken" },
                { "unique", true },
                { "equip", new GDict { { "category", "attack" }, { "id", "dual_executioner" } } },
            }),
        },
        ["special"] = new GArr
        {
            R("ruh_cap", "Deeper Ruh", "+1 Ruh charge (max 5)"),
            R("longer_imp", "Fortitude", "+3s Aegis (invuln) duration"),
            R("imp_until_hit", "Last Stand", "Aegis lasts until you're hit (WIP)"),
            R("bigger_blast", "Wide Impact", "+20% special hit radius (WIP)"),
            // PER-MOVE BUFF: a perfect parry with Redere Shield also heals; offered once it's equipped.
            R("parry_mend", "Guardian's Mend", "Perfect parry also heals you", new GDict
            {
                { "unique", true },
                { "requires", new GDict { { "equipped", "redere_shield" } } },
                { "passive", "parry_mend" },
            }),
        },
    };
}
