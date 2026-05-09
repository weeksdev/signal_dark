class_name EncounterPlacer
extends RefCounted

const SeedRng := preload("res://src/arcade/ArcadeSeedRng.gd")
const ZoneGraph := preload("res://src/arcade/ArcadeZoneGraph.gd")
const SWEEPER_SCENE     := preload("res://src/enemies/Sweeper.tscn")
const PULSAR_SCENE      := preload("res://src/enemies/Pulsar.tscn")
const SENTRY_SCENE      := preload("res://src/enemies/Sentry.tscn")
const HUNTER_SCENE      := preload("res://src/enemies/Hunter.tscn")
const WISP_SCENE        := preload("res://src/enemies/Wisp.tscn")
const PRISM_SCENE       := preload("res://src/enemies/Prism.tscn")
const WARPMINE_SCENE    := preload("res://src/enemies/WarpMine.tscn")
const WALL_SENSOR_SCENE := preload("res://src/enemies/WallSensor.tscn")
const DARK_POCKET_SCENE := preload("res://src/terrain/DarkPocket.tscn")
const GATELOCK_SCENE    := preload("res://src/terrain/GateLock.tscn")

const COSTS := {
	"sweeper": 2,
	"pulsar":  2,
	"wisp":    2,
	"hunter":  3,
	"sentry":  3,
	"prism":   4,
	"warpmine": 4,
}

const ENEMY_MARGIN    := 126.0
const POCKET_MARGIN   := 104.0
const DOORWAY_CLEAR   := 148.0
const SPREAD_MIN      := 80.0
const CENTER_BIAS_PULL := 0.42
const POCKET_ENEMY_CLEAR := 132.0
const WISP_PAIR_MARGIN := 46.0
const WISP_ROUTE_CLEAR := 56.0
const TEMPLATE_DEFAULT := "default"
const TEMPLATE_MOVING_GAP_CORRIDOR := "moving_gap_corridor"
const TEMPLATE_CROSSING_SCANNERS := "crossing_scanners"
const TEMPLATE_GUARD_SCANNER_OVERLAP := "guard_scanner_overlap"
const TEMPLATE_BRANCH_BAIT := "branch_bait"
const TEMPLATE_SETPIECE_CROSSFIRE := "setpiece_crossfire"

# Room/corridor dimensions mirrored from ModuleAssembler (kept local to avoid cross-dependency)
const _ROOM_W   := 560.0
const _ROOM_H   := 420.0
const _CORRIDOR := 140.0

# Enemies unlocked per floor index (cumulative)
const FLOOR_POOLS: Array = [
	["sentry", "wisp", "sweeper"],
	["sentry", "wisp", "sweeper", "pulsar"],
	["sentry", "wisp", "sweeper", "pulsar", "hunter", "prism"],
	["sentry", "wisp", "sweeper", "pulsar", "hunter", "prism", "warpmine"],
]

var _theme: int = ZoneGraph.ZoneTheme.STEALTH_MAZE


func place(world: Node2D, graph,
		node_rects: Dictionary, node_cells: Dictionary, floor_index: int) -> void:
	var rng = SeedRng.new(ArcadeState.get_floor_seed() + 99991)
	_theme = graph.theme
	var max_depth := _max_depth(graph)
	var pool: Array = FLOOR_POOLS[mini(floor_index, FLOOR_POOLS.size() - 1)]
	var first_combat_room := true

	for node in graph.nodes:
		if node.type == ZoneGraph.NodeType.START:
			continue
		if node.type == ZoneGraph.NodeType.EXIT:
			continue
		if not node_rects.has(node.id):
			continue

		var rect: Rect2 = node_rects[node.id]
		var doorways := _doorway_centers(node.id, graph, node_cells, node_rects)
		var budget   := _room_budget(node, floor_index, max_depth)
		var plan: Dictionary = _build_encounter_plan(node, budget, pool, rng)
		var types: Array = plan.get("types", [])
		var template: String = str(plan.get("template", TEMPLATE_DEFAULT))

		var pocket_positions := _place_dark_pockets(world, rect, node, doorways, first_combat_room, floor_index, rng)
		_place_enemies(world, rect, node, types, template, doorways, pocket_positions, rng)
		_place_wall_sensors(world, rect, node, doorways, pocket_positions, rng)
		first_combat_room = false

	_place_gatelocks(world, graph, node_rects, node_cells, floor_index, rng)
	_place_lockdown_corridor_gates(world, graph, node_rects, node_cells)
	_place_debris(world, graph, node_rects, rng)


# ── Debris placement ─────────────────────────────────────────────────────────

const DEBRIS_MARGIN  := 52.0
const DEBRIS_SPACING := 48.0

func _place_debris(world: Node2D, graph, node_rects: Dictionary, rng) -> void:
	var debris_scene: PackedScene = load("res://src/terrain/Debris.tscn")
	if debris_scene == null:
		return
	for node in graph.nodes:
		if node.type == ZoneGraph.NodeType.START:
			continue
		if not node_rects.has(node.id):
			continue
		var rect: Rect2 = node_rects[node.id]
		var is_corridor: bool = node.type == ZoneGraph.NodeType.CORRIDOR
		var count: int = rng.randi_range(0, 1) if is_corridor else rng.randi_range(1, 3)
		var placed: Array = []
		for _i in count:
			var pos := _debris_pos(rect, placed, rng)
			if pos == Vector2.ZERO:
				continue
			var piece: Node2D = debris_scene.instantiate()
			piece.position = pos
			world.add_child(piece)
			placed.append(pos)


func _debris_pos(rect: Rect2, placed: Array, rng) -> Vector2:
	var inner := rect.grow(-DEBRIS_MARGIN)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return Vector2.ZERO
	for _attempt in 18:
		var pos := Vector2(
			rng.randf_range(inner.position.x, inner.end.x),
			rng.randf_range(inner.position.y, inner.end.y)
		)
		var clear := true
		for other in placed:
			if (pos as Vector2).distance_to(other) < DEBRIS_SPACING:
				clear = false
				break
		if clear:
			return pos
	return Vector2.ZERO


# ── Budget & composition ──────────────────────────────────────────────────────

func _max_depth(graph) -> int:
	var d := 1
	for n in graph.nodes:
		d = maxi(d, n.depth)
	return d


