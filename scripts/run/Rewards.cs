using Godot;
using System.Collections.Generic;
using GDict = Godot.Collections.Dictionary;
using GArr = Godot.Collections.Array;

namespace MyGame;

/// <summary>
/// Reward OFFER + EFFECT logic over the typed catalog (<see cref="RewardsCatalog"/> / <see cref="Reward"/>) —
/// build-aware. C# port of <c>scripts/run/rewards.gd</c>. <c>[GlobalClass]</c> with INSTANCE methods so the
/// still-GDScript RunManager calls it via <c>Rewards.new().offer_for(...)</c> until it ports too (5b);
/// afterwards a C# caller uses <c>new Rewards()</c> just the same.
///
/// Door types: HEALTH / ATHLETIC / ATTACK / SPECIAL. The SPECIAL door also mixes in CHANGE-SPECIAL swap cards.
/// Effects are one of: equip a move (upgrade), grant a <see cref="Passive"/> (ability), or a stat buff keyed by id.
/// </summary>
[GlobalClass]
public partial class Rewards : RefCounted
{
    /// <summary>`n` rewards for a `door_type`, build-aware (requires + unique gates), sampled weighted by synergy.
    /// The SPECIAL door also mixes in change-special swap cards. Returns an array of card dicts for RewardUI.</summary>
    public GArr offer_for(string doorType, Player player, int n)
    {
        var build = Build.Of(player);
        var weighted = new List<(GDict card, float weight)>();
        if (RewardsCatalog.POOLS.ContainsKey(doorType))
            foreach (Variant dv in RewardsCatalog.POOLS[doorType].As<GArr>())
            {
                var r = Reward.Make(doorType, dv.As<GDict>());
                if (r.Offerable(build))
                    weighted.Add((r.ToCard(), r.Weight(build)));
            }
        if (doorType == "special" && player != null)
            foreach (Variant cv in player.loadout_choices())
            {
                var choice = cv.As<GDict>();
                if (choice["category"].AsString() != "special")
                    continue;
                var o = choice["option"].As<GDict>();
                string tierLbl = Loadout.TierLabel(o["tier"].AsString());
                weighted.Add((new GDict
                {
                    { "id", $"swap:special:{o["id"].AsString()}" },
                    { "name", o["name"] },
                    { "desc", $"Change special · {tierLbl}" },
                    { "tier", o["tier"] },
                    { "icon", o["icon"] },
                }, 1.0f));
            }
        return Sample(weighted, n);
    }

    /// <summary>Sample up to `n` cards from the weighted list WITHOUT replacement (roulette).</summary>
    private static GArr Sample(List<(GDict card, float weight)> entries, int n)
    {
        var pool = new List<(GDict card, float weight)>(entries);
        var outArr = new GArr();
        while (pool.Count > 0 && outArr.Count < n)
        {
            float total = 0.0f;
            foreach (var e in pool)
                total += e.weight;
            float pick = GD.Randf() * total;
            int idx = 0;
            for (int i = 0; i < pool.Count; i++)
            {
                pick -= pool[i].weight;
                if (pick <= 0.0f)
                {
                    idx = i;
                    break;
                }
            }
            outArr.Add(pool[idx].card);
            pool.RemoveAt(idx);
        }
        return outArr;
    }

    /// <summary>Apply reward `id` to the player — the single place a reward's EFFECT lives. Records it on the build.</summary>
    public void apply(string id, Player player)
    {
        if (id.StartsWith("swap:"))
        {
            var parts = id.Split(':'); // swap:<category>:<option_id>
            if (parts.Length == 3)
                player.equip(parts[1], parts[2]);
            player.record_reward(id);
            return;
        }
        var r = Find(id);
        if (r == null)
        {
            GD.PushWarning($"Rewards: unknown reward id '{id}'");
            return;
        }
        player.record_reward(id);
        if (r.Equip.Count > 0) // a move swap / upgrade
        {
            player.equip(r.Equip["category"].AsString(), r.Equip["id"].AsString());
            return;
        }
        if (r.Passive != "") // a behavioural passive (ability)
        {
            var p = MakePassive(r.Passive);
            if (p != null)
                player.add_passive(p);
            return;
        }
        Buff(id, player); // a stat buff
    }

    /// <summary>The Reward with this id, searching every door pool (null if none).</summary>
    private static Reward Find(string id)
    {
        foreach (var door in RewardsCatalog.POOLS.Keys)
            foreach (Variant dv in RewardsCatalog.POOLS[door].As<GArr>())
            {
                var d = dv.As<GDict>();
                if (d["id"].AsString() == id)
                    return Reward.Make(door.AsString(), d);
            }
        return null;
    }

    /// <summary>Instantiate a reward-granted Passive by id — the C# passives directly (no load-path bridge).</summary>
    private static Passive MakePassive(string passiveId) => passiveId switch
    {
        "leech" => new Leech(),
        "parry_mend" => new ParryMend(),
        "reaper_edge" => new ReaperEdge(),
        _ => Warn(passiveId),
    };

    private static Passive Warn(string id)
    {
        GD.PushWarning($"Rewards: no Passive for '{id}'");
        return null;
    }

    /// <summary>Stat-buff effects, keyed by reward id (the ones that just tweak a Player stat).</summary>
    private static void Buff(string id, Player player)
    {
        switch (id)
        {
            // health
            case "mend": player.heal(40.0f); break;
            case "max_hp": player.max_health += 25.0f; player.heal(25.0f); break;
            // athletic
            case "air_jump": player.air_jump_bonus += 1; player.equip("jump", player.loadout_id("jump")); break;
            case "run": player.run_mult *= 1.1f; player.equip("run", player.loadout_id("run")); break;
            case "tough": player.damage_taken_mult *= 0.9f; break;
            case "slam_dmg": player.slam_damage_mult *= 1.25f; break;
            case "crimson_vortex": player.set_dash_effect("dash_crimson_vortex"); break;
            // attack
            case "reach": player.attack_reach_mult *= 1.15f; break;
            case "atk_dmg": player.damage_mult += 0.12f; break;
            case "multishot": player.attack_projectile_bonus += 1; break;
            // special
            case "ruh_cap": player.ruh_cap += player.RUH_PER_BLOCK; break;
            case "longer_imp": player.special_invuln_bonus += 3.0f; break;
            case "imp_until_hit": player.impervious_until_hit = true; break;
            case "bigger_blast": player.special_radius_mult *= 1.2f; break;
            default: GD.PushWarning($"Rewards: unhandled buff id '{id}'"); break;
        }
    }
}
