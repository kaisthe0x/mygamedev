using Godot;
using GDict = Godot.Collections.Dictionary;
using GArr = Godot.Collections.Array;

namespace MyGame;

/// <summary>
/// The roguelite run driver + the <c>arena.tscn</c> root. Builds each arena from Levels data, drops in start
/// enemies, refills finite BATCHES as the arena clears, banks Ruh on hits, opens the exit once every batch is
/// dead, runs the reward pick, advances levels, and restarts the run on death. Owns the player spawn, camera
/// follow, and death/spawn flair. C# port of <c>scripts/run/run_manager.gd</c> (Phase 5b).
///
/// <para>Talks to the C# body tree (Player/Enemy) + reward system (Rewards) directly; BRIDGES the still-GDScript
/// config/autoload/UI layer (Terrain/Levels/SfxCharacters/SaveData via <c>GD.Load&lt;GDScript&gt;().Call</c> or the
/// constant map, Music/Sfx via <c>/root/*</c>, ExitGate/RewardUI/AttackSelect/LaunchOrb via <c>.New()</c> + signals).
/// Those bridges dissolve as phase 6/7 port those layers.</para>
/// </summary>
[GlobalClass]
public partial class RunManager : Node2D
{
    private const int RewardsOffered = 3;
    private static readonly Vector2 SpawnFxOffset = new(0, -22);
    private static readonly Vector2 DamageNumberOffset = new(0, -42);
    private const float DeathY = 320.0f;
    private const string StartCharacter = "khalid";

    // Camera follow (speed-adaptive).
    private const float CamFollowBase = 0.002f;
    private const float CamTightenStart = 600.0f;
    private const float CamTightenFull = 1200.0f;
    private const float CamTightK = 0.9f;
    private static readonly Vector2 CamZoomNormal = new(1.5f, 1.5f);
    private static readonly Vector2 CamZoomDeath = new(3.0f, 3.0f);
    private static readonly Vector2 CamZoomSpawn = new(2, 2);
    private const float DeathHold = 0.7f;
    private const int DeathPlayerZ = 500;
    private const int DeathOverlayZ = 400;
    private const float DeathFadeIn = 0.55f;
    private const float DeathFadeOut = 0.6f;
    private const float DeathFreeze = 0.5f;
    private const float ClearSlowmoScale = 0.3f;
    private const float ClearSlowmoHold = 0.7f;
    private const float ClearSlowmoRamp = 0.55f;
    private const int TerrainZ = -5;
    private const int PlantZ = -4;
    private const int TreeZ = -15;

    [Export] public NodePath player_path = "Player";

    private Player _player;
    private Camera2D _camera;

    private int _levelIndex = 0;
    private int _clearedThisRun = 0;
    private int _waveIndex = 0;
    private int _alive = 0;
    private bool _cleared = false;
    private DoorType _doorType = DoorType.Health;
    private bool _transitioning = false;
    private Node2D _content;
    private ExitGate _gate;
    private ColorRect _bg;
    private Sprite2D _bgSky;
    private Vector2 _bgImgSize;
    private AnimatedSprite2D _bgAnim;
    private LevelLayout _layout;

    private const string StageDir = "res://scenes/levels/stage1/";
    private Vector2 _playerSpawn = Vector2.Zero;
    private bool _deadPrev = false;
    private float _deathHold = 0.0f;
    private bool _spawning = false;
    private Tween _camTween;
    private Polygon2D _deathOverlay;
    private float _deathTuneLeft = 0.0f;

    // --- bridges (cached in _Ready) ---
    private Music _music;
    private Sfx _sfx;
    private PackedScene _enemyScene, _spawnFx, _ruhOrb;

