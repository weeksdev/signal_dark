# MGS-Style Gameplay Gaps

This document tracks the remaining gaps between `Signal Dark` and the kind of stealth texture that makes classic `Metal Gear Solid` feel readable, tense, and fair.

The goal is not to copy MGS literally. The goal is to identify the missing gameplay fundamentals that create:
- observation
- planning
- timing windows
- improvisation
- recovery after mistakes

Several of the items below are partially implemented already. This list is about what still needs to feel stronger, cleaner, or more intentional.

## 1. Patrol Language

Current gap:
- Some enemies still feel like movers in a room instead of guards with authored routines.
- The player cannot always read a room and say, "wait for that opening."

Needed:
- fixed patrol paths
- clear turn points
- dwell timing at patrol nodes
- synchronized overlaps
- predictable separation windows
- room patterns built around those paths

Arcade target:
- `Sweeper`: 2-point or 3-point patrol routes
- `Wisp`: fixed orbit anchors, not loose drift
- `Hunter`: short pressure loops or perch-to-perch routes
- `Prism` / `Pulsar`: area-denial timing pieces rather than general roamers

High-value room patterns:
- crossing patrols
- staggered parallel sweeps
- alternating chokepoint coverage
- guard + scanner overlap
- branch bait route with one safe timing lane

Success condition:
- the player can watch for a few seconds, identify a pattern, and commit through a timing window

## 2. Investigation / Search State

Current gap:
- Detection is better than before, but enemy follow-up still needs to feel more like a search operation and less like a mode flip.

Needed:
- enemy moves to last known position
- short sweep/search pattern
- elevated caution window
- gradual return to patrol if the player stays hidden
- stronger separation between `noticed something` and `full combat failure`

Desired feel:
- the player makes a mistake
- enemies investigate the disturbance
- the player can evade, reposition, or re-enter stealth

Success condition:
- being noticed is dangerous but not automatically a failed run

## 3. Stronger Stealth Verbs

Current gap:
- The game has dark mode, probe, suppress, jammer, hiding spots, and gate hacks.
- The verbs exist, but the toolset still needs to become more legible and more strategically distinct.

Needed:
- each stealth tool should solve a different problem
- tools should interact with patrol timing, not just create noise
- the player should be able to shape the room before committing

Recommended direction:
- `Probe`: lure or redirect patrol attention
- `Jammer`: break a local detection setup and create a recovery window
- `Suppress`: precision close-range removal tool
- `Hack`: controlled risk tradeoff, not just mandatory friction

Possible future tools:
- temporary vision disruptor
- false signal burst
- route lock / unlock
- one-time corridor blackout

Success condition:
- the player can plan an approach with tools instead of only relying on movement skill

## 4. Consequences Short of Failure

Current gap:
- The game still leans too much on `stealth vs combat` as the only consequence ladder.

Needed:
- local penalties that raise pressure without ending the run
- alert consequences that change room texture for a short period

Examples:
- local lockdown
- temporary scanner reinforcement
- route tightening
- harder gate interaction
- patrol density spike in nearby lanes
- branch room becomes unsafe for a short time

Success condition:
- mistakes cost something meaningful even if the player avoids full combat

## 5. Space With Intent

Current gap:
- Arcade structure is better than a straight hallway, but many rooms still do not feel authored around stealth choices.

Needed:
- more route intent in room generation
- alternate lanes through danger
- edge-safe movement options
- baited high-risk rooms
- rooms built around enemy interplay instead of just enemy count

What to improve:
- chokepoints with passing windows
- side lanes that trade distance for safety
- dead-end reward rooms with escape pressure
- optional branch tasks that are worth the risk
- clearer geometry for hide, wait, move, and cross

Success condition:
- rooms generate stealth stories on their own

## 6. Recovery Fantasy

Current gap:
- The player can recover better than before, but that recovery loop still needs to become more satisfying and deliberate.

Needed:
- break-contact tools
- search shedding
- stealth re-entry routes
- local reset opportunities
- more reliable ways to salvage a bad situation

Desired feel:
- the player gets into trouble
- breaks line of sight
- uses space or a tool correctly
- returns to stealth instead of brute-forcing combat

Success condition:
- recovery is a core skill, not an edge case

## 7. Objective Variety

Current gap:
- Arcade now has objective nodes, but the objective layer still needs expansion beyond the current floor-task format.

Needed:
- more mission types than `reach exit`
- objective structure that changes movement decisions
- objectives that interact with stealth planning

Good mission types:
- steal key
- link relay
- disable scanner node
- collect intel
- hack 2 of 3 terminals
- survive a timed sweep
- cross an area without alert

Success condition:
- the player’s route depends on the mission, not only the map layout

## 8. Feedback Clarity

Current gap:
- Sound is deferred for now, but visual and state feedback still needs to be stronger and cleaner in some places.

Needed:
- clearer partial-detection feedback
- stronger room-level objective direction
- cleaner distinction between danger, search, caution, and combat
- better explanation of what the player is trying to do at any given moment

Visual priorities:
- objective beacons
- threat ownership zones
- readable patrol arcs and paths
- search-state emphasis
- route readability under stealth darkness

Success condition:
- the player understands what is happening and what they should do next without guessing

## 9. Enemy Identity Separation

Current gap:
- Enemy silhouettes are distinct, but their behavior roles still need more contrast.

Needed:
- each enemy should punish a different bad habit
- each enemy should create a different planning problem

Examples:
- `Sweeper`: timed lane control
- `Pulsar`: range and pulse timing
- `Prism`: beam denial and angle management
- `Sentry`: static pressure and line punishment
- `Wisp`: local proximity ownership and map preview pressure
- `Hunter`: pursuit and collapse pressure
- `WarpMine`: trap and room contamination

