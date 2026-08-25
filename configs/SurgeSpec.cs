using Godot;
using GDict = Godot.Collections.Dictionary;

namespace MyGame;

/// <summary>
/// The timed self-buff a SURGE applies — the "surge" component of a SURGE Action. Triggered on the `surge`
/// button, gated by RUH (each use spends `cost`). C# port of <c>configs/surge_spec.gd</c>. Snake public fields
/// so the Player addresses them via <c>.Get</c>.
/// </summary>
public partial class SurgeSpec : RefCounted
{
    public float cost = 100.0f;
    public float duration = 5.0f;
    public bool invuln = false;
    public float damage_mult = 1.0f;
    public float damage_taken_mult = 1.0f;
    public float speed_mult = 1.0f;
    public bool channel = false;       // a movement-locking sleep/heal channel (Nem)
    public float heal_frac = 0.0f;
    public string trigger = "cast";    // "cast" (immediate) or "hit" (armed reactive — Wara)
    public float stun_radius = 0.0f;
    public float stun_time = 0.0f;
    public string aura = "";           // orbit aura VFX scene shown while active
    public string burst = "";          // Wara: the AoE burst played once WHEN triggered

    private static float F(GDict d, string k, float def) => d.ContainsKey(k) ? d[k].As<float>() : def;

    public static SurgeSpec Make(GDict d)
    {
        var s = new SurgeSpec();
        s.cost = F(d, "cost", s.cost);
        s.duration = F(d, "duration", s.duration);
        s.invuln = d.ContainsKey("invuln") && d["invuln"].AsBool();
        s.damage_mult = F(d, "damage_mult", s.damage_mult);
        s.damage_taken_mult = F(d, "damage_taken_mult", s.damage_taken_mult);
        s.speed_mult = F(d, "speed_mult", s.speed_mult);
        s.channel = d.ContainsKey("channel") && d["channel"].AsBool();
        s.heal_frac = F(d, "heal_frac", s.heal_frac);
        s.trigger = d.ContainsKey("trigger") ? d["trigger"].AsString() : s.trigger;
        s.stun_radius = F(d, "stun_radius", s.stun_radius);
        s.stun_time = F(d, "stun_time", s.stun_time);
        s.aura = d.ContainsKey("aura") ? d["aura"].AsString() : s.aura;
        s.burst = d.ContainsKey("burst") ? d["burst"].AsString() : s.burst;
        return s;
    }
}
