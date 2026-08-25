using Godot;
using GDict = Godot.Collections.Dictionary;

namespace MyGame;

/// <summary>
/// The "Locomotion" component of a movement Action (run/jump/dash/slam) — every movement/physics knob. The
/// values below are the shared BASELINE; a character's catalog `move` dict overlays only the fields it deviates
/// on. C# port of <c>configs/locomotion.gd</c>. Snake public fields so the Player addresses them via <c>.Get</c>.
/// </summary>
public partial class Locomotion : RefCounted
{
    // run
    public float run_speed = 160.0f;
    public float acceleration = 1200.0f;
    public float friction = 1400.0f;
    public float run_anim_speed = 1.5f;
    // jump / vertical arc / landing
    public float jump_velocity = -330.0f;
    public int air_jumps = 2;
    public float gravity = 900.0f;
    public float fall_gravity_scale = 1.35f;
    public float land_min_fall_speed = 140.0f;
    public float land_predict_distance = 22.0f;
    // dash
    public float dash_speed = 420.0f;
    public float dash_time = 0.18f;
    public float dash_cooldown = 0.45f;
    public float dash_anim_time = 0.30f;
    public float dash_gravity_scale = 0.35f;
    public bool blink = false;
    // slam
    public float slam_speed = 1200.0f;
    public float slam_min_clearance = 50.0f;
    public int slam_hold_frame = 2;
    public float slam_impact_distance = 30.0f;
    public float slam_min_drop = 120.0f;
    public float slam_max_drop = 700.0f;
    public float slam_max_damage_mult = 2.5f;

    private static float F(GDict d, string k, float def) => d.ContainsKey(k) ? d[k].As<float>() : def;
    private static int I(GDict d, string k, int def) => d.ContainsKey(k) ? d[k].As<int>() : def;

    /// <summary>Build a Locomotion, overlaying only the fields the catalog `move` dict specifies.</summary>
    public static Locomotion Make(GDict d)
    {
        var m = new Locomotion();
        m.run_speed = F(d, "run_speed", m.run_speed);
        m.acceleration = F(d, "acceleration", m.acceleration);
        m.friction = F(d, "friction", m.friction);
        m.run_anim_speed = F(d, "run_anim_speed", m.run_anim_speed);
        m.jump_velocity = F(d, "jump_velocity", m.jump_velocity);
        m.air_jumps = I(d, "air_jumps", m.air_jumps);
        m.gravity = F(d, "gravity", m.gravity);
        m.fall_gravity_scale = F(d, "fall_gravity_scale", m.fall_gravity_scale);
        m.land_min_fall_speed = F(d, "land_min_fall_speed", m.land_min_fall_speed);
        m.land_predict_distance = F(d, "land_predict_distance", m.land_predict_distance);
        m.dash_speed = F(d, "dash_speed", m.dash_speed);
        m.dash_time = F(d, "dash_time", m.dash_time);
        m.dash_cooldown = F(d, "dash_cooldown", m.dash_cooldown);
        m.dash_anim_time = F(d, "dash_anim_time", m.dash_anim_time);
        m.dash_gravity_scale = F(d, "dash_gravity_scale", m.dash_gravity_scale);
        m.blink = d.ContainsKey("blink") && d["blink"].AsBool();
        m.slam_speed = F(d, "slam_speed", m.slam_speed);
        m.slam_min_clearance = F(d, "slam_min_clearance", m.slam_min_clearance);
        m.slam_hold_frame = I(d, "slam_hold_frame", m.slam_hold_frame);
        m.slam_impact_distance = F(d, "slam_impact_distance", m.slam_impact_distance);
        m.slam_min_drop = F(d, "slam_min_drop", m.slam_min_drop);
        m.slam_max_drop = F(d, "slam_max_drop", m.slam_max_drop);
        m.slam_max_damage_mult = F(d, "slam_max_damage_mult", m.slam_max_damage_mult);
        return m;
    }
}
