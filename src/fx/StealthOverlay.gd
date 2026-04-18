extends Control

var drift: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ColorSystem.mode_changed.connect(_on_mode_changed)


func _process(delta: float) -> void:
	drift += delta
	queue_redraw()


func _on_mode_changed(_in_combat: bool) -> void:
	queue_redraw()


func _draw() -> void:
	var rect := get_viewport_rect()
	var center := rect.size * 0.5
	if not ColorSystem.in_combat:
		for i in range(8):
			var radius := 130.0 + i * 42.0
			var alpha := 0.03 - i * 0.0028
			draw_circle(center + Vector2(sin(drift * 0.17), cos(drift * 0.13)) * 18.0, radius, Color(0.0, 0.18, 0.08, maxf(alpha, 0.003)))
		var edge := 42.0
		draw_rect(Rect2(Vector2.ZERO, Vector2(rect.size.x, edge)), Color(0, 0, 0, 0.22), true)
		draw_rect(Rect2(Vector2(0, rect.size.y - edge), Vector2(rect.size.x, edge)), Color(0, 0, 0, 0.24), true)
		draw_rect(Rect2(Vector2.ZERO, Vector2(edge, rect.size.y)), Color(0, 0, 0, 0.18), true)
		draw_rect(Rect2(Vector2(rect.size.x - edge, 0), Vector2(edge, rect.size.y)), Color(0, 0, 0, 0.18), true)
		var y := 0.0
		while y < rect.size.y:
			var line_alpha := 0.03 + 0.01 * sin((y * 0.05) + drift * 1.7)
			draw_line(Vector2(0.0, y), Vector2(rect.size.x, y), Color(0.4, 1.0, 0.7, line_alpha), 1.0)
			y += 3.0
	else:
		for i in range(4):
			var radius_c := 150.0 + i * 56.0
			var alpha_c := 0.022 - i * 0.004
			draw_circle(center, radius_c, Color(0.05, 0.08, 0.26, maxf(alpha_c, 0.004)))
