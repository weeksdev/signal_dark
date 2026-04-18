extends Node

@export var pulse_shot_scene: PackedScene
@export var fire_cooldown: float = 0.18

var cooldown_remaining: float = 0.0


func _process(delta: float) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)


func try_fire(direction: Vector2) -> void:
	if cooldown_remaining > 0.0:
		return
	if direction == Vector2.ZERO:
		return
	cooldown_remaining = fire_cooldown
	AlertSystem.add_alert(0.12)
	var pulse_shot = pulse_shot_scene.instantiate()
	pulse_shot.global_position = get_parent().global_position + direction.normalized() * 22.0
	pulse_shot.direction = direction.normalized()
	get_tree().current_scene.add_child(pulse_shot)