    public override void _Ready()
    {
        _player = GetNodeOrNull<Player>(player_path);
        _camera = GetNodeOrNull<Camera2D>("Camera2D");
        _music = GetNode<Music>("/root/Music");
        _sfx = GetNode<Sfx>("/root/Sfx");
        _enemyScene = GD.Load<PackedScene>("res://scenes/enemy.tscn");
        _spawnFx = GD.Load<PackedScene>("res://vfx/spawn/enemy_spawn.tscn");
        _ruhOrb = GD.Load<PackedScene>("res://vfx/character/khalid/ruh_orb/ruh_orb.tscn");

        Engine.TimeScale = 1.0;
        AddGlow();
        BuildBg();
        BuildFloor();
        if (_player != null)
            _player.character = StartCharacter;
        BuildLevel(0);
        if (_player != null)
            _player.spawn();
        if (_camera != null)
            PlaceAt(_camera, _playerSpawn + new Vector2(0, -30));
        ChooseAttack();
    }

    public override void _PhysicsProcess(double deltaD)
    {
        if (_player == null)
            return;
        float delta = (float)deltaD;
        if (_gate != null && IsInstanceValid(_gate))
            _gate.Reflect(_cleared);

        if (_player.is_dead())
        {
            HandleDeath(delta);
            return;
        }
        if (_player.is_spawning())
        {
            HandleSpawn(delta);
            return;
        }
        if (_player.GlobalPosition.Y > DeathY)
        {
            PlaceAt(_player, _playerSpawn);
            if (_camera != null)
                PlaceAt(_camera, _playerSpawn + new Vector2(0, -30));
            return;
        }
        if (_spawning)
        {
            _spawning = false;
            ZoomTo(CamZoomNormal, 0.4f);
        }
        FollowCamera(delta);
    }

    // --- level building -------------------------------------------------------

    private GDict Level(int i) => Levels.GetLevel(i);
    private int LevelCount() => Levels.Count();

    /// <summary>Every hand-painted layout variant for the stage (<c>stage1_v*.tscn</c>). Auto-uses whatever exists —
    /// add a variant to the folder and it joins the random pool with no code change.</summary>
    private static string[] StageLayoutPaths()
    {
        var list = new System.Collections.Generic.List<string>();
        using var da = DirAccess.Open(StageDir);
        if (da != null)
        {
            da.ListDirBegin();
            for (string f = da.GetNext(); f != ""; f = da.GetNext())
            {
                if (da.CurrentIsDir())
                    continue;
                string name = f.TrimSuffix(".remap"); // exported builds serve .tscn.remap
                if (name.StartsWith("stage1_v") && name.EndsWith(".tscn"))
                    list.Add(StageDir + name);
            }
            da.ListDirEnd();
        }
        return list.ToArray();
    }

    private void BuildLevel(int index)
    {
        _music.play("level");
        _levelIndex = Mathf.Clamp(index, 0, LevelCount() - 1);
        _waveIndex = 0;
        _alive = 0;
        _cleared = false;
        _transitioning = false;
        if (_content != null && IsInstanceValid(_content))
            _content.QueueFree();
        _content = new Node2D();
        AddChild(_content);

        var lv = Level(_levelIndex);
        Color tint = lv["bg"].As<Color>();
        if (Terrain.BackgroundTexture() != null)
            tint.A = Terrain.BackgroundTintAlpha;
        _bg.Color = tint;
        // Load one of the stage's hand-painted layouts at RANDOM (terrain + collision + spawn markers).
        _layout = null;
        var layoutPaths = StageLayoutPaths();
        if (layoutPaths.Length > 0)
        {
            var scene = GD.Load<PackedScene>(layoutPaths[GD.Randi() % (uint)layoutPaths.Length]);
            _layout = scene?.Instantiate() as LevelLayout;
            if (_layout != null)
            {
                _layout.Position = Vector2.Zero; // ignore any authored root offset — sit the layout at origin
                _content.AddChild(_layout);
            }
        }
        else
        {
            GD.PushWarning("RunManager: no stage1_v*.tscn layouts under scenes/levels/stage1/ — level will be empty.");
        }
        _playerSpawn = _layout != null ? _layout.PlayerSpawn() : lv["player_spawn"].As<Vector2>();

        foreach (var op in _layout?.Orbs() ?? new System.Collections.Generic.List<Vector2>())
            _content.AddChild(new LaunchOrb { Position = op });

        _doorType = DoorTypes.All[GD.Randi() % (uint)DoorTypes.All.Length];
        _gate = new ExitGate();
        _gate.Setup(_doorType);
        _gate.Position = _layout != null ? _layout.ExitPoint() : lv["exit_pos"].As<Vector2>();
        _gate.touched += OnGateTouched;
        _content.AddChild(_gate);

        SpawnGroup(lv["start"].As<GArr>(), false);
        if (_alive <= 0)
            Callable.From(AdvanceBatch).CallDeferred();

        if (_player != null)
            PlaceAt(_player, _playerSpawn);
    }

