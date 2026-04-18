extends Node2D

@export var duration: float = 0.45

var elapsed: float = 0.0
var combat_mode: bool = false
var signature_color := Color("00ff88")


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(elapsed / duration, 0.0, 1.0)
	var radius := lerpf(6.0, 48.0, t)
	if combat_mode:
		var colors := [
			Color("ff4d4d"),
			Color("ffb84d"),
			Color("fff36b"),
			Color("4dff88"),
			Color("54d6ff"),
			Color("bf6cff")
		]
		for i in range(colors.size()):
			var arc_start := (TAU / colors.size()) * i + t * 0.7
			var arc_end := arc_start + TAU / colors.size() * 0.72
			var c: Color = colors[i]
			c.a = 1.0 - t
			draw_arc(Vector2.ZERO, radius + i * 2.5, arc_start, arc_end, 12, c, 2.2)
		draw_circle(Vector2.ZERO, 10.0 + radius * 0.25, Color(1, 1, 1, 0.12 * (1.0 - t)))
	else:
		var c := signature_color
		c.a = 0.9 - t * 0.8
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, c, 2.0)
		draw_arc(Vector2.ZERO, radius * 0.66, 0.0, TAU, 28, Color(c.r, c.g, c.b, c.a * 0.5), 1.0)
