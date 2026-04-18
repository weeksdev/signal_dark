# Signal Dark — Game Design Document
**Version:** 0.1 — Foundation Build  
**Target Platform:** iOS (primary) / macOS (development & testing)  
**Engine:** Godot 4.x  
**Input:** MFi Controller (GameSir G8 Plus / standard MFi) — controller-first, no touch fallback in v1  
**Viewport:** 390 × 844 (iPhone 14 portrait) — enforced on macOS during development  
**Status:** Pre-production — document for agent implementation

---

## 1. Vision Statement

Signal Dark is a top-down stealth-action game set inside an abstract geometric machine world. The player pilots a small geometric vessel through a vast scrolling map populated by hostile geometric entities. The default state is stealth — everything is rendered in monochrome green, slow, and quiet. Stealth breaks into geometry wars-style combat — explosive color, particle chaos, and swarm pressure — before the player must find silence again.

The game asks one question on every screen: *do you ghost through, or do you fight your way out?*

Core references:
- **Metal Gear Solid** — patrol logic, detection cones, alert states, suppressed kills, the tension of being hunted
- **Geometry Wars (Xbox Arcade)** — color explosion aesthetic, particle systems, enemy swarm behavior, screen-filling chaos when combat starts
- **Matrix: Nebuchadnezzar hiding** — powering down to vanish inside a hostile machine ecosystem

---

## 2. Core Design Pillars

### 2.1 Green world / color explosion duality
The entire game world renders in monochrome **green** during stealth. Enemies, terrain, particles, UI — everything is a shade of green phosphor. The moment combat triggers, the world **explodes into full Geometry Wars color** — enemies light up in their signature hues, particle systems fire in saturated neons, the grid pulses. When the last enemy in an alert zone is eliminated, color bleeds back out and the world returns to green. This transition is the emotional heartbeat of the game.

### 2.2 The emission system
Every action the player takes broadcasts signal. Signal radius is the core mechanic — it determines whether enemies can detect you. Moving increases emission. Firing increases it dramatically. Going dark (holding L2) collapses emission to near-zero. The player manages this meter constantly, choosing between speed, aggression, and silence.

### 2.3 Two kill modes — always a choice
Every enemy can be killed two ways:
- **Suppressed kill** — approach from behind while dark, in close range. Instant silent elimination. No alert. No color.
- **Combat kill** — fire weapons. Instant kill on most enemies, but triggers a local alert cascade that goes full Geometry Wars until the zone is clear.

The suppressed path is slower and requires reading patrol patterns. The combat path is fast and chaotic but leaves you exposed and visible across the map.

### 2.4 Scrolling map with limited view
The player has a zoomed viewport — they see only a small window of a much larger map. The map scrolls with the player, hiding what lies ahead. This creates genuine exploration tension. The player cannot see threats outside their view radius, which makes emission management and patrol timing critical.

---

## 3. Visual System

### 3.1 Stealth mode (default state)
- **Color palette:** Monochrome green phosphor — `#00FF41` (bright), `#00C032` (mid), `#007A1F` (dark), `#003D0F` (shadow), `#000A02` (background)
- All geometry: player ship, enemies, terrain, grid, particles rendered in green variants only
- Background: near-black with faint green grid (`#001A05` dots at 32px spacing)
- Particle effects on movement and kills: green sparks only
- UI elements: green monochrome, CRT-style monospace font
- Enemy detection cones: dim green translucent fill
- Enemy alert state (pre-cascade): cone turns bright green, pulses

### 3.2 Combat mode (alert cascade active)
Triggered when a combat kill occurs or full alert is reached. The transition happens over ~12 frames:
- Background grid pulses white then settles to deep navy `#050518`
- Each enemy type reveals its **signature color** (see Section 5)
- Player ship becomes full electric blue `#00BFFF` with white engine trail
- Particle explosions use **full spectrum** — magenta, cyan, yellow, orange, white
- Grid ripples outward from the kill point in concentric colored rings
- UI accent color shifts from green to white/cyan

