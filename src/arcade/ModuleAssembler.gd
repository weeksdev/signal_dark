class_name ModuleAssembler
extends RefCounted

const ZoneGraph := preload("res://src/arcade/ArcadeZoneGraph.gd")
const WALL_SCENE := preload("res://src/terrain/LatticeWall.tscn")
const EXIT_SCENE := preload("res://src/world/ExitZone.tscn")

const ROOM_W := 480.0
const ROOM_H := 360.0
const CORRIDOR := 120.0
const DOOR_W := 180.0
const WALL_UNIT := 144.0
const CELL_X := ROOM_W + CORRIDOR   # 600
const CELL_Y := ROOM_H + CORRIDOR   # 480

var _node_cells: Dictionary = {}       # node_id → Vector2i(col, row)
var _node_rects: Dictionary = {}       # node_id → Rect2 (interior)
var _col_branch_count: Dictionary = {} # col → int


func assemble(world: Node2D, graph) -> Dictionary:
	_assign_grid_positions(graph)
	_compute_room_rects()
	_generate_walls(world, graph)
	_place_exit(world, graph)
	return {
		spawn       = _spawn_position(graph),
		world_rect  = _compute_world_rect(),
		node_rects  = _node_rects,
		node_cells  = _node_cells,
	}


# ── Grid layout ──────────────────────────────────────────────────────────────

func _assign_grid_positions(graph) -> void:
	_node_cells.clear()
	_col_branch_count.clear()
	_assign_main_path_positions(graph)

	for edge in graph.edges:
		if not edge.is_branch:
			continue
		var child = graph.get_node(edge.to_id)
		if child == null or not child.is_branch:
			continue
		var parent = graph.get_node(edge.from_id)
		if parent == null:
			continue
		var col: int = parent.depth
		_node_cells[edge.to_id] = Vector2i(col, _next_branch_row(col))


func _assign_main_path_positions(graph) -> void:
	var path_ids: Array = _main_path_ids(graph)
	if path_ids.is_empty():
		return

	var cell := Vector2i.ZERO
	var vertical_dir := -1
	_node_cells[path_ids[0]] = cell

	for i in range(1, path_ids.size()):
		if i % 2 == 1:
			cell += Vector2i(1, 0)
		else:
			cell += Vector2i(0, vertical_dir)
			vertical_dir *= -1
		_node_cells[path_ids[i]] = cell


func _main_path_ids(graph) -> Array:
	var ids: Array = [graph.start_node_id]
	var current_id: int = graph.start_node_id
	var visited: Dictionary = {current_id: true}

	while current_id != graph.exit_node_id:
		var next_id := -1
		for edge in graph.edges:
			if edge.is_branch:
				continue
			if edge.from_id != current_id:
				continue
			next_id = edge.to_id
			break
		if next_id < 0 or visited.has(next_id):
			break
		ids.append(next_id)
		visited[next_id] = true
		current_id = next_id

	return ids


func _next_branch_row(col: int) -> int:
	if not _col_branch_count.has(col):
		_col_branch_count[col] = 0
	var idx: int = _col_branch_count[col]
	_col_branch_count[col] = idx + 1
	var half := (idx / 2) + 2
	return half if idx % 2 == 0 else -half


func _compute_room_rects() -> void:
	for node_id in _node_cells:
		var cell: Vector2i = _node_cells[node_id]
		var origin := Vector2(float(cell.x) * CELL_X, float(cell.y) * CELL_Y)
		_node_rects[node_id] = Rect2(origin, Vector2(ROOM_W, ROOM_H))


# ── Wall generation ───────────────────────────────────────────────────────────

func _generate_walls(world: Node2D, graph) -> void:
	var corridors_done: Dictionary = {}

	for node in graph.nodes:
		if not _node_rects.has(node.id):
			continue
		var rect: Rect2 = _node_rects[node.id]
		var cell: Vector2i = _node_cells[node.id]

		# Collect connected directions and their neighbour rects
		var connected: Dictionary = {}     # dir → true
		var neighbours: Dictionary = {}   # dir → other_id

		for edge in graph.edges:
			var other_id := -1
			if edge.from_id == node.id:
				other_id = edge.to_id
			elif edge.to_id == node.id:
				other_id = edge.from_id
			if other_id < 0 or not _node_cells.has(other_id):
				continue
			var dir := _cell_dir(cell, _node_cells[other_id])
			if dir != "":
				connected[dir] = true
				neighbours[dir] = other_id

		_gen_room_walls(world, rect, connected)

		for dir in neighbours:
			var other_id: int = neighbours[dir]
			var key := "%d_%d" % [mini(node.id, other_id), maxi(node.id, other_id)]
			if corridors_done.has(key):
				continue
			corridors_done[key] = true
			_gen_corridor_walls(world, rect, _node_rects[other_id], dir)


