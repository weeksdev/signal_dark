# Signal Dark — Living Next-Steps Document

Last updated: 2026-04-25
Repository reviewed: `weeksdev/signal_dark`

## Current Assessment

`Signal Dark` is already beyond a throwaway prototype. It has a recognizable identity: top-down stealth-action in hostile machine spaces, with visibility management, dark mode, hacking, enemy pattern reading, seeded arcade floors, and hand-authored story zones.

The next phase should not be “add more enemies” or “add more levels” by default. The next phase should be to make the core loop legible, repeatable, tunable, and shippable.

The game’s strongest current direction is:

> A compact stealth roguelite / arcade stealth-action game where the player manages signal exposure, darkness, enemy sensor logic, and short bursts of combat pressure.

The main risk is systems sprawl. The project already has dark mode, boost, probes, suppress kills, hacking, enemy respawns, reinforcements, gatelocks, story zones, arcade mode, difficulty, and multiple enemy archetypes. That is enough mechanical surface area. The next work should convert those mechanics into a polished player experience.

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

## Immediate Priority Stack

### P0 — Make the Current Game Playable Without Explanation

#### 1. Add a first-run/tutorialized Zone 00

Current issue: the game has enough systems that a new player may not understand what is happening quickly enough.

Create a very small onboarding zone before Zone 01 or as an optional “Training Signal” mode.

Required beats:

- Move through darkness.
- Toggle dark mode and see signal emission drop.
- Get near one simple detector and escape during caution.
- Use a dark pocket to break detection.
- Hack one gate.
- Launch one probe to misdirect an enemy.
- Perform one optional suppressed kill.
- Reach exit.

Acceptance criteria:

- A new player can complete it in under 3 minutes.
- No text wall longer than one sentence.
- Each mechanic is introduced immediately before it is needed.
- Player death is unlikely unless they ignore prompts.

Proof obligation:

- Record a first-playthrough session and note every moment where the player hesitates for more than 5 seconds.

---

#### 2. Fix control prompt consistency

Current risk: README/control docs and start screen hints appear potentially inconsistent. The README lists Space as boost, Left Mouse as fire, E as suppress, F/Right Mouse as hack, Q as probe. The start screen hint block says FIRE SPACE, BOOST E, SUPPRESS F. That inconsistency can make the game feel broken even when the mechanics work.

Tasks:

- Choose canonical keyboard mapping.
- Update `project.godot`, README, start screen, HUD prompts, and any tutorial prompts to match.
- Decide whether mouse aiming/fire is the primary desktop scheme or keyboard-only is the default.

Recommended canonical mapping:

- WASD: move
- Mouse: aim
- Left Mouse: fire
- Space: boost
- Left Shift: dark mode
- Q: probe
- E: suppress
- F / Right Mouse: hack

Acceptance criteria:

- README, start screen, and actual input map match.
- Controller mapping has the same action semantics.
- No gameplay hint contradicts the input map.

Proof obligation:

- Manual smoke test: perform every action from the title-screen hints in one run.

---

#### 3. Make detection state visually explicit

Current issue: the stealth model is interesting, but the player needs extremely clear feedback.

Add or improve visual states:

- Hidden / low signal
- Exposed / high signal
- Caution countdown
- Full combat alert
- Enemy has line-of-sight
- Enemy lost line-of-sight

Concrete additions:

- A small “SIGNAL” meter near the player or HUD.
- Caution ring around the player or enemy when detection begins.
- Brief directional indicator showing which enemy detected the player.
- Distinct combat screen pulse when full alert begins.

Acceptance criteria:

- Player can tell within 0.5 seconds whether they are safe, suspicious, or detected.
- Player can identify which enemy caused detection.
- Dark pocket safety is unmistakable.

Proof obligation:

- In a playtest, ask the player to narrate “safe / suspicious / detected” while playing. They should be correct at least 90% of the time.

---

### P1 — Make Arcade Mode the Core Product

#### 4. Add run summary and scoring

Arcade mode already has seeded multi-floor runs and difficulty. It needs a reason to replay.

