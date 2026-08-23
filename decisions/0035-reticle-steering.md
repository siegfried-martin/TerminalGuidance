# ADR 0035 — Missile steering is a reticle the missile turns towards

*Status: accepted · 2026-08-23 · human direction during the first flight session · refines ADR 0003*

## Decision

Input no longer rotates the missile. Input moves a **reticle** — an intended
direction, drawn on screen — and the missile turns towards the reticle at
`missile/turn_rate_deg_per_sec`.

- The reticle is clamped to a cone of `missile/reticle_max_angle_deg` around the
  nose, so it can never be parked somewhere the missile has no chance of reaching.
- The overlay draws the reticle and a faint line from the nose to it, so the lag
  is visible and not merely felt.
- `aim off` in the debug HUD reports the angle between the two, which is the
  number to watch when tuning the turn rate.

## Why

Direct steering — input rotating the basis, clamped per frame by the turn rate —
made the missile feel weightless. The cap was doing its arithmetic correctly and
still reading as unrealistic, because a rate cap applied to an instantaneous
input is invisible: the missile went where you pointed, just no faster than the
cap, and the player has nothing to compare against to perceive the limit.

Splitting intent from state makes the limit legible. The reticle is where you
asked to go, the nose is where you are, and the gap between them *is* the
missile's mass. Same physical constraint, now perceivable.

This refines ADR 0003 rather than reversing it. That decision rejects vector
thrust in favour of direct screen-space mapping, and this is still direct
screen-space mapping — the reticle goes exactly where the stick points, with no
inertia the player has to model. What changed is that the missile is no longer
identical to the reticle.

## What this forbids

- Do not remove the reticle to make the missile "more responsive". Tune
  `turn_rate_deg_per_sec` instead; that is the dial.
- Do not give the missile momentum, drift, or thrust vectoring. It turns towards
  the reticle at a bounded rate and it flies at a constant forward speed. Anything
  more is the flight model ADR 0003 rejects.
- Do not let the reticle escape its cone. An unreachable reticle is a control that
  lies to the player.
- Roll stays locked out. A rolling missile makes "up" ambiguous and breaks the
  screen-space mapping both decisions depend on.