func _cell_dir(from: Vector2i, to: Vector2i) -> String:
	var d := to - from
	if d == Vector2i(1, 0):  return "right"
	if d == Vector2i(-1, 0): return "left"
	if d == Vector2i(0, 1):  return "down"
	if d == Vector2i(0, -1): return "up"
	return ""


func _gen_room_walls(world: Node2D, rect: Rect2, connected: Dictionary) -> void:
	var x0 := rect.position.x
	var y0 := rect.position.y
	var x1 := x0 + ROOM_W
	var y1 := y0 + ROOM_H
	var cx := x0 + ROOM_W * 0.5
	var cy := y0 + ROOM_H * 0.5

	# Top
	if connected.has("up"):
		_h_wall(world, x0, cx - DOOR_W * 0.5, y0)
		_h_wall(world, cx + DOOR_W * 0.5, x1, y0)
	else:
		_h_wall(world, x0, x1, y0)

	# Bottom
	if connected.has("down"):
		_h_wall(world, x0, cx - DOOR_W * 0.5, y1)
		_h_wall(world, cx + DOOR_W * 0.5, x1, y1)
	else:
		_h_wall(world, x0, x1, y1)

	# Left
	if connected.has("left"):
		_v_wall(world, x0, y0, cy - DOOR_W * 0.5)
		_v_wall(world, x0, cy + DOOR_W * 0.5, y1)
	else:
		_v_wall(world, x0, y0, y1)

	# Right
	if connected.has("right"):
		_v_wall(world, x1, y0, cy - DOOR_W * 0.5)
		_v_wall(world, x1, cy + DOOR_W * 0.5, y1)
	else:
		_v_wall(world, x1, y0, y1)


func _gen_corridor_walls(world: Node2D, ra: Rect2, rb: Rect2, dir: String) -> void:
	match dir:
		"right":
			var x0 := ra.position.x + ROOM_W
			var x1 := rb.position.x
			var cy := ra.position.y + ROOM_H * 0.5
			_h_wall(world, x0, x1, cy - DOOR_W * 0.5)
			_h_wall(world, x0, x1, cy + DOOR_W * 0.5)
		"left":
			var x0 := rb.position.x + ROOM_W
			var x1 := ra.position.x
			var cy := ra.position.y + ROOM_H * 0.5
			_h_wall(world, x0, x1, cy - DOOR_W * 0.5)
			_h_wall(world, x0, x1, cy + DOOR_W * 0.5)
		"down":
			var y0 := ra.position.y + ROOM_H
			var y1 := rb.position.y
			var cx := ra.position.x + ROOM_W * 0.5
			_v_wall(world, cx - DOOR_W * 0.5, y0, y1)
			_v_wall(world, cx + DOOR_W * 0.5, y0, y1)
		"up":
			var y0 := rb.position.y + ROOM_H
			var y1 := ra.position.y
			var cx := ra.position.x + ROOM_W * 0.5
			_v_wall(world, cx - DOOR_W * 0.5, y0, y1)
			_v_wall(world, cx + DOOR_W * 0.5, y0, y1)


func _h_wall(world: Node2D, x0: float, x1: float, y: float) -> void:
	var length := x1 - x0
	if length < 4.0:
		return
	var wall: Node2D = WALL_SCENE.instantiate()
	wall.position = Vector2((x0 + x1) * 0.5, y)
	wall.scale.x = length / WALL_UNIT
	world.add_child(wall)


func _v_wall(world: Node2D, x: float, y0: float, y1: float) -> void:
	var length := y1 - y0
	if length < 4.0:
		return
	var wall: Node2D = WALL_SCENE.instantiate()
	wall.position = Vector2(x, (y0 + y1) * 0.5)
	wall.rotation = PI * 0.5
	wall.scale.x = length / WALL_UNIT
	world.add_child(wall)


# ── Spawn / exit / bounds ────────────────────────────────────────────────────

func _place_exit(world: Node2D, graph) -> void:
	var rect: Rect2 = _node_rects.get(graph.exit_node_id, Rect2(CELL_X, 0.0, ROOM_W, ROOM_H))
	var exit: Node2D = EXIT_SCENE.instantiate()
	exit.name = "ExitZone"
	exit.position = rect.get_center()
	world.add_child(exit)


func _spawn_position(graph) -> Vector2:
	var rect: Rect2 = _node_rects.get(graph.start_node_id, Rect2(0.0, 0.0, ROOM_W, ROOM_H))
	return rect.get_center()


func _compute_world_rect() -> Rect2:
	if _node_rects.is_empty():
		return Rect2(-96.0, -96.0, 1200.0, 800.0)
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for node_id in _node_rects:
		var r: Rect2 = _node_rects[node_id]
		min_x = minf(min_x, r.position.x)
		min_y = minf(min_y, r.position.y)
		max_x = maxf(max_x, r.end.x)
		max_y = maxf(max_y, r.end.y)
	var m := 120.0
	return Rect2(min_x - m, min_y - m, max_x - min_x + m * 2.0, max_y - min_y + m * 2.0)