    private void BuildPlatform(float centerX, float topY, float width, float height)
    {
        var body = new StaticBody2D
        {
            CollisionLayer = (uint)Combat.Layer.World,
            CollisionMask = 0,
            Position = new Vector2(centerX, topY),
        };
        body.AddToGroup("oneway_platform");
        var col = MakeBox(new Vector2(width, height), new Vector2(0, height / 2.0f));
        col.OneWayCollision = true;
        body.AddChild(col);
        PaintSurface(body, new Vector2(-width / 2.0f, 0), width, 0);
        ScatterPlants(body, new Vector2(-width / 2.0f, 0), width, 0.35f);
        _content.AddChild(body);
    }

    // --- terrain painting (visual skin over the colliders) --------------------

    private void PaintSurface(Node parent, Vector2 origin, float width, int fillRows)
    {
        var sheet = Terrain.Sheet();
        if (sheet == null)
        {
            var r = new ColorRect
            {
                Color = Terrain.PLATFORM_FALLBACK,
                Position = origin,
                Size = new Vector2(width, Mathf.Max(Terrain.TILE, (fillRows + 1) * Terrain.TILE)),
                ZIndex = TerrainZ,
            };
            parent.AddChild(r);
            return;
        }
        float t = Terrain.TILE;
        int full = (int)(width / t);
        float rem = width - full * t;
        int cols = full + (rem > 2.0f ? 1 : 0);
        for (int row = 0; row < fillRows + 1; row++)
        {
            var cells = row == 0 ? Terrain.TOP_CELLS : Terrain.FILL_CELLS;
            for (int c = 0; c < cols; c++)
            {
                var cell = cells[(c + row) % cells.Length];
                float w = c < full ? t : rem;
                var at = Terrain.CellTexture(sheet, cell);
                if (w < t)
                    at.Region = new Rect2(at.Region.Position, new Vector2(w, t));
                var spr = new Sprite2D
                {
                    Texture = at,
                    Centered = false,
                    TextureFilter = CanvasItem.TextureFilterEnum.Nearest,
                    Position = origin + new Vector2(c * t, row * t),
                    ZIndex = TerrainZ,
                };
                parent.AddChild(spr);
            }
        }
    }

    private void ScatterPlants(Node parent, Vector2 origin, float width, float density)
    {
        var ps = Terrain.PlantsSheet();
        if (ps == null)
            return;
        int slots = (int)(width / Terrain.TILE);
        for (int i = 0; i < slots; i++)
        {
            if (GD.Randf() > density)
                continue;
            Vector2I cell = GD.Randf() < 0.2f
                ? Terrain.MUSHROOM_CELL
                : Terrain.PLANT_CELLS[(int)(GD.Randi() % (uint)Terrain.PLANT_CELLS.Length)];
            var spr = new Sprite2D
            {
                Texture = Terrain.CellTexture(ps, cell),
                Centered = false,
                TextureFilter = CanvasItem.TextureFilterEnum.Nearest,
                Position = origin + new Vector2(i * Terrain.TILE + GD.Randf() * 6.0f, -Terrain.TILE),
                ZIndex = PlantZ,
            };
            parent.AddChild(spr);
        }
    }

