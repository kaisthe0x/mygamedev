using Godot;
using GDict = Godot.Collections.Dictionary;

namespace MyGame;

/// <summary>
/// The single entry point for particle-emitter config, characters AND enemies — aggregates
/// <see cref="EmittersCharacters"/> + <see cref="EmittersEnemies"/> so callers have one place to look.
/// C# port of <c>vfx/config/emitters.gd</c>. Characters are keyed id → animation → [rows] and driven by
/// <see cref="ParticleDirector"/> on animation frames; enemies are keyed id → effect → row and attached in
/// code by state/event (no frame scheduling). Same row vocabulary otherwise (scene, pos, …).
/// </summary>
public static class Emitters
{
    /// <summary>Every animation's rows for a character id, or {} if the character has none.</summary>
    public static GDict Character(string id) =>
        EmittersCharacters.TABLE.ContainsKey(id) ? EmittersCharacters.TABLE[id].As<GDict>() : new GDict();

    /// <summary>Every effect's row for an enemy id, or {} if the enemy has none.</summary>
    public static GDict Enemy(string id) =>
        EmittersEnemies.TABLE.ContainsKey(id) ? EmittersEnemies.TABLE[id].As<GDict>() : new GDict();

    /// <summary>One enemy effect's row ({scene, pos, …}), or {} if unlisted (an absent row = no such emitter).</summary>
    public static GDict EnemyEffect(string id, string effect)
    {
        var e = Enemy(id);
        return e.ContainsKey(effect) ? e[effect].As<GDict>() : new GDict();
    }
}
