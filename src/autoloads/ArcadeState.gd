extends Node

const ARCADE_SCENE := "res://src/world/ArcadeWorld.tscn"
const FLOOR_COUNT  := 4
enum Difficulty { EASY, MEDIUM, HARDCORE }
const DIFFICULTY_NAMES := ["EASY", "MEDIUM", "HARDCORE"]

var run_seed:    int  = 0
var floor_index: int  = 0
var is_active:   bool = false
var difficulty:  int  = Difficulty.MEDIUM


func start_run(seed_val: int, difficulty_val: int = Difficulty.MEDIUM) -> void:
	run_seed    = seed_val
	floor_index = 0
	is_active   = true
	difficulty  = clampi(difficulty_val, Difficulty.EASY, Difficulty.HARDCORE)


func get_current_scene_path() -> String:
	return ARCADE_SCENE


func get_floor_seed() -> int:
	return run_seed * 10000 + floor_index


func advance() -> bool:
	floor_index += 1
	return floor_index < FLOOR_COUNT


func reset() -> void:
	is_active   = false
	run_seed    = 0
	floor_index = 0
	difficulty  = Difficulty.MEDIUM


func get_difficulty_name() -> String:
	return DIFFICULTY_NAMES[difficulty]
