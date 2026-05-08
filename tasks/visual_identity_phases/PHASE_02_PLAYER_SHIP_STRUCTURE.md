# Phase 02 - Player Ship Structure

## Purpose

Turn the player ship from a mostly open signal glyph into a compact, directional machine with mass.

The ship should still belong to the Matrix-style signal world, but it must feel piloted, engineered, and dangerous.

## Primary Files Likely Involved

- ship scene and draw logic
- player VFX scripts
- stealth overlay interaction if visibility/readability needs tuning

## Deliverables

- stronger player silhouette
- internal body mass
- directional emphasis
- restrained emissive logic
- snapshot review batch
- checkpoint commit

## Microscopic Tasks

### 02.1 Silhouette Lock

- preserve a readable top-down silhouette
- define nose/front direction clearly
- avoid adding decorative shape noise that hurts movement read

### 02.2 Core Body Pass

- add a central body mass
- reduce “empty artifact” feeling
- establish shell vs interior

### 02.3 Structural Frame Pass

- add mid-bright support lines or plating
- ensure frame does not outshine the silhouette
- use asymmetry carefully if needed

### 02.4 Emission Logic Pass

- define where engine glow or signal heat lives
- define cockpit/core node if appropriate
- keep emissions localized rather than flooding the ship

### 02.5 Motion Read Pass

- verify ship heading is readable while moving
- verify ship remains readable under scanlines, grain, and darkness
- verify zoomed-in framing still supports recognition

### 02.6 HUD Relationship Pass

- ensure ship does not visually blend into UI-green overlay language
- preserve player priority over background grid

## Snapshot Gate

Capture:

- ship idle at spawn
- ship in corridor
- ship near interactable/objective

Review questions:

- does the ship feel owned and piloted
- does the ship feel heavier than a hollow marker
- is direction clearer than before

## Acceptance Criteria

- player ship reads as a machine, not a symbol
- ship remains instantly identifiable in stealth darkness
- new structure supports gameplay rather than obscuring it

## Commit Gate

Checkpoint commit required before enemy work begins.
