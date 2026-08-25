using Godot;
using GDict = Godot.Collections.Dictionary;

namespace MyGame;

/// <summary>
/// The enemy roster — one named kit per enemy TYPE, referenced by the level/wave tables in <see cref="Levels"/>.
/// A kit is a spawn spec: an `id` (built from scenes/enemy.tscn) or a custom `scene`, plus Enemy @export overrides
/// (combat tuning), applied by RunManager via <c>enemy.Set(key, value)</c> — so a kit stays a by-name override BAG
/// (its keys mirror Enemy's [Export] names), not a fixed record. `tier` (<see cref="EnemyTier"/>) is advisory
/// wave-building shorthand (RunManager skips it). IDs use <see cref="EnemyIds"/>; attack_type uses the
/// <see cref="StrikeType"/> taxonomy. C# port of <c>scripts/run/enemies.gd</c> (pure data).
/// </summary>
public static class EnemyKits
{
    public static readonly GDict KEBUS = new()
    {
        { "id", EnemyIds.Kebus }, { "tier", (int)EnemyTier.Strong },
        { "ranged_mode", "forward" }, { "ranged_hitbox_extents", new Vector2(7, 10) },
        { "ranged_travel", 180.0 }, { "projectile_speed", 200.0 },
    };

    public static readonly GDict BAGHEL = new()
    {
        { "id", EnemyIds.Baghel }, { "tier", (int)EnemyTier.Chip },
        { "ranged_mode", "forward" }, { "ranged_range", 130.0 }, { "ranged_travel", 100.0 }, { "projectile_speed", 200.0 },
        { "ranged_hitbox_extents", new Vector2(4, 15) }, { "ranged_hitbox_offset", new Vector2(0, -9) }, { "ranged_damage", 7.0 },
        { "idle_time_min", 5.0 }, { "idle_time_max", 7.0 },
    };

    public static readonly GDict MAZAB = new()
    {
        { "id", EnemyIds.Mazab }, { "tier", (int)EnemyTier.Mid }, { "attack_type", StrikeType.DelayedProjectile.Key() },
        { "ranged_mode", "lob" }, { "ranged_range", 260.0 }, { "attack_align_y", 120.0 }, { "attack_cooldown", 2.2 },
        { "ranged_damage", 16.0 }, { "ranged_knockback", 160.0 }, { "ranged_stun", 0.25 },
        { "lob_arc_time", 0.9 }, { "lob_dwell", 1.0 }, { "lob_explosion_extents", new Vector2(48, 26) },
    };

    public static readonly GDict NASEN = new()
    {
        { "scene", "res://scenes/sleeper_enemy.tscn" }, { "id", EnemyIds.Nasen }, { "display_name", "Nasen" },
        { "max_health", 90.0 }, { "tier", (int)EnemyTier.Strong }, { "optional", true }, { "attack_type", StrikeType.Aoe.Key() },
    };

    public static readonly GDict EIN = new()
    {
        { "scene", "res://scenes/diver_enemy.tscn" }, { "id", EnemyIds.Ein }, { "display_name", "Ein" }, { "max_health", 28.0 },
        { "body_size", new Vector2(22, 22) }, { "hurtbox_size", new Vector2(26, 26) }, { "move_speed", 34.0 },
        { "patrol_distance", 70.0 }, { "tier", (int)EnemyTier.Mid },
    };

    public static readonly GDict MATAT = new()
    {
        { "id", EnemyIds.Matat }, { "display_name", "Matat" }, { "tier", (int)EnemyTier.Strong }, { "attack_type", StrikeType.Aoe.Key() },
        { "max_health", 95.0 }, { "body_size", new Vector2(20, 34) }, { "hurtbox_size", new Vector2(24, 40) },
        { "move_speed", 40.0 }, { "patrol_distance", 90.0 }, { "ranged_range", 300.0 },
        { "melee_range", 52.0 }, { "attack_align_y", 44.0 }, { "attack_cooldown", 1.2 },
        { "attack_loops", true }, { "attack_hitstop", 0.0 },
        { "melee_damage", 11.0 }, { "melee_knockback", 150.0 }, { "melee_stun", 0.25 },
        { "melee_hitbox_x", 0.0 }, { "melee_hitbox_extents", new Vector2(46, 30) }, { "melee_strike_lifetime", 0.35 },
    };

    public static readonly GDict TARRI = new()
    {
        { "id", EnemyIds.Tarri }, { "display_name", "Tarri" }, { "tier", (int)EnemyTier.Mid }, { "attack_type", StrikeType.Blast.Key() },
        { "max_health", 70.0 }, { "body_size", new Vector2(18, 24) }, { "hurtbox_size", new Vector2(22, 28) },
        { "move_speed", 34.0 }, { "patrol_distance", 100.0 },
        { "melee_range", 140.0 }, { "attack_align_y", 52.0 }, { "attack_cooldown", 2.6 },
        { "melee_hitbox_x", 70.0 }, { "melee_hitbox_extents", new Vector2(70, 22) }, { "melee_strike_lifetime", 2.0 },
        { "melee_damage", 16.0 }, { "melee_knockback", 120.0 }, { "melee_stun", 0.3 },
        { "attack_hitstop", 2.0 }, { "attack_shake", 1.5 },
    };

    public static readonly GDict BRESKI = new()
    {
        { "id", EnemyIds.Breski }, { "display_name", "Breski" }, { "tier", (int)EnemyTier.Strong }, { "attack_type", StrikeType.Melee.Key() },
        { "max_health", 110.0 }, { "body_size", new Vector2(18, 28) }, { "hurtbox_size", new Vector2(22, 34) },
        { "move_speed", 46.0 }, { "patrol_distance", 90.0 },
        { "melee_range", 56.0 }, { "attack_align_y", 44.0 }, { "attack_cooldown", 1.8 },
        { "melee_damage", 10.0 }, { "melee_knockback", 130.0 }, { "melee_stun", 0.2 },
        { "attack_hitstop", 0.12 }, { "attack_shake", 1.0 },
    };
}
