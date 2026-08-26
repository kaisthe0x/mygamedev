using Godot;
using System.Collections.Generic;

namespace MyGame;

/// <summary>
/// Root of a hand-painted level LAYOUT scene (<c>scenes/levels/stageN/lM/vK.tscn</c>). Holds a painted
/// <c>TileMapLayer</c> ("Terrain" — its solid tiles carry collision) plus spawn <c>Marker2D</c>s. RunManager
/// instantiates ONE random variant per level and reads these, so each entry into a level is a hand-made look.
///
/// <para>AUTHORING (in the editor): paint the <b>Terrain</b> layer with the terrain TileSet; drag the
/// <b>PlayerSpawn</b> + <b>Exit</b> markers where you want them; add enemy-spawn <c>Marker2D</c>s and put each in
/// the <b>spawn_ground</b> or <b>spawn_air</b> group (ground = walkers, air = flyers). Optional launch-orb spots go
/// in the <b>orb</b> group. WHICH enemies appear is the shared per-level roster in <see cref="Levels"/>; this scene
/// only says WHERE they can appear.</para>
/// </summary>
[GlobalClass]
public partial class LevelLayout : Node2D
{
    /// <summary>World position of the player start.</summary>
    public Vector2 PlayerSpawn() => MarkerPos("PlayerSpawn");

    /// <summary>World position of the exit door.</summary>
    public Vector2 ExitPoint() => MarkerPos("Exit");

    /// <summary>Ground enemy spawn positions (walkers).</summary>
    public List<Vector2> GroundSpawns() => GroupPositions("spawn_ground");

    /// <summary>Air enemy spawn positions (flyers).</summary>
    public List<Vector2> AirSpawns() => GroupPositions("spawn_air");

    /// <summary>Optional launch-orb positions.</summary>
    public List<Vector2> Orbs() => GroupPositions("orb");

    private Vector2 MarkerPos(string childName)
    {
        var m = GetNodeOrNull<Node2D>(childName);
        return m?.GlobalPosition ?? GlobalPosition;
    }

    private List<Vector2> GroupPositions(string group)
    {
        var outL = new List<Vector2>();
        foreach (var n in GetTree().GetNodesInGroup(group))
            if (n is Node2D m && IsAncestorOf(m))
                outL.Add(m.GlobalPosition);
        return outL;
    }
}
