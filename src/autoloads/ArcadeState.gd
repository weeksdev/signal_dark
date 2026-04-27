extends Node

const ARCADE_SCENE := "res://src/world/ArcadeWorld.tscn"
const FLOOR_COUNT  := 4
enum Difficulty { EASY, MEDIUM, HARDCORE }
const DIFFICULTY_NAMES := ["EASY", "MEDIUM", "HARDCORE"]

var run_seed:    int  = 0
var floor_index: int  = 0
var is_active:   bool = false
var difficulty:  int  = Difficulty.MEDIUM
var run_started_msec: int = 0
var completed_floors: int = 0
var total_kills: int = 0
var total_suppressed_kills: int = 0
var total_alerts_triggered: int = 0
var total_hacks_completed: int = 0
var total_probes_used: int = 0
var last_summary: Dictionary = {}
var music_resume_positions: Dictionary = {}


func start_run(seed_val: int, difficulty_val: int = Difficulty.MEDIUM) -> void:
	run_seed    = seed_val
	floor_index = 0
	is_active   = true
	difficulty  = clampi(difficulty_val, Difficulty.EASY, Difficulty.HARDCORE)
	run_started_msec = Time.get_ticks_msec()
	completed_floors = 0
	total_kills = 0
	total_suppressed_kills = 0
	total_alerts_triggered = 0
	total_hacks_completed = 0
	total_probes_used = 0
	last_summary = {}
	music_resume_positions = {}


func get_current_scene_path() -> String:
	return ARCADE_SCENE


func get_floor_seed() -> int:
	return run_seed * 10000 + floor_index


func advance() -> bool:
	floor_index += 1
	return floor_index < FLOOR_COUNT


func is_final_floor() -> bool:
	return floor_index >= FLOOR_COUNT - 1


func record_floor_result(stats: Dictionary, cleared: bool) -> void:
	total_kills += int(stats.get("kills", 0))
	total_suppressed_kills += int(stats.get("suppressed_kills", 0))
	total_alerts_triggered += int(stats.get("alerts_triggered", 0))
	total_hacks_completed += int(stats.get("hacks_completed", 0))
	total_probes_used += int(stats.get("probes_used", 0))
	if cleared:
		completed_floors = maxi(completed_floors, floor_index + 1)


func build_run_summary(completed: bool) -> Dictionary:
	var elapsed_seconds := maxf(0.0, float(Time.get_ticks_msec() - run_started_msec) / 1000.0)
	var loud_kills := maxi(total_kills - total_suppressed_kills, 0)
	var discipline := clampi(int(round(
		100.0
		- float(total_alerts_triggered) * 18.0
		- float(loud_kills) * 8.0
		- float(total_probes_used) * 3.0
		+ float(total_hacks_completed) * 4.0
	)), 0, 100)
	var score := 0
	score += completed_floors * 1500
	score += 2200 if completed else 0
	score += total_suppressed_kills * 120
	score += total_hacks_completed * 140
	score += discipline * 25
	score -= total_alerts_triggered * 220
	score -= loud_kills * 80
	score -= int(elapsed_seconds * 6.0)
	score = maxi(score, 0)
	var rating := "BURNED"
	if total_alerts_triggered == 0 and total_kills == 0:
		rating = "GHOST"
	elif total_alerts_triggered == 0 and total_kills == total_suppressed_kills:
		rating = "SILENT"
	elif total_alerts_triggered <= 1 and loud_kills <= maxi(1, completed_floors):
		rating = "SURGICAL"
	last_summary = {
		"seed": run_seed,
		"difficulty": get_difficulty_name(),
		"floors_cleared": completed_floors,
		"floor_count": FLOOR_COUNT,
		"time_seconds": elapsed_seconds,
		"kills": total_kills,
		"suppressed_kills": total_suppressed_kills,
		"alerts_triggered": total_alerts_triggered,
		"hacks_completed": total_hacks_completed,
		"probes_used": total_probes_used,
		"signal_discipline": discipline,
		"score": score,
		"rating": rating,
		"completed": completed,
	}
	return last_summary


func reset() -> void:
	is_active   = false
	run_seed    = 0
	floor_index = 0
	difficulty  = Difficulty.MEDIUM
	run_started_msec = 0
	completed_floors = 0
	total_kills = 0
	total_suppressed_kills = 0
	total_alerts_triggered = 0
	total_hacks_completed = 0
	total_probes_used = 0
	last_summary = {}
	music_resume_positions = {}


func set_music_resume_position(mode: StringName, position: float) -> void:
	if mode == &"":
		return
	music_resume_positions[mode] = position


func get_music_resume_position(mode: StringName, fallback: float = 0.0) -> float:
	return float(music_resume_positions.get(mode, fallback))


func get_difficulty_name() -> String:
	return DIFFICULTY_NAMES[difficulty]
