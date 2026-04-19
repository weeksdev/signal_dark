extends SceneTree

const DEFAULT_SCENES = [
	"res://src/world/World.tscn",
]

const WALL_SCRIPT_PATH := "res://src/terrain/LatticeWall.gd"
const GRID_CELL_SIZE := 8.0
const OUTSIDE_MARGIN_CELLS := 6


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene_paths := _resolve_scene_paths()
	var failures: Array[String] = []

	for scene_path in scene_paths:
		var result := await _verify_scene(scene_path)
		if result["ok"]:
			print("PASS ", scene_path, " ", result["message"])
		else:
			push_error("FAIL %s %s" % [scene_path, result["message"]])
			failures.append("%s: %s" % [scene_path, result["message"]])

	if failures.is_empty():
		print("Map boundary tests passed for %d scene(s)." % scene_paths.size())
		quit(0)
		return

	print("")
	print("Boundary failures:")
	for failure in failures:
		print(" - ", failure)
	quit(1)


func _resolve_scene_paths() -> PackedStringArray:
	var args := PackedStringArray(OS.get_cmdline_user_args())
	if args.is_empty():
		return PackedStringArray(DEFAULT_SCENES)

	if args.size() == 1 and args[0] == "--all":
		var world_scenes := PackedStringArray()
		var dir := DirAccess.open("res://src/world")
		if dir == null:
			push_error("Unable to open res://src/world")
			return PackedStringArray(DEFAULT_SCENES)
		dir.list_dir_begin()
		while true:
			var file_name := dir.get_next()
			if file_name == "":
				break
			if dir.current_is_dir():
				continue
			if not file_name.ends_with(".tscn"):
				continue
			if not file_name.begins_with("World"):
				continue
			world_scenes.append("res://src/world/%s" % file_name)
		dir.list_dir_end()
		world_scenes.sort()
		return world_scenes

	return args


func _verify_scene(scene_path: String) -> Dictionary:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return {
			"ok": false,
			"message": "scene could not be loaded",
		}

	var world := packed.instantiate()

	var wall_rects := _collect_wall_rects(world)
	var actor_info := _collect_actor_info(world)
	var grid_node: Node = world.get_node_or_null("Grid")

	if wall_rects.is_empty():
		world.free()
		return {
			"ok": false,
			"message": "no lattice walls found",
		}

	var actors: Array[Dictionary] = actor_info["actors"]
	if actors.is_empty():
		world.free()
		return {
			"ok": false,
			"message": "no actor spawn points found",
		}

	var world_rect: Rect2 = grid_node.world_rect if grid_node != null else _merge_rects(wall_rects).grow(128.0)
	var expanded_world_rect := world_rect.grow(GRID_CELL_SIZE * OUTSIDE_MARGIN_CELLS)
	var grid_size := Vector2i(
		int(ceil(expanded_world_rect.size.x / GRID_CELL_SIZE)),
		int(ceil(expanded_world_rect.size.y / GRID_CELL_SIZE))
	)
	var blocked_cache: Dictionary = {}
	var checked_radii: Dictionary = {}

	for actor in actors:
		var actor_radius: float = actor["radius"]
		var radius_key := "%.2f" % actor_radius
		if not blocked_cache.has(radius_key):
			var blocked := _build_blocked_grid(wall_rects, expanded_world_rect, grid_size, actor_radius)
			blocked_cache[radius_key] = {
				"blocked": blocked,
				"outside": _flood_from_outside(blocked, grid_size),
			}
		if checked_radii.has(radius_key):
			continue
		var same_radius_actors: Array[Dictionary] = []
		for candidate in actors:
			if "%.2f" % float(candidate["radius"]) == radius_key:
				same_radius_actors.append(candidate)
		var actor_search := _flood_from_actors(
			same_radius_actors,
			blocked_cache[radius_key]["blocked"],
			blocked_cache[radius_key]["outside"],
			expanded_world_rect,
			grid_size
		)
		if not actor_search["ok"]:
			world.free()
			return actor_search
		checked_radii[radius_key] = true

	world.free()

	return {
		"ok": true,
		"message": "sealed for %d actor spawn(s) across %d walls" % [actors.size(), wall_rects.size()],
	}


