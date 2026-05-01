extends Node2D

@export var radius: float = 285.0
@export var lifetime: float = 0.72

var _age: float = 0.0
var _seed: float = 0.0


func _ready() -> void:
	_seed = randf() * TAU


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(_age / lifetime, 0.0, 1.0)
	var ease := 1.0 - pow(1.0 - t, 3.0)
	var fade := 1.0 - t
	var ring_radius := radius * ease
	var cyan := Color(0.5, 0.95, 1.0, 0.0)
	var white := Color(0.86, 1.0, 1.0, 0.0)
	var error := Color(1.0, 0.16, 0.22, 0.0)

	draw_circle(Vector2.ZERO, ring_radius * 0.92, Color(0.45, 0.95, 1.0, 0.035 * fade))
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 96, Color(cyan.r, cyan.g, cyan.b, 0.85 * fade), 2.0)
	draw_arc(Vector2.ZERO, ring_radius * 0.82, 0.0, TAU, 80, Color(white.r, white.g, white.b, 0.28 * fade), 0.8)
	draw_arc(Vector2.ZERO, ring_radius * 1.06, 0.0, TAU, 96, Color(0.02, 0.06, 0.07, 0.36 * fade), 2.5)

	for i in range(18):
		var a := _seed + float(i) * TAU / 18.0 + sin(_age * 18.0 + i) * 0.08
		var length := radius * (0.045 + 0.04 * sin(_age * 25.0 + i * 1.7))
		var start := Vector2.RIGHT.rotated(a) * maxf(ring_radius - length, 0.0)
		var end := Vector2.RIGHT.rotated(a + sin(i * 2.4) * 0.08) * (ring_radius + length * 0.5)
		var col := Color(cyan.r, cyan.g, cyan.b, (0.34 + 0.2 * sin(_age * 20.0 + i)) * fade)
		draw_line(start, end, col, 0.8)

	for i in range(5):
		var a2 := _seed * 0.7 + float(i) * TAU / 5.0 + _age * 4.0
		var start2 := Vector2.RIGHT.rotated(a2) * ring_radius * 0.92
		var end2 := Vector2.RIGHT.rotated(a2 + 0.22) * ring_radius * 1.08
		draw_line(start2, end2, Color(error.r, error.g, error.b, 0.42 * fade), 0.55)
