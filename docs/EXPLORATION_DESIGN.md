# Exploration Design — The Highway Network

*Version 1. Companion to `PROJECT_OVERVIEW.md`. Governs the travel layer between and within systems.*

*This document is subordinate to the **Target Experience** section of `PROJECT_OVERVIEW.md`. Where anything here conflicts with that section, that section wins.*

---

## The Problem This Solves

The travel layer has to satisfy four things that pull against each other:

1. **Vastness.** The map must feel large. This is the genre's cornerstone and the reason Starfield's fast-travel is a failure.
2. **Population.** The player must meet other ships regularly, or the world reads as empty — Void Crew's most-cited weakness.
3. **Directness.** A player who just wants to get from A to B must be able to, without ceremony.
4. **Renderability.** A solo developer cannot author or stream an honestly-scaled star system.

A road network satisfies all four with one idea. Roads concentrate traffic (population), leave the space between them empty (vastness), are the direct route by construction (directness), and bound what must be rendered at any moment (renderability).

**The lineage is Freelancer's trade lanes**, which demonstrated this working. The differences: Freelancer's lanes were an on-rails conveyor with no steering and no route choice. Here the road is something you **pilot**, with lane position, overtaking, and curvature.

**The cautionary lineage is X Rebirth**, whose highways were widely disliked. The failure modes, and how this design avoids each:

| X Rebirth / X4 failure | Avoided by |
|---|---|
| Impervious conveyor; no agency | Player steers; lane position and overtaking are live |
| Highways redundant with personal travel drive | Cruise drive works **only** on the highway; there is no personal equivalent |
| AI pathfinder ignores highways; roads sit empty | NPC traffic is authored onto roads as a first-class spawn source, not an emergent pathfinding result |
| Blue strips read as unmotivated | Roads are faction infrastructure with visible ownership, construction, and decay |

---

## Locked Decisions

These are settled. Do not re-litigate them; raise a flag if implementation reveals a contradiction.

### Structure

- **The road network is a 2D graph presented on a map, realised as 3D tubes in space.** The map is the planning layer; the tube is the driving layer.
- **Lanes are one-way.** Each direction is a physically separate deck. There is no oncoming traffic in the player's lane.
- **The two decks are stacked vertically**, upper and lower, visible to each other. From outside, a road reads as one square-ish structure divided into two halves with streaks running opposite ways.
- **Deck convention:** headings in the arc running clockwise from northwest through north, east, to southeast ride the **upper** deck. Everything else rides the **lower** deck. The mnemonic is *heading into the upper-right half of the map means the upper deck*.
- **Deck assignment is a property of the authored road segment**, not a runtime function of heading. See *Enforced Invariants* below.
- **Cross-section is wide and flat**, matching monitor aspect, ship proportions, and the locked-roll control scheme. Shape is a rounded lozenge rather than a rectangle, so no boundary edge is dramatically nearer than another.
- **The lane boundary is soft.** Drifting out slows the player and pushes them back. It is an incentive, not a wall, and never a hard stop.
- **Junctions do not exist.** Route choice happens at portals. Exits are frequent enough that a missed turn costs one hop off and back on in the other direction.

### Access and propulsion

- **Cruise drive is a separate engine with its own fuel source.** It works only on the highway, and it is mandatory there. There is no personal cruise equivalent for open space.
- **Fuel is tracked only for cruise.** Normal flight is free. Running out of cruise fuel means *slow*, never *immobilised*.
- **Portals are the only way on and off.** A portal is a large square structure, unmissable, in shimmering material carrying the name of the system it leads toward. Two portals are stacked at each site, one per direction, so which is which is visible before entry and matches the map.
- **Portals open automatically for anyone entitled to use them.** Drive in. No docking sequence, no menu, no request-and-wait. Entry latency is a design constraint, not a visual choice — see *Two-Tier Network*.
- **Faction-owned portals deny access to those who have broken that faction's laws.** This is a designed consequence of the reputation system, not a lockout: pirate and unaligned gateways exist and serve the outlaw playstyle.
- **Portals exist in deep space as well as in systems**, including roads that dead-end at portals under construction. Deep-space exit points are among the more dangerous places in the game.

### Safety

- **Weapons are disabled on the highway.** This is a rule of the road, not emergent NPC behaviour. It is what makes the highway a sanctuary bounded only by fuel.
- **There is no interdiction anywhere in the game.** Nothing pulls a player out of cruise. This includes anything that would achieve the same effect under a different name.
- **Collisions glance off. No collision damage.** Deferred; may be revisited.
- **No minimum speed and no shoulder.** A stopped ship is an obstacle traffic routes around, not a hazard.
- **Consequences live at the exits.** Customs, blockades, and waiting guards are legitimate — provided they are visible on the comms network *before* the player commits to that exit. A surprise force on arrival is interdiction wearing a uniform.

### Presentation

