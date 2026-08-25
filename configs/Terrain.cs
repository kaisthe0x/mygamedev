using Godot;

namespace MyGame;

/// <summary>
/// The terrain SKIN — the art that dresses each level: a 32px tileset, ground plants, tree props, an optional
/// background image. Data + helpers; RunManager does the placing. Missing sheet → flat-colour fallback. C# port
/// of <c>configs/terrain.gd</c>.
/// </summary>
public static class Terrain
{
    public const int TILE = 32;

    // Stage 1 art set (assets/terrain/stage1/).
    private const string SheetPath = "res://assets/terrain/stage1/tileset1-Sheet.png";
    private const string PlantsSheetPath = "res://assets/terrain/stage1/ground_plants-Sheet.png";
    private static readonly string[] TREES =
    {
        "res://assets/terrain/stage1/neon-tree1.png",
        "res://assets/terrain/stage1/neon-tree2.png",
    };

    // Atlas cells (col,row) by role. TOP = walkable surface; FILL = body below.
    public static readonly Vector2I[] TOP_CELLS = { new(0, 0), new(1, 0), new(2, 0), new(3, 0) };
    public static readonly Vector2I[] FILL_CELLS =
    {
        new(0, 1), new(1, 1), new(2, 1), new(3, 1),
        new(0, 2), new(1, 2), new(2, 2), new(3, 2),
    };
    public static readonly Vector2I[] PLANT_CELLS = { new(0, 0), new(1, 0) };
    public static readonly Vector2I MUSHROOM_CELL = new(0, 1);

    public static readonly Color PLATFORM_FALLBACK = new(0.22f, 0.23f, 0.30f);
    public static readonly Color FLOOR_FALLBACK = new(0.16f, 0.17f, 0.22f);

    // Optional full-screen background image behind the per-level colour tint.
    public const string BackgroundTexturePath = "res://assets/terrain/background.png";
    public const float BackgroundTintAlpha = 0.4f;

    private static Texture2D Load(string path) => ResourceLoader.Exists(path) ? GD.Load<Texture2D>(path) : null;

    public static Texture2D Sheet() => Load(SheetPath);
    public static Texture2D PlantsSheet() => Load(PlantsSheetPath);
    public static Texture2D BackgroundTexture() => Load(BackgroundTexturePath);

    /// <summary>An AtlasTexture for one 32px cell of `tex`.</summary>
    public static AtlasTexture CellTexture(Texture2D tex, Vector2I cell) =>
        new() { Atlas = tex, Region = new Rect2(cell.X * TILE, cell.Y * TILE, TILE, TILE) };

    /// <summary>A tree prop texture by index (wraps), or null if none present.</summary>
    public static Texture2D TreeTexture(int i) => TREES.Length == 0 ? null : Load(TREES[i % TREES.Length]);
}
