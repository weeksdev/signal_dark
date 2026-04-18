extends Area2D

@onready var shape = $Shape


func _ready() -> void:
	ColorSystem.mode_changed.connect(_on_mode_changed)
	_update_palette()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 68.0, Color(0.0, 0.0, 0.0, 0.14))
	draw_circle(Vector2.ZERO, 58.0, Color("0a160d"))
	draw_circle(Vector2.ZERO, 42.0, Color("081109"))
	draw_arc(Vector2.ZERO, 58.0, 0.0, TAU, 48, Color(0.23, 0.83, 0.42, 0.55), 2.0)
	draw_arc(Vector2.ZERO, 44.0, 0.0, TAU, 48, Color(0.18, 0.7, 0.36, 0.22), 1.0)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player_ship"):
		body.in_dark_pocket = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player_ship"):
		body.in_dark_pocket = false


func _update_palette() -> void:
	queue_redraw()


func _on_mode_changed(_in_combat: bool) -> void:
	_update_palette()
