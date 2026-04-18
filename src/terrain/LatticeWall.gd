extends StaticBody2D

@onready var fill = $Fill
@onready var outline = $Outline


func _ready() -> void:
	ColorSystem.mode_changed.connect(_on_mode_changed)
	_update_palette()


func _update_palette() -> void:
	fill.color = ColorSystem.terrain_fill()
	outline.default_color = ColorSystem.terrain_outline()
	outline.width = 2.6 if not ColorSystem.in_combat else 2.0
	queue_redraw()


func _on_mode_changed(_in_combat: bool) -> void:
	_update_palette()


func _draw() -> void:
	var rect := Rect2(Vector2(-72.0, -18.0), Vector2(144.0, 36.0))
	var glow := ColorSystem.glow_color()
	var glow_alpha := 0.12 if not ColorSystem.in_combat else 0.06
	draw_rect(rect.grow(12.0), Color(glow.r, glow.g, glow.b, glow_alpha), true)
	draw_rect(rect, Color(0.02, 0.09, 0.05, 0.65), true)
	var line_color := ColorSystem.terrain_outline()
	line_color.a = 0.38 if not ColorSystem.in_combat else 0.24
	var x := rect.position.x - 12.0
	while x < rect.end.x + 18.0:
		draw_line(Vector2(x, rect.position.y), Vector2(x + 36.0, rect.end.y), line_color, 1.0)
		x += 18.0
	var y := rect.position.y + 6.0
	while y < rect.end.y:
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(line_color.r, line_color.g, line_color.b, 0.12), 1.0)
		y += 12.0
	draw_line(rect.position + Vector2(8.0, 8.0), rect.position + Vector2(24.0, 8.0), Color(0.7, 1.0, 0.8, 0.25), 2.0)
	draw_line(rect.position + Vector2(8.0, 8.0), rect.position + Vector2(8.0, 20.0), Color(0.7, 1.0, 0.8, 0.25), 2.0)
	draw_line(rect.end - Vector2(24.0, 8.0), rect.end - Vector2(8.0, 8.0), Color(0.7, 1.0, 0.8, 0.22), 2.0)
	draw_line(rect.end - Vector2(8.0, 20.0), rect.end - Vector2(8.0, 8.0), Color(0.7, 1.0, 0.8, 0.22), 2.0)
