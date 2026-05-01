extends Area2D

@export var gate_unlock_radius: float = 220.0

@onready var shape = $Shape


func _ready() -> void:
	add_to_group("dark_pocket")
	ColorSystem.mode_changed.connect(_on_mode_changed)
	_update_palette()


func _draw() -> void:
	var ui := ColorSystem.ui_color()
	var outer := PackedVector2Array([
		Vector2(0.0, -68.0),
		Vector2(48.0, -48.0),
		Vector2(68.0, 0.0),
		Vector2(48.0, 48.0),
		Vector2(0.0, 68.0),
		Vector2(-48.0, 48.0),
		Vector2(-68.0, 0.0),
		Vector2(-48.0, -48.0),
		Vector2(0.0, -68.0),
	])
	var inner := PackedVector2Array([
		Vector2(0.0, -46.0),
		Vector2(32.0, -32.0),
		Vector2(46.0, 0.0),
		Vector2(32.0, 32.0),
		Vector2(0.0, 46.0),
		Vector2(-32.0, 32.0),
		Vector2(-46.0, 0.0),
		Vector2(-32.0, -32.0),
		Vector2(0.0, -46.0),
	])

	draw_polygon(outer, [Color(0.0, 0.0, 0.0, 0.22)])
	draw_polygon(inner, [Color("081109")])
	draw_polyline(outer, Color(ui.r, ui.g, ui.b, 0.62), 1.1)
	draw_polyline(inner, Color(ui.r, ui.g, ui.b, 0.24), 0.6)

	draw_line(Vector2(-22.0, -22.0), Vector2(22.0, -22.0), Color(ui.r, ui.g, ui.b, 0.16), 0.5)
	draw_line(Vector2(-22.0, 0.0), Vector2(22.0, 0.0), Color(ui.r, ui.g, ui.b, 0.2), 0.5)
	draw_line(Vector2(-22.0, 22.0), Vector2(22.0, 22.0), Color(ui.r, ui.g, ui.b, 0.16), 0.5)
	draw_line(Vector2(-22.0, -22.0), Vector2(-22.0, 22.0), Color(ui.r, ui.g, ui.b, 0.14), 0.5)
	draw_line(Vector2(0.0, -22.0), Vector2(0.0, 22.0), Color(ui.r, ui.g, ui.b, 0.2), 0.5)
	draw_line(Vector2(22.0, -22.0), Vector2(22.0, 22.0), Color(ui.r, ui.g, ui.b, 0.14), 0.5)

	draw_line(Vector2(-54.0, -8.0), Vector2(-38.0, -8.0), Color(ui.r, ui.g, ui.b, 0.55), 0.5)
	draw_line(Vector2(38.0, -8.0), Vector2(54.0, -8.0), Color(ui.r, ui.g, ui.b, 0.55), 0.5)
	draw_line(Vector2(-54.0, 8.0), Vector2(-38.0, 8.0), Color(ui.r, ui.g, ui.b, 0.55), 0.5)
	draw_line(Vector2(38.0, 8.0), Vector2(54.0, 8.0), Color(ui.r, ui.g, ui.b, 0.55), 0.5)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player_ship"):
		body.in_dark_pocket = true
		var world := get_tree().current_scene
		if world != null and world.has_method("set_player_dark_pocket_state"):
			world.set_player_dark_pocket_state(self, true)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player_ship"):
		body.in_dark_pocket = false
		var world := get_tree().current_scene
		if world != null and world.has_method("set_player_dark_pocket_state"):
			world.set_player_dark_pocket_state(self, false)


func _update_palette() -> void:
	queue_redraw()


func _on_mode_changed(_in_combat: bool) -> void:
	_update_palette()
