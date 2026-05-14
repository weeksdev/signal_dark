# Agent-Driven Deterministic Game Testing Harness for Signal Dark

## Goal

Build a deterministic automated testing and review harness for `Signal Dark` that allows an AI agent to:

1. Modify the game.
2. Launch controlled deterministic gameplay scenarios.
3. Simulate player behavior.
4. Capture screenshots and telemetry during execution.
5. Review results.
6. Determine whether the implementation worked correctly.
7. Iteratively fix issues.

This system is NOT intended to create a fully autonomous gameplay AI initially.

The primary goal is:

* deterministic reproducibility
* visual validation
* gameplay regression detection
* rapid agent feedback loops

---

# High-Level Architecture

```text
Agent
  ↓
Scenario JSON
  ↓
Godot Agent Harness
  ↓
Deterministic Scenario Execution
  ↓
Screenshots + Telemetry + Assertions
  ↓
Artifacts Written To Disk
  ↓
Agent Reviews Results
  ↓
Agent Modifies Game Or Scenario
```

---

# Core Design Principles

## 1. Deterministic

All runs must be reproducible.

Requirements:

* explicit seed support
* fixed spawn locations
* deterministic scripted actions
* deterministic scenario timing

The same scenario file should produce near-identical output every run.

---

## 2. Sparse Screenshot Capture

DO NOT capture every frame.

Capture:

* explicit checkpoints
* interval snapshots
* failures
* major gameplay events

Hard-cap screenshots per run.

Recommended:

* 8–20 screenshots per scenario

---

## 3. Semantic Actions

DO NOT simulate raw keyboard input initially.

Instead expose semantic actions:

```json
{
  "action": "move_to",
  "target": [300, 120]
}
```

instead of:

```json
{
  "keypress": "D"
}
```

Semantic actions are:

* more stable
* more deterministic
* easier for agents to generate
* easier to debug

---

## 4. Visual + Structured Feedback

Screenshots alone are insufficient.

Telemetry alone is insufficient.

Combine both.

Each screenshot should have associated world-state metadata.

---

# Directory Structure

Create:

```text
tests/
  agent/
    AgentHarness.gd
    ScenarioRunner.gd
    InputDriver.gd
    ScreenshotRecorder.gd
    TelemetryRecorder.gd
    AssertionEngine.gd

    scenarios/
      hunter_basic_attack.json
      stealth_visibility.json
      warp_mine_payload.json
      regression_template.json

    artifacts/
      .gitkeep
```

---

# Godot Entry Point

Add CLI support:

```bash
godot --headless --path . -- \
  --agent-harness \
  --scenario tests/agent/scenarios/hunter_basic_attack.json
```

Support future arguments:

```bash
--seed 1234
--speed 2
--artifact-dir tests/agent/artifacts
```

---

# Main Harness Responsibilities

## AgentHarness.gd

Responsibilities:

* parse CLI args
* load scenario
* configure engine
* initialize services
* launch scenario runner
* coordinate teardown
* write final report

Pseudo-flow:

```text
parse args
load scenario json
set Engine.time_scale
initialize telemetry
initialize screenshots
initialize assertions
run scenario
save artifacts
exit with code
```

---

# Scenario JSON Format

## Example

```json
{
  "scenario": "hunter_basic_attack",
  "scene": "res://src/world/AgentTestArena.tscn",

  "seed": 1234,

  "time_scale": 2.0,

  "screenshots": {
    "interval_seconds": 1.0,
    "max": 16,
    "capture_on_failure": true
  },

  "assertions": [
    {
      "condition": "enemy_count == 0",
      "message": "Enemy should be destroyed"
    }
  ],

  "steps": [
    {
      "t": 0.0,
      "action": "spawn_player",
      "at": [120, 120]
    },

    {
      "t": 0.1,
      "action": "spawn_enemy",
      "type": "Hunter",
      "id": "enemy_1",
      "at": [420, 120]
    },

    {
      "t": 0.2,
      "action": "capture",
      "name": "initial_state"
    },

    {
      "t": 1.0,
      "action": "move_to",
      "target": [260, 120]
    },

    {
      "t": 2.0,
      "action": "aim_at",
      "target": "enemy_1"
    },

    {
      "t": 2.1,
      "action": "hold_input",
      "input": "fire",
      "duration": 1.0
    },

    {
      "t": 3.5,
      "action": "capture",
      "name": "after_attack"
    }
  ]
}
```

---

# Supported Actions

## Required Initial Actions

Implement:

