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

const ENEMY_MARGIN    := 80.0
const POCKET_MARGIN   := 90.0
const DOORWAY_CLEAR   := 130.0
const SPREAD_MIN      := 80.0

# Room/corridor dimensions mirrored from ModuleAssembler (kept local to avoid cross-dependency)
const _ROOM_W   := 480.0
const _ROOM_H   := 360.0
const _CORRIDOR := 120.0

# Enemies unlocked per floor index (cumulative)
const FLOOR_POOLS: Array = [
	["sentry", "wisp"],
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
		var types    := _pick_enemies(budget, node.preferred_threat, pool, rng)

		_place_enemies(world, rect, types, doorways, rng)
		_place_dark_pockets(world, rect, node, doorways, first_combat_room, floor_index, rng)
		first_combat_room = false

	_place_gatelocks(world, graph, node_rects, node_cells, floor_index, rng)


# ── Budget & composition ──────────────────────────────────────────────────────

func _max_depth(graph) -> int:
	var d := 1
	for n in graph.nodes:
		d = maxi(d, n.depth)
	return d


func _room_budget(node, floor_index: int, max_depth: int) -> int:
	var depth_ratio := float(node.depth) / float(max_depth)
	var raw := 2.0 + float(floor_index) + depth_ratio * float(floor_index)
	match node.type:
		ZoneGraph.NodeType.CORRIDOR:
			raw *= 0.6
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

func _place_enemies(world: Node2D, rect: Rect2, types: Array, doorways: Array, rng) -> void:
	var placed: Array = []
	for t: String in types:
		var pos := _valid_pos(rect, doorways, placed, rng, ENEMY_MARGIN)
		placed.append(pos)
		match t:
			"sweeper":  _spawn_sweeper(world, pos, rect)
			"pulsar":   _spawn_basic(world, PULSAR_SCENE, pos)
			"sentry":   _spawn_basic(world, SENTRY_SCENE, pos)
			"hunter":   _spawn_basic(world, HUNTER_SCENE, pos)
			"wisp":     _spawn_basic(world, WISP_SCENE, pos)
			"prism":    _spawn_basic(world, PRISM_SCENE, pos)
			"warpmine": _spawn_basic(world, WARPMINE_SCENE, pos)


func _spawn_basic(world: Node2D, scene: PackedScene, pos: Vector2) -> void:
	var enemy: Node2D = scene.instantiate()
	enemy.position = pos
	world.register_spawned_enemy(enemy)


func _spawn_sweeper(world: Node2D, pos: Vector2, room_rect: Rect2) -> void:
	var sweeper: Node2D = SWEEPER_SCENE.instantiate()
	sweeper.position = pos

	var patrol_range: float
	var patrol_dir: Vector2
	if room_rect.size.x >= room_rect.size.y:
		patrol_range = minf(room_rect.size.x * 0.28, 130.0)
		patrol_dir   = Vector2.RIGHT
	else:
		patrol_range = minf(room_rect.size.y * 0.28, 110.0)
		patrol_dir   = Vector2.DOWN

	var inner   := room_rect.grow(-60.0)
	var a_world := (pos + patrol_dir * patrol_range).clamp(inner.position, inner.end)
	var b_world := (pos - patrol_dir * patrol_range).clamp(inner.position, inner.end)

	sweeper.get_node("PatrolA").position = a_world - pos
	sweeper.get_node("PatrolB").position = b_world - pos

	world.register_spawned_enemy(sweeper)


# ── Gate lock placement ───────────────────────────────────────────────────────

func _place_gatelocks(world: Node2D, graph,
		node_rects: Dictionary, node_cells: Dictionary, floor_index: int, rng) -> void:
	if floor_index < 1:
		return

	# Probability per corridor edge: floor 1=30%, floor 2=50%, floor 3+=66%
	var gate_pct: int = [0, 30, 50, 66][mini(floor_index, 3)]

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


# ── Dark pocket placement ─────────────────────────────────────────────────────

func _place_dark_pockets(world: Node2D, rect: Rect2, node,
		doorways: Array, force_one: bool, floor_index: int, rng) -> void:
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

	var placed: Array = []
	for _i in count:
		var pos := _valid_pos(rect, doorways, placed, rng, POCKET_MARGIN)
		placed.append(pos)
		var pocket: Node2D = DARK_POCKET_SCENE.instantiate()
		pocket.position = pos
		world.add_child(pocket)


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


func _valid_pos(rect: Rect2, doorways: Array, placed: Array, rng, margin: float) -> Vector2:
	var inner := rect.grow(-margin)
	if inner.size.x <= 4.0 or inner.size.y <= 4.0:
		return rect.get_center()

	for _attempt in 14:
		var pos := Vector2(
			inner.position.x + rng.randf() * inner.size.x,
			inner.position.y + rng.randf() * inner.size.y,
		)
		var ok := true
		for dp: Vector2 in doorways:
			if pos.distance_to(dp) < DOORWAY_CLEAR:
				ok = false
				break
		if ok:
			for pp: Vector2 in placed:
				if pos.distance_to(pp) < SPREAD_MIN:
					ok = false
					break
		if ok:
			return pos

	return inner.get_center() + Vector2(
		rng.randf_range(-30.0, 30.0),
		rng.randf_range(-30.0, 30.0)
	)
