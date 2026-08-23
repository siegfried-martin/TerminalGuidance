# ADR 0033 — The tuning file is a Godot ConfigFile, so feel values carry inline comments

*Status: accepted · 2026-08-23 · refines ADR 0026, which is otherwise unchanged*

## Decision

`tuning.json` becomes `tuning.cfg`, parsed by Godot's built-in `ConfigFile`.

- Comments start with `;` and may sit at the end of a value line.
- **`#` is not a comment character.** It is parsed into the following key and
  silently corrupts the file.
- Values are Godot literals. `Vector3(x, y, z)` is a real Vector3 rather than a
  three-element array.
- Colours stay hex strings (`"#c9ccd2"`). `ConfigFile`'s `Color()` literal needs
  four float components, which is not a form a human wants to edit.
- Section names map onto the existing lookup paths: `Tuning.num("ship/arc_speed")`
  reads key `arc_speed` from `[ship]`. No call site changed.

`docs/COMBAT_POC_IMPLEMENTATION.md` specifies "`tuning.json` (or `.tres` text
resource)". A `ConfigFile` is within that intent — a plain-text, diffable,
hot-reloadable file at the repo root — and it beats both options on the one axis
that matters for a file a human edits while playing.

## Why

JSON cannot carry comments, and the tuning file is the human's instrument. A wall
of forty bare numbers gives no indication of units, of sane ranges, or of which
values are coupled — `flash_end_radius` has to stay under
`missile_follow_distance` or the camera ends up inside the explosion, and nothing
in a JSON file could say so.

Inline comments specifically, over comment lines above each value: they roughly
halve the line count, so more of a section fits on screen at once. That matters
because tuning is comparative — you are reading `base_speed` against
`turn_rate_deg_per_sec` against `fuse_seconds`, and scrolling between them breaks
the comparison.

`ConfigFile` over JSON-with-comment-stripping or TOML because it is **native**.
No custom parser, no dependency, no format that Godot half-understands. The
alternative was pre-stripping comments before `JSON.parse_string`, which is a
parser we would then own and which would report errors against line numbers that
no longer match the file.

Verified against the engine rather than assumed: `;` inline comments parse, `#`
does not, semicolons inside quoted strings are safe, `Vector3(...)` round-trips,
and a truncated value mid-save produces error 43 — which the loader treats as
"keep the previous values" so a save-in-progress cannot wipe a running session.

## What this forbids

- Do not use `#` for a comment in `tuning.cfg`.
- Do not call `ConfigFile.save()` on the tuning file from code. `ConfigFile`
  serialises values only; it would silently delete every comment in the file.
  Tuning is human-authored and read-only to the game.
- Do not reintroduce a defaults mechanism on the getters. ADR 0026 still stands:
  a missing key errors, shows red in the HUD, and fails `make check`.
- Colours stay hex strings. Do not "fix" them into `Color()` literals.
