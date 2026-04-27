# Signal Dark — Product Memo

Last updated: 2026-04-25
Repository reviewed: `weeksdev/signal_dark`

## Current Assessment

`Signal Dark` is already beyond a throwaway prototype. It has a recognizable identity: top-down stealth-action in hostile machine spaces, with visibility management, dark mode, hacking, enemy pattern reading, seeded arcade floors, and hand-authored story zones.

The next phase should not be “add more enemies” or “add more levels” by default. The next phase should be to make the core loop legible, repeatable, tunable, and shippable.

The game’s strongest current direction is:

> A compact stealth roguelite / arcade stealth-action game where the player manages signal exposure, darkness, enemy sensor logic, and short bursts of combat pressure.

The main risk is systems sprawl. The project already has dark mode, boost, probes, suppress kills, hacking, enemy respawns, reinforcements, gatelocks, story zones, arcade mode, difficulty, and multiple enemy archetypes. That is enough mechanical surface area. The next work should convert those mechanics into a polished player experience.

This file should stay at the product level:

- player fantasy
- design pillars
- current priorities
- scope boundaries
- open product questions

Implementation detail, acceptance criteria, and proof obligations should live in `docs/spec/`.

---

## North Star

### Player Fantasy

“You are a fragile signal inside a hostile machine. You survive by staying unreadable, exploiting darkness, manipulating enemy sensors, and escaping before the system fully understands where you are.”

### Design Pillars

1. **Readable stealth pressure**
   - The player should understand why they were detected.
   - The player should understand when they are safe.
   - The player should understand what each enemy is threatening.

2. **Signal as the central resource**
   - Movement, boost, firing, probes, and dark mode should all connect back to signal exposure.
   - The player should learn to think: “How much am I broadcasting?”

3. **Short combat is failure recovery, not the main mode**
   - Combat should be intense and survivable, but should feel like the system waking up.
   - The optimal player should prefer stealth, suppression, hacking, and misdirection.

4. **Arcade mode should become the replayable product core**
   - Story zones can teach and showcase.
   - Arcade mode should provide long-term replayability.

5. **Every enemy should teach one clean rule**
   - Sweeper: moving patrol lanes.
   - Pulsar: timed danger / rhythm.
   - Prism: line/beam discipline.
   - Sentry: static scanner pressure.
   - Hunter: chase pressure.
   - Wisp: light/dark pocket pressure.
   - WarpMine: area denial / delayed escalation.

---

## Already Landed / Verify

These systems exist in some form and now need verification, tuning, or documentation rather than vague expansion:

- stealth/combat state transitions
- dark pockets and stealth reset behavior
- hack gates, previews, and controller/keyboard prompt adaptation
- seeded arcade generation with multi-floor runs
- difficulty selection
- enemy suspicion/search/support behaviors
- combat reinforcements and lockdown pressure
- pause/settings shell
- title/in-game reactive music

The next passes should ask:

- Is it readable?
- Is it deterministic where it needs to be?
- Is it fair?
- Does the player understand it without explanation?

## Immediate Priority Stack

### P0 — Make the Current Game Playable Without Explanation

- Add a short onboarding zone or training signal.
- Normalize controls, prompts, and docs.
- Make stealth/detection state readable within half a second.

See:

- `docs/spec/signal_dark_spec.md`
- `docs/spec/control_mapping.md`
- `docs/spec/test_obligations.md`

### P1 — Make Arcade Mode the Product Core

- Add run summary and stealth-first scoring.
- Add deterministic between-floor upgrade choices.
- Add a daily challenge seed.

See:

- `docs/spec/arcade_generation_spec.md`
- `docs/spec/signal_dark_spec.md`
- `docs/spec/test_obligations.md`

### P2 — Tighten Enemy Identity and Pressure Composition

- Lock down enemy roles, counters, and tuning knobs.
- Tune difficulty by pressure composition, not raw count.
- Keep early rooms readable and late rooms harsh but recoverable.

See:

- `docs/spec/enemy_matrix.md`
- `docs/spec/arcade_generation_spec.md`

### P3 — Harden the Project

- Expand deterministic and invariant tests around generation and progression.
- Keep a live decision log so balance changes have rationale.

See:

- `docs/spec/test_obligations.md`
- `docs/spec/decision_log.md`

---

## Current Active Priorities

1. Normalize controls and all player-facing prompts.
2. Add a short onboarding/tutorial zone.
3. Add run summary and stealth-first arcade scoring.
4. Add deterministic arcade generation checks and floor-validity tests.
5. Improve stealth readability: signal, caution, and detection ownership.

---

## What Not To Do Yet

Do not add more enemy types yet.

Do not add a large story campaign yet.

Do not add complex narrative cutscenes yet.

Do not add inventory/crafting/meta-progression yet.

Do not spend too much time on art polish until detection readability is solved.

Do not balance by gut feel only. Add debug metrics and simple playtest notes.

---

## Open Design Questions

1. Is the game primarily mouse/keyboard twin-stick, keyboard-only, or controller-first?
2. Should arcade mode be the main menu default?
3. Is killing supposed to be a failure, a valid tactic, or a scoring tradeoff?
4. Should hacking always respawn defeated enemies, or only in certain gates/floors?
5. Should dark mode be a held input, a toggle, or configurable?
6. Should story zones unlock mechanics gradually, or should arcade mode be available fully from the start?
7. What is the target session length: 5 minutes, 15 minutes, or 30 minutes?
8. What is the intended release target: itch.io web build, Steam demo, downloadable desktop, or all of the above?

## Later-Phase Expansion Worth Preserving

One strong later-phase direction is discrete multi-layer infiltration spaces: upper/lower route planes with readable transition points and blurred ghost context for the inactive layer.

This fits the project’s stealth identity and has precedent in the genre, but it should stay behind current priorities until one-layer stealth/combat and arcade readability are more mature.

See:

- `docs/spec/multi_layer_spaces.md`

## Near-Term Platform Note

Mobile matters for this project, but the correct first move is a surface adaptation, not a separate mobile game.

That means:

- landscape phone presentation
- slightly wider mobile camera framing
- touch/controller shell
- HUD/prompt scaling
- same core gameplay rules

See:

- `docs/spec/mobile_surface_plan.md`

---

## Current Working Hypothesis

The best near-term product shape is:

> A polished Godot web/desktop stealth arcade prototype with a short tutorial, four story zones, seeded arcade runs, daily challenge seed, replayable scoring, and extremely readable signal/detection feedback.

That is enough to make the game coherent and testable without ballooning scope.

---

## Working Rule

Each implementation task should:

1. Read the relevant spec page.
2. Inspect current behavior in code.
3. Make the smallest meaningful change.
4. Update spec and decision log if behavior changed.
5. Run smoke checks or proof obligations.

This file should not hold agent prompts or task-by-task execution scripts. Those belong in the current task context or the spec pages.
