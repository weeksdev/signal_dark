extends Area2D

@export var travel_speed: float = 420.0
@export var max_distance: float = 220.0
@export var active_duration: float = 4.0

var direction: Vector2 = Vector2.ZERO
var anchor_position: Vector2 = Vector2.ZERO
var lodged: bool = false


func _ready() -> void:
	anchor_position = global_position


func _physics_process(delta: float) -> void:
	if lodged:
		return
	global_position += direction * travel_speed * delta
	if anchor_position.distance_to(global_position) >= max_distance:
		_lodge()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 7.0, Color("5cf2ff"))
	draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 32, Color("5cf2ff"), 2.0)


func _on_body_entered(_body: Node) -> void:
	_lodge()


func _lodge() -> void:
	if lodged:
		return
	lodged = true
	set_physics_process(false)
	if get_tree().current_scene.has_method("register_probe"):
		get_tree().current_scene.register_probe(global_position, active_duration)
	var timer := get_tree().create_timer(active_duration)
	timer.timeout.connect(queue_free)
