# Visual Identity Phase Track

## Mission

This game must read as:

**Top down shooter. Metal Gear Solid mechanics. Matrix style visuals.**

If a change weakens any part of that sentence, the work is not complete.

This phase track exists to let engineering and art iterate slowly, commit often, and verify every visual step with reproducible snapshots before moving on.

## Working Rules

1. Do not combine multiple major visual goals into one implementation pass.
2. Each phase must end with:
   - code/art changes
   - a snapshot run
   - a written review against acceptance criteria
   - a checkpoint commit before the next phase begins
3. If a phase fails snapshot review, do not continue forward. Revise inside the same phase.
4. Prefer multiple small commits over one large art dump.
5. Preserve gameplay readability above decorative complexity.
6. The signal-language look must remain intentional, but game entities must gain mass and presence.

## Snapshot Requirement

All phase docs assume snapshot verification through the existing tooling:

```bash
./agent-tooling/capture-screenshots.sh --mode story --story-scenes res://src/world/World.tscn --capture-backend screen --output-dir <phase_review_name>
```

Use additional focused runs when needed, but every phase must at minimum regenerate a review set for:

- `story_world_spawn`
- `story_world_corridor`
- `story_world_next_room`

## Required Review Format

Every phase review should answer:

1. Did the change make the game feel more like a top down stealth-action shooter?
2. Did it improve material weight without muddying readability?
3. Did it strengthen the Matrix-style signal aesthetic rather than replacing it?
4. Did it introduce any new visual lies, UI confusion, or target readability problems?
5. Is the result worth committing as a checkpoint?

## Phase Order

1. [00 - Visual Contract](./PHASE_00_VISUAL_CONTRACT.md)
2. [01 - Ground And Wall Mass](./PHASE_01_GROUND_AND_WALL_MASS.md)
3. [02 - Player Ship Structure](./PHASE_02_PLAYER_SHIP_STRUCTURE.md)
4. [03 - Enemy Structure](./PHASE_03_ENEMY_STRUCTURE.md)
5. [04 - Contact And Occlusion](./PHASE_04_CONTACT_AND_OCCLUSION.md)
6. [05 - Integration And Signal Discipline](./PHASE_05_INTEGRATION_AND_SIGNAL_DISCIPLINE.md)

## Exit Condition

This track is complete only when:

- floor, walls, ship, and enemies all feel materially different
- moving actors feel weighty rather than hollow
- geometry reads as infrastructure, not placeholder lines
- the signal/CRT language remains core to the identity
- screenshots consistently support the mission statement