### 3.3 Return to stealth
When the last enemy in the active alert zone is eliminated:
- Screen-filling color burst (white flash, then saturated ring expanding outward)
- Over ~60 frames, all remaining scene elements desaturate back to green
- Grid returns to dark green phosphor
- Player ship dims back to green silhouette

### 3.4 Art direction notes for implementation
- All rendering via Godot `CanvasItem` with `modulate` property for the green/color toggle
- Stealth mode: apply a global `ColorAdjustment` environment or shader that desaturates + hue-shifts everything to green
- Combat mode: disable the desaturation shader, let native colors show
- Particle systems: two variants per effect — green particles (stealth) and colored particles (combat). Swap active emitter on state change
- Grid: `TileMap` or procedural `draw_line` calls in a background `Node2D`
- All geometry is vector/polygon-based — no raster sprites

---

## 4. Map & World Structure

### 4.1 Map architecture
- **Logical map size:** 6400 × 3200 pixels (world units)
- **Viewport (player view):** 390 × 844 pixels (iPhone 14 — enforced during macOS dev)
- **Player is always centered** in viewport; map scrolls around them
- Map is divided into **zones** — each zone is roughly 2–3 screens wide
- Zones have a **patrol density**, **terrain layout**, and **enemy composition** set at design time
- Between zones: brief open corridors (breathing room / tension release)

### 4.2 Terrain objects
All terrain is geometric — no organic shapes.

| Object | Description | Signal behavior |
|---|---|---|
| **Lattice wall** | Solid geometric barrier, blocks movement and signal propagation | Blocks detection cones behind it |
| **Signal node** | Pulsing geometric beacon — amplifies player emission radius if nearby | Avoid or destroy silently |
| **Dark pocket** | Zone where emission is suppressed — safe to move quickly | Strategic rest points |
| **Charge gate** | Entry to next zone — activates only when zone is clear or stealthed through | Progression checkpoint |
| **Cover shard** | Small geometric debris — partial cover, reduces cone exposure | Use for stealth routing |

### 4.3 Zone design philosophy
- Zone 1: Tutorial density — 2 Sweepers, 1 Pulsar, open sightlines. Teaches emission and dark mode.
- Zone 2: Introduces lattice walls and routing choices. First suppressed kill opportunity.
- Zone 3+: Layered patrol overlaps, multiple Pulsars, first Hunter encounter.
- Every zone has at least one viable ghost route (full stealth path) AND one viable combat route (fight through).
- Designer intent: the ghost route is always harder and more rewarding.

---

## 5. Enemy Archetypes

All enemies are geometric polygons. In stealth mode: green. In combat mode: their signature color.

### 5.1 The Sweeper
- **Shape:** Rotating hexagon
- **Combat color:** `#00FF88` (bright teal-green — distinct from stealth green)
- **Behavior:** Patrols a fixed circular or linear path. Projects a detection cone in its facing direction. Cone angle: ~60 degrees. Detection range: ~120 world units.
- **Detection:** Detects player if emission radius overlaps cone AND no lattice wall blocks line of sight.
- **Alert:** On detection, broadcasts alert to all enemies within 200 units. Enters pursuit for 3 seconds before returning to patrol if player goes dark.
- **Suppressed kill:** Approach within 20 units from behind (outside cone arc). One button press. Silent. Green spark burst. No alert.
- **Combat kill:** Any weapon hit. Triggers alert cascade. Color explosion on death — teal ring expanding outward.
- **Geometry Wars behavior (combat):** In alert, Sweepers swarm toward player position, circling at medium range and closing.

### 5.2 The Pulsar
- **Shape:** Star polygon (6-point), rotates slowly
- **Combat color:** `#FFB300` (amber)
- **Behavior:** Stationary. Emits periodic omnidirectional detection pulses. Pulse interval: 2.5 seconds. Pulse travels outward at 180 units/sec. Detects player if pulse ring intersects player AND player is not in dark mode.
- **Suppressed kill:** Go dark, close to within 20 units, execute. Silent. Pulse stops permanently.
- **Combat kill:** Weapon hit. Spectacular amber explosion — rings expanding in 3 sizes.
- **Geometry Wars behavior:** In alert, dormant Pulsars in range activate and pulse rapidly (0.5s interval), flooding the zone with detection rings.

