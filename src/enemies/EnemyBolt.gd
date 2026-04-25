extends Area2D

@export var speed: float = 320.0
@export var lifetime: float = 2.2
@export var tint := Color("8affc9")

var direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta


func _draw() -> void:
	draw_line(Vector2(-7.0, 0.0), Vector2(7.0, 0.0), tint, 2.0)
	draw_circle(Vector2.ZERO, 2.5, Color(tint.r, tint.g, tint.b, 0.6))


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player_ship"):
		body.take_hit()
		queue_free()
