# ADR 0031 — Visual changes are verified from the CLI before a human is asked to look

*Status: accepted · 2026-08-23 · made while bootstrapping the repo*

> *Amended 2026-09-01, at the human's suggestion; the decision is unchanged and one
> clause is added.* **A capture harness takes the controls; it does not share them
> with whoever is at the desk.** `make shot` renders into a REAL WINDOW, so a hand
> resting on the mouse was steering the ship and breaking approach locks in the middle
> of runs that were supposed to be reproducible — a rendered frame was a coin flip
> rather than a verification, which is the one property this ADR depends on.
> `ExplorationScene.set_reads_input(false)` hands the scene, the ship and the map to
> the harness together, and the harness flies through `input_throttle`,
> `input_stick`, `input_strafe` and `map().pressed_dock` instead. The flight code
> underneath is the same code. **It has to be a faithful stand-in**: the approach
> envelope asks the SHIP whether it is being flown rather than asking the devices, so a
> harness holding the throttle aborts a landing exactly as a player holding W does.
> Every harness that loads the exploration scene sets it, and nothing in the game may.

## Decision

`make shot` renders frames to `.shots/*.png` via Godot's movie writer. The model
reads those frames directly.

## Why

This closes the loop that would otherwise require a human for every visual change.
On the bootstrap session it caught two things immediately: the first ship model
read as a paper plane, and the key light was aimed at the side of the hull the
camera could not see.

It does **not** extend to feel. A rendered frame answers "does this look like what
I intended"; it cannot answer "is this fun," and no amount of frames will.

## What this forbids

- Do not ask the human to look at a visual change that has not been looked at.
- Do not use rendered frames to form or report a feel verdict. Feel is human-only.
