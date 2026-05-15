# Tests

Map boundary leak check:

```bash
godot --headless --path . -s tests/map_boundary_test.gd
```

Run it against a specific scene:

```bash
godot --headless --path . -s tests/map_boundary_test.gd -- res://src/world/World02.tscn
```

Run it against every scene in `src/world/`:

```bash
godot --headless --path . -s tests/map_boundary_test.gd -- --all
```

Gate lock toggle check:

```bash
godot --headless --path . -s tests/gate_lock_test.gd
```

Warp mine payload deployment check:

```bash
godot --headless --path . -s tests/warp_mine_test.gd
```

Agent-driven visible scenario harness:

```bash
./tests/agent/run_scenario.sh tests/agent/scenarios/hunter_basic_attack.json
```

Use `--headless` before the scenario path for mechanics-only verification without screenshot files:

```bash
./tests/agent/run_scenario.sh --headless tests/agent/scenarios/hunter_basic_attack.json
```

Drone attention scenario:

```bash
./tests/agent/run_scenario.sh tests/agent/scenarios/drone_search_attention.json
```

Cover blocks enemy overlap scenario:

```bash
./tests/agent/run_scenario.sh tests/agent/scenarios/cover_blocks_enemy_overlap.json
```

Dark pocket blocks Sweeper overlap scenario:

```bash
./tests/agent/run_scenario.sh tests/agent/scenarios/dark_pocket_blocks_sweeper_overlap.json
```

Artifacts are written to `tests/agent/artifacts/<timestamp>_<scenario>/` with `harness.log`, `run.json`, `summary.md`, `telemetry.jsonl`, `captures.json`, and sparse screenshots.

What it checks:

- Loads the map scene in Godot.
- Collects every `LatticeWall` collision rectangle.
- Inflates walls by the largest actor collision radius in the scene.
- Flood-fills from actor spawn points and from outside the map.
- Fails if those two reachable regions connect, which means the ship or enemies can escape the maze.
- Verifies `GateLock` collision opens on combat and closes after combat.
- Verifies `WarpMine` deploys its payload enemies into the active world and applies close-range blast pressure.
- Verifies deterministic agent scenarios can spawn actors, drive semantic inputs, capture screenshots, write telemetry, and evaluate assertions.
- Verifies cover/hide mode blocks enemy body overlap instead of only suppressing damage.
