# Signal Dark Agent Testing Harness Usage

This project has an agent-driven Godot gameplay harness under `tests/agent/`.

Use it when changing gameplay mechanics, enemy behavior, player actions, stealth/search/cover systems, projectiles, or anything that benefits from deterministic playthrough evidence.

## Primary Command

Run a scenario with a visible Godot window:

```bash
./tests/agent/run_scenario.sh tests/agent/scenarios/hunter_basic_attack.json
```

Run mechanics-only without screenshot files:

```bash
./tests/agent/run_scenario.sh --headless tests/agent/scenarios/hunter_basic_attack.json
```

Headless mode is useful for assertions and telemetry. Visible mode is required when you need PNG screenshots.

## Current Scenarios

```bash
./tests/agent/run_scenario.sh tests/agent/scenarios/hunter_basic_attack.json
./tests/agent/run_scenario.sh tests/agent/scenarios/drone_search_attention.json
./tests/agent/run_scenario.sh tests/agent/scenarios/cover_blocks_enemy_overlap.json
./tests/agent/run_scenario.sh tests/agent/scenarios/dark_pocket_blocks_sweeper_overlap.json
```

## Important Sandbox Note

On this macOS setup, Godot headless may crash inside the filesystem sandbox while trying to write its user log files. If a headless command fails before harness logs appear, rerun the Godot command outside the sandbox with approval.

Known-good direct form:

```bash
godot --headless --path . -s tests/agent/AgentHarness.gd -- --scenario tests/agent/scenarios/hunter_basic_attack.json
```

Visible runs generally work through the runner script and produce screenshot files.

## Artifact Output

Each run writes:

```text
tests/agent/artifacts/<timestamp>_<scenario>/
  harness.log
  run.json
  summary.md
  telemetry.jsonl
  captures.json
  screenshots/
```

Use these files as follows:

- `harness.log`: step-by-step execution log with timestamps.
- `run.json`: final machine-readable result, assertions, failures, and embedded capture index.
- `summary.md`: short human-readable result.
- `telemetry.jsonl`: one JSON object per capture, with player/enemy/drone/search state.
- `captures.json`: screenshot/capture index paired with telemetry summary.
- `screenshots/*.png`: sparse screenshots from visible runs. In headless runs captures are marked `skipped` and `file` is empty.

## Scenario Format

Scenarios are JSON files:

```json
{
  "scenario": "example_name",
  "scene": "res://src/world/AgentTestArena.tscn",
  "seed": 1234,
  "time_scale": 1.0,
  "duration": 3.5,
  "screenshots": {
    "interval_seconds": 0.0,
    "max": 8,
    "capture_on_failure": true
  },
  "steps": [],
  "assertions": []
}
```

The harness validates scenarios before running. Bad JSON or malformed steps fail early.

## Supported Actions

Use semantic actions instead of raw keyboard/mouse automation:

- `spawn_player`
- `spawn_dark_pocket`
- `spawn_enemy`
- `move_to`
- `move_vector`
- `aim_at`
- `hold_input`
- `tap_input`
- `wait`
- `capture`
- `assert`

Example:

```json
{
  "t": 0.3,
  "action": "tap_input",
  "input": "drone",
  "duration": 0.08
}
```

## Spawn Examples

Spawn player:

```json
{
  "t": 0.0,
  "action": "spawn_player",
  "id": "player",
  "at": [120, 120]
}
```

Spawn enemy:

```json
{
  "t": 0.2,
  "action": "spawn_enemy",
  "type": "Hunter",
  "id": "enemy_1",
  "at": [420, 120]
}
```

Spawn a real hideout/dark pocket:

```json
{
  "t": 0.0,
  "action": "spawn_dark_pocket",
  "id": "hideout_1",
  "at": [280, 210]
}
```

Spawn Sweeper with a patrol route:

```json
{
  "t": 0.2,
  "action": "spawn_enemy",
  "type": "Sweeper",
  "id": "enemy_1",
  "at": [160, 210],
  "patrol_points": [[160, 210], [400, 210]],
  "patrol_start_index": 1
}
```

Supported enemy `type` values currently include:

- `Hunter`
- `Sweeper`
- `Sentry`
- `Wisp`
- `Prism`
- `Pulsar`
- `WarpMine`

## Assertion Examples

Assertions use simple expressions:

```json
{
  "condition": "enemy_count == 0",
  "message": "Enemy should be destroyed"
}
```

Useful assertion tokens:

- `enemy_count`
- `drone_count`
- `screenshot_count`
- `search_active`
- `player_alive`
- `player_dark_mode`
- `player_in_dark_pocket`
- `player_blocks_enemies`
- `player_cover_active`
- `cover_active`
- `player_position.x`
- `player_position.y`
- `scene_loaded`
- `player_inside_bounds`
- `target_exists(enemy_1)`
- `target_destroyed(enemy_1)`
- `enemy_alerting(enemy_1)`
- `enemy_health(enemy_1)`
- `enemy_distance_to_player(enemy_1)`
- `enemy_distance_to_search_target(enemy_1)`

Supported comparison operators:

- `==`
- `!=`
- `>`
- `>=`
- `<`
- `<=`

## Writing A New Scenario

Recommended workflow:

1. Copy an existing scenario from `tests/agent/scenarios/`.
2. Give it a unique `scenario` name.
3. Keep `scene` as `res://src/world/AgentTestArena.tscn` unless you intentionally need another scene.
4. Use fixed spawn positions.
5. Add explicit `capture` steps at important moments.
6. Add one or two behavioral assertions at the exact moment the behavior should be true.
7. Add final assertions under top-level `assertions`.
8. Run visible once if screenshots matter.
9. Run headless/direct for fast mechanics verification.

## Current Design Notes

`AgentTestArena` is a controlled test scene that mirrors arcade-style runtime assumptions:

- real `Ship.tscn`
- real enemy scenes
- real `FloorLayer`
- real `LatticeWall`
- real `StealthOverlay`
- real `HUD`
- arcade-like room dimensions and camera zoom
- minimal world methods required by search, line-of-sight, and enemy behavior

Do not replace it with a fake debug-only scene unless the test is purely logical. The goal is deterministic control while staying close enough to actual gameplay rendering and collision behavior.

## What To Check After Running

Always inspect:

```text
run.json
harness.log
captures.json
telemetry.jsonl
```

For visible runs, also inspect relevant screenshots under:

```text
screenshots/
```

If a scenario fails, read `harness.log` first, then compare the failed assertion in `run.json` with the matching capture entry in `captures.json`.
