extends SceneTree
## Dev tool: build a LEVEL LAYOUT template scene (structure only — you paint the Terrain + move markers).
##   godot-mono --headless --script tools/gen_level_template.gd
const TILESET := "res://assets/terrain/stage1/terrain_tileset.tres"
const OUT := "res://scenes/levels/stage1/level_v1.tscn"
func _init() -> void:
	var root := Node2D.new()
	root.name = "LevelLayout"
	root.set_script(load("res://scripts/run/LevelLayout.cs"))
	var tml := TileMapLayer.new()
	tml.name = "Terrain"
	tml.tile_set = load(TILESET)
	_add(root, tml)
	_marker(root, "PlayerSpawn", Vector2(-400, -40), "")
	_marker(root, "Exit", Vector2(400, -40), "")
	_marker(root, "Ground1", Vector2(-200, -20), "spawn_ground")
	_marker(root, "Ground2", Vector2(0, -20), "spawn_ground")
	_marker(root, "Ground3", Vector2(200, -20), "spawn_ground")
	_marker(root, "Air1", Vector2(-120, -220), "spawn_air")
	_marker(root, "Air2", Vector2(140, -220), "spawn_air")
	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		push_error("pack failed"); quit(); return
	var s := ResourceSaver.save(packed, OUT)
	print("gen_level_template: %s -> %s" % ["OK" if s == OK else "ERR %d" % s, OUT])
	quit()
func _add(root: Node, n: Node) -> void:
	root.add_child(n); n.owner = root
func _marker(root: Node, nm: String, pos: Vector2, grp: String) -> void:
	var m := Marker2D.new(); m.name = nm; m.position = pos
	if grp != "": m.add_to_group(grp, true)
	_add(root, m)
