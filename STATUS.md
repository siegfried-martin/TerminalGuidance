# STATUS

*Updated 2026-08-29.*

## The project has moved to the exploration bet

The human called the combat POC a success and handed over two new documents —
`docs/EXPLORATION_DESIGN.md` (locked decisions for the travel layer) and
`docs/EXPLORATION_POC_IMPLEMENTATION.md` (the three-system test map). **Both
supersede prior decisions where they conflict**, at the human's explicit direction.
Four ADRs landed with that:

- **0057** the highway is a place, not a travel mode — supersedes 0009
- **0058** NPCs are worse than an engaged player at *every* station — supersedes the
  gunner half of 0007
- **0059** every ship number is keyed by hull class, with a shared default
- **0060** a portal opens for a cruise drive, and its colour says so

ADR 0013 is **reframed, not superseded**. Every station is a person who keeps doing
their job — worse — while the player is elsewhere, and the heading hold already *is*
a pilot doing that job. A better hired pilot is a better number, never more
authority, so 0013's bounds hold unchanged and hold harder.

**Only the pilot matters in this POC.** The exploration scene carries the helm and
the missile tube; no turret, no gunner station. This is not a combat POC.

### The speed ladder landed, and it changes combat

Everything derives from `missile/base_speed`, the one number the combat POC
validated. The player's gunboat is now **taxi class at 15.5 m/s, down from 34** —
a deliberate re-opening the human asked for ("I had thought the taxi type ships
might be too fast so we will test with the new numbers"), not a side effect.

Two absolutes became fractions, because both inverted at the corrected speed and
neither would have errored:

| | Was | Now | What the absolute would have done |
|---|---|---|---|
| `ship/arc_speed` | 13.8 m/s | `arc_speed_fraction` 0.45 | 0.89 of manual top speed — flying yourself becomes decoration |
| `enemy/drift_speed` | 20 m/s | `drift_speed_fraction` 0.45 | an enemy of the player's own class could simply leave |

`H` cycles hull class live in the combat arena, and the HUD carries a `class` row.
That is the exploration POC's step-3 roster arriving in step 1 on purpose: *"is
15.5 m/s the right taxi speed"* anchors every number downstream and is answerable
in the scene that already exists. **This is the first feel question waiting on the
human.**

### Exploration step 3 is built — the hull roster

`H` cycles **taxi → fighter → capital**, instantly, in both scenes. The classes are
three ships rather than three top speeds: turn rate, throttle travel, thruster
authority and silhouette are all per class, because a fighter that is just a fast
taxi teaches nothing about what a fighter is.

**The taxi has no rows of its own on purpose.** It *is* the shared fallback, so it
is exactly the ship the combat POC was validated on and the roster cannot disturb
it. A test asserts that.

| | Top | Turn | To full / stop | Crosses the disc |
|---|---|---|---|---|
| Taxi | 15.5 m/s | 26 °/s | 3.2 s / 2.4 s | 3.8 min |
| Fighter | 38.7 m/s | 62 °/s | 1.4 s / 1.0 s | **1.5 min** |
| Capital | 11.0 m/s | 11 °/s | 7.0 s / 6.0 s | 5.3 min |

The fighter's 1.5 minutes is the number `EXPLORATION_DESIGN.md` §Two-Tier Network
predicted for "system diameter, fighter alone" — so the ladder and the disc size
agree without either having been fitted to the other.

### Exploration step 4 is built — arriving somewhere

`ApproachEnvelope` is reusable and mounted on the planet; the same node goes on the
portals' ramp stations in step 6, which is where the fuel and market content
actually lives. Fly into it, watch a countdown, arrive. Touch anything and it hands
the ship straight back with the throttle you had.

**How ADR 0012's two rules were reconciled.** It says *"no auto-steer, ever, for any
reason, in any system"* and then *"any sequence that moves the ship must abort on any
player input"*, which reads as a contradiction. It is the same distinction the system
boundary already makes: **magnitude, never direction.** The sequence walks the ship's
speed ceiling down to zero so it comes to rest along the vector the player was already
flying, reusing `Mothership.speed_ceiling_scale` — so there is no code path in the
approach that can produce a heading. The mechanism makes the guarantee; a comment
would only have promised it.

Both the boundary and the approach constrain that same ceiling, so the scene composes
them and assigns the tightest. Two systems each writing the field would have fought,
with the winner being whichever happened to run second.

**The envelope is drawn as three rings, not a shell.** The first build used a
translucent sphere and a rendered frame killed it: from just outside, an 840 m sphere
fills the whole view and the planet, the disc and the markers are all seen through a
colour filter. That is a tint, not a signpost. Rings mark the same boundary and leave
the view alone.

The docking screen has one service — `Depart`. Refuel is step 7's, the magazine needs
missiles this scene does not carry, and dead placeholder buttons teach the player that
the screen lies. It is built as a service list, so step 7 adds a row.

### ✅ Taxi speed is confirmed at 15.5 m/s — 2026-08-29

> "yes the taxi speed is correct based on the updated doc. It felt too fast in
> combat and it's OK if a giant ship feels slow as it's descending to the planet."

Cause named, and it is the useful half: the old 34 m/s **read too fast in combat**,
and a large ship feeling slow on a descent is *correct* rather than a cost being
paid. The whole ladder derives from this, so everything below it — cruise, leg
times, system size — is now anchored rather than provisional.

### 🔜 SETTLED, NOT YET BUILT: the system border

Decided with the human 2026-08-29, before implementation. **Build this next.**

**The rim becomes a boundary**, which supersedes ADR 0011's *"do not put a wall,
threshold, or prompt at the rim"*. That clause existed because lateral exit **was**
departure; once roads exist, departure is through the corridor and an open rim leads
somewhere nothing is rendered. That is the highway design's own renderability
argument, so ADR 0057 is untouched and it is 0011 that gives. **Needs an ADR.**

**Apertures are funnels.** The rim opens where a road attaches — wider at the rim,
narrowing into the corridor, so the player is guided in rather than threading a
1750 m hole. The current single-system scene declares a **placeholder aperture** at
the bearing the local leg will use, so the rim is testable before step 6 rather than
being closed now and reopened later.

**The clamp becomes heading-proportional, and reaches zero.** The old version was a
boolean — any outbound velocity component at all triggered the full clamp on the
whole speed, so a legal lateral departure near the ceiling was strangled by a few
degrees of climb. The human's model, which is better:

    outbound = (1 + cos θ) / 2              ; = cos²(θ/2), θ from the outward normal
    depth    = clamp(metres past the edge / bounds_stop_distance, 0, 1)
    scale    = 1 − depth × outbound

`cos²(θ/2)` is 1 straight out, **0.5 tangential**, 0 straight back in. So tangential
is still slowed, the way home is never taxed at any depth, and a ship that keeps
pushing outward arrives at zero and must turn. **The boundary stops you by making
outward cost everything, never by taking the stick** — magnitude, never direction,
exactly as before.

Note that "the faces slow the player, they never stop them" currently appears in
`tuning.cfg`'s comments. That was mine, not ADR 0011's, and it is wrong — drop it.

**Two distances, previously conflated.** `bounds_warning_band` is metres *inside*
the edge where the faces redden: pure telegraph, no mechanical effect. A new
`bounds_stop_distance` is metres *outside* the edge over which the cap ramps to
zero. The red zone is genuinely outside the good zone and can be entered.

**Boundaries become a list of constraints**, each contributing a distance and an
outward normal, rather than ceiling/floor/rim being three special cases. `warning`
is the max over them; `outward` is their normals summed weighted by depth. Every
corner then falls out of the arithmetic — at a ceiling∩rim corner the combined
normal is the diagonal, so down-and-inward is free and up-and-out is stopped, with
no case written for it. A disc is one constraint set; the whole-map boundary the
human expects to want later is a different set, not different code.

### 🔵 THE FIRST FEEL QUESTION IS OPEN

Step 4's checkpoint: **does approach feel like arriving somewhere, or like a menu
with a runway?** `make run SCENE=res://scenes/exploration.tscn`.

Worth knowing while reading it: the camera boom scales with hull size, so the ship
stays the same size on screen and the *world* changes scale instead — a small ship
makes the system feel large. That is `camera/boom_hull_scale_influence`; drop it to
0 to read hull size off the screen directly instead.

### Open, and flagged rather than resolved

- **The envelope now measures itself.** `EnvelopeMeter` keeps a session high-water
  mark and the arena HUD carries an `envelope` row. Two figures, because the chain
  wants them for different things: **span** (largest distance between any two
  participants) sizes the diameter, and **vertical** (up-axis spread alone) is what
  disc height is actually 5–10x of — the clause is *"so the ceiling never enters a
  fight"*, and a ceiling is only entered vertically. An earlier note here said the
  numbers chain was "resolved from the wrong end"; that conflated the fight's
  horizontal sprawl with its vertical one and was wrong. **One session now produces
  the number.**
- For scale while reading it: the fight is held at 203 m standoff, missile reach is
  348 m, the target patrols a 600 m box — while the rock field the human has been
  flying in is already **3,134 m across and 440 m thick**. The scenery is roughly
  3–4x the fight in both dimensions. Whether that comes down is a feel call.
### Exploration step 2 is built — the first system disc

`make run SCENE=res://scenes/exploration.tscn`. A 3500 m disc, 1150 m tall (400 up,
750 down), a planet 450 m below the combat plane, and manual flight. No missiles,
no turret, no roster — only the pilot exists here.

**ADR 0011 was built for the first time.** The combat arena has always been an
unbounded marker lattice; there was no "existing boundary treatment" for the POC doc
to reuse. The disc now has hard flat faces, an open rim, a red volume, a telegraphed
grace period, ramping damage and the outbound speed clamp.

The clamp is **on the speed limit, not on the velocity vector**, which is what makes
ADR 0011's *"magnitude only, never direction"* structural: `DiscBounds` returns a
scale and never sees a heading it could return, so no code path exists that can turn
the player's ship. It shows on the HUD — the speed row's "of N" comes down.

Verified by rendering both states. `tools/shots/bounds_shot.tscn` parks the ship past
the ceiling, because *"the volume is visibly red"* is the one thing in that ADR no
test can check. It reads as a translucent membrane — markers and the planet are
visible through it — rather than as a wall.
- **Per-ship / per-faction tuning data** is not on `ROADMAP.md`. ADR 0059 landed the
  mechanism; the rows are the work.


## Where the build is

### ✅ Success criterion 1 has PASSED — 2026-08-27

> "I have play tested enough of the POC to determine this is a winner. The brakes +
> acceleration give a much higher skill ceiling that feels believable."

The 8 seconds work. The named cause is **brake and boost**, which is worth holding
onto: the verdict is not "flying a missile is fun" (that was never in doubt and the
POC doc says so) but that the *speed-versus-agility trade* is what gives it a
ceiling. That is the thing to protect in every later change.

Also endorsed, and now written down:

- **The shared horizon.** "All ships are kept on the same plane" — nothing rolls
  (ADR 0045). This had been an accident of ADR 0003's roll-free bases; it is a rule
  now.
- **Ship movement and the autopilot.** Good enough. Better trajectory-locking
  mechanics are wanted eventually; the heading hold is not blocking anything.

### 🟢 Combat reads right — 2026-08-29, first session with the whole loop

> "I think the combat looks right. There are a lot of good mechanics here, and I
> don't need to incorporate all of them in every fight for every player. This is a
> good dynamic system and can also let the players have some more agency."

**This is not yet the formal verdict.** Criterion 2 is *"after 30 minutes of
continuous play"* and criterion 3 is *"a felt difference between an early missile
and a late one"* — both want the session that step 9 is supposed to frame, and the
target still cannot die, so a fight has no terminus to play past. What this reading
does settle is the thing the POC existed to risk: **nothing here says rethink.**

The second sentence is the load-bearing one and it is a design finding, not a
compliment. The combat system has come out as a *space of configurations* rather
than one configuration: four weapons over two loadouts, three missile verbs that
ADR 0047 already tiers as equipment, blockers on both sides, an interrupt with an
interval. No single fight needs all of it. That is ADR 0018 (difficulty banded by
faction) and ADR 0025 (difficulty selected through mechanics, never a menu) turning
out to be *implementable in the tuning file* rather than needing a difficulty
system built for them.

**The architectural consequence is not yet built:** `tuning.cfg` is one global set
of values. "Will look different for different factions" means those numbers have to
become **per-ship and per-faction data**, not globals — the first concrete
requirement for the equipment layer, and it is not on `ROADMAP.md` yet. Flagged
here rather than acted on.

### ⏳ Criteria 2 and 3 are not formally read

Criterion 2 is the loop — "after 30 minutes the developer is still choosing to
fire, and never feels stuck waiting" — and criterion 3 is the ceiling. Both are
questions about *what happens between missiles*, and until 2026-08-27 there was no
between. `PROJECT_OVERVIEW.md` §Sequencing: "the loop under test is missile *and*
turret, not missile alone."

**`docs/TURRET_MODE_IMPLEMENTATION.md` is built and has been played.** `G` mans the guns; all four
weapons fire; both sides throw flares; the launch tube has its 10 s cooldown; and
the target sends one telegraphed guided missile at the player on a long timer.

**POC steps 5, 6, 7 and 8 are complete.** Only step 9 — death, respawn, the PiP
toggle, and the 30-minute verdict session — is outstanding. Criteria 2 and 3 are
now questions the build can answer, and nobody has played it yet.

So the POC is half-verdicted. The half that passed is the half the doc predicted
would pass.

### What works

| Thing | State |
|---|---|
| Godot 4.7.2 project, runs windowed and headless | working |
| `tuning.cfg` hot reload (save the file, the running game changes) | working |
| Tuning file is a `ConfigFile` with inline `;` comments on every value (ADR 0033) | working |
| **F2 tuning panel**: live sliders, tooltips, filter, save — now in collapsible sections | working |
| Comment-preserving save — five edits changed exactly five lines | working |
| `Tuning` autoload with typed getters and loud missing-key errors | working |
| Input bindings from `data/input_map.json` (no editor Input Map tab) | working |
| Debug HUD with pluggable readout rows + tuning status line | working |
| Gray-box arena: 7³ marker lattice via one MultiMesh, rebuilt on reload | working |
| Debug fly-cam (RMB look, WASD/QE, Shift boost) | working |
| Asset pipeline: `.obj` model + `.png` texture, generated → imported → rendered | working |
| `make check`: 673 headless assertions, exit code gated | working |
| Godot-3 API linter over all scripts, data-driven denylist | working |
| `make shot`: render frames to PNG from the CLI for visual verification | working |
| `make apiref`: this exact build's 771-class reference for API grounding | working |
| `DESIGN.md` — distilled thesis, Target Experience verbatim | written |
| `decisions/` — 56 ADRs, indexed, each with a *What this forbids* section | written |
| **Combat arena** (`scenes/arena.tscn`, now the main scene) | working |
| Mothership autopilot: slow arc at standoff, nose on target | working |
| Dumb target ship: drifts, turns at its patrol bounds | working |
| Missile: launch along ship heading, constant speed, fuse | working |
| Reticle steering: input moves an intent marker, the missile turns toward it | working |
| Autopilot faces its direction of travel; missiles launch across the target | working |
| Flight overlay: reticle, nose-to-reticle lag line, screen-edge target arrow | working |
| Early detonate on the fire button while riding, camera returns to the ship | working |
| SHIP ↔ MISSILE camera state machine, hard cut, timed return | working |
| Swept-segment hit test — no physics bodies anywhere (ADR 0032) | working |
| Detonation flash, hit/miss readout, shot and hit counters | working |
| `make shot SCENE=res://tools/shots/missile_view_shot.tscn` — captures the ride | working |
| **Boost**: held on W, from a reserve that does not refill in flight | working |
| **Brake**: held on S, trades speed for turn rate, overrides boost (ADR 0039) | working |
| **Dodge**: A/D, one press, one displacement, then a cooldown (ADR 0039) | working |
| **Rocks kill missiles**: 260 obstacles inside the fight (ADR 0038) | working |
| **Rocks are ellipsoid clusters** — the drawn shape *is* the hit shape (ADR 0041) | working |
| **Manual ship flight**: W/S throttle, A/D thrusters, mouse steers (ADR 0040) | working |
| Ship top speed clamped against `missile/base_speed` in code, not by comment | working |
| **Target is a ship shape** — fuselage, nose, wings, fin, built from primitives | working |
| **Destructible components**: 4 cylinders, darken then explode, respawn (ADR 0042) | working |
| Target hit as the boxes it is drawn from; nearest part along the shot wins (ADR 0043) | working |
| **Player ship is a 50 m gunboat** — crescent-winged capital hull (ADR 0044) | working |
| Autopilot eases its nose instead of snapping, and cannot outrun manual flight | working |
| F2 panel folds into one collapsible section per `[section]`, with counts | working |
| `make shot SCENE=res://tools/shots/target_shot.tscn` — captures the target close up | working |
| **Gun station**: `G` mans it, a peer of the helm, not a sub-state (ADR 0048) | working |
| Turret aim is 1:1 in the arena frame — the hull turns under it, the aim holds | working |
| Turret camera with a boom that levels instead of diving through the hull | working |
| Loadout state: four weapon slots over two loadouts, `1` / `2` switch | working |
| Gun crosshair, `turret` and `gun aim` HUD rows | working |
| SHIP ↔ TURRET state machine; no turret-to-missile edge, and `fire()` enforces it | working |
| `make shot SCENE=res://tools/shots/turret_shot.tscn` — captures the gun view | working |
| **Autocannon**: 2/s, unlimited, a travelling round with a visible tracer | working |
| **Pulse beam**: hitscan, damage per second, heat buildup and lockout | working |
| One shot resolver — nearest of hull, component or rock wins (ADR 0049) | working |
| Component damage is a pool; every weapon spends a number against it (ADR 0049) | working |
| Projectile speed clamped *above* the missile's boosted top speed, in code | working |
| Guns are sighted: muzzle off the sight line, shots converge at a tuned range | working |
| Heat bar under the crosshair; `guns` HUD row with rate, cooldown and heat | working |
| **Unguided missile**: click to fire, click again to detonate, one in the air | working |
| Magazine of 10 with a per-round trickle back; `unguided` HUD row | working |
| **Splash damage** — POC step 5 is finished (ADR 0004, `scripts/lib/damage.gd`) | working |
| Splash capped below a direct hit *in code*, falloff floored at quadratic | working |
| One blast damages several components at once, skipping the one it hit directly | working |
| A blast is drawn at exactly the radius it damaged (ADR 0050) | working |
| **Blockers**: a star of flares on a 5 s cooldown, thrown across the threat axis | working |
| **Enemy blockers**: the target answers an incoming missile on a tuned roll | working |
| A flare is a physical object, not a chance of being fooled (ADR 0051) | working |
| One flare stops one missile and is spent; the star is exactly what is drawn | working |
| Shootable sets are Godot groups, so nothing keeps a registry that could rot | working |
| **The 10 s launch cooldown** — the metronome of the loop (ADR 0052) | working |
| Reload gauge on the flight overlay, readable from every view without F1 | working |
| **The interrupt**: one guided missile on a long timer, telegraphed in advance | working |
| Its aim error is sampled at launch and never corrected — the line is the tell | working |
| Killable by the autocannon, the beam, an unguided blast, or a flare | working |
| Loud alert banner + a bracket on the missile, built to be tuned *down* | working |
| Ship HP and hit counting, with `ship/invulnerable = true` for the pacing build | working |
| Impact tint round the screen edge, which fires even while invulnerable | working |
| **First-person gun station** with its own narrower FOV (ADR 0054) | working |
| Off-screen arrow pointing at an incoming missile, not just a bracket | working |
| A flare star has two speeds: one moves the wall, one opens it | working |
| A star carries the launching ship's motion; aimed shots do not (ADR 0055) | working |
| **Crew roster**: T pilot, G gunner, and the autopilot follows (ADR 0056) | working |
| **Q launches a missile**, from either station; Space/LMB only ever detonates | working |
| The autopilot arcs on a plane 60 m under the target, so the gun clears the hull | working |

### Deliberately not built yet

In build order, each with its own feel checkpoint — do not pull any of them
forward, because adding one early destroys the reading on the one before it:

- ~~**Step 5**~~ — **done** on 2026-08-27. Splash landed with the unguided
  missile's warhead; the ridden missile's early detonation, fuse expiry and impact
  all go off in a radius through the same falloff (ADR 0004).
- ~~**Step 6**~~ — **done** on 2026-08-27: the station, all four weapons, and the
  10 s launch cooldown.
- ~~**Step 7**~~ — **done**: blockers on both sides, enemy return fire, ship HP.
  HP is present and counted but `ship/invulnerable` is true, at the human's
  direction, so the pacing signal is not mixed with a difficulty one.
- ~~**Step 8**~~ — **done**: the interrupt, at the specified 60 s and **expecting
  to be raised** (see the flag in `docs/TURRET_MODE_IMPLEMENTATION.md`).
- **Step 9** — target death and respawn, the PiP camera toggle, and the 30-minute
  verdict session against all three criteria. This is all that is left of the POC.

## Next

**Step 9, and make the envelope measure itself.** Combat has been played and reads
right (above). Two things are left before the combat bet is closed, and they are
both small:

1. **`ship.max_engagement_envelope` — deferred four times now, and blocking the
   entire exploration chain.** It should stop being something a human has to
   remember to eyeball: the arena can *record* the largest distance a fight sprawls
   across and put it on the HUD. That is building the instrument rather than asking
   for the observation, and it turns a deferred chore into a number that is simply
   there at the end of a session.
2. **POC step 9 — the target can die.** It has never had hull hit points; components
   strip and respawn and the ship drifts on regardless. That is why criterion 2's
   *"after 30 minutes"* has no natural shape to it — **a fight with no terminus
   cannot be played past**, so there is nothing to observe about the loop resetting.
   Ship damage is one flip of `ship/invulnerable`, already plumbed and tested.

The PiP camera toggle is also step 9, and is the one piece worth questioning: the
hard cut has been played for a week and nobody has complained about it.

**Read the layers one at a time.** Three build-order checkpoints landed together,
and the scope doc warns that adding one early destroys the reading on the one
before it. Every layer is independently disableable from `tuning.cfg`, so the
readings are still obtainable — in this order:

| To read | Set |
|---|---|
| Step 6 alone: the turret and the cooldown | `enemy/interrupt_interval_seconds = 0`, `enemy/blocker_chance = 0` |
| Step 7: add blockers | `enemy/blocker_chance = 0.5` |
| Step 8: add the interrupt | `enemy/interrupt_interval_seconds = 60` |
| Any weapon out of the mix | that loadout slot to `"none"` |

**Expect to raise `interrupt_interval_seconds`.** The scope doc calls it "the single
easiest way to turn a relaxed game into a stressful one" and predicts the good value
is much larger than intuition suggests. At 60 s against a 10 s tube it is an
interrupt on roughly every sixth action — dense on purpose, because an interrupt you
never see cannot be evaluated.

**And take the engagement-envelope measurement while playing** — see below. It is an
observation, not a design act, and the whole exploration numbers chain is blocked on
it. It has now been deferred three times.

**Then the fork, and it is a real one:**

- **The exploration prototype** (`ROADMAP.md` §3) — the second and last bet that can
  still return *rethink*. Cruise feel, the travel gauntlet, whether an off-route gray
  blip is worth diverting for. Blocked on the envelope number, which is why item 1
  above comes first.
- **Per-ship and per-faction tuning data** — the architectural consequence of
  2026-08-29's "will look different for different factions". Not on `ROADMAP.md`.
  It is the first real piece of the equipment layer, and doing it before exploration
  would mean building the content system before knowing what the content is worth.

The recommendation is exploration first, on `ROADMAP.md`'s own reasoning: it is the
last thing that can invalidate the design, and the faction data layer is priced off
travel time like everything else in §5.

**And take the engagement-envelope measurement** — see below. It is an observation,
not a design act, and the entire exploration numbers chain is blocked on it.

Everything else the design is waiting on — cruise, economy, missions, interactions,
art — is downstream of one or the other of those two. See *Where to start* below.

Still open from the first feel session, and worth judging while playing step 6:

1. **Boost and brake numbers.** 1.9x for 1.8 s of reserve; 0.55x speed for 1.8x
   turn. The verdict says the *shape* is right, which makes the values worth a
   second pass rather than a first one.
2. **Dodge** — 22 m over 0.28 s on a 1.1 s cooldown. Not named in the verdict
   either way. Worth asking whether it is earning its button (ADR 0047 leaves its
   tier open for that reason).
3. **The ship's new scale.** 50 m of hull at a 203 m standoff, camera 62 m back.
   Every camera and speed value was retuned around it and none has been felt.
4. **Target practice.** Components against a single hit sphere.
   `enemy/component_count = 0` restores the old target for an A/B.
5. **Whether the far-field speed reference is missed** now the rocks came inside.
   If it is, the fix is a second sparse non-colliding layer (ADR 0038), not moving
   these back out.

## Where to start — the dependency chain

*Full version, with what each stage is blocked on: `docs/ROADMAP.md`.
The current build's detailed spec: `docs/TURRET_MODE_IMPLEMENTATION.md`.*

The design has a lot of open fronts (cruise, between-system activity, economy,
missions, interactions, art) and they look parallel. They are not; they are a
chain, and most of it is already written down in `PROJECT_OVERVIEW.md`
§Sequencing and §Open Questions. In order:

1. **Finish the combat bet** — step 6, then 7-9. Cheapest remaining question,
   and the only one that can still say "rethink".
2. **Measure `ship.max_engagement_envelope`.** Root of the numbers chain.
3. **Exploration prototype** — the second bet, and blocked on 2. Cruise feel, the
   gauntlet, whether a gray blip is worth diverting for.
4. **Overworld design in parallel** — chat-only, validated by a headless faction
   sim at 1000x before anything visual exists.
5. **Economy, missions, interactions** — these price off travel time, which comes
   out of 3. Travel carries the campaign clock (ADR 0022), the clock sets mission
   cadence, cadence sets economy tuning. Designing them before cruise feel is
   settled means re-tuning all of it afterwards.
6. **Art, last.** Placeholders are generated by scripts and replaced in place
   (ADR 0030); nothing in code knows the difference, so nothing is waiting on it.

Every change lands on a feature branch via a PR to `main`. See `CLAUDE.md`
§Git flow.

## Open feel questions

Every value below is a starting position picked to be flyable, not a proposal.
They are the knobs most likely to be wrong.

- **`missile/boost_multiplier` 1.9 for `boost_seconds` 1.8, no regen.** A single
  tank per missile, so boost is a route decision rather than a held button. If it
  is always right to burn it immediately, the reserve is too small or the
  multiplier too shy.
- **`missile/dodge_distance` 22 m over `dodge_seconds` 0.28, cooldown 1.1 s.** The
  displacement eases out, so most of it lands in the first few frames. Cooldown
  under `dodge_seconds` degenerates back into a held strafe — the thing ADR 0039
  removed.
- **`missile/brake_speed_multiplier` 0.55 and `brake_turn_multiplier` 1.8.** How
  sharp the speed/agility trade is. Brake pays in range and nothing else.
- **`arena/rock_inner_radius` 69.8 with `rock_count` 260 and sizes 8–46 m.** Note
  the scale: a 46 m rock 70 m from arena centre is enormous next to a 203 m
  standoff, so the near rocks are large. These counts and sizes were chosen against
  the *old* forgiving hit shape — the field is meaningfully more solid now that
  `rock_hit_radius_scale` is 1.0 and the ellipsoids bite at their own silhouette.
  Expect to want fewer or smaller.
- **`missile/base_speed` 58 m/s and `missile/turn_rate_deg_per_sec` 41.85.** The
  speed/turn-rate ratio is the whole handling model. Too much turn rate and the
  fuse stops mattering; too little and the shot is decided at launch.
- **`missile/fuse_seconds` 6.0** against a 203 m standoff — about 350 m of travel
  un-boosted, so roughly 150 m of margin for manoeuvring. That margin *is* the
  difficulty (ADR 0002). Boost buys reach at the cost of the reserve.
- **`camera/missile_follow_distance` 7.85 / `_height` 2.0 / `_look_ahead` 25.5.**
  Set so the missile sits low-centre with the target above it. Lag is 14.
- **`camera/return_delay_sec` 0.7** — how long the flash is watched before the cut
  back. Long enough to read the outcome, short enough not to be a cutscene.
- **`ship/arc_speed` 13.8 at `standoff_distance` 203** — how much the launch
  geometry varies shot to shot, which is where the procedural variety comes from.
- **`controls/mouse_sensitivity` 0.20 deg/px** versus the stick. Both are capped by
  the same turn rate so neither device can out-ask the other.
- **`ship/manual_max_speed` 34 against a 0.6 ceiling fraction.** 0.6 x 58 is 34.8,
  so the ship's own number is what currently binds — but only just. Raise
  `manual_max_speed` and the clamp takes over silently and correctly; the HUD's
  *flight* row shows both figures so it is visible when that happens.
- **`ship/manual_accel_seconds` 3.2 and `manual_brake_seconds` 2.4.** How heavy the
  ship feels to get moving and to stop. Longer is more ship-like and more annoying;
  the crossover is the thing to find.
- **`ship/manual_turn_rate_deg_per_sec` 26** against the missile's 41.85. The gap
  between those two numbers is how different the two vehicles feel to fly, and it
  is the main dial for that.
- **`enemy/component_count` 4 at `component_hit_radius` 2.2**, inside a hull sphere
  of 9. If components are too easy to hit the experiment says nothing; if they are
  too hard, every shot lands on the hull and it also says nothing.
- **`enemy/component_respawn_seconds` 8.0.** A harness value, not a design claim —
  it exists so the loop can be felt more than once per session.
- **`controls/turret_mouse_sensitivity` 0.16 deg/px**, separate from the ship's
  0.20 on purpose: aiming a gun and flying a hull are different hand movements.
  This one is 1:1 — it moves the gun, not a reticle the gun then chases (ADR 0048),
  so it is the *only* thing between the hand and the shot.
- **`turret/mount_offset` (0, 18, −6) and the whole `camera/turret_*` group.**
  Where the station sits on a 50 m hull and how the camera hangs behind it. How
  much of your own ship is in frame is the main thing to judge; too little and the
  turret could be anywhere, too much and it is in the way.
- **`camera/turret_boom_pitch_share` 0.3.** 0 keeps the boom level and lets the gun
  rise inside the frame; 1 pins it to the gun and dives through the hull at high
  elevation. 0.3 is a guess at "reads as a boom, does not clip".
- **`turret/elevation_limit_deg` 55 against `traverse_deg_per_sec` 90.** Every ship
  is on one plane, so most of that elevation is aiming at nothing — the question is
  whether the limit ever gets in the way when a target is close and above.
- **`turret/convergence_distance` 210 m against `turret/muzzle_mount_offset`
  −3.5 m.** The range the guns are sighted at, and how far below the sight line they
  sit. Together they set how wrong a travelling round is at other ranges: about
  1.8 m low at 100 m, against a component hit radius of 2. Larger offset means more
  visible tracers and a worse close-range gun; the crossover is the thing to find.
  The pulse beam is unaffected — it is exact everywhere by design.
- **`turret/autocannon_damage` 9.0 at 2 rounds a second, against a 100-point
  component.** Six seconds of continuous fire per component, if every round lands.
  Compare against `turret/pulse_damage_per_second` 45, which is the same component
  in a little over two seconds — but only inside `pulse_range` 180, which is under
  the 203 m standoff. **That gap is the whole design of the two weapons**: the
  cannon works from where the autopilot parks you, the beam is a reason to close.
  If closing never feels worth it, the beam's damage or the cannon's is wrong.
- **`enemy/interrupt_interval_seconds` 60 with an 8 s warning lead.** *The* number
  the scope doc warns about, and the one most likely to be badly wrong. Judge the
  lead against `missile/fuse_seconds` 6: it has to exceed a typical remaining ride
  or "win both" is arithmetically impossible.
- **`ship/arc_depth` 60 at a 203 m standoff** — about 17° of look-up, against a
  `turret/elevation_limit_deg` of 55. Deep enough to clear the hull; whether it is
  deep enough to feel like a *position* rather than an accident is the question, and
  it costs the arc horizontal radius (194 m instead of 203) to go deeper.
- **`camera/turret_fov` 52 against `camera/fov_base` 70.** How much magnification
  the gun gets, traded against how much of the sky you can see from it. The reason
  the interrupt was hard to shoot; the reason to stop narrowing it is losing track
  of where things are.
- **`camera/turret_follow_distance` 2.5 with height 0** — first person, near enough.
  Raise it and the boom, its lag and ADR 0048's pitch share all come back.
- **`enemy/missile_aim_error` 26 m against a hit sphere derived from a 50 m hull.**
  How often the interrupt would have hit anyway. Too small and every one must be
  shot down; too large and none of them matter.
- **`enemy/missile_hit_points` 20 against `turret/autocannon_damage` 9.** Three
  rounds, so it is answerable from loadout 1 — which matters, because the player has
  no way of knowing to switch loadout before an interrupt they have not been warned
  about yet.
- **`ship/missile_cooldown_seconds` 10 against a fuse of 6.** *The* number of this
  build. Below the fuse it does nothing — the tube is always ready by the time a
  long ride lands. At 10 a full-fuse ride leaves about four seconds at the gun and a
  quick detonation about nine, and that gap is the mechanic. Watch for the two
  failure modes named in the criterion: bored at the gun (too long) and never
  reaching the gun at all (too short).
- **`enemy/blocker_trigger_range` 120 m against a 203 m standoff and a flare that
  lives 4 s and spreads at 26 m/s.** *When* the wall goes up is the whole difficulty
  of the mechanic: thrown early the flares have dispersed by the time the missile
  arrives, thrown late there is no room to fly around them. This is the single most
  likely wrong number in the blocker set.
- **`enemy/blocker_chance` 0.5**, the spec's figure, with a 6 s launcher cooldown.
  Worth watching whether being blocked reads as *your* mistake for flying straight
  at it, or as the game taking a shot away. If it is the second, the answer is a
  longer trigger range and more room, not a lower chance.
- **`flare/launch_speed` 15 against `flare/spread_speed` 6**, with `flare/radius`
  5.5 and six flares. **These are relative to the launching ship now** (ADR 0055),
  which changes what the number means: 15 is the separation the wall achieves from
  the ship that threw it, so after four seconds of flare life the wall is 60 m out
  in front. Whether that is the right standoff for a wall has never been felt. Six 5.5 m spheres opening at 6 m/s are shoulder to shoulder
  for the first couple of seconds and a scatter with 30 m gaps by four. **This is
  now a tighter, more solid wall than the one that was played**, which cuts both
  ways: harder to thread while it is fresh, and easier to go around, because it
  covers much less sky. Keep `spread_speed` well under `launch_speed` — equal or
  above and the star turns inside out into a cone.
- **`turret/unguided_magazine` 10 with `unguided_reload_seconds` 6.0 per round.**
  A full magazine back takes a minute. Whether ten shots is a session's worth or a
  minute's worth is the open question, and `unguided_reload_seconds = 0` (never
  refills) is the setting that answers it cleanly.
