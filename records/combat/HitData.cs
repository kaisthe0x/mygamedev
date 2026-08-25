using Godot;

namespace MyGame;

/// <summary>
/// The "Strike" component of an <see cref="Action"/>: HOW a hit is delivered (<see cref="Type"/>) + its per-combo-
/// SEGMENT hitbox tuning. Replaces the old <c>StrikeSpec</c> (which held stringly-typed dicts). Author with the
/// params form: <c>new HitData(StrikeType.Melee, seg1, seg2, seg3)</c> — a single-hit move passes one segment, a
/// combo passes several, and a move whose numbers live in its own scene passes none.
/// </summary>
public sealed record HitData(StrikeType Type, params SegmentData[] Segments)
{
    /// <summary>The tuning for combo segment <paramref name="seg"/> (a shorter list reuses its last entry; none → an empty segment).</summary>
    public SegmentData Segment(int seg) =>
        Segments.Length == 0 ? new SegmentData() : Segments[Mathf.Min(seg, Segments.Length - 1)];
}
