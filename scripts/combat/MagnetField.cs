using Godot;
using System.Collections.Generic;

namespace MyGame;

/// <summary>
/// The Come Closer special's effect: on spawn, MAGNETIZE the <see cref="max_targets"/> nearest enemies within
/// <see cref="pull_range"/> toward Khalid — each dragged in (Enemy.magnetize) and STUNNED on arrival. Self-frees
/// after <see cref="life"/>. C# port of <c>scripts/combat/magnet_field.gd</c>. Public surface stays snake_case
/// (the come_closer scene authors the exports). Enemy is still GDScript, so <c>magnetize</c> is a dynamic Call.
/// </summary>
[GlobalClass]
public partial class MagnetField : Node2D
{
    [Export] public float pull_range { get; set; } = 260.0f;
    [Export] public float pull_y_band { get; set; } = 48.0f;
    [Export] public int max_targets { get; set; } = 1;
    [Export] public float arrive_dist { get; set; } = 64.0f;
    [Export] public float pull_speed { get; set; } = 340.0f;
    [Export] public float stun_time { get; set; } = 1.5f;
    [Export] public float life { get; set; } = 1.6f;

    public override void _Ready()
    {
        // Measure the grab from KHALID, not `self`: the director add_child()s us (running this _Ready) and only
        // sets our world position afterwards, so our own global_position isn't final here.
        if (GetTree().GetFirstNodeInGroup("player") is Node2D khalid)
        {
            Vector2 origin = khalid.GlobalPosition;
            // Collect every in-range, same-level enemy, then grab only the nearest `max_targets` (closest-first).
            var inReach = new List<(Node2D Enemy, float Dist)>();
            foreach (var e in GetTree().GetNodesInGroup("enemies"))
            {
                if (e is not Node2D enemy)
                    continue;
                float dx = Mathf.Abs(enemy.GlobalPosition.X - origin.X);
                if (dx <= pull_range && Mathf.Abs(enemy.GlobalPosition.Y - origin.Y) <= pull_y_band)
                    inReach.Add((enemy, dx));
            }
            inReach.Sort((a, b) => a.Dist.CompareTo(b.Dist));
            // Wider Pull buff bumps the grab count via a run-scoped bonus on the player.
            int targets = max_targets + (khalid is Player pl ? pl.magnet_target_bonus : 0);
            int n = Mathf.Min(targets, inReach.Count);
            for (int i = 0; i < n; i++)
                inReach[i].Enemy.Call("magnetize", khalid, arrive_dist, pull_speed, stun_time);
        }
        GetTree().CreateTimer(life).Timeout += QueueFree;
    }
}