- **`turret/unguided_blast_radius` 17.34 against `unguided_blast_damage` 22 and a
  falloff of 2.4.** Twice the ridden missile's splash radius, as specified. The
  falloff is steep enough that "somewhere near two components" is worth much less
  than "between them" — which is the skill in the weapon. If choosing where to
  detonate never feels worth it, the falloff is too shallow, not too steep.
- **`missile/splash_damage_fraction` 0.25**, the number ADR 0004 named, under a
  hard code ceiling of `splash_max_fraction` 0.4. The first thing to watch is
  whether early detonation has quietly become the default play; if it has, this is
  too high, and that ADR says so in advance.
- **`turret/pulse_heat_per_second` 0.42 with `cool_per_second` 0.3 and a 2.5 s
  lockout.** About 2.4 seconds of beam, then a wait. Whether that reads as a rhythm
  or as an interruption is the question; it is the only weapon with a limiter the
  player has to think about at all until the missile cooldown lands.

### Feel direction taken 2026-08-29, deliberately not acted on

Both are the human's, and both were explicitly deferred by them — *"those are tweaks
we can still add and will look different for different factions potentially."*
Recorded because feel direction is expensive to re-derive and cheap to lose.

1. **Player blockers should be faster, so they can be *shot at* an incoming
   missile.** The intent named is skill: a flare star aimed and led like a weapon,
   rather than a wall dropped in front of you. `flare/launch_speed` (15 m/s) is the
   knob, and it is already relative to the ship (ADR 0055) so raising it is a clean
   change. Worth checking `flare/spread_speed` at the same time — a star thrown as a
   projectile probably wants to stay tighter for longer than one thrown as a wall.
