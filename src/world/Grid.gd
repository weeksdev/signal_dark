extends Node2D

@export var world_rect := Rect2(-64.0, -64.0, 2048.0, 1408.0)
@export var spacing: float = 28.0

var pulse: float = 0.0


func _process(delta: float) -> void:
	pulse += delta
	queue_redraw()


func _ready() -> void:
	ColorSystem.mode_changed.connect(_on_mode_changed)


func _on_mode_changed(_in_combat: bool) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(world_rect, ColorSystem.background_color(), true)
	if not ColorSystem.in_combat:
		_draw_stealth_haze()
		_draw_machine_mass()
	else:
		_draw_combat_haze()
	_draw_warped_grid()
	_draw_star_dust()
	_draw_grid_nodes()
	if not ColorSystem.in_combat:
		_draw_corner_marks()


func _draw_stealth_haze() -> void:
	var center := world_rect.get_center()
	for i in range(7):
		var radius := 180.0 + i * 110.0
		var offset := Vector2(cos(pulse * 0.15 + i), sin(pulse * 0.11 + i * 0.6)) * 48.0
		var alpha := 0.034 - i * 0.0032
		draw_circle(center + offset, radius, Color(0.02, 0.11, 0.06, maxf(alpha, 0.004)))
	draw_rect(Rect2(world_rect.position, Vector2(world_rect.size.x, 90.0)), Color(0, 0, 0, 0.18), true)
	draw_rect(Rect2(Vector2(world_rect.position.x, world_rect.end.y - 120.0), Vector2(world_rect.size.x, 120.0)), Color(0, 0, 0, 0.24), true)


func _draw_machine_mass() -> void:
	var slabs := [
		Rect2(Vector2(24.0, 120.0), Vector2(112.0, 236.0)),
		Rect2(Vector2(258.0, 72.0), Vector2(108.0, 170.0)),
		Rect2(Vector2(208.0, 470.0), Vector2(148.0, 198.0)),
		Rect2(Vector2(38.0, 760.0), Vector2(132.0, 190.0))
	]
	var fill := Color(0.01, 0.04, 0.02, 0.34)
	var edge := Color(0.08, 0.26, 0.14, 0.1)
	for slab in slabs:
		draw_rect(slab, fill, true)
		draw_rect(slab.grow(2.0), Color(0.0, 0.0, 0.0, 0.16), false, 2.0)
		draw_line(slab.position + Vector2(18.0, 0.0), slab.position + Vector2(slab.size.x, slab.size.y - 18.0), edge, 1.0)
		draw_line(slab.position + Vector2(0.0, slab.size.y * 0.4), slab.position + Vector2(slab.size.x * 0.65, slab.size.y), Color(edge.r, edge.g, edge.b, 0.08), 1.0)
	var trench := Rect2(Vector2(168.0, -64.0), Vector2(62.0, 1472.0))
	draw_rect(trench, Color(0.0, 0.0, 0.0, 0.2), true)
	draw_line(trench.position, trench.position + Vector2(0.0, trench.size.y), Color(0.05, 0.2, 0.12, 0.2), 2.0)
	draw_line(trench.position + Vector2(trench.size.x, 0.0), trench.position + trench.size, Color(0.05, 0.2, 0.12, 0.12), 1.0)


func _draw_combat_haze() -> void:
	var center := world_rect.get_center()
	for i in range(4):
		var radius := 220.0 + i * 130.0
		var alpha := 0.02 - i * 0.003
		draw_circle(center, radius, Color(0.08, 0.1, 0.32, maxf(alpha, 0.004)))


func _draw_grid_nodes() -> void:
	var x := world_rect.position.x
	var xi := 0
	while x <= world_rect.end.x:
		var y := world_rect.position.y
		var yi := 0
		while y <= world_rect.end.y:
			if (xi + yi) % 3 == 0:
				var flicker := 0.012 + 0.012 * (0.5 + 0.5 * sin(pulse * 1.3 + xi * 0.4 + yi * 0.7))
				var node_color := ColorSystem.haze_color()
				draw_circle(_warp_point(Vector2(x, y)), 1.3, Color(node_color.r * 1.4, node_color.g * 1.7, node_color.b * 1.2, flicker))
			y += spacing
			yi += 1
		x += spacing
		xi += 1


func _draw_corner_marks() -> void:
	var marks := [
		Vector2(26.0, 100.0),
		Vector2(320.0, 112.0),
		Vector2(42.0, 708.0),
		Vector2(310.0, 786.0)
	]
	for mark in marks:
		var tint := Color(0.22, 0.9, 0.48, 0.18 + 0.04 * sin(pulse * 1.4 + mark.x))
		draw_line(mark, mark + Vector2(18.0, 0.0), tint, 2.0)
		draw_line(mark, mark + Vector2(0.0, 18.0), tint, 2.0)


func _draw_warped_grid() -> void:
	var line_color := ColorSystem.grid_color()
	var attractors := _get_attractors()
	var x := world_rect.position.x
	var col := 0
	while x <= world_rect.end.x:
		var alpha_boost := 0.025 if col % 5 == 0 else 0.0
		var points := PackedVector2Array()
		var y := world_rect.position.y
		while y <= world_rect.end.y:
			points.append(_warp_point(Vector2(x, y), attractors))
			y += 12.0
		draw_polyline(points, Color(line_color.r, line_color.g, line_color.b, 0.22 + alpha_boost), 1.4)
		x += spacing
		col += 1
	var row := 0
	var y2 := world_rect.position.y
	while y2 <= world_rect.end.y:
		var alpha_boost_h := 0.025 if row % 5 == 0 else 0.0
		var h_points := PackedVector2Array()
		var x2 := world_rect.position.x
		while x2 <= world_rect.end.x:
			h_points.append(_warp_point(Vector2(x2, y2), attractors))
			x2 += 12.0
		draw_polyline(h_points, Color(line_color.r, line_color.g, line_color.b, 0.22 + alpha_boost_h), 1.4)
		y2 += spacing
		row += 1


func _draw_star_dust() -> void:
	for i in range(90):
		var seed := float(i) * 17.137
		var point := Vector2(
			world_rect.position.x + fposmod(seed * 91.0, world_rect.size.x),
			world_rect.position.y + fposmod(seed * 53.0 + 170.0, world_rect.size.y)
		)
		var drift := Vector2(sin(pulse * 0.2 + i), cos(pulse * 0.17 + i * 0.7)) * 8.0
		var warped := _warp_point(point + drift)
		var streak := Vector2(2.0 + 3.0 * sin(seed), 0.8).rotated(0.45)
		var tint := Color(0.72, 0.82, 0.74, 0.08 if not ColorSystem.in_combat else 0.14)
		draw_line(warped - streak, warped + streak, tint, 1.0)


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
		attractors.append({
			"position": enemy.global_position,
			"strength": 9000.0 if not ColorSystem.in_combat else 14000.0,
			"twist": 0.12 if not ColorSystem.in_combat else 0.22,
			"radius": 210.0
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
