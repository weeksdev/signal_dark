extends Node2D

# Loads each story zone, zooms out to fit, disables overlays, and saves screenshots to /tmp/.
# Run: godot --path . res://tools/MapScreenshot.tscn

const SCENES := [
	"res://src/world/World.tscn",
	"res://src/world/World02.tscn",
	"res://src/world/World03.tscn",
	"res://src/world/World04.tscn",
]

var _idx := 0
var _world: Node = null
var _cam: Camera2D = null
var _tick := 0


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_load_world()


func _load_world() -> void:
	if _idx >= SCENES.size():
		print("All screenshots done.")
		get_tree().quit()
		return
	print("Loading zone %d: %s" % [_idx + 1, SCENES[_idx]])
	var s: PackedScene = load(SCENES[_idx])
	if s == null:
		print("FAILED to load")
		_idx += 1
		_load_world()
		return
	_world = s.instantiate()
	add_child(_world)
	_tick = 0


func _process(_delta: float) -> void:
	if _world == null:
		return
	_tick += 1
	if _tick == 4:
		_prep()
	elif _tick == 7:
		_snap()
		_cleanup()
		_idx += 1
		_load_world()


func _prep() -> void:
	# Disable canvas layer overlays (stealth shader, HUD, etc.)
	var cl := _world.get_node_or_null("CanvasLayer")
	if cl:
		for n: String in ["StealthOverlay", "BackBufferCopy", "HUD",
				"GameOverOverlay", "ZoneCompleteOverlay"]:
			var c := cl.get_node_or_null(n)
			if c:
				c.visible = false

	# Kill ship camera so our overview cam takes over
	var ship := _world.get_node_or_null("Ship")
	if ship:
		var c2d := ship.get_node_or_null("Camera2D")
		if c2d:
			c2d.enabled = false

	# Compute world bounds from Grid.world_rect
	var rect := Rect2(-96, 400, 4096, 1400)
	var grid := _world.get_node_or_null("Grid")
	if grid:
		var r = grid.get("world_rect")
		if r is Rect2:
			rect = r

	# Create overview camera sized to fit the level with a small margin
	if _cam:
		_cam.queue_free()
	_cam = Camera2D.new()
	var vp := get_viewport().get_visible_rect().size
	var zoom := minf(vp.x / rect.size.x, vp.y / rect.size.y) * 0.88
	_cam.zoom = Vector2(zoom, zoom)
	_cam.global_position = rect.get_center()
	add_child(_cam)
	_cam.make_current()


func _snap() -> void:
	var path := "/tmp/zone%02d_map.png" % (_idx + 1)
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("Saved: %s" % path)


func _cleanup() -> void:
	if _cam:
		remove_child(_cam)
		_cam.queue_free()
		_cam = null
	if _world:
		remove_child(_world)
		_world.queue_free()
		_world = null
