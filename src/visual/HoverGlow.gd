extends Node2D

@export var outer_radius: float = 26.0
@export var inner_radius: float = 14.0
@export var flatten: float = 0.42
@export var point_count: int = 24
@export var outer_alpha: float = 0.14
@export var inner_alpha: float = 0.3

@onready var outer: Polygon2D = $Outer
@onready var inner: Polygon2D = $Inner


func _ready() -> void:
	_rebuild()
	set_glow_color(Color(0.3, 1.0, 0.58, 1.0), 0.72)


func set_glow_color(color: Color, intensity: float = 1.0) -> void:
	var applied := color
	outer.color = Color(applied.r, applied.g, applied.b, outer_alpha * intensity)
	inner.color = Color(applied.r, applied.g, applied.b, inner_alpha * intensity)


func _rebuild() -> void:
	outer.polygon = _ellipse_points(outer_radius)
	inner.polygon = _ellipse_points(inner_radius)


func _ellipse_points(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := maxi(point_count, 8)
	for i in range(steps):
		var angle := TAU * float(i) / float(steps)
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius * flatten))
	return points
