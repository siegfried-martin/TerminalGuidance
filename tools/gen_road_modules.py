#!/usr/bin/env python3
"""Generate the highway's structural modules — the pieces the road is built from.

The road used to be one continuous swept `ArrayMesh`, and that is why it read as
an abstract volume rather than as a built thing: nothing was repeated, so nothing
looked manufactured. It is now MODULES placed along the path (ADR 0078), which
is what the concept art in docs/reference/highway_concept.jpeg is actually made
of — heavy metal collars at intervals, glazed bays between them, a solid roadway.

**THE UNIT SECTION IS THE CONTRACT.** Every module is authored inside a unit box:

    x in [-0.5, 0.5]   across the road
    y in [-0.5, 0.5]   floor to roof
    z in [-0.5, 0.5]   along the road

and `RoadStructure` scales each instance by (full width, full height, the length
of that module). So a module authored here at 1 x 1 x 1 comes out at whatever
the tuned section is, and **real art replaces the .obj in place** with nothing in
code knowing the difference (ADR 0030).

The second half of the contract: **the unit box is the CLEAR INTERIOR.** Every
piece sits on or outside its faces — the glazing is at exactly +-0.5, the collars
stand proud outward, the roadway hangs below. So the space a ship flies through
is exactly the box, and the lane's half-extents are the structure's inside face.
A module that reaches inward is a module that eats the lane.

Godot convention: -Z is forward, +Y is up, +X is starboard.

Run: python3 tools/gen_road_modules.py   (or `make assets`)
"""

import math
from pathlib import Path

from objlib import box, prism, write_obj

OUT = Path(__file__).resolve().parent.parent / "assets" / "models"

## How far a collar stands proud of the glazing, as a fraction of the section. The
## whole reason a rib reads as a rib: flush with the bays it is a colour change,
## proud of them it is a structure the bays are hung on.
PROUD = 0.07
## How thick a glass panel is. Thin enough to be a pane, thick enough to have two
## faces so it is not invisible edge-on.
PANE = 0.012
## How deep the roadway slab is. It hangs BELOW the interior, so the drivable
## surface is exactly the floor of the lane.
DECK = 0.06
## The kerb along each edge of the roadway, where the floor meets the wall. Small,
## and it is what stops the roadway reading as a floating plane.
KERB = 0.035
## How many facets a circle gets. Faceted rather than smooth, matching the cut-crystal
## read of the hulls, and it keeps every piece a convex solid.
FACETS = 24
## How thick the steel of a ring is, as a fraction of its own inner radius.
RING_STEEL = 0.16


def rib_parts():
    """A collar: four beams around the section, standing proud of the glazing.

    Built as four convex boxes rather than one picture-frame solid, because
    `objlib.Part` fixes face winding against the part's own centroid and that is
    only exact for a convex piece.
    """
    outer = 1.0 + 2.0 * PROUD
    return [
        box((-(0.5 + PROUD * 0.5), 0.0, 0.0), (PROUD, outer, 1.0)),
        box((+(0.5 + PROUD * 0.5), 0.0, 0.0), (PROUD, outer, 1.0)),
        box((0.0, +(0.5 + PROUD * 0.5), 0.0), (outer, PROUD, 1.0)),
        box((0.0, -(0.5 + PROUD * 0.5), 0.0), (outer, PROUD, 1.0)),
    ]


def bay_parts():
    """The glazing between two collars: both walls and the roof.

    Not the floor. The floor is the roadway, and it is the one face of this
    structure that is deliberately solid — you drive on it (ADR 0079).
    """
    return [
        box((-(0.5 + PANE * 0.5), 0.0, 0.0), (PANE, 1.0, 1.0)),
        box((+(0.5 + PANE * 0.5), 0.0, 0.0), (PANE, 1.0, 1.0)),
        box((0.0, +(0.5 + PANE * 0.5), 0.0), (1.0, PANE, 1.0)),
    ]


def plate_parts():
    """The roadway: a slab hanging below the interior, with a kerb up each edge.

    Below rather than inside, so the surface a ship flies over is exactly y = -0.5
    and the lane's floor and the road's surface are the same plane.
    """
    return [
        box((0.0, -(0.5 + DECK * 0.5), 0.0), (1.0, DECK, 1.0)),
        box((-(0.5 - KERB * 0.5), -(0.5 - KERB * 0.5), 0.0), (KERB, KERB, 1.0)),
        box((+(0.5 - KERB * 0.5), -(0.5 - KERB * 0.5), 0.0), (KERB, KERB, 1.0)),
    ]


def ring_parts():
    """A steel hoop, hole along Z. Authored at INNER DIAMETER 1.0, so an instance
    scaled uniformly by the ring's diameter has exactly that opening.

    Scaled uniformly, unlike everything else here — a ring marks a mouth you fly
    through, and a mouth that is an ellipse is a mouth you cannot judge the size of
    at a glance. It is the one piece whose size is its meaning (ADR 0080).
    """
    parts = []
    inner, outer = 0.5, 0.5 * (1.0 + RING_STEEL)
    for i in range(FACETS):
        a = 2.0 * math.pi * i / FACETS
        b = 2.0 * math.pi * (i + 1) / FACETS
        face = [
            (inner * math.cos(a), inner * math.sin(a), -0.5),
            (outer * math.cos(a), outer * math.sin(a), -0.5),
            (outer * math.cos(b), outer * math.sin(b), -0.5),
            (inner * math.cos(b), inner * math.sin(b), -0.5),
        ]
        parts.append(prism(face, (0.0, 0.0, 1.0)))
    return parts


def open_bay_parts(missing):
    """A bay with one face left out, so a ramp can leave through it.

    The whole face, not a hole in it: an interchange opening is full height, and a
    circular cut in a panel scaled by height and by length is an ellipse. The steel
    ring placed in the gap is what says how big the mouth actually is.
    """
    faces = {
        "left": box((-(0.5 + PANE * 0.5), 0.0, 0.0), (PANE, 1.0, 1.0)),
        "right": box((+(0.5 + PANE * 0.5), 0.0, 0.0), (PANE, 1.0, 1.0)),
        "roof": box((0.0, +(0.5 + PANE * 0.5), 0.0), (1.0, PANE, 1.0)),
    }
    return [part for key, part in faces.items() if key != missing]


def pane_parts():
    """The median: one pane of glass down the middle, floor to roof.

    Only the mainline pair carries one — it is the thing that separates the two
    directions, and a ramp has only one direction on it.
    """
    return [box((0.0, 0.0, 0.0), (PANE, 1.0, 1.0))]


def main():
    for name, parts in [
        ("road_rib", rib_parts()),
        ("road_bay", bay_parts()),
        ("road_plate", plate_parts()),
        ("road_pane", pane_parts()),
        ("road_ring", ring_parts()),
        ("road_bay_open_right", open_bay_parts("right")),
        ("road_bay_open_left", open_bay_parts("left")),
        ("road_bay_open_top", open_bay_parts("roof")),
    ]:
        write_obj(OUT / ("%s.obj" % name), name, parts, "gen_road_modules.py",
                  uv_scale=1.0)


if __name__ == "__main__":
    main()