func _room_budget(node, floor_index: int, max_depth: int) -> int:
	var depth_ratio := float(node.depth) / float(max_depth)
	var raw := 2.0 + float(floor_index) + depth_ratio * float(floor_index)
	match ArcadeState.difficulty:
		ArcadeState.Difficulty.EASY:
			raw *= 0.82
		ArcadeState.Difficulty.HARDCORE:
			raw *= 1.22
	match node.type:
		ZoneGraph.NodeType.CORRIDOR:
			raw *= 0.72 if ArcadeState.difficulty == ArcadeState.Difficulty.HARDCORE else 0.6
		ZoneGraph.NodeType.BRANCH_ROOM:
			raw *= 0.7
		ZoneGraph.NodeType.SETPIECE_ROOM:
			raw *= 1.3
	return maxi(int(raw), 2)


func _pick_enemies(budget: int, preferred_threat: int, pool: Array, rng) -> Array:
	var result: Array = []
	var remaining := budget

	var lead := _threat_to_enemy(preferred_threat, pool, rng)
	lead = _apply_theme_bias(lead, pool, rng)
	if lead != "" and COSTS.get(lead, 999) <= remaining:
		result.append(lead)
		remaining -= COSTS[lead]

	var attempts := 0
	while remaining >= 2 and attempts < 12:
		attempts += 1
		var candidates: Array = []
		for t in pool:
			if COSTS.get(t, 999) <= remaining:
				candidates.append(t)
		if candidates.is_empty():
			break
		var pick: String = candidates[rng.randi() % candidates.size()]
		result.append(pick)
		remaining -= COSTS[pick]

	return result


func _build_encounter_plan(node, budget: int, pool: Array, rng) -> Dictionary:
	var template: String = TEMPLATE_DEFAULT
	var reserved: Array = []
	var remaining_budget: int = budget

	match node.type:
		ZoneGraph.NodeType.CORRIDOR:
			if "sweeper" in pool and remaining_budget >= COSTS["sweeper"] * 2:
				template = TEMPLATE_MOVING_GAP_CORRIDOR
				reserved = ["sweeper", "sweeper"]
			elif "wisp" in pool and remaining_budget >= COSTS["wisp"]:
				template = TEMPLATE_CROSSING_SCANNERS
				reserved = ["wisp"]
		ZoneGraph.NodeType.BRANCH_ROOM:
			if remaining_budget >= 5 and (("sentry" in pool) or ("pulsar" in pool)) and "wisp" in pool:
				template = TEMPLATE_BRANCH_BAIT
				reserved = ["wisp", _first_available(["sentry", "pulsar"], pool)]
		ZoneGraph.NodeType.SETPIECE_ROOM:
			if remaining_budget >= 5 and "wisp" in pool:
				template = TEMPLATE_SETPIECE_CROSSFIRE
				reserved = ["wisp"]
				var denial_pick: String = _first_available(["prism", "sentry", "pulsar", "hunter"], pool)
				if denial_pick != "":
					reserved.append(denial_pick)
		_:
			if remaining_budget >= 5 and "wisp" in pool and (("sentry" in pool) or ("prism" in pool) or ("pulsar" in pool)):
				template = TEMPLATE_GUARD_SCANNER_OVERLAP
				reserved = ["wisp", _first_available(["sentry", "prism", "pulsar"], pool)]
			elif remaining_budget >= COSTS["wisp"] and "wisp" in pool and rng.randi() % 100 < 55:
				template = TEMPLATE_CROSSING_SCANNERS
				reserved = ["wisp"]

	for t in reserved:
		remaining_budget -= int(COSTS.get(t, 0))
	remaining_budget = maxi(remaining_budget, 0)

	var filler: Array = _pick_enemies(remaining_budget, node.preferred_threat, pool, rng)
	var types: Array = reserved.duplicate()
	for t in filler:
		types.append(t)
	types = _tune_corridor_loadout(node, types, pool, rng)

	return {
		"template": template,
		"types": types,
	}


func _first_available(candidates: Array, pool: Array) -> String:
	for candidate in candidates:
		if pool.has(candidate):
			return str(candidate)
	return ""


func _tune_corridor_loadout(node, types: Array, pool: Array, rng) -> Array:
	if node.type != ZoneGraph.NodeType.CORRIDOR:
		return types

	var result: Array = types.duplicate()
	if ArcadeState.difficulty == ArcadeState.Difficulty.EASY:
		return result

	var corridor_pick := ""
	if "sweeper" in pool:
		corridor_pick = "sweeper"
	elif "sentry" in pool:
		corridor_pick = "sentry"
	elif "wisp" in pool:
		corridor_pick = "wisp"

	if corridor_pick != "" and not result.has(corridor_pick):
		result.push_front(corridor_pick)

	if ArcadeState.difficulty == ArcadeState.Difficulty.HARDCORE and "wisp" in pool and not result.has("wisp") and rng.randi() % 2 == 0:
		result.append("wisp")

	return result


func _threat_to_enemy(threat: int, pool: Array, rng) -> String:
	var preferred := ""
	match threat:
		ZoneGraph.ThreatType.SCANNER:
			if "sentry" in pool: preferred = "sentry"
			elif "wisp" in pool: preferred = "wisp"
		ZoneGraph.ThreatType.SWEEPER:
			if "sweeper" in pool: preferred = "sweeper"
		ZoneGraph.ThreatType.PULSAR:
			if "pulsar" in pool: preferred = "pulsar"
		ZoneGraph.ThreatType.HUNTER:
			if "hunter" in pool: preferred = "hunter"
		ZoneGraph.ThreatType.MIXED:
			if not pool.is_empty():
				preferred = pool[rng.randi() % pool.size()]
	return preferred


func _apply_theme_bias(lead: String, pool: Array, rng) -> String:
	match _theme:
		ZoneGraph.ZoneTheme.PULSE_LATTICE:
			if rng.randi() % 2 == 0:
				if "sweeper" in pool: return "sweeper"
				if "pulsar" in pool:  return "pulsar"
		ZoneGraph.ZoneTheme.PRISM_LOCKDOWN:
			if "prism" in pool and rng.randi() % 3 != 0:
				return "prism"
		ZoneGraph.ZoneTheme.WARP_NEST:
			if "warpmine" in pool and rng.randi() % 2 == 0:
				return "warpmine"
		ZoneGraph.ZoneTheme.COMBAT_COLLAPSE:
			if "hunter" in pool: return "hunter"
	return lead


