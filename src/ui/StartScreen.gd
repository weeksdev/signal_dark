extends Node2D

var _elapsed: float = 0.0
var _ready_to_start: bool = false


func _ready() -> void:
	AlertSystem.reset()
	ColorSystem.reset()
	var t := get_tree().create_timer(0.6)
	t.timeout.connect(func(): _ready_to_start = true)


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not _ready_to_start:
		return
	var pressed := false
	if event is InputEventKey and event.pressed and not event.echo:
		pressed = true
	elif event is InputEventJoypadButton and event.pressed:
		pressed = true
	if pressed:
		get_tree().change_scene_to_file("res://src/world/World.tscn")


func _draw() -> void:
	var vp  := get_viewport_rect().size
	var t   := _elapsed
	var font := ThemeDB.fallback_font

	# Background
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.025, 0.01, 1.0))

	# Grid
	var gc := Color(0.1, 0.24, 0.14, 0.3)
	var sp := 28.0
	var gx := 0.0
	while gx <= vp.x:
		draw_line(Vector2(gx, 0.0), Vector2(gx, vp.y), gc, 1.0)
		gx += sp
	var gy := 0.0
	while gy <= vp.y:
		draw_line(Vector2(0.0, gy), Vector2(vp.x, gy), gc, 1.0)
		gy += sp

	# Animated scan line
	var scan_y := fmod(t * 180.0, vp.y + 60.0) - 30.0
	draw_line(Vector2(0.0, scan_y), Vector2(vp.x, scan_y),
			Color(0.3, 0.9, 0.45, 0.06), 2.0)

	# Title glow (layered for phosphor bloom)
	var cx  := vp.x * 0.5
	var ty  := vp.y * 0.36
	var title := "SIGNAL DARK"
	for i in 3:
		var spread := (3 - i) * 3.0
		draw_string(font,
				Vector2(cx - 104.0 + spread * 0.3, ty + spread * 0.3),
				title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40,
				Color(0.15, 0.7, 0.3, 0.12 - i * 0.03))
	draw_string(font, Vector2(cx - 104.0, ty), title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 40,
			Color(0.42, 1.0, 0.56, 0.95))

	# Tagline
	draw_string(font, Vector2(cx - 68.0, ty + 30.0),
			"STEALTH PROTOCOL  //  ZONE 01",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(0.22, 0.65, 0.33, 0.5))

	# Divider
	draw_line(Vector2(cx - 120.0, ty + 50.0), Vector2(cx + 120.0, ty + 50.0),
			Color(0.22, 0.6, 0.32, 0.28), 1.0)

	# Blinking prompt
	if fmod(t, 1.3) < 0.82:
		draw_string(font, Vector2(cx - 96.0, vp.y * 0.58),
				"PRESS ANY KEY TO START",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
				Color(0.38, 1.0, 0.52, 0.9))

	# Controls block
	var hy    := vp.y * 0.73
	var hc    := Color(0.18, 0.52, 0.27, 0.48)
	var hints := [
		"MOVE          WASD  /  LEFT STICK",
		"DARK MODE     SHIFT  /  L2          (reduces emission)",
		"FIRE          SPACE  /  R1",
		"BOOST         E  /  R2",
		"PROBE         Q  /  X               (decoy beacon)",
		"SUPPRESS      F  /  A               (silent kill from behind)",
	]
	for i in hints.size():
		draw_string(font, Vector2(cx - 130.0, hy + i * 15.0),
				hints[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, hc)

	# Version / build tag
	draw_string(font, Vector2(16.0, vp.y - 16.0),
			"SIGNAL DARK  //  PROTOTYPE",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color(0.15, 0.42, 0.22, 0.35))
