# ADR 0049 — Damage is a pool, every shot resolves through one place, and the guns are sighted

*Status: accepted · 2026-08-27 · from building stage 2 of `docs/TURRET_MODE_IMPLEMENTATION.md`*

## Decision

Three things the turret's first two weapons forced, none of which is only about
those two weapons.

1. **A component carries a pool of hit points, and every weapon spends a damage
   number against it.** `enemy/component_hits_to_destroy` is replaced by
   `enemy/component_hit_points`, and the ridden missile now carries
   `missile/damage`. ADR 0042's behaviour is unchanged — at 100 points against a
   warhead of 50 it is still exactly two missile hits — only the currency is.
2. **Every shot, travelling or hitscan, resolves through `Shot.resolve`**, which
   compares one entry parameter across the target's parts, its components and the
   rocks, and returns whichever is nearest. Callers do not order their own tests.
3. **The guns are sighted, not slung.** The muzzle sits off the sight line
   (`turret/muzzle_mount_offset`), and a travelling round is fired at the point the
   crosshair marks rather than parallel to the aim — so it is exact at
   `turret/convergence_distance` and progressively off either side of it. The
   crosshair is drawn at that same distance, so there is one number rather than two
   that have to agree. **The hitscan beam is exempt**: it resolves along the sight
   line and is exact at every range, and is merely *drawn* from the muzzle.

## Why

**1: a counter cannot tell four weapons apart.** An autocannon round, one frame of
a beam, a missile warhead and a splash at the edge of a blast are not
interchangeable events, and the specification asks for all four. Counting hits
would force every weapon to do the same amount of damage or to fake it by counting
some hits twice. The pool is also what ADR 0004's "splash is steeply worse than a
direct hit" is measured in — that rule is unimplementable in a currency of hits.

The beam is the case that makes it unavoidable: it applies damage-per-second times
delta, so its damage is a *fraction* of a hit by construction, and it darkens the
component continuously rather than in steps. That is the visible difference between
a beam and a gun, and it needs a real number to exist.

**2: ADR 0043 has already been paid for once.** That ADR exists because a test
order stood in for geometry — components were tested before a hull sphere that
enclosed them, and no component was ever reachable. Three weapons each doing their
own ordering is three chances to reintroduce it. One resolver, one comparison, and
"a rock between the gun and the target stops the shot" is not a special case
anywhere: it falls out of comparing parameters.

This is why `FlightGeometry` gained `segment_ellipsoid_entry` and `ReferenceField`
gained `hit_entry`. The missile only ever needed to know *whether* it hit a rock,
because it dies either way. A round needs to know *where*, or it scores on
something it never reached.

**3: a gun whose shots are invisible gives no feedback.** Fired from the sight
line, every tracer and every beam travels straight down the camera's view axis and
projects to a single dot at the crosshair — this was built, photographed, and the
frame showed nothing at all between pulling the trigger and the impact flash.
Dropping the muzzle below the sight puts the fire in frame.

Converging then follows immediately: a round fired *parallel* from an offset muzzle
lands a muzzle-offset below the crosshair at every range, forever, which is a sight
that lies. Converging makes the sight honest at the range the fight is held at,
which is the same trade a real sighted gun makes.

The beam is exempt because the specification is explicit that it is hitscan **so
that lead and travel time never have to be factored in**. A beam that landed low at
close range would be factoring geometry back in through the side door. It is drawn
from the muzzle regardless, and at a two-degree divergence over 180 m nobody can
see the difference — what they can see is that the beam comes out of the ship.

## What this forbids

- **Do not add a weapon that damages a component by any route other than
  `TargetShip.damage_component(index, amount)`.** No second currency, no "counts as
  two hits", no per-weapon special case inside the target.
- **Do not let a weapon do its own hit ordering.** New shootable things are added
  to `Shot.resolve`, where they are compared against everything else by parameter.
  A weapon that tests one set before another has reintroduced ADR 0043's bug.
- **Do not fire a travelling round parallel to the aim**, and do not add a second
  key for the crosshair's draw distance. One convergence distance, one meaning.
- **Do not give the hitscan beam a convergence.** Its exactness at every range is
  the specification, not an oversight.
- **Do not zero `turret/muzzle_mount_offset` to "fix" the parallax.** That trades a
  visible, tunable, range-dependent error for invisible fire, which is worse and
  was the state this replaced.
