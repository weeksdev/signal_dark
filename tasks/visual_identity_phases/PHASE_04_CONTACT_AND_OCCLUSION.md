# Phase 04 - Contact And Occlusion

## Purpose

Add the subtle depth cues that make things feel anchored to the world.

This phase should create weight through contact and value relationships, not through noisy decoration.

## Primary Files Likely Involved

- player/enemy draw scripts
- environment scripts
- shader or overlay scripts if shadow handling is post-processed

## Deliverables

- actor contact shadows or occlusion pools
- wall-to-floor grounding
- clearer actor/world attachment
- snapshot review batch
- checkpoint commit

## Microscopic Tasks

### 04.1 Player Contact Shadow Pass

- add faint shadow/occlusion under the ship
- verify it reads under stealth darkness
- keep it subtle enough not to become a gameplay circle

### 04.2 Enemy Contact Shadow Pass

- add matching grounding under enemies
- vary intensity by class if needed
- ensure it increases threat weight rather than clutter

### 04.3 Wall Base Occlusion Pass

- darken immediate floor contact near walls
- improve threshold depth at corridors and doors
- reinforce heavy architecture feel

### 04.4 Objective / Interactable Grounding Pass

- ensure objectives feel physically present
- prevent important interactables from floating visually

### 04.5 Readability Check

- confirm shadows do not create false hitboxes
- confirm they do not blend with stealth visibility boundaries

## Snapshot Gate

Capture:

- ship near walls
- enemy near walls
- objective/interactable near walls

Review questions:

- do actors feel attached to the space now
- do walls feel embedded into the floor plane
- did grounding improve mass without adding muddiness

## Acceptance Criteria

- floating geometry feeling is reduced
- actors and structures feel planted
- no new gameplay ambiguity is introduced

## Commit Gate

Checkpoint commit required before final integration polish.
