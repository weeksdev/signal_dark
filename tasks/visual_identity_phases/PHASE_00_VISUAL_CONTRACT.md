# Phase 00 - Visual Contract

## Purpose

Define the visual rules before creating new detail. This phase prevents random decoration and keeps all later passes aligned to the game pillar:

**Top down shooter. Metal Gear Solid mechanics. Matrix style visuals.**

## Deliverables

- written classification of visual layers
- written material language for player, enemies, walls, floor, UI overlays
- screenshot baseline set for comparison
- checkpoint commit

## Microscopic Tasks

### 00.1 Baseline Snapshot Capture

- capture a fresh story review batch
- archive the output directory name in notes or commit message
- identify three representative frames:
  - spawn
  - combat-adjacent corridor
  - next-room traversal

### 00.2 Value Hierarchy Definition

- define darkest layer
- define mid-dark structural layer
- define gameplay-readable layer
- define hot signal/emissive layer
- define forbidden overlaps:
  - floor and ship cannot share the same visual priority
  - enemies and objectives cannot use the same brightness logic

### 00.3 Material Language Definition

- player ship:
  - directional
  - engineered
  - controlled
  - compact
- baseline enemies:
  - predatory
  - heavier than current outlines
  - readable at a glance
- wisps:
  - unstable
  - signal-distorted
  - not generic circles or empty diamonds
- walls:
  - industrial mass
  - hard edges
  - built environment, not drawn graph paper
- floor:
  - substrate for signal projection
  - not the same thing as the grid

### 00.4 Shape Hierarchy Definition

- define primary silhouette for ship
- define primary silhouettes for each enemy family
- define secondary structure rules:
  - core
  - shell
  - frame
  - emission points
- define negative space usage rules

### 00.5 Failure Conditions

- if any entity still reads as a hollow UI icon, this phase is not ready to advance
- if walls still read as pure linework, this phase is not ready to advance
- if the planned look drifts away from stealth-surveillance / signal-field identity, stop

## Snapshot Gate

Required:

- baseline review batch generated
- three screenshots selected for repeated future comparison

## Acceptance Criteria

- visual hierarchy is written clearly enough that future phases can be judged objectively
- the mission statement is explicitly referenced in the phase notes
- the team can say what should be solid, hollow, emissive, infrastructural, and decorative

## Commit Gate

Commit only planning and note updates for this phase if any files were changed.