# ── Enemy placement ───────────────────────────────────────────────────────────

func _place_enemies(world: Node2D, rect: Rect2, node, types: Array, template: String, doorways: Array, blocked_positions: Array, rng) -> void:
	var placed: Array = []
	var remaining_types: Array = types.duplicate()
	_apply_encounter_template(world, rect, node, template, remaining_types, doorways, blocked_positions, placed, rng)
	for t: String in remaining_types:
		var pos := _valid_pos(rect, doorways, placed, blocked_positions, rng, ENEMY_MARGIN)
		if pos == Vector2.ZERO:
			continue
		match t:
			"sweeper":
				placed.append(pos)
				_spawn_sweeper(world, pos, rect, node, doorways)
			"pulsar":
				placed.append(pos)
				_spawn_basic(world, PULSAR_SCENE, pos)
			"sentry":
				placed.append(pos)
				_spawn_basic(world, SENTRY_SCENE, pos)
			"hunter":
				placed.append(pos)
				_spawn_basic(world, HUNTER_SCENE, pos)
			"wisp":     _spawn_wisp_pair(world, pos, rect, node, doorways, placed)
			"prism":
				placed.append(pos)
				_spawn_basic(world, PRISM_SCENE, pos)
			"warpmine":
				placed.append(pos)
				_spawn_basic(world, WARPMINE_SCENE, pos)


func _apply_encounter_template(world: Node2D, rect: Rect2, node, template: String, remaining_types: Array, doorways: Array, blocked_positions: Array, placed: Array, rng) -> void:
	match template:
		TEMPLATE_MOVING_GAP_CORRIDOR:
			if _consume_type(remaining_types, "sweeper", 2):
				_spawn_corridor_sweeper_pair(world, rect, node, doorways, placed)
		TEMPLATE_CROSSING_SCANNERS:
			if _consume_type(remaining_types, "wisp", 1):
				var center := _template_anchor(rect, doorways, "center")
				_spawn_wisp_pair(world, center, rect, node, doorways, placed)
		TEMPLATE_GUARD_SCANNER_OVERLAP:
			if _consume_type(remaining_types, "wisp", 1):
				var center := _template_anchor(rect, doorways, "center")
				_spawn_wisp_pair(world, center, rect, node, doorways, placed)
			_spawn_template_denial(world, rect, remaining_types, doorways, blocked_positions, placed, rng, true)
		TEMPLATE_BRANCH_BAIT:
			if _consume_type(remaining_types, "wisp", 1):
				var side_center := _template_anchor(rect, doorways, "doorway_bias")
				_spawn_wisp_pair(world, side_center, rect, node, doorways, placed)
			_spawn_template_denial(world, rect, remaining_types, doorways, blocked_positions, placed, rng, false)
		TEMPLATE_SETPIECE_CROSSFIRE:
			if _consume_type(remaining_types, "wisp", 1):
				_spawn_wisp_pair(world, rect.get_center(), rect, node, doorways, placed)
			_spawn_template_denial(world, rect, remaining_types, doorways, blocked_positions, placed, rng, true)


func _consume_type(types: Array, type_name: String, count: int) -> bool:
	var found_indices: Array = []
	for i in range(types.size()):
		if str(types[i]) == type_name:
			found_indices.append(i)
			if found_indices.size() >= count:
				break
	if found_indices.size() < count:
		return false
	for i in range(found_indices.size() - 1, -1, -1):
		types.remove_at(int(found_indices[i]))
	return true


func _template_anchor(rect: Rect2, doorways: Array, mode: String) -> Vector2:
	if mode == "doorway_bias" and not doorways.is_empty():
		return _avg_points(doorways).lerp(rect.get_center(), 0.35)
	return rect.get_center()


func _spawn_template_denial(world: Node2D, rect: Rect2, remaining_types: Array, doorways: Array, blocked_positions: Array, placed: Array, rng, use_choke_point: bool) -> void:
	var denial_order: Array = ["prism", "sentry", "pulsar", "hunter"]
	for type_name in denial_order:
		if _consume_type(remaining_types, type_name, 1):
			var pos := _valid_pos(rect, doorways, placed, blocked_positions, rng, ENEMY_MARGIN)
			if use_choke_point:
				pos = _best_overlap_position(rect, doorways, placed, blocked_positions)
			placed.append(pos)
			match type_name:
				"prism":
					_spawn_basic(world, PRISM_SCENE, pos)
				"sentry":
					_spawn_basic(world, SENTRY_SCENE, pos)
				"pulsar":
					_spawn_basic(world, PULSAR_SCENE, pos)
				"hunter":
					_spawn_basic(world, HUNTER_SCENE, pos)
			return


func _best_overlap_position(rect: Rect2, doorways: Array, placed: Array, blocked_positions: Array) -> Vector2:
	if doorways.is_empty():
		return rect.get_center()
	var doorway_center := _avg_points(doorways)
	var center := rect.get_center()
	var candidate := doorway_center.lerp(center, 0.38)
	for blocked: Vector2 in blocked_positions:
		if candidate.distance_to(blocked) < POCKET_ENEMY_CLEAR:
			candidate = center.lerp(candidate, 0.55)
	for other: Vector2 in placed:
		if candidate.distance_to(other) < SPREAD_MIN:
			candidate = candidate.move_toward(center, SPREAD_MIN * 0.45)
	return candidate.clamp(rect.position + Vector2(ENEMY_MARGIN, ENEMY_MARGIN), rect.end - Vector2(ENEMY_MARGIN, ENEMY_MARGIN))


func _spawn_basic(world: Node2D, scene: PackedScene, pos: Vector2) -> void:
	var enemy: Node2D = scene.instantiate()
	enemy.position = pos
	world.register_spawned_enemy(enemy)


func _spawn_wall_sensor(world: Node2D, pos: Vector2, facing_rotation: float) -> void:
	var sensor: Node2D = WALL_SENSOR_SCENE.instantiate()
	sensor.position = pos
	sensor.rotation = facing_rotation
	world.register_spawned_enemy(sensor)


