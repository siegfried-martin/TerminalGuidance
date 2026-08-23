# ADR 0023 — Godot 4 over Unity, for text legibility

*Status: accepted · 2026-08-23 · recorded from `docs/PROJECT_OVERVIEW.md` v3 and `docs/COMBAT_POC_IMPLEMENTATION.md` v3; the decision predates this repo*

## Decision

Godot 4.x, native on Linux, GDScript. The entire project — scenes, resources,
scripts — is plain text in the repo.

## Why

The workflow is AI-heavy: Claude Code owns systems (faction sim, economy, missile
physics, autopilot, tooling), all of which is LLM-native and headlessly testable.
That workflow depends on the model being able to read the whole game like a
codebase and on every change being a reviewable diff.

Unity's scene and prefab serialisation is not that. Godot's is.

## What this forbids

- Do not introduce a binary project format, a binary scene, or an editor-only
  authoring step for anything load-bearing.
