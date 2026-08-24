using Godot;
using GDict = Godot.Collections.Dictionary;
using GArr = Godot.Collections.Array;

namespace MyGame;

/// <summary>
/// The 5 arena levels of a run, as data. RunManager builds and runs each one. Per level: name, bg tint,
/// platforms ([cx, top_y, width]), player_spawn, exit_pos, `start` batch, and escalating `waves`. Each spawn is
/// {kit (an <see cref="EnemyKits"/> dict), pos}. C# port of <c>scripts/run/levels.gd</c>.
/// </summary>
public static class Levels
{
    // A spawn spec {kit, pos}.
    private static GDict K(GDict kit, float x, float y) => new() { { "kit", kit }, { "pos", new Vector2(x, y) } };

    private static readonly GArr LEVELS = new()
    {
        // 1 · The Shallows — gentle intro, ONE batch (no waves), a traversal testbed with launch orbs.
        new GDict
        {
            { "name", "The Shallows" },
            { "bg", new Color(0.06f, 0.10f, 0.13f) },
            { "platforms", new GArr { new GArr { 0.0, -320.0, 110.0 }, new GArr { 800.0, -360.0, 110.0 }, new GArr { 1600.0, -320.0, 110.0 } } },
            { "orbs", new GArr { new Vector2(-300, -160), new Vector2(400, -190), new Vector2(1200, -170) } },
            { "player_spawn", new Vector2(-600, 0) },
            { "exit_pos", new Vector2(2200, -20) },
            { "start", new GArr
                {
                    K(EnemyKits.BAGHEL, -350, 0), K(EnemyKits.BAGHEL, 200, 0), K(EnemyKits.MATAT, 750, 0),
                    K(EnemyKits.TARRI, 1050, 0), K(EnemyKits.BRESKI, 1400, 0), K(EnemyKits.KEBUS, 1700, 0),
                } },
            { "waves", new GArr() },
        },
        // 2 · Redward
        new GDict
        {
            { "name", "Redward" },
            { "bg", new Color(0.13f, 0.05f, 0.06f) },
            { "platforms", new GArr { new GArr { -350.0, -120.0, 150.0 }, new GArr { -40.0, -190.0, 170.0 }, new GArr { 280.0, -140.0, 160.0 }, new GArr { 430.0, -240.0, 140.0 } } },
            { "player_spawn", new Vector2(-470, 0) },
            { "exit_pos", new Vector2(520, -20) },
            { "start", new GArr
                {
                    K(EnemyKits.KEBUS, -150, 0), K(EnemyKits.KEBUS, 150, 0), K(EnemyKits.MAZAB, 280, -140),
                    K(EnemyKits.BAGHEL, 20, 0), K(EnemyKits.BAGHEL, -350, -120), K(EnemyKits.EIN, 0, -220),
                } },
            { "waves", new GArr
                {
                    new GArr { K(EnemyKits.EIN, -100, -200), K(EnemyKits.EIN, 300, -220), K(EnemyKits.KEBUS, 0, 0), K(EnemyKits.KEBUS, 280, -140), K(EnemyKits.BAGHEL, -200, 0) },
                    new GArr { K(EnemyKits.MAZAB, -40, -190), K(EnemyKits.MAZAB, 430, -240), K(EnemyKits.KEBUS, -350, -120), K(EnemyKits.KEBUS, 200, 0), K(EnemyKits.BAGHEL, 400, 0) },
                    new GArr { K(EnemyKits.NASEN, -40, -190), K(EnemyKits.MAZAB, 280, -140), K(EnemyKits.KEBUS, -150, 0), K(EnemyKits.EIN, 100, -240), K(EnemyKits.EIN, -250, -160) },
                } },
        },
        // 3 · The Gullet
        new GDict
        {
            { "name", "The Gullet" },
            { "bg", new Color(0.09f, 0.05f, 0.12f) },
            { "platforms", new GArr { new GArr { -280.0, -110.0, 160.0 }, new GArr { 80.0, -160.0, 200.0 }, new GArr { 360.0, -120.0, 150.0 }, new GArr { -120.0, -250.0, 150.0 } } },
            { "player_spawn", new Vector2(-470, 0) },
            { "exit_pos", new Vector2(520, -20) },
            { "start", new GArr
                {
                    K(EnemyKits.NASEN, 80, -160), K(EnemyKits.KEBUS, -200, 0), K(EnemyKits.KEBUS, 200, 0),
                    K(EnemyKits.MAZAB, 300, 0), K(EnemyKits.BAGHEL, -100, 0), K(EnemyKits.EIN, 0, -220),
                } },
            { "waves", new GArr
                {
                    new GArr { K(EnemyKits.EIN, 0, -220), K(EnemyKits.EIN, -200, -180), K(EnemyKits.KEBUS, -280, -110), K(EnemyKits.KEBUS, 360, -120), K(EnemyKits.BAGHEL, 200, 0) },
                    new GArr { K(EnemyKits.NASEN, -120, -250), K(EnemyKits.NASEN, 80, -160), K(EnemyKits.KEBUS, 360, -120), K(EnemyKits.MAZAB, -100, 0), K(EnemyKits.MAZAB, 250, 0) },
                    new GArr { K(EnemyKits.KEBUS, -280, -110), K(EnemyKits.KEBUS, 80, -160), K(EnemyKits.KEBUS, 300, 0), K(EnemyKits.NASEN, -120, -250), K(EnemyKits.EIN, 0, -230), K(EnemyKits.EIN, 200, -200) },
                } },
        },
        // 4 · Ossuary
        new GDict
        {
            { "name", "Ossuary" },
            { "bg", new Color(0.05f, 0.11f, 0.08f) },
            { "platforms", new GArr { new GArr { -330.0, -100.0, 150.0 }, new GArr { -60.0, -170.0, 160.0 }, new GArr { 220.0, -130.0, 170.0 }, new GArr { 420.0, -220.0, 150.0 }, new GArr { 60.0, -270.0, 160.0 } } },
            { "player_spawn", new Vector2(-470, 0) },
            { "exit_pos", new Vector2(520, -20) },
            { "start", new GArr
                {
                    K(EnemyKits.KEBUS, -180, 0), K(EnemyKits.KEBUS, 120, 0), K(EnemyKits.NASEN, 60, -270), K(EnemyKits.EIN, 150, -200),
                    K(EnemyKits.EIN, -100, -180), K(EnemyKits.MAZAB, 300, 0), K(EnemyKits.MAZAB, -330, -100),
                } },
            { "waves", new GArr
                {
                    new GArr { K(EnemyKits.KEBUS, -330, -100), K(EnemyKits.KEBUS, 220, -130), K(EnemyKits.KEBUS, 0, 0), K(EnemyKits.EIN, 0, -230), K(EnemyKits.EIN, 300, -230), K(EnemyKits.MAZAB, -200, 0) },
                    new GArr { K(EnemyKits.NASEN, -60, -170), K(EnemyKits.NASEN, 60, -270), K(EnemyKits.KEBUS, 420, -220), K(EnemyKits.MAZAB, -200, 0), K(EnemyKits.EIN, 250, -250), K(EnemyKits.EIN, -150, -200) },
                    new GArr { K(EnemyKits.KEBUS, -330, -100), K(EnemyKits.KEBUS, -60, -170), K(EnemyKits.KEBUS, 220, -130), K(EnemyKits.NASEN, 60, -270), K(EnemyKits.MAZAB, 300, 0), K(EnemyKits.MAZAB, -180, 0) },
                } },
        },
        // 5 · Way of All Flesh
        new GDict
        {
            { "name", "Way of All Flesh" },
            { "bg", new Color(0.13f, 0.08f, 0.03f) },
            { "platforms", new GArr { new GArr { -350.0, -110.0, 150.0 }, new GArr { -80.0, -180.0, 170.0 }, new GArr { 200.0, -140.0, 160.0 }, new GArr { 420.0, -230.0, 150.0 }, new GArr { -200.0, -260.0, 150.0 } } },
            { "player_spawn", new Vector2(-470, 0) },
            { "exit_pos", new Vector2(520, -20) },
            { "start", new GArr
                {
                    K(EnemyKits.NASEN, -200, -260), K(EnemyKits.KEBUS, -150, 0), K(EnemyKits.KEBUS, 200, -140), K(EnemyKits.KEBUS, 80, 0),
                    K(EnemyKits.MAZAB, 320, 0), K(EnemyKits.EIN, 0, -220), K(EnemyKits.EIN, -300, -160),
                } },
            { "waves", new GArr
                {
                    new GArr { K(EnemyKits.KEBUS, -350, -110), K(EnemyKits.KEBUS, 200, -140), K(EnemyKits.NASEN, -80, -180), K(EnemyKits.EIN, 100, -240), K(EnemyKits.EIN, 300, -240), K(EnemyKits.MAZAB, -250, 0) },
                    new GArr { K(EnemyKits.KEBUS, 0, 0), K(EnemyKits.KEBUS, 420, -230), K(EnemyKits.KEBUS, -200, 0), K(EnemyKits.NASEN, 200, -140), K(EnemyKits.MAZAB, -350, -110), K(EnemyKits.MAZAB, 250, 0) },
                    new GArr { K(EnemyKits.NASEN, -200, -260), K(EnemyKits.NASEN, -80, -180), K(EnemyKits.KEBUS, -350, -110), K(EnemyKits.KEBUS, 200, -140), K(EnemyKits.MAZAB, 320, 0), K(EnemyKits.EIN, 0, -240), K(EnemyKits.EIN, -300, -200) },
                } },
        },
    };

    public static int Count() => LEVELS.Count;

    public static GDict GetLevel(int i) => LEVELS[Mathf.Clamp(i, 0, LEVELS.Count - 1)].As<GDict>();
}