func _place_wall_sensors(world: Node2D, rect: Rect2, node, doorways: Array, blocked_positions: Array, rng) -> void:
	var chance := 0
	match node.type:
		ZoneGraph.NodeType.CORRIDOR:
			chance = 58
		ZoneGraph.NodeType.SETPIECE_ROOM:
			chance = 62
		ZoneGraph.NodeType.BRANCH_ROOM:
			chance = 34
		_:
			chance = 42
	match ArcadeState.difficulty:
		ArcadeState.Difficulty.EASY:
			chance = maxi(chance - 18, 8)
		ArcadeState.Difficulty.HARDCORE:
			chance = mini(chance + 18, 90)
	if rng.randi() % 100 >= chance:
		return
	var count := 1
	if ArcadeState.difficulty == ArcadeState.Difficulty.HARDCORE and node.type != ZoneGraph.NodeType.BRANCH_ROOM and rng.randi() % 100 < 35:
		count = 2
	var candidates := _wall_sensor_candidates(rect, node, doorways, blocked_positions)
	if candidates.is_empty():
		return
	for _i in range(count):
		if candidates.is_empty():
			break
		var pick_index: int = rng.randi() % candidates.size()
		var data: Dictionary = candidates[pick_index]
		candidates.remove_at(pick_index)
		_spawn_wall_sensor(world, data["position"], data["rotation"])


func _spawn_sweeper(world: Node2D, pos: Vector2, room_rect: Rect2, node, doorways: Array) -> void:
	var patrol_layout := _build_sweeper_patrol_layout(room_rect.grow(-72.0), pos, doorways, node.type)
	var patrol_points: Array = patrol_layout.get("points", [])
	var start_index := 0
	if node.type == ZoneGraph.NodeType.CORRIDOR and patrol_points.size() >= 4:
		start_index = 1
	_spawn_pattern_sweeper(world, patrol_layout, start_index, 1, pos)


func _spawn_pattern_sweeper(world: Node2D, patrol_layout: Dictionary, start_index: int, step: int, fallback_pos: Vector2) -> void:
	var sweeper: Node2D = SWEEPER_SCENE.instantiate()
	var patrol_points: Array = patrol_layout.get("points", [])
	var choke_indices: Array = patrol_layout.get("choke_indices", [])
	if patrol_points.is_empty():
		patrol_points = [fallback_pos]
	choke_indices = _clamp_patrol_indices(choke_indices, patrol_points.size())
	var safe_start_index: int = clampi(start_index, 0, patrol_points.size() - 1)
	sweeper.position = patrol_points[safe_start_index]
	sweeper.set("patrol_points", patrol_points)
	sweeper.set("choke_indices", choke_indices)
	sweeper.set("patrol_start_index", safe_start_index)
	sweeper.set("patrol_step", step)

	world.register_spawned_enemy(sweeper)


func _spawn_corridor_sweeper_pair(world: Node2D, room_rect: Rect2, node, doorways: Array, placed: Array) -> void:
	var center := room_rect.get_center()
	var patrol_layout := _build_sweeper_patrol_layout(room_rect.grow(-72.0), center, doorways, node.type)
	var patrol_points: Array = patrol_layout.get("points", [])
	if patrol_points.is_empty():
		patrol_points = [center]
	var first_index := 0
	var second_index := 0
	if patrol_points.size() >= 4:
		first_index = 1
		second_index = clampi(int(patrol_points.size() / 2) + 1, 0, patrol_points.size() - 1)
	elif patrol_points.size() >= 2:
		second_index = patrol_points.size() - 1
	_spawn_pattern_sweeper(world, patrol_layout, first_index, 1, center)
	_spawn_pattern_sweeper(world, patrol_layout, second_index, -1, center)
	placed.append(patrol_points[clampi(first_index, 0, patrol_points.size() - 1)])
	placed.append(patrol_points[clampi(second_index, 0, patrol_points.size() - 1)])


func _spawn_wisp_pair(world: Node2D, center: Vector2, room_rect: Rect2, node, doorways: Array, placed: Array) -> void:
	var inner := room_rect.grow(-WISP_PAIR_MARGIN)
	if inner.size.x <= 24.0 or inner.size.y <= 24.0:
		inner = room_rect.grow(-ENEMY_MARGIN)
	if inner.size.x <= 24.0 or inner.size.y <= 24.0:
		inner = room_rect
	var patrol_layout := _build_wisp_patrol_layout(inner, center, doorways, node.type)
	var patrol_points: Array = patrol_layout["points"]
	if patrol_points.is_empty():
		patrol_points = [center]
	var choke_indices: Array = patrol_layout["choke_indices"]
	choke_indices = _clamp_patrol_indices(choke_indices, patrol_points.size())
	var first_choke_index: int = clampi(int(patrol_layout["primary_choke"]), 0, patrol_points.size() - 1)
	var opposite_index := clampi(int(patrol_layout["opposite_start"]), 0, patrol_points.size() - 1)
	var first_pos: Vector2 = patrol_points[first_choke_index]
	var second_pos: Vector2 = patrol_points[opposite_index]

	_spawn_routed_wisp(world, first_pos, patrol_points, choke_indices, first_choke_index, 1)
	_spawn_routed_wisp(world, second_pos, patrol_points, choke_indices, opposite_index, -1)
	placed.append(first_pos)
	placed.append(second_pos)


func _spawn_routed_wisp(world: Node2D, pos: Vector2, patrol_points: Array, choke_indices: Array, start_index: int, step: int) -> void:
	var wisp = WISP_SCENE.instantiate()
	wisp.position = pos
	wisp.set("use_route_patrol", true)
	wisp.set("patrol_points", patrol_points)
	wisp.set("choke_indices", choke_indices)
	wisp.set("_patrol_index", start_index)
	wisp.set("patrol_step", step)
	if patrol_points.size() >= 2:
		var longest_leg := 0.0
		for i in range(patrol_points.size() - 1):
			longest_leg = maxf(longest_leg, patrol_points[i].distance_to(patrol_points[i + 1]))
		wisp.set("patrol_radius", maxf(longest_leg * 0.4, WISP_ROUTE_CLEAR))
	world.register_spawned_enemy(wisp)


func _clamp_patrol_indices(indices: Array, point_count: int) -> Array:
	if point_count <= 0:
		return []
	var clamped: Array = []
	for index in indices:
		var safe_index := clampi(int(index), 0, point_count - 1)
		if not clamped.has(safe_index):
			clamped.append(safe_index)
	return clamped if not clamped.is_empty() else [0]


