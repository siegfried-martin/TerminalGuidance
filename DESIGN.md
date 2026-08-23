# DESIGN.md

**Living document.** The distilled design thesis, so any session has the *why*
without re-litigating it. Source of record is `docs/PROJECT_OVERVIEW.md`; this is
the working extract. Where they disagree, the overview wins and this file is stale
— fix it.

Decisions with reasoning and dates live in `decisions/`. Rules that constrain code
live in `CLAUDE.md`. Current build state lives in `STATUS.md`.

---

## The thesis

**Starsector's world with Star Fox's hands.**

Closer to the actual lineage: *what if Escape Velocity had real faction wars with
territory that changes hands, persistent fleets, a functioning economy, combat that
replaced vector thrust with something still skill-rewarding in real time, and ship
building that changed what your hands do.*

A living faction-war overworld paired with a visceral, accessible, novel combat
system that no existing game in that lane has: **the player pilots the munitions,
not the ship.**

The pitch in one line: *guiding a missile into a target is letting the intrusive
thoughts win and getting rewarded.*

### The problem it answers

Every successful space game cheats around the 3D interception problem in one of
three ways — flatten the world (Rebel Galaxy), flatten the player's task (Star
Fox), or assist the controls (Elite). None of them solve combat and exploration
with the same idea. This design does: **munitions are fast, ships are slow**, which
is also true in real naval warfare, so realism and fun pull the same direction for
once.

---

## Target Experience

> **Reproduced verbatim from `docs/PROJECT_OVERVIEW.md`.** This section governs
> every design decision below it. When a proposal conflicts with it, the proposal
> loses. It is the section most likely to erode silently across sessions, because
> pressure mechanics look like good design when evaluated one at a time. Do not
> paraphrase it here; re-copy it if the overview changes.


This section governs every design decision below it. When a proposal conflicts with this section, the proposal loses.

**Relaxed mastery, not tension.** The audience is the sim/sandbox player — Bannerlord, Starsector, X4 — not the action-game player. That audience's pleasure is accumulation expressed as dominance, not adversity. They are not seeking a challenge to overcome; they are seeking a world to become powerful in. Default tuning biases toward power fantasy.

**Pressure is a decision the player made, never a condition imposed on them.** This is the governing rule, and it replaces the broader v2 prohibition on "resource anxiety," which was too wide — it forbade good systems (fuel as a route-planning budget) alongside bad ones. The test is not whether a system creates pressure. It is whether the player chose it, could see the cost before committing, and can unmake the choice.

- **Passes:** fuel spent on a route you plotted; cargo mass traded against speed; flying into a contested corridor because the shortcut was worth it; the opportunity cost of every second in the missile being a second off the gun.
- **Fails:** being pulled out of cruise by an NPC's decision; unattended systems degrading while you're busy elsewhere; ambient dread with no avoidable cause; anything that demands the player attend to two things at once.

**Stress is a spike, never ambient.** Punctual, loudly telegraphed threats that demand a single focused response are good. Continuous background dread is a failure state.

**Pressure comes one job at a time.** The player's attention is sequential, never parallel. This is the structural lesson of the RTS→MOBA transition: what broadened that audience was not reduced difficulty or lower stakes, but the removal of the demand to manage several fronts simultaneously. Every job in this game — pilot, gunner, missile — gets the player's whole attention while they are in it.

**The player is always the difference maker.** Hired crew is convenience, never superiority. No build, automation, or upgrade should outperform an engaged human at the same station.

**Difficulty is selected by the player through mechanics, never through a menu.** All dials are player-controlled and diegetic:

- *Fuse-as-range* — the player sets their own risk on every single shot
- *Crew hiring* — delegate the jobs you don't enjoy
- *Fixed-difficulty regions* — geography is the slider
- *Missile speed upgrades* — an optional, earned difficulty increase
- *Route choice* — cross the hot corridor or go around and pay in time and fuel

The cautious setting must remain **viable, not merely possible**. If winning requires max-range shots, the dial is decorative. Playing it safe should be slower, never failing.

**Build for depth, tune for accessibility — in that order.** Default difficulty is a late, reversible edit to a tuning file. Depth is an early architectural commitment. A deep system can always be made gentler; a shallow one cannot be made deep. The threat model for this genre is not "bounced off in hour one" — sandbox players invest hundreds of hours — it is **boredom at hour thirty**. Set the floor gentle. Keep the ceiling high. These are not in tension.

---

## The pillars, distilled

Full text in `docs/PROJECT_OVERVIEW.md` §Core Design Pillars. This is what a
session needs in working memory.

**1 — Ships are taxis *by choice*. Missiles are your hands.**
The mothership can be flown manually, and that is the primary mode for exploration
and for positioning before a fight. Autopilot is a delegation the player elects,
tuned to be *safe and adequate* — it holds range and never embarrasses you, but
manual flight is how you get the launch geometry that makes a hard shot possible.
Fire a missile, the camera cuts to close third-person behind it, and you steer it
in while dodging blockers.

**Fuse-as-range is the load-bearing difficulty mechanic.** A short fuse caps range;
upgrading the fuse extends it. Firing at the edge of fuse range demands a
near-perfect turn-to-target; firing close is nearly free but concedes a volley. The
player wagers against their own honest assessment of their hands, and the system
auto-calibrates. *Protect this. Nothing may make max-range shots mandatory.*

