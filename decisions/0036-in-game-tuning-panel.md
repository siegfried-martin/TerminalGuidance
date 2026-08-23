# ADR 0036 — Tuning is edited in an in-game panel; the file stays the source of truth

*Status: accepted · 2026-08-23 · human direction · refines ADR 0026 and ADR 0033*

## Decision

A debug panel (`DebugPanel` autoload, F2) lists every value in `tuning.cfg` down
the left of the screen and edits it live. Save writes back to `tuning.cfg`.

- **The file is still the only source of truth.** The panel is an editor for it,
  not a parallel store. There is no separate overrides file, no user-settings
  layer, and no value that exists only in the UI.
- **Labels, tooltips and slider ranges come from the file's own comments.**
  Documenting a value and exposing it in the panel are the same act, so a value
  cannot be added to the panel without being explained.
- **Saving preserves every comment.** `TuningWriter` rewrites only the value text
  of changed lines; a save that touched five values changed exactly five lines,
  columns and all.

Annotation format, parsed by `TuningSchema`:

```ini
;; Long-form description. As many lines as it needs. Shown as the tooltip.
base_speed = 70.0        ; [20..400] m/s. Short label, shown on the row
```

`[min..max]` is optional. With it, a number gets a slider; without it, a plain
number box.

## Why

Dragging a slider while watching a missile fly is a different instrument from
typing a number in another window and alt-tabbing. The POC doc puts "make
changing any of these take zero seconds to test" squarely in the AI's column, and
a file round-trip is not zero seconds.

The tooltips are the other half. The inline comments have to stay short to keep a
section on screen (ADR 0033), which left several values genuinely unclear —
`velocity_inheritance`, `range_hold_seconds` and `missile_follow_lag` all needed a
paragraph. A tooltip has room for a paragraph and costs no screen space until
hovered, so the short label and the long description can both exist without
fighting.

Comment-preserving save is what makes the loop closed rather than one-way. Without
it the panel would be a scratchpad whose results had to be copied out by hand, and
the documentation would be destroyed the first time anyone pressed Save.

File watching is kept. Editing `tuning.cfg` from an editor or a script still
hot-reloads, and a reload from disk clears any unsaved panel edits — disk wins,
because that is the direction that cannot be undone from inside the game.

## What this forbids

- Do not add a second place where feel values can live. No user-settings file, no
  in-memory-only value, no panel-only override that never reaches `tuning.cfg`.
- Do not call `ConfigFile.save()` on the tuning file. It serialises values only
  and would delete every comment — which is now also every tooltip and every
  slider range (ADR 0033).
- Do not add a value to `tuning.cfg` without a comment. The comment is the
  panel's label, and an undocumented row is worse than no row.
- Keep `TuningSchema` and `TuningWriter` pure and static. They are tested by
  round-tripping text, which is only possible while they never touch the disk.
