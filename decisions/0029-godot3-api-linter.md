# ADR 0029 — A data-driven denylist fails the build on Godot 3 APIs

*Status: accepted · 2026-08-23 · made while bootstrapping the repo*

## Decision

`tools/tests/godot3_denylist.json` holds regex rules for Godot 3.x APIs; the test
runner scans every `.gd` and fails on a hit. `# godot4-lint: ignore` is the escape
hatch. `make apiref` dumps this exact engine build's 771-class reference to
`.apiref/` for grounding.

## Why

This is the documented failure mode for LLM-written Godot code: years of Godot 3
tutorials in the training data, emitted with total confidence. `Spatial`,
`yield()`, `export var`, `.instance()`, `connect("sig", self, "method")`,
`File.new()`, `deg2rad()`, `PoolVector3Array`.

The POC doc calls for this to be caught by the machine rather than by a human
reading diffs. The denylist lives in a data file rather than in the linter source
so that the linter does not flag its own pattern table — which it did, on the first
run.

`make apiref` is the other half: when unsure whether an API is 3.x or 4.x, grep the
generated class reference instead of recalling it.

## What this forbids

- Add a rule the first time any Godot-3-ism gets past review.
- Prefer grepping `.apiref/` over trusting memory for any uncertain API.
