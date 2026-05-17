extends Node

const SPAWN_INTERVAL   := 0.38
const MIN_MOVE_DIST    := 16.0
const GHOST_LIFETIME   := 3.5
const TRAIL_SEARCH_DUR := 4.2
const ACTIVE_BUFFER    := 2.2

var _active: bool = false
var _deactivate_timer: float = 0.0
var _spawn_timer: float = 0.0
var _last_spawn_pos: Vector2 = Vector2(INF, INF)


func activate() -> void:
	_active = true
	_deactivate_timer = ACTIVE_BUFFER


func _process(delta: float) -> void:
	if not _active:
		return
	_deactivate_timer -= delta
	if _deactivate_timer <= 0.0:
		_active = false
		return
	var player = get_tree().get_first_node_in_group("player_ship")
	if player == null:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and player.global_position.distance_to(_last_spawn_pos) >= MIN_MOVE_DIST:
		_stamp(player)
		_spawn_timer = SPAWN_INTERVAL


func _stamp(player: Node2D) -> void:
	_last_spawn_pos = player.global_position
	var ghost := load("res://src/fx/PlayerTrailGhost.gd").new()
	get_parent().add_child(ghost)
	ghost.init(player.global_position, player.rotation, GHOST_LIFETIME)
	var world = GameState.current_world
	if world != null and world.has_method("start_search"):
		world.start_search(player.global_position, TRAIL_SEARCH_DUR, "SEARCH: TRAIL")
