extends Node2D

@export var tile_texture: Texture2D
@export var alternate_tile_texture: Texture2D
@export var world_rect := Rect2()
@export var tile_scale := Vector2(0.034, 0.034)
@export var cell_spacing: float = 36.0
@export var collision_mask: int = 4
@export var wall_clearance: float = 14.0

var _last_world_rect := Rect2()
var _tile_centers: Array[Vector2] = []
var _tile_variants: Array[int] = []
var _built: bool = false


func _ready() -> void:
	_sync_world_rect()
	queue_redraw()


func _process(_delta: float) -> void:
	var rect_changed := _sync_world_rect()
	if rect_changed:
		_built = false
	if not _built and _world_ready_for_build():
		_rebuild_tiles()
		queue_redraw()


func _draw() -> void:
	if tile_texture == null:
		return
	for i in range(_tile_centers.size()):
		var texture := tile_texture
		if alternate_tile_texture != null and i < _tile_variants.size() and _tile_variants[i] == 1:
			texture = alternate_tile_texture
		var tile_size := texture.get_size() * tile_scale
		if tile_size.x <= 0.0 or tile_size.y <= 0.0:
			continue
		var center := _tile_centers[i]
		draw_texture_rect(texture, Rect2(center - tile_size * 0.5, tile_size), false, Color(0.25, 0.34, 0.25, 1.0))


func _world_ready_for_build() -> bool:
	if tile_texture == null:
		return false
	if world_rect.size.x <= 0.0 or world_rect.size.y <= 0.0:
		return false
	var player := get_tree().get_first_node_in_group("player_ship")
	return player != null


func _rebuild_tiles() -> void:
	_tile_centers.clear()
	_tile_variants.clear()
	var player := get_tree().get_first_node_in_group("player_ship")
	if player == null:
		return
	var start_pos: Vector2 = player.global_position
	if not world_rect.has_point(start_pos):
		start_pos = world_rect.get_center()
	var start_cell := _world_to_cell(start_pos)
	var start_center := _cell_to_world(start_cell)
	if not _is_walkable(start_center):
		return

	var queue: Array[Vector2i] = [start_cell]
	var visited := {}
	visited[_cell_key(start_cell)] = true
	var limit := 48000

	while not queue.is_empty() and _tile_centers.size() < limit:
		var cell: Vector2i = queue.pop_front()
		var center := _cell_to_world(cell)
		if not _is_walkable(center):
			continue
		_tile_centers.append(center)
		_tile_variants.append(_tile_variant_for_cell(cell))
		for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next_cell: Vector2i = cell + dir
			var next_center: Vector2 = _cell_to_world(next_cell)
			if not world_rect.has_point(next_center):
				continue
			var key := _cell_key(next_cell)
			if visited.has(key):
				continue
			visited[key] = true
			if not _is_walkable(next_center):
				continue
			if _segment_hits_wall(center, next_center):
				continue
			queue.append(next_cell)
	_built = true


func _sync_world_rect() -> bool:
	var grid := get_parent().get_node_or_null("Grid")
	if grid != null:
		var rect = grid.get("world_rect")
		if rect is Rect2:
			world_rect = rect
	if world_rect == _last_world_rect:
		return false
	_last_world_rect = world_rect
	return true


func _world_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(
		int(floor((point.x - world_rect.position.x) / cell_spacing)),
		int(floor((point.y - world_rect.position.y) / cell_spacing))
	)


func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		world_rect.position.x + (float(cell.x) + 0.5) * cell_spacing,
		world_rect.position.y + (float(cell.y) + 0.5) * cell_spacing
	)


func _cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]


func _tile_variant_for_cell(cell: Vector2i) -> int:
	if alternate_tile_texture == null:
		return 0
	var parity: int = abs(cell.x * 31 + cell.y * 17)
	return 1 if parity % 5 in [1, 4] else 0


func _is_walkable(point: Vector2) -> bool:
	if not world_rect.grow(-wall_clearance).has_point(point):
		return false
	var space := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = point
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.collision_mask = collision_mask
	return space.intersect_point(params, 1).is_empty()


func _segment_hits_wall(from_point: Vector2, to_point: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var params := PhysicsRayQueryParameters2D.create(from_point, to_point, collision_mask)
	params.collide_with_areas = false
	params.collide_with_bodies = true
	return not space.intersect_ray(params).is_empty()
