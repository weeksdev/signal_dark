extends Node2D

@export var world_rect := Rect2(-96.0, -96.0, 4096.0, 2816.0)
@export var spacing: float = 28.0

var pulse: float = 0.0
var redraw_accumulator: float = 0.0


func _process(delta: float) -> void:
	pulse += delta
	redraw_accumulator += delta
	if redraw_accumulator >= 0.05:
		redraw_accumulator = 0.0
		queue_redraw()


func _ready() -> void:
	ColorSystem.mode_changed.connect(_on_mode_changed)


func _on_mode_changed(_in_combat: bool) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(world_rect, ColorSystem.background_color(), true)
	var view_rect := _get_visible_world_rect().grow(160.0)
	if not ColorSystem.in_combat:
		_draw_stealth_haze(view_rect)
		_draw_machine_mass(view_rect)
	else:
		_draw_combat_haze(view_rect)
	_draw_warped_grid(view_rect)
	_draw_star_dust(view_rect)
	_draw_grid_nodes(view_rect)
	if not ColorSystem.in_combat:
		_draw_corner_marks(view_rect)


func _draw_stealth_haze(view_rect: Rect2) -> void:
	var center := view_rect.get_center()
	for i in range(5):
		var radius := 180.0 + i * 110.0
		var offset := Vector2(cos(pulse * 0.15 + i), sin(pulse * 0.11 + i * 0.6)) * 48.0
		var alpha := 0.034 - i * 0.0032
		draw_circle(center + offset, radius, Color(0.02, 0.11, 0.06, maxf(alpha, 0.004)))
	draw_rect(Rect2(Vector2(view_rect.position.x, world_rect.position.y), Vector2(view_rect.size.x, 90.0)), Color(0, 0, 0, 0.18), true)
	draw_rect(Rect2(Vector2(view_rect.position.x, world_rect.end.y - 120.0), Vector2(view_rect.size.x, 120.0)), Color(0, 0, 0, 0.24), true)


func _draw_machine_mass(view_rect: Rect2) -> void:
	var slabs := [
		Rect2(Vector2(220.0, 120.0), Vector2(260.0, 220.0)),
		Rect2(Vector2(980.0, 260.0), Vector2(300.0, 180.0)),
		Rect2(Vector2(1680.0, 720.0), Vector2(340.0, 240.0)),
		Rect2(Vector2(2780.0, 520.0), Vector2(360.0, 250.0)),
		Rect2(Vector2(620.0, 1640.0), Vector2(280.0, 240.0)),
		Rect2(Vector2(2080.0, 1900.0), Vector2(320.0, 260.0)),
		Rect2(Vector2(3240.0, 1520.0), Vector2(360.0, 320.0))
	]
	var fill := Color(0.01, 0.04, 0.02, 0.34)
	var edge := Color(0.08, 0.26, 0.14, 0.1)
	for slab in slabs:
		if not view_rect.grow(240.0).intersects(slab):
			continue
		draw_rect(slab, fill, true)
		draw_rect(slab.grow(2.0), Color(0.0, 0.0, 0.0, 0.16), false, 2.0)
		draw_line(slab.position + Vector2(18.0, 0.0), slab.position + Vector2(slab.size.x, slab.size.y - 18.0), edge, 0.5)
		draw_line(slab.position + Vector2(0.0, slab.size.y * 0.4), slab.position + Vector2(slab.size.x * 0.65, slab.size.y), Color(edge.r, edge.g, edge.b, 0.08), 0.5)
	var trench := Rect2(Vector2(1940.0, -96.0), Vector2(92.0, 3008.0))
	if view_rect.grow(120.0).intersects(trench):
		draw_rect(trench, Color(0.0, 0.0, 0.0, 0.2), true)
		draw_line(trench.position, trench.position + Vector2(0.0, trench.size.y), Color(0.05, 0.2, 0.12, 0.2), 0.5)
		draw_line(trench.position + Vector2(trench.size.x, 0.0), trench.position + trench.size, Color(0.05, 0.2, 0.12, 0.12), 0.5)


func _draw_combat_haze(view_rect: Rect2) -> void:
	var center := view_rect.get_center()
	for i in range(3):
		var radius := 220.0 + i * 130.0
		var alpha := 0.02 - i * 0.003
		draw_circle(center, radius, Color(0.08, 0.1, 0.32, maxf(alpha, 0.004)))


func _draw_grid_nodes(view_rect: Rect2) -> void:
	var x_start: float = floor(view_rect.position.x / spacing) * spacing - spacing * 2.0
	var x_end: float = ceil(view_rect.end.x / spacing) * spacing + spacing * 2.0
	var y_start: float = floor(view_rect.position.y / spacing) * spacing - spacing * 2.0
	var y_end: float = ceil(view_rect.end.y / spacing) * spacing + spacing * 2.0
	var x: float = x_start
	var xi := int(x_start / spacing)
	while x <= x_end:
		var y: float = y_start
		var yi := int(y_start / spacing)
		while y <= y_end:
			if (xi + yi) % 3 == 0:
				var flicker := 0.012 + 0.012 * (0.5 + 0.5 * sin(pulse * 1.3 + xi * 0.4 + yi * 0.7))
				var node_color := ColorSystem.haze_color()
				draw_circle(_warp_point(Vector2(x, y)), 1.3, Color(node_color.r * 1.4, node_color.g * 1.7, node_color.b * 1.2, flicker))
			y += spacing * 2.0
			yi += 2
		x += spacing * 2.0
		xi += 2


