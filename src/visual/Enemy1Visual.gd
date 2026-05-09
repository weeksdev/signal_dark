extends Node2D

const _SHADOW_SHADER := """
shader_type canvas_item;
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.55);
uniform float blur_size = 2.0;
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * blur_size;
	float a = 0.0;
	a += texture(TEXTURE, UV + vec2(-px.x, -px.y)).a;
	a += texture(TEXTURE, UV + vec2( 0.0,  -px.y)).a;
	a += texture(TEXTURE, UV + vec2( px.x, -px.y)).a;
	a += texture(TEXTURE, UV + vec2(-px.x,  0.0)).a;
	a += texture(TEXTURE, UV).a;
	a += texture(TEXTURE, UV + vec2( px.x,  0.0)).a;
	a += texture(TEXTURE, UV + vec2(-px.x,  px.y)).a;
	a += texture(TEXTURE, UV + vec2( 0.0,   px.y)).a;
	a += texture(TEXTURE, UV + vec2( px.x,  px.y)).a;
	a /= 9.0;
	COLOR = vec4(shadow_color.rgb, a * shadow_color.a);
}
"""

@onready var sprite: Sprite2D = $Sprite2D
@onready var glow_sprite: Sprite2D = $GlowSprite2D

var _shadow: Sprite2D = null


func _ready() -> void:
	if sprite == null:
		return
	_shadow = Sprite2D.new()
	_shadow.texture = sprite.texture
	_shadow.position = Vector2(10.0, 14.0)
	_shadow.z_index = 0
	var mat := ShaderMaterial.new()
	var shdr := Shader.new()
	shdr.code = _SHADOW_SHADER
	mat.shader = shdr
	_shadow.material = mat
	add_child(_shadow)
	move_child(_shadow, 0)


func apply_palette(fill_color: Color, outline_color: Color, combat_active: bool, alerting: bool, emp_disabled: bool) -> void:
	sprite.scale = Vector2.ONE * (0.034 if not combat_active else 0.035)
	glow_sprite.scale = Vector2(0.040, 0.026) if not combat_active else Vector2(0.041, 0.027)
	if _shadow != null:
		_shadow.scale = Vector2(sprite.scale.x * 1.15, sprite.scale.y * 0.55)
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
