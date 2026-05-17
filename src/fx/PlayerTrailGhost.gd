extends Node2D

var _lifetime: float = 3.5
var _max_lifetime: float = 3.5


func init(pos: Vector2, rot: float, lifetime: float) -> void:
	global_position = pos
	rotation = rot
	_lifetime = lifetime
	_max_lifetime = lifetime
	add_to_group("player_trail_ghost")


func _process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(_lifetime / _max_lifetime, 0.0, 1.0)
	var alpha := t * 0.30
	draw_polyline(PackedVector2Array([
		Vector2(0.0, -13.0), Vector2(11.0, 4.0), Vector2(5.0, 2.0),
		Vector2(5.0, 9.0), Vector2(-5.0, 9.0), Vector2(-5.0, 2.0),
		Vector2(-11.0, 4.0), Vector2(0.0, -13.0),
	]), Color(0.55, 0.92, 0.72, alpha), 0.9)
	draw_circle(Vector2.ZERO, 2.2, Color(0.55, 0.92, 0.72, alpha * 0.5))
