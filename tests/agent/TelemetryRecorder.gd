extends RefCounted

var _tree: SceneTree
var _file: FileAccess
var _events: Array[String] = []


func setup(tree: SceneTree, artifact_dir_abs: String) -> bool:
	_tree = tree
	_file = FileAccess.open(artifact_dir_abs.path_join("telemetry.jsonl"), FileAccess.WRITE)
	return _file != null


func record_event(event: String) -> void:
	_events.append(event)


func sample(label: String = "") -> Dictionary:
	var player := _player_node()
	var enemies: Array[Dictionary] = []
	for enemy in _tree.get_nodes_in_group("zone_enemy"):
		if not (enemy is Node2D):
			continue
		var enemy_node := enemy as Node2D
		enemies.append({
			"id": str(enemy_node.get_meta("agent_id", enemy_node.name)),
			"type": str(enemy_node.get_meta("agent_type", enemy_node.scene_file_path.get_file().get_basename())),
			"position": _vec(enemy_node.global_position),
			"alive": _node_bool(enemy_node, "is_alive", true),
			"combat_active": _node_bool(enemy_node, "combat_active", false),
			"alerting": enemy_node.call("is_alerting_state") if enemy_node.has_method("is_alerting_state") else false,
		})
	var drones: Array[Dictionary] = []
	for drone in _tree.get_nodes_in_group("player_drone"):
		if not (drone is Node2D):
			continue
		var drone_node := drone as Node2D
		drones.append({
			"id": str(drone_node.name),
			"position": _vec(drone_node.global_position),
		})
	var world := _tree.current_scene
	var search_active := false
	var search_target := Vector2.ZERO
	var search_reason := ""
	if world != null and world.has_method("is_search_active"):
		search_active = bool(world.call("is_search_active"))
	if world != null and world.has_method("get_search_target"):
		var target: Variant = world.call("get_search_target")
		if target is Vector2:
			search_target = target
	if world != null and world.has_method("get_search_reason"):
		search_reason = str(world.call("get_search_reason"))
	var state := {
		"time_msec": Time.get_ticks_msec(),
		"label": label,
		"player": {},
		"enemies": enemies,
		"drones": drones,
		"enemy_count": _alive_enemy_count(),
		"drone_count": drones.size(),
		"search": {
			"active": search_active,
			"target": _vec(search_target),
			"reason": search_reason,
		},
		"events_since_last_capture": _events.duplicate(),
	}
	if player != null:
		state["player"] = {
			"id": str(player.get_meta("agent_id", "player")),
			"position": _vec(player.global_position),
			"alive": not bool(player.get("dead")),
			"dark_mode": bool(player.get("dark_mode")),
			"in_dark_pocket": bool(player.get("in_dark_pocket")),
			"cover_active": bool(player.get("cover_active")),
		}
	_events.clear()
	return state


func write_sample(sample_data: Dictionary) -> void:
	if _file == null:
		return
	_file.store_line(JSON.stringify(sample_data))
	_file.flush()


func close() -> void:
	if _file != null:
		_file.close()
		_file = null


func _player_node() -> Node2D:
	var player := _tree.get_first_node_in_group("player_ship")
	return player as Node2D


func _alive_enemy_count() -> int:
	var count := 0
	for enemy in _tree.get_nodes_in_group("zone_enemy"):
		if bool(enemy.get("is_alive")):
			count += 1
	return count


func _vec(value: Vector2) -> Array[float]:
	return [snappedf(value.x, 0.01), snappedf(value.y, 0.01)]


func _node_bool(node: Node, property: String, default_value: bool) -> bool:
	var value: Variant = node.get(property)
	return default_value if value == null else bool(value)
