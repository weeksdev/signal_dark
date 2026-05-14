extends Node2D

const TRAVEL_SPEED := 280.0
const TRAVEL_DISTANCE := 180.0
const LIFETIME := 8.0
const PULSE_INTERVAL := 1.5
const SEARCH_DURATION := 3.5

var direction: Vector2 = Vector2.ZERO
var _anchor: Vector2 = Vector2.ZERO
var _traveling: bool = true
var _lifetime_remaining: float = LIFETIME
var _pulse_timer: float = 0.0
var _blink_t: float = 0.0


func _ready() -> void:
	add_to_group("player_drone")
	_anchor = global_position


func _process(delta: float) -> void:
	_lifetime_remaining -= delta
	if _lifetime_remaining <= 0.0:
		queue_free()
		return
	_blink_t += delta

	if _traveling:
		global_position += direction * TRAVEL_SPEED * delta
		if global_position.distance_to(_anchor) >= TRAVEL_DISTANCE:
			_traveling = false
			_anchor = global_position
			_send_search_pulse()
	else:
		_pulse_timer -= delta
		if _pulse_timer <= 0.0:
			_pulse_timer = PULSE_INTERVAL
			_send_search_pulse()

	queue_redraw()


func _draw() -> void:
	var alpha := 0.55 + 0.45 * sin(_blink_t * 3.5)
	var fade := clampf(_lifetime_remaining / 1.2, 0.0, 1.0)
	draw_circle(Vector2.ZERO, 3.5, Color(0.38, 0.88, 0.58, alpha * fade))
	draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 16, Color(0.38, 0.88, 0.58, alpha * 0.45 * fade), 1.0)


func _send_search_pulse() -> void:
	var world := get_tree().current_scene
	if world != null and world.has_method("start_search"):
		world.start_search(global_position, SEARCH_DURATION, "SEARCH: DRONE")
