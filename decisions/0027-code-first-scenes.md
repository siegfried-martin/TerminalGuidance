# ADR 0027 — Scenes are shells; the editor is a viewer

*Status: accepted · 2026-08-23 · made while bootstrapping the repo*

## Decision

`.tscn` files contain a root node and a script, nothing else. Entities are
constructed programmatically from data in `_ready()`. Input bindings live in
`data/input_map.json` and are applied by an autoload, not through the editor's
Input Map tab. `project.godot` stays minimal.

## Why

The whole AI-heavy workflow depends on the model being able to read the game as a
codebase and on a human being able to review a change as a diff. A decision that is
only discoverable by opening a scene in a GUI is invisible to both.

It also keeps merge conflicts tractable, which matters as soon as work happens on
branches.

## What this forbids

- Do not add authoritative state through editor manipulation.
- Do not use the editor's Input Map tab; those actions land in `project.godot` and
  get clobbered by the `Bindings` autoload anyway.
- `.tscn` diffs must remain human-reviewable.