    private void PlaceTrees()
    {
        if (Terrain.TreeTexture(0) == null)
            return;
        float[] spots = { -360.0f, 240.0f, -80.0f };
        for (int i = 0; i < Mathf.Min(2, spots.Length); i++)
        {
            var tex = Terrain.TreeTexture(_levelIndex + i);
            if (tex == null)
                continue;
            var spr = new Sprite2D
            {
                Texture = tex,
                Centered = false,
                TextureFilter = CanvasItem.TextureFilterEnum.Nearest,
                Position = new Vector2(spots[i] - tex.GetWidth() / 2.0f, -tex.GetHeight()),
                ZIndex = TreeZ,
            };
            AddLeafFall(spr, tex.GetWidth(), tex.GetHeight());
            _content.AddChild(spr);
        }
    }

    /// <summary>
    /// Attach a gently-falling "leaves" particle emitter to a tree. The tree sprite is Centered=false, so its LOCAL
    /// space runs (0,0) top-left → (w,h) bottom-right; leaves spawn across the CANOPY band up top and drift down.
    /// This is a plain <c>CpuParticles2D</c> — every knob below is a dial you can tune (or copy for other props).
    /// </summary>
    private static void AddLeafFall(Node2D tree, float w, float h)
    {
        var leafTex = GD.Load<Texture2D>("res://vfx/shared/textures/soft_dot.png"); // swap for a real leaf sprite later
        var leaves = new CpuParticles2D
        {
            Emitting = true,          // run continuously
            LocalCoords = false,      // leaves keep falling in WORLD space (don't snap to the tree)
            ZIndex = TreeZ + 1,       // in front of the trunk
            Texture = leafTex,

            // WHERE they're born: a rectangle across the top of the canopy.
            EmissionShape = CpuParticles2D.EmissionShapeEnum.Rectangle,
            EmissionRectExtents = new Vector2(w * 0.42f, h * 0.18f), // half-size of the spawn band
            Position = new Vector2(w * 0.5f, h * 0.26f),             // centred over the canopy (tree-local)

            // HOW MANY / HOW LONG: sparse + slow = calm, not a blizzard.
            Amount = 10,              // leaves alive at once — raise for denser fall
            Lifetime = 5.0,          // seconds each leaf lives (how long it falls)
            Explosiveness = 0.0f,    // 0 = steady trickle; 1 = all at once (bursts)
            Preprocess = 3.0,        // start mid-fall so leaves are already drifting when a level loads

            // MOTION: a floaty downward fall with sway + tumble.
            Direction = new Vector2(0, 1), // down
            Spread = 30.0f,                // ± degrees of fan-out
            Gravity = new Vector2(0, 24),  // gentle pull (low = leaf-light; raise = heavier fall)
            InitialVelocityMin = 6.0f,
            InitialVelocityMax = 18.0f,
            DampingMin = 6.0f,             // air resistance — slows them so they *drift*, not plummet
            DampingMax = 12.0f,
            AngularVelocityMin = -70.0f,   // tumble/spin (deg/s)
            AngularVelocityMax = 70.0f,

            // SIZE: small motes.
            ScaleAmountMin = 0.15f,
            ScaleAmountMax = 0.35f,
        };
        // LOOK over life: born a soft violet, fade to transparent electric-blue as they settle (Arcane-Void palette).
        var ramp = new Gradient();
        ramp.SetColor(0, new Color(0.72f, 0.45f, 1.0f, 0.9f));
        ramp.SetColor(1, new Color(0.45f, 0.55f, 1.0f, 0.0f));
        leaves.ColorRamp = ramp;
        tree.AddChild(leaves);
    }

    // --- spawning + waves -----------------------------------------------------

