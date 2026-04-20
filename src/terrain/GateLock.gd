extends StaticBody2D

@export var open_in_combat: bool = true
@export var hack_radius: float = 96.0
@export var hack_duration: float = 10.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var fill: Polygon2D = $Fill
@onready var outline: Line2D = $Outline

var _open_from_dark_pocket: bool = false
var _open_from_hack: bool = false


func _ready() -> void:
	AlertSystem.combat_changed.connect(_on_combat_changed)
	ColorSystem.mode_changed.connect(_on_mode_changed)
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


func is_open() -> bool:
	return _open_from_dark_pocket or _open_from_hack or (open_in_combat and AlertSystem.combat_mode)


func _apply_state() -> void:
	var open_now := is_open()
	collision_shape.set_deferred("disabled", open_now)
	fill.visible = not open_now
	outline.visible = not open_now
	modulate = Color(1.0, 1.0, 1.0, 0.28 if open_now else 1.0)
	queue_redraw()


func _draw() -> void:
	if collision_shape.disabled:
		var c := ColorSystem.ui_color()
		draw_arc(Vector2.ZERO, 32.0, 0.0, TAU, 28, Color(c.r, c.g, c.b, 0.28), 1.3)
		draw_line(Vector2(-28.0, 0.0), Vector2(28.0, 0.0), Color(c.r, c.g, c.b, 0.22), 1.2)
