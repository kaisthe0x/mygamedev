using Godot;
using GDict = Godot.Collections.Dictionary;
using GArr = Godot.Collections.Array;

namespace MyGame;

/// <summary>
/// The 5 arena levels of a run, as data. RunManager builds and runs each one. **This is where you design a level:**
/// edit its <c>platforms</c> (add/shorten/move), spawns, spawn/exit points. C# port of <c>scripts/run/levels.gd</c>.
///
/// <para>COORDINATES: world pixels, +X = right, **+Y = DOWN** (so a platform higher up has a MORE-NEGATIVE topY).
/// The ground floor sits at y = 0; the player spawns at <c>player_spawn</c>. A camera zoom of 1.5× means ~768×432
/// world units are on screen at once.</para>
///
/// <para>PLATFORMS: each <see cref="P"/>(centerX, topY, width) is one floating one-way platform — you jump up
/// through it and land on top. <c>centerX</c> = its middle, <c>topY</c> = the walkable surface height (negative =
/// higher), <c>width</c> = how long it is (px; ~32 = one tile, so 110 ≈ 3½ tiles). Add more P(...) entries for
/// more platforms; shrink <c>width</c> for shorter ones; the tileset skin auto-paints over whatever you define.</para>
/// </summary>
public static class Levels
{
    // A spawn spec {kit, pos}.
    private static GDict K(GDict kit, float x, float y) => new() { { "kit", kit }, { "pos", new Vector2(x, y) } };

    // A platform spec [centerX, topY, width] — see the class summary. Returned as an array so RunManager reads p[0..2].
    private static GArr P(float centerX, float topY, float width) => new() { centerX, topY, width };

    private static readonly GArr LEVELS = new()
    {
        // 1 · The Shallows — gentle intro, ONE batch (no waves), a traversal testbed with launch orbs.
        new GDict
        {
            { "name", "The Shallows" },
            { "bg", new Color(0.06f, 0.10f, 0.13f) },
            { "platforms", new GArr { P(0, -320, 110), P(800, -360, 110), P(1600, -320, 110) } },
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
            { "platforms", new GArr { P(-350, -120, 150), P(-40, -190, 170), P(280, -140, 160), P(430, -240, 140) } },
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
            { "platforms", new GArr { P(-280, -110, 160), P(80, -160, 200), P(360, -120, 150), P(-120, -250, 150) } },
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
            { "platforms", new GArr { P(-330, -100, 150), P(-60, -170, 160), P(220, -130, 170), P(420, -220, 150), P(60, -270, 160) } },
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
            { "platforms", new GArr { P(-350, -110, 150), P(-80, -180, 170), P(200, -140, 160), P(420, -230, 150), P(-200, -260, 150) } },
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