**2 — Turret mode is the other half of the loop, not a side feature.**
The intended rhythm: steer into range → set autopilot → fire → ride it → return →
work the turret while the launcher reloads → fire again. **Cooldown governs rhythm;
ammo governs endurance.** They are separate levers and must not be collapsed.
Scarcity of a fun mechanic produces hoarding, so cooldown is the primary lever and
ammo is generous by default.

**3 — Space is one continuous place. One verb, three scales.**
No travel mode, no hyperspace, no jump animation, no loading screen in a costume.
The same stick does the same thing threading a fight, crossing a system, or running
a gap between systems. Systems are **discs** — substantial vertical room, ceiling
and floor much closer than the diameter, so *height is the sneak dimension*. The
flat faces are hard boundaries; the rim is not a boundary, it is departure.

**4 — Danger is terrain. Travel through it is a gauntlet, not an ambush.**
Traveling through hostile space does not stop you; it **costs** you. At cruise
speed nobody aims meaningfully — the player *steers*: thread the picket, pick the
line, read the threat. Damage degrades top cruise speed, which lengthens exposure
on a curve the player can read and act on.

**5 — Threat sits on value, not on coordinates.**
Enemies occupy what the war is currently about: stations, trade lanes, approaches
to inhabited planets. Access to a destination is gated in proportion to how much
that destination matters, and the backwater stays open.

**6 — The ship is a place, not a stat sheet — arrived at incrementally.**
Staged, each contingent on the last proving out: (1) a flat list of installed mods,
(2) an actual builder, (3) distinct cockpits with instant switching, (4)
walkability. Upgrades must change what your hands do, not just numbers. **Stages 3
and 4 are expensive and explicitly unvalidated — not committed.**

**7 — Crew, and the two supported fantasies.**
"Four excellent gunners while I pilot" and "I'll fly every station myself" must
both be first-class. **Competence ceiling:** NPC gunners can be genuinely
excellent; NPC missile use is dumb fire-and-forget. A manually flown missile is the
one thing nobody can do for the player.

**8 — Progression through reputation, not XP.**
No level trees. Faction standing gates access to upgrade catalogs; deeper standing
improves prices. Access and cost are independent dials. Factions have different
upgrade *philosophies*, so faction choice IS build choice.

**9 — Fixed-difficulty regions. No level scaling. Ever.**
The map dictates difficulty. Because territory changes hands, difficulty is a
property of **factions and their fleets**, not of map coordinates — the bands move
with the war. Walls must be *skippable*, not merely beatable: a player who whiffs
six missiles in a row must still have a fallback and must never hit a gate that
says *get better at this specific thing or stop playing*.

**10 — Living overworld.**
Dynamic alliances, systems genuinely taken and lost, running whether the player
participates or not. Invasions must be **witnessed, not reported** — and that is
now nearly free, because a system *is* the arena.

---

## What this game is not

Stated because each is a genre default that will be proposed by accident:

- Not a game with a travel mode, a jump animation, or a starmap you play on. The
  starmap is a planning UI (Escape Velocity, not Mount & Blade).
- Not a game where an NPC can stop your ship. No interdiction, and cruise does not
  drop on damage either.
- Not a game with level scaling, an XP bar, or a difficulty menu.
- Not a game that takes the stick away from the player — no auto-steer, ever.
- Not a game with ambient dread, unattended degradation, or two things demanding
  attention at once.
- Not a tactical game. Starsector proves the faction sim; its top-down cerebral
  combat and overworld-as-playfield are exactly the inversion this design rejects.

---

## Creative direction

This is a game built because its author wants to play it, not one assembled from
aggregate preference data. Research, prior art, and community sentiment are inputs
for identifying *failure modes others have hit and why*. They are **not** inputs for
deciding what feels good.

**Feel verdicts, and creative direction generally, are human-only.** This is the
feel-parameter law of `CLAUDE.md` applied one level up: AI builds the instrument,
the human plays it.

When directing feel work, the useful currency is *reference anchors*, not
adjectives: "turn response like Star Fox's Arwing, not a Newtonian thruster"
outperforms "make it snappier."

---

## Sequencing

1. **Combat POC first — it is the bet.** The loop under test is missile *and*
   turret, not missile alone. See `docs/COMBAT_POC_IMPLEMENTATION.md`. Exploration
   is deliberately absent from it.
2. **Exploration prototype second, a separate bet.** Cruise feel, the gauntlet, and
   whether a gray blip is worth diverting for are feel questions the combat POC
   cannot answer.
3. **Overworld design in parallel (cheap), implementation contingent.** Validate
   via a headless faction-war sim at 1000× before anything visual is built.
4. **Ship-as-place in stages,** each gated on the previous one earning its cost.

## Open questions

Carried deliberately, not forgotten. Full text in the overview.

1. **The numbers chain.** Engagement envelope → disc height → cruise speeds →
   system diameter, sized in that order. Disc height ≈ 5–10× the largest engagement
   envelope. The height:diameter ratio is an *output*, not an input.
2. **What a gray blip contains,** and therefore what exploration rewards.
   Information (charts, faction intel) is the leading candidate.
3. **Blip density authored against travel time, not distance.**
4. **Whether reputation travels between clusters.**
5. **Whether the starting region has a visible contested edge,** and whether war
   tempo is cyclical.
6. **Cruise-combat hazard vocabulary** — static versus emplaced, and how a
   corridor's heat is communicated before entry.
