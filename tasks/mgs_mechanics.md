# MGS Mechanics Implementation Plan

Signal Dark has the visual identity and emission system. What it's missing is the **cognitive tension loop** that makes Metal Gear Solid elite: the moment where you've been spotted, you've slipped away, and now enemies are hunting the ghost of where you were. This document is the phased plan to build that loop.

---

## Phase 1 — Three-State Alert Machine + Last Known Position

**The single highest-leverage change.** Everything else in MGS is built on top of this.

### Current state

Binary: `stealth ↔ combat`. Detection instantly recruits every enemy in the zone to chase the player's real position. There is no recovery without killing everyone.

### Target state

```
STEALTH → ALERT → SEARCH → STEALTH
```

| State | Enemy behavior | Exits when |
|---|---|---|
| `STEALTH` | Patrol routes | Any enemy detects player |
| `ALERT` | All nearby enemies pursue player's **real** position | Player breaks LOS for `ALERT_TO_SEARCH_SECONDS` |
| `SEARCH` | Enemies converge on **last known position**, then sweep | Search timer expires with no re-detection |
| `STEALTH` | Return to patrol | Search expires clean |

The genius is the **SEARCH state**: enemies know where you *were*, not where you *are*. You hide 30 units away and watch them investigate empty space.

---

### 1a. AlertSystem — add three states

**`src/autoload/AlertSystem.gd`** — extend the existing singleton:

```gdscript
enum AlertPhase { STEALTH, ALERT, SEARCH }

var phase: AlertPhase = AlertPhase.STEALTH
var last_known_position: Vector2 = Vector2.ZERO
var alert_timer: float = 0.0
var search_timer: float = 0.0

const ALERT_TO_SEARCH_SECONDS := 2.5   # LOS lost → start search
const SEARCH_DURATION_SECONDS  := 8.0  # search before returning to patrol

signal phase_changed(new_phase: AlertPhase)

func enter_alert(lkp: Vector2) -> void:
    if phase == AlertPhase.ALERT:
        last_known_position = lkp   # refresh LKP on re-detection
        alert_timer = ALERT_TO_SEARCH_SECONDS
        return
    phase = AlertPhase.ALERT
    last_known_position = lkp
    alert_timer = ALERT_TO_SEARCH_SECONDS
    combat_mode = true
    phase_changed.emit(phase)

func tick_alert(delta: float, player_visible: bool, player_position: Vector2) -> void:
    match phase:
        AlertPhase.ALERT:
            if player_visible:
                last_known_position = player_position
                alert_timer = ALERT_TO_SEARCH_SECONDS
            else:
                alert_timer -= delta
                if alert_timer <= 0.0:
                    _enter_search()
        AlertPhase.SEARCH:
            search_timer -= delta
            if search_timer <= 0.0:
                _return_to_stealth()

func _enter_search() -> void:
    phase = AlertPhase.SEARCH
    search_timer = SEARCH_DURATION_SECONDS
    phase_changed.emit(phase)

func _return_to_stealth() -> void:
    phase = AlertPhase.STEALTH
    combat_mode = false
    phase_changed.emit(phase)
```

---

### 1b. World.gd — drive the tick and expose LKP

Replace the current `_update_combat_cooldown` with phase-aware ticking:

```gdscript
func _process(delta: float) -> void:
    # ... existing probe/restart logic ...
    if AlertSystem.phase != AlertSystem.AlertPhase.STEALTH and not restarting:
        var player_visible := _any_enemy_sees_player()
        AlertSystem.tick_alert(delta, player_visible, ship.global_position)
        _sync_enemies_to_phase()


func _any_enemy_sees_player() -> bool:
    for enemy in enemies:
        if is_instance_valid(enemy) and enemy.is_alive and enemy.has_player_in_sight():
            return true
    return false


func _sync_enemies_to_phase() -> void:
    var phase := AlertSystem.phase
    for enemy in enemies:
        if not is_instance_valid(enemy) or not enemy.is_alive:
            continue
        match phase:
            AlertSystem.AlertPhase.ALERT:
                enemy.activate_for_combat(ship)   # chase real position
            AlertSystem.AlertPhase.SEARCH:
                enemy.enter_search(AlertSystem.last_known_position)
            AlertSystem.AlertPhase.STEALTH:
                enemy.deactivate_to_stealth()


func _on_enemy_detected(enemy: Node) -> void:
    AlertSystem.enter_alert(ship.global_position)
    # local propagation handled in Phase 2
```

