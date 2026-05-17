extends Node

signal controller_layout_changed(using_controller: bool)

const DEADZONE := 0.25
const AIM_DEADZONE := 0.3

var _controller_present: bool = false
var _agent_input_enabled: bool = false
var _agent_move_vector: Vector2 = Vector2.ZERO
var _agent_aim_vector: Vector2 = Vector2.ZERO
var _agent_actions_pressed: Dictionary = {}
var _agent_actions_just_pressed: Dictionary = {}
var _joy_buttons_just_pressed: Dictionary = {}


func _ready() -> void:
	_controller_present = not Input.get_connected_joypads().is_empty()
	set_process(true)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		_joy_buttons_just_pressed[int(event.button_index)] = true


func _process(_delta: float) -> void:
	_joy_buttons_just_pressed.clear()
	var connected := not Input.get_connected_joypads().is_empty()
	if connected == _controller_present:
		return
	_controller_present = connected
	controller_layout_changed.emit(_controller_present)


func get_move_vector() -> Vector2:
	if _agent_input_enabled:
		return _agent_move_vector
	var joy_vector := _get_left_stick()
	if joy_vector != Vector2.ZERO:
		return joy_vector
	if OS.has_feature("mobile"):
		return TouchControls.touch_move
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func is_dark_mode() -> bool:
	if _agent_input_enabled and _agent_actions_pressed.get("dark_mode", false):
		return true
	if OS.has_feature("mobile") and TouchControls.touch_dark_mode:
		return true
	return Input.is_action_pressed("dark_mode") or _left_trigger_pressed()


func is_boost_pressed() -> bool:
	if _agent_input_enabled and _agent_actions_pressed.get("boost", false):
		return true
	if OS.has_feature("mobile"):
		return TouchControls.touch_boost
	return Input.is_action_pressed("boost") or _right_trigger_pressed()


func is_fire_pressed() -> bool:
	if _agent_input_enabled and _agent_actions_pressed.get("fire", false):
		return true
	if OS.has_feature("mobile"):
		return TouchControls.touch_fire or _joy_button_pressed(JOY_BUTTON_RIGHT_SHOULDER) or _right_trigger_pressed()
	return Input.is_action_pressed("fire") or _joy_button_pressed(JOY_BUTTON_RIGHT_SHOULDER)


func is_suppress_pressed() -> bool:
	if _agent_input_enabled and _agent_actions_pressed.get("suppress", false):
		return true
	return Input.is_action_pressed("suppress") or _joy_button_pressed(JOY_BUTTON_A)


func is_probe_pressed() -> bool:
	if _agent_input_enabled and _agent_actions_pressed.get("probe", false):
		return true
	return Input.is_action_pressed("probe") or _joy_button_pressed(JOY_BUTTON_X)


func is_hack_pressed() -> bool:
	if _agent_input_enabled and _agent_actions_pressed.get("hack", false):
		return true
	if OS.has_feature("mobile"):
		return TouchControls.touch_hack
	return Input.is_action_pressed("hack") or _joy_button_pressed(JOY_BUTTON_Y)


func is_hack_just_pressed() -> bool:
	if _agent_input_enabled and _consume_agent_just_pressed("hack"):
		return true
	if OS.has_feature("mobile"):
		return TouchControls.is_hack_just_pressed_touch()
	return Input.is_action_just_pressed("hack") or _joy_button_just_pressed(JOY_BUTTON_Y)


func is_emp_just_pressed() -> bool:
	if _agent_input_enabled and _consume_agent_just_pressed("emp"):
		return true
	if OS.has_feature("mobile") and TouchControls.is_emp_just_pressed_touch():
		return true
	return Input.is_action_just_pressed("emp")


func is_cover_just_pressed() -> bool:
	if _agent_input_enabled and _consume_agent_just_pressed("cover"):
		return true
	if OS.has_feature("mobile") and TouchControls.is_cover_just_pressed_touch():
		return true
	if InputMap.has_action("cover"):
		return Input.is_action_just_pressed("cover")
	return false


func is_drone_just_pressed() -> bool:
	if _agent_input_enabled and _consume_agent_just_pressed("drone"):
		return true
	if OS.has_feature("mobile") and TouchControls.is_drone_just_pressed_touch():
		return true
	if InputMap.has_action("drone"):
		return Input.is_action_just_pressed("drone")
	return false


func is_right_stick_active() -> bool:
	if _agent_input_enabled:
		return _agent_aim_vector.length() > AIM_DEADZONE
	if OS.has_feature("mobile") and TouchControls.touch_aim.length() > AIM_DEADZONE:
		return true
	return _get_right_stick().length() > AIM_DEADZONE


