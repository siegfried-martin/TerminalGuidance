# ADR 0074 — The lane is a translucent solid, and "visually open" means you can see through it

*Status: accepted · 2026-08-30 · from the human flying the wireframe road*

## Decision

The deck the ship is riding is drawn as a **translucent shell** — a closed tube of the
lane's own cross-section, at `lane_shell_alpha` — with rails along it and widely
spaced rings across it. Every other deck is four dim rails and nothing else.

ADR 0057's *"the lane is visually open"* is read as **the surrounding space stays
rendered and visible through it**, which is what that ADR's own text asks for. It is
not read as *drawn with lines*. The gate checks the alpha, not the primitive.

The rings are demoted to a **speed cue** and spaced accordingly. They are no longer
carrying the shape, because the shell is.

## Why

The wireframe road was built from the right instinct and did not work. The human flew
it and reported that the lane did not read as a place — *"the wire wrapping on the
highway is not doing it"* — and, separately, that they kept driving off course near
interchanges because there was no way to tell which of four overlapping wire tubes was
theirs. A road you cannot see is not open, it is absent.

The thing ADR 0057 was actually protecting is in its own words: no camera cut, no
scene load, no non-interactive transit, **the surrounding space stays rendered**, and
floating origin and LOD rules apply inside the tube exactly as outside. A surface at a
twentieth of an alpha satisfies every one of those. Lines were one way to guarantee it
and turned out not to be the only one, so the gate now asserts the guarantee directly
rather than the implementation that used to imply it.

Two things fell out of building it that are worth writing down, because both are
non-obvious and both will be re-derived otherwise.

**You are inside the surface, so whatever tints it tints the whole view.** A bright
skin at 0.10 lifted the black of space until the deep field stopped reading — the road
became a fog with the scenery behind it. The colour is muted and the alpha is a
twentieth for that reason, not as a default nobody thought about.

**The geometry is built once and toggled, never built on activation.** A mainline's
shell is tens of thousands of vertices. Rebuilding it at the moment the ship merges
would put a frame hitch exactly where the player is doing the one thing the road
exists for.

## What this forbids

- Do not raise `lane_shell_alpha` toward opacity. Past the gate's threshold the road
  is the tunnel ADR 0057 forbids, and the check exists because this is the slider that
  would do it.
- Do not give the shell a bright albedo. You are inside it; a bright skin is a
  full-screen colour filter over everything the lane was supposed to leave visible.
- Do not draw the shell on every deck. One lane lit is how the player knows which lane
  they are in; four is the thicket this replaced.
- Do not rebuild lane geometry inside `set_active`. Build it in `rebuild` and toggle
  visibility.
- Do not restore the wireframe-only lane on the strength of ADR 0057. That reading is
  superseded here; the clause is about seeing through the lane, not about primitives.
