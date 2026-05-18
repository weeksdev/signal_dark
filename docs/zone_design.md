# Signal Dark — Story Zone Design Plan

## Enemy Roster Reference

| Enemy | Type | Behavior | Suppression? | Introduced |
|---|---|---|---|---|
| **Sweeper** | Patrol | Wall-clipped cone flashlight, pulses; patrols A↔B | Yes (from behind, dark mode) | Zone 1 |
| **Wisp** | Patrol | Orbital anchor patrol; radial wall-clipped vision; suspicion builds fast | Yes (from behind, dark mode) | Zone 1 |
| **Pulsar** | Stationary | Detection rings radiate outward on rhythm — must time the gap | Yes (dark mode, close) | Zone 1 |
| **Sentry** | Stationary/Turret | Fires projectiles in combat; 220px suspicion warning ring; requires LOS | Yes (from behind, dark mode) | Zone 2 |
| **Hunter** | Roaming Chaser | Oval patrol; chases aggressively in combat; no LOS detection | No | Zone 2 |
| **Prism** | Stationary Spinner | 4 rotating beams; suspicion builds on beam crossing; faster in combat | Yes (close, dark mode) | Zone 3 |
| **WarpMine** | Tripwire | Deploys 2 Hunters or Wisps when triggered; blast kills at close range | Yes (dark mode, very close) | Zone 4 |

---

## Design Principles

**Corridors beat rooms.** Arcade uses rooms. Story uses corridors — bent, branching, stacked — so the player reads danger around corners, not across open spaces.

**Teach, then stack.** Each zone introduces 1–2 enemy types. Subsequent zones layer old types into new configurations.

**Every dark pocket is a decision.** Placed at crossroads, not dead ends. The player has to choose whether to hide and wait or push through.

**GateLocks create checkpoints.** Hacking costs attention and time — place them where the difficulty resets the player's resource state before the next section.

**Enemy overlap is the challenge.** Pulsars behind Sweepers. Prisms next to Wisps. The puzzle is finding the seam between their patterns.

---

## Zone 1 — Static

**Theme:** The machine spaces are dormant — most threats are pattern-based and readable. Introduction zone. No Hunter, no Prism, no WarpMine.

**Introduced:** Sweeper, Wisp, Pulsar, DarkPocket, ExitZone

**Teaching goals:**
- Dark mode slows you, hides you
- Sweeper cone has a safe window to cross
- Pulse rings have a timing gap — stand still and wait
- Dark pockets are perfect hiding spots mid-corridor
- Wisp orbit is predictable — it has a cadence

```
ENTRY ──[CORRIDOR A]──┐
                       │ Sweeper pacing left-right
                    [POCKET] ── [CORRIDOR B] ──┐
                                                │ L-bend; Wisp orbiting
                                           [NEXUS ROOM]
                                            │         │
                                     [LEFT NECK]  [RIGHT NECK]
                                     Pulsar ×2    Sweeper + Pocket
                                            │         │
                                         [TERMINAL CHAMBER]
                                          Pulsar ×1, Wisp ×1
                                                │
                                           [EXIT HALL]
                                           Sweeper blocking exit
                                                │
                                            [EXIT]
```

### Section Breakdown

**Corridor A — The Opener**
- 300×120px. One Sweeper pacing left-right, full width.
- DarkPocket on the south wall mid-corridor.
- Player learns: enter DarkPocket, wait for cone to pass, sprint through.

**Nexus Room — First Junction**
- 260×260px open space with two wall pillars creating channels.
- Wisp orbiting the center pillar (90px radius).
- DarkPocket tucked in the south-west corner.
- Two exits: Left Neck and Right Neck. Player chooses.

**Left Neck — Pulse Gauntlet**
- 100×320px straight corridor (tall).
- Two Pulsars, one at each end, offset by ~0.65 seconds so their rings interleave.
- No dark pocket — player must time the gap.
- Teaches: reading pulse rhythm, not running.

**Right Neck — The Bend**
- L-shaped: 200×100px horizontal segment bending into 100×200px vertical.
- One Sweeper on the horizontal. DarkPocket at the bend.
- Teaches: using the corner as a natural pause point.

