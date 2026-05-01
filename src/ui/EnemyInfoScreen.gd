extends Node2D

const ENEMIES := [
	{"name": "SWEEPER", "role": "Patrol scanner", "detail": "Pulse-cone patrol. Builds warning, then alerts."},
	{"name": "PULSAR", "role": "Ring detector", "detail": "Expanding pulse rings. Direct exposed hits alert immediately."},
	{"name": "PRISM", "role": "Beam scanner", "detail": "Rotating beam tripwire. Beam contact alerts immediately."},
	{"name": "SENTRY", "role": "Turret watcher", "detail": "Pressure detector. Warns on exposed fast movement, fires in combat."},
	{"name": "HUNTER", "role": "Proximity predator", "detail": "Owns a danger circle. Entering it triggers alert."},
	{"name": "WISP", "role": "Orbit hunter", "detail": "Light roaming pressure enemy. Dangerous once combat starts."},
	{"name": "WARPMINE", "role": "Trap mine", "detail": "Arms when you enter its trigger space, then deploys payload."},
]

var _elapsed: float = 0.0


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_I or event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			GameState.start_menu()
			return
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_B or event.button_index == JOY_BUTTON_Y or event.button_index == JOY_BUTTON_START:
			GameState.start_menu()


func _draw() -> void:
	var vp := get_viewport_rect().size
	var font := ThemeDB.fallback_font

	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.025, 0.01, 1.0), true)

	var grid := Color(0.1, 0.24, 0.14, 0.22)
	var sp := 28.0
	var gx := 0.0
	while gx <= vp.x:
		draw_line(Vector2(gx, 0.0), Vector2(gx, vp.y), grid, 0.5)
		gx += sp
	var gy := 0.0
	while gy <= vp.y:
		draw_line(Vector2(0.0, gy), Vector2(vp.x, gy), grid, 0.5)
		gy += sp

	var cx := vp.x * 0.5
	draw_string(font, Vector2(cx - 128.0, 90.0), "ENEMY INDEX", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.48, 1.0, 0.62, 0.95))
	draw_string(font, Vector2(cx - 170.0, 118.0), "FIELD REFERENCE  //  STEALTH THREATS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.22, 0.65, 0.33, 0.52))
	draw_line(Vector2(cx - 180.0, 136.0), Vector2(cx + 180.0, 136.0), Color(0.22, 0.6, 0.32, 0.22), 0.5)

	var start_y := 180.0
	var card_h := 60.0
	var card_gap := 12.0
	var card_w := minf(vp.x - 120.0, 860.0)
	var left := cx - card_w * 0.5

	for i in range(ENEMIES.size()):
		var item: Dictionary = ENEMIES[i]
		var y := start_y + float(i) * (card_h + card_gap)
		var card := Rect2(Vector2(left, y), Vector2(card_w, card_h))
		var selected_glow := 0.06 + 0.02 * sin(_elapsed * 1.8 + float(i))
		draw_rect(card, Color(0.02, 0.07, 0.04, 0.74), true)
		draw_rect(card.grow(1.0), Color(0.22, 0.58, 0.34, 0.16 + selected_glow), false, 0.5)

		var icon_center := Vector2(left + 34.0, y + card_h * 0.5)
		_draw_enemy_icon(i, icon_center)

		draw_string(font, Vector2(left + 64.0, y + 22.0), item["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.62, 1.0, 0.74, 0.95))
		draw_string(font, Vector2(left + 210.0, y + 22.0), item["role"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.38, 0.82, 0.52, 0.72))
		draw_string(font, Vector2(left + 64.0, y + 43.0), item["detail"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.54, 0.82, 0.62, 0.68))

	draw_string(font, Vector2(cx - 170.0, vp.y - 28.0), "ESC / I / B  TO RETURN", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.30, 0.72, 0.40, 0.62))


func _draw_enemy_icon(index: int, center: Vector2) -> void:
	var c := Color(0.55, 1.0, 0.65, 0.9)
	match index:
		0:
			draw_arc(center, 18.0, -0.6, 0.6, 18, c, 1.0)
			draw_arc(center, 12.0, -0.6, 0.6, 18, Color(c.r, c.g, c.b, 0.35), 0.5)
		1:
			draw_circle(center, 6.0, Color(c.r, c.g, c.b, 0.18))
			draw_arc(center, 16.0, 0.0, TAU, 28, c, 1.0)
		2:
			draw_line(center + Vector2(-16.0, 0.0), center + Vector2(16.0, 0.0), c, 0.9)
			draw_line(center + Vector2(0.0, -16.0), center + Vector2(0.0, 16.0), c, 0.9)
		3:
			draw_arc(center, 12.0, 0.0, TAU, 24, c, 1.0)
			draw_line(center + Vector2(-7.0, 0.0), center + Vector2(7.0, 0.0), c, 0.6)
			draw_line(center + Vector2(0.0, -7.0), center + Vector2(0.0, 7.0), c, 0.6)
		4:
			draw_polyline(PackedVector2Array([
				center + Vector2(0.0, -10.0),
				center + Vector2(6.0, 0.0),
				center + Vector2(0.0, 10.0),
				center + Vector2(-6.0, 0.0),
				center + Vector2(0.0, -10.0),
			]), c, 0.8)
		5:
			draw_polyline(PackedVector2Array([
				center + Vector2(0.0, -8.0),
				center + Vector2(6.0, 0.0),
				center + Vector2(0.0, 8.0),
				center + Vector2(-6.0, 0.0),
				center + Vector2(0.0, -8.0),
			]), c, 0.6)
			draw_line(center, center + Vector2(0.0, -16.0).rotated(_elapsed * 2.0), Color(c.r, c.g, c.b, 0.55), 0.6)
		6:
			draw_polyline(PackedVector2Array([
				center + Vector2(0.0, -11.0),
				center + Vector2(10.0, 0.0),
				center + Vector2(0.0, 11.0),
				center + Vector2(-10.0, 0.0),
				center + Vector2(0.0, -11.0),
			]), c, 0.7)
			draw_arc(center, 17.0, 0.0, TAU, 24, Color(c.r, c.g, c.b, 0.35), 0.5)
