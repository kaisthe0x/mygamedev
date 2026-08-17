class_name OffscreenMarkers
extends Control

## Edge-of-screen arrows pointing at OFF-SCREEN enemies -- so you know where they are (and which is which)
## while airborne / after an orb launch, when the tight 6x camera has left them out of frame. Lives in the
## HUD CanvasLayer (screen space): each frame it projects every enemy through the camera
## (get_canvas_transform), and for any that fall outside the view it draws a chevron clamped to an inset
## screen edge, rotated toward the enemy, tinted per enemy (EnemyMarkers) and faded/shrunk by how FAR the
## enemy is (world distance from the camera centre). On-screen enemies get no arrow.

const MARGIN := 24.0        ## inset from the screen edge the arrows ride on (px)
const SIZE_NEAR := 13.0     ## chevron half-length for a close (just off-screen) enemy
const SIZE_FAR := 7.0       ## ...for a very distant one
const FADE_START := 250.0   ## WORLD px from the camera centre where the arrow is at full size/alpha
const FADE_END := 1600.0    ## ...and where it reaches min size / min alpha
const ALPHA_NEAR := 0.95
const ALPHA_FAR := 0.40


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw() # enemies + camera move every frame; the markers track live


func _draw() -> void:
	var xform := get_viewport().get_canvas_transform() # world -> screen (the active camera)
	var view := get_viewport_rect().size
	var center := view * 0.5
	var cam_center: Vector2 = xform.affine_inverse() * center # camera centre in WORLD space (for the fade)
	var lo := Vector2(MARGIN, MARGIN)
	var hi := view - Vector2(MARGIN, MARGIN)

	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node2D):
			continue
		var enemy := e as Node2D
		var screen: Vector2 = xform * enemy.global_position
		# On-screen (inside the view) -> no arrow; you can already see it.
		if screen.x >= 0.0 and screen.x <= view.x and screen.y >= 0.0 and screen.y <= view.y:
			continue
		var dir := screen - center
		if dir.length() < 0.001:
			continue
		var edge := _clamp_to_rect(center, dir, lo, hi)
		# Fade + shrink by WORLD distance (zoom-independent, intuitive to tune).
		var world_dist := enemy.global_position.distance_to(cam_center)
		var t := clampf((world_dist - FADE_START) / maxf(FADE_END - FADE_START, 1.0), 0.0, 1.0)
		var col := EnemyMarkers.color_for(String(enemy.get("enemy_id")) if "enemy_id" in enemy else "")
		col.a = lerpf(ALPHA_NEAR, ALPHA_FAR, t)
		_draw_chevron(edge, dir.angle(), lerpf(SIZE_NEAR, SIZE_FAR, t), col)


## Where the ray from `c` in direction `dir` first crosses the inset rect [lo, hi] -- the point on the
## screen edge the arrow sits at. Returns `c` if `dir` is degenerate.
func _clamp_to_rect(c: Vector2, dir: Vector2, lo: Vector2, hi: Vector2) -> Vector2:
	var t := INF
	if dir.x > 0.001:
		t = minf(t, (hi.x - c.x) / dir.x)
	elif dir.x < -0.001:
		t = minf(t, (lo.x - c.x) / dir.x)
	if dir.y > 0.001:
		t = minf(t, (hi.y - c.y) / dir.y)
	elif dir.y < -0.001:
		t = minf(t, (lo.y - c.y) / dir.y)
	return c + dir * t if is_finite(t) else c


## A filled triangle pointing along `angle` at `pos`, with a faint dark outline so it reads on any
## background. `half` is roughly the tip's distance from `pos`.
func _draw_chevron(pos: Vector2, angle: float, half: float, col: Color) -> void:
	var fwd := Vector2.RIGHT.rotated(angle)
	var side := fwd.orthogonal()
	var tip := pos + fwd * half
	var a := pos - fwd * (half * 0.55) + side * (half * 0.85)
	var b := pos - fwd * (half * 0.55) - side * (half * 0.85)
	draw_colored_polygon(PackedVector2Array([tip, a, b]), col)
	draw_polyline(PackedVector2Array([tip, a, b, tip]), Color(0.0, 0.0, 0.0, col.a * 0.55), 1.5)