---

### 1c. Enemy base — add SEARCH state behavior

Each enemy needs `enter_search()` and `has_player_in_sight()`. Add to **Sweeper.gd** first, then mirror to other enemy types:

```gdscript
enum EnemyState { PATROL, COMBAT, SEARCH }
var state: EnemyState = EnemyState.PATROL
var search_target: Vector2 = Vector2.ZERO
var search_wander_timer: float = 0.0

const SEARCH_ARRIVE_THRESHOLD := 24.0
const SEARCH_WANDER_INTERVAL  := 2.2   # seconds before picking next wander point


func enter_search(lkp: Vector2) -> void:
    state = EnemyState.SEARCH
    search_target = lkp
    search_wander_timer = 0.0
    combat_active = false
    velocity = Vector2.ZERO


func has_player_in_sight() -> bool:
    var player := get_tree().get_first_node_in_group("player_ship")
    if player == null:
        return false
    var to_player: Vector2 = player.global_position - global_position
    if to_player.length() > detection_range:
        return false
    if facing_vector.dot(to_player.normalized()) < cos(deg_to_rad(cone_angle_degrees * 0.5)):
        return false
    if get_tree().current_scene.is_line_blocked(global_position, player.global_position, [get_rid()]):
        return false
    return player.get_effective_emission() > 0.015


func _physics_process(delta: float) -> void:
    if not is_alive:
        return
    match state:
        EnemyState.PATROL:  _run_patrol()
        EnemyState.COMBAT:  _run_combat()
        EnemyState.SEARCH:  _run_search(delta)
    queue_redraw()


func _run_search(delta: float) -> void:
    search_wander_timer -= delta
    var offset := search_target - global_position
    if offset.length() < SEARCH_ARRIVE_THRESHOLD or search_wander_timer <= 0.0:
        # pick a random point near the LKP to simulate sweeping behavior
        search_target = AlertSystem.last_known_position + Vector2(
            randf_range(-80.0, 80.0),
            randf_range(-80.0, 80.0)
        )
        search_wander_timer = SEARCH_WANDER_INTERVAL
    facing_vector = (search_target - global_position).normalized()
    velocity = facing_vector * (patrol_speed * 0.85)
    move_and_slide()
```

---

### 1d. HUD — show phase state and search countdown

The exclamation mark moment needs clear UI feedback. Extend **HUD.gd**:

```gdscript
func _update_mode_label() -> void:
    var phase := AlertSystem.phase
    match phase:
        AlertSystem.AlertPhase.STEALTH:
            mode_label.text = "MODE: STEALTH"
            mode_label.modulate = ColorSystem.ui_primary()
        AlertSystem.AlertPhase.ALERT:
            mode_label.text = "! ALERT"
            mode_label.modulate = Color("ff3b30")
        AlertSystem.AlertPhase.SEARCH:
            var t := AlertSystem.search_timer
            mode_label.text = "? SEARCH  %.1fs" % t
            mode_label.modulate = Color("ff9f0a")
```

The `?` and countdown are the MGS exclamation mark equivalent — the player watches the timer and knows exactly when they're safe.

---

## Phase 2 — Local Alert Propagation

**Current behavior:** any detection instantly activates every enemy in the zone.

**Target:** detection spreads outward from the detecting enemy via a simulated radio call. Enemies outside radio range stay on patrol until the chain reaches them or they detect the player directly. This preserves the "slip past the distracted guard" moment.

### 2a. World.gd — ripple alert from source enemy

