class_name ZoneGraphBuilder
extends RefCounted

const SeedRng := preload("res://src/arcade/ArcadeSeedRng.gd")
const ZoneGraph := preload("res://src/arcade/ArcadeZoneGraph.gd")

# Critical path should feel like a small maze run, not a straight hallway.
static func _path_length(floor_index: int) -> int:
	var base := 4 + floor_index
	match ArcadeState.difficulty:
		ArcadeState.Difficulty.EASY:
			base -= 1
		ArcadeState.Difficulty.HARDCORE:
			base += 1
	return clamp(base, 3, 8)

# Side branches should meaningfully complicate routing.
static func _branch_count(rng, floor_index: int) -> int:
	var min_branches := 2 + floor_index / 2
	var max_branches := 3 + floor_index
	match ArcadeState.difficulty:
		ArcadeState.Difficulty.EASY:
			min_branches -= 1
			max_branches -= 1
		ArcadeState.Difficulty.HARDCORE:
			min_branches += 1
			max_branches += 1
	return rng.randi_range(min_branches, min(max_branches, 5))


func build(rng, floor_index: int):
	var graph = ZoneGraph.new()
	var path_len := _path_length(floor_index)

	var start_id := graph.add_node(ZoneGraph.NodeType.START, 0, false)
	graph.start_node_id = start_id

	var prev_id := start_id
	for i in path_len:
		var depth := i + 1
		var node_type := _pick_node_type(rng, depth, path_len)
		var node_id := graph.add_node(node_type, depth, false)
		graph.add_edge(prev_id, node_id, _pick_width(rng, depth, path_len), false)
		graph.get_node(node_id).preferred_threat = _pick_threat(rng, depth, path_len, floor_index)
		prev_id = node_id

	var exit_id := graph.add_node(ZoneGraph.NodeType.EXIT, path_len + 1, false)
	graph.add_edge(prev_id, exit_id, 2, false)
	graph.exit_node_id = exit_id

	_add_branches(graph, rng, _branch_count(rng, floor_index), floor_index)
	graph.theme = _pick_theme(rng, floor_index)

	return graph


static func _pick_node_type(rng, depth: int, path_len: int) -> int:
	if depth == 1:
		return ZoneGraph.NodeType.CORRIDOR
	if depth == path_len and path_len >= 3 and rng.randi() % 3 == 0:
		return ZoneGraph.NodeType.SETPIECE_ROOM
	if rng.randi() % 3 == 0:
		return ZoneGraph.NodeType.CORRIDOR
	return ZoneGraph.NodeType.ROOM


static func _pick_width(rng, depth: int, path_len: int) -> int:
	match ArcadeState.difficulty:
		ArcadeState.Difficulty.EASY:
			if depth <= 2:
				return 3
			return 2 + rng.randi() % 2
		ArcadeState.Difficulty.HARDCORE:
			if depth == 1:
				return 1 + rng.randi() % 2
			if depth == path_len:
				return 1
			return 1 + rng.randi() % 2
		_:
			if depth == 1:
				return 2
			if depth == path_len:
				return 1 + rng.randi() % 2
			return 1 + rng.randi() % 3


static func _pick_threat(rng, depth: int, path_len: int, floor_index: int) -> int:
	if depth <= 1:
		return ZoneGraph.ThreatType.NONE
	var late := depth >= path_len
	var mid := depth > path_len / 2

	match floor_index:
		0:
			return ZoneGraph.ThreatType.SCANNER if late else ZoneGraph.ThreatType.NONE
		1:
			if late: return ZoneGraph.ThreatType.SWEEPER
			if mid:  return ZoneGraph.ThreatType.SCANNER
			return ZoneGraph.ThreatType.NONE

	# floor 2+: pick from a pool that grows with depth
	var pool := [ZoneGraph.ThreatType.SWEEPER, ZoneGraph.ThreatType.PULSAR]
	if mid:
		pool.append(ZoneGraph.ThreatType.HUNTER)
	if late:
		pool.append(ZoneGraph.ThreatType.MIXED)
	return pool[rng.randi() % pool.size()]


static func _pick_theme(rng, floor_index: int) -> int:
	if floor_index == 0:
		return ZoneGraph.ZoneTheme.STEALTH_MAZE
	var options: Array = [ZoneGraph.ZoneTheme.STEALTH_MAZE, ZoneGraph.ZoneTheme.PULSE_LATTICE]
	if floor_index >= 2:
		options.append_array([ZoneGraph.ZoneTheme.PRISM_LOCKDOWN, ZoneGraph.ZoneTheme.WARP_NEST])
	if floor_index >= 3:
		options.append(ZoneGraph.ZoneTheme.COMBAT_COLLAPSE)
	return options[rng.randi() % options.size()]


static func _add_branches(graph, rng, count: int, floor_index: int) -> void:
	var eligible: Array = []
	for node in graph.nodes:
		if not node.is_branch \
				and node.type != ZoneGraph.NodeType.START \
				and node.type != ZoneGraph.NodeType.EXIT:
			eligible.append(node.id)

	if eligible.is_empty():
		return

	for _i in count:
		if eligible.is_empty():
			break
		var parent_id: int = eligible[rng.randi() % eligible.size()]
		var parent = graph.get_node(parent_id)
		var branch_id: int = graph.add_node(ZoneGraph.NodeType.BRANCH_ROOM, parent.depth, true)
		var branch_width: int = 1
		if ArcadeState.difficulty != ArcadeState.Difficulty.HARDCORE:
			branch_width = 1 + rng.randi() % 2
		graph.add_edge(parent_id, branch_id, branch_width, true)
		graph.get_node(branch_id).preferred_threat = \
			_pick_threat(rng, parent.depth, parent.depth + 1, floor_index)
		eligible.erase(parent_id)
