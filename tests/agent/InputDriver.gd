extends RefCounted

var _input_manager: Node
var _targets: Dictionary
var _move_to_target: Variant = null
var _aim_target: Variant = null
var _held_until: Dictionary = {}
var _movement_speed_scale: float = 1.0


func setup(input_manager: Node, targets: Dictionary) -> void:
	_input_manager = input_manager
	_targets = targets
	_input_manager.enable_agent_input(true)
	_input_manager.clear_agent_input()


func clear() -> void:
	if _input_manager != null:
		_input_manager.clear_agent_input()
		_input_manager.enable_agent_input(false)


func apply_step(step: Dictionary, now: float) -> void:
	match str(step.get("action", "")):
		"move_to":
			_move_to_target = _vec2(step.get("target", [0, 0]))
			_movement_speed_scale = float(step.get("speed_scale", 1.0))
		"move_vector":
			_input_manager.set_agent_move_vector(_vec2(step.get("direction", [0, 0])).normalized())
			_held_until["__move_vector"] = now + float(step.get("duration", 0.0))
		"aim_at":
			_aim_target = step.get("target", "")
		"hold_input":
			var input := str(step.get("input", ""))
			_input_manager.set_agent_action_pressed(input, true)
			_held_until[input] = now + float(step.get("duration", 0.0))
		"tap_input":
			var tap := str(step.get("input", ""))
			_input_manager.tap_agent_action(tap)
			_held_until[tap] = now + float(step.get("duration", 0.08))


func update(now: float) -> void:
	_update_move_to()
	_update_aim()
	for key in _held_until.keys():
		if now < float(_held_until[key]):
			continue
		if key == "__move_vector":
			_input_manager.set_agent_move_vector(Vector2.ZERO)
		else:
			_input_manager.release_agent_action(str(key))
		_held_until.erase(key)


func has_active_work() -> bool:
	return _move_to_target is Vector2 or not _held_until.is_empty()


func _update_move_to() -> void:
	if not (_move_to_target is Vector2):
		return
	var player_value: Variant = _targets.get("player")
	if player_value == null or not is_instance_valid(player_value):
		return
	var player := player_value as Node2D
	if player == null:
		return
	var offset: Vector2 = _move_to_target - player.global_position
	if offset.length() <= 8.0:
		_input_manager.set_agent_move_vector(Vector2.ZERO)
		_move_to_target = null
		return
	_input_manager.set_agent_move_vector(offset.normalized() * _movement_speed_scale)


func _update_aim() -> void:
	if _aim_target == null:
		return
	var player_value: Variant = _targets.get("player")
	if player_value == null or not is_instance_valid(player_value):
		return
	var player := player_value as Node2D
	if player == null:
		return
	var direction := Vector2.ZERO
	if _aim_target is Array:
		direction = _vec2(_aim_target) - player.global_position
	else:
		var target_value: Variant = _targets.get(str(_aim_target))
		if target_value != null and is_instance_valid(target_value):
			var target := target_value as Node2D
			if target == null:
				return
			direction = target.global_position - player.global_position
		else:
			_aim_target = null
			_input_manager.set_agent_aim_vector(Vector2.ZERO)
			return
	if direction != Vector2.ZERO:
		_input_manager.set_agent_aim_vector(direction.normalized())


func _vec2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