```gdscript
const RADIO_CALL_RANGE    := 320.0   # how far a detection shout travels
const RADIO_CALL_DELAY    := 0.6     # seconds before alerted enemy calls its neighbors

var _propagation_queue: Array[Dictionary] = []  # [{enemy, position, delay_remaining}]


func _on_enemy_detected(source_enemy: Node) -> void:
    if AlertSystem.phase == AlertSystem.AlertPhase.ALERT:
        AlertSystem.enter_alert(ship.global_position)
        return
    AlertSystem.enter_alert(ship.global_position)
    # activate detecting enemy immediately
    source_enemy.activate_for_combat(ship)
    # queue neighbors for radio-call activation
    _queue_radio_propagation(source_enemy.global_position, [source_enemy])


func _queue_radio_propagation(origin: Vector2, already_alerted: Array) -> void:
    for enemy in enemies:
        if not is_instance_valid(enemy) or not enemy.is_alive:
            continue
        if already_alerted.has(enemy):
            continue
        var dist := enemy.global_position.distance_to(origin)
        if dist <= RADIO_CALL_RANGE:
            _propagation_queue.append({
                "enemy": enemy,
                "delay": RADIO_CALL_DELAY * (dist / RADIO_CALL_RANGE),  # farther = longer delay
                "origin": enemy.global_position   # for chained propagation
            })
            already_alerted.append(enemy)


func _process(delta: float) -> void:
    # ... existing logic ...
    _tick_propagation(delta)


func _tick_propagation(delta: float) -> void:
    if _propagation_queue.is_empty():
        return
    var still_pending: Array[Dictionary] = []
    for entry in _propagation_queue:
        entry["delay"] -= delta
        if entry["delay"] <= 0.0:
            var enemy: Node = entry["enemy"]
            if is_instance_valid(enemy) and enemy.is_alive:
                enemy.activate_for_combat(ship)
                # chain: this enemy now radios its own neighbors
                _queue_radio_propagation(entry["origin"], _currently_alerted_enemies())
        else:
            still_pending.append(entry)
    _propagation_queue = still_pending


func _currently_alerted_enemies() -> Array:
    var alerted: Array = []
    for enemy in enemies:
        if is_instance_valid(enemy) and enemy.is_alive and enemy.state != enemy.EnemyState.PATROL:
            alerted.append(enemy)
    return alerted
```

This creates the **wave propagation** feel: detection at point A visibly ripples outward over 0.6–1.2 seconds. A player who spots this happening can sprint through the far side of the zone before the wave reaches those guards.

---

### 2b. Visual feedback for propagation

Draw a brief radio-call ring on each enemy when they receive the alert. Add to enemy `_draw()`:

```gdscript
var _alert_ring_alpha: float = 0.0   # set to 0.8 when alerted, fades to 0


func activate_for_combat(target_ship: Node2D) -> void:
    ship = target_ship
    state = EnemyState.COMBAT
    combat_active = true
    _alert_ring_alpha = 0.8   # trigger ring flash


func _draw() -> void:
    # ... existing cone/body draw ...
    if _alert_ring_alpha > 0.0:
        var ring_color := Color("ff3b30", _alert_ring_alpha)
        draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 32, ring_color, 2.0)
        _alert_ring_alpha = maxf(0.0, _alert_ring_alpha - get_process_delta_time() * 2.4)
        queue_redraw()
```

---

## Phase 3 — Maze-First Level Design

Mechanics only create tension if the level geometry **forces decisions**. Open-field avoidance is boring. The maze must create moments where there is exactly one path forward and a guard on it.

### Design rules for Signal Dark zones

```
Rule 1: Every path has a chokepoint
  A chokepoint is a gap ≤ 80 units wide with at least one enemy patrol route
  crossing it. The player must time movement or suppress the guard.

Rule 2: The player can always see the solution
  Detection cones must be visible from the approach. No blind corners that
  instantly kill. The player should be able to stop, read the patrol timing,
  and plan before committing.

Rule 3: Three routes minimum per zone segment
  Stealth route: narrow, slow, requires dark mode, bypasses all guards
  Aggressive route: wider, faster, requires killing 2–3 enemies
  Hybrid route: one suppressed kill opens the stealth route

Rule 4: Dark Pockets are placed at chokepoints
  A dark pocket at a chokepoint lets skilled players inch through at emission
  0.015 even without dark mode. Place them just inside the sightline.

Rule 5: Patrol timing is readable within 8 seconds
  Any patrol route should complete a full cycle in 6–10 seconds. Players
  shouldn't need to watch for 30s to understand the pattern.
```

### Zone segment template (World.tscn pattern)

```
[Segment layout]
  
  Entry gap (80 units)
        │
   ┌────┴─────────────────────────────────┐
   │                                      │
   │  [Sweeper: A→B horizontal patrol]    │
   │         ↕ 120 unit gap               │
   │  [Lattice Wall — forces routing]     │
   │         ↕                            │
   │  [Dark Pocket — stealth route]       │
   │                                      │
   │  [Sentry — covers aggressive route]  │
   └────────────────────────────────────┬─┘
                                        │
                                   Exit gap (80 units)
```