func _build_sweeper_patrol_layout(inner: Rect2, center: Vector2, doorways: Array, node_type: int) -> Dictionary:
	if inner.size.x <= 24.0 or inner.size.y <= 24.0:
		inner = Rect2(center - Vector2(80.0, 60.0), Vector2(160.0, 120.0))
	match node_type:
		ZoneGraph.NodeType.CORRIDOR:
			return _build_sweeper_corridor_layout(inner, center, doorways)
		_:
			return _build_sweeper_room_layout(inner, center, doorways)


func _build_sweeper_corridor_layout(inner: Rect2, center: Vector2, doorways: Array) -> Dictionary:
	var horizontal: bool = _corridor_is_horizontal(doorways, inner)
	var points: Array = []
	var choke_indices: Array = []
	if horizontal:
		var left_entry := _best_side_doorway_point(doorways, inner, "left", Vector2(inner.position.x + 34.0, center.y))
		var right_entry := _best_side_doorway_point(doorways, inner, "right", Vector2(inner.end.x - 34.0, center.y))
		var patrol_y := clampf(center.y, inner.position.y + 26.0, inner.end.y - 26.0)
		points = [
			Vector2(left_entry.x, patrol_y),
			Vector2(inner.position.x + inner.size.x * 0.12, patrol_y),
			Vector2(inner.position.x + inner.size.x * 0.24, patrol_y),
			Vector2(inner.position.x + inner.size.x * 0.36, patrol_y),
			Vector2(inner.position.x + inner.size.x * 0.50, patrol_y),
			Vector2(inner.position.x + inner.size.x * 0.64, patrol_y),
			Vector2(inner.position.x + inner.size.x * 0.76, patrol_y),
			Vector2(inner.position.x + inner.size.x * 0.88, patrol_y),
			Vector2(right_entry.x, patrol_y),
		]
		choke_indices = [0, 8]
	else:
		var top_entry := _best_side_doorway_point(doorways, inner, "top", Vector2(center.x, inner.position.y + 34.0))
		var bottom_entry := _best_side_doorway_point(doorways, inner, "bottom", Vector2(center.x, inner.end.y - 34.0))
		var patrol_x := clampf(center.x, inner.position.x + 26.0, inner.end.x - 26.0)
		points = [
			Vector2(patrol_x, top_entry.y),
			Vector2(patrol_x, inner.position.y + inner.size.y * 0.12),
			Vector2(patrol_x, inner.position.y + inner.size.y * 0.24),
			Vector2(patrol_x, inner.position.y + inner.size.y * 0.36),
			Vector2(patrol_x, inner.position.y + inner.size.y * 0.50),
			Vector2(patrol_x, inner.position.y + inner.size.y * 0.64),
			Vector2(patrol_x, inner.position.y + inner.size.y * 0.76),
			Vector2(patrol_x, inner.position.y + inner.size.y * 0.88),
			Vector2(patrol_x, bottom_entry.y),
		]
		choke_indices = [0, 8]
	return _finalize_wisp_layout(points, choke_indices, 0, 4)


func _build_sweeper_room_layout(inner: Rect2, center: Vector2, doorways: Array) -> Dictionary:
	var points: Array = [
		_best_side_doorway_point(doorways, inner, "left", Vector2(inner.position.x + 28.0, center.y)),
		Vector2(inner.position.x + inner.size.x * 0.22, inner.position.y + 32.0),
		_best_side_doorway_point(doorways, inner, "top", Vector2(center.x, inner.position.y + 28.0)),
		Vector2(inner.end.x - inner.size.x * 0.22, inner.position.y + 32.0),
		_best_side_doorway_point(doorways, inner, "right", Vector2(inner.end.x - 28.0, center.y)),
		Vector2(inner.end.x - inner.size.x * 0.22, inner.end.y - 32.0),
		_best_side_doorway_point(doorways, inner, "bottom", Vector2(center.x, inner.end.y - 28.0)),
		Vector2(inner.position.x + inner.size.x * 0.22, inner.end.y - 32.0),
	]
	var choke_indices: Array = []
	for i in [0, 2, 4, 6]:
		var side: String = ["left", "top", "right", "bottom"][i / 2]
		if _side_has_doorway(doorways, inner, side):
			choke_indices.append(i)
	if choke_indices.is_empty():
		choke_indices = [0, 4]
	return _finalize_wisp_layout(points, choke_indices, int(choke_indices[0]), posmod(int(choke_indices[0]) + 4, points.size()))


func _wall_sensor_candidates(rect: Rect2, node, doorways: Array, blocked_positions: Array) -> Array:
	var inner := rect.grow(-26.0)
	var candidates: Array = []
	var fractions: Array = [0.34, 0.66]
	var horizontal_corridor: bool = node.type == ZoneGraph.NodeType.CORRIDOR and _corridor_is_horizontal(doorways, inner)
	var allowed_sides: Array = []
	if node.type == ZoneGraph.NodeType.CORRIDOR:
		allowed_sides = ["top", "bottom"] if horizontal_corridor else ["left", "right"]
	else:
		allowed_sides = ["left", "top", "right", "bottom"]
	for side in allowed_sides:
		for fraction in fractions:
			var candidate := _wall_sensor_candidate_for_side(inner, side, float(fraction))
			if not _wall_sensor_candidate_clear(candidate["position"], side, rect, doorways, blocked_positions):
				continue
			candidates.append(candidate)
	return candidates


func _wall_sensor_candidate_for_side(inner: Rect2, side: String, fraction: float) -> Dictionary:
	match side:
		"left":
			return {"position": Vector2(inner.position.x + 10.0, lerpf(inner.position.y + 32.0, inner.end.y - 32.0, fraction)), "rotation": 0.0}
		"right":
			return {"position": Vector2(inner.end.x - 10.0, lerpf(inner.position.y + 32.0, inner.end.y - 32.0, fraction)), "rotation": PI}
		"top":
			return {"position": Vector2(lerpf(inner.position.x + 32.0, inner.end.x - 32.0, fraction), inner.position.y + 10.0), "rotation": PI * 0.5}
		_:
			return {"position": Vector2(lerpf(inner.position.x + 32.0, inner.end.x - 32.0, fraction), inner.end.y - 10.0), "rotation": -PI * 0.5}


func _wall_sensor_candidate_clear(pos: Vector2, side: String, rect: Rect2, doorways: Array, blocked_positions: Array) -> bool:
	for doorway in doorways:
		var point: Vector2 = doorway
		if _nearest_rect_side(point, rect) != side:
			continue
		if pos.distance_to(point) < DOORWAY_CLEAR * 0.78:
			return false
	for blocked in blocked_positions:
		if pos.distance_to(blocked) < POCKET_ENEMY_CLEAR:
			return false
	return true

