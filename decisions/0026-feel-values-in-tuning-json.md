# ADR 0026 — Every feel value lives in tuning.json, and the getters have no defaults

*Status: accepted · 2026-08-23 · made while bootstrapping the repo*

## Decision

All gameplay-feel values load from `tuning.json` through the `Tuning` autoload and
are read at the point of use. The file hot-reloads on save. `Tuning.num()` and its
siblings take **no default argument**: a missing key errors, registers in the debug
HUD in red, and fails `make check`.

## Why

The feel-parameter law exists because feel verdicts are human-only and AI-authored
code will otherwise accrete constants that quietly become design. Hot reload exists
because the AI's job is to make changing any parameter take zero seconds to test.

The no-default rule is the part that is easy to get wrong. A default argument is a
feel constant hiding in code — it makes a typo'd key behave plausibly, and it means
a parameter can exist in code without existing in the file the human tunes.
Failing loudly is the whole point.

Infrastructure constants (poll intervals, buffer sizes, layer numbers) are not feel
values and stay in code as `const`. The test: would the human ever want to nudge it
while looking at the screen?

## What this forbids

- Do not add a default-value overload to the tuning getters.
- Adding a feel parameter means editing `tuning.json`, reading it via `Tuning`,
  adding it to `REQUIRED_TUNING_KEYS`, and surfacing it in the HUD — same change.
- Systems that cache a derived value must rebuild on `Tuning.reloaded`.
