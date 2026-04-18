extends Control

var mode_text: String = "MODE: STEALTH"
var emission_value: float = 8.0
var alert_value: float = 0.0
var status_text: String = "PROBES 3   SPEED 000"
var blink: float = 0.0


func _ready() -> void:
	ColorSystem.mode_changed.connect(_on_mode_changed)
	AlertSystem.emission_changed.connect(_on_emission_changed)
	AlertSystem.alert_changed.connect(_on_alert_changed)
	_on_mode_changed(ColorSystem.in_combat)
	_on_emission_changed(AlertSystem.emission)
	_on_alert_changed(AlertSystem.alert_level)


func _process(delta: float) -> void:
	blink += delta
	var ship = get_tree().get_first_node_in_group("player_ship")
	if ship != null:
		status_text = "PROBES %d   SPEED %03d" % [ship.probe_charges, int(ship.velocity.length())]
	queue_redraw()


func _on_emission_changed(value: float) -> void:
	emission_value = value * 100.0
	queue_redraw()


func _on_alert_changed(value: float) -> void:
	alert_value = value * 100.0
	queue_redraw()


func _on_mode_changed(in_combat: bool) -> void:
	mode_text = "MODE: COMBAT" if in_combat else "MODE: STEALTH"
	queue_redraw()


func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	var panel_width := minf(viewport_size.x - 32.0, 420.0)
	var panel := Rect2(Vector2(16.0, 16.0), Vector2(panel_width, 78.0))
	var inner := panel.grow(-8.0)
	var ui_color := ColorSystem.ui_color()
	draw_rect(panel, Color(0.0, 0.0, 0.0, 0.3), true)
	draw_rect(inner, Color(0.01, 0.04, 0.03, 0.74), true)
	draw_rect(inner.grow(1.0), Color(0.0, 0.2, 0.1, 0.12), false, 1.0)
	draw_line(Vector2(inner.position.x, inner.position.y + 20.0), Vector2(inner.end.x, inner.position.y + 20.0), Color(ui_color.r, ui_color.g, ui_color.b, 0.14), 1.0)

	var font := ThemeDB.fallback_font
	var font_size := 11
	var small_size := 10
	var tiny_size := 8
	draw_string(font, inner.position + Vector2(8.0, 16.0), mode_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, ui_color)
	draw_string(font, Vector2(inner.end.x - 48.0, inner.position.y + 16.0), "%02d%%" % int(round(emission_value)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.85, 1.0, 0.9, 0.95))
	draw_string(font, Vector2(inner.end.x - 48.0, inner.position.y + 38.0), "%02d%%" % int(round(alert_value)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.85, 1.0, 0.9, 0.95))

	var bar_width := minf(250.0, inner.size.x - 72.0)
	_draw_bar(Rect2(inner.position + Vector2(8.0, 26.0), Vector2(bar_width, 8.0)), emission_value / 100.0, Color(0.2, 1.0, 0.45, 0.9), true)
	_draw_bar(Rect2(inner.position + Vector2(8.0, 44.0), Vector2(bar_width, 8.0)), alert_value / 100.0, Color(0.95, 0.35, 0.35, 0.9), false)
	draw_string(font, inner.position + Vector2(8.0, 66.0), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, small_size, ui_color)


func _draw_bar(rect: Rect2, ratio: float, tint: Color, segmented: bool) -> void:
	draw_rect(rect, Color(0.0, 0.0, 0.0, 0.4), true)
	draw_rect(rect, Color(tint.r, tint.g, tint.b, 0.2), false, 1.0)
	var fill_rect := Rect2(rect.position + Vector2(2.0, 2.0), Vector2((rect.size.x - 4.0) * clampf(ratio, 0.0, 1.0), rect.size.y - 4.0))
	if fill_rect.size.x > 0.0:
		draw_rect(fill_rect, tint, true)
	if segmented:
		var x := rect.position.x + 6.0
		while x < rect.end.x:
			draw_line(Vector2(x, rect.position.y + 1.0), Vector2(x, rect.end.y - 1.0), Color(0.0, 0.0, 0.0, 0.28), 1.0)
			x += 18.0