func _build_wisp_patrol_layout(inner: Rect2, center: Vector2, doorways: Array, node_type: int) -> Dictionary:
	match node_type:
		ZoneGraph.NodeType.CORRIDOR:
			return _build_wisp_corridor_layout(inner, center, doorways)
		ZoneGraph.NodeType.BRANCH_ROOM:
			return _build_wisp_branch_layout(inner, center, doorways)
		ZoneGraph.NodeType.SETPIECE_ROOM:
			return _build_wisp_room_layout(inner, center, doorways, 20.0)
		_:
			return _build_wisp_room_layout(inner, center, doorways, 18.0)


func _build_wisp_corridor_layout(inner: Rect2, center: Vector2, doorways: Array) -> Dictionary:
	var horizontal: bool = _corridor_is_horizontal(doorways, inner)
	var points: Array = []
	var choke_indices: Array = []
	if horizontal:
		var left_entry := _best_side_doorway_point(doorways, inner, "left", Vector2(inner.position.x + 30.0, center.y))
		var right_entry := _best_side_doorway_point(doorways, inner, "right", Vector2(inner.end.x - 30.0, center.y))
		var top_lane := inner.position.y + 22.0
		var bottom_lane := inner.end.y - 22.0
		points = [
			Vector2(left_entry.x, top_lane),
			Vector2(inner.position.x + inner.size.x * 0.22, top_lane),
			Vector2(inner.position.x + inner.size.x * 0.42, top_lane),
			Vector2(right_entry.x, top_lane),
			right_entry,
			Vector2(right_entry.x, bottom_lane),
			Vector2(inner.position.x + inner.size.x * 0.58, bottom_lane),
			Vector2(inner.position.x + inner.size.x * 0.78, bottom_lane),
			Vector2(left_entry.x, bottom_lane),
			left_entry,
		]
		choke_indices = [4, 9]
	else:
		var top_entry := _best_side_doorway_point(doorways, inner, "top", Vector2(center.x, inner.position.y + 30.0))
		var bottom_entry := _best_side_doorway_point(doorways, inner, "bottom", Vector2(center.x, inner.end.y - 30.0))
		var left_lane := inner.position.x + 22.0
		var right_lane := inner.end.x - 22.0
		points = [
			Vector2(left_lane, top_entry.y),
			Vector2(left_lane, inner.position.y + inner.size.y * 0.22),
			Vector2(left_lane, inner.position.y + inner.size.y * 0.42),
			Vector2(left_lane, bottom_entry.y),
			bottom_entry,
			Vector2(right_lane, bottom_entry.y),
			Vector2(right_lane, inner.position.y + inner.size.y * 0.58),
			Vector2(right_lane, inner.position.y + inner.size.y * 0.78),
			Vector2(right_lane, top_entry.y),
			top_entry,
		]
		choke_indices = [4, 9]
	return _finalize_wisp_layout(points, choke_indices, points.size() - 1, int(points.size() / 2))


func _build_wisp_branch_layout(inner: Rect2, center: Vector2, doorways: Array) -> Dictionary:
	var layout := _build_wisp_room_layout(inner, center, doorways, 18.0)
	var choke_indices: Array = layout["choke_indices"]
	if not choke_indices.is_empty():
		layout["primary_choke"] = int(choke_indices[0])
		layout["opposite_start"] = posmod(int(choke_indices[0]) + int(layout["points"].size() / 2), layout["points"].size())
	return layout


func _build_wisp_room_layout(inner: Rect2, center: Vector2, doorways: Array, corner_inset: float) -> Dictionary:
	var edge_points := {
		"left": _best_side_doorway_point(doorways, inner, "left", Vector2(inner.position.x + 28.0, center.y)),
		"top": _best_side_doorway_point(doorways, inner, "top", Vector2(center.x, inner.position.y + 28.0)),
		"right": _best_side_doorway_point(doorways, inner, "right", Vector2(inner.end.x - 28.0, center.y)),
		"bottom": _best_side_doorway_point(doorways, inner, "bottom", Vector2(center.x, inner.end.y - 28.0)),
	}
	var points: Array = [
		edge_points["left"],
		Vector2(inner.position.x + corner_inset, inner.position.y + corner_inset),
		edge_points["top"],
		Vector2(inner.end.x - corner_inset, inner.position.y + corner_inset),
		edge_points["right"],
		Vector2(inner.end.x - corner_inset, inner.end.y - corner_inset),
		edge_points["bottom"],
		Vector2(inner.position.x + corner_inset, inner.end.y - corner_inset),
	]
	var choke_indices: Array = []
	for i in [0, 2, 4, 6]:
		var side: String = ["left", "top", "right", "bottom"][i / 2]
		if _side_has_doorway(doorways, inner, side):
			choke_indices.append(i)
	if choke_indices.is_empty():
		choke_indices = [0, 4]
	return _finalize_wisp_layout(points, choke_indices, int(choke_indices[0]), posmod(int(choke_indices[0]) + 4, points.size()))


func _finalize_wisp_layout(points: Array, choke_indices: Array, primary_choke: int, opposite_start: int) -> Dictionary:
	points = _clean_patrol_points(points)
	if points.is_empty():
		points.append(Vector2.ZERO)
	if points.size() < 2:
		points.append(points[0] + Vector2(72.0, 0.0))
	var cleaned_chokes: Array = []
	for index in choke_indices:
		var safe_index := clampi(int(index), 0, points.size() - 1)
		if not cleaned_chokes.has(safe_index):
			cleaned_chokes.append(safe_index)
	choke_indices = cleaned_chokes if not cleaned_chokes.is_empty() else [0]
	primary_choke = clampi(primary_choke, 0, points.size() - 1)
	opposite_start = clampi(opposite_start, 0, points.size() - 1)
	return {
		"points": points,
		"choke_indices": choke_indices,
		"primary_choke": primary_choke,
		"opposite_start": opposite_start,
	}


func _clean_patrol_points(points: Array) -> Array:
	var cleaned: Array = []
	for point in points:
		var p: Vector2 = point
		if cleaned.is_empty() or p.distance_to(cleaned[cleaned.size() - 1]) >= 28.0:
			cleaned.append(p)
	if cleaned.size() > 2 and cleaned[0].distance_to(cleaned[cleaned.size() - 1]) < 28.0:
		cleaned.remove_at(cleaned.size() - 1)
	return cleaned