### 5.3 The Hunter
- **Shape:** Elongated diamond / arrowhead
- **Combat color:** `#FF2D55` (hot red)
- **Behavior:** Spawns when alert level exceeds 70%. Locks onto player and pursues relentlessly. Faster than the player at full emission. Cannot be outrun — must be evaded by going dark (loses lock after 2s of zero emission).
- **Suppressed kill:** Not possible — Hunters are always facing the player.
- **Combat kill:** Weapon hit. Red explosion with trailing particles. Satisfying to kill.
- **Geometry Wars behavior:** In alert, multiple Hunters spawn in waves, weaving toward player.

### 5.4 The Lattice Weaver
- **Shape:** Diamond with extending line segments (spider-like)
- **Combat color:** `#BF5AF2` (purple)
- **Behavior:** Slow-moving. Extends geometric tether lines between itself and nearby Lattice terrain. Tethers act as tripwires — player passing through triggers alert. Tethers visible as dim lines in stealth.
- **Suppressed kill:** Destroy from behind while tethers retracted (brief window during movement).
- **Combat kill:** Weapon hit. Purple web explosion — tethers snap outward as projectiles.
- **Geometry Wars behavior:** In alert, Weavers rapidly lay tether networks across the arena, constraining player movement.

### 5.5 The Void Cluster
- **Shape:** Mass of 8–12 small triangles orbiting a center point
- **Combat color:** `#FF6B35` (orange) — individual fragments in various warm hues
- **Behavior:** Drifts slowly in a patrol area. Individual fragments are harmless. Cluster contact kills player. Reacts to signal emission by accelerating toward the source.
- **Suppressed kill:** Not possible directly — must use a signal probe to draw it away from path, then ghost past.
- **Combat kill:** Destroy center node. Fragments scatter as short-lived projectiles then explode. Most visually chaotic enemy death in the game.
- **Geometry Wars behavior:** In alert, multiple Clusters converge, filling corridors.

### 5.6 The Mirror
- **Shape:** Flat rhombus, reflective surface rendered as bright highlight line
- **Combat color:** `#32D2FF` (cyan)
- **Behavior (late game):** Mimics player emission signature. Emits a signal radius equal to the player's current emission. Confuses other enemies (they may target Mirror instead of player in some states). Mirror itself homes slowly toward player.
- **Suppressed kill:** Emit a specific pattern — go dark, brief burst, dark again. Mirror enters confused state for 3s. Approach from any direction for suppressed kill.
- **Combat kill:** Hit while Mirror is in confused state or from outside its facing arc. Cyan crystalline shatter explosion.
- **Geometry Wars behavior:** In alert, Mirror copies player weapon fire, shooting back toward them.

---

## 6. Player Ship

### 6.1 Visual
- **Stealth mode:** Elongated arrowhead polygon, dark green `#004D15` fill, bright green `#00FF41` outline, dim engine trail
- **Combat mode:** Electric blue `#00BFFF` fill, white outline, full particle engine trail
- **Dark mode active:** Ship goes near-black with a faint purple outline, engine trail disappears. Drifts on momentum.

### 6.2 Movement
- **Physics:** Momentum-based. Acceleration applied while input held. Drag applied always.
- **Normal thrust:** Moderate acceleration, moderate drag. Responsive but not instant.
- **Dark mode thrust:** Reduced acceleration (50%), higher drag. Ship is harder to steer but harder to detect.
- **Boost:** High acceleration burst, very high emission spike. Emergency use only.
- Left analog stick magnitude directly maps to thrust intensity, which directly drives emission output — pushing stick gently = whisper movement, full push = high emission. This is the core analog controller feel.

### 6.3 Weapons (progression)

Weapons are found in the map as geometric pickups.