2. **Facing enemy blockers, there is not enough time to dodge the missile past them
   and still hit the ship.** `enemy/blocker_trigger_range` (120 m) is the knob, and
   this is the failure `STATUS.md` predicted for it in advance: *"thrown late there
   is no room to fly around them."* Raising it throws the wall earlier and further
   out, which buys the room. Note it interacts with `flare/seconds` (4.0) — thrown
   too early and the flares are gone before the missile arrives.

**Both are reachable from `tuning.cfg` with no code change**, which is the
feel-parameter law paying for itself. Neither has been touched: feel verdicts are
human-only and these are the human's knobs to turn.

### Decided 2026-08-28 (the crew roster)

> "autopilot should always be engaged when in gun mode and always disengaged when
> not. you can think of it that the player is either the pilot or the gunner (there
> might be other jobs in the future), 'T' makes the player the pilot, 'G' makes the
> player the gunner, 'Q' fires a missile"

- **The player holds a job, not a mode** (ADR 0056). `T` and `G` *select* a station
  rather than toggling anything, and the autopilot is a consequence of not being the
  pilot. An independent toggle allowed two states that make no sense — at the helm
  with the autopilot flying, and at the guns with nobody flying — and binding it to
  the roster deletes both by construction. **"There might be other jobs in the
  future" is why `Role` is an enum**, not a bool: Pillar 6 has a crew in it.
