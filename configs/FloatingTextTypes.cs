using Godot;
using GDict = Godot.Collections.Dictionary;

namespace MyGame;

/// <summary>
/// Presets for <see cref="FloatingText.Emit"/> — PURE DATA, one entry per label TYPE (its look + in/out
/// transition). Every key is optional (FloatingText fills defaults). C# port of <c>configs/floating_text_types.gd</c>.
/// </summary>
public static class FloatingTextTypes
{
    private const string Font = "res://assets/fonts/Sixtyfour-Regular-VariableFont_BLED,SCAN.ttf";

    public static readonly GDict TYPES = new()
    {
        // Damage numbers: small white light hits -> big hot-gold heavy hits (ramped by `magnitude`).
        { "damage", new GDict
            {
                { "font", Font },
                { "size_lo", 6 }, { "size_hi", 8 }, { "mag_lo", 8.0 }, { "mag_hi", 45.0 },
                { "color_lo", new Color(1, 1, 1) }, { "color_hi", new Color(1.4f, 0.55f, 0.15f) },
                { "outline_color", new Color(0, 0, 0, 0.85f) }, { "outline_size", 5 },
                { "rise", 26.0 }, { "drift", 12.0 }, { "jitter", 8.0 }, { "life", 0.8 },
                { "pop_scale", 0.7 }, { "pop_time", 0.14 }, { "hold", 0.4 },
            }
        },
        // Damage dealt by a SPECIAL — same motion, magenta so special hits read distinctly.
        { "damage_special", new GDict
            {
                { "font", Font },
                { "size_lo", 6 }, { "size_hi", 8 }, { "mag_lo", 8.0 }, { "mag_hi", 45.0 },
                { "color_lo", new Color(1.2f, 0.7f, 1.3f) }, { "color_hi", new Color(1.5f, 0.35f, 1.2f) },
                { "outline_color", new Color(0, 0, 0, 0.85f) }, { "outline_size", 5 },
                { "rise", 26.0 }, { "drift", 12.0 }, { "jitter", 8.0 }, { "life", 0.8 },
                { "pop_scale", 0.7 }, { "pop_time", 0.14 }, { "hold", 0.4 },
            }
        },
        // Damage the PLAYER takes — Player.take_damage OVERRIDES `color` per-call with the run's hair pick.
        { "player_damage", new GDict
            {
                { "font", Font },
                { "size_lo", 8 }, { "size_hi", 12 }, { "mag_lo", 5.0 }, { "mag_hi", 40.0 },
                { "color", new Color(0.58f, 0.12f, 0.12f) },
                { "outline_color", new Color(0, 0, 0, 0.9f) }, { "outline_size", 5 },
                { "rise", 20.0 }, { "drift", 7.0 }, { "jitter", 8.0 }, { "life", 0.95 },
                { "pop_scale", 0.7 }, { "pop_time", 0.14 }, { "hold", 0.4 },
            }
        },
    };
}
