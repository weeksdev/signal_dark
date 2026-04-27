# Test Obligations

Last updated: 2026-04-25

## Rule

Every meaningful system change should have one of:

- a repeatable smoke test
- a deterministic invariant test
- an explicit deferred-risk note

## Current Priority Obligations

- controls: every prompted action can be performed exactly as documented
- stealth readability: player can identify safe, suspicious, and detected states quickly
- arcade determinism: same seed and difficulty reproduce the same structure
- floor validity: generated floors always contain valid progression
- placements: enemies, gates, and dark pockets do not spawn in broken locations

## Desired Automated Checks

- same seed produces same graph/layout
- different seeds produce meaningfully different layouts
- spawn and exit always exist
- world bounds and camera bounds are valid
- mandatory progression is not unfairly blocked
- story zones load headlessly

## Smoke Commands

Current baseline:

```bash
godot --headless --path . --scene res://src/ui/StartScreen.tscn --quit
godot --headless --path . --scene res://src/world/World.tscn --quit
godot --headless --path . --scene res://src/world/ArcadeWorld.tscn --quit
```

## Current Reality

These smoke commands are already being used repeatedly during development.

Current caveat:

- scene loads pass, but headless shutdown still emits resource/object leak warnings related to active audio players

That means:

- scene parse/load regressions are being caught
- shutdown cleanliness is not fully solved yet

## Next Test Pass

- add a single documented command for invariant tests
- add deterministic seed checks for arcade generation
- add placement validity checks for doors, dark pockets, and enemy spawns