| Weapon | Stealth kill? | Combat behavior | Emission cost |
|---|---|---|---|
| **Pulse shot** (default) | No | Single projectile, low damage, low particle output | Medium |
| **Scatter burst** | No | 5-way spread, each pellet has particles | High |
| **Dark lance** | Yes (suppressed) | Slow silent projectile — kills in 1 hit, no explosion, no alert if target is isolated | Zero (dark mode only) |
| **Nova bomb** | No | Screen-clearing explosion, massive color burst, triggers full alert | Very high |
| **Tether mine** | Partial | Plant on terrain, detonates on enemy contact silently if set to suppressed mode | Low (placement), High (detonation) |
| **Chain arc** | No | Chains between nearby enemies, Geometry Wars-style. Spectacular. Loud. | Very high |

### 6.4 Signal probe
- 3 charges, replenished at dark pockets
- Fires a small beacon that broadcasts fake emission from its landing point
- Draws detection-based enemies (Sweepers, Pulsars, Void Clusters) toward it for 4 seconds
- Essential for routing around dense patrol formations

---

## 7. Detection & Alert System

### 7.1 Emission meter
- Range: 0.0 – 1.0
- Base idle emission: 0.08
- Moving (normal): 0.25 + velocity magnitude × 0.6
- Dark mode: 0.02 (near-zero, not absolute zero — prevents exploit of being immune)
- Boost: 0.85 instant spike, decays over 1.5s
- Pulse shot fired: 0.4 spike, decays over 0.8s
- Combat weapon fired: 0.7–1.0 spike

