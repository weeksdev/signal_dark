# Enemy Matrix

Last updated: 2026-04-25

## Intent

Every enemy should communicate one dominant rule and one obvious counterplay path.

| Enemy | Current Behavior | Counterplay | Main Tuning Knobs | Current Watchouts |
|---|---|---|---|---|
| Sweeper | Moving patrol that emits rhythmic detection pulses and can hold corridor chokes | timing, route reading, dark pockets, silent kill from behind | pulse pattern, patrol length, dwell at choke points, detection range | post-combat route recovery and choke dwell need careful tuning |
| Pulsar | Static rhythmic pulse detector with expanding range and hard punish when player is bright | wait, move between pulses, stay dark, break LoS | pulse interval, pulse range, alert threshold | pulse readability is good, but range/fairness must stay obvious |
| Prism | Rotating multi-beam denial scanner that escalates through line contact | break LoS, dark pockets, route around beam sweep | beam width, beam range, spin speed | beam ownership must remain crystal clear |
| Sentry | Static watcher that builds suspicion from close, fast, visible movement and shoots in combat | stay dark, stay calm, route around, suppress from behind | suspicion gain, attack range, fire interval | can become oppressive if used too early or too densely |
| Hunter | High-pressure mover that patrols a small loop and becomes direct chase pressure in combat | hide, break LoS, probe, force it off timing | chase speed, reacquire behavior, patrol loop size | needs to feel dangerous without reading as omniscient |
| Wisp | Short-radius proximity alert enemy with route patrols and halo-based pressure | avoid halo, time corridors, use shadows | alert radius, route length, halo visibility, route pause | route clarity is critical; short loops feel unfair at choke points |
| WarpMine | Proximity escalation trap that arms, then spawns payload enemies on detonation | avoid, suppress early, trigger intentionally, back off | arm time, trigger radius, payload kind/count, blast radius | can create chaos if payload count or density gets too high |

## Usage Rules

- early arcade rooms should isolate one or two readable threats
- enemy combinations should create deliberate pressure, not visual noise
- each enemy should have at least one obvious counter the player can learn

## Current Notes From Implementation

- `Sweeper`, `Wisp`, and `Hunter` now attempt patrol-route recovery after combat instead of free-floating forever.
- `Sentry`, `Pulsar`, and `Prism` are effectively static anchors that escalate through sensing, not pathing.
- `WarpMine` is not just a trap; it is also an enemy spawner and escalation device.
- all enemies now share a common stealth visual-state ladder through `BaseEnemy`, but readability still needs tuning room by room.

## Spec Follow-Up

- add codex-style short entries later
- add one test room per enemy rule
