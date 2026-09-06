# Project Overview — Working Title: "Missile Rider"

*Version 3. Supersedes v2. This revision adds the exploration and travel model, narrows the Target Experience pressure rule, and corrects the overworld framing from Mount & Blade to Escape Velocity. Changes are recorded in `decisions/`.*

## The Problem

Space games are enticing and almost impossible to get right. The recurring failure modes, observed across the genre and confirmed by community sentiment:

1. **Realism kills exploration.** Space is absurdly large and empty. Games that model this honestly (Starfield) end up replacing travel with forced fast-travel, destroying the feeling of exploration that is the genre's cornerstone.
2. **Full 3D combat is unreadable.** First-person 6DOF dogfighting produces chaos: targets whiz past faster than players can track, dodging is impossible, and situational awareness collapses. This is a structural tension, not an implementation bug — it appears independently across studios.
3. **Vector-thrust physics are unintuitive.** Realistic Newtonian flight (Escape Velocity, Elite with flight-assist off) is elegant but alienating to modern players. Intuitive controls matter more than fidelity.
4. **Ship building has no payoff.** Starfield's ship builder is its best feature, yet upgrades are stats on a sheet — nothing you build changes what your hands actually do.

Every successful space game cheats around the 3D interception problem in one of three ways: flatten the world (Rebel Galaxy's 2D plane), flatten the player's task (Star Fox's rails), or assist the controls (Elite's flight assist). None of them solve combat and exploration with the same idea.

## The Thesis

**Starsector's world with Star Fox's hands.**

More precisely, and closer to the actual lineage: *what if Escape Velocity had real faction wars with territory that changes hands, persistent fleets, a functioning economy, combat that replaced vector thrust with something still skill-rewarding in real time, and ship building that changed what your hands do.*

A living faction-war overworld paired with a visceral, accessible, novel combat system that no existing game in that lane has: the player pilots the *munitions*, not the ship.

## Target Experience

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

## Core Design Pillars

### 1. Ships are taxis *by choice*. Missiles are your hands.

The mothership can be flown manually — first-person or close third-person — and this is the primary mode for exploration and for positioning before a fight. Autopilot is a **delegation the player elects**, not a permanent condition. Commanding at the intent level frees the player's hands for another station; it is never imposed.

Autopilot is deliberately tuned to be *safe and adequate*: it holds range, it doesn't die, it never embarrasses you. Manual flight is how you get the launch geometry that makes a difficult shot possible. If autopilot were as good as manual, manual flight would be decoration.

The piloting fantasy relocates to where physics says it belongs: munitions are fast, ships are slow, in real naval warfare too. Realism and fun pull in the same direction for once.

- **Missile riding:** Fire a missile along the ship's current heading, camera switches to close third-person behind the missile, player steers it to the target while dodging slow-moving blocker/shrapnel countermeasures.
- **Fuse as range:** Missiles have a short fuse. Upgrading fuse = more range. Launch geometry varies every shot because the ship's relative position varies — procedural variety for free. Faster turn-to-target = more effective range AND higher rate of fire (skill converts directly to throughput).
- **Fuse-as-range is the load-bearing difficulty mechanic.** Firing at the edge of fuse range demands a near-perfect turn-to-target or the fuse eats the missile; firing closer is nearly free but concedes a volley. The player wagers against their own honest assessment of their hands, and the system auto-calibrates — a cautious player succeeds slowly, a confident one feels like a god. Protect this. Nothing may make max-range shots mandatory.
- **Early detonation:** Player-triggered, with splash for partial damage on near-misses. Turns a miss from binary anticlimax into a graded outcome. Splash must be steeply worse than a direct hit or it flattens the skill game.
- **Speed as skill gate:** Faster missiles are strictly better (range, RoF) but harder to fly. The upgrade tree is itself a difficulty dial the player earns the right to use. Afterburner/boost is essential to satisfaction.
- **The pitch in one line:** guiding a missile into a target is letting the intrusive thoughts win and getting rewarded.

### 2. Turret mode is the other half of the loop, not a side feature.

The player leaves the pilot seat and takes over a turret: no movement control, pure aim-and-track against ships and incoming missiles, plus deploying blocker shrapnel to disrupt enemy missiles.

Turret mode exists to solve the pacing problem that a missile-only game would have. The intended rhythm:

> steer into effective range → set autopilot → fire the missile (the heavy hit) → ride it → return → work the turret while the launcher reloads → fire again

**Cooldown governs rhythm; ammo governs endurance.** These are separate levers and must not be collapsed:

- *Cooldown* (~15–25s, upgradeable) guarantees the alternation and makes a wasted long-range shot sting immediately and concretely — you spend the reload on the gun thinking about it. It is legible in the moment and never punishes the player for playing the game.
- *Ammo capacity* (upgradeable) operates at a coarser grain — generous enough that no one hoards within a single engagement, tight enough that a long expedition without resupply is felt. This makes ammo a **logistics pressure on the travel layer**, not a combat-turn decision.

Scarcity of a fun mechanic reliably produces hoarding. If players routinely end fights with missiles unspent, the design is telling them the best mode is a mistake to use. Cooldown is the primary lever for that reason; ammo is tuned generously by default.

**The interrupt.** Occasionally the enemy launches at *you* — loud, telegraphed, unambiguous — and the player abandons or hastily detonates their missile and returns to the turret to intercept. This is the intended shape of stress: punctual, single-focus, resolvable. Two rules:

1. Frequency is a tuning parameter, and the good value will be **surprisingly low**. Rare enough to be a highlight; common enough and it becomes the "never where I need to be" feeling this design rejects.
2. It must be *possible to win both* — a player close enough and fast enough detonates on target and still makes the turret in time. The interrupt is an opportunity to show off, not a tax for being in the missile. The skill ceiling absorbs the stress instead of the player.

### 3. Space is one continuous place. One verb, three scales.

**There is no travel mode.** No hyperspace, no jump animation, no map layer you play on, no loading screen wearing a costume. The player points the ship and burns, and the same stick does the same thing whether they are threading a fight, crossing a system, or running a gap between systems. Every scale is the same physical space at a different throttle setting.

This is the single organizing decision of the exploration layer, and most of what follows is a consequence of it.

**Speed is a continuum, not a tier list.** Engines upgrade continuously; there is no drive tech that gates a category of destination. Speed is contested by mass — a larger cargo hold is slower, so the hauler and the courier are different ships and neither is upgrading toward the other. This generates a decision on every trip (sell more, or beat the other merchants to a temporary high-demand market) where a tech gate would generate one decision, once.

Regions therefore gate themselves *softly*: a distant cluster is reachable at hour two, but the crossing is long, the fuel cost is real, and you arrive with no standing and no contacts. The door is open and the world tells you *not yet*. This is the Morrowind gate, and it is more consistent with fixed-difficulty regions than a tech unlock would be — a tech unlock is a menu wearing an engine's clothes.

**Systems are discs.** Each system is a self-contained, origin-local arena shaped like a disc: substantial vertical room, but a ceiling and floor much closer than the diameter. The vertical is not decoration — combat occupies a thin slab, so *height is the sneak dimension*. Coming in on a high arc and dropping onto a target from above the engagement layer is a real approach option that costs nothing to support because the space already exists.

**Boundaries differ by surface.**

- *The flat faces* (ceiling and floor) are hard boundaries. There is genuinely nothing up there, ever. Bannerlord's solution applies: the out-of-bounds volume is visibly red, entering starts a telegraphed timer, damage ramps if the player doesn't return, and maximum velocity is scaled down in the outbound direction so nobody drifts far into it. The clamp scales magnitude only, never direction — the stick still does what the player asked; the ship just feels like it's straining.
- *The rim* is not a boundary. Flying laterally out of a system **is** departure — the transit lane between systems is continuous with the system itself. There is no threshold to cross.

Bounds apply to the player only. NPCs avoid the volume rather than being ejected from it, which makes a brief dip a legitimate tactical option (break contact, reposition, eat some damage) while ramping damage makes camping non-viable.

**Planets use an approach envelope, never auto-steer.** Taking the stick away from a player is one of the most irritating things a flight game can do, and the fiction never rescues it. Instead, entering a planet's approach envelope commits to a short, clearly signposted landing sequence — approach vector acquired, brief countdown — abortable on any input, which returns the ship to its original vector. The envelope always resolves before the surface is reached, and it doubles as the landing UI. Combat spilling into the envelope is *good*: missiles cratering into a planet gives fuse-as-range a spatial dimension.

**The galaxy is largely flat.** Systems sit roughly on a plane with some height variance between them, which keeps the top-level map readable while leaving the vertical live where it matters — inside a disc.

**Autopilot is a heading hold, nothing more.** It keeps the nose pointed at a distant object. The player still owns the throttle. It does not path, does not avoid, does not "arrive." It composes with everything and overrides nothing, and it cannot gate content because it never had authority the player didn't hand it.

The delegation contract is identical to combat autopilot at a different scale: **set a heading and walk away and you arrive safely, but blind.** What inattention forfeits is everything you would have seen along the way. It never forfeits safety. Fly it yourself and the anomalies, derelicts, and unlisted contacts on the route are there to divert toward — the blue blip is the system you set out for, the gray blip off to the right is why you came.

*Open: what a gray blip actually contains. Charts and faction intel are the leading candidate, since information feeds reputation-gated progression without an XP bar and makes the war legible from outside. Not decided.*

**Fuel is a range budget, not a needle.** Fuel is spent by the route, which makes tankage a real fitting decision traded against cargo space — peace of mind costs you hold. Running dry must be recoverable, never a softlock: the specific failure to avoid is being broke and stranded with the money to fix it sitting somewhere the fuel would have taken you. Rescue is expensive and embarrassing, and the encounter is a fine place for genre color (the helpful merchant who is sometimes a pirate springing a trap — and whose fuel you take if you win).

**Legibility before commitment.** A soft gate is only a gate if the player can see the cost while deciding. Travel time and fuel cost must be visible at the moment the player would point the ship, not discovered thirty minutes in. The same applies to danger: a hot corridor the player cannot identify in advance is not a route choice, it is a punishment for not knowing.

### 4. Danger is terrain. Travel through it is a gauntlet, not an ambush.

**No interdiction, ever.** Cruise is never dropped by an NPC's decision, and — this is the correction that makes the rest work — **not by taking damage either.** "Drops on damage" is interdiction with an extra step: any pirate with a long-range gun stops the player. Cruise drops on player input alone.

The consequence is the point. Traveling through hostile space does not stop you; it **costs** you. Cross the contested corridor and arrive scraped up, or route around and pay in time and fuel. Dangerous regions become terrain — expensive to avoid, costly to cross — which is the fixed-difficulty-region pillar expressed spatially instead of as a label.

**Cruise-speed combat is a dodging game, not a shooting one.** At transit speed nobody aims meaningfully, including the player. What the player does is *steer*: thread the picket, pick the line, read the threat. That is Star Fox, and it is the same verb at the third scale. Getting through clean is a skill expression, so the shortcut through the hot lane is available to a good pilot and unwise for a cautious one — another self-selected difficulty dial.

This implies the texture of what's out there: hitscan and static hazards. Beams, flak, mines, debris. Enemy missiles cannot catch a ship at cruise, which falls out of the existing speed hierarchy rather than needing a rule.

**It is where hired crew pays off outside set-piece combat.** The player steers; the gunners shoot back. One job, whole attention, and the summoner build gets a moment in exploration instead of only in fights.

**Damage degrades, it doesn't interrupt.** Sustained fire reduces top cruise speed, which lengthens exposure — a visible tightening the player can read and act on. A heavily defended corridor can genuinely bring a ship down, but gradually, on a legible curve, with turning back available the whole way. That is a wager going wrong rather than an ambush.

It is also a build axis. Faster means less total exposure but less reaction time to thread anything; armor competes with cargo. The courier and the hauler experience the same corridor differently, for free.

**Stopping in dangerous space is the dangerous act.** The drive will not spool with a hostile inside a set radius. This is a law of the world, not an agent's decision — legible, learnable, avoidable by giving hostiles a berth, and resolvable by breaking contact. That distinction is the whole reason it is admissible where interdiction is not. Two tuning constraints keep it honest: the radius must be small enough that a wide berth genuinely works, and enemies must not chase far enough to re-establish inhibition indefinitely.

**Fleeing is always available, and never free.** The player who can always leave is the accessibility promise working as intended. What escape forfeits is the objective, because threat sits on value — you are not fleeing a fight, you are fleeing the station you meant to dock at, the lane you were hauling through, the planet you meant to land on. Fuel spent getting there is spent either way, so aborting deep costs more than aborting early; abandoned contracts cost standing. Both bite the flee-everything player specifically without touching combat.

*Note: the flee-everything player is not a design failure to be closed off. They get bored, which is self-correcting, rather than stuck, which is not.*

### 5. Threat sits on value, not on coordinates.

Enemies occupy what the war is currently about: stations, trade lanes, the approaches to inhabited planets. This gates access to a destination in proportion to how much that destination matters, and leaves the backwater open — which is more interesting than uniform gating.

It also produces the danger gradient that fixed-difficulty regions need, lets the living world express itself positionally rather than through a menu, and means an invasion is happening *around* the player at arrival instead of parked somewhere static.

**Spatial commitment does the pacing work.** If the valuable things sit deep in the disc and the player enters at the rim, going for a defended planet means a long run back out under fire. The player feels the commitment accumulating as they travel inward. A shallow raid and a deep one are genuinely different risk profiles without anything being tuned.

### 6. The ship is a place, not a stat sheet — arrived at incrementally.

Install a turret in the ship builder → eventually, physically climb the ladder to it. The reward for building your ship is inhabiting what you built. This is the unclaimed synthesis: Void Crew has walkable crewed ships but preset hulls; Starfield has a deep builder but no felt payoff.

**This pillar rolls out in stages, each contingent on the last proving out:**

1. A flat list of installed mods — ship, missile, and turret upgrades
2. An actual builder
3. Distinct cockpits per role, with instant "teleport" switching between jobs
4. Walkability — only if everything above works and the payoff is real

Upgrades must change what your hands do (dodge-thruster on missiles, turret traverse arcs), not just numbers. Stages 3 and 4 are the expensive ones and are explicitly unvalidated; do not treat them as committed.

**Cruise design must not acquire a dependency on stage 4.** "Set a heading and go do something else on the ship" is satisfied by stage 3's instant station switching. Walking there is a later, separate bet.

### 7. Crew, and the two supported fantasies.

The player chooses, at any time, which station to occupy — and hires NPCs for the rest. Both of these must be first-class, viable ways to play:

- *"I want four excellent turrets and four skilled gunners, and I'll pilot while they wreck everything."*
- *"I'll pilot to get the range, switch to the turret, switch to the missile, then back to the helm because I want more control than the autopilot gives me."*

**Competence ceiling.** NPCs are worse than an engaged player at *every* station, gunners included (ADR 0058) — the best affordable gunner is roughly a mediocre player, and by the time you can afford one you have improved past it. Crew is convenience, never superiority. NPC missile use is dumb fire-and-forget with a mediocre hit rate, permanently. A manually flown missile is the one thing in the universe nobody can do for the player. This preserves both fantasies: the summoner build is viable and pleasant, and hands-on is stronger.

*Parked: generated crew dialogue.* The risk is not generation quality, it is authority — a world with real state produces generated lines that drift from it, and players catch that instantly and prefer repetition. If revisited, the workable shape is generation over a tightly-specified state snapshot, flavor only, with anything load-bearing authored. Not before the world sim can describe itself.

### 8. Progression through reputation, not XP.

No level trees. Faction standing gates access to upgrade catalogs; deeper standing improves prices ("they let me buy tier one, but I'm not trusted yet so I pay a premium"). Access and cost are independent dials. Factions have different upgrade *philosophies* (heavy reliable Confederation missiles vs. twitchy pirate ones vs. weird research-faction modules), so faction choice IS build choice. Lineage: Escape Velocity, Elite's naval ranks, Freelancer.

Cooldown upgrades and capacity upgrades sit on different axes — *throughput* vs. *endurance* — and factions can have opinions about which they sell.

*Open: whether standing travels between clusters.* Since distance is now a soft gate rather than a tech gate, a player can arrive somewhere distant early and find themselves at zero. Reputation known at range, factions with cross-cluster reach, or a genuine reset that makes emigration a real commitment — any of these work. It should be chosen, not defaulted into.

### 9. Fixed-difficulty regions. No level scaling. Ever.

The map dictates difficulty (Gothic/Morrowind/Elden Ring school). Players earn the ability to become gods in low-danger regions — that power trip is the payoff, not a balance bug. Dangerous content lives on the fringe with alien factions; the player starts in a faction's safe interior, away from border wars.

**Architectural constraint:** because territory changes hands, difficulty must be a property of factions and their fleets, not of map coordinates — the bands move with the war.

**Accessibility constraint:** walls must be *skippable*, not merely beatable. The lesson of Skyrim's reach versus Elden Ring's is not that Skyrim is easier — it is that Skyrim forgives disengagement. A player who whiffs six missiles in a row must still be making progress, still have a fallback (the turret, hired gunners, a softer target elsewhere, a longer route), and must never hit a gate that says *get better at this specific thing or stop playing*.

**The safe-start tension.** The player begins in a quiet interior while the war runs whether they participate or not. If the early game is entirely insulated, the player may first encounter the war already resolved. Either the starting region needs a contested edge visible from safety, or war tempo must be cyclical rather than terminal. Probably both.

### 10. Living overworld.

Dynamic alliances, systems genuinely taken and lost through wars and campaigns, running whether the player participates or not.

**Correction from v2:** this was previously framed as "Mount & Blade's overworld model applied to space," which was wrong and load-bearing enough to have misdirected design work. M&B's campaign map is a place you *act* — parties intercept you, army size trades against speed, sieges happen on it. That map exists to make army logistics a decision. This game commonly fields 2–5 ships and a couple dozen at the large end; there is no logistics layer to model, and without one the map is a slow menu.

**The correct lineage is Escape Velocity.** The starmap is a planning and information UI. All actual play happens in a ship, in real space. Since travel is continuous and real-time, *the campaign clock is carried by travel itself* — the war advances while the player is flying to it, and they arrive at a board that changed for reasons they can feel rather than watch a counter report.

Starsector proves the faction sim; its combat is top-down tactical and its overworld is where the game is played, which is exactly the inversion this design rejects.

Critical presentation requirement: invasions must be *witnessed*, not reported. This is now largely free — a system **is** the arena, so there is no combat venue to drop into and no transition to hide. The player arrives and the battle is where they are.

Void Crew's most cited weakness among solo players is that its world felt empty and lifeless. Consequence-bearing faction activity is the antidote, and it is why this pillar exists despite being unnecessary for combat to function.

## Prior Art & Differentiation

| Game | What it proves | What it lacks |
|---|---|---|
| Escape Velocity | **Primary lineage.** Faction-gated progression, witnessed invasions, starmap-as-UI with all play in-ship | Vector thrust too unintuitive for modern players; no persistent territory war; thin economy |
| Starsector | Living faction sim works in space | Combat is top-down tactical and cerebral; the overworld is where you play, not where you plan |
| X4: Foundations | Real-time faction wars taking sectors | Personal combat is its weakest system |
| Mount & Blade | Overworld generating battles you fight with your hands | Its map model is army logistics; does not transfer to a 2–5 ship game |
| Rebel Galaxy | Continuous real-time cruise across a world with no jump abstraction | Locked to a lateral plane; interdiction pulls you out of cruise |
| Void Crew | Walkable crewed ship, turret roles, solo autopilot mode | Preset hulls, no builder, no missile riding; solo widely reported as the weak mode |
| Star Fox | Automated navigation + timing-based defense feels great | On-rails, no open world |
| Descent (guided missile) | Closest combat ancestor. Fly-by-wire munition with a chase cam is durably beloved | A specialty tool used from cover, not a combat system |
| Battlefield (TV missile) | Real skill curve — hours to master, instant kill once mastered | A single vehicle gadget; balance-hostile in PvP |
| Unreal Tournament (Redeemer) | Piloting a munition is universally delightful | A moment, never a whole combat system |
| Missile Pilot (2024, Steam) | Someone shipped missile-flying as a whole game | Tiny arcade runner, linear levels, no world |
| American/Euro Truck Simulator | Travel as content sustains hundreds of hours | — |

**On travel as content.** ATS works because the player is performing the core verb continuously — the road *is* the game. That endorses steerable travel with things to find along the route. It does *not* endorse a non-interactive transit with activities bolted on, which is a lounge attached to a loading screen and decays badly by hour sixty. Fast travel did not kill exploration in Oblivion by being instant; it killed it because the space between was empty, so instant was strictly better. Fill the space, and no one asks for the button.

**The vulnerability lesson from prior art, and why it does not apply here.** Player-guided missiles are conventionally balanced by leaving the player's own vehicle exposed while they fly — that cost is what makes the mechanic a wager. This design supplies the same cost *without* ambient danger: every second in the missile is a second not on the gun. That is opportunity cost, it is legible, and it is chosen.

Nobody has paired a living faction-war sim with combat this visceral and accessible. That pairing is the identity.

## Creative Direction

This is a game built because its author wants to play it, not one assembled from aggregate preference data. Design assembled from market fit produces mush, and "you pilot the munitions" is exactly the kind of idea a market-fit analysis talks people out of.

Research, prior art, and community sentiment are inputs for identifying *failure modes others have hit and why*. They are not inputs for deciding what feels good. Feel verdicts, and creative direction generally, are human-only — this is the same principle as the feel-parameter law in `CLAUDE.md`, applied one level up.

## Development Approach

- **Engine:** Godot 4.x, native on Linux. Entire project (scenes, resources, scripts) is plain text in the repo — the model can read the whole game like a codebase.
- **AI-heavy workflow:** Claude Code owns systems (faction sim, economy, missile physics, autopilot, tooling). All heavily LLM-native territory, all headlessly testable.
- **Feel stays human:** Every tunable (turn rates, fuse times, camera lag, boost curves, easing, cooldowns, interrupt frequency, cruise speeds, spool times) lives in externalized hot-reloadable data files. AI builds the instrument; the human plays it. Never let feel-values live inside AI-authored code.
- **Coordinate strategy — floating origin.** Continuous travel means large coordinates, and single-precision floats visibly degrade in the tens-of-kilometers range (jitter in physics, camera, and particles — it will show up first as missile flight feeling subtly wrong far from origin). The world recenters on the player and everything else shifts. This avoids compiling an experimental double-precision Godot build, but every system that stores a position must respect it, so it is an early architectural commitment and painful to retrofit.
- **Distant-object LOD.** Planets and stations render as background-layer objects that scale with distance and swap to real meshes on approach. Two rules: the swap must occur where apparent size change is sub-pixel (a second camera at compressed scale, real mesh spawning where the two agree), and **only the real object has collision** — the background layer is visual only, with no physics body and nothing queryable.
- **Repo as source of truth:** DESIGN.md + ADRs capture decisions and reasoning; AGENTS.md/CLAUDE.md pins conventions. Parallel work streams read from the same context.

## Open Questions

Carried deliberately, not forgotten:

1. **The numbers chain.** Engagement envelope → disc height → cruise speeds → system diameter, sized in that order; each mostly determines the next. Disc height should be set at roughly 5–10× the largest engagement envelope so the ceiling never enters a fight, with diameter falling out afterward. The height:diameter ratio is an *output*, not an input.
2. **What a gray blip contains,** and therefore what exploration rewards. Information is the leading candidate.
3. **Blip density authored against travel time, not distance** — otherwise long gaps are empty and system crossings are cluttered. Long hauls specifically need sparse, high-value finds, or the biggest commitments become the least interesting.
4. **Whether reputation travels between clusters.**
5. **Whether the starting region has a visible contested edge,** and whether war tempo is cyclical.
6. **Cruise-combat hazard vocabulary** — how much of the gauntlet is static (mines, debris) versus emplaced (beams, flak), and how a corridor's heat is communicated before entry.

## Sequencing

1. **Combat POC first — it is the bet.** The loop under test is missile *and* turret, not missile alone. See `COMBAT_POC_IMPLEMENTATION.md`. Exploration is deliberately absent from it.
2. **Exploration prototype second, and it is a separate bet.** Cruise feel, the gauntlet, and whether a gray blip is worth diverting for are all feel questions that a combat POC cannot answer.
3. **Overworld design in parallel (cheap), implementation contingent.** Design thinking in chat; validation via headless faction-war sim at 1000x speed (does one faction snowball? does the map reach boring equilibrium?) before anything visual is built.
4. **Ship-as-place in stages,** per Pillar 6, each stage gated on the previous one earning its cost.
