extends SceneTree

# Loads the real ArcadeWorld.tscn (same path the game uses) and verifies
# that enemies are actually placed and present in the scene tree.

const ARCADE_WORLD_SCENE := "res://src/world/ArcadeWorld.tscn"

var _world: Node = null
var _seed_val: int = 0
var _floor_idx: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var test_cases: Array[Dictionary] = [
		{"seed": 12345, "floor": 0},
		{"seed": 12345, "floor": 1},
		{"seed": 99999, "floor": 0},
		{"seed": 54321, "floor": 2},
	]

	var arcade_state := get_root().get_node_or_null("/root/ArcadeState")
	var alert_system := get_root().get_node_or_null("/root/AlertSystem")
	var color_system := get_root().get_node_or_null("/root/ColorSystem")

	if arcade_state == null:
		push_error("[arcade_enemy_count] FAIL: ArcadeState autoload missing")
		quit(1)
		return

	var failures: Array[String] = []

	for tc in test_cases:
		_seed_val = int(tc["seed"])
		_floor_idx = int(tc["floor"])

		arcade_state.start_run(_seed_val)
		arcade_state.floor_index = _floor_idx
		if alert_system != null and alert_system.has_method("reset"):
			alert_system.reset()
		if color_system != null and color_system.has_method("reset"):
			color_system.reset()

		var packed: PackedScene = load(ARCADE_WORLD_SCENE)
		if packed == null:
			push_error("[arcade_enemy_count] FAIL: could not load ArcadeWorld.tscn")
			quit(1)
			return

		_world = packed.instantiate()
		root.add_child(_world)
		current_scene = _world

		# Give the world a few frames to finish _ready and place enemies
		await process_frame
		await process_frame
		await process_frame

		var enemies := get_nodes_in_group("zone_enemy")
		var count := enemies.size()

		if count > 0:
			print("[arcade_enemy_count] seed=%d floor=%d: %d enemies — OK" % [_seed_val, _floor_idx, count])
		else:
			failures.append("seed=%d floor=%d: 0 enemies in zone_enemy group" % [_seed_val, _floor_idx])

		_world.queue_free()
		await process_frame
		await process_frame

	if failures.is_empty():
		print("[arcade_enemy_count] PASS — enemies present across all %d configurations" % test_cases.size())
		quit(0)
	else:
		push_error("[arcade_enemy_count] FAIL:")
		for f in failures:
			push_error("  " + f)
		quit(1)
