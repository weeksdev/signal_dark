extends Control

var tc: Node  # TouchControls reference


func _process(_delta: float) -> void:
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		tc.handle_touch(event)
	elif event is InputEventScreenDrag:
		tc.handle_drag(event)


func _draw() -> void:
	if tc == null:
		return
	var vp := get_viewport_rect().size
	_draw_stick(tc._left_id, tc._left_origin, tc._left_pos)
	_draw_stick(tc._right_id, tc._right_origin, tc._right_pos)
	_draw_buttons(tc.button_defs(vp))


func _draw_stick(touch_id: int, origin: Vector2, pos: Vector2) -> void:
	if touch_id == -1:
		return
	var d := pos - origin
	var len := d.length()
	var knob_pos := origin + d.normalized() * minf(len, tc.STICK_MAX_RADIUS) if len > 6.0 else origin

	draw_arc(origin, tc.STICK_MAX_RADIUS, 0.0, TAU, 52, Color(1.0, 1.0, 1.0, 0.13), 1.5)
	draw_circle(origin, 6.0, Color(1.0, 1.0, 1.0, 0.08))
	draw_circle(knob_pos, 26.0, Color(1.0, 1.0, 1.0, 0.16))
	draw_arc(knob_pos, 26.0, 0.0, TAU, 36, Color(1.0, 1.0, 1.0, 0.28), 1.8)


func _draw_buttons(defs: Array) -> void:
	var active := {
		"dark":  tc._dark_id != -1,
		"boost": tc._boost_id != -1,
		"emp":   tc._emp_id != -1,
	}
	var labels := {"dark": "STL", "boost": "BST", "emp": "EMP"}
	var font := ThemeDB.fallback_font

	for btn in defs:
		var is_active: bool = active.get(btn["id"], false)
		var ring_alpha := 0.34 if is_active else 0.18
		var fill_alpha := 0.16 if is_active else 0.07
		var center: Vector2 = btn["center"]
		var radius: float = btn["radius"]

		draw_circle(center, radius, Color(1.0, 1.0, 1.0, fill_alpha))
		draw_arc(center, radius, 0.0, TAU, 36, Color(1.0, 1.0, 1.0, ring_alpha), 1.5)

		var label: String = labels.get(btn["id"], "?")
		var font_size := 10
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var text_pos := center + Vector2(-text_size.x * 0.5, text_size.y * 0.35)
		draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
				Color(1.0, 1.0, 1.0, ring_alpha * 1.6))
