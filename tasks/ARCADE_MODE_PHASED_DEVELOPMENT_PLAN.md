# Arcade Mode Phased Development Plan

## Goal

Build an `Arcade Mode` that generates replayable, deterministic, validated levels from a seed instead of relying on fully hand-authored scenes.

The target is not "pure randomness." The target is:

- readable procedural stealth/combat spaces
- escalating pressure over a run
- deterministic seeds for replay and debugging
- automatic rejection of invalid or low-quality maps
- reuse of the current enemy and terrain systems wherever possible


## Design Direction

Arcade Mode should be a constrained procedural director, not a freeform noise generator.

Preferred model:

1. Generate a high-level level graph
2. Assemble rooms/corridors from authored modules
3. Apply setpieces and encounter rules
4. Run validators
5. Reject and reroll bad seeds

This keeps levels readable and testable while still giving variety.


## Core Principles

Every generated floor should satisfy these principles:

- There is always one critical path from spawn to exit.
- The critical path is readable before commitment.
- There is at least one alternate pocket, side route, or dead end.
- The player spawn is safe on load.
- The exit is reachable and not trivially exposed with zero counterplay.
- Detection threats escalate in layers, not as immediate chaos everywhere.
- Enemy combinations should create different decision pressure, not just higher counts.
- Combat escalation should feel authored even when the map is generated.
- Generated floors must pass geometry, spawn, and routing validation.


## Non-Goals

Do not start with:

- arbitrary organic maze generation
- tile-by-tile fully emergent geometry
- "infinite" rules without validation
- enemy placement based only on random coordinates

That will produce unreadable or broken levels too often.


## Generator Strategy

Use a hybrid model:

- Authored room and corridor modules
- Procedural graph assembly
- Rule-based encounter composition
- Seeded deterministic generation

This allows the game to preserve:

- stealth readability
- combat pacing
- known-good wall closure
- validation compatibility


## Data Model

### 1. Run Seed

Each Arcade Mode run should be reproducible from a single seed.

Suggested fields:

- `run_seed`
- `floor_index`
- `difficulty_tier`
- `theme_id`

The generator should derive all randomness from these inputs.

### 2. Zone Graph

Represent the level as a graph before geometry is placed.

Suggested node types:

- `start`
- `corridor`
- `room`
- `branch_room`
- `setpiece_room`
- `exit`

Suggested edge properties:

- traversal width
- required gate state
- preferred threat type
- branch vs critical path

### 3. Room Modules

Each room module should define:

- size
- doorway anchors
- valid connection directions
- interior wall pattern slots
- cover slots
- dark pocket slots
- setpiece support tags

Example categories:

- `spawn_safe`
- `scanner_gallery`
- `cross_room`
- `reactor_room`
- `gate_prison`
- `warp_nest`
- `exit_vault`

### 4. Encounter Templates

Each encounter template should define:

- enemy budget cost
- enemy mix constraints
- min room size
- placement slots
- compatibility tags
- escalation rules


## Difficulty System

Use a point budget per floor, not just enemy count.

Suggested starting costs:

- `Sweeper`: 2
- `Pulsar`: 2
- `Wisp`: 2
- `Hunter`: 3
- `Sentry`: 3
- `Prism`: 4
- `WarpMine`: 4
- `GateLock pair`: 3

Suggested floor budgets:

- Floor 1-2: `6-10`
- Floor 3-4: `10-14`
- Floor 5-6: `14-18`
- Floor 7+ : `18-24`

Also apply composition rules:

- No more than one high-pressure novelty mechanic on the first floor.
- `Prism` should appear after the player has already seen basic detection logic.
- `WarpMine` should appear after the player has already learned lane control.
- `GateLock` should change route logic, not softlock the map.
- Reinforcement-style combat escalation should be reserved for later floors or explicit themes.


## Theming

Arcade floors should rotate between themes so runs feel structured.

Suggested themes:

- `Stealth Maze`
- `Pulse Lattice`
- `Prism Lockdown`
- `Gate Prison`
- `Warp Nest`
- `Combat Collapse`

Theme effects:

- bias room module selection
- bias encounter template selection
- bias dark pocket frequency
- bias gate or reinforcement usage


## Validation Requirements

Validation is mandatory. A generated floor that fails validation should be discarded.

### Existing Validation To Reuse

- map boundary containment
- actor spawn clearance
- sealed maze / no outside leakage

### New Validation To Add

#### Path Validation

- spawn to exit path exists in stealth state
- spawn to exit path exists in combat state
- if gates are used, validate both closed and open traversal states as needed

#### Spawn Safety Validation

- player spawn not inside enemy collision
- player spawn not in direct unavoidable LOS
- exit not blocked by invalid gate/wall state

#### Encounter Validation

- no enemy spawns inside walls
- no WarpMine payload spawn markers inside walls
- no gate overlaps actor spawns
- no setpiece cluster produces zero-cover unavoidable death

#### Fairness Validation

- minimum distance from spawn to first detection threat
- minimum distance from exit to final threat cluster
- no tiny room with excessive high-threat stacking early

#### Readability Validation

- chokepoints have preview space before commitment
- large detectors are not placed entirely off the playable route
- dark pockets remain accessible and meaningful


## Recommended Architecture

### Runtime Pieces

