extends Area2D

@export var speed: float = 760.0
@export var lifetime: float = 1.2

var direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta


func _draw() -> void:
	draw_line(Vector2(-10.0, 0.0), Vector2(10.0, 0.0), Color("8af7ff"), 3.0)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("zone_enemy"):
		body.take_damage(false, global_position)
		queue_free()
	elif body.collision_layer & 4 != 0:
		queue_free()
