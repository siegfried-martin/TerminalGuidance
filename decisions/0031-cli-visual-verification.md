# ADR 0031 — Visual changes are verified from the CLI before a human is asked to look

*Status: accepted · 2026-08-23 · made while bootstrapping the repo*

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
