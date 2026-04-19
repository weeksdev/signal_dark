extends StaticBody2D

@export var open_in_combat: bool = true

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var fill: Polygon2D = $Fill
@onready var outline: Line2D = $Outline


func _ready() -> void:
	AlertSystem.combat_changed.connect(_on_combat_changed)
	ColorSystem.mode_changed.connect(_on_mode_changed)
	_apply_state()


func _on_combat_changed(_active: bool) -> void:
	_apply_state()


func _on_mode_changed(_in_combat: bool) -> void:
	_apply_state()


func _apply_state() -> void:
	var is_open := open_in_combat and AlertSystem.combat_mode
	collision_shape.disabled = is_open
	fill.visible = not is_open
	outline.visible = not is_open
	modulate = Color(1.0, 1.0, 1.0, 0.28 if is_open else 1.0)
	queue_redraw()


func _draw() -> void:
	if collision_shape.disabled:
		var c := ColorSystem.ui_color()
		draw_arc(Vector2.ZERO, 32.0, 0.0, TAU, 28, Color(c.r, c.g, c.b, 0.28), 1.3)
		draw_line(Vector2(-28.0, 0.0), Vector2(28.0, 0.0), Color(c.r, c.g, c.b, 0.22), 1.2)