func get_aim_vector(fallback: Vector2) -> Vector2:
	if _agent_input_enabled and _agent_aim_vector.length() > AIM_DEADZONE:
		return _agent_aim_vector.normalized()
	var joy_aim := _get_right_stick()
	if joy_aim.length() > AIM_DEADZONE:
		return joy_aim.normalized()
	if OS.has_feature("mobile") and TouchControls.touch_aim.length() > AIM_DEADZONE:
		return TouchControls.touch_aim.normalized()
	return fallback


func get_hack_button_just_pressed() -> String:
	if _agent_input_enabled:
		for token in ["A", "B", "X", "Y"]:
			if _consume_agent_just_pressed("hack_%s" % token.to_lower()):
				return token
	if OS.has_feature("mobile"):
		var btn := TouchControls.touch_hack_button
		TouchControls.touch_hack_button = ""
		return btn
	if Input.is_action_just_pressed("hack_a"):
		return "A"
	if Input.is_action_just_pressed("hack_b"):
		return "B"
	if Input.is_action_just_pressed("hack_x"):
		return "X"
	if Input.is_action_just_pressed("hack_y"):
		return "Y"
	return ""


func has_controller() -> bool:
	return _controller_present


func get_hack_button_display(token: String) -> String:
	if has_controller():
		return token
	match token:
		"A":
			return "J"
		"B":
			return "K"
		"X":
			return "U"
		"Y":
			return "I"
		_:
			return token


func is_restart_just_pressed() -> bool:
	if _agent_input_enabled and _consume_agent_just_pressed("restart"):
		return true
	return Input.is_action_just_pressed("restart")


func enable_agent_input(enabled: bool) -> void:
	_agent_input_enabled = enabled
	if not enabled:
		clear_agent_input()


func clear_agent_input() -> void:
	_agent_move_vector = Vector2.ZERO
	_agent_aim_vector = Vector2.ZERO
	_agent_actions_pressed.clear()
	_agent_actions_just_pressed.clear()


func set_agent_move_vector(move_vector: Vector2) -> void:
	_agent_move_vector = move_vector.limit_length(1.0)


func set_agent_aim_vector(aim_vector: Vector2) -> void:
	_agent_aim_vector = aim_vector.limit_length(1.0)


func set_agent_action_pressed(action: String, pressed: bool) -> void:
	if pressed:
		_agent_actions_pressed[action] = true
	else:
		_agent_actions_pressed.erase(action)


func tap_agent_action(action: String) -> void:
	_agent_actions_pressed[action] = true
	_agent_actions_just_pressed[action] = true


func release_agent_action(action: String) -> void:
	_agent_actions_pressed.erase(action)


func _consume_agent_just_pressed(action: String) -> bool:
	if not _agent_actions_just_pressed.get(action, false):
		return false
	_agent_actions_just_pressed.erase(action)
	return true


func _get_left_stick() -> Vector2:
	var device := _first_joypad()
	if device == -1:
		return Vector2.ZERO
	var axis := Vector2(
		Input.get_joy_axis(device, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
	)
	return _apply_deadzone(axis, DEADZONE)


func _get_right_stick() -> Vector2:
	var device := _first_joypad()
	if device == -1:
		return Vector2.ZERO
	var axis := Vector2(
		Input.get_joy_axis(device, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)
	)
	return _apply_deadzone(axis, AIM_DEADZONE)


func _left_trigger_pressed() -> bool:
	var device := _first_joypad()
	if device == -1:
		return false
	return _normalize_trigger(Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT)) > 0.35


func _right_trigger_pressed() -> bool:
	var device := _first_joypad()
	if device == -1:
		return false
	return _normalize_trigger(Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT)) > 0.35


func _normalize_trigger(raw: float) -> float:
	# macOS reports triggers on a -1..1 scale; normalize to 0..1
	return (raw + 1.0) * 0.5 if raw < 0.0 else raw


func _joy_button_pressed(button: JoyButton) -> bool:
	var device := _first_joypad()
	if device == -1:
		return false
	return Input.is_joy_button_pressed(device, button)


func _joy_button_just_pressed(button: JoyButton) -> bool:
	return _joy_buttons_just_pressed.get(int(button), false)


func _first_joypad() -> int:
	var devices := Input.get_connected_joypads()
	if devices.is_empty():
		return -1
	return devices[0]


func _apply_deadzone(axis: Vector2, deadzone: float) -> Vector2:
	if axis.length() <= deadzone:
		return Vector2.ZERO
	return axis.normalized() * inverse_lerp(deadzone, 1.0, minf(axis.length(), 1.0))
