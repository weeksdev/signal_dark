# Mobile Surface Plan

Last updated: 2026-04-25

## Intent

`Signal Dark` should support iPhone play without forking the game into a separate mobile edition.

The minimal strategy is:

- keep the same core game
- adapt camera framing for landscape phone play
- add a touch/controller input shell
- scale HUD and prompts for handheld readability
- keep core stealth/combat/world logic unchanged as long as possible

This is an edge-layer adaptation plan, not a gameplay rewrite.

## Product Rule

Mobile should feel like the same game with a different surface:

- same spaces
- same enemies
- same arcade/story structure
- same stealth/combat rules

Only these layers should change first:

- display orientation
- camera framing
- touch input
- prompt layout
- HUD scale and placement

## Target Form

### Device Orientation

Use `landscape` on phone.

Do not target portrait for the first mobile pass.

Reason:

- current game language already reads horizontally
- twin-stick touch layout fits landscape
- objective awareness is better with more lateral view
- controller support maps naturally to landscape

### Camera

The first mobile camera should be a preset, not a new camera system.

Recommended first rule:

- desktop keeps current camera behavior
- mobile landscape uses a slightly wider horizontal framing
- do not redesign rooms or world scale yet

The change should feel like:

- “more horizontal awareness”
- not:
- “zoomed so far out the game becomes tiny”

### HUD

The first mobile HUD pass should:

- increase safe margins
- enlarge critical prompt text
- preserve top-corner status readability
- avoid placing important text under thumbs

Important information should stay readable with touch controls visible.

## Input Plan

### Controller

If a controller is connected on iPhone:

- use controller prompts
- hide touch controls
- preserve normal controller behavior

This is already aligned with the current controller-detection direction in the codebase.

### Touch

First-pass touch layout:

- left thumb: movement stick
- right thumb: aim stick
- right-side contextual action button:
  - hack
  - interact
  - suppress
- separate buttons near screen edges:
  - dark mode
  - boost
  - EMP
  - probe if needed
- pause button in a safe upper corner

The touch plan should prefer:

- one large contextual action
- a few dedicated ability buttons

It should avoid:

- too many small buttons
- duplicated actions
- forcing the player to read tiny button labels during combat

## Hack Interaction Rule

Pure touch hack input should not simply mirror the current keyboard/controller sequence UI.

For touch, the likely correct first version is:

- dedicated temporary hack overlay
- large buttons
- clear sequence visibility

Controller and keyboard can keep the current approach.

This should be treated as a separate touch-surface pass, not blocked on the first mobile build.

## Minimal Implementation Order

1. Add iOS export preset and local device build path.
2. Lock phone presentation to landscape.
3. Add a mobile camera preset.
4. Add a touch control overlay.
5. Hide touch controls when controller is present.
6. Scale HUD/prompts for mobile readability.
7. Run phone playtests with and without controller.

## What Not To Do First

Do not:

- build separate mobile maps
- redesign enemy behavior for phone
- add mobile-only mechanics
- attempt true 3D corridor mode for phone
- optimize every safe-area/notch detail before basic control feel is proven

## Local iPhone Build Path

Current repo status:

- there is no `export_presets.cfg` yet
- mobile build setup still needs to be added

### Required Local Tooling

To test on an iPhone locally, use:

- macOS
- Xcode installed
- a connected iPhone
- an Apple developer signing identity
- Godot 4.5 export templates installed

### First Build Flow

1. Install Godot iOS export templates for the exact engine version in use.
2. Add an `iOS` export preset in Godot.
3. Set landscape orientation in the iOS export/project settings.
4. Generate the Xcode project from Godot export.
5. Open the generated Xcode project.
6. Set your signing team and bundle identifier.
7. Select the connected iPhone as the target.
8. Build and run from Xcode.

### Minimal Repo Additions Needed

To make this repeatable, the repo should eventually gain:

- `export_presets.cfg`
- one documented iOS bundle id placeholder
- a short `docs/ios_local_build.md` or equivalent

Optional later:

- one helper script to export/open the Xcode project

### Recommended First Preset Behavior

The first iPhone build should:

- run story and arcade without feature differences
- default to landscape
- keep existing mobile renderer choice
- use touch if no controller is attached
- switch to controller prompts automatically when controller is attached

## Verification Plan

### Phone Without Controller

Verify:

- landscape presentation feels natural
- ship can move and aim reliably
- contextual action button is readable and reachable
- HUD remains readable under thumbs
- stealth/combat readability survives the smaller screen

### Phone With Controller

Verify:

- touch controls hide automatically
- controller prompts appear correctly
- hack prompts use controller labeling
- camera framing still feels right on phone landscape

### Non-Goals For First Pass

Do not block the first mobile test on:

- perfect touch combat balance
- final hack overlay design
- final mobile HUD polish
- App Store packaging

The first goal is simple:

> prove the same game is playable on iPhone in landscape, with and without controller

## Current Status

Not implemented.

No iOS export preset is currently committed in the repo.
