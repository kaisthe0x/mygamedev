using Godot;
using GDict = Godot.Collections.Dictionary;
using GArr = Godot.Collections.Array;

namespace MyGame;

/// <summary>
/// Khalid's ACTION catalog — PURE DATA (the <see cref="Actions"/> accessor turns these rows into typed
/// <see cref="Action"/> objects). One table per category; each row is an <see cref="Action.Make"/> dict.
/// C# port of <c>configs/actions_khalid.gd</c>. Presentation lives elsewhere, keyed by `animation`.
/// </summary>
public static class ActionsKhalid
{
    private const string Ember = "res://vfx/shared/textures/pixel_ember.png";
    private const string Blast1 = "res://vfx/shared/textures/blast1.png";
    private const string Bolt = "res://vfx/shared/impervious/bolt.png";
    private const string SoftDot = "res://vfx/shared/textures/soft_dot.png";
    private const string Shield = "res://vfx/shared/impervious/shield.png";

    public static readonly GDict ATTACKS = new()
    {
        { "ora_ora", new GDict
            {
                { "name", "Ora Ora" }, { "icon", Ember }, { "style", "flurry" },
                { "hit", new GDict { { "type", "melee" }, { "segments", new GDict { { "damage", 15 }, { "knockback", 0 }, { "stun", 0.1 }, { "extents", new Vector2(32, 22) } } } } },
            }
        },
        { "spear", new GDict
            {
                { "name", "Spear" }, { "icon", Blast1 }, { "tier", "elite" },
                { "hit", new GDict { { "type", "melee" }, { "segments", new GArr
                    {
                        new GDict { { "damage", 10 }, { "knockback", 40 } },
                        new GDict { { "damage", 20 }, { "knockback", 60 } },
                        new GDict { { "damage", 35 }, { "knockback", 140 } },
                    } } } },
            }
        },
        { "bakshen", new GDict
            {
                { "name", "Bakshen" }, { "icon", Bolt }, { "tier", "elite" }, { "style", "cooldown" }, { "cooldown", 3.0 },
                { "hit", new GDict { { "type", "melee" }, { "segments", new GDict { { "damage", 65 }, { "knockback", 0 }, { "stun", 0.0 } } } } },
            }
        },
        { "zahluq", new GDict
            {
                { "name", "Zahluq" }, { "icon", Bolt }, { "tier", "elite" }, { "style", "cooldown" }, { "cooldown", 3.0 }, { "tags", new GArr { "air" } },
                { "hit", new GDict { { "type", "melee" }, { "segments", new GDict
                    {
                        { "damage", 45 }, { "knockback", 90 }, { "stun", 0.2 },
                        { "lunge", 1100.0 }, { "hold", 0.4 }, { "super_armor", 0.4 }, { "extents", new Vector2(40, 28) },
                    } } } },
            }
        },
        { "cherry_shots", new GDict
            {
                { "name", "Cherry Shots" }, { "icon", SoftDot }, { "tier", "elite" },
                { "hit", new GDict { { "type", "projectile" }, { "segments", new GArr
                    {
                        new GDict { { "damage", 4 }, { "knockback", 0 } },
                        new GDict { { "damage", 7 }, { "knockback", 0 } },
                    } } } },
            }
        },
        { "twin_reaper", new GDict
            {
                { "name", "Twin Reaper" }, { "icon", Blast1 }, { "tier", "elite" }, { "style", "flurry" }, { "tags", new GArr { "reaper" } },
                { "hit", new GDict { { "type", "melee" }, { "segments", new GDict { { "damage", 12 }, { "knockback", 0 }, { "reap", 0.12 }, { "reap_time", 5.0 } } } } },
            }
        },
        { "dual_executioner", new GDict
            {
                { "name", "Dual Executioner" }, { "icon", Blast1 }, { "tier", "broken" }, { "style", "flurry" }, { "tags", new GArr { "reaper" } },
                { "hit", new GDict { { "type", "melee" }, { "segments", new GDict { { "damage", 22 }, { "knockback", 0 }, { "stun", 0.3 } } } } },
            }
        },
    };