    private void SpawnGroup(GArr specs, bool withFx)
    {
        // Positions come from the LAYOUT's spawn markers (ground for walkers, air for flyers), assigned round-robin.
        // The roster (WHICH enemies) is the shared per-level data; each spec's own `pos` is only a fallback.
        var ground = _layout?.GroundSpawns() ?? new System.Collections.Generic.List<Vector2>();
        var air = _layout?.AirSpawns() ?? new System.Collections.Generic.List<Vector2>();
        int gi = 0, ai = 0;
        foreach (Variant specV in specs)
        {
            var spec = specV.As<GDict>();
            var kit = spec["kit"].As<GDict>();
            bool isAir = kit.ContainsKey("air") && kit["air"].AsBool();
            Vector2 pos;
            if (isAir && air.Count > 0)
                pos = air[ai++ % air.Count];
            else if (ground.Count > 0)
                pos = ground[gi++ % ground.Count];
            else
                pos = spec["pos"].As<Vector2>(); // no markers → fall back to the authored position
            if (withFx)
                SpawnFx(pos);
            var enemy = SpawnEnemy(kit, pos);
            if (enemy != null)
            {
                var e = enemy; // stable per-iteration capture for the bound handlers
                enemy.Connect(Enemy.SignalName.died, Callable.From(() => OnEnemyDied(e)));
                enemy.Connect(Enemy.SignalName.damaged, Callable.From((float amount, Node source) => OnEnemyDamaged(amount, source, e)));
                if (!enemy.optional)
                    _alive += 1;
            }
        }
    }

    private Enemy SpawnEnemy(GDict kit, Vector2 pos)
    {
        var scene = kit.ContainsKey("scene") ? GD.Load<PackedScene>(kit["scene"].AsString()) : _enemyScene;
        var enemy = (Enemy)scene.Instantiate();
        foreach (var key in kit.Keys)
        {
            string k = key.AsString();
            if (k is "scene" or "tier" or "pos" or "air" or "movement")  // advisory kit metadata, not Enemy properties
                continue;
            if (k == "id")
                enemy.Set("enemy_id", kit[key]);
            else
                enemy.Set(k, kit[key]);
        }
        enemy.Position = pos;
        _content.AddChild(enemy);
        return enemy;
    }

    private void SpawnFx(Vector2 pos)
    {
        var fx = _spawnFx.Instantiate<Node2D>();
        _content.AddChild(fx);
        PlaceAt(fx, pos + SpawnFxOffset);
        _sfx.play_at("enemy_spawn", pos);
        GetTree().CreateTimer(1.2).Timeout += () =>
        {
            if (IsInstanceValid(fx))
                fx.QueueFree();
        };
    }

    private void OnEnemyDied(Enemy enemy)
    {
        if (enemy.optional)
            return;
        _alive -= 1;
        if (_alive <= 0 && !_transitioning && !_cleared)
            Callable.From(AdvanceBatch).CallDeferred();
    }

    private void SpawnRuhOrb(Vector2 at, bool completedCharge)
    {
        if (_player == null)
            return;
        var orb = _ruhOrb.Instantiate<Node2D>();
        VfxPalette.RecolorTree(orb);
        AddChild(orb);
        PlaceAt(orb, at + new Vector2(0, -18));
        orb.Call("launch", _player, completedCharge);
    }

    private void AdvanceBatch()
    {
        if (_alive > 0 || _transitioning || _cleared)
            return;
        if (!SpawnNextWave())
        {
            _cleared = true;
            CelebrateClear();
            _sfx.play("level_cleared");
            _music.play("base_rest");
        }
        else if (_alive <= 0)
        {
            Callable.From(AdvanceBatch).CallDeferred();
        }
    }

    private void CelebrateClear()
    {
        Engine.TimeScale = ClearSlowmoScale;
        var t = CreateTween().SetIgnoreTimeScale(true);
        t.TweenInterval(ClearSlowmoHold);
        t.TweenMethod(Callable.From<float>(SetTimeScale), ClearSlowmoScale, 1.0f, ClearSlowmoRamp)
            .SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
    }

    private static void SetTimeScale(float v) => Engine.TimeScale = v;

