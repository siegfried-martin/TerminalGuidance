# ADR 0028 — The test gate runs in a real scene tree, not via --check-only

*Status: accepted · 2026-08-23 · made while bootstrapping the repo*

## Decision

`make check` runs `tools/tests/test_runner.tscn` headless. It asserts that every
`.gd` compiles, that no Godot-3 API appears, that required tuning keys and input
actions exist, that assets import, and that the sandbox scene builds its nodes.
Exit code gates the build.

## Why

`godot --headless --check-only --script foo.gd` **cannot see autoloads**. It
reports `Identifier not found: Tuning` for nearly every gameplay file, so it is
useless as a gate. Autoloads only exist when the project's main loop is up, which
means the gate has to run inside a scene tree.

Two Godot 4.7 specifics found the hard way and worth keeping written down:
`ResourceLoader.load()` returns a non-null GDScript even for a file that failed to
parse — `can_instantiate()` is the signal that actually flips — and loading a
`class_name` script with `CACHE_MODE_IGNORE` duplicates it in the global class
table and segfaults the engine.

## What this forbids

- Extend the gate in the same change that adds a system.
- Do not use `--check-only` as a correctness gate.
- Do not use `CACHE_MODE_IGNORE` on scripts.
