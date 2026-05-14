extends Control

const FADE_IN_DURATION := 0.45

var _active: bool = false
var _elapsed: float = 0.0
var _summary: Dictionary = {}
var _accept_input: bool = false
var _mode: String = "run_end"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func show_summary(summary: Dictionary, mode: String = "run_end") -> void:
	_summary = summary.duplicate(true)
	_mode = mode
	_active = true
	_elapsed = 0.0
	_accept_input = false
	visible = true
	queue_redraw()
	var t := get_tree().create_timer(0.7)
	t.timeout.connect(func(): _accept_input = true)


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not _active or not _accept_input:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if _mode == "floor_clear":
					_continue_run()
				else:
					_restart_same_seed()
			KEY_R:
				if _mode != "floor_clear":
					_reroll_seed()
			KEY_ESCAPE:
				_return_to_title()
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_A, JOY_BUTTON_START:
				if _mode == "floor_clear":
					_continue_run()
				else:
					_restart_same_seed()
			JOY_BUTTON_X:
				if _mode != "floor_clear":
					_reroll_seed()
			JOY_BUTTON_B, JOY_BUTTON_BACK:
				_return_to_title()
	elif OS.has_feature("mobile") and event is InputEventScreenTouch and event.pressed:
		get_viewport().set_input_as_handled()
		if _mode == "floor_clear":
			_continue_run()
		else:
			_restart_same_seed()


func _continue_run() -> void:
	_active = false
	visible = false
	GameState.advance_zone()


func _restart_same_seed() -> void:
	_active = false
	visible = false
	GameState.start_arcade_run(ArcadeState.run_seed, ArcadeState.difficulty)


func _reroll_seed() -> void:
	_active = false
	visible = false
	GameState.start_arcade_run(randi() % 90000 + 10000, ArcadeState.difficulty)


func _return_to_title() -> void:
	_active = false
	visible = false
	ArcadeState.reset()
	GameState.start_menu()


func _draw() -> void:
	if not _active:
		return
	var vp := get_viewport_rect().size
	var alpha := minf(_elapsed / FADE_IN_DURATION, 1.0)
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.0, 0.0, 0.86 * alpha), true)
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.12, 0.08, 0.08 * alpha), true)

	var panel := Rect2(Vector2(vp.x * 0.5 - 220.0, vp.y * 0.5 - 165.0), Vector2(440.0, 330.0))
	draw_rect(panel, Color(0.02, 0.05, 0.04, 0.95 * alpha), true)
	draw_rect(panel, Color(0.35, 0.92, 0.58, 0.18 * alpha), false, 1.0)

	var complete := bool(_summary.get("completed", false))
	var heading := "FLOOR CLEARED" if _mode == "floor_clear" else ("ARCADE CLEARED" if complete else "SIGNAL LOST")
	var heading_color := Color(0.56, 1.0, 0.68, alpha) if (_mode == "floor_clear" or complete) else Color(1.0, 0.26, 0.2, alpha)
	draw_string(font, panel.position + Vector2(24.0, 34.0), heading, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, heading_color)
	draw_string(font, panel.position + Vector2(24.0, 54.0), "%s  //  %s" % [_summary.get("difficulty", "MEDIUM"), _summary.get("rating", "BURNED")], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.74, 0.96, 0.84, alpha * 0.9))
	draw_string(font, panel.position + Vector2(panel.size.x - 124.0, 34.0), "SCORE %05d" % int(_summary.get("score", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.88, 1.0, 0.92, alpha * 0.95))

	var rows := [
		["SEED", str(_summary.get("seed", 0))],
		["FLOORS", "%d / %d" % [int(_summary.get("floors_cleared", 0)), int(_summary.get("floor_count", 4))]],
		["TIME", "%.1fs" % float(_summary.get("time_seconds", 0.0))],
		["KILLS", str(_summary.get("kills", 0))],
		["SUPPRESSED", str(_summary.get("suppressed_kills", 0))],
		["ALERTS", str(_summary.get("alerts_triggered", 0))],
		["HACKS", str(_summary.get("hacks_completed", 0))],
		["PROBES", str(_summary.get("probes_used", 0))],
		["DISCIPLINE", "%d%%" % int(_summary.get("signal_discipline", 0))],
	]
	var y := panel.position.y + 92.0
	for row in rows:
		draw_string(font, panel.position + Vector2(28.0, y), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.46, 0.86, 0.58, alpha * 0.78))
		draw_string(font, panel.position + Vector2(220.0, y), row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.90, 0.96, 0.92, alpha * 0.95))
		y += 22.0

	var prompt_color := Color(0.72, 0.94, 0.80, alpha * (0.35 + 0.65 * absf(sin(_elapsed * 3.0))))
	if _mode == "floor_clear":
		draw_string(font, panel.position + Vector2(28.0, panel.size.y - 44.0), "ENTER/A  NEXT FLOOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, prompt_color)
		draw_string(font, panel.position + Vector2(28.0, panel.size.y - 28.0), "ESC/B  TITLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.52, 0.82, 0.62, alpha * 0.82))
	else:
		draw_string(font, panel.position + Vector2(28.0, panel.size.y - 44.0), "ENTER/A  RESTART SAME SEED", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, prompt_color)
		draw_string(font, panel.position + Vector2(28.0, panel.size.y - 28.0), "R/X  NEW SEED     ESC/B  TITLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.52, 0.82, 0.62, alpha * 0.82))