    private void OnEnemyDamaged(float amount, Node source, Enemy enemy)
    {
        if (_player != null && source == _player)
        {
            _player.notify_hit_dealt(amount, enemy);
            if (amount > 0.0f && !enemy.last_hit_from_special && _player.gain_ruh_on_hit())
                SpawnRuhOrb(enemy.GlobalPosition, true);
            FloatingTextType kind = enemy.last_hit_from_special ? FloatingTextType.DamageSpecial : FloatingTextType.Damage;
            FloatingText.Emit(kind, enemy, DamageNumberOffset, Mathf.RoundToInt(amount).ToString(), amount);
        }
    }

    private bool SpawnNextWave()
    {
        var waves = Level(_levelIndex)["waves"].As<GArr>();
        if (_waveIndex >= waves.Count)
            return false;
        SpawnGroup(waves[_waveIndex].As<GArr>(), true);
        _waveIndex += 1;
        return true;
    }

    // --- exit gate -> reward -> next level -------------------------------------

    private void OnGateTouched()
    {
        if (_transitioning || _player == null || !_cleared)
            return;
        _transitioning = true;
        OfferReward();
    }

    private void OfferReward()
    {
        var ui = new RewardUI();
        AddChild(ui);
        ui.chosen += OnRewardChosen;
        ui.Open(new Rewards().offer_for(_doorType, _player, RewardsOffered), _doorType);
    }

    private void OnRewardChosen(string id)
    {
        new Rewards().apply(id, _player);
        _clearedThisRun += 1;
        SaveData.SetCurrentCleared(_clearedThisRun);
        if (_levelIndex >= LevelCount() - 1)
            RestartRun();
        else
            BuildLevel(_levelIndex + 1);
    }

    private void RestartRun()
    {
        Engine.TimeScale = 1.0;
        SaveData.ReportRun(_clearedThisRun);
        _clearedThisRun = 0;
        SaveData.SetCurrentCleared(0);
        _deadPrev = false;
        BuildLevel(0);
        if (_player != null)
        {
            _player.begin_run();
            ChooseAttack();
        }
        EndDeathCinematic();
    }

    private void ChooseAttack()
    {
        if (_player == null)
            return;
        var ui = new AttackSelect();
        AddChild(ui);
        ui.chosen += OnAttackChosen;
        ui.Open(_player.character);
    }

    private void OnAttackChosen(string id) => _player.equip(LoadoutCategory.Attack, id);

    // --- death / spawn / camera flair -----------------------------------------

    private void HandleDeath(float delta)
    {
        if (!_deadPrev)
        {
            _deadPrev = true;
            _deathHold = DeathHold;
            ZoomTo(CamZoomDeath, 0.45f);
            BeginDeathCinematic();
        }
        _deathTuneLeft = Mathf.Max(_deathTuneLeft - delta, 0.0f);
        if (_camera != null)
            _camera.GlobalPosition = _camera.GlobalPosition.Lerp(_player.GlobalPosition + new Vector2(0, -18), 0.12f);
        if (_player.death_complete() && _deathTuneLeft <= 0.0f)
        {
            _deathHold -= delta;
            if (_deathHold <= 0.0f)
                RestartRun();
        }
    }

    private void BeginDeathCinematic()
    {
        _deathTuneLeft = DeathTuneLength();
        _music.stop();
        if (_player != null)
        {
            _player.ZIndex = DeathPlayerZ;
            _player.ZAsRelative = false;
        }
        if (_deathOverlay != null && IsInstanceValid(_deathOverlay))
            _deathOverlay.QueueFree();
        const float s = 20000.0f;
        _deathOverlay = new Polygon2D
        {
            Polygon = new Vector2[] { new(-s, -s), new(s, -s), new(s, s), new(-s, s) },
            Color = Colors.Black,
            Modulate = new Color(1, 1, 1, 0.0f),
            ZIndex = DeathOverlayZ,
            ZAsRelative = false,
        };
        Node host = _camera != null ? _camera : this;
        host.AddChild(_deathOverlay);
        CreateTween().TweenProperty(_deathOverlay, "modulate:a", 1.0, DeathFadeIn);
        GetTree().CreateTimer(DeathFreeze).Timeout += () =>
        {
            if (_player != null && _player.is_dead())
                _player.release_death();
        };
    }