Add end-of-run summary:

- Seed
- Difficulty
- Floors cleared
- Time
- Kills
- Suppressed kills
- Alerts triggered
- Hacks completed
- Probes used
- No-kill bonus
- No-alert bonus
- Signal discipline score

Scoring should reward stealth first, not raw combat.

Suggested score categories:

- Ghost: no kills, no alerts
- Silent: suppressed kills only, no full alerts
- Surgical: minimal kills, low alerts
- Burned: repeated alerts but survived

Acceptance criteria:

- Finishing or dying in arcade mode shows a summary screen.
- Summary includes seed and difficulty for replay/sharing.
- Player can restart same seed or reroll from summary.

Proof obligation:

- Same seed + same difficulty produces same generated layout and enemy placements.

---

#### 5. Add arcade progression modifiers

Current arcade floor count is fixed at four floors. Add controlled variation without bloating scope.

After each floor, offer one of three upgrades or modifiers:

Possible player upgrades:

- +1 probe charge
- Dark mode movement penalty reduced
- Boost cooldown reduced
- Suppression range slightly increased
- Hack sequences reveal one extra symbol early

Possible system modifiers:

- More gates
- Fewer dark pockets
- Reinforcements spawn faster
- Wisp-heavy floor
- Prism lockdown floor

Recommendation: start with player upgrades only. Add system modifiers later.

Acceptance criteria:

- After each arcade floor, player chooses one upgrade.
- Upgrade effects are visible in HUD or pause/status screen.
- Upgrade choices are deterministic for seed + floor.

Proof obligation:

- Same seed produces same upgrade options.

---

#### 6. Add daily challenge seed

This is cheap and gives the game an external hook.

Rules:

- Daily seed is derived from date.
- Same daily seed for all players.
- Difficulty fixed or selectable.
- Summary screen marks “Daily Run.”

Acceptance criteria:

- Title screen has “Daily Signal” option.
- Daily seed is stable for the date.
- Summary screen distinguishes daily vs random run.

Proof obligation:

- Date-based seed generation test.

---

### P2 — Balance and Enemy Design

#### 7. Create an enemy behavior matrix

Each enemy needs a defined purpose, counterplay, and tuning knobs.

| Enemy | Primary Threat | Player Counter | Tuning Knobs | Current Risk |
|---|---|---|---|---|
| Sweeper | Patrol lane pressure | Timing, route planning | speed, patrol length, sight width | May feel generic unless lane is readable |
| Pulsar | Rhythmic detection/damage | Wait, dash between pulses | pulse interval, radius, warning time | Needs clear telegraph |
| Prism | Beam/line denial | Break LoS, dark pockets | beam width, rotation speed | Can feel unfair if beam origin unclear |
| Sentry | Static scanner | Route around, dark mode | cone size, detection time | Good tutorial enemy |
| Hunter | Active pursuit | Hide, break LoS, probe | speed, reacquire delay | Should be scary but not omniscient |
| Wisp | Light/dark pressure | Avoid halos, use pockets | halo radius, drift speed | Strong identity if visualized well |
| WarpMine | Delayed escalation | Avoid, trigger intentionally, suppress payload | arm time, payload count, blast radius | Could become chaos if overused |

Acceptance criteria:

- Every enemy has a short codex entry.
- Every enemy has at least one obvious counterplay mechanic.
- Arcade placement avoids stacking unreadable enemy combinations too early.

Proof obligation:

- For each enemy, create one small test room where its rule is obvious in isolation.

---

#### 8. Tune difficulty by signal pressure, not just enemy count

Current encounter placement uses cost budgets, floor pools, floor depth, and difficulty multipliers. That is a good start, but difficulty should be measured by pressure composition.

Track per-room pressure values:

- Detection coverage
- Movement denial
- Chase risk
- Required hack exposure
- Dark pocket availability
- Exit path complexity

Add debug overlay or log output for generated arcade rooms.

Acceptance criteria:

- Arcade generation can print a per-room pressure summary.
- Easy difficulty guarantees at least one safe recovery option per major room.
- Hardcore can be cruel but not unwinnable.