func _collect_wall_rects(world: Node) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for node in world.find_children("*", "StaticBody2D", true, false):
		var script: Script = node.get_script() as Script
		if script == null or script.resource_path != WALL_SCRIPT_PATH:
			continue
		var shape_node := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node == null:
			continue
		var shape := shape_node.shape as RectangleShape2D
		if shape == null:
			continue
		rects.append(_global_rect_from_shape(shape_node, shape.size))
	return rects


func _collect_actor_info(world: Node) -> Dictionary:
	var actors: Array[Dictionary] = []

	for node in world.find_children("*", "CharacterBody2D", true, false):
		var actor_radius := 0.0
		for child in node.get_children():
			var shape_node := child as CollisionShape2D
			if shape_node == null:
				continue
			if shape_node.shape is CircleShape2D:
				actor_radius = maxf(actor_radius, (shape_node.shape as CircleShape2D).radius)
			elif shape_node.shape is RectangleShape2D:
				var rect_shape := shape_node.shape as RectangleShape2D
				actor_radius = maxf(actor_radius, maxf(rect_shape.size.x, rect_shape.size.y) * 0.5)
		if actor_radius <= 0.0:
			continue
		actors.append({
			"name": node.name,
			"position": node.global_position,
			"radius": actor_radius,
		})

	return {
		"actors": actors,
	}


func _global_rect_from_shape(shape_node: CollisionShape2D, shape_size: Vector2) -> Rect2:
	var half := shape_size * 0.5
	var corners := [
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	]

	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF

	for corner in corners:
		var global_corner: Vector2 = shape_node.global_transform * corner
		min_x = minf(min_x, global_corner.x)
		min_y = minf(min_y, global_corner.y)
		max_x = maxf(max_x, global_corner.x)
		max_y = maxf(max_y, global_corner.y)

	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _merge_rects(rects: Array[Rect2]) -> Rect2:
	var merged := rects[0]
	for i in range(1, rects.size()):
		merged = merged.merge(rects[i])
	return merged


func _build_blocked_grid(
	wall_rects: Array[Rect2],
	test_rect: Rect2,
	grid_size: Vector2i,
	actor_radius: float
) -> PackedByteArray:
	var blocked := PackedByteArray()
	blocked.resize(grid_size.x * grid_size.y)
	var raster_padding := actor_radius + GRID_CELL_SIZE * 0.5

	for wall_rect in wall_rects:
		var expanded := wall_rect.grow(raster_padding)
		var min_cell := _point_to_cell(expanded.position, test_rect)
		var max_cell := _point_to_cell(expanded.end, test_rect)

		for y in range(maxi(0, min_cell.y), mini(grid_size.y - 1, max_cell.y) + 1):
			for x in range(maxi(0, min_cell.x), mini(grid_size.x - 1, max_cell.x) + 1):
				var idx := _index(x, y, grid_size.x)
				var center := _cell_center(x, y, test_rect)
				if expanded.has_point(center):
					blocked[idx] = 1

	return blocked


func _flood_from_outside(blocked: PackedByteArray, grid_size: Vector2i) -> PackedByteArray:
	var visited := PackedByteArray()
	visited.resize(grid_size.x * grid_size.y)
	var queue: Array[int] = []
	var head := 0

	for x in range(grid_size.x):
		_enqueue_if_open(x, 0, blocked, visited, queue, grid_size)
		_enqueue_if_open(x, grid_size.y - 1, blocked, visited, queue, grid_size)
	for y in range(grid_size.y):
		_enqueue_if_open(0, y, blocked, visited, queue, grid_size)
		_enqueue_if_open(grid_size.x - 1, y, blocked, visited, queue, grid_size)

	while head < queue.size():
		var idx := queue[head]
		head += 1
		var x := idx % grid_size.x
		var y := idx / grid_size.x
		_visit_neighbors(x, y, blocked, visited, queue, grid_size)

	return visited


