# Platform: iOS + macOS

Signal Dark ships on both platforms. macOS is the dev/test environment. iOS is the primary target. The design priority order is:

```
iOS touch → iOS controller → macOS controller → macOS keyboard+mouse
```

Everything in this document serves that order.

---

## The Input Hierarchy

Three input modes must work without manual switching. `InputManager.gd` detects the active mode each frame and returns the right values. The rest of the game never asks "what platform am I on."

```
Priority 1: Controller (MFi/Xbox/PlayStation — detected via joypad connection)
Priority 2: Touch (iOS — detected via touch events)
Priority 3: Keyboard + Mouse (macOS fallback)
```

---

## Phase 1 — Touch Input System

### Design principles

The controls must feel like they belong on iOS, not like a ported PC game. Two rules:

1. **Floating joysticks** — sticks appear where the thumb lands, not at a fixed corner. This is the modern standard (Dead Cells, Pascal's Wager). Fixed-position sticks cause constant thumb drift.
2. **Aim fires** — on the right side, dragging the aim stick past a threshold fires automatically. No separate "fire" button to juggle while aiming. Tap the right zone = burst fire in current aim direction.

### Touch zone layout (landscape)

```
┌──────────────────────────────────────────────────────────┐
│                                                          │
│                                                          │
│  ┌─ LEFT ZONE ────────┐     ┌─ RIGHT ZONE ─────────┐    │
│  │                    │     │                       │    │
│  │  [move joystick]   │     │  [aim joystick]       │    │
│  │                    │     │  auto-fires when      │    │
│  │  [DARK  ] [PROBE]  │     │  stick > 0.4 length   │    │
│  │  (hold)  (tap)     │     │                       │    │
│  └────────────────────┘     │  [BOOST]  [SUPPRESS]  │    │
│                              └───────────────────────┘    │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

- Left zone: left half of screen minus safe area insets
- Right zone: right half of screen minus safe area insets
- Action buttons anchor to bottom of their zone, 20px from safe area edge
- Joysticks float — base appears at initial touch point, capped 80px from base

### TouchInputLayer — new autoload node

Create **`src/autoloads/TouchInputLayer.gd`**. `InputManager` calls into this when no joypad is connected.

```gdscript
extends Node

# --- joystick state ---
var move_base: Vector2 = Vector2.ZERO
var move_touch_id: int = -1
var move_vector: Vector2 = Vector2.ZERO

var aim_base: Vector2 = Vector2.ZERO
var aim_touch_id: int = -1
var aim_vector: Vector2 = Vector2.ZERO
var aim_firing: bool = false

# --- button state ---
var dark_mode_held: bool = false
var boost_tapped: bool = false
var probe_tapped: bool = false
var suppress_tapped: bool = false

# --- consumed taps (cleared each frame) ---
var _boost_consumed: bool = false
var _probe_consumed: bool = false
var _suppress_consumed: bool = false

const STICK_MAX_RADIUS   := 80.0
const AIM_FIRE_THRESHOLD := 0.40   # aim stick length to trigger auto-fire
const SCREEN_SPLIT       := 0.50   # left/right zone boundary (fraction of width)

var _viewport_size: Vector2 = Vector2.ZERO


func _ready() -> void:
    set_process_input(true)


func _process(_delta: float) -> void:
    _boost_consumed = false
    _probe_consumed = false
    _suppress_consumed = false
    aim_firing = aim_vector.length() >= AIM_FIRE_THRESHOLD


func _input(event: InputEvent) -> void:
    if not _is_touch_active():
        return
    _viewport_size = get_viewport().get_visible_rect().size
    var split_x := _viewport_size.x * SCREEN_SPLIT

    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed:
            _handle_touch_down(touch.index, touch.position, split_x)
        else:
            _handle_touch_up(touch.index)

    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        _handle_drag(drag.index, drag.position)


func _handle_touch_down(id: int, pos: Vector2, split_x: float) -> void:
    if pos.x < split_x:
        # left zone — check buttons first, then joystick
        if _in_button_zone(pos, "dark_mode"):
            dark_mode_held = true
        elif _in_button_zone(pos, "probe"):
            _probe_consumed = true
        elif move_touch_id == -1:
            move_touch_id = id
            move_base = pos
            move_vector = Vector2.ZERO
    else:
        # right zone — check buttons first, then aim joystick
        if _in_button_zone(pos, "boost"):
            _boost_consumed = true
        elif _in_button_zone(pos, "suppress"):
            _suppress_consumed = true
        elif aim_touch_id == -1:
            aim_touch_id = id
            aim_base = pos
            aim_vector = Vector2.ZERO


func _handle_touch_up(id: int) -> void:
    if id == move_touch_id:
        move_touch_id = -1
        move_vector = Vector2.ZERO
        dark_mode_held = false   # dark mode held only while move finger down
    if id == aim_touch_id:
        aim_touch_id = -1
        aim_vector = Vector2.ZERO


func _handle_drag(id: int, pos: Vector2) -> void:
    if id == move_touch_id:
        var offset := pos - move_base
        if offset.length() > STICK_MAX_RADIUS:
            # float the base so thumb never feels capped
            move_base += offset.normalized() * (offset.length() - STICK_MAX_RADIUS)
            offset = offset.normalized() * STICK_MAX_RADIUS
        move_vector = offset / STICK_MAX_RADIUS

    elif id == aim_touch_id:
        var offset := pos - aim_base
        if offset.length() > STICK_MAX_RADIUS:
            aim_base += offset.normalized() * (offset.length() - STICK_MAX_RADIUS)
            offset = offset.normalized() * STICK_MAX_RADIUS
        aim_vector = offset / STICK_MAX_RADIUS


# --- query API (called by InputManager) ---

func get_move_vector() -> Vector2:
    return move_vector

func get_aim_vector() -> Vector2:
    return aim_vector

func is_dark_mode() -> bool:
    return dark_mode_held

func is_fire() -> bool:
    return aim_firing

func consume_boost() -> bool:
    var v := _boost_consumed
    _boost_consumed = false
    return v

func consume_probe() -> bool:
    var v := _probe_consumed
    _probe_consumed = false
    return v

func consume_suppress() -> bool:
    var v := _suppress_consumed
    _suppress_consumed = false
    return v


# --- helpers ---

func _is_touch_active() -> bool:
    return OS.has_feature("mobile") or OS.has_feature("web")


func _in_button_zone(pos: Vector2, action: String) -> bool:
    # Buttons are anchored by TouchHUD — this returns false here; TouchHUD
    # intercepts those rects directly. Stub kept for override if needed.
    return false
```

---

### TouchHUD — on-screen controls overlay

Create **`src/ui/TouchHUD.gd`** — draws the virtual sticks and action buttons. Only visible on iOS.

```gdscript
extends CanvasLayer

@onready var touch := TouchInputLayer

const STICK_BASE_RADIUS := 32.0
const STICK_KNOB_RADIUS := 18.0
const BTN_RADIUS        := 28.0
const SAFE_MARGIN       := 24.0   # respect iPhone safe area

var _safe_insets: Vector4 = Vector4.ZERO   # left, top, right, bottom


func _ready() -> void:
    if not (OS.has_feature("mobile") or OS.has_feature("web")):
        queue_free()
        return
    # Godot 4.3+ exposes safe area
    if DisplayServer.has_method("get_display_safe_area"):
        var r: Rect2i = DisplayServer.get_display_safe_area()
        var vp := get_viewport().get_visible_rect()
        _safe_insets = Vector4(r.position.x, r.position.y,
                               vp.size.x - r.end.x, vp.size.y - r.end.y)
    set_process(true)


func _process(_delta: float) -> void:
    queue_redraw()


func _draw() -> void:
    var vp := get_viewport().get_visible_rect().size
    var ui := ColorSystem.ui_color()

    # left zone floating stick
    if touch.move_touch_id != -1:
        _draw_stick(touch.move_base, touch.move_vector * touch.STICK_MAX_RADIUS, ui)

    # right zone floating stick
    if touch.aim_touch_id != -1:
        _draw_stick(touch.aim_base, touch.aim_vector * touch.STICK_MAX_RADIUS, ui)

    # action buttons — bottom of each zone
    var left_bottom  := Vector2(vp.x * 0.25, vp.y - SAFE_MARGIN - _safe_insets.w - BTN_RADIUS)
    var right_bottom := Vector2(vp.x * 0.75, vp.y - SAFE_MARGIN - _safe_insets.w - BTN_RADIUS)

    _draw_button(left_bottom + Vector2(-54.0, 0.0), "DARK", touch.dark_mode_held, Color("00bfff"), ui)
    _draw_button(left_bottom + Vector2(54.0, 0.0),  "PRB",  false,                Color("4fbf68"), ui)
    _draw_button(right_bottom + Vector2(-54.0, 0.0), "BST",  false,               Color("ff9f0a"), ui)
    _draw_button(right_bottom + Vector2(54.0, 0.0),  "SUP",  false,               Color("ff3b30"), ui)


func _draw_stick(base: Vector2, knob_offset: Vector2, color: Color) -> void:
    draw_arc(base, STICK_BASE_RADIUS, 0.0, TAU, 32, Color(color, 0.18), 1.5)
    draw_circle(base, STICK_BASE_RADIUS, Color(color, 0.06))
    var knob_pos := base + knob_offset.limit_length(touch.STICK_MAX_RADIUS)
    draw_circle(knob_pos, STICK_KNOB_RADIUS, Color(color, 0.22))
    draw_arc(knob_pos, STICK_KNOB_RADIUS, 0.0, TAU, 24, Color(color, 0.55), 1.5)


func _draw_button(center: Vector2, label: String, active: bool, tint: Color, ui: Color) -> void:
    var alpha := 0.55 if active else 0.28
    draw_circle(center, BTN_RADIUS, Color(tint, alpha * 0.4))
    draw_arc(center, BTN_RADIUS, 0.0, TAU, 32, Color(tint, alpha), 1.5)
    var font := ThemeDB.fallback_font
    draw_string(font, center + Vector2(-10.0, 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
                Color(ui, 0.7 if active else 0.45))
```

---

### InputManager.gd — wire in touch layer

Extend the existing `InputManager` to route through `TouchInputLayer` when no joypad is active:

```gdscript
# Add to top of InputManager.gd
@onready var touch: Node = null

func _ready() -> void:
    # TouchInputLayer is only added to autoloads on mobile builds
    if Engine.has_singleton("TouchInputLayer"):
        touch = Engine.get_singleton("TouchInputLayer")
    elif has_node("/root/TouchInputLayer"):
        touch = get_node("/root/TouchInputLayer")


func _use_touch() -> bool:
    return touch != null and _first_joypad() == -1


func get_move_vector() -> Vector2:
    if _use_touch():
        return touch.get_move_vector()
    var keyboard_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
    var joy_vector := _get_left_stick()
    return joy_vector if joy_vector.length() > DEADZONE else keyboard_vector


func get_aim_vector(fallback: Vector2) -> Vector2:
    if _use_touch():
        var v := touch.get_aim_vector()
        return v.normalized() if v.length() > 0.1 else fallback
    var joy_aim := _get_right_stick()
    if joy_aim.length() > AIM_DEADZONE:
        return joy_aim.normalized()
    return fallback


func is_dark_mode() -> bool:
    if _use_touch():
        return touch.is_dark_mode()
    return Input.is_action_pressed("dark_mode") or _left_trigger_pressed()


func is_boost_pressed() -> bool:
    if _use_touch():
        return touch.consume_boost()
    return Input.is_action_pressed("boost") or _right_trigger_pressed()


func is_fire_pressed() -> bool:
    if _use_touch():
        return touch.is_fire()
    return Input.is_action_pressed("fire") or _joy_button_pressed(JOY_BUTTON_RIGHT_SHOULDER)


func is_suppress_pressed() -> bool:
    if _use_touch():
        return touch.consume_suppress()
    return Input.is_action_pressed("suppress") or _joy_button_pressed(JOY_BUTTON_A)


func is_probe_pressed() -> bool:
    if _use_touch():
        return touch.consume_probe()
    return Input.is_action_pressed("probe") or _joy_button_pressed(JOY_BUTTON_X)
```

---

## Phase 2 — iOS Export Configuration

### project.godot changes

```ini
[display]
window/size/viewport_width=1334
window/size/viewport_height=750
window/size/resizable=false
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[rendering]
renderer/rendering_method="mobile"
textures/canvas_textures/default_texture_filter=0

[input_devices]
pointing/emulate_touch_from_mouse=false
```

### Export preset (set in Godot Editor → Project → Export)

| Setting | Value | Why |
|---|---|---|
| Architectures | arm64 only | Drops 32-bit, smaller binary |
| Bundle identifier | `com.yourname.signaldark` | Required for App Store |
| Version | 1.0 | Start here |
| Targeted device family | iPhone + iPad | Don't limit yourself |
| Minimum iOS version | 16.0 | Covers ~95%+ devices, gives Metal feature set 3 |
| Orientation | Landscape left + Landscape right | Lock to landscape |
| High-res (Retina) | On | Required for 3x displays |
| Icons | All sizes required | Use asset catalog |

### `run.sh` — add iOS simulator target

```bash
#!/bin/bash
# existing mac run preserved
if [ "$1" == "ios-sim" ]; then
    godot --export-debug "iOS" /tmp/signal_dark.xcodeproj
    xcodebuild -project /tmp/signal_dark.xcodeproj \
               -scheme signal_dark \
               -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
               clean build
    xcrun simctl install booted /tmp/signal_dark.app
    xcrun simctl launch booted com.yourname.signaldark
else
    godot --path . --debug
fi
```

---

## Phase 3 — Screen + Safe Area Adaptation

iPhones have notches, Dynamic Islands, and home indicators. The HUD must respect these. 

### HUD.gd — safe area insets

```gdscript
var _safe: Rect2 = Rect2(0, 0, 0, 0)

func _ready() -> void:
    # ... existing connections ...
    _update_safe_area()
    get_tree().root.size_changed.connect(_update_safe_area)


func _update_safe_area() -> void:
    if DisplayServer.has_method("get_display_safe_area"):
        _safe = Rect2(DisplayServer.get_display_safe_area())
    else:
        _safe = Rect2(Vector2.ZERO, get_viewport_rect().size)


func _draw() -> void:
    var inset_x := _safe.position.x + 16.0   # push right of notch/island
    var inset_y := _safe.position.y + 16.0

    # Replace hardcoded Vector2(16, 16) panel origin with:
    var panel := Rect2(Vector2(inset_x, inset_y), Vector2(panel_width, 78.0))
    # ... rest of draw unchanged ...
```

### Adaptive font sizing

The HUD was designed at a fixed font size of 11px. On 3x Retina, that's readable but tight. Scale by display density:

```gdscript
func _get_font_size() -> int:
    var scale := DisplayServer.screen_get_scale()
    if scale >= 3.0:
        return 14
    elif scale >= 2.0:
        return 12
    return 11
```

---

## Phase 4 — Performance Budget for iOS

Signal Dark draws everything via `_draw()` calls — no sprites, pure Canvas rendering. This is GPU-friendly on Metal but needs discipline on older devices.

### Target devices and frame budget

| Device | Chip | Target FPS | Notes |
|---|---|---|---|
| iPhone 16 Pro | A18 Pro | 120fps | ProMotion, no budget concerns |
| iPhone 15 | A16 | 60fps | Primary test target |
| iPhone 13 | A15 | 60fps | Minimum supported |
| iPad Air M2 | M2 | 120fps | |

### Grid.gd — reduce draw calls on mobile

The grid is the most expensive draw pass. Gate the warp attractor count:

```gdscript
func _get_max_attractors() -> int:
    if OS.has_feature("mobile"):
        return 2   # player + nearest enemy only
    return 5       # player + 4 enemies (current)


func _build_attractor_list() -> Array:
    var attractors := []
    # always add player first
    # ... existing player attractor ...
    var enemies := get_tree().get_nodes_in_group("zone_enemy")
    var max_count := _get_max_attractors() - 1
    # sort by distance to player, take closest N
    enemies.sort_custom(func(a, b):
        return a.global_position.distance_to(_player_pos) < b.global_position.distance_to(_player_pos)
    )
    for i in min(max_count, enemies.size()):
        # ... add enemy attractor ...
        pass
    return attractors
```

### Particle counts

```gdscript
# In ExplosionBurst.gd — scale particle count by platform
func _get_particle_count() -> int:
    return 12 if OS.has_feature("mobile") else 24
```

### Lock to 60fps on non-ProMotion iOS

In `project.godot`:
```ini
[application]
run/max_fps=60
```

Then unlock to 120 for ProMotion at runtime:

```gdscript
# In World.gd _ready():
if OS.has_feature("mobile"):
    var refresh := DisplayServer.screen_get_refresh_rate()
    Engine.max_fps = 120 if refresh >= 119.0 else 60
```

---

## Phase 5 — Controller on iOS (MFi + Xbox/PlayStation)

The existing `InputManager.gd` already handles controllers correctly. Two things to add:

### Auto-detect controller and hide touch HUD

```gdscript
# In TouchHUD.gd
func _ready() -> void:
    # ... existing setup ...
    Input.joy_connection_changed.connect(_on_joy_changed)


func _on_joy_changed(device: int, connected: bool) -> void:
    # Hide touch overlay when controller connected; show when disconnected
    visible = not connected or Input.get_connected_joypads().is_empty()
```

### Controller button labels adapt to brand

On iOS, connected controllers can be Xbox (A/B/X/Y) or PlayStation (Cross/Circle/Square/Triangle). The suppress label currently shows text — on controller it should show the right glyph.

```gdscript
# In Ship.gd _update_suppress_prompt():
func _update_suppress_prompt() -> void:
    var can_suppress := false
    for enemy in get_tree().get_nodes_in_group("zone_enemy"):
        if enemy.can_be_suppressed_by(self):
            can_suppress = true
            break
    suppress_label.visible = can_suppress
    if can_suppress:
        suppress_label.text = _get_suppress_label_text()


func _get_suppress_label_text() -> String:
    if Input.get_connected_joypads().is_empty():
        return ""   # TouchHUD shows button
    # Godot 4.2+ can query controller name
    var name := Input.get_joy_name(0).to_lower()
    if "playstation" in name or "dualsense" in name or "dualshock" in name:
        return "[cross]"
    return "[A]"   # Xbox / generic
```

---

## Implementation order

```
Week 1 — Touch foundation
  [ ] Create TouchInputLayer.gd autoload
  [ ] Create TouchHUD.gd CanvasLayer
  [ ] Wire InputManager to route through touch layer
  [ ] Test: floating joysticks move ship, aim stick fires
  [ ] Test: dark mode hold, probe tap, boost tap, suppress tap

Week 2 — iOS export + safe area
  [ ] Set project.godot display/stretch settings
  [ ] Configure iOS export preset in editor
  [ ] Add safe area inset logic to HUD.gd
  [ ] Test on iPhone 15 simulator in landscape

Week 3 — Performance pass
  [ ] Gate grid attractor count on mobile
  [ ] Scale particle counts
  [ ] Cap FPS, unlock for ProMotion
  [ ] Profile on A15 device (Instruments → GPU)

Week 4 — Controller polish
  [ ] Auto-hide TouchHUD on controller connect
  [ ] Adaptive suppress label glyph
  [ ] Full playthrough with MFi controller on device
```

---

## Test matrix

| Scenario | macOS | iOS simulator | iOS device |
|---|---|---|---|
| Keyboard + mouse | ✓ | — | — |
| MFi controller connected | ✓ | ✓ | ✓ |
| Touch only (no controller) | — | ✓ | ✓ |
| Touch + controller connected | — | ✓ | ✓ |
| Notch/Dynamic Island safe area | — | ✓ (iPhone 16 sim) | ✓ |
| 120fps ProMotion | — | — | ✓ (iPhone 16 Pro) |
| Portrait rotation (should lock landscape) | — | ✓ | ✓ |
