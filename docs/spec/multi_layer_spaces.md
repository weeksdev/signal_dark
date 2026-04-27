# Multi-Layer Spaces

Last updated: 2026-04-25

## Intent

`Signal Dark` can support discrete multi-layer infiltration spaces as a future extension of its stealth language.

This is not a novelty feature. It is established stealth design: the player reads space vertically as well as horizontally, uses lower routes to bypass pressure above, and treats stairs, ramps, shafts, or elevators as exposed transition points.

The goal is not freeform 3D movement. The goal is a readable second layer that deepens infiltration, route planning, and enemy coverage.

## Design Rule

Multi-layer spaces should behave like **stacked stealth planes**, not like a genre switch.

That means:

- the player moves on one active layer at a time
- transitions are discrete and intentional
- the inactive layer remains visible as ghosted context
- enemies, objectives, and routes stay legible during transitions

## Player Fantasy

“Above me, the system is still running. Below me, I have a tighter route through its structure.”

The player should feel like they are slipping underneath surveillance, not loading into a separate map.

## Why This Fits Signal Dark

This supports the game’s core identity:

- stronger infiltration fantasy
- more meaningful route planning
- new stealth choices without adding raw weapon complexity
- denser spaces without requiring larger maps
- more authored pressure around entrances, exits, and sensor coverage

It also fits the existing look:

- blurred ghost geometry above
- active layer emphasized with stronger focus and contrast
- transition zoom/ease can sell vertical movement without true 3D

## Recommended Form

Use **two discrete layers** first:

- `upper layer`
- `lower layer`

Do not start with:

- free vertical aiming
- jump/fall systems
- full 3D corridor driving
- arbitrary multi-floor stacks

The first version should be:

- top-down on both layers
- camera eases/zooms during transition
- inactive layer stays faint and blurred
- transition points are fixed and authored

## Transition Types

Good entry/exit forms:

- maintenance ramps
- freight lifts
- drop shafts
- hatch access points
- stairwells

Each transition should create a small tactical commitment:

- visible approach lane
- short vulnerability window
- predictable arrival point

## Visual Rule

The player must never lose spatial orientation.

When moving between layers:

- current layer stays crisp
- inactive layer remains visible but dim and blurred
- transition destination is obvious before committing
- entrances/exits read as high-value points in room layout

The player should think:

- “I know where I am relative to the upper floor”
- not:
- “I loaded into a different room and got disoriented”

## Enemy Design Implications

Multi-layer spaces are only worth adding if enemy behavior stays readable.

Useful rules:

- some enemies are layer-bound
- some enemies only monitor transition points
- some enemies can pressure both layers indirectly
- very few enemies should traverse layers freely

Examples:

- `Sweeper`: patrols one layer only
- `Sentry`: can lock a ramp or shaft entrance
- `Prism`: controls a lane on one layer, forcing a descent
- `Wisp`: good lower-layer pressure if tuned carefully
- `Hunter`: dangerous only if clearly signposted as able to traverse layers

The main design opportunity is **pressure asymmetry**:

- upper layer is safer visually but more surveilled
- lower layer is tighter, darker, and better for bypassing

## Objective Design Implications

Multi-layer spaces become valuable when objectives use them deliberately.

Good uses:

- uplink is on one layer, exit path is on another
- scanner control node is below, guarded route is above
- player can choose a slower hidden under-route or a faster exposed upper route
- one layer contains escape/hide infrastructure, the other contains objective access

Bad uses:

- mandatory layer switching with no tactical decision
- hiding critical objectives where the player cannot infer they exist
- forcing constant transitions every room

## Arcade Mode Use

This is best introduced in arcade as **rare authored encounter types**, not as the new baseline for every floor.

Good first use:

- occasional setpiece room
- one lower bypass under a guarded corridor
- one transition-heavy room late in the run

Bad first use:

- every floor requires layer switching
- generator treats layers as just more random geometry

Arcade should learn this through templates, not full procedural freedom.

## Technical Scope Rule

This is a future feature because it multiplies system complexity:

- pathing
- search routing
- patrol generation
- reinforcement logic
- lockdown logic
- objective placement
- line-of-sight readability
- hiding rules

That means it should only begin after:

1. one-layer stealth/combat is stable
2. arcade templates are more authored and reliable
3. objectives and scoring are settled

## First Implementation Slice

If this is built later, the first slice should be narrow:

1. One authored story-space room with one upper and one lower layer.
2. One transition type.
3. No enemy free-traversal between layers except by clear authored rule.
4. One objective that benefits from using the lower route.
5. Blur/ghost visualization for inactive layer.

If that feels good, then add:

- one arcade setpiece
- one enemy interaction specialized around transition control

## Acceptance Criteria

The first shipped multi-layer room should prove:

- the player understands where they are after every transition
- the inactive layer remains readable but not noisy
- the lower route creates a meaningful stealth decision
- enemies do not become confusing across layers
- the feature feels like infiltration depth, not map gimmickry

## Current Status

Not implemented.

This is a documented future direction, not an active near-term milestone.
