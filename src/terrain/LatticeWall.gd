extends StaticBody2D

@onready var fill = $Fill
@onready var outline = $Outline


func _ready() -> void:
	ColorSystem.mode_changed.connect(_on_mode_changed)
	_update_palette()


func _process(_delta: float) -> void:
	if ColorSystem.in_combat:
		queue_redraw()


func _update_palette() -> void:
	fill.color = ColorSystem.terrain_fill()
	outline.visible = false  # drawn manually in _draw() without end caps
	queue_redraw()


func _on_mode_changed(_in_combat: bool) -> void:
	_update_palette()


func _draw() -> void:
	var rect := Rect2(Vector2(-72.0, -18.0), Vector2(144.0, 36.0))
	var combat_pulse := 0.0
	if ColorSystem.in_combat:
		combat_pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0085)
	var glow := ColorSystem.glow_color()
	if ColorSystem.in_combat:
		glow = glow.lerp(Color("ffae3b"), combat_pulse * 0.26)
	var glow_alpha := 0.12 if not ColorSystem.in_combat else lerpf(0.08, 0.18, combat_pulse)
	draw_rect(rect.grow(12.0), Color(glow.r, glow.g, glow.b, glow_alpha), true)
	var wall_fill := Color(0.02, 0.09, 0.05, 0.65)
	if ColorSystem.in_combat:
		wall_fill = wall_fill.lerp(Color("220307"), 0.58 + combat_pulse * 0.18)
	draw_rect(rect, wall_fill, true)
	var line_color := ColorSystem.terrain_outline()
	if ColorSystem.in_combat:
		line_color = line_color.lerp(Color("ff4e2d"), 0.45 + combat_pulse * 0.28)
		line_color.a = lerpf(0.26, 0.52, combat_pulse)
	else:
		line_color.a = 0.38
	var x := rect.position.x - 12.0
	while x < rect.end.x + 18.0:
		draw_line(Vector2(x, rect.position.y), Vector2(x + 36.0, rect.end.y), line_color, 0.5)
		x += 18.0
	var y := rect.position.y + 6.0
	while y < rect.end.y:
		var horizontal_alpha := 0.12 if not ColorSystem.in_combat else lerpf(0.08, 0.2, combat_pulse)
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(line_color.r, line_color.g, line_color.b, horizontal_alpha), 0.5)
		y += 12.0
	# Only the two long face edges — no end caps so adjacent walls merge cleanly
	var ow := 1.3 if not ColorSystem.in_combat else lerpf(1.0, 1.4, combat_pulse)
	var oc := ColorSystem.terrain_outline()
	if ColorSystem.in_combat:
		oc = oc.lerp(Color("ff6230"), 0.62 + combat_pulse * 0.22)
	draw_line(Vector2(-72.0, -18.0), Vector2(72.0, -18.0), oc, ow)
	draw_line(Vector2(-72.0,  18.0), Vector2(72.0,  18.0), oc, ow)
