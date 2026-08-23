#!/usr/bin/env python3
"""Generate assets/models/probe.obj — the gray-box stand-in ship hull.

Placeholder assets are generated from a script wherever that is practical, so
an asset review is a diff review and nothing needs a DCC tool to reproduce.
Real art replaces the .obj in place; nothing in code knows it was generated.

Run: python3 tools/gen_probe_obj.py   (or `make assets`)

Godot convention: -Z is forward, +Y is up. Every part below is a convex solid;
face winding is fixed up automatically against the part's own centroid, so the
part definitions do not have to get vertex order right by hand.
"""
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets" / "models" / "probe.obj"


# --- tiny vector helpers -----------------------------------------------------

def add(a, b): return (a[0] + b[0], a[1] + b[1], a[2] + b[2])
def sub(a, b): return (a[0] - b[0], a[1] - b[1], a[2] - b[2])
def dot(a, b): return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
def scale(a, k): return (a[0] * k, a[1] * k, a[2] * k)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def normalize(v):
    m = (v[0] ** 2 + v[1] ** 2 + v[2] ** 2) ** 0.5
    return (0.0, 1.0, 0.0) if m < 1e-9 else (v[0] / m, v[1] / m, v[2] / m)


def centroid(points):
    n = len(points)
    return (sum(p[0] for p in points) / n, sum(p[1] for p in points) / n, sum(p[2] for p in points) / n)


# --- part builders -----------------------------------------------------------

class Part:
    """A convex solid: a vertex list plus faces as index tuples."""

    def __init__(self, verts, faces):
        self.verts = [tuple(map(float, v)) for v in verts]
        self.faces = [list(f) for f in faces]
        self._orient()

    def _orient(self):
        """Flip any face whose normal points inward. Convexity makes this exact."""
        c = centroid(self.verts)
        for face in self.faces:
            pts = [self.verts[i] for i in face]
            n = cross(sub(pts[1], pts[0]), sub(pts[2], pts[0]))
            if dot(n, sub(centroid(pts), c)) < 0.0:
                face.reverse()


def prism(polygon, offset):
    """Extrude an ordered planar polygon by `offset`. Winding is fixed afterwards."""
    n = len(polygon)
    verts = list(polygon) + [add(p, offset) for p in polygon]
    faces = [list(range(n)), list(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append([i, j, j + n, i + n])
    return Part(verts, faces)


def box(center, size):
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    v = [(center[0] + sx * hx, center[1] + sy * hy, center[2] + sz * hz)
         for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    faces = [[0, 1, 3, 2], [4, 5, 7, 6], [0, 1, 5, 4], [2, 3, 7, 6], [0, 2, 6, 4], [1, 3, 7, 5]]
    return Part(v, faces)


def mirror_x(part):
    verts = [(-v[0], v[1], v[2]) for v in part.verts]
    return Part(verts, [list(f) for f in part.faces])


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


# --- obj emit ----------------------------------------------------------------

def planar_uv(p, n, uv_scale=0.35):
    ax, ay, az = abs(n[0]), abs(n[1]), abs(n[2])
    if ax >= ay and ax >= az:
        u, v = p[2], p[1]
    elif ay >= az:
        u, v = p[0], p[2]
    else:
        u, v = p[0], p[1]
    return (u * uv_scale + 0.5, 1.0 - (v * uv_scale + 0.5))


def main():
    lines = [
        "# probe.obj — gray-box hull for the Missile Rider sandbox.",
        "# GENERATED by tools/gen_probe_obj.py. Do not hand-edit; edit the generator.",
        "o probe",
    ]
    positions, uvs, normals, face_rows = [], [], [], []

    for part in build_parts():
        base = len(positions)
        positions.extend(part.verts)
        for face in part.faces:
            pts = [part.verts[i] for i in face]
            n = normalize(cross(sub(pts[1], pts[0]), sub(pts[2], pts[0])))
            normals.append(n)
            ni = len(normals)
            corners = []
            for idx, p in zip(face, pts):
                uvs.append(planar_uv(p, n))
                corners.append("%d/%d/%d" % (base + idx + 1, len(uvs), ni))
            face_rows.append("f " + " ".join(corners))

    lines += ["v %.4f %.4f %.4f" % p for p in positions]
    lines += ["vt %.4f %.4f" % uv for uv in uvs]
    lines += ["vn %.4f %.4f %.4f" % nn for nn in normals]
    lines += face_rows

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines) + "\n")
    tris = sum(len(r.split()) - 3 for r in face_rows)
    print(f"wrote {OUT} — {len(positions)} verts, {len(face_rows)} faces, {tris} tris")


if __name__ == "__main__":
    main()
