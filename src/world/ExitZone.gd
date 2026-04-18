extends Area2D

signal player_reached

@export var radius: float = 52.0

var _pulse: float = 0.0


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not ColorSystem.mode_changed.is_connected(_on_mode_changed):
		ColorSystem.mode_changed.connect(_on_mode_changed)


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player_ship"):
		player_reached.emit()


func _on_mode_changed(_in_combat: bool) -> void:
	queue_redraw()


func _draw() -> void:
	var t := _pulse
	var breathe := 0.55 + 0.45 * sin(t * 2.2)
	var color := ColorSystem.ui_color()

	# Outer beacon ring
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48,
			Color(color.r, color.g, color.b, breathe * 0.85), 2.2)

	# Inner fill
	draw_circle(Vector2.ZERO, radius,
			Color(color.r, color.g, color.b, 0.06 * breathe))

	# Second ring — tighter, slower pulse
	var breathe2 := 0.4 + 0.6 * sin(t * 1.1 + 1.0)
	draw_arc(Vector2.ZERO, radius * 0.6, 0.0, TAU, 32,
			Color(color.r, color.g, color.b, breathe2 * 0.4), 1.2)

	# Arrow pointing right — direction of progression
	var arr_color := Color(color.r, color.g, color.b, breathe * 0.9)
	draw_line(Vector2(-18.0, 0.0), Vector2(18.0, 0.0), arr_color, 2.5)
	draw_line(Vector2(8.0, -11.0), Vector2(18.0, 0.0), arr_color, 2.5)
	draw_line(Vector2(8.0, 11.0), Vector2(18.0, 0.0), arr_color, 2.5)

	# "EXIT" label
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-14.0, radius + 16.0), "EXIT",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Color(color.r, color.g, color.b, breathe * 0.7))