    private void EndDeathCinematic()
    {
        if (_deathOverlay == null || !IsInstanceValid(_deathOverlay))
        {
            ResetPlayerZ();
            return;
        }
        var ov = _deathOverlay;
        _deathOverlay = null;
        var tw = CreateTween();
        tw.TweenProperty(ov, "modulate:a", 0.0, DeathFadeOut);
        tw.TweenCallback(Callable.From(() =>
        {
            if (IsInstanceValid(ov))
                ov.QueueFree();
            ResetPlayerZ();
        }));
    }

    private void ResetPlayerZ()
    {
        if (_player != null)
        {
            _player.ZIndex = 0;
            _player.ZAsRelative = true;
        }
    }

    private float DeathTuneLength()
    {
        var cues = SfxCharacters.CUES;
        string path = cues.ContainsKey("player_death") ? cues["player_death"].AsString() : "";
        if (path == "" || !ResourceLoader.Exists(path))
            return 0.0f;
        var s = GD.Load<AudioStream>(path);
        return s != null ? (float)s.GetLength() : 0.0f;
    }

    private void HandleSpawn(float delta)
    {
        if (!_spawning)
        {
            _spawning = true;
            ZoomTo(CamZoomSpawn, 0.35f);
        }
        if (_camera != null)
            _camera.GlobalPosition = _camera.GlobalPosition.Lerp(_player.GlobalPosition + new Vector2(0, -18), 0.12f);
    }

    private void FollowCamera(float delta)
    {
        if (_camera == null)
            return;
        Vector2 target = new Vector2(_player.GlobalPosition.X, _player.GlobalPosition.Y - 30.0f) + _player.Velocity * delta;
        float vy = Mathf.Abs(_player.Velocity.Y);
        float t = Mathf.Clamp((vy - CamTightenStart) / (CamTightenFull - CamTightenStart), 0.0f, 1.0f);
        float k = Mathf.Lerp(1.0f - Mathf.Pow(CamFollowBase, delta), CamTightK, t);
        _camera.GlobalPosition = _camera.GlobalPosition.Lerp(target, k);
    }

    private void ZoomTo(Vector2 z, float dur)
    {
        if (_camera == null)
            return;
        if (_camTween != null && _camTween.IsValid())
            _camTween.Kill();
        _camTween = _camera.CreateTween();
        _camTween.TweenProperty(_camera, "zoom", z, dur).SetTrans(Tween.TransitionType.Sine).SetEase(Tween.EaseType.Out);
    }

    // --- scaffolding ----------------------------------------------------------

    private void BuildBg()
    {
        var layer = new CanvasLayer { Layer = -100 };
        AddChild(layer);
        var bgTex = Terrain.BackgroundTexture();
        if (bgTex != null)
        {
            _bgImgSize = bgTex.GetSize();
            // Dark backing in the image's OWN edge tone, so zooming the single (non-tiled) image out never shows a
            // hard cut or the void — the starfield just sits in a bit more of its own space.
            Color fill = new(0.05f, 0.05f, 0.06f);
            Image im = bgTex.GetImage();
            if (im != null)
            {
                if (im.IsCompressed())
                    im.Decompress();
                fill = im.GetPixel(0, 0);
            }
            var back = new ColorRect { Color = fill, MouseFilter = Control.MouseFilterEnum.Ignore };
            back.SetAnchorsPreset(Control.LayoutPreset.FullRect);
            layer.AddChild(back);
            // The SINGLE starfield (no tiling), centred + scaled by BackgroundZoom in LayoutBg (1.0 = fills).
            _bgSky = new Sprite2D { Texture = bgTex, TextureFilter = CanvasItem.TextureFilterEnum.Nearest };
            layer.AddChild(_bgSky);
        }
        // Animated background element (orbiting planet) — over the sky, scaled with the same zoom.
        var animFrames = Terrain.BackgroundAnimFrames();
        if (animFrames != null)
        {
            _bgAnim = new AnimatedSprite2D
            {
                SpriteFrames = animFrames,
                TextureFilter = CanvasItem.TextureFilterEnum.Nearest,
            };
            layer.AddChild(_bgAnim);
            _bgAnim.Play("orbit");
        }
        LayoutBg();
        GetViewport().SizeChanged += LayoutBg;
        _bg = new ColorRect { MouseFilter = Control.MouseFilterEnum.Ignore };
        _bg.SetAnchorsPreset(Control.LayoutPreset.FullRect);
        layer.AddChild(_bg);
    }

