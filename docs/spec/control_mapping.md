# Control Mapping

Last updated: 2026-04-25

## Intent

All player-facing prompts, docs, and bindings should describe the same control scheme.

## Current Implemented Mapping

From `project.godot` and `InputManager.gd`:

- `WASD`: move
- `Left Shift`: dark mode
- `Space`: boost
- `Left Mouse`: fire
- `Q`: probe
- `E`: suppress
- `F` or `Right Mouse`: hack / interact
- `J / K / U / I`: hack sequence buttons when no controller is present
- `C`: EMP
- `R`: restart / reroll where applicable
- `Esc` / `P`: pause in-game

Current controller behavior:

- left stick: move
- right stick: aim
- left trigger: dark mode
- right trigger: boost
- right shoulder: fire
- `A`: suppress
- `X`: probe
- `Y`: hack / interact
- hack sequence buttons use controller face buttons `A/B/X/Y`
- `Start`: pause / confirm in some menus

## Current Menu Behavior

Title screen:

- `Up/Down` or `W/S`: move between `PLAY` and `SETTINGS`
- `Enter` / `Space`: confirm
- `Tab`: switch root menu selection
- arcade mode:
  - `Left/Right`: difficulty
  - `R`: reroll seed
- `I`: enemy info screen

Settings menu:

- `Up/Down`: select setting
- `Left/Right`: change value
- current settings:
  - auto fire mode
  - music volume
  - FX volume

## Target Desktop Mapping

- `WASD`: move
- `Mouse`: aim
- `Left Mouse`: fire
- `Space`: boost
- `Left Shift`: dark mode
- `Q`: probe
- `E`: suppress / contextual stealth takedown
- `F` or `Right Mouse`: hack / interact
- `R`: restart or reroll where applicable
- `Esc` / `P`: pause

## Target Controller Semantics

- left stick: move
- right stick: aim
- face button fire/hack semantics should mirror desktop action meanings
- pause and settings navigation should be fully controller-usable

## Acceptance Criteria

- `project.godot` input map matches prompts
- title screen hints match actual controls
- HUD and tutorial prompts match actual controls
- README and in-game help match actual controls

## Current Inconsistencies / Work
- README and title screen were normalized on 2026-04-25 to match the actual input map
- verify in-game contextual prompts still match `E` suppress and `F/RMB` hack behavior everywhere
- decide whether `Tab` should remain part of title navigation or be removed for clarity