**Terminal Chamber — The Convergence**
- 300×200px. Both necks arrive here.
- One Pulsar center-right (rings cover most of the room).
- One Wisp orbiting a structural column near the north wall.
- DarkPocket at the south-west entry.
- Player must navigate between Pulsar timing and Wisp arc.

**Exit Hall**
- 400×100px straight run.
- One Sweeper pacing the full length. No pocket — reward for getting through Terminal.
- Exit at the far end.

**Enemy count:** 3 Sweepers, 3 Pulsars, 2 Wisps, 3 DarkPockets

---

## Zone 2 — Tension

**Theme:** The machines are active. Sentries watch key choke points. Hunters patrol corridors without a pattern you can easily read. Combat becomes a real option for the first time — but it costs you.

**Introduced:** Sentry, Hunter

**Teaching goals:**
- Sentry has a 220px suspicion ring — staying dark mode at range is safe
- Hunter has no cone — it roams the room and will smell your signal at close range
- Suppression kills: in dark mode, approach from behind to silent-kill a Sentry or Sweeper
- EMP as a panic button (first map where you might need it)
- Jammer to blank a Sentry temporarily

```
ENTRY ──[ANTECHAMBER]──[GATELESS NECK]──[SPLIT HALL]
                                              │          │
                                     [WEST WING]    [EAST WING]
                                      Sentry ×2      Hunter patrol
                                      Sweeper ×1     Sweeper ×1
                                              │          │
                                         [ARCHIVE ROOM]
                                          Pulsar ×2
                                          Sentry watching south
                                                │
                                       [COMPRESSION NECK]
                                        Sweeper + Hunter overlap
                                                │
                                         [RELAY CHAMBER]
                                          Wisp ×2, Pulsar ×1
                                          DarkPockets ×2
                                                │
                                            [EXIT]
```

### Section Breakdown

**Antechamber**
- 200×200px. One Sentry facing the ENTRY door.
- DarkPocket in the north corner — player enters it and waits for facing_vector to rotate, then suppresses from behind.
- First taught suppression opportunity — low stakes.

**Split Hall — The Fork**
- 320×100px T-junction.
- One Sweeper pacing the horizontal length.
- Player chooses West or East Wing.

**West Wing — The Sentry Gallery**
- 160×340px tall corridor with two side alcoves.
- Two Sentries in alcoves facing outward (they cover the center lane).
- One DarkPocket at the far end (behind Sentry B).
- Player must either suppress both Sentries in sequence or run the dark-mode gap between their arcs.

**East Wing — Hunter Den**
- 200×280px irregular room with a central pillar column.
- Hunter orbiting the room perimeter (120×80px oval).
- One Sweeper on a cross-path.
- No dark pocket — player must time both the Hunter oval and the Sweeper cone.
- If detected, Hunter chases into the rest of the zone.

