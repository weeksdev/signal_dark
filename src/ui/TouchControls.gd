extends Node

# Public state — read by InputManager each frame
var touch_move: Vector2 = Vector2.ZERO
var touch_aim: Vector2 = Vector2.ZERO
var touch_fire: bool = false
var touch_dark_mode: bool = false
var touch_boost: bool = false
var touch_hack_button: String = ""

const STICK_MAX_RADIUS := 90.0
const FIRE_THRESHOLD := 0.48

# Left stick tracking
var _left_id: int = -1
var _left_origin: Vector2
var _left_pos: Vector2

# Right stick tracking
var _right_id: int = -1
var _right_origin: Vector2
var _right_pos: Vector2

# Button touch tracking
var _dark_id: int = -1
var _boost_id: int = -1
var _emp_id: int = -1
var _emp_just: bool = false
var _emp_prev_active: bool = false
var _cover_id: int = -1
var _cover_just: bool = false
var _cover_prev_active: bool = false
var _drone_id: int = -1
var _drone_just: bool = false
var _drone_prev_active: bool = false


func _ready() -> void:
	if not OS.has_feature("mobile"):
		return
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	var overlay_script := load("res://src/ui/TouchOverlay.gd")
	var overlay: Control = overlay_script.new()
	overlay.tc = self
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(overlay)


func _process(_delta: float) -> void:
	if not OS.has_feature("mobile"):
		return
	_emp_just = (_emp_id != -1) and not _emp_prev_active
	_emp_prev_active = _emp_id != -1
	_cover_just = (_cover_id != -1) and not _cover_prev_active
	_cover_prev_active = _cover_id != -1
	_drone_just = (_drone_id != -1) and not _drone_prev_active
	_drone_prev_active = _drone_id != -1
	_update_state()


func is_emp_just_pressed_touch() -> bool:
	return _emp_just


func is_cover_just_pressed_touch() -> bool:
	return _cover_just


func is_drone_just_pressed_touch() -> bool:
	return _drone_just


func reset_all() -> void:
	_left_id = -1
	_right_id = -1
	_dark_id = -1
	_boost_id = -1
	_emp_id = -1
	_emp_just = false
	_emp_prev_active = false
	_cover_id = -1
	_cover_just = false
	_cover_prev_active = false
	_drone_id = -1
	_drone_just = false
	_drone_prev_active = false
	touch_move = Vector2.ZERO
	touch_aim = Vector2.ZERO
	touch_fire = false
	touch_dark_mode = false
	touch_boost = false
	touch_hack_button = ""


func button_defs(vp_size: Vector2) -> Array:
	var w := vp_size.x
	var h := vp_size.y
	return [
		{"id": "dark",  "center": Vector2(w * 0.892, h * 0.800), "radius": 38.0},
		{"id": "boost", "center": Vector2(w * 0.812, h * 0.800), "radius": 36.0},
		{"id": "emp",   "center": Vector2(w * 0.892, h * 0.555), "radius": 30.0},
		{"id": "cover", "center": Vector2(w * 0.732, h * 0.690), "radius": 28.0},
		{"id": "drone", "center": Vector2(w * 0.732, h * 0.800), "radius": 28.0},
	]


func handle_touch(event: InputEventScreenTouch) -> void:
	var vp_size := get_viewport().get_visible_rect().size
	var half_x := vp_size.x * 0.5

	if event.pressed:
		var pos := event.position
		if pos.x >= half_x:
			var btn := _button_at(pos, vp_size)
			if btn != "":
				match btn:
					"dark":  _dark_id = event.index
					"boost": _boost_id = event.index
					"emp":   _emp_id = event.index
					"cover": _cover_id = event.index
					"drone": _drone_id = event.index
				return
		if pos.x < half_x:
			if _left_id == -1:
				_left_id = event.index
				_left_origin = pos
				_left_pos = pos
		else:
			if _right_id == -1:
				_right_id = event.index
				_right_origin = pos
				_right_pos = pos
	else:
		var idx := event.index
		if   idx == _left_id:  _left_id = -1
		elif idx == _right_id: _right_id = -1
		elif idx == _dark_id:  _dark_id = -1
		elif idx == _boost_id: _boost_id = -1
		elif idx == _emp_id:   _emp_id = -1
		elif idx == _cover_id: _cover_id = -1
		elif idx == _drone_id: _drone_id = -1


func handle_drag(event: InputEventScreenDrag) -> void:
	var idx := event.index
	if idx == _left_id:
		_left_pos = event.position
	elif idx == _right_id:
		_right_pos = event.position


func _update_state() -> void:
	if _left_id != -1:
		var d := _left_pos - _left_origin
		var len := d.length()
		if len > 6.0:
			touch_move = d / STICK_MAX_RADIUS if len < STICK_MAX_RADIUS else d.normalized()
		else:
			touch_move = Vector2.ZERO
	else:
		touch_move = Vector2.ZERO

	if _right_id != -1:
		var d := _right_pos - _right_origin
		var len := d.length()
		if len > 6.0:
			var v := d / STICK_MAX_RADIUS if len < STICK_MAX_RADIUS else d.normalized()
			touch_aim = v
			touch_fire = v.length() >= FIRE_THRESHOLD
		else:
			touch_aim = Vector2.ZERO
			touch_fire = false
	else:
		touch_aim = Vector2.ZERO
		touch_fire = false

	touch_dark_mode = _dark_id != -1
	touch_boost = _boost_id != -1


func _button_at(pos: Vector2, vp_size: Vector2) -> String:
	for btn in button_defs(vp_size):
		if pos.distance_to(btn["center"]) <= btn["radius"]:
			return btn["id"]
	return ""
