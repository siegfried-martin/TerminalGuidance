# ADR 0075 — Every lane is drawn; the one you are on is brighter, and a lane has a floor

*Status: accepted · 2026-08-30 · from flying the translucent road · supersedes ADR 0074's "one lane lit" clause*

## Decision

**Every deck draws its shell**, at `lane_shell_idle_alpha`; the deck being ridden
draws the same shell at `lane_shell_alpha` and adds its rings and its sixteen
longitudinal lines.

**The shell is vertex-coloured around its section**, so a lane has an up and a down
from anywhere inside it.

> *Amended the same day, and the decision is unchanged.* The scheme this first shipped
> with was floor-versus-roof. It is now a **gradient toward the face the two decks
> share** — `lane_shell_outer_color`, `lane_shell_divider_color`,
> `lane_shell_divider_bias`, replacing the `lane_shell_floor_*` keys named here. The
> decks are stacked flush, so that face is the upper deck's floor and the lower deck's
> roof, and running the gradient toward it on both makes the seam one colour from
> either side: a lane divider, visible from outside as a stripe down the middle of the
> stack and from inside as which deck you are on. The mechanism below is untouched —
> vertex colour rather than lighting, relative alpha multiplying into the material's —
> and setting the two colours equal returns a flat tube.

ADR 0074's *"Do not draw the shell on every deck"* is superseded. Everything else in
0074 stands, including the alpha ceiling and the build-once rule.

> *Amended again by ADR 0077, and the decision is still unchanged.* The carriageways
> are side by side now, so the shared face is the **left of both of them** rather than
> one deck's floor and the other's roof. The gradient still runs toward it from both,
> and `shade()` lost its deck argument in the process: one function answers for both
> sides, so the seam matches by construction instead of by two mirrored cases
> agreeing. The mechanism is otherwise untouched.

> **Superseded in mechanism by ADRs 0078 and 0079, and the decision still stands.**
> There is no shell. The road is a building of modules and the lane inside it is
> drawn as MARKINGS painted on its own carriageway — every carriageway is marked, and
> the ridden one is painted bright. That is this ADR's clause word for word, carried
> by paint instead of by a tube. The vertex gradient and its three colour keys are
> gone: the median is a pane of glass now, which is a better answer to "which side am
> I on" than a colour ramp was.

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