- **`Q` launches, from either station.** This reverses ADR 0048's helm-only clause,
  which did not survive the roster: launching moves the player into the missile in
  the same frame, so sequential attention is intact, and a helm-only launch would
  force the gunner to take the helm first and drop the autopilot *every time they
  wanted to fire*. Launching also stopped sharing a button with detonating — one key
  whose meaning depended on where you were standing.
- **The autopilot arcs under the target** (`ship/arc_depth`, 60 m). The gun is
  mounted on the spine, so from a level arc it looks across its own hull; ADR 0054's
  first-person camera made that unmissable. Standoff still means *slant* range, so
  the number compared against missile reach is unchanged. It also simplified the
  code — the arc is horizontal by construction now, which is ADR 0045's shared
  horizon arriving in the autopilot, and the degenerate near-vertical case is gone.
- **Runs now start at the helm** (`ship/start_role = "pilot"`), where they used to
  start watching the autopilot arc. `"gunner"` restores the old opening.

### Decided 2026-08-28 (from the first turret playtest)

> "there's too much spread on the blockers, they should move slightly faster toward
> the direction of release and much less fast apart. it was really hard for me to
> see and shoot the enemy missile. I think it would help if the turret was more like
> a first person experience, maybe the FOV also needs to be adjusted for this as
> well"

