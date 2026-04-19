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

What it checks:

- Loads the map scene in Godot.
- Collects every `LatticeWall` collision rectangle.
- Inflates walls by the largest actor collision radius in the scene.
- Flood-fills from actor spawn points and from outside the map.
- Fails if those two reachable regions connect, which means the ship or enemies can escape the maze.
