class_name ObjectiveNode
extends Area2D

signal objective_completed(node: ObjectiveNode)

@export var radius: float = 42.0
@export var objective_name: String = "UPLINK"
@export var accent_color: Color = Color("4fbf68")

var completed: bool = false
var _pulse: float = 0.0


func _ready() -> void:
	monitoring = true
	monitorable = true
	collision_layer = 0
	collision_mask = 0
	if get_node_or_null("CollisionShape2D") == null:
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = radius
		shape.shape = circle
		shape.name = "CollisionShape2D"
		add_child(shape)
	else:
		var existing := get_node("CollisionShape2D")
		if existing.shape is CircleShape2D:
			existing.shape.radius = radius


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func can_be_triggered_by(ship: Node2D) -> bool:
	if completed or ship == null:
		return false
	return global_position.distance_to(ship.global_position) <= radius + 18.0


func complete() -> void:
	if completed:
		return
	completed = true
	objective_completed.emit(self)
	queue_redraw()


func _draw() -> void:
	var breathe: float = 0.55 + 0.45 * sin(_pulse * 2.0)
	var c: Color = accent_color
	if completed:
		draw_circle(Vector2.ZERO, radius * 1.3, Color(c.r, c.g, c.b, 0.04))
		draw_circle(Vector2.ZERO, radius, Color(c.r, c.g, c.b, 0.08))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(c.r, c.g, c.b, 0.55), 2.2)
		draw_arc(Vector2.ZERO, radius * 0.58, 0.0, TAU, 28, Color(c.r, c.g, c.b, 0.28), 1.2)
		return

	draw_circle(Vector2.ZERO, radius * 2.2, Color(c.r, c.g, c.b, 0.03 * breathe))
	draw_circle(Vector2.ZERO, radius * 1.55, Color(c.r, c.g, c.b, 0.055 * breathe))
	draw_circle(Vector2.ZERO, radius * 1.05, Color(c.r, c.g, c.b, 0.08 * breathe))
	draw_circle(Vector2.ZERO, radius * 0.72, Color(c.r, c.g, c.b, 0.11 * breathe))
	draw_arc(Vector2.ZERO, radius * 1.45, 0.0, TAU, 48, Color(c.r, c.g, c.b, 0.22 * breathe), 1.4)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(c.r, c.g, c.b, 0.78 * breathe), 2.4)
	draw_arc(Vector2.ZERO, radius * 0.52, 0.0, TAU, 28, Color(c.r, c.g, c.b, 0.32 * breathe), 1.4)
	draw_line(Vector2(-14.0, 0.0), Vector2(14.0, 0.0), Color(c.r, c.g, c.b, 0.55), 1.8)
	draw_line(Vector2(0.0, -14.0), Vector2(0.0, 14.0), Color(c.r, c.g, c.b, 0.55), 1.8)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-26.0, -(radius + 18.0)), objective_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(c.r, c.g, c.b, 0.88))
	draw_string(font, Vector2(-22.0, radius + 16.0), "HACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(c.r, c.g, c.b, 0.72))