- **A star carries the launching ship's motion** (ADR 0055). Reported as "the
  blocker is slower than the ship, which causes issues" — and it was worse than a
  nuisance: *both* flare speeds are slower than a ship at cruise, so the wall was
  dropped in place and the ship flew out through its own countermeasure inside a
  second. The general rule it settles is **whether the player is aiming the thing**:
  if they are, it goes where they pointed and inherits nothing; if they are letting
  go of it, it keeps what it had. ADR 0005 already made that call for the ridden
  missile; this states the reason.
- **A flare star has two speeds now, not one speed and a blend.**
  `flare/launch_speed` moves the whole wall along the throw; `flare/spread_speed`
  opens the ring. The old parameterisation could not express "throw it out quickly
  but keep it tight" at all — raising the speed to move the wall also opened it up,
  which is exactly the spread that was reported. ADR 0051's shape is unchanged; only
  how it is dialled.
- **The gun station is first person, with its own field of view** (ADR 0054). Not a
  preference — a measurement problem. The target is a 2.6 m sphere at up to 200 m in
  a field of 260 rocks: about three pixels at the shared 70°. First person removes
  the eye-to-sight-line parallax, and 52° is about 1.4× magnification on every
  linear dimension. `camera/fov_base` is untouched, because the helm and the ridden
  missile want the wide value and criterion 1 already passed on it.
