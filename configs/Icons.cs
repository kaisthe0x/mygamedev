using Godot;
using System.Collections.Generic;
using GDict = Godot.Collections.Dictionary;

namespace MyGame;

/// <summary>
/// Central ICON registry for things without their own icon field — reward doors + buffs + status pips. UI asks
/// HERE, so when real art lands you swap a PATH and nothing else changes. Keys are namespaced ("door:&lt;type&gt;",
/// "buff:&lt;id&gt;", "status:&lt;id&gt;"); textures load lazily + cache. C# port of <c>configs/icons.gd</c>.
/// >>> TODO(art): every path is a TEMP placeholder (reused pngs). <<<
/// </summary>
public static class Icons
{
    private const string Fallback = "res://vfx/shared/textures/soft_dot.png";

    private static readonly GDict PATHS = new()
    {
        // reward DOOR types
        { "door:health", "res://vfx/shared/textures/soft_dot.png" },
        { "door:athletic", "res://vfx/shared/textures/pixel_ember.png" },
        { "door:attack", "res://vfx/shared/textures/blast1.png" },
        { "door:special", "res://vfx/shared/impervious/shield.png" },
        // buffs (by reward id)
        { "buff:mend", "res://vfx/shared/textures/soft_dot.png" },
        { "buff:max_hp", "res://vfx/shared/textures/soft_dot.png" },
        { "buff:ruh_cap", "res://vfx/shared/impervious/shield.png" },
        { "buff:air_jump", "res://vfx/shared/textures/pixel_ember.png" },
        { "buff:run", "res://vfx/shared/textures/pixel_ember.png" },
        { "buff:crimson_vortex", "res://vfx/shared/textures/soft_dot.png" },
        // enemy STATUS icons
        { "status:reap", "res://vfx/shared/textures/skull_texture.png" },
        { "status:stun", "res://vfx/shared/textures/z_texture.png" },
        { "status:slow", "res://vfx/shared/textures/forward_arrow_texture.png" },
        { "status:charm", "res://vfx/shared/textures/pixel_ember.png" },
    };

    private static readonly Dictionary<string, Texture2D> Cache = new();

    /// <summary>The texture for a namespaced key ("door:health", "buff:mend", …), cached. Unknown = FALLBACK.</summary>
    public static Texture2D Texture(string key)
    {
        string path = PATHS.ContainsKey(key) ? PATHS[key].AsString() : Fallback;
        return LoadCached(ResourceLoader.Exists(path) ? path : Fallback);
    }

    /// <summary>The texture at an explicit res:// PATH (e.g. an Action's embedded icon), cached. Empty/missing = FALLBACK.</summary>
    public static Texture2D LoadPath(string path)
    {
        if (path == "" || !ResourceLoader.Exists(path))
            path = Fallback;
        return LoadCached(path);
    }

    private static Texture2D LoadCached(string path)
    {
        if (Cache.TryGetValue(path, out var tex))
            return tex;
        tex = GD.Load<Texture2D>(path);
        Cache[path] = tex;
        return tex;
    }

    public static Texture2D Door(DoorType doorType) => Texture($"door:{doorType.Key()}");
    public static Texture2D Buff(string id) => Texture($"buff:{id}");
    public static Texture2D Status(StatusType status) => Texture($"status:{status.Key()}");
}
