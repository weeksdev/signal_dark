extends Control

var _active: bool = false
var _selected_index: int = 0
var _pulse: float = 0.0
var _world: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func setup(world: Node) -> void:
	_world = world


func _process(delta: float) -> void:
	if not _active:
		return
	_pulse += delta
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not _can_toggle_pause():
		return
	if _is_pause_event(event):
		if _active:
			resume()
		else:
			_open()
		get_viewport().set_input_as_handled()
		return
	if not _active:
		return
	if _is_up_event(event):
		_selected_index = posmod(_selected_index - 1, 2)
		queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if _is_down_event(event):
		_selected_index = posmod(_selected_index + 1, 2)
		queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if _is_confirm_event(event):
		if _selected_index == 0:
			resume()
		else:
			_exit_to_menu()
		get_viewport().set_input_as_handled()


func resume() -> void:
	_active = false
	visible = false
	get_tree().paused = false


func _open() -> void:
	_active = true
	_selected_index = 0
	visible = true
	get_tree().paused = true
	queue_redraw()


func _exit_to_menu() -> void:
	_active = false
	visible = false
	get_tree().paused = false
	ArcadeState.reset()
	AlertSystem.reset()
	ColorSystem.reset()
	GameState.start_menu()


func _can_toggle_pause() -> bool:
	if _world == null:
		return true
	if _world.has_method("can_pause_game"):
		return _world.can_pause_game()
	return true


func _is_pause_event(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_ESCAPE or event.keycode == KEY_P
	if event is InputEventJoypadButton and event.pressed:
		return event.button_index == JOY_BUTTON_START
	return false


func _is_up_event(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_UP or event.keycode == KEY_W
	if event is InputEventJoypadButton and event.pressed:
		return event.button_index == JOY_BUTTON_DPAD_UP
	return false


func _is_down_event(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_DOWN or event.keycode == KEY_S
	if event is InputEventJoypadButton and event.pressed:
		return event.button_index == JOY_BUTTON_DPAD_DOWN
	return false


func _is_confirm_event(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE
	if event is InputEventJoypadButton and event.pressed:
		return event.button_index == JOY_BUTTON_A or event.button_index == JOY_BUTTON_START
	return false


func _draw() -> void:
	if not _active:
		return
	var vp := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	var cx := vp.x * 0.5
	var cy := vp.y * 0.5
	var alpha := 0.78
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.0, 0.0, alpha), true)
	draw_rect(Rect2(Vector2(cx - 176.0, cy - 96.0), Vector2(352.0, 192.0)), Color(0.02, 0.06, 0.04, 0.92), true)
	draw_rect(Rect2(Vector2(cx - 176.0, cy - 96.0), Vector2(352.0, 192.0)), Color(0.28, 0.86, 0.48, 0.22), false, 1.2)
	draw_string(font, Vector2(cx - 56.0, cy - 48.0), "PAUSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.62, 1.0, 0.74, 0.95))
	draw_string(font, Vector2(cx - 128.0, cy - 22.0), "ESC / START  TO RESUME", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.38, 0.74, 0.48, 0.64))

	var pulse := 0.72 + 0.28 * sin(_pulse * 5.0)
	var options := ["RESUME", "EXIT TO TITLE"]
	for i in range(options.size()):
		var y := cy + 18.0 + i * 34.0
		var selected := i == _selected_index
		if selected:
			draw_rect(Rect2(Vector2(cx - 114.0, y - 16.0), Vector2(228.0, 24.0)), Color(0.16, 0.48, 0.24, 0.22 * pulse), true)
		draw_string(
			font,
			Vector2(cx - 72.0, y),
			("▶ " if selected else "  ") + options[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			Color(0.74, 1.0, 0.82, 0.95) if selected else Color(0.42, 0.78, 0.52, 0.66)
		)