    /// <summary>Centre + scale the single bg image (BackgroundZoom of the viewport) and place the animated element
    /// inside its rect, for the current resolution. Re-run on viewport resize.</summary>
    private void LayoutBg()
    {
        Vector2 vp = GetViewport().GetVisibleRect().Size;
        float zoom = Terrain.BackgroundZoom;
        Vector2 skySize = vp * zoom;        // the image's on-screen rect (zoom 1.0 = fills)
        Vector2 origin = (vp - skySize) / 2; // centred
        if (_bgSky != null && IsInstanceValid(_bgSky) && _bgImgSize.X > 0)
        {
            _bgSky.Position = vp / 2;
            _bgSky.Scale = skySize / _bgImgSize;
        }
        if (_bgAnim != null && IsInstanceValid(_bgAnim))
        {
            _bgAnim.Position = origin + Terrain.BackgroundAnimRatio * skySize;
            float px = _bgImgSize.X > 0 ? skySize.X / _bgImgSize.X : zoom;
            _bgAnim.Scale = new Vector2(px, px) * Terrain.BackgroundAnimScale;
        }
    }

    private void BuildFloor()
    {
        // Legacy arena floor — the painted layout is the terrain now, so switch the old floor OFF entirely.
        var floorBody = GetNodeOrNull<StaticBody2D>("Floor");
        if (floorBody == null)
            return;
        floorBody.CollisionLayer = 0; // no collision: the layout's painted solid tiles are the ground
        floorBody.Visible = false;
        var old = floorBody.GetNodeOrNull<ColorRect>("ColorRect");
        if (old != null)
            old.Visible = false;
    }

    private void AddGlow()
    {
        var env = new Godot.Environment
        {
            BackgroundMode = Godot.Environment.BGMode.Canvas,
            GlowEnabled = true,
            GlowBlendMode = Godot.Environment.GlowBlendModeEnum.Additive,
            GlowIntensity = 0.9f,
            GlowBloom = 0.15f,
            GlowHdrThreshold = 1.0f,
        };
        AddChild(new WorldEnvironment { Environment = env });
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (@event.IsActionPressed("debug_respawn"))
        {
            BuildLevel(_levelIndex);
            return;
        }
        if (_player == null)
            return;
        if (@event.IsActionPressed("debug_damage"))
            _player.take_damage(12.0f);
        else if (@event.IsActionPressed("debug_heal"))
            _player.ruh += _player.RUH_PER_BLOCK;
        else if (@event is InputEventKey k && k.Pressed && !k.Echo && k.Keycode == Key.B)
            _player.debug_grant_next_buff();   // DEBUG: cycle-grant catalog buffs
        else if (@event is InputEventKey k2 && k2.Pressed && !k2.Echo && k2.Keycode == Key.N)
            _player.debug_clear_buffs();
    }

    // --- small helpers --------------------------------------------------------

    private static void PlaceAt(Node2D node, Vector2 pos)
    {
        node.GlobalPosition = pos;
        node.ResetPhysicsInterpolation();
    }

    private static CollisionShape2D MakeBox(Vector2 size, Vector2 offset) =>
        new() { Shape = new RectangleShape2D { Size = size }, Position = offset };
}
