#!/usr/bin/env python3
"""Generate assets/models/probe.obj — the gray-box stand-in ship hull.

Placeholder assets are generated from a script wherever that is practical, so
an asset review is a diff review and nothing needs a DCC tool to reproduce.
Real art replaces the .obj in place; nothing in code knows it was generated.

Run: python3 tools/gen_probe_obj.py   (or `make assets`)

Geometry helpers and .obj emit live in tools/objlib.py, shared with the carrier
generator. Godot convention: -Z is forward, +Y is up.
"""
from pathlib import Path

from objlib import Part, box, mirror_x, prism, write_obj

OUT = Path(__file__).resolve().parent.parent / "assets" / "models" / "probe.obj"


# --- the probe ---------------------------------------------------------------

def build_parts():
    parts = []

    # Fuselage: a faceted spindle. Nose at -Z, engine block at +Z.
    hull = Part(
        verts=[
            (0.00, 0.00, -2.60),                                        # 0 nose
            (0.00, 0.58, -0.70), (0.52, 0.06, -0.70),                   # 1 2  forward ring
            (0.00, -0.46, -0.70), (-0.52, 0.06, -0.70),                 # 3 4
            (0.00, 0.44, 1.30), (0.40, 0.04, 1.30),                     # 5 6  aft ring
            (0.00, -0.34, 1.30), (-0.40, 0.04, 1.30),                   # 7 8
            (0.00, 0.00, 1.62),                                         # 9 tail point
        ],
        faces=[
            [0, 1, 2], [0, 2, 3], [0, 3, 4], [0, 4, 1],
            [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 8, 4], [4, 8, 5, 1],
            [5, 9, 6], [6, 9, 7], [7, 9, 8], [8, 9, 5],
        ],
    )
    parts.append(hull)

    # Right wing: a swept, tapered slab with real thickness.
    wing_plan = [
        (0.40, -0.06, -0.40),
        (1.32, -0.06, 1.02),
        (1.14, -0.06, 1.32),
        (0.36, -0.06, 1.24),
    ]
    right_wing = prism(wing_plan, (0.0, 0.13, 0.0))
    parts.append(right_wing)
    parts.append(mirror_x(right_wing))

    # Dorsal fin.
    fin_plan = [
        (-0.05, 0.40, 0.26),
        (-0.05, 1.08, 1.16),
        (-0.05, 0.98, 1.40),
        (-0.05, 0.36, 1.38),
    ]
    parts.append(prism(fin_plan, (0.10, 0.0, 0.0)))

    # Engine nacelles: silhouette anchors, and where a thruster flare will go.
    for sx in (-1.0, 1.0):
        parts.append(box((sx * 0.60, -0.02, 0.92), (0.30, 0.28, 1.05)))

    return parts


def main():
    write_obj(OUT, "probe", build_parts(), "gen_probe_obj.py")


if __name__ == "__main__":
    main()