**Archive Room — The Merge**
- 300×220px. Both wings connect here.
- Two Pulsars: one north-left, one south-right — rings interleave diagonally.
- One Sentry watching south from a raised alcove (can't be suppressed from below).
- DarkPocket east side.
- Teaches Pulsar + Sentry stacking: move between pulses while staying dark.

**Compression Neck**
- 100×200px straight corridor.
- Sweeper top-to-bottom pace. Hunter also roams in from the Archive Room if alerted.
- Intended to be difficult if a Hunter is active — teaches "clear before you bottle yourself in."

**Relay Chamber**
- 260×260px circular-ish room.
- Two Wisps orbiting the two columns (different phase offsets — their arcs briefly overlap).
- One Pulsar center.
- Two DarkPockets at south entries.
- Exit north.

**Enemy count:** 3 Sweepers, 3 Pulsars, 3 Sentries, 2 Hunters, 2 Wisps, 3 DarkPockets

---

## Zone 3 — The Grid

**Theme:** Industrial density. Tight cross-corridor layouts. Prism introduces beam intersection — the challenge shifts from "avoid the cone" to "find the gap in a rotating 4-axis grid."

**Introduced:** Prism

**Teaching goals:**
- Prism beams rotate — find the safe quarter before moving
- Two Prisms at right angles create a beam lattice — must thread through
- Reinforcement spawns: kill count triggers Wisps and Prisms from marker positions
- Dark pockets become more valuable as reward spaces inside Prism zones

```
ENTRY ──[FILTER HALL]── [PRISM ANTECHAMBER] ──[CROSSING]──┐
          Sweeper ×2       Prism ×1                          │
          Sentry ×1        Pocket                      [NORTH GALLERY]
                                                        Prism ×2
                                                        Hunter ×2
                                                              │
                                                        [REACTOR CORE]
                                                         Prism ×3
                                                         Wisp ×2
                                                         Pocket ×2
                                                              │
                                                     [SOUTH LOCK NECK]
                                                      Sentry ×2 + Sweeper
                                                              │
                                                       [RELAY CORRIDOR]
                                                        Pulsar ×2
                                                        Hunter ×1
                                                              │
                                                          [EXIT]
```

### Section Breakdown

**Filter Hall**
- 380×120px with two pillars creating a chicane (player must S-curve through).
- Two Sweepers: one pacing the west half, one east half — cones nearly touch at the center pillar.
- One Sentry at the east end watching west.
- DarkPocket tucked behind the west pillar.
- Teaches: chicane movement, timed double-cone crossing.

**Prism Antechamber — First Prism**
- 200×200px square room with the first Prism at center.
- Four alcoves in corners — player can shelter in any to wait for a safe angle.
- DarkPocket in the south-west alcove.
- Solo Prism at low rotate speed — readable introduction.

**The Crossing — 4-way Junction**
- 260×260px with walls trimmed into a cross shape (four arms, each 100px wide).
- One Pulsar in the center — rings fill the junction.
- Player must cross from south arm to north arm through the junction, timing the Pulsar.
- Prism Antechamber is visible from here through the west arm — its beams sweep into the junction occasionally.

**North Gallery — Double Prism**
- 380×220px with two structural pillars creating lanes.
- Two Prisms: positioned so their beams sweep perpendicular to each other.
- Two Hunters roaming the gallery perimeter.
- Two DarkPockets: one behind each pillar.
- High pressure room: Prism beams + Hunter patrol. Player must find beam gap AND avoid Hunter arc.
- Reinforcement marker: killing Hunter A here spawns one Wisp at the south end.

**Reactor Core — The Dense Room**
- 280×280px central hub connecting Gallery + South Lock Neck.
- Three Prisms: one at center (slow spin), two at north and south walls (faster).
- Two Wisps orbiting the center Prism and the south Prism respectively.
- Two DarkPockets at east and west walls.
- This is the zone's hardest room — 3 rotating beam sets + 2 orbital Wisps.
- Designed to be threaded in dark mode using the dark pockets as waypoints.

**South Lock Neck**
- 100×200px straight.
- Two Sentries watching each other (cross-fire — can't suppress one without the other seeing).
- One Sweeper adding cone pressure.
- Intent: player needs to use suppression kit (jammer or clever sequencing) to pass.

**Relay Corridor**
- 400×100px with one L-bend.
- Two Pulsars staggered along the corridor (rings interleave at the bend).
- One Hunter pacing the corridor.
- Final pressure before the exit — no pocket, must run clean.

**Enemy count:** 4 Sweepers, 4 Pulsars, 4 Sentries, 3 Hunters, 4 Wisps, 6 Prisms, 4 DarkPockets

**Reinforcement markers:** HunterGalleryN (→ Wisp), PrismCrossE (→ Prism), WispReactorB (→ Wisp)

---

## Zone 4 — The Collapse

**Theme:** The space is failing — WarpMines seed every approach, GateLocks checkpoint the most dangerous sections, and enemy density is maximum. Every tool the player has is tested.

**Introduced:** WarpMine, GateLock

**Teaching goals:**
- WarpMine triggers on proximity + emission — dark mode pass is safe, running is not
- Mines deploy 2 Hunters or Wisps — clearing them first is an option
- GateLock requires hacking under pressure (enemies still patrol while you type the sequence)
- The final gate puts a Prism and Sentry on the other side watching through the gate window

```
ENTRY ──[MINEFIELD ENTRY]──[GATE A]──[BRIDGE WING]──┐
          WarpMine ×2                                  │
          Sweeper ×1                           [SIGNAL HUB]
          Pocket                                Prism ×2
                                                Sentry ×1
                                                Wisp ×2
                                                      │
                                              [GATE B]
                                                      │
                                         [COMPRESSION CROSS]
                                          Sweeper ×2
                                          Pulsar ×2
                                          WarpMine ×2
                                          Pocket ×1
                                                      │
                                            [DEEP NEST]
                                             Hunter ×3
                                             Prism ×1
                                             WarpMine ×2
                                             Pocket ×2
                                                      │
                                         [GATE C — LOCKDOWN]
                                                      │
                                           [EXIT CHAMBER]
                                            Sentry ×2
                                            Wisp ×1
                                            No Pocket
                                                      │
                                               [EXIT]
```

### Section Breakdown

**Minefield Entry**
- 300×180px. Two WarpMines placed in the center lane.
- One Sweeper pacing across the north half.
- DarkPocket on the west wall near entry.
- First WarpMines: player learns at low cost — mine trigger radius is visible, dark mode pass is safe.
- One mine `payload_kind = "wisp"`, one `payload_kind = "hunter"`.

**Gate A — First GateLock**
- 100px neck with a GateLock door.
- Sentry watching from the far side through the gate window.
- Player hacks the gate while Sweeper patrols behind them and Sentry watches through.
- Teaches: hack under time pressure; enemies see through open gates.

**Bridge Wing**
- 400×120px with a central column cutting line-of-sight.
- Two Sweepers: one each side of the column (facing opposite directions).
- No pocket — player must dark-mode through the gap between cones.

**Signal Hub — Mid-Boss Room**
- 300×300px. Zone's most complex multi-threat room.
- Two Prisms: opposite corners, perpendicular spin axes.
- One Sentry facing north (toward Gate A).
- Two Wisps: one orbiting each Prism.
- Two DarkPockets: east and west walls.
- Intent: player suppresses the Sentry, then threads Prism beams to reach Gate B.

**Gate B**
- Narrow neck, GateLock. No enemies immediately adjacent — brief rest.
- Teaches: GateLocks are also breathing room between hard sections.

**Compression Cross**
- 260×260px cross junction.
- Two Sweepers on perpendicular axes (one horizontal, one vertical).
- Two Pulsars in opposite corners (rings fill the junction center).
- Two WarpMines in the north and east arms.
- One DarkPocket at the south arm entrance.
- All mechanics stacking — the tightest design challenge in the game.

**Deep Nest**
- 280×280px with three structural pillars.
- Three Hunters roaming — different oval paths, partially overlapping.
- One Prism at center (slow spin).
- Two WarpMines tucked against the east wall.
- Two DarkPockets behind two of the pillars.
- Option: EMP the Prism and run for the pocket, then suppress Hunters one by one.

**Gate C — Lockdown**
- GateLock with `lockdown_only = true`.
- Triggers if combat escalates: gate slams shut during combat, opens in stealth.
- Forces player to disengage and go dark before advancing.

**Exit Chamber — Final Pressure**
- 280×180px final room.
- Two Sentries watching the exit (cross-coverage, can't suppress both easily).
- One Wisp orbiting the exit trigger.
- No dark pocket — final test is raw movement and dark mode discipline.

**Enemy count:** 2 Sweepers, 2 Pulsars, 4 Sentries, 3 Hunters, 3 Wisps, 3 Prisms, 6 WarpMines, 3 GateLocks, 7 DarkPockets

---

## Implementation Order

| Priority | Work |
|---|---|
| 1 | Rebuild Zone 1 layout — current version has too many enemy types too early |
| 2 | Rebuild Zone 2 layout — add Sentry gallery and Hunter den as distinct teaching rooms |
| 3 | Zone 3 is closest to plan — add Prism Antechamber intro, tune density |
| 4 | Zone 4 — add Gate C lockdown logic, tune WarpMine placement |
| 5 | Zone complete overlay: show "Zone X of 4" and kill count; add brief flavor text per zone |
| 6 | Playtest each zone solo before wiring the chain |
