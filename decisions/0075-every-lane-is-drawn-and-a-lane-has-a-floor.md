# ADR 0075 — Every lane is drawn; the one you are on is brighter, and a lane has a floor

*Status: accepted · 2026-08-30 · from flying the translucent road · supersedes ADR 0074's "one lane lit" clause*

## Decision

**Every deck draws its shell**, at `lane_shell_idle_alpha`; the deck being ridden
draws the same shell at `lane_shell_alpha` and adds its rings and its sixteen
longitudinal lines.

**The shell is vertex-coloured around its section.** The floor has its own colour and
carries more of the alpha than the roof (`lane_shell_floor_color`,
`lane_shell_floor_bias`), so a lane has an up and a down from anywhere inside it.

ADR 0074's *"Do not draw the shell on every deck"* is superseded. Everything else in
0074 stands, including the alpha ceiling and the build-once rule.

## Why

**One lane lit produced a bug that reads as a rendering fault.** Taking a ramp hands
the shell over to it, so the mainline's tube stops being drawn straight ahead — the
road appears to vanish for a few seconds, and then the ramp swings into view beside
you. The human reported exactly that and guessed, correctly, that it was the moment
the ramps became available.

The reasoning in 0074 was about clutter, and it was measuring the wrong thing. The
clutter that was actually reported came from **wireframe** decks — four full rib
cages every 120 m in identical colour. A translucent surface does not read that way:
a faint tube beside you is a road you can see is there, which is the opposite problem
from the one 0074 was solving. **A road you can only see once you are committed to it
is not a road you can choose**, and choosing is the whole of what an interchange is
for.

**Flat colour was why it did not read as a tunnel.** The human could not say which
part of the sheen was left, right, above or below, because every part of it was
identical — and a tube of one flat colour is, visually, a fog with a boundary rather
than a place with a shape. Real tunnels give two cues and the lane had neither:
longitudinal lines converging to a vanishing point, and a floor that is not the roof.
Sixteen lines and a floor colour supply both.

The tint is carried in **vertex colours rather than in lighting**, deliberately: an
unshaded lane looks the same wherever the system's key light happens to point, and a
road that changes character between systems is a road the player cannot learn. The
per-vertex alpha is *relative* and multiplies into the material's, so the one slider
that could turn the road into a tunnel is still the one slider.

## What this forbids

- Do not go back to drawing the shell only on the ridden deck. That is this ADR.
- Do not make an idle deck's shell as strong as the ridden one's. Which lane is yours
  has to be readable at a glance, and the gate checks the ordering.
- Do not light the shell with the scene's lights. It is unshaded on purpose.
- Do not put the floor/roof distinction into the material's albedo. It lives in the
  vertices; an albedo tint flattens the section back into one colour.
- Do not solve a "which lane am I in" problem by hiding lanes. Brightness, not
  absence.