Proof obligation:

- Generate 100 seeds per difficulty and verify no floor lacks a valid path from spawn to exit.

---

### P3 — Technical Hardening

#### 9. Expand automated tests around arcade generation

Existing tests already cover map boundary leaks, gate lock toggling, and WarpMine behavior. Expand this into AGSP-style executable specifications.

Add tests for:

- Same seed produces same graph/layout.
- Different seeds produce meaningfully different layouts.
- Every generated arcade floor has spawn and exit.
- Every generated floor has valid camera/world bounds.
- Gate locks do not block mandatory progression unfairly.
- Enemy placements do not spawn inside walls or too close to doors.
- Dark pockets do not spawn inside walls.
- All story zones load headlessly.

Acceptance criteria:

- One command runs all smoke/invariant tests.
- Test README lists purpose, command, and expected failure meaning.
- CI can run Godot headless if practical.

Proof obligation:

- `godot --headless --path . --quit` passes.
- All custom tests pass locally.

---

#### 10. Add a living spec folder

Create:

```text
docs/spec/
  signal_dark_spec.md
  arcade_generation_spec.md
  enemy_matrix.md
  control_mapping.md
  test_obligations.md
  decision_log.md
```

The spec should evolve with the game. Every major feature should include:

- Intent
- Current behavior
- Player-facing rule
- Tuning knobs
- Acceptance criteria
- Test/proof obligation
- Known risks
- Decision log entry

Acceptance criteria:

- No new mechanic lands without an entry in the spec.
- No balance change lands without a short rationale.
- Bugs discovered during playtesting become either test cases or explicit deferred issues.

---

## Recommended Next 10 Commits

1. Normalize controls across README, start screen, `project.godot`, and HUD prompts.
2. Add `docs/spec/control_mapping.md`.
3. Add `docs/spec/enemy_matrix.md`.
4. Add `docs/spec/arcade_generation_spec.md` based on current seeded floor behavior.
5. Add first-run tutorial zone or tiny training scene.
6. Add signal meter / caution indicator polish.
7. Add arcade run summary screen.
8. Add same-seed determinism test for arcade generation.
9. Add generated-floor validity test over a batch of seeds.
10. Add first pass of arcade upgrade choices between floors.

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

---

## Current Working Hypothesis

The best near-term product shape is:

> A polished Godot web/desktop stealth arcade prototype with a short tutorial, four story zones, seeded arcade runs, daily challenge seed, replayable scoring, and extremely readable signal/detection feedback.

That is enough to make the game coherent and testable without ballooning scope.

---

## Agent Execution Protocol

For agent-driven development, each task should follow this loop:

1. Read relevant spec page.
2. Inspect current implementation.
3. State observed behavior.
4. Implement the smallest change.
5. Add or update test/proof obligation.
6. Update spec with decision and evidence.
7. Run smoke tests.
8. Summarize changed files and remaining risks.

Every agent task should produce:

- Summary
- Changed files
- Behavior before/after
- Test evidence
- Spec updates
- Known risks

---

## Next Agent Prompt

Use this prompt for the next coding pass:

```text
You are working in the Godot 4 repository `signal_dark`.

Goal: normalize player controls and documentation across the project.

Tasks:
1. Inspect `project.godot`, `README.md`, `src/ui/StartScreen.gd`, HUD/prompt scripts, and any tutorial/help text.
2. Identify all places where controls are documented or displayed.
3. Choose this canonical keyboard/mouse mapping unless current implementation makes it unsafe:
   - WASD: move
   - Mouse: aim
   - Left Mouse: fire
   - Space: boost
   - Left Shift: dark mode
   - Q: probe
   - E: suppress
   - F / Right Mouse: hack
   - R: restart/reroll where applicable
4. Update code and docs so all displayed controls match actual bindings.
5. Add `docs/spec/control_mapping.md` describing keyboard and controller mappings.
6. Run Godot headless smoke check.
7. Report changed files, test output, and any remaining inconsistencies.

Do not add new gameplay mechanics in this pass.
```