func _flood_from_actors(
	actors: Array[Dictionary],
	blocked: PackedByteArray,
	outside_visited: PackedByteArray,
	test_rect: Rect2,
	grid_size: Vector2i
) -> Dictionary:
	var visited := PackedByteArray()
	visited.resize(grid_size.x * grid_size.y)
	var queue: Array[int] = []
	var head := 0

	for actor in actors:
		var actor_name := String(actor["name"])
		var actor_position: Vector2 = actor["position"]
		var cell := _find_nearest_open_cell(actor_position, blocked, test_rect, grid_size)
		if cell.x < 0 or cell.y < 0 or cell.x >= grid_size.x or cell.y >= grid_size.y:
			return {
				"ok": false,
				"message": "actor %s at %s has no open seed cell" % [actor_name, actor_position],
			}
		var idx := _index(cell.x, cell.y, grid_size.x)
		if visited[idx] == 0:
			visited[idx] = 1
			queue.append(idx)

	while head < queue.size():
		var idx := queue[head]
		head += 1

		if outside_visited[idx] == 1:
			var x := idx % grid_size.x
			var y := idx / grid_size.x
			var border_contact := _find_border_contact(Vector2i(x, y), outside_visited, grid_size)
			return {
				"ok": false,
				"message": "reachable escape path near %s to border %s" % [
					_cell_center(x, y, test_rect),
					_cell_center(border_contact.x, border_contact.y, test_rect),
				],
			}

		var x := idx % grid_size.x
		var y := idx / grid_size.x
		_visit_neighbors(x, y, blocked, visited, queue, grid_size)

	return {
		"ok": true,
		"message": "actors are contained",
	}


func _enqueue_if_open(
	x: int,
	y: int,
	blocked: PackedByteArray,
	visited: PackedByteArray,
	queue: Array[int],
	grid_size: Vector2i
) -> void:
	var idx := _index(x, y, grid_size.x)
	if blocked[idx] == 1 or visited[idx] == 1:
		return
	visited[idx] = 1
	queue.append(idx)


func _visit_neighbors(
	x: int,
	y: int,
	blocked: PackedByteArray,
	visited: PackedByteArray,
	queue: Array[int],
	grid_size: Vector2i
) -> void:
	var offsets: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
	]

	for offset in offsets:
		var nx: int = x + offset.x
		var ny: int = y + offset.y
		if nx < 0 or ny < 0 or nx >= grid_size.x or ny >= grid_size.y:
			continue
		var nidx := _index(nx, ny, grid_size.x)
		if blocked[nidx] == 1 or visited[nidx] == 1:
			continue
		visited[nidx] = 1
		queue.append(nidx)


func _point_to_cell(point: Vector2, test_rect: Rect2) -> Vector2i:
	var local := point - test_rect.position
	return Vector2i(
		int(floor(local.x / GRID_CELL_SIZE)),
		int(floor(local.y / GRID_CELL_SIZE))
	)


func _find_nearest_open_cell(
	point: Vector2,
	blocked: PackedByteArray,
	test_rect: Rect2,
	grid_size: Vector2i
) -> Vector2i:
	var origin := _point_to_cell(point, test_rect)
	if _cell_is_open(origin, blocked, grid_size):
		return origin

	for radius in range(1, 5):
		for y in range(origin.y - radius, origin.y + radius + 1):
			for x in range(origin.x - radius, origin.x + radius + 1):
				var cell := Vector2i(x, y)
				if not _cell_is_open(cell, blocked, grid_size):
					continue
				return cell

	return Vector2i(-1, -1)


func _cell_is_open(cell: Vector2i, blocked: PackedByteArray, grid_size: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= grid_size.x or cell.y >= grid_size.y:
		return false
	return blocked[_index(cell.x, cell.y, grid_size.x)] == 0


func _find_border_contact(start: Vector2i, visited_region: PackedByteArray, grid_size: Vector2i) -> Vector2i:
	var seen := PackedByteArray()
	seen.resize(grid_size.x * grid_size.y)
	var queue: Array[Vector2i] = [start]
	var head := 0
	seen[_index(start.x, start.y, grid_size.x)] = 1

	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		if cell.x == 0 or cell.y == 0 or cell.x == grid_size.x - 1 or cell.y == grid_size.y - 1:
			return cell
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cell + offset
			if next.x < 0 or next.y < 0 or next.x >= grid_size.x or next.y >= grid_size.y:
				continue
			var idx := _index(next.x, next.y, grid_size.x)
			if visited_region[idx] == 0 or seen[idx] == 1:
				continue
			seen[idx] = 1
			queue.append(next)

	return start


func _cell_center(x: int, y: int, test_rect: Rect2) -> Vector2:
	return test_rect.position + Vector2(
		(x + 0.5) * GRID_CELL_SIZE,
		(y + 0.5) * GRID_CELL_SIZE
	)


func _index(x: int, y: int, width: int) -> int:
	return y * width + x
