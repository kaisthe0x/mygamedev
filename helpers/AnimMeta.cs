using Godot;
using GDict = Godot.Collections.Dictionary;
using GArr = Godot.Collections.Array;

namespace MyGame;

/// <summary>
/// Readers for the per-animation metadata the sprite generator writes into each SpriteFrames (see
/// tools/gen_spriteframes.py). Both the player combo/strike logic and enemy attack timing read the same maps.
/// C# port of <c>helpers/anim_meta.gd</c>.
/// </summary>
public static class AnimMeta
{
    /// <summary>The authored hit frames (EMITTED indices) for `anim`, or [] if none.</summary>
    public static GArr HitFrames(SpriteFrames frames, StringName anim)
    {
        if (frames == null || !frames.HasMeta("hit_frames"))
            return new GArr();
        var m = frames.GetMeta("hit_frames").As<GDict>();
        string a = anim.ToString();
        return m.ContainsKey(a) ? m[a].As<GArr>() : new GArr();
    }

    /// <summary>How many leading sheet frames were dropped for `anim` (the idle-reference frame 0), or 0.</summary>
    public static int SheetStart(SpriteFrames frames, StringName anim)
    {
        if (frames == null || !frames.HasMeta("sheet_start"))
            return 0;
        var m = frames.GetMeta("sheet_start").As<GDict>();
        string a = anim.ToString();
        return m.ContainsKey(a) ? m[a].As<int>() : 0;
    }

    /// <summary>The `loop_from` / `loop_to` bound (EMITTED index) for `anim`, or -1 if unset. `key` is "loop_from"/"loop_to".</summary>
    public static int LoopBound(SpriteFrames frames, StringName anim, string key)
    {
        if (frames == null || !frames.HasMeta(key))
            return -1;
        var m = frames.GetMeta(key).As<GDict>();
        string a = anim.ToString();
        return m.ContainsKey(a) ? m[a].As<int>() : -1;
    }
}