```text
spawn_player
spawn_enemy
move_to
move_vector
aim_at
hold_input
tap_input
wait
capture
assert
```

---

## Example Definitions

### move_to

```json
{
  "action": "move_to",
  "target": [300, 100]
}
```

Harness should:

* compute normalized direction
* drive movement until close to target
* stop automatically

---

### move_vector

```json
{
  "action": "move_vector",
  "direction": [1, 0],
  "duration": 1.5
}
```

---

### aim_at

```json
{
  "action": "aim_at",
  "target": "nearest_enemy"
}
```

---

### hold_input

```json
{
  "action": "hold_input",
  "input": "fire",
  "duration": 0.8
}
```

---

### capture

```json
{
  "action": "capture",
  "name": "before_combat"
}
```

---

# Screenshot System

## ScreenshotRecorder.gd

Responsibilities:

* capture viewport
* enforce screenshot cap
* timestamp captures
* write PNG files

---

## Capture Rules

Capture:

* explicit capture actions
* interval captures
* failures
* assertion failures

Do NOT:

* capture every frame

---

## File Naming

```text
001_initial_state.png
002_enemy_spawned.png
003_after_attack.png
004_failure.png
```

---

# Telemetry System

## TelemetryRecorder.gd

Every screenshot should have associated telemetry.

---

## Telemetry Example

```json
{
  "time": 2.4,

  "player": {
    "position": [280, 120],
    "health": 3,
    "dark_mode": false
  },

  "enemies": [
    {
      "id": "enemy_1",
      "type": "Hunter",
      "position": [420, 120],
      "health": 2,
      "state": "attacking"
    }
  ],

  "events_since_last_capture": [
    "enemy_detected_player",
    "player_fired_weapon"
  ]
}
```

---

# Artifact Output

Each run should create:

```text
tests/agent/artifacts/
  2026-05-14_001_hunter_basic_attack/
```

Inside:

```text
run.json
summary.md
telemetry.jsonl

screenshots/
  001_initial_state.png
  002_after_attack.png
```

---

# run.json Format

```json
{
  "scenario": "hunter_basic_attack",
  "seed": 1234,

  "ok": true,

  "duration_seconds": 4.2,

  "screenshots": 4,

  "assertions": [
    {
      "ok": true,
      "message": "Enemy should be destroyed"
    }
  ]
}
```

---

# Assertion System

## AssertionEngine.gd

Initial assertions:

* enemy_count
* player_health
* enemy_health
* object_exists
* scene_loaded
* player_inside_bounds

Later:

* FPS stability
* no softlock
* path validity
* visibility correctness

---

# Recommended Test Arenas

Create dedicated deterministic test scenes:

```text
AgentTestArena.tscn
WeaponTestArena.tscn
StealthArena.tscn
EnemyBehaviorArena.tscn
```

DO NOT initially run all tests through full gameplay.

Small isolated scenarios are:

* faster
* easier to debug
* easier for agents to reason about

---

# Engine Time Scaling

Use:

```gdscript
Engine.time_scale = scenario.time_scale
```

Recommended:

* 1.0–2.0 initially

Avoid very high values until stability verified.

---

# Agent Workflow

## Desired Future Workflow

```text
User:
"Add a new mine enemy."

Agent:
- modifies code
- creates scenario
- runs harness
- reviews screenshots + telemetry
- fixes bugs
- reruns
```

---

# Future Improvements

## Phase 2

Add:

* automatic event capture
* gameplay heatmaps
* AI-driven scenario generation
* visual diffing
* regression comparisons

---

## Phase 3

Add:

* multi-agent playtesting
* explorer bots
* aggressive bots
* stealth bots
* exploit-seeking bots

---

## Phase 4

Add:

* CV-based UI validation
* visual clutter analysis
* navigation quality analysis
* balancing analytics

---

# Important Constraints

## DO NOT

* capture every frame
* rely entirely on screenshots
* rely entirely on telemetry
* use raw keyboard automation initially
* attempt fully autonomous gameplay immediately

---

# Success Criteria

The implementation is successful if an AI agent can:

1. Modify gameplay code.
2. Generate deterministic scenarios.
3. Execute scenarios headlessly.
4. Review screenshots + telemetry.
5. Identify implementation failures.
6. Iteratively improve the game automatically.

---

# Initial Milestone

Implement:

* scenario parsing
* deterministic movement
* screenshot capture
* telemetry
* assertion system
* artifact output

before attempting:

* autonomous gameplay AI
* advanced CV analysis
* large-scale procedural testing