- **The camera is fixed to the road's direction while in cruise**, with a limited maximum turn angle off the road axis.
- **Roads curve, climb, and descend.** This is load-bearing, not decoration: a clamped heading on a straight road is a screensaver. Curvature is what makes the clamp acceptable and is the primary source of driving demand.
- **The lane is visually open.** Markers, lights, and structure define it, but the player can see out into the system and the space around them. An opaque tunnel would convert the living overworld from *witnessed* to *reported*, violating Pillar 7.
- **Events happen beside the road, never on it.** A battle visible off to one side, which the player may choose to exit and join, is the intended shape. The road is a vantage point on the war, not a tunnel away from it.
- **The comms network** carries chatter, distress calls, and exit alerts. All of it is opt-in information. None of it forces an encounter.

---

## The Speed Ladder

All speeds derive from **missile base speed**, which is the one value validated in the combat POC. Every number below is a **starting position**; all of them become equipment properties.

| | Ratio | m/s | vs taxi |
|---|---|---|---|
| Highway cruise | fighter × 2–3 | **~97** | 6.2× |
| Missile | — | **58** | 3.7× |
| Fighter | missile ÷ 1–2 | **~39** | 2.5× |
| Taxi / merchant / capital | fighter ÷ 2–3 | **~15.5** | — |

Consequences that fall out of these ratios rather than being imposed:

- **Missiles are anti-capital weapons.** At roughly 1.5× fighter speed, a missile struggles to run down a fighter that turns well. Fighter-versus-fighter resolves to guns. A missile kill on a fighter is a skilled player's flex, not a mechanic.
- **Turrets are the anti-fighter answer.** This gives the two weapon systems a clean division without a rule enforcing it.
- **Capitals cannot outrun anything.** Which is correct.

---

## Two-Tier Network

A sub-minute hop to a neighbouring system and a map that feels vast cannot both be true on a single-tier network. Two tiers make them compatible.

| | Distance | Highway | Fighter alone | Taxi off-road |
|---|---|---|---|---|
| **Local leg** (within group) | ~4 km | 41 s | 1.7 min | 4.3 min |
| **Trunk leg** (group to group) | ~40 km | 6.9 min | 17 min | 43 min |
| **System diameter** | 3–4 km | — | ~1.5 min | ~4 min |

### What each tier is for

**Local roads are plumbing.** Short, straight, unremarkable. At 41 seconds there is no room for an encounter, a convoy, or a story. Their interesting content lives at the **portals** — fuel, market, customs, mission board, the bar. Portals carry more of the local experience than the roads do and deserve art and design attention out of proportion to their size.

**Trunk roads are the road-as-place.** Long sight lines, curvature, traffic density, convoys, overtaking, battles visible off to the side. Everything the highway system exists to deliver happens here.

### Emergent properties worth protecting

- **The fighter's natural operating radius is its local group.** It covers a local leg in 1.7 minutes and crosses a system in 1.5, all without a cruise drive. Cross-group is 17 minutes, which is where paying for a taxi becomes worth it. The fighter's "in-system combat ship" identity holds without a rule enforcing it.
- **Off-road is a real choice locally and a last resort at range.** 4.3 minutes versus 41 seconds means a player can decline the road on a short hop — keeping open space genuinely usable and making cruise fuel a live decision. 43 minutes versus 7 makes the road near-mandatory cross-group. Same road, two relationships, no extra mechanics.
- **Portal entry is latency-sensitive.** Ten seconds of alignment and spin-up is 25% of a 41-second local leg. Freelancer's lane docking took a couple of seconds and players still found it grating at frequency. Entry must be near-instant or the local network reads as a chain of loading screens.

---

## Ship Classes and Progression

Progression is by **equipment slot count**. Each slot unlocks a *playstyle*, not a stat. Money and reputation sit on the same axis: high money with low standing routes to the pirate market, high standing routes to faction catalogues and prestige contracts.

| Tier | Slots | Example builds |
|---|---|---|
| 1 | 0 | Shuttle: light forward gun, 2 missiles, no boost, no dodge, no cruise drive. Light cargo and passenger work only. |
| 2 | 1 | Turret (in-system defence) · Cruise drive (scout, cross-system missions) · Fighter (speed and guns, docks on capitals) · Bomber (missiles and unguided bombs) · Cargo bay (short-haul intra-system freight) |
| 3 | 2 | Cruise + cargo (merchant) · Cruise + turret (merchant guard) · Turret + missiles (gunboat, docks on the largest capitals only) |
| 4 | 3+ | Small capitals: armed transports, small warships, all with cruise |
| 5 | many | Large capitals: crew, multiple turrets, dedicated missile gunners, large holds. Reputation-gated. |

This list is illustrative. Actual ships emerge from faction catalogues.

### Crew and station switching

