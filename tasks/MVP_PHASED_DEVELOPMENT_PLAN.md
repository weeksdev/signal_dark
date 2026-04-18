# Signal Dark MVP Phased Development Plan

## Goal

Build a Godot 4 proof of concept that proves the core promise in a single playable zone:

- Ghost through a patrol space using low emission and dark mode
- Trigger detection and transition from monochrome stealth into full-color combat
- Survive the local alert encounter
- Clear the zone and return the world to green stealth mode

This plan treats the game as:

- `Metal Gear Solid` for stealth readability, patrol dynamics, and suppression rules
- `Geometry Wars` for arena structure, immediacy, and explosive combat presentation

## POC Product Decisions

### Scope

The MVP is one hand-authored zone, not a full campaign map.

Included:

- One player ship
- One `Sweeper`
- One `Pulsar`
- One `Pulse Shot`
- One `Signal Probe`
- One `Dark Pocket`
- One `Lattice Wall`
- Zone-local alert/combat transition
- Death and instant restart

Deferred:

- Multiple zones
- Inventory progression
- Weapon pickups
- Score persistence
- iOS export polish
- Advanced enemy roster

### POC Rules

- Movement is arcade-responsive with light momentum
- Right stick aiming persists when released
- `Dark Mode` reduces emission sharply and weakens thrust
- `Sweeper` detects through a readable cone plus line-of-sight check
- `Pulsar` detects through periodic radial pulses
- Suppressed kill uses a generous rear-arc rule and short snap window
- Alert is strictly zone-local
- Leaving the zone is not part of the MVP loop
- Death restarts the current zone immediately

## Success Criteria

The MVP is successful if a player can do all of the following in one short session:

1. Move with analog-feeling thrust and observe emission changing
2. Use dark mode to reduce detection risk
3. Read and avoid a `Sweeper` patrol cone
4. Experience a `Pulsar` pulse check
5. Trigger alert through visibility or gunfire
6. See the world transition from green stealth to full-color combat
7. Fight and clear the active enemies
8. See the world return to green stealth mode

## Build Phases

## Phase 1: Project Skeleton

Purpose:
- Create a Godot-standard project with clean scene/script separation

Tasks:
- Create `project.godot`
- Add `src/autoloads`, `src/world`, `src/player`, `src/enemies`, `src/terrain`, `src/ui`, `src/fx`
- Register autoload singletons:
  - `GameState.gd`
  - `AlertSystem.gd`
  - `InputManager.gd`
  - `ColorSystem.gd`
- Create `World.tscn` as the main scene

Deliverable:
- Project opens in Godot and runs into a playable scene shell

## Phase 2: Core Player Loop

Purpose:
- Prove the ship feels good enough for stealth and arcade combat

Tasks:
- Implement ship movement with:
  - acceleration
  - drag
  - max speed
  - boost
  - dark mode thrust penalty
- Track emission from movement and actions
- Add simple aim handling from right stick / fallback to movement vector
- Add debug-visible emission radius

Deliverable:
- Ship can move, aim, boost, and change emission in real time

## Phase 3: Stealth Readability

Purpose:
- Prove stealth is understandable and deterministic

Tasks:
- Add `Sweeper` with patrol path and detection cone
- Add `Pulsar` with timed expanding pulse
- Add `Lattice Wall` blocking LOS
- Add `Dark Pocket` that suppresses emission further
- Add suppressed kill prompt/range/rear-arc check
- Add debug overlays for cone, pulse, LOS, and enemy states

Deliverable:
- Player can intentionally ghost around enemies and perform at least one silent kill route

## Phase 4: Alert and Combat Transition

Purpose:
- Prove the green-to-color identity shift

Tasks:
- Add zone-local alert state machine
- Trigger combat on combat kill or enemy detection
- Switch world from stealth green to combat color mode
- Add simple combat swarm behavior for active enemies
- Return to stealth when all zone enemies are eliminated

Deliverable:
- Alert feels local, readable, and visually dramatic

## Phase 5: Arena Combat MVP

Purpose:
- Prove the Geometry Wars side of the pitch

Tasks:
- Add `Pulse Shot`
- Add hit detection and enemy death handling
- Add enemy activation on alert
- Add lightweight particles/rings via procedural draw or simple nodes
- Add restart-on-death flow

Deliverable:
- Player can fight through the same zone after detection

## Phase 6: Presentation and Evaluation Pass

Purpose:
- Make the MVP usable for evaluation

Tasks:
- Add minimal HUD:
  - emission bar
  - alert bar
  - mode label
  - probe count
- Add combat/stealth color modulation
- Add camera framing for portrait layout
- Add zone clear and reset affordances
- Document controls

Deliverable:
- Playable vertical slice ready for feel review

## Implementation Boundaries

### Architecture

- Keep all alert and color state in autoloads
- Keep zone ownership in `World`
- Keep enemies self-contained and driven by a small shared base class
- Prefer hand-authored placement in the scene tree over data systems for the MVP

### Rendering

- Stealth mode should force a monochrome green read across world geometry
- Combat mode should restore native colors and enable stronger effects
- UI remains readable in both modes

### Tuning Priorities

Tune in this order:

1. Ship handling
2. Sweeper readability
3. Pulsar readability
4. Alert transition timing
5. Combat pacing

## Evaluation Checklist

- Does movement feel sharp enough for an arcade game while preserving stealth tension?
- Can a player predict why they were detected?
- Does dark mode feel tactically useful instead of mandatory?
- Does alert feel like a local combat event rather than a global failure state?
- Is the green-to-color transition the strongest emotional beat on screen?
- Can the same zone support both ghost and fight playstyles?
