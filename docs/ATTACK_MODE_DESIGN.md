# Attack Mode Design

Attack mode should feel like a **Signal Breach**: fast, dangerous electronic warfare inside the same dark surveillance world. `Geometry Wars` is a useful mechanical reference for movement pressure and readability, but the tone should stay darker, harsher, and more cohesive with stealth mode.

## Design Goal

- Attack mode is not a separate arcade minigame.
- It is the system punishing a blown stealth trace.
- The player should understand whether they are tracked, evading, hidden, or clear.
- The best outcome is not always killing everything; escape and reset should be valid.

## Combat State Language

- `TRACKED`: enemies still have line of sight or close threat pressure.
- `EVADE`: the player broke contact and the clear timer is counting down.
- `HIDDEN`: player reached a hiding spot and is clearing pressure.
- `RESOLVED`: combat exits back to stealth with a strong visual snap.

Current HUD support exists for `TRACKED`, `EVADE`, `HIDDEN`, and `CAUTION`.

## Tone

Use:
- cyan/white/red electronic warfare
- harsh signal arcs
- dark negative-space flashes
- corrupted geometry
- sharp enemy outlines and projectile lanes

Avoid:
- rainbow neon
- playful particle confetti
- bouncy arcade explosions
- score-attack visual noise
- effects that imply enemies are dead when they are only disabled

## Visual Direction

Stealth mode:
- green/black monitor view
- constrained visibility
- blurred peripheral information

Caution:
- amber/orange suspicion
- warning arcs and visual buildup

Combat:
- red/cyan signal breach palette
- wider visibility than stealth
- reduced blur so dodging stays fair
- sharper enemy/projectile contrast
- pulsing trace pressure

EMP:
- blue-white system collapse
- broken electric arcs
- disabled enemy glitching
- player system slowdown feedback

## Enemy Combat Roles

`Sentry`
- Stationary turret pressure.
- Should force movement through projectile lanes.
- Needs clear aim/readiness feedback.

`Sweeper`
- Mobile hunter and pulse pressure.
- Should own long lanes and force dodges.
- Best used to flush the player out of safe paths.

`Wisp`
- Flanker / perimeter control.
- Should threaten routes and cutoffs, not swarm randomly.
- In stealth, patrols edges; in combat, pressures escape lanes.

`Hunter`
- Direct chase threat.
- Should be simple, fast, and scary.
- Contact danger remains important.

`Prism`
- Rotating beam hazard.
- Should create timing windows and unsafe zones.
- Beam contact should remain immediately serious.

`Pulsar`
- Rhythmic area denial.
- Should create “move now / wait now” combat beats.

`WarpMine`
- Delayed trap / reinforcement threat.
- Should be visually clear when arming.

## Player Combat Verbs

Existing:
- fire
- boost
- probe
- jammer
- EMP
- hide/reset

Needed refinements:
- combat should make escape viable, not only fighting
- EMP should control a room but slow the player
- probes should distract search pressure without becoming mandatory
- jammer should reduce local pressure and help break contact

## Combat Objective

Attack mode needs structure beyond “kill everything.”

Potential default rule:
- survive and break contact until trace clears
- HUD shows `TRACKED` or `EVADE`
- if `EVADE` reaches zero, combat exits to stealth

Future variants:
- destroy a signal core
- survive a lockdown timer
- reach a blackout/hiding pocket
- disable a reinforcement relay
- escape through a breached gate

## Readability Requirements

- Player must know if combat is still active.
- Player must know whether they are tracked or evading.
- Projectiles and enemy attack zones must be clearer than background effects.
- Combat visibility should be less restrictive than stealth visibility.
- Hiding spots should read as emergency reset geometry.

## Implementation Priority

1. Combat visibility pass.
   - widen visibility
   - reduce blur
   - sharpen enemies/projectiles

2. Enemy combat role tuning.
   - make each enemy’s attack-mode behavior distinct
   - avoid all enemies simply chasing

3. Combat impact language.
   - darker projectile hits
   - enemy damage flash
   - signal-fragment death effects
   - near-miss / danger pulse

4. Combat resolution feedback.
   - stronger snap back to stealth
   - visible trace clear
   - relief moment when the player escapes

5. Combat encounter templates.
   - rooms designed for breach pressure
   - escape lanes and reset pockets
   - reinforcements used sparingly

## Current Notes

- Combat escape HUD has been added.
- EMP exists and should remain a tactical tradeoff, not a kill button.
- Suspicion/alert colors now help bridge stealth into combat.
- Next highest-value pass is combat visibility and projectile/enemy readability.
