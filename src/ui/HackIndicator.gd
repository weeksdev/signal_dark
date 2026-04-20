extends Node2D

var _visible_state: bool = false
var _pulse: float = 0.0
var _sequence: Array = []
var _current_index: int = 0
var _flash_wrong: float = 0.0


func _ready() -> void:
	top_level = true
	z_index = 200
	visible = false


func _process(delta: float) -> void:
	_pulse += delta
	_flash_wrong = maxf(0.0, _flash_wrong - delta * 2.8)
	if _visible_state:
		queue_redraw()


func update_indicator(active: bool, world_pos: Vector2, sequence: Array, current_index: int, wrong_flash: bool) -> void:
	_visible_state = active
	visible = active
	if not active:
		return
	global_position = world_pos
	global_rotation = 0.0
	_sequence = sequence
	_current_index = current_index
	if wrong_flash:
		_flash_wrong = 1.0
	queue_redraw()


func _draw() -> void:
	var spacing := 38.0
	var start_x := -((_sequence.size() - 1) * spacing) * 0.5
	var font := ThemeDB.fallback_font
	for i in range(_sequence.size()):
		var x := start_x + float(i) * spacing
		var center := Vector2(x, 0.0)
		var pulse := 0.78 + 0.22 * sin(_pulse * 6.0)
		var bg := Color(0.04, 0.06, 0.05, 0.9)
		var ring := Color(0.35, 0.39, 0.37, 0.78)
		var text_col := Color(0.85, 0.9, 0.87, 0.96)

		if i < _current_index:
			ring = Color(0.24, 0.92, 0.48, 0.95)
		elif i == _current_index:
			ring = Color(0.24, 0.92, 0.48, 0.45 + 0.4 * pulse)
		if _flash_wrong > 0.0 and i == _current_index:
			ring = Color(1.0, 0.35, 0.3, 0.55 + 0.35 * _flash_wrong)

		draw_circle(center, 18.0, Color(0.0, 0.0, 0.0, 0.16))
		draw_circle(center, 15.0, bg)
		draw_arc(center, 15.0, 0.0, TAU, 32, ring, 3.6)
		draw_circle(center, 10.0, Color(0.08, 0.11, 0.09, 0.96))
		draw_string(font, center + Vector2(-5.5, 5.5), str(_sequence[i]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, text_col)
