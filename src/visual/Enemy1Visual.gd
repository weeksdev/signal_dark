extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var glow_sprite: Sprite2D = $GlowSprite2D


func apply_palette(fill_color: Color, outline_color: Color, combat_active: bool, alerting: bool, emp_disabled: bool) -> void:
	sprite.scale = Vector2.ONE * (0.0265 if not combat_active else 0.0275)
	glow_sprite.scale = Vector2(0.031, 0.02) if not combat_active else Vector2(0.032, 0.021)
	if emp_disabled:
		sprite.modulate = Color(0.82, 0.96, 1.0, 1.0)
		glow_sprite.modulate = Color(0.82, 0.96, 1.0, 0.7)
	elif alerting and not combat_active:
		sprite.modulate = Color(1.0, 0.92, 0.9, 1.0)
		glow_sprite.modulate = Color(1.0, 0.42, 0.18, 0.7)
	elif combat_active:
		sprite.modulate = Color(1.0, 0.98, 0.94, 1.0)
		glow_sprite.modulate = Color(outline_color.r, outline_color.g, outline_color.b, 0.76)
	else:
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		glow_sprite.modulate = Color(outline_color.r, outline_color.g, outline_color.b, 0.68)
