extends SceneTree

# Loaded at runtime (inside _run) so autoloads are already initialized when
# these scripts are compiled — preload at module level would fail headless.
var _SeedRng    = null
var _Builder    = null
var _Assembler  = null
var _Placer     = null

const DEBRIS_ENEMY_MIN  := 64.0
const DEBRIS_POCKET_MIN := 96.0
const DEBRIS_SCRIPT     := "res://src/terrain/Debris.gd"
const POCKET_SCRIPT     := "res://src/terrain/DarkPocket.gd"


class TestWorld extends Node2D:
	var spawned_enemies: Array[Node] = []

	func register_spawned_enemy(enemy: Node) -> void:
		add_child(enemy)
		spawned_enemies.append(enemy)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_SeedRng   = load("res://src/arcade/ArcadeSeedRng.gd")
	_Builder   = load("res://src/arcade/ZoneGraphBuilder.gd")
	_Assembler = load("res://src/arcade/ModuleAssembler.gd")
	_Placer    = load("res://src/arcade/EncounterPlacer.gd")

	if _SeedRng == null or _Builder == null or _Assembler == null or _Placer == null:
		push_error("[spawn_overlap_test] Failed to load arcade scripts")
		quit(1)
		return

	var arcade_state := get_root().get_node_or_null("/root/ArcadeState")
	if arcade_state == null:
		push_error("[spawn_overlap_test] ArcadeState autoload missing")
		quit(1)
		return

	var test_cases: Array[Dictionary] = [
		{"seed": 12345, "floor": 0},
		{"seed": 12345, "floor": 1},
		{"seed": 12345, "floor": 2},
		{"seed": 99999, "floor": 0},
		{"seed": 99999, "floor": 2},
		{"seed": 54321, "floor": 1},
		{"seed": 11111, "floor": 3},
		{"seed": 77777, "floor": 3},
	]

	var all_violations: Array[String] = []

	for tc in test_cases:
		var seed_val: int = int(tc["seed"])
		var floor_idx: int = int(tc["floor"])

		arcade_state.start_run(seed_val)
		arcade_state.floor_index = floor_idx

		var result := await _test_floor(arcade_state, seed_val, floor_idx)
		if not result["ok"]:
			all_violations.append_array(result["violations"])

	if all_violations.is_empty():
		print("[spawn_overlap_test] PASS — no debris/enemy overlaps across %d configurations." % test_cases.size())
		quit(0)
	else:
		push_error("[spawn_overlap_test] FAIL — %d overlap violation(s):" % all_violations.size())
		for v in all_violations:
			push_error("  %s" % v)
		quit(1)


func _test_floor(arcade_state: Node, seed_val: int, floor_idx: int) -> Dictionary:
	var world := TestWorld.new()
	root.add_child(world)
	current_scene = world

	var rng   = _SeedRng.new(arcade_state.get_floor_seed())
	var graph = _Builder.new().build(rng, floor_idx)
	var asm   = _Assembler.new().assemble(world, graph)

	_Placer.new().place(
		world,
		graph,
		asm["node_rects"],
		asm["node_cells"],
		floor_idx,
	)

	await process_frame

	var enemy_positions:  Array[Vector2] = []
	var debris_positions: Array[Vector2] = []
	var pocket_positions: Array[Vector2] = []

	for child in world.get_children():
		if not is_instance_valid(child):
			continue
		if child is CharacterBody2D:
			enemy_positions.append(child.global_position)
		elif child is StaticBody2D:
			var scr: Script = child.get_script()
			if scr != null and scr.resource_path == DEBRIS_SCRIPT:
				debris_positions.append(child.global_position)
		elif child is Area2D:
			var scr: Script = child.get_script()
			if scr != null and scr.resource_path == POCKET_SCRIPT:
				pocket_positions.append(child.global_position)

	var violations: Array[String] = []

	for d_pos in debris_positions:
		for e_pos in enemy_positions:
			var dist := d_pos.distance_to(e_pos)
			if dist < DEBRIS_ENEMY_MIN:
				violations.append("seed=%d floor=%d: debris %s overlaps enemy %s (dist=%.1f)" % [seed_val, floor_idx, d_pos, e_pos, dist])

	for d_pos in debris_positions:
		for p_pos in pocket_positions:
			var dist := d_pos.distance_to(p_pos)
			if dist < DEBRIS_POCKET_MIN:
				violations.append("seed=%d floor=%d: debris %s overlaps pocket %s (dist=%.1f)" % [seed_val, floor_idx, d_pos, p_pos, dist])

	world.queue_free()
	await process_frame

	return {
		"ok": violations.is_empty(),
		"violations": violations,
	}
