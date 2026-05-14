extends RefCounted

var _tree: SceneTree
var _targets: Dictionary


func setup(tree: SceneTree, targets: Dictionary) -> void:
	_tree = tree
	_targets = targets


func evaluate(condition: String, message: String = "") -> Dictionary:
	var normalized := condition.strip_edges()
	var parts := normalized.split(" ", false)
	var ok := false
	var actual: Variant = null
	var expected: Variant = null
	if parts.size() == 3:
		actual = _value_for_token(parts[0])
		expected = _literal(parts[2])
		ok = _compare(actual, parts[1], expected)
	elif parts.size() == 4 and parts[0] == "object_exists":
		actual = _object_exists(parts[1])
		expected = _literal(parts[3])
		ok = _compare(actual, parts[2], expected)
	else:
		actual = _value_for_token(normalized)
		expected = true
		ok = bool(actual)
	return {
		"ok": ok,
		"condition": condition,
		"message": message,
		"actual": actual,
		"expected": expected,
	}


func _value_for_token(token: String) -> Variant:
	if token == "enemy_count":
		return _alive_enemy_count()
	if token == "drone_count":
		return _tree.get_nodes_in_group("player_drone").size()
	if token == "search_active":
		return _search_active()
	if token == "player_alive":
		var player := _tree.get_first_node_in_group("player_ship")
		return player != null and not bool(player.get("dead"))
	if token == "scene_loaded":
		return _tree.current_scene != null
	if token == "player_inside_bounds":
		return _player_inside_bounds()
	if token.begins_with("object_exists(") and token.ends_with(")"):
		return _object_exists(token.trim_prefix("object_exists(").trim_suffix(")"))
	if token.begins_with("enemy_health(") and token.ends_with(")"):
		var id := token.trim_prefix("enemy_health(").trim_suffix(")")
		var enemy: Node = _targets.get(id)
		return 1 if enemy != null and is_instance_valid(enemy) and bool(enemy.get("is_alive")) else 0
	if token.begins_with("enemy_distance_to_search_target(") and token.ends_with(")"):
		var enemy_id := token.trim_prefix("enemy_distance_to_search_target(").trim_suffix(")")
		return _enemy_distance_to_search_target(enemy_id)
	if token.begins_with("enemy_distance_to_player(") and token.ends_with(")"):
		var enemy_id := token.trim_prefix("enemy_distance_to_player(").trim_suffix(")")
		return _enemy_distance_to_player(enemy_id)
	if token == "cover_active":
		var player := _tree.get_first_node_in_group("player_ship")
		return player != null and bool(player.get("cover_active"))
	return null


func _compare(actual: Variant, operator: String, expected: Variant) -> bool:
	match operator:
		"==":
			return actual == expected
		"!=":
			return actual != expected
		">":
			return float(actual) > float(expected)
		">=":
			return float(actual) >= float(expected)
		"<":
			return float(actual) < float(expected)
		"<=":
			return float(actual) <= float(expected)
		_:
			return false


func _literal(value: String) -> Variant:
	var lower := value.to_lower()
	if lower == "true":
		return true
	if lower == "false":
		return false
	if value.is_valid_int():
		return int(value)
	if value.is_valid_float():
		return float(value)
	return value


func _alive_enemy_count() -> int:
	var count := 0
	for enemy in _tree.get_nodes_in_group("zone_enemy"):
		if bool(enemy.get("is_alive")):
			count += 1
	return count


func _search_active() -> bool:
	var world := _tree.current_scene
	return world != null and world.has_method("is_search_active") and bool(world.call("is_search_active"))


func _enemy_distance_to_search_target(id: String) -> float:
	var enemy_value: Variant = _targets.get(id)
	if enemy_value == null or not is_instance_valid(enemy_value):
		return INF
	var enemy := enemy_value as Node2D
	if enemy == null:
		return INF
	var world := _tree.current_scene
	if world == null or not world.has_method("get_search_target"):
		return INF
	var target: Variant = world.call("get_search_target")
	if not (target is Vector2):
		return INF
	return snappedf(enemy.global_position.distance_to(target), 0.01)


func _enemy_distance_to_player(id: String) -> float:
	var enemy_value: Variant = _targets.get(id)
	if enemy_value == null or not is_instance_valid(enemy_value):
		return INF
	var enemy := enemy_value as Node2D
	var player := _tree.get_first_node_in_group("player_ship") as Node2D
	if enemy == null or player == null:
		return INF
	return snappedf(enemy.global_position.distance_to(player.global_position), 0.01)


func _object_exists(id: String) -> bool:
	var node: Node = _targets.get(id)
	return node != null and is_instance_valid(node)


func _player_inside_bounds() -> bool:
	var player := _tree.get_first_node_in_group("player_ship") as Node2D
	if player == null:
		return false
	var grid := _tree.current_scene.get_node_or_null("Grid") if _tree.current_scene != null else null
	if grid != null:
		var world_rect: Variant = grid.get("world_rect")
		if world_rect is Rect2:
			return (world_rect as Rect2).has_point(player.global_position)
	return true
