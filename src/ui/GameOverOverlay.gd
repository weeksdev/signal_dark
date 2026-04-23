extends Control

const FADE_IN_SECS := 0.55
const HOLD_SECS    := 2.0
const TOTAL_SECS   := FADE_IN_SECS + HOLD_SECS

var _active: bool  = false
var _elapsed: float = 0.0
var _accept_input: bool = false


func trigger() -> void:
	_active = true
	_elapsed = 0.0
	_accept_input = false
	queue_redraw()
	# Brief delay before accepting input so a held key doesn't skip instantly
	var t := get_tree().create_timer(1.1)
	t.timeout.connect(func(): _accept_input = true)


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	queue_redraw()
	if _elapsed >= TOTAL_SECS:
		_restart()


func _input(event: InputEvent) -> void:
	if not _active or not _accept_input:
		return
	var pressed := false
	if event is InputEventKey and event.pressed and not event.echo:
		pressed = true
	elif event is InputEventJoypadButton and event.pressed:
		pressed = true
	if pressed:
		_restart()


func _restart() -> void:
	_active = false
	GameState.restart_zone()


func _draw() -> void:
	if not _active:
		return

	var vp    := get_viewport_rect().size
	var alpha := minf(_elapsed / FADE_IN_SECS, 1.0)
	var font  := ThemeDB.fallback_font
	var cx    := vp.x * 0.5

	# Dark overlay
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.0, 0.0, 0.82 * alpha))

	# Red tint pulse
	var pulse := 0.5 + 0.5 * sin(_elapsed * 3.0)
	draw_rect(Rect2(Vector2.ZERO, vp),
			Color(0.55, 0.0, 0.0, 0.06 * alpha * pulse))

	# Failure state — layered signal-loss glow
	var gx := cx - 92.0
	var gy := vp.y * 0.43
	for i in 2:
		var spread := (2 - i) * 3.0
		draw_string(font, Vector2(gx + spread * 0.4, gy + spread * 0.4),
				"SIGNAL LOST", HORIZONTAL_ALIGNMENT_LEFT, -1, 32,
				Color(0.9, 0.1, 0.08, 0.15 * alpha))
	draw_string(font, Vector2(gx, gy), "SIGNAL LOST",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 32,
			Color(1.0, 0.22, 0.18, alpha))
	draw_string(font, Vector2(cx - 88.0, vp.y * 0.495),
			"DARK TRACE TERMINATED",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(0.9, 0.45, 0.4, alpha * 0.72))

	# Prompt or countdown
	if _accept_input:
		if fmod(_elapsed, 1.1) < 0.7:
			draw_string(font, Vector2(cx - 82.0, vp.y * 0.555),
					"PRESS ANY KEY TO RETRY",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
					Color(0.9, 0.45, 0.4, alpha * 0.85))
	else:
		var remaining := maxf(0.0, TOTAL_SECS - _elapsed)
		draw_string(font, Vector2(cx - 10.0, vp.y * 0.555),
				"%.1f" % remaining,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
				Color(1.0, 0.22, 0.18, alpha * 0.55))
