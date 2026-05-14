extends StaticBody2D

const ElectricSparks = preload("res://src/fx/ElectricSparks.gd")

const _TEXTURES := [
	"res://assets/debris_1.png",
	"res://assets/debris_2.png",
]

func _ready() -> void:
	rotation = randf() * TAU
	var sprite := $Sprite2D as Sprite2D
	if sprite != null:
		sprite.texture = load(_TEXTURES[randi() % _TEXTURES.size()])
	var sparks: Node2D = ElectricSparks.new()
	sparks.radius = 20.0
	sparks.intensity = 0.28
	sparks.z_index = 4
	add_child(sparks)