- `ArcadeModeController`
- `ArcadeGenerator`
- `ArcadeSeedRng`
- `ZoneGraphBuilder`
- `ModuleAssembler`
- `EncounterPlacer`
- `ArcadeValidator`
- `ArcadeRunState`

### Content Data

- `RoomModule` resources or JSON-like data
- `EncounterTemplate` resources
- `ThemeProfile` resources
- `DifficultyProfile` resources

### Output

Preferred output format:

- generated scene graph in memory at runtime

Optional debugging output:

- save generated floor as a `.tscn` or debug snapshot for inspection


## Phased Implementation

## Phase 1: Seeded Prototype Skeleton

### Goals

- Create the runtime scaffolding for Arcade Mode
- Generate a trivial deterministic floor from a seed
- Transition into generated play instead of authored world scenes

### Deliverables

- `ArcadeModeController`
- seed handling
- floor index progression
- deterministic RNG wrapper
- temporary generated floor using a single simple template

### Success Criteria

- entering Arcade Mode always produces the same floor for the same seed
- different seeds produce different layouts
- the run can progress from one floor to the next


## Phase 2: Graph-Based Layout Generation

### Goals

- Build the level as a graph before placement
- Separate critical path and branches

### Deliverables

- graph node/edge model
- generator for start → mid sections → exit
- branch/dead-end support
- simple difficulty scaling by floor

### Success Criteria

- generated floors always contain a main route
- some floors contain optional branch pockets
- graph generation is deterministic and debuggable


## Phase 3: Room Module Assembly

### Goals

- Replace placeholder geometry with authored reusable modules
- Assemble modules into a cohesive spatial map

### Deliverables

- module format
- connection rules
- room placement logic
- collision/wall generation from module data

### Success Criteria

- rooms connect cleanly
- boundaries remain sealed
- module-based floors feel authored rather than noisy


## Phase 4: Encounter Placement System

### Goals

- Populate generated spaces with enemy encounters using budget rules

### Deliverables

- enemy budget model
- encounter templates
- placement slots for threats, cover, and dark pockets
- first pass enemy composition rules

### Success Criteria

- encounters vary meaningfully across runs
- placement respects geometry and readability
- early floors are simpler than later floors


## Phase 5: Special Mechanics Integration

### Goals

- Integrate advanced systems into procedural generation

### Deliverables

- `Prism` support
- reinforcement marker support
- `GateLock` support
- `WarpMine` support
- theme-based mechanic biasing

### Success Criteria

- advanced mechanics appear in later floors or themed floors
- gates change route logic correctly
- WarpMine usage feels intentional, not spammy


## Phase 6: Validation Layer

### Goals

- Prevent broken, unfair, or degenerate floors from shipping to the player

### Deliverables

- path validators
- spawn safety validators
- encounter fairness validators
- module overlap validators
- reroll/reject pipeline

### Success Criteria

- invalid seeds are rejected automatically
- generated floors are consistently playable
- debugging failure reasons is straightforward


## Phase 7: Arcade Progression Loop

### Goals

- Turn level generation into a full arcade run structure

### Deliverables

- score system
- run timer or survival metrics
- floor progression
- escalating themes
- optional endless mode after milestone floors

### Success Criteria

- a run feels like a climb, not just isolated random maps
- difficulty escalation is noticeable and coherent
- replaying with a seed is stable


## Phase 8: UX and Debugging Tools

### Goals

- Make the system practical to tune and test

### Deliverables

- developer seed input
- floor preview overlay
- debug graph printout
- validation report output
- run summary and seed display

### Success Criteria

- designers can reproduce bad/fun seeds immediately
- balancing the generator is feasible
- validation failures are explainable


## Suggested Testing Plan

### Automated Tests

- boundary sealing test for generated output
- spawn clearance tests
- gate state traversal tests
- WarpMine payload placement tests
- deterministic seed consistency tests
- path-to-exit tests for stealth and combat

### Playtest Checks

- Can the player read why they were detected?
- Do generated levels still preserve stealth decision-making?
- Are dead ends interesting rather than annoying?
- Do later floors feel harder because of interaction complexity rather than clutter?
- Are there repeated module patterns that become too obvious?


## Technical Risks

### Risk: Maps feel random and ugly

Mitigation:

- use authored modules
- use themes
- enforce graph pacing

### Risk: Generator produces too many invalid maps

Mitigation:

- keep the grammar constrained
- validate early and often
- reject aggressively

### Risk: Difficulty spikes are unfair

Mitigation:

- encounter budgets
- novelty pacing
- spawn safety rules

### Risk: Debugging procedural bugs becomes painful

Mitigation:

- seed determinism
- validation reports
- optional saved debug outputs


## Recommended Build Order

If implementation time is limited, build in this order:

1. deterministic seed + floor progression
2. graph generator
3. module assembly
4. boundary/path validation
5. encounter budget placement
6. advanced mechanics
7. scoring and arcade progression polish


## Definition Of Done For Arcade Mode v1

Arcade Mode v1 is done when:

- a seeded multi-floor run is playable from start to finish
- generated floors are assembled from reusable modules
- encounters escalate by floor and theme
- invalid maps are automatically rejected
- all generated floors pass containment and path validation
- seeds are reproducible
- the mode is fun enough to replay for variety


## Future Extensions

Do not build these first, but keep them compatible with the architecture:

- boss floors
- elite modifier floors
- score multipliers for stealth clears
- daily seeded run
- leaderboards
- inter-floor story screens
- meta progression / unlockable themes