- **The alert marker gained an arrow.** A narrow FOV means the incoming missile is
  off screen more often, so "incoming" has to be a *direction* to turn towards. The
  bracket also stopped pulsing in size — a marker that shrinks every second is a
  marker that is hard to find.

### Decided 2026-08-27 (from building the interrupt)

- **The interrupt is telegraphed before it happens, not announced as it arrives**
  (ADR 0053). With no lead, the only way to survive one is to already be at the gun
  — which means never committing to a ride, and that is ambient pressure with extra
  steps. Pillar 2 requires that it be possible to **win both**, so the lead is
  constrained against the fuse.
- **The alert is built loud, to be tuned down.** The spec asked for "a small alert";
  the scope doc asks for "loud, telegraphed, unambiguous". Building it small and
  tuning up means shipping the failure mode and finding it by feel; building it
  loud and tuning down is the safe direction to be wrong in.
- **The miss is decided at launch.** The aim error is sampled once and never
  corrected, so the missile's *line* is the information — it is visibly going to
  pass wide, or visibly not — rather than a die roll at the end. Same reasoning as
  ADR 0051's flares: the game's threats should be things you can look at.
- **The enemy has a timer, not a decision.** No leading, no waiting for the player
  to be mid-ride, no holding fire. ADR 0013 and ADR 0014 keep NPCs from making
  decisions about the player's ship; this keeps them from making decisions about
  the player's shot.

### Decided 2026-08-27 (from building the launch cooldown)

- **The tube's clock starts at launch, not at detonation** (ADR 0052). This is what
  makes "every second in the missile is a second off the gun" literally true:
  detonate early and you buy turret time, ride the fuse out and you spend it.
  Starting at detonation would make a long ride free, deleting the price on a
  decision ADR 0002 makes the difficulty dial.
