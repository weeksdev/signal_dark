extends StaticBody2D

@export var open_in_combat: bool = false
@export var hack_radius: float = 96.0
@export var hack_duration: float = 10.0
@export var lockdown_only: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var fill: Polygon2D = $Fill
@onready var outline: Line2D = $Outline

var _open_from_dark_pocket: bool = false
var _open_from_hack: bool = false
var _closed_from_lockdown: bool = false
var _hack_preview_sequence: Array = []
var _hack_preview_progress: int = 0
var _hack_preview_wrong_flash: bool = false
var _hack_preview_flash: float = 0.0


func _ready() -> void:
	AlertSystem.combat_changed.connect(_on_combat_changed)
	ColorSystem.mode_changed.connect(_on_mode_changed)
	if InputManager != null and not InputManager.controller_layout_changed.is_connected(_on_controller_layout_changed):
		InputManager.controller_layout_changed.connect(_on_controller_layout_changed)
	_apply_state()


func _on_combat_changed(_active: bool) -> void:
	_apply_state()


func _on_mode_changed(_in_combat: bool) -> void:
	_apply_state()


func set_dark_pocket_open(active: bool) -> void:
	if _open_from_dark_pocket == active:
		return
	_open_from_dark_pocket = active
	_apply_state()


func can_be_hacked_by(ship: Node2D) -> bool:
	if lockdown_only:
		return false
	if ship == null:
		return false
	if is_open():
		return false
	return global_position.distance_to(ship.global_position) <= hack_radius


func set_hacked_open(active: bool) -> void:
	if _open_from_hack == active:
		return
	_open_from_hack = active
	_apply_state()


func set_lockdown_closed(active: bool) -> void:
	if _closed_from_lockdown == active:
		return
	_closed_from_lockdown = active
	_apply_state()


func set_hack_preview(sequence: Array, progress: int = 0, wrong_flash: bool = false) -> void:
	_hack_preview_sequence = sequence.duplicate()
	_hack_preview_progress = clampi(progress, 0, _hack_preview_sequence.size())
	_hack_preview_wrong_flash = wrong_flash
	_hack_preview_flash = 0.16 if wrong_flash else 0.0
	queue_redraw()


func is_open() -> bool:
	if lockdown_only:
		return not _closed_from_lockdown
	if _open_from_dark_pocket or _open_from_hack:
		return true
	return (open_in_combat and AlertSystem.combat_mode) and not _closed_from_lockdown


func is_lockdown_candidate() -> bool:
	return lockdown_only


func _process(delta: float) -> void:
	if _hack_preview_flash <= 0.0:
		return
	_hack_preview_flash = maxf(0.0, _hack_preview_flash - delta)
	queue_redraw()


func _apply_state() -> void:
	var open_now := is_open()
	collision_shape.set_deferred("disabled", open_now)
	fill.visible = not open_now
	outline.visible = not open_now
	if lockdown_only and open_now:
		modulate = Color(1.0, 1.0, 1.0, 0.0)
	else:
		modulate = Color(1.0, 1.0, 1.0, 0.28 if open_now else 1.0)
	queue_redraw()


func _draw() -> void:
	if lockdown_only and is_open():
		return
	if collision_shape.disabled:
		var c := ColorSystem.ui_color()
		draw_arc(Vector2.ZERO, 32.0, 0.0, TAU, 28, Color(c.r, c.g, c.b, 0.28), 1.3)
		draw_line(Vector2(-28.0, 0.0), Vector2(28.0, 0.0), Color(c.r, c.g, c.b, 0.22), 1.2)
		return
	_draw_hack_preview()


func _draw_hack_preview() -> void:
	if lockdown_only or _hack_preview_sequence.is_empty():
		return
	var ui := ColorSystem.ui_color()
	var wrong_mix := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 38.0) if _hack_preview_flash > 0.0 else 0.0
	var slot_y := -40.0
	var spacing := 22.0
	var radius := 8.0
	var start_x := -((_hack_preview_sequence.size() - 1) * spacing) * 0.5
	var font := ThemeDB.fallback_font
	for i in range(_hack_preview_sequence.size()):
		var center := Vector2(start_x + i * spacing, slot_y)
		var done := i < _hack_preview_progress
		var active := i == _hack_preview_progress and _hack_preview_progress < _hack_preview_sequence.size()
		var ring := Color(0.16, 0.18, 0.18, 0.9)
		var fill := Color(0.06, 0.08, 0.07, 0.82)
		var text := Color(0.72, 0.8, 0.74, 0.92)
		if done:
			ring = Color(0.35, 1.0, 0.52, 0.95)
			fill = Color(0.12, 0.32, 0.18, 0.92)
			text = Color(0.9, 1.0, 0.92, 1.0)
		elif active:
			ring = Color(0.95, 0.92, 0.36, 0.96)
			fill = Color(0.28, 0.24, 0.08, 0.92)
			text = Color(1.0, 0.98, 0.82, 1.0)
		if _hack_preview_flash > 0.0:
			ring = ring.lerp(Color(1.0, 0.26, 0.18, 1.0), wrong_mix)
			fill = fill.lerp(Color(0.42, 0.08, 0.06, 0.94), wrong_mix * 0.7)
		draw_circle(center, radius + 3.0, Color(ui.r, ui.g, ui.b, 0.06))
		draw_circle(center, radius, fill)
		draw_arc(center, radius, 0.0, TAU, 20, ring, 1.6)
		var label := InputManager.get_hack_button_display(str(_hack_preview_sequence[i]))
		draw_string(font, center + Vector2(-4.5, 4.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, text)


func _on_controller_layout_changed(_using_controller: bool) -> void:
	if not _hack_preview_sequence.is_empty():
		queue_redraw()