    public static readonly GDict SPECIALS = new()
    {
        { "ground_breaker", new GDict
            {
                { "name", "Ground Breaker" }, { "icon", Blast1 },
                { "hit", new GDict { { "type", "aoe" }, { "segments", new GDict
                    {
                        { "damage", 40 }, { "knockback", 160 }, { "stun", 1.0 },
                        { "victim_effect", "res://vfx/character/khalid/status/ground_breaker_stun.tscn" },
                    } } } },
            }
        },
        { "frenemy", new GDict
            {
                { "name", "Frenemy" }, { "icon", Ember }, { "tier", "elite" }, { "tags", new GArr { "charm" } },
                { "hit", new GDict { { "type", "blast" }, { "segments", new GDict
                    {
                        { "damage", 4 }, { "knockback", 0 }, { "frenemy", 8.0 },
                        { "victim_effect", "res://vfx/character/khalid/status/frenemy_stun.tscn" }, { "victim_time", 8.0 },
                    } } } },
            }
        },
        { "come_closer", new GDict
            {
                { "name", "Come Closer" }, { "icon", Ember }, { "tags", new GArr { "control" } }, { "cooldown", 1.0 },
            }
        },
        { "redere_shield", new GDict
            {
                { "name", "Redere Shield" }, { "icon", Shield }, { "tier", "elite" }, { "tags", new GArr { "shield", "held" } },
            }
        },
        { "redere_frisbee", new GDict
            {
                { "name", "Redere Frisbee" }, { "icon", Blast1 }, { "tier", "broken" }, { "tags", new GArr { "shield" } },
                { "hit", new GDict { { "type", "projectile" }, { "segments", new GDict { { "damage", 15 }, { "knockback", 120 } } } } },
            }
        },
    };

    public static readonly GDict SURGES = new()
    {
        { "aegis", new GDict
            {
                { "name", "Aegis" }, { "icon", Shield }, { "tier", "typical" },
                { "surge", new GDict { { "duration", 5.0 }, { "invuln", true }, { "cost", 100.0 }, { "aura", "res://vfx/character/khalid/surge/aegis/surge_aegis.tscn" } } },
            }
        },
        { "jnoon", new GDict
            {
                { "name", "Jnoon" }, { "icon", Shield }, { "tier", "typical" },
                { "surge", new GDict { { "duration", 5.0 }, { "damage_mult", 2.0 }, { "damage_taken_mult", 0.5 }, { "cost", 100.0 }, { "aura", "res://vfx/character/khalid/surge/jnoon/surge_jnoon.tscn" } } },
            }
        },
        { "asra", new GDict
            {
                { "name", "Asra" }, { "icon", Shield }, { "tier", "typical" },
                { "surge", new GDict { { "duration", 5.0 }, { "speed_mult", 2.0 }, { "cost", 100.0 }, { "aura", "res://vfx/character/khalid/surge/asra/surge_asra.tscn" } } },
            }
        },
        { "nem", new GDict
            {
                { "name", "Nem" }, { "icon", Shield }, { "tier", "typical" },
                { "surge", new GDict { { "duration", 5.0 }, { "channel", true }, { "heal_frac", 0.5 }, { "cost", 200.0 }, { "aura", "res://vfx/character/khalid/surge/nem/surge_nem.tscn" } } },
            }
        },
        { "wara", new GDict
            {
                { "name", "Wara" }, { "icon", Shield }, { "tier", "typical" },
                { "surge", new GDict
                    {
                        { "trigger", "hit" }, { "stun_radius", 150.0 }, { "stun_time", 2.0 }, { "cost", 100.0 },
                        { "aura", "res://vfx/character/khalid/surge/wara/surge_wara.tscn" },
                        { "burst", "res://vfx/character/khalid/surge/wara/surge_wara_burst.tscn" },
                    } },
            }
        },
    };

    public static readonly GDict MOVEMENTS = new()
    {
        { "run", new GDict { { "standard_stride", new GDict { { "name", "Standard Stride" }, { "icon", Ember }, { "move", new GDict { { "run_speed", 230.0 } } } } } } },
        { "jump", new GDict { { "standard_leap", new GDict { { "name", "Standard Leap" }, { "icon", SoftDot }, { "move", new GDict { { "air_jumps", 1 } } } } } } },
        { "dash", new GDict { { "blink_dash", new GDict { { "name", "Blink Dash" }, { "icon", Bolt }, { "move", new GDict { { "blink", true } } } } } } },
        { "slam", new GDict { { "standard_slam", new GDict { { "name", "Standard Slam" }, { "icon", Blast1 }, { "move", new GDict() } } } } },
    };

    public const string DEFAULT_ATTACK = "bakshen";
    public const string DEFAULT_SPECIAL = "redere_frisbee";
    public const string DEFAULT_SURGE = "wara";
    public static readonly GDict DEFAULT_MOVEMENTS = new()
    {
        { "run", "standard_stride" }, { "jump", "standard_leap" }, { "dash", "blink_dash" }, { "slam", "standard_slam" },
    };
}