- **The player switches into any crew member's station directly.** No walking, no ladders. This is the Dragon Age party-switch model applied to a ship, and it is what the first implementation of Pillar 3 looks like.
- **Autopilot is your own character flying while you are elsewhere.** It is not a system with a difficulty setting; it is a person's competence. Hiring a better pilot produces better autopilot.
- **Crew are hireable at varying skill for varying price.** This is a live money sink and a source of texture.
- **NPCs are worse than an engaged player at every station.** *This supersedes the "NPC gunners can be genuinely excellent" language in `PROJECT_OVERVIEW.md` Pillar 4.* The best affordable gunner is roughly a mediocre player; by the time the player can afford one, they have improved. The fantasy holds in both directions — the summoner build is comfortable and viable, the hands-on build is stronger.
- **Fighters carried by a capital are the top-tier expression of the fighter fantasy, not its replacement.** Owning a carrier means owning a hangar, and the player still flies the interceptor.

### Deferred

- **Commander view** — top-down system command with drop-in to any hull. A sequel-sized feature. The game ships without it.
- **Walkability** — unchanged from `PROJECT_OVERVIEW.md` Pillar 3, stage 4.

---

## Enforced Invariants

These are machine-checkable and belong in headless tests.

1. **No road segment's heading may cross the northwest–southeast divider.** A route that must turn that far is either split into two segments joined at a portal, or is authored with a **physical twist** where the two decks roll past each other. The twist is the preferred resolution: the invariant never breaks, the player watches it happen, and it makes a landmark. A test walks the road graph and asserts every segment's declared deck matches its orientation.
   - **Consequence:** long ring roads are illegal unless built as a chain of twists. X4's signature ring road could not exist here.
   - **Worldbuilding hook:** placing the two major faction capitals in the southwest and northeast corners puts trunk roads perpendicular to the divider, so ordinary traffic stays far from it and twists remain rare and special.
   - **Why enforce hard:** the convention's real value is as a mistake-catcher — *"I'm heading east, why am I on the lower deck?"* One exception and players stop trusting it, at which point it is worse than no rule.

2. **The ship speed ceiling is per hull class, not global.** `manual_speed_ceiling_fraction` currently enforces one global missile-faster-than-ship ratio. At the ladder above, a taxi is 0.27× missile speed and a fighter is 0.67×. One value cannot express both. The invariant it protects changes from *"missiles outrun ships"* to *"a missile outruns its intended targets."* Do not widen the global clamp until fighters fit.

3. **Autopilot arc speed is a fraction of the hull's own maximum, never an absolute.** POC values were 13.8 arc against 34 max. At a corrected taxi speed of ~15.5, an absolute 13.8 makes manual flight 12% faster than autopilot, which makes manual flight decoration and violates Pillar 1. Peg arc speed at roughly 0.4–0.6 of hull max so the gap holds automatically as equipment scales.

4. **Enemy drift and patrol speeds are fractions of hull class maximum, never absolutes.** POC drift was 20 m/s against a corrected taxi speed of 15.5, meaning an enemy of the same class could simply leave.

5. **Missile speed, fuse, and cooldown are per-launcher equipment properties, not globals.** Same for hull maximum speed, turn rate, and every other value currently single-valued in `tuning.cfg`. The difference between "one value" and "a table keyed by loadout with a default" is trivial now and a refactor across every consumer later.

6. **Floating origin and LOD/collision-on-real-meshes-only remain non-deferrable.** The highway does not exempt anything from these. The tube is not a loading screen and must not be built as one.

---

## Open Questions

Carried forward, not blocking.

- **Verb ceiling on the missile.** Steer, boost, brake, dodge left, dodge right, detonate is six inputs in an eight-second window. Playtesting says the current set feels good. The question is where adding another verb stops adding ceiling and starts adding fumbling. Find it deliberately rather than at missile #400.
- **Mixed magazines.** Missiles have purchasable features and no weight cost, and magazines are small. Letting the player choose *per slot* what goes in makes the magazine a loadout and the shot a commitment — a second dial in the same shape as fuse-as-range. Also solves the un-buy problem: a player who bought a complicated missile can carry a simple one alongside it.
- **Missile roll.** Ships are roll-locked with a clamped pitch. Whether the missile shares that constraint is untested. A rolling missile is more expressive; a roll-locked one is consistent with everything else. Cheap to A/B now.
- **Persisted versus procedural traffic.** Some road traffic should be persisted entities the player can meet again. Recurring faces do more for "this world is populated" than hull variety does, and it is systems work rather than art work. Design the persistence layer with this in mind rather than treating persisted ships as a performance concession.
- **Traffic visual variety.** The road's justification is that it explains why you meet people. Convoy composition, escort behaviour, and cargo-pod silhouette variation buy more perceived variety than hull count. This is a production dependency of the highway system, not a polish item.
- **Local group structure.** How many systems per group, and whether groups have their own identity, economy, or faction alignment.