Success condition:
- mixed encounters feel layered, not just more crowded

## 10. Arcade Encounter Templates

Current gap:
- Arcade still relies too much on enemy placement and not enough on authored encounter logic.

Needed:
- reusable encounter templates
- patrol anchor sets
- pattern-based composition
- difficulty scaling through behavior and route design, not just counts

Template examples:
- crossing scanners
- moving gap corridor
- objective behind alternating patrols
- safe branch with delayed collapse
- central choke with optional flank route

Success condition:
- arcade runs feel intentionally designed even though they are procedural

## Recommended Priority Order

If the next goal is `make arcade mode truly playable and fun`, the highest-value work order is:

1. Patrol language and path definition
2. Encounter templates and room timing windows
3. Stronger investigation/search behavior
4. Better route-authored geometry in arcade generation
5. Objective variety expansion
6. Recovery loop tuning
7. Tool differentiation polish
8. Feedback and sound pass

## Immediate Next Tasks

Concrete next implementation steps:

1. Replace loose roaming with defined anchor paths for `Wisp`, `Hunter`, and more arcade `Sweeper` setups.
2. Add encounter templates to arcade placement instead of pure spawn distribution.
3. Ensure overlapping patrols create intentional timed gaps through chokepoints.
4. Add at least two more objective variants beyond the current node-link flow.
5. Tune search state so it feels dangerous but escapable.
6. Improve objective routing clarity so targets are never visually or spatially ambiguous.

## Engineering Risks To Address

These are not just code-cleanliness issues. They directly affect stability, iteration speed, and whether the stealth systems stay maintainable as arcade mode grows.

### 1. Scene Coupling Through `get_tree().current_scene`

Current risk:
- several enemies call methods directly on `get_tree().current_scene`
- examples include:
  - `is_line_blocked(...)`
  - `has_active_probe()`
  - `get_probe_target()`
  - `is_search_active()`
  - `is_point_jammed(...)`

Why this matters:
- enemy code now depends on whatever scene happens to be loaded
- scene transitions can break behavior
- missing methods can cause runtime errors or inconsistent fallback behavior
- it makes enemies harder to reuse outside the current world scenes

Better direction:
- introduce a stable `WorldInterface` autoload or a world service reference
- alternatively, register the current world in a single shared place and make enemies query that
- short term: guard every scene-method call consistently

Priority:
- high

### 2. Duplicate Suspicion / Alert State Machines

Current risk:
- `Sweeper`, `Pulsar`, `Prism`, `Wisp`, and related enemies all carry their own versions of:
  - `_alerting`
  - `_alert_hold`
  - `_suspicion`
  - suspicion decay
  - alert trigger timing

Why this matters:
- stealth tuning now requires editing multiple scripts
- it is easy to change one enemy and forget the others
- the behavior will drift over time unintentionally

Better direction:
- move shared suspicion logic into `BaseEnemy`
- or create a reusable suspicion/alert component
- allow per-enemy tuning through parameters rather than copy-pasted logic

Priority:
- high

### 3. Manual Enemy Contact Checks In `Ship.gd`

Current risk:
- `_check_enemy_contact()` loops all `zone_enemy` nodes every physics frame

Why this matters:
- acceptable at low counts
- increasingly wasteful as arcade density rises
- the engine can handle this spatial work better than a manual loop

Better direction:
- use `Area2D` and collision layers for player-enemy contact
- let physics callbacks handle lethal touch

Priority:
- medium

### 4. Copy-Pasted Alert Marker Drawing

Current risk:
- the MGS-style `!` marker is duplicated across multiple enemy `_draw()` methods

Why this matters:
- visual tweaks require editing many files
- timing or styling drift will happen
- platform-specific adjustments become noisy and error-prone

Better direction:
- shared draw helper in `BaseEnemy`
- or a small utility/static draw helper

Priority:
- medium

### 5. `queue_redraw()` On Every Enemy Every Frame

Current risk:
- many enemies redraw every frame whether their visible state changed or not

Why this matters:
- desktop tolerates this better
- iPhone and lower-power targets will not
- this is exactly the kind of silent performance leak that appears late

Better direction:
- redraw only when movement or visual state changes
- keep per-frame redraws only for enemies with active animated elements
- audit which enemies truly need continuous custom drawing

Priority:
- medium-high for iOS/macOS shipping

### 6. Touch UX For Hacking

Current risk:
- the current `A/B/X/Y` face-button style hack sequence fits controller well
- it will likely be awkward on pure touch if layered on top of movement/aim controls

Why this matters:
- touch needs spatial clarity
- stacked live controls will feel cramped and error-prone

Better direction:
- switch into a dedicated hack overlay on touch
- show four large buttons cleanly
- pause or heavily damp normal movement while hacking

Priority:
- high for iOS

## Revised Priority Order

For overall project health, the next work should be balanced between gameplay and architecture:

1. Patrol language and path definition
2. Replace `current_scene` enemy coupling with a stable world interface
3. Centralize suspicion / alert logic
4. Encounter templates and timing-window room patterns
5. Better route-authored geometry in arcade generation
6. Objective variety expansion
7. Recovery loop tuning
8. iOS input/hack overlay pass
9. Performance cleanup for redraw/contact handling
10. Audio and feedback polish

## Definition Of "Good"

Arcade stealth is in a good place when:
- the player can read the room before moving
- multiple enemies create timing puzzles instead of chaos
- mistakes trigger recoverable pressure
- objectives change route choice
- tools create plans, not just panic buttons
- detection feels earned
- success feels like execution, not luck