### Lattice Wall sizing guide

| Purpose | Width | Height | Notes |
|---|---|---|---|
| Chokepoint wall | 400–600 | 28 | One guard patrols past the gap |
| Room divider | 200–320 | 28 | Creates two-path routing |
| Dead end pocket | 120 | 120 | Forces player to commit then retreat |
| Cover block | 48 | 48 | Lets player break LOS mid-corridor |

### Patrol waypoint placement rules

```gdscript
# Good: patrol crosses chokepoint gap — forces timing decision
patrol_a = Vector2(-80, 300)   # outside gap
patrol_b = Vector2(80, 300)    # other side of gap (Lattice Wall nearby)

# Bad: patrol parallel to wall — player just walks perpendicular, no tension
patrol_a = Vector2(0, 200)
patrol_b = Vector2(0, 400)
```

---

## Phase 4 — Alert Timer HUD Element

Small but critical for the MGS feel. The visible countdown during SEARCH is what makes the "hold still and wait" moment so tense. The player is watching a number count to zero, knowing if they twitch the timer resets.

```gdscript
# In HUD.gd — add a timer bar that only shows in ALERT and SEARCH phases

func _draw_alert_timer_bar() -> void:
    var phase := AlertSystem.phase
    if phase == AlertSystem.AlertPhase.STEALTH:
        return

    var bar_width  := 180.0
    var bar_height := 6.0
    var origin     := Vector2(20.0, 88.0)   # below the existing bars

    var fill_ratio: float
    var bar_color: Color

    match phase:
        AlertSystem.AlertPhase.ALERT:
            fill_ratio = AlertSystem.alert_timer / AlertSystem.ALERT_TO_SEARCH_SECONDS
            bar_color  = Color("ff3b30")
        AlertSystem.AlertPhase.SEARCH:
            fill_ratio = AlertSystem.search_timer / AlertSystem.SEARCH_DURATION_SECONDS
            bar_color  = Color("ff9f0a")

    # background track
    draw_rect(Rect2(origin, Vector2(bar_width, bar_height)), Color(1, 1, 1, 0.08))
    # fill
    draw_rect(Rect2(origin, Vector2(bar_width * fill_ratio, bar_height)), bar_color)
```

---

## Implementation order

```
Week 1 — Phase 1 (Alert Machine)
  [ ] Add AlertPhase enum and tick logic to AlertSystem.gd
  [ ] Replace _update_combat_cooldown in World.gd
  [ ] Add enter_search() and has_player_in_sight() to Sweeper.gd
  [ ] Wire HUD mode label to three states
  [ ] Test: get spotted → slip away → watch SEARCH state → stealth returns

Week 2 — Phase 1 polish + Phase 4 (Timer bar)
  [ ] Mirror SEARCH behavior to Pulsar, Hunter, Sentry, Wisp
  [ ] Add LKP wander sweep to all enemies
  [ ] Add alert timer bar to HUD
  [ ] Tune ALERT_TO_SEARCH_SECONDS and SEARCH_DURATION_SECONDS by feel

Week 3 — Phase 2 (Local propagation)
  [ ] Add _propagation_queue to World.gd
  [ ] Replace trigger_alert() bulk activation with ripple activation
  [ ] Add alert ring flash to enemy _draw()
  [ ] Test: detect at one end of zone, watch wave reach far enemies

Week 4 — Phase 3 (Maze redesign)
  [ ] Sketch 3-route zone layout on paper first
  [ ] Move Lattice Walls to create chokepoints
  [ ] Adjust Sweeper patrol waypoints to cross chokepoints
  [ ] Place Dark Pockets at chokepoints
  [ ] Playtest both ghost route and combat route to completion
```

---

## Success criteria

The implementation is working when all three of these scenarios are fun and distinct:

1. **Ghost run:** Player completes zone with 0 kills and 0 alerts by timing every patrol and using dark mode at chokepoints
2. **Search recovery:** Player gets spotted, breaks LOS, watches SEARCH phase play out from cover, then completes zone
3. **Combat clear:** Player triggers full alert, kills all enemies in color-exploding chaos, zone goes quiet

If scenario 2 doesn't exist (the search state doesn't feel tense), Phase 1 isn't done yet.
