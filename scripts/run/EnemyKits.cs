using Godot;
using GDict = Godot.Collections.Dictionary;

namespace MyGame;

/// <summary>
/// The enemy roster — one named kit per enemy TYPE, referenced by the level/wave tables in <see cref="Levels"/>.
/// A kit is a spawn spec: an `id` (built from scenes/enemy.tscn) or a custom `scene`, plus Enemy @export overrides
/// (combat tuning). `tier` (CHIP/MID/STRONG, advisory) is design shorthand for wave-building. C# port of
/// <c>scripts/run/enemies.gd</c> (pure data). RunManager applies a kit via <c>enemy.Set(key, value)</c>, skipping
/// scene/tier/pos.
/// </summary>
public static class EnemyKits
{
    public enum Tier { CHIP, MID, STRONG }

    public static readonly GDict KEBUS = new()
    {
        { "id", "kebus" }, { "tier", (int)Tier.STRONG },
        { "ranged_mode", "forward" }, { "ranged_hitbox_extents", new Vector2(7, 10) },
        { "ranged_travel", 180.0 }, { "projectile_speed", 200.0 },
    };

    public static readonly GDict BAGHEL = new()
    {
        { "id", "baghel" }, { "tier", (int)Tier.CHIP },
        { "ranged_mode", "forward" }, { "ranged_range", 130.0 }, { "ranged_travel", 100.0 }, { "projectile_speed", 200.0 },
        { "ranged_hitbox_extents", new Vector2(4, 15) }, { "ranged_hitbox_offset", new Vector2(0, -9) }, { "ranged_damage", 7.0 },
        { "idle_time_min", 5.0 }, { "idle_time_max", 7.0 },
    };

    public static readonly GDict MAZAB = new()
    {
        { "id", "mazab" }, { "tier", (int)Tier.MID }, { "attack_type", "delayed_projectile" },
        { "ranged_mode", "lob" }, { "ranged_range", 260.0 }, { "attack_align_y", 120.0 }, { "attack_cooldown", 2.2 },
        { "ranged_damage", 16.0 }, { "ranged_knockback", 160.0 }, { "ranged_stun", 0.25 },
        { "lob_arc_time", 0.9 }, { "lob_dwell", 1.0 }, { "lob_explosion_extents", new Vector2(48, 26) },
    };

    public static readonly GDict NASEN = new()
    {
        { "scene", "res://scenes/sleeper_enemy.tscn" }, { "id", "nasen" }, { "display_name", "Nasen" },
        { "max_health", 90.0 }, { "tier", (int)Tier.STRONG }, { "optional", true }, { "attack_type", "aoe" },
    };

    public static readonly GDict EIN = new()
    {
        { "scene", "res://scenes/diver_enemy.tscn" }, { "id", "ein" }, { "display_name", "Ein" }, { "max_health", 28.0 },
        { "body_size", new Vector2(22, 22) }, { "hurtbox_size", new Vector2(26, 26) }, { "move_speed", 34.0 },
        { "patrol_distance", 70.0 }, { "tier", (int)Tier.MID },
    };

    public static readonly GDict MATAT = new()
    {
        { "id", "matat" }, { "display_name", "Matat" }, { "tier", (int)Tier.STRONG }, { "attack_type", "aoe" },
        { "max_health", 95.0 }, { "body_size", new Vector2(20, 34) }, { "hurtbox_size", new Vector2(24, 40) },
        { "move_speed", 40.0 }, { "patrol_distance", 90.0 }, { "ranged_range", 300.0 },
        { "melee_range", 52.0 }, { "attack_align_y", 44.0 }, { "attack_cooldown", 1.2 },
        { "attack_loops", true }, { "attack_hitstop", 0.0 },
        { "melee_damage", 11.0 }, { "melee_knockback", 150.0 }, { "melee_stun", 0.25 },
        { "melee_hitbox_x", 0.0 }, { "melee_hitbox_extents", new Vector2(46, 30) }, { "melee_strike_lifetime", 0.35 },
    };

    public static readonly GDict TARRI = new()
    {
        { "id", "tarri" }, { "display_name", "Tarri" }, { "tier", (int)Tier.MID }, { "attack_type", "blast" },
        { "max_health", 70.0 }, { "body_size", new Vector2(18, 24) }, { "hurtbox_size", new Vector2(22, 28) },
        { "move_speed", 34.0 }, { "patrol_distance", 100.0 },
        { "melee_range", 140.0 }, { "attack_align_y", 52.0 }, { "attack_cooldown", 2.6 },
        { "melee_hitbox_x", 70.0 }, { "melee_hitbox_extents", new Vector2(70, 22) }, { "melee_strike_lifetime", 2.0 },
        { "melee_damage", 16.0 }, { "melee_knockback", 120.0 }, { "melee_stun", 0.3 },
        { "attack_hitstop", 2.0 }, { "attack_shake", 1.5 },
    };

    public static readonly GDict BRESKI = new()
    {
        { "id", "breski" }, { "display_name", "Breski" }, { "tier", (int)Tier.STRONG }, { "attack_type", "melee" },
        { "max_health", 110.0 }, { "body_size", new Vector2(18, 28) }, { "hurtbox_size", new Vector2(22, 34) },
        { "move_speed", 46.0 }, { "patrol_distance", 90.0 },
        { "melee_range", 56.0 }, { "attack_align_y", 44.0 }, { "attack_cooldown", 1.8 },
        { "melee_damage", 10.0 }, { "melee_knockback", 130.0 }, { "melee_stun", 0.2 },
        { "attack_hitstop", 0.12 }, { "attack_shake", 1.0 },
    };
}