- **The reload gauge lives on the flight overlay, not in the debug HUD.** Criterion
  2 is a question about that bar, and it is not answerable if reading it requires
  F1. It is drawn in every view — helm, guns, and inside a missile.

### Decided 2026-08-27 (from building the blockers)

- **A flare is an object in the way, not a chance of being fooled** (ADR 0051). The
  genre default is a seduction roll resolved off screen — a condition imposed on
  the player that they cannot see, act on, or learn from. A flare is a sphere: it
  is visible before the missile reaches it, the counter to it is flying around it,
  and getting better at that is a skill. One flare stops one missile and is spent,
  so the star on screen *is* the accounting.
- **A star is a ring across the threat axis, not a cone down it.** A cone is a line
  of flares the missile flies between. `flare/forward_bias` leans the wall out to
  meet the missile rather than dropping it in place.
- **The enemy rolls once per missile, not once per frame.** At 60 fps a per-frame
  roll of 0.5 fires on the first frame every time, and `enemy/blocker_chance` would
  be a number with no effect that nobody would notice was broken.

### Decided 2026-08-27 (from building the unguided missile)

- **One unguided missile in the air, and the second click is the mechanic**
  (ADR 0050). A weapon is either *held* or *clicked*, and which one is a property
  of the weapon: on a held trigger a magazine of ten empties in a fifth of a
  second, and with a dozen rounds in flight "click again to detonate" has no
  referent. One at a time makes the second click a decision with a subject — you
  are always either holding a shot or holding a detonator.
- **A blast is drawn at exactly the radius it damaged.** `missile/flash_end_radius`
  is gone; the flash's end radius *is* `missile/splash_radius`. This is the same
  rule as ADR 0041's rocks and ADR 0043's hull arriving a third time, and it is
  worse here than either — the player judges "did that reach the other component"
  from a sphere that expands and fades in half a second and cannot be studied.
- **Splash is capped below a direct hit in code, not by a comment.**
  `Damage.capped_peak` enforces ADR 0004's "do not tune splash upward to make
  missiles feel more reliable", and the falloff power is floored at quadratic so no
  tuning session can buy the polite straight taper that ADR rejects.

### Decided 2026-08-27 (from building the turret's first weapons)

- **Damage is a pool, every shot resolves in one place, and the guns are sighted**
  (ADR 0049). Three things stage 2 forced. `enemy/component_hits_to_destroy` became
  `enemy/component_hit_points` with `missile/damage` beside it — the default numbers
  reproduce ADR 0042's two missile hits exactly, but a beam applying
  damage-per-second times delta cannot exist in a currency of hits. Every weapon
  resolves through `Shot.resolve`, which compares one entry parameter across hull,
  components and rocks, so "a rock stops the shot" is not a special case anywhere
  and ADR 0043's ordering bug has one place to not happen instead of three.
- **The muzzle is off the sight line, and shots converge.** Built the obvious way
  first, photographed it, and the frame showed *nothing at all* between the trigger
  and the impact flash: fire leaving the sight line travels straight down the
  camera axis and projects to a dot. Dropping the muzzle below the sight puts the
  tracers in frame; converging on the crosshair keeps the sight honest at the range
  the fight is held at. The hitscan beam is exempt and exact at every range, which
  is what its specification asks for.

### Decided 2026-08-27 (from building the gun station)

- **The gun station is a peer of the helm, and its aim is 1:1 in the arena frame**
  (ADR 0048). Four things at once: `G` mans the guns and takes the helm away, there
  is no turret-to-missile edge (`fire()` itself refuses, not just the input
  handler), the aim is an azimuth and an elevation in arena space so the hull turns
  under a gun that stays put, and the mouse moves the gun directly — **ADR 0035's
  reticle deliberately does not apply here**, because a reticle exists to give a
  *vehicle* weight and one of the four weapons is hitscan on purpose.
- **The turret camera's boom levels.** A rigid boom at 55° of elevation swings the
  camera down and back through the hull the gun is bolted to, and the player ends
  up aiming from inside their own ship. `camera/turret_boom_pitch_share` carries
  it; 1.0 restores the rigid boom every other view has.

### Decided 2026-08-27 (from the POC verdict)

- **Every vehicle shares one horizon; nothing rolls** (ADR 0045). Promoted from an
  accident of ADR 0003 to a rule, because the next session to add a vehicle will
  otherwise reach for a roll axis and the reason not to was nowhere in the code.
  Ships and missiles still pitch and climb freely — this is not a 2D plane.
- **Two supported playstyles, one economic gradient** (ADR 0046). Gunboat with
  missiles and turret, or a fast fighter with ship-facing pilot-controlled guns.
  Merchant hulls are large and hauling is the reliable money, so the earning curve
  points at the gunboat. **The tension to watch:** the fighter must earn *less*,
  never *not enough* — ADR 0025's "the cautious path stays viable" applies, and a
  playstyle that cannot pay its own upkeep is a trap dressed as a choice.
- **Brake and boost are missile-tier equipment** (ADR 0047), not baseline verbs.
  The starting missile is reticle steering, a fuse and early detonate. This is
  Pillar 1's "the upgrade tree is itself a difficulty dial" applied to the two
  verbs that turned out to carry the ceiling — and it protects the fuse, which is
  fuzzier to read when boost is available (ADR 0002).

### Decided 2026-08-26

- **Manual ship flight lands** (ADR 0040). `T` toggles; `W`/`S` are a *throttle*
  that stays where it is put, `A`/`D` are held thrusters, the mouse steers through
  the same reticle instrument the missile uses. The autopilot is untouched and
  still starts every run. This is the human lifting a deferral the scope doc always
  marked as one — not a design reversal, and `docs/COMBAT_POC_IMPLEMENTATION.md`
  now carries the amendment.
- **The speed hierarchy is enforced in code.** `ship/manual_max_speed` is clamped
  against `missile/base_speed`, on the whole velocity vector so a thruster held at
  full throttle cannot sum past it either. `CLAUDE.md` calls the hierarchy
  structural; a tuning comment is not a structure.
- **A rock is a cluster of ellipsoids, and the drawn shape is the hit shape**
  (ADR 0041). This answers both halves of the human's report at once — the missing
  corners *and* "they don't look like rocks" — because the thing that fixes the
  silhouette is the same thing that fixes the hit test. `rock_hit_radius_scale`
  is back to 1.0. ADR 0032's mechanism rule is untouched: still no physics body,
  still swept segments, now against `segment_hits_ellipsoid`.
- **The target carries destructible components** (ADR 0042). Two hits each:
  darken, then explode. They respawn, because otherwise a practice run is over in a
  handful of shots and the loop cannot be felt twice.
