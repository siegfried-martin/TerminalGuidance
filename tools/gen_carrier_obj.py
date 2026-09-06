#!/usr/bin/env python3
"""Generate assets/models/carrier.obj — the player's ship.

A capital-scale gunboat (ADR 0044), and specifically the *StarCraft* reading of
"carrier" rather than the US Navy one: a thick faceted core with forward-swept
crescent wings reaching past the prow, not a flat runway deck with an island.
The silhouette has to say "large gunboat" from behind, because the chase camera
is almost always behind it.

Authored at 1 unit = 1 metre — 50 m stem to wingtip, 44 m across the crescent —
so `ship/hull_scale` is 1.0 and the tuning file's distances are all in the same
units as the mesh. Compare against ship/standoff_distance while tuning: at 203 m
the ship is a quarter of the range to its target, which is the naval reading and
not the dogfight one.

Geometry helpers and .obj emit live in tools/objlib.py, shared with the probe
generator. Godot convention: -Z is forward, +Y is up, +X is starboard.

Run: python3 tools/gen_carrier_obj.py   (or `make assets`)
"""
from pathlib import Path

from objlib import box, cone, frustum, mirror_x, prism, ring, write_obj

OUT = Path(__file__).resolve().parent.parent / "assets" / "models" / "carrier.obj"


def build_parts():
    parts = []

    # --- core hull ------------------------------------------------------------
    # Stations from prow to stern. Widest and deepest just aft of midships, which
    # is what gives it mass; a hull of constant section reads as a girder.
    stations = [
        ring(-19.0, 3.2, 1.6, 1.4),
        ring(-11.0, 6.0, 3.4, 3.0),
        ring(-1.0, 8.4, 5.2, 4.4),
        ring(9.0, 7.6, 4.6, 4.0),
        ring(17.0, 5.4, 3.0, 2.6),
    ]
    for a, b in zip(stations, stations[1:]):
        parts.append(frustum(a, b))
    parts.append(cone(stations[0], (0.0, 0.4, -25.0)))       # prow
    parts.append(frustum(stations[-1], ring(20.0, 5.0, 2.6, 2.4)))

    # --- crescent wings -------------------------------------------------------
    # Swept *forward*, reaching past the prow. This is the whole silhouette: it is
    # what separates a bulk hull from a fighter, and it reads at any range.
    wing_y = -1.7
    wing_plan = [
        (4.6, wing_y, -16.0),
        (18.5, wing_y, -27.0),
        (21.8, wing_y, -21.0),
        (16.0, wing_y, -1.0),
        (9.5, wing_y, 7.0),
        (4.6, wing_y, 7.0),
    ]
    wing = prism(wing_plan, (0.0, 3.4, 0.0))
    parts.append(wing)
    parts.append(mirror_x(wing))

    # Wingtip pods — the launch bays. Blunt mass on the ends of the crescent, so
    # the tips do not taper away to nothing.
    for part in (box((19.6, 0.0, -23.0), (4.4, 4.8, 8.0)),
                 box((19.6, 0.0, -27.6), (2.6, 2.6, 3.0))):
        parts.append(part)
        parts.append(mirror_x(part))

    # --- dorsal crest ---------------------------------------------------------
    crest_plan = [
        (2.6, 4.4, -9.0),
        (3.8, 4.4, 1.0),
        (2.4, 4.4, 12.0),
        (-2.4, 4.4, 12.0),
        (-3.8, 4.4, 1.0),
        (-2.6, 4.4, -9.0),
    ]
    parts.append(prism(crest_plan, (0.0, 4.2, 0.0)))
    parts.append(box((0.0, 9.8, 4.0), (3.0, 2.0, 9.0)))       # bridge block
    parts.append(box((0.0, 13.4, 6.0), (0.6, 5.2, 0.6)))      # spine mast

    # --- ventral hangars ------------------------------------------------------
    pod = box((5.0, -6.2, 1.0), (4.2, 3.2, 15.0))
    parts.append(pod)
    parts.append(mirror_x(pod))
    parts.append(box((0.0, -6.8, -2.0), (5.0, 2.6, 11.0)))

    # --- gun blisters ---------------------------------------------------------
    # Four a side down the hull shoulders. The "gunboat" half of the read.
    for z in (-12.0, -3.0, 6.0, 13.0):
        blister = box((7.4, 2.0, z), (2.6, 2.2, 3.0))
        parts.append(blister)
        parts.append(mirror_x(blister))
        barrel = box((8.8, 2.1, z - 2.4), (0.6, 0.6, 3.6))
        parts.append(barrel)
        parts.append(mirror_x(barrel))

    # --- stern ----------------------------------------------------------------
    for sx in (-4.6, 0.0, 4.6):
        parts.append(box((sx, 0.2, 21.6), (3.4, 3.4, 2.6)))

    return parts


def main():
    write_obj(OUT, "carrier", build_parts(), "gen_carrier_obj.py", uv_scale=0.08)


if __name__ == "__main__":
    main()
