extends Node2D

var spark_color := Color(0.28, 1.0, 0.48, 1.0)
var radius := 28.0
var intensity := 0.0

var _rng := RandomNumberGenerator.new()
var _bolts: Array = []
var _sparking: bool = false
var _timer: float = 0.0


func _ready() -> void:
	_rng.randomize()
	_timer = _rng.randf_range(0.2, 1.8)


func _process(delta: float) -> void:
	if intensity < 0.01:
		if not _bolts.is_empty():
			_bolts.clear()
			queue_redraw()
		return
	_timer -= delta
	if _timer <= 0.0:
		if _sparking:
			_sparking = false
			_bolts.clear()
			queue_redraw()
			_timer = lerpf(3.5, 0.35, intensity) * _rng.randf_range(0.5, 1.5)
		else:
			_sparking = true
			_rebuild()
			queue_redraw()
			_timer = _rng.randf_range(0.05, 0.15)


func _rebuild() -> void:
	_bolts.clear()
	var count := 1 + int(_rng.randf() < 0.3)
	for _i in count:
		var a := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(radius * 0.25, radius * 0.9)
		var c := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(radius * 0.25, radius * 0.9)
		var seg_count := 2 + int(_rng.randf() * 2.0)
		var points: Array[Vector2] = [a]
		var main_dir := (c - a)
		var perp := main_dir.orthogonal().normalized() if main_dir.length() > 0.5 else Vector2.RIGHT
		var jag := main_dir.length() * 0.22
		for j in seg_count:
			var t := float(j + 1) / float(seg_count + 1)
			var pt := a.lerp(c, t) + perp * _rng.randf_range(-jag, jag)
			points.append(pt)
		points.append(c)
		_bolts.append([points, _rng.randf_range(0.7, 1.0)])


func _draw() -> void:
	for bolt in _bolts:
		var points: Array[Vector2] = bolt[0]
		var alpha: float = float(bolt[1])
		for i in range(points.size() - 1):
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			draw_line(a, b, Color(spark_color.r, spark_color.g, spark_color.b, alpha * 0.14), 1.1, true)
			draw_line(a, b, Color(spark_color.r, spark_color.g, spark_color.b, alpha), 0.28, true)
		draw_circle(points[0], 1.0, Color(spark_color.r, spark_color.g, spark_color.b, alpha * 0.6))
		draw_circle(points[-1], 1.0, Color(spark_color.r, spark_color.g, spark_color.b, alpha * 0.6))