- **The target is hit as its parts, nearest-first** (ADR 0043, superseding ADR
  0042's hull clauses). See *Fixed this session* — this started as a bug and became
  a rule: **test order cannot substitute for geometry**, and a volume that encloses
  another makes it unreachable however the tests are ordered.
- **The autopilot may not fly the ship in a way the player could not** (ADR 0043).
  It is clamped to the ship's own top speed and turns its nose at a bounded rate.
  Both of those were free while the autopilot was the only thing flying; manual
  flight is what made them observable.
- **Ships are capital-scale gunboats; the engagement is naval, not a dogfight**
  (ADR 0044). The player's hull is 50 m stem to wingtip now — a thick faceted core
  with forward-swept crescent wings, the *StarCraft* reading of "carrier" rather
  than the flat-decked US Navy one. The old `probe.obj` was a 5 m dart, and a dart
  implies a dogfight, which is the wrong game to be reading feel verdicts against.
- **The F2 panel folds.** One collapsible section per `[section]`, collapsed by
  default, each header carrying its value count; `+`/`−` expand and collapse
  everything; the filter reaches into collapsed sections and restores the fold
  state when cleared. 200-odd rows in one scroll had become the bottleneck.
- **`ReticleSteering` is now shared** between the missile and manual flight. The
  two vehicles differ in their numbers, not in their model — a ship that taught a
  different mouse response from the missile would be teaching the wrong one, and
  the player spends far more time in the ship.

### Fixed this session

- **No component was ever hittable.** Reported as "I didn't see any enemy ship
  component ever get hit — my aim can't be that bad." The aim was fine. Every
  component sat inside the hull's 9 m sphere, so the sphere always resolved first,
  four metres before the nearest component — the "components are tested first" rule
  in ADR 0042 never came into play. Worse, that ADR's own gate asserted the
  *opposite* invariant ("components sit within the hull's hit sphere") and passed.
  The hull is now hit as the boxes it is drawn from, components are mounted proud
  of it, and the nearest shape along the shot wins (ADR 0043). The gate checks the
  geometric property — every component's outermost point outside every hull box —
  instead of the ordering, which was never the thing that mattered.
  **Expect hits to be harder now.** The old sphere was far more forgiving than the
  12 m hull it wrapped. If the target feels unfairly small, grow it with
  `enemy/hull_*` rather than re-inflating a sphere around it.
- **Handing the ship back to the autopilot yanked it.** The autopilot re-pointed
  its nose with `look_at`, which snapped through whatever angle the player had left
  it at, on the first frame; and it station-kept at up to 45 m/s against a manual
  ceiling of 34, so it could also move the ship faster than the player ever could.
  Both were invisible while the autopilot was the only thing flying. It now turns
  at `ship/autopilot_turn_rate_deg_per_sec` and is clamped to the ship's own top
  speed. A stale `_last_standoff` could also fire a `snap_to_standoff` teleport
  after a standoff edit made during manual flight; the handover now adopts the
  current value.
- **The strafe summed past the speed ceiling.** Caught in a screenshot reading
  `36 m/s of 34`: the lateral thruster was added on top of a full throttle. The
  clamp is on the whole velocity vector now, so the speed hierarchy cannot be
  broken by holding two keys.
- **The target's art was bigger than its hit sphere** — a 26 m hull inside a 9 m
  sphere, which is the same art-vs-hitbox gap that got the rocks rebuilt, freshly
  reintroduced in the same session. Moot now that the hull is hit as its parts, but
  it is why the hull proportions are what they are.
- **Autopilot could not hold its standoff.** The range correction was a normalised
  blend of tangent and radial, so its authority collapsed at the setpoint and a
  target drifting at 6 m/s outran it — the held range wandered indefinitely, and
  after a `standoff_distance` edit the ship crawled toward the new value ever more
  slowly. It read as "hot reload is broken"; hot reload was fine. Now the radial
  correction is an explicit speed (`range_hold_seconds`, `range_hold_max_speed`),
  and a standoff edit snaps the ship immediately so the typed value is visible at
  once. Guarded by a 30-second simulated regression test.
- **The flight overlay drew nothing.** A `Control` parented straight to a
  `CanvasLayer` has no parent Control to resolve anchors against, so
  `PRESET_FULL_RECT` left it at zero size and the edge-clamping maths degenerated.
  It now sizes itself from the viewport, with a test asserting non-zero size.
- **`glow_intensity` was a constant in arena code** — a feel value in code, which
  the feel-parameter law forbids. Moved to `[arena]`.

### Known inconsistency

The **enemy target is still a 12 m fighter silhouette** — fuselage, nose cone,
wings, fin — which predates ADR 0044 and now contradicts it. If the engagement is
naval, the thing being engaged should read as a gunboat too. Left alone
deliberately rather than changed in the same pass; it is a known inconsistency, not
a considered contrast. Changing it is cheap: the hull is built from tuning values
in `TargetShip._build_hull`, and the hit volumes are registered beside each drawn
part, so the shape and the hit test move together.

### How to tune now

Press **F2** in game. Every value in the file is here, folded into one collapsible
section per `[section]` — click a header to open it, or `+` / `−` to open and close
everything at once. Each header shows how many values are inside. The filter box
reaches into collapsed sections and puts the fold state back when you clear it.
Hover any row for the long description. *Save to tuning.cfg* writes your session
back to the file without disturbing a single comment; *Revert* throws it away.
Editing the file in a text editor still hot-reloads, and disk wins over unsaved
panel edits.

### Engagement envelope — STILL UNMEASURED, and now it is the blocker

`docs/COMBAT_POC_IMPLEMENTATION.md` asks for `ship.max_engagement_envelope` — the
largest distance a fight sprawls across — to be observed rather than guessed,
because it is the first link in the exploration numbers chain:

> envelope → disc height (5-10x the envelope) → cruise speeds → system diameter

`PROJECT_OVERVIEW.md` §Open Questions 1 adds that these are "sized in that order;
each mostly determines the next", and that the height:diameter ratio is an *output*.
So the exploration prototype cannot be scoped without this number, and guessing it
means re-deriving cruise speeds and system size afterwards.

It costs one playtest to observe and it has now been deferred **three** times. The
build it needs is finished; there is nothing left blocking it but a session.

Current geometry, as built: standoff 203 m, missile reach ~350 m un-boosted, target
patrol ±300 m, obstacle field from 70 m out, player hull 50 m. Manual flight makes
this properly observable for the first time — **the standoff you choose when you
own the throttle is the reading that matters**, not the one the autopilot holds.
Write the observed value here.

### Still open from the doc

- Whether the hard-cut camera transition or Descent-style PiP wins the round trip.
  `camera/missile_view_mode` carries the toggle; only `"cut"` is implemented (PiP
  is step 9).

## Notes for the next session

- `make check` before calling anything done. `make shot` to look at it yourself.
- Godot 4.7 segfaults if you `ResourceLoader.load()` a `class_name` script with
  `CACHE_MODE_IGNORE`; the test runner uses the default cache mode for that reason.
- `godot --check-only --script foo.gd` cannot see autoloads, so it reports
  "Identifier not found: Tuning" for most files. It is not a usable gate; the
  in-scene-tree test runner is.
- `tuning.cfg` uses `;` for comments. `#` is **not** a comment character — it gets
  parsed into the next key and corrupts the file without an obvious error.
- Adding a new `class_name` needs `make import` before anything can reference it,
  or the script fails to parse with "Could not find type". `make check` depends on
  `import` for that reason, and carries a `timeout` watchdog — when the runner
  script itself fails to parse, its scene root has no script, nothing calls
  `quit()`, and the engine idles forever instead of failing.