### 7.2 Detection resolution
Each enemy type has a **detection threshold** (how much of the player's emission radius must overlap their detection area) and a **line-of-sight requirement**.

```
Detection = (emission_overlap > enemy.threshold) AND (LOS not blocked by lattice) AND (player not in dark_pocket)
```

### 7.3 Alert states

| State | Trigger | Visual | Enemy behavior |
|---|---|---|---|
| **Clear** | Alert meter 0–0.2 | Stealth green, all normal | Normal patrol |
| **Caution** | Alert meter 0.2–0.5 | Green pulses slightly brighter | Sweepers slow patrol, Pulsars increase pulse rate |
| **Alert** | Any combat kill OR meter > 0.7 | Full color explosion. Grid pulses. | All enemies in zone activate and converge |
| **Pursuit** | Hunter spawned | Red edge vignette | Hunter locks on, swarm converges |

### 7.4 Alert cascade mechanics
When **Alert** state triggers in a zone:
1. All enemies within 400 units of the trigger point activate simultaneously
2. Geometry Wars combat begins — enemies use their combat swarm behavior
3. New enemies may spawn from the edges of the active zone (wave spawning)
4. Alert ends only when **all activated enemies are eliminated** OR player exits the zone boundary
5. Exiting the zone boundary pauses the cascade — enemies hold at zone edge, alert does not follow (stealth game design principle: you can always run)

---

## 8. Controller Mapping (MFi / GameSir G8 Plus)

| Input | Action |
|---|---|
| **Left stick** | Thrust direction + magnitude (analog — stick pressure = emission intensity) |
| **Right stick** | Aim direction (decouple aim from movement) |
| **L2 (hold)** | Dark mode — cut all power, drift on momentum |
| **R2** | Boost — emergency speed burst, high emission spike |
| **R1** | Fire primary weapon |
| **L1** | Fire alternate weapon / swap weapon |
| **Cross / A** | Suppressed kill (context — only appears when behind enemy in range) |
| **Square / X** | Launch signal probe |
| **Triangle / Y** | Interact (pick up weapon, activate dark pocket) |
| **Circle / B** | Nova bomb (if equipped) |
| **D-pad** | Weapon slot select (up/down) |
| **Options / Menu** | Pause |
| **L3 (stick click)** | Zoom out briefly (tactical view — 0.5s hold, shows wider map area) |

---

## 9. Godot 4 Implementation Architecture

### 9.1 Project structure
```
signal_dark/
├── project.godot
├── src/
│   ├── autoloads/
│   │   ├── GameState.gd        # Global state singleton
│   │   ├── AlertSystem.gd      # Emission + alert level management
│   │   └── InputManager.gd     # Controller input abstraction
│   ├── world/
│   │   ├── World.tscn          # Main game scene
│   │   ├── ZoneMap.gd          # Map scrolling, zone management
│   │   ├── Grid.gd             # Background grid renderer
│   │   └── zones/              # Individual zone scene files
│   ├── player/
│   │   ├── Ship.tscn
│   │   ├── Ship.gd             # Movement, emission, dark mode
│   │   ├── WeaponSystem.gd     # Weapon management + firing
│   │   └── SignalProbe.tscn
│   ├── enemies/
│   │   ├── BaseEnemy.gd        # Shared detection + alert logic
│   │   ├── Sweeper.tscn / .gd
│   │   ├── Pulsar.tscn / .gd
│   │   ├── Hunter.tscn / .gd
│   │   ├── LatticeWeaver.tscn / .gd
│   │   ├── VoidCluster.tscn / .gd
│   │   └── Mirror.tscn / .gd
│   ├── weapons/
│   │   ├── PulseShot.tscn
│   │   ├── ScatterBurst.tscn
│   │   ├── DarkLance.tscn
│   │   ├── NovaBomb.tscn
│   │   ├── TetherMine.tscn
│   │   └── ChainArc.tscn
│   ├── terrain/
│   │   ├── LatticeWall.tscn
│   │   ├── SignalNode.tscn
│   │   ├── DarkPocket.tscn
│   │   └── CoverShard.tscn
│   ├── fx/
│   │   ├── ColorSystem.gd      # Global green/color mode shader toggle
│   │   ├── ParticleLibrary.gd  # Particle scene factory
│   │   ├── ExplosionRing.tscn  # Expanding ring on death
│   │   └── GridPulse.gd        # Grid ripple on combat trigger
│   └── ui/
│       ├── HUD.tscn
│       ├── EmissionBar.gd
│       ├── AlertBar.gd
│       └── WeaponDisplay.gd
├── assets/
│   ├── shaders/
│   │   ├── stealth_green.gdshader   # Global desaturate + green hue shift
│   │   └── grid_background.gdshader
│   └── particles/                   # GPUParticles2D assets
└── export/
    ├── ios/
    └── macos/
```

### 9.2 Key implementation notes

**Viewport & display:**
```gdscript
# project.godot display settings
display/window/size/viewport_width = 390
display/window/size/viewport_height = 844
display/window/stretch/mode = "canvas_items"
display/window/stretch/aspect = "keep"
```
This enforces iPhone 14 portrait dimensions even on macOS, ensuring all development is 1:1 with iOS target.

**Emission system (AlertSystem.gd autoload):**
```gdscript
var emission: float = 0.0
var alert_level: float = 0.0
var combat_mode: bool = false

func update_emission(delta: float, ship: Ship) -> void:
    var target = 0.08
    if ship.is_moving: target += 0.25 + ship.velocity.length() * 0.6
    if ship.dark_mode: target = 0.02
    if ship.boosting: target = 0.85
    emission = lerp(emission, target, delta * 8.0)
    emission = clamp(emission, 0.0, 1.0)
```

**Color mode shader toggle (ColorSystem.gd):**
```gdscript
var stealth_shader: ShaderMaterial  # applied to World CanvasLayer
var in_combat: bool = false

func enter_combat() -> void:
    in_combat = true
    var tween = create_tween()
    tween.tween_property(stealth_shader, "shader_parameter/intensity", 0.0, 0.4)
    GridPulse.trigger()

func exit_combat() -> void:
    var tween = create_tween()
    tween.tween_property(stealth_shader, "shader_parameter/intensity", 1.0, 1.5)
    await tween.finished
    in_combat = false
```

**Enemy detection (BaseEnemy.gd):**
```gdscript
func check_detection(ship: Ship, alert_system: AlertSystem) -> void:
    var emission_radius = 20.0 + alert_system.emission * 100.0
    var d = global_position.distance_to(ship.global_position)
    var in_range = d < (emission_radius + detection_range * 0.3)
    var has_los = not _is_blocked_by_lattice(ship.global_position)
    if in_range and has_los and not ship.dark_mode:
        _trigger_detection(ship)
```

**Camera / map scroll:**
- Use Godot `Camera2D` with `position_smoothing_enabled = true`
- Camera follows player, bounded by map edges
- Zoom level fixed at value that shows ~390×844 world units (1:1 with viewport)
- `L3` tactical zoom: `camera.zoom = lerp(camera.zoom, Vector2(0.5, 0.5), delta * 8.0)` while held, snaps back on release

### 9.3 Physics layers
```
Layer 1: Player ship
Layer 2: Enemies
Layer 3: Weapons / projectiles
Layer 4: Terrain (lattice walls)
Layer 5: Detection areas (Area2D — no physics, overlap only)
Layer 6: Signal zones (dark pockets, signal nodes)
```

### 9.4 Particle system strategy
Each enemy death has two `GPUParticles2D` nodes as children:
- `particles_stealth` — green variants, active when `ColorSystem.in_combat == false`
- `particles_combat` — full color variants, active when `ColorSystem.in_combat == true`

On kill, activate the appropriate emitter, then `queue_free()` the enemy after particle lifetime.

---

## 10. iOS Export Configuration

```
# Godot export preset: iOS
export/bundle_identifier = "com.yourname.signaldark"
export/version = "0.1.0"
export/orientation = portrait
export/targeted_device = 2  # iPhone only
export/min_ios_version = "16.0"
export/controllers_required = false  # allow future touch layer
export/mfi_controller_support = true
```

**MFi controller note:** Godot 4's `Input` singleton handles MFi controllers natively on iOS via GameController framework. No additional plugin required. Use `Input.get_joy_axis()` for analog sticks and `Input.is_joy_button_pressed()` for buttons. Map in `Project > Input Map` using joystick axis actions.

**macOS testing with controller:**
- Connect GameSir G8 Plus via USB-C or Bluetooth
- Godot detects automatically as a standard gamepad
- All `InputMap` actions defined for joypad carry over to iOS export without modification

---

## 11. Build Sequence for Agent

Implement in this order — each phase produces a testable build:

**Phase 1 — Core loop (test in browser or macOS first)**
1. Viewport setup (390×844 enforced)
2. Ship movement with momentum physics
3. Emission meter driving from analog stick magnitude
4. Dark mode toggle (L2)
5. Background grid renderer (green)
6. Single Sweeper with patrol + detection cone
7. Alert state color transition (green → color)

**Phase 2 — Stealth system**
1. Lattice wall terrain with LOS blocking
2. Detection logic with lattice occlusion
3. Alert cascade (zone-local, not global)
4. Suppressed kill mechanic
5. Signal probe

**Phase 3 — Combat system**
1. Primary weapon (Pulse shot)
2. Combat kill → alert cascade trigger
3. Geometry Wars enemy swarm behavior
4. Wave spawning during alert
5. Alert-clear → stealth return transition

**Phase 4 — Enemy roster**
Add enemies in this order: Pulsar → Hunter → Void Cluster → Lattice Weaver → Mirror

**Phase 5 — Weapons & progression**
Scatter burst → Dark lance → Tether mine → Chain arc → Nova bomb

**Phase 6 — Map & zones**
1. Large map implementation (6400×3200)
2. Camera scroll with player follow
3. Zone system with charge gates
4. 3 hand-designed zones + corridor connectors
5. Weapon pickups in world

**Phase 7 — Polish**
1. Particle system full pass (stealth + combat variants for all deaths)
2. Grid pulse on combat trigger
3. Color transition tweening
4. HUD (emission bar, alert bar, weapon display, probe count)
5. Ghost rating / score on zone clear
6. iOS export + controller mapping verification

---

## 12. Ghost Rating System

Awarded per zone, displayed on zone clear.

| Rating | Condition |
|---|---|
| **S — Silent ghost** | Zero combat kills, zero alert triggers, under par time |
| **A — Clean** | Zero combat kills, alert triggered but resolved silently |
| **B — Operative** | 1–3 combat kills, alert resolved |
| **C — Loud** | Full alert triggered, survived |
| **D — Compromised** | Multiple alert cascades, heavy combat |

Cumulative rating across all zones determines end-of-run score.

---

*Document version 0.1 — prepared for Godot 4 agent implementation. All measurements in Godot world units (pixels at 1:1 zoom). Controller mapping assumes standard MFi layout. Platform target: iOS 16+ / macOS 13+ for development.*
