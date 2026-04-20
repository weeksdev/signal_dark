extends Node

const DEADZONE := 0.25
const AIM_DEADZONE := 0.3


func get_move_vector() -> Vector2:
	var keyboard_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var joy_vector := _get_left_stick()
	return joy_vector if joy_vector.length() > DEADZONE else keyboard_vector


func is_dark_mode() -> bool:
	return Input.is_action_pressed("dark_mode") or _left_trigger_pressed()


func is_boost_pressed() -> bool:
	return Input.is_action_pressed("boost") or _right_trigger_pressed()


func is_fire_pressed() -> bool:
	return Input.is_action_pressed("fire") or _joy_button_pressed(JOY_BUTTON_RIGHT_SHOULDER)


func is_suppress_pressed() -> bool:
	return Input.is_action_pressed("suppress") or _joy_button_pressed(JOY_BUTTON_A)


func is_probe_pressed() -> bool:
	return Input.is_action_pressed("probe") or _joy_button_pressed(JOY_BUTTON_X)


func is_hack_pressed() -> bool:
	return Input.is_action_pressed("hack") or _joy_button_pressed(JOY_BUTTON_Y)


func get_hack_button_just_pressed() -> String:
	if Input.is_action_just_pressed("hack_a"):
		return "A"
	if Input.is_action_just_pressed("hack_b"):
		return "B"
	if Input.is_action_just_pressed("hack_x"):
		return "X"
	if Input.is_action_just_pressed("hack_y"):
		return "Y"
	return ""


func is_restart_just_pressed() -> bool:
	return Input.is_action_just_pressed("restart")


func is_right_stick_active() -> bool:
	return _get_right_stick().length() > AIM_DEADZONE


func get_aim_vector(fallback: Vector2) -> Vector2:
	var joy_aim := _get_right_stick()
	if joy_aim.length() > AIM_DEADZONE:
		return joy_aim.normalized()
	return fallback


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
	return Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT) > 0.35


func _right_trigger_pressed() -> bool:
	var device := _first_joypad()
	if device == -1:
		return false
	return Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > 0.35


func _joy_button_pressed(button: JoyButton) -> bool:
	var device := _first_joypad()
	if device == -1:
		return false
	return Input.is_joy_button_pressed(device, button)


func _first_joypad() -> int:
	var devices := Input.get_connected_joypads()
	if devices.is_empty():
		return -1
	return devices[0]


func _apply_deadzone(axis: Vector2, deadzone: float) -> Vector2:
	if axis.length() <= deadzone:
		return Vector2.ZERO
	return axis.normalized() * inverse_lerp(deadzone, 1.0, minf(axis.length(), 1.0))
