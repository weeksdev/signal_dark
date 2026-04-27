# Signal Dark Spec

Last updated: 2026-04-25

## Intent

`Signal Dark` should feel like stealth survival inside a hostile machine, not like a content-maximal action prototype.

## Player-Facing Rule

The player is safest when unreadable:

- darkness lowers exposure
- movement and aggression increase exposure
- short combat is survivable but costly
- hiding, misdirection, and route reading are the optimal answers

## Current Product Shape

- top-down stealth-action
- short authored story spaces
- seeded arcade runs as the replayable core
- stealth-first scoring and recovery-driven combat

## Current Implemented Shape

What exists in the repo today:

- story mode plus seeded arcade mode
- 4-floor arcade runs
- difficulty selection: `Easy`, `Medium`, `Hardcore`
- stealth/combat state switching
- dark pockets as immediate stealth reset spaces
- gate hacking with visible button sequences
- probes, suppression, boost, EMP, and dark mode
- enemy suspicion, caution, search support, reinforcements, and lockdown escalation
- pause/settings shell
- title and in-game music layers

What does not exist yet in a finished form:

- first-run tutorial / Zone 00
- arcade run summary and scoring screen
- between-floor upgrades
- daily challenge seed
- fully normalized prompts/docs across every surface
- broad automated generation/invariant coverage
- multi-layer infiltration spaces
- mobile surface adaptation and local iPhone build path

## Core Design Pillars

1. Readable stealth pressure.
2. Signal as the central resource.
3. Combat as failure recovery, not the primary mode.
4. Arcade mode as the long-term core.
5. Enemies with one clean rule each.

## Near-Term Product Goals

- onboarding without long text
- unified controls and prompts
- clear safe/suspicious/detected feedback
- arcade replay incentives
- deterministic generation and stronger tests

## Future Expansion Notes

One promising future direction is discrete multi-layer infiltration spaces: upper/lower stealth planes with blurred inactive-layer context and authored transition points.

That should remain a later-phase feature, after the one-layer stealth/combat loop and arcade generation are fully reliable.

See:

- `docs/spec/multi_layer_spaces.md`
- `docs/spec/mobile_surface_plan.md`

## Current Product Rule

The game currently behaves like this:

- stealth is the preferred state
- combat is fun and survivable, but the system increasingly punishes staying loud
- objectives and exits can be delayed by alert-state systems
- hiding breaks enemy pressure and resets the encounter state

That is close to the intended identity and should be reinforced rather than replaced.

## Known Risks

- systems sprawl
- prompt drift from actual controls
- combat overpowering stealth
- arcade generation creating unreadable pressure stacks
- docs/spec drifting behind code unless updated during implementation
