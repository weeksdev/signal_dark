# Phase 03 - Enemy Structure

## Purpose

Give enemies density, threat, and class identity.

Enemies should no longer feel like alternate line icons. They need weight, hostility, and clear taxonomy while still respecting stealth readability.

## Primary Files Likely Involved

- enemy scene files
- enemy draw scripts
- reveal/visibility logic if readability changes expose edge cases

## Deliverables

- distinct body language per enemy family
- stronger threat read
- consistent visibility behavior
- snapshot review batch
- checkpoint commit

## Microscopic Tasks

### 03.1 Family Audit

- list every active enemy type
- define role:
  - hunter
  - watcher
  - unstable signal threat
  - mine/trap
- define expected visual behavior for each

### 03.2 Base Enemy Mass Pass

- add body fill or shell structure
- add internal features that imply machinery or threat
- distinguish alert state from idle state

### 03.3 Wisp Identity Pass

- remove hollow-placeholder feeling
- give wisps a unique unstable structure
- ensure they do not cheat visibility rules unless explicitly designed to

### 03.4 Threat Emission Pass

- define hot points:
  - sensors
  - weapon nodes
  - phase cores
- ensure threat glow supports detection, not confusion

### 03.5 Distance Read Pass

- verify enemy classes remain readable at the current zoom
- verify silhouette survives CRT and darkness
- verify danger does not rely on color alone

### 03.6 Visibility Rule Pass

- verify enemies outside the ship visibility window obey the same visibility contract
- verify no class leaks through by exception unless deliberately designed

## Snapshot Gate

Capture frames containing:

- one or more base enemies
- one or more wisps
- mixed enemy + objective framing

Review questions:

- do enemies feel heavier and more dangerous
- are classes distinguishable without UI help
- do any enemies break the visibility contract

## Acceptance Criteria

- enemy families feel intentionally designed
- enemy mass improves threat without clutter
- no hollow glyph enemy remains unless that is the explicit fantasy

## Commit Gate

Checkpoint commit required before contact-shadow work begins.
