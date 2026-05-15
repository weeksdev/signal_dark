# Agent-Driven Gameplay Harness Pattern for Godot

## Abstract

Small game teams often rely on manual playtesting because full automation feels too expensive for moment-to-moment game mechanics. A practical middle ground is an agent-driven deterministic gameplay harness: a lightweight Godot runner that loads small scenario files, drives the game through semantic actions, records sparse screenshots and telemetry, evaluates assertions, and writes a complete artifact bundle for review.

The core idea is not to build a full autonomous game-playing AI. Instead, give developers and coding agents a repeatable loop:

1. Create or modify gameplay code.
2. Write a small scenario JSON.
3. Launch a controlled Godot scene.
4. Drive gameplay through high-level actions such as `spawn_enemy`, `move_to`, `aim_at`, `tap_input`, or `hold_input`.
5. Capture a few important screenshots.
6. Record structured telemetry.
7. Evaluate assertions.
8. Use the artifacts to fix regressions.

This works especially well for mechanics that are hard to unit test in isolation: enemy pursuit, stealth visibility, cover behavior, projectile interactions, scripted encounters, and UI state during gameplay.

## Why It Helps

Traditional automated tests are good at pure logic and bad at lived game behavior. Manual testing is good at feel and visuals but slow, inconsistent, and easy to skip. A deterministic scenario harness sits between those extremes.

It gives a small team:

- repeatable gameplay situations
- visible screenshots for human or agent review
- telemetry that explains what happened
- clear pass/fail assertions
- artifacts that can be compared across changes
- a fast loop for fixing regressions

The harness becomes more valuable when coding agents are involved because agents need grounded evidence. Screenshots alone are ambiguous. Logs alone miss visual problems. Telemetry alone misses presentation. Combining all three gives an agent enough context to make useful repairs.

## Recommended Architecture

Use a dedicated Godot script entry point, for example:

```bash
godot --path . -s tests/agent/AgentHarness.gd -- --scenario tests/agent/scenarios/example.json
```

The harness should create one artifact directory per run:

```text
tests/agent/artifacts/<timestamp>_<scenario>/
  harness.log
  run.json
  summary.md
  telemetry.jsonl
  captures.json
  screenshots/
    001_initial_state.png
    002_after_action.png
```

The most important pieces are:

- `AgentHarness.gd`: parses CLI arguments, loads and validates the scenario, creates artifact directories, writes final reports, and exits with a meaningful status code.
- `ScenarioRunner.gd`: loads the scene, applies seed and time scale, executes timed steps, records telemetry, captures screenshots, runs assertions, and restores engine settings.
- `InputDriver.gd`: maps semantic scenario actions to game input overrides.
- `ScreenshotRecorder.gd`: captures sparse screenshots and records metadata.
- `TelemetryRecorder.gd`: writes machine-readable world state.
- `AssertionEngine.gd`: evaluates simple scenario assertions.
- `ScenarioValidator.gd`: fails early when generated scenario JSON is malformed.

## Semantic Actions

Prefer semantic actions over raw input simulation. For example:

```json
{
  "t": 0.3,
  "action": "tap_input",
  "input": "drone",
  "duration": 0.08
}
```

This is more stable than simulating keyboard events. It also makes scenarios easier for agents to write and easier for developers to read.

Useful initial actions include:

- `spawn_player`
- `spawn_enemy`
- `move_to`
- `move_vector`
- `aim_at`
- `hold_input`
- `tap_input`
- `capture`
- `assert`
- `wait`

## Test Arena

Use a dedicated arena scene, but make it faithful to the real game. It should reuse the actual player scene, enemy scenes, UI, camera settings, tile layers, collision layers, and world methods that gameplay code expects.

Avoid making the arena a fake debug world. If the real game uses a HUD, post-processing overlay, floor renderer, or procedural room dimensions, the arena should mirror those patterns closely enough that screenshots remain meaningful.

## Artifact Indexing

Screenshots should be indexed explicitly. A useful `captures.json` entry looks like:

```json
{
  "label": "hunter_tracking_drone",
  "file": "screenshots/003_hunter_tracking_drone.png",
  "time_msec": 3494,
  "enemy_count": 1,
  "drone_count": 1,
  "search": {
    "active": true,
    "reason": "SEARCH: DRONE",
    "target": [323.25, 120.0]
  },
  "events_since_last_capture": [
    "assert:search_active == true:true"
  ]
}
```

This lets an agent open `run.json` or `captures.json` and know exactly which screenshots correspond to which world state.

## Headless Versus Visible Runs

Headless runs are useful for CI and mechanics assertions, but screenshots may not be available depending on the renderer and platform. Treat headless screenshot skips as acceptable for telemetry-only checks, but use visible or virtual-display runs when visual review matters.

Practical options:

- local visible Godot windows during agent development
- Linux CI with Xvfb or another virtual display
- platform-specific offscreen rendering if your project supports it
- separate screenshot jobs from pure mechanics jobs

## Assertion Strategy

Start with simple named assertions rather than a full expression language. Examples:

- `enemy_count == 0`
- `player_alive == true`
- `player_cover_active == true`
- `enemy_distance_to_player(enemy_1) >= 30`
- `enemy_distance_to_search_target(enemy_1) < 90`
- `enemy_alerting(enemy_1) == true`
- `screenshot_count >= 2`

This keeps the harness understandable. Add a richer parser only when the simple format becomes a real limitation.

## Example Scenario

```json
{
  "scenario": "cover_blocks_enemy_overlap",
  "scene": "res://src/world/AgentTestArena.tscn",
  "seed": 2468,
  "duration": 3.2,
  "screenshots": {
    "max": 8,
    "capture_on_failure": true
  },
  "assertions": [
    {
      "condition": "player_cover_active == true",
      "message": "Player cover should still be active during the patrol crossing"
    },
    {
      "condition": "enemy_distance_to_player(enemy_1) >= 30",
      "message": "Enemy should not overlap the covered player"
    }
  ],
  "steps": [
    {
      "t": 0.0,
      "action": "spawn_player",
      "id": "player",
      "at": [280, 210]
    },
    {
      "t": 0.08,
      "action": "tap_input",
      "input": "cover",
      "duration": 0.08
    },
    {
      "t": 0.2,
      "action": "spawn_enemy",
      "type": "Sweeper",
      "id": "enemy_1",
      "at": [160, 210],
      "patrol_points": [[160, 210], [400, 210]],
      "patrol_start_index": 1
    },
    {
      "t": 2.15,
      "action": "capture",
      "name": "cover_patrol_crossing"
    },
    {
      "t": 2.18,
      "action": "assert",
      "condition": "enemy_distance_to_player(enemy_1) >= 30",
      "message": "Enemy body should be blocked instead of passing through"
    }
  ]
}
```

## Takeaway

An indie-scale harness does not need to be large to be valuable. The useful version is small, deterministic, artifact-driven, and close to the actual game runtime. Once it exists, every new mechanic can ship with a scenario that proves the behavior still works.