func _draw_corner_marks(view_rect: Rect2) -> void:
	var marks := [
		Vector2(120.0, 120.0),
		Vector2(3880.0, 120.0),
		Vector2(120.0, 2600.0),
		Vector2(3880.0, 2600.0)
	]
	for mark in marks:
		if not view_rect.grow(120.0).has_point(mark):
			continue
		var tint := Color(0.22, 0.9, 0.48, 0.18 + 0.04 * sin(pulse * 1.4 + mark.x))
		draw_line(mark, mark + Vector2(18.0, 0.0), tint, 0.5)
		draw_line(mark, mark + Vector2(0.0, 18.0), tint, 0.5)


func _draw_warped_grid(view_rect: Rect2) -> void:
	var line_color := ColorSystem.grid_color()
	var attractors := _get_attractors()
	var x_start: float = floor(view_rect.position.x / spacing) * spacing - spacing * 3.0
	var x_end: float = ceil(view_rect.end.x / spacing) * spacing + spacing * 3.0
	var y_start: float = floor(view_rect.position.y / spacing) * spacing - spacing * 3.0
	var y_end: float = ceil(view_rect.end.y / spacing) * spacing + spacing * 3.0
	var x: float = x_start
	var col := 0
	while x <= x_end:
		var alpha_boost := 0.025 if col % 5 == 0 else 0.0
		var points := PackedVector2Array()
		var y: float = y_start
		while y <= y_end:
			points.append(_warp_point(Vector2(x, y), attractors))
			y += 24.0
		draw_polyline(points, Color(line_color.r, line_color.g, line_color.b, 0.22 + alpha_boost), 0.7)
		x += spacing * 1.5
		col += 1
	var row := 0
	var y2: float = y_start
	while y2 <= y_end:
		var alpha_boost_h := 0.025 if row % 5 == 0 else 0.0
		var h_points := PackedVector2Array()
		var x2: float = x_start
		while x2 <= x_end:
			h_points.append(_warp_point(Vector2(x2, y2), attractors))
			x2 += 24.0
		draw_polyline(h_points, Color(line_color.r, line_color.g, line_color.b, 0.22 + alpha_boost_h), 0.7)
		y2 += spacing * 1.5
		row += 1


func _draw_star_dust(view_rect: Rect2) -> void:
	for i in range(24):
		var seed := float(i) * 17.137
		var point := Vector2(
			view_rect.position.x + fposmod(seed * 91.0 + pulse * 20.0, view_rect.size.x),
			view_rect.position.y + fposmod(seed * 53.0 + 170.0 + pulse * 11.0, view_rect.size.y)
		)
		var drift := Vector2(sin(pulse * 0.2 + i), cos(pulse * 0.17 + i * 0.7)) * 8.0
		var warped := _warp_point(point + drift)
		var streak := Vector2(2.0 + 3.0 * sin(seed), 0.8).rotated(0.45)
		var tint := Color(0.72, 0.82, 0.74, 0.08 if not ColorSystem.in_combat else 0.14)
		draw_line(warped - streak, warped + streak, tint, 0.5)


func _get_attractors() -> Array:
	var attractors := []
	var player = get_tree().get_first_node_in_group("player_ship")
	if player != null:
		attractors.append({
			"position": player.global_position,
			"strength": 22000.0 if not ColorSystem.in_combat else 32000.0,
			"twist": 0.28 if not ColorSystem.in_combat else 0.45,
			"radius": 320.0
		})
	for enemy in get_tree().get_nodes_in_group("zone_enemy"):
		if enemy == null:
			continue
		if attractors.size() >= 5:
			break
		var strength := 9000.0 if not ColorSystem.in_combat else 14000.0
		var twist := 0.12 if not ColorSystem.in_combat else 0.22
		var radius := 210.0
		if enemy.scene_file_path.ends_with("Wisp.tscn"):
			strength = 18000.0 if not ColorSystem.in_combat else 24000.0
			twist = 0.18 if not ColorSystem.in_combat else 0.28
			radius = 320.0
		attractors.append({
			"position": enemy.global_position,
			"strength": strength,
			"twist": twist,
			"radius": radius
		})
	return attractors


func _warp_point(point: Vector2, attractors := []) -> Vector2:
	var warped: Vector2 = point
	var source := attractors if not attractors.is_empty() else _get_attractors()
	for attractor in source:
		var target: Vector2 = attractor["position"]
		var to_target: Vector2 = target - point
		var distance: float = maxf(to_target.length(), 1.0)
		var radius: float = attractor["radius"]
		if distance > radius:
			continue
		var influence: float = 1.0 - (distance / radius)
		var pull: Vector2 = to_target.normalized() * float(attractor["strength"]) * pow(influence, 2.4) / 1000.0
		var tangent: Vector2 = Vector2(-to_target.y, to_target.x).normalized() * float(attractor["strength"]) * float(attractor["twist"]) * pow(influence, 1.9) / 1000.0
		var displacement: Vector2 = pull + tangent
		if displacement.length() > 48.0:
			displacement = displacement.normalized() * 48.0
		warped += displacement
	return warped


func _get_visible_world_rect() -> Rect2:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return world_rect
	var safe_zoom := Vector2(
		maxf(camera.zoom.x, 0.001),
		maxf(camera.zoom.y, 0.001)
	)
	var view_size: Vector2 = Vector2(
		get_viewport_rect().size.x / safe_zoom.x,
		get_viewport_rect().size.y / safe_zoom.y
	)
	var center: Vector2 = camera.get_screen_center_position()
	var rect := Rect2(center - view_size * 0.5, view_size)
	return rect.intersection(world_rect)
