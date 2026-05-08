# Phase 01 - Ground And Wall Mass

## Purpose

Make the environment feel built and substantial before adding complexity to actors.

The floor must become a substrate.
The walls must become volume.
The grid must become a projected information layer rather than the world itself.

## Primary Files Likely Involved

- `src/world/Grid.gd`
- world scene files and wall visuals
- `src/fx/ColorSystem.gd`
- any environment-specific visual scripts or nodes discovered during implementation

## Deliverables

- darker, more physical floor plane
- thicker wall read with body + edge hierarchy
- preserved gameplay navigation readability
- snapshot review batch
- checkpoint commit

## Microscopic Tasks

### 01.1 Floor Substrate Pass

- define floor base tone below the grid
- add floor panel rhythm or machine seams
- add low-contrast regional variation
- ensure floor detail does not compete with actors

### 01.2 Grid Separation Pass

- confirm grid is visually distinct from floor body
- ensure grid looks projected, energized, or signal-derived
- reduce cases where the grid is mistaken for wall structure

### 01.3 Wall Mass Pass

- add wall interior fill/body value
- add structural edge treatment
- distinguish lit edge from shadow edge
- make door frames and openings feel cut into mass

### 01.4 Corner And Junction Pass

- improve room corners so they read as constructed joins
- improve corridor thresholds so they read as spatial barriers
- improve trench/channel/industrial interruptions if available

### 01.5 Regional Contrast Pass

- verify important rooms feel intentionally denser or emptier
- avoid one uniform wallpaper treatment across the whole map

### 01.6 Readability Regression Check

- verify the ship remains readable against the new floor
- verify enemies do not disappear into wall mass
- verify pathing is still understandable under stealth darkness

## Snapshot Gate

Capture:

- `story_world_spawn`
- `story_world_corridor`
- `story_world_next_room`

Review questions:

- do walls feel like infrastructure now
- does the floor feel separate from the grid
- does the map feel more like a facility than a schematic

## Acceptance Criteria

- environment reads as solid world geometry
- grid no longer carries the entire burden of world readability
- empty rooms feel intentional, not unfinished

## Commit Gate

Do not proceed to ship work until:

- environment pass is snapshot-verified
- a checkpoint commit is made