func _corridor_is_horizontal(doorways: Array, inner: Rect2) -> bool:
	var left_or_right := 0
	var top_or_bottom := 0
	for doorway in doorways:
		var point: Vector2 = doorway
		if absf(point.x - inner.position.x) <= 6.0 or absf(point.x - inner.end.x) <= 6.0:
			left_or_right += 1
		elif absf(point.y - inner.position.y) <= 6.0 or absf(point.y - inner.end.y) <= 6.0:
			top_or_bottom += 1
	if left_or_right == top_or_bottom:
		return inner.size.x >= inner.size.y
	return left_or_right > top_or_bottom


func _doorway_patrol_point(doorway: Vector2, inner: Rect2) -> Vector2:
	var inset := 26.0
	var point := doorway
	match _nearest_rect_side(doorway, inner):
		"left":
			point.x = inner.position.x + inset
		"right":
			point.x = inner.end.x - inset
		"top":
			point.y = inner.position.y + inset
		"bottom":
			point.y = inner.end.y - inset
	return point.clamp(inner.position, inner.end)


func _avg_points(points: Array) -> Vector2:
	var total := Vector2.ZERO
	for point in points:
		total += point
	return total / float(points.size())


func _best_side_doorway_point(doorways: Array, inner: Rect2, side: String, fallback: Vector2) -> Vector2:
	var matches: Array = []
	for doorway in doorways:
		var point: Vector2 = doorway
		match side:
			"left":
				if _nearest_rect_side(point, inner) == "left":
					matches.append(_doorway_patrol_point(point, inner))
			"right":
				if _nearest_rect_side(point, inner) == "right":
					matches.append(_doorway_patrol_point(point, inner))
			"top":
				if _nearest_rect_side(point, inner) == "top":
					matches.append(_doorway_patrol_point(point, inner))
			"bottom":
				if _nearest_rect_side(point, inner) == "bottom":
					matches.append(_doorway_patrol_point(point, inner))
	if matches.is_empty():
		return fallback
	return _avg_points(matches)


func _side_has_doorway(doorways: Array, inner: Rect2, side: String) -> bool:
	for doorway in doorways:
		var point: Vector2 = doorway
		match side:
			"left":
				if _nearest_rect_side(point, inner) == "left":
					return true
			"right":
				if _nearest_rect_side(point, inner) == "right":
					return true
			"top":
				if _nearest_rect_side(point, inner) == "top":
					return true
			"bottom":
				if _nearest_rect_side(point, inner) == "bottom":
					return true
	return false


func _nearest_rect_side(point: Vector2, rect: Rect2) -> String:
	var left := absf(point.x - rect.position.x)
	var right := absf(point.x - rect.end.x)
	var top := absf(point.y - rect.position.y)
	var bottom := absf(point.y - rect.end.y)
	var best := minf(minf(left, right), minf(top, bottom))
	if best == left:
		return "left"
	if best == right:
		return "right"
	if best == top:
		return "top"
	return "bottom"


# ── Gate lock placement ───────────────────────────────────────────────────────

func _place_gatelocks(world: Node2D, graph,
		node_rects: Dictionary, node_cells: Dictionary, floor_index: int, rng) -> void:
	if floor_index < 1:
		return

	# Probability per corridor edge: floor 1=30%, floor 2=50%, floor 3+=66%
	var gate_pct: int = [0, 30, 50, 66][mini(floor_index, 3)]
	match ArcadeState.difficulty:
		ArcadeState.Difficulty.EASY:
			gate_pct = maxi(gate_pct - 18, 0)
		ArcadeState.Difficulty.HARDCORE:
			gate_pct = mini(gate_pct + 18, 90)

	# PRISM_LOCKDOWN and WARP_NEST themes emphasise gates
	if _theme == ZoneGraph.ZoneTheme.PRISM_LOCKDOWN:
		gate_pct = mini(gate_pct + 25, 80)

	for edge in graph.edges:
		if edge.is_branch:
			continue
		if not node_rects.has(edge.from_id) or not node_rects.has(edge.to_id):
			continue
		if not node_cells.has(edge.from_id) or not node_cells.has(edge.to_id):
			continue
		var from_node = graph.get_node(edge.from_id)
		if from_node == null or from_node.type == ZoneGraph.NodeType.START:
			continue  # keep spawn approach clear
		if rng.randi() % 100 >= gate_pct:
			continue
		_spawn_gatelock(world,
			node_rects[edge.from_id], node_rects[edge.to_id],
			node_cells[edge.from_id], node_cells[edge.to_id])


func _spawn_gatelock(world: Node2D, rect_a: Rect2, rect_b: Rect2,
		cell_a: Vector2i, cell_b: Vector2i) -> void:
	var diff := cell_b - cell_a
	var gate: Node2D = GATELOCK_SCENE.instantiate()

	if diff == Vector2i(1, 0):
		gate.position = Vector2(rect_a.position.x + _ROOM_W + _CORRIDOR * 0.5, rect_a.get_center().y)
		gate.rotation = PI * 0.5
	elif diff == Vector2i(-1, 0):
		gate.position = Vector2(rect_b.position.x + _ROOM_W + _CORRIDOR * 0.5, rect_a.get_center().y)
		gate.rotation = PI * 0.5
	elif diff == Vector2i(0, 1):
		gate.position = Vector2(rect_a.get_center().x, rect_a.position.y + _ROOM_H + _CORRIDOR * 0.5)
	elif diff == Vector2i(0, -1):
		gate.position = Vector2(rect_a.get_center().x, rect_b.position.y + _ROOM_H + _CORRIDOR * 0.5)
	else:
		gate.queue_free()
		return

	world.add_child(gate)


func _place_lockdown_corridor_gates(world: Node2D, graph,
		node_rects: Dictionary, node_cells: Dictionary) -> void:
	for edge in graph.edges:
		if not node_rects.has(edge.from_id) or not node_rects.has(edge.to_id):
			continue
		if not node_cells.has(edge.from_id) or not node_cells.has(edge.to_id):
			continue
		var gate: Node2D = _make_corridor_gatelock(
			node_rects[edge.from_id], node_rects[edge.to_id],
			node_cells[edge.from_id], node_cells[edge.to_id]
		)
		if gate == null:
			continue
		gate.name = "LockdownGate_%d_%d" % [edge.from_id, edge.to_id]
		gate.set("lockdown_only", true)
		gate.set("open_in_combat", true)
		world.add_child(gate)


