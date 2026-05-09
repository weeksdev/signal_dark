extends StaticBody2D

const ElectricSparks = preload("res://src/fx/ElectricSparks.gd")

func _ready() -> void:
	rotation = randf() * TAU
	var sparks: Node2D = ElectricSparks.new()
	sparks.radius = 20.0
	sparks.intensity = 0.28
	sparks.z_index = 4
	add_child(sparks)
