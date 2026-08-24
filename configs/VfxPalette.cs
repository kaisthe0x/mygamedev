using Godot;
using GDict = Godot.Collections.Dictionary;

namespace MyGame;

/// <summary>
/// POWER / VFX recolour — the emitter-side counterpart to <see cref="PaletteConfig"/> (which recolours the body).
/// C# port of <c>configs/vfx_palette.gd</c>. Khalid's effects collapse to three well-separated hue FAMILIES
/// (red ~0°, gold ~50°, teal ~176°) plus neutrals; instead of pre-baking the effect scenes we recolour at SPAWN
/// time — classify each gradient stop by hue and swap ONLY its hue to the picked colour, keeping saturation, value
/// (HDR &gt;1 for bloom) and alpha. <see cref="picks"/> (family → Color) is set once per run from the picker;
/// empty == identity. <c>ParticleDirector</c> calls <see cref="RecolorTree"/> on every effect it spawns.
/// </summary>
public static class VfxPalette
{
    /// <summary>Family hue centres, Godot hue units (0..1 == 0..360°). Far apart so Classify is unambiguous.</summary>
    public static readonly GDict FAMILIES = new() { { "red", 0.0 }, { "gold", 0.14 }, { "teal", 0.49 } };
    public const float SAT_FLOOR = 0.28f;  // below this a pixel is a NEUTRAL (white/grey core, smoke) — never recoloured
    public const float HUE_TOL = 0.11f;    // a stop must sit within this of a family centre, else it's left untouched

    /// <summary>The player's picks: family name → chosen Color. Empty == no change (identity). Static so any spawn
    /// path can honour it without threading state; set from the picker / run profile at run start.</summary>
    public static GDict picks = new();

    public static void SetPicks(GDict newPicks) => picks = (GDict)newPicks.Duplicate();

    /// <summary>Which family a colour belongs to ("" = neutral/unmatched → leave as-is).</summary>
    public static string Classify(Color c)
    {
        if (c.S < SAT_FLOOR)
            return "";
        string best = "";
        float bestd = 999.0f;
        foreach (var famK in FAMILIES.Keys)
        {
            float d = HueDist(c.H, FAMILIES[famK].As<float>());
            if (d < bestd)
            {
                bestd = d;
                best = famK.AsString();
            }
        }
        return bestd <= HUE_TOL ? best : "";
    }

    private static float HueDist(float a, float b)
    {
        float d = Mathf.Abs(a - b);
        return Mathf.Min(d, 1.0f - d);
    }

    /// <summary>The picked HUE (0..1) for the family `sample` belongs to, or -1 if no pick / no match — for a
    /// hue-replace shader on a texture-baked "thing" (see vfx/shaders/thing_recolor).</summary>
    public static float HueFor(Color sample)
    {
        if (picks.Count == 0)
            return -1.0f;
        string fam = Classify(sample);
        if (fam == "" || !picks.ContainsKey(fam))
            return -1.0f;
        return picks[fam].As<Color>().H;
    }

    /// <summary>Recolour ONE colour by the current picks: adopt the picked family's HUE, keep this stop's own
    /// saturation + value (HDR preserved) + alpha. No pick / unmatched → returned unchanged.</summary>
    public static Color Recolor(Color c)
    {
        if (picks.Count == 0)
            return c;
        string fam = Classify(c);
        if (fam == "" || !picks.ContainsKey(fam))
            return c;
        Color target = picks[fam].As<Color>();
        return Color.FromHsv(target.H, c.S, c.V, c.A);
    }

    /// <summary>Recolour an entire freshly-instantiated effect subtree in place (particle colour / ramp / modulate
    /// on the node and its descendants). Safe once on spawn; gradients are duplicated so shared resources survive.</summary>
    public static void RecolorTree(Node root)
    {
        if (picks.Count == 0)
            return;
        RecolorNode(root);
        foreach (var child in root.GetChildren())
            RecolorTree(child);
    }

    private static void RecolorNode(Node n)
    {
        if (n is CanvasItem ci)
            ci.SelfModulate = Recolor(ci.SelfModulate);
        if (n is Line2D line)
            line.DefaultColor = Recolor(line.DefaultColor);
        if (n is CpuParticles2D cp)
        {
            cp.Color = Recolor(cp.Color);
            cp.ColorRamp = RecoloredGradient(cp.ColorRamp);
            cp.ColorInitialRamp = RecoloredGradient(cp.ColorInitialRamp);
        }
        if (n is GpuParticles2D gp && gp.ProcessMaterial is ParticleProcessMaterial pm)
        {
            var dup = (ParticleProcessMaterial)pm.Duplicate();
            dup.Color = Recolor(dup.Color);
            dup.ColorRamp = RecoloredGradientTex(dup.ColorRamp);
            dup.ColorInitialRamp = RecoloredGradientTex(dup.ColorInitialRamp);
            gp.ProcessMaterial = dup;
        }
        // Gradient-as-texture trick: many effects colour particles via a GradientTexture on `texture` — recolour
        // that too. A normal sprite texture is returned untouched. Guard on the property existing (like GDScript `in`).
        if (HasProp(n, "texture"))
            n.Set("texture", RecoloredGradientTex(n.Get("texture").As<Texture2D>()));
    }

    private static Gradient RecoloredGradient(Gradient g)
    {
        if (g == null)
            return null;
        var dup = (Gradient)g.Duplicate();
        for (int i = 0; i < dup.GetPointCount(); i++)
            dup.SetColor(i, Recolor(dup.GetColor(i)));
        return dup;
    }

    private static Texture2D RecoloredGradientTex(Texture2D t)
    {
        if (t is GradientTexture1D || t is GradientTexture2D)
        {
            var dt = (Texture2D)t.Duplicate();
            dt.Set("gradient", RecoloredGradient((Gradient)t.Get("gradient").AsGodotObject()));
            return dt;
        }
        return t;
    }

    private static bool HasProp(GodotObject o, string name)
    {
        foreach (var p in o.GetPropertyList())
            if (p["name"].AsString() == name)
                return true;
        return false;
    }
}
