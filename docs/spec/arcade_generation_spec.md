# Arcade Generation Spec

Last updated: 2026-04-25

## Intent

Arcade mode should be the replayable product core: deterministic where needed, varied between seeds, and readable at the room level.

## Current Implemented Behavior

From `ArcadeState.gd`, `ArcadeWorld.gd`, `ZoneGraphBuilder.gd`, and `EncounterPlacer.gd`:

- arcade runs are 4 floors long
- floor seed is derived from `run_seed * 10000 + floor_index`
- difficulty is one of `Easy`, `Medium`, or `Hardcore`
- floor generation is seeded
- encounter placement is budget-based with authored template bias
- templates currently include:
  - moving corridor gap
  - crossing scanners
  - guard/scanner overlap
  - branch bait
  - setpiece crossfire
- objectives are generated and currently revolve around node-link pickup/activation flow
- exits remain locked until required objective progress is complete

## Current Gaps

- no daily challenge mode yet
- no between-floor upgrade choice yet
- no run-summary screen yet
- no explicit player-facing scoring layer yet
- no broad batch validation harness yet

## Required Properties

- same seed + same difficulty should reproduce the same run structure
- every floor must have a valid path from spawn to exit
- easy should always leave at least one recovery option
- hardcore may be harsh but not structurally unwinnable

## Pressure Model

Rooms should be evaluated by composition, not just enemy count:

- detection coverage
- movement denial
- chase risk
- hack exposure
- dark pocket availability
- exit path complexity

## Encounter Rules

- early floors: fewer stacked systems, cleaner teaching
- mid floors: more overlap, still readable
- late floors: denial + chase + timing pressure can combine, but must preserve a response window

## Current Work

- deterministic seed behavior
- floor validity checks
- room pressure logging or debug output
- safe-lane guarantees on easy

## Implementation Notes

- the generator already uses difficulty to alter graph and encounter pressure
- early corridor pressure and choke readability remain the most sensitive tuning area
- hidden lockdown gates now allow the system to constrain progress even on floors without visible hack gates