func _make_corridor_gatelock(rect_a: Rect2, rect_b: Rect2,
		cell_a: Vector2i, cell_b: Vector2i) -> Node2D:
	var diff: Vector2i = cell_b - cell_a
	var gate: Node2D = GATELOCK_SCENE.instantiate()

	if diff == Vector2i(1, 0):
		gate.position = Vector2(rect_a.position.x + _ROOM_W + _CORRIDOR * 0.5, rect_a.get_center().y)
		gate.rotation = PI * 0.5
	elif diff == Vector2i(-1, 0):
		gate.position = Vector2(rect_b.position.x + _ROOM_W + _CORRIDOR * 0.5, rect_a.get_center().y)
		gate.rotation = PI * 0.5
	elif diff == Vector2i(0, 1):
		gate.position = Vector2(rect_a.get_center().x, rect_a.position.y + _ROOM_H + _CORRIDOR * 0.5)
	elif diff == Vector2i(0, -1):
		gate.position = Vector2(rect_a.get_center().x, rect_b.position.y + _ROOM_H + _CORRIDOR * 0.5)
	else:
		gate.queue_free()
		return null

	return gate


# ── Dark pocket placement ─────────────────────────────────────────────────────

func _place_dark_pockets(world: Node2D, rect: Rect2, node,
		doorways: Array, force_one: bool, floor_index: int, rng) -> Array:
	var count := 0
	if force_one:
		count = 1
	elif node.type == ZoneGraph.NodeType.BRANCH_ROOM:
		count = 1
	elif node.type == ZoneGraph.NodeType.SETPIECE_ROOM:
		count = 1 + (1 if floor_index >= 2 else 0)
	elif floor_index >= 1 and rng.randi() % 3 == 0:
		count = 1

	# STEALTH_MAZE theme adds an extra pocket chance in regular rooms
	if _theme == ZoneGraph.ZoneTheme.STEALTH_MAZE and count == 0 and rng.randi() % 2 == 0:
		count = 1
	if ArcadeState.difficulty == ArcadeState.Difficulty.EASY and count == 0 and rng.randi() % 2 == 0:
		count = 1
	if ArcadeState.difficulty == ArcadeState.Difficulty.HARDCORE and node.type == ZoneGraph.NodeType.CORRIDOR:
		count = maxi(0, count - 1)

	var placed: Array = []
	for _i in count:
		var pos := _valid_pos(rect, doorways, placed, [], rng, POCKET_MARGIN)
		placed.append(pos)
		var pocket: Node2D = DARK_POCKET_SCENE.instantiate()
		pocket.position = pos
		world.add_child(pocket)
	return placed


# ── Helpers ───────────────────────────────────────────────────────────────────

func _doorway_centers(node_id: int, graph,
		node_cells: Dictionary, node_rects: Dictionary) -> Array:
	var centers: Array = []
	if not node_cells.has(node_id) or not node_rects.has(node_id):
		return centers
	var cell: Vector2i = node_cells[node_id]
	var rect: Rect2    = node_rects[node_id]
	var cx := rect.get_center().x
	var cy := rect.get_center().y

	for edge in graph.edges:
		var other_id := -1
		if edge.from_id == node_id:
			other_id = edge.to_id
		elif edge.to_id == node_id:
			other_id = edge.from_id
		if other_id < 0 or not node_cells.has(other_id):
			continue
		var diff: Vector2i = node_cells[other_id] - cell
		var center: Vector2 = Vector2.ZERO
		if diff == Vector2i(1, 0):    center = Vector2(rect.position.x + rect.size.x, cy)
		elif diff == Vector2i(-1, 0): center = Vector2(rect.position.x, cy)
		elif diff == Vector2i(0, 1):  center = Vector2(cx, rect.position.y + rect.size.y)
		elif diff == Vector2i(0, -1): center = Vector2(cx, rect.position.y)
		if center != Vector2.ZERO:
			centers.append(center)
	return centers


func _valid_pos(rect: Rect2, doorways: Array, placed: Array, blocked_positions: Array, rng, margin: float) -> Vector2:
	var inner := rect.grow(-margin)
	if inner.size.x <= 4.0 or inner.size.y <= 4.0:
		return rect.get_center()
	var center: Vector2 = inner.get_center()
	var best_pos := center
	var best_score := -INF

	for _attempt in 30:
		var pos := Vector2(
			inner.position.x + rng.randf() * inner.size.x,
			inner.position.y + rng.randf() * inner.size.y,
		)
		pos = pos.lerp(center, CENTER_BIAS_PULL)
		var score := _placement_clearance_score(pos, doorways, placed, blocked_positions)
		if score > best_score:
			best_score = score
			best_pos = pos
		if _is_valid_placement(pos, doorways, placed, blocked_positions):
			return pos

	if _is_valid_placement(best_pos, doorways, placed, blocked_positions):
		return best_pos

	# If cramped, still accept best_pos unless it violates pocket clearance.
	for blocked: Vector2 in blocked_positions:
		if best_pos.distance_to(blocked) < POCKET_ENEMY_CLEAR:
			return Vector2.ZERO
	return best_pos


func _is_valid_placement(pos: Vector2, doorways: Array, placed: Array, blocked_positions: Array) -> bool:
	for dp: Vector2 in doorways:
		if pos.distance_to(dp) < DOORWAY_CLEAR:
			return false
	for pp: Vector2 in placed:
		if pos.distance_to(pp) < SPREAD_MIN:
			return false
	for blocked: Vector2 in blocked_positions:
		if pos.distance_to(blocked) < POCKET_ENEMY_CLEAR:
			return false
	return true


func _placement_clearance_score(pos: Vector2, doorways: Array, placed: Array, blocked_positions: Array) -> float:
	var score := 0.0
	for blocked: Vector2 in blocked_positions:
		score += minf(pos.distance_to(blocked), POCKET_ENEMY_CLEAR * 2.0) * 3.0
	for dp: Vector2 in doorways:
		score += minf(pos.distance_to(dp), DOORWAY_CLEAR * 1.5)
	for pp: Vector2 in placed:
		score += minf(pos.distance_to(pp), SPREAD_MIN * 1.5)
	return score
