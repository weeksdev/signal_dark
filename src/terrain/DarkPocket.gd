extends Area2D

@export var gate_unlock_radius: float = 220.0

@onready var shape = $Shape
@onready var hideout_visual: Sprite2D = $HideoutVisual


func _ready() -> void:
	add_to_group("dark_pocket")
	ColorSystem.mode_changed.connect(_on_mode_changed)
	_update_palette()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player_ship"):
		if body.has_method("set_dark_pocket_active"):
			body.set_dark_pocket_active(true)
		else:
			body.in_dark_pocket = true
		var world := get_tree().current_scene
		if world != null and world.has_method("set_player_dark_pocket_state"):
			world.set_player_dark_pocket_state(self, true)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player_ship"):
		if body.has_method("set_dark_pocket_active"):
			body.set_dark_pocket_active(false)
		else:
			body.in_dark_pocket = false
		var world := get_tree().current_scene
		if world != null and world.has_method("set_player_dark_pocket_state"):
			world.set_player_dark_pocket_state(self, false)


func _update_palette() -> void:
	if hideout_visual != null:
		hideout_visual.modulate = Color(0.82, 0.84, 0.83, 1.0) if ColorSystem.in_combat else Color(0.74, 0.76, 0.78, 1.0)


func _on_mode_changed(_in_combat: bool) -> void:
	_update_palette()
